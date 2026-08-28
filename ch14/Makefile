LAB   = bgpbook-ch14
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
.PHONY: generate node-image host-image up down setup burst qos degrade audit verify break-14a heal-14a ssh-%
generate:
	python3 gen_topo.py
node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || docker build --network host -t bgpbook-multitool-lldpd -f ../ch06/Dockerfile.node ../ch06
	docker image inspect bgpbook-frr-host >/dev/null 2>&1 || docker build --network host -t bgpbook-frr-host -f ../ch09/Dockerfile.host ../ch09
up: generate node-image
	sudo containerlab deploy -t topo.clab.yml --reconfigure
down:
	sudo containerlab destroy -t topo.clab.yml
setup:
	./setup.sh
burst:
	./burst.sh
qos:
	./qos.sh
degrade:
	./degrade.sh
audit:
	./audit.sh
verify:
	./verify_lldp.sh
break-14a:
	./break14a.sh
heal-14a:
	./heal14a.sh
ssh-%:
	$(SSH)$*
