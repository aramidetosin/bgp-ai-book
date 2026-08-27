#!/usr/bin/env bash
# The over-tuning trap, demonstrated: load spine01's control plane while a
# ping runs, and see whether the armed detection settings survive it.
# CPU hogs run inside the switch itself, starving the processes that answer
# keepalives and BFD, which stands in for a busy control plane. Records
# session flaps (or the absence of them) plus ping loss. Evidence under
# audits/tuning/.
set -uo pipefail
LABEL=${1:?usage: stress.sh <label>}
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
mkdir -p audits/tuning
F="audits/tuning/stress_${LABEL}.txt"
: > "${F}"

echo "== ${LABEL}: 60 s of CPU starvation on spine01, ping running ==" | tee -a "${F}"
before=$(${SSH} cumulus@clab-${LAB}-leaf04 "sudo grep -c ADJCHANGE /var/log/frr/frr.log" 2>/dev/null)
${D}-server02 ping -i 0.01 -w 75 -q 172.16.1.11 > /tmp/stressping.$$ &
pp=$!
sleep 5
${SSH} cumulus@clab-${LAB}-spine01 \
  "sudo sh -c 'for i in 1 2 3 4 5 6; do nohup yes >/dev/null 2>&1 & done; sleep 60; pkill yes'" 2>/dev/null \
  && echo "stress window complete" | tee -a "${F}"
wait ${pp} || true
tail -3 /tmp/stressping.$$ | tee -a "${F}"
after=$(${SSH} cumulus@clab-${LAB}-leaf04 "sudo grep -c ADJCHANGE /var/log/frr/frr.log" 2>/dev/null)
echo "leaf04 ADJCHANGE lines before=${before} after=${after}" | tee -a "${F}"
if [ "${after}" != "${before}" ]; then
  echo "SESSION FLAPPED during stress; latest transitions:" | tee -a "${F}"
  ${SSH} cumulus@clab-${LAB}-leaf04 "sudo grep 'ADJCHANGE\|BFD' /var/log/frr/frr.log | tail -6" 2>/dev/null | tee -a "${F}"
else
  echo "no session flap during stress" | tee -a "${F}"
fi
rm -f /tmp/stressping.$$
echo "recorded ${F}"
