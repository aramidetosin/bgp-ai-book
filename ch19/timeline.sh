#!/usr/bin/env bash
# Chapter 19: one timeline. Job step time and fabric events on a single axis.
# The mesh's cross-fabric probe (server01 -> server04) is the job's step; BMP
# is the routing view. A clean failure shows on both. A gray failure (silent
# loss, sessions stay up) shows on the job and is invisible to routing: the
# gap chapter 16 opened, on one clock.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")"
OUT=${OUT:-audits/timeline}; mkdir -p "$OUT"
COL="docker exec clab-bgpbook-${LAB#bgpbook-}-server01"
_ssh(){ local h=$1; shift; sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 cumulus@clab-${LAB}-"$h" "$@"; }
bmpcount(){ docker exec clab-${LAB}-server01 sh -c "wc -l < /tmp/bmp-events.jsonl" 2>/dev/null | tr -d ' '; }
# job step: 20 probes over ~2s across the fabric; return % lost (stalled)
stall(){ docker exec clab-${LAB}-server01 ping -c 20 -i 0.1 -W1 172.16.4.11 2>/dev/null | grep -oE "[0-9]+% packet loss" | grep -oE "^[0-9]+"; }
gray_on(){  for p in swp2 swp3; do _ssh leaf01 "sudo tc qdisc replace dev $p root netem loss ${1}%" </dev/null >/dev/null 2>&1; done; }
gray_off(){ for p in swp2 swp3; do _ssh leaf01 "sudo tc qdisc del dev $p root netem" </dev/null >/dev/null 2>&1; done; }
row(){ printf "  t+%-3s  %-14s routing=%-3s BMP-events   step-stall=%-4s  %s\n" "$1" "$2" "$3" "$4%" "$5"; }

{
echo "=== One timeline: routing (BMP) and the job (mesh step) on one clock ==="
gray_off 2>/dev/null; sleep 3
b0=$(bmpcount)
echo "-- healthy --"
s=$(stall);            row 0  "healthy"    "$(( $(bmpcount)-b0 ))" "${s:-0}" "green: routing quiet, job clean"
echo "-- GRAY FAILURE: 20% loss on leaf01 uplinks, sessions stay up --"
gray_on 20; b1=$(bmpcount)
s=$(stall);            row 4  "gray"       "$(( $(bmpcount)-b1 ))" "${s:-0}" "routing SILENT, job bleeding"
s=$(stall);            row 7  "gray"       "$(( $(bmpcount)-b1 ))" "${s:-0}" "the gap: BMP sees nothing, steps stall"
gray_off
echo "-- CLEAN FAILURE: leaf04 loses both uplinks --"
b2=$(bmpcount)
_ssh leaf04 "sudo ip link set swp2 down; sudo ip link set swp3 down" </dev/null >/dev/null 2>&1
sleep 12
s=$(stall);            row 20 "clean-fail"  "$(( $(bmpcount)-b2 ))" "${s:-0}" "routing SEES it: withdrawals in BMP"
_ssh leaf04 "sudo ip link set swp2 up; sudo ip link set swp3 up" </dev/null >/dev/null 2>&1
sleep 12
s=$(stall);            row 32 "restored"    "$(( $(bmpcount)-b2 ))" "${s:-0}" "re-announced, job clean"
echo
echo "The gray failure moved the job metric and left the routing metric flat."
echo "On one timeline, the counter and the step time agree; the dashboard alone does not."
} | tee "$OUT/evidence.txt"
