# Chapter 16: Failure Modes at Training Scale

The standard chapter 6 fabric (4 leafs, 2 spines, eBGP unnumbered) with a
server on every leaf, so the four servers form a heartbeat mesh that
stands in for a collective library's step timing. A "step" is a probe
across the fabric; a stalled step is a lost probe. Failures are injected
on the fabric links, and the detection ladder (hold-timer slow versus BFD
fast) decides how many steps a failure stalls.

## Targets

```
make up      # the fabric and the four-node mesh
make sim     # the healthy mesh: every rank reaches every rank, sub-ms
make fail    # a clean link failure, measured without BFD then with it
make gray    # a gray failure: silent loss while BGP stays Established
make flap    # a flapping link: repeated stalls, no clean run
make audit   # sessions, BFD state, the mesh fully connected
make down
```

## The three failure classes

`audits/down/` is the headline: the same clean link failure measured
twice. Without BFD the far spine does not see the carrier drop (the
containerlab quirk chapter 1 named), so it keeps forwarding into the dead
link until its BGP hold timer expires, about 4 to 5 seconds of 100%
stalled steps. With BFD the same failure is caught in a fraction of a
second, one partly-stalled step and done. Same break, two detection
times: the ladder chapter 6 measured, in stalled collective steps.

`audits/gray/` is a gray failure: 20% frame loss on both of leaf01's
uplinks, which keeps carrier and keeps the BGP keepalives flowing, so
every session reads Established with a full prefix count while the data
plane silently loses about one step in five. "Reachability restored" and
"job healthy" are different claims, and this is the gap.

`audits/flap/` is a flapping link, down 2 seconds and up 4, without BFD.
Each flap restarts the multi-second detection clock, so the mesh is
perpetually reconverging and never gets a clean run: the total stalled
step time across a flap window exceeds a single hard failure, which is
exercise 1's point.

## Real-hardware evidence

The monitoring surface this chapter defines is read read-only from the
two B300 GPU nodes (`../ch13/hw/b300/`): the host RoCE error counters
(`out_of_sequence`, `packet_seq_err`, `roce_adp_retrans`,
`local_ack_timeout_err`, `np_cnp_sent`) that a gray failure would move.
On the idle testbed they read zero, the healthy baseline, and the alert
is the first non-zero, the derivative rather than the value.

## Honest limits

The heartbeat mesh is a step-timing proxy, not a real collective library:
it reproduces the structure of step-time damage (a stalled step gated on
the slowest path) without running NCCL. Staging a real collective-library
timeline during a port flap would mean running a job on the production
B300 GPUs, which this book does not do. Failures are injected with
`ip link` and `tc netem` on the fabric links; the NVUE admin-status must
be reconciled after `ip link` toggling (the `heal` step does this), a
platform quirk noted in appendix A.
