LAB   = bgpbook-ch02
TOPO  = topo.clab.yml
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-

.PHONY: up down solution audit trace break-2a heal-2a
.PHONY: ssh-% logs-%

# Deploys three UNCONFIGURED switches. The chapter walks you through the
# build; `make solution` applies the finished configs from bootstrap/.
up:
	sudo containerlab deploy -t $(TOPO) --reconfigure

down:
	sudo containerlab destroy -t $(TOPO)

solution:
	./configure.sh

ssh-%:
	$(SSH)$*

logs-%:
	$(SSH)$* "sudo tail -f /var/log/frr/frr.log"

audit:
	./audit.sh

trace:
	./trace.sh

break-2a:
	./break-2a.sh

heal-2a:
	./heal-2a.sh
