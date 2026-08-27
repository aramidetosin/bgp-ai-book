#!/usr/bin/env bash
# Build the Kubernetes cluster: fabric addressing on eth1, kubeadm init
# and join (kube-proxy skipped: Cilium replaces it), Cilium images
# preloaded into containerd on every node, and Cilium installed from a
# locally rendered helm template. The recorded recipe the chapter's
# "kubeadm-built cluster inside containerlab" promise refers to.
set -uo pipefail

LAB=bgpbook-ch10
D="docker exec clab-${LAB}"
K8SV=$(awk '/k8s_version:/{print $2}' spec.yml)
CILV=$(awk '/cilium_version:/{print $2}' spec.yml)

echo "=== Step 1: fabric addressing on every node's eth1 ==="
docker exec node01 bash -c "ip addr add 172.16.1.11/24 dev eth1 2>/dev/null; ip link set eth1 mtu 9216; ip route replace 172.16.0.0/16 via 172.16.1.1 dev eth1; ip route replace 10.244.0.0/16 via 172.16.1.1 dev eth1"
docker exec node02 bash -c "ip addr add 172.16.1.12/24 dev eth1 2>/dev/null; ip link set eth1 mtu 9216; ip route replace 172.16.0.0/16 via 172.16.1.1 dev eth1; ip route replace 10.244.0.0/16 via 172.16.1.1 dev eth1"
docker exec node03 bash -c "ip addr add 172.16.2.11/24 dev eth1 2>/dev/null; ip link set eth1 mtu 9216; ip route replace 172.16.0.0/16 via 172.16.2.1 dev eth1; ip route replace 10.244.0.0/16 via 172.16.2.1 dev eth1"
echo "  eth1 addressed; fabric and pod ranges route via the ToR"

# The lab host runs with swap (kubelet refuses that by default), and the
# node's Kubernetes identity belongs on the fabric NIC, not the docker
# bridge: node-ip decides where NodePorts and tunnel endpoints live.
docker exec node01 bash -c "echo KUBELET_EXTRA_ARGS=\"--fail-swap-on=false --node-ip=172.16.1.11\" > /etc/default/kubelet"
docker exec node02 bash -c "echo KUBELET_EXTRA_ARGS=\"--fail-swap-on=false --node-ip=172.16.1.12\" > /etc/default/kubelet"
docker exec node03 bash -c "echo KUBELET_EXTRA_ARGS=\"--fail-swap-on=false --node-ip=172.16.2.11\" > /etc/default/kubelet"

API_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' node01)
echo "=== Step 2: kubeadm init on node01 (API at ${API_IP}, kube-proxy skipped) ==="
docker exec node01 kubeadm reset -f >/dev/null 2>&1
docker exec node01 kubeadm init --kubernetes-version ${K8SV} \
  --apiserver-advertise-address ${API_IP} \
  --pod-network-cidr 10.244.0.0/16 \
  --skip-phases=addon/kube-proxy \
  --ignore-preflight-errors=all >/tmp/kubeadm_init.log 2>&1 \
  && echo "  control plane up" || { echo "  kubeadm init FAILED"; exit 1; }

JOIN=$(docker exec node01 kubeadm token create --print-join-command 2>/dev/null | tail -1)
for n in node02 node03; do
  docker exec ${n} kubeadm reset -f >/dev/null 2>&1
  docker exec ${n} bash -c "${JOIN} --ignore-preflight-errors=all" >/dev/null 2>&1 \
    && echo "  ${n} joined" || echo "  ${n} join FAILED"
done

K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"

echo "=== Step 3: Cilium images, preloaded into every node ==="
for img in quay.io/cilium/cilium:v${CILV} quay.io/cilium/operator-generic:v${CILV} $(helm template cilium cilium/cilium --version ${CILV} --namespace kube-system 2>/dev/null | grep -o "quay.io/cilium/cilium-envoy:[^\"]*" | head -1); do
  docker image inspect ${img} >/dev/null 2>&1 || docker pull ${img} >/dev/null
done
docker image inspect python:3.12-alpine >/dev/null 2>&1 || docker pull python:3.12-alpine >/dev/null
for n in node01 node02 node03; do
  docker save quay.io/cilium/cilium:v${CILV} quay.io/cilium/operator-generic:v${CILV} python:3.12-alpine \
    | docker exec -i ${n} ctr -n k8s.io images import - >/dev/null 2>&1
  echo "  ${n}: images imported"
done

echo "=== Step 4: Cilium, rendered locally and applied ==="
command -v helm >/dev/null 2>&1 || {
  curl -fsSL https://get.helm.sh/helm-v3.16.3-linux-amd64.tar.gz | tar xz -C /tmp
  install /tmp/linux-amd64/helm /usr/local/bin/helm
}
helm repo add cilium https://helm.cilium.io >/dev/null 2>&1; helm repo update >/dev/null 2>&1
helm template cilium cilium/cilium --version ${CILV} --namespace kube-system \
  --set kubeProxyReplacement=true \
  --set k8sServiceHost=${API_IP} --set k8sServicePort=6443 \
  --set routingMode=native \
  --set ipv4NativeRoutingCIDR=10.244.0.0/16 \
  --set enableIPv4Masquerade=false \
  --set bgpControlPlane.enabled=true \
  --set l2announcements.enabled=true \
  --set devices=eth1 \
  --set ipam.mode=kubernetes \
  --set operator.replicas=1 \
  > /tmp/cilium.yaml
docker exec -i node01 kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f - < /tmp/cilium.yaml >/dev/null 2>&1 && echo "  cilium applied"

echo "=== Step 5: waiting for the cluster ==="
for i in $(seq 1 30); do
  ready=$(${K} get nodes --no-headers 2>/dev/null | grep -c " Ready") || true
  [ "${ready}" = "3" ] && break
  sleep 10
done
${K} get nodes -o wide 2>/dev/null | awk '{print "  "$1" "$2" "$6}'
cil=$(${K} -n kube-system get pods -l k8s-app=cilium --no-headers 2>/dev/null | grep -c Running) || true
echo "  cilium agents running: ${cil}/3"
