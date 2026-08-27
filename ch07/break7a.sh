#!/usr/bin/env bash
# break-7a: a VNI mismatch. leaf04's TENANTA L3VNI moves to 4009 while
# leaf01 keeps 4001: the classic one-side typo. The auto-derived route
# targets no longer match, so leaf01 stops importing leaf04's routed
# tenant routes: the type-5 destination dies while the stretched layer 2
# segment, whose L2VNI still matches, keeps working. TENANTB never
# notices. Evidence under audits/break7a/. heal restores 4001.
set -uo pipefail
MODE=${1:-break}
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
mkdir -p audits/break7a

if [ "${MODE}" = "heal" ]; then
  ${SSH} cumulus@clab-${LAB}-leaf04 \
    "nv config detach >/dev/null 2>&1; nv unset vrf TENANTA evpn vni 4009 && nv set vrf TENANTA evpn vni 4001 && nv config apply -y" >/dev/null 2>&1 \
    && echo "healed: leaf04 TENANTA back on L3VNI 4001"
  exit 0
fi

F=audits/break7a/evidence.txt
: > "${F}"
echo '$ nv unset vrf TENANTA evpn vni 4001 && nv set vrf TENANTA evpn vni 4009 && nv config apply -y   (leaf04: the typo)' >> "${F}"
${SSH} cumulus@clab-${LAB}-leaf04 \
  "nv config detach >/dev/null 2>&1; nv unset vrf TENANTA evpn vni 4001 && nv set vrf TENANTA evpn vni 4009 && nv config apply -y" >/dev/null 2>&1
sleep 30

{
  echo
  echo '$ sudo ip vrf exec TENANTA ping -c 3 -W 2 -I 10.201.1.1 10.201.4.1   (leaf01: the routed tenant destination, dead)'
  ${SSH} cumulus@clab-${LAB}-leaf01 "sudo ip vrf exec TENANTA ping -c 3 -W 2 -I 10.201.1.1 10.201.4.1" 2>&1 | tail -2
  echo
  echo '$ sudo ip vrf exec TENANTA ping -c 3 -W 2 10.200.1.4   (leaf01: the stretched segment, still alive on the L2VNI)'
  ${SSH} cumulus@clab-${LAB}-leaf01 "sudo ip vrf exec TENANTA ping -c 3 -W 2 10.200.1.4" 2>&1 | tail -2
  echo
  echo '$ sudo ip vrf exec TENANTB ping -c 3 -W 2 10.200.1.4   (leaf01: tenant B, untouched)'
  ${SSH} cumulus@clab-${LAB}-leaf01 "sudo ip vrf exec TENANTB ping -c 3 -W 2 10.200.1.4" 2>&1 | tail -2
  echo
  echo '$ ip route show vrf TENANTA 10.201.4.1   (leaf01: the route is gone from the VRF)'
  ${SSH} cumulus@clab-${LAB}-leaf01 "ip route show vrf TENANTA 10.201.4.1" 2>&1 | grep -v Warning | grep -v Welcome
  echo
  echo '$ sudo vtysh -c "show bgp l2vpn evpn route type prefix" | grep -A 3 "\[10.201.4.1\]"   (leaf01: still in the EVPN table, with the tell)'
  ${SSH} cumulus@clab-${LAB}-leaf01 "sudo vtysh -c 'show bgp l2vpn evpn route type prefix'" 2>/dev/null | grep -A 3 "\[10.201.4.1\]" | head -8
  echo
  echo '$ sudo vtysh -c "show evpn vni"   (leaf04: the mismatch in plain sight)'
  ${SSH} cumulus@clab-${LAB}-leaf04 "sudo vtysh -c 'show evpn vni'" 2>/dev/null | grep -v Warning | grep -v Welcome
} >> "${F}"
cat "${F}"
echo "recorded ${F}"
