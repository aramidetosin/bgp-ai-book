# Chapter 6 lab: the core underlay, measured

The book's base topology: chapter 1's fabric shape regenerated from a spec
(4 leafs, 2 spines, 2 servers, eBGP unnumbered, per-leaf ASNs), then used
as the test bench for the chapter's whole tuning story: the failover
measurement ladder (hold timer defaults, tuned timers, BFD), the
graceful-restart measurement, the reconnect timings, and the over-tuning
trap sprung with deterministic control-plane stalls. Later chapters build
directly on this lab.

## Requirements

Same as earlier chapters: containerlab v0.79+, Docker,
`vrnetlab/nvidia_cumulus-vx:5.12.0`, `sshpass`, Python 3 with PyYAML, and
the `bgpbook-multitool-lldpd` node image (`make node-image`, shared with
chapter 5). Switch password defaults to `Clab123!` (override with `CL_PASS` for the
scripts, `make PASS=...` for make targets).

## Targets

| Target | What it does |
|---|---|
| `make up` | Generate topology + configs + intent from `spec.yml`, deploy |
| `make down` | Destroy the lab |
| `make verify` | LLDP versus intent, the chapter 5 habit carried forward |
| `make audit` | Sessions, loopback mesh, server path, cabling vs intent |
| `make trace` | Collect the evidence quoted in the chapter |
| `make measure-default` | Failover with platform defaults (ping loss counter) |
| `make tune-timers` | keepalive 1 / hold 3, fabric-wide |
| `make measure-tuned` | Failover again under tuned timers |
| `make bfd-on` | BFD at platform default intervals |
| `make measure-bfd` | Failover again under BFD |
| `make tune-connect` | connection-retry 1, fabric-wide (before `reconnect-tuned`) |
| `make reconnect-default` / `reconnect-tuned` | Re-establishment timing, connect-retry default vs 1 |
| `make bfd-fast` | BFD 50 ms x2, the aggressive profile |
| `./stall.sh <label> <ms>` | Freeze spine01's CPU for `<ms>`; did the settings survive? |
| `make defaults` | All tuning back to platform defaults |
| `make numbered` / `make unnumbered` | Exercise 1: the whole fabric as /31s, and back |
| `make break-6a` / `make heal-6a` | Exercise 4: leaf04 wearing leaf01's ASN, and the truth restored |

## Addressing (all generated)

| Element | Value |
|---|---|
| leaf0i | AS 6510i, lo 10.0.0.i; server subnet 172.16.i.0/24 (gateway .1) where present |
| Spines | AS 65100, lo 10.0.0.101 and .102 |
| server01 / server02 | 172.16.1.11 on leaf01, 172.16.4.11 on leaf04, MTU 9216 |
| Fabric links | unnumbered eBGP; `--numbered` emits the /31 plan (10.0.1.0/26 pairs) instead |

## Evidence

Recorded runs backing every output printed in chapter 6 live under
`audits/`: the green audits, `failover/` (the measurement ladder),
`tuning/` (applied commands, negotiated-vs-configured hold, BFD state,
graceful-restart measurement, reconnect timings, stall experiments),
`break6a/` (the duplicate-ASN views), `numbered/` (the conversion counts
and the numbered deploy's audit), and the trace indexed by its `TRACE.md`.
