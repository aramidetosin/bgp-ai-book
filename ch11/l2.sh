#!/usr/bin/env bash
# Chapter 11, the layer 2 announcement path: a leader-elected node
# answers ARP for the VIP on leaf01's segment. Records the lease, the
# client's ARP table, the stream working from the same segment, the
# routed client served only through the segment gateway (the trombone),
# and the leader-death takeover gap, measured. Evidence under audits/l2/.
set -uo pipefail

LAB=bgpbook-ch10
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
VIP=172.16.1.200
OUT=audits/l2
mkdir -p "${OUT}"

echo "=== The policy: label the service, apply the announcement ==="
docker exec -i node01 kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f - < manifests/l2policy.yaml
# Leadership is first-come and sticky; pin it briefly to node02 so the
# takeover test later can freeze a worker rather than the control plane.
${K} patch ciliuml2announcementpolicy rack1-l2 --type merge \
  -p '{"spec":{"nodeSelector":{"matchLabels":{"kubernetes.io/hostname":"node02"}}}}' >/dev/null
sleep 12
${K} patch ciliuml2announcementpolicy rack1-l2 --type merge \
  -p '{"spec":{"nodeSelector":{"matchLabels":{"rack":"rack1"}}}}' >/dev/null
sleep 5

{
  echo "=== Who answers: the lease names the leader ==="
  ${K} -n kube-system get leases | head -1
  ${K} -n kube-system get leases | grep l2announce
  echo
  echo "=== The client's view: one ARP entry, one node's MAC ==="
  ${D}-client01 sh -c "ping -c 2 -W 2 ${VIP} >/dev/null 2>&1; arp -n | head -1; arp -n | grep ${VIP}"
  echo "--- the nodes' MACs, for comparison ---"
  for n in node01 node02; do
    echo "  ${n} eth1: $(docker exec ${n} cat /sys/class/net/eth1/address)"
  done
  echo
  echo "=== The stream, from the same segment ==="
  ${D}-client01 sh -c "curl -sN --max-time 4 http://${VIP}/ | head -3"
  echo
  echo "=== The routed client: served, but every packet trombones through leaf01 ==="
  ${D}-client02 sh -c "curl -sN --max-time 4 http://${VIP}/ -o /tmp/o 2>/dev/null; echo \"  tokens received in 4 seconds: \$(grep -c token /tmp/o)\"; head -1 /tmp/o 2>/dev/null"
} | tee "${OUT}/l2_state.txt"

echo
echo "=== The takeover, measured: freeze the leader mid-ping ==="
LEADER=$(${K} -n kube-system get lease -o custom-columns=N:.metadata.name,H:.spec.holderIdentity --no-headers | awk '/l2announce.*inference-l2/{print $2}')
[ -z "${LEADER}" ] && LEADER=$(${K} -n kube-system get leases | awk '/l2announce/{print $1}' | head -1)
echo "  leader: ${LEADER}"
{
  # The VIP answers its service port, not ICMP, so the probe is a curl
  # loop: 0.3-second polls, one-second timeout, logged with timestamps.
  # A poll succeeds if the service answers with HTTP 200 inside a second
  # (the stream itself runs ten; the probe only samples the front door).
  ${D}-client01 sh -c "rm -f /tmp/takeover.log; ( for i in \$(seq 1 120); do \
    code=\$(curl -s --max-time 1 -o /dev/null -w '%{http_code}' http://${VIP}/); \
    if [ \"\$code\" = \"200\" ]; then echo \"\$(date +%s.%N) ok\"; \
    else echo \"\$(date +%s.%N) FAIL\"; fi; sleep 0.3; done ) > /tmp/takeover.log 2>&1 &"
  sleep 5
  echo "--- the leader's segment NIC dies five seconds in ---"
  docker exec ${LEADER} ip link set eth1 down
  sleep 20
  echo "--- the lease, mid-failure (does it move?) ---"
  ${K} -n kube-system get leases | grep l2announce
  echo "--- the client's ARP entry now ---"
  ${D}-client01 sh -c "arp -n | grep ${VIP} || echo '  (no entry)'"
  sleep 25
  docker exec ${LEADER} ip link set eth1 up
  # a link bounce clears the via-eth1 static routes; restore them
  docker exec ${LEADER} sh -c "ip route replace 172.16.0.0/16 via 172.16.1.1 dev eth1; ip route replace 10.244.0.0/16 via 172.16.1.1 dev eth1"
  sleep 15
  echo "--- the probe's log around the freeze ---"
  ${D}-client01 sh -c "grep -c ok /tmp/takeover.log; grep -c FAIL /tmp/takeover.log" | paste -d/ - - | sed 's|^|  polls ok/FAIL: |'
  ${D}-client01 sh -c "awk 'prev==\"ok\" && \$2==\"FAIL\" {print \"  first failure:  \" \$1} prev==\"FAIL\" && \$2==\"ok\" {print \"  recovered at:   \" \$1} {prev=\$2}' /tmp/takeover.log | head -4"
  echo "--- the lease after ---"
  ${K} -n kube-system get leases | grep l2announce
} | tee "${OUT}/takeover.txt"
echo "Evidence written to ${OUT}/"
