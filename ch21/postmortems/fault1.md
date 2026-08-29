# Post-mortem: clean link failure

**Signature.** The one-timeline shows the job step stall to 100% and, on the
same clock, BMP records withdrawals: the affected leaf's loopback and server
subnet leave the fabric. Both the routing view and the job view move together.

**Root cause.** A fabric link (or an optic that dropped carrier) failed. ECMP
had an alternate path, so the outage is bounded by detection time, not by the
absence of a path.

**Fix.** None to the config: the fabric did what it was built to do. If the
stall exceeded the collective timeout, the fix is faster detection (BFD, chapter
6), not a topology change.

**New check.** A golden-snapshot alert that pages when a leaf's session count
drops, so the failure is a page and not a surprise at the next job restart.
