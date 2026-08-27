LAB   = bgpbook-ch06
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
D     = docker exec clab-$(LAB)

.PHONY: generate node-image up down verify audit trace
.PHONY: measure-default tune-timers measure-tuned bfd-on measure-bfd
.PHONY: tune-connect reconnect-default reconnect-tuned
.PHONY: bfd-fast stress defaults
.PHONY: numbered unnumbered break-6a heal-6a
.PHONY: ssh-% logs-% shell-%

# The spec is the design; everything else is generated from it.
generate:
	python3 gen_topo.py

node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || \
	  docker build --network host -t bgpbook-multitool-lldpd -f Dockerfile.node .

up: generate node-image
	sudo containerlab deploy -t topo.clab.yml --reconfigure

down:
	sudo containerlab destroy -t topo.clab.yml

verify:
	./verify_lldp.sh

audit:
	./audit.sh

trace:
	./trace.sh

# --- the measured tuning ladder ---
measure-default:            ## failover with everything at platform defaults
	./measure.sh default-hold

tune-timers:                ## keepalive 1, hold 3, fabric-wide
	./tune.sh timers

measure-tuned:
	./measure.sh tuned-hold

bfd-on:                     ## BFD at platform default intervals
	./tune.sh bfd

measure-bfd:
	./measure.sh bfd

tune-connect:
	./tune.sh connect

reconnect-default:
	./reconnect.sh default

reconnect-tuned:
	./reconnect.sh tuned

# --- the over-tuning trap ---
bfd-fast:                   ## BFD 50 ms x2: the aggressive setting
	./tune.sh bfd-fast

stress:                     ## CPU-starve spine01 with current settings
	./stress.sh $(LABEL)

defaults:                   ## back to platform defaults everywhere
	./tune.sh defaults

# --- exercise 1: the numbered conversion ---
numbered:
	python3 gen_topo.py --numbered
	sudo containerlab deploy -t topo.clab.yml --reconfigure

unnumbered: up

# --- exercise 4: the duplicate ASN ---
break-6a:
	python3 gen_topo.py --dup-asn 1 4
	sudo containerlab deploy -t topo.clab.yml --reconfigure
	@echo "deployed with leaf04 wearing leaf01's ASN. Look at leaf04's routes."

heal-6a: up

ssh-%:
	$(SSH)$*

shell-%:
	$(D)-$* bash

logs-%:
	$(SSH)$* "sudo tail -f /var/log/frr/frr.log"
