# Chapter 20: Hardening the Fabric

Red-teams the chapter 9 routed-host session (`bgpbook-ch09`): a compromised
host attacks the fabric through its BGP session, and the per-peer controls
stop it. The threat model here is a compromised host or pod inside the fabric,
not a distant hijacker, so the controls are the ones on the host-facing
session: the import filter and prefix limit chapter 9 built, completed with
session authentication and GTSM.

## Prerequisites

- The chapter 9 fabric running (`cd ../ch09 && make up`). `host01` is the
  routed FRR host we treat as compromised; `leaf01` is its ToR.

## Targets

```
make redteam   # a default-route hijack and a bogus prefix, filtered;
               # then a prefix flood, torn down by maximum-prefix
make harden    # complete the session: TCP-AO checked, MD5 enforced, GTSM added
```

## What the red-team shows (`audits/redteam/`)

The compromised host advertises a default route (`0.0.0.0/0`), a bogus prefix
(`10.66.66.0/24`), and its one legitimate `/32`. The leaf receives all three,
and the import filter installs only the `/32`: the accepted-prefix count on
the session is 1. An unhardened leaf installs whatever it receives, so the
attacker's default route would become the pod's gateway and its traffic would
route through a compromised node. The filter drops the hijack at the door.
Then the host floods eight extra `/32`s that pass the filter, and the
`maximum-prefix` limit tears the session down (`Idle (PfxCt)`) rather than
letting the flood exhaust the leaf's RIB.

## What hardening completes (`audits/harden/`)

TCP-AO is checked against the platform, not assumed: this FRR build has zero
`tcp-authopt` references, so session authentication uses MD5, the widely
deployed fallback. With MD5 set on the leaf only, the session drops, because
an attacker without the key cannot complete it; supplying the matching key on
the host brings it back. GTSM (`ttl-security hops 1`) is added, and the
directly connected host passes while a peer more than one hop away fails the
TTL check before BGP runs. `hardened-session.txt` is the complete hardened
host-facing session as a diff against chapter 9's original.

## Making it permanent

Every control here becomes a chapter 18 pipeline check so hardening cannot
silently rot: a property check that no host-facing peer accepts a default
route, and that every host peer carries a maximum-prefix and an import filter,
would fail the pipeline on a config that dropped them. The controls and the
checks that enforce them ship together.

## Files

`redteam.sh` runs the attack; `harden.sh` completes the session hardening;
`hardened-session.txt` is the annotated hardened config. `lib.sh` shared
settings. All device access is a fixed ssh helper or docker exec, never a bash
loop over ssh.
