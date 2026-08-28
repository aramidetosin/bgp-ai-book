#!/usr/bin/env bash
# Chapter 13 hardware evidence collector. Read-only show/dump commands
# only, run against the backend RoCE switch (Enterprise SONiC on a
# Supermicro SSE-T8164, Broadcom ASIC) over the office jump host. No
# configuration is changed. Output lands in this directory; the
# chapter quotes it verbatim.
#
# The switch is reached as admin@<mgmt-ip> from the jump host. Set
# SONIC_HOST and SONIC_PASS for your own testbed.
set -uo pipefail
JUMP=${JUMP:-eve-office}
SONIC_HOST=${SONIC_HOST:-172.16.99.43}
SONIC_PASS=${SONIC_PASS:-iPKP7bhXDmhrwk8WgwFz2jJX}
HERE=$(cd "$(dirname "$0")" && pwd)
SW="sshpass -p '${SONIC_PASS}' ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=15 admin@${SONIC_HOST}"

run() { ssh ${JUMP} "${SW} '$1'" 2>/dev/null; }

run 'show version | head -12'                                    > "${HERE}/version.txt"
run 'show interfaces status | head -20'                          > "${HERE}/ifstatus.txt"
for T in DSCP_TO_TC_MAP TC_TO_QUEUE_MAP TC_TO_PRIORITY_GROUP_MAP WRED_PROFILE \
         BUFFER_PROFILE BUFFER_POOL SCHEDULER CABLE_LENGTH PFC_WD; do
  echo "==== ${T}"; run "sonic-cfggen -d --var-json \"${T}\""
done > "${HERE}/qos_config.txt"
run 'sonic-cfggen -d --var-json "PORT_QOS_MAP" | head -12'       > "${HERE}/port_qos_map_sample.txt"
run 'show pfc counters | head -10'                               > "${HERE}/pfc_counters.txt"
run 'show queue counters Ethernet0'                              > "${HERE}/queue_counters_eth0.txt"
run 'show interfaces counters | head -8'                         > "${HERE}/iface_counters.txt"
echo "collected into ${HERE}/"
