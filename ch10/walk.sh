#!/usr/bin/env bash
# Chapter 10: the packet walk, recorded hop by hop. Two pods on two
# racks, and every table a packet consults between them: the endpoint
# identity, the node FIB, the ToR's BGP table, the spine, the delivery
# leaf. Evidence under audits/walk/.
set -uo pipefail

LAB=bgpbook-ch10
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
OUT=audits/walk
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== Two pods, two racks ==="
${K} delete pod walk-a walk-b --ignore-not-found --wait=true >/dev/null 2>&1
${K} run walk-a --image=python:3.12-alpine --image-pull-policy=Never \
  --overrides='{"spec":{"nodeName":"node01"}}' --command -- sleep 3600 >/dev/null 2>&1
${K} run walk-b --image=python:3.12-alpine --image-pull-policy=Never \
  --overrides='{"spec":{"nodeName":"node03"}}' --command -- sleep 3600 >/dev/null 2>&1
${K} wait --for=condition=Ready pod/walk-a pod/walk-b --timeout=120s >/dev/null 2>&1
A=$(${K} get pod walk-a -o jsonpath='{.status.podIP}')
B=$(${K} get pod walk-b -o jsonpath='{.status.podIP}')
echo "  walk-a on node01: ${A}   walk-b on node03: ${B}"

{
  echo "=== The walk: walk-a (${A}, node01) to walk-b (${B}, node03) ==="
  echo "--- 1. the pod's reachability, proven first ---"
  ${K} exec walk-a -- ping -c 3 -W 2 ${B} 2>&1 | tail -2
  echo "--- 2. the eBPF view: pods are endpoints with identities, not interfaces ---"
  ${K} get ciliumendpoints -o wide 2>/dev/null | awk 'NR==1 || /walk/'
  echo "--- 3. node01's FIB: the remote pod range goes to the ToR ---"
  docker exec node01 ip route get ${B} | head -1
  echo "--- 4. leaf01's BGP table: the /24 behind node03, learned via the spines ---"
  sw leaf01 "sudo vtysh -c 'show ip bgp $(echo ${B} | cut -d. -f1-3).0/24' | grep -E 'Paths|6551|65100|from'"
  echo "--- 5. the spine's view ---"
  sw spine01 "ip route show $(echo ${B} | cut -d. -f1-3).0/24"
  echo "--- 6. leaf02 delivers to node03's session address ---"
  sw leaf02 "sudo vtysh -c 'show ip bgp $(echo ${B} | cut -d. -f1-3).0/24' | grep -E 'Paths|65510|from'"
} | tee "${OUT}/walk.txt"
echo "Evidence written to ${OUT}/"
