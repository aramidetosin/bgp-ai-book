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
# Healing needs more than docker start: the lab's veth links died with the
# container's old namespace, so we recreate them with containerlab's veth
# tool before the VM will boot.
fail-spine:
	docker stop clab-$(LAB)-spine01

heal-spine:
	docker start clab-$(LAB)-spine01
	sudo containerlab tools veth create -a clab-$(LAB)-spine01:swp1 -b clab-$(LAB)-leaf01:swp2
	sudo containerlab tools veth create -a clab-$(LAB)-spine01:swp2 -b clab-$(LAB)-leaf02:swp2
	sudo containerlab tools veth create -a clab-$(LAB)-spine01:swp3 -b clab-$(LAB)-leaf03:swp2
	sudo containerlab tools veth create -a clab-$(LAB)-spine01:swp4 -b clab-$(LAB)-leaf04:swp2
	@echo "spine01 is rebooting; give it about two minutes, then run ./audit.sh"

# Exercise 2: rerun the link failure with BGP packet capture on every
# fabric-facing port of both spines and leaf01, then count UPDATE messages.
capture:
	./capture.sh
