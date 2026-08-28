#!/usr/bin/env bash
# Chapter 14 audit: underlay green, the array's VIP reachable via both
# leafs (dual-homed routed head), writers can reach it, cabling matches.
set -uo pipefail
LAB=bgpbook-ch14
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
TS=$(date +%Y%m%d_%H%M%S); OUT=audits/ch14_audit_${TS}; mkdir -p "${OUT}/raw"; SUM="${OUT}/summary.txt"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }
echo "=== Underlay BGP ===" | tee -a "${SUM}"
for pair in leaf01:3 leaf02:3 leaf03:2 spine01:3 spine02:3; do
  dev=${pair%%:*}; want=${pair##*:}
  est=$(sw ${dev} "sudo vtysh -c 'show bgp summary json'" | python3 -c "import json,sys;d=json.load(sys.stdin)['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${dev}: ${est}/${want} Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done
echo "=== The array VIP, ECMP across both leafs on a compute leaf ===" | tee -a "${SUM}"
n=$(sw leaf03 "sudo vtysh -c 'show ip route 172.16.202.1/32 json'" | python3 -c "import json,sys;d=json.load(sys.stdin);print(len(list(d.values())[0][0]['nexthops']))" 2>/dev/null)
echo "  leaf03 -> array VIP: ${n} next hops $([ "${n}" = "2" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
echo "=== Writer to array ===" | tee -a "${SUM}"
${D}-writer01 ping -c 2 -W 2 172.16.202.1 >/dev/null 2>&1 && echo "  writer01 -> array VIP - OK" | tee -a "${SUM}" || echo "  writer01 -> array VIP - FAIL" | tee -a "${SUM}"
echo "=== Cabling versus intent (LLDP) ===" | tee -a "${SUM}"
./verify_lldp.sh > "${OUT}/raw/lldp.txt" 2>&1
tail -1 "${OUT}/raw/lldp.txt" | sed 's/^/  /' | tee -a "${SUM}"
echo | tee -a "${SUM}"; echo "Audit written to ${OUT}/"
