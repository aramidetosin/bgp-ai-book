#!/usr/bin/env bash
# Chapter 8, policy pinning: the lab-scale stand-in for traffic-engineered
# balancing. Pin server02's flows toward server01's subnet to spine01 on
# leaf02, and verify with ip route get, traceroutes, and counters.
#
# Two acts, both recorded. Act one configures the platform's PBR: the
# daemon accepts it and reports Installed, but the route it writes into
# the policy table is an IPv4 default via an IPv6 link-local next hop,
# which this kernel will not match through an ip rule, so nothing is
# actually pinned; ip route get is the witness. Act two pins with the
# kernel's own policy routing, a specific prefix via the same link-local
# next hop, which the kernel honors. Evidence under audits/pin/.
set -uo pipefail

LAB=bgpbook-ch08
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
OUT=audits/pin
mkdir -p "${OUT}"

routes() {
  echo "--- six traceroutes, middle hop only ($1) ---"
  for i in 1 2 3 4 5 6; do
    ${D}-server02 traceroute -n -q 1 -m 3 172.16.1.11 2>/dev/null | awk 'NR==3 {print "  run '"$i"': " $2}'
  done
}

verdict() {
  echo "--- the kernel's own verdict: ip route get ($1) ---"
  ${SSH} cumulus@clab-${LAB}-leaf02 "ip route get 172.16.1.11 from 172.16.2.11 iif swp1" 2>/dev/null | head -1 | sed 's/^/  /'
}

flows() {
  local slug=$1
  ${SSH} cumulus@clab-${LAB}-leaf02 "for p in swp2 swp3; do echo -n \"\$p \"; cat /sys/class/net/\$p/statistics/tx_bytes; done" 2>/dev/null > "${OUT}/.before"
  ${D}-server02 iperf3 -c 172.16.1.11 -P 8 -t 8 > "${OUT}/iperf_${slug}.txt" 2>&1
  ${SSH} cumulus@clab-${LAB}-leaf02 "for p in swp2 swp3; do echo -n \"\$p \"; cat /sys/class/net/\$p/statistics/tx_bytes; done" 2>/dev/null > "${OUT}/.after"
  python3 - "${OUT}/.before" "${OUT}/.after" <<'PY'
import sys
b = dict(l.split() for l in open(sys.argv[1]))
a = dict(l.split() for l in open(sys.argv[2]))
d = {p: int(a[p]) - int(b[p]) for p in b}
tot = sum(d.values()) or 1
print("  eight iperf3 flows, leaf02's split:")
for p, v in sorted(d.items()):
    print(f"    {p}  {v/1e6:8.1f} MB  {100*v/tot:5.1f}%")
PY
}

${D}-server01 pkill iperf3 2>/dev/null
sleep 1
${D}-server01 iperf3 -s -D

LL=$(${SSH} cumulus@clab-${LAB}-leaf02 "ip -6 neigh show dev swp2 | awk '/^fe80/{print \$1; exit}'" 2>/dev/null)

{
  echo "=== Before any pin: ECMP decides ==="
  verdict "baseline"
  flows before

  echo
  echo "=== Act one: the platform's PBR, configured and believed ==="
  echo "  spine01's link-local on swp2: ${LL}"
  ${SSH} cumulus@clab-${LAB}-leaf02 "nv set router pbr enable on && \
    nv set router nexthop group VIA-SPINE01 via ${LL} interface swp2 && \
    nv set router pbr map PIN rule 10 match source-ip 172.16.2.11/32 && \
    nv set router pbr map PIN rule 10 match destination-ip 172.16.1.0/24 && \
    nv set router pbr map PIN rule 10 action nexthop-group VIA-SPINE01 && \
    nv set interface swp1 router pbr map PIN && \
    nv config apply -y" >/dev/null 2>&1
  sleep 30
  until ${SSH} cumulus@clab-${LAB}-leaf02 "ip route show 172.16.1.0/24 | grep -q nhid" 2>/dev/null; do sleep 3; done
  echo "  --- what the daemon believes ---"
  ${SSH} cumulus@clab-${LAB}-leaf02 "sudo vtysh -c 'show pbr map'" 2>/dev/null | sed 's/^/  /'
  echo "  --- what the daemon installed ---"
  ${SSH} cumulus@clab-${LAB}-leaf02 "ip rule show | grep 10000; ip route show table 10000" 2>/dev/null | sed 's/^/  /'
  verdict "with PBR applied"
  flows pbr

  echo
  echo "=== Act two: the kernel's policy routing, a specific prefix ==="
  ${SSH} cumulus@clab-${LAB}-leaf02 "nv unset interface swp1 router pbr && \
    nv unset router pbr map PIN && \
    nv unset router nexthop group VIA-SPINE01 && \
    nv unset router pbr enable && \
    nv config apply -y" >/dev/null 2>&1
  sleep 30
  until ${SSH} cumulus@clab-${LAB}-leaf02 "ip route show 172.16.1.0/24 | grep -q nhid" 2>/dev/null; do sleep 3; done
  echo "  \$ sudo ip route add 172.16.1.0/24 via inet6 ${LL} dev swp2 table 200"
  echo "  \$ sudo ip rule add from 172.16.2.11/32 to 172.16.1.0/24 iif swp1 table 200 priority 250"
  ${SSH} cumulus@clab-${LAB}-leaf02 "sudo ip route add 172.16.1.0/24 via inet6 ${LL} dev swp2 table 200 && \
    sudo ip rule add from 172.16.2.11/32 to 172.16.1.0/24 iif swp1 table 200 priority 250" 2>&1 | grep -v "Warning:\|Welcome to" | sed 's/^/  /'
  verdict "with the kernel pin"
  routes "pinned"
  flows pinned
} | tee "${OUT}/pin.txt"
rm -f "${OUT}/.before" "${OUT}/.after"
echo "Evidence written to ${OUT}/"
