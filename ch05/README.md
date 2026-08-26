# Chapter 5 lab: the fabric as data

The topology generator's debut. `spec.yml` states the design in five numbers,
`gen_topo.py` derives everything else (containerlab topology, per-switch
NVUE bootstrap configs, and `intent.json`, the list of every link the design
intends), and `verify_lldp.sh` proves the running fabric matches the intent
by collecting LLDP announcements from every switch. The diagram is
generated, never drawn.

The generated fabric is a small rail-optimized backend: 2 nodes with 4 NICs
each, 4 rail leafs (one per NIC rank), 2 spines, unnumbered eBGP throughout.

## Requirements

Same as the earlier chapters: containerlab v0.79+, Docker,
`vrnetlab/nvidia_cumulus-vx:5.12.0`, `sshpass`, and
`ghcr.io/srl-labs/network-multitool`, plus Python 3 with PyYAML for the
generator. Switch password defaults to `Clab123!` (override with `CL_PASS`).
`make node-image` builds `bgpbook-multitool-lldpd` once (the multitool plus
`lldpd`, from `Dockerfile.node`), so nodes can speak LLDP without needing
internet access at deploy time.

## Targets

| Target | What it does |
|---|---|
| `make generate` | Run the generator: spec in, topology + configs + intent out |
| `make node-image` | One-time build of the node image with lldpd baked in |
| `make up` | Generate, then deploy; switches self-configure at first boot |
| `make down` | Destroy the lab |
| `make verify` | LLDP versus intent, every switch port, OK or MISMATCH |
| `make paths` | The traffic-path walk: intra-rail, the cross-rail shortcut, the forced leaf-spine-leaf trace |
| `make audit` | BGP sessions, per-rail node reachability, cabling vs intent |
| `make trace` | Collect the evidence quoted in the chapter |
| `make break-5a` | Redeploy with rails 2 and 3 swapped on the node side |
| `make heal-5a` | Regenerate the correct topology and redeploy |

## Addressing (all generated)

| Element | Value |
|---|---|
| Rail i leaf | AS 6510i, lo 10.5.0.i, SVI 172.31.i.1/24 on vlan i |
| Spines | AS 65100, lo 10.5.0.101 and .102 |
| node j on rail i | 172.31.i.(10+j)/24 on eth i, MTU 9216 |
| Uplinks | unnumbered eBGP, one session per rail-spine pair |

Change `spec.yml` (more nodes, more spines, more GPUs per node) and rerun
`make up`; the topology, configs, and intent all move together.

## Evidence

Recorded runs backing every output printed in chapter 5 live under
`audits/`: two green audits, the trace with the ECMP proof, the LLDP wire
capture, and the traffic-path walk (`node1_paths.txt`: intra-rail in one
hop, the kernel's cross-rail shortcut, and the forced leaf-spine-leaf
traceroute with both spine loopbacks answering), all indexed by
`audits/e2e_trace_ch05_20260826/TRACE.md`, plus `audits/break5a/` with
the miscabled deploy's verify diff, the still-passing per-rail pings, and
the failing gateways.
