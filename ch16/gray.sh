#!/usr/bin/env bash
# Chapter 16: a gray failure. A degrading link corrupts a fraction of
# frames but keeps carrier and keeps the BGP/BFD keepalives flowing, so
# routing sees nothing wrong while the job quietly bleeds. "Reachability
# restored" and "job healthy" are different claims; this is the gap.
source "$(dirname "$0")/lib.sh"
OUT=${OUT:-audits/gray}; mkdir -p "$OUT"
heal >/dev/null 2>&1
LOSS=${LOSS:-20}
{
echo "=== Gray failure: ${LOSS}% frame loss on both leaf01 uplinks ==="
gray_on "$LOSS"; sleep 6
echo "--- the routing view (the dashboard stays green): ---"
vt leaf01 "show bgp summary" | grep -E "spine0[12]" | awk '{print "  "$1" Established, PfxRcd="$10}'
echo "--- the data plane (the job the dashboard cannot see): ---"
for s in 1 2; do
  loss=$(dex $SRC ping -c 60 -i 0.1 -W1 $DST_IP | ploss)
  printf "  window %s (6s): %s%% of steps stalled\n" "$s" "${loss:-100}"
done
gray_off
echo "BGP Established on every session, and one in five steps silently lost."
} | tee "$OUT/gray.txt"
