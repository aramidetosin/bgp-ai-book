#!/usr/bin/env python3
"""Chapter 8's fabric: the chapter 6 shape with capacity made unequal.

Reads spec.yml and emits topo.clab.yml, bootstrap/*.cfg, and intent.json,
same contract as the chapter 5 and 6 generators. The one new spec field
is `uplinks`: how many links each leaf runs to EACH spine. leaf01 gets
two per spine (a four-way ECMP fan), leaf02 one (the standard shape), so
the fabric can demonstrate both flow collisions and weighted ECMP.
"""
import json, os
import yaml

spec = yaml.safe_load(open("spec.yml"))
LEAFS, SPINES = spec["leafs"], spec["spines"]
UPLINKS = {int(k): int(v) for k, v in spec["uplinks"].items()}
SERVERS = {leaf: f"server{i+1:02d}" for i, leaf in enumerate(spec["servers_on"])}
NAME = spec["name"]

def leaf(i): return f"leaf{i:02d}"
def spine(s): return f"spine{s:02d}"

# ---- links and intent ----
links, intent = [], {}
def add(a, pa, b, pb):
    links.append((a, pa, b, pb))
    intent.setdefault(a, {})[pa] = [b, pb]
    intent.setdefault(b, {})[pb] = [a, pa]

spine_port = {s: 0 for s in range(1, SPINES + 1)}
leaf_uplinks = {}          # leaf -> list of its uplink ports
for i in range(1, LEAFS + 1):
    if i in SERVERS:
        add(leaf(i), "swp1", SERVERS[i], "eth1")
    port, ports = 2, []
    for s in range(1, SPINES + 1):
        for _ in range(UPLINKS[i]):
            spine_port[s] += 1
            add(leaf(i), f"swp{port}", spine(s), f"swp{spine_port[s]}")
            ports.append(port)
            port += 1
    leaf_uplinks[i] = ports

# ---- topo.clab.yml ----
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
for i, srv in SERVERS.items():
    topo["topology"]["nodes"][srv] = {
        "kind": "linux", "image": spec["node_image"],
        "exec": [
            "ip link set eth1 mtu 9216",
            f"ip addr add 172.16.{i}.11/24 dev eth1",
            f"ip route replace default via 172.16.{i}.1 dev eth1",
            "lldpd",
        ],
    }
yaml.safe_dump(topo, open("topo.clab.yml", "w"), sort_keys=False)

# ---- bootstrap configs ----
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
    asn = spec["leaf_asn_base"] + i
    last = leaf_uplinks[i][-1]
    lines = [
        f"nv set system hostname {leaf(i)}",
        f"nv set interface lo ip address 10.0.0.{i}/32",
        "nv set interface lo type loopback",
    ]
    if i in SERVERS:
        lines.append(f"nv set interface swp1 ip address 172.16.{i}.1/24")
    first = 1 if i in SERVERS else 2
    lines.append(f"nv set interface swp{first}-{last} type swp")
    lines += bgp_block(asn, f"10.0.0.{i}", [f"swp{p}" for p in leaf_uplinks[i]])
    lines.append(BASE)
    open(f"bootstrap/{leaf(i)}.cfg", "w").write("\n".join(lines) + "\n")

for s in range(1, SPINES + 1):
    lines = [
        f"nv set system hostname {spine(s)}",
        f"nv set interface lo ip address 10.0.0.{100 + s}/32",
        "nv set interface lo type loopback",
        f"nv set interface swp1-{spine_port[s]} type swp",
    ]
    lines += bgp_block(spec["spine_asn"], f"10.0.0.{100 + s}",
                       [f"swp{p}" for p in range(1, spine_port[s] + 1)])
    lines.append(BASE)
    open(f"bootstrap/{spine(s)}.cfg", "w").write("\n".join(lines) + "\n")

json.dump(intent, open("intent.json", "w"), indent=1, sort_keys=True)
print(f"generated: {LEAFS} leafs, {SPINES} spines, {len(SERVERS)} servers, "
      f"{len(links)} links, leaf01 fan: {len(leaf_uplinks[1])} uplinks, "
      f"intent for {sum(len(v) for v in intent.values())} endpoints")
