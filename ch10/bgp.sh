#!/usr/bin/env bash
# Chapter 10: the CNI meets the ToRs. Configures the switch side of the
# node sessions (numbered peering to the nodes, import filtered to pod
# /24s), labels the nodes, applies the Cilium BGP resources, and records
# the evidence. Evidence under audits/bgp/.
set -uo pipefail

LAB=bgpbook-ch10
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
OUT=audits/bgp
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== Step 1: the ToR side, sessions plus the pod filter ==="
for pair in "leaf01:172.16.1.11 172.16.1.12" "leaf02:172.16.2.11"; do
  dev=${pair%%:*}; nodes=${pair##*:}
  cmds="nv set router policy prefix-list PODS-IN rule 10 action permit && \
    nv set router policy prefix-list PODS-IN rule 10 match 10.244.0.0/16 min-prefix-len 24 && \
    nv set router policy prefix-list PODS-IN rule 10 match 10.244.0.0/16 max-prefix-len 24 && \
    nv set router policy route-map RM-PODS-IN rule 10 action permit && \
    nv set router policy route-map RM-PODS-IN rule 10 match type ipv4 && \
    nv set router policy route-map RM-PODS-IN rule 10 match ip-prefix-list PODS-IN"
  for n in ${nodes}; do
    cmds="${cmds} && nv set vrf default router bgp neighbor ${n} remote-as external && \
      nv set vrf default router bgp neighbor ${n} address-family ipv4-unicast policy inbound route-map RM-PODS-IN && \
      nv set vrf default router bgp neighbor ${n} address-family ipv4-unicast prefix-limits inbound maximum 20 && \
      nv set vrf default router bgp neighbor ${n} address-family ipv4-unicast soft-reconfiguration on"
  done
  for try in 1 2 3; do
    sw ${dev} "${cmds}" >/dev/null
    sw ${dev} "nv config apply -y" >/dev/null
    got=$(sw ${dev} "nv config show -o commands | grep -c 'PODS-IN\|neighbor 172'")
    exp=$(( 6 + 4 * $(echo ${nodes} | wc -w) ))
    [ "${got}" -ge "$((exp - 1))" ] && break
    sw ${dev} "nv config detach" >/dev/null; sleep 5
  done
  echo "  ${dev}: node sessions + pod filter (${got} config lines)"
done

echo "=== Step 2: node labels and the Cilium BGP resources ==="
${K} label node node01 rack=rack1 --overwrite >/dev/null
${K} label node node02 rack=rack1 --overwrite >/dev/null
${K} label node node03 rack=rack2 --overwrite >/dev/null
docker exec -i node01 kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f - < manifests/bgp.yaml
sleep 20

{
  echo "=== The sessions: the CNI in the same neighbor list as the fabric ==="
  echo "--- leaf01 ---"
  sw leaf01 "sudo vtysh -c 'show bgp summary' | tail -9"
  echo "--- node03's agent, from inside ---"
  CIL=$(${K} -n kube-system get pods -l k8s-app=cilium -o wide --no-headers | awk '/node03/{print $1}')
  ${K} -n kube-system exec ${CIL} -c cilium-agent -- cilium-dbg bgp peers 2>/dev/null
} | tee "${OUT}/sessions.txt"

{
  echo "=== What the fabric learned: one /24 per node, and nothing else ==="
  echo "--- leaf03 (no nodes attached; the routes arrived over the fabric) ---"
  sw leaf03 "ip route show | grep 10.244"
  echo "--- leaf01's filter at work ---"
  sw leaf01 "sudo vtysh -c 'show ip bgp neighbors 172.16.1.11 received-routes' | tail -6"
  sw leaf01 "sudo vtysh -c 'show ip bgp neighbors 172.16.1.11 routes' | tail -5"
} | tee "${OUT}/routes.txt"
echo "Evidence written to ${OUT}/"
