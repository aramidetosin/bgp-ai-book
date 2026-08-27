#!/usr/bin/env bash
# Chapter 11, the anycast build: the inference VIP advertised from every
# node, long-lived token streams opened across it, a serving node killed
# mid-stream, broken streams counted; then the same failure with drain
# choreography (eTP Local plus withdraw-before-terminate) and the counts
# compared. Evidence under audits/anycast/.
set -uo pipefail

LAB=bgpbook-ch10
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
VIP=172.16.200.1
OUT=audits/anycast
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

streams() { # start 6 streams from client02, return after they finish, print survival
  ${D}-client02 sh -c "rm -f /tmp/s*.log; for i in 1 2 3 4 5 6; do \
    (curl -sN --max-time 30 http://${VIP}/ > /tmp/s\$i.log 2>&1; echo \$? > /tmp/s\$i.rc) & done; wait"
  ${D}-client02 sh -c "ok=0; for i in 1 2 3 4 5 6; do \
    if grep -q done /tmp/s\$i.log 2>/dev/null; then ok=\$((ok+1)); \
    else echo \"  stream \$i: broken after \$(grep -c token /tmp/s\$i.log 2>/dev/null) tokens (served by \$(head -1 /tmp/s\$i.log 2>/dev/null | sed 's/serving //'))\"; fi; done; \
    echo \"  streams completed: \$ok/6\""
}

{
  echo "=== eTP Local: only nodes with ready backends advertise ==="
  ${K} patch svc inference -p '{"spec":{"externalTrafficPolicy":"Local"}}' >/dev/null
  sleep 12
  echo "--- leaf02's view: node03 advertises while it has a ready backend ---"
  sw leaf02 "sudo vtysh -c 'show ip bgp ${VIP}/32' | grep -E 'Paths|65510|from'"

  echo
  echo "=== Round 1: node death mid-stream, no drain ==="
  ${D}-client02 sh -c "rm -f /tmp/s*.log; for i in 1 2 3 4 5 6; do \
    (curl -sN --max-time 30 http://${VIP}/ > /tmp/s\$i.log 2>&1) & done" &
  sleep 4
  echo "--- freezing node03 four seconds in ---"
  docker pause node03
  wait
  sleep 28
  ${D}-client02 sh -c "ok=0; for i in 1 2 3 4 5 6; do \
    if grep -q done /tmp/s\$i.log 2>/dev/null; then ok=\$((ok+1)); \
    else echo \"  stream \$i: broken after \$(grep -c token /tmp/s\$i.log 2>/dev/null) tokens (\$(head -1 /tmp/s\$i.log 2>/dev/null))\"; fi; done; \
    echo \"  streams completed: \$ok/6\""
  docker unpause node03
  ${K} rollout status deploy/inference --timeout=120s >/dev/null 2>&1
  sleep 20

  echo
  echo "=== Round 2: the same node leaves politely: out of rotation first ==="
  echo "--- streams open; then cordon node03 and take its pod out of the service ---"
  ${D}-client02 sh -c "rm -f /tmp/s*.log; for i in 1 2 3 4 5 6; do \
    (curl -sN --max-time 30 http://${VIP}/ > /tmp/s\$i.log 2>&1) & done" &
  sleep 4
  POD=$(${K} get pods -l app=inference -o wide --no-headers | awk '/node03/{print $1}')
  ${K} cordon node03 >/dev/null 2>&1
  ${K} label pod ${POD} app- >/dev/null 2>&1
  echo "--- ${POD} out of rotation: still running, no longer an endpoint;"
  echo "    the replacement schedules elsewhere, node03 withdraws the VIP ---"
  wait
  sleep 5
  ${D}-client02 sh -c "ok=0; for i in 1 2 3 4 5 6; do \
    if grep -q done /tmp/s\$i.log 2>/dev/null; then ok=\$((ok+1)); \
    else echo \"  stream \$i: broken after \$(grep -c token /tmp/s\$i.log 2>/dev/null) tokens\"; fi; done; \
    echo \"  streams completed: \$ok/6\""
  echo "--- leaf02's view after the drain: no local backend, no direct path ---"
  sw leaf02 "sudo vtysh -c 'show ip bgp ${VIP}/32' | grep -E 'Paths|65510|from|Network not in'"
  ${K} delete pod ${POD} --wait=false >/dev/null 2>&1
  ${K} uncordon node03 >/dev/null 2>&1
} | tee "${OUT}/anycast.txt"
${K} rollout status deploy/inference --timeout=120s >/dev/null 2>&1
echo "Evidence written to ${OUT}/"
