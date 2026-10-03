<!-- task: K2c-1 | agent: Space Bunny Free | date: 2026-10-03 -->
# K2c-1-summary: conflict briefs for batch K2c-1

## Summary
9 briefs written, one per row of `analysis/agent-batches/K2c-1.tsv`, all 9 commits in the
`optional` group and all `trivial` size_class (`analysis/exyhyperbrick-trial/conflict_detail.tsv`).
Method per commit: `git show --stat`, upstream SHA read from the message with the K1 patterns,
`git merge-tree --write-tree --merge-base=C^ a30605a54f3b C`, then `git grep` against sdm670 to
test whether the change is already there. Resolutions: **2 DROP, 7 MERGE, 0 PREREQ, 0 HUMAN**,
so the "more than half HUMAN" stop rule did not trigger.

**Read this first, in this order:**

1. **`4cf42717d891` (mm/vmalloc: VM_FLUSH_RESET_PERMS) is misclassified.** The trial says
   `optional`; I believe it is **required**. `kernel/bpf/trampoline.c:32` and
   `kernel/bpf/bpf_struct_ops.c:601` @ baa585f67e0e call `set_vm_flush_reset_perms()`, and those
   files come from trial-**CLEAN** commits `5ab406ffb73f` (series pos 1325) and `c49c98ee5ce7`
   (pos 2188). trampoline.o is built unconditionally (`kernel/bpf/Makefile:12`). **Dropping this
   commit breaks the eBPF build.** It also collides with sdm670's own `VM_LOWMEM 0x00000100`
   (arch/arm/mm/mmu.c:1540, mm/vmalloc.c:2793), and its `mm/vmalloc.c` half needs symbols sdm670
   does not have (`include/linux/set_memory.h`, `set_direct_map_*_noflush`, `asm/set_memory.h`).
   Recommendation and the full reasoning are in the brief.
2. **`d2ec292ffd08` (binder oneway spam) is a safe DROP** — sdm670 already has the identical
   change as `01ad2bbbd5a37a0bd45ca98adfdf2e06e512bba5`. Because a wrong DROP is the worst
   possible outcome, that brief carries five independent proofs.
3. **Every other brief warns against taking "theirs" whole**, which is the mistake
   `AGENT-TASKS.md` §9 calls out: doing that would delete sdm670's `VM_LOWMEM`
   (`4cf42717d891`), its `VM_MAYWRITE` `WARN_ON` (`fad9a6a81aa6`), its
   `clang-android.sh` safety check (`7f6ca00150fc`), or would add non-existent GPU directories
   `arm/` and `exynos/` (`667e0cd40150`).
4. **Two briefs record a defect in the trial's file lists.** `4cf42717d891` also conflicts in
   `mm/vmalloc.c`, and `fad9a6a81aa6`'s `mm/userfaultfd.c` sibling file needs no action but is
   listed in `conflict_detail.tsv`; `conflict_detail.tsv` only counted `include/linux/vmalloc.h`
   for `4cf42717d891` because the earlier stacked commits had already absorbed the mm/vmalloc.c
   hunk. The lead should expect a few more conflicting files than `conflict_detail.tsv` says.
5. **Cross-batch build risk spotted while working on `4cf42717d891`** (not mine to fix):
   `2e71fb11d9a8` "provide linux/set_memory.h" (pos 116, CLEAN) adds
   `include/linux/set_memory.h`, whose `#ifdef CONFIG_ARCH_HAS_SET_MEMORY` branch does
   `#include <asm/set_memory.h>`; `1f9378f37a88` "arm64: Select ARCH_HAS_SET_MEMORY" (pos 120,
   CLEAN) then turns that branch on for arm64 — but `arch/arm64/include/asm/set_memory.h` does not
   exist in the series head either (`git ls-tree -r baa585f67e0e | grep set_memory.h` shows only
   arch/arm, arch/s390, arch/x86, asm-generic, linux). `mm/vmalloc.c` is the only core file that
   includes it. Worth checking against the K4/K6 build results.

## Table

| commit | subject | resolution | confidence |
|---|---|---|---|
| `285607f6d86f` | nl80211: add WPA3 definition for SAE authentication | DROP | high |
| `437cc7c3ab63` | ion: Map userspace buffers page-aligned | MERGE | high |
| `9a27f565137b` | mm, vmalloc: use __GFP_HIGHMEM implicitly | MERGE | high |
| `4cf42717d891` | mm/vmalloc: Add flag for freeing of special permsissions | MERGE | medium |
| `f4e1fe0bc47b` | BACKPORT: kernfs: don't set dentry->d_fsdata | MERGE | high |
| `667e0cd40150` | BACKPORT: gpu/trace: add a gpu total memory usage tracepoint | MERGE | high |
| `d2ec292ffd08` | BACKPORT: binder: detect oneway transaction spam | DROP | high |
| `7f6ca00150fc` | BACKPORT: kbuild: clang: Allow CLANG_TRIPLE without CROSS_COMPILE | MERGE | high |
| `fad9a6a81aa6` | UPSTREAM: userfaultfd: use vma_is_anonymous | MERGE | high |

## Detail, per commit

| commit | group | merge-tree | blocks | what the conflict is | already in sdm670? |
|---|---|---|---|---|---|
| `285607f6d86f` | optional | conflicts, tree `d488ca49d55b` | 2 (both files) | series renumbers the Exynos WAPI bit out of the way of WPA3; sdm670 has no WAPI | yes — `9b7ffd7b43e4`, same Change-Id |
| `437cc7c3ab63` | optional | conflicts, tree `76cafa63255b` | 1 | `ion_heap_map_user()`: old `len = min(len, remainder)` vs page-aligned `map_len` | no (`map_len` absent, no `PAGE_ALIGN` in that function) |
| `9a27f565137b` | optional | conflicts, tree `68f63d75f183` | 1 | `kernel/fork.c` `THREADINFO_GFP \| __GFP_HIGHMEM` + tab depth | no (still explicit in kernel/fork.c:201 and 6× mm/vmalloc.c) |
| `4cf42717d891` | optional (I say required) | conflicts, tree `0ad19a653697` | 2 (2 files) | `VM_LOWMEM 0x100` vs `VM_FLUSH_RESET_PERMS 0x100`, plus `vmalloc_exec()` calling convention | no; only the `vm_flags` parameter of `__vmalloc_node_range()` already exists |
| `f4e1fe0bc47b` | optional | conflicts, tree `00d4a0995815` | 1 | `kernfs_iop_getattr()` prototype: 4.9 `vfsmount`/`dentry` vs newer `struct path` | partly — `inode->i_private` is set at inode.c:220, but 21 `d_fsdata` uses remain |
| `667e0cd40150` | optional | conflicts, tree `7546ad382c1b` | 1 | `drivers/gpu/Makefile` `obj-y` line: sdm670 has no `arm/`, `exynos/` | no (no `gpu_mem_total`, no `include/trace/events/gpu_mem.h`) |
| `d2ec292ffd08` | optional | conflicts, tree `5c07775b580c` | 2 | whitespace only; merge produced no real diff | yes — `01ad2bbbd5a3`, same author and same 4 files |
| `7f6ca00150fc` | optional | conflicts, tree `f80a5eef1fa2` | 1 | Samsung `clang-android.sh` error check sits in the gap the CLANG_TRIPLE guard closes | partly — sdm670 has `CLANG_TRIPLE` but no `ifneq ($(CLANG_TRIPLE),)` guard |
| `fad9a6a81aa6` | optional | conflicts, tree `7c4e902c9ef2` | 1 | extra `WARN_ON(!(vma->vm_flags & VM_MAYWRITE));` under `BUG_ON(vma->vm_ops)` | no (4 `vm_ops` tests in fs/, 1 in mm/) |

## Upstream SHAs (for K1 cross-check)
- Found by the K1 patterns: `667e0cd40150` → `bbd9d05618a6`, `d2ec292ffd08` → `261e7818f06ec`.
- Found, but **not** by the four literal K1 patterns (a strict K1 run would log `-`; flagging so
  K1 can decide): `7f6ca00150fc` → `c04915fd6939` (Android common, trailer text
  "Android common commit c04915fd6939"), `fad9a6a81aa6` → `a94720bf821d` (trailer text
  `Upstream-commit: a94720bf821dd63e72176da5f423ba7935dde67d`, hyphenated).
- No SHA in the message, so `-`: `285607f6d86f` (Change-Id only, which must not count),
  `437cc7c3ab63`, `9a27f565137b` (lore link only), `4cf42717d891` (lore link only),
  `f4e1fe0bc47b`.
- Bonus for K1: sdm670's own equivalents of two series commits are `9b7ffd7b43e4` (same Change-Id
  as `285607f6d86f`) and `01ad2bbbd5a3` (same author as `d2ec292ffd08`); both should come out
  `sdm670_has=yes`.

## Verification notes
- Kernel tree used read-only: `~/work/k670`, sdm670 tip `a30605a54f3b92627d868f169c72ef9c6ef82123`,
  series base `d54533f1546b91f94eb4e445dfea3a94ffa58a74`, series head
  `baa585f67e0efc9f1efa046d0b0e76955ca4c8d5`, `rev-list --count --no-merges d54533f1546b..baa585f67e0e`
  = 2599, git 2.47.3. No ref was created, moved or deleted; no second clone was made.
- All 9 commits conflict when merged standalone; none of them was explained by an earlier series
  commit, so every brief quotes real conflict markers.
- No more than 20 lines of kernel code are quoted in any brief.

## Confidence
Batch-level: high that the 8 `high` items are correct, medium on `4cf42717d891`
alone. Reason: every brief has a verified `file:line` or SHA citation and a merge-tree
tree ID, and the two DROPs rest on five and three independent proofs respectively; the one
`medium` asks for a partial apply (rejecting hunks git merged cleanly) and depends on a
`linux/set_memory.h` chain that belongs to another batch.

## Problems
None. No command failed. One caveat to disclose: `AGENT-TASKS.md` §10 says not to use untested
free models such as Space Bunny Free for K tasks and to rerun such a batch with a tier-2 model if
it comes out mostly `HUMAN`/`low`. This batch came out 8 `high` + 1 `medium`, 0 `HUMAN`, 0 `low`,
so I do not think a rerun is needed — but the reviewer should keep §11's spot-check of the
`high`-confidence items in mind, and pay extra attention to the two DROPs (`285607f6d86f`,
`d2ec292ffd08`) and to the one `medium` (`4cf42717d891`).
