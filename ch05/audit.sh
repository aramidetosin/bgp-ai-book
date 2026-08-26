#!/usr/bin/env bash
# Chapter 5 audit: every BGP session up on the generated fabric, every rail
# carrying its nodes, and the cabling matching intent. Evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch05
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch05_audit_${TS}
mkdir -p "${OUT}/raw"
SUM="${OUT}/summary.txt"

SPINES=$(python3 -c "import yaml;print(yaml.safe_load(open('spec.yml'))['spines'])")
RAILS=$(python3 -c "import yaml;print(yaml.safe_load(open('spec.yml'))['gpus_per_node'])")
NODES=$(python3 -c "import yaml;print(yaml.safe_load(open('spec.yml'))['nodes'])")

echo "=== BGP sessions on the generated fabric ===" | tee -a "${SUM}"
for i in $(seq 1 ${RAILS}); do sw="rail${i}"; want=${SPINES}
  ${SSH} cumulus@clab-${LAB}-${sw} "sudo vtysh -c 'show bgp summary json'" 2>/dev/null > "${OUT}/raw/${sw}_bgp.json"
  est=$(python3 -c "import json;d=json.load(open('${OUT}/raw/${sw}_bgp.json'))['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${sw}: ${est}/${want} Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done
for s in $(seq 1 ${SPINES}); do sw="spine${s}"; want=${RAILS}
  ${SSH} cumulus@clab-${LAB}-${sw} "sudo vtysh -c 'show bgp summary json'" 2>/dev/null > "${OUT}/raw/${sw}_bgp.json"
  est=$(python3 -c "import json;d=json.load(open('${OUT}/raw/${sw}_bgp.json'))['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${sw}: ${est}/${want} Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done

echo "=== Every rail carries its nodes (node1 to node2, per rail) ===" | tee -a "${SUM}"
for i in $(seq 1 ${RAILS}); do
  if ${D}-node1 ping -c 2 -W 2 -I 172.31.${i}.11 172.31.${i}.12 >/dev/null 2>&1; then
    echo "  rail${i}: node1 -> node2 on 172.31.${i}.0/24 - OK" | tee -a "${SUM}"
  else
    echo "  rail${i}: node1 -> node2 on 172.31.${i}.0/24 - FAIL" | tee -a "${SUM}"
  fi
done

echo "=== Cabling versus intent (LLDP) ===" | tee -a "${SUM}"
./verify_lldp.sh > "${OUT}/raw/lldp_verify.txt" 2>&1
tail -1 "${OUT}/raw/lldp_verify.txt" | sed 's/^/  /' | tee -a "${SUM}"

echo | tee -a "${SUM}"
echo "Audit written to ${OUT}/"
