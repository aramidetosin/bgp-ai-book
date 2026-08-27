#!/usr/bin/env bash
# Chapter 6 trace: the tuned underlay, seen from the boxes.
set -uo pipefail
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
OUT=audits/e2e_trace_ch06_$(date +%Y%m%d)
mkdir -p "${OUT}/raw"

run() { echo "\$ $2" > "${OUT}/raw/$1"; eval "$2" >> "${OUT}/raw/$1" 2>&1; }

run leaf04_summary.txt   "${SSH} cumulus@clab-${LAB}-leaf04 \"sudo vtysh -c 'show bgp summary'\""
run leaf04_timers.txt    "${SSH} cumulus@clab-${LAB}-leaf04 \"sudo vtysh -c 'show bgp neighbors swp2' | grep -E 'Hold time|keepalive|BFD|Last reset'\""
run leaf04_bfd.txt       "${SSH} cumulus@clab-${LAB}-leaf04 \"sudo vtysh -c 'show bfd peers brief'\""
run leaf04_gr.txt        "${SSH} cumulus@clab-${LAB}-leaf04 'nv show router bgp graceful-restart'"
run spine01_summary.txt  "${SSH} cumulus@clab-${LAB}-spine01 \"sudo vtysh -c 'show bgp summary'\""
run leaf01_routes.txt    "${SSH} cumulus@clab-${LAB}-leaf01 \"sudo vtysh -c 'show ip route bgp'\""
run server_trace.txt     "${D}-server02 traceroute -n -q 2 -w 2 172.16.1.11"
run verify.txt           "./verify_lldp.sh"

echo "Raw trace outputs in ${OUT}/raw/. Write TRACE.md from them; never from memory."
