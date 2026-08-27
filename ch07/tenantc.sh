#!/usr/bin/env bash
# Exercise 1 recorded: a third tenant with a type-5 export, on leaf01
# only. leaf04 receives the route in its EVPN table but installs nothing,
# because no local VRF imports that route target: export travels the
# fabric, import is a local decision. Then the tenant is removed.
set -uo pipefail
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
mkdir -p audits/overlay
F=audits/overlay/tenantc_type5.txt
: > "${F}"

CMDS="nv set vrf TENANTC evpn enable on && \
nv set vrf TENANTC evpn vni 4003 && \
nv set vrf TENANTC loopback ip address 10.203.1.1/32 && \
nv set vrf TENANTC router bgp enable on && \
nv set vrf TENANTC router bgp address-family ipv4-unicast enable on && \
nv set vrf TENANTC router bgp address-family ipv4-unicast redistribute connected enable on && \
nv set vrf TENANTC router bgp address-family ipv4-unicast route-export to-evpn enable on &&"

echo "== TENANTC applied on leaf01 only ==" >> "${F}"
echo "${CMDS}" | tr '&' '\n' | grep -v '^ *$' | sed 's/^ *//' >> "${F}"
${SSH} cumulus@clab-${LAB}-leaf01 "${CMDS} nv config apply -y" >/dev/null 2>&1 \
  && echo "leaf01: TENANTC applied" | tee -a "${F}"
sleep 20

{
  echo
  echo '$ sudo vtysh -c "show bgp l2vpn evpn route type prefix" | grep -B 1 -A 4 10.203.1.1   (leaf04)'
  ${SSH} cumulus@clab-${LAB}-leaf04 "sudo vtysh -c 'show bgp l2vpn evpn route type prefix'" 2>/dev/null | grep -B 1 -A 4 "10.203.1.1"
  echo
  echo '$ ip route show vrf TENANTA 10.203.1.1; ip vrf show   (leaf04: in the EVPN table, installed nowhere)'
  ${SSH} cumulus@clab-${LAB}-leaf04 "ip route show vrf TENANTA 10.203.1.1; ip vrf show" 2>&1
} >> "${F}"

# remove the tenant again
${SSH} cumulus@clab-${LAB}-leaf01 "nv unset vrf TENANTC && nv config apply -y" >/dev/null 2>&1 \
  && echo "leaf01: TENANTC removed" | tee -a "${F}"
cat "${F}"
