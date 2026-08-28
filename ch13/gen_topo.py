#!/usr/bin/env python3
"""The book's core underlay, generated (chapter 6).

Reads spec.yml and emits topo.clab.yml, bootstrap/*.cfg, and intent.json,
exactly as chapter 5's generator did for the rail fabric. This topology is
the base every later chapter builds on.

  --numbered        emit numbered point-to-point peering (/31 per fabric
                    link, neighbors by address) instead of unnumbered.
                    Exercise 1's conversion, one flag.
  --dup-asn A B     give leaf B the ASN of leaf A (the break-6a mistake);
                    intent and addressing stay correct, only the ASN lies.
"""
import argparse, json, os
import yaml

p = argparse.ArgumentParser()
p.add_argument("--spec", default="spec.yml")
p.add_argument("--numbered", action="store_true")
p.add_argument("--dup-asn", nargs=2, type=int, metavar=("A", "B"))
args = p.parse_args()

spec = yaml.safe_load(open(args.spec))
LEAFS, SPINES = spec["leafs"], spec["spines"]
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

for i in range(1, LEAFS + 1):
    if i in SERVERS:
        add(leaf(i), "swp1", SERVERS[i], "eth1")
    for s in range(1, SPINES + 1):
        add(leaf(i), f"swp{1 + s}", spine(s), f"swp{i}")

# /31 plan for --numbered: fabric link n gets 10.0.1.(2n)/31, leaf side even.
link_addr = {}
if args.numbered:
    n = 0
    for i in range(1, LEAFS + 1):
        for s in range(1, SPINES + 1):
            link_addr[(i, s)] = (f"10.0.1.{2*n}", f"10.0.1.{2*n + 1}")
            n += 1

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

def bgp_block(asn, router_id, peers):
    """peers: list of (port, peer_addr_or_None). Unnumbered when addr is None."""
    lines = [
        f"nv set router bgp autonomous-system {asn}",
        "nv set router bgp enable on",
        f"nv set router bgp router-id {router_id}",
        "nv set vrf default router bgp address-family ipv4-unicast enable on",
        "nv set vrf default router bgp address-family ipv4-unicast redistribute connected enable on",
        "nv set vrf default router bgp enable on",
    ]
    for port, peer_addr in peers:
        nbr = peer_addr if peer_addr else port
        lines.append(f"nv set vrf default router bgp neighbor {nbr} remote-as external")
        if not peer_addr:
            lines.append(f"nv set vrf default router bgp neighbor {nbr} type unnumbered")
    return lines

for i in range(1, LEAFS + 1):
    asn = spec["leaf_asn_base"] + i
    if args.dup_asn and i == args.dup_asn[1]:
        asn = spec["leaf_asn_base"] + args.dup_asn[0]
        print(f"NOTE: {leaf(i)} emitted with {leaf(args.dup_asn[0])}'s ASN {asn}")
    lines = [
        f"nv set system hostname {leaf(i)}",
        f"nv set interface lo ip address 10.0.0.{i}/32",
        "nv set interface lo type loopback",
    ]
    if i in SERVERS:
        lines.append(f"nv set interface swp1 ip address 172.16.{i}.1/24")
    peers = []
    for s in range(1, SPINES + 1):
        port = f"swp{1 + s}"
        if args.numbered:
            leaf_ip, spine_ip = link_addr[(i, s)]
            lines.append(f"nv set interface {port} ip address {leaf_ip}/31")
            peers.append((port, spine_ip))
        else:
            peers.append((port, None))
    first_port = 1 if i in SERVERS else 2   # only declare ports that have links
    lines.append(f"nv set interface swp{first_port}-{1 + SPINES} type swp")
    lines += bgp_block(asn, f"10.0.0.{i}", peers)
    lines.append(BASE)
    open(f"bootstrap/{leaf(i)}.cfg", "w").write("\n".join(lines) + "\n")

for s in range(1, SPINES + 1):
    lines = [
        f"nv set system hostname {spine(s)}",
        f"nv set interface lo ip address 10.0.0.{100 + s}/32",
        "nv set interface lo type loopback",
        f"nv set interface swp1-{LEAFS} type swp",
    ]
    peers = []
    for i in range(1, LEAFS + 1):
        port = f"swp{i}"
        if args.numbered:
            leaf_ip, spine_ip = link_addr[(i, s)]
            lines.append(f"nv set interface {port} ip address {spine_ip}/31")
            peers.append((port, leaf_ip))
        else:
            peers.append((port, None))
    lines += bgp_block(spec["spine_asn"], f"10.0.0.{100 + s}", peers)
    lines.append(BASE)
    open(f"bootstrap/{spine(s)}.cfg", "w").write("\n".join(lines) + "\n")

json.dump(intent, open("intent.json", "w"), indent=1, sort_keys=True)
style = "numbered" if args.numbered else "unnumbered"
print(f"generated: {LEAFS} leafs, {SPINES} spines, {len(SERVERS)} servers, "
      f"{len(links)} links ({style}), intent for {sum(len(v) for v in intent.values())} endpoints")
