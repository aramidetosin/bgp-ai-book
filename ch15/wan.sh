#!/usr/bin/env bash
# Chapter 15: emulate the WAN with netem latency, then show the difference
# between a local path and one that crosses the WAN.
source "$(dirname "$0")/lib.sh"
OUT=${OUT:-audits/wan}; mkdir -p "$OUT"
MS=${MS:-20}
{
echo "=== Emulated WAN: ${MS} ms netem each way on the inter-border link ==="
netem_on "$MS"; sleep 2
echo "=== Across the WAN: sa-border -> site B server subnet 172.17.1.1 (~$((MS*2)) ms) ==="
sw sa-border "ping -c 4 -i 0.3 172.17.1.1" | grep -E "rtt|packet loss" | sed 's/^/  /'
echo "=== Local: sa-border -> the anycast VIP 100.64.0.1 (local site, sub-ms) ==="
sw sa-border "ping -c 4 -i 0.3 100.64.0.1" | grep -E "rtt|packet loss" | sed 's/^/  /'
echo "The WAN is far; the local service is near. break-15a confuses the two."
} | tee "$OUT/wan.txt"
