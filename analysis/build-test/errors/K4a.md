<!-- task: K4a | agent: Space Bunny Free (opencode) | date: 2026-10-03 -->
# K4a: randomized_struct_fields_end

## Summary
K4a is a **missing prerequisite, not a skipped series commit**. The only definitions of
`randomized_struct_fields_end` in the series head are the empty fallback in
`include/linux/compiler.h:477-480` @ `baa585f67e0e` and the GCC form in
`include/linux/compiler-gcc.h:293-294` @ `baa585f67e0e`. Both were added by
`ddfaa236ef8b05a2c593d6ad77447cfa97849610` ("task_struct: Allow randomized layout", Kees Cook,
author date 2017-04-05), which is an **ancestor of the series base** `d54533f1546b`, so the replay
never applies it and sdm670 never had it.

The line reached the test port tree only through conflict resolution, not through the series.
Commit `c3e95a25fa4a6c7a48ff507e093c273e2682b62c` (recorded **CONFLICT**, `include/linux/sched.h`,
in [`../../exyhyperbrick-trial/results.tsv`](../../exyhyperbrick-trial/results.tsv)) adds `bpf_ctx`
immediately above the randstruct comment + marker, and taking the whole series side of that
conflict block pasted `randomized_struct_fields_end` into sdm670's `sched.h`. Proof below.

Scope is small: `randomized_struct_fields_end` has exactly **one** use in the whole series head
(`include/linux/sched.h:2273` @ `baa585f67e0e`), and **no Kconfig change is needed** — sdm670 has no
randstruct Kconfig at all and the macros are unconditional for GCC >= 4.6 with empty fallbacks.

**Lead must check first:** whether the sibling randstruct macros `__designated_init` /
`__randomize_layout` are also missing in sdm670 (they are — see *Present in sdm670*), because they
are needed for any GCC toolchain build even though the clang test build does not need them.

## Defined at
Primary definition (the one a clang build relies on), `include/linux/compiler.h:477-480` @ `baa585f67e0e`:

```c
#ifndef randomized_struct_fields_start
# define randomized_struct_fields_start
# define randomized_struct_fields_end
#endif
```

GCC definition, `include/linux/compiler-gcc.h:293-294` @ `baa585f67e0e`, inside the
`#if GCC_VERSION >= 40600` block that opens at `include/linux/compiler-gcc.h:277`:

```c
#define randomized_struct_fields_start	struct {
#define randomized_struct_fields_end	} __randomize_layout;
```

Neither is gated on `CONFIG_RANDSTRUCT` / `CONFIG_GCC_PLUGIN_RANDSTRUCT`; the comment above them
(compiler-gcc.h:287-292) says they are used for all GCC 4.6+ builds, not only plugin builds.

Only use, `include/linux/sched.h:2273` @ `baa585f67e0e`, the last line of the randomizable region of
`task_struct`, just before `struct thread_struct thread;`. The matching opening marker is
`include/linux/sched.h:1735` @ `baa585f67e0e`, right after `volatile long state;`.

Full grep, only 3 hits in the series head tree (`git -C ~/work/k670 grep -n
'randomized_struct_fields_end' baa585f67e0e`):

```
baa585f67e0e:include/linux/compiler-gcc.h:294:#define randomized_struct_fields_end	} __randomize_layout;
baa585f67e0e:include/linux/compiler.h:479:# define randomized_struct_fields_end
baa585f67e0e:include/linux/sched.h:2273:	randomized_struct_fields_end
```

confidence: high — the two files are the only `#define` sites and the grep covers the whole tree.

## Added by
`ddfaa236ef8b05a2c593d6ad77447cfa97849610` — "task_struct: Allow randomized layout", Kees Cook
(author date 2017-04-05), `Signed-off-by: krazey <admin@krazey.de>`, 3 files, +31/-1:
`include/linux/compiler-gcc.h`, `include/linux/compiler.h`, `include/linux/sched.h`.

It is the only commit in the whole ExyHyperBrick history that adds the string:
`git log --format='%h %ad %s' --date=short -S'randomized_struct_fields_end' baa585f67e0e --
include/linux/compiler.h include/linux/compiler-gcc.h` returns that one commit, and the same for
`-- include/linux/sched.h`.

Two older commits in the same family, both also before the series base, matter for a full backport:

| SHA (12+) | Subject | Adds |
|---|---|---|
| `97bb46e4d413d94db0927e2a9042963eb0c6e9ab` | compiler: Add `__designated_init` annotation | `__designated_init` |
| `26c4d610ff153e2dd1d8871712b91171637b25eb` | gcc-plugins: Add the randstruct plugin | `__randomize_layout` fallback, `arch/Kconfig` `GCC_PLUGIN_RANDSTRUCT` |

Note: author dates are shuffled here because the ExyHyperBrick branch was rebased.
`git rev-list --count ddfaa236ef8b..26c4d610ff15` = 0 and `26c4d610ff15..ddfaa236ef8b` = 6, so
topologically `97bb46e4d413` → `26c4d610ff15` → `ddfaa236ef8b`, even though the author dates read
2017-04-05 then 2017-05-05.

confidence: high — one `-S` hit per file, and the ancestry counts confirm the order.

## Status (in series/skipped/prerequisite)
**Prerequisite: BEFORE the series base.**

```
git -C ~/work/k670 merge-base --is-ancestor \
    ddfaa236ef8b05a2c593d6ad77447cfa97849610 d54533f1546b   -> exit 0 (is an ancestor of the base)
```

So it is a missing prerequisite: the Exynos tree already had it, sdm670 does not, and it is correctly
absent from `analysis/exyhyperbrick-trial/results.tsv` (that file only covers
`d54533f1546b..baa585f67e0e`). It was never skipped as SKIPDEV/SKIPDEV2 and is not a series CONFLICT.

**How the broken line got into the port tree anyway** — commit
`c3e95a25fa4a6c7a48ff507e093c273e2682b62c`, "BACKPORT: bpf: Add ambient BPF runtime context stored
in current", recorded in `results.tsv` as:

```
CONFLICT	c3e95a25fa4a6c7a48ff507e093c273e2682b62c	BACKPORT: bpf: Add ambient BPF runtime context stored in current	include/linux/sched.h
```

Its `include/linux/sched.h` hunk inserts 4 lines whose trailing context is the randstruct comment and
the marker. Replayed onto sdm670 with `git merge-tree --write-tree --merge-base=<c>^ a30605a54f3b <c>`
it produces tree `b45888c7c0180e7e2be2f3da9692f3f86814f42f` with this conflict block at
`include/linux/sched.h:2208-2221` (stage-1/2/3 blobs listed for that file in the same command):

```
2207 #endif
2208 <<<<<<< a30605a54f3b
2209 =======
2210 #ifdef CONFIG_BPF_SYSCALL
2211     /* Ambient context for the currently running BPF program. */
2212     struct bpf_run_ctx *bpf_ctx;
2213 #endif
2214        (blank)
2215-2218   /* "New fields for task_struct should be added above here ...
                 they are included in the randomized portion of task_struct." */
2219     randomized_struct_fields_end
2220        (blank)
2221 >>>>>>> c3e95a25fa4a6c7a48ff507e093c273e2682b62c
```

Taking the series side of that whole block (what the trial did, see
[`../../exyhyperbrick-trial/README.md`](../../exyhyperbrick-trial/README.md) and
[`../../build-test/README.md`](../../build-test/README.md)) inserts line 2219 into the port tree,
which is the `include/linux/sched.h:2284` of `port-first-errors.txt` (line numbers shift because
other merged content lands in the same file).

Related series commits touching `include/linux/sched.h`, with their recorded status, so the lead
knows what else to check in that file:

| SHA (12+) | Subject | results.tsv status |
|---|---|---|
| `c3e95a25fa4a` | BACKPORT: bpf: Add ambient BPF runtime context stored in current | CONFLICT (`include/linux/sched.h`) |
| `68c98f0dbfa2` | BACKPORT: bpf: Implement local storage for tasks | CLEAN — **artifact**: its hunk context is `struct bpf_run_ctx *bpf_ctx;`, which only exists after `c3e95a25fa4a` was merged with the series side |
| `57dbd53a0638` | BACKPORT: cgroup: cgroup v2 freezer | CONFLICT (`kernel/signal.c`) |
| `74b2f258866b` | BACKPORT: sched/uclamp: Add CPU's clamp buckets refcounting | CONFLICT (`init/Kconfig kernel/sched/core.c`) |
| `2ece0aa41dee` | BACKPORT: sched/uclamp: Add system default clamps | CONFLICT (`include/linux/sched/sysctl.h`) |
| `bfb69594b22a` | BACKPORT: sched/uclamp: Extend `sched_setattr()` … clamping | CLEAN |
| `f5395b96ddd9` | BACKPORT: sock: ulimit on MSG_ZEROCOPY pages | CLEAN |
| `f53f22a39479` | [exynos9810] sched: separate performance-critical and PSI flags | SKIPDEV |

`68c98f0dbfa2` is a descendant of `c3e95a25fa4a` (`merge-base --is-ancestor` succeeds), so it was
replayed on top of the already-broken `sched.h`; it will need re-checking after the K4a fix.

confidence: high — the status rows are quoted from `results.tsv`, and the conflict block is reproduced
from the `merge-tree` output tree named above.

## Present in sdm670
**No.** In `a30605a54f3b`:

| Check | Result |
|---|---|
| `git grep -n 'randomized_struct_fields_end' a30605a54f3b` | no match (exit 1) |
| `git grep -n 'randomized_struct_fields' a30605a54f3b` (whole tree) | no match |
| `git grep -n -i 'randstruct' a30605a54f3b` (whole tree) | no match |
| `git grep -n '__randomize_layout' a30605a54f3b` (whole tree) | no match |
| `git grep -n '__designated_init' a30605a54f3b` (whole tree) | no match |
| `git grep -i 'RANDSTRUCT' a30605a54f3b -- '*Kconfig*' 'Makefile'` | no match |

sdm670's `include/linux/compiler.h` goes straight from `#define __latent_entropy` (line 462) to the
`__cold` block (line 470) — it has none of `__designated_init`, `__randomize_layout`,
`__no_randomize_layout` or the `randomized_struct_fields_*` fallbacks
(all line numbers @ `a30605a54f3b`).

**Field ordering (the extra-credit question).** sdm670's `task_struct` has **no randstruct markers at
all**, so the boundaries the series expects do not exist:

| Landmark | Series head `baa585f67e0e` | sdm670 `a30605a54f3b` |
|---|---|---|
| `struct task_struct {` | `include/linux/sched.h` (earlier) | line 1681 |
| `randomized_struct_fields_start` | line 1735 | absent |
| `atomic_t stack_refcount;` | inside `#ifdef CONFIG_THREAD_INFO_IN_TASK` | line 2205 |
| `randomized_struct_fields_end` | line 2273 | absent |
| `struct thread_struct thread;` | after the marker | line 2208 |

Consequence: there is no "randomizable region" to reason about, but that does not matter for BPF.
The only two fields the series adds to `task_struct` are `bpf_ctx` (`c3e95a25fa4a`) and `bpf_storage`
(`68c98f0dbfa2`), and both must simply sit immediately before `struct thread_struct thread;`. In
sdm670 that insertion point is `include/linux/sched.h:2207`, i.e. right after the `#endif` that closes
the `CONFIG_THREAD_INFO_IN_TASK` block and before the `/* CPU-specific state of this task */` comment.

**CONFIG_RANDSTRUCT dependency: none, and none is needed.** There is no randstruct Kconfig in sdm670
at all, and no defconfig mentions it: `arch/arm64/configs/gts4lv_defconfig` and
`arch/arm64/configs/gts4lvwifi_defconfig` @ `a30605a54f3b` contain no `RANDSTRUCT`, `GCC_PLUGIN`,
`THREAD_INFO_IN_TASK`, `VMAP_STACK` or `LTO` line (they do already set `CONFIG_BPF_SYSCALL=y` at
line 42). Enabling `CONFIG_GCC_PLUGIN_RANDSTRUCT` is neither required nor advisable (sdm670 has no
such Kconfig entry; the plugin would also want to randomize parts of `task_struct` that upstream
marks non-randomizable).

The only toolchain caveat: with **clang** (`LLVM=1`, as in the build test) `compiler-gcc.h` is not
used, so the empty `compiler.h` fallbacks suffice. With **GCC >= 4.6** the `compiler-gcc.h` form is
used, and it expands `randomized_struct_fields_end` to `} __randomize_layout;`, which expands to
`} __designated_init;`. Both of those macros are missing in sdm670, so a GCC build needs the full
three-commit backport below, not just `ddfaa236ef8b`.

confidence: high — every row is a grep result; the field-ordering table is line-numbered from
`git show` of both commits.

## Suggested fix
**Recommended (Option A): fix the conflict by hand, do not backport randstruct.** Resolve
`c3e95a25fa4a6c7a48ff507e093c273e2682b62c`'s `include/linux/sched.h` conflict by keeping only its
4 added lines (`#ifdef CONFIG_BPF_SYSCALL` / comment / `struct bpf_run_ctx *bpf_ctx;` / `#endif`) and
dropping the randstruct comment plus `randomized_struct_fields_end` from the series side, placing the
block at `include/linux/sched.h:2207` @ sdm670 `a30605a54f3b`, just before
`/* CPU-specific state of this task */`. Then re-check `68c98f0dbfa2` (`bpf_storage`) in the same
place, just above `bpf_ctx`. No compiler.h change, no defconfig change, and `task_struct` stays
byte-identical to the baseline.

**Alternative (Option B): backport the prerequisite as 3 commits** in topological order
`97bb46e4d413` → `26c4d610ff15` → `ddfaa236ef8b`, all before the series base, then the series side
would compile. Result of `git merge-tree --write-tree --name-only --merge-base=ddfaa236ef8b^
a30605a54f3b ddfaa236ef8b`: `include/linux/compiler-gcc.h` and `include/linux/sched.h` auto-merge
clean (the markers land at `include/linux/sched.h:1695` and `:2219` of the merged blob), and
`include/linux/compiler.h` conflicts in one hunk, because sdm670 also lacks `__designated_init`,
`__randomize_layout` and `__no_randomize_layout` that the Exynos base already had. Do **not** cherry-pick
`ddfaa236ef8b` alone: on GCC it leaves `__randomize_layout` expanding to an undefined
`__designated_init`. Option B costs more and buys nothing unless randstruct is wanted later.

Do not enable `CONFIG_GCC_PLUGIN_RANDSTRUCT`, and do not "fix" this by defining
`randomized_struct_fields_end` on its own without `randomized_struct_fields_start`: only the `_end`
marker was pasted in, so a plugin-enabled build would produce an unterminated anonymous struct.

confidence: high for Option A's mechanics (exact conflict block and target line quoted above);
medium for the claim that Option A is the right overall call, because that is a judgement about the
port plan rather than a measured fact.

## Confidence
- Definition location and single-use scope: **high** — exhaustive `git grep` over the series head.
- Adding commit and its pre-base status: **high** — single `-S` hit plus a successful
  `merge-base --is-ancestor`.
- Root cause of the error line (conflict on `c3e95a25fa4a`, series side taken): **high** — the
  `merge-tree` conflict block is reproduced verbatim from tree
  `b45888c7c0180e7e2be2f3da9692f3f86814f42f`; the only unverified step is that the trial's resolution
  picked exactly that side, which `../../build-test/README.md` states.
- No Kconfig/defconfig change needed: **high** — no randstruct Kconfig exists in sdm670 and the macros
  are unconditional in the series head.
- That `randomized_struct_fields_start` was *not* also pasted into the port tree: **medium** — inferred
  from the conflict lists (only `c3e95a25fa4a` lists `include/linux/sched.h`, and its block contains
  only `_end`); the port tree itself is not in this container, so I could not read it.

## Problems
- The trial's port tree (`/tmp/claude-0/w/k670-port`, from `../../build-test/port-first-errors.txt`)
  does not exist in this container, so I could not read its `include/linux/sched.h` to confirm exactly
  which markers and how many randstruct lines the blind resolution pasted in. Everything about the
  conflict block above is derived from `git merge-tree` on the shared kernel tree instead.
- I did not verify whether `CONFIG_THREAD_INFO_IN_TASK` ends up set in the built `.config` (neither
  `gts4lv_defconfig` nor `gts4lvwifi_defconfig` lists it, and 4.9 arm64 defaults it on; I did not read
  `init/Kconfig`). It only affects whether `stack_refcount` exists at `sched.h:2205`, not the fix.
- No command failed twice. One command was mistyped by me —
  `git merge-base --write-tree --merge-base=...` ("error: unknown option `write-tree'") — and was
  re-run correctly as `git merge-tree --write-tree ...`.
- Model note: this agent is Space Bunny Free. `AGENT-TASKS.md` §10 assigns K4a–d to tier-1 models
  (DeepSeek V4.1 Flash) and says not to use free/unknown models for K tasks, so the lead should
  spot-check the high-confidence claims above rather than accept them unchecked.