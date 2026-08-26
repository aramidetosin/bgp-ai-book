# BGP for AI Infrastructure: the labs

The companion lab repository for the book *BGP for AI Infrastructure: A DevOps
Engineer's Guide to AI Data Center Fabric Networking*. One directory per chapter. Every
lab deploys a working topology from a clean clone: containerlab plus the
chapter's bootstrap configuration, with nothing hand-typed.

## What's here

| Directory | Chapter | Lab |
|---|---|---|
| [ch01](ch01/) | Why Data Centers Run BGP | A guided tour of a running eBGP fabric: 4 leafs, 2 spines, BGP unnumbered, link-failure demos, packet-capture verification |
| [ch02](ch02/) | BGP Fundamentals Without the CCNA Detour | Build a three-switch eBGP triangle by hand: numbered then unnumbered peering, a deliberate Bad Peer AS, path selection, loop prevention on the wire, and a TCP-layer break-fix |
| [ch03](ch03/) | Frontend and Backend: Two Networks, Two Jobs | Two nodes with a NIC in each of two disjoint fabrics: run a service on one and a collective stand-in on the other, prove zero cross-traffic with simultaneous captures, and break each network while the other doesn't notice |

Each chapter directory contains:

- `topo.clab.yml`: the containerlab topology
- `bootstrap/`: per-node configuration, applied at first boot
- `Makefile`: deploy, destroy, and every demo the chapter walks through
- `audit.sh` and `trace.sh`: fabric health audit and end-to-end path trace
- `audits/`: the recorded runs that back every output printed in the book,
  including a written `TRACE.md` per trace

## Requirements

- A Linux host with Docker and containerlab (v0.79 or later)
- The Cumulus Linux VX image, built with vrnetlab and tagged
  `vrnetlab/nvidia_cumulus-vx:5.12.0`
- `sshpass` for the scripted node logins

Switches are Cumulus Linux VX VMs (qemu inside containers via vrnetlab), so
labs need a machine with virtualization support and a few GB of RAM per
switch. Each chapter's README states its own sizing.

## Conventions

- `make up` deploys and configures; `make down` destroys. Always.
- Break-fix exercises ship pre-broken: `make break-<chapter><letter>`.
- Runtime state (per-node overlay disks, `clab-*` directories) is never
  committed; the base VM disk lives once, inside the Docker image.
- The recorded outputs under each chapter's `audits/` directory are the
  source of every command output printed in the book. If you find a
  mismatch between the book and a fresh run of these labs, that's a bug:
  please open an issue.
