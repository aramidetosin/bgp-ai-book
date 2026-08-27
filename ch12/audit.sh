#!/usr/bin/env bash
# Chapter 12 audit: sessions up end to end (including the multihop edge
# session through the firewalls), the HA pair in active/passive, reach
# to the public VIP, and containment of everything else.
set -uo pipefail
cd "$(dirname "$0")"
source ./pa.sh

LAB=bgpbook-ch12
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch12_audit_${TS}
mkdir -p "${OUT}"
SUM="${OUT}/summary.txt"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== BGP sessions ===" | tee -a "${SUM}"
for pair in leaf01:2 border01:2; do
  dev=${pair%%:*}; want=${pair##*:}
  est=$(sw ${dev} "sudo vtysh -c 'show bgp summary json'" | python3 -c "import json,sys;d=json.load(sys.stdin)['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${dev}: ${est}/${want} Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done
uest=$(${D}-upstream01 vtysh -c "show bgp summary json" 2>/dev/null | python3 -c "import json,sys;d=json.load(sys.stdin)['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
echo "  upstream01: ${uest}/1 Established $([ "${uest}" = "1" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"

echo "=== The pair ===" | tee -a "${SUM}"
A=$(pa_state 172.20.40.11); B=$(pa_state 172.20.40.12)
echo "  fw-a: ${A}   fw-b: ${B} $([ "${A}${B}" = "activepassive" -o "${A}${B}" = "passiveactive" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"

echo "=== Reach: the public VIP from the internet ===" | tee -a "${SUM}"
if ${D}-extclient01 curl -s --max-time 5 http://203.0.113.100/ | grep -q inference; then
  echo "  extclient01 -> 203.0.113.100 (HTTP) - OK" | tee -a "${SUM}"
else
  echo "  extclient01 -> 203.0.113.100 (HTTP) - FAIL" | tee -a "${SUM}"
fi

echo "=== Containment: nothing else answers ===" | tee -a "${SUM}"
for tgt in 172.16.1.11 10.0.0.9 172.31.1.0; do
  if ${D}-extclient01 sh -c "curl -s --max-time 3 http://${tgt}/ -o /dev/null 2>/dev/null || ping -c 1 -W 2 ${tgt} >/dev/null 2>&1"; then
    echo "  extclient01 -> ${tgt} reachable - FAIL (containment broken)" | tee -a "${SUM}"
  else
    echo "  extclient01 -> ${tgt} unreachable - OK" | tee -a "${SUM}"
  fi
done

echo | tee -a "${SUM}"
echo "Audit written to ${OUT}/"
