<!-- task: K2d-1 | agent: Space Bunny Free | date: 2026-10-03 -->
# K2d-1: conflict briefs for batch K2d-1 (optional, moderate)

## Summary

8 briefs written, one per row of `analysis/agent-batches/K2d-1.tsv`. All 8 commits are group **`optional`**
(nice-to-have: power, memory, DRM niceties — nothing needed for eBPF or boot).

**modify/delete count: 0 of 8.** `analysis/exyhyperbrick-trial/conflict_detail.tsv` has a `modify_delete`
column and every one of my rows reads `0`:
`5610ada6efc5`=0, `05e231887443`=0, `b48811f9463e`=0, `b611939c2042`=0, `225cc0357185`=0,
`69934e633aa5`=0, `7c9b3c4119eb`=0, `a0163349e173`=0. There was no delete-vs-modify case to reason about.

| commit | subject | resolution | confidence |
|---|---|---|---|
| `5610ada6efc5` | drm: Add aspect ratio parsing in DRM layer | DROP | high |
| `05e231887443` | drm: Add a new connector atomic property for link status | DROP | medium |
| `b48811f9463e` | alarmtimer: Shorten wakeup hold for imminent alarms | MERGE | high |
| `b611939c2042` | mm: refactor __purge_vmap_area_lazy() | DROP | high |
| `225cc0357185` | mm: turn vmap_purge_lock into a mutex | DROP | high |
| `69934e633aa5` | mm: add preempt points into __purge_vmap_area_lazy() | DROP | high |
| `7c9b3c4119eb` | mm/vmalloc.c: add priority threshold to __purge_vmap_area_lazy() | MERGE | high (medium on adopt) |
| `a0163349e173` | mm/vmalloc.c: keep track of free blocks for vmap allocation | MERGE | high (low on adopt) |

No HUMAN items, so no stop-and-ask condition was triggered.

### The big finding: sdm670 already contains this hch/Joel Fernandes vmalloc trio

`b611939c2042`, `225cc0357185` and `69934e633aa5` are each **byte-identical** (same `git patch-id --stable`,
same `Change-Id`, same `Link:`, same `Git-commit:`) to three commits already in sdm670:

| series commit | sdm670 twin | patch-id |
|---|---|---|
| `b611939c2042` | `835db09522b92ec7839851684f7992e547afcd10` | `9f35f5ce1d7e496335dcfe1996142daab3a0ca54` |
| `225cc0357185` | `9fd2c02aae746a4b2817b1b2b20499256e84a5d9` | `8118acc6a70cf2367311901919c623d5db1c111d` |
| `69934e633aa5` | `68b90437585c1a69f4fef3fdf060e8a819410b72` | `af4e03ab0abfed4acf9a80a4e93393a43b5681e3` |

For the latter two, `git merge-tree --write-tree --merge-base=<C>^ a30605a54f3b <C>` returns tree
`a9dfa91a0c2022c93aa3fc4184dcb9da030c71d0` and `git diff --name-only a30605a54f3b a9dfa91a0c20...` prints
**nothing** — the merge is a fixpoint. sdm670 is also *ahead*: it has the mutex form, so taking the series
version would be a downgrade, not a merge. All three DROP together.

`5610ada6efc5` is the same story: sdm670 has the identical patch as
`6fce4f33639272165f94bd65e28760862dcf3f85` ("drm: Add aspect ratio parsing in DRM layer", same 31-insertion
stat) plus a later refactor, `57ef61243805` "drm/modes: Introduce drm_mode_match()".

### Trial artefacts the lead should know about

Four of my eight commits (`225cc0357185`, `69934e633aa5`, `7c9b3c4119eb`, and partly
`a0163349e173`) **apply cleanly in isolation** — their trial CONFLICT is a stacking artefact. The trial
"committed conflicted commits with conflict markers"
(`analysis/exyhyperbrick-trial/README.md`), so every later `mm/vmalloc.c` commit merged against a
marker-laden file. All four trace back to `b611939c2042` (position 81), the only commit in this group that
conflicts on its own.

### Two problems outside my batch, found while working

1. **`0a115d7aaf34` "mm/vmalloc.c: convert vmap_lazy_nr to atomic_long_t"** (series position 109, between
   two of mine) is recorded **CLEAN** in `analysis/exyhyperbrick-trial/results.tsv`, so **no K2 brief exists
   for it**, but in isolation it does conflict:
   `git merge-tree --write-tree --merge-base=0a115d7aaf34^ a30605a54f3b 0a115d7aaf34` → tree
   `b0d77661d71b337eed380631ed37387d38b9fde2`, `CONFLICT (content)`, 3 blocks, all inside
   `__purge_vmap_area_lazy()`. Resolution is mechanical once `7c9b3c4119eb` is in: drop the obsolete
   `bool do_free = false;`, keep `resched_threshold = lazy_max_pages() << 1;`, take theirs for the
   `atomic_long_*` hunk.
2. **`05e231887443` does not compile in either tree, not just ours.** It uses `config->link_status_property`
   but `struct drm_mode_config` (which lives in `include/drm/drm_crtc.h` here — there is no
   `include/drm/drm_mode_config.h`) has no such member in sdm670 *or* at series head `baa585f67e0e`. The
   prerequisite (upstream patch 1/5, "drm: Add a new connector property for link status") is not in the
   series. A plain MERGE there breaks the build.

### For the K1 upstream map

Three commits carry real upstream SHAs in a `Git-commit:` trailer (CodeAurora/Android convention), which is
**not** one of the four patterns K1 step 2 looks for. K1 may record `-` for these; they should be
corrected:

| commit | `Git-commit:` |
|---|---|
| `b611939c2042` | `0574ecd141df28d573d4364adec59766ddf5f38d` |
| `225cc0357185` | `f9e09977671b618aeb25ddc0d4c9a84d5b5cde9d` |
| `69934e633aa5` | `763b218ddfaf56761c19923beb7e16656f66ec62` |

None of the three objects exist in the `~/work/k670` clone (they are torvalds/linux commits).

## Confidence

high: for the six commits marked DROP or MERGE-high, every claim rests on a reproducible command
(`git patch-id --stable`, `git diff --name-only <tree>`, `git grep -n ... a30605a54f3b`,
`git cat-file -p <tree>:<path>`) rather than on reading hunks, and the five `mm/vmalloc.c` conclusions
agree with each other across three independent methods. The two soft spots are called out per-item above
and are the reason `05e231887443` is `medium` and `a0163349e173` carries a `low` on adoption: both are
judgement calls about optional changes, not textual facts.

Caveat on the reviewer: this batch was produced by **Space Bunny Free**, which
`AGENT-TASKS.md` §10 lists under "Don't use free or unknown models ... for K or R tasks" and places
outside the tier-1/tier-2 bands. The facts are all command-backed and cheap to re-verify, but per §11
step 2 the DROP items and every `low` should get the manual look the doc asks for regardless.

## What the lead must check first

1. **`a0163349e173` — the `calc_total_vmalloc_size()` trap.** This is the one item where following the
   "take theirs" reflex silently loses sdm670 functionality. The patch is 763 insertions / 247 deletions
   even though the trial classed it `moderate`. If it is taken, Block 1 must become
   `vmap_init_free_space();` **plus** `calc_total_vmalloc_size();`, or the exported `VMALLOC_TOTAL` reads 0
   in `/proc/meminfo`, `drivers/md/dm-bufio.c` and `mm/percpu.c`. My recommendation is to **defer or drop**
   this rework until after the first boot; it is `optional`, so nothing needed for eBPF depends on it.
2. **The four DROPs** (`5610ada6efc5`, `b611939c2042`, `225cc0357185`, `69934e633aa5`). Each is justified by
   an identical-patch proof, not by inspection, but DROPs are the ones that can lose code silently, so per
   §11 step 2 they deserve the manual check. The cheapest verification is the two commands quoted in
   `b611939c2042.md`: `git show <c> | git patch-id --stable` for both members of each pair.
3. **`05e231887443`** — verify the missing `link_status_property` field claim before accepting the DROP.
   It is the only item where I recommend *not* applying a commit that merges cleanly, and my reason is a
   build break rather than a textual overlap.
4. **`b48811f9463e`** — cosmetic only: the patch's `s64 msec` shadows sdm670's function-scope
   `uint64_t msec` (`kernel/time/alarmtimer.c:354-356`), and `CONFIG_SEC_PM_DEBUG=y` in our defconfigs
   means the new `pr_err` really compiles in.

## Problems

None. No command failed more than once; the shared kernel clone at `~/work/k670` was only read
from (no checkout, no ref moves, no writes).