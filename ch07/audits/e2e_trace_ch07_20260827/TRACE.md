# End-to-end trace: the overlay on the core underlay (chapter 7)

Trace date: 2026-08-27. Base: the chapter 6 generated underlay
(`bgpbook-ch06`), Cumulus Linux VX 5.12.0, reference tuning in force.
Overlay applied by `overlay.sh` (every command in
`../overlay/apply_overlay.txt`), collected with the overlay healthy,
before the break-7a experiment. Audit `ch07_audit_20260827_060808` fully
green at collection time. Raw outputs in `raw/`.

## 1. The same sessions, one more payload

`raw/leaf01_summary.txt`: the L2VPN EVPN summary on leaf01 shows the two
fabric sessions (spine01, spine02) carrying the new address family,
PfxRcd 8 from each. The OPEN that negotiated it is captured in
`../overlay/open_capture.txt`: leaf01's OPEN carries two Multiprotocol
capabilities, AFI IPv4(1)/SAFI Unicast(1) and AFI 25/SAFI EVPN(70)
(tcpdump prints AFI 25 by its historical name VPLS), alongside the
Extended Next Hop and 4-byte AS capabilities recorded in earlier
chapters.

## 2. The route types, in the table

`raw/leaf04_evpn_table.txt`: leaf04's EVPN table with FRR's own legend,
then per-RD entries. Type-5 routes for TENANTA's 10.200.1.0/24 and the
VRF loopback 10.201.1.1 under RD 10.0.0.1:2 (leaf04's mirror sits under
RD 10.0.0.4:2), next hop 10.0.0.1 (the far VTEP's
loopback, received via spine01 and spine02: two paths, the underlay's
ECMP inherited), with the auto-derived RT:65101:4001 (ASN:VNI) and the
router MAC extended community. Type-2 MAC/IP and type-3 IMET entries for
both L2VNIs. `raw/leaf04_type5.txt` isolates the prefix routes.

## 3. The VNIs, on the box

`raw/leaf01_vnis.txt`: `show evpn vni` with L2VNIs 10100 (TENANTA, vlan
100) and 10200 (TENANTB, vlan 200), each with 1 remote VTEP, and L3VNI
4001 for TENANTA.

## 4. Two tenants, one subnet

`raw/tenant_a_ping.txt` and `raw/tenant_b_ping.txt`: leaf01 pings
10.200.1.4 in TENANTA and in TENANTB, both answered, each across its own
VNI, on the same overlapping 10.200.1.0/24. `raw/leaf01_vrf_a.txt` and
`raw/leaf01_vrf_b.txt`: the two VRF tables side by side; TENANTA holds
the type-5 destination 10.201.4.1 as an installed BGP route, and
TENANTB's table holds no trace of TENANTA's exports. `raw/underlay_route.txt`: the
underlay route to the far VTEP loopback, two ECMP next hops, unchanged
by everything above it.

## 5. The rest of the recorded set (../)

- `overlay/apply_overlay.txt`: every overlay command, per device, as
  applied.
- `overlay/mtu_probe.txt`: inner 9100 rides as one VXLAN frame (the
  capture shows `vni 4001` and the inner tenant addresses in clear);
  inner 9188 still delivers but the wire shows `truncated-ip - 54 bytes
  missing` plus a bare `ip-proto-17` continuation: the underlay silently
  fragmenting the outer packet past the encapsulation headroom.
- `overlay/tenantc_type5.txt`: exercise 1 recorded; a tenant exported
  from leaf01 only appears in leaf04's EVPN table (RD 10.0.0.1:5,
  RT:65101:4003) and is installed nowhere, because no local VRF imports
  that route target.
- `break7a/evidence.txt`: leaf04's TENANTA L3VNI mistyped to 4009. The
  routed tenant destination goes to 100% loss, the stretched segment and
  TENANTB keep working, the route vanishes from leaf01's VRF while the
  EVPN table still shows it carrying RT:65104:4009, and `show evpn vni`
  on leaf04 displays the mismatch in plain sight.
- `removal/after_regenerate.txt` and `removal/ch06_audit_after.txt`:
  after `make remove` regenerates the underlay from its spec: no EVPN
  address family, no VNIs, no tenant VRFs, and the complete chapter 6
  audit green again, cabling verdict included.
