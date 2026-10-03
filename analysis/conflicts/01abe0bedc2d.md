<!-- task: K2c-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# 01abe0bedc2d: BACKPORT: sched/uclamp: Remove uclamp_util()
- Author / date: Valentin Schneider <valentin.schneider@arm.com>, 2019-12-11
- Upstream: 59fe675248ffc37d4167e9ec6920a2f3d5ec67bb
- Batch: K2c-2, size_class: trivial
- Group in conflict_detail.tsv: **optional** (power management — NOT needed for eBPF or boot)

## Conflicting files
- kernel/sched/cpufreq_schedutil.c (2 blocks)
- kernel/sched/sched.h (1 block)
  (`kernel/sched/sched.h` is **not** in the batch list; merge-tree reports it.)

## Why it conflicts
merge-tree on its own: **conflicts** (3 blocks, tree `ef9ded306c4e`).

This is a **pure deletion commit** (kill the `uclamp_util()` wrapper, keep `uclamp_util_with()`), plus a change of
the two call sites in `cpufreq_schedutil.c` from `uclamp_util(rq, util)` to `uclamp_util_with(rq, util, NULL)`.

Two independent reasons it conflicts:
1. **sdm670 has no uclamp at all** (`git grep -ln 'uclamp' a30605a54f3b` → 0 files), so `kernel/sched/sched.h`
   has nothing where the series has the whole `CONFIG_UCLAMP_TASK` helper block.
2. **sdm670's `cpufreq_schedutil.c` is the Samsung WALT variant.** In `sugov_update_single()` sdm670 has an extra
   `sugov_walt_adjust(sg_cpu, &util, &max);` (`kernel/sched/cpufreq_schedutil.c:386` @ a30605a54f3b) where the
   Exy tree has the uclamp line; and in `sugov_next_freq_shared()` sdm670 applies
   `sugov_iowait_boost()` **after** the max-selection (`kernel/sched/cpufreq_schedutil.c:433-434` @ a30605a54f3b)
   whereas the Exy tree applies it before, per-CPU, on `j_util`/`j_max`.

Per block (line numbers in tree `ef9ded306c4e`):

- Block 1, kernel/sched/cpufreq_schedutil.c ~line 385 (`sugov_update_single`):
  ours = `sugov_walt_adjust(sg_cpu, &util, &max);`
  theirs = `util = uclamp_util_with(this_rq(), util, NULL);`
  Common context around it is `sugov_iowait_boost(sg_cpu, &util, &max);` … `next_f = get_next_freq(...)`.
- Block 2, kernel/sched/cpufreq_schedutil.c ~line 432 (`sugov_next_freq_shared`):
  ours = nothing (sdm670 jumps straight from `j_max = j_sg_cpu->max;` to `if (j_util * max >= j_max * util)`, then
  calls `sugov_iowait_boost()` + `sugov_walt_adjust()` afterwards);
  theirs = `#ifdef CONFIG_UCLAMP_TASK` + `sugov_iowait_boost(j_sg_cpu, &j_util, &j_max);` +
  `j_util = uclamp_util_with(cpu_rq(j), j_util, NULL);` + `#endif`.
- Block 3, kernel/sched/sched.h ~line 2406 (between `#endif /* CONFIG_CPU_FREQ */` and
  `#ifdef arch_scale_freq_capacity`):
  ours = nothing; theirs = the `CONFIG_SCHED_WALT` `walt_task_in_cum_window_demand()` helper **plus** the
  `CONFIG_UCLAMP_TASK` block (`uclamp_eff_value()` prototype + `uclamp_util_with()` + the `#else` stub),
  with the two `uclamp_util()` wrappers already removed.

## Already in sdm670?
**no.** `git grep -ln 'uclamp' a30605a54f3b` → 0 files (whole tree).
`uclamp_util`, `uclamp_util_with`, `uclamp_rq_util_with`, `uclamp_is_used`, `sched_uclamp_used`,
`sysctl_sched_uclamp_handler` → all absent.
`git log a30605a54f3b --grep='Remove uclamp_util()' -F` → no match; upstream `59fe675248ff` not in sdm670 history.

Things the resolution needs that sdm670 has: `this_rq()` is used in `kernel/sched/core.c`/`fair.c`/`cputime.c`
but not yet in `cpufreq_schedutil.c` — it is a `static inline` in `kernel/sched/sched.h`, which this file already
includes (`#include "sched.h"`, `kernel/sched/cpufreq_schedutil.c:21` @ a30605a54f3b). The loop variable `j`
exists in sdm670's `sugov_next_freq_shared()` (`kernel/sched/cpufreq_schedutil.c:403`), so `cpu_rq(j)` is valid.

## Proposed resolution
MERGE — and the schedutil adaptation must preserve Samsung's WALT path. krazey's own note on this commit is
"[krazey: Update the 4.9 schedutil callbacks to pass their local runqueues.]", i.e. he already had to re-target
these two call sites in his own 4.9 tree.

- Block 1: keep **both**, uclamp last, so the clamp is applied to the final util/max:
  `sugov_iowait_boost(sg_cpu, &util, &max);` / `sugov_walt_adjust(sg_cpu, &util, &max);` /
  `util = uclamp_util_with(this_rq(), util, NULL);` / `next_f = get_next_freq(sg_policy, util, max);`
- Block 2: take **only the uclamp line** from theirs and leave sdm670's WALT structure alone:
  `j_util = j_sg_cpu->util;` / `j_max = j_sg_cpu->max;` /
  `#ifdef CONFIG_UCLAMP_TASK` / `j_util = uclamp_util_with(cpu_rq(j), j_util, NULL);` / `#endif` /
  `if (j_util * max >= j_max * util) { util = j_util; max = j_max; }` /
  `sugov_iowait_boost(j_sg_cpu, &util, &max); sugov_walt_adjust(j_sg_cpu, &util, &max);`
  **Do not** also take theirs' `sugov_iowait_boost(j_sg_cpu, &j_util, &j_max);` — sdm670 already applies the
  iowait boost once, after the selection; adding theirs' copy would apply it twice.
- Block 3: take theirs in full (it is exactly the post-deletion state of the upstream helper block). Dropping the
  `uclamp_util()` wrappers is the whole point of the commit.

**Value note (optional group):** this commit only deletes dead code. A DROP loses nothing functionally, but it is
also **not free to skip**: `kernel/sched/sched.h` must still gain the `uclamp_util_with()` block that the later
commits in this batch (70b95802146b, 45170da68469) rewrite. If the human drops this one they must port the
`uclamp_util_with()` definition from 01abe0bedc2d's "theirs" side by hand anyway.

## Confidence
medium: the three blocks and the "ours = Samsung WALT variant" reading are verified directly, but choosing
"uclamp line last" in block 1 and "don't double-apply iowait_boost" in block 2 is a judgement about correct
behaviour rather than a mechanical merge, so the human should eyeball those two hunks.

## Problems
None
