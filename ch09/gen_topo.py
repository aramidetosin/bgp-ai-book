#!/usr/bin/env python3
"""Chapter 9's host fabric, generated.

Reads spec.yml and emits topo.clab.yml, bootstrap/*.cfg, and intent.json,
same contract as chapters 5, 6, and 8. The base is the plain chapter 6
underlay; host01's two links land on leaf01 swp1 and leaf02 swp1 and are
declared but deliberately unconfigured, because wiring them up is the
chapter's whole subject (make mh, make routed).
"""
import json, os
import yaml

spec = yaml.safe_load(open("spec.yml"))
LEAFS, SPINES = spec["leafs"], spec["spines"]
SRV, HOSTS = spec["server_on"], spec["host_on"]
NAME = spec["name"]

def leaf(i): return f"leaf{i:02d}"
def spine(s): return f"spine{s:02d}"

links, intent = [], {}
def add(a, pa, b, pb):
    links.append((a, pa, b, pb))
    intent.setdefault(a, {})[pa] = [b, pb]
    intent.setdefault(b, {})[pb] = [a, pa]

for k, i in enumerate(HOSTS):
    add(leaf(i), "swp1", "host01", f"eth{k+1}")
add(leaf(SRV), "swp1", "server03", "eth1")
for i in range(1, LEAFS + 1):
    for s in range(1, SPINES + 1):
        add(leaf(i), f"swp{1 + s}", spine(s), f"swp{i}")

topo = {
    "name": NAME,
    "mgmt": {"network": NAME, "ipv4-subnet": spec["mgmt_subnet"]},
    "topology": {
        "defaults": {"kind": "nvidia_cumulusvx", "image": spec["switch_image"]},
        "nodes": {},
        "links": [{"endpoints": [f"{a}:{pa}", f"{b}:{pb}"]} for a, pa, b, pb in links],
    },
}
for i in range(1, LEAFS + 1):
    topo["topology"]["nodes"][leaf(i)] = {"startup-config": f"bootstrap/{leaf(i)}.cfg"}
for s in range(1, SPINES + 1):
    topo["topology"]["nodes"][spine(s)] = {"startup-config": f"bootstrap/{spine(s)}.cfg"}
topo["topology"]["nodes"]["server03"] = {
    "kind": "linux", "image": spec["node_image"],
    "exec": [
        "ip link set eth1 mtu 9216",
        f"ip addr add 172.16.{SRV}.11/24 dev eth1",
        f"ip route replace default via 172.16.{SRV}.1 dev eth1",
        "lldpd",
    ],
}
topo["topology"]["nodes"]["host01"] = {
    "kind": "linux", "image": spec["host_image"],
    "exec": [
        "ip link set eth1 mtu 9216",
        "ip link set eth2 mtu 9216",
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
        "nv set vrf default router bgp enable on",
    ]
    for port in ports:
        lines.append(f"nv set vrf default router bgp neighbor {port} remote-as external")
        lines.append(f"nv set vrf default router bgp neighbor {port} type unnumbered")
    return lines

for i in range(1, LEAFS + 1):
    lines = [
        f"nv set system hostname {leaf(i)}",
        f"nv set interface lo ip address 10.0.0.{i}/32",
        "nv set interface lo type loopback",
        f"nv set interface swp1-{1 + SPINES} type swp",
    ]
    if i == SRV:
        lines.append(f"nv set interface swp1 ip address 172.16.{SRV}.1/24")
    fabric_ports = [f"swp{1 + s}" for s in range(1, SPINES + 1)]
    lines += bgp_block(spec["leaf_asn_base"] + i, f"10.0.0.{i}", fabric_ports)
    lines.append(BASE)
    open(f"bootstrap/{leaf(i)}.cfg", "w").write("\n".join(lines) + "\n")

for s in range(1, SPINES + 1):
    lines = [
        f"nv set system hostname {spine(s)}",
        f"nv set interface lo ip address 10.0.0.{100 + s}/32",
        "nv set interface lo type loopback",
        f"nv set interface swp1-{LEAFS} type swp",
    ]
    lines += bgp_block(spec["spine_asn"], f"10.0.0.{100 + s}",
                       [f"swp{p}" for p in range(1, LEAFS + 1)])
    lines.append(BASE)
    open(f"bootstrap/{spine(s)}.cfg", "w").write("\n".join(lines) + "\n")

json.dump(intent, open("intent.json", "w"), indent=1, sort_keys=True)
print(f"generated: {LEAFS} leafs, {SPINES} spines, host01 dual-homed to "
      f"{leaf(HOSTS[0])}+{leaf(HOSTS[1])}, server03 on {leaf(SRV)}, {len(links)} links")
