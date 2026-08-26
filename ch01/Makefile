LAB   = bgpbook-ch01
TOPO  = topo.clab.yml
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-

.PHONY: up deploy configure down ping fail-link heal-link fail-spine heal-spine capture
.PHONY: ssh-% logs-%

up: deploy configure

deploy:
	sudo containerlab deploy -t $(TOPO) --reconfigure

configure:
	./configure.sh

down:
	sudo containerlab destroy -t $(TOPO)

ssh-%:
	$(SSH)$*

logs-%:
	$(SSH)$* "sudo tail -f /var/log/frr/frr.log"

ping:
	docker exec -it clab-$(LAB)-server01 ping 172.16.3.10

# The chapter's failure demo: kill the spine01-to-leaf01 link (spine side).
fail-link:
	$(SSH)spine01 "sudo ip link set swp1 down"

heal-link:
	$(SSH)spine01 "sudo ip link set swp1 up"

# Exercise 1: kill an entire spine, then bring it back.
fail-spine:
	docker stop clab-$(LAB)-spine01

heal-spine:
	docker start clab-$(LAB)-spine01

# Exercise 2: rerun the link failure with BGP packet capture on every
# fabric-facing port of both spines and leaf01, then count UPDATE messages.
capture:
	./capture.sh
