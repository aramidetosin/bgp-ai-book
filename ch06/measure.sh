#!/usr/bin/env bash
# The chapter's failover measurement: a ping loss counter.
#
# server02 pings server01 as fast as ping allows (about 50 per second in
# this environment) for 30 seconds. Ten seconds in, a spine's
# leaf04-facing port goes down FROM THE SPINE SIDE, so leaf04 sees no
# carrier loss (the appendix A quirk, which here stands in for the
# real-world failures where the light stays on) and must detect the dead
# session itself: hold timer or BFD, whichever is armed. Outage seconds =
# lost packets divided by the run's own measured rate. Evidence under
# audits/failover/.
#
# ICMP hashes on addresses only, so the flow deterministically uses one
# spine; if failing spine01 loses nothing, the flow was on spine02, and the
# script heals and fails spine02 instead, recording the effective run.
set -uo pipefail
LABEL=${1:?usage: measure.sh <label>}
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
OUT=audits/failover
mkdir -p "${OUT}"
F="${OUT}/${LABEL}.txt"

run_once() {
  local sp=$1 port=swp4   # both spines face leaf04 on swp4
  echo "== ${LABEL}: fail ${sp}:${port} (leaf04-facing, spine side) ==" | tee -a "${F}"
  ${D}-server02 ping -i 0.01 -w 30 -q 172.16.1.11 > /tmp/ping.$$ &
  local pp=$!
  sleep 10
  ${SSH} cumulus@clab-${LAB}-${sp} "sudo ip link set ${port} down" 2>/dev/null
  wait ${pp} || true
  ${D}-server02 true  # keep docker exec plumbing warm
  cat /tmp/ping.$$ | tail -3 | tee -a "${F}"
  local loss sent
  loss=$(grep -o '[0-9]* packets transmitted, [0-9]* received' /tmp/ping.$$ | awk '{print $1 - $4}')
  sent=$(grep -o '[0-9]* packets transmitted' /tmp/ping.$$ | awk '{print $1}')
  echo "lost ${loss} of ${sent} packets in 30 s: outage about $(awk "BEGIN{printf \"%.2f\", ${loss}*30/${sent}}") s" | tee -a "${F}"
  echo "leaf04 log:" | tee -a "${F}"
  ${SSH} cumulus@clab-${LAB}-leaf04 "sudo grep ADJCHANGE /var/log/frr/frr.log | tail -2" 2>/dev/null | tee -a "${F}"
  # heal: port up, wait for the session to come back
  ${SSH} cumulus@clab-${LAB}-${sp} "sudo ip link set ${port} up" 2>/dev/null
  for i in $(seq 1 30); do
    est=$(${SSH} cumulus@clab-${LAB}-leaf04 "sudo vtysh -c 'show bgp summary json'" 2>/dev/null \
      | python3 -c "import json,sys;d=json.load(sys.stdin)['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
    [ "${est}" = "2" ] && break
    sleep 5
  done
  echo "healed: leaf04 back to ${est}/2 Established" | tee -a "${F}"
  rm -f /tmp/ping.$$
  echo "${loss}"
}

: > "${F}"
loss=$(run_once spine01 | tail -1)
if [ "${loss}" = "0" ]; then
  echo "flow was on spine02; measuring there" | tee -a "${F}"
  run_once spine02 > /dev/null
fi
echo "recorded ${F}"
