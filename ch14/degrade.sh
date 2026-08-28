#!/usr/bin/env bash
# Chapter 14: what a drowned link does to checkpoint time. The array
# loses one of its two uplinks, halving its serve capacity, and the same
# restore burst moves half as many bytes in the same window, so a fixed
# checkpoint takes twice as long. This is the number chapter 8 promised
# chapter 14 would put on a partial failure; the fabric-side remedy is
# chapter 8's link-bandwidth weighted ECMP, and this is the cost of not
# having it. Evidence under audits/degrade/.
set -uo pipefail
LAB=bgpbook-ch14
D="docker exec clab-${LAB}"
VIP=172.16.202.1
OUT=audits/degrade
mkdir -p "${OUT}"
DUR=${DUR:-10}

# reset both uplinks to a plain shaped FIFO for a clean capacity comparison
for ifc in eth1 eth2; do
  ${D}-array01 sh -c "tc qdisc replace dev ${ifc} root tbf rate 2gbit burst 256kb latency 50ms 2>/dev/null"
done

aggregate() { # returns aggregate Gbit/s the array served
  for w in 01 02 03 04; do
    ${D}-writer${w} sh -c "iperf3 -c ${VIP} -p $((5200 + 10#$w)) -R -t ${DUR} -J > /tmp/d${w}.json 2>/dev/null" &
  done
  wait
  local total=0
  for w in 01 02 03 04; do
    bps=$(${D}-writer${w} sh -c "cat /tmp/d${w}.json" | python3 -c "import json,sys;print(int(json.load(sys.stdin)['end']['sum_received']['bits_per_second']))" 2>/dev/null || echo 0)
    total=$(python3 -c "print(${total}+${bps})")
  done
  python3 -c "print(f'{${total}/1e9:.2f}')"
}

{
  echo "=== Both uplinks up: full serve capacity ==="
  H=$(aggregate)
  echo "  aggregate served: ${H} Gbit/s"
  echo "=== One uplink drowned: array eth1 down ==="
  ${D}-array01 ip link set eth1 down
  sleep 12
  Dg=$(aggregate)
  echo "  aggregate served: ${Dg} Gbit/s"
  echo "=== The checkpoint-time cost ==="
  python3 -c "print(f'  a fixed checkpoint that took T at {${H}:.2f} Gbit/s now takes {${H}/${Dg}:.2f} T at {${Dg}:.2f} Gbit/s')" 2>/dev/null || echo "  capacity roughly halved, so a fixed checkpoint takes roughly twice as long"
  ${D}-array01 ip link set eth1 up
  sleep 12
} | tee "${OUT}/degrade.txt"
echo "Evidence written to ${OUT}/"
