#!/usr/bin/env python3
"""Chapter 14's storage fabric, generated.

Two storage leafs and two spines carry the standard chapter 6 underlay.
A storage array is dual-homed to leaf01 and leaf02 (the routed-host
pattern of chapter 9); four writers sit behind leaf03. Emits
topo.clab.yml, bootstrap/*.cfg, intent.json.
"""
import json, os
import yaml

spec = yaml.safe_load(open("spec.yml"))
LEAFS, SPINES = spec["leafs"], spec["spines"]
ARRAY = spec["array_on"]
WRITER_LEAF = spec["writers_on"]
NWRITERS = 4
NAME = spec["name"]

def leaf(i): return f"leaf{i:02d}"
def spine(s): return f"spine{s:02d}"

links, intent = [], {}
def add(a, pa, b, pb):
    links.append((a, pa, b, pb))
    intent.setdefault(a, {})[pa] = [b, pb]
    intent.setdefault(b, {})[pb] = [a, pa]

# storage array dual-homed to the two storage leafs
for k, i in enumerate(ARRAY):
    add(leaf(i), "swp1", "array01", f"eth{k+1}")
# writers behind the compute leaf
for w in range(1, NWRITERS + 1):
    add(leaf(WRITER_LEAF), f"swp{w}", f"writer{w:02d}", "eth1")
# fabric links
for i in range(1, LEAFS + 1):
    for s in range(1, SPINES + 1):
        first = NWRITERS if i == WRITER_LEAF else 1
        add(leaf(i), f"swp{first + s}", spine(s), f"swp{i}")

topo = {
    "name": NAME,
    "mgmt": {"network": NAME, "ipv4-subnet": spec["mgmt_subnet"]},
    "topology": {
        "defaults": {"kind": "nvidia_cumulusvx", "image": spec["switch_image"]},
        "nodes": {}, "links": [{"endpoints": [f"{a}:{pa}", f"{b}:{pb}"]} for a, pa, b, pb in links],
    },
}
for i in range(1, LEAFS + 1):
    topo["topology"]["nodes"][leaf(i)] = {"startup-config": f"bootstrap/{leaf(i)}.cfg"}
for s in range(1, SPINES + 1):
    topo["topology"]["nodes"][spine(s)] = {"startup-config": f"bootstrap/{spine(s)}.cfg"}
topo["topology"]["nodes"]["array01"] = {
    "kind": "linux", "image": spec["host_image"],
    "exec": ["ip link set eth1 mtu 9216", "ip link set eth2 mtu 9216", "lldpd"],
}
for w in range(1, NWRITERS + 1):
    topo["topology"]["nodes"][f"writer{w:02d}"] = {
        "kind": "linux", "image": spec["node_image"],
        "exec": [
            f"ip addr add 172.16.{WRITER_LEAF}.{10+w}/24 dev eth1",
            "ip link set eth1 mtu 9216",
            f"ip route replace default via 172.16.{WRITER_LEAF}.1 dev eth1",
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

def bgp_block(asn, rid, ports, filt=False):
    lines = [
        f"nv set router bgp autonomous-system {asn}",
        "nv set router bgp enable on",
        f"nv set router bgp router-id {rid}",
        "nv set vrf default router bgp address-family ipv4-unicast enable on",
        "nv set vrf default router bgp address-family ipv4-unicast redistribute connected enable on",
        "nv set vrf default router bgp path-selection multipath aspath-ignore on",
        "nv set vrf default router bgp enable on",
    ]
    for port, kind in ports:
        lines.append(f"nv set vrf default router bgp neighbor {port} remote-as external")
        lines.append(f"nv set vrf default router bgp neighbor {port} type unnumbered")
    return lines

for i in range(1, LEAFS + 1):
    is_writer_leaf = (i == WRITER_LEAF)
    first_fabric = (NWRITERS if is_writer_leaf else 1) + 1
    lines = [
        f"nv set system hostname {leaf(i)}",
        f"nv set interface lo ip address 10.0.0.{i}/32",
        "nv set interface lo type loopback",
        f"nv set interface swp1-{first_fabric - 1 + SPINES} type swp",
    ]
    if is_writer_leaf:
        lines.append(f"nv set interface swp1 ip address 172.16.{i}.1/24")
        # writers share one subnet on the compute leaf via a bridge
        access = ",".join(f"swp{w}" for w in range(1, NWRITERS + 1))
        lines = [l for l in lines if not l.startswith("nv set interface swp1 ip")]
        lines.append("nv set bridge domain br_default vlan 100")
        for w in range(1, NWRITERS + 1):
            lines.append(f"nv set interface swp{w} bridge domain br_default access 100")
        lines.append(f"nv set interface vlan100 ip address 172.16.{i}.1/24")
    fabric_ports = [(f"swp{first_fabric + s - 1}", "f") for s in range(1, SPINES + 1)]
    array_ports = [("swp1", "h")] if (i in ARRAY) else []
    lines += bgp_block(spec["leaf_asn_base"] + i, f"10.0.0.{i}", array_ports + fabric_ports)
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
                       [(f"swp{i}", "f") for i in range(1, LEAFS + 1)])
    lines.append(BASE)
    open(f"bootstrap/{spine(s)}.cfg", "w").write("\n".join(lines) + "\n")

json.dump(intent, open("intent.json", "w"), indent=1, sort_keys=True)
print(f"generated: {LEAFS} leafs, {SPINES} spines, array dual-homed to "
      f"{leaf(ARRAY[0])}+{leaf(ARRAY[1])}, {NWRITERS} writers on {leaf(WRITER_LEAF)}")
