#!/usr/bin/env bash
# The chapter's whole move: add an EVPN overlay to the running chapter 6
# underlay, as recorded steps. Two tenants on leaf01 and leaf04:
#   TENANTA  routed tenant: vlan 100 / L2VNI 10100, L3VNI 4001, SVIs
#            10.200.1.1 and .4/24, a VRF loopback per leaf exported as a
#            type-5 route.
#   TENANTB  stretched layer 2 only: vlan 200 / L2VNI 10200, SVIs on the
#            SAME 10.200.1.0/24 subnet as TENANTA, which is the isolation
#            proof: overlapping addresses, never meeting.
# Spines carry the new address family and nothing else. The wire capture
# records the OPEN renegotiation when the address family activates.
# Every command lands in audits/overlay/apply_overlay.txt.
set -uo pipefail
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
mkdir -p audits/overlay
F=audits/overlay/apply_overlay.txt
: > "${F}"

apply() {
  local dev=$1; shift
  local cmds="$*"
  echo "== ${dev} ==" >> "${F}"
  echo "${cmds}" | tr '&' '\n' | grep -v '^ *$' | sed 's/^ *//' >> "${F}"
  ${SSH} cumulus@clab-${LAB}-${dev} "${cmds} nv config apply -y" >/dev/null 2>&1 \
    && echo "${dev}: applied" | tee -a "${F}" \
    || echo "${dev}: FAILED" | tee -a "${F}"
}

AF="nv set vrf default router bgp address-family l2vpn-evpn enable on"
nbr_af() { echo "nv set vrf default router bgp neighbor $1 address-family l2vpn-evpn enable on"; }

leaf_tenants() {
  local n=$1   # 1 or 4
  echo "nv set evpn enable on && \
nv set evpn route-advertise svi-ip on && \
nv set nve vxlan enable on && \
nv set nve vxlan source address 10.0.0.${n} && \
nv set bridge domain br_default vlan 100 vni 10100 && \
nv set bridge domain br_default vlan 200 vni 10200 && \
nv set vrf TENANTA evpn enable on && \
nv set vrf TENANTA evpn vni 4001 && \
nv set vrf TENANTA loopback ip address 10.201.${n}.1/32 && \
nv set vrf TENANTA router bgp enable on && \
nv set vrf TENANTA router bgp address-family ipv4-unicast enable on && \
nv set vrf TENANTA router bgp address-family ipv4-unicast redistribute connected enable on && \
nv set vrf TENANTA router bgp address-family ipv4-unicast route-export to-evpn enable on && \
nv set interface vlan100 ip vrf TENANTA && \
nv set interface vlan100 ip address 10.200.1.${n}/24 && \
nv set vrf TENANTB table auto && \
nv set interface vlan200 ip vrf TENANTB && \
nv set interface vlan200 ip address 10.200.1.${n}/24 && \
$(nbr_af swp2) && $(nbr_af swp3) && ${AF} &&"
}

# Start the wire capture on leaf01 before its session renegotiates, so the
# new OPEN (with the l2vpn evpn capability) lands in the recording.
${SSH} cumulus@clab-${LAB}-leaf01 \
  "sudo sh -c 'nohup timeout 90 tcpdump -i swp2 -c 60 -vv -w /tmp/evpn_open.pcap port 179 >/dev/null 2>&1 &'" 2>/dev/null
echo "capture armed on leaf01 swp2" | tee -a "${F}"
sleep 2

apply leaf01  "$(leaf_tenants 1)"
apply spine01 "$(nbr_af swp1) && $(nbr_af swp2) && $(nbr_af swp3) && $(nbr_af swp4) && ${AF} &&"
apply spine02 "$(nbr_af swp1) && $(nbr_af swp2) && $(nbr_af swp3) && $(nbr_af swp4) && ${AF} &&"
apply leaf04  "$(leaf_tenants 4)"

echo "waiting for sessions and the overlay to settle" | tee -a "${F}"
sleep 45
${SSH} cumulus@clab-${LAB}-leaf01 \
  "sudo tcpdump -r /tmp/evpn_open.pcap -vv 2>/dev/null | grep -A 12 'BGP.*Open' | head -40" \
  > audits/overlay/open_capture.txt 2>&1
echo "OPEN capture in audits/overlay/open_capture.txt" | tee -a "${F}"
echo "recorded ${F}"
