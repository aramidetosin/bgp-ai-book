#!/usr/bin/env bash
# Chapter 8, the collision ladder: the same traffic sent as 1, 4, and 16
# flows, and where each lands on leaf01's four equal uplinks. The 4-flow
# run happens twice so the dice get rethrown: same flow count, new
# ephemeral ports, a different split. Evidence under audits/collide/.
set -uo pipefail

LAB=bgpbook-ch08
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
OUT=audits/collide
mkdir -p "${OUT}"
PORTS="swp2 swp3 swp4 swp5"

sample() {
  ${SSH} cumulus@clab-${LAB}-leaf01 \
    "for p in ${PORTS}; do echo -n \"\$p \"; cat /sys/class/net/\$p/statistics/tx_bytes; done" 2>/dev/null
}

${D}-server02 pkill iperf3 2>/dev/null
sleep 1
${D}-server02 iperf3 -s -D

run() {
  local label=$1 flows=$2 slug=$3
  echo "--- ${label}: iperf3 -P ${flows} -t 8, server01 -> server02 ---"
  sample > "${OUT}/.before"
  ${D}-server01 iperf3 -c 172.16.2.11 -P "${flows}" -t 8 > "${OUT}/iperf_${slug}.txt" 2>&1
  sample > "${OUT}/.after"
  grep -E "SUM.*receiver|] .* receiver" "${OUT}/iperf_${slug}.txt" | tail -1
  python3 - "${OUT}/.before" "${OUT}/.after" <<'PY'
import sys
b = dict(l.split() for l in open(sys.argv[1]))
a = dict(l.split() for l in open(sys.argv[2]))
d = {p: int(a[p]) - int(b[p]) for p in b}
tot = sum(d.values()) or 1
for p in sorted(d):
    bar = "#" * round(40 * d[p] / tot)
    print(f"  {p}  {d[p]/1e6:8.1f} MB  {100*d[p]/tot:5.1f}%  {bar}")
PY
  echo
}

{
  run "one elephant"            1  p01
  run "four flows, first roll"  4  p04a
  run "four flows, second roll" 4  p04b
  run "sixteen flows"           16 p16
} | tee "${OUT}/ladder.txt"
rm -f "${OUT}/.before" "${OUT}/.after"
echo "Evidence written to ${OUT}/"
