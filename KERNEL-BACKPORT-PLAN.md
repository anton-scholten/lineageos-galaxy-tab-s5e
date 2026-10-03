# Plan: making LineageOS 23.2 run on the Galaxy Tab S5e (all variants)

All Tab S5e models (SM-T720/T720N Wi-Fi and SM-T725/T725C/T725N/T727* LTE) use
the same SoC (SDM670) and the **same kernel**,
`LineageOS/android_kernel_samsung_sdm670` (Linux 4.9.337, merged with
`android-4.9-q`). The kernel work below unblocks every variant at once.

## Why it doesn't boot today

On lineage-23.2, Android 16 enforces kernel versions in two places in
`packages/modules/Connectivity`:

| File | Check | Result on 4.9 |
|---|---|---|
| `bpf/loader/NetBpfLoad.cpp` | U needs ≥4.14, V needs ≥4.19, 25Q2 needs ≥5.4 | `netbpfload` exits with 4, 5 or 6, so no networking BPF |
| `bpf/netd/BpfHandler.cpp` | the same three checks | netd init fails |

LineageOS relaxed only the 25Q4 (5.10) check (`8e92e094e9 NetBpfLoad: Relax
5.10 kernel requirement`). Older kernels pass the remaining checks by
**reporting** a 5.4 version through `ro.bpf.kver_override` after the real
eBPF features have been backported.

The BPF programs themselves still contain 4.9 fallback paths
(`KVER_4_9` variants in `bpf/progs/netd.c` and `clatd.c`), because the
Connectivity mainline module still has to run on Android 12 devices with 4.9
kernels. On 22.2 these version checks were only warnings, which is why 22.2
boots on this tablet.

## Two tracks

### Track A: kernel backports to `android12-5.4` parity (the official LineageOS route)

This is the only route LineageOS accepts for official builds. It's a lot of
work but mechanical, and there's a reference to follow: basamaryan's 4.14
series in `LineageOS/android_kernel_samsung_sm8150` (`lineage-20`), merged into
`android_kernel_samsung_sm7125` for 23.x. That series has about 1,770
commits: 1,364 `UPSTREAM`, 347 `BACKPORT`, plus fix-ups, and about 970 of them touch BPF.

#### Phase 0: setup (about 1 week)
1. Fork `android_kernel_samsung_sdm670` from `lineage-22.2`, creating branch `lineage-23.2`.
2. Build a 23.2 tree with this repo's patches 0001–0003, and check that the 22.2
   kernel boots far enough to reach `netbpfload`. Expect it to stop there.
3. Get a test setup working:
   - `adb logcat -b all | grep -iE 'bpf|netd'`
   - `atest bpf_existence_test netd_integration_test kernel_test` (in
     `system/netd/tests`, these include `TestKernel54`)
   - a UART or `pstore`/`last_kmsg` capture for kernel panics.
4. Pin the kernel clang version (`TARGET_KERNEL_CLANG_VERSION`) so compiler
   changes don't get mixed up with backport bugs.

#### Phase 1: small syscall backports (about 2–3 days)
Cherry-pick these from `android_kernel_samsung_sm7125` `lineage-23.2`, in this order:

```
039c8dfeafed BACKPORT: open: add close_range()
dba54db2587f BACKPORT: close_range: add CLOSE_RANGE_UNSHARE
21f7bdc33a7d BACKPORT: arch: wire-up close_range()
de534ec60a68 UPSTREAM: fs, close_range: add flag CLOSE_RANGE_CLOEXEC
c6bf0a31f426 UPSTREAM: close_range: unshare all fds for CLOSE_RANGE_UNSHARE | CLOSE_RANGE_CLOEXEC
238338ad0578 UPSTREAM: file: fix close_range() for unshare+cloexec
1e7b26a5876b UPSTREAM: file: simplify logic in __close_range()
666465c7b927 UPSTREAM: alloc_fdtable(): change calling conventions.
7d98c8a7b039 UPSTREAM: fs: fd tables have to be multiples of BITS_PER_LONG
0a3f6083e5e3 UPSTREAM: fs: fix fd table size alignment properly
c654b3cbdb48 UPSTREAM: close_range(): fix the logics in descriptor table trimming
26ffcf8ca2f5 BACKPORT: file: let pick_file() tell caller it's done
b7fdc7ec2d37 UPSTREAM: fs: add do_epoll_*() helpers; remove internal calls to sys_epoll_*()
7ab1864eef3f BACKPORT: epoll: convert internal api to timespec64
f56f365ba0d4 UPSTREAM: epoll: add syscall epoll_pwait2
efa39f0a99f8 BACKPORT: epoll: wire up syscall epoll_pwait2
623ece6f0762 BACKPORT: epoll: fix compat syscall wire up of epoll_pwait2
cf09b7600001 fixup! BACKPORT: epoll: wire up syscall epoll_pwait2
```

On 4.9, expect conflicts in `arch/arm64/include/asm/unistd*.h`,
`include/uapi/asm-generic/unistd.h` (4.9's syscall numbering ends earlier, so
fill in the gaps with `sys_ni_syscall`) and `fs/file.c`.

#### Phase 2: BPF from 4.9 to 4.14 (the hardest part, about 4–8 weeks)
The 4.14 series assumes a 4.14 BPF core. 4.9 is missing the 4.10–4.14
verifier rewrite and the features built on it: `BPF_JLT/JLE/JSLT/JSLE`,
`bpf_prog_info`/`BPF_OBJ_GET_INFO_BY_FD`, map-in-map, `BPF_PROG_TYPE_SOCK_OPS`,
`BPF_PROG_TYPE_SK_SKB`, `BPF_F_NUMA_NODE`, prog/map IDs, `BPF_PROG_ATTACH` flags,
`bpf_skb_adjust_room`, `bpf_get_socket_cookie/uid`, LPM trie and
`BPF_MAP_TYPE_DEVMAP`.

There are two ways to do it. Pick one:
- **(a) Commit-by-commit.** Generate the list from upstream with
  `git log --reverse --no-merges v4.9..v4.14 -- kernel/bpf include/linux/bpf*.h
  include/linux/filter.h include/uapi/linux/bpf*.h net/core/filter.c
  net/core/sock.c kernel/cgroup* net/ipv4/af_inet.c net/ipv6/af_inet6.c
  arch/arm64/net tools/include/uapi/linux/bpf.h`, then drop the XDP and driver
  commits, which Android doesn't need. Cherry-pick in order, and build plus
  boot-test every ~50 commits. This is slow, but bugs are easy to bisect.
- **(b) Subsystem transplant.** First check the community 4.9 eBPF backports.
  The best candidate is the sdm845 4.9 series
  (`gitea.com/console-ramoops/kernel_qcom_sdm845-bpf-4.9`), since sdm845 is
  the same `msm-4.9` CAF base. If it's usable, port its commits directly.
  This is the fastest path if that series is complete.

Watch for:
- The arm64 BPF JIT (`arch/arm64/net/bpf_jit_comp.c`) must keep up with the
  new instructions. Otherwise turn off `CONFIG_BPF_JIT_ALWAYS_ON` until it does.
- Things in Samsung's tree that hook into networking: the `ANDROID_PARANOID_NETWORK`,
  KNOX `ncm` and `sec_net` code. The sm8150 series had to fully revert
  `ANDROID_PARANOID_NETWORK`.
- `cgroup` v1 vs v2 `bpf` attachment. Android 16 requires the cgroup2 mount
  at `/sys/fs/cgroup`.

#### Phase 3: BPF from 4.14 to 5.4 parity (about 3–5 weeks)
Replay the sm8150 `lineage-20` series by basamaryan, from 2024-02-13
(`UPSTREAM: fs: add RWF_APPEND`) to 2025-10-02 (`UPSTREAM: seccomp, bpf:
disable preemption before calling into bpf prog`):
- `git log --reverse --committer=basamaryan` on that branch gives the list.
- Include its prerequisites: TCP stats, sk_msg/TLS, flow_dissector, umh/bpfilter,
  sk_storage, BTF, `PERF_RECORD_BPF_EVENT` and FUSE passthrough.
- Skip the 4.14-only reverts (e.g. "Squashed revert of 4.14 tls backports"), and
  check each one against what 4.9 actually contains.

Check after this phase: `bpf_existence_test` passes and `kernel_test`
`TestKernel54` passes with `ro.bpf.kver_override=5.4.299`.

#### Phase 4: enable and check (about 1–2 weeks)
1. Apply `patches/device/samsung/gts4lv-common/0004-…Override-kernel-BPF-version.patch`.
2. Check traffic accounting (Settings → Data usage), per-app network
   restrictions, VPN lockdown, tethering offload, clat/464xlat (LTE) and Wi-Fi Display.
3. Leave it running for 24 hours or more. BPF verifier or JIT bugs tend to show up as slow memory corruption.
4. Send the kernel upstream to LineageOS Gerrit
   (`android_kernel_samsung_sdm670`, a new `lineage-23.2` branch), and work with the maintainers
   (LuK1337 and bgcngm) on official support.

**Total for Track A:** about 3–4 months for one experienced kernel developer. It's
much shorter if the sdm845 4.9 series can be reused.

### Track B: relax the userspace version checks (unofficial, quick)

Patch the hard `return` statements in `NetBpfLoad.cpp` and `BpfHandler.cpp`
(table above) back into warnings, the way AOSP 15 had them. Leave
`ro.bpf.kver_override` unset, so the 4.9 BPF fallbacks get used, as on 22.2.

- **Good:** a few lines of change in one repo. You can boot 23.2 in days, and
  start fixing the remaining device bugs alongside Track A.
- **Bad:** it turns off a kernel-compatibility safeguard on purpose, and
  Google doesn't test this combination. Features built on newer hooks
  (getsockopt/setsockopt and connect/sendmsg cgroup hooks, socket-release
  cleanup) silently stop working. That weakens per-app network
  restrictions and accounting compared with a real 5.4-parity kernel. LineageOS
  won't accept it for official builds, so it's only fit for personal
  or testing use.
- This patch **is not included** in this repo. See the README for status.

Recommended: use Track B as a temporary way to test the rest of the port, and
Track A as the real solution.

## Device-side work still needed (both tracks)

- `patches/device/samsung/gts4lv-common/0001–0003`: done.
- **FCM level.** In lineage-23.2, `compatibility_matrix.5.xml` is an
  empty placeholder ("Android R FCM has been deprecated"). Bump
  `manifest.xml` `target-level` from 5 to 6.
  - Wi-Fi model: every `android.hardware.*` HAL is already within matrix 6,
    except soundtrigger 2.2. Matrix 6 lists 2.3, but sm7125-common runs
    2.2 at level 6 too.
  - LTE model: the RIL declares `android.hardware.radio@1.4::IRadio`, and matrix 6 wants
    1.5–1.6. Check this against the blobs. If `check_vintf` fails, keep LTE
    at level 5 for now.
- **LTE (`gts4lv`) device tree:** needs no extra changes beyond the common patches. It
  uses the AIDL `vibrator-service.legacy` (still in `hardware/lineage/interfaces`)
  and the Samsung RIL (`hardware/samsung/ril`, still on 23.2).
- Fix the sepolicy neverallows and blob linkage problems the first build reports.

## Milestones

| # | Milestone | Proves |
|---|---|---|
| M1 | 23.2 builds for gts4lvwifi and gts4lv | Device trees are correct |
| M2 | Boots to UI (Track B, or Track A once finished) | Userspace and HALs work |
| M3 | Kernel passes `bpf_existence_test` and `TestKernel54` | Track A is done |
| M4 | Override enabled, 24 h soak passes, all features checked | Ready for daily use |
| M5 | Merged on LineageOS Gerrit, added to hudson | Official 23.2 |
