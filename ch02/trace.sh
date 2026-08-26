#!/usr/bin/env bash
# Chapter 2 end-to-end trace: r1's loopback to r3's loopback, both paths of
# the triangle verified on the box. Writes raw evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch02
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
OUT=audits/e2e_trace_ch02_$(date +%Y%m%d)
mkdir -p "${OUT}/raw"

run() { echo "\$ $2" > "${OUT}/raw/$1"; eval "$2" >> "${OUT}/raw/$1" 2>&1; }

run trace_r1_to_r3.txt "${SSH} cumulus@clab-${LAB}-r1 \"sudo traceroute -n -I -s 10.0.0.1 10.0.0.3\""
run ping_ttl.txt       "${SSH} cumulus@clab-${LAB}-r1 \"ping -c 3 -I 10.0.0.1 10.0.0.3\""
run r1_bgp_r3lo.txt    "${SSH} cumulus@clab-${LAB}-r1 \"sudo vtysh -c 'show bgp ipv4 unicast 10.0.0.3/32'\""
run r3_bgp_r1lo.txt    "${SSH} cumulus@clab-${LAB}-r3 \"sudo vtysh -c 'show bgp ipv4 unicast 10.0.0.1/32'\""
run r2_transit.txt     "${SSH} cumulus@clab-${LAB}-r2 \"sudo vtysh -c 'show ip route 10.0.0.1/32'; sudo vtysh -c 'show ip route 10.0.0.3/32'\""
run versions.txt       "${SSH} cumulus@clab-${LAB}-r1 \"grep -E 'NAME=|VERSION_ID' /etc/os-release; sudo vtysh -c 'show version' | head -1\""

echo "Raw trace outputs in ${OUT}/raw/. Write TRACE.md from them; never from memory."
