#!/usr/bin/env bash
# Chapter 1 fabric audit. Run on the containerlab host after `make up`.
# Writes audits/ch01_audit_<timestamp>/summary.txt plus raw JSON for every claim.
# Convention follows ecloud-containerlab: every chapter ships an audit whose
# output backs the examples printed in the chapter.
set -uo pipefail

LAB=bgpbook-ch01
PASS=${CL_PASS:-Clab123!}
SSH="sshpass -p ${PASS} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
TS=$(date +%Y%m%d_%H%M%S)
OUT=audits/ch01_audit_${TS}
mkdir -p "${OUT}/raw"
SUM="${OUT}/summary.txt"

declare -A ROLE=( [leaf01]="cumulus leaf, AS 65101" [leaf02]="cumulus leaf, AS 65102" \
                  [leaf03]="cumulus leaf, AS 65103" [leaf04]="cumulus leaf, AS 65104" \
                  [spine01]="cumulus spine, AS 65100" [spine02]="cumulus spine, AS 65100" )

for node in spine01 spine02 leaf01 leaf02 leaf03 leaf04; do
  echo "=== ${node} (${ROLE[$node]}) ===" | tee -a "${SUM}"
  ${SSH} cumulus@clab-${LAB}-${node} "sudo vtysh -c 'show bgp summary json'" \
    2>/dev/null > "${OUT}/raw/${node}_bgp_summary.json"
  python3 - "${OUT}/raw/${node}_bgp_summary.json" <<'PY' | tee -a "${SUM}"
import json, sys
d = json.load(open(sys.argv[1]))["ipv4Unicast"]
peers = d.get("peers", {})
est = sum(1 for p in peers.values() if p.get("state") == "Established")
print(f"  BGP ipv4 sessions: {est} Established / {len(peers)} configured"
      + ("  - OK" if est == len(peers) and est > 0 else "  - FAIL"))
PY
done

echo "=== ECMP spot checks (each leaf's route to every other server subnet) ===" | tee -a "${SUM}"
for node in leaf01 leaf02 leaf03 leaf04; do
  for net in 172.16.1.0 172.16.2.0 172.16.3.0 172.16.4.0; do
    own="172.16.${node#leaf0}.0"; [ "${net}" = "${own%.*}.0" ] 2>/dev/null && continue
    [ "${net}" = "172.16.$((10#${node:5:2})).0" ] && continue
    ${SSH} cumulus@clab-${LAB}-${node} "sudo vtysh -c 'show ip route ${net}/24 json'" \
      2>/dev/null > "${OUT}/raw/${node}_route_${net}.json"
    python3 - "${OUT}/raw/${node}_route_${net}.json" "${node}" "${net}" <<'PY' | tee -a "${SUM}"
import json, sys
routes = json.load(open(sys.argv[1]))
nh = 0
for entries in routes.values():
    for e in entries:
        if e.get("selected"): nh = len(e.get("nexthops", []))
ok = "OK" if nh == 2 else "FAIL"
print(f"  {sys.argv[2]} -> {sys.argv[3]}/24: {nh} next-hop(s) - {ok}")
PY
  done
done

echo "=== Data plane ===" | tee -a "${SUM}"
for pair in "server01 172.16.3.10" "server03 172.16.1.10"; do
  src=${pair%% *}; dst=${pair##* }
  loss=$(docker exec clab-${LAB}-${src} ping -c 4 -W 2 "${dst}" \
    | tee "${OUT}/raw/ping_${src}_to_${dst}.txt" | grep -oE '[0-9]+% packet loss')
  echo "  ${src} -> ${dst}: ${loss}" | tee -a "${SUM}"
done

echo
echo "Audit written to ${OUT}/"
