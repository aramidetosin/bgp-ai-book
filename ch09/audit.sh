#!/usr/bin/env bash
# Chapter 9 audit: the base fabric green (sessions, server path, LLDP),
# and whichever host design is currently applied reported as found.
# Evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch09
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch09_audit_${TS}
mkdir -p "${OUT}/raw"
SUM="${OUT}/summary.txt"

echo "=== Fabric BGP sessions ===" | tee -a "${SUM}"
for pair in leaf01:2 leaf02:2 leaf03:2 spine01:3 spine02:3; do
  dev=${pair%%:*}; want=${pair##*:}
  ${SSH} cumulus@clab-${LAB}-${dev} "sudo vtysh -c 'show bgp summary json'" 2>/dev/null > "${OUT}/raw/${dev}_bgp.json"
  est=$(python3 -c "
import json
d=json.load(open('${OUT}/raw/${dev}_bgp.json'))['ipv4Unicast']['peers']
print(sum(1 for k,p in d.items() if p['state']=='Established' and k.startswith('swp') and k in ('swp2','swp3','swp1')))" 2>/dev/null)
  total=$(python3 -c "
import json
d=json.load(open('${OUT}/raw/${dev}_bgp.json'))['ipv4Unicast']['peers']
print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${dev}: ${total} Established (fabric baseline ${want}) $([ "${total}" -ge "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done

echo "=== Server path ===" | tee -a "${SUM}"
if ${D}-server03 ping -c 3 -W 2 172.16.3.1 >/dev/null 2>&1; then
  echo "  server03 -> leaf03 gateway - OK" | tee -a "${SUM}"
else
  echo "  server03 -> leaf03 gateway - FAIL" | tee -a "${SUM}"
fi

echo "=== Host design currently applied ===" | tee -a "${SUM}"
if ${D}-host01 ip link show bond0 >/dev/null 2>&1; then
  echo "  host01 has bond0: multihoming design (make mh) present" | tee -a "${SUM}"
elif [ "$(${D}-host01 vtysh -c 'show bgp summary json' 2>/dev/null | python3 -c 'import json,sys;d=json.load(sys.stdin)["ipv4Unicast"]["peers"];print(sum(1 for p in d.values() if p["state"]=="Established"))' 2>/dev/null)" = "2" ]; then
  echo "  host01 runs FRR with established sessions: routed design (make routed) present" | tee -a "${SUM}"
else
  echo "  host01 unconfigured: base state" | tee -a "${SUM}"
fi

echo "=== Cabling versus intent (LLDP) ===" | tee -a "${SUM}"
./verify_lldp.sh > "${OUT}/raw/lldp_verify.txt" 2>&1
tail -1 "${OUT}/raw/lldp_verify.txt" | sed 's/^/  /' | tee -a "${SUM}"

echo | tee -a "${SUM}"
echo "Audit written to ${OUT}/"
