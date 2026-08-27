#!/usr/bin/env bash
# Chapter 12: configure the provider router and the internal service
# host (both FRR containers). The provider bridges the outside segment
# across both firewalls' outside ports, originates a default, and
# filters its customer to exactly the public /32.
set -uo pipefail

LAB=bgpbook-ch12
D="docker exec clab-${LAB}"

echo "=== upstream01: the provider ==="
${D}-upstream01 sh -c "ip link add br0 type bridge 2>/dev/null; \
  ip link set eth1 master br0; ip link set eth2 master br0; \
  ip link set eth1 up; ip link set eth2 up; ip link set br0 up; \
  ip addr add 203.0.113.1/31 dev br0 2>/dev/null; \
  ip addr add 198.51.100.1/24 dev eth3 2>/dev/null; ip link set eth3 up; \
  cat > /etc/frr/frr.conf <<'EOF'
frr defaults datacenter
hostname upstream01
!
ip route 172.31.1.0/31 203.0.113.0
!
ip prefix-list CUSTOMER-IN seq 10 permit 203.0.113.100/32
!
route-map RM-CUSTOMER-IN permit 10
 match ip address prefix-list CUSTOMER-IN
!
router bgp 64900
 bgp router-id 203.0.113.1
 neighbor 172.31.1.0 remote-as external
 neighbor 172.31.1.0 ebgp-multihop 2
 neighbor 172.31.1.0 passive
 neighbor 172.31.1.0 update-source br0
 !
 address-family ipv4 unicast
  redistribute connected
  neighbor 172.31.1.0 default-originate
  neighbor 172.31.1.0 route-map RM-CUSTOMER-IN in
  neighbor 172.31.1.0 soft-reconfiguration inbound
 exit-address-family
!
EOF
  vtysh -f /etc/frr/frr.conf >/dev/null 2>&1"
echo "  br0 bridges both firewalls' outside ports; default originated; customer filtered"

echo "=== intserver01: the internal service host (chapter 9's pattern) ==="
${D}-intserver01 sh -c "ip addr add 172.16.1.11/24 dev eth1 2>/dev/null; \
  ip addr add 172.16.200.1/32 dev lo 2>/dev/null; \
  ip route del default 2>/dev/null; \
  mkdir -p /www && printf 'bgpbook inference endpoint\n' > /www/index.html && \
  (pgrep -x httpd >/dev/null || httpd -p 80 -h /www); \
  cat > /etc/frr/frr.conf <<'EOF'
frr defaults datacenter
hostname intserver01
!
router bgp 65510
 bgp router-id 172.16.200.1
 neighbor eth1 interface remote-as external
 !
 address-family ipv4 unicast
  redistribute connected
 exit-address-family
!
EOF
  vtysh -f /etc/frr/frr.conf >/dev/null 2>&1"
echo "  VIP 172.16.200.1/32 on the loopback, advertised to leaf01, web served"
