<!-- task: K2d-3 | agent: opencode space-bunny-free | date: 2026-10-03 -->
# K2d-3: conflict briefs, batch K2d-3 (optional group, moderate + modify/delete)
## Summary
All 7 commits in `analysis/agent-batches/K2d-3.tsv` have a brief in `analysis/conflicts/`.
Resolutions: 6 MERGE, 1 DROP, 0 PREREQ, 0 HUMAN; confidence 1 high, 6 medium, 0 low.
**1 of the 7 is modify/delete**: `3d3946a898f4` (conflicted file `kernel/sched/ems/energy.c`).
It is the one place where git's default resolution would have *added* Exynos-only code to the
Qualcomm tree, so it is the item in this batch most likely to cause damage if replayed mechanically.

Method note: for every commit I ran the isolated `git merge-tree` **and** a stacked replay that
reproduces `analysis/exyhyperbrick-trial/trial.py` (same `merge-tree --write-tree
--merge-base=<c>^ <accumulated> <c>` chain, restricted to the paths each commit touches, so it stays
read-only apart from loose objects). The replay reproduced `conflict_detail.tsv`'s file and block
counts **exactly** for all 7 commits, so the "stacked" measurements in the briefs are the trustworthy
ones. Where the two disagree I said so:
- `10a07035a7e7`: isolated over-reports 4 files / 11 blocks, trial (and my replay) has 2 files / 3 blocks
  (`include/uapi/linux/userfaultfd.h` and `mm/hugetlb.c` are artifacts of earlier series commits
  `8c554e9b6054`/`8a9ebf480d46` and `0409ccca4d11`).
- `813a92f62045`: isolated over-reports `kernel/sched/core.c`; only `kernel/sched/features.h` really
  conflicts.

Two findings the lead should look at first, both of which silently lose or break code if missed:
1. **`f75397804369` is a bit collision, not a text overlap.** The series wants
   `FAULT_FLAG_INTERRUPTIBLE 0x200`; sdm670 already uses `0x200` for `FAULT_FLAG_SPECULATIVE`
   (a30605a54f3b:include/linux/mm.h:293) and `0x400` for `FAULT_FLAG_PREFAULT_OLD` (:294). A naive
   "keep both" merge fuses the two flags and breaks sdm670's speculative page fault path
   (mm/memory.c:2046,2992,3781,3832). Use `0x800`.
2. **Both binder ioctl commits define nr 14 twice** (`BINDER_FREEZE` and `BINDER_SET_SYSTEM_SERVER_PID`).
   Harmless only because `_IOW` encodes the argument size (0x400C620E vs 0x4004620E), but see the
   caveat in those briefs.

The `optional` group label for this batch is misleading. `analysis/exyhyperbrick-trial/classify.py:15`
has no `binder`, `sched`, `uclamp`, `userfaultfd` or `energy` keyword, so two ioctl commits that
Android 16 may well need (`BINDER_FREEZE`, `BINDER_GET_FROZEN_INFO`) and two scheduler commits landed
here. I did not treat any of them as disposable, and I marked no DROP that loses a desirable tweak -
the single DROP (`3d3946a898f4`) drops a file sdm670 never had, so it loses nothing.

| commit | subject | resolution | confidence |
|---|---|---|---|
| `10a07035a7e7` | BACKPORT: userfaultfd: add minor fault registration mode | MERGE | medium |
| `f75397804369` | BACKPORT: mm: introduce FAULT_FLAG_INTERRUPTIBLE | MERGE | medium |
| `ee8a477b712d` | BACKPORT: binder: BINDER_FREEZE ioctl | MERGE | medium |
| `e5dba8a19d08` | BACKPORT: binder: BINDER_GET_FROZEN_INFO ioctl | MERGE | medium |
| `a2d0003b101b` | BACKPORT: sched/cpufreq, sched/uclamp: Add clamps for FAIR and RT tasks | MERGE | medium |
| `3d3946a898f4` | BACKPORT: sched/uclamp: Add uclamp support to energy_compute() | DROP | high |
| `813a92f62045` | ANDROID: Re-use SUGOV_RT_MAX_FREQ to control uclamp rt behavior | MERGE | medium |

Cross-cutting caveats that apply to more than one brief and that I could not settle from the kernel
tree: (a) sdm670 has no `CONFIG_UCLAMP_TASK` at all, so the three uclamp briefs are code-correct but
functionally inert until K6 turns it on; (b) sdm670 has neither `kernel/sched/ems/` nor
`include/linux/ems.h`, so any series commit that pulls an `exynos_*` call into a shared file will not
build; (c) four upstream SHAs come from K1's index rather than from a trailer in the commit message and
should be confirmed before the branch is published.

Self-check: `bash scripts/check-agent-output.sh K2d-3` passes; `grep -L 'Confidence'
analysis/conflicts/{10a07035a7e7,f75397804369,ee8a477b712d,e5dba8a19d08,a2d0003b101b,3d3946a898f4,813a92f62045,K2d-3-summary}.md`
lists no file.
## Problems
1. Two rounds of unresolved conflict markers left by *earlier* series commits sit in the middle of
   `10a07035a7e7`'s conflict region: `fad9a6a81aa6`, `f0f30b4639c2`, `9114ddb3b20f`, `d5f2acfd8dc2` and
   `b07d07e8f011` all CONFLICTed in `fs/userfaultfd.c` and were committed with markers by the trial
   (see `analysis/exyhyperbrick-trial/results.tsv`). The `vma_is_anonymous` -> `vma_can_userfault`
   chain has to be resolved as one unit across those five commits plus `10a07035a7e7`; they belong to
   another batch's briefs, so this is a coordination point, not something I could fix here.
2. I could not verify from this machine whether Android 16's libbinder calls `BINDER_FREEZE` /
   `BINDER_GET_FROZEN_INFO`, or whether Android 16 writes `cpu.uclamp_min`. The AOSP trees available
   locally (`LineageOS/android_system_core` at ~/work/clone-R7/core) do not contain libbinder
   (it is in `frameworks/native`) nor the cgroup uclamp writer (libprocessgroup). Suggested checks are
   named in the individual briefs.
3. Upstream SHAs for `ee8a477b712d`, `e5dba8a19d08`, `a2d0003b101b`, `3d3946a898f4` and `813a92f62045`
   are taken from K1's `upstream-map.tsv` (branch `agent/K1`, fetched read-only) because those commit
   messages carry no `Upstream-commit:` trailer. The three binder/scheduler/binder SHAs in particular
   deserve a manual check.