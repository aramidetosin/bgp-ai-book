#!/usr/bin/env bash
# Chapter 16: a flapping link. It comes back before the hold timer
# fully punishes it, then fails again, so the fabric is perpetually
# reconverging and never stable. Without BFD a flap slower than the
# detection time can damage more total step time than one hard failure.
source "$(dirname "$0")/lib.sh"
OUT=${OUT:-audits/flap}; mkdir -p "$OUT"
heal >/dev/null 2>&1
{
echo "=== Flapping leaf01 the flow's spine uplink (down 2s / up 4s), no BFD, 18s window ==="
bfd_set off; sleep 6; link_up; sleep 6
( for c in 1 2 3; do link_down; sleep 2; link_up; sleep 4; done ) &
FLAP=$!
loss_series 18
wait $FLAP 2>/dev/null; link_up
echo "Each flap restarts the ~5s detection clock; the job never gets a clean run."
} | tee "$OUT/flap.txt"
