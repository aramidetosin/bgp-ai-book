#!/usr/bin/env bash
# Undo wecmp.sh: leaf01 swp5 back up, the link bandwidth route-maps off
# the spines. The fabric returns to the audited baseline.
set -uo pipefail

LAB=bgpbook-ch08
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"

${SSH} cumulus@clab-${LAB}-leaf01 "nv unset interface swp5 link state && nv config apply -y" >/dev/null 2>&1
for sp in spine01 spine02; do
  ${SSH} cumulus@clab-${LAB}-${sp} "nv unset vrf default router bgp neighbor swp3 address-family ipv4-unicast policy outbound route-map && \
    nv unset router policy route-map LINKBW && nv config apply -y" >/dev/null 2>&1
done
sleep 8
${SSH} cumulus@clab-${LAB}-leaf02 "ip route show 172.16.1.0/24" 2>/dev/null
echo "healed: swp5 up, route-maps removed"
