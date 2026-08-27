LAB   = bgpbook-ch10
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
D     = docker exec clab-$(LAB)
K     = docker exec node01 kubectl --kubeconfig /etc/kubernetes/admin.conf

.PHONY: generate node-image nodes-up up cluster bgp walk tunnel
.PHONY: break-10a heal-10a audit verify down ssh-% shell-%

generate:
	python3 gen_topo.py

node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || \
	  docker build --network host -t bgpbook-multitool-lldpd -f ../ch06/Dockerfile.node ../ch06

nodes-up:
	./nodes-up.sh

up: generate node-image nodes-up
	sudo containerlab deploy -t topo.clab.yml --reconfigure

cluster:
	./cluster.sh

bgp:
	./bgp.sh

walk:
	./walk.sh

tunnel:
	./tunnel.sh

break-10a:
	./break10a.sh

heal-10a:
	./heal10a.sh

audit:
	./audit.sh

verify:
	./verify_lldp.sh

down:
	sudo containerlab destroy -t topo.clab.yml || true
	docker rm -f clab-$(LAB)-node01 clab-$(LAB)-node02 clab-$(LAB)-node03 2>/dev/null || true

ssh-%:
	$(SSH)$*

shell-%:
	$(D)-$* bash
