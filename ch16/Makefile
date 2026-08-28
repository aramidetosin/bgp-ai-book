LAB   = bgpbook-ch16
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
.PHONY: generate node-image up down sim fail gray flap bfd nobfd audit ssh-%
generate:
	python3 gen_topo.py
node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || docker build --network host -t bgpbook-multitool-lldpd -f ../ch06/Dockerfile.node ../ch06
up: generate node-image
	sudo containerlab deploy -t topo.clab.yml --reconfigure
down:
	sudo containerlab destroy -t topo.clab.yml
sim:
	./sim.sh
fail:
	./down.sh
gray:
	./gray.sh
flap:
	./flap.sh
audit:
	./audit.sh
ssh-%:
	$(SSH)$*
