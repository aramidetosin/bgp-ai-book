# Chapter 1 lab: a guided tour of a running fabric

Four Cumulus Linux leafs, two spines, eBGP unnumbered everywhere, and two Linux
hosts to route between. The chapter walks this lab step by step; this file is
just the mechanics.

## Requirements

- A Linux host with containerlab (v0.79 or later) and Docker
- The Cumulus Linux VX image, built with vrnetlab and tagged
  `vrnetlab/nvidia_cumulus-vx:5.12.0` (Appendix A covers building it)
- `sshpass` for the scripted node logins

The topology uses the `nvidia_cumulusvx` containerlab kind. Each switch is a
qemu VM inside a container and takes a few minutes to boot.

## Credentials

The switch password is set when the vrnetlab image is built. These scripts
default to `Clab123!`; if your image uses a different password, export it:

```bash
export CL_PASS='your-password'
make up PASS='your-password'
```

## Targets

| Target | What it does |
|---|---|
| `make up` | Deploy the topology, then push the NVUE config to all six switches |
| `make down` | Destroy the lab |
| `make ssh-leaf01` | Shell on a switch (any node name works) |
| `make logs-leaf01` | Follow FRR's log on a switch |
| `make ping` | Continuous ping server01 to server03 |
| `make fail-link` | Take down spine01's link to leaf01 (spine side) |
| `make heal-link` | Bring it back |
| `make fail-spine` | Stop the spine01 container entirely (exercise 1) |
| `make heal-spine` | Start it again |
| `make capture` | Rerun the link failure with BGP packet capture, report UPDATE counts (exercise 2) |
| `./audit.sh` | Fabric health audit: sessions, ECMP, data plane, with raw JSON evidence |
| `./trace.sh` | End-to-end trace collection, server01 to server03, hop by hop |

The recorded runs backing every output printed in chapter 1 are committed under
`audits/`, including the written trace at
`audits/e2e_trace_ch01_20260826/TRACE.md`.

The switches self-configure at first boot from `bootstrap/<node>.cfg` (the
image's patched vrnetlab launcher applies them). If your image lacks that
patch, run `./configure.sh` after deploy. Runtime state (per-node overlay
qcow2 disks, `clab-*` directories) is gitignored; the base VM disk lives once,
inside the Docker image.

## Addressing

| Node | ASN | Loopback | Server subnet |
|---|---|---|---|
| leaf01 | 65101 | 10.0.0.1/32 | 172.16.1.0/24 |
| leaf02 | 65102 | 10.0.0.2/32 | 172.16.2.0/24 |
| leaf03 | 65103 | 10.0.0.3/32 | 172.16.3.0/24 |
| leaf04 | 65104 | 10.0.0.4/32 | 172.16.4.0/24 |
| spine01 | 65100 | 10.0.0.101/32 | |
| spine02 | 65100 | 10.0.0.102/32 | |

Fabric links run BGP unnumbered: leafs peer on swp2 (spine01) and swp3
(spine02); spines peer on swp1 through swp4 (leaf01 through leaf04). Servers
hang off each leaf's swp1.

## A note on `make fail-link`

The link is failed on the spine side only. In this emulated fabric that
matters: carrier loss does not propagate to the leaf the way a real optic's
light loss usually would, so spine01 reacts instantly while leaf01 only
notices when the BGP hold timer expires (9 seconds on Cumulus Linux
defaults). The chapter discusses exactly this, and chapter 6 fixes it
properly with BFD.
