#!/usr/bin/env bash
# Chapter 10 break-fix: the peer ASN in the CRD is wrong, and the
# diagnosis runs entirely from the Kubernetes side: no switch access.
# Evidence under audits/break10a/.
set -uo pipefail

LAB=bgpbook-ch10
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
OUT=audits/break10a
mkdir -p "${OUT}"

echo "=== The typo: rack2's peer ASN becomes 65103 (leaf02 is 65102) ==="
${K} patch ciliumbgpclusterconfig rack2 --type json \
  -p '[{"op":"replace","path":"/spec/bgpInstances/0/peers/0/peerASN","value":65103}]' >/dev/null
sleep 25

{
  echo "=== The diagnosis, without touching a switch ==="
  echo "--- the agent's view on node03 ---"
  CIL=$(${K} -n kube-system get pods -l k8s-app=cilium -o wide --no-headers | awk '/node03/{print $1}')
  ${K} -n kube-system exec ${CIL} -c cilium-agent -- cilium-dbg bgp peers 2>/dev/null
  echo "--- the node's BGP status conditions ---"
  ${K} get ciliumbgpnodeconfigs node03 -o yaml | sed -n '/status:/,$p' | head -20
} | tee "${OUT}/evidence.txt"
echo
echo "break-10a armed. make heal-10a undoes it."
