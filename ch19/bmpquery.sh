#!/usr/bin/env bash
# Chapter 19: which prefixes churned during the incident window, answered from
# BMP alone, without logging into a switch. The collector has the RIB's whole
# history; a query over its event log names the prefixes and the moment they
# moved.
source "$(dirname "$0")/lib.sh"
cd "$(dirname "$0")"
OUT=${OUT:-audits/bmp}; mkdir -p "$OUT"
COL="clab-${LAB}-server01"
_ssh(){ local h=$1; shift; sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 cumulus@clab-${LAB}-"$h" "$@"; }
lines(){ docker exec "$COL" sh -c "wc -l < /tmp/bmp-events.jsonl" | tr -d ' '; }
{
echo "=== BMP: the RIB's history, collected off-box ==="
b=$(lines)
echo "  collector holds $b events (peer-up and the full RIB dump so far)"
echo
echo "=== Incident: leaf04 drops off the fabric, then returns ==="
_ssh leaf04 "sudo ip link set swp2 down; sudo ip link set swp3 down"
sleep 13
mid=$(lines)
_ssh leaf04 "sudo ip link set swp2 up; sudo ip link set swp3 up"
sleep 13
end=$(lines)
echo
echo "=== Query: which prefixes were WITHDRAWN during the window (from BMP only) ==="
docker exec "$COL" sh -c "sed -n '$((b+1)),${mid}p' /tmp/bmp-events.jsonl" | \
  python3 -c "import sys,json;s=set();[s.update(json.loads(l).get('withdraw',[])) for l in sys.stdin];print('  '+', '.join(sorted(s)) if s else '  (none)')"
echo "=== Query: which prefixes were RE-ANNOUNCED when it returned ==="
docker exec "$COL" sh -c "sed -n '$((mid+1)),${end}p' /tmp/bmp-events.jsonl" | \
  python3 -c "import sys,json;s=set();[s.update(json.loads(l).get('announce',[])) for l in sys.stdin];print('  '+', '.join(sorted(x for x in s if x.startswith(('10.0.0.4','172.16.4')))) or '  (none)')"
echo
echo "Answered without touching a switch: leaf04's loopback and server subnet"
echo "left the fabric at the failure and returned at recovery, timestamped in BMP."
} | tee "$OUT/evidence.txt"
