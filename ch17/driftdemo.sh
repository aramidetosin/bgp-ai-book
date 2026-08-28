#!/usr/bin/env bash
# Chapter 17: drift, created by hand and caught by the check. Someone SSHes to
# leaf02 and "fixes" its router-id without touching the spec. The generator's
# intent no longer matches the wire; the drift check finds the exact line, and
# the push reconciles it.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")"
OUT=${OUT:-audits/drift}; mkdir -p "$OUT"
{
echo "=== The generated fabric, in sync ==="
python3 drift.py | tail -1
echo
echo "=== A hand-edit on leaf02: router-id changed off-spec ==="
sw leaf02 "bash -c 'nv config detach 2>/dev/null; nv set router bgp router-id 10.0.0.222; nv config apply -y'" >/dev/null 2>&1
echo "  leaf02: router-id set to 10.0.0.222 by hand"
echo
echo "=== The drift check finds it, by line, without guessing ==="
python3 drift.py | sed -n '/leaf02: DRIFT/,+1p' | sed 's/^/  /'
python3 drift.py | tail -1 | sed 's/^/  /'
echo
echo "=== The push reconciles leaf02 to the generated intent ==="
python3 push.py | sed -n '/leaf02:/p;/Every device/p' | sed 's/^/  /'
sleep 3
echo
echo "=== The drift check, run again: clean ==="
python3 drift.py | tail -1 | sed 's/^/  /'
} | tee "$OUT/evidence.txt"
