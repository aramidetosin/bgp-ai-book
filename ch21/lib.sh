#!/usr/bin/env bash
set -uo pipefail
LAB=${LAB:-bgpbook-ch16}
PASS=${PASS:-Clab123!}
_ssh(){ local h=$1; shift; sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 cumulus@clab-${LAB}-"$h" "$@"; }
COL(){ docker exec clab-${LAB}-server01 "$@"; }
