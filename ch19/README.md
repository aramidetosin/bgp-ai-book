# Chapter 19: Observability

The chapter 16 heartbeat-mesh fabric (`bgpbook-ch16`), instrumented so the
job's step time and the fabric's routing events share one clock. The mesh's
cross-fabric probe (server01 to server04) stands in for a collective step; BMP
streams every BGP change off the switches to a collector. The point the lab
makes: a clean failure shows on both the job and routing, and a gray failure
shows only on the job, invisible to routing, which is the gap chapter 16
opened.

## Prerequisites

- The chapter 16 fabric running (`cd ../ch16 && make up`).
- The collector runs on a server (fabric-reachable from every switch; the
  switches' default VRF cannot reach the management network). The server image
  ships python3.

## Targets

```
make bmp-up      # load FRR's BMP module, start the collector, enable BMP
make timeline    # one clock: routing (BMP) vs the job (mesh step), gray vs clean
make bmp-query   # which prefixes churned during an incident, from BMP alone
make bmp-down    # remove BMP config, stop the collector
```

## BMP collection

Cumulus VX ships `bgpd_bmp.so` but does not start bgpd with `-M bmp`, so
`enablebmp.py` adds the module and restarts FRR (a one-time lab-platform step;
real Cumulus enables it the same way). `bmpconfig.py` points each switch's FRR
at the collector. `bmpcollect.py` is a BMP station (RFC 7854): it decodes
peer-up, peer-down, and route-monitoring messages, pulls the announced and
withdrawn prefixes out of each embedded BGP UPDATE (classic and MP-BGP, since
the fabric carries IPv4 over unnumbered with extended next-hop), and appends
one JSON event per change. The RIB's whole history then lives off-box, so
"which prefixes churned during the incident window" is a query, not a switch
login.

## Evidence (`audits/`)

- `bmp/` the churn query: leaf04 drops off the fabric and returns, and BMP
  alone names the prefixes that moved (its loopback `10.0.0.4/32` and server
  subnet `172.16.4.0/24`), withdrawn at the failure and re-announced at
  recovery, without touching a switch. `sample-events.jsonl` shows the decoded
  peer-up and withdrawal events.
- `timeline/` the one-clock view. Healthy: routing quiet, job clean. Gray
  failure (20% loss, sessions stay up): routing silent (zero BMP events), job
  bleeding (steps stall). Clean failure (leaf04 down): routing sees it (BMP
  withdrawals), job stalls. The gray row and the clean row side by side are
  the chapter: the dashboard alone agrees with the job on one and not the
  other.

## Where the collector runs

The switches reach the collector through the fabric, not the management
network (their bgpd is in the default VRF, which has no route to the
management subnet). So the collector binds on a server the fabric routes to.
On a production fabric the collector is a reachable host or a route-reflector
adjacent station; the principle is the same.

## Files

`enablebmp.py`, `bmpconfig.py` set up BMP; `bmpcollect.py` is the collector;
`timeline.sh` and `bmpquery.sh` are the evidence runs. All device access is
Python subprocess or a fixed ssh helper, never a bash loop over ssh (which
truncates on this host). `lib.sh` shared shell settings.
