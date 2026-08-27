#!/usr/bin/env bash
# Chapter 11, the BGP announcement path: the VIP becomes a /32 in the
# fabric, advertised by every node under eTP Cluster. Records the filter
# growing to admit the service range (a deliberate step), the anycast
# routes on a remote leaf, the routed client working, and the node-death
# withdrawal gap. Evidence under audits/bgpsvc/.
set -uo pipefail

LAB=bgpbook-ch10
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
VIP=172.16.200.1
OUT=audits/bgpsvc
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

echo "=== Step 1: the filter grows: the service range joins the contract ==="
for dev in leaf01 leaf02; do
  sw ${dev} "nv set router policy prefix-list PODS-IN rule 20 action permit && \
    nv set router policy prefix-list PODS-IN rule 20 match 172.16.200.0/24 min-prefix-len 32 && \
    nv set router policy prefix-list PODS-IN rule 20 match 172.16.200.0/24 max-prefix-len 32 && \
    nv set router policy prefix-list PODS-IN rule 21 action permit && \
    nv set router policy prefix-list PODS-IN rule 21 match 172.16.1.200/32 && \
    nv config apply -y" >/dev/null
  echo "  ${dev}: import now allows pod /24s plus service /32s"
done

echo "=== Step 2: the advertisement ==="
docker exec -i node01 kubectl --kubeconfig /etc/kubernetes/admin.conf apply -f - < manifests/svc-advert.yaml
sleep 15

{
  echo "=== The VIP in the fabric: anycast from every node ==="
  echo "--- leaf01 (two node sessions) ---"
  sw leaf01 "sudo vtysh -c 'show ip bgp ${VIP}/32' | grep -E 'Paths|655|from'"
  echo "--- leaf03 (no nodes; the routes crossed the fabric) ---"
  sw leaf03 "r=\$(ip route show ${VIP}); echo \"\$r\"; id=\$(echo \$r | sed -n 's/.*nhid \([0-9]*\).*/\1/p'); [ -n \"\$id\" ] && ip nexthop show id \$id"
  echo
  echo "=== The routed client, now served ==="
  ${D}-client02 sh -c "curl -sN --max-time 4 http://${VIP}/ | head -2"
} | tee "${OUT}/bgp_state.txt"

echo
echo "=== The withdrawal, measured: a serving node freezes mid-probes ==="
{
  ${D}-client02 sh -c "rm -f /tmp/withdraw.log; ( for i in \$(seq 1 120); do \
    code=\$(curl -s --max-time 1 -o /dev/null -w '%{http_code}' http://${VIP}/); \
    if [ \"\$code\" = \"200\" ]; then echo \"\$(date +%s) ok\"; \
    else echo \"\$(date +%s) FAIL\"; fi; sleep 0.3; done ) > /tmp/withdraw.log 2>&1 &"
  sleep 5
  echo "--- freezing node03 five seconds in ---"
  docker pause node03 >/dev/null
  sleep 40
  echo "--- leaf02's session to the frozen node ---"
  sw leaf02 "sudo vtysh -c 'show bgp summary' | tail -4"
  echo "--- leaf03's paths now (node03's gone) ---"
  sw leaf03 "r=\$(ip route show ${VIP}); echo \"\$r\"; id=\$(echo \$r | sed -n 's/.*nhid \([0-9]*\).*/\1/p'); [ -n \"\$id\" ] && ip nexthop show id \$id"
  sleep 15
  docker unpause node03 >/dev/null
  sleep 20
  echo "--- probe verdict ---"
  ${D}-client02 sh -c "echo \"  polls ok: \$(grep -c ok /tmp/withdraw.log)  FAIL: \$(grep -c FAIL /tmp/withdraw.log)\"; \
    awk 'prev==\"ok\" && \$2==\"FAIL\" {f=\$1} prev==\"FAIL\" && \$2==\"ok\" && f {print \"  outage: \" \$1-f \" seconds\"; f=0} {prev=\$2}' /tmp/withdraw.log | head -4"
} | tee "${OUT}/withdraw.txt"
echo "Evidence written to ${OUT}/"
