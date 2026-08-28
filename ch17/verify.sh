#!/usr/bin/env bash
# Chapter 17: the generated fabric converges with no hand-configuration.
source "$(dirname "$0")/lib.sh"
echo "=== Every device's BGP, from a fabric no one configured by hand ==="
for n in leaf01 leaf02 leaf03 leaf04 spine01 spine02; do
  est=$(sw "$n" "vtysh -c 'show bgp summary json'" | grep -o '"state":"Established"' | wc -l)
  printf "  %-8s %s sessions Established\n" "$n" "$est"
done
echo "=== server01 -> server04 across the generated underlay ==="
docker exec clab-${LAB}-server01 ping -c 3 -i 0.3 172.16.4.11 2>/dev/null | grep -E "packet loss|rtt" | sed 's/^/  /'
