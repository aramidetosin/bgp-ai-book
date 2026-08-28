#!/usr/bin/env python3
"""Chapter 19: turn on BMP on every fabric switch, pointed at the collector.
Reliable subprocess ssh (a bash loop over ssh truncates on this host); the
config is piped to vtysh over one session so the bmp-targets node context is
preserved."""
import subprocess, os, sys
LAB = os.environ.get("LAB", "bgpbook-ch16")
PASS = os.environ.get("PASS", "Clab123!")
COLLECTOR = os.environ.get("COLLECTOR", "172.16.1.11")
PORT = os.environ.get("BMP_PORT", "1790")
DEVICES = os.environ.get("DEVICES", "leaf01 leaf02 leaf03 leaf04 spine01 spine02").split()
OFF = "--off" in sys.argv

def ssh(dev, cmd, stdin=None):
    base = ["sshpass", "-p", PASS, "ssh", "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=10",
            f"cumulus@clab-{LAB}-{dev}", cmd]
    return subprocess.run(base, input=stdin, capture_output=True, text=True)

def asn(dev):
    out = ssh(dev, "sudo vtysh -c 'show run bgpd' 2>/dev/null").stdout
    for l in out.splitlines():
        if l.strip().startswith("router bgp "):
            return l.split()[2]
    return None

for d in DEVICES:
    a = asn(d)
    if not a:
        print(f"  {d}: could not read ASN"); continue
    if OFF:
        cfg = f"configure terminal\nrouter bgp {a}\nno bmp targets T1\nend\n"
    else:
        cfg = (f"configure terminal\nrouter bgp {a}\n"
               f"bmp targets T1\n"
               f"bmp connect {COLLECTOR} port {PORT} min-retry 1000 max-retry 5000\n"
               f"bmp monitor ipv4 unicast pre-policy\n"
               f"bmp monitor ipv4 unicast post-policy\n"
               f"end\nwrite memory\n")
    r = ssh(d, "sudo vtysh", stdin=cfg)
    ok = "% " not in r.stdout
    print(f"  {d} (AS {a}): BMP {'removed' if OFF else 'configured'} -> {COLLECTOR}:{PORT} "
          f"{'' if ok else '[warnings: ' + r.stdout.strip()[:80] + ']'}")
