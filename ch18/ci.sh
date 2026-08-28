#!/usr/bin/env bash
# Chapter 18: the promotion pipeline. Each stage catches a class of bug, and a
# failure at any stage stops the change before production. This is the recipe
# a CI system runs on every change to the intent; the stage boundaries are the
# same whether the runner is GitLab CI, GitHub Actions, or Jenkins.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")"
OUT=${OUT:-audits/ci}; mkdir -p "$OUT"
stage(){ echo; echo "===== STAGE $1 ====="; }
{
stage "1: lint the spec";              python3 lint.py            || exit 1
stage "2: render the configs";         (cd ../ch17 && python3 gen.py) || exit 1
stage "3: build the digital twin";     python3 mksnapshot.py      || exit 1
stage "4: property checks (Batfish)";  $PY validate.py            || exit 1
stage "5: golden snapshot test";       python3 golden.py          || exit 1
echo; echo "ALL STAGES PASSED: the change is safe to promote to production"
} | tee "$OUT/evidence.txt"
