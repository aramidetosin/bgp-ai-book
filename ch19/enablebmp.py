#!/usr/bin/env python3
"""Chapter 19 lab setup: load FRR's BMP module. Cumulus VX ships bgpd_bmp.so
but does not start bgpd with -M bmp, so BMP commands are inert until the module
is loaded. This adds -M bmp to bgpd_options and restarts FRR on each switch.
A lab-platform step, done once; on real Cumulus the module is enabled the same
way. Restarting FRR bounces the sessions; the fabric reconverges in seconds."""
import subprocess, os, sys, time
LAB = os.environ.get("LAB", "bgpbook-ch16")
PASS = os.environ.get("PASS", "Clab123!")
DEVICES = os.environ.get("DEVICES", "leaf01 leaf02 leaf03 leaf04 spine01 spine02").split()

def ssh(dev, cmd):
    base = ["sshpass", "-p", PASS, "ssh", "-o", "StrictHostKeyChecking=no",
            "-o", "UserKnownHostsFile=/dev/null", "-o", "ConnectTimeout=10",
            f"cumulus@clab-{LAB}-{dev}", cmd]
    return subprocess.run(base, capture_output=True, text=True)

for d in DEVICES:
    have = "bmp" in ssh(d, "sudo grep bgpd_options /etc/frr/daemons").stdout
    if not have:
        ssh(d, "sudo sed -i 's/bgpd_options=\"/bgpd_options=\"-M bmp /' /etc/frr/daemons")
    ssh(d, "sudo systemctl restart frr")
    print(f"  {d}: -M bmp {'already set' if have else 'added'}, FRR restarted")
print("waiting for the fabric to reconverge...")
time.sleep(15)
