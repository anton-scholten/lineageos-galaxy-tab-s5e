<!-- task: K4c | agent: Space Bunny Free (space-bunny-free) | date: 2026-10-03 -->
# K4c: TIF_FSCHECK

## Summary
**This is not a missing prerequisite. It is a one-sided conflict resolution, and the task's premise is inverted:**
sdm670 **has** the whole arm64 fscheck mechanism; the ExyHyperBrick series has **none of it**.

The single series commit that touches `arch/arm64/include/asm/thread_info.h` is
`2d6869d3a4cea710b71ebb7fba0175e49af942d2` "arm64: Add uprobe support". In the Exy tree TIF bit 4 was free, so it
took it for `TIF_UPROBE`. In sdm670 bit 4 is already `TIF_FSCHECK`. That commit is `CONFLICT`
([results.tsv:991](../../exyhyperbrick-trial/results.tsv)), and the trial resolved it by taking the series side
([build-test/README.md:18-21](../../build-test/README.md)), so `TIF_FSCHECK` / `_TIF_FSCHECK` were deleted while
sdm670's `set_thread_flag(TIF_FSCHECK)` in `uaccess.h` survived untouched → the reported error.

Proof by line/column arithmetic (see *Defined at*): sdm670 has `set_thread_flag(TIF_FSCHECK)` at `uaccess.h:77`,
and the **CLEAN** series commit `bf425599523bc0362022beb5cb8d7556a36c9af6`
([results.tsv:1414](../../exyhyperbrick-trial/results.tsv)) inserts exactly 12 lines above it, moving it to
**line 89**, where `TIF_FSCHECK` starts at **column 18**. That is the reported error exactly.

Two things the lead must not get wrong:
1. The fix must keep **both** flags. `_TIF_UPROBE` is used *unconditionally* by `arch/arm64/kernel/signal.c`, which
   merged cleanly in the same commit. A "keep ours" resolution just moves the error.
2. This error is the cause of K4d's `offsetof` error (the trial README already says so), so fixing it should clear
   line 4 of `port-first-errors.txt` too.

## Defined at
**In the series head `baa585f67e0e`: `TIF_FSCHECK` does not exist.** `git grep -n TIF_FSCHECK baa585f67e0e`
returns one unrelated hit only: `drivers/scsi/aacraid/aacraid.h:1333` (`#define FsCheck 24`, SCSI).
`git grep -n -i fscheck d54533f1546b` (the series **base**) returns the same single hit, so the Exy tree never had
fscheck at all.

**In sdm670 `a30605a54f3b`** (4 places, the complete mechanism):

| What | Where @ `a30605a54f3b` |
|---|---|
| `#define TIF_FSCHECK 4` | `arch/arm64/include/asm/thread_info.h:83` |
| `#define _TIF_FSCHECK (1 << TIF_FSCHECK)` | `arch/arm64/include/asm/thread_info.h:106` |
| `_TIF_FSCHECK` added to `_TIF_WORK_MASK` | `arch/arm64/include/asm/thread_info.h:109-111` |
| the *use* that failed to compile | `arch/arm64/include/asm/uaccess.h:77` — `set_thread_flag(TIF_FSCHECK);` inside `set_fs()` |
| the *consumer* | `include/linux/syscalls.h:212-226` — `addr_limit_user_check()`, both uses inside `#ifdef TIF_FSCHECK` (lines 214 and 223) |
| the only caller | `arch/arm64/kernel/signal.c:415` — `addr_limit_user_check();` in `do_notify_resume()` (unconditional) |

Line/column check of the error message. `uaccess.h:77` in sdm670 is one tab + `set_thread_flag(`, i.e. 17
characters, so the identifier starts at column 18. `bf425599523bc0362022beb5cb8d7556a36c9af6` adds a 12-line
`arm64_bpf_fixup_exception()` block between `#define ARCH_HAS_RELATIVE_EXTABLE` and `extern int fixup_exception`
(`arch/arm64/include/asm/uaccess.h:65-67` in sdm670), shifting line 77 to 77+12 = **89**. Reported error is
`arch/arm64/include/asm/uaccess.h:89:18`. **Exact match on both line and column** — this identifies the failing
statement unambiguously.

**The competing definition**, the one the conflict is really about — series head
`baa585f67e0e:arch/arm64/include/asm/thread_info.h:88`: `#define TIF_UPROBE 4`, added by `2d6869d3a4ce`, plus
`_TIF_UPROBE` at `:111` and `_TIF_UPROBE` in `_TIF_WORK_MASK` at `:114-116`.

## Added by
| Symbol | Commit | Date | Note |
|---|---|---|---|
| `TIF_FSCHECK` (sdm670) | `b17d6c4789ed2a077989bee4acb959d50f5add21` | 2017-06-14 | "UPSTREAM: arm64/syscalls: Check address limit on user-mode return", cherry-picked from mainline `cf7de27ab35172a9240f079477cae3146a182998`. Touches 3 files, +12/-1: `thread_info.h`, `uaccess.h`, `kernel/signal.c`. Found by `git log -S'TIF_FSCHECK' a30605a54f3b -- arch/arm64/include/asm/thread_info.h` (oldest = only hit) |
| `TIF_UPROBE` (series) | `2d6869d3a4cea710b71ebb7fba0175e49af942d2` | 2016-11-02 | "arm64: Add uprobe support", Pratyush Anand. 10 files, +277/-2. Touches `thread_info.h`, `kernel/signal.c`, `Kconfig`, and **adds** `arch/arm64/kernel/probes/uprobes.c` (216 lines) |

Ancestor checks (`git merge-base --is-ancestor <sha> <ref>`):

| Commit | ancestor of sdm670 `a30605a54f3b` | ancestor of series base `d54533f1546b` | ancestor of series head `baa585f67e0e` |
|---|---|---|---|
| `b17d6c4789ed2a077989bee4acb959d50f5add21` (fscheck) | **YES** | no | no |
| `2d6869d3a4cea710b71ebb7fba0175e49af942d2` (uprobe) | no | no | **YES** |

## Status (in series/skipped/prerequisite)
**Neither "in series, skipped" nor "missing prerequisite" — it is a third case: in the series, conflicted, and
auto-resolved to the series side.**

- `2d6869d3a4ce…` — **in the series** (after base `d54533f1546b`, ancestor of head `baa585f67e0e`).
  `results.tsv:991` → `CONFLICT`, conflicted file `arch/arm64/include/asm/thread_info.h`.
  `conflict_detail.tsv:57` → `files=1, blocks=3, ours_lines=3, theirs_lines=3, modify_delete=0,
  size_class=trivial, group=required`.
  Reproduced read-only with `git merge-tree 2d6869d3a4ce^ a30605a54f3b 2d6869d3a4ce` (old three-arg form, writes no
  objects). It reports **3 conflict hunks, all in `thread_info.h`**, exactly matching `blocks=3`:
  ```
  @@ -80,7 +80,11 @@   #define TIF_FOREIGN_FPSTATE 3
  +<<<<<<< .our
   #define TIF_FSCHECK		4	/* Check FS is USER_DS on return */
  +=======
  +#define TIF_UPROBE		4	/* uprobe breakpoint or singlestep */
  +>>>>>>> .their
  @@ -103,12 +107,20 @@  -> _TIF_FSCHECK (ours) vs _TIF_UPROBE (theirs)
  @@                    -> _TIF_WORK_MASK tail: _TIF_FSCHECK) vs _TIF_UPROBE)
  ```
  `arch/arm64/kernel/signal.c` is reported "changed in both" but **merges cleanly**: the added lines
  `if (thread_flags & _TIF_UPROBE) uprobe_notify_resume(regs);` land without conflict markers. That is why
  `_TIF_UPROBE` now has a caller with no definition.
- `bf425599523b…` — `results.tsv:1414` → `CLEAN`. It is the reason the fscheck `set_thread_flag` survived into the
  port tree but moved from line 77 to line 89.
- `b17d6c4789ed…` — not in the series and not in its base at all; it exists only in sdm670. Nothing in the series
  touches it. It needs no porting; it needs to **stop being deleted**.

## Present in sdm670
**Yes — all of it, and nothing in the arm64 speculation-mitigation set is missing.** sdm670 has:
`TIF_FSCHECK` (bit 4) and `TIF_SSBD` (bit 23) in `arch/arm64/include/asm/thread_info.h:83` / `:94`;
`config ARM64_SSBD` at `arch/arm64/Kconfig:905`; `config ARM64_UAO` at `arch/arm64/Kconfig:1061`;
`TIF_SSBD` used in `arch/arm64/kernel/entry.S:118` and `arch/arm64/kernel/ssbd.c:47,53,60`. The series head also
has `config ARM64_SSBD` (`arch/arm64/Kconfig:944`), so the two trees agree on this mechanism.

**The symbols named in the task brief do not exist in any 4.9 tree.** `git grep -n -E 'ARM64_PAC|UNMAP_STRICT|FORCE_TASKS_MAX|^config SPECULATION'`
over `a30605a54f3b` (`arch/arm64`, `include`) and over `baa585f67e0e` (`arch/arm64/Kconfig*`) returns **zero
hits in both trees**. `CONFIG_ARM64_PAC`, `CONFIG_UNMAP_STRICT_KERNEL`, `FORCE_TASKS_MAX` and `CONFIG_SPECULATION`
are 5.x-era names; a 4.9 kernel uses the `TIF_FSCHECK` + `TIF_SSBD` + `ARM64_SSBD` form that sdm670 already has.

Defconfig (`git ls-tree -r --name-only a30605a54f3b arch/arm64/configs | grep gts4lv` → 4 files; checked
`gts4lvwifi_defconfig` @ `a30605a54f3b`): grep for `PROBE|BPF|SSBD|UAO` returns only `CONFIG_CGROUP_BPF=y`,
`CONFIG_BPF_SYSCALL=y`, `CONFIG_SECCOMP=y`, `CONFIG_NETFILTER_XT_MATCH_BPF=y`, `CONFIG_NET_CLS_BPF=y` — there is
**no `CONFIG_UPROBES`, no `CONFIG_KPROBES`, no `CONFIG_BPF_JIT`, no `CONFIG_ARM64_SSBD`, no `CONFIG_ARM64_UAO`**
line. The trial's defconfig fragment
([exyhyperbrick-trial/README.md:76-83](../../exyhyperbrick-trial/README.md)) adds `CONFIG_KPROBES=y` but **not**
`CONFIG_UPROBES`. Good news: `uprobe_notify_resume()` is a no-op stub when `CONFIG_UPROBES=n`
(`include/linux/uprobes.h:151` `#else`, stub at `:189`), so the arm64 `signal.c` call compiles either way. The
**define is mandatory, the config option is not.**

## Suggested fix
Re-resolve `2d6869d3a4cea710b71ebb7fba0175e49af942d2` (`arch/arm64/include/asm/thread_info.h`, 3 hunks) keeping
**both** flags: keep `#define TIF_FSCHECK 4` as-is, add `#define TIF_UPROBE 5` (bit 5 is the first free bit in
sdm670's arm64 TIF space — 6, 12-17 and 25-31 are also free, 0-4 and 7-24 are taken
@ `a30605a54f3b:arch/arm64/include/asm/thread_info.h:79-95`), keep both `#define _TIF_FSCHECK` and
`#define _TIF_UPROBE`, and make `_TIF_WORK_MASK` end in `_TIF_FOREIGN_FPSTATE | _TIF_FSCHECK | _TIF_UPROBE)`.
Leave `bf425599523b` and the sdm670 fscheck files alone.

Do **not** "fix" this by adding a `#define`, and do **not** port arm64 speculation-hardening prerequisite patches —
nothing is missing (see *Present in sdm670*). Separately: decide whether `CONFIG_UPROBES` goes in the gts4lv
defconfig (K6); the build works without it, but with it you get working arm64 uprobes.

## Confidence
- Root cause = auto-resolved conflict `2d6869d3a4ce` dropping `TIF_FSCHECK`: **high** — the read-only
  `git merge-tree` reproduces the exact 3 hunks, `conflict_detail.tsv` independently reports `blocks=3`, and
  `results.tsv` says `CONFLICT` on that exact file.
- The failing statement is `set_thread_flag(TIF_FSCHECK)` at `uaccess.h:89:18`: **high** — 77 + 12 inserted lines
  = 89 and column 18 both match the reported position to the character; a wrong statement could not land there.
- "The arm64 speculation mechanism is complete in sdm670, nothing to port": **high** — all four fscheck files plus
  `ARM64_SSBD`/`ARM64_UAO` were read directly at `a30605a54f3b`, and the 5.x-era symbol names return zero hits in
  both trees.
- `TIF_UPROBE` on bit 5 is *a* free, safe choice, not the only one: **medium** — bit 5 is verifiably unused in
  sdm670's arm64 TIF block, but I did not audit non-arm64 code that might use raw `_TIF_*` bit numbers on arm64
  tasks, and I did not check what upstream mainline settled on for this collision.
- Effect on K4d (`offsetof` in `asm-offsets.c:49`): **medium** — the trial README asserts it is "a result of the
  above", and `schedule.h:2284` / `arch/arm64/kernel/asm-offsets.c:49` are exactly the `randomized_struct_fields_end`
  error that is K4a, a *different* symbol. I did not open `asm-offsets.c:49`, which is K4d's own task.

## Problems
None. All commands succeeded on the first run. Two notes for reproducibility:
- I used the **old three-argument** `git merge-tree <base> <ours> <theirs>` form, which prints a merge preview and
  writes no objects, to stay read-only in `~/work/k670`. The `--write-tree` form from
  AGENT-TASKS.md §1.3 would have written blobs into that shared repo, so I avoided it. The results agree with
  `results.tsv` / `conflict_detail.tsv` anyway.
- `/tmp/claude-0/w/k670-port` (the trial tree named in `port-first-errors.txt`) no longer exists on this machine, so
  I could not read the post-resolution `thread_info.h` directly. The line/column arithmetic plus
  `results.tsv` + `build-test/README.md:18-21` identify it unambiguously, but if the lead wants certainty, diff that
  tree's `arch/arm64/include/asm/thread_info.h` against the hunks in *Defined at*.