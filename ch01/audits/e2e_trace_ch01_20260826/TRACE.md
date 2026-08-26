# End-to-end trace: server01 to server03 (chapter 1 fabric)

Trace date: 2026-08-26. Lab: `labs/ch01` (`bgpbook-ch01`), Cumulus Linux VX 5.12.0 with FRRouting 8.4.3, deployed on the office containerlab host. Audit `ch01_audit_20260826_153044` was fully green at collection time: 16/16 BGP sessions established, 12/12 ECMP checks at 2 next-hops, 0% loss both directions. Every claim below was verified on the box; raw outputs for everything quoted here are in `raw/` next to this file.

Source: `server01` (behind leaf01), 172.16.1.10/24, default via 172.16.1.1.
Destination: `server03` (behind leaf03), 172.16.3.10/24, default via 172.16.3.1.

## 1. The live traceroute, decoded

```
traceroute to 172.16.3.10 (172.16.3.10), 6 hops max, 46 byte packets
 1  172.16.1.1  0.163 ms  0.027 ms  0.047 ms
 2  10.0.0.101  0.206 ms  10.0.0.102  0.223 ms  10.0.0.101  0.070 ms
 3  10.0.0.3  0.335 ms  0.168 ms  0.150 ms
 4  172.16.3.10  0.132 ms  0.134 ms  0.108 ms
```

| Hop | Reported IP | Actual device | What happens there |
|---|---|---|---|
| 1 | 172.16.1.1 | leaf01 | The server's default gateway (leaf01's swp1 address). VRF default lookup for 172.16.3.0/24: BGP route, 2-way ECMP toward both spines (section 2). |
| 2 | 10.0.0.101 / 10.0.0.102 | spine01 / spine02 | The 3-probe run landed on both spines: flow-hash ECMP live on the wire. The fabric links are unnumbered, so each spine sources its ICMP time-exceeded from its loopback. Each spine has a single path onward: leaf03 owns the destination subnet. |
| 3 | 10.0.0.3 | leaf03 | Same unnumbered story: reply sourced from leaf03's loopback. The subnet is connected on swp1; the host is a REACHABLE neighbor entry (raw/leaf03_connected.txt). |
| 4 | 172.16.3.10 | server03 | Destination. |

Echo replies arrive with `ttl=61`: exactly 3 routed hops on the return path (64 - 61), the mirror of hops 1 to 3.

## 2. FIB at each decision point

leaf01, three layers of the same route (BGP table, RIB, kernel FIB):

```
BGP routing table entry for 172.16.3.0/24
Paths: (2 available, best #1, table default)
  65100 65103
    fe80::a8c1:abff:fe48:b819 (spine01) from spine01(swp2) (10.0.0.101)
      Origin incomplete, valid, external, multipath, bestpath-from-AS 65100, best (Older Path)
  65100 65103
    fe80::a8c1:abff:fe09:4ce7 (spine02) from spine02(swp3) (10.0.0.102)
      Origin incomplete, valid, external, multipath
```

```
Routing entry for 172.16.3.0/24
  Known via "bgp", distance 20, metric 0, best
  * fe80::a8c1:abff:fe09:4ce7, via swp3, weight 1
  * fe80::a8c1:abff:fe48:b819, via swp2, weight 1
```

```
172.16.3.0/24 nhid 40 proto bgp metric 20
id 40 group 29/41 proto zebra
id 29 via fe80::a8c1:abff:fe09:4ce7 dev swp3 scope link proto zebra
id 41 via fe80::a8c1:abff:fe48:b819 dev swp2 scope link proto zebra
```

The kernel route points at nexthop group 40, whose members 29 and 41 are the two spine-facing interfaces with IPv6 link-local next-hops (BGP unnumbered: IPv4 routes carried with the RFC 8950 next-hop encoding).

spine01 has a single path (leaf03 originates the subnet): `via swp3` toward leaf03. spine02 mirrors it. leaf03 has the subnet directly connected on swp1.

## 3. The control plane behind it

Both of leaf01's paths carry AS path `65100 65103`: through a spine (65100, shared by both), originated by leaf03 (65103). Both marked `multipath`, both installed. Loop prevention needs no extra mechanism: any route re-advertised back toward a device whose ASN is already in the path is rejected on arrival.

## 4. The failure event (spine01-to-leaf01 link)

Observed during the recorded failure run (raw captures from `make capture`, log lines from leaf01):

- spine01, whose interface went down, reacted immediately and sent withdrawals to its three remaining peers. On the wire: **3 UPDATE messages from spine01**.
- leaf01's side of the link stayed physically up (emulated links do not propagate carrier loss the way real optics usually do), so leaf01 only declared the session dead when the hold timer expired, 9 seconds after the failure:

```
15:20:22 bgpd[4003]: %NOTIFICATION: sent to neighbor swp2 4/0 (Hold Timer Expired) 0 bytes
15:20:22 bgpd[4003]: %ADJCHANGE: neighbor swp2(spine01) in vrf default Down BGP Notification send
```

- At that point leaf01 sent exactly **1 UPDATE to spine02**: withdrawing the path to spine01's loopback it had been re-advertising. spine02 received it and discarded it (its own ASN is in the path). spine02's own sessions never moved: uptime counters ran through the whole event.
- Fabric-wide wire truth: **4 UPDATE messages total** (spine01: 3 sent; leaf01: 1 sent; leaf03: 1 received of spine01's 3; spine02: 1 received and rejected). The continuous ping between the servers recorded **0% loss** in this run; the flow had hashed onto the surviving spine. A flow hashed onto the failed path would have blackholed for up to the 9-second hold time: that asymmetry is chapter 6's opening argument for BFD.
