#!/usr/bin/env bash
# Chapter 1 end-to-end trace: server01 to server03, every hop verified on the box.
# Writes audits/e2e_trace_ch01_<date>/ with raw outputs; TRACE.md is written from
# these raw files. Convention follows ecloud-containerlab.
set -uo pipefail

LAB=bgpbook-ch01
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
OUT=audits/e2e_trace_ch01_$(date +%Y%m%d)
mkdir -p "${OUT}/raw"

run() { echo "\$ $2" > "${OUT}/raw/$1"; eval "$2" >> "${OUT}/raw/$1" 2>&1; }

# The trace itself, from the source host
run trace_3probe.txt      "docker exec clab-${LAB}-server01 traceroute -n -m 6 172.16.3.10"
run ping_ttl.txt          "docker exec clab-${LAB}-server01 ping -c 3 172.16.3.10"

# Hop 1: leaf01. BGP view, RIB view, FIB view of the destination subnet.
run leaf01_bgp.txt        "${SSH} cumulus@clab-${LAB}-leaf01 \"sudo vtysh -c 'show bgp ipv4 unicast 172.16.3.0/24'\""
run leaf01_rib.txt        "${SSH} cumulus@clab-${LAB}-leaf01 \"sudo vtysh -c 'show ip route 172.16.3.0/24'\""
run leaf01_fib.txt        "${SSH} cumulus@clab-${LAB}-leaf01 \"ip route show 172.16.3.0/24; ip nexthop show\""

# Hop 2: a spine. Its route to the destination subnet (single path: the leaf owns it).
run spine01_rib.txt       "${SSH} cumulus@clab-${LAB}-spine01 \"sudo vtysh -c 'show ip route 172.16.3.0/24'\""
run spine02_rib.txt       "${SSH} cumulus@clab-${LAB}-spine02 \"sudo vtysh -c 'show ip route 172.16.3.0/24'\""

# Hop 3: leaf03. The destination subnet is connected; the host is a neighbor entry.
run leaf03_connected.txt  "${SSH} cumulus@clab-${LAB}-leaf03 \"sudo vtysh -c 'show ip route 172.16.3.0/24'; ip neigh show 172.16.3.10\""

# Control plane: where leaf01's knowledge of 172.16.3.0/24 came from (AS path proof)
run leaf01_aspath.txt     "${SSH} cumulus@clab-${LAB}-leaf01 \"sudo vtysh -c 'show bgp ipv4 unicast 172.16.3.0/24 json'\""

# Versions, for the book's compatibility matrix
run versions.txt          "${SSH} cumulus@clab-${LAB}-leaf01 \"grep -E 'NAME=|VERSION_ID' /etc/os-release; sudo vtysh -c 'show version' | head -1\""

echo "Raw trace outputs in ${OUT}/raw/. Write TRACE.md from them; never from memory."
