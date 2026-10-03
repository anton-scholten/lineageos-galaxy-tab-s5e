<!-- task: K2a-3 | agent: Space Bunny Free (space-bunny-free) | date: 2026-10-03 -->
# 7bea7dea3ed7: BACKPORT: epoll: wire up syscall epoll_pwait2
- Author / date: Willem de Bruijn <willemb@google.com>, 2020-12-18
- Upstream: `-` (no upstream SHA in the message; only a lkml `Link:` trailer and a Gerrit `Change-Id: I48dfae6f721b24ebc53de603e393289954a95908`, which is not a SHA)
- Batch: K2a-3, size_class: trivial
## Conflicting files
- arch/arm/tools/syscall.tbl (the one the trial flagged)
- (merge-tree on its own also flags: arch/arm64/include/asm/unistd.h, arch/arm64/include/asm/unistd32.h, arch/x86/entry/syscalls/syscall_32.tbl, arch/x86/entry/syscalls/syscall_64.tbl, include/uapi/asm-generic/unistd.h)
- auto-merged with no conflict: include/linux/syscalls.h, include/linux/compat.h, kernel/sys_ni.c
## Why it conflicts
merge-tree on its own: conflicts in 6 files (tree `672656002a40da1437f958f5beeb26665d4f083f`).
The trial reported only `arch/arm/tools/syscall.tbl`, i.e. the other five had already been brought in line by an earlier series commit.

- Block 1, arch/arm/tools/syscall.tbl ~line 414 (tail of table): ours = sdm670 ends `424 pidfd_send_signal`, `434 pidfd_open` and has no `397 statx`; theirs = `397 statx`, `436 close_range`, then adds `441 common epoll_pwait2 sys_epoll_pwait2`. Pure append at end of file with different context.
- Block 2, arch/arm64/include/asm/unistd.h ~line 47: ours = `#define __NR_compat_syscalls 435`; theirs = `442` (a number bump, same line).
- Block 3, arch/arm64/include/asm/unistd32.h ~line 816: ours = nothing after `__SYSCALL(__NR_pidfd_open, ...)`; theirs = adds `__NR_close_range 436` + `__NR_epoll_pwait2 441` blocks.
- Block 4, arch/x86/entry/syscalls/syscall_32.tbl ~line 394: ours = ends at `434 i386 pidfd_open`; theirs = adds `436 i386 close_range`, `441 i386 epoll_pwait2`.
- Block 5, arch/x86/entry/syscalls/syscall_64.tbl ~line 343: ours = ends at `434 common pidfd_open`; theirs = adds `436 common close_range`, `441 common epoll_pwait2`.
- Block 6, include/uapi/asm-generic/unistd.h ~line 737: ours = blank line then `#undef __NR_syscalls` / `#define __NR_syscalls 435`; theirs = `__NR_close_range 436` + `__SYSCALL(...)`, `__NR_epoll_pwait2 441` + `__SC_COMP(...)`, then `#define __NR_syscalls 442`.
## Already in sdm670?
no. Evidence: `git grep -n 'epoll_pwait2' a30605a54f3b` returns **no hits at all** in the whole sdm670 tree (checked the full tree, not just one file). Second check: `git grep -n '__NR_epoll_pwait2\|sys_close_range' a30605a54f3b -- include/uapi/asm-generic/unistd.h arch/arm/tools/syscall.tbl` also returns nothing, so sdm670 has neither this syscall nor the `close_range` one.
Highest syscall number sdm670 uses on arm is 434 (`arch/arm/tools/syscall.tbl` @ a30605a54f3b:415), so 436/441 are free and do not collide.
## Proposed resolution
MERGE. Keep all of sdm670's existing lines and append only the new syscall:
- arch/arm/tools/syscall.tbl: after `434 common pidfd_open ...` add `441	common	epoll_pwait2		sys_epoll_pwait2`.
- include/uapi/asm-generic/unistd.h: insert `#define __NR_epoll_pwait2 441` + `__SC_COMP(__NR_epoll_pwait2, sys_epoll_pwait2, compat_sys_epoll_pwait2)` before the `#undef __NR_syscalls` block, and set `#define __NR_syscalls 442`.
- arch/arm64/include/asm/unistd.h: set `#define __NR_compat_syscalls 442`.
- arch/arm64/include/asm/unistd32.h, arch/x86/.../syscall_32.tbl, arch/x86/.../syscall_64.tbl: append the 441 entry (dead files for this target, but keep them consistent).
Do **not** add the `436 close_range` lines here: those belong to earlier series commit `495ac52546da` "BACKPORT: arch: wire-up close_range()" (also in the conflict list, `analysis/exyhyperbrick-trial/conflict_detail.tsv:58`). If that commit was resolved first, blocks 2-6 become context matches and only the append remains.
Build safety: `sys_epoll_pwait2` / `compat_sys_epoll_pwait2` are only declared here (include/linux/syscalls.h, include/linux/compat.h auto-merged) and defined as `-ENOSYS` stubs by the auto-merged `cond_syscall()` lines in kernel/sys_ni.c, so this commit builds on its own.
## Confidence
medium: step 4 was done and the conflict shape is a simple append, but I did not verify by build, and I am assuming the lead keeps the syscall rather than skipping it (nothing in eBPF itself calls `epoll_pwait2`; it is only required by the `required` label in conflict_detail.tsv:2).
## Problems
None