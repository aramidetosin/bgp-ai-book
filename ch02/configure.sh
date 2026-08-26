#!/usr/bin/env bash
# Apply the finished chapter 2 configuration (the unnumbered triangle) to all
# three switches. The chapter walks you through building this by hand; this
# script is the solution key, and `make solution` calls it.
set -euo pipefail

LAB=bgpbook-ch02
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@"

for node in r1 r2 r3; do
  (
    cmds=$(sed 's/$/ \&\&/' "bootstrap/${node}.cfg" | tr '\n' ' ')
    ${SSH}clab-${LAB}-${node} "${cmds} nv config apply -y" \
      && echo "${node}: solution applied"
  ) &
done
wait
echo "All switches configured with the finished triangle."
