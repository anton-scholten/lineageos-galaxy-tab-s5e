<!-- task: K8 | agent: Space Bunny Free | date: 2026-10-03 -->
# K8: briefs for the two un-briefed conflicts

## Summary
Two briefs written: `analysis/conflicts/47d10743ccd7.md` and `analysis/conflicts/0a115d7aaf34.md`.
**Both commits turn out not to conflict at all.** The trial's `CLEAN` is correct for both; the "they conflict"
claim traces to two agents running the isolated `git merge-tree` against pristine sdm670, which over-reports.
Measured each one two or three ways (`analysis/tools/replay_show.py`, an isolated `merge-tree`, and an exact
in-order replay); file/block counts are in the briefs.

| commit | subject | trial | my measurement | resolution | confidence |
|---|---|---|---|---|---|
| `47d10743ccd7` | BACKPORT: mm: introduce MADV_PAGEOUT | `CLEAN` | isolated: 6 files / 9 blocks; stacked: **0 / 0**; stacked marker-free: **0 / 0** | PREREQ (`138179e5ccba`) then apply as-is | medium |
| `0a115d7aaf34` | mm/vmalloc.c: convert vmap_lazy_nr to atomic_long_t | `CLEAN` | isolated: 1 file / 3 blocks; stacked: **0 / 0**; exact in-order replay: **0 / 0** (tree `e2afa03e5d27`) | MERGE, apply as-is | high |

**The lead must check these three things first** (all are corrections to existing briefs, not new files):

1. **`analysis/conflicts/e7751e04e9d1.md:63-71` is wrong about `47d10743ccd7`.** It says "whoever reaches
   47d10743ccd7 must expect a conflict there even though no brief was assigned for it". Isolated `merge-tree`
   reports 6 files / 9 blocks; a stacked replay reports 0 files and 0 blocks. Do not budget resolution effort for
   this commit.
   The rest of that brief (47d10743ccd7 is a mandatory prerequisite for `e7751e04e9d1`) is confirmed.
2. **`analysis/conflicts/138179e5ccba.md:90-94` would break the build if followed literally.** It advises renaming
   sdm670's `can_madv_dontneed_vma` → `can_madv_lru_vma` "in exactly two places". There are **three**
   occurrences: `mm/internal.h:66`, `mm/madvise.c:481`, and `mm/oom_kill.c:529` (all @ `a30605a54f3b`).
   `138179e5ccba` only *adds* `can_madv_lru_vma` (`mm/internal.h:46` @ `138179e5ccba`, 5-line insert, zero
   deletions; the Exy base has no `can_madv_*` helper at all), so the correct merge is **keep both names**. The
   series itself rewrites the `oom_kill.c` call site later, in `11c19a7b0938`.
3. **`47d10743ccd7` is a prerequisite for 12 later commits, 11 of which have no brief.** Twelve MADV_PAGEOUT
   commits follow it back-to-back (13 counting itself); only `e7751e04e9d1` (CONFLICT) has a brief. The other 11
   are trial-`CLEAN` with no brief, so P1 walks straight past them. The full SHA list is in the brief. If the
   lead drops the MADV_PAGEOUT feature (K2c-2's briefs put it in the **optional** group), drop all 13 commits
   together plus the MADV_PAGEOUT hunk of `138179e5ccba` — a half-dropped chain does not link.

Prerequisite status, both directions:

- `47d10743ccd7` **needs** `138179e5ccba` first: its new `madvise_pageout()` calls `can_madv_lru_vma()`
  (`mm/madvise.c:616` @ `47d10743ccd7`), which only exists after that commit. It is also **needed by**
  `e7751e04e9d1` + the 11 commits above.
- `0a115d7aaf34` **needs** `7c9b3c4119eb` (its parent; already briefed). It is needed by **nothing** later —
  `git log --oneline 0a115d7aaf34..baa585f67e0e -S'vmap_lazy_nr'` is empty.

## Problems
- `analysis/tools/README.md` says the replay scripts should be pointed at a scratch clone, because they create
  `commit-tree` commits in the clone. My instructions forbade a second clone, so I ran them with
  `K670=~/work/k670`. They wrote loose objects (and dangling, unreferenced commits) into the shared
  clone. **No ref was created, moved or deleted, and nothing was checked out** — the same thing the trial itself
  does. Worth `git gc --prune=now` on the shared clone if anyone cares.
- One extra tool was needed and is **not** in this repo: a scratch `replay_strip.py` that replays a stack and
  resolves each conflict by keeping both sides, so the next commit is merged against a marker-free tree. It lives
  at `/tmp/opencode/replay_strip.py`. For `0a115d7aaf34` it was unnecessary — a two-command exact in-order replay
  (`merge-tree` with `2492fe92d81e` as "ours") answers the question better, and that method needs no extra script.
- The K2 verdict vocabulary has no value for "this commit has no conflict". `0a115d7aaf34` is therefore filed as
  MERGE (apply as-is, nothing to merge), and `47d10743ccd7` as PREREQ, which is accurate in substance: its
  ordering constraint on `138179e5ccba` is real and compile-breaking if ignored.
- Residual risk I did not have the budget to close: the 11 unbriefed MADV_PAGEOUT commits after
  `47d10743ccd7` are trial-`CLEAN`, and the trial's stacked replay keeps conflict markers in the tree
  (`analysis/exyhyperbrick-trial/trial.py:29-31`), so their `CLEAN` is not proof. If P1 hits a conflict in
  `mm/madvise.c` anywhere in that chain, there is no brief — escalate, and note that dropping the whole chain is
  a valid choice.
