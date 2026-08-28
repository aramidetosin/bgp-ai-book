LAB   = bgpbook-ch15
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
.PHONY: generate node-image up down contract wan leak audit break-15a heal-15a ssh-%
generate:
	python3 gen_topo.py
node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || docker build --network host -t bgpbook-multitool-lldpd -f ../ch06/Dockerfile.node ../ch06
up: generate node-image
	sudo containerlab deploy -t topo.clab.yml --reconfigure
down:
	sudo containerlab destroy -t topo.clab.yml
contract:
	./contract.sh
wan:
	./wan.sh
leak:
	./leak.sh
audit:
	./audit.sh
break-15a:
	./break15a.sh
heal-15a:
	./heal15a.sh
ssh-%:
	$(SSH)$*
