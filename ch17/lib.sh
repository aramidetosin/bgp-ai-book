#!/usr/bin/env bash
set -uo pipefail
LAB=${LAB:-bgpbook-ch17}
PASS=${PASS:-Clab123!}
sw(){ sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-${LAB}-$1 "sudo $2" 2>/dev/null; }
