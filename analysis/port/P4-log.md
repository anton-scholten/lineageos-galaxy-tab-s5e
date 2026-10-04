<!-- task: P4 | agent: Space Bunny Free (opencode) | date: 2026-10-04 -->
# P4: kernel build loop

## Summary
`port/pick` builds. `Image.gz-dtb` links for both target defconfigs and `check-pick.py` reports
`problems: 0`. Fifteen build attempts were needed: one host-toolchain problem and fourteen kernel
fixes, all committed on `port/pick` with a `Fix-by:` trailer and pushed. `lineage-22.2` and
`lineage-23.2` in the kernel fork are still at `a30605a54f3b`.

| Target | Result | Size | Warnings |
|---|---|---|---|
| `gts4lvwifi_defconfig`, incremental | `EXIT=0`, `CAT arch/arm64/boot/Image.gz-dtb` | 18,736,159 B | 0 |
| `gts4lvwifi_defconfig`, from scratch in a fresh output tree | `EXIT=0`, `CAT arch/arm64/boot/Image.gz-dtb` | 18,735,923 B | 20 |
| `gts4lv_defconfig`, from scratch in a fresh output tree | `EXIT=0`, `CAT arch/arm64/boot/Image.gz-dtb` | 18,743,864 B | 20 |

The `gts4lvwifi` build was re-run from scratch in a separate output tree afterwards, so the
incremental result is not resting on stale objects. Its image is 236 bytes smaller than the
incremental one, which is the embedded build timestamp (`UTS_VERSION`, `__kbuild_utsversion`)
differing between the two runs. All 20 warnings in the from-scratch runs are
`DWARF2 only supports one section per compilation unit` from hand-written `.S` files in
`arch/arm64/`; the 22.2 baseline in [`../build-test/README.md`](../build-test/README.md) also had
20 warnings, so that count is unchanged.

Command for the primary target, unchanged from the spec:
`PATH=~/work/llvmbin:$PATH bash analysis/build-test/kbuild.sh ~/work/k670 ~/work/out ~/work/build.log`

## Host setup (no kernel change)
Debian's `llvm-19` package installs only versioned binaries (`llvm-nm-19`), but `kbuild.sh` runs
with `LLVM=1`, so `Makefile:359-361` looks for `llvm-nm`, `llvm-objdump`, `llvm-objcopy`,
`llvm-ar`, ... `~/work/llvmbin` holds `llvm-<tool>` -> `llvm-<tool>-19` symlinks and is
prepended to `PATH`. Without this `vdso.so.dbg` never links, `vdso-offsets.h` comes out empty and
`arch/arm64/kernel/signal.c` fails on `vdso_offset_sigtramp` - the first "error" of the run.
Nothing in the kernel tree or in `analysis/build-test/kbuild.sh` was changed for it.
`/tmp/opencode/p4build.sh` is the wrapper that sets `PATH` and calls `kbuild.sh`,
`/tmp/opencode/p4build-gts4lv.sh` is the same with `gts4lv_defconfig` and its own output tree
`~/work/out-gts4lv`, and `/tmp/opencode/p4build-wifi-clean.sh` does a from-scratch
`gts4lvwifi_defconfig` build in `~/work/out-clean`. All three are scratch files outside
this repo; the three build logs are `~/work/build.log`,
`~/work/build-gts4lv.log` and `~/work/build-clean.log`.

One stale build artefact also had to be removed once: `out/include/generated/vdso-offsets.h` had
been created empty by the very first run, and kbuild does not redo `prepare`/`vdso_prepare` once
they are up to date. Deleting the file makes `vdso_prepare` regenerate it.

## Attempts

| # | error (first in build.log) | file:line | fix | commit |
|---|---|---|---|---|
| host | `llvm-objdump: not found`, then `use of undeclared identifier 'vdso_offset_sigtramp'` | `arch/arm64/kernel/signal.c:246` | `PATH` symlinks; delete the empty stale `vdso-offsets.h` | (no commit) |
| 1 | `implicit declaration of function 'atomic_cond_read_relaxed'`, `use of undeclared identifier 'VAL'` | `kernel/bpf/helpers.c:678` | `select BPF_ARCH_SPINLOCK` on arm64 so the `arch_spin_lock()` branch is used | `5078de1ee272` |
| 2 | `incompatible function pointer types ... binder_set_context_mgr` (x4) | `security/selinux/hooks.c:6305-6308`, `security/security.c:152` | four binder `LSM_HOOK` entries back to `const struct cred *` | `56a6f0373c87` |
| 3 | `too many arguments to function call, expected single argument 'req'` | `fs/fuse/dev.c:560` | call this tree's one-argument `fuse_req_init_context()` | `a7f561e7e1b3` |
| 4 | `too many arguments to function call, expected 2, have 4`, `undeclared 'STATX_BASIC_STATS'`, undeclared `path`/`request_mask`/`flags` | `fs/fuse/backing.c:596,981,1270`, `fs/fuse/dir.c:3979` | use 4.9's two-argument `vfs_getattr()`; build the `struct path` from mnt+dentry | `d078fd143e53` |
| 5 | `cannot increment value of type 'atomic_t'` | `drivers/android/binder.c:5319` | `atomic_inc(&target_proc->tmp_ref)` | `238647ed4e7a` |
| 6 | `fatal error: 'linux/unicode.h' file not found` | `fs/unicode/utf8-core.c:8` | copy `include/linux/unicode.h` from the series head | `6996e6845fdb` |
| 7 | `implicit declaration of function 'task_util_est'` | `kernel/sched/core.c:1336` | the reviewer-specified WALT shim in `kernel/sched/sched.h` | `1cb9785b0d64` |
| 8 | `no member named 'modifier_count'` / `'format_mod_supported'` / `'modifiers'` / `'modifiers_property'` | `drivers/gpu/drm/drm_plane.c:93-140` | add upstream v4.14's four DRM declarations | `1c21d6589088` |
| 9 | `function definition is not allowed here` (x14) | `kernel/sched/cpufreq_schedutil.c:401` onwards | restore the two braces and the `cached_raw_freq` reset the merge dropped | `f58d0181a988` |
| 10 | `sizeof on array function parameter will return size of 'u32 *'` | `drivers/gpu/drm/msm/sde/sde_trace.h:182`, `drivers/media/platform/msm/sde/rotator/sde_rotator_trace.h:299` | spell the argument `u32 *data` instead of `u32 data[]` | `618c893a702a` |
| 11 | `use of undeclared identifier 'ARG_PTR_TO_RAW_STACK'` / `'ARG_CONST_STACK_SIZE'` | `kernel/trace/bpf_trace.c:290` | `bpf_probe_read_str_proto` to the post-rename arg types | `d1ff974a44f8` |
| 12 | `implicit declaration of function 'bpf_trace_rundst_bw'` (18-argument tracepoint) | `drivers/media/platform/msm/sde/rotator/sde_rotator_trace.h:25` | widen `COUNT_ARGS`, `__CASTn` and `BPF_TRACE_DEFN_x` from 12 to 18 | `c8f303abafce` |
| 13 | `use of undeclared identifier '__SEQ_0_11'` | `kernel/trace/bpf_trace.c:1876` | leftover second use of the old sequence name | `62e4f2ade22f` |
| 14 | `implicit declaration of function 'bpf_trace_run18'` | `drivers/media/platform/msm/sde/rotator/sde_rotator_trace.h:25` | declare `bpf_trace_run13()`..`bpf_trace_run18()` in `include/linux/trace_events.h` | `801f3f20e54a` |

## Escalated
Nothing was escalated. Six commits carry a `Needs-review:` trailer because they were judgment
calls rather than mechanical error fixes; each states its alternatives and why they were worse.
The reviewer should read these first.

1. **`5078de1ee272`** - `select BPF_ARCH_SPINLOCK` on arm64 (`arch/arm64/Kconfig:246`).
   The first real error was in `kernel/bpf/helpers.c`, a directory P4 must not change. The broken
   code is `atomic_cond_read_relaxed(l, !VAL)` in the `#else` half of `__bpf_spin_lock()`; `VAL`
   does not exist in 4.9, in the series head, or in upstream (kernel/bpf/helpers.c:255 in
   torvalds/linux v5.1 has the same text). That half is only reached because 4.9 arm64 has no
   queued spinlocks, and every mainstream arch does, so upstream has never compiled it.
   `config BPF_ARCH_SPINLOCK` was added by the series itself (kernel/Kconfig.locks:245 @
   baa585f67e0e) and is read in exactly one place, that `#if`; nothing selected it. arm64 satisfies
   what it exists for: `arch_spinlock_t` is a 4-byte `{u16 owner; u16 next;}` and
   `__ARCH_SPIN_LOCK_UNLOCKED` is `{0,0}`. Alternatives: (a) edit `kernel/bpf/` (forbidden),
   (b) define the missing `VAL` next to `atomic_cond_read_relaxed()` in
   `include/linux/atomic.h:653` - allowed, but it leaves a `VAL` macro in every translation unit,
   (c) `select ARCH_USE_QUEUED_SPINLOCKS` - changes spinlock behaviour for the entire 4.9 kernel.
   **A reviewer may prefer (b).**
2. **`a7f561e7e1b3`** - `fuse_req_init_context(fc, req)`.
   The two-argument definition lives in the ExyHyperBrick base (fs/fuse/dev.c:117 @ d54533f1546b)
   and comes with Android's fuse `pid_ns` work. The alternative is that five-file backport
   (fs/fuse/fuse_i.h:474, fs/fuse/inode.c:639,648, fs/fuse/dev.c:121,1275,1889,
   fs/fuse/file.c:2132,2195), which changes which pids the FUSE daemon and setxattr see.
3. **`d078fd143e53`** - 4.9's two-argument `vfs_getattr()` in the fuse-bpf backing helpers.
   The full alternative is 4.11's four-argument `vfs_getattr()`/`vfs_getattr_nosec()` (fs/stat.c:105
   @ d54533f1546b), `STATX_*` in `include/uapi/linux/stat.h`, a new `inode_operations.getattr`
   and about twenty converted call sites in fs/9p, fs/overlayfs, fs/ecryptfs, fs/nfsd and
   `drivers/`. That is a core VFS change and far more than a build fix should decide. The
   adaptation is behaviour-identical on 4.9: at two of the three sites the series itself passed
   `STATX_BASIC_STATS, 0`, which in 4.11 means "every basic attribute" and is what the 4.9
   two-argument form always returns.
4. **`1c21d6589088`** - the four DRM format-modifier declarations.
   `c72864d9d467` ("drm: Create a format/modifier blob") has a prerequisite that exists in neither
   the series nor the exy base; its own message lists the two files it conflicted on and could not
   apply. Upstream v4.14's declarations were added instead. **Note the feature is half-present by
   the series' own design**: there is no `drm_mode_mod_get()` and no `DRM_MODE_MOD_*` anywhere in
   baa585f67e0e, so no userspace can consume the `IN_FORMATS` blob this now creates. If the reviewer
   would rather not add an unusable property, the alternatives are dropping the
   `drivers/gpu/drm/drm_plane.c` hunk of `c72864d9d467` (deleting code, which P4 may not do) or
   backporting the whole upstream 4.14 modifier series. Nothing in the tree is disabled by this
   commit: `create_in_format_blob()` only runs under `if (config->allow_fb_modifiers)`, which no
   driver sets, and takes the "can't determine support, bail" branch because
   `format_mod_supported` is NULL everywhere.
5. **`618c893a702a`** - `u32 *data` instead of `u32 data[]` in two sdm670 tracepoint prototypes.
   With `CONFIG_BPF_EVENTS=y`, `include/trace/bpf_probe.h:39` does `UINTTYPE(sizeof(x))` on every
   tracepoint argument, and `sizeof` on an adjusted array parameter is exactly what clang rejects.
   The two prototypes are unchanged from `a30605a54f3b`; they compiled before only because
   `bpf_probe.h` did not exist. In a parameter list the two spellings declare the same function
   type, so nothing is cast away.
6. **`c8f303abafce`**, **`62e4f2ade22f`**, **`801f3f20e54a`** - widening the BPF native-tracepoint
   argument limit from 12 to 18.
   `rot_entry_template` has 18 `TP_ARGS` and `iwl-devtrace-iwlwifi.h:128` has 17; upstream still
   stops at 12 (torvalds/linux v6.6 include/trace/bpf_probe.h:41) because no upstream tracepoint
   is that wide. A scan of every `TP_ARGS` in the tree found those five sites and no others above
   12. `COUNT_ARGS` (include/linux/kernel.h) has one other user,
   `security/apparmor/include/path.h:48`, and results for 0..12 arguments are unchanged. The
   alternative was shrinking the SDE rotator tracepoint, which would change its perf event format
   and what trace-cmd and the Qualcomm userspace tools see.

## Not done / out of scope
- `analysis/port/STATUS.md`, `WORKLOG.md`, `HANDOVER.md` and the other shared files were not
  touched.
- The 4.14 `ew_open` defconfigs were not built; the task names `gts4lvwifi_defconfig` and
  `gts4lv_defconfig`, and P3 merged the same fragment into all four.
- Nothing about runtime behaviour was verified; this loop only got the tree to link.

## Problems
None. No command failed twice, and no error needed a forbidden fix.