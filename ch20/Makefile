# Chapter 20: hardening. Red-teams the chapter 9 routed-host session
# (bgpbook-ch09): a compromised host attacks through BGP and the per-peer
# controls stop it. Assumes that fabric is up (cd ../ch09 && make up).
.PHONY: redteam harden
redteam:  ## default-route hijack filtered; prefix flood torn down
	./redteam.sh
harden:   ## complete the session: TCP-AO check, MD5, GTSM
	./harden.sh
