#!/usr/bin/env bash
# Chapter 17: a change to intent is a diff you can review. Turn on the BFD
# tuning the schema already carries, regenerate, and read the config diff
# the pull request would show, before anything is pushed.
cd "$(dirname "$0")"
OUT=${OUT:-audits/diff}; mkdir -p "$OUT"
{
echo "=== The change request: bfd.enabled false -> true in spec.yml ==="
python3 gen.py >/dev/null; cp -r bootstrap /tmp/before17
sed 's/  enabled: false/  enabled: true/' spec.yml > /tmp/spec-bfd.yml
python3 gen.py --spec /tmp/spec-bfd.yml >/dev/null
echo "--- the rendered diff on leaf01 (what a reviewer approves) ---"
diff /tmp/before17/leaf01.cfg bootstrap/leaf01.cfg | grep -E "^[<>]" | sed 's/^/  /'
python3 gen.py >/dev/null   # regenerate back to the committed spec
echo "One line of intent, four lines of config per neighbor, every device, reviewable before it ships."
} | tee "$OUT/evidence.txt"
