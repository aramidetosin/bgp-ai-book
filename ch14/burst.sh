#!/usr/bin/env bash
# Chapter 14: the synchronized checkpoint burst. Every writer opens its
# stream to the array's VIP at the same instant while a low-rate control
# flow (a health probe) runs alongside. On the undersized, unprotected
# path the burst floods the array's shaped uplinks and the control flow
# suffers with it: that is the fate-sharing the chapter is about.
# Evidence under audits/burst/.
set -uo pipefail
LAB=bgpbook-ch14
D="docker exec clab-${LAB}"
VIP=172.16.202.1
OUT=audits/burst
mkdir -p "${OUT}"
DUR=${DUR:-10}

echo "=== The synchronized restore burst: the array fans out to 4 nodes at once ==="
# the control flow: a health probe to the array through the whole burst
${D}-writer01 sh -c "ping -i 0.2 -c $(( (DUR+4)*5 )) ${VIP} > /tmp/control.txt 2>&1" &
CTRL=$!
sleep 1
# the burst: every writer starts within the same instant
for w in 01 02 03 04; do
  ${D}-writer${w} sh -c "iperf3 -c ${VIP} -p $((5200 + 10#$w)) -R -t ${DUR} -J > /tmp/w${w}.json 2>/dev/null" &
done
wait
kill ${CTRL} 2>/dev/null; wait ${CTRL} 2>/dev/null

{
  echo "=== Per-writer throughput and the aggregate the array absorbed ==="
  total=0
  for w in 01 02 03 04; do
    bps=$(${D}-writer${w} sh -c "cat /tmp/w${w}.json" | python3 -c "import json,sys;print(int(json.load(sys.stdin)['end']['sum_received']['bits_per_second']))" 2>/dev/null || echo 0)
    retr=$(${D}-writer${w} sh -c "cat /tmp/w${w}.json" | python3 -c "import json,sys;print(json.load(sys.stdin)['end']['sum_sent'].get('retransmits','?'))" 2>/dev/null || echo ?)
    printf "  writer%s  %6.2f Gbit/s   retransmits %s\n" "${w}" "$(python3 -c "print(${bps}/1e9)")" "${retr}"
    total=$(python3 -c "print(${total}+${bps})")
  done
  printf "  aggregate absorbed: %6.2f Gbit/s (the array's two shaped uplinks are the ceiling)\n" "$(python3 -c "print(${total}/1e9)")"
  echo
  echo "=== The control flow, sharing the burst's fate ==="
  ${D}-writer01 grep -E "packet loss|rtt" /tmp/control.txt | head -2 | sed 's/^/  /'
} | tee "${OUT}/burst.txt"
echo "Evidence written to ${OUT}/"
