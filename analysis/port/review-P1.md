<!-- review: P1-R + P2-R + round-3 review | reviewer: strong model (Claude) | date: 2026-10-04 -->
# Review of round 3, P1 and P2

**Verdict: P1 passes with no rejections, P2 is confirmed, and round 3 is accepted.** P3 can start.
Kernel `port/pick` @ `d73f07cf8b5c` (2,438 picks on top of `a30605a54f3b`). `lineage-23.2` is untouched.

## What was checked
| Check | Result |
|---|---|
| `scripts/check-pick.py` on `port/pick` with P1's `dropped.tsv` | 2,372 clean, 60 hand-resolved (23 full + 37 spot), 6 auto-merged-but-different, **problems: 0** |
| Full-review packets | Read the trailers of all 23 and all 69 `Needs-review:` commits. Verified against the tree: TIF bits, FAULT_FLAG, the `get_scan_count` result, the `oom_kill` rename, fuse `passthrough.o` |
| Spot pool (37) | Random 8 read. 6 match their briefs directly. 2 looked large and were checked: `3d3946a898f4` is the planned partial DROP; `6ee017762dda` replaced sdm670's `refcount.h`, but the result is identical to the series head and no symbol was lost |
| P2 SUSPECTs (F1, F2) and the lead's F3 | All three confirmed in the tree (line numbers below) |
| Round 3 (K7, K8, R7, R8, R9) | Format checker OK. Key claims re-checked: `product_launched_with_p.mk` at `gts4lv.mk:18` (R7); sm7125-common at `target-level="6"` with soundtrigger 2.2 (R9); the K7 rows in the current tree |

Verified facts:
- `TIF_UPROBE` is 5 and free, and `_TIF_WORK_MASK` has both `_TIF_FSCHECK` and `_TIF_UPROBE` (`arch/arm64/include/asm/thread_info.h:86`).
- `FAULT_FLAG_INTERRUPTIBLE` is `0x800`, free next to `SPECULATIVE 0x200` and `PREFAULT_OLD 0x400` (`include/linux/mm.h:325-329`).
- `get_scan_count` equals the series head except the Exynos-only `need_memory_boosting` block, which is correctly absent.

## Findings that change the plan
1. **All six K7 collisions are already resolved in `port/pick`.**
   - TIF (row 1) and FAULT_FLAG (row 2): done by P1.
   - `VM_FLUSH_RESET_PERMS` (row 4) is at `0x200`: done by P1. Don't re-add the series' `0x100`.
   - `VM_ARCH_2` (row 3) no longer exists as a definition (`VM_MPX` is x86-only), so there's no collision on arm64.
   - `KEY_HOT` and `SW_MACHINE_COVER` (rows 5–6) aren't in the tree and nothing references them.
   **P3 needs none of K7.**
2. **`wakeup_source_register()` has 5 old-style callers, not 1:** `drivers/char/diag/diagchar_core.c:4148`, `drivers/power/supply/qcom/battery.c:1605`,
   `drivers/power/supply/qcom/smb1390-charger.c:779`, `drivers/power/supply/qcom/step-chg-jeita.c:755`, `net/ipc_router/ipc_router_core.c:1384`.
3. **Duplicates to delete** ([duplicate-picks.md](duplicate-picks.md)):
   - **F1** `include/uapi/drm/drm_mode.h`: remove the pick's copy at lines 92–104 (`<<19`). Keep 106–124.
   - **F2** `fs/userfaultfd.c`: remove the first of the two identical `VM_MAYWRITE` blocks (`:1391-1403`).
   - **F3** (parisc) stays: identical value, not built.
4. **`set_memory.h` and `fs/unicode` are still missing**, as expected: `arch/arm64/Kconfig:43` selects `ARCH_HAS_SET_MEMORY`, and nothing wires `fs/unicode` into `fs/Makefile` or `fs/Kconfig`.
5. **The two symbols P1 left undefined** (commit `d217c733a`):
   - `cpu_cgrp_id` isn't really missing. `include/linux/cgroup_subsys.h:15-16` generates it when `CONFIG_CGROUP_SCHED` is on, which P3's defconfig does.
   - `task_util_est()`: decided. Map it onto sdm670's WALT `task_util()` with a 3-line inline (AGENT-TASKS §6c P4), instead of porting upstream's
     PELT util_est (`d272fed29eea`), which would fight sdm670's WALT scheduler.
   - `restore_pcpu_tick()` is no longer referenced, so it needs nothing.

## Decisions (reviewer; the owner can overrule)
| Question | Decision | Why |
|---|---|---|
| KNOX NPA socket options (refused 4×), `CONFIG_NETPM` (5×), `BINDER_SET_SYSTEM_SERVER_PID` (3×) | **Keep refusing** | 0 occurrences in sdm670; Samsung/Exynos-only features with no driver here. Refusing KNOX NPA also removed the `ANDROID_VERSION` build error (K4b): 0 hits in `port/pick` |
| fuse-bpf pair picked despite the `skip` group | **Accept** | The group came from a `classify.py` regex bug (`EAS` inside `rel-EAS-e`). `CONFIG_FUSE_BPF` needs them |
| `process_mrelease` (3 commits wrongly skipped by the same bug) | **Defer; not needed for boot** | AOSP lmkd probes for `process_mrelease` and should fall back to a plain kill on `ENOSYS`. Not verified against 23.2 lmkd: check `logcat -s lmkd` on first boot. P1's `dropped.tsv` rows `030886f39a44`/`e0c1326972d75` hold the chain to pick later (`2e700093ca33 → e987691659c0 → 030886f39a44 → e0c1326972d75 → 996b9f83a3fa`) |
| `classify.py` regex bug | **Document, don't regenerate** | P1 is complete, so no more picks depend on it. The affected commits are recorded in `dropped.tsv` |
| `target-level` | **Stay at 5 for the first build** | Level 5 has an empty matrix on 23.2, so nothing can fail. Level 6 is unreachable for LTE (radio 1.4) and is shared by both models. Revisit after first boot. P5 skips the bump |
| soundtrigger block, `per_proxy_helper`, vendor property names | **No change** (R7, R9) | |
| F3 parisc duplicate | **Leave** | Legal C, not built |

## For the record
P1's work quality was high: every non-trivial resolution carries a reasoned trailer, it caught and fixed its own indentation drift
without rewriting history, and it overrode three wrong brief claims with evidence. The free model is doing this job well.
