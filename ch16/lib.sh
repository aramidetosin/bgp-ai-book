#!/usr/bin/env bash
# Chapter 16 shared helpers. Runs on the containerlab host.
# The four servers form a heartbeat mesh standing in for a collective
# library's step timing: a "step" is a probe across the fabric, and a
# stalled step is a lost probe. Failures are injected on fabric links;
# the detection ladder (hold-timer slow vs BFD fast) decides how many
# steps a failure stalls.
set -uo pipefail
LAB=bgpbook-ch16
PASS=${PASS:-Clab123!}
_ssh(){ local n=$1; shift; sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-${LAB}-${n} "$@"; }
sw(){ _ssh "$1" "sudo $2" 2>/dev/null; }
vt(){ _ssh "$1" "sudo vtysh -c \"$2\"" 2>/dev/null; }
dex(){ docker exec clab-${LAB}-$1 "${@:2}" 2>/dev/null; }

# the heartbeat mesh's measured flow: rank 0 (server01) to rank 2 (server03),
# which crosses a spine. Loss here is a stalled collective step.
SRC=server01
DST_IP=172.16.3.11

# extract the integer packet-loss percent from ping output (handles the
# fractional form "33.3333% packet loss" that a non-power-of-two count prints).
ploss(){ sed -nE 's/.*[^0-9.]([0-9]+)(\.[0-9]+)?% packet loss.*/\1/p'; }

# per-second stall series: N one-second windows of fast probes, loss% each.
loss_series(){ local n=$1
  for s in $(seq 1 "$n"); do
    local loss
    loss=$(dex "$SRC" ping -c 8 -i 0.12 -W1 "$DST_IP" | ploss)
    printf "  step %2ss  stalled=%s%%\n" "$s" "${loss:-100}"
  done
}

# bring the fabric back to full health: both leaf01 uplinks up (verified,
# retried), no impairment, sessions cleared to re-establish promptly.
heal(){
  gray_off
  # ip link toggling drifts NVUE's admin-status down, so switchd keeps
  # re-downing the port; reconcile NVUE's view, not just the kernel link.
  sw leaf01 "bash -c \"nv set interface swp2 link state up; nv set interface swp3 link state up; nv config apply -y; ip link set swp2 up; ip link set swp3 up\"" >/dev/null 2>&1
  local r est
  for r in $(seq 1 6); do
    sleep 5
    est=$(sw leaf01 "vtysh -c 'show bgp summary json'" | grep -o '"state":"Established"' | wc -l)
    [ "${est:-0}" -ge 2 ] && return 0
  done
}

# BFD on/off across every fabric session (platform-default intervals).
# off uses unset so the session runs with no BFD at all (hold-timer detection).
bfd_set(){ local mode=$1   # on | off
  local verb; [ "$mode" = on ] && verb="nv set VRF bfd enable on" || verb="nv unset VRF bfd"
  for l in leaf01 leaf02 leaf03 leaf04; do
    for p in swp2 swp3; do sw "$l" "bash -c \"${verb/VRF/vrf default router bgp neighbor $p}; nv config apply -y\"" >/dev/null 2>&1; done
  done
  for s in spine01 spine02; do
    for p in swp1 swp2 swp3 swp4; do sw "$s" "bash -c \"${verb/VRF/vrf default router bgp neighbor $p}; nv config apply -y\"" >/dev/null 2>&1; done
  done
}

# fail the leaf01 uplink the measured return flow actually uses (ECMP makes
# a fixed link wrong half the time), detected fresh each failure.
FAILSWP=""
link_down(){
  local d; d=$(sw leaf03 "ip route get 172.16.1.11 from 172.16.3.11 iif swp1" | grep -oE "dev swp[0-9]+" | head -1)
  FAILSWP=$(echo "${d##*dev }" | tr -d ' '); [ -n "$FAILSWP" ] || FAILSWP=swp3
  sw leaf01 "ip link set ${FAILSWP} down"
}
link_up(){ sw leaf01 "ip link set swp2 up; ip link set swp3 up"; }
gray_on(){  sw leaf01 "tc qdisc replace dev swp2 root netem loss ${1:-20}%"; sw leaf01 "tc qdisc replace dev swp3 root netem loss ${1:-20}%"; }
gray_off(){ sw leaf01 "tc qdisc del dev swp2 root" >/dev/null 2>&1; sw leaf01 "tc qdisc del dev swp3 root" >/dev/null 2>&1; }
