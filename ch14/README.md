# Chapter 14: Storage Networks for Checkpointing

The storage fabric: two storage leafs, two spines, a storage array
dual-homed to both storage leafs (the routed-host pattern of chapter 9,
applied to a storage head), and four compute-node checkpoint writers
behind a compute leaf. The array advertises a storage VIP that reaches
every writer over ECMP across both leafs.

The synchronized burst in the lab is the checkpoint **restore**
direction, the array fanning out to every node at once, because a Linux
host shapes its egress faithfully (real queuing, then drop) where
containerlab's virtual switch ASIC models no buffers. The write
direction is symmetric; the chapter says so. Each array uplink's serve
rate is shaped with tc, standing in for a real storage head's absorb
rate.

## Targets

```
make up          # the storage fabric (chapter 6 underlay)
make setup       # the dual-homed array (VIP, four sinks) and the writers
make burst       # the synchronized restore burst, control flow alongside
make qos         # protect the control flow with a strict class, re-run
make degrade     # drown one array uplink, measure the checkpoint-time cost
make break-14a   # the burst starves the control flow, no QoS (make heal-14a)
make audit       # underlay, the VIP's ECMP, writer reach, cabling
make down
```

## Evidence

`audits/burst/` is the unprotected burst: aggregate ~4 Gbit/s across the
two shaped uplinks, and the control flow's latency tripling (0.5 ms
baseline to ~2.1 ms average, 3.3 ms peak) as it shares the FIFO.
`audits/qos/` is the same burst with the control class protected: the
bulk still floods to ~4 Gbit/s while the control flow drops back to
~0.34 ms. `audits/degrade/` is the drowned link: capacity halves from
4.01 to 2.03 Gbit/s, so a fixed checkpoint takes 1.98x as long, the
number chapter 8 promised chapter 14 would put on a partial failure.
`audits/break14a/` is the control flow starved (2.5 ms) for want of the
QoS class.

Honest limit: there is no access to the GPU nodes, so the real
checkpoint-burst shape from a training job is not captured here; the
lab reproduces the burst's structure (synchronized, many-to-one,
fate-sharing) with a traffic generator, and the sizing worked example
is arithmetic the reader re-runs with their own model.
