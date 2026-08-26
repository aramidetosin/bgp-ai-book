# End-to-end traces: one journey per network (chapter 3)

Trace date: 2026-08-26. Lab: `ch03` (`bgpbook-ch03`), Cumulus Linux VX 5.12.0,
all node NICs at MTU 9216 to match the switches' default. Audit
`ch03_audit_20260826_185731` fully green at collection time: HTTP 200 across
the frontend, 15.0 Gbit/s across the backend, isolation confirmed, node
routing view as designed. Raw outputs in `raw/`; failure demos in
`../failure_demo_20260826/raw/`.

## 1. Journey 1: the frontend, routed

```
traceroute to 172.16.10.11 (172.16.10.11), 4 hops max, 46 byte packets
 1  172.16.20.1  0.159 ms
 2  172.16.10.11  0.239 ms
```

The client crosses fe-leaf's SVI (172.16.20.1) into the nodes' subnet: one
routed hop, ordinary IP, visible to traceroute like any service path.

## 2. Journey 2: the backend, flat

```
PING 172.31.1.12 (172.31.1.12) from 172.31.1.11 : 56(84) bytes of data.
64 bytes from 172.31.1.12: icmp_seq=1 ttl=64 time=0.201 ms
```

TTL 64 on arrival: zero routed hops. On this lab's single rail the two
backend NICs are adjacent, the way NICs on one rail segment are.

## 3. One node, two worlds

```
default via 172.16.10.1 dev eth1
172.16.10.0/24 dev eth1 proto kernel scope link src 172.16.10.11
172.31.1.0/24 dev eth2 proto kernel scope link src 172.31.1.11
```

nodea's default route points at the frontend; the backend exists only as a
connected subnet. From the client's side the backend is not merely
filtered but unroutable: `ip route get 172.31.1.11` falls to the default
gateway, and fe-leaf holds no route there (audit: unreachable).

## 4. The wire proof

Both workloads ran at once (five HTTP requests, a 6-second iperf3 run) while
both fabrics were captured simultaneously.

- fe-leaf capture: 7 KB total; every packet is a
  `172.16.20.100 <-> 172.16.10.11:80` flow.
- be-leaf capture: 1.9 GB on disk; the decoded capture holds 64,442 packets,
  every one between 172.31.1.11 and 172.31.1.12, and the opening SYN shows
  `mss 9176`: jumbo frames at work under the 9216 MTU.

Cross-contamination, counted with address-anchored greps over the full
captures:

- Backend addresses seen on the frontend fabric: **0 packets**
- Frontend addresses seen on the backend fabric: **0 packets**

## 5. The failure demos

Frontend NIC down for 8 seconds while the backend flow ran: iperf3 averaged
13.5 Gbit/s across the 16-second run with **zero retransmits**, every
interval healthy, while the client's curl timed out (exit 28). Backend NIC
down mid-run: iperf3 went to 0.00 bits/sec within the interval; the
client's curl answered `200 in 0.000622s` during the failure. Each
network's job dies with it, and neither notices the other's death.

## Platform notes recorded during the build

- **MTU: align at 9216.** Cumulus ports default to MTU 9216; containerlab
  gives node veths 9500. Frames sized for 9500 exceed the switch MTU and
  die silently: measured 30 Kbit/s at 9500-vs-9216, 12.8+ Gbit/s once the
  node NICs were pinned to 9216 (the topology now does this). An earlier
  note here blamed the emulated path for dropping jumbo frames; that was
  wrong, and the 9216-aligned numbers prove it.
- Taking a Linux interface down deletes routes through it, and up does not
  restore them; `make heal-frontend` re-adds nodea's default route.
