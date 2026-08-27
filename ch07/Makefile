LAB   = bgpbook-ch06
PASS ?= Clab123!
SSH   = sshpass -p $(PASS) ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null cumulus@clab-$(LAB)-

.PHONY: underlay overlay audit trace mtu tenant-c break-7a heal-7a remove ssh-%

# The base is chapter 6's generated fabric. If it is not running, this
# brings it up from its own spec.
underlay:
	$(MAKE) -C ../ch06 up

# The chapter's move: the overlay, applied as recorded steps.
overlay:
	./overlay.sh

audit:
	./audit.sh

trace:
	./trace.sh

mtu:
	./mtu.sh

# Exercise 1 recorded: the one-sided type-5 export.
tenant-c:
	./tenantc.sh

break-7a:
	./break7a.sh break

heal-7a:
	./break7a.sh heal

# The removal is part of the lesson: regenerate the underlay from its
# spec, and the overlay is gone because the spec never described it.
remove:
	$(MAKE) -C ../ch06 up

ssh-%:
	$(SSH)$*
