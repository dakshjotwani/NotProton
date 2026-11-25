# steamplay-mac fork of NotProton: build rules and checks that upstream does not carry.
# Included from the end of Makefile, so a rebase onto a new release meets one line there.
#
# The fork itself is two commits on an upstream tag (see FORK.md):
#   custom Wine runners  dylib/feats/custom_runner.inc, the "steamplay-mac fork" block in
#                        dylib/feats/compat_run.sh and its one-line calls, helpers/
#   AION 2 CPUID fix     gamefixes/aion2

.PHONY: forkruncheck forkcheck

# The fork's block in the run script, against a fake custom runner.
forkruncheck:
	@sh dylib/tests/forkruncheck.sh dylib/feats/compat_run.sh

# Everything the fork touches: its own checks, and upstream's suites that read the files it
# patches. Run after every rebase (scripts/update-notproton.sh in steamplay-mac does).
FORK_SUITES := forkruncheck compatcheck compatsvc-check webpatch-fixtures \
               featcheck panel-behavior runnervariantcheck envcheck envpasscheck buildcheck \
               bridgecheck settingscheck launchercheck runcheck

forkcheck:
	@fail=""; for t in $(FORK_SUITES); do \
		printf '%-20s ' "$$t"; \
		if out=$$($(MAKE) -s $$t 2>&1); then printf '%s\n' "$$out" | tail -1; \
		else echo FAILED; printf '%s\n' "$$out" | tail -15 | sed 's/^/    /'; fail="$$fail $$t"; fi; \
	done; \
	if [ -n "$$fail" ]; then echo "==> forkcheck: failed:$$fail"; exit 1; fi; \
	echo "==> forkcheck: every suite the fork touches passes"
