#!/usr/bin/env bash
# Chapter 16 audit: sessions up, BFD state, the mesh fully connected.
source "$(dirname "$0")/lib.sh"
OUT=${OUT:-audits/ch16_audit}; mkdir -p "$OUT"
heal >/dev/null 2>&1   # both uplinks up, sessions reconverged
{
echo "=== BGP sessions (each device, Established count) ==="
for n in leaf01 leaf02 leaf03 leaf04 spine01 spine02; do
  c=$(vt "$n" "show bgp summary json" | grep -o '"state":"Established"' | wc -l)
  printf "  %-8s established: %s\n" "$n" "$c"
done
echo "=== BFD state on leaf01 (NVUE) ==="
sw leaf01 "nv show vrf default router bgp neighbor swp2 bfd" 2>/dev/null | grep -iE "enable|state|detect|interval" | head -4 | sed 's/^/  /'
echo "=== the heartbeat mesh is fully connected ==="
ok=0; tot=0
for a in 01 02 03 04; do for b in 1 2 3 4; do
  [ "$a" = "0$b" ] && continue; tot=$((tot+1))
  dex server$a ping -c1 -W1 172.16.$b.11 >/dev/null 2>&1 && ok=$((ok+1))
done; done
echo "  $ok/$tot rank-to-rank paths healthy"
} | tee "$OUT/summary.txt"
