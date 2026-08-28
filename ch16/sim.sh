#!/usr/bin/env bash
# Chapter 16: the heartbeat mesh, healthy. All four ranks reach each
# other; a step is sub-millisecond and nothing stalls.
source "$(dirname "$0")/lib.sh"
OUT=${OUT:-audits/sim}; mkdir -p "$OUT"
{
echo "=== The heartbeat mesh, healthy: every rank reaches every rank ==="
for a in 01 02 03 04; do
  line="  server$a ->"
  for b in 1 2 3 4; do
    [ "$a" = "0$b" ] && continue
    r=$(dex server$a ping -c1 -W1 172.16.$b.11 | grep -oE "time=[0-9.]+" | cut -d= -f2)
    line="$line rank$b:${r:-DROP}ms"
  done
  echo "$line"
done
echo "A healthy step is the slowest of these, well under a millisecond."
} | tee "$OUT/sim.txt"
