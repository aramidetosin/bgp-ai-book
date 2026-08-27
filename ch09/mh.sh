#!/usr/bin/env bash
# Chapter 9, design A: EVPN multihoming. The ToR pair presents one
# logical LACP partner to a bonded host01 through an Ethernet segment,
# with no peer link and no shared vendor state: the coordination rides
# the EVPN address family as type-1 and type-4 routes. Applies the
# design to the generated base as recorded steps, then records the
# evidence and the mid-ping NIC pull. Evidence under audits/mh/.
set -uo pipefail

LAB=bgpbook-ch09
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
OUT=audits/mh
mkdir -p "${OUT}"

sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== Step 1: the EVPN address family and multipath relax, fabric-wide ==="
for dev in leaf01 leaf02 leaf03 spine01 spine02; do
  nbrs=$(sw ${dev} "nv config show -o commands | grep 'neighbor swp' | grep remote-as | awk '{print \$8}'" | sort -u)
  want=1
  cmds="nv set vrf default router bgp path-selection multipath aspath-ignore on && nv set vrf default router bgp address-family l2vpn-evpn enable on && nv set evpn enable on"
  for n in ${nbrs}; do
    want=$((want + 1))
    cmds="${cmds} && nv set vrf default router bgp neighbor ${n} address-family l2vpn-evpn enable on"
  done
  for try in 1 2 3; do
    sw ${dev} "${cmds}" >/dev/null
    sw ${dev} "nv config apply -y" >/dev/null
    got=$(sw ${dev} "nv config show -o commands | grep -c l2vpn")
    [ "${got}" = "${want}" ] && break
    sw ${dev} "nv config detach" >/dev/null
    sleep 5
  done
  echo "  ${dev}: EVPN address family on (${got}/${want} lines), multipath relax on"
done

echo "=== Step 2: the pair becomes an Ethernet segment ==="
for i in 1 2; do
  dev=leaf0${i}
  sw ${dev} "nv set nve vxlan enable on && \
    nv set nve vxlan source address 10.0.0.${i} && \
    nv set system global anycast-mac 44:38:39:ff:00:07 && \
    nv set evpn multihoming enable on && \
    nv set evpn multihoming segment mac-address 44:38:39:be:ef:aa && \
    nv set interface bond0 bond member swp1 && \
    nv set interface bond0 evpn multihoming segment enable on && \
    nv set interface bond0 evpn multihoming segment local-id 1 && \
    nv set interface bond0 bridge domain br_default access 100 && \
    nv set bridge domain br_default vlan 100 vni 10100 && \
    nv set interface vlan100 ip address 172.16.10.1/24 && \
    nv config apply -y" >/dev/null
  echo "  ${dev}: bond0(swp1) in segment be:ef:aa local-id 1, vlan 100, SVI 172.16.10.1"
done

echo "=== Step 2b: restart switchd on the pair (the VX bond-member carrier quirk) ==="
for i in 1 2; do
  sw leaf0${i} "sudo systemctl restart switchd" >/dev/null
  echo "  leaf0${i}: switchd restarted, port carrier restored"
done
sleep 30

echo "=== Step 3: host01 bonds two NICs, believing in one switch ==="
${D}-host01 sh -c "ip link set eth1 down; ip link set eth2 down; \
  ip link add bond0 type bond mode 802.3ad miimon 100 lacp_rate 1 2>/dev/null; \
  ip link set eth1 master bond0; ip link set eth2 master bond0; \
  ip link set eth1 up; ip link set eth2 up; ip link set bond0 up; \
  ip addr add 172.16.10.11/24 dev bond0 2>/dev/null; \
  ip route replace default via 172.16.10.1 dev bond0"
sleep 25

{
  echo "=== host01's view: one LACP partner (the lie, recorded) ==="
  ${D}-host01 sh -c "grep -A3 'Slave Interface' /proc/net/bonding/bond0 | grep -B1 -A3 . ; grep -i 'partner mac\|system mac' -A1 /proc/net/bonding/bond0" 2>/dev/null
  ${D}-host01 cat /proc/net/bonding/bond0 > "${OUT}/bond0_full.txt" 2>/dev/null
  echo
  echo "=== leaf01: the Ethernet segment and its designated forwarder ==="
  sw leaf01 "sudo vtysh -c 'show evpn es detail'"
  echo
  echo "=== leaf03: the segment's routes, learned like any other BGP routes ==="
  echo "--- type-4 (Ethernet segment) ---"
  sw leaf03 "sudo vtysh -c 'show bgp l2vpn evpn route type es' | head -30"
  echo "--- type-1 (Ethernet auto-discovery) ---"
  sw leaf03 "sudo vtysh -c 'show bgp l2vpn evpn route type ead' | head -30"
  echo
  echo "=== Reachability: server03 -> host01 across the fabric ==="
  ${D}-server03 ping -c 3 -W 2 172.16.10.11 | tail -2
} | tee "${OUT}/mh_state.txt"

echo
echo "=== The NIC pull, mid-ping, both directions at once ==="
{
  ${D}-server03 sh -c "ping -i 0.2 -c 100 172.16.10.11 > /tmp/pull_in.txt 2>&1" &
  IN_PID=$!
  ${D}-host01 sh -c "ping -i 0.2 -c 100 172.16.3.11 > /tmp/pull_out.txt 2>&1" &
  OUT_PID=$!
  sleep 5
  echo "--- pulling host01 eth1 at packet ~25 ---"
  ${D}-host01 ip link set eth1 down
  wait ${IN_PID} ${OUT_PID}
  echo "--- outbound during the pull (host01 -> server03: the bond's own repair) ---"
  ${D}-host01 sh -c "tail -2 /tmp/pull_out.txt | head -1"
  echo "--- inbound during the pull (server03 -> host01: the fabric's side) ---"
  ${D}-server03 sh -c "grep transmitted /tmp/pull_in.txt"
  echo "--- the segment after the pull (leaf01 now non-DF, peer still listed) ---"
  sw leaf01 "sudo vtysh -c 'show evpn es' | head -12"
  echo "--- restoring eth1 ---"
  ${D}-host01 ip link set eth1 up
} | tee "${OUT}/nic_pull.txt"
echo "Evidence written to ${OUT}/"
