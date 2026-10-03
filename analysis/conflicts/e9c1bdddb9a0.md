<!-- task: K2a-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# e9c1bdddb9a0: BACKPORT: locking/refcount: Create unchecked atomic_t implementation
- Author / date: Peter Zijlstra <peterz@infradead.org>, 2017-02-10 (squash of ~14 upstream refcount commits; the squash message only has `Link:`/`Fixes:` trailers, no `Upstream commit` line)
- Upstream: -
- Batch: K2a-2, size_class: trivial

## Summary
A squash of ~14 upstream refcount commits that introduces the unchecked `atomic_t`-based `refcount_t`
(`lib/refcount.c`, 378 new lines, `atomic_try_cmpxchg()`, `CONFIG_REFCOUNT_FULL`, and
`refcount_error_report()` in `kernel/panic.c`). sdm670 has the older **all-inline** `refcount.h` but no
`lib/refcount.c` and no `refcount_error_report`, so this is a real backport, not a duplicate. Only
`kernel/panic.c` conflicts, in a 5-line include block where sdm670 has Qualcomm/Samsung minidump
includes and the series base has `#include <linux/exynos-ss.h>`. Resolution: keep ours, add
`#include <linux/ratelimit.h>` (needed for `WARN_RATELIMIT`), drop `exynos-ss.h`.

## Conflicting files
- kernel/panic.c

## Why it conflicts
merge-tree on its own: **conflicts** (tree `f89eab62fcf845b8329c5c153e4bf392ba7d6292`, exit 1).
`kernel/panic.c` is the only conflicted file; `arch/Kconfig`, `arch/x86/*`, `include/linux/atomic.h`,
`include/linux/kernel.h`, `lib/Makefile` auto-merged, and `lib/refcount.c` is a brand-new file.

- Block 1, kernel/panic.c ~line 29 (include list; base `e9c1bdddb9a0^:kernel/panic.c:28-29` has
  `#include <linux/bug.h>` then `#include <linux/exynos-ss.h>`):
  ours (sdm670 `a30605a54f3b:kernel/panic.c:28-31`) = `#include <linux/bug.h>`,
  `#define CREATE_TRACE_POINTS`, `#include <trace/events/exception.h>`, `#include <soc/qcom/minidump.h>`
  — Qualcomm/Samsung minidump + tracepoint includes, **no** `exynos-ss.h`.
  theirs (series, `e9c1bdddb9a0:kernel/panic.c:29-30`) = `#include <linux/ratelimit.h>` (**newly added by
  this commit**) plus `#include <linux/exynos-ss.h>` (pre-existing Exynos line, not part of this commit).
  Base had no Qualcomm/Samsung includes, so "ours" and "theirs" both rewrote the same hunk.
- The commit's second hunk (add `refcount_error_report()` after `EXPORT_SYMBOL(__stack_chk_fail)`,
  wrapped in `#ifdef CONFIG_ARCH_HAS_REFCOUNT`, using `WARN_RATELIMIT`) applied cleanly and is already
  present in the merged tree at `f89eab62fcf:kernel/panic.c:638-647`.

## Already in sdm670?
**partly** — sdm670 has the *old, all-inline* refcount_t, not this commit's out-of-line one.
- `git grep -n 'refcount_error_report' a30605a54f3b` → **no hits** (rc=1).
- `git cat-file -t a30605a54f3b:lib/refcount.c` → `fatal: path 'lib/refcount.c' does not exist in 'a30605a54f3b'`.
- `git grep -n 'refcount.o' a30605a54f3b -- lib/Makefile` → only `percpu-refcount.o`
  (`a30605a54f3b:lib/Makefile:41`); plain `refcount.o` is absent.
- `git grep -rn 'ARCH_HAS_REFCOUNT' a30605a54f3b -- arch/` → **no hits**.
- `git grep -n 'ratelimit.h' a30605a54f3b -- kernel/panic.c` → **no hits**.
- `include/linux/refcount.h` **does** exist in sdm670 (`git cat-file -t` → `blob`, 294 lines) and is the
  inline form: `a30605a54f3b:include/linux/refcount.h:46` `#define REFCOUNT_WARN(cond, str) WARN_ON(cond)`
  (the `CONFIG_REFCOUNT_FULL` variant) with `static inline` helpers at lines 59-249. The series base has
  the same shape (`e9c1bdddb9a0^:include/linux/refcount.h`, 242 lines). This commit does **not** touch
  `include/linux/refcount.h`, so nothing here duplicates sdm670's inline symbols; the new symbols in
  `lib/refcount.c` are the `refcount_*_checked()` variants plus `refcount_error_report`.
- searched lines: `refcount_error_report`, `refcount.o` (lib/Makefile), `ARCH_HAS_REFCOUNT`,
  `ratelimit.h` in kernel/panic.c.

## Proposed resolution
MERGE — take **ours** for the block and add exactly one line.
Keep sdm670's `#define CREATE_TRACE_POINTS` / `#include <trace/events/exception.h>` /
`#include <soc/qcom/minidump.h>`, then **add `#include <linux/ratelimit.h>`** above them; **delete
`#include <linux/exynos-ss.h>`** (Exynos-only header, does not exist in this tree).
`linux/ratelimit.h` is mandatory: the `refcount_error_report()` body this commit adds uses `WARN_RATELIMIT`.
Everything else in the commit (`lib/refcount.c`, `lib/Makefile` `+ refcount.o`, `include/linux/atomic.h`
`atomic_try_cmpxchg`, `arch/Kconfig`) keep as git merged it.
Note for the build: on arm64 nothing selects `CONFIG_ARCH_HAS_REFCOUNT` (series head only has it in
`arch/Kconfig`, `arch/x86/Kconfig`, `include/linux/kernel.h`, `kernel/panic.c`), so `refcount_error_report()`
compiles out. That is upstream behaviour at this point in history and is harmless.
The `arch/x86/*` files this commit adds are dead weight on arm64 but harmless; keep or drop at will.

## Confidence
high: `merge-tree` was run and the markers were read from the resulting tree; both absence greps
(`refcount_error_report`, `lib/refcount.c`, `ARCH_HAS_REFCOUNT`, `ratelimit.h` in panic.c) plus the
presence greps for the inline `refcount.h` were run; the block is a 5-line include list with one
required addition and one Exynos-only removal.

## Problems
None