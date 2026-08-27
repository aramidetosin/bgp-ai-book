#!/usr/bin/env bash
# Chapter 7 audit: the chapter 6 underlay still healthy underneath, the
# EVPN sessions carrying the new address family, all three route types
# present, both tenants working on their overlapping subnets, and the
# type-5 next hop naming the far VTEP's loopback. Evidence under audits/.
set -uo pipefail
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch07_audit_${TS}
mkdir -p "${OUT}/raw"
SUM="${OUT}/summary.txt"

echo "=== Underlay: BGP sessions still Established ===" | tee -a "${SUM}"
for dev in leaf01 leaf04 spine01; do
  want=2; case ${dev} in spine*) want=4;; esac
  ${SSH} cumulus@clab-${LAB}-${dev} "sudo vtysh -c 'show bgp summary json'" 2>/dev/null > "${OUT}/raw/${dev}_bgp.json"
  est=$(python3 -c "import json;d=json.load(open('${OUT}/raw/${dev}_bgp.json'))['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${dev}: ${est}/${want} ipv4 Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done

echo "=== Overlay: the same sessions carry l2vpn evpn ===" | tee -a "${SUM}"
for dev in leaf01 leaf04 spine01; do
  want=2; case ${dev} in spine*) want=4;; esac
  est=$(python3 -c "import json;d=json.load(open('${OUT}/raw/${dev}_bgp.json')).get('l2VpnEvpn',{}).get('peers',{});print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${dev}: ${est}/${want} evpn Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done

echo "=== Route types on leaf04 ===" | tee -a "${SUM}"
${SSH} cumulus@clab-${LAB}-leaf04 "sudo vtysh -c 'show bgp l2vpn evpn' " > "${OUT}/raw/leaf04_evpn_table.txt" 2>/dev/null
for t in 2 3 5; do
  n=$(grep -c "^ *\*>.*\[${t}\]:" "${OUT}/raw/leaf04_evpn_table.txt" 2>/dev/null)
  echo "  type-${t} best routes: ${n} $([ "${n}" -gt 0 ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done

echo "=== TENANTA: routed tenant across the overlay ===" | tee -a "${SUM}"
if ${SSH} cumulus@clab-${LAB}-leaf01 "sudo ip vrf exec TENANTA ping -c 3 -W 2 10.200.1.4" >/dev/null 2>&1; then
  echo "  leaf01 -> 10.200.1.4 in TENANTA - OK" | tee -a "${SUM}"
else
  echo "  leaf01 -> 10.200.1.4 in TENANTA - FAIL" | tee -a "${SUM}"
fi
if ${SSH} cumulus@clab-${LAB}-leaf01 "sudo ip vrf exec TENANTA ping -c 3 -W 2 -I 10.201.1.1 10.201.4.1" >/dev/null 2>&1; then
  echo "  leaf01 -> 10.201.4.1 (type-5 route) in TENANTA - OK" | tee -a "${SUM}"
else
  echo "  leaf01 -> 10.201.4.1 (type-5 route) in TENANTA - FAIL" | tee -a "${SUM}"
fi

echo "=== TENANTB: the same addresses, a different world ===" | tee -a "${SUM}"
if ${SSH} cumulus@clab-${LAB}-leaf01 "sudo ip vrf exec TENANTB ping -c 3 -W 2 10.200.1.4" >/dev/null 2>&1; then
  echo "  leaf01 -> 10.200.1.4 in TENANTB - OK" | tee -a "${SUM}"
else
  echo "  leaf01 -> 10.200.1.4 in TENANTB - FAIL" | tee -a "${SUM}"
fi

echo "=== Isolation: TENANTB holds no route to TENANTA's exports ===" | tee -a "${SUM}"
if ${SSH} cumulus@clab-${LAB}-leaf01 "ip route show vrf TENANTB 10.201.4.1" 2>/dev/null | grep -q 10.201; then
  echo "  TENANTB sees 10.201.4.1 - FAIL (leak)" | tee -a "${SUM}"
else
  echo "  TENANTB has no route to 10.201.4.1 - OK" | tee -a "${SUM}"
fi

echo "=== Type-5 next hop is the far VTEP loopback ===" | tee -a "${SUM}"
${SSH} cumulus@clab-${LAB}-leaf04 "sudo vtysh -c 'show bgp l2vpn evpn route type prefix' " > "${OUT}/raw/leaf04_type5.txt" 2>/dev/null
if grep -q "10.0.0.1" "${OUT}/raw/leaf04_type5.txt"; then
  echo "  leaf04 sees 10.201.1.1/32 via 10.0.0.1 - OK" | tee -a "${SUM}"
else
  echo "  type-5 next hop check - FAIL" | tee -a "${SUM}"
fi

echo | tee -a "${SUM}"
echo "Audit written to ${OUT}/"
