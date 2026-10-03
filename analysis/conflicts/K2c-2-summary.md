<!-- task: K2c-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# K2c-2: conflict briefs for the `optional` / `trivial` conflict batch

## Summary

9 briefs written for the 9 rows of `analysis/agent-batches/K2c-2.tsv`, plus this summary.
**All 9 commits are `group = optional` in `analysis/exyhyperbrick-trial/conflict_detail.tsv`** — "nice to have
(power, memory)", **not** needed for eBPF or boot. No commit in this batch is a BPF, verifier or boot-path commit,
so nothing here blocks the port; the whole batch could in principle be dropped. Each brief therefore states
explicitly what a DROP would lose, so that decision is made knowingly rather than by default.

Verdicts: **0 DROP, 2 PREREQ, 7 MERGE, 0 HUMAN.** Nothing came out HUMAN, so the "stop and ask" trigger did
not fire. No `git show <sha>` failed — all 9 SHAs are valid series commits.

Two systematic findings the lead should look at first:

1. **The trial's `conflicting_files` / `blocks` columns understate the real work**, because the trial replayed the
   series *stacked on itself* (`analysis/exyhyperbrick-trial/trial.py`). Where I ran
   `merge-tree --merge-tree-base=C^ a30605a54f3b C` (the "cold" case the task specifies), merge-tree reported
   **more** conflicts than the batch file for 4 of 9 commits:

   | commit | batch file says | merge-tree says |
   |---|---|---|
   | `2ece0aa41dee` | `include/linux/sched/sysctl.h` | + `include/linux/sched.h` (2), `kernel/sched/core.c` |
   | `01abe0bedc2d` | `kernel/sched/cpufreq_schedutil.c` | + `kernel/sched/sched.h` |
   | `70b95802146b` | `kernel/sched/cpufreq_schedutil.c` | + `kernel/sched/sched.h` |
   | `45170da68469` | `kernel/sched/cpufreq_schedutil.c` | + `kernel/sched/core.c` (2), `kernel/sched/sched.h` (2) |
   | `138179e5ccba` | `mm/internal.h mm/madvise.c` | + 4 × `uapi/*/mman.h` (see brief; these disappear if `7b1c5c0a4417` is applied first) |

   In all four uclamp cases the extra blocks are **pure insertions** ("ours" is empty), so the extra files cost
   nothing — but the effort estimate for this batch is wrong if taken from the batch file alone.

2. **`47d10743ccd7a55cf12741be471933e518ef57b1` ("BACKPORT: mm: introduce MADV_PAGEOUT") is recorded `CLEAN` in
   `results.tsv` but actually conflicts in 6 files** when applied standalone to `a30605a54f3b`
   (verified: `merge-tree --write-tree --merge-base=47d10743ccd7^ a30605a54f3b 47d10743ccd7` → tree
   `e2dc184b3cd08`, exit 1). It is a **mandatory prerequisite for `e7751e04e9d1`**, and **no brief was assigned
   for it** (it is not in `conflict_detail.tsv`, so no batch contains it). The human must expect an unplanned
   conflict there. Same caveat applies in principle to every other trial-`CLEAN` commit that follows a conflict.

Cross-commit dependencies inside this batch (apply in series order, do not reorder):

| earlier | later | why |
|---|---|---|
| `f0f30b4639c2` | `9114ddb3b20f` | `vma_can_userfault()` is built on `is_vm_hugetlb_page()`, which only `f0f30b4639c2` introduces |
| `f0f30b4639c2`, `9114ddb3b20f` | `b07d07e8f011` | its conflict block is `BUG_ON(!vma_can_userfault(vma))` |
| `138179e5ccba` | `e7751e04e9d1` | needs `can_madv_lru_vma()` (the rename 138179e5ccba introduces) |
| `74b2f258866b` (other batch), `c86bfd9a4ae3`, `64895384e5f0` | `2ece0aa41dee` | `CONFIG_UCLAMP_TASK`, `struct uclamp_se`, `bits_per()` |
| `2ece0aa41dee`, `29c3a0630917`, `01abe0bedc2d` | `70b95802146b` | the name `uclamp_util_with()` must exist to be renamed |
| `70b95802146b` | `45170da68469` | `uclamp_rq_util_with()` must exist to be gated by the static key |

The four uclamp commits must be **accepted or dropped as a group** (2ece0aa41dee, 01abe0bedc2d, 70b95802146b,
45170da68469). Dropping some but not others leaves an expensive uclamp fast path with none of the benefit — see
the value note in `45170da68469.md`. `74b2f258866b` ("Add CPU's clamp buckets refcounting") is the first uclamp
commit, is a trial CONFLICT, and is in another batch; it is the hard prerequisite for all four.

One correction to a likely assumption: **none of these 9 commits is a DROP candidate on grounds of
"already in sdm670"**, and I am not proposing one. Every step-4 check found the change absent. The closest thing
to a duplicate is in `138179e5ccba`: sdm670 already has the helper `can_madv_dontneed_vma()` with a
byte-identical body (`mm/internal.h:66-68` @ a30605a54f3b), so that commit is partly a rename of code we have.
sdm670 also already carries upstream `29ec90660d68`'s `VM_MAYWRITE` check, which the series base lacks and which
`sdm670`-side code must keep (see `f0f30b4639c2.md` and `b07d07e8f011.md`).

## Batch table

| commit | subject | resolution | confidence |
|---|---|---|---|
| `f0f30b4639c2` | UPSTREAM: hugetlb: allow registration of ranges containing huge pages | MERGE | high |
| `9114ddb3b20f` | UPSTREAM: userfaultfd: introduce vma_can_userfault | PREREQ (f0f30b4639c2) | high |
| `b07d07e8f011` | UPSTREAM: userfaultfd: check registration before VM_MAYWRITE | MERGE | high |
| `138179e5ccba` | BACKPORT: mm: introduce MADV_COLD | MERGE | medium |
| `e7751e04e9d1` | BACKPORT: mm: factor out common parts between MADV_COLD and MADV_PAGEOUT | PREREQ (47d10743ccd7) | medium |
| `2ece0aa41dee` | BACKPORT: sched/uclamp: Add system default clamps | MERGE | high |
| `01abe0bedc2d` | BACKPORT: sched/uclamp: Remove uclamp_util() | MERGE | medium |
| `70b95802146b` | BACKPORT: sched/uclamp: Rename uclamp_util_with() into uclamp_rq_util_with() | MERGE | medium |
| `45170da68469` | BACKPORT: sched/uclamp: Protect uclamp fast path code with static key | MERGE | medium |

## Method / verification notes

- Kernel tree used read-only at `~/work/k670`; verified `a30605a54f3b` (sdm670 tip),
  `d54533f1546b` (series base), `baa585f67e0e` (series head). No ref was created, moved or deleted.
- Upstream SHAs were read from each commit message with the K1 patterns (`Upstream-commit:`, `[ Upstream commit ]`,
  `commit <sha> upstream`, `(cherry picked from commit …)`), taking the first match; `Change-Id:` was ignored.
  K1's `analysis/upstream-map/upstream-map.tsv` did not exist when I ran, so I did my own extraction.
- Step 4 ("does sdm670 already have it?") was done for every commit with `git grep` on `a30605a54f3b` using at
  least two distinctive added lines, plus a `git log --grep=<subject> -F` check and an upstream-SHA check against
  sdm670's history. Every brief lists the exact patterns searched.
- The shared kernel repo was used exactly as instructed: `git -C … show|log|grep|merge-tree|cat-file` only.

## Problems
None. No command failed twice; the only command that needed a retry was a `cat-file` with a truncated tree
SHA, corrected by re-running with the full 40-char SHA.
