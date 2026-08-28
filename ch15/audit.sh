#!/usr/bin/env bash
# Chapter 15 audit: both sites' sessions, the WAN session, the contract,
# the anycast VIP preferring local at each border, cross-site reachability.
source "$(dirname "$0")/lib.sh"
OUT=${OUT:-audits/ch15_audit}; mkdir -p "$OUT"
{
echo "=== BGP sessions (each device) ==="
for n in sa-spine sa-leaf sa-border sb-spine sb-leaf sb-border; do
  est=$(vt "$n" "show bgp summary" | grep -cE "Established|:.*[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9]+ +[0-9:]+ +[0-9]+")
  printf "  %-10s sessions up: %s\n" "$n" "$(vt "$n" "show bgp summary json" | grep -o '"state":"Established"' | wc -l)"
done
echo "=== The WAN session (numbered eBGP, sa-border <-> sb-border) ==="
vt sa-border "show bgp summary" | grep -E "10.255.0.1" | sed 's/^/  /'
echo "=== Anycast VIP prefers LOCAL at each border (healthy) ==="
echo -n "  sa-border best AS-path: "; vt sa-border "show ip bgp 100.64.0.1/32" | grep -A1 "best" | grep -E "65" | head -1
echo -n "  sb-border best AS-path: "; vt sb-border "show ip bgp 100.64.0.1/32" | grep -A1 "best" | grep -E "65" | head -1
echo "=== Contract holds: neither backend crosses the WAN ==="
echo -n "  sa-border sees site B backend 10.99.2.0/24: "; vt sa-border "show ip bgp 10.99.2.0/24" | grep -qE "Network not" && echo "NO (correct)" || echo "YES (leak!)"
echo -n "  sb-border sees site A backend 10.99.1.0/24: "; vt sb-border "show ip bgp 10.99.1.0/24" | grep -qE "Network not" && echo "NO (correct)" || echo "YES (leak!)"
echo "=== Cross-site reachability: site A server -> site B server (over the WAN) ==="
docker exec clab-${LAB}-sa-srv ping -c 3 -i 0.3 172.17.1.11 2>/dev/null | grep -E "packet loss|rtt" | sed 's/^/  /'
} | tee "$OUT/summary.txt"
