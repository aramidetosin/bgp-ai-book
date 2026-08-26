#!/usr/bin/env bash
# Exercise 2 verifier: rerun the spine01-to-leaf01 link failure with BGP
# packet capture running on every device, then count the UPDATE messages
# that actually crossed each fabric link.
#
# Captures run inside the switches (Cumulus Linux ships tcpdump). Counting
# uses tcpdump's BGP decoder: every "Update Message" line in the decoded
# output is one UPDATE on the wire.
set -euo pipefail

LAB=bgpbook-ch01
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@"
DUR=25

echo "Starting ${DUR}s captures on all fabric ports..."
${SSH}clab-${LAB}-spine01 "sudo timeout ${DUR} tcpdump -i any -w /tmp/spine01.pcap port 179" >/dev/null 2>&1 &
${SSH}clab-${LAB}-spine02 "sudo timeout ${DUR} tcpdump -i any -w /tmp/spine02.pcap port 179" >/dev/null 2>&1 &
${SSH}clab-${LAB}-leaf01  "sudo timeout ${DUR} tcpdump -i any -w /tmp/leaf01.pcap  port 179" >/dev/null 2>&1 &
${SSH}clab-${LAB}-leaf03  "sudo timeout ${DUR} tcpdump -i any -w /tmp/leaf03.pcap  port 179" >/dev/null 2>&1 &
sleep 5

echo "Failing the spine01-to-leaf01 link..."
${SSH}clab-${LAB}-spine01 "sudo ip link set swp1 down"
sleep $((DUR))

echo "Healing the link..."
${SSH}clab-${LAB}-spine01 "sudo ip link set swp1 up"

echo
echo "UPDATE messages seen on the wire during the failure window:"
for node in spine01 spine02 leaf01 leaf03; do
  count=$(${SSH}clab-${LAB}-${node} "sudo tcpdump -r /tmp/${node}.pcap -vv 2>/dev/null | grep -c 'Update Message'" || true)
  echo "  ${node}: ${count}"
done
echo
echo "Compare these with your prediction from the worked example."
echo "Remember spine01 and leaf01 each see their own links only, and"
echo "a message appears once at its sender and once at its receiver."
