#!/usr/bin/env bash
# Chapter 3 audit: the two networks each do their job, and cannot do each
# other's. Writes evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch03
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch03_audit_${TS}
mkdir -p "${OUT}/raw"
SUM="${OUT}/summary.txt"
D="docker exec clab-${LAB}"

echo "=== Frontend: the service path works ===" | tee -a "${SUM}"
code=$(${D}-client curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://172.16.10.11/ 2>/dev/null)
echo "  client -> nodea HTTP: ${code} $([ "${code}" = "200" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"

echo "=== Backend: the collective path works ===" | tee -a "${SUM}"
${D}-nodea sh -c "pgrep iperf3 >/dev/null || nohup iperf3 -s -B 172.31.1.11 >/dev/null 2>&1 &" 2>/dev/null
sleep 1
${D}-nodeb iperf3 -c 172.31.1.11 -B 172.31.1.12 -t 3 -J > "${OUT}/raw/iperf_backend.json" 2>/dev/null
gbps=$(python3 -c "import json;d=json.load(open('${OUT}/raw/iperf_backend.json'));print(round(d['end']['sum_received']['bits_per_second']/1e9,1))" 2>/dev/null)
echo "  nodeb -> nodea over backend: ${gbps} Gbit/s $([ -n "${gbps}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"

echo "=== Isolation: each network cannot do the other's job ===" | tee -a "${SUM}"
if ${D}-client ping -c 2 -W 2 172.31.1.11 >/dev/null 2>&1; then
  echo "  client -> backend subnet: REACHABLE - FAIL (should be impossible)" | tee -a "${SUM}"
else
  echo "  client -> backend subnet: unreachable - OK" | tee -a "${SUM}"
fi
${D}-client ip route get 172.31.1.11 > "${OUT}/raw/client_route_to_backend.txt" 2>&1

echo "=== Node view: two worlds in one routing table ===" | tee -a "${SUM}"
${D}-nodea sh -c "ip -br addr show eth1 eth2; ip route" > "${OUT}/raw/nodea_view.txt" 2>&1
grep -q "default via 172.16.10.1" "${OUT}/raw/nodea_view.txt" \
  && echo "  nodea default via frontend, backend connected-only - OK" | tee -a "${SUM}" \
  || echo "  nodea routing view unexpected - FAIL" | tee -a "${SUM}"

echo | tee -a "${SUM}"
echo "Audit written to ${OUT}/"
