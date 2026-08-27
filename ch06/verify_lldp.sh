#!/usr/bin/env bash
# Chapter 5's check, carried forward: does the cabling match the intent?
# Reads intent.json, asks every switch for its LLDP neighbors, and reports
# every port as OK or MISMATCH. Exit code is the number of mismatches.
set -uo pipefail

python3 - "$@" << 'PY'
import json, subprocess, sys

LAB = "bgpbook-ch06"
intent = json.load(open("intent.json"))
switches = sorted(d for d in intent if d.startswith(("leaf", "spine")))

fails = 0
for sw in switches:
    out = subprocess.run(
        ["sshpass", "-p", "Clab123!", "ssh",
         "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
         f"cumulus@clab-{LAB}-{sw}", "sudo lldpctl -f keyvalue"],
        capture_output=True, text=True).stdout
    seen = {}
    for line in out.splitlines():
        if "=" not in line: continue
        key, _, val = line.partition("=")
        parts = key.split(".")
        if len(parts) < 4 or parts[0] != "lldp": continue
        port = parts[1]
        if parts[2] == "chassis" and parts[3] == "name":
            seen.setdefault(port, {})["name"] = val
        if parts[2] == "port" and parts[3] in ("descr", "ifname"):
            seen.setdefault(port, {}).setdefault("port", val)
    for port, (exp_dev, exp_port) in sorted(intent[sw].items()):
        got = seen.get(port)
        if got and got.get("name") == exp_dev and got.get("port") == exp_port:
            print(f"  OK        {sw}:{port} <-> {exp_dev}:{exp_port}")
        else:
            fails += 1
            actual = f"{got.get('name','?')}:{got.get('port','?')}" if got else "nothing heard"
            print(f"  MISMATCH  {sw}:{port} expected {exp_dev}:{exp_port}, sees {actual}")

print(f"\n{'CABLING MATCHES INTENT' if fails == 0 else f'{fails} MISMATCHES: the fabric is not the design'}")
sys.exit(fails)
PY
