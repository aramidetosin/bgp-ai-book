#!/usr/bin/env bash
# Chapter 7 trace: the overlay, seen from the boxes.
set -uo pipefail
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
OUT=audits/e2e_trace_ch07_$(date +%Y%m%d)
mkdir -p "${OUT}/raw"

run() { echo "\$ $2" > "${OUT}/raw/$1"; eval "$2" >> "${OUT}/raw/$1" 2>&1; }

run leaf01_summary.txt   "${SSH} cumulus@clab-${LAB}-leaf01 \"sudo vtysh -c 'show bgp summary' | sed -n '/L2VPN EVPN Summary/,\\\$p'\""
run leaf04_evpn_table.txt "${SSH} cumulus@clab-${LAB}-leaf04 \"sudo vtysh -c 'show bgp l2vpn evpn'\""
run leaf04_type5.txt     "${SSH} cumulus@clab-${LAB}-leaf04 \"sudo vtysh -c 'show bgp l2vpn evpn route type prefix'\""
run leaf01_vnis.txt      "${SSH} cumulus@clab-${LAB}-leaf01 \"sudo vtysh -c 'show evpn vni'\""
run leaf01_vrf_a.txt     "${SSH} cumulus@clab-${LAB}-leaf01 'ip route show vrf TENANTA'"
run leaf01_vrf_b.txt     "${SSH} cumulus@clab-${LAB}-leaf01 'ip route show vrf TENANTB'"
run tenant_a_ping.txt    "${SSH} cumulus@clab-${LAB}-leaf01 'sudo ip vrf exec TENANTA ping -c 3 10.200.1.4'"
run tenant_b_ping.txt    "${SSH} cumulus@clab-${LAB}-leaf01 'sudo ip vrf exec TENANTB ping -c 3 10.200.1.4'"
run underlay_route.txt   "${SSH} cumulus@clab-${LAB}-leaf01 \"sudo vtysh -c 'show ip route 10.0.0.4'\""

echo "Raw trace outputs in ${OUT}/raw/. Write TRACE.md from them; never from memory."
