# Chapter 10: Pod Networking with BGP

The Kubernetes fabric: three leafs, two spines, three kindest/node
containers wired in by containerlab as external containers, and two
clients. leaf01 bridges a small segment (node01, node02, client01)
behind one SVI, which chapter 11's layer 2 story needs; node03 sits
routed behind leaf02; client02 sits behind leaf03. Multipath relax
ships in the bootstrap (chapter 9's lesson institutionalized).

## Targets

```
make up          # fabric + node containers (nodes-up.sh), wired by clab
make cluster     # kubeadm init/join, images imported, Cilium applied
make bgp         # ToR sessions + pod filter, Cilium BGP CRDs, evidence
make walk        # the packet walk, every table recorded
make tunnel      # native vs tunnel mode captured on leaf02 swp1
make break-10a   # wrong peer ASN in the CRD (make heal-10a)
make audit       # fabric, cluster, agents, pod routes, LLDP
make down        # destroy fabric and node containers
```

The cluster recipe (`cluster.sh`) carries the recorded hard lessons:
`--fail-swap-on=false` (the lab host runs swap), `--node-ip` pinned to
the fabric NIC (otherwise NodePorts and tunnels ride the docker
bridge), images imported into containerd via stdin (`docker cp` into
tmpfs /tmp goes nowhere), and Cilium config changes require a
DaemonSet rollout restart to become real.

## Evidence

`audits/bgp/` holds the sessions from both ends (the ToR's neighbor
table with nodes beside spines; the agent's own `cilium-dbg bgp
peers`) and the filter at work. `audits/walk/` is the recorded packet
walk. `audits/tunnel/` is the same ping captured on the same port in
both routing modes, identity-in-the-VNI included. `audits/break10a/`
is the idle session diagnosed from status conditions alone.
`audits/ch10_audit_*` is the green baseline (node links marked as
verified by their BGP sessions; kindest speaks no LLDP).
