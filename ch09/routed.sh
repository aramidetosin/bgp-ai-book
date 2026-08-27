#!/usr/bin/env bash
# Chapter 9, design B: the routed host. host01 runs FRR, speaks eBGP
# unnumbered to both ToRs with the shared host ASN, advertises its
# service loopback, and the ToRs enforce the book's first import filter.
# Applies the design to the regenerated base as recorded steps, records
# the filter, the multipath-relax ladder (host, then fabric), and the
# mid-ping NIC pull with a capture running. Evidence under audits/routed/.
set -uo pipefail

LAB=bgpbook-ch09
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
OUT=audits/routed
mkdir -p "${OUT}"

sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== Step 1: the ToR side, session plus filter, both leafs ==="
for i in 1 2; do
  dev=leaf0${i}
  for try in 1 2 3; do
    sw ${dev} "nv set router policy prefix-list HOSTS-IN rule 10 action permit && \
      nv set router policy prefix-list HOSTS-IN rule 10 match 172.16.101.0/24 min-prefix-len 32 && \
      nv set router policy prefix-list HOSTS-IN rule 10 match 172.16.101.0/24 max-prefix-len 32 && \
      nv set router policy route-map RM-HOSTS-IN rule 10 action permit && \
      nv set router policy route-map RM-HOSTS-IN rule 10 match type ipv4 && \
      nv set router policy route-map RM-HOSTS-IN rule 10 match ip-prefix-list HOSTS-IN && \
      nv set vrf default router bgp neighbor swp1 remote-as external && \
      nv set vrf default router bgp neighbor swp1 type unnumbered && \
      nv set vrf default router bgp neighbor swp1 address-family ipv4-unicast policy inbound route-map RM-HOSTS-IN && \
      nv set vrf default router bgp neighbor swp1 address-family ipv4-unicast prefix-limits inbound maximum 5 && \
      nv set vrf default router bgp neighbor swp1 address-family ipv4-unicast default-route-origination enable on && \
      nv set vrf default router bgp neighbor swp1 address-family ipv4-unicast soft-reconfiguration on && \
      nv config apply -y" >/dev/null
    got=$(sw ${dev} "nv config show -o commands | grep -c 'HOSTS-IN\|neighbor swp1'")
    [ "${got}" = "12" ] && break
    sw ${dev} "nv config detach" >/dev/null; sleep 5
  done
  echo "  ${dev}: swp1 session, import = host /32s only, prefix limit 5, default out (${got}/12 lines)"
done

echo "=== Step 2: host01 becomes a router (FRR, shared host ASN 65500) ==="
${D}-host01 sh -c "ip addr add 172.16.101.1/32 dev lo 2>/dev/null; \
  ip addr add 10.66.66.1/24 dev lo 2>/dev/null; \
  ip route del default 2>/dev/null; \
  cat > /etc/frr/frr.conf <<'EOF'
frr defaults datacenter
hostname host01
!
router bgp 65500
 bgp router-id 172.16.101.1
 neighbor eth1 interface remote-as external
 neighbor eth2 interface remote-as external
 !
 address-family ipv4 unicast
  redistribute connected
 exit-address-family
!
EOF
  vtysh -f /etc/frr/frr.conf >/dev/null 2>&1"
sleep 20

{
  echo "=== The sessions, from both sides ==="
  echo "--- host01 ---"
  ${D}-host01 vtysh -c "show bgp summary" | tail -8
  echo "--- leaf01 ---"
  sw leaf01 "sudo vtysh -c 'show bgp summary' | tail -8"
} | tee "${OUT}/sessions.txt"

{
  echo "=== The filter, doing its job on leaf01 ==="
  echo "--- what host01 offered (received-routes) ---"
  sw leaf01 "sudo vtysh -c 'show ip bgp neighbors swp1 received-routes' | tail -16"
  echo "--- what leaf01 accepted (routes) ---"
  sw leaf01 "sudo vtysh -c 'show ip bgp neighbors swp1 routes' | tail -8"
} | tee "${OUT}/filter.txt"

{
  echo "=== The multipath ladder: relax, host first, then fabric ==="
  ${D}-host01 vtysh -c "conf t" -c "router bgp 65500" -c "no bgp bestpath as-path multipath-relax" >/dev/null 2>&1
  sleep 5
  echo "--- host01's default, before relax (two ToRs, two ASNs, one path) ---"
  ${D}-host01 ip route show default
  echo "--- host01: bestpath as-path multipath-relax ---"
  ${D}-host01 vtysh -c "conf t" -c "router bgp 65500" -c "bgp bestpath as-path multipath-relax" >/dev/null 2>&1
  sleep 5
  ${D}-host01 ip route show default
  echo
  echo "--- spine01's route to the host loopback, before fabric relax ---"
  sw spine01 "ip route show 172.16.101.1/32; sudo vtysh -c 'show ip bgp 172.16.101.1/32' | grep -E 'Paths|65'"
  echo "--- applying multipath relax fabric-wide ---"
  for dev in leaf01 leaf02 leaf03 spine01 spine02; do
    sw ${dev} "nv set vrf default router bgp path-selection multipath aspath-ignore on && nv config apply -y" >/dev/null
  done
  sleep 12
  echo "--- spine01 after ---"
  sw spine01 "r=\$(ip route show 172.16.101.1/32); echo \"\$r\"; id=\$(echo \$r | sed -n 's/.*nhid \([0-9]*\).*/\1/p'); [ -n \"\$id\" ] && ip nexthop show id \$id"
  echo "--- leaf03 after ---"
  sw leaf03 "r=\$(ip route show 172.16.101.1/32); echo \"\$r\"; id=\$(echo \$r | sed -n 's/.*nhid \([0-9]*\).*/\1/p'); [ -n \"\$id\" ] && ip nexthop show id \$id"
  echo
  echo "--- and the chapter 8 verdict, on the host itself ---"
  ${D}-host01 ip route get 172.16.3.11 from 172.16.101.1 | head -1
} | tee "${OUT}/relax_ladder.txt"

echo
echo "=== The NIC pull, mid-ping, with the wire recorded ==="
{
  ${D}-host01 sh -c "tcpdump -i eth2 -w /tmp/pull.pcap 'tcp port 179 or icmp' >/dev/null 2>&1 &"
  ${D}-server03 sh -c "ping -i 0.2 -c 100 172.16.101.1 > /tmp/pull_ping.txt 2>&1" &
  PING_PID=$!
  sleep 5
  echo "--- pulling host01 eth1 at packet ~25 (default timers, no BFD yet) ---"
  ${D}-host01 ip link set eth1 down
  wait ${PING_PID}
  ${D}-server03 tail -3 /tmp/pull_ping.txt
  ${D}-host01 sh -c "pkill tcpdump; sleep 1; tcpdump -n -r /tmp/pull.pcap 2>/dev/null | head -6; echo ...; tcpdump -n -r /tmp/pull.pcap 2>/dev/null | grep ': BGP' | grep -v 'length 19' | head -3" 2>/dev/null
  echo "--- restoring eth1 ---"
  ${D}-host01 ip link set eth1 up
  sleep 15
  ${D}-host01 vtysh -c "show bgp summary" | tail -4
} | tee "${OUT}/nic_pull_default.txt"
echo "Evidence written to ${OUT}/"
