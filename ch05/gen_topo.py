#!/usr/bin/env python3
"""The book's topology generator, first appearance (chapter 5).

Reads spec.yml and emits:
  topo.clab.yml    the containerlab topology (rail leafs, spines, nodes)
  bootstrap/*.cfg  per-switch NVUE configs (unnumbered eBGP, chapter 1 pattern)
  intent.json      every link the design intends, for LLDP verification

The diagram is generated, never drawn. Chapter 17 grows this idea into the
full BGP-as-code pipeline.

  --swap-rails A B   emit a topology with nodes' rail-A and rail-B NICs
                     swapped (the cabling mistake), leaving intent.json
                     correct. Used by `make break-5a`.
"""
import argparse, json, sys
import yaml

p = argparse.ArgumentParser()
p.add_argument("--spec", default="spec.yml")
p.add_argument("--swap-rails", nargs=2, type=int, metavar=("A", "B"))
args = p.parse_args()

spec = yaml.safe_load(open(args.spec))
NODES, RAILS, SPINES = spec["nodes"], spec["gpus_per_node"], spec["spines"]
NAME = spec["name"]

def rail(i): return f"rail{i}"
def spine(i): return f"spine{i}"
def node(j): return f"node{j}"

# ---- links: the design, stated once ----
links, intent = [], {}
def add(dev_a, port_a, dev_b, port_b):
    links.append((dev_a, port_a, dev_b, port_b))
    intent.setdefault(dev_a, {})[port_a] = [dev_b, port_b]
    intent.setdefault(dev_b, {})[port_b] = [dev_a, port_a]

for i in range(1, RAILS + 1):
    for j in range(1, NODES + 1):                 # downstream: one node NIC per rail
        add(rail(i), f"swp{j}", node(j), f"eth{i}")
    for s in range(1, SPINES + 1):                # uplinks
        add(rail(i), f"swp{NODES + s}", spine(s), f"swp{i}")

# The deliberate miscabling: swap two rails on the NODE side of the topology
# only. intent.json keeps the design, so verification catches the swap.
topo_links = list(links)
if args.swap_rails:
    a, b = args.swap_rails
    def swap(l):
        da, pa, db, pb = l
        if da.startswith("rail") and db.startswith("node"):
            if da == rail(a): return (da, pa, db, f"eth{b}")
            if da == rail(b): return (da, pa, db, f"eth{a}")
        return l
    topo_links = [swap(l) for l in topo_links]
    print(f"NOTE: emitted topology with rails {a} and {b} swapped on the node side")

# ---- topo.clab.yml ----
topo = {
    "name": NAME,
    "mgmt": {"network": NAME, "ipv4-subnet": spec["mgmt_subnet"]},
    "topology": {
        "defaults": {"kind": "nvidia_cumulusvx", "image": spec["switch_image"]},
        "nodes": {},
        "links": [{"endpoints": [f"{a}:{pa}", f"{b}:{pb}"]} for a, pa, b, pb in topo_links],
    },
}
for i in range(1, RAILS + 1):
    topo["topology"]["nodes"][rail(i)] = {"startup-config": f"bootstrap/{rail(i)}.cfg"}
for s in range(1, SPINES + 1):
    topo["topology"]["nodes"][spine(s)] = {"startup-config": f"bootstrap/{spine(s)}.cfg"}
for j in range(1, NODES + 1):
    execs = []
    for i in range(1, RAILS + 1):
        execs += [f"ip link set eth{i} mtu 9216",
                  f"ip addr add 172.31.{i}.{10 + j}/24 dev eth{i}"]
    # nodes speak LLDP so the fabric can verify its own cabling
    execs += ["lldpd"]
    topo["topology"]["nodes"][node(j)] = {"kind": "linux", "image": spec["node_image"], "exec": execs}

yaml.safe_dump(topo, open("topo.clab.yml", "w"), sort_keys=False)

# ---- bootstrap configs: the chapter 1 pattern, emitted ----
import os
os.makedirs("bootstrap", exist_ok=True)

BASE = """nv set system api state enabled
nv set system config auto-save state enabled
nv set system control-plane acl acl-default-dos inbound
nv set system control-plane acl acl-default-whitelist inbound
nv set system reboot mode cold
nv set system ssh-server state enabled"""

def bgp_block(asn, router_id, peer_ports):
    lines = [
        f"nv set router bgp autonomous-system {asn}",
        "nv set router bgp enable on",
        f"nv set router bgp router-id {router_id}",
        "nv set vrf default router bgp address-family ipv4-unicast enable on",
        "nv set vrf default router bgp address-family ipv4-unicast redistribute connected enable on",
        "nv set vrf default router bgp enable on",
    ]
    for port in peer_ports:
        lines += [f"nv set vrf default router bgp neighbor {port} remote-as external",
                  f"nv set vrf default router bgp neighbor {port} type unnumbered"]
    return lines

for i in range(1, RAILS + 1):
    uplinks = [f"swp{NODES + s}" for s in range(1, SPINES + 1)]
    lines = [
        f"nv set system hostname {rail(i)}",
        f"nv set interface lo ip address 10.5.0.{i}/32",
        "nv set interface lo type loopback",
        f"nv set bridge domain br_default vlan {i}",
    ]
    for j in range(1, NODES + 1):
        lines.append(f"nv set interface swp{j} bridge domain br_default access {i}")
    lines += [
        f"nv set interface vlan{i} ip address 172.31.{i}.1/24",
        f"nv set interface swp1-{NODES + SPINES} type swp",
    ]
    lines += bgp_block(spec["rail_asn_base"] + i, f"10.5.0.{i}", uplinks)
    lines.append(BASE)
    open(f"bootstrap/{rail(i)}.cfg", "w").write("\n".join(lines) + "\n")

for s in range(1, SPINES + 1):
    lines = [
        f"nv set system hostname {spine(s)}",
        f"nv set interface lo ip address 10.5.0.{100 + s}/32",
        "nv set interface lo type loopback",
        f"nv set interface swp1-{RAILS} type swp",
    ]
    lines += bgp_block(spec["spine_asn"], f"10.5.0.{100 + s}",
                       [f"swp{i}" for i in range(1, RAILS + 1)])
    lines.append(BASE)
    open(f"bootstrap/{spine(s)}.cfg", "w").write("\n".join(lines) + "\n")

json.dump(intent, open("intent.json", "w"), indent=1, sort_keys=True)
print(f"generated: {RAILS} rail leafs, {SPINES} spines, {NODES} nodes, "
      f"{len(links)} links, intent for {sum(len(v) for v in intent.values())} endpoints")
