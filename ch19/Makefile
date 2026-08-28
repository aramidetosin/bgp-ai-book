# Chapter 19: observability. Runs against the chapter 16 heartbeat-mesh fabric
# (bgpbook-ch16): the mesh is the job's step time, BMP is the routing view, and
# the two share one clock. Assumes that fabric is up (cd ../ch16 && make up).
LAB  ?= bgpbook-ch16
.PHONY: bmp-up bmp-config collector timeline bmp-query bmp-down

bmp-up: ## load FRR's BMP module, start the collector, point BMP at it
	python3 enablebmp.py
	docker exec clab-$(LAB)-server01 sh -c "pkill -9 -f bmpcollect; sleep 1" 2>/dev/null || true
	docker cp bmpcollect.py clab-$(LAB)-server01:/tmp/bmpcollect.py
	docker exec -d clab-$(LAB)-server01 sh -c "python3 /tmp/bmpcollect.py > /tmp/bmp.log 2>&1"
	sleep 2
	python3 bmpconfig.py
	@echo "BMP up; give FRR ~20s to dump the RIB, then: make timeline / make bmp-query"
timeline:
	./timeline.sh
bmp-query:
	./bmpquery.sh
bmp-down:
	python3 bmpconfig.py --off
	docker exec clab-$(LAB)-server01 pkill -f bmpcollect 2>/dev/null || true
