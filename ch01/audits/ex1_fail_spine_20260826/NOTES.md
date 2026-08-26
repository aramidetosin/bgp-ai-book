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

`docker start` alone does not heal a stopped node: the containerlab veth
links died with the container's old network namespace, and the VM launcher
waits forever for interfaces that no longer exist. `make heal-spine`
recreates the four links with `containerlab tools veth create`, after which
the VM boots and rejoins on its saved configuration.
