# Chapter 18: Pre-Deployment Validation

The chapter 17 fabric, put through a promotion pipeline before any change
ships. Each stage catches a class of bug; a failure at any stage stops the
change before it reaches production. The digital twin is the same
containerlab fabric chapter 17 generated (`bgpbook-ch17`), read here for
analysis with Batfish rather than for forwarding.

## Prerequisites

- The chapter 17 fabric running (`cd ../ch17 && make up`).
- The Batfish service: `make bf-up` (pulls and runs `batfish/allinone`).
- pybatfish in a virtualenv:

```
python3 -m venv bfvenv && ./bfvenv/bin/pip install pybatfish
```

Point the lab at it with `make PY=./bfvenv/bin/python <target>`.

## Targets

```
make bf-up        # start the Batfish service
make lint         # stage 1: the spec's schema (ASNs, counts, servers)
make twin         # stage 3: build the Batfish snapshot from the fabric
make validate     # stage 4: the property checks (sessions, reachability, ECMP)
make golden       # stage 5: the bgp-summary session count vs the golden
make ci           # the whole pipeline, end to end
make break-18a    # a bad change the property checks catch before it ships
make heal-18a     # discard the bad candidate
make bf-down
```

## The pipeline (`ci.sh`)

Five stages, cheapest first, each catching what it is cheapest to catch there:

1. **lint** (`lint.py`): the spec's schema. Counts sane, servers on real
   leafs, ASNs in RFC 6996 private space and unique across the fabric.
2. **render** (`../ch17/gen.py`): the configs generate without error.
3. **twin** (`mksnapshot.py`): build the Batfish snapshot. Each device is the
   Cumulus-concatenated layout Batfish parses (hostname, interfaces, FRR), and
   `layer1_topology.json` is derived from the generated cabling so Batfish can
   resolve the unnumbered adjacencies.
4. **property checks** (`validate.py`): the invariants that must hold. Every
   session compatible, every leaf reaches every other leaf, and every
   leaf-to-leaf route keeps its full ECMP width (one path per spine, which is
   the no-single-spine-partition guarantee). Expectations come from the same
   spec that built the fabric, so the checks scale with it.
5. **golden snapshot** (`golden.py`): each device's established peer count
   against the committed `golden/bgp-summary.json`. A session that did not
   come up, or an unexpected neighbor, fails here. Record a new golden with
   `make golden-update`.

## Evidence (`audits/`)

- `ci/` the full pipeline on a good change: all five stages green, ending in
  "safe to promote."
- `twin/` the twin's parse status (every device a Cumulus node) and the 16
  eBGP sessions Batfish models as ESTABLISHED, resolved from the layer-1
  topology.
- `break18a/` a bad change: an outbound filter on spine01 meant for a storage
  prefix that matches leaf04's loopback by mistake. It passes lint and would
  deploy without error, and reachability stays green (leaf04 is still reached
  via spine02), so a ping test passes. The ECMP-width check catches it: every
  leaf's path count to leaf04 drops from two to one, one spine failure from
  partition. The pipeline exits non-zero and blocks the promotion.

## What the twin cannot catch

Batfish models the control plane and L3 forwarding: sessions, routes, ECMP,
policy. It does not model buffers, PFC, or ECN (chapters 13 and 14), optic
light levels, or the storage array's absorb rate (chapter 14). A change that
is correct in the twin can still fail on hardware for those reasons. Each gap
is a stated pipeline gap with a compensating check: the QoS config
consistency check from chapter 13, the hardware counters from chapter 19, and
the storage team's own load test for the absorb rate. Batfish also reports a
few Cumulus knobs as unrecognized (`capability extended-nexthop`, `bgp
deterministic-med`, `ip-forward`); none change the reachability or ECMP
conclusions, and the parse warnings name them exactly.

## Files

`lint.py`, `mksnapshot.py`, `validate.py`, `golden.py` the pipeline stages;
`ci.sh` chains them. `mkbreak.py` builds the break-18a candidate; `break18a.sh`
runs it through the checks. `twinev.py` records the twin evidence. `lib.sh`
shared shell settings. `golden/bgp-summary.json` the committed golden.
