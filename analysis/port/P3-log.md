<!-- task: P3 | agent: Space Bunny Free | date: 2026-10-04 -->
# P3: known fixes and defconfig

## Summary
Six commits on `port/pick` in `anton-scholten/android_kernel_samsung_sdm670`, on top of P1's
`d73f07cf8b5c`, pushed one by one. `lineage-23.2` and `lineage-22.2` are untouched (both still
`a30605a54f3b92627d868f169c72ef9c6ef82123` on the remote). All four spec checks pass and
`scripts/check-pick.py` still prints `problems: 0` with `fix commits: 6`.

**Two things the reviewer must look at first:**
1. **Item 2 has a sixth caller that the spec does not list**: `drivers/tty/serial/msm_geni_serial.c:2793`
   was still calling the old one-argument `wakeup_source_register()`. I fixed it in the same commit,
   flagged with a `Needs-review:` trailer. Details under "Deviations".
2. **Item 6: fragment section 5 was not applied.** It is headed "optional lines, left commented", and
   one of its lines (`# CONFIG_DEBUG_INFO_BTF is not set`) would have cancelled section 1's
   `CONFIG_DEBUG_INFO_BTF=y`. Details under "Deviations".

`confidence: high` for both: the evidence is in the two commits' trailers and in the check output below.

## One line per item

| # | What | Commit | Check → result |
|---|---|---|---|
| 1 | New `arch/arm64/include/asm/set_memory.h` | `81b96404370485f663ff67d554d5c202840d42ba` | `ls arch/arm64/include/asm/set_memory.h` → exists |
| 2 | `NULL` (and one `&pdev->dev`) as the new first argument of `wakeup_source_register()` | `d6239359349dd167a09219f03361e881138e9fcf` | `git grep -n 'wakeup_source_register(' -- '*.c'` → every call has 2 arguments |
| 3 | `fs/unicode` from `baa585f67e0e` + 2 wiring lines | `d147e3464f7c592c9b3d7164225e43ad0e5718cd` | `ls fs/unicode/Kconfig` → exists |
| 4 | F1: delete `drm_mode.h:92-104` (the `<<19` duplicate) | `14bf14fcdd22b82c1b4f0da1dc0909c56e8a1f08` | region identical to `a30605a54f3b`, `grep -c PIC_AR_MASK` → `1` |
| 5 | F2: delete the second `VM_MAYWRITE` block, `userfaultfd.c:1417-1428` | `d26bd320c51d3ff7237ad718c6eac225a3760530` | `grep -c 'if (unlikely(!(cur->vm_flags & VM_MAYWRITE)))'` → `1` |
| 6 | Merge `gts4lv-23.2.fragment` into all four defconfigs | `316352012ff2b8687d797c63e769f0ec16f499ed` | `make O=~/work/out ARCH=arm64 LLVM=1 gts4lvwifi_defconfig` → exit 0; the 7-line grep → `7` |

## Item 1 — `arch/arm64/include/asm/set_memory.h`

The header was genuinely missing and genuinely needed:
- `arch/arm64/include/asm/cacheflush.h:23` does `#include <asm/set_memory.h>` and that file did not
  exist (`ls` → "No such file", and `git cat-file -e <rev>:arch/arm64/include/asm/set_memory.h`
  fails at `a30605a54f3b`, at `d54533f1546b` and at `baa585f67e0e`).
- arm64 already has the functions: declared `arch/arm64/include/asm/cacheflush.h:161-164`, defined
  `arch/arm64/mm/pageattr.c:98,105,112,120`.
- `arch/arm64/Kconfig:43` `select ARCH_HAS_SET_MEMORY` (LEAD-SYNTHESIS §1.3 says `:25`; the line moved
  when the series was picked — same select, nothing to fix). `include/linux/set_memory.h:12` includes
  the new header.

Content is exactly the 8 lines §6c item 1 dictates. The resulting include cycle
(`set_memory.h` → `cacheflush.h` → `set_memory.h`) is harmless: both files have include guards, and
whoever is included second gets an empty file while the first one already declared `set_memory_*`.

## Item 2 — `wakeup_source_register()`

The prototype is `wakeup_source_register(struct device *dev, const char *name)`
(`include/linux/pm_wakeup.h:102`, `:145`), changed by series commit `0c6f8a9a50ad`. The five
spec'd call sites matched the spec's line numbers exactly, and each got `NULL` — correct, because
`drivers/base/power/wakeup.c:249` documents `@dev` as "or NULL if virtual" and `:302` accepts NULL.

**The sixth caller** (deviation, see below): `drivers/tty/serial/msm_geni_serial.c:2793`
called `wakeup_source_register(dev_name(&pdev->dev))`, i.e. it passed a `const char *` where the new
`struct device *` sits. Evidence that this is the same class of break and not something the spec
covers:
- `git show --stat 0c6f8a9a50ad` touches 15 files, `msm_geni_serial.c` is not one of them;
- `git log --oneline d54533f1546b..baa585f67e0e -- drivers/tty/serial/msm_geni_serial.c` is empty and
  the series head has no such file, so this caller was never updated by anyone;
- `CONFIG_SERIAL_MSM_GENI=y` in all four defconfigs (`:362`, `:362`, `:2327`, `:2327`), so the file
  is built;
- `msm_geni_serial_probe(struct platform_device *pdev)` at `:2603`, and a platform device is
  registered before its probe runs, so `&pdev->dev` is a valid argument — the same value the kernel
  passes at `drivers/base/power/wakeup.c:324`, `kernel/time/alarmtimer.c:1039` and
  `drivers/acpi/device_pm.c:436`. I therefore used `&pdev->dev`, not `NULL`.

Check output (`git grep -n 'wakeup_source_register(' -- '*.c'`), all calls two-argument:

```
drivers/acpi/device_pm.c:436:	adev->wakeup.ws = wakeup_source_register(&adev->dev,
drivers/base/power/wakeup.c:252:struct wakeup_source *wakeup_source_register(struct device *dev,
drivers/base/power/wakeup.c:324:	ws = wakeup_source_register(dev, dev_name(dev));
drivers/char/diag/diagchar_core.c:4148:	driver->diag_dev->power.wakeup = wakeup_source_register(NULL, "DIAG_WS");
drivers/input/misc/gpio_input.c:313:		ds->ws = wakeup_source_register(NULL, wlname);
drivers/power/supply/qcom/battery.c:1605:	chip->pl_ws = wakeup_source_register(NULL, "qcom-battery");
drivers/power/supply/qcom/smb1390-charger.c:779:	chip->cp_ws = wakeup_source_register(NULL, "qcom-chargepump");
drivers/power/supply/qcom/step-chg-jeita.c:755:	chip->step_chg_ws = wakeup_source_register(NULL, "qcom-step-chg");
drivers/staging/qca-wifi-host-cmn/qdf/linux/src/qdf_lock.c:273:	lock->priv = wakeup_source_register(lock->lock.dev, name);
drivers/tty/serial/msm_geni_serial.c:2793:		dev_port->geni_wake = wakeup_source_register(&pdev->dev, dev_name(&pdev->dev));
fs/eventpoll.c:1268:		epi->ep->ws = wakeup_source_register(NULL, "eventpoll");
fs/eventpoll.c:1274:	ws = wakeup_source_register(NULL, n.name);
kernel/power/autosleep.c:122:	autosleep_ws = wakeup_source_register(NULL, "autosleep");
kernel/power/wakelock.c:185:	wl->ws = wakeup_source_register(NULL, wl->name);
kernel/time/alarmtimer.c:1039:	ws = wakeup_source_register(&pdev->dev, "alarmtimer");
net/ipc_router/ipc_router_core.c:1384:		port_ptr->port_rx_ws = wakeup_source_register(NULL, port_ptr->rx_ws_name);
```

(`drivers/base/power/wakeup.c:252` is the definition, not a call.)

## Item 3 — `fs/unicode`

`git checkout baa585f67e0e -- fs/unicode` brought in 10 files. Both wiring lines were inserted at
the exact anchors the spec gives, and both match where the series head has them:

| File | Line | Inserted | Series head |
|---|---|---|---|
| `fs/Makefile` | after `:93` `obj-$(CONFIG_NLS)\t\t+= nls/` | `obj-$(CONFIG_UNICODE)\t\t+= unicode/` (tabs, checked with `cat -A`) | `baa585f67e0e:fs/Makefile:96` |
| `fs/Kconfig` | after `:312` `source "fs/dlm/Kconfig"` | `source "fs/unicode/Kconfig"` | `baa585f67e0e:fs/Kconfig:320` |

`fs/unicode/Kconfig` defines `UNICODE` and `UNICODE_NORMALIZATION_SELFTEST`; `fs/unicode/Makefile`
builds `unicode.o` from `utf8-norm.o` + `utf8-core.o`, so it is a real build, not a no-op like
before.

## Item 4 — F1, `include/uapi/drm/drm_mode.h`

Both spec'd line numbers were exactly right: `:92-104` was the pick's `<<19` copy, `:106-124` the
sdm670 `<<24` copy. Deleted 92-104 (13 lines), kept 106-124. `91cf4dc6c832` ("drm: add picture
aspect ratio flags") is the commit that added the duplicate; it applied without a conflict, so P1
never saw it.

Checks:
- `grep -c 'PIC_AR_MASK' include/uapi/drm/drm_mode.h` → `1`
- `diff` of the region from `DRM_MODE_FLAG_SUPPORTS_YUV420` to `DRM_MODE_FLAG_PIC_AR_256_135`
  against `git show a30605a54f3b:include/uapi/drm/drm_mode.h` → no output (identical)
- `git diff a30605a54f3b -- include/uapi/drm/drm_mode.h` now shows only the legitimate series
  additions (the mode-flag comment, `enum drm_mode_subconnector`, `drm_format_modifier_blob`); the
  picture-aspect-ratio region is untouched relative to the base.

Deleting the other copy, as the prompt warned, would have lost `DRM_MODE_PICTURE_ASPECT_64_27` /
`_256_135` (only the kept block defines them) and left `(0x0F<<19)` covering bits 19-22, which
overlaps `DRM_MODE_FLAG_SUPPORTS_YUV420 (1<<22)` at `:90`.

## Item 5 — F2, `fs/userfaultfd.c`

Deleted 1417-1428: the blank line plus the *second* copy of the "UFFDIO_COPY will fill file holes"
comment and its `VM_MAYWRITE` check, the one after the hugetlb alignment block, as the reviewer
decided. A script asserted the two 11-line copies were byte-identical before deleting.

Checks:
- `grep -c 'if (unlikely(!(cur->vm_flags & VM_MAYWRITE)))' fs/userfaultfd.c` → `1`
- the run from `is_vm_hugetlb_page(cur)` to `ret = -EBUSY;` is byte-identical to
  `baa585f67e0e:fs/userfaultfd.c` (diff of the two extracts → no output)
- the rest of the file still differs from the series head only by sdm670-local Android work
  (`vm_write_begin`/`vm_write_end` around `vm_flags`, three places) — kept, as intended.

## Item 6 — defconfig fragment

37 option lines applied (33 `CONFIG_X=y`, 4 `# CONFIG_X is not set`), per file:

| Defconfig | replaced in place | appended at end | already correct |
|---|---|---|---|
| `gts4lvwifi_defconfig` | 3 | 18 | 16 |
| `gts4lv_defconfig` | 3 | 18 | 16 |
| `gts4lvwifi_eur_open_defconfig` | 10 | 12 | 15 |
| `gts4lv_eur_open_defconfig` | 10 | 12 | 15 |

The three in-place replacements in the small defconfigs are `CGROUP_SCHEDTUNE`, `RT_GROUP_SCHED`,
`SCHED_TUNE`, all flipped to `# ... is not set` per fragment §4. The `*_eur_open_defconfig` files
also had `# CONFIG_PSI is not set`, `# CONFIG_BLK_CGROUP is not set`, `# CONFIG_KPROBES is not set`,
`# CONFIG_UPROBES is not set`, `# CONFIG_USERFAULTFD is not set`, `# CONFIG_NET_ACT_BPF is not set`,
`# CONFIG_BPF_JIT is not set` flipped to `=y`.

A separate script verified afterwards that in all four files each of the 37 symbols appears exactly
once and with exactly the fragment's value: `37/37 options exact, duplicates/omissions: none` ×4.

Spec check:
```
$ make O=~/work/out ARCH=arm64 LLVM=1 gts4lvwifi_defconfig
  ...
# configuration written to .config
make exit=0

$ grep -E '^CONFIG_(CGROUP_SCHED|FAIR_GROUP_SCHED|SCHED_WALT|UPROBES|BPF_JIT|BPF_LSM|UNICODE)=y' \
       ~/work/out/.config | wc -l
7
```
The seven lines: `CONFIG_SCHED_WALT=y`, `CONFIG_CGROUP_SCHED=y`, `CONFIG_FAIR_GROUP_SCHED=y`,
`CONFIG_BPF_LSM=y`, `CONFIG_UPROBES=y`, `CONFIG_BPF_JIT=y`, `CONFIG_UNICODE=y`. Baseline before this
commit was 3 of 7, so `UPROBES`, `BPF_JIT`, `BPF_LSM` and `UNICODE` are the four the fragment adds;
no dependency had to be invented.

Extra, not required by the spec: the same `make ... <defconfig>` plus the same grep for the other
three files gives exit 0 and `7` each (`gts4lv_defconfig`, `gts4lvwifi_eur_open_defconfig`,
`gts4lv_eur_open_defconfig`), so P4 can start from any of the four.

Of the 37 options, 35 survive into `.config`. `SCHED_TUNE` and `CGROUP_SCHEDTUNE` do not appear in
`.config` at all: `init/Kconfig:1536` makes `SCHED_TUNE` `depends on !UCLAMP_TASK`, which section 1
sets, so kconfig makes both symbols invisible and writes nothing. Fragment §4.3/§4.4 predicted
exactly this ("No build impact either way"). Nothing to fix.

## Deviations from the spec (both deliberate, both for the reviewer)

1. **Item 2, sixth call site.** `drivers/tty/serial/msm_geni_serial.c:2793` is not in §6c item 2 and
   was not in review-P1.md finding 2. Item 2's own check ("Every call must now have two arguments")
   cannot pass while it is there, and `CONFIG_SERIAL_MSM_GENI=y` in all four defconfigs means it
   would have reached P4's build. I fixed it in the same commit with `NULL` replaced by
   `&pdev->dev` (device available, kernel's own pattern) and a `Needs-review:` trailer.
   If the reviewer prefers `NULL` for arity-only minimalism, that is a one-line follow-up commit.
   `confidence: high` that it is a real break — the call passed a `const char *` into the
   `struct device *` parameter, and no commit in the series or the base ever touched that file.
2. **Item 6, fragment section 5 not applied.** §6c item 6's mechanical rule ("for each `CONFIG_X=y`
   or `# CONFIG_X is not set` line in the fragment") also matches section 5's two lines, because
   section 5 is written as comments. Applying `# CONFIG_DEBUG_INFO_BTF is not set` (fragment `:466`)
   would have switched off the `CONFIG_DEBUG_INFO_BTF=y` of section 1 (fragment `:123`), which is
   the opposite of what the fragment wants (its own escape hatch, only "if pahole cannot be
   installed on the build host at all"). Section 5's header settles it: "optional lines, left
   commented. Uncomment only if you hit the problem described. Do not uncomment them 'just in
   case'." So everything from the `SECTION 5` header (fragment `:454`) onwards was skipped and
   sections 1-4 applied. If the reviewer wants the mechanical reading instead, it is one more commit.
   `confidence: high` — the decision is quoted from the fragment itself.

## Notes for P4

- `~/work/out/.config` is left holding `gts4lvwifi_defconfig`; the other three were built in
  `/tmp/opencode/out-<defconfig>` and are disposable.
- `include/linux/cgroup_subsys.h:14-16` (`#if IS_ENABLED(CONFIG_CGROUP_SCHED)` → `SUBSYS(cpu)`)
  generates `cpu_cgrp_id`, and `CONFIG_CGROUP_SCHED` is now `=y`, so the `kernel/sched/core.c`
  `cpu_cgrp_id` errors the reviewer predicted should be gone. If they are not, P3's defconfig did
  not take: fix the defconfig, not the code. (`CONFIG_CGROUP_SCHED` itself is `init/Kconfig:1262`.)
- `task_util_est()` is still missing by design — §6c P4's 3-line WALT shim is still needed. It does
  not depend on any P3 item.
- The three K7 collisions are untouched: `TIF_UPROBE` = 5, `FAULT_FLAG_INTERRUPTIBLE` = `0x800`,
  `VM_FLUSH_RESET_PERMS` = `0x200`. I did not re-add the series' `0x100` and did not touch K7 at all.
- Local clone notes (not commits, no history touched): the kernel clone's push URL is now
  `git@github.com:anton-scholten/android_kernel_samsung_sdm670.git` (SSH, since no token was
  available and `git ls-remote`/`git push` authenticate as `anton-scholten`), and
  `remote.origin.fetch` gained `+refs/heads/port/pick:refs/remotes/origin/port/pick` because the
  clone is `--single-branch` and `git fetch origin` alone did not see `port/pick`. `port/pick` now
  tracks `origin/port/pick`, so plain `git push` and `git fetch` work for P4.
- One accident, repaired immediately and never pushed: the first `git checkout port/pick` failed
  ("pathspec did not match"), and because that command was in an `&&` chain piped through `tail`,
  the next command ran and fast-forwarded the **local** `lineage-23.2` branch to `d73f07cf8b5c`.
  I moved it back with `git branch -f lineage-23.2 a30605a54f3b` before making any commit. The
  remote `lineage-23.2` and `lineage-22.2` were never touched (verified with `git ls-remote` above).

## Self-check output

```
$ git -C ~/work/k670 log --oneline d73f07cf8b5c..origin/port/pick
316352012ff2 P3: merge the gts4lv-23.2 defconfig fragment into all four defconfigs
d26bd320c51d P3: F2: delete the second copy of the UFFDIO_COPY VM_MAYWRITE check
14bf14fcdd22 P3: F1: delete the duplicate picture-aspect-ratio block in drm_mode.h
d147e3464f7c P3: bring in fs/unicode and wire it into fs/Makefile and fs/Kconfig
d6239359349d P3: give the old-style wakeup_source_register() calls the new dev argument
81b964043704 P3: add arch/arm64/include/asm/set_memory.h

$ python3 scripts/check-pick.py ~/work/k670 ~/work/pick-review
picked clean: 2372
hand-resolved: 60 (full review: 23, spot-check pool: 37)
auto-merged but different: 6 (triage)
fix commits: 6
problems: 0
review packets: ~/work/pick-review

$ ls arch/arm64/include/asm/set_memory.h fs/unicode/Kconfig
arch/arm64/include/asm/set_memory.h
fs/unicode/Kconfig

$ git -C ~/work/k670 log -1 --format=%h lineage-23.2
a30605a54f3b

$ git -C ~/work/k670 ls-remote origin refs/heads/lineage-23.2 refs/heads/lineage-22.2
a30605a54f3b92627d868f169c72ef9c6ef82123	refs/heads/lineage-22.2
a30605a54f3b92627d868f169c72ef9c6ef82123	refs/heads/lineage-23.2

$ git -C ~/work/k670 status -sb
## port/pick...origin/port/pick          (no modified files)
```

## Problems

None blocking. The two deviations above are the only judgement calls; both are recorded in the
commits themselves (`Needs-review:` on `d6239359349dd167a09219f03361e881138e9fcf`, and the section 5
reasoning in the body of `316352012ff2b8687d797c63e769f0ec16f499ed`).