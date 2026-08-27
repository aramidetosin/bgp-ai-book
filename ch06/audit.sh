#!/usr/bin/env bash
# Chapter 6 audit: every BGP session Established, every loopback reachable
# from leaf01, the server path working end to end, and the cabling matching
# intent. Evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch06_audit_${TS}
mkdir -p "${OUT}/raw"
SUM="${OUT}/summary.txt"

echo "=== BGP sessions on the core underlay ===" | tee -a "${SUM}"
for dev in leaf01 leaf02 leaf03 leaf04; do want=2
  ${SSH} cumulus@clab-${LAB}-${dev} "sudo vtysh -c 'show bgp summary json'" 2>/dev/null > "${OUT}/raw/${dev}_bgp.json"
  est=$(python3 -c "import json;d=json.load(open('${OUT}/raw/${dev}_bgp.json'))['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${dev}: ${est}/${want} Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done
for dev in spine01 spine02; do want=4
  ${SSH} cumulus@clab-${LAB}-${dev} "sudo vtysh -c 'show bgp summary json'" 2>/dev/null > "${OUT}/raw/${dev}_bgp.json"
  est=$(python3 -c "import json;d=json.load(open('${OUT}/raw/${dev}_bgp.json'))['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${dev}: ${est}/${want} Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done

echo "=== Every loopback reachable from leaf01 ===" | tee -a "${SUM}"
for ip in 10.0.0.2 10.0.0.3 10.0.0.4 10.0.0.101 10.0.0.102; do
  if ${SSH} cumulus@clab-${LAB}-leaf01 "sudo ping -c 2 -W 2 -I 10.0.0.1 ${ip}" >/dev/null 2>&1; then
    echo "  leaf01 -> ${ip} - OK" | tee -a "${SUM}"
  else
    echo "  leaf01 -> ${ip} - FAIL" | tee -a "${SUM}"
  fi
done

echo "=== Server to server across the fabric ===" | tee -a "${SUM}"
if ${D}-server01 ping -c 3 -W 2 172.16.4.11 >/dev/null 2>&1; then
  echo "  server01 -> server02 (172.16.4.11) - OK" | tee -a "${SUM}"
else
  echo "  server01 -> server02 (172.16.4.11) - FAIL" | tee -a "${SUM}"
fi

echo "=== Cabling versus intent (LLDP) ===" | tee -a "${SUM}"
./verify_lldp.sh > "${OUT}/raw/lldp_verify.txt" 2>&1
tail -1 "${OUT}/raw/lldp_verify.txt" | sed 's/^/  /' | tee -a "${SUM}"

echo | tee -a "${SUM}"
echo "Audit written to ${OUT}/"
