.PHONY: check
check: check-overlays check-mirrors

.PHONY: check-overlays
check-overlays:
	$(MAKE) -C files/overlays check

.PHONY: check-mirrors
check-mirrors:
	$(MAKE) -C files/mirrors check
