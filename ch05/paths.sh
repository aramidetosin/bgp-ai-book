#!/usr/bin/env bash
# Chapter 5's traffic-path walk: how backend traffic moves intra-rail and
# inter-rail, demonstrated from node1. Records every command and output.
set -uo pipefail
LAB=bgpbook-ch05
D="docker exec clab-${LAB}-node1"
OUT=${1:-audits/e2e_trace_ch05_20260826/raw/node1_paths.txt}
mkdir -p "$(dirname "${OUT}")"
: > "${OUT}"

say() { echo "$1" | tee -a "${OUT}"; }
run() { echo "\$ $1" >> "${OUT}"; ${D} sh -c "$1" >> "${OUT}" 2>&1; echo >> "${OUT}"; }

say "== 1. Intra-rail: node1 to node2 on rail 1 (same rail, one switch) =="
run "traceroute -n -q 1 -w 2 172.31.1.12"

say "== 2. The node's own cross-rail shortcut (what PXN does with NVLink) =="
run "ip route get 172.31.2.12"

say "== 3. Force the fabric path: host route via rail1's gateway =="
run "ip route add 10.5.0.0/24 via 172.31.1.1 dev eth1"
run "ip route add 172.31.2.12/32 via 172.31.1.1 dev eth1"
run "ip route get 172.31.2.12"

say "== 4. Inter-rail through the fabric: leaf, spine, destination =="
run "traceroute -n -q 2 -w 2 172.31.2.12"

say "== 5. Cleanup =="
run "ip route del 172.31.2.12/32 via 172.31.1.1 dev eth1"
run "ip route del 10.5.0.0/24 via 172.31.1.1 dev eth1"

echo "Recorded to ${OUT}"
