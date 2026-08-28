#!/usr/bin/env bash
# Chapter 15 shared helpers. Runs on the containerlab host.
# The communities contract and the anycast local-pref steering are applied
# here as NVUE policy, idempotently (detach clears any pending revision).
set -uo pipefail
LAB=bgpbook-ch15
PASS=${PASS:-Clab123!}
VIP=100.64.0.1
SA_PEER=10.255.0.1   # sb-border, from sa-border
SB_PEER=10.255.0.0   # sa-border, from sb-border

_ssh(){ local node=$1; shift; sshpass -p "${PASS}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-${LAB}-${node} "$@"; }
sw(){ _ssh "$1" "sudo $2" 2>/dev/null; }         # run sudo cmd on a node, quiet
vt(){ _ssh "$1" "sudo vtysh -c \"$2\"" 2>/dev/null; }  # run one vtysh command

# origin tagging at a compute leaf: VIP + server subnet get WAN-OK (64512:1),
# the backend prefix gets SITE-LOCAL (64512:9). Applied to redistribute connected.
apply_origin(){ local host=$1 vip=$2 srv=$3 backend=$4
  sw "$host" "bash -c \"
nv config detach 2>/dev/null
nv set router policy prefix-list PL-VIP rule 10 action permit
nv set router policy prefix-list PL-VIP rule 10 match ${vip}/32
nv set router policy prefix-list PL-SERVER rule 10 action permit
nv set router policy prefix-list PL-SERVER rule 10 match ${srv}
nv set router policy prefix-list PL-BACKEND rule 10 action permit
nv set router policy prefix-list PL-BACKEND rule 10 match ${backend}
nv set router policy route-map ORIGIN rule 10 match type ipv4
nv set router policy route-map ORIGIN rule 10 match ip-prefix-list PL-BACKEND
nv set router policy route-map ORIGIN rule 10 action permit
nv set router policy route-map ORIGIN rule 10 set community 64512:9
nv set router policy route-map ORIGIN rule 20 match type ipv4
nv set router policy route-map ORIGIN rule 20 match ip-prefix-list PL-VIP
nv set router policy route-map ORIGIN rule 20 action permit
nv set router policy route-map ORIGIN rule 20 set community 64512:1
nv set router policy route-map ORIGIN rule 30 match type ipv4
nv set router policy route-map ORIGIN rule 30 match ip-prefix-list PL-SERVER
nv set router policy route-map ORIGIN rule 30 action permit
nv set router policy route-map ORIGIN rule 30 set community 64512:1
nv set router policy route-map ORIGIN rule 40 action permit
nv set vrf default router bgp address-family ipv4-unicast redistribute connected route-map ORIGIN
nv config apply -y\"" >/dev/null 2>&1
}

# the contract at a border: across the WAN, permit only WAN-OK (64512:1),
# both directions. Everything else (backends, loopbacks) is dropped.
apply_filter(){ local host=$1 peer=$2
  sw "$host" "bash -c \"
nv config detach 2>/dev/null
nv set router policy community-list CL-WANOK rule 10 action permit
nv set router policy community-list CL-WANOK rule 10 community 64512:1
nv set router policy route-map WAN-OUT rule 10 match type ipv4
nv set router policy route-map WAN-OUT rule 10 match community-list CL-WANOK
nv set router policy route-map WAN-OUT rule 10 action permit
nv set vrf default router bgp neighbor ${peer} address-family ipv4-unicast policy outbound route-map WAN-OUT
nv set vrf default router bgp neighbor ${peer} address-family ipv4-unicast policy inbound route-map WAN-OUT
nv config apply -y\"" >/dev/null 2>&1
}
remove_filter(){ local host=$1 peer=$2
  sw "$host" "bash -c \"
nv config detach 2>/dev/null
nv unset vrf default router bgp neighbor ${peer} address-family ipv4-unicast policy outbound route-map 2>/dev/null
nv unset vrf default router bgp neighbor ${peer} address-family ipv4-unicast policy inbound route-map 2>/dev/null
nv config apply -y\"" >/dev/null 2>&1
}

# break-15a: a blanket local-preference 200 on the WAN inbound, applied too
# broadly, so the WAN copy of the anycast VIP beats the local one.
apply_break(){ local host=$1 peer=$2
  sw "$host" "bash -c \"
nv config detach 2>/dev/null
nv set router policy route-map WAN-IN-BUG rule 10 match type ipv4
nv set router policy route-map WAN-IN-BUG rule 10 match community-list CL-WANOK
nv set router policy route-map WAN-IN-BUG rule 10 action permit
nv set router policy route-map WAN-IN-BUG rule 10 set local-preference 200
nv set vrf default router bgp neighbor ${peer} address-family ipv4-unicast policy inbound route-map WAN-IN-BUG
nv config apply -y\"" >/dev/null 2>&1
}
heal_break(){ local host=$1 peer=$2
  sw "$host" "bash -c \"
nv config detach 2>/dev/null
nv set vrf default router bgp neighbor ${peer} address-family ipv4-unicast policy inbound route-map WAN-OUT
nv config apply -y\"" >/dev/null 2>&1
}

# emulated WAN latency: netem delay on each border's WAN-facing swp2.
netem_on(){ local ms=${1:-20}
  sw sa-border "tc qdisc replace dev swp2 root netem delay ${ms}ms" >/dev/null 2>&1
  sw sb-border "tc qdisc replace dev swp2 root netem delay ${ms}ms" >/dev/null 2>&1
}

apply_contract(){ apply_origin sa-leaf 100.64.0.1 172.16.1.0/24 10.99.1.0/24
  apply_origin sb-leaf 100.64.0.1 172.17.1.0/24 10.99.2.0/24
  apply_filter sa-border "$SA_PEER"; apply_filter sb-border "$SB_PEER"; }
