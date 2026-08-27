# Chapter 7 lab: the overlay, added and removed

The EVPN-VXLAN overlay applied as recorded steps to chapter 6's running
generated underlay, and removed by regenerating that underlay from its
spec. Two tenants on leaf01 and leaf04: TENANTA routed (L2VNI 10100,
L3VNI 4001, type-5 exports), TENANTB stretched layer 2 only (L2VNI
10200), with deliberately overlapping subnets between them as the
isolation proof. Spines carry the new address family and nothing else;
leaf02 and leaf03 are untouched.

## Requirements

The chapter 6 lab (`../ch06`), deployed and healthy. Everything here
runs against it over SSH; there is no topology of its own.

## Targets

| Target | What it does |
|---|---|
| `make underlay` | Regenerate and deploy the chapter 6 fabric from its spec (same action as `make remove`) |
| `make overlay` | Apply the overlay as recorded steps, capturing the OPEN renegotiation |
| `make audit` | Underlay still green, EVPN sessions, route types 2/3/5, both tenants, isolation, type-5 next hop |
| `make trace` | Collect the evidence quoted in the chapter |
| `make mtu` | The encapsulation headroom probe (and the silent fragmentation past it) |
| `make tenant-c` | Exercise 1 recorded: a one-sided type-5 export, then removed |
| `make break-7a` | leaf04's TENANTA L3VNI mistyped to 4009: the routed tenant dies, the stretched segment survives |
| `make heal-7a` | L3VNI back to 4001 |
| `make remove` | Regenerate the chapter 6 underlay from its spec; the overlay is gone because the spec never described it |

## The overlay, in numbers

| Element | Value |
|---|---|
| VTEPs | leaf01 (10.0.0.1), leaf04 (10.0.0.4): the loopbacks the address plan reserved |
| TENANTA | VRF, vlan 100 / L2VNI 10100, L3VNI 4001, SVIs 10.200.1.1 and .4/24, VRF loopbacks 10.201.1.1 and 10.201.4.1 exported as type-5 |
| TENANTB | VRF, vlan 200 / L2VNI 10200, SVIs on the same 10.200.1.0/24 as TENANTA |
| EVPN sessions | the chapter 6 fabric sessions, with `l2vpn-evpn` enabled per neighbor |

## Evidence

Recorded runs backing every output printed in chapter 7 live under
`audits/`: `overlay/` (the applied commands, the captured OPEN with the
EVPN capability, the MTU probes with the wire captures showing single
frames inside the headroom and outer fragmentation past it, the tenant-c
type-5 recording, and the NVUE syntax probes), the green audit, `break7a/` (the L3VNI mismatch
evidence), `removal/` (the fabric after regeneration: no address family,
no VNIs, no VRFs, chapter 6 audit green), and the trace indexed by its
`TRACE.md`.
