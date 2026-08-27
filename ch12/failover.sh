#!/usr/bin/env bash
# Chapter 12: fail the active firewall mid-download and measure what
# survives. State sync is on, so the session should ride through the
# failover. Evidence under audits/failover/.
set -uo pipefail
cd "$(dirname "$0")"
source ./pa.sh

LAB=bgpbook-ch12
D="docker exec clab-${LAB}"
OUT=audits/failover
mkdir -p "${OUT}"

ACTIVE_IP=172.20.40.11; ACTIVE_NAME=fw-a; STANDBY_IP=172.20.40.12
if [ "$(pa_state 172.20.40.12)" = "active" ]; then
  ACTIVE_IP=172.20.40.12; ACTIVE_NAME=fw-b; STANDBY_IP=172.20.40.11
fi

${D}-intserver01 sh -c "[ -s /www/big.bin ] || dd if=/dev/urandom of=/www/big.bin bs=1M count=60 2>/dev/null"

{
  echo "=== Before: ${ACTIVE_NAME} is active ==="
  echo "  fw-a: $(pa_state 172.20.40.11)   fw-b: $(pa_state 172.20.40.12)"
  echo
  echo "=== The download starts (60 MB, rate-limited so it lives long enough) ==="
  ${D}-extclient01 sh -c "rm -f /tmp/big.bin; (time curl -s --max-time 120 --limit-rate 2000k http://203.0.113.100/big.bin -o /tmp/big.bin) 2>/tmp/dl.time; echo done > /tmp/dl.flag" &
  DL=$!
  sleep 6
  echo "--- suspending ${ACTIVE_NAME} six seconds in ---"
  pa_op ${ACTIVE_IP} "<request><high-availability><state><suspend/></state></high-availability></request>" | grep -o "<result>[^<]*</result>" | head -1
  sleep 10
  echo "--- states mid-transfer ---"
  for ip in 172.20.40.11 172.20.40.12; do
    echo "  ${ip}: $(pa_op ${ip} "<show><high-availability><state/></high-availability></show>" | grep -o "<state>[a-z-]*</state>" | head -1)"
  done
  wait ${DL}
  echo
  echo "=== The verdict ==="
  size=$(${D}-extclient01 sh -c "wc -c < /tmp/big.bin | tr -d ' '")
  echo "  bytes received: ${size} of 62914560"
  ${D}-extclient01 sh -c "grep real /tmp/dl.time"
  [ "${size}" = "62914560" ] && echo "  the download survived the failover" || echo "  the download DID NOT survive"
  echo
  echo "=== The session, now owned by the survivor ==="
  pa_op ${STANDBY_IP} "<show><session><all><filter><destination>203.0.113.100</destination></filter></all></session></show>" 2>/dev/null | grep -cE "<entry>" | sed 's/^/  sessions on the new active: /'
  echo "--- restoring the suspended unit to functional ---"
  pa_op ${ACTIVE_IP} "<request><high-availability><state><functional/></state></high-availability></request>" | grep -o "<result>[^<]*</result>" | head -1
} | tee "${OUT}/failover.txt"
echo "Evidence written to ${OUT}/"
