# Chapter 21: day-2 operations, the capstone. Game day runs against the
# reference fabric (bgpbook-ch16) with the chapter 19 observability stack up.
# Assumes ../ch16 is deployed and ../ch19 `make bmp-up` has been run.
.PHONY: gameday reveal clear
gameday:  ## inject one of five undisclosed faults
	./gameday.sh
reveal:   ## reveal the injected fault and its reference post-mortem
	./reveal.sh
clear:    ## clear all faults, return the fabric to health
	./clear.sh
