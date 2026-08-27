#!/usr/bin/env bash
# Chapter 10 audit: fabric green, cluster Ready, agents running, pod
# routes present across the fabric. Evidence under audits/.
set -uo pipefail

LAB=bgpbook-ch10
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch10_audit_${TS}
mkdir -p "${OUT}/raw"
SUM="${OUT}/summary.txt"

echo "=== Fabric BGP sessions ===" | tee -a "${SUM}"
for pair in leaf01:4 leaf02:3 leaf03:2 spine01:3 spine02:3; do
  dev=${pair%%:*}; want=${pair##*:}
  ${SSH} cumulus@clab-${LAB}-${dev} "sudo vtysh -c 'show bgp summary json'" 2>/dev/null > "${OUT}/raw/${dev}_bgp.json"
  est=$(python3 -c "import json;d=json.load(open('${OUT}/raw/${dev}_bgp.json'))['ipv4Unicast']['peers'];print(sum(1 for p in d.values() if p['state']=='Established'))" 2>/dev/null)
  echo "  ${dev}: ${est}/${want} Established $([ "${est}" = "${want}" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
done

echo "=== The cluster ===" | tee -a "${SUM}"
ready=$(${K} get nodes --no-headers 2>/dev/null | grep -c " Ready")
echo "  nodes Ready: ${ready}/3 $([ "${ready}" = "3" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"
cil=$(${K} -n kube-system get pods -l k8s-app=cilium --no-headers 2>/dev/null | grep -c Running)
echo "  cilium agents Running: ${cil}/3 $([ "${cil}" = "3" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"

echo "=== Pod routes across the fabric ===" | tee -a "${SUM}"
pods=$(${SSH} cumulus@clab-${LAB}-leaf03 "ip route show | grep -c 10.244" 2>/dev/null)
echo "  leaf03 pod /24s: ${pods} $([ "${pods}" -ge "2" ] && echo '- OK' || echo '- FAIL')" | tee -a "${SUM}"

echo "=== Cabling versus intent (LLDP) ===" | tee -a "${SUM}"
./verify_lldp.sh > "${OUT}/raw/lldp_verify.txt" 2>&1
tail -1 "${OUT}/raw/lldp_verify.txt" | sed 's/^/  /' | tee -a "${SUM}"

echo | tee -a "${SUM}"
echo "Audit written to ${OUT}/"
