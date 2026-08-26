# End-to-end trace: r1's loopback to r3's loopback (chapter 2 triangle)

Trace date: 2026-08-26. Lab: `ch02` (`bgpbook-ch02`), Cumulus Linux VX 5.12.0
with FRRouting 8.4.3. Audit `ch02_audit_20260826_174535` fully green at
collection time: 6/6 sessions established, r3 holding both paths to r1's
loopback, 0% loss on both loopback-to-loopback pings. Raw outputs for
everything quoted here are in `raw/`; the staged build outputs the chapter
quotes are in `../build_walkthrough_20260826/raw/`.

## 1. The path

ICMP traceroute from r1, sourced from its loopback (UDP probes are dropped
by Cumulus's default control-plane ACLs, a lab note worth remembering):

```
traceroute to 10.0.0.3 (10.0.0.3), 30 hops max, 60 byte packets
 1  10.0.0.3  0.194 ms
```

One hop: r1 and r3 are directly connected, and the best path is the direct
link (AS path `65003`), not the detour through r2 (`65002 65003`). The ping
evidence agrees: 0% loss, and the BGP view on each end shows both paths in
the table with the direct one marked `best (AS Path)`.

## 2. What each device knows

- r1 for `10.0.0.3/32`: two paths, best is direct via swp2 (`65003`),
  alternate via r2 (`65002 65003`). Raw: `raw/r1_bgp_r3lo.txt`.
- r3 for `10.0.0.1/32`: the mirror image. Raw: `raw/r3_bgp_r1lo.txt`.
- r2 as transit: single best path to each loopback, learned directly from
  its owner. Raw: `raw/r2_transit.txt`.

## 3. The build evidence behind the chapter

The chapter walks a staged build, and every stage's output is committed
under `../build_walkthrough_20260826/raw/`:

| Stage | Evidence |
|---|---|
| Numbered peering r1 to r2 | `r1_numbered_summary.txt`, `r1_numbered_route.txt`, `r1_numbered_config.txt` |
| Session establishment on the wire | `r1_session_establishment_decode.txt` (SYN, an RST while r2 was still unconfigured, then the OPEN with AS, hold time, router ID, and capabilities) |
| Deliberate remote-as mismatch | `r1_badas_summary.txt` (Idle), `r1_badas_log.txt`, `r1_badas_decode.txt` (NOTIFICATION: OPEN Message Error, Bad Peer AS) |
| Conversion to unnumbered | `r1_unnumbered_summary.txt`, `r1_unnumbered_route.txt` (same route, next hop now IPv6 link-local), `r1_unnumbered_capabilities.txt` (Extended nexthop: advertised and received) |
| The full triangle | `r1_triangle_summary.txt`, `r3_two_paths.txt` (best chosen on AS path length, stated by FRR) |
| Loop prevention on the wire | `r1_loop_prevention_decode.txt` (r1's own prefix arriving back on both links, its own ASN in both paths), `r1_own_prefix.txt` (table holds only the Local path) |
| Prepending (exercise 1) | `r3_after_prepend.txt` (direct path now three ASNs long, best flips to r2, `best (AS Path)`) |
| Community and local preference (exercise 1) | `r3_community_localpref.txt` (`Community: 65001:100`, `localpref 200`, `best (Local Pref)`) |
| break-2a (exercise 3) | `r1_break2a_summary.txt` (Connect), `r1_break2a_syn_retries.txt` (SYNs with no answer), `r1_break2a_healed.txt` |
