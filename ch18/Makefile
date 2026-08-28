# Chapter 18: pre-deployment validation. The pipeline that gates a change on
# evidence before it touches production. Assumes the chapter 17 fabric
# (bgpbook-ch17) is running; the twin is read from it.
PY   ?= /root/bfvenv/bin/python
.PHONY: bf-up bf-down lint twin validate golden golden-update ci break-18a heal-18a clean

bf-up:      ## start the Batfish service
	docker inspect batfish >/dev/null 2>&1 || \
	  docker run -d --name batfish -p 9996:9996 -p 9997:9997 batfish/allinone >/dev/null
	@echo "batfish up"
bf-down:
	docker rm -f batfish >/dev/null 2>&1 || true
lint:
	python3 lint.py
twin:
	python3 mksnapshot.py
validate: twin
	$(PY) validate.py
golden:
	python3 golden.py
golden-update:
	python3 golden.py --update
ci: bf-up
	./ci.sh
break-18a: bf-up
	./break18a.sh
heal-18a:
	rm -rf snapshot-broken && echo "bad candidate discarded; re-run make ci on the fixed change"
clean:
	rm -rf snapshot snapshot-broken
