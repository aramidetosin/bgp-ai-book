#!/usr/bin/env bash
# Undo break11a.sh: three spread replicas again.
set -uo pipefail
LAB=bgpbook-ch10
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
${K} delete deploy inference --wait=true >/dev/null 2>&1
${K} delete pods -l '!app,run notin (walk-a walk-b)' --field-selector status.phase=Running >/dev/null 2>&1
docker exec -i node01 kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f - < manifests/streamer.yaml >/dev/null
${K} rollout status deploy/inference --timeout=120s >/dev/null 2>&1
sleep 10
echo "healed: three replicas, spread; the VIP is anycast again"
