#!/usr/bin/env python3
"""Chapter 17: drift detection. Compare each device's running configuration
against intent.json (what the generator says it should carry). A device
whose running config is missing an intended line, or has been hand-edited
away from intent, is flagged. Run on the containerlab host."""
import json, os, subprocess, sys
LAB = os.environ.get("LAB", "bgpbook-ch17")
PASS = os.environ.get("PASS", "Clab123!")
intent = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "intent.json")))

def running(dev):
    cmd = ["sshpass", "-p", PASS, "ssh", "-o", "StrictHostKeyChecking=no",
           "-o", "UserKnownHostsFile=/dev/null", f"cumulus@clab-{LAB}-{dev}",
           "sudo nv config show -o commands 2>/dev/null"]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    return set(l.strip() for l in out.splitlines() if l.strip().startswith("nv set"))

clean = True
print("=== Drift: running configuration vs intent.json ===")
for dev in sorted(intent):
    run = running(dev)
    missing = [l for l in intent[dev] if l not in run]
    if missing:
        clean = False
        print(f"  {dev}: DRIFT ({len(missing)} intended line(s) not on the device)")
        for l in missing:
            print(f"      - {l}")
    else:
        print(f"  {dev}: in sync ({len(intent[dev])} intended lines all present)")
print("DRIFT DETECTED: run the generator and push to reconcile" if not clean
      else "NO DRIFT: every device matches the generated intent")
sys.exit(1 if not clean else 0)
