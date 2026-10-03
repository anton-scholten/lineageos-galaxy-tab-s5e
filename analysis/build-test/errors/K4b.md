<!-- task: K4b | agent: Space Bunny Free | date: 2026-10-03 -->
# K4b: ANDROID_VERSION

## Summary
- `ANDROID_VERSION` is **not** defined anywhere in the sdm670 tree: `git grep -n ANDROID_VERSION a30605a54f3b` returns **zero hits**.
- In the Exynos tree it is a **build-system symbol**, not a header `#define`: `Makefile:490` / `Makefile:496` add `-DANDROID_VERSION=...` to `KBUILD_CFLAGS`, and the root `Kconfig:11-13` declares a Kconfig symbol `ANDROID_VERSION` fed from the environment.
- **Which is it?** It is a **missing prerequisite from the Exynos base**, *not* series behaviour and *not* new `-Wundef` behaviour. The defining commit `c8eec9dd15359ee501990ed88fc6b0b029987f62` ("G960FXXUCFTK1", 2021-01-04) is an **ancestor of the series base** `d54533f1546b`, so it is outside `d54533f1546b..baa585f67e0e` and has **no row in `results.tsv`**. No commit in the series defines it (3 in-series commits touch `Makefile`, none adds it; 0 commits touch the root `Kconfig`).
- `-Wundef` and `-Werror` already exist in sdm670 (`Makefile:411`, `Makefile:757-759` + `CONFIG_CC_WERROR=y` in `gts4lvwifi_defconfig:785`), so the error is an ordinary missing-define error, not a new warning class.
- **How the offending line got into the port:** it was pulled in by a conflict that was auto-resolved to the Exynos side, not by a clean apply. `05e4636c5fed5134406bd251623d656c031f760e` is **CONFLICT** on `include/uapi/asm-generic/socket.h` (`results.tsv:468`); the following clean commit `b6d094128229f96f330064e07f2c748ab39e1f93` then inserted `SO_BINDTOIFINDEX 62` right above it, putting `#if ANDROID_VERSION < 90000` at **exactly line 112** — the line in the build log.
- **Lead must check first:** the primary fix I recommend is to resolve that conflict *by hand* and **drop the Samsung KNOX NPA block** (nothing in sdm670 uses it). Porting the `ANDROID_VERSION` build machinery is the fallback, needed only if other KNOX/base prerequisites are going to be dragged in later.

## Defined at
Series head `baa585f67e0e`, two places, neither of them a C header:

| What | Where |
|---|---|
| C preprocessor define (the one the error is about) | `Makefile:490` `KBUILD_CFLAGS += -DANDROID_VERSION=$(PLATFORM_VERSION_NUMBER)` and the fallback `Makefile:496` `KBUILD_CFLAGS += -DANDROID_VERSION=990000` |
| Same value exported to sub-makes and to Kconfig | `Makefile:488` `export ANDROID_VERSION=...`, `Makefile:495` `export ANDROID_VERSION=990000` |
| Kconfig symbol (string, from env) | `Kconfig:11-13` → `config ANDROID_VERSION` / `string` / `option env="ANDROID_VERSION"` |

The **failing use** is `include/uapi/asm-generic/socket.h:112` at `baa585f67e0e` (`#if ANDROID_VERSION < 90000`, inside the `// KNOX NPA` block, lines 111-121). Same line number at `b6d094128229f96f330064e07f2c748ab39e1f93`, which matches `port-first-errors.txt` line 2 exactly.

Other uses of the same define at `baa585f67e0e` that will break the build the same way if they get pulled into the port: `include/linux/fs.h:3407` (`AID_USE_ROOT_RESERVED` 5555 vs 5678), `kernel/kmod.c:583` (`ANDROID_VERSION >= 100000`, `CONFIG_SECURITY_DEFEX`), `fs/proc/Kconfig:113`, `init/Kconfig:1983`, plus Exynos-only files (`drivers/sensorhub/brcm/ssp_firmware.c:18,20,26,28,34,36`, `drivers/sensorhub/brcm/ssp_debug.c:489`, `drivers/gpu/arm/Kconfig:27-30`, `drivers/net/wireless/broadcom/bcmdhd_101_12/Makefile:334-346`).

## Added by
`c8eec9dd15359ee501990ed88fc6b0b029987f62` — "G960FXXUCFTK1", synt4x93, 2021-01-04. One big Samsung vendor squash commit that introduced **both** the definition (`Kconfig`, `Makefile`) and the generic uses (`include/uapi/asm-generic/socket.h`, `include/linux/fs.h`, `kernel/kmod.c`, `drivers/sensorhub/brcm/*`) in one go:

```
git log --format='%H %ad %s' --date=short -S'ANDROID_VERSION' baa585f67e0e -- Kconfig
git log --format='%H %ad %s' --date=short -S'ANDROID_VERSION' baa585f67e0e -- Makefile
git log --format='%H %ad %s' --date=short -S'ANDROID_VERSION' d54533f1546b..baa585f67e0e   # → empty
```
Both per-file searches return only `c8eec9dd1535…`; the in-series search returns **nothing**, i.e. no series commit adds or removes the string.

Commit that brought the *use* into the port tree: `05e4636c5fed5134406bd251623d656c031f760e` ("UPSTREAM: net: add new control message for incoming HW-timestamped packets", 2017-05-19) — **CONFLICT**, conflicting file `include/uapi/asm-generic/socket.h` (`analysis/exyhyperbrick-trial/results.tsv:468`), resolved to the Exynos side (`analysis/build-test/README.md` §2: "conflicts auto-resolved to the series side").

## Status (in series/skipped/prerequisite)
**Prerequisite (before the series base).** Verified both directions:

```
git merge-base --is-ancestor c8eec9dd15359ee501990ed88fc6b0b029987f62 d54533f1546b  → exit 0 (it IS an ancestor of the base)
git merge-base --is-ancestor d54533f1546b c8eec9dd15359ee501990ed88fc6b0b029987f62  → non-zero (it is NOT after the base)
git rev-list --count d54533f1546b..c8eec9dd15359ee501990ed88fc6b0b029987f62        → 0
```
The Exynos base already has it: `d54533f1546b:Kconfig:11`, `d54533f1546b:Makefile:486,488,493,494`.

**No status in `results.tsv`** — expected, because the commit is outside the range the trial replayed (`grep c8eec9dd1535 analysis/exyhyperbrick-trial/results.tsv` → no match). So this is one of the "prerequisites sit in the Exynos tree's base, not in the series" cases listed in `analysis/exyhyperbrick-trial/README.md` / `analysis/build-test/README.md` §"What this shows" 2.

The commit whose conflict *caused* the error, `05e4636c5fed5134406bd251623d656c031f760e`, is **CONFLICT** (`results.tsv:468`); the follow-up `b6d094128229f96f330064e07f2c748ab39e1f93` is **CLEAN** (`results.tsv:2244`).

## Present in sdm670
**No — zero occurrences anywhere in the tree at `a30605a54f3b`.** `git grep -n ANDROID_VERSION a30605a54f3b` → empty, and `git grep -n -i 'android_version' a30605a54f3b` → empty too. Also absent:
- the `Kconfig` symbol: sdm670's root `Kconfig` (blob `c13f48d6`) contains only `config SRCARCH` + `option env="SRCARCH"`, 11 lines total;
- `scripts/android-version.sh` and `scripts/android-major-version.sh`: `git ls-tree a30605a54f3b scripts/android-version.sh scripts/android-major-version.sh` → empty (both were added by the same prerequisite commit);
- the KNOX NPA block: sdm670's `include/uapi/asm-generic/socket.h` is 97 lines and ends at `#endif`, and `git grep -n 'SO_SET_DOMAIN_NAME\|SO_SET_DNS_UID\|SO_SET_DNS_PID' a30605a54f3b` → **no hits**, so nothing in sdm670 needs those three constants.

What sdm670 *does* have, so the warning is an error:
- `-Wundef`: `Makefile:411` `KBUILD_CFLAGS := -Wall -Wundef -Wstrict-prototypes …` (also present in the Exynos tree at `Makefile:406`);
- `-Werror`: `Makefile:757-759` `ifdef CONFIG_CC_WERROR / KBUILD_CFLAGS += -Werror`, and `CONFIG_CC_WERROR=y` is set in `arch/arm64/configs/gts4lvwifi_defconfig:785` and `arch/arm64/configs/gts4lv_defconfig:787`.
→ the `[-Werror,-Wundef]` diagnostic is pre-existing sdm670 behaviour; the series/port only supplied the undefined macro.

## How the Exynos build sets it
Exactly how `baa585f67e0e:Makefile:485-497` works — a make variable from the **environment**, converted by a 2-line awk script, with a hardcoded fallback:

```make
485:ifneq ($(PLATFORM_VERSION), )
486:PLATFORM_VERSION_NUMBER=$(shell $(CONFIG_SHELL) $(srctree)/scripts/android-version.sh $(PLATFORM_VERSION))
487:MAJOR_VERSION=$(shell $(CONFIG_SHELL) $(srctree)/scripts/android-major-version.sh $(PLATFORM_VERSION))
488:export ANDROID_VERSION=$(PLATFORM_VERSION_NUMBER)
489:export ANDROID_MAJOR_VERSION=$(MAJOR_VERSION)
490:KBUILD_CFLAGS += -DANDROID_VERSION=$(PLATFORM_VERSION_NUMBER)
491:KBUILD_CFLAGS += -DANDROID_MAJOR_VERSION=$(MAJOR_VERSION)
494:else
495:export ANDROID_VERSION=990000
496:KBUILD_CFLAGS += -DANDROID_VERSION=990000
497:endif
```
(13 lines at `Makefile:485-497` @ `baa585f67e0e`; line 493 is a commented-out example.)

- **Env var, not a file and not `git describe`.** `PLATFORM_VERSION` is a make variable (normally exported into the kernel build by the Android build system as the platform release string, e.g. `16` / `10.0.0_r1`).
- `scripts/android-version.sh` (2 lines, `@ baa585f67e0e`) turns it into an integer: `echo $1 | awk -F. '{ printf "%d%02d%02d", $1, $2, $3 }'` → `10.0.0` → `100000`. That is why the comparisons are `< 90000` (Android 9) and `>= 100000` (Android 10).
- **`PLATFORM_VERSION` unset (the normal case for a plain `make`, and for our build test): the `else` branch hardcodes `990000`.** So the Exynos kernel always compiles with `-DANDROID_VERSION=990000` unless the Android build passes `PLATFORM_VERSION`. 990000 ≥ 90000, so `#if ANDROID_VERSION < 90000` is false → the Android-9-and-later values (`SO_SET_DOMAIN_NAME 1000`, `SO_SET_DNS_UID 1001`, `SO_SET_DNS_PID 1002`) are used.
- The `export` at `Makefile:488/495` is what makes the value visible to Kconfig, where `Kconfig:11-13 option env="ANDROID_VERSION"` turns it into the string symbol the Kconfig conditionals use (`drivers/gpu/arm/Kconfig:27-30`, `fs/proc/Kconfig:113`, `init/Kconfig:1983`).
- I could **not** find an authoritative AOSP file that exports `PLATFORM_VERSION` into the kernel build: `grep PLATFORM_VERSION` in `platform_build/core/config.mk` and `core/Makefile` (master, `android-9.0.0_r1`, `android-8.1.0_r1`) and `core/envsetup.mk` shows only *uses* of `PLATFORM_VERSION`, no `export PLATFORM_VERSION`. Not important for us: sdm670's `Makefile` ignores `PLATFORM_VERSION` entirely, and the `else` branch alone is enough to fix the build.

**ACK / mainline for comparison (checked 2026-10-03):** this is **Samsung/KNOX-specific, not an ACK or mainline mechanism.**
- `aosp-mirror/kernel_common` branch `android-mainline`, root `Kconfig`: no `ANDROID_VERSION` symbol (it only has `source "scripts/Kconfig.include"` etc.).
- `aosp-mirror/kernel_common` `android-mainline` and `android11-5.4` `Makefile`: no `ANDROID_VERSION`, no `PLATFORM_VERSION`.
- `torvalds/linux` `master` `Makefile`: no `ANDROID_VERSION`, and no case-insensitive `android` match at all.
So the series does not mirror ACK or mainline for this symbol — it carries a Samsung-internal prerequisite.

## Suggested fix
Two workable options. **Recommend option A**, keep B as the fallback.

**A (recommended): resolve `05e4636c5fed5134406bd251623d656c031f760e` by hand and drop the KNOX NPA block** from `include/uapi/asm-generic/socket.h` — i.e. keep sdm670's version and add only the new constants the commit actually brings (`SCM_TIMESTAMPING_OPT_STATS 54`, `SO_MEMINFO 55`, `SO_INCOMING_NAPI_ID 56`, `SCM_TIMESTAMPING_PKTINFO 58`, `SO_PEERGROUPS 59`, `SO_ZEROCOPY 60`, `SO_BINDTOIFINDEX 62`), leaving out the `#if ANDROID_VERSION < 90000` / `SO_SET_DOMAIN_NAME` / `SO_SET_DNS_UID` / `SO_SET_DNS_PID` block. This needs no build-system change, and it is what the other K4 errors also point at ("taking theirs" is the root cause). Supporting facts:
- `git grep 'SO_SET_DOMAIN_NAME|SO_SET_DNS_UID|SO_SET_DNS_PID' a30605a54f3b` → no hits, so the block is dead code on this device.
- It is a **uapi** header: userspace gets `ANDROID_VERSION` = 0, so it would take the `< 90000` branch and define `SO_SET_DOMAIN_NAME 55` (= `SO_MEMINFO 55`), `SO_SET_DNS_UID 56` (= `SO_INCOMING_NAPI_ID 56`), `SO_SET_DNS_PID 58` (= `SCM_TIMESTAMPING_PKTINFO 58`). Silent value collisions in `/usr/include` headers.
- Precedent: this is the same shape as K4a (`compiler.h` randstruct macros) and K4c — Exynos-base prerequisites that were never needed by sdm670.

**B (fallback, or if option A conflicts with something else): port the prerequisite build glue**, as its own commit on the kernel branch, not as part of the series replay:
- copy `Makefile:485-497` from `baa585f67e0e` into the sdm670 `Makefile` (11 operative lines quoted above; it needs `scripts/android-version.sh` and `scripts/android-major-version.sh` from the same commit, or just keep only the `else` branch: `export ANDROID_VERSION=990000` + `KBUILD_CFLAGS += -DANDROID_VERSION=990000`);
- optionally add the two stanzas `Kconfig:11-17` (`config ANDROID_VERSION` / `string` / `option env="ANDROID_VERSION"`, and `ANDROID_MAJOR_VERSION`) so the Kconfig conditionals (`init/Kconfig`, `fs/proc/Kconfig`) can also see it;
- **always use the `else`/990000 path** (or drop the `PLATFORM_VERSION` branch) so the value never depends on the build environment. 990000 ≥ 90000 selects the modern Android KNOX/ABI values, which is what a 23.2 build wants.
- Note this is not "Track B": `ANDROID_VERSION` selects Android **platform API level** constants (socket options, `AID_USE_ROOT_RESERVED`), it is not a security/version check.

**After either fix, sweep the port tree** for the other uses listed in "Defined at" — `include/linux/fs.h:3407` and `kernel/kmod.c:583` are generic files that a later "theirs" resolution can drag in, and they fail the same way. `grep -rn ANDROID_VERSION <port tree>` should come back empty (option A) or fully defined (option B).

## Confidence
- `confidence: high` on "sdm670 has zero `ANDROID_VERSION`, the defining commit is `c8eec9dd15359ee501990ed88fc6b0b029987f62`, it is an ancestor of the base (prerequisite, no `results.tsv` row), and the build sets it via `KBUILD_CFLAGS += -DANDROID_VERSION=` from `PLATFORM_VERSION` with a hardcoded `990000` fallback" — every one of those is a direct `git log`/`git grep`/`merge-base --is-ancestor` result quoted above, checked in the shared tree without modifying it.
- `confidence: high` on "the block at `socket.h:112` arrived via the CONFLICT on `05e4636c5fed…` resolved to the Exynos side, not via the CLEAN `b6d094128229…`" — the line number 112 matches `git show b6d094128229…:include/uapi/asm-generic/socket.h | grep -n ANDROID_VERSION` exactly, sdm670's own `socket.h` has no such block at all, and `results.tsv:468` records that conflict.
- `confidence: high` on "not new `-Wundef`/`-Werror` behaviour" — both flags are in sdm670's `Makefile` (411, 757-759) and `CONFIG_CC_WERROR=y` is in both defconfigs.
- `confidence: medium` on "ACK and mainline don't define `ANDROID_VERSION`" — checked by fetching 4 files from `aosp-mirror/kernel_common` and `torvalds/linux` on 2026-10-03; a Samsung-specific symbol could still exist in an older ACK branch I did not check (the mirror only goes back to `android11-5.4`).
- `confidence: low` on "the Android build system exports `PLATFORM_VERSION`" — I could not find it in `platform_build` `core/config.mk`, `core/Makefile`, `core/envsetup.mk` (master, 9.0, 8.1); only a third-party kernel build script on the web sets it. Irrelevant to the fix, since sdm670's `Makefile` never reads it.
- `confidence: medium` on recommending option A over B — it is a judgement call about how much Exynos KNOX code the port intends to carry; the K4c/K4d errors suggest the lead is already dropping Exynos-only code, but that is the lead's call.

## Problems
- `git log -S'ANDROID_VERSION' a30605a54f3b` (checking whether sdm670 ever had the symbol anywhere in its history) timed out after 120 s on this tree, so I did not retry it. I only verified the tip (`git grep -n ANDROID_VERSION a30605a54f3b` → 0 hits), which is what the build needs. Command as run: `git -C ~/work/k670 log --format='%H %s' -S'ANDROID_VERSION' a30605a54f3b`.
- The port tree from the build test (`/tmp/claude-0/w/k670-port`, per `port-first-errors.txt`) no longer exists on this host, so I could not grep it for the other `ANDROID_VERSION` uses. The list in "Defined at" comes from the series head instead and is a superset of what the port can contain.
- I could not identify from an authoritative AOSP source who exports `PLATFORM_VERSION` (see Confidence). The kernel side of the mechanism is fully established, so this does not affect the fix.