#!/usr/bin/env python3
"""Chapter 17: the generator, revealed in full.

One spec file in; three artifacts out, all derived, none hand-edited:
  - topo.clab.yml   the containerlab topology
  - bootstrap/*.cfg the per-device NVUE config, rendered through Jinja2
  - intent.json     what each device is supposed to carry, for drift checks

This is the same shape the generator has produced since chapter 5. The
config rendering that earlier chapters did with Python string-building is
here done with a Jinja2 template (templates/switch.cfg.j2), which is what
keeps it maintainable as the config grows.

  --template NAME   render with a different template (break-17a uses the
                    broken one to show a bug the CI diff catches)
"""
import argparse, json, os
import yaml
from jinja2 import Environment, FileSystemLoader

HERE = os.path.dirname(os.path.abspath(__file__))
p = argparse.ArgumentParser()
p.add_argument("--spec", default="spec.yml")
p.add_argument("--template", default="switch.cfg.j2")
args = p.parse_args()

spec = yaml.safe_load(open(args.spec))
LEAFS, SPINES = spec["leafs"], spec["spines"]
SERVERS = {leaf: f"server{i+1:02d}" for i, leaf in enumerate(spec["servers_on"])}
NAME = spec["name"]
BFD = spec.get("bfd", {"enabled": False})

def leaf(i): return f"leaf{i:02d}"
def spine(s): return f"spine{s:02d}"

# ---- links and intent-shape (same topology every chapter builds) ----
links = []
def add(a, pa, b, pb): links.append((a, pa, b, pb))
for i in range(1, LEAFS + 1):
    if i in SERVERS:
        add(leaf(i), "swp1", SERVERS[i], "eth1")
    for s in range(1, SPINES + 1):
        add(leaf(i), f"swp{1 + s}", spine(s), f"swp{i}")

# ---- per-device parameters, the only place role differences live ----
def leaf_dev(i):
    has_server = i in SERVERS
    return {
        "hostname": leaf(i),
        "loopback": f"10.0.0.{i}",
        "router_id": f"10.0.0.{i}",
        "asn": spec["leaf_asn_base"] + i,
        "first_swp": 1 if has_server else 2,
        "last_swp": 1 + SPINES,
        "server_subnet": f"172.16.{i}" if has_server else None,
        "fabric_ports": [f"swp{1 + s}" for s in range(1, SPINES + 1)],
    }
def spine_dev(s):
    return {
        "hostname": spine(s),
        "loopback": f"10.0.0.{100 + s}",
        "router_id": f"10.0.0.{100 + s}",
        "asn": spec["spine_asn"],
        "first_swp": 1,
        "last_swp": LEAFS,
        "server_subnet": None,
        "fabric_ports": [f"swp{i}" for i in range(1, LEAFS + 1)],
    }
devices = [leaf_dev(i) for i in range(1, LEAFS + 1)] + [spine_dev(s) for s in range(1, SPINES + 1)]

# ---- render each device's config through the template ----
env = Environment(loader=FileSystemLoader(os.path.join(HERE, "templates")),
                  trim_blocks=True, lstrip_blocks=True, keep_trailing_newline=True)
tmpl = env.get_template(args.template)
bootstrap_dir = os.path.join(HERE, "bootstrap")
os.makedirs(bootstrap_dir, exist_ok=True)
# clear stale device configs so shrinking the fabric (fewer leafs/spines)
# never leaves an orphan config behind; the spec is the only source.
for f in os.listdir(bootstrap_dir):
    if f.endswith(".cfg"):
        os.remove(os.path.join(bootstrap_dir, f))
intent = {}
for dev in devices:
    cfg = tmpl.render(dev=dev, bfd=BFD)
    open(os.path.join(HERE, f"bootstrap/{dev['hostname']}.cfg"), "w").write(cfg)
    # intent = the set of nv-set commands this device is supposed to carry
    intent[dev["hostname"]] = sorted(l for l in cfg.splitlines() if l.startswith("nv set"))

# ---- topology ----
topo = {
    "name": NAME,
    "mgmt": {"network": NAME, "ipv4-subnet": spec["mgmt_subnet"]},
    "topology": {
        "defaults": {"kind": "nvidia_cumulusvx", "image": spec["switch_image"]},
        "nodes": {}, "links": [{"endpoints": [f"{a}:{pa}", f"{b}:{pb}"]} for a, pa, b, pb in links],
    },
}
for dev in devices:
    topo["topology"]["nodes"][dev["hostname"]] = {"startup-config": f"bootstrap/{dev['hostname']}.cfg"}
for i, srv in SERVERS.items():
    topo["topology"]["nodes"][srv] = {
        "kind": "linux", "image": spec["node_image"],
        "exec": [f"ip addr add 172.16.{i}.11/24 dev eth1",
                 f"ip route replace default via 172.16.{i}.1 dev eth1", "lldpd"],
    }
yaml.safe_dump(topo, open(os.path.join(HERE, "topo.clab.yml"), "w"), sort_keys=False)
json.dump(intent, open(os.path.join(HERE, "intent.json"), "w"), indent=1, sort_keys=True)
print(f"generated from {args.spec} via {args.template}: {LEAFS} leafs, {SPINES} spines, "
      f"{len(devices)} device configs, {len(links)} links, intent for {len(intent)} devices")
