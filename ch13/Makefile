LAB   = bgpbook-ch13
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
.PHONY: generate node-image up down roce qoscheck audit verify hw break-13a heal-13a ssh-%
generate:
	python3 gen_topo.py
node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || \
	  docker build --network host -t bgpbook-multitool-lldpd -f ../ch06/Dockerfile.node ../ch06
up: generate node-image
	sudo containerlab deploy -t topo.clab.yml --reconfigure
down:
	sudo containerlab destroy -t topo.clab.yml
roce:
	./roce.sh
qoscheck:
	./qoscheck.sh
audit:
	./audit.sh
verify:
	./verify_lldp.sh
hw:
	./hw/collect.sh
break-13a:
	./break13a.sh
heal-13a:
	./heal13a.sh
ssh-%:
	$(SSH)$*
