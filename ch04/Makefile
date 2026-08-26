LAB   = bgpbook-ch04
TOPO  = topo.clab.yml
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
D     = docker exec clab-$(LAB)

.PHONY: up down configure audit trace curl collective dataset oob-ping blackout restore
.PHONY: ssh-% logs-% shell-%

up:
	sudo containerlab deploy -t $(TOPO) --reconfigure

down:
	sudo containerlab destroy -t $(TOPO)

configure:
	./configure.sh

ssh-%:
	$(SSH)$*

shell-%:
	$(D)-$* bash

logs-%:
	$(SSH)$* "sudo tail -f /var/log/frr/frr.log"

audit:
	./audit.sh

trace:
	./trace.sh

# One job per network.
curl:
	$(D)-client curl -s -o /dev/null -w "frontend: %{http_code} in %{time_total}s\n" http://172.16.10.11/

collective:
	$(D)-node sh -c "pgrep iperf3 >/dev/null || nohup iperf3 -s -B 172.31.1.11 >/dev/null 2>&1 &"
	$(D)-gpu-peer iperf3 -c 172.31.1.11 -B 172.31.1.12 -t 10 -i 5

dataset:
	$(D)-node sh -c "curl -s -o /dev/null -w 'storage: fetched dataset.bin at %{speed_download} bytes/s over %{time_total}s\n' http://172.30.2.12/dataset.bin"

oob-ping:
	$(D)-oob-mgmt ping -c 3 10.99.0.11

# The out-of-band survival demo: every data-plane NIC on the node dies,
# and the BMC path keeps answering.
blackout:
	$(D)-node ip link set eth1 down
	$(D)-node ip link set eth2 down
	$(D)-node ip link set eth3 down
	@echo "frontend, backend, and storage are down on the node. Try 'make curl' (fails) and 'make oob-ping' (succeeds)."

restore:
	$(D)-node ip link set eth1 up
	$(D)-node ip link set eth2 up
	$(D)-node ip link set eth3 up
	$(D)-node ip route replace default via 172.16.10.1
	$(D)-node ip route replace 172.30.2.0/24 via 172.30.1.1
