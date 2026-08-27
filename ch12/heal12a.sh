#!/usr/bin/env bash
# Undo break12a.sh: session synchronization back on, both units
# functional.
set -uo pipefail
cd "$(dirname "$0")"
source ./pa.sh

for ip in 172.20.40.11 172.20.40.12; do
  KEY=$(pa_key ${ip})
  curl -sk "https://${ip}/api/" --data-urlencode "type=config" --data-urlencode "action=set" \
    --data-urlencode "key=${KEY}" \
    --data-urlencode "xpath=/config/devices/entry[@name='localhost.localdomain']/deviceconfig/high-availability/group/state-synchronization" \
    --data-urlencode "element=<enabled>yes</enabled>" >/dev/null
  curl -sk "https://${ip}/api/" --data-urlencode "type=commit" --data-urlencode "key=${KEY}" \
    --data-urlencode "cmd=<commit></commit>" >/dev/null
  pa_op ${ip} "<request><high-availability><state><functional/></state></high-availability></request>" >/dev/null 2>&1
done
sleep 30
echo "healed: state sync on, both units functional (fw-a: $(pa_state 172.20.40.11), fw-b: $(pa_state 172.20.40.12))"
