#!/usr/bin/env bash
# Undo pin.sh: remove the kernel policy rule and table (act two), and any
# leftover NVUE PBR state (act one). leaf02 forwards by ECMP again.
set -uo pipefail

LAB=bgpbook-ch08
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

${SSH} cumulus@clab-${LAB}-leaf02 "sudo ip rule del priority 250 2>/dev/null; \
  sudo ip route flush table 200 2>/dev/null; \
  nv unset interface swp1 router pbr 2>/dev/null; \
  nv unset router pbr map PIN 2>/dev/null; \
  nv unset router nexthop group VIA-SPINE01 2>/dev/null; \
  nv unset router pbr enable 2>/dev/null; \
  nv config apply -y >/dev/null 2>&1; \
  ip route get 172.16.1.11 from 172.16.2.11 iif swp1 | head -1"
echo "unpinned: leaf02 forwards by ECMP again"
