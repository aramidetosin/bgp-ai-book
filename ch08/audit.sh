#!/usr/bin/env bash
# Chapter 8 audit: every session Established (including leaf01's parallel
# pairs), the ECMP fans as designed (4 next hops on leaf01, 2 on leaf02),
# the kernel hashing on the 5-tuple, and servers reachable end to end.
# Evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch08
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch08_audit_${TS}
mkdir -p "${OUT}/raw"
SUM="${OUT}/summary.txt"

echo "=== BGP sessions ===" | tee -a "${SUM}"
for pair in leaf01:4 leaf02:2 spine01:3 spine02:3; do
  dev=${pair%%:*}; want=${pair##*:}
  ${SSH} cumulus@clab-${LAB}-${dev} "sudo vtysh -c 'show bgp summary json'" 2>/dev/null > "${OUT}/raw/${dev}_bgp.json"
  est=$(python3 -c "import json;d=json.load(open('${OUT}/raw/${dev}_bgp.json'))['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${dev}: ${est}/${want} Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done

echo "=== The ECMP fans ===" | tee -a "${SUM}"
n1=$(${SSH} cumulus@clab-${LAB}-leaf01 "sudo vtysh -c 'show ip route 172.16.2.0/24 json'" 2>/dev/null | python3 -c "import json,sys;print(len(json.load(sys.stdin)['172.16.2.0/24'][0]['nexthops']))" 2>/dev/null)
n2=$(${SSH} cumulus@clab-${LAB}-leaf02 "sudo vtysh -c 'show ip route 172.16.1.0/24 json'" 2>/dev/null | python3 -c "import json,sys;print(len(json.load(sys.stdin)['172.16.1.0/24'][0]['nexthops']))" 2>/dev/null)
echo "  leaf01 -> 172.16.2.0/24: ${n1} next hops $([ "${n1}" = "4" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
echo "  leaf02 -> 172.16.1.0/24: ${n2} next hops $([ "${n2}" = "2" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
${SSH} cumulus@clab-${LAB}-leaf01 "ip route show 172.16.2.0/24 && ip nexthop show" > "${OUT}/raw/leaf01_route.txt" 2>/dev/null
${SSH} cumulus@clab-${LAB}-leaf02 "ip route show 172.16.1.0/24 && ip nexthop show" > "${OUT}/raw/leaf02_route.txt" 2>/dev/null

echo "=== The hash the kernel plays with ===" | tee -a "${SUM}"
hp=$(${SSH} cumulus@clab-${LAB}-leaf01 "cat /proc/sys/net/ipv4/fib_multipath_hash_policy" 2>/dev/null)
echo "  fib_multipath_hash_policy = ${hp} (1 = 5-tuple) $([ "${hp}" = "1" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"

echo "=== Server to server across the fabric ===" | tee -a "${SUM}"
if ${D}-server01 ping -c 3 -W 2 172.16.2.11 >/dev/null 2>&1; then
  echo "  server01 -> server02 (172.16.2.11) - OK" | tee -a "${SUM}"
else
  echo "  server01 -> server02 (172.16.2.11) - FAIL" | tee -a "${SUM}"
fi

echo "=== Cabling versus intent (LLDP) ===" | tee -a "${SUM}"
./verify_lldp.sh > "${OUT}/raw/lldp_verify.txt" 2>&1
tail -1 "${OUT}/raw/lldp_verify.txt" | sed 's/^/  /' | tee -a "${SUM}"

echo | tee -a "${SUM}"
echo "Audit written to ${OUT}/"
