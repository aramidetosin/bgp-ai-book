# Chapter 11: Service Exposure

Runs on the chapter 10 lab (bgpbook-ch10): deploy that first
(`ch10: make up cluster bgp`). Two services front one streaming
deployment: `inference` (172.16.200.1, the routed pool, the anycast
build) and `inference-l2` (172.16.1.200, inside rack1's subnet, the
layer 2 pattern and the migration subject).

## Targets

```
make svc         # the streaming service, both VIPs, the address pool
make l2          # lease, ARP evidence, the trombone, the takeover truths
make bgp         # filter growth, anycast routes, withdrawal timing
make migrate     # L2 to BGP and back, probe running, zero-gap
make anycast     # eTP Local, streams, rude and polite removals
make break-11a   # served from one leaf only (make heal-11a)
```

## Evidence, and what it honestly shows

`audits/l2/` records the leader's MAC in the client's ARP table, the
routed client served through the segment gateway trombone, and the
chapter's sharpest findings: a leader whose segment NIC dies keeps the
lease (48 recorded seconds of outage, ending only at link repair), and
an agent restarted while its device is down re-acquires the lease it
cannot serve. `audits/bgpsvc/` records the anycast (one path per
advertising node, an ECMP group on a nodeless leaf) and withdrawal
timing (1 to 7 second flow outages against the 9-second hold; the
Cilium control plane speaks no BFD). `audits/migrate/` records the
zero-gap two-label migration, both directions. `audits/anycast/`
records the drain boundary: withdrawal protects new connections;
in-flight external streams die with their backend's service-map entry
however politely the pod is treated. `audits/break11a/` is the
one-advertiser anycast.

Probe discipline throughout: VIPs answer their service port, not ICMP,
and success is the HTTP code, never curl's exit status on a stream.
