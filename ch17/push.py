#!/usr/bin/env python3
"""Chapter 17: the push. Reconcile the generated config onto every device.

One render, applied to each switch, converging its running configuration back
to intent.json. At fleet scale Nornir drives these applies in parallel from
the inventory containerlab writes for the fabric
(clab-<lab>/nornir-simple-inventory.yml); here the same operation is shown at
lab scale. Each device is applied, then read back and checked against its
intent, with one retry, so a dropped session is caught rather than reported
as success."""
import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
LAB = os.environ.get("LAB", "bgpbook-ch17")
PASS = os.environ.get("PASS", "Clab123!")
intent = json.load(open(os.path.join(HERE, "intent.json")))

def ssh(dev, cmd, stdin=None):
    base = ["sshpass", "-p", PASS, "ssh", "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=10",
            f"cumulus@clab-{LAB}-{dev}", cmd]
    return subprocess.run(base, input=stdin, capture_output=True, text=True)

def running(dev):
    out = ssh(dev, "sudo nv config show -o commands 2>/dev/null").stdout
    return set(l.strip() for l in out.splitlines() if l.strip().startswith("nv set"))

def apply(dev):
    cfg = open(os.path.join(HERE, f"bootstrap/{dev}.cfg")).read()
    ssh(dev, "sudo tee /tmp/gen.cfg >/dev/null", stdin=cfg)
    ssh(dev, "sudo bash -c 'nv config detach 2>/dev/null; "
             "while read -r l; do [ -n \"$l\" ] && $l </dev/null >/dev/null 2>&1; "
             "done < /tmp/gen.cfg; nv config apply -y >/dev/null 2>&1'")

def missing(dev):
    run = running(dev)
    return [l for l in intent[dev] if l.strip() not in run]

print("=== reconcile the generated config onto every device ===")
ok = True
for dev in sorted(intent):
    apply(dev)
    m = missing(dev)
    if m:                      # a dropped session or slow apply: try once more
        apply(dev)
        m = missing(dev)
    if m:
        ok = False
        print(f"  {dev}: WARNING {len(m)} intent line(s) still missing")
    else:
        print(f"  {dev}: reconciled, all {len(intent[dev])} intent lines present")
print("Every device reconciled to the generated intent." if ok
      else "Some devices did not converge; re-run the push.")
sys.exit(0 if ok else 1)
