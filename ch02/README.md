# Chapter 2 lab: build the triangle

Three Cumulus Linux switches, deployed unconfigured on purpose. The chapter
walks you through building eBGP by hand: numbered peering first, then a
deliberate remote-as failure, then the conversion to unnumbered, then the
full three-switch triangle where path selection and loop prevention become
visible.

## Requirements

Same as ch01: containerlab v0.79+, Docker, the
`vrnetlab/nvidia_cumulus-vx:5.12.0` image, and `sshpass`. Switch password
defaults to `Clab123!` (override with `CL_PASS` / `make PASS=...`).

## Targets

| Target | What it does |
|---|---|
| `make up` | Deploy three blank switches (the build is yours) |
| `make solution` | Apply the finished configs from `bootstrap/` |
| `make down` | Destroy the lab |
| `make ssh-r1` | Shell on a switch (r1, r2, r3) |
| `make logs-r1` | Follow FRR's log on a switch |
| `make audit` | Fabric health audit with raw JSON evidence |
| `make trace` | End-to-end loopback trace collection |
| `make break-2a` | Exercise 3: a session sticks in Connect; the fault is below BGP |
| `make heal-2a` | Undo break-2a |

## Addressing

| Node | ASN | Loopback |
|---|---|---|
| r1 | 65001 | 10.0.0.1/32 |
| r2 | 65002 | 10.0.0.2/32 |
| r3 | 65003 | 10.0.0.3/32 |

Links: r1:swp1 to r2:swp1, r2:swp2 to r3:swp1, r1:swp2 to r3:swp2. The
numbered build uses 10.0.1.0/31 on the r1-r2 link; the finished build is
unnumbered everywhere.

## Evidence

Every output printed in chapter 2 is quoted from the recorded build under
`audits/build_walkthrough_20260826/raw/`, with the audit and end-to-end
trace beside it. `audits/e2e_trace_ch02_20260826/TRACE.md` indexes all of it.
