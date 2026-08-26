#!/usr/bin/env bash
# Chapter 4 traces: one journey per network, the node's split routing view,
# and the out-of-band survival demo. Writes raw evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch04
D="docker exec clab-${LAB}"
OUT=audits/e2e_trace_ch04_$(date +%Y%m%d)
mkdir -p "${OUT}/raw"

run() { echo "\$ $2" > "${OUT}/raw/$1"; eval "$2" >> "${OUT}/raw/$1" 2>&1; }

# One journey per network
run frontend_trace.txt "${D}-client traceroute -n -m 4 172.16.10.11"
run backend_ping.txt   "${D}-node ping -c 3 -I 172.31.1.11 172.31.1.12"
run storage_trace.txt  "${D}-node traceroute -n -m 4 172.30.2.12"
run storage_fetch.txt  "${D}-node sh -c \"curl -s -o /dev/null -w 'fetched at %{speed_download} bytes/s over %{time_total}s\n' http://172.30.2.12/dataset.bin\""
run oob_ping.txt       "${D}-oob-mgmt ping -c 3 10.99.0.11"

# The node's split view of the world
run node_addr.txt      "${D}-node sh -c 'ip -br addr show eth1; ip -br addr show eth2; ip -br addr show eth3; ip -br addr show eth4'"
run node_routes.txt    "${D}-node ip route"
run node_vrf_routes.txt "${D}-node ip route show vrf mgmt"
run node_vrf_list.txt  "${D}-node ip vrf show"

# The survival demo: frontend, backend, and storage die; the BMC answers.
${D}-node ip link set eth1 down
${D}-node ip link set eth2 down
${D}-node ip link set eth3 down
run blackout_curl.txt  "${D}-client curl -s -o /dev/null -w 'frontend during blackout: %{http_code}\n' --max-time 4 http://172.16.10.11/ ; echo exit \$?"
run blackout_oob.txt   "${D}-oob-mgmt ping -c 3 10.99.0.11"
${D}-node ip link set eth1 up
${D}-node ip link set eth2 up
${D}-node ip link set eth3 up
${D}-node ip route replace default via 172.16.10.1
${D}-node ip route replace 172.30.2.0/24 via 172.30.1.1

echo "Raw trace outputs in ${OUT}/raw/. Write TRACE.md from them; never from memory."
