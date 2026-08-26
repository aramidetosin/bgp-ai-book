# Exercise 1 recorded run: killing spine01 entirely

Run date: 2026-08-26. Method: continuous ping from server03 to server01
running, then `make fail-spine` (stops the spine01 container). Collected
six seconds after the stop.

## Timeline

- `docker stop` issued at **16:25:22.087 UTC**.
- leaf03's session to spine01 declared down at **16:25:27.505 UTC**, about
  5.4 seconds later. The gap is the container's graceful-shutdown window;
  once the container's namespace went away, the leaf-side link lost carrier
  and detection was immediate (contrast with the chapter's `fail-link` demo,
  where the leaf side waits out the 9 second hold timer):

```
2026-08-26T16:25:27.505858+00:00 leaf03 bgpd[3996]: [PXVXG-TFNNT] %ADJCHANGE:
  neighbor swp2(spine01) in vrf default Down BGP Notification send
```

## Reachability through the event

leaf03's route to leaf01's subnet immediately after the failure, one path
remaining, via spine02:

```
Known via "bgp", distance 20, metric 0, best
  * fe80::a8c1:abff:fe87:9190, via swp3, weight 1
```

The ping recorded **zero loss** across the entire spine death (11 sent, 11
received). Reachability never depended on spine01 alone: ECMP had a live
member through spine02 at every moment.

## Recovery note

`docker start` alone does not heal a stopped node. Three separate things
break when the container stops, and the recorded recovery confirmed each
one. The veth links die with the container's network namespace and must be
recreated using the container-side names, eth1 through eth4 (the VM maps
them to swp names internally; links created with swp names are invisible
to the launcher). They must exist within the launcher's startup wait, or
qemu never starts (links created 7 minutes late left the launcher stalled;
links created seconds after a restart let it proceed within its next
poll). And each leaf's replacement eth2 needs its tc redirect to the VM
tap rebuilt, because the old rules pointed at the destroyed device.

`make heal-spine` runs the whole sequence (see `heal-spine.sh`). After
this recovery, the full fabric audit came back green:
`ch01_audit_20260826_165442`, all sessions established, all ECMP checks at
two next hops, zero loss both directions.
