# Post-mortem: session authentication teardown

**Signature.** BMP records a peer-down for one session, and it does not come
back: the session cycles in Connect rather than reaching Established. One leaf
loses a path to one spine, so ECMP width to some destinations halves while
reachability holds.

**Root cause.** A session-authentication key mismatch: a password was changed on
one end and not the other, so the TCP connection cannot complete. The same
mechanism that stops an attacker without the key (chapter 20) stops a
legitimate peer when the key is wrong.

**Fix.** Correct the key on both ends, ideally as one coordinated change through
the push (chapter 17). A key rotation drill (chapter 20 exercise) is how you
avoid causing this in the first place.

**New check.** A golden-snapshot alert on any session that leaves Established
and does not return within a convergence window, so a wedged session pages
instead of silently halving redundancy.
