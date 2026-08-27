#!/usr/bin/env bash
# Chapter 12 break-fix: short requests work, every long transfer dies
# mid-flight. The cause: the service host's NIC was "fixed" to the
# fabric-standard 9216, its jumbo segments die inside the edge, and the
# firewall says nothing about packets it will not carry: the classic
# path-MTU blackhole at a security boundary. Evidence under
# audits/break12a/.
set -uo pipefail
cd "$(dirname "$0")"
source ./pa.sh

LAB=bgpbook-ch12
D="docker exec clab-${LAB}"
OUT=audits/break12a
mkdir -p "${OUT}"

echo "=== The well-meant mistake: the server joins the fabric's 9216 standard ==="
${D}-intserver01 ip link set eth1 mtu 9216
${D}-intserver01 sh -c "[ -s /www/big.bin ] || dd if=/dev/urandom of=/www/big.bin bs=1M count=60 2>/dev/null"
sleep 3

{
  echo "=== The symptom pair ==="
  echo "--- a short request works ---"
  ${D}-extclient01 sh -c "curl -s --max-time 5 http://203.0.113.100/"
  echo "--- a long transfer dies mid-flight ---"
  ${D}-extclient01 sh -c "rm -f /tmp/big.bin; curl -s --max-time 20 http://203.0.113.100/big.bin -o /tmp/big.bin; echo \"  curl exit: \$?\"; echo \"  bytes received: \$(wc -c < /tmp/big.bin 2>/dev/null | tr -d ' ') of 62914560\""
  echo
  echo "=== The investigation, from the server outward ==="
  echo "--- the interface, freshly standardized ---"
  ${D}-intserver01 sh -c "ip link show eth1 | head -1"
  echo "--- the server keeps sending big frames; nothing but silence comes back ---"
  ${D}-intserver01 timeout 8 tcpdump -c 6 -n -i eth1 "(tcp port 80 and greater 2000) or icmp" 2>/dev/null &
  CAP=$!
  sleep 1
  ${D}-extclient01 sh -c "curl -s --max-time 6 http://203.0.113.100/big.bin -o /dev/null"
  wait ${CAP}
  echo "--- no ICMP fragmentation-needed arrives: the edge ate the hint ---"
} | tee "${OUT}/evidence.txt"
echo
echo "break-12a armed and recorded. make heal-12a undoes it."
