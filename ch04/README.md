# Chapter 4 lab: one node, four fabrics

The book's four-network anatomy made runnable: one specimen node with a NIC
into each of four disjoint fabrics, a peer on every fabric so each network
has its real job, and the BMC port fenced in a VRF. The audit proves all
four jobs, the VRF fence, and a diagonal isolation matrix; the blackout demo
proves the out-of-band property.

## Requirements

Same as the earlier chapters: containerlab v0.79+, Docker,
`vrnetlab/nvidia_cumulus-vx:5.12.0`, `sshpass`, and
`ghcr.io/srl-labs/network-multitool`. Switch password defaults to
`Clab123!` (override with `CL_PASS`).

## Targets

| Target | What it does |
|---|---|
| `make up` | Deploy; all four switches self-configure at first boot |
| `make down` | Destroy the lab |
| `make curl` | Frontend job: client fetches the node's HTTP service |
| `make collective` | Backend job: 10s iperf3 from gpu-peer to the node |
| `make dataset` | Storage job: node fetches the 512 MB dataset, rate reported |
| `make oob-ping` | Out-of-band job: management station pings the BMC port |
| `make blackout` | Down the node's frontend, backend, and storage NICs at once |
| `make restore` | Bring them back and restore the routes |
| `make audit` | Four jobs, VRF fence both ways, and the isolation matrix |
| `make trace` | Four journeys, node route views, and the blackout evidence |

## Addressing

| Fabric | Subnets | Notes |
|---|---|---|
| Frontend | 172.16.10.0/24 (node .11), 172.16.20.0/24 (client .100) | fe-leaf routes between SVIs |
| Backend | 172.31.1.0/24 (node .11, gpu-peer .12) | flat rail |
| Storage | 172.30.1.0/24 (node .11), 172.30.2.0/24 (storage-srv .12) | st-leaf routes; node uses a static route |
| Out-of-band | 10.99.0.0/24 (BMC .11, oob-mgmt .100) | flat, deliberately boring; node side lives in `vrf mgmt` |

`inventory.csv` is exercise 3's deliberately messy port inventory; two
miscabled links hide in it.

## Evidence

Recorded runs backing every output printed in chapter 4 live under
`audits/`: the green audit with the isolation matrix, and the trace with
all four journeys and the blackout demo
(`audits/e2e_trace_ch04_20260826/TRACE.md` indexes it).
