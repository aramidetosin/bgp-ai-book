LAB   = bgpbook-ch12
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
D     = docker exec clab-$(LAB)

.PHONY: generate node-image up setup audit edge failover break-12a heal-12a down ssh-% shell-%

generate:
	python3 gen_fw_xml.py

node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || \
	  docker build --network host -t bgpbook-multitool-lldpd -f ../ch06/Dockerfile.node ../ch06
	docker image inspect bgpbook-frr-host >/dev/null 2>&1 || \
	  docker build --network host -t bgpbook-frr-host -f ../ch09/Dockerfile.host ../ch09

# The firewall pair boots and self-configures in roughly 19 minutes.
up: generate node-image
	sudo containerlab deploy -t topo.clab.yml --reconfigure

setup:
	./setup.sh

audit:
	./audit.sh

edge:
	./edge.sh

failover:
	./failover.sh

break-12a:
	./break12a.sh

heal-12a:
	./heal12a.sh

down:
	sudo containerlab destroy -t topo.clab.yml

ssh-%:
	$(SSH)$*

shell-%:
	$(D)-$* sh
