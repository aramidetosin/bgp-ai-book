#!/usr/bin/env bash
# Chapter 12 break-fix: every long transfer through the edge dies
# mid-flight while short requests keep working. The cause: session
# synchronization was disabled, so a failover hands established flows
# to a firewall that never saw them, and out-of-state packets land on
# a device with no session to match. Evidence under audits/break12a/.
set -uo pipefail
cd "$(dirname "$0")"
source ./pa.sh

LAB=bgpbook-ch12
D="docker exec clab-${LAB}"
OUT=audits/break12a
mkdir -p "${OUT}"

ACTIVE_IP=172.20.40.11; ACTIVE_NAME=fw-a; STANDBY_IP=172.20.40.12; STANDBY_NAME=fw-b
if [ "$(pa_state 172.20.40.12)" = "active" ]; then
  ACTIVE_IP=172.20.40.12; ACTIVE_NAME=fw-b; STANDBY_IP=172.20.40.11; STANDBY_NAME=fw-a
fi

echo "=== The quiet mistake: state synchronization off ==="
KEY=$(pa_key ${ACTIVE_IP})
curl -sk "https://${ACTIVE_IP}/api/" --data-urlencode "type=config" --data-urlencode "action=set" \
  --data-urlencode "key=${KEY}" \
  --data-urlencode "xpath=/config/devices/entry[@name='localhost.localdomain']/deviceconfig/high-availability/group/state-synchronization" \
  --data-urlencode "element=<enabled>no</enabled>" | grep -o 'status="[a-z]*"' | head -1
curl -sk "https://${ACTIVE_IP}/api/" --data-urlencode "type=commit" --data-urlencode "key=${KEY}" \
  --data-urlencode "cmd=<commit></commit>" | grep -o 'status="[a-z]*"' | head -1
sleep 45

${D}-intserver01 sh -c "[ -f /www/big.bin ] || head -c 60m /dev/urandom > /www/big.bin"

{
  echo "=== The symptom pair ==="
  echo "--- a short request works ---"
  ${D}-extclient01 sh -c "curl -s --max-time 5 http://203.0.113.100/"
  echo "--- a long transfer, with a failover mid-flight ---"
  ${D}-extclient01 sh -c "rm -f /tmp/big.bin; (curl -s --max-time 60 --limit-rate 2000k http://203.0.113.100/big.bin -o /tmp/big.bin; echo curl exit: \$?) > /tmp/dl.out 2>&1" &
  DL=$!
  sleep 6
  pa_op ${ACTIVE_IP} "<request><high-availability><state><suspend/></state></high-availability></request>" >/dev/null
  wait ${DL}
  ${D}-extclient01 sh -c "cat /tmp/dl.out; echo \"  bytes received: \$(wc -c < /tmp/big.bin | tr -d ' ') of 62914560\""
  echo "--- and a short request right after: fine again ---"
  ${D}-extclient01 sh -c "curl -s --max-time 5 http://203.0.113.100/"
  echo
  echo "=== The investigation ==="
  echo "--- the new active never saw the old session ---"
  pa_op ${STANDBY_IP} "<show><session><all><filter><destination>203.0.113.100</destination></filter></all></session></show>" 2>/dev/null | grep -cE "<entry>" | sed 's/^/  matching sessions on the new active: /'
  echo "--- the tell, in the HA state ---"
  pa_op ${STANDBY_IP} "<show><high-availability><all/></high-availability></show>" 2>/dev/null | grep -oE "<(state-synchronization|enabled)>[^<]*" | head -4
  echo "--- restoring the suspended unit ---"
  pa_op ${ACTIVE_IP} "<request><high-availability><state><functional/></state></high-availability></request>" >/dev/null
} | tee "${OUT}/evidence.txt"
echo
echo "break-12a armed and recorded. make heal-12a undoes it."
