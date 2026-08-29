# Post-mortem: route leak

**Signature.** BMP records an announcement of a prefix that belongs to no plan:
a leaf originates a large aggregate it should never advertise. The prefix
appears in the collector's event log with the leaf that leaked it named by its
peer address. Reachability may look fine, which is why only the routing history
catches it.

**Root cause.** A misconfiguration (a stray `network` statement, a
redistribution without a filter) caused a device to originate a prefix outside
its allocation. On a fabric without egress filters this can black-hole or
hijack traffic to the leaked range.

**Fix.** Remove the offending statement as a pull request against the spec
(chapter 17), so the leak cannot come back by hand. Add the missing egress
filter on the device's advertisements.

**New check.** A chapter 18 property check that every device originates only
prefixes inside its allocation, so a leak fails the pipeline before it ships.
