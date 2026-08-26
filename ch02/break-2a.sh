#!/usr/bin/env bash
# Break-fix 2a: r1's session toward r2 gets stuck in a TCP-layer failure.
# The fault is deliberately NOT in BGP configuration. Diagnose it from r1
# before you read this file any further.
#
# (Spoiler below.)
#
#
#
# What it does: drops TCP port 179 in both directions on r2's swp1 with
# ip6tables (the unnumbered session runs over IPv6 link-local), so neither
# side's connection attempt can complete and the session cycles through
# Connect/Active forever. heal-2a.sh removes exactly these rules.
set -euo pipefail
LAB=bgpbook-ch02
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@"

${SSH}clab-${LAB}-r2 "sudo ip6tables -I INPUT -i swp1 -p tcp --dport 179 -j DROP && \
  sudo ip6tables -I INPUT -i swp1 -p tcp --sport 179 -j DROP && \
  sudo vtysh -c 'clear bgp swp1' >/dev/null"
echo "break-2a armed. Go look at r1."
