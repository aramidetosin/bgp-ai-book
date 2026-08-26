#!/usr/bin/env bash
# Undo break-2a.
set -euo pipefail
LAB=bgpbook-ch02
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@"

${SSH}clab-${LAB}-r2 "sudo ip6tables -D INPUT -i swp1 -p tcp --dport 179 -j DROP; \
  sudo ip6tables -D INPUT -i swp1 -p tcp --sport 179 -j DROP; true"
echo "break-2a healed. The session will re-establish on its own."
