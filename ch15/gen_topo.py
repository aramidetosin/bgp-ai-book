#!/usr/bin/env python3
"""Chapter 15's two-site topology, generated.

Two scaled chapter 6 fabrics (spine + compute leaf + border leaf each),
joined by a numbered eBGP session between the border leafs across an
emulated WAN. Site A on the primary ASN block, site B on chapter 6's
reserved second-site block. Each compute leaf originates the shared
anycast VIP (so a local and a WAN path to it compete) and a site-local
backend prefix (to demonstrate the communities contract). Emits
topo.clab.yml, bootstrap/*.cfg, intent.json.

The communities contract and the anycast local-pref steering are applied
post-deploy by contract.sh, so the underlay here is clean chapter 6.
"""
import json, os
import yaml

spec = yaml.safe_load(open("spec.yml"))
NAME = spec["name"]
VIP = spec["vip"]
SITES = spec["sites"]

links, intent = [], {}
def add(a, pa, b, pb):
    links.append((a, pa, b, pb))
    intent.setdefault(a, {})[pa] = [b, pb]
    intent.setdefault(b, {})[pb] = [a, pa]

# within each site: leaf swp2 <-> spine swp1 ; border swp1 <-> spine swp2 ;
# server eth1 <-> leaf swp1. across sites: sa-border swp2 <-> sb-border swp2.
for s in SITES.values():
    add(s["leaf"]["host"], "swp1", s["server"]["host"], "eth1")
    add(s["leaf"]["host"], "swp2", s["spine"]["host"], "swp1")
    add(s["border"]["host"], "swp1", s["spine"]["host"], "swp2")
add(SITES["A"]["border"]["host"], "swp2", SITES["B"]["border"]["host"], "swp2")

topo = {
    "name": NAME,
    "mgmt": {"network": NAME, "ipv4-subnet": spec["mgmt_subnet"]},
    "topology": {
        "defaults": {"kind": "nvidia_cumulusvx", "image": spec["switch_image"]},
        "nodes": {},
        "links": [{"endpoints": [f"{a}:{pa}", f"{b}:{pb}"]} for a, pa, b, pb in links],
    },
}
for s in SITES.values():
    for role in ("spine", "leaf", "border"):
        topo["topology"]["nodes"][s[role]["host"]] = {
            "startup-config": f"bootstrap/{s[role]['host']}.cfg"}
    srv = s["server"]
    topo["topology"]["nodes"][srv["host"]] = {
        "kind": "linux", "image": spec["node_image"],
        "exec": [
            "ip link set eth1 mtu 9216",
            f"ip addr add {srv['ip']}/24 dev eth1",
            f"ip route replace default via {srv['subnet']}.1 dev eth1",
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

def bgp_head(asn, rid):
    return [
        f"nv set router bgp autonomous-system {asn}",
        "nv set router bgp enable on",
        f"nv set router bgp router-id {rid}",
        "nv set vrf default router bgp address-family ipv4-unicast enable on",
        "nv set vrf default router bgp address-family ipv4-unicast redistribute connected enable on",
        "nv set vrf default router bgp enable on",
    ]

def unnum(port):
    return [
        f"nv set vrf default router bgp neighbor {port} remote-as external",
        f"nv set vrf default router bgp neighbor {port} type unnumbered",
    ]

def numbered(port, local_ip, peer_ip, peer_asn):
    return [
        f"nv set interface {port} ip address {local_ip}/31",
        f"nv set vrf default router bgp neighbor {peer_ip} remote-as external",
    ]

for name, s in SITES.items():
    sp, lf, bd, srv = s["spine"], s["leaf"], s["border"], s["server"]

    # --- compute leaf: server subnet, the anycast VIP, the backend prefix ---
    lines = [
        f"nv set system hostname {lf['host']}",
        f"nv set interface lo ip address {lf['lo']}/32",
        f"nv set interface lo ip address {VIP}/32",              # anycast VIP
        f"nv set interface lo ip address {s['backend'].split('/')[0].rsplit('.', 1)[0]}.1/24",  # backend prefix
        "nv set interface lo type loopback",
        "nv set interface swp1-2 type swp",
        f"nv set interface swp1 ip address {srv['subnet']}.1/24",   # server subnet
    ]
    lines += bgp_head(lf["asn"], lf["lo"]) + unnum("swp2")
    lines.append(BASE)
    open(f"bootstrap/{lf['host']}.cfg", "w").write("\n".join(lines) + "\n")

    # --- spine: swp1 leaf, swp2 border, both unnumbered ---
    lines = [
        f"nv set system hostname {sp['host']}",
        f"nv set interface lo ip address {sp['lo']}/32",
        "nv set interface lo type loopback",
        "nv set interface swp1-2 type swp",
    ]
    lines += bgp_head(sp["asn"], sp["lo"]) + unnum("swp1") + unnum("swp2")
    lines.append(BASE)
    open(f"bootstrap/{sp['host']}.cfg", "w").write("\n".join(lines) + "\n")

    # --- border: swp1 unnumbered to spine, swp2 numbered to the other border ---
    other = SITES["B"] if name == "A" else SITES["A"]
    lines = [
        f"nv set system hostname {bd['host']}",
        f"nv set interface lo ip address {bd['lo']}/32",
        "nv set interface lo type loopback",
        "nv set interface swp1-2 type swp",
    ]
    lines += bgp_head(bd["asn"], bd["lo"]) + unnum("swp1")
    lines += numbered("swp2", s["wan_ip"], other["wan_ip"], other["border"]["asn"])
    lines.append(BASE)
    open(f"bootstrap/{bd['host']}.cfg", "w").write("\n".join(lines) + "\n")

json.dump(intent, open("intent.json", "w"), indent=1, sort_keys=True)
print(f"generated: 2 sites, {len(links)} links, VIP {VIP} at both leafs, "
      f"WAN {SITES['A']['wan_ip']}/31 <-> {SITES['B']['wan_ip']}")
