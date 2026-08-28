#!/usr/bin/env bash
# Undo break13a.sh: leaf02 maps switch-priority 3 back to queue 3.
set -uo pipefail
LAB=bgpbook-ch13
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
${SSH} cumulus@clab-${LAB}-leaf02 "nv config detach; nv set qos egress-queue-mapping default-global switch-priority 3 traffic-class 3 && nv config apply -y" >/dev/null 2>&1
sleep 4
echo "healed: leaf02 maps switch-priority 3 to queue 3 again"
