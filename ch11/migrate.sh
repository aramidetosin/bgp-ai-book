#!/usr/bin/env bash
# Chapter 11, the live migration of inference-l2, both directions, with
# a probe running from the routed client the whole time. Make before
# break: add the second path's label, wait for it to carry, remove the
# first. The probe polls every half second and logs every failure.
# Evidence under audits/migrate/.
set -uo pipefail

LAB=bgpbook-ch10
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
D="docker exec clab-${LAB}"
K="docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf"
VIP=172.16.1.200
OUT=audits/migrate
mkdir -p "${OUT}"
sw() { ${SSH} cumulus@clab-${LAB}-$1 "$2" 2>/dev/null; }

{
  echo "=== The probe: client02, every half second, throughout ==="
  ${D}-client02 sh -c "rm -f /tmp/probe.log; ( for i in \$(seq 1 200); do \
    code=\$(curl -s --max-time 1 -o /dev/null -w '%{http_code}' http://${VIP}/); \
    if [ \"\$code\" = \"200\" ]; then echo ok; else echo FAIL; fi; sleep 0.5; done ) > /tmp/probe.log 2>&1 &"
  sleep 6

  echo
  echo "=== Migration 1: L2 to BGP, make before break ==="
  echo "--- make: the service joins the BGP advertisement ---"
  ${K} label svc inference-l2 expose-bgp=true --overwrite >/dev/null
  sleep 12
  echo "--- verify: the /32 exists in the fabric before the L2 path goes ---"
  sw leaf03 "ip route show ${VIP}"
  echo "--- break: the L2 label comes off; the lease follows ---"
  ${K} label svc inference-l2 expose-l2- >/dev/null
  sleep 15
  echo "--- state: BGP only ---"
  sw leaf03 "ip route show ${VIP}"

  echo
  echo "=== Migration 2: back to L2, the same choreography reversed ==="
  ${K} label svc inference-l2 expose-l2=true --overwrite >/dev/null
  sleep 12
  ${K} label svc inference-l2 expose-bgp- >/dev/null
  sleep 15
  echo "--- state: the /32 is gone from the fabric; ARP answers again ---"
  sw leaf03 "ip route show ${VIP}; echo '  (no route: the fabric reaches it as part of 172.16.1.0/24 again)'"

  echo
  echo "=== The probe's verdict ==="
  ${D}-client02 sh -c "sleep 3; total=\$(wc -l < /tmp/probe.log | tr -d ' '); fails=\$(grep -c FAIL /tmp/probe.log); echo \"  polls: \$total  failed: \$fails\""
} | tee "${OUT}/migrate.txt"
echo "Evidence written to ${OUT}/"
