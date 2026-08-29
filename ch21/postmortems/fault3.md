# Post-mortem: flapping link

**Signature.** BMP shows a high churn rate on one peer: the same prefixes
withdrawn and re-announced over and over. The job step time stalls repeatedly
and never gets a clean run, because the fabric is perpetually reconverging.

**Root cause.** A link that fails and recovers on a cycle. Each recovery looks
healthy long enough to be trusted with traffic, then fails again. A flapping
component hurts more than a dead one, because a dead one is routed around once.

**Fix.** Pin the flapping interface down (drain it) until the hardware is
replaced, converting a repeating outage into one clean reroute. Link-flap
damping is the standing control.

**New check.** An alert on churn rate per peer above a threshold sustained for
a few minutes, which catches the flap that session-state monitoring misses
because it reconverges between polls.
