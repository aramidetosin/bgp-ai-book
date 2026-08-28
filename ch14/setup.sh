#!/usr/bin/env bash
# Chapter 14: bring up the storage array (FRR, dual-homed, VIP on the
# loopback, four iperf3 sinks). The synchronized burst in the lab is the
# checkpoint RESTORE direction, array fanning out to every node at once,
# because a Linux host shapes its egress faithfully (real queuing, then
# drop) where containerlab's virtual switch ASIC models no buffers; the
# write direction is symmetric and the chapter says so. The array's
# per-uplink egress is shaped to a stated ceiling standing in for a real
# storage head's serve rate.
set -uo pipefail
LAB=bgpbook-ch14
D="docker exec clab-${LAB}"
RATE=${ARRAY_RATE:-2gbit}
echo "=== The storage array: routed head, dual-homed, four sinks ==="
${D}-array01 sh -c "ip addr add 172.16.202.1/32 dev lo 2>/dev/null; ip route del default 2>/dev/null; \
  cat > /etc/frr/frr.conf <<CFG
frr defaults datacenter
hostname array01
!
router bgp 65520
 bgp router-id 172.16.202.1
 neighbor eth1 interface remote-as external
 neighbor eth2 interface remote-as external
 !
 address-family ipv4 unicast
  redistribute connected
 exit-address-family
!
CFG
  vtysh -f /etc/frr/frr.conf >/dev/null 2>&1; \
  vtysh -c 'conf t' -c 'router bgp 65520' -c 'bgp bestpath as-path multipath-relax' >/dev/null 2>&1; \
  pkill iperf3 2>/dev/null; for p in 5201 5202 5203 5204; do iperf3 -s -p \$p -D; done"
sleep 3
# unprotected: one shaped FIFO per uplink (bulk and control share it)
for ifc in eth1 eth2; do
  ${D}-array01 sh -c "tc qdisc replace dev ${ifc} root tbf rate ${RATE} burst 256kb latency 50ms 2>/dev/null"
done
echo "  array01: VIP up, 4 sinks, both uplinks shaped to ${RATE} egress (one FIFO)"
echo "=== The writers ==="
for w in 01 02 03 04; do
  echo "  writer${w}: $(${D}-writer${w} sh -c 'ip -4 addr show eth1 | awk "/inet /{print \$2}"')"
done
