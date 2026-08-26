#!/usr/bin/env bash
# Fallback: apply the two leafs' bootstrap configs over SSH, for images
# without the startup-config patch.
set -euo pipefail
LAB=bgpbook-ch04
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@"

for node in fe-leaf be-leaf st-leaf oob-sw; do
  cmds=$(sed 's/$/ \&\&/' "bootstrap/${node}.cfg" | tr '\n' ' ')
  ${SSH}clab-${LAB}-${node} "${cmds} nv config apply -y" && echo "${node}: configured"
done
