LAB   = bgpbook-ch05
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
D     = docker exec clab-$(LAB)

.PHONY: generate node-image up down verify audit trace break-5a heal-5a
.PHONY: ssh-% logs-% shell-%

# The chapter's whole idea in two targets: the spec is the design,
# everything else is generated from it.
generate:
	python3 gen_topo.py

# One-time: the node image is the multitool plus lldpd, so nodes can
# speak LLDP without needing internet at deploy time.
node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || \
	  docker build --network host -t bgpbook-multitool-lldpd -f Dockerfile.node .

up: generate node-image
	sudo containerlab deploy -t topo.clab.yml --reconfigure

down:
	sudo containerlab destroy -t topo.clab.yml

# Does the cabling match the intent? The check that replaces eyeballs.
verify:
	./verify_lldp.sh

audit:
	./audit.sh

trace:
	./trace.sh

# Exercise 4: regenerate the topology with two rails swapped on the node
# side (the cabling mistake), redeploy, and let verify find it.
break-5a:
	python3 gen_topo.py --swap-rails 2 3
	sudo containerlab deploy -t topo.clab.yml --reconfigure
	@echo "deployed with the mistake. Run 'make verify' and read the mismatches."

heal-5a: up

ssh-%:
	$(SSH)$*

shell-%:
	$(D)-$* bash

logs-%:
	$(SSH)$* "sudo tail -f /var/log/frr/frr.log"
