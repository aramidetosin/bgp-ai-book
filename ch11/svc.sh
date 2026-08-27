#!/usr/bin/env bash
# Chapter 11: deploy the mock inference service and the address pool on
# the chapter 10 cluster. Evidence under audits/svc/.
set -uo pipefail

LAB=bgpbook-ch10
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
OUT=audits/svc
mkdir -p "${OUT}"

docker exec -i node01 kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f - < manifests/streamer.yaml
${K} rollout status deploy/inference --timeout=180s >/dev/null 2>&1
sleep 5

{
  echo "=== The service and its backends ==="
  ${K} get svc inference -o wide | sed 's/  */ /g'
  ${K} get pods -l app=inference -o wide --no-headers | awk '{print "  "$1" "$3" "$7}'
} | tee "${OUT}/svc.txt"
echo "Evidence written to ${OUT}/"
