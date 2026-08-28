#!/usr/bin/env bash
source "$(dirname "$0")/lib.sh"
heal_break sa-border "$SA_PEER"; sleep 6
echo "=== healed: VIP best path back to local (shorter AS-path, default local-pref) ==="
vt sa-border "show ip bgp 100.64.0.1/32" | grep -E "65100 65101|65611|localpref|best" | sed 's/^/  /'
sw sa-border "ping -c 3 -i 0.3 100.64.0.1" | grep -E "rtt" | sed 's/^/  /'
