#!/usr/bin/env python3
"""Chapter 18: the property checks. Run Batfish against the twin snapshot and
assert the invariants that must hold before any change ships:

  1. every eBGP session is compatible (would establish),
  2. every leaf reaches every other leaf's loopback (full reachability),
  3. every leaf keeps its full ECMP width (one path per spine) to every other
     leaf, which is also the no-single-spine-partition guarantee: width N
     across N spines means losing any one spine leaves a path.

Expectations come from the same spec that built the fabric (chapter 17), so
the checks scale with the fabric instead of being hand-listed. Exit non-zero
on any failure; a CI stage gates the deploy on this."""
import os, sys, yaml
from pybatfish.client.session import Session

HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = os.environ.get("SPEC", os.path.join(HERE, "..", "ch17", "spec.yml"))
SNAP = os.environ.get("SNAP", os.path.join(HERE, "snapshot"))
spec = yaml.safe_load(open(SPEC))
LEAFS, SPINES = spec["leafs"], spec["spines"]
leaves = [f"leaf{i:02d}" for i in range(1, LEAFS + 1)]
loopback = {f"leaf{i:02d}": f"10.0.0.{i}" for i in range(1, LEAFS + 1)}

bf = Session(host=os.environ.get("BF_HOST", "localhost"))
bf.set_network("bgpbook")
bf.init_snapshot(SNAP, name="twin", overwrite=True)

fails = []

# 1. session compatibility
st = bf.q.bgpSessionStatus().answer().frame()
bad = st[st["Established_Status"] != "ESTABLISHED"]
expect_sessions = 2 * LEAFS * SPINES     # each fabric link is two session-ends
if len(bad):
    fails.append(f"{len(bad)} session(s) not ESTABLISHED: "
                 + ", ".join(f"{r.Node}[{r.Local_Interface}]" for r in bad.itertuples()))
elif len(st) != expect_sessions:
    fails.append(f"session count {len(st)}, expected {expect_sessions}")
print(f"[{'ok' if not len(bad) and len(st)==expect_sessions else 'FAIL'}] "
      f"sessions: {len(st)} modeled, all ESTABLISHED")

# 2 + 3. reachability and ECMP width, every ordered leaf pair
reach_fail = width_fail = 0
for src in leaves:
    for dst in leaves:
        if src == dst:
            continue
        r = bf.q.routes(nodes=src, network=loopback[dst] + "/32").answer().frame()
        w = len(r)
        if w == 0:
            reach_fail += 1
            fails.append(f"{src} has no route to {dst} ({loopback[dst]}/32)")
        elif w != SPINES:
            width_fail += 1
            fails.append(f"{src} -> {dst}: ECMP width {w}, expected {SPINES}")
print(f"[{'ok' if reach_fail==0 else 'FAIL'}] reachability: every leaf reaches "
      f"every other leaf ({len(leaves)*(len(leaves)-1)} ordered pairs)")
print(f"[{'ok' if width_fail==0 else 'FAIL'}] ECMP width: {SPINES} paths "
      f"(one per spine) on every leaf-to-leaf route; survives any one spine")

print()
if fails:
    print(f"VALIDATION FAILED ({len(fails)} finding(s)):")
    for f in fails:
        print(f"  - {f}")
    sys.exit(1)
print("VALIDATION PASSED: the twin satisfies every invariant; safe to promote")
