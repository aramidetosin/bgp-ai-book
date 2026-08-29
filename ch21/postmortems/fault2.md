# Post-mortem: gray failure (silent loss)

**Signature.** The one-timeline shows the job step stall climbing while BMP
stays flat: every session Established, no withdrawals, no churn. Routing is
silent and the job is bleeding. This is the diagnostic that sends the
investigation to the data plane, not the control plane.

**Root cause.** A degrading link corrupts a fraction of frames while keeping
carrier and keeping the keepalives flowing, so no routing timer fires. The
data-plane counter (host out-of-sequence, or interface errors) is the only
thing that sees it.

**Fix.** Drain the affected rail (chapter 16), replace the optic, restore. The
routing never needed changing; the hardware did.

**New check.** A first-non-zero alert on the per-port error and host
out-of-sequence counters, so the next gray failure pages the moment the counter
leaves zero rather than after a job hangs.
