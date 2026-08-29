# Chapter 21: Running the Fabric (Day-2 Operations)

The book's capstone: one incident run end to end against the reference fabric,
with every tool the earlier chapters built. Game day injects one of five
undisclosed faults; you diagnose it with the chapter 19 observability stack,
write the post-mortem, and compare it against the reference.

## Prerequisites

- The chapter 16 fabric running (`cd ../ch16 && make up`).
- The chapter 19 stack up against it (`cd ../ch19 && make bmp-up`), so the BMP
  collector and the one-timeline are available to diagnose with.

## Targets

```
make gameday   # inject one of five undisclosed faults
make reveal    # reveal the injected fault and its reference post-mortem
make clear     # clear all faults, return the fabric to health
```

`./gameday.sh N` injects a specific fault (1 to 5) instead of a random one, for
practice against a known signature.

## The five faults

Each has a distinct signature across the tools you built, so the game is a test
of whether you can read them:

1. **Clean link failure.** The one-timeline moves both columns: BMP
   withdrawals and a stalled job.
2. **Gray failure (silent loss).** The job stalls while BMP stays flat. Routing
   silent, data plane bleeding: the diagnosis is the data plane.
3. **Flapping link.** BMP shows a high churn rate, the same prefixes withdrawn
   and re-announced, and the job never gets a clean run.
4. **Route leak.** BMP records an announcement of a prefix nobody allocated,
   while reachability looks fine. Only the routing history catches it.
5. **Session authentication teardown.** BMP records a peer-down that does not
   recover; one leaf loses a path to one spine, halving ECMP width while
   reachability holds.

## The loop is the lesson

The incident is not the point; the loop is. Alert, then the one-timeline, then
a first hypothesis, then a reproduction that tests it, then the fix as a pull
request against the spec (chapter 17), then the post-mortem, then a new pipeline
check (chapter 18) that keeps it fixed. `audits/gameday/` records a route-leak
run: the BMP collector catches the unplanned `10.66.0.0/16` while a ping test
would pass, and the reveal names the fault and hands back the reference
post-mortem, which ends in the new check that would have caught it.

## Reference post-mortems

`postmortems/faultN.md` is the reference write-up for each fault: its signature
across the chapter 19 stack, the root cause, the fix as a pull request, and the
new pipeline check. Write yours before revealing, then compare.

## Files

`gameday.sh` injects, `reveal.sh` reveals, `clear.sh` restores. `postmortems/`
holds the five references. `lib.sh` shared settings. All device access is a
fixed ssh helper, never a bash loop over ssh.
