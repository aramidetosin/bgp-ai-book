# End-to-end traces: one journey per network (chapter 4)

Trace date: 2026-08-26. Lab: `ch04` (`bgpbook-ch04`), Cumulus Linux VX 5.12.0.
Audit `ch04_audit_20260826_195441` fully green at collection time: all four
networks doing their jobs, the VRF fencing the BMC both ways, and a perfectly
diagonal isolation matrix. Raw outputs in `raw/`.

## 1. Four journeys

- **Frontend, routed:** client to node in two hops through fe-leaf's SVI
  (`raw/frontend_trace.txt`).
- **Backend, flat:** node to gpu-peer, TTL 64, zero routed hops
  (`raw/backend_ping.txt`).
- **Storage, routed:** node to storage-srv in two hops through st-leaf's SVI
  at 172.30.1.1 (`raw/storage_trace.txt`), fetching the 512 MB dataset at
  roughly 2.3 GB/s in this emulated fabric (`raw/storage_fetch.txt`).
- **Out-of-band, flat and deliberately boring:** management station to the
  node's BMC port, 0% loss (`raw/oob_ping.txt`).

## 2. One node, four worlds

The node's default-VRF routing table is the chapter's anatomy lesson:

```
default via 172.16.10.1 dev eth1
172.16.10.0/24 dev eth1 proto kernel scope link src 172.16.10.11
172.30.1.0/24 dev eth3 proto kernel scope link src 172.30.1.11
172.30.2.0/24 via 172.30.1.1 dev eth3
172.31.1.0/24 dev eth2 proto kernel scope link src 172.31.1.11
```

Default via the frontend, the backend rail connected-only, the storage
subnets reached by a specific static route, and the BMC absent entirely,
because it lives in its own VRF:

```
$ ip route show vrf mgmt
10.99.0.0/24 dev eth4 proto kernel scope link src 10.99.0.11
```

The audit proves the fence in both directions: the default VRF cannot reach
the OOB subnet, and `ip vrf exec mgmt` can.

## 3. The isolation matrix

All four workloads ran at once while all four fabrics were captured
simultaneously on their node-facing ports. Packets counted per capture, by
subnet family:

```
capture    frontend    backend    storage        oob
fe-leaf          36          0          0          0
be-leaf           0      97671          0          0
st-leaf           0          0      13282          0
oob-sw            0          0          0         10
```

A diagonal matrix: each fabric carried its own traffic and not one packet
of anyone else's.

## 4. The out-of-band survival demo

With eth1, eth2, and eth3 all down on the node (frontend, backend, and
storage dead), the frontend confirmed dead (`curl` 000, exit 28) while the
management station pinged the BMC port with 0% loss
(`raw/blackout_curl.txt`, `raw/blackout_oob.txt`). The network that works
when everything else doesn't, demonstrated rather than asserted.
