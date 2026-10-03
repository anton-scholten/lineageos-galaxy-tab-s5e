<!-- task: K2c-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# 2ece0aa41dee: BACKPORT: sched/uclamp: Add system default clamps
- Author / date: Patrick Bellasi <patrick.bellasi@arm.com>, 2019-06-21
- Upstream: e8f14172c6b11e9a86c65532497087f8eb0f91b1
- Batch: K2c-2, size_class: trivial
- Group in conflict_detail.tsv: **optional** (power management — NOT needed for eBPF or boot)

## Conflicting files
Batch file lists `include/linux/sched/sysctl.h`. merge-tree standalone reports **3 files**:
- `include/linux/sched/sysctl.h` (1 block)
- `include/linux/sched.h` (2 blocks) — *not* in the batch list
- `kernel/sched/core.c` (1 block) — *not* in the batch list

(`kernel/sysctl.c` auto-merges cleanly — it is where the two `sched_util_clamp_{min,max}` ctl_table entries go.)

## Why it conflicts
merge-tree on its own: **conflicts** (4 blocks total, tree `520dd7921aa1`).

Reason: **sdm670 has no uclamp at all.** `git grep -ln 'uclamp' a30605a54f3b` → 0 files. The series base already
has `struct uclamp_se`, `UCLAMP_BUCKETS`, `UCLAMP_CNT`, `uclamp_rq_inc()` etc. from
`74b2f258866bab11ea8940093e88fd4beaef622a` ("BACKPORT: sched/uclamp: Add CPU's clamp buckets refcounting"),
which is why sdm670's files look "empty" to this commit.

All four blocks are **pure insertions or adjacent-addition splits** — none of them requires a semantic merge:

- Block 1, include/linux/sched.h ~line 1681 (after `struct tlbflush_unmap_batch`):
  ours = nothing; theirs = the `#ifdef CONFIG_UCLAMP_TASK` block defining
  `#define UCLAMP_BUCKETS CONFIG_UCLAMP_BUCKETS_COUNT`, `struct uclamp_se`, …, **with the new
  `unsigned int active : 1;` bit field**. Take theirs.
- Block 2, include/linux/sched.h ~line 1766 (inside `struct task_struct`, after `struct sched_dl_entity dl;`):
  ours = nothing; theirs = `#ifdef CONFIG_UCLAMP_TASK` with the new
  `struct uclamp_se uclamp_req[UCLAMP_CNT];` array plus the existing `struct uclamp_se uclamp[UCLAMP_CNT];`.
  Take theirs.
- Block 3, kernel/sched/core.c ~line 773 (right after `set_load_weight()`, before `enqueue_task()`):
  ours = nothing; theirs = ~105 lines: `sysctl_sched_uclamp_util_{min,max}`, `static struct uclamp_se
  uclamp_default[UCLAMP_CNT]`, `UCLAMP_BUCKET_DELTA`, the `for_each_clamp_id()` macro, the bucket machinery,
  and the `#else` stubs (`uclamp_rq_inc`/`uclamp_rq_dec`/`uclamp_fork`/`init_uclamp`).
  Take theirs.
- Block 4, include/linux/sched/sysctl.h ~line 134 (right after `sched_rt_handler()`):
  ours = Samsung's own `extern int sched_updown_migrate_handler(struct ctl_table *table, int write,
  void __user *buffer, size_t *lenp, loff_t *ppos);`
  (`include/linux/sched/sysctl.h:135-137` @ a30605a54f3b);
  theirs = `#ifdef CONFIG_UCLAMP_TASK` + `extern int sysctl_sched_uclamp_handler(struct ctl_table *table,
  int write, void __user *buffer, size_t *lenp, loff_t *ppos);` + `#endif`.
  **Keep BOTH** — they are independent declarations; order does not matter.

The *first* sysctl.h hunk of this commit (`extern unsigned int sysctl_sched_uclamp_util_min;` /
`..._max;` after `sysctl_sched_rt_runtime`) applied **cleanly** — it does not conflict with anything in sdm670.

## Already in sdm670?
**no.** Step 4 on `a30605a54f3b` across `kernel/sched/`, `include/linux/sched.h`, `include/linux/sched/` and
`kernel/sysctl.c`:
- `git grep -ln 'uclamp' a30605a54f3b` → **0 files** (whole tree, not just sched).
- `uclamp`, `sysctl_sched_uclamp_handler`, `sched_util_clamp`, `uclamp_util`, `uclamp_util_with`,
  `uclamp_rq_util_with`, `uclamp_is_used`, `sched_uclamp_used` → all absent.
- `git log a30605a54f3b --grep='uclamp: Add system default clamps' -F` → no match; upstream
  `e8f14172c6b1` not in sdm670's history.

Prerequisite confirmed: `CONFIG_UCLAMP_TASK`, `struct uclamp_se` (using `bits_per()` from
`include/linux/log2.h`) and `struct uclamp_rq` all arrive with `74b2f258866b` (+ `c86bfd9a4ae3`,
`64895384e5f0`, all earlier). `74b2f258866b` itself is a **trial CONFLICT** (`init/Kconfig`,
`kernel/sched/core.c`) and is in another batch — the lead must resolve that one first, otherwise this commit
cannot compile no matter how it is merged.

`DEFINE_STATIC_KEY_FALSE`/`DECLARE_STATIC_KEY_FALSE` and `static_branch_*` are already available in sdm670
(`include/linux/jump_label.h` @ a30605a54f3b).

## Proposed resolution
MERGE — take theirs in blocks 1-3 (pure insertions) and **keep both declarations** in block 4.
Nothing in sdm670's version of any of the four files needs to be edited.

The `sysctl_sched_uclamp_handler()` symbol that block 4 declares is *defined* by this commit inside
`kernel/sched/core.c` and referenced from the `kernel/sysctl.c` table, so it only needs a prototype — dropping
Samsung's `sched_updown_migrate_handler` prototype instead would break the Qualcomm/Samsung scheduler.

**Ordering prerequisite (does not change the verdict):** 74b2f258866b, c86bfd9a4ae3, 64895384e5f0 must be in the
tree first. They are earlier in the series, so a normal in-order replay gets them for free.

**Risk note for the human (optional group):** all of this is dead weight unless `CONFIG_UCLAMP_TASK=y` and
`CONFIG_UCLAMP_TASK_GROUP=y` are enabled — task K6 lists both, and
`arch/arm64/configs/gts4lvwifi_defconfig` @ a30605a54f3b sets neither. A DROP loses the
`/proc/sys/kernel/sched_util_clamp_{min,max}` interface (which Android 16's scheduler-aware power HAL reads);
it does not affect eBPF or boot. There is no way to "take the easy way out" by skipping only this commit —
without it the later uclamp commits in this batch do not apply either.

## Confidence
high: all four blocks read verbatim from the merge-tree output, and step 4 establishes that sdm670 has zero
uclamp, so "pure insertion / keep both" is unambiguous.

## Problems
None
