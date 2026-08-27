#!/usr/bin/env bash
# Measure session re-establishment after a local link bounce on leaf04:
# down swp2 (the spine01 uplink), wait, bring it up, and read the whole
# timeline from leaf04's own log so one clock tells the story.
set -uo pipefail
LABEL=${1:?usage: reconnect.sh <label>}
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
mkdir -p audits/tuning
F="audits/tuning/reconnect_${LABEL}.txt"
: > "${F}"

echo "== ${LABEL}: bounce leaf04 swp2, timeline from leaf04's log ==" | tee -a "${F}"
${SSH} cumulus@clab-${LAB}-leaf04 \
  "sudo ip link set swp2 down && sleep 25 && sudo date '+link up at: %H:%M:%S.%3N' && sudo ip link set swp2 up" \
  2>/dev/null | tee -a "${F}"
sleep 45
${SSH} cumulus@clab-${LAB}-leaf04 \
  "sudo grep -E 'ADJCHANGE' /var/log/frr/frr.log | tail -2" 2>/dev/null | tee -a "${F}"
echo "recorded ${F}"
