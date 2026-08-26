#!/usr/bin/env bash
# Chapter 1 lab: push the NVUE configuration to every switch.
# Run after `containerlab deploy`. Idempotent: re-running reapplies the same config.
set -euo pipefail

LAB=bgpbook-ch01
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@"

nv() { # nv <node> "<command>;<command>;..."
  local node=$1; shift
  ${SSH}clab-${LAB}-${node} "$*"
}

configure_leaf() { # configure_leaf <name> <index> <asn>
  local name=$1 idx=$2 asn=$3
  nv "$name" "
    nv set system hostname ${name} &&
    nv set interface lo ip address 10.0.0.${idx}/32 &&
    nv set interface swp1 ip address 172.16.${idx}.1/24 &&
    nv set interface swp2,swp3 &&
    nv set router bgp autonomous-system ${asn} &&
    nv set router bgp router-id 10.0.0.${idx} &&
    nv set vrf default router bgp neighbor swp2 remote-as external &&
    nv set vrf default router bgp neighbor swp3 remote-as external &&
    nv set vrf default router bgp address-family ipv4-unicast redistribute connected &&
    nv config apply -y"
}

configure_spine() { # configure_spine <name> <index>
  local name=$1 idx=$2
  nv "$name" "
    nv set system hostname ${name} &&
    nv set interface lo ip address 10.0.0.10${idx}/32 &&
    nv set interface swp1,swp2,swp3,swp4 &&
    nv set router bgp autonomous-system 65100 &&
    nv set router bgp router-id 10.0.0.10${idx} &&
    nv set vrf default router bgp neighbor swp1 remote-as external &&
    nv set vrf default router bgp neighbor swp2 remote-as external &&
    nv set vrf default router bgp neighbor swp3 remote-as external &&
    nv set vrf default router bgp neighbor swp4 remote-as external &&
    nv set vrf default router bgp address-family ipv4-unicast redistribute connected &&
    nv config apply -y"
}

configure_leaf leaf01 1 65101 &
configure_leaf leaf02 2 65102 &
configure_leaf leaf03 3 65103 &
configure_leaf leaf04 4 65104 &
configure_spine spine01 1 &
configure_spine spine02 2 &
wait
echo "All switches configured."
