# steamplay-mac fork of NotProton

This branch is upstream NotProton plus a short stack of commits for steamplay-mac. It is
never merged with upstream: every upstream release gets a fresh branch, `custom-wine-<version>`,
with the stack rebased onto the release tag.

| Commit | What it adds |
| --- | --- |
| Custom Wine runners | `runners/wine-<name>` registered as Steam compat tools, run through the same script |
| AION 2 CPUID fix | `gamefixes/aion2`, inserted into the Wine loader for app 3393110 |

Upstream does not take custom runners, so they stay here.

## Where the fork touches upstream files

The fork's code lives in its own files or in one marked block. Upstream files get one-line
hooks only, so a rebase conflicts in a few predictable lines.

| Upstream file | Fork change |
| --- | --- |
| `Makefile` | `include fork.mk` at the end |
| `dylib/feats/compat.h` | prototype of `np_compat_load_custom_runners` |
| `dylib/feats/compat.c` | a call to it in the tool scan, and `#include "custom_runner.inc"` at the end |
| `dylib/feats/compat_run.sh` | the block between `# >>> steamplay-mac fork` and `# <<< steamplay-mac fork`, and calls guarded by `[ "${np_runner_kind-}" != custom ] \|\|` |
| `dylib/feats/webui.c` | `MAX_ROUTES` 12 → 16 and four more job factories, so the fork's extra web UI routes fit |
| `dylib/tests/compatcheck.c` | `custom_runner_cases()` and its call |
| `README.md` | a "Custom Wine runners (this fork)" section at the end |

Everything else is new: `fork.mk`, `dylib/feats/custom_runner.inc`, `dylib/tests/forkruncheck.sh`,
`helpers/`, `gamefixes/aion2/`, this file.

The run-script calls stay guarded because upstream's shell tests cut regions out of
`compat_run.sh` with sed and run them without the fork block. An unguarded call there is
"command not found". With the guard, a CrossOver launch never reaches the fork's code.

## Moving to a new upstream release

From steamplay-mac:

```sh
scripts/update-notproton.sh v1.2.8
```

The script fetches upstream and rebases this stack onto the tag as `custom-wine-1.2.8`. It
then runs `make forkcheck`, builds and installs, and commits the submodule pointer. It stops
on a conflict or a failing suite and leaves the branch for you to finish.

When a rebase conflicts:

- **`compat_run.sh`:** keep upstream's version of the lines around a hook and re-add the
  one-line hook. `make forkruncheck` fails if a `np_custom_*` function is no longer called.
- **`compat.c` and `compat.h`:** the same, for the call and the include.
- **New upstream behaviour the fork duplicated:** drop the fork's copy. Check upstream's
  changelog before porting anything.

`make forkcheck` runs the fork's own suites and every upstream suite that reads a file the
fork patches.

## After Steam updates itself

From steamplay-mac:

```sh
scripts/check-notproton.sh
```

This reads `notproton.log` and `/tmp/dumps` from the latest Steam start and reports:

- a crash dump newer than that start
- a web UI left unpatched
- signatures or hooks left unresolved

Any of these usually means the new client needs a newer NotProton release, and the script
says so.
