#!/usr/bin/env bash
# Chapter 4 audit: all four networks do their jobs, the VRF fences the BMC,
# and the isolation matrix is diagonal. Writes evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch04
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch04_audit_${TS}
mkdir -p "${OUT}/raw"
SUM="${OUT}/summary.txt"

echo "=== Each network does its job ===" | tee -a "${SUM}"
code=$(${D}-client curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://172.16.10.11/ 2>/dev/null)
echo "  frontend  client -> node HTTP: ${code} $([ "$code" = "200" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"

${D}-node sh -c "pgrep iperf3 >/dev/null || nohup iperf3 -s -B 172.31.1.11 >/dev/null 2>&1 &" 2>/dev/null; sleep 1
${D}-gpu-peer iperf3 -c 172.31.1.11 -B 172.31.1.12 -t 3 -J > "${OUT}/raw/iperf_backend.json" 2>/dev/null
gbps=$(python3 -c "import json;d=json.load(open('${OUT}/raw/iperf_backend.json'));print(round(d['end']['sum_received']['bits_per_second']/1e9,1))" 2>/dev/null)
echo "  backend   gpu-peer -> node iperf3: ${gbps} Gbit/s $([ -n "$gbps" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"

rate=$(${D}-node sh -c "curl -s -o /dev/null -w '%{speed_download}' http://172.30.2.12/dataset.bin" 2>/dev/null)
mbs=$(python3 -c "print(round(float('${rate:-0}')/1e6,1))" 2>/dev/null)
echo "  storage   node <- storage-srv dataset: ${mbs} MB/s $([ -n "$rate" ] && [ "${rate%%.*}" -gt 0 ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"

if ${D}-oob-mgmt ping -c 2 -W 2 10.99.0.11 >/dev/null 2>&1; then
  echo "  oob       mgmt -> BMC ping: reachable - OK" | tee -a "${SUM}"
else
  echo "  oob       mgmt -> BMC ping: unreachable - FAIL" | tee -a "${SUM}"
fi

echo "=== The VRF fences the BMC ===" | tee -a "${SUM}"
if ${D}-node ping -c 2 -W 2 10.99.0.100 >/dev/null 2>&1; then
  echo "  node default VRF -> oob-mgmt: REACHABLE - FAIL (should be fenced)" | tee -a "${SUM}"
else
  echo "  node default VRF -> oob-mgmt: unreachable - OK" | tee -a "${SUM}"
fi
if ${D}-node ip vrf exec mgmt ping -c 2 -W 2 10.99.0.100 >/dev/null 2>&1; then
  echo "  node vrf mgmt    -> oob-mgmt: reachable - OK" | tee -a "${SUM}"
else
  echo "  node vrf mgmt    -> oob-mgmt: unreachable - FAIL" | tee -a "${SUM}"
fi

echo "=== Isolation matrix (packets on each fabric, by subnet family) ===" | tee -a "${SUM}"
for lf in fe-leaf be-leaf st-leaf oob-sw; do
  ${SSH} cumulus@clab-${LAB}-${lf} "sudo timeout 10 tcpdump -i swp1 -w /tmp/m.pcap ip" >/dev/null 2>&1 &
done
sleep 2
${D}-gpu-peer sh -c "iperf3 -c 172.31.1.11 -B 172.31.1.12 -t 6 >/dev/null 2>&1" &
${D}-node sh -c "curl -s -o /dev/null http://172.30.2.12/dataset.bin" &
for i in 1 2 3; do ${D}-client curl -s -o /dev/null http://172.16.10.11/; done
${D}-oob-mgmt ping -c 5 -i 0.5 10.99.0.11 >/dev/null 2>&1
wait
printf "  %-8s %10s %10s %10s %10s\n" "capture" "frontend" "backend" "storage" "oob" | tee -a "${SUM}"
for lf in fe-leaf be-leaf st-leaf oob-sw; do
  counts=$(${SSH} cumulus@clab-${LAB}-${lf} "sudo tcpdump -r /tmp/m.pcap -n 2>/dev/null | awk '
    / 172\.16\./  {fe++}
    / 172\.31\.1\./ {be++}
    / 172\.30\./  {st++}
    / 10\.99\.0\./ {ob++}
    END {printf \"%d %d %d %d\", fe, be, st, ob}'" 2>/dev/null | grep -v -e Warning -e Welcome | tail -1)
  printf "  %-8s %10s %10s %10s %10s\n" "${lf}" ${counts:-? ? ? ?} | tee -a "${SUM}"
done

echo | tee -a "${SUM}"
echo "Audit written to ${OUT}/"
