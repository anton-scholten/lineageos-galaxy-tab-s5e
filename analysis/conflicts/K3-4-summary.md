<!-- task: K3-4 | agent: Space Bunny Free | date: 2026-10-03 -->
# K3-4: large-conflict briefs, batch K3-4 (facts only)

## Summary
Three `large` conflict briefs, all in group `required`, produced as facts only. **No resolution is proposed
anywhere in these files** - no `DROP` / `MERGE` / `PREREQ` / `HUMAN` verdict appears in any of them; each brief has a
`## Notes for the lead` section instead, capped at 10 lines of observations.

| commit | subject | conflicting files | blocks examined | later commits on those files | confidence |
|---|---|---|---|---|---|
| `40a60987a65a` | BACKPORT: net: Expose socket option helpers to BPF | 1 (`net/core/sock.c`) | 1 (ours 8 / theirs 88) | 0 | high (facts), medium (why the hunk is un-anchorable) |
| `c8b2d2af17be` | ANDROID: refcount: Fix linkage of out-of-line helpers | 1 (`include/linux/refcount.h`) | 4 (ours 60 / theirs 8) | 0 | high |
| `74b2f258866b` | BACKPORT: sched/uclamp: Add CPU's clamp buckets refcounting | 2 (`init/Kconfig`, `kernel/sched/core.c`) | 4 (ours 0 / theirs 100) | 2 and 36 | high |

Method: `git -C ~/work/k670 show --stat`, `merge-tree --write-tree --merge-base=C^ a30605a54f3b C`,
`git cat-file -p <tree>:<path>` for every conflict block, `git grep -n <line> a30605a54f3b -- <file>` for presence
checks, and `git log --oneline C..baa585f67e0e -- <file> | head -30` for churn. The shared kernel repo was only read.

### Facts the lead should look at first
1. **`c8b2d2af17be` depends on an earlier conflict.** Its 4 blocks turn four `static inline` bodies into `extern`
   declarations. sdm670 has no `lib/refcount.c` and its `lib/Makefile` builds no `refcount.o`; those come from
   `e9c1bdddb9a0` (series position 450, *before* this commit at 2442), which is itself `CONFLICT` in the trial on
   `kernel/panic.c`. Ordering decides whether `extern` resolves at link time.
2. **`74b2f258866b` has the largest churn in the batch.** 36 later series commits touch `kernel/sched/core.c` and 2
   touch `init/Kconfig`; 2 of the `core.c` ones are themselves trial `CONFLICT`s and 1 is `SKIPDEV`.
3. **`74b2f258866b`'s theirs side references Exynos-only symbols.** `update_cpu_active_ratio()` and `init_ems()` come
   from `kernel/sched/ems/multi_load.c`; sdm670 has no `kernel/sched/ems/` directory and no series commit adds it
   (`git log -S'update_cpu_active_ratio' d54533f1546b..baa585f67e0e` is empty).
4. **`74b2f258866b` introduces uclamp from nothing.** `git grep -il uclamp a30605a54f3b` returns 0 files, so all
   4 "ours" sides are empty. Its header changes (`include/linux/sched.h`, `kernel/sched/sched.h`,
   `include/linux/log2.h`) and its 166 `core.c` lines all auto-merge cleanly.
5. **`40a60987a65a` has a duplicate-definition hazard, not a logic disagreement.** The commit only relocates
   `sock_valbool_flag` from `net/core/sock.c` to `include/net/sock.h`; the header copy auto-merges at
   `cf987a870877:include/net/sock.h:779` while the `.c` copy is on the "ours" side of the single conflict block, and
   `net/core/sock.c` includes that header at line 128. A later `CLEAN` commit, `ba6cfd463efe`, calls
   `sock_valbool_flag()` from `net/core/filter.c`.
6. **`40a60987a65a` conflicts because of Samsung KNOX NPA, not because of a missing function.** Both sides carry a
   KNOX NPA block; the sdm670 copy differs from the Exynos one, so the hunk cannot be anchored. sdm670's
   `net/core/sock.c` is 492 lines shorter than the merge base.
7. **Trial vs isolated counts.** `74b2f258866b` matches the trial exactly (2/4/0/100). `40a60987a65a` and
   `c8b2d2af17be` do not (trial 2 blocks/9/91 vs mine 1/8/88; trial 4 blocks/64/8 vs mine 4/60/8) - see each
   brief's `## Problems`.
8. **Upstream SHAs** were read by hand because `analysis/upstream-map/upstream-map.tsv` (K1) did not exist:
   `dfde1d7dee9b` (plural trailer, plus `aad4a0a9513a` and `cb81110997d1`), `-` (no trailer at all),
   `69842cba9ace` (plus a second cherry-pick trailer `d96bd1d5fc86`).

## Problems
- `analysis/upstream-map/upstream-map.tsv` does not exist yet, so all three upstream SHAs were derived by reading
  the commit messages by hand as instructed. Two of the three have trailer shapes that do not literally match the
  K1 patterns (`Upstream commits <sha>, <sha>, and <sha>` for `40a60987a65a`; two
  `(cherry picked from commit <sha>)` trailers for `74b2f258866b`), so K1 may legitimately report different values.
  `c8b2d2af17be` has no upstream SHA under any pattern and is recorded as `-`.
- My isolated `merge-tree` reproduces the trial's block/line counts exactly for 1 of 3 commits. For
  `40a60987a65a` the trial saw one extra small conflict region (24 earlier series commits touch `net/core/sock.c`,
  listed in the brief); for `c8b2d2af17be` the trial's ours side is 4 lines longer than sdm670's, and no series
  commit between the base and that commit touches the header. Both gaps are reported, not explained.
- Model caveat: AGENT-TASKS.md §10 lists "Space Bunny Free" as a model that should not be used for K tasks. I am
  that model. The findings here are all mechanically sourced (every claim carries a SHA, a path:line or a command),
  but the three "Notes for the lead" sections are the kind of judgement §10 reserves for a stronger tier, so they
  deserve a skim by whoever reviews the batch.
- No command failed twice.