# Chapter 12: The Edge

The edge in miniature: one fabric leaf with a chapter-9-style service
host (the VIP on its loopback, advertised over eBGP), a border leaf, a
Palo Alto active/passive pair inline in routed mode, an upstream
provider router (FRR, bridging the outside segment across both
firewalls' outside ports), and an external client on "the internet".
The firewall pair's full configuration is generated XML
(`gen_fw_xml.py`), loaded and committed by the patched launcher at
first boot; both units boot and self-configure in about six minutes
here (recorded in audits/edge/boot.txt).

## Targets

```
make up          # deploy (generates the firewall XML first)
make setup       # provider and service host (FRR containers)
make audit       # sessions, HA pair, reach, containment
make edge        # the main recording: contract, session table, NATs
make failover    # fail the active mid-download; state sync carries it
make break-12a   # the PMTU blackhole at the edge (make heal-12a)
make down        # destroy
```

## Evidence

`audits/edge/` records the border's contract from both ends (default
in, one /32 out, the provider's own filter agreeing), the chain of
defaults down to the host's RFC 8950 next hop, one customer request
with the active firewall's session-table entry quoted (zones, both NAT
translations, `web-browsing`, state ACTIVE), the traceroute that goes
dark past the provider by design, and both NATs proven by capture: the
server receives the client's true source with a translated
destination, and the internet sees the cluster as the firewall's
outside address.

`audits/failover/` records a 60 MB download riding through an active
suspension: state sync hands the session to the survivor and every
byte arrives. In this lab's testing the pair proved hard to break even
with the sync transport down, because the permissive rulebase plus
port-preserving SNAT lets the new active rebuild mid-flow sessions;
the chapter reports that honestly rather than staging a failure.

`audits/break12a/` is the path-MTU blackhole: the service host
"standardized" to the fabric's 9216, short requests fine, every long
transfer dead, 9164-byte segments captured streaming into silence with
no ICMP hint coming back.

Recorded quirks worth knowing: the launcher's API password is what
containerlab passes (`Admin@123` here, not vrnetlab's default); a unit
that was briefly active during boot lingers in neighbor caches until
flushed (edge.sh does it); the BGP session through the pair needs a
no-NAT exemption above the outbound SNAT rule; and the provider is
configured passive so only the customer dials.
