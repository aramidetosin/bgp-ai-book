#!/usr/bin/env bash
# Chapter 9, exercise 1 recorded: BFD on the host sessions, then the
# same NIC pull as routed.sh, so the two loss counts sit side by side.
# Run after routed.sh. Evidence under audits/bfd/.
set -uo pipefail

LAB=bgpbook-ch09
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
OUT=audits/bfd
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== BFD on, both ends of both host sessions ==="
for i in 1 2; do
  sw leaf0${i} "nv set vrf default router bgp neighbor swp1 bfd enable on && nv config apply -y" >/dev/null
done
${D}-host01 vtysh -c "conf t" -c "router bgp 65500" \
  -c "neighbor eth1 bfd" -c "neighbor eth2 bfd" >/dev/null 2>&1
sleep 12

{
  echo "=== The BFD peers, from the host ==="
  ${D}-host01 vtysh -c "show bfd peers brief"
  echo
  echo "=== The same pull, with BFD watching ==="
  ${D}-server03 sh -c "ping -i 0.2 -c 100 172.16.101.1 > /tmp/bfd_ping.txt 2>&1" &
  PING_PID=$!
  sleep 5
  echo "--- pulling host01 eth1 at packet ~25 ---"
  ${D}-host01 ip link set eth1 down
  wait ${PING_PID}
  ${D}-server03 tail -3 /tmp/bfd_ping.txt
  echo "--- restoring eth1 ---"
  ${D}-host01 ip link set eth1 up
} | tee "${OUT}/nic_pull_bfd.txt"
echo "Evidence written to ${OUT}/"
