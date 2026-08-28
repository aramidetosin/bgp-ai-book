#!/usr/bin/env bash
# Chapter 14 break-fix: the restore burst starves the control flow
# because the array's uplinks carry one undifferentiated FIFO, so the
# bulk restore and the health probe share fate and the probe suffers
# through every burst. make heal-14a re-arms the control class.
# Evidence under audits/break14a/.
set -uo pipefail
LAB=bgpbook-ch14
D="docker exec clab-${LAB}"
RATE=${ARRAY_RATE:-2gbit}
OUT=audits/break14a
mkdir -p "${OUT}"
echo "=== The mistake: one shaped FIFO per uplink, no control class ==="
for ifc in eth1 eth2; do
  ${D}-array01 sh -c "tc qdisc replace dev ${ifc} root tbf rate ${RATE} burst 256kb latency 50ms 2>/dev/null"
done
sleep 2
{ echo "=== The restore burst starves the control flow ==="; OUT=${OUT} OUTFILE=inner.txt DUR=${DUR:-10} ./burst.sh 2>/dev/null | grep -A2 "control flow"; } | tee "${OUT}/evidence.txt"
echo; echo "break-14a armed and recorded. make heal-14a undoes it."
