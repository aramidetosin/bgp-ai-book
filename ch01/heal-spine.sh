#!/usr/bin/env bash
# Bring spine01 back after `make fail-spine`.
#
# Three things break when a vrnetlab node's container stops, and all three
# need fixing, in order:
#   1. The container itself: restart it (restart also recovers a launcher
#      that stalled waiting for interfaces).
#   2. The veth links: they died with the old network namespace. Recreate
#      them with containerlab's veth tool, using the CONTAINER-side names,
#      which are eth1..ethN (the VM maps them to swp names internally).
#      They must exist within the launcher's startup wait, so this script
#      creates them immediately after the restart.
#   3. The far ends: each leaf's new eth2 needs its tc redirect to the VM
#      tap rebuilt, because the old rules pointed at the destroyed device.
set -euo pipefail

LAB=bgpbook-ch01

docker restart clab-${LAB}-spine01 > /dev/null
echo "spine01 restarted"

for i in 1 2 3 4; do
  sudo containerlab tools veth create \
    -a clab-${LAB}-spine01:eth${i} -b clab-${LAB}-leaf0${i}:eth2
done

for l in leaf01 leaf02 leaf03 leaf04; do
  docker exec clab-${LAB}-${l} sh -c '
    ip link set eth2 up
    ip link set eth2 mtu 65000
    ip -6 addr flush eth2
    tc qdisc add dev eth2 clsact 2>/dev/null || true
    tc filter add dev eth2 ingress flower action mirred egress redirect dev tap2
    tc filter del dev tap2 ingress 2>/dev/null || true
    tc filter add dev tap2 ingress flower action mirred egress redirect dev eth2'
  echo "${l}: link to spine01 rebound"
done

echo "spine01 is booting; give it about two minutes, then run ./audit.sh"
