#!/usr/bin/env bash
# Chapter 12, the edge recorded: the border's two policies at work, the
# chain of defaults, one customer request traced end to end (session
# table included), the dark traceroute, and both NATs proven on the
# wire. Evidence under audits/edge/.
set -uo pipefail
cd "$(dirname "$0")"
source ./pa.sh

LAB=bgpbook-ch12
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
OUT=audits/edge
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

ACTIVE=172.20.40.11
[ "$(pa_state 172.20.40.12)" = "active" ] && ACTIVE=172.20.40.12

# A unit that was briefly active during boot can linger in neighbor
# caches; refresh both sides so traffic follows the current active.
${D}-upstream01 ip neigh flush dev br0 2>/dev/null
sw border01 "sudo ip neigh flush dev vlan10" >/dev/null 2>&1

{
  echo "=== The border's contract, from both sides of the session ==="
  echo "--- what the provider offered, and what the border accepted (default only) ---"
  sw border01 "sudo vtysh -c 'show ip bgp neighbors 203.0.113.1 routes' | tail -6"
  echo "--- what the border announced, and nothing else ---"
  sw border01 "sudo vtysh -c 'show ip bgp neighbors 203.0.113.1 advertised-routes' | tail -6"
  echo "--- the provider's own filter agrees (received vs accepted) ---"
  ${D}-upstream01 vtysh -c "show ip bgp neighbors 172.31.1.0 received-routes" 2>/dev/null | tail -6
  ${D}-upstream01 vtysh -c "show ip bgp neighbors 172.31.1.0 routes" 2>/dev/null | tail -4
} | tee "${OUT}/contract.txt"

{
  echo "=== The chain of defaults: provider to border to leaf to host ==="
  echo "--- border01 ---"
  sw border01 "ip route show default"
  echo "--- leaf01 ---"
  sw leaf01 "ip route show default"
  echo "--- intserver01 ---"
  ${D}-intserver01 ip route show default
} | tee "${OUT}/defaults.txt"

{
  echo "=== One customer request, end to end ==="
  echo "--- the client fetches the public address ---"
  ${D}-extclient01 sh -c "curl -s --max-time 5 http://203.0.113.100/"
  echo "--- the active firewall's session table entry, mid-request ---"
  ${D}-extclient01 sh -c "curl -s --max-time 10 http://203.0.113.100/ -o /dev/null --limit-rate 1k &"
  sleep 2
  pa_op ${ACTIVE} "<show><session><all><filter><destination>203.0.113.100</destination></filter></all></session></show>" \
    | python3 -c "import sys,xml.dom.minidom; print(xml.dom.minidom.parseString(sys.stdin.read()).toprettyxml(indent='  '))" 2>/dev/null \
    | grep -E "<application|<state|<from|<to|<source>|<dst>|<xsource|<xdst|<sport|<dport|<xsport|<xdport|<srczone|<dstzone|<type" | head -18
} | tee "${OUT}/request.txt"

{
  echo "=== What the trace cannot show: dark past the provider, by design ==="
  ${D}-extclient01 sh -c "traceroute -n -q 1 -w 2 -m 6 203.0.113.100 2>/dev/null"
} | tee "${OUT}/dark_trace.txt"

{
  echo "=== The NATs, on the wire ==="
  echo "--- inbound (DNAT): what the server actually receives ---"
  ${D}-intserver01 sh -c "timeout 6 tcpdump -c 2 -n -i eth1 'tcp port 80' 2>/dev/null" &
  CAP=$!
  sleep 1
  ${D}-extclient01 curl -s --max-time 4 http://203.0.113.100/ -o /dev/null
  wait ${CAP}
  echo "--- outbound (SNAT): what the internet sees of the cluster ---"
  ${D}-extclient01 sh -c "timeout 6 tcpdump -c 2 -n -i eth1 'tcp port 80' 2>/dev/null" &
  CAP=$!
  sleep 1
  ${D}-intserver01 curl -s --max-time 4 http://198.51.100.11/ -o /dev/null
  wait ${CAP}
} | tee "${OUT}/nats.txt"
echo "Evidence written to ${OUT}/"
