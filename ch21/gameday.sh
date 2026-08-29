#!/usr/bin/env bash
# Chapter 21 game day: inject one of five undisclosed faults into the running
# reference fabric. Diagnose it with the chapter 19 stack (the BMP collector,
# make timeline, make bmp-query), write the post-mortem, then run
# ./reveal.sh to check your answer against the reference. Faults are chosen so
# each has a distinct signature across the tools you built.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")"
N=${1:-$(( (RANDOM % 5) + 1 ))}
echo "$N" > .gameday-fault
case "$N" in
  1) _ssh leaf04 "sudo ip link set swp2 down; sudo ip link set swp3 down" >/dev/null 2>&1 ;;
  2) for p in swp2 swp3; do _ssh leaf01 "sudo tc qdisc replace dev $p root netem loss 20%" >/dev/null 2>&1; done ;;
  3) _ssh leaf03 "sudo bash -c 'for i in \$(seq 1 30); do ip link set swp2 down; sleep 2; ip link set swp2 up; sleep 4; done' >/dev/null 2>&1 &" >/dev/null 2>&1 ;;
  4) _ssh leaf02 "sudo vtysh -c 'configure terminal' -c 'ip route 10.66.0.0/16 Null0' -c 'router bgp 65102' -c 'address-family ipv4 unicast' -c 'network 10.66.0.0/16' -c 'end'" >/dev/null 2>&1 ;;
  5) _ssh leaf03 "sudo vtysh -c 'configure terminal' -c 'router bgp 65103' -c 'neighbor swp3 password wrongkey' -c 'end'" >/dev/null 2>&1 ;;
esac
echo "A fault is active on the reference fabric. It started just now."
echo "Diagnose it with your chapter 19 stack, write the post-mortem, then: ./reveal.sh"
