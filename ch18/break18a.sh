#!/usr/bin/env bash
# Chapter 18 break-18a: a bad change submitted to the pipeline. The property
# check stage catches it before it ships. The change passes lint and render
# and would deploy without error; only the twin, checked against the ECMP
# invariant, sees that it silently halves a leaf's path count.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")"
OUT=${OUT:-audits/break18a}; mkdir -p "$OUT"
{
echo "===== STAGE 1: lint the spec ====="; python3 lint.py
echo; echo "===== STAGE 4: property checks catch the bad route policy ====="
python3 mkbreak.py
SNAP=snapshot-broken $PY validate.py
rc=$?
echo; echo "pipeline exit code: $rc (non-zero blocks the promotion)"
} | tee "$OUT/evidence.txt"
