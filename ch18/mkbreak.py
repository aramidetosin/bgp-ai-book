#!/usr/bin/env python3
"""Chapter 18 break-18a: a change that passes lint and render and deploys
without error, but is subtly wrong. Someone adds an outbound filter on
spine01 to stop advertising a storage prefix out of the pod, and the
prefix-list matches a leaf loopback (10.0.0.4/32) by mistake. Reachability
survives (leaf04 is still reached via spine02), so a ping test passes. But
spine01 no longer offers its path to leaf04, so every leaf's ECMP width to
leaf04 drops from two to one: one spine failure now partitions leaf04, and
only a property check sees it before it ships. This builds the broken twin
from the good one; validate.py run against it is the CI stage that fails."""
import os, shutil
HERE = os.path.dirname(os.path.abspath(__file__))
GOOD = os.path.join(HERE, "snapshot")
BROKEN = os.path.join(HERE, "snapshot-broken")

if os.path.isdir(BROKEN):
    shutil.rmtree(BROKEN)
shutil.copytree(GOOD, BROKEN)

POLICY = [
    "ip prefix-list PL-EGRESS-BLOCK seq 5 permit 10.0.0.4/32",
    "route-map RM-EGRESS-FILTER deny 10",
    " match ip address prefix-list PL-EGRESS-BLOCK",
    "route-map RM-EGRESS-FILTER permit 20",
]
cfg = os.path.join(BROKEN, "configs", "spine01.cfg")
lines = open(cfg).read().splitlines()
out = []
for l in lines:
    out.append(l)
    if l.strip() == "frr defaults datacenter":
        out += POLICY
    if l.strip().startswith("neighbor swp") and l.strip().endswith("activate"):
        port = l.split()[1]
        out.append(f"neighbor {port} route-map RM-EGRESS-FILTER out")
open(cfg, "w").write("\n".join(out) + "\n")
print("built snapshot-broken/: spine01 filters 10.0.0.4/32 outbound "
      "(intended a storage prefix, hit leaf04's loopback)")
