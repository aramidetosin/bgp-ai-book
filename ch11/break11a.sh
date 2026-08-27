#!/usr/bin/env bash
# Chapter 11 break-fix: the service is served from one leaf only. During
# an incident the deployment was scaled to one replica (which landed on
# node01) and externalTrafficPolicy is Local, so exactly one node
# advertises the VIP and every path in the fabric funnels through leaf01.
# The service works; the redundancy is gone, and nothing alerts.
# Evidence under audits/break11a/.
set -uo pipefail

LAB=bgpbook-ch10
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
VIP=172.16.200.1
OUT=audits/break11a
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== The incident's leftovers: one replica, pinned, eTP Local ==="
${K} patch svc inference -p '{"spec":{"externalTrafficPolicy":"Local"}}' >/dev/null 2>&1
${K} patch deploy inference --type json -p '[
  {"op":"replace","path":"/spec/replicas","value":1},
  {"op":"add","path":"/spec/template/spec/nodeName","value":"node01"},
  {"op":"remove","path":"/spec/template/spec/topologySpreadConstraints"}]' >/dev/null 2>&1
${K} rollout status deploy/inference --timeout=120s >/dev/null 2>&1
for i in $(seq 1 20); do
  n=$(${K} get pods -l app=inference --no-headers 2>/dev/null | wc -l | tr -d " ")
  [ "${n}" = "1" ] && break
  sleep 5
done
sleep 15

{
  echo "=== The symptom that is not a symptom: the service works ==="
  ${D}-client02 sh -c "curl -sN --max-time 4 http://${VIP}/ | head -1"
  echo
  echo "=== The investigation ==="
  echo "--- leaf03's paths to the VIP: one, via one leaf ---"
  sw leaf03 "sudo vtysh -c 'show ip bgp ${VIP}/32' | grep -E 'Paths|655'"
  echo "--- leaf02's session to node03 is up; node03 just has nothing to say ---"
  sw leaf02 "sudo vtysh -c 'show bgp summary' | tail -3"
  echo "--- the cause, from the cluster side ---"
  ${K} get pods -l app=inference -o wide --no-headers | awk '{print "  "$1" "$7}'
  ${K} get svc inference -o jsonpath='  eTP: {.spec.externalTrafficPolicy}{"\n"}'
} | tee "${OUT}/evidence.txt"
echo
echo "break-11a armed. make heal-11a undoes it."
