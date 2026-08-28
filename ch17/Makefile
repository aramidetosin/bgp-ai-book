LAB   = bgpbook-ch17
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-
.PHONY: generate node-image up down verify drift break-17a heal-17a diff push ssh-%
generate:
	python3 gen.py
node-image:
	docker image inspect bgpbook-multitool-lldpd >/dev/null 2>&1 || docker build --network host -t bgpbook-multitool-lldpd -f ../ch06/Dockerfile.node ../ch06
up: generate node-image
	sudo containerlab deploy -t topo.clab.yml --reconfigure
down:
	sudo containerlab destroy -t topo.clab.yml
verify:
	./verify.sh
drift:
	python3 drift.py
diff:
	./gitdiff.sh
break-17a:
	./break17a.sh
heal-17a:
	python3 gen.py && echo "regenerated from the correct template; make push to deploy"
push:
	python3 push.py
ssh-%:
	$(SSH)$*
