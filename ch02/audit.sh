#!/usr/bin/env bash
# Chapter 2 fabric audit: run after the build (or after `make solution`).
# Expects the finished unnumbered triangle. Writes evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch02
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch02_audit_${TS}
mkdir -p "${OUT}/raw"
SUM="${OUT}/summary.txt"

for node in r1 r2 r3; do
  echo "=== ${node} ===" | tee -a "${SUM}"
  ${SSH} cumulus@clab-${LAB}-${node} "sudo vtysh -c 'show bgp summary json'" \
    2>/dev/null > "${OUT}/raw/${node}_bgp_summary.json"
  python3 - "${OUT}/raw/${node}_bgp_summary.json" <<'PY' | tee -a "${SUM}"
import json, sys
d = json.load(open(sys.argv[1]))["ipv4Unicast"]
peers = d.get("peers", {})
est = sum(1 for p in peers.values() if p.get("state") == "Established")
print(f"  BGP ipv4 sessions: {est} Established / {len(peers)} configured"
      + ("  - OK" if est == len(peers) == 2 else "  - FAIL"))
PY
done

echo "=== Path diversity (r3's view of r1's loopback) ===" | tee -a "${SUM}"
${SSH} cumulus@clab-${LAB}-r3 "sudo vtysh -c 'show bgp ipv4 unicast 10.0.0.1/32 json'" \
  2>/dev/null > "${OUT}/raw/r3_paths_to_r1lo.json"
python3 - "${OUT}/raw/r3_paths_to_r1lo.json" <<'PY' | tee -a "${SUM}"
import json, sys
d = json.load(open(sys.argv[1]))
n = len(d.get("paths", []))
print(f"  r3 -> 10.0.0.1/32: {n} path(s) in table - " + ("OK" if n == 2 else "FAIL"))
PY

echo "=== Data plane (loopback to loopback) ===" | tee -a "${SUM}"
for pair in "r1 10.0.0.1 10.0.0.3" "r3 10.0.0.3 10.0.0.2"; do
  set -- ${pair}
  loss=$(${SSH} cumulus@clab-${LAB}-$1 "ping -c 3 -W 2 -I $2 $3" 2>/dev/null \
    | tee "${OUT}/raw/ping_$1_to_$3.txt" | grep -oE '[0-9]+% packet loss')
  echo "  $1 ($2) -> $3: ${loss}" | tee -a "${SUM}"
done

echo
echo "Audit written to ${OUT}/"
