# Chapter 8: ECMP and the Elephant Flow Problem

The collision fabric: two leafs, two spines, and capacity made deliberately
unequal. leaf01 attaches to each spine twice, so its four-way ECMP fan hosts
the collision ladder; leaf02 attaches once per spine and becomes the observer
that cannot see remote capacity change. Generated from `spec.yml` by
`gen_topo.py`, same contract as chapters 5 and 6; the one new spec field is
`uplinks`, links per leaf per spine.

## Targets

```
make up           # generate and deploy the fabric
make verify       # LLDP against intent.json
make audit        # sessions, both ECMP fans, hash policy, end to end
make trace        # routes, kernel next-hop groups, traceroute spread
make collide      # the ladder: 1, 4, 4, 16 flows on leaf01's four uplinks
make wecmp        # fail leaf01 swp5, then weight with the link bandwidth
                  # community (make heal-wecmp undoes it)
make pin          # policy pinning, two acts (make unpin undoes it)
make down         # destroy the lab
```

`make collide` runs iperf3 from server01 and prints per-uplink transmit
deltas: one flow lands on one link, four flows leave a link empty on both
rolls, sixteen flows spread but stay lumpy.

`make wecmp` runs three phases from leaf02's side: the healthy baseline,
the failure that leaf02's routing table cannot see (same `nhid`, same two
next hops), and the spines advertising their real path counts with
`ext-community-bw multipaths`, which turns into kernel next-hop weights
(255 against 127) and a measured two-to-one split.

`make pin` records both acts: the platform's PBR map, which reports
`Installed: yes` while `ip route get` proves traffic still follows the
main table's ECMP, and the kernel policy-routing pin (a specific prefix
via spine01's link-local, plus one rule) that moves 100% of the matched
flows onto swp2. See the appendix A quirk before trusting `show pbr map`.

## Evidence

`audits/` holds the recorded runs the chapter quotes: `ch08_audit_*` (the
green baseline), `collide/` (the ladder with per-link megabytes and
percentages), `wecmp/` (three phases, including the `LB:65100:250000
(2.000 Mbps)` extended communities and the weighted next-hop group),
`pin/` (both acts plus `table10000.txt`, the empty policy table behind
the daemon's `Installed: yes`), and `e2e_trace_ch08_*` (routes, kernel
groups, traceroute spread).

The lab leaves the fabric healthy after `make heal-wecmp` and `make unpin`;
`make audit` should end green at any point.
