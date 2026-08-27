#!/usr/bin/env bash
# The over-tuning trap, sprung deterministically: freeze spine01's CPU for
# a stated number of milliseconds (docker pause/unpause around the switch),
# the kind of control-plane stall a saturated CPU or a busy hypervisor
# produces, and see which detection settings declare the switch dead.
# A 400 ms stall is longer than the aggressive profile's 100 ms budget
# (50 ms x 2) and comfortably inside the default profile's 900 ms
# (300 ms x 3). Evidence under audits/tuning/.
set -uo pipefail
LABEL=${1:?usage: stall.sh <label> [stall-ms]}
MS=${2:-400}
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
mkdir -p audits/tuning
F="audits/tuning/stall_${LABEL}.txt"
: > "${F}"

echo "== ${LABEL}: ${MS} ms CPU stall on spine01, ping running ==" | tee -a "${F}"
before=$(${SSH} cumulus@clab-${LAB}-leaf04 "sudo grep -c ADJCHANGE /var/log/frr/frr.log" 2>/dev/null)
${D}-server02 sh -c "ping -i 0.02 -w 25 -q 172.16.1.11 > /tmp/stallping.txt; true" &
pp=$!
sleep 8
docker pause clab-${LAB}-spine01 >/dev/null
sleep "$(awk "BEGIN{printf \"%.3f\", ${MS}/1000}")"
docker unpause clab-${LAB}-spine01 >/dev/null
echo "stalled and resumed" | tee -a "${F}"
wait ${pp} || true
${D}-server02 sh -c "tail -2 /tmp/stallping.txt" | tee -a "${F}"
after=$(${SSH} cumulus@clab-${LAB}-leaf04 "sudo grep -c ADJCHANGE /var/log/frr/frr.log" 2>/dev/null)
echo "leaf04 ADJCHANGE lines before=${before} after=${after}" | tee -a "${F}"
if [ "${after}" != "${before}" ]; then
  echo "SESSION RESET by the stall; latest transitions:" | tee -a "${F}"
  ${SSH} cumulus@clab-${LAB}-leaf04 "sudo grep 'ADJCHANGE' /var/log/frr/frr.log | tail -2" 2>/dev/null | tee -a "${F}"
else
  echo "no session reset: the stall fit inside the detection budget" | tee -a "${F}"
fi
echo "recorded ${F}"
