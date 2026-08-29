#!/usr/bin/env bash
# Chapter 21: clear every game-day fault, return the fabric to health.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")"
_ssh leaf04 "sudo ip link set swp2 up; sudo ip link set swp3 up" >/dev/null 2>&1
for p in swp2 swp3; do _ssh leaf01 "sudo tc qdisc del dev $p root netem" >/dev/null 2>&1; done
_ssh leaf03 "sudo pkill -f 'ip link set swp2'; sudo ip link set swp2 up" >/dev/null 2>&1
_ssh leaf02 "sudo vtysh -c 'configure terminal' -c 'router bgp 65102' -c 'address-family ipv4 unicast' -c 'no network 10.66.0.0/16' -c 'exit' -c 'no ip route 10.66.0.0/16 Null0' -c 'end'" >/dev/null 2>&1
_ssh leaf03 "sudo vtysh -c 'configure terminal' -c 'router bgp 65103' -c 'no neighbor swp3 password wrongkey' -c 'end'" >/dev/null 2>&1
rm -f .gameday-fault
echo "Faults cleared; fabric returning to health."
