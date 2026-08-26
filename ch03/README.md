# Chapter 3 lab: two networks, two jobs

Two GPU-node stand-ins, each with a frontend NIC and a backend NIC wired
into fabrics that share nothing: a routed frontend leaf (with a client where
users live) and a flat backend rail. The chapter uses it to prove the
frontend/backend distinction physically: each network does its job, cannot
do the other's, and dies alone.

## Requirements

containerlab v0.79+, Docker, the `vrnetlab/nvidia_cumulus-vx:5.12.0` image,
`sshpass`, and `ghcr.io/srl-labs/network-multitool` for the Linux nodes.
Switch password defaults to `Clab123!` (override with `CL_PASS`).

## Targets

| Target | What it does |
|---|---|
| `make up` | Deploy; both leafs self-configure at first boot |
| `make down` | Destroy the lab |
| `make curl` | The frontend's job: client fetches nodea's HTTP service |
| `make collective` | The backend's job: 20s iperf3 between backend NICs |
| `make fail-frontend` / `heal-frontend` | Drop and restore nodea's frontend NIC |
| `make fail-backend` / `heal-backend` | Drop and restore nodea's backend NIC |
| `make audit` | Both jobs work, isolation holds, node view correct |
| `make trace` | Both journeys plus simultaneous captures of both fabrics |
| `make ssh-fe-leaf` | Shell on a switch |
| `make shell-nodea` | Shell on a Linux node |

## Addressing

| Where | Subnet | Notes |
|---|---|---|
| Frontend, nodes | 172.16.10.0/24 | nodea .11, nodeb .12, gateway .1 on fe-leaf |
| Frontend, client | 172.16.20.0/24 | client .100, gateway .1 on fe-leaf (routed hop) |
| Backend rail | 172.31.1.0/24 | nodea .11, nodeb .12, flat L2, no gateway |

## Platform notes

- Node NICs are pinned to MTU 1500 in the topology: the emulated switch
  path drops jumbo frames, and without the pin TCP crawls on retransmits
  (the recorded first run measured 1.5 Mbit/s; with it, 3+ Gbit/s).
- `make heal-frontend` also restores nodea's default route: Linux removes
  routes through an interface that goes down and does not re-add them.

## Evidence

Recorded runs backing every output printed in chapter 3 live under
`audits/`: the green audit, the two-journey trace with simultaneous
captures of both fabrics (`e2e_trace_ch03_20260826/TRACE.md` indexes it),
and both failure demos.
