# Port status

Updated by the owner or the reviewing lead after each step, **not** by working agents. Steps and prompts: [RUNBOOK.md](../../RUNBOOK.md).

| Step | State | Branch / output | Notes |
|---|---|---|---|
| 0 Setup: tokens, branch protection, clones | ✅ | | No `fork-token` needed or stored — SSH already has write access to both forks (verified by dry-run push). Branch protection set up by the owner. |
| 1 Round 3: K7 | ✅ | `agent/K7` | 6 bit collisions found, 4 previously unknown. 367 headers swept. |
| 1 Round 3: K8 | ✅ | `agent/K8` | Proved both "unbriefed conflicts" apply **cleanly** — the trial was right. |
| 1 Round 3: R7 | ✅ | `agent/R7` | Check never runs: our API level is 28, it needs ≥29. |
| 1 Round 3: R8 | ✅ | `agent/R8` | RIL caps at radio 1.4. Level 6 is unreachable for LTE. |
| 1 Round 3: R9 | ✅ | `agent/R9` | soundtrigger + `per_proxy_helper` both no-ops. |
| 1 🔍 Round 3 review + merge | ✅ | `main` | Reviewed and merged 2026-10-04 ([review-P1.md](review-P1.md)). |
| 2 P1 cherry-pick | ✅ | kernel `port/pick` @ `d73f07cf8b5c`, `agent/P1` | **2,438 picks. `check-pick.py` → `problems: 0`.** 60 hand-resolved, 23 full-review + 37 spot. `lineage-23.2` untouched. 27 `Needs-review:`. |
| 3 🔍 P1-R | ✅ | [review-P1.md](review-P1.md) | Passed, no rejections. All 6 K7 collisions already resolved in `port/pick`. |
| 3 P2 automerge triage | ✅ | `agent/P2-1`, `agent/P2-2` | 6 packets: **4 BENIGN, 2 SUSPECT — both SUSPECTs are real defects**, now confirmed by the lead. |
| 3 🔍 P2-R | ✅ | [review-P1.md](review-P1.md) | F1, F2 confirmed → P3 items 4–5. F3 left as is. |
| 4 P3 known fixes + defconfig | ✅ | kernel `port/pick` @ `316352012ff2`, `agent/P3` @ `6eff7f0` | 6 commits, `problems: 0`, `fix commits: 6`. **Found a 6th `wakeup_source_register()` caller the spec missed** — flagged `Needs-review:`. |
| 4 🔍 P3-R | ✅ | [review-P4.md](review-P4.md) | Passed. Ruling: `&pdev->dev` at `msm_geni_serial.c:2793` is correct. |
| 5 P4 build loop | ✅ | kernel `port/pick` @ `801f3f20e54a`, `agent/P4` @ `89ef1fa` | **BOTH defconfigs link `Image.gz-dtb`.** 14 commits, all `Fix-by:`. `problems: 0`, `fix commits: 20`. Nothing escalated. |
| 5 🔍 P4-R | ✅ | [review-P4.md](review-P4.md) | Passed, all 14 commits accepted. **Reviewer rebuilt `port/pick` independently: `Image.gz-dtb`, 0 errors, key configs `=y`, vDSO offset sane.** |
| 6 P5 device-tree commits | ✅ | device `port/dt` @ `e3ccc923bcf2`, `agent/P5` @ `bfc078f` | 1 commit: 79 comma-lists → space-separated, 499 commas. `xmllint` clean. **Verified by reverse-transform, byte-identical.** `target-level` stays 5. |
| 6 🔍 P5-R | ✅ | [review-P4.md](review-P4.md) | Passed. sm7125-common 23.2 ships space-separated lists (0 comma lists). Check audio on first boot (HAL 6.0 vs sm7125's 7.0). |
| 7 Fast-forward both `lineage-23.2` | ✅ | | Done 2026-10-04 (plain fast-forward pushes): kernel `a30605a`→`801f3f20e54a`, device `2e50286`→`e3ccc923bcf2`. |
| 8a B1 ROM sync + first build | ✅ | `agent/B1`, `~/android/lineage` | Done. The host OOM was solved with a 32 GB swapfile. Tree synced (1,170 projects), verified: kernel `801f3f20e54a`, device `e3ccc92`. |
| 8b P6 ROM build-error loop | ✅ | device `port/dt-2` @ `d154fb4384fb`, `agent/P6` | 2 errors fixed (AntHalService, git-lfs), 1 escalated (`libwfdservice`). Zip `lineage-23.2-20261005-UNOFFICIAL-gts4lvwifi.zip`, sha256 `cc2c82e796e7fa3678bf8169f8c6ba7ffdedfe2e79e3e0b697b55790927a39ea`. |
| 8b 🔍 P6-R | ✅ | [review-P6.md](review-P6.md) | Passed. Device `lineage-23.2` fast-forwarded `e3ccc92`→`d154fb4384fb`. WFD: flash allowed, fix later as P8. |
| 8 ROM build | ✅ | zip on the removable drive | Built 2026-10-05. Use `brunch gts4lvwifi`, **not** a bare `m`. ⚠️ Built via `mka bacon -k 0`, not a clean `brunch`. |
| 8 Flash SM-T720 to 23.2 | ◐ | [`FLASH-BLOCKER.md`](FLASH-BLOCKER.md) | **23.2 recovery boots** (2026-10-06) with kernel `500658be3c16`; the fix was the SELinux avtab change. Kernel `lineage-23.2` fast-forwarded. Next: rebuild the zip, format data, sideload, first boot. |
| 9 B2 full ROM build + install + first boot | ◐ | [B2-HANDOFF.md](B2-HANDOFF.md), `agent/B2` | **Done 2026-10-07.** Release build + matching recovery flashed and running; device `lineage-23.2` @ `e38c0de`, vendor fork @ `bceca6f`. Next: owner testing, LTE build ([HANDOVER.md](../../HANDOVER.md)). |
| 8c P7 boot-log triage | ☐ | `agent/P7`, `boot-<n>.md` | Free agent collects and sorts logs per flash; strong model diagnoses. |
| 8 First boot | ☐ | | Collect logs after **every** crash — pstore keeps only the newest. |
| 8 Tests + 24 h soak | ☐ | | Then the LTE model. |
| 8 LTE build `brunch gts4lv` | ☐ | | After the Wi-Fi model boots. |
| 9 P8 restore WFD (screen casting) | ☐ | review-P6.md | Strong model / owner. Not blocking. |

States: ☐ not started · ◐ running · ✅ done · ⛔ blocked (say why in Notes).

## Review outcome, 2026-10-04

`review-P1.md`: **P1 passes with no rejections.** Four things changed the plan:
1. **All six K7 collisions are already resolved in `port/pick`.** TIF, FAULT_FLAG and `VM_FLUSH_RESET_PERMS`
   were done by P1; `VM_ARCH_2` is x86-only so moot on arm64; `KEY_HOT` and `SW_MACHINE_COVER` are absent and
   unreferenced. **P3 needs none of K7.**
2. **`wakeup_source_register()` has 5 old-style callers, not 1.**
3. **`process_mrelease` deferred, not ported.** AOSP lmkd probes for it and should fall back to a plain kill on
   `ENOSYS`, but this was **not verified against 23.2 lmkd**. Check `logcat -s lmkd` on first boot. The chain to
   pick later is in `dropped.tsv`: `2e700093ca33 → e987691659c0 → 030886f39a44 → e0c1326972d75 → 996b9f83a3fa`.
4. **`target-level` stays 5** for the first build (empty matrix on 23.2, so nothing can fail); P5 skips the bump.

## P3 outcome, 2026-10-04

Six commits, `port/pick` @ `316352012ff2`, `check-pick.py` → `problems: 0`, `fix commits: 6`, zero conflict markers.

| # | SHA | What |
|---|---|---|
| 1 | `81b964043704` | `arch/arm64/include/asm/set_memory.h` |
| 2 | `d6239359349d` | `wakeup_source_register()` dev argument — **also the 6th caller, below** |
| 3 | `d147e3464f7c` | `fs/unicode` + wiring in `fs/Makefile` and `fs/Kconfig` |
| 4 | `14bf14fcdd22` | F1 `drm_mode.h` |
| 5 | `d26bd320c51d` | F2 second `VM_MAYWRITE` block |
| 6 | `316352012ff2` | defconfig fragment × 4 |

**F1 came out right.** One `DRM_MODE_FLAG_PIC_AR_MASK`, at `(0x0F<<24)`; `_64_27`, `_256_135` and
`FLAG_PIC_AR_256_135` all still defined; **zero** occurrences of `0x0F<<19` left, so the bit-22 collision with
`DRM_MODE_FLAG_SUPPORTS_YUV420` is gone. F2: exactly one `VM_MAYWRITE` check. All four defconfigs give **7/7**.
35 of the fragment's 37 options reach `.config`; `SCHED_TUNE` and `CGROUP_SCHEDTUNE` cannot, because
`init/Kconfig:1536` is `depends on !UCLAMP_TASK` and `CONFIG_UCLAMP_TASK=y` — the fragment's own §4.3/4.4
prediction, not a failure.

### Two things P3 did that the spec did not authorise

1. **A 6th `wakeup_source_register()` caller, which the spec and `review-P1.md` both missed.**
   `drivers/tty/serial/msm_geni_serial.c:2793` called `wakeup_source_register(dev_name(&pdev->dev))`, putting a
   `const char *` where the new signature wants `struct device *`. Verified: `0c6f8a9a50ad` — the commit that
   changed the signature — touches **0** lines of that file, and the series has **0** commits touching it, so nothing
   anywhere fixed it. `CONFIG_SERIAL_MSM_GENI=y` in all four defconfigs, so this was a hard build error.
   P3 used `&pdev->dev`, following `wakeup.c:324` and `alarmtimer.c:1039`, and flagged it `Needs-review:`.
   **This is the one open question for P3-R.** `NULL` preserves the original name-only behaviour more faithfully;
   `&pdev->dev` ties the wakeup source to device suspend. Both defensible — do not "fix" it without a ruling.
2. **It skipped fragment section 5.** The spec's mechanical rule would have applied two `is not set` lines that are
   written as *comments*, cancelling section 1's `CONFIG_DEBUG_INFO_BTF=y` — the opposite of the fragment's intent.
   P3 applied sections 1–4 and stopped at the `SECTION 5` header (`fragment:454`).

### The accident, and the repair

P3's first `git checkout port/pick` failed on a single-branch clone; because it sat in an `&&` chain piped through
`tail`, the following `git merge --ff-only` ran anyway and fast-forwarded the **local** `lineage-23.2`. P3 caught it
and repaired with `git branch -f lineage-23.2 a30605a54f3b` before committing anything. **Verified:** remote
`lineage-22.2` and `lineage-23.2` are both still `a30605a54f3b`. The remote was never touched. This is the second
time in this project an `&&` chain swallowed a failure — prefer separate commands with explicit checks.

## P4 outcome, 2026-10-04 — the kernel builds

**Both target defconfigs link `Image.gz-dtb` from a clean output tree.**

| Target | Result | Size |
|---|---|---|
| `gts4lvwifi_defconfig` | `EXIT=0` | 18,735,923 B |
| `gts4lv_defconfig` | `EXIT=0` | 18,743,864 B |

All 20 warnings are `DWARF2 only supports one section per compilation unit` from hand-written `.S` files; the 22.2
baseline had exactly the same 20, so nothing new. `check-pick.py` → **`problems: 0`, `fix commits: 20`** (6 from P3
+ 14 from P4). `lineage-22.2` and `lineage-23.2` both still `a30605a54f3b`. **Nothing was escalated** — no error
needed a forbidden fix and no command failed twice. Every diff is 1–36 lines and surgical; **nothing disables or
deletes a check to silence an error.**

### The vdso is fine — checked, because it looked alarming

`include/generated/vdso-offsets.h` is 36 bytes and `vdso.so` only 3,576 B, which reads like a stub. It is not.
arm64's vdso needs exactly **one** offset — `#define vdso_offset_sigtramp 0x0810` — present and non-zero, with
`vdso.so.dbg` linked, exporting `__kernel_clock_gettime`, `__kernel_gettimeofday`, `__kernel_clock_getres`,
`__kernel_time` and `__kernel_rt_sigreturn` under SONAME `linux-vdso.so.1`. The large `__vdso_*` offset table is an
x86 thing. (Binaries live in `arch/arm64/kernel/vdso/`, not `arch/arm64/boot/`.)

### The `BPF_ARCH_SPINLOCK` fix is correct — verified, because it looked wrong

`5078de1ee272` adds one line, `select BPF_ARCH_SPINLOCK`, under `config SMP` in `arch/arm64/Kconfig`, and P4 wanted
a ruling on it. It is correct: the symbol is defined in `kernel/Kconfig.locks:245` (not `kernel/bpf/Kconfig`, which
is where one looks first), it evaluates to `CONFIG_BPF_ARCH_SPINLOCK=y` in both built configs, and that makes
`kernel/bpf/helpers.c:652` take the `arch_spinlock_t` branch — so the broken `atomic_cond_read_relaxed(l, !VAL)` at
`:678` sits in the `#else` and is **no longer compiled**. Note it is *not* a restoration: neither the base nor the
series head had that select on arm64; P4 added it, matching mainline arm64.

The other reviewer-specified fix, the `task_util_est()` → WALT `task_util()` shim (`1cb9785b0d64`), is a 6-line
inline calling `task_util(p)`, and correctly does **not** port upstream's PELT util_est.

## ⚠ The build needs `~/work/llvmbin` on `PATH`

Debian's `llvm-19` ships only versioned names (`llvm-nm-19`) but `LLVM=1` looks for unversioned ones. P4 made
persistent symlinks in `~/work/llvmbin`. **Nothing in the repo, the kernel tree or `kbuild.sh` was
changed** — all verified clean.

Without that directory on `PATH`, `vdso.so.dbg` does not link and `vdso_offset_sigtramp` comes out **wrong**: a
silently broken sigreturn trampoline, **not a build failure**. The build succeeds and ships a bad kernel. This will
bite anyone who rebuilds here, so it is recorded in
[LEAD-SYNTHESIS.md §10](../../LEAD-SYNTHESIS.md#10-environment-and-reproduction) too.

## P5 outcome, 2026-10-04

`port/dt` @ `e3ccc923bcf2`, one commit, one file: `audio/configs/audio_policy_configuration.xml`, the only
`audio_policy*.xml` in the tree (`audio_platform_info.xml` and `audio_platform_info_diff.xml` are `audio_platform*`
and out of scope). 79 lines / 499 commas converted inside `samplingRates`, `channelMasks` and `formats`; the
comma-separated `sources=` route attributes and the licence comments keep theirs (84 commas before and after).
`xmllint --noout` clean. `lineage-23.2` untouched at `2e50286`.

**Verified by reversing the transform** on the new file: it reproduces `lineage-23.2`'s copy **byte for byte**, all
110 attributes have identical token lists, no token lost. That is what distinguishes this from a blind
`sed 's/,/ /g'`, which would have destroyed the `sources=` attributes and which the diffstat alone would not reveal.

Two guards: `sepolicy/vendor/per_proxy_helper.te` exists (8 lines) but **0** binaries named `per_proxy_helper` exist
anywhere, so the domain is provably dead (R9) — left in place, harmless. And nothing may raise
`PRODUCT_SHIPPING_API_LEVEL` above **28**; `gts4lv.mk:18` inherits `$(SRC_TARGET_DIR)/product/product_launched_with_p.mk`,
but that file is **outside this repo**, so the value is a build-system fact to re-check, not a tree fact.

R6's *mechanism* — that the parser splits these attributes on whitespace — is **unverified**; `frameworks/av` is not
cloned. P5 rated the space-separated form high confidence and the mechanism medium, which is the right split and the
only thing P5-R needs to check.

## Decisions (all settled 2026-10-04, [review-P4.md](review-P4.md))

| Question | Decision |
|---|---|
| `&pdev->dev` vs `NULL` at `msm_geni_serial.c:2793` | `&pdev->dev` (registered probe device; upstream style) |
| 4.11 `vfs_getattr()` backport vs 4.9 two-argument form | Keep the 4.9 form (only the statx mask is lost) |
| Fuse `pid_ns` backport | Not needed; the one-argument `fuse_req_init_context()` is fine |
| Tracepoints widened 12→18 args | Accept (generic, backward-compatible) |
| Inert DRM `IN_FORMATS` blob | Keep (harmless) |
| `target-level` 5 → 6 | Stay at 5 for the first build; revisit after boot |
| `process_mrelease` | Deferred; check `logcat -s lmkd` at first boot |

## Three confirmed defects in `port/pick` (F1 and F2 fixed by P3 on 2026-10-04; F3 left)

Found by P2 (2 of 3) plus an ad-hoc sweep of all 2,438 picks (1 of 3). Full detail, with verified line numbers
and the counterintuitive fix for F1, in [`duplicate-picks.md`](duplicate-picks.md).

| | file | what | now | fix |
|---|---|---|---|---|
| **F1** | `include/uapi/drm/drm_mode.h` | 7 macros duplicated; pick's copy at **92–104** (`0x0F<<19`) vs base's at 106–124 (`0x0F<<24`) | benign — later wins — but the `<<19` copy is the only thing preventing a **bit-22 collision** with `SUPPORTS_YUV420` at line 90 | delete **92–104**. Deleting 106–124 drops `_64_27`/`_256_135` *and* causes the collision. |
| **F2** | `fs/userfaultfd.c` | 11-line `VM_MAYWRITE` check duplicated at `:1401` and `:1427` | benign, idempotent — dead code | delete `:1391–1403` |
| **F3** | `arch/parisc/include/uapi/asm/socket.h` | `SO_PEERGROUPS` at `:98` and `:100` — the series carries the same upstream patch twice, under two SHAs | benign — legal C, and parisc isn't built for arm64 | cosmetic; P1-R's call |

**Two root-cause classes:** (A) the change was already in the sdm670 base and the pick landed a duplicate
anyway — F1, F2; (B) the series carries one upstream patch under two SHAs so the second pick is a pure
duplicate — F3. Neither is visible to `check-pick.py`'s `clean` bucket, which gets no human review.

**What bounds the risk:** 2 of the 3 were found in P2's 6-packet `automerge` bucket. Sweeping the
**2,372-commit `clean` bucket that nobody ever reviewed turned up exactly one finding**, and it is in unbuilt
`arch/parisc` and is legal C. The unreviewed bucket is in better shape than the `ec3b287a8a17` anecdote
suggested. This should inform how much of the 37-commit spot-check pool really needs reading.

## ROM built 2026-10-05 — and one latent defect to decide on

```
~/android/lineage/out/target/product/gts4lvwifi/lineage-23.2-20261005-UNOFFICIAL-gts4lvwifi.zip
1,133,973,020 bytes
sha256  cc2c82e796e7fa3678bf8169f8c6ba7ffdedfe2e79e3e0b697b55790927a39ea
```

All of `out/` (119 GB including this zip) is on the **removable drive** — a single bind mount of `/dev/sda[/out]`
with no nested mounts. `out.old` was deleted on 2026-10-09, when the whole tree moved to the drive (HANDOVER.md, "Build machine layout").

⚠️ **The zip came from `mka bacon -k 0`, not a clean `brunch`.** Ninja packaged past a failure and then exited 1.
Contents are complete and it should flash, but it is not a from-scratch verified artifact. `confidence: medium`.

**Two errors fixed, and neither needed a code change:**

1. `AntHalService` — a dangling `PRODUCT_PACKAGES` entry, `d154fb4` on `port/dt-2`. See [P6-log.md](P6-log.md).
2. `webview.apk` was a **134-byte git-lfs pointer file**, so `aapt2` could not read it. `git-lfs` had been
   installed at 10:35:20, **three minutes after** the tree was checked out at 10:32:32 — the sync predated the
   package install. Fixed with `git lfs pull`. No commit.

**The error I sent P6 after was a red herring.** I briefed it that `Disallowed PATH tool
"arm-linux-gnueabi-ld.bfd"` was the blocker. P6 reproduced it, found it **non-fatal**, and went on to the real first
error. The vDSO was in fact linked by the in-tree `ld.lld` by absolute path and `.path_interposer` was never the
linker. P6 also **declined** the fix I had suggested — pointing `CROSS_COMPILE_ARM32` at the host
`/usr/bin/arm-linux-gnueabi-ld.bfd` — because it would make the ROM non-hermetic and is not reachable from the
device tree. That was the right call and it contradicted me.

### The latent defect — P6 escalated rather than fixed

`libwfdservice` (32-bit) will fail to load at runtime. AOSP `709977845deb` added a 4th parameter
(`bool deviceSwitch`) to `AudioSystem::setDeviceConnectionState`; the 2019-era 32-bit blob calls the 3-argument
version. Proven from the shipped image: **3-arg call sites = 0, 4-arg = 1**. CFI was ruled out by direct test.

**Latent, not certain:** nothing in the tree sets `vendor.wfdservice=enable`, so it stays `disabled`. WFD is
Wi-Fi Display (screen mirroring) — non-essential.

P6 did not fix it because every option is destructive or out of scope: `allow_undefined_symbols` converts a build
error into a **boot-time `dlopen` failure** (the blob is `BIND_NOW`); dropping it removes WFD; the real fix is
extending `hardware/lineage/compat/libwfdservice/`, which is not P6's write scope. LineageOS already did exactly
this for a *different* symbol in `8a4285c0377`, so a known path exists. `confidence: high` on the diagnosis.

### Read this before approving any future ROM fix

**A green build does not prove a fix is correct** — and when the error is a *guard* rather than a missing symbol, the
cheapest green build is usually the guard being removed rather than the problem solved. Five concrete review
questions are in [P6-log.md](P6-log.md).

## Flashing blocker, 2026-10-06 — needs a strong model

The 23.2 recovery is not taking on the SM-T720. Samloader **detects** the tablet and the flash returns **`exit=0`**,
yet `adb reboot recovery` still boots the **22.2** recovery.

Ruled out already: the image is not the problem. `~/work/recovery.img` is 64.0 MB, a valid `Android bootimg`, and its
sha256 `fa7c34fe…090b1b` **matches the copy inside the zip exactly**; the codename is right for SM-T720. `vbmeta` does
not need reflashing either — that step belongs to the bootloader unlock already completed when 22.2 was installed.

Leading hypothesis is **A/B slots**: the write succeeds but lands on the slot the bootloader is not booting from.
One command tests it — `adb shell getprop ro.boot.slot_suffix`.

Full evidence, four ranked hypotheses, the five missing commands, and a sideload route that avoids the problem
entirely are in [FLASH-BLOCKER.md](FLASH-BLOCKER.md). **Nothing has been guessed at and no firmware operation has been
attempted**; the partition name and slot mechanism should be confirmed, not inferred.

## Open items carried into the next step

**P1 escalated three things (decided 2026-10-04 in [review-P1.md](review-P1.md)):**

1. **`process_mrelease` is missing** — its three introducing commits were silently removed by
   `classify.py:35`'s `EAS` regex matching inside `proc-EAS-s`/`rel-EAS-e`. Same defect class as the fuse-bpf
   pair, but larger. P1 could not verify the userspace fallback, so it escalated rather than decided. Porting
   it to 4.9 is expensive (no `mmap_lock` API; `rw_semaphore mmap_sem`).
   **Decided: defer.** lmkd should fall back without it; check `logcat -s lmkd` on first boot. The chain to pick later is in review-P1.md.
2. **Three confirmed duplicate-landing picks** (F1/F2/F3 above). F1 and F2 are one-block deletions; F1's
   target lines are load-bearing, so read [`duplicate-picks.md`](duplicate-picks.md) before touching it.
3. **Expect a whitespace-heavy diff at `1c225cfcb958`.** P1 introduced a `get_scan_count` tab drift, pinned
   it by tab-counting every commit touching `mm/vmscan.c` since the last push, and fixed it in the next
   commit because a rebase was forbidden. `git diff -w` there shows only the intended comment swap — but a
   reviewer skimming that commit will see noise.

**Two known landmines, deliberately not fixed:**

- **`classify.py` is unfixed on purpose.** Regenerating `conflict_detail.tsv` would change which *remaining*
  commits `pick-series.sh` skips, so it has to be fixed as one unit with a decision, not piecemeal.
- **A clean cherry-pick is not evidence of correctness.** P1 found `ec3b287a8a17` apply cleanly and silently
  duplicate `bpf_probe_read_str` because sdm670 already had it (it healed at `dddb8c0eafe8`). `check-pick.py`'s
  *clean* bucket gets no human review — which is why `pick-review/full/` and `spot/` exist.

**Round-3 agents corrected three round-2 conclusions** (the `target-level` decision, the soundtrigger block,
the radio bump). When a round-3 agent contradicts a round-2 verdict on this device, check it against a
shipping tree before acting on either. Details in [LEAD-SYNTHESIS.md §7.4](../../LEAD-SYNTHESIS.md).
