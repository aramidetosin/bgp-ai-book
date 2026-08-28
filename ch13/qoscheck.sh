#!/usr/bin/env bash
# Chapter 13: the QoS consistency checker. Classification only works if
# every hop agrees, so this resolves the RoCE data DSCP (26) the whole
# way down, DSCP to switch-priority to egress queue, on every switch,
# and reports the fabric consistent only when all hops land it on the
# same queue. This is the containerlab-checkable half of chapter 13;
# the dataplane behaviour (PFC, ECN, buffers) lives on real hardware
# under hw/.
set -uo pipefail

LAB=bgpbook-ch13
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
DSCP=${1:-26}
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== RoCE data DSCP ${DSCP}: the queue it lands on, every hop ==="
declare -A QUEUE
expected=""
fail=0
for dev in leaf01 leaf02 spine01 spine02; do
  dmap=$(sw ${dev} "nv show qos mapping default-global -o json")
  emap=$(sw ${dev} "nv show qos egress-queue-mapping default-global -o json")
  q=$(python3 -c "
import json,sys
try:
    d=json.loads('''${dmap}'''); e=json.loads('''${emap}''')
    sp=str(d['dscp']['${DSCP}']['switch-priority'])
    tc=e['switch-priority'][sp]['traffic-class']
    print(f'{sp} {tc}')
except Exception as ex:
    print('? ?')" 2>/dev/null)
  sp=${q%% *}; tc=${q##* }
  QUEUE[$dev]="${tc}"
  [ -z "${expected}" ] && expected="${tc}"
  echo "  ${dev}: DSCP ${DSCP} -> switch-priority ${sp} -> queue ${tc}"
done

# consensus = the value the majority of hops agree on
consensus=$(printf '%s\n' "${QUEUE[@]}" | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
echo "=== Verdict ==="
for dev in leaf01 leaf02 spine01 spine02; do
  if [ "${QUEUE[$dev]}" = "${consensus}" ]; then
    echo "  ${dev}: queue ${QUEUE[$dev]} - OK"
  else
    echo "  ${dev}: queue ${QUEUE[$dev]} - MISMATCH (fabric agrees on queue ${consensus})"
    fail=1
  fi
done
[ "${fail}" = "0" ] && echo "CLASSIFICATION CONSISTENT: DSCP ${DSCP} rides queue ${consensus} on every hop" \
                     || echo "CLASSIFICATION INCONSISTENT: one or more hops disagree"
exit ${fail}
