#!/usr/bin/env python3
"""Chapter 18, stage 1: lint the spec. The cheapest check catches the
cheapest bugs before anything renders: counts sane, servers on real leafs,
ASNs in private space and unique across the fabric. Exit non-zero on any
finding."""
import os, sys, yaml
HERE = os.path.dirname(os.path.abspath(__file__))
SPEC = os.environ.get("SPEC", os.path.join(HERE, "..", "ch17", "spec.yml"))
spec = yaml.safe_load(open(SPEC))
errs = []

L, S = spec.get("leafs"), spec.get("spines")
if not isinstance(L, int) or L < 1: errs.append(f"leafs must be a positive integer, got {L!r}")
if not isinstance(S, int) or S < 1: errs.append(f"spines must be a positive integer, got {S!r}")
for i in spec.get("servers_on", []):
    if not (isinstance(i, int) and 1 <= i <= (L or 0)):
        errs.append(f"servers_on has {i}, which is not a leaf index in 1..{L}")

def private(asn):  # RFC 6996 two-byte and four-byte private ranges
    return 64512 <= asn <= 65534 or 4200000000 <= asn <= 4294967294

asns = {"spine_asn": spec["spine_asn"]}
for i in range(1, (L or 0) + 1):
    asns[f"leaf{i:02d}"] = spec["leaf_asn_base"] + i
for name, a in asns.items():
    if not private(a):
        errs.append(f"{name} ASN {a} is not in RFC 6996 private space")
# every leaf ASN must be unique and differ from the shared spine ASN
leaf_asns = [asns[f"leaf{i:02d}"] for i in range(1, (L or 0) + 1)]
dups = {a for a in leaf_asns if leaf_asns.count(a) > 1}
if dups: errs.append(f"duplicate leaf ASN(s): {sorted(dups)}")
if spec["spine_asn"] in leaf_asns:
    errs.append(f"spine ASN {spec['spine_asn']} collides with a leaf ASN")

if errs:
    print("LINT FAILED:")
    for e in errs: print(f"  - {e}")
    sys.exit(1)
print(f"LINT PASSED: {L} leafs, {S} spines, {len(leaf_asns)} unique leaf ASNs, all private")
