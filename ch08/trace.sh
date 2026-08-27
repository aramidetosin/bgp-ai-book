#!/usr/bin/env bash
# Chapter 8 end-to-end trace: the routes with all their next hops, the
# hash policy, and a spread of traceroutes showing per-flow path choice.
# Evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch08
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
TS=$(date +%Y%m%d)
OUT=audits/e2e_trace_ch08_${TS}
mkdir -p "${OUT}"

{
  echo "=== leaf01: the four-way fan toward server02's subnet ==="
  ${SSH} cumulus@clab-${LAB}-leaf01 "sudo vtysh -c 'show ip route 172.16.2.0/24'" 2>/dev/null
  echo "--- and the next-hop group the kernel FIB installs ---"
  ${SSH} cumulus@clab-${LAB}-leaf01 "ip route show 172.16.2.0/24; ip nexthop show" 2>/dev/null

  echo
  echo "=== leaf02: the two-way fan toward server01's subnet ==="
  ${SSH} cumulus@clab-${LAB}-leaf02 "sudo vtysh -c 'show ip route 172.16.1.0/24'" 2>/dev/null
  echo "--- and the next-hop group the kernel FIB installs ---"
  ${SSH} cumulus@clab-${LAB}-leaf02 "ip route show 172.16.1.0/24; ip nexthop show" 2>/dev/null

  echo
  echo "=== what the kernel hashes on ==="
  echo "leaf01 fib_multipath_hash_policy = $(${SSH} cumulus@clab-${LAB}-leaf01 'cat /proc/sys/net/ipv4/fib_multipath_hash_policy' 2>/dev/null)"

  echo
  echo "=== six traceroutes, server01 -> server02, middle hop ==="
  for i in 1 2 3 4 5 6; do
    ${D}-server01 traceroute -n -q 1 -m 3 172.16.2.11 2>/dev/null | awk -v i=$i 'NR==3 {print "run " i ": " $2}'
  done
} | tee "${OUT}/TRACE_RAW.txt"
echo "Trace written to ${OUT}/"
