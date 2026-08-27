#!/usr/bin/env bash
# Apply one tuning step to every fabric session, both ends, and record the
# commands. Steps:
#   timers    keepalive 1, hold 3
#   connect   connection-retry 1
#   bfd       enable BFD with platform default intervals
#   bfd-fast  BFD 50 ms intervals, multiplier 2 (the over-tuning candidate)
#   defaults  put timers and connection-retry back, disable BFD
set -euo pipefail
STEP=${1:?usage: tune.sh timers|connect|bfd|bfd-fast|defaults}
LAB=bgpbook-ch06
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
mkdir -p audits/tuning
F="audits/tuning/apply_${STEP}.txt"
: > "${F}"

# device -> its fabric-facing ports
ports() {
  case $1 in
    leaf*)  echo "swp2 swp3" ;;
    spine*) echo "swp1 swp2 swp3 swp4" ;;
  esac
}

cmds_for() {
  local port=$1
  local n="nv set vrf default router bgp neighbor ${port}"
  case ${STEP} in
    timers)   echo "${n} timers keepalive 1 && ${n} timers hold 3" ;;
    connect)  echo "${n} timers connection-retry 1" ;;
    bfd)      echo "${n} bfd enable on" ;;
    bfd-fast) echo "${n} bfd enable on && ${n} bfd min-rx-interval 50 && ${n} bfd min-tx-interval 50 && ${n} bfd detect-multiplier 2" ;;
    defaults) echo "nv unset vrf default router bgp neighbor ${port} timers && nv unset vrf default router bgp neighbor ${port} bfd" ;;
  esac
}

for dev in leaf01 leaf02 leaf03 leaf04 spine01 spine02; do
  all=""
  for port in $(ports ${dev}); do
    all="${all}$(cmds_for ${port}) && "
  done
  echo "== ${dev} ==" >> "${F}"
  echo "${all}nv config apply -y" | tr '&' '\n' | grep -v '^ *$' | sed 's/^ *//' >> "${F}"
  ${SSH} cumulus@clab-${LAB}-${dev} "${all}nv config apply -y" >/dev/null 2>&1 \
    && echo "${dev}: applied ${STEP}" | tee -a "${F}" \
    || echo "${dev}: FAILED" | tee -a "${F}"
done
echo "recorded ${F}"
