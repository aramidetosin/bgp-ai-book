#!/usr/bin/env bash
# Chapter 14: protect the control flow through the restore burst. Each
# array uplink gets an htb hierarchy with the control class (ICMP here,
# a heartbeat class in production) at strict priority and a guaranteed
# slice, so the bulk restore floods the rest without starving it.
# Evidence under audits/qos/.
set -uo pipefail
LAB=bgpbook-ch14
D="docker exec clab-${LAB}"
RATE=${ARRAY_RATE:-2gbit}
OUT=audits/qos
mkdir -p "${OUT}"
echo "=== Re-arm each uplink: control class strict, bulk gets the rest ==="
for ifc in eth1 eth2; do
  ${D}-array01 sh -c "
    tc qdisc replace dev ${ifc} root handle 1: htb default 20;
    tc class add dev ${ifc} parent 1: classid 1:1 htb rate ${RATE} 2>/dev/null;
    tc class add dev ${ifc} parent 1:1 classid 1:10 htb rate 50mbit ceil ${RATE} prio 0 2>/dev/null;
    tc class add dev ${ifc} parent 1:1 classid 1:20 htb rate 1950mbit ceil ${RATE} prio 1 2>/dev/null;
    tc qdisc add dev ${ifc} parent 1:10 handle 10: pfifo 2>/dev/null;
    tc qdisc add dev ${ifc} parent 1:20 handle 20: pfifo 2>/dev/null;
    tc filter add dev ${ifc} parent 1: protocol ip prio 1 u32 match ip protocol 1 0xff flowid 1:10 2>/dev/null"
done
echo "  ICMP -> class 1:10 (prio 0, 50mbit guaranteed); bulk -> 1:20"
sleep 2
OUT=${OUT} OUTFILE=inner.txt DUR=${DUR:-10} ./burst.sh 2>/dev/null | tail -8 > /tmp/qos_burst.txt
{ echo "=== The same restore burst, control class protected ==="; cat /tmp/qos_burst.txt; } | tee "${OUT}/qos.txt"
echo "Evidence written to ${OUT}/"
