#!/usr/bin/env bash
# Chapter 10: native routing against tunnel mode, on the wire. Captures
# the same pod-to-pod ping on leaf02 swp1 in native mode (bare pod
# addresses) and in VXLAN tunnel mode (node addresses on UDP 8472),
# then returns to native. Evidence under audits/tunnel/.
set -uo pipefail

LAB=bgpbook-ch10
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
CILV=$(awk '/cilium_version:/{print $2}' spec.yml)
API_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' node01)
OUT=audits/tunnel
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

B=$(${K} get pod walk-b -o jsonpath='{.status.podIP}')

capture() {
  local label=$1 filter=$2
  sw leaf02 "sudo timeout 8 tcpdump -c 4 -n -i swp1 ${filter} 2>/dev/null" > "${OUT}/.cap" &
  CAP=$!
  sleep 1
  ${K} exec walk-a -- ping -c 5 -W 2 ${B} >/dev/null 2>&1
  wait ${CAP}
  echo "--- ${label} ---"
  head -4 "${OUT}/.cap"
}

render() {
  helm template cilium cilium/cilium --version ${CILV} --namespace kube-system \
    --set kubeProxyReplacement=true \
    --set k8sServiceHost=${API_IP} --set k8sServicePort=6443 \
    --set routingMode=$1 $2 \
    --set enableIPv4Masquerade=false \
    --set bgpControlPlane.enabled=true \
    --set l2announcements.enabled=true \
    --set devices=eth1 \
    --set ipam.mode=kubernetes \
    --set operator.replicas=1 > /tmp/cilium-$1.yaml
  docker exec -i node01 kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f - < /tmp/cilium-$1.yaml >/dev/null 2>&1
  ${K} -n kube-system rollout restart ds/cilium >/dev/null 2>&1
  ${K} -n kube-system rollout status ds/cilium --timeout=180s >/dev/null 2>&1
  sleep 10
}

{
  echo "=== Native routing: the fabric sees the pods themselves ==="
  capture "leaf02 swp1 (node03-facing), pod-to-pod ping, native mode" "icmp and net 10.244.0.0/16"
  echo
  echo "=== Switching to tunnel mode (VXLAN) ==="
  render tunnel ""
  echo "  routingMode now: $(${K} -n kube-system get cm cilium-config -o jsonpath='{.data.routing-mode}')"
  capture "leaf02 swp1, the same ping, tunnel mode" "udp port 8472"
  echo
  echo "=== Back to native ==="
  render native "--set ipv4NativeRoutingCIDR=10.244.0.0/16"
  echo "  routingMode now: $(${K} -n kube-system get cm cilium-config -o jsonpath='{.data.routing-mode}')"
} | tee "${OUT}/tunnel.txt"
rm -f "${OUT}/.cap"
echo "Evidence written to ${OUT}/"
