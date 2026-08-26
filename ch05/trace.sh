#!/usr/bin/env bash
# Chapter 5 trace: the generated fabric's shape, seen from the boxes.
set -uo pipefail
LAB=bgpbook-ch05
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
OUT=audits/e2e_trace_ch05_$(date +%Y%m%d)
mkdir -p "${OUT}/raw"

run() { echo "\$ $2" > "${OUT}/raw/$1"; eval "$2" >> "${OUT}/raw/$1" 2>&1; }

run rail1_summary.txt   "${SSH} cumulus@clab-${LAB}-rail1 \"sudo vtysh -c 'show bgp summary'\""
run spine1_summary.txt  "${SSH} cumulus@clab-${LAB}-spine1 \"sudo vtysh -c 'show bgp summary'\""
run spine1_routes.txt   "${SSH} cumulus@clab-${LAB}-spine1 \"sudo vtysh -c 'show ip route bgp'\""
run rail1_lldp.txt      "${SSH} cumulus@clab-${LAB}-rail1 \"sudo lldpctl -f keyvalue | grep -E 'chassis.name|port.descr'\""
run node1_addr.txt      "${D}-node1 sh -c 'ip -br addr show | grep eth'"
run rail1_ping.txt      "${D}-node1 ping -c 3 -I 172.31.1.11 172.31.1.12"
run verify.txt          "./verify_lldp.sh"

echo "Raw trace outputs in ${OUT}/raw/. Write TRACE.md from them; never from memory."
