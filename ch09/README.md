# Chapter 9: BGP to the Server

The host fabric: three leafs, two spines, host01 dual-homed to the
leaf01/leaf02 ToR pair, server03 behind leaf03 as the remote vantage
point. Generated from `spec.yml`; the base bootstrap is the plain
chapter 6 underlay with host01's ports declared but unconfigured,
because wiring them is the chapter. Both designs apply to the base as
recorded steps; `make base` regenerates between them.

## Targets

```
make up           # generate and deploy the base fabric
make audit        # fabric green, LLDP, which design is applied
make mh           # design A: EVPN multihoming toward a bonded host01
make base         # regenerate the design-free base
make routed       # design B: the routed host (FRR, filter, relax ladder)
make bfd          # exercise 1: BFD on the host sessions, pull re-measured
make break-9a     # the asymmetric return path blackhole (make heal-9a)
make down         # destroy
```

The host image (`Dockerfile.host`) is FRR 9.1.0 with bgpd and bfdd
enabled at build time: restarting FRR's PID 1 restarts the container
and takes the lab links with it, so configuration loads live through
`vtysh -f` instead.

## Evidence

`audits/mh/` records design A: the bond seeing one LACP partner
(44:38:39:be:ef:aa, the segment's MAC, from both leafs), the ES with
its DF and peer VTEP, type-1 and type-4 routes in the fabric, and the
mid-ping NIC pull in both directions, where flows whose fabric leg
crossed the failed leaf blackholed: the virtual dataplane has no ES
backup path, and the chapter uses that honestly.

`audits/routed/` records design B: sessions both sides, the import
filter accepting 1 of 10 offered prefixes, the multipath-relax ladder
on the host and then fabric-wide, RFC 5549 in `ip route get`, and the
default-timer NIC pull (41% loss over the 20-second window) with the
BGP UPDATE captured on the surviving link. `audits/bfd/` repeats the
pull with BFD: 3% loss. `audits/break9a/` is the advertise-only host
trap: NIC up, session Connect, inbound delivered via leaf02, replies
dead.

Chapter quirk found here (appendix A): a port newly enslaved to a bond
stays NO-CARRIER on VX until switchd restarts; `make mh` includes the
restart as a recorded step.
