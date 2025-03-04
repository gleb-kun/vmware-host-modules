MODULES = vmmon vmnet
SUBDIRS = $(MODULES:%=%-only)
TARBALLS = $(MODULES:%=%.tar)
MODFILES = $(foreach mod,$(MODULES),$(mod)-only/$(mod).ko)
VM_UNAME = $(shell uname -r)
MODDIR = /lib/modules/$(VM_UNAME)/misc

MODINFO = /sbin/modinfo
DEPMOD = /sbin/depmod

%.tar: FORCE gitcleancheck
	git archive -o $@ --format=tar HEAD $(@:.tar=-only)

.PHONY: FORCE subdirs $(SUBDIRS) clean tarballs

subdirs: retiredcheck $(SUBDIRS)

FORCE:

$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)

gitcheck:
	@git status >/dev/null 2>&1 \
	     || ( echo "This only works in a git repository."; exit 1 )

gitcleancheck: gitcheck
	@git diff --exit-code HEAD >/dev/null 2>&1 \
	     || echo "Warning: tarballs will reflect current HEAD (no uncommited changes)"

retiredcheck:
	@test -f RETIRED && cat RETIRED || true

install: retiredcheck $(MODFILES)
	@echo "Installing kernel modules..."
	@for f in $(MODFILES); do \
	    mver=$$($(MODINFO) -F vermagic $$f);\
	    mver=$${mver%% *};\
	    test "$${mver}" = "$(VM_UNAME)" \
	        || ( echo "Version mismatch: module $$f $${mver}, kernel $(VM_UNAME)" ; exit 1 );\
	done
	@for f in $(MODFILES); do \
	    target="$(DESTDIR)$(MODDIR)/$$(basename $$f)"; \
	    echo "Installing $$f -> $$target"; \
	    install -D $$f $$target; \
	done
	@for mod in $(MODULES); do \
	    echo "Stripping debug symbols from $(DESTDIR)$(MODDIR)/$$mod.ko"; \
	    strip --strip-debug $(DESTDIR)$(MODDIR)/$$mod.ko; \
	done
	if test -z "$(DESTDIR)"; then \
	    echo "Updating module dependencies..."; \
	    $(DEPMOD) -a $(VM_UNAME); \
	fi
	@echo "Installation complete."

uninstall:
	@echo "Uninstalling kernel modules..."
	@for mod in $(MODULES); do \
	    if [ -f "$(DESTDIR)$(MODDIR)/$$mod.ko" ]; then \
	        echo "Removing $(DESTDIR)$(MODDIR)/$$mod.ko"; \
	        rm -f "$(DESTDIR)$(MODDIR)/$$mod.ko"; \
	    else \
	        echo "Module $$mod.ko not found in $(DESTDIR)$(MODDIR)"; \
	    fi \
	done
	if test -z "$(DESTDIR)"; then \
	    echo "Updating module dependencies..."; \
	    $(DEPMOD) -a $(VM_UNAME); \
	fi
	@echo "Uninstall complete."

clean: $(SUBDIRS)
	rm -f *.o

tarballs: $(TARBALLS)

