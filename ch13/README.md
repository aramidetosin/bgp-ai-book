# Chapter 13: RoCEv2 on a BGP Underlay

Two halves, honestly separated. The containerlab fabric (two rail
leafs, two spines, two GPU-node stand-ins) validates the QoS
configuration: the RoCE lossless preset applied fabric-wide, and a
consistency checker that resolves the RoCE data DSCP the whole way
down (DSCP to switch-priority to egress queue) on every hop. The
dataplane behaviour, PFC, ECN marking, buffers, is not modelled by
containerlab. The real counters and the real config come from the
hardware testbed under `hw/`.

## Targets

```
make up          # the backend fabric (chapter 6 underlay)
make roce        # apply the RoCE preset, read back what it generated
make qoscheck    # resolve DSCP 26 to a queue on every hop, verify consistent
make break-13a   # one leaf sends the RoCE class to the wrong queue (make heal-13a)
make audit       # underlay, preset, consistency, cabling
make hw          # re-collect the hardware evidence (read-only, needs testbed)
make down
```

## The hardware evidence (`hw/`)

Collected read-only from the backend RoCE switch (Enterprise SONiC on a
Supermicro SSE-T8164, Broadcom ASIC) with `hw/collect.sh`; every file
is verbatim `show`/`sonic-cfggen -d` output, no configuration changed.
It holds the real RoCE lossless config the chapter audits: the DSCP to
traffic-class map (26 to TC3 for data, 48 to TC6 for CNP), the queue
and priority-group maps, the WRED/ECN profile (mark from 1 MiB to 2
MiB), PFC on priorities 3 and 4, the PFC watchdog (200 ms detect, 400
ms restore, drop), the buffer profiles keyed by speed and cable length
(xoff 446024 bytes for 400G at 40 m), the DWRR/STRICT scheduler, and
the counters: queue 3 carried 110 GB of RoCE with zero drops and zero
PFC pauses over 69 days of uptime.

Two honest limits the chapter states plainly: the testbed's rails are
VLANs today, not the routed backend the book designs (the QoS is
orthogonal and transfers unchanged), and there is no access to the GPU
nodes, so no live congestion event (a PFC storm, an ECN-mark spike)
can be generated here; that capture is one to collect on loaded
hardware, and the chapter says so rather than staging it.
