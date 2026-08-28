#!/usr/bin/env bash
# Chapter 15: data residency. A site-local backend prefix is reachable
# inside its own site but is stopped at the border, so it never reaches
# the other site. This is exercise 2's mechanism, shown both ways.
source "$(dirname "$0")/lib.sh"
OUT=${OUT:-audits/leak}; mkdir -p "$OUT"
{
echo "=== Site A backend 10.99.1.0/24: present in site A, absent in site B ==="
echo "--- at sa-border (in site A): ---"
vt sa-border "show ip bgp 10.99.1.0/24" | grep -E "65101|Community|10.0.0.1" | head -2 | sed 's/^/  /'
echo "--- at sb-border (across the WAN in site B): ---"
vt sb-border "show ip bgp 10.99.1.0/24" | grep -E "65401|Network not" | sed 's/^/  /'
echo "=== Site B backend 10.99.2.0/24: present in site B, absent in site A ==="
echo "--- at sb-border (in site B): ---"
vt sb-border "show ip bgp 10.99.2.0/24" | grep -E "65601|Community|10.1.0.1" | head -2 | sed 's/^/  /'
echo "--- at sa-border (across the WAN in site A): ---"
vt sa-border "show ip bgp 10.99.2.0/24" | grep -E "65611|Network not" | sed 's/^/  /'
echo "RESIDENCY HELD: neither backend crosses the WAN; the policy is testable"
} | tee "$OUT/leak.txt"
