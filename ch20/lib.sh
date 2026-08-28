#!/usr/bin/env bash
set -uo pipefail
LAB=${LAB:-bgpbook-ch09}
PASS=${PASS:-Clab123!}
HOST=${HOST:-host01}      # the routed host we treat as compromised
LEAF=${LEAF:-leaf01}      # its ToR
S(){ sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 cumulus@clab-${LAB}-"$LEAF" "sudo vtysh $*"; }
H(){ docker exec clab-${LAB}-"$HOST" vtysh "$@"; }
# accepted-prefix count on the host-facing session
accepted(){ S -c "'show bgp ipv4 unicast neighbor swp1 json'" 2>/dev/null | python3 -c "import sys,json;d=json.load(sys.stdin);n=list(d.values())[0] if d else {};print(n.get('pfxRcd', n.get('prefixReceivedCount','?')))" 2>/dev/null; }
