#!/usr/bin/env bash
# Fallback: apply every generated bootstrap config over SSH, for images
# without the startup-config patch. Run gen_topo.py first.
set -euo pipefail
LAB=bgpbook-ch05
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@"

for cfg in bootstrap/*.cfg; do
  node=$(basename "${cfg}" .cfg)
  cmds=$(sed 's/$/ \&\&/' "${cfg}" | tr '\n' ' ')
  ${SSH}clab-${LAB}-${node} "${cmds} nv config apply -y" && echo "${node}: configured"
done
