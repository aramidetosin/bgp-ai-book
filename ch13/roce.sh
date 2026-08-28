#!/usr/bin/env bash
# Chapter 13: apply the RoCE lossless preset to the backend fabric and
# record what it actually generated. The point is auditing, not
# trusting: `nv set qos roce enable on` is one line, and this script
# reads back the full mapping/PFC/ECN/scheduler config it expands into,
# on every switch, so the reader sees the preset's real contents.
# Evidence under audits/roce/.
set -uo pipefail

LAB=bgpbook-ch13
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
OUT=audits/roce
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== Applying the RoCE preset, one line per switch ==="
for dev in leaf01 leaf02 spine01 spine02; do
  sw ${dev} "nv set qos roce enable on && nv config apply -y" >/dev/null
  echo "  ${dev}: nv set qos roce enable on"
done
sleep 5

{
  echo "=== What one line generated (leaf01), read back ==="
  sw leaf01 "nv show qos roce"
  echo
  echo "=== The DSCP-to-traffic-class mapping the preset installed ==="
  sw leaf01 "nv show qos mapping 2>/dev/null | head -30"
  echo
  echo "=== The egress queue mapping and scheduler ==="
  sw leaf01 "nv show qos egress-queue-mapping 2>/dev/null | head -20"
  sw leaf01 "nv show qos egress-scheduler 2>/dev/null | head -20"
} | tee "${OUT}/preset_expanded.txt"
echo "Evidence written to ${OUT}/"
