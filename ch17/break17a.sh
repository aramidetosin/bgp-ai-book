#!/usr/bin/env bash
# Chapter 17 break-17a: a template bug that is invisible until a device has
# more than four uplinks. The broken template slices the neighbor loop to the
# first four uplinks; at two spines every leaf has at most two uplinks, so the
# render is identical and the bug hides. Bump the pod to six spines and the CI
# render diff shows leaf01 missing its fifth and sixth uplink neighbors,
# before a single device is touched.
cd "$(dirname "$0")"
OUT=${OUT:-audits/break17a}; mkdir -p "$OUT"
{
echo "=== At two spines (spec.yml): correct vs broken template, leaf01 ==="
python3 gen.py --spec spec.yml --template switch.cfg.j2 >/dev/null;   cp bootstrap/leaf01.cfg /tmp/ok2.cfg
python3 gen.py --spec spec.yml --template switch.broken.j2 >/dev/null; cp bootstrap/leaf01.cfg /tmp/bad2.cfg
if diff -q /tmp/ok2.cfg /tmp/bad2.cfg >/dev/null; then echo "  identical: the bug is invisible at four uplinks or fewer"; fi
echo
echo "=== At six spines (spec-bigpod.yml): the CI render diff catches it ==="
python3 gen.py --spec spec-bigpod.yml --template switch.cfg.j2 >/dev/null;   cp bootstrap/leaf01.cfg /tmp/ok6.cfg
python3 gen.py --spec spec-bigpod.yml --template switch.broken.j2 >/dev/null; cp bootstrap/leaf01.cfg /tmp/bad6.cfg
echo "--- diff: correct (>) vs broken (<) template, leaf01 with six uplinks ---"
diff /tmp/bad6.cfg /tmp/ok6.cfg | grep -E "^[<>]" | sed 's/^/  /'
echo "The broken template stops emitting neighbors after the fourth uplink,"
echo "so the fifth and sixth spines get no session on a six-uplink leaf. The"
echo "render diff is the review artifact; the bug never reaches a device."
# restore the correct two-spine generation
python3 gen.py --spec spec.yml --template switch.cfg.j2 >/dev/null
} | tee "$OUT/evidence.txt"
