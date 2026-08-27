LAB   = bgpbook-ch08
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
D     = docker exec clab-$(LAB)

.PHONY: generate node-image up down verify audit trace
.PHONY: collide wecmp heal-wecmp pin unpin
.PHONY: ssh-% shell-%

# The spec is the design; everything else is generated from it.
generate:
	python3 gen_topo.py

# The node image is chapter 6's, built once there (make node-image in ch06).
node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || \
	  docker build --network host -t bgpbook-multitool-lldpd -f ../ch06/Dockerfile.node ../ch06

up: generate node-image
	sudo containerlab deploy -t topo.clab.yml --reconfigure

down:
	sudo containerlab destroy -t topo.clab.yml

verify:
	./verify_lldp.sh

audit:
	./audit.sh

trace:
	./trace.sh

# --- the collision ladder: 1, 4, 4, 16 flows on leaf01's four uplinks ---
collide:
	./collide.sh

# --- weighted ECMP: fail one link, then advertise real capacity ---
wecmp:
	./wecmp.sh

heal-wecmp:
	./heal_wecmp.sh

# --- policy pinning: the traffic-engineering stand-in ---
pin:
	./pin.sh

unpin:
	./unpin.sh

ssh-%:
	$(SSH)$*

shell-%:
	$(D)-$* bash
