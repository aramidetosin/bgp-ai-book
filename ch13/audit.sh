#!/usr/bin/env bash
# Chapter 13 audit: the underlay is green, the RoCE preset is on every
# switch, and the classification is consistent fabric-wide. The lossless
# dataplane itself is not modelled here; hw/ holds the real counters.
set -uo pipefail
LAB=bgpbook-ch13
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch13_audit_${TS}; mkdir -p "${OUT}/raw"; SUM="${OUT}/summary.txt"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== Underlay BGP ===" | tee -a "${SUM}"
for pair in leaf01:2 leaf02:2 spine01:2 spine02:2; do
  dev=${pair%%:*}; want=${pair##*:}
  est=$(sw ${dev} "sudo vtysh -c 'show bgp summary json'" | python3 -c "import json,sys;d=json.load(sys.stdin)['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${dev}: ${est}/${want} Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done
echo "=== RoCE preset applied everywhere ===" | tee -a "${SUM}"
for dev in leaf01 leaf02 spine01 spine02; do
  mode=$(sw ${dev} "nv show qos roce -o json" | python3 -c "import json,sys;print(json.load(sys.stdin).get('congestion-control',{}).get('congestion-mode','none'))" 2>/dev/null)
  echo "  ${dev}: roce lossless, congestion-control ${mode} $([ "${mode}" = "ECN" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done
echo "=== Classification consistency ===" | tee -a "${SUM}"
./qoscheck.sh > "${OUT}/raw/qoscheck.txt" 2>&1
tail -1 "${OUT}/raw/qoscheck.txt" | sed 's/^/  /' | tee -a "${SUM}"
echo "=== Cabling versus intent (LLDP) ===" | tee -a "${SUM}"
./verify_lldp.sh > "${OUT}/raw/lldp.txt" 2>&1
tail -1 "${OUT}/raw/lldp.txt" | sed 's/^/  /' | tee -a "${SUM}"
echo | tee -a "${SUM}"; echo "Audit written to ${OUT}/"
