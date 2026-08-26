LAB   = bgpbook-ch03
TOPO  = topo.clab.yml
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-

.PHONY: up down configure audit trace serve collective fail-frontend heal-frontend fail-backend heal-backend
.PHONY: ssh-% logs-% shell-%

up:
	sudo containerlab deploy -t $(TOPO) --reconfigure

down:
	sudo containerlab destroy -t $(TOPO)

# Fallback for images without the startup-config patch.
configure:
	./configure.sh

ssh-%:
	$(SSH)$*

shell-%:
	docker exec -it clab-$(LAB)-$* bash

logs-%:
	$(SSH)$* "sudo tail -f /var/log/frr/frr.log"

audit:
	./audit.sh

trace:
	./trace.sh

# The frontend's job: nodea's HTTP service (the image ships nginx on :80),
# reached by the client across the routed frontend.
curl:
	docker exec clab-$(LAB)-client curl -s -o /dev/null -w "%{http_code} in %{time_total}s\n" http://172.16.10.11/

# The backend's job: a stand-in for collective traffic between the nodes.
collective:
	docker exec -d clab-$(LAB)-nodea iperf3 -s -B 172.31.1.11
	docker exec clab-$(LAB)-nodeb iperf3 -c 172.31.1.11 -B 172.31.1.12 -t 20 -i 5

fail-frontend:
	docker exec clab-$(LAB)-nodea ip link set eth1 down

heal-frontend:
	docker exec clab-$(LAB)-nodea ip link set eth1 up
	docker exec clab-$(LAB)-nodea ip route replace default via 172.16.10.1

fail-backend:
	docker exec clab-$(LAB)-nodea ip link set eth2 down

heal-backend:
	docker exec clab-$(LAB)-nodea ip link set eth2 up
