.PHONY: check check-overlays check-mirrors
check: check-overlays check-mirrors

check-overlays:
	$(MAKE) -C files/overlays check

check-mirrors:
	$(MAKE) -C files/mirrors check
