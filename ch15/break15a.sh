#!/usr/bin/env bash
# Chapter 15 break-15a: a blanket local-preference 200 on sa-border's WAN
# inbound (applied too broadly) sends the anycast VIP the long way across
# the WAN even though a local copy exists one spine away.
source "$(dirname "$0")/lib.sh"
OUT=${OUT:-audits/break15a}; mkdir -p "$OUT"
netem_on 20 >/dev/null 2>&1
apply_break sa-border "$SA_PEER"; sleep 6
{
echo "=== break-15a: VIP best path at sa-border (now the WAN copy, localpref 200) ==="
vt sa-border "show ip bgp 100.64.0.1/32" | grep -E "65100 65101|65611 65600 65601|localpref|best" | sed 's/^/  /'
echo "=== VIP RTT from sa-border: hairpinned across the WAN ==="
sw sa-border "ping -c 4 -i 0.3 100.64.0.1" | grep -E "rtt|packet loss" | sed 's/^/  /'
echo "The local route still exists (AS-path 65100 65101); local-pref 200 overrode it."
} | tee "$OUT/evidence.txt"
