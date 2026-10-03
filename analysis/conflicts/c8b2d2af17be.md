<!-- task: K3-4 | agent: Space Bunny Free | date: 2026-10-03 -->
# c8b2d2af17be: ANDROID: refcount: Fix linkage of out-of-line helpers

## Summary
Facts only, no resolution proposed (K3). One conflicting file, `include/linux/refcount.h`, with **4 conflict blocks**
(ours 60 lines / theirs 8). Every block is the same shape: sdm670 carries a full inline body, the series has only
an `extern` declaration. sdm670 does **not** have the change and has no `lib/refcount.c` at all; the out-of-line
definitions the `extern` declarations point at arrive from an *earlier* series commit (`e9c1bdddb9a0`, position 450)
which is itself a `CONFLICT` in the trial. 0 later series commits touch this header.
Lead should look first at that ordering fact - whether `e9c1bdddb9a0` lands determines if the `extern` form has
implementations in the merged tree.

- Author / date: Mathias Gluszczynski <admin@krazey.de>, 2026-09-14
- Upstream: `-`. The message has no upstream-SHA trailer of any of the four K1 patterns; it carries
  `Fixes: e9c1bdddb9a0 (...)`, which names a *series* commit, not an upstream one. There is no `Change-Id:`.
- Batch: K3-4, size_class: large (group `required`)

Files touched by the commit (`git show --stat c8b2d2af17be`): `include/linux/refcount.h` only, 4 insertions /
4 deletions. It is 4 one-token edits: `static inline __refcount_check` -> `extern __refcount_check` on
`refcount_dec_if_one`, `refcount_dec_not_one`, `refcount_dec_and_mutex_lock`, `refcount_dec_and_lock`.

## Conflicting files
- `include/linux/refcount.h` - the only one.

Command and result:
```
git -C ~/work/k670 merge-tree --write-tree --merge-base=c8b2d2af17be^ a30605a54f3b c8b2d2af17be
34c93ad840d989a5588b056ea306333bd4fd9742          <- tree id, exited 1 (conflict)
100644 ...25802ac31796 1  include/linux/refcount.h   <- base (c8b2d2af17be^)
100644 ...600aadf9cca4 2  include/linux/refcount.h   <- ours (sdm670 a30605a54f3b)
100644 ...0974dece46fe 3  include/linux/refcount.h   <- theirs (c8b2d2af17be)
CONFLICT (content): Merge conflict in include/linux/refcount.h
```

## Why it conflicts
merge-tree on its own: **conflicts** (1 file, 4 blocks, ours 60 lines, theirs 8 lines).
The trial recorded the same 4 blocks and the same 8 theirs lines but 64 ours lines
(`analysis/exyhyperbrick-trial/conflict_detail.tsv`) - 4 more ours lines than the isolated replay, i.e. about one
extra line per block. No series commit between the base and this one touches this header, so the stacked replay's
ours side differs from plain sdm670 for a reason I could not reproduce.

| Block | merged-tree lines | ours (sdm670) | theirs (series) |
|---|---|---|---|
| 1 | 208-217 | 5 lines: `static inline __refcount_check` + full `refcount_dec_if_one()` body returning `atomic_cmpxchg_release(&r->refs, 1, 0) == 1` | 2 lines: `extern __refcount_check` + `bool refcount_dec_if_one(refcount_t *r);` |
| 2 | 225-256 | 27 lines: `static inline __refcount_check` + full `refcount_dec_not_one()` body (the `for(;;)` UINT_MAX-saturating loop with `REFCOUNT_WARN`) | 2 lines: `extern __refcount_check` + `bool refcount_dec_not_one(refcount_t *r);` |
| 3 | 266-284 | 14 lines: `static inline __refcount_check` + full `refcount_dec_and_mutex_lock()` body | 2 lines: `extern __refcount_check` + `bool refcount_dec_and_mutex_lock(refcount_t *r, struct mutex *lock);` |
| 4 | 294-312 | 14 lines: `static inline __refcount_check` + full `refcount_dec_and_lock()` body | 2 lines: `extern __refcount_check` + `bool refcount_dec_and_lock(refcount_t *r, spinlock_t *lock);` |

All four blocks are the same edit at four sites, with the same doc comment above each (the merged-tree comment
blocks are at lines 197-207, 219-224, 258-265, 286-293 and are *not* in conflict).

Reference points in sdm670 for the same four helpers, all `static inline __refcount_check`:
`a30605a54f3b:include/linux/refcount.h:208` (`refcount_dec_if_one`), `:220` (`refcount_dec_not_one`),
`:256` (`refcount_dec_and_mutex_lock`), `:279` (`refcount_dec_and_lock`); `__refcount_check` is defined locally at
`a30605a54f3b:include/linux/refcount.h:47` and `:50`.

## Already in sdm670?
**No.** Lines searched (all against `a30605a54f3b`):

| Line searched | Result |
|---|---|
| `extern __refcount_check` in `include/linux/refcount.h` | NO MATCH (`git grep` rc=1) |
| `extern __refcount_check` in the whole tree | NO MATCH |
| `EXPORT_SYMBOL(refcount_dec_if_one)` | NO MATCH |
| `EXPORT_SYMBOL(refcount_dec_not_one)` | NO MATCH |
| `EXPORT_SYMBOL(refcount_dec_and_mutex_lock)` | NO MATCH |
| `EXPORT_SYMBOL(refcount_dec_and_lock)` | NO MATCH |

Related facts, all verified:
- `lib/refcount.c` does **not** exist in sdm670: `git cat-file -e a30605a54f3b:lib/refcount.c` ->
  `fatal: path 'lib/refcount.c' does not exist in 'a30605a54f3b'`.
- sdm670's `lib/Makefile` builds no `refcount.o` (`a30605a54f3b:lib/Makefile:41` lists `percpu-refcount.o` only).
  The series head does: `baa585f67e0e:lib/Makefile:40` adds `refcount.o`.
- The series head has `lib/refcount.c` (`baa585f67e0e:lib/refcount.c`, blob `e8853a436dbb`).
- No `.c` file in sdm670 calls any of these four helpers
  (`git grep -E 'refcount_dec_not_one|refcount_dec_and_lock|refcount_dec_and_mutex_lock|refcount_dec_if_one'
  a30605a54f3b -- '*.c'` = no output), so today they are reachable only from inside the header.
- The `extern` side's implementations come from an **earlier series commit**:
  `e9c1bdddb9a09ec14e8ab37f0d32b1a80cb7c0c8 "BACKPORT: locking/refcount: Create unchecked atomic_t implementation"`,
  series position 450 (base..head count), `git merge-base --is-ancestor e9c1bdddb9a0 c8b2d2af17be` succeeds, and it
  is the **only** commit in the series touching `lib/refcount.c`
  (`git log --oneline d54533f1546b..baa585f67e0e -- lib/refcount.c`). In that commit's version of `lib/refcount.c`
  all four are defined and exported: `e9c1bdddb9a0:lib/refcount.c:247/253`, `:266/287`, `:305/318`, `:336/349`.
- `e9c1bdddb9a0` is itself a **CONFLICT** in the trial: `results.tsv` -> `CONFLICT ... kernel/panic.c`, and
  `conflict_detail.tsv` -> 1 file, 1 block, ours 3, theirs 2, `size_class trivial`.
- Only two commits in the whole series touch `include/linux/refcount.h`:
  `6ee017762dda "refcount_t: Introduce a special purpose refcount type"` and this one.
  `git merge-base --is-ancestor d54533f1546b 6ee017762dda` fails, so `6ee017762dda` is at/before the series base,
  i.e. a prerequisite the Exynos tree already had and sdm670 got some other way.

**Confidence: high** - six greps for the exact added tokens all miss, plus the absence of `lib/refcount.c` and of
`refcount.o` in the sdm670 build are direct file-system facts, and the ancestry of `e9c1bdddb9a0` is a git
`--is-ancestor` result rather than an assumption.

## Notes for the lead
Observations only, no recommendation:
1. All 4 blocks are one mechanical edit repeated; there is no third side and no disagreement about logic, only about where the body lives.
2. The `extern` declarations are only sound if `lib/refcount.c` is in the tree and `lib/Makefile` builds `refcount.o`; neither is true of sdm670 at `a30605a54f3b`, both come from `e9c1bdddb9a0`.
3. `e9c1bdddb9a0` (position 450) is **earlier** than this commit (position 2442) and is itself an unresolved `CONFLICT` in the trial, so ordering decides whether `extern` resolves at link time.
4. sdm670's `refcount_dec_and_mutex_lock` / `refcount_dec_and_lock` bodies call `refcount_dec_not_one()` (`a30605a54f3b:include/linux/refcount.h:259` and `:282`); under the `extern` form those become external calls too, which `e9c1bdddb9a0:lib/refcount.c` provides.
5. sdm670 has no `.c` caller of the four helpers today, so no existing call site depends on the inline bodies.
6. The commit message cites F2FS `refcount_dec_not_one()`; the related `554b84a02e00 ANDROID: f2fs: Restore compression context reference types` is itself a `size_class large` / `skip` conflict.
7. `git show --stat` is 4 insertions / 4 deletions in one file: no logic and no ABI change.
8. 0 later series commits touch this header, so no follow-up commit re-opens the same lines.

## Later series commits touching the same files
`git -C ~/work/k670 log --oneline c8b2d2af17be..baa585f67e0e -- include/linux/refcount.h | head -30`

```
(no output)
```

**0 later series commits** touch `include/linux/refcount.h` after `c8b2d2af17be` (157 commits remain in the series
after it, position 2442 of 2599).

## Confidence
high - Conflicting files: **1** (`include/linux/refcount.h`); blocks examined: **4**; later series commits touching
it: **0**. A single-file, four-block, single-token change: every block was read in full from the merge-tree blob, and
the sdm670-side and dependency-side claims are backed by greps, `cat-file -e` and `--is-ancestor` results rather than
inference.

## Problems
- `analysis/upstream-map/upstream-map.tsv` (task K1) does not exist yet. Reading the message by hand found no
  upstream SHA matching any of the four patterns, so `upstream_sha = "-"`. The `Fixes: e9c1bdddb9a0` trailer is a
  series SHA, not an upstream one, and `e9c1bdddb9a0` is not an ancestor of anything in mainline as far as I checked.
- The trial's `conflict_detail.tsv` records ours_lines=64 for this commit; my isolated merge-tree measures 60.
  The 4-line gap (about one line per block) is reported, not explained.
- No command failed twice.