#!/usr/bin/env bash
# Undo break9a.sh: defaults learned over BGP again from both ToRs, the
# static gone, leaf01's port back up.
set -uo pipefail

LAB=bgpbook-ch09
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

${D}-host01 vtysh -c "conf t" \
  -c "router bgp 65500" \
  -c "address-family ipv4 unicast" \
  -c "no neighbor eth1 route-map BLOCK-IN in" \
  -c "no neighbor eth2 route-map BLOCK-IN in" \
  -c "exit" -c "exit" \
  -c "no route-map BLOCK-IN deny 10" >/dev/null 2>&1
sw leaf01 "nv unset interface swp1 link state && nv config apply -y" >/dev/null
${D}-host01 ip route del default 2>/dev/null
${D}-host01 vtysh -c "clear ip bgp *" >/dev/null 2>&1
sleep 25
echo "--- host01's default now ---"
${D}-host01 ip route show default
${D}-host01 ping -c 2 -W 2 172.16.3.11 >/dev/null 2>&1 && echo "healed: host01 -> server03 works, learned routes only"
