# Chapter 17: BGP as Code

The standard chapter 6 fabric (4 leafs, 2 spines, eBGP unnumbered, a server on
leaf01 and leaf04), but nothing about it is written by hand. One spec file,
`spec.yml`, is the source of truth. A generator turns it into three derived
artifacts, and a drift check holds the running fabric to them:

- `topo.clab.yml` the containerlab topology
- `bootstrap/*.cfg` the per-device NVUE configuration, rendered through a
  Jinja2 template (`templates/switch.cfg.j2`)
- `intent.json` what each device is supposed to carry, for the drift check

Every device config is generated; none is edited. Change the fabric by
changing the spec and regenerating, never by touching a switch.

## Targets

```
make up         # generate from spec.yml, then deploy the fabric
make verify     # every session Established, server01 -> server04 across it
make drift      # compare every running device against intent.json
make diff       # a change to intent (BFD on) as a reviewable config diff
make break-17a  # a template bug the render diff catches before it ships
make heal-17a   # regenerate from the correct template
make push       # reconcile the generated config onto every device
make down
```

## The pipeline

`spec.yml` -> `gen.py` -> (`topo.clab.yml`, `bootstrap/*.cfg`, `intent.json`).
`gen.py` computes the links and per-device parameters (the only place a leaf
differs from a spine is data: its ASN, its loopback, which ports face the
fabric), then renders each device through the one template. The same shape
every chapter's generator has produced, with the config step moved into
Jinja2 so it stays readable as the config grows.

`drift.py` reads `intent.json`, asks each device for its running config
(`nv config show -o commands`), and reports any intended line not on the wire.
`push.py` reconciles: it applies each device's generated config, reads it
back, checks it against intent, and retries once, so a dropped session is
caught rather than reported as success.

## Evidence (`audits/`)

- `generate/` the generator run: 4 leafs, 2 spines, 6 device configs, 10 links.
- `verify/` every device two or four sessions Established, server01 to
  server04 at 0% loss, on a fabric no one hand-configured.
- `drift/` the headline: the fabric in sync, a router-id hand-edited on leaf02
  off-spec, the drift check naming the exact missing line, the push
  reconciling it, and the check clean again.
- `diff/` turning on the BFD tuning the schema already carries: one line of
  intent (`bfd.enabled: true`) becomes four config lines per neighbor on every
  device, shown as the diff a reviewer approves before it ships.
- `break17a/` a template bug that is invisible until a leaf has more than four
  uplinks. At two spines the broken and correct templates render identically;
  at six spines the render diff shows the missing fifth and sixth uplink
  neighbors. The diff is the review artifact; the bug never reaches a device.
- `addleaf/` the worked example: growing the fabric from four leafs to five is
  one line in the spec. The generator writes a full bootstrap for leaf05 and
  adds it to every spine's port range, with no human touching a device config.

## Files

`spec.yml` the source of truth. `spec-bigpod.yml` a six-spine variant for
break-17a. `gen.py` the generator. `templates/switch.cfg.j2` the device
template; `templates/switch.broken.j2` the break-17a variant. `drift.py` the
drift check. `push.py` the reconcile. `verify.sh`, `gitdiff.sh`, `break17a.sh`,
`driftdemo.sh` the evidence runs. `lib.sh` shared shell helpers.
