#!/usr/bin/env bash
# Chapter 9 break-fix: the asymmetric return path blackhole. The host
# carries a static default via eth1's link-local gateway instead of
# learning defaults over BGP; leaf01's port then goes down inside the
# switch, which the emulated link never reports to the host's NIC. The
# fabric fails over inbound, the host keeps sending into the dead link
# outbound, and every conversation blackholes while every interface
# shows UP. Run on the routed design. Evidence under audits/break9a/.
set -uo pipefail

LAB=bgpbook-ch09
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
OUT=audits/break9a
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== Setting the trap: the advertise-only host ==="
# The legacy pattern, faithfully reproduced: BGP is used only to advertise
# the loopback; every received route is filtered, and reachability rests
# on a static default pointing at one uplink's gateway.
LL=$(${D}-host01 sh -c "ip -6 neigh show dev eth1 | awk '/^fe80/{print \$1; exit}'")
${D}-host01 vtysh -c "conf t" \
  -c "route-map BLOCK-IN deny 10" \
  -c "router bgp 65500" \
  -c "address-family ipv4 unicast" \
  -c "neighbor eth1 route-map BLOCK-IN in" \
  -c "neighbor eth2 route-map BLOCK-IN in" >/dev/null 2>&1
${D}-host01 vtysh -c "clear ip bgp *" >/dev/null 2>&1
sleep 12
${D}-host01 ip route replace default via inet6 ${LL} dev eth1
${D}-host01 ping -c 2 -W 2 172.16.3.11 >/dev/null 2>&1 && echo "  baseline: host01 -> server03 works via the static default"

echo "=== The failure: leaf01's swp1 goes down inside the switch ==="
sw leaf01 "nv set interface swp1 link state down && nv config apply -y" >/dev/null
sleep 15

{
  echo "=== The symptoms ==="
  echo "--- host01 -> server03 ---"
  ${D}-host01 sh -c "ping -c 5 -W 1 172.16.3.11 2>&1 | tail -2"
  echo "--- server03 -> host01's loopback ---"
  ${D}-server03 sh -c "ping -c 5 -W 1 172.16.101.1 2>&1 | tail -2"
  echo
  echo "=== The investigation ==="
  echo "--- the NIC that looks healthy ---"
  ${D}-host01 sh -c "ip link show eth1 | head -1"
  echo "--- the sessions that tell the truth ---"
  ${D}-host01 vtysh -c "show bgp summary" | tail -5
  echo "--- the verdict: where outbound packets actually go ---"
  ${D}-host01 ip route get 172.16.3.11 2>&1 | head -1
  echo "--- what the fabric still knows (leaf02 keeps the /32) ---"
  sw leaf02 "ip route show 172.16.101.1/32"
} | tee "${OUT}/evidence.txt"
echo
echo "break-9a armed and recorded. make heal-9a undoes it."
