#!/usr/bin/env bash
# Chapter 9, exercise 2's mechanism recorded: with connected
# redistribution, the loopback address's presence IS the advertisement.
# A health check that adds and removes the address controls the fabric.
# Evidence under audits/routed/conditional.txt.
set -uo pipefail

LAB=bgpbook-ch09
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
mkdir -p audits/routed
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

{
  echo "=== The health-check withdrawal: the address is the advertisement ==="
  echo "--- leaf01 before ---"
  sw leaf01 "ip route show 172.16.101.1/32"
  echo "--- the failing health check removes the address ---"
  echo "\$ ip addr del 172.16.101.1/32 dev lo"
  ${D}-host01 ip addr del 172.16.101.1/32 dev lo
  sleep 6
  echo "--- leaf01 after (no output: the route is gone) ---"
  sw leaf01 "ip route show 172.16.101.1/32"
  echo "--- recovery restores it ---"
  echo "\$ ip addr add 172.16.101.1/32 dev lo"
  ${D}-host01 ip addr add 172.16.101.1/32 dev lo
  sleep 6
  sw leaf01 "ip route show 172.16.101.1/32"
} | tee audits/routed/conditional.txt
