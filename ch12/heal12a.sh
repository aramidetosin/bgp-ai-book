#!/usr/bin/env bash
# Undo break12a.sh: the edge-facing service host returns to the path's
# real MTU.
set -uo pipefail
LAB=bgpbook-ch12
D="docker exec clab-${LAB}"
${D}-intserver01 ip link set eth1 mtu 1500
sleep 2
${D}-extclient01 sh -c "rm -f /tmp/big.bin; curl -s --max-time 60 http://203.0.113.100/big.bin -o /tmp/big.bin && echo \"healed: \$(wc -c < /tmp/big.bin | tr -d ' ') bytes fetched through the edge\""
