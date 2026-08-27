#!/usr/bin/env bash
# Undo break10a.sh.
set -uo pipefail
LAB=bgpbook-ch10
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
${K} patch ciliumbgpclusterconfig rack2 --type json \
  -p '[{"op":"replace","path":"/spec/bgpInstances/0/peers/0/peerASN","value":65102}]' >/dev/null
sleep 20
echo "healed: rack2 peers with 65102 again"
