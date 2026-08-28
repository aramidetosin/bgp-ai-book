#!/usr/bin/env bash
# Chapter 16: a clean link failure, measured twice. Without BFD the far
# side (spine01) does not see the carrier drop, so it keeps forwarding
# into the dead link until its hold timer expires. With BFD it learns in
# a fraction of a second. Same failure, two detection times: the ladder
# chapter 6 measured, in stalled collective steps.
source "$(dirname "$0")/lib.sh"
OUT=${OUT:-audits/down}; mkdir -p "$OUT"
heal >/dev/null 2>&1
{
echo "=== WITHOUT BFD: down leaf01 uplink the flow uses, stalled steps until the hold timer ==="
bfd_set off; sleep 6; link_up; sleep 6
link_down
loss_series 9
link_up; sleep 10
echo
echo "=== WITH BFD: the same failure, detected in a fraction of a second ==="
bfd_set on; sleep 8
link_down
loss_series 6
link_up; sleep 8
echo "Same link, same break. The detection time is the whole difference in step damage."
} | tee "$OUT/down.txt"
