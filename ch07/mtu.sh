#!/usr/bin/env bash
# The encapsulation headroom, measured: inner packets that fit the tenant
# MTU but not tenant MTU plus VXLAN overhead die in encapsulation. The
# underlay runs 9216 end to end (the book's standing discipline), so the
# boundary sits just under it. Records pass and fail sizes.
set -uo pipefail
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
mkdir -p audits/overlay
F=audits/overlay/mtu_probe.txt
: > "${F}"

probe() {
  local size=$1
  echo "\$ sudo ip vrf exec TENANTA ping -c 2 -W 2 -M do -s ${size} 10.200.1.4" >> "${F}"
  if ${SSH} cumulus@clab-${LAB}-leaf01 "sudo ip vrf exec TENANTA ping -c 2 -W 2 -M do -s ${size} 10.200.1.4" >> "${F}" 2>&1; then
    echo "size ${size}: PASS" | tee -a "${F}"
  else
    echo "size ${size}: FAIL" | tee -a "${F}"
  fi
  echo >> "${F}"
}

probe 9100
probe 9188
echo "recorded ${F}"
