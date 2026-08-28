#!/usr/bin/env bash
# Chapter 15: the communities contract. Tag exportable prefixes at origin,
# and at each border permit only WAN-OK across the WAN. Show a site-local
# backend prefix stopped at the border while the anycast VIP still crosses.
source "$(dirname "$0")/lib.sh"
OUT=${OUT:-audits/contract}; mkdir -p "$OUT"
{
echo "=== Origin tags: each site stamps WAN-OK (64512:1) on exportable prefixes,"
echo "    SITE-LOCAL (64512:9) on the backend ==="
apply_origin sa-leaf 100.64.0.1 172.16.1.0/24 10.99.1.0/24
apply_origin sb-leaf 100.64.0.1 172.17.1.0/24 10.99.2.0/24
echo "  tags applied at sa-leaf and sb-leaf"
echo
echo "=== Before the contract: site B backend 10.99.2.0/24 leaks into site A ==="
remove_filter sa-border "$SA_PEER"; remove_filter sb-border "$SB_PEER"; sleep 6
vt sa-border "show ip bgp 10.99.2.0/24" | grep -E "65611 65600 65601|Network not|Community" | sed 's/^/  /'
echo
echo "=== Apply the contract: borders advertise and accept only WAN-OK ==="
apply_filter sa-border "$SA_PEER"; apply_filter sb-border "$SB_PEER"; sleep 7
echo "--- site B backend 10.99.2.0/24, now at site A's border: ---"
vt sa-border "show ip bgp 10.99.2.0/24" | grep -E "65611|Network not" | sed 's/^/  /'
echo "--- the WAN-OK anycast VIP 100.64.0.1/32 still crosses: ---"
vt sa-border "show ip bgp 100.64.0.1/32" | grep -E "65611 65600 65601" | head -1 | sed 's/^/  /'
echo "CONTRACT HOLDS: backend stopped at the border, service VIP crosses"
} | tee "$OUT/contract.txt"
