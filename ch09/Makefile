LAB   = bgpbook-ch09
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
D     = docker exec clab-$(LAB)

.PHONY: generate node-image host-image up base down verify audit
.PHONY: mh routed bfd conditional break-9a heal-9a
.PHONY: ssh-% shell-%

generate:
	python3 gen_topo.py

node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || \
	  docker build --network host -t bgpbook-multitool-lldpd -f ../ch06/Dockerfile.node ../ch06

host-image:
	docker image inspect bgpbook-frr-host >/dev/null 2>&1 || \
	  docker build --network host -t bgpbook-frr-host -f Dockerfile.host .

up: generate node-image host-image
	sudo containerlab deploy -t topo.clab.yml --reconfigure

# The base is the design-free fabric; both designs regenerate to it.
base: up

down:
	sudo containerlab destroy -t topo.clab.yml

verify:
	./verify_lldp.sh

audit:
	./audit.sh

# --- design A: EVPN multihoming toward a bonded host ---
mh:
	./mh.sh

# --- design B: the routed host (run on a fresh base) ---
routed:
	./routed.sh

bfd:
	./bfd.sh

conditional:
	./conditional.sh

# --- the asymmetric return path blackhole (on the routed design) ---
break-9a:
	./break9a.sh

heal-9a:
	./heal9a.sh

ssh-%:
	$(SSH)$*

shell-%:
	$(D)-$* sh
