#!/usr/bin/env python3
"""Chapter 18, golden snapshot test: capture each device's established BGP
peer count from show bgp summary and compare it to the committed golden. A
change in the session count, a peer that did not come up, a neighbor added or
removed, fails the pipeline. Cheap, and it catches what property checks are
not looking at. Writes the golden with --update."""
import os, sys, json, subprocess
HERE = os.path.dirname(os.path.abspath(__file__))
LAB = os.environ.get("LAB", "bgpbook-ch17")
PASS = os.environ.get("PASS", "Clab123!")
DEVICES = os.environ.get("DEVICES", "leaf01 leaf02 leaf03 leaf04 spine01 spine02").split()
GOLDEN = os.path.join(HERE, "golden", "bgp-summary.json")

def established(dev):
    base = ["sshpass", "-p", PASS, "ssh", "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=10",
            f"cumulus@clab-{LAB}-{dev}", "sudo vtysh -c 'show bgp summary json'"]
    out = subprocess.run(base, capture_output=True, text=True).stdout
    j = json.loads(out)
    peers = j.get("ipv4Unicast", {}).get("peers", {})
    return sum(1 for p in peers.values() if p.get("state") == "Established")

current = {d: established(d) for d in DEVICES}
if "--update" in sys.argv:
    os.makedirs(os.path.dirname(GOLDEN), exist_ok=True)
    json.dump(current, open(GOLDEN, "w"), indent=1, sort_keys=True)
    print("golden updated:", current)
    sys.exit(0)

golden = json.load(open(GOLDEN))
diffs = [f"{d}: {current.get(d)} established, golden {golden.get(d)}"
         for d in sorted(set(golden) | set(current)) if current.get(d) != golden.get(d)]
if diffs:
    print("GOLDEN MISMATCH:")
    for d in diffs: print(f"  - {d}")
    sys.exit(1)
print("GOLDEN MATCH: every device's established peer count is as recorded",
      dict(sorted(current.items())))
