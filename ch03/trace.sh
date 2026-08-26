#!/usr/bin/env bash
# Chapter 3 end-to-end traces: one journey per network, plus the wire proof
# that neither fabric carries the other's traffic. Writes raw evidence
# under audits/.
set -uo pipefail

LAB=bgpbook-ch03
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
OUT=audits/e2e_trace_ch03_$(date +%Y%m%d)
mkdir -p "${OUT}/raw"

run() { echo "\$ $2" > "${OUT}/raw/$1"; eval "$2" >> "${OUT}/raw/$1" 2>&1; }

# Journey 1: the frontend, routed (client crosses fe-leaf's SVIs)
run frontend_trace.txt "${D}-client traceroute -n -m 4 172.16.10.11"
run frontend_ping.txt  "${D}-client ping -c 3 172.16.10.11"

# Journey 2: the backend, flat (nodes are L2-adjacent on the rail)
run backend_ping.txt   "${D}-nodea ping -c 3 -I 172.31.1.11 172.31.1.12"
run backend_neigh.txt  "${D}-nodea ip neigh show 172.31.1.12"

# The node's split view of the world
run nodea_addr.txt     "${D}-nodea sh -c 'ip -br addr show eth1; ip -br addr show eth2'"
run nodea_routes.txt   "${D}-nodea ip route"
run client_no_backend.txt "${D}-client ip route get 172.31.1.11"

# Wire proof: run both workloads, capture both fabrics simultaneously.
${D}-nodea sh -c "pgrep iperf3 >/dev/null || nohup iperf3 -s -B 172.31.1.11 >/dev/null 2>&1 &"
sleep 1
${SSH} cumulus@clab-${LAB}-fe-leaf "sudo timeout 12 tcpdump -i swp1 -w /tmp/fe.pcap ip" >/dev/null 2>&1 &
${SSH} cumulus@clab-${LAB}-be-leaf "sudo timeout 12 tcpdump -i swp1 -w /tmp/be.pcap ip" >/dev/null 2>&1 &
sleep 2
${D}-nodeb iperf3 -c 172.31.1.11 -B 172.31.1.12 -t 6 >/dev/null 2>&1 &
for i in 1 2 3 4 5; do ${D}-client curl -s -o /dev/null http://172.16.10.11/; done
wait
run fe_wire_summary.txt "${SSH} cumulus@clab-${LAB}-fe-leaf \"sudo tcpdump -r /tmp/fe.pcap -n 2>/dev/null | awk '{print \\\$3, \\\$4, \\\$5}' | sort | uniq -c | sort -rn | head -8\""
run be_wire_summary.txt "${SSH} cumulus@clab-${LAB}-be-leaf \"sudo tcpdump -r /tmp/be.pcap -n 2>/dev/null | awk '{print \\\$3, \\\$4, \\\$5}' | sort | uniq -c | sort -rn | head -8\""
run fe_wire_iperf_count.txt "${SSH} cumulus@clab-${LAB}-fe-leaf \"sudo tcpdump -r /tmp/fe.pcap -n 2>/dev/null | grep -cE ' 172\\.31\\.1\\.'\""
run be_wire_http_count.txt  "${SSH} cumulus@clab-${LAB}-be-leaf \"sudo tcpdump -r /tmp/be.pcap -n 2>/dev/null | grep -cE ' 172\\.16\\.'\""

echo "Raw trace outputs in ${OUT}/raw/. Write TRACE.md from them; never from memory."
