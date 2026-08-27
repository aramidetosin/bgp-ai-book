#!/usr/bin/env python3
"""Chapter 10's Kubernetes fabric, generated.

Emits topo.clab.yml, bootstrap/*.cfg, and intent.json. The three
Kubernetes nodes are external containers (started first by nodes-up.sh);
containerlab wires eth1 into each. leaf01 bridges its three access ports
into one segment behind an SVI; leaf02 and leaf03 use plain routed ports.
Multipath relax ships in the bootstrap: chapter 9 taught why, and chapter
11's anycast services need it from day one.
"""
import json, os
import yaml

spec = yaml.safe_load(open("spec.yml"))
NAME = spec["name"]

links, intent = [], {}
def add(a, pa, b, pb):
    links.append((a, pa, b, pb))
    intent.setdefault(a, {})[pa] = [b, pb]
    intent.setdefault(b, {})[pb] = [a, pa]

add("leaf01", "swp1", "node01", "eth1")
add("leaf01", "swp2", "node02", "eth1")
add("leaf01", "swp3", "client01", "eth1")
add("leaf02", "swp1", "node03", "eth1")
add("leaf03", "swp1", "client02", "eth1")
for i in (1, 2, 3):
    add(f"leaf0{i}", f"swp{4 if i == 1 else 2}", "spine01", f"swp{i}")
    add(f"leaf0{i}", f"swp{5 if i == 1 else 3}", "spine02", f"swp{i}")

topo = {
    "name": NAME,
    "mgmt": {"network": NAME, "ipv4-subnet": spec["mgmt_subnet"]},
    "topology": {
        "defaults": {"kind": "nvidia_cumulusvx", "image": spec["switch_image"]},
        "nodes": {},
        "links": [{"endpoints": [f"{a}:{pa}", f"{b}:{pb}"]} for a, pa, b, pb in links],
    },
}
for sw in ("leaf01", "leaf02", "leaf03", "spine01", "spine02"):
    topo["topology"]["nodes"][sw] = {"startup-config": f"bootstrap/{sw}.cfg"}
for n in ("node01", "node02", "node03"):
    topo["topology"]["nodes"][n] = {"kind": "ext-container"}
topo["topology"]["nodes"]["client01"] = {
    "kind": "linux", "image": spec["node_image"],
    "exec": [
        "ip addr add 172.16.1.21/24 dev eth1",
        "ip route replace default via 172.16.1.1 dev eth1",
        "lldpd",
    ],
}
topo["topology"]["nodes"]["client02"] = {
    "kind": "linux", "image": spec["node_image"],
    "exec": [
        "ip addr add 172.16.3.21/24 dev eth1",
        "ip route replace default via 172.16.3.1 dev eth1",
        "lldpd",
    ],
}
yaml.safe_dump(topo, open("topo.clab.yml", "w"), sort_keys=False)

os.makedirs("bootstrap", exist_ok=True)

BASE = """nv set system api state enabled
nv set system config auto-save state enabled
nv set system control-plane acl acl-default-dos inbound
nv set system control-plane acl acl-default-whitelist inbound
nv set system reboot mode cold
nv set system ssh-server state enabled"""

def bgp_block(asn, router_id, ports):
    lines = [
        f"nv set router bgp autonomous-system {asn}",
        "nv set router bgp enable on",
        f"nv set router bgp router-id {router_id}",
        "nv set vrf default router bgp address-family ipv4-unicast enable on",
        "nv set vrf default router bgp address-family ipv4-unicast redistribute connected enable on",
        "nv set vrf default router bgp path-selection multipath aspath-ignore on",
        "nv set vrf default router bgp enable on",
    ]
    for port in ports:
        lines.append(f"nv set vrf default router bgp neighbor {port} remote-as external")
        lines.append(f"nv set vrf default router bgp neighbor {port} type unnumbered")
    return lines

# leaf01: bridged access segment plus fabric
lines = [
    "nv set system hostname leaf01",
    "nv set interface lo ip address 10.0.0.1/32",
    "nv set interface lo type loopback",
    "nv set interface swp1-5 type swp",
    "nv set interface swp1 bridge domain br_default access 100",
    "nv set interface swp2 bridge domain br_default access 100",
    "nv set interface swp3 bridge domain br_default access 100",
    "nv set bridge domain br_default vlan 100",
    "nv set interface vlan100 ip address 172.16.1.1/24",
]
lines += bgp_block(spec["leaf_asn_base"] + 1, "10.0.0.1", ["swp4", "swp5"])
lines.append(BASE)
open("bootstrap/leaf01.cfg", "w").write("\n".join(lines) + "\n")

for i, subnet in ((2, "172.16.2.1/24"), (3, "172.16.3.1/24")):
    lines = [
        f"nv set system hostname leaf0{i}",
        f"nv set interface lo ip address 10.0.0.{i}/32",
        "nv set interface lo type loopback",
        "nv set interface swp1-3 type swp",
        f"nv set interface swp1 ip address {subnet}",
    ]
    lines += bgp_block(spec["leaf_asn_base"] + i, f"10.0.0.{i}", ["swp2", "swp3"])
    lines.append(BASE)
    open(f"bootstrap/leaf0{i}.cfg", "w").write("\n".join(lines) + "\n")

for s in (1, 2):
    lines = [
        f"nv set system hostname spine0{s}",
        f"nv set interface lo ip address 10.0.0.{100 + s}/32",
        "nv set interface lo type loopback",
        "nv set interface swp1-3 type swp",
    ]
    lines += bgp_block(spec["spine_asn"], f"10.0.0.{100 + s}",
                       ["swp1", "swp2", "swp3"])
    lines.append(BASE)
    open(f"bootstrap/spine0{s}.cfg", "w").write("\n".join(lines) + "\n")

json.dump(intent, open("intent.json", "w"), indent=1, sort_keys=True)
print(f"generated: 3 leafs, 2 spines, 3 external k8s nodes, 2 clients, {len(links)} links")
