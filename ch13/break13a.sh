#!/usr/bin/env bash
# Chapter 13 break-fix: one leaf sends the RoCE switch-priority to the
# wrong egress queue, so on that one hop the lossless class (DSCP 26,
# switch-priority 3) rides the default lossy queue 0 instead of queue 3.
# Every session stays up and every link is green; the only symptom is a
# queue map that disagrees with the rest of the fabric, which the
# consistency checker (make qoscheck) finds. Evidence under
# audits/break13a/.
set -uo pipefail
LAB=bgpbook-ch13
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
OUT=audits/break13a; mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== The typo: leaf02 maps switch-priority 3 to queue 0, not 3 ==="
sw leaf02 "nv config detach; nv set qos egress-queue-mapping default-global switch-priority 3 traffic-class 0 && nv config apply -y" >/dev/null
sleep 4
{
  echo "=== leaf02's egress map now sends the RoCE class to the lossy queue ==="
  sw leaf02 "nv show qos egress-queue-mapping default-global -o json 2>/dev/null | python3 -c \"import json,sys;print('  leaf02 switch-priority 3 -> queue', json.load(sys.stdin)['switch-priority']['3']['traffic-class'])\""
  echo
  echo "=== The checker finds the one hop that disagrees ==="
  ./qoscheck.sh 2>/dev/null
} | tee "${OUT}/evidence.txt"
echo
echo "break-13a armed and recorded. make heal-13a undoes it."
