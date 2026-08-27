#!/usr/bin/env bash
# Chapter 8, weighted ECMP: fail one of leaf01's two spine02-facing links,
# watch leaf02 keep splitting 50/50 while the capacity behind spine02 has
# halved, then let the spines advertise their real path counts with the
# link bandwidth extended community and watch the weights and the traffic
# follow. Evidence under audits/wecmp/.
set -uo pipefail

LAB=bgpbook-ch08
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
D="docker exec clab-${LAB}"
OUT=audits/wecmp
mkdir -p "${OUT}"

# leaf02's forwarding view: the route, and the kernel next-hop group it
# points at (where the weights live).
fan() {
  ${SSH} cumulus@clab-${LAB}-leaf02 \
    "r=\$(ip route show 172.16.1.0/24); echo \"\$r\"; id=\$(echo \$r | sed -n 's/.*nhid \([0-9]*\).*/\1/p'); [ -n \"\$id\" ] && ip nexthop show id \$id" 2>/dev/null | sed 's/^/  /'
}

# One snapshot covers all three vantage points: leaf02's two uplinks, and
# each spine's transmit counters toward leaf01.
snap() {
  {
    echo "leaf02.swp2 $(${SSH} cumulus@clab-${LAB}-leaf02 'cat /sys/class/net/swp2/statistics/tx_bytes' 2>/dev/null)"
    echo "leaf02.swp3 $(${SSH} cumulus@clab-${LAB}-leaf02 'cat /sys/class/net/swp3/statistics/tx_bytes' 2>/dev/null)"
    ${SSH} cumulus@clab-${LAB}-spine01 "for p in swp1 swp2; do echo spine01.\$p \$(cat /sys/class/net/\$p/statistics/tx_bytes); done" 2>/dev/null
    ${SSH} cumulus@clab-${LAB}-spine02 "for p in swp1 swp2; do echo spine02.\$p \$(cat /sys/class/net/\$p/statistics/tx_bytes); done" 2>/dev/null
  } > "$1"
}

measure() {
  local label=$1 slug=$2
  echo "--- ${label}: iperf3 -P 8 -t 8, server02 -> server01 ---"
  snap "${OUT}/.before"
  ${D}-server02 iperf3 -c 172.16.1.11 -P 8 -t 8 > "${OUT}/iperf_${slug}.txt" 2>&1
  snap "${OUT}/.after"
  python3 - "${OUT}/.before" "${OUT}/.after" <<'PY'
import sys
b = dict(l.split() for l in open(sys.argv[1]))
a = dict(l.split() for l in open(sys.argv[2]))
d = {p: int(a[p]) - int(b[p]) for p in b}
l2 = {p: v for p, v in d.items() if p.startswith("leaf02")}
tot = sum(l2.values()) or 1
print("  leaf02's split across the spines:")
for p, v in sorted(l2.items()):
    print(f"    {p}  {v/1e6:8.1f} MB  {100*v/tot:5.1f}%")
print("  per surviving link toward leaf01:")
for p, v in sorted(d.items()):
    if p.startswith("spine") and v > 1e6:
        print(f"    {p}  {v/1e6:8.1f} MB")
PY
  echo
}

${D}-server01 pkill iperf3 2>/dev/null
sleep 1
${D}-server01 iperf3 -s -D

{
  echo "=== Phase 0: the healthy fabric ==="
  fan
  measure "baseline" phase0

  echo "=== Phase 1: leaf01 swp5 down (spine02 keeps one path to leaf01) ==="
  ${SSH} cumulus@clab-${LAB}-leaf01 "nv set interface swp5 link state down && nv config apply -y" >/dev/null 2>&1
  sleep 8
  fan
  measure "after the failure, no weighting" phase1

  echo "=== Phase 2: the spines advertise their real capacity ==="
  for sp in spine01 spine02; do
    ${SSH} cumulus@clab-${LAB}-${sp} "nv set router policy route-map LINKBW rule 10 action permit && \
      nv set router policy route-map LINKBW rule 10 set ext-community-bw multipaths && \
      nv set vrf default router bgp neighbor swp3 address-family ipv4-unicast policy outbound route-map LINKBW && \
      nv config apply -y" >/dev/null 2>&1
  done
  sleep 8
  echo "  --- leaf02's view of 172.16.1.0/24 in BGP ---"
  ${SSH} cumulus@clab-${LAB}-leaf02 "sudo vtysh -c 'show ip bgp 172.16.1.0/24'" 2>/dev/null | sed 's/^/  /'
  echo "  --- and in the forwarding table ---"
  fan
  measure "weighted" phase2
} | tee "${OUT}/wecmp.txt"
rm -f "${OUT}/.before" "${OUT}/.after"
echo "Evidence written to ${OUT}/"
