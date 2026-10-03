# Trial: ExyHyperBrick 4.9 eBPF series on the Tab S5e kernel

**Question:** how much of the ExyHyperBrick Galaxy S9 (Exynos 9810, Linux
4.9.337) LineageOS 23.2 kernel work applies directly to the Tab S5e kernel?

**Inputs**

| | Repo | Ref | Commit |
|---|---|---|---|
| Target | `LineageOS/android_kernel_samsung_sdm670` | `lineage-22.2` | `a30605a54f3b` |
| Series base | `ExyHyperBrick/android_kernel_samsung_exynos9810` | `lineage-22.2` | `d54533f1546b` |
| Series head | `ExyHyperBrick/android_kernel_samsung_exynos9810` | `lineage-23.2` | `baa585f67e0e` |

The series is `lineage-22.2..lineage-23.2`: 2,599 non-merge commits, mostly by
Mathias Gluszczynski (krazey). It includes:
- eBPF up to the level of Linux **5.15**, including ring buffer, BTF, CAP_BPF, sk_storage, sockmap/sk_msg, XDP sockets and BPF LSM.
- `close_range`, `epoll_pwait2` and `process_mrelease`.
- FUSE-BPF, userfaultfd, uclamp and PSI fixes.
- A Linux 5.15.178 BPF verifier test corpus.

The matching device tree sets `ro.bpf.kver_override=5.15.178`. The kernel also
reports `5.15.178` from `uname()` to `bpfloader`, `netbpfload`, `netd` and the
UprobeStats loader only (`kernel/sys.c`).

**Method** ([`trial.py`](trial.py)): replay every commit in order onto the
sdm670 tree with `git merge-tree` (a 3-way merge in memory, the same thing
cherry-pick does), stacking each result on the previous one. Commits tagged
`[exynos9810]`/`[9810]`, and commits that only touch Exynos-only directories, were skipped.

## Results

| Outcome | Commits |
|---|---|
| Applies cleanly | **2,335** (94% of those tried) |
| Conflicts | **150** |
| Skipped: Exynos device-specific | 114 |

The full per-commit list is in [`results.tsv`](results.tsv). For conflicts it also lists the conflicting files.

Conflicts by area (number of conflicting files):
- `include/linux` 27, `kernel/sched` 14, `net/ipv4` 13, `net/ipv6` 12
- `include/uapi` 11, `arch/arm64` 11 (including `gts4lv*_defconfig`)
- `fs/fuse` 10, `lib/zstd` 9, `net/core` 7, `kernel/time` 7
- `fs/userfaultfd.c` 6, `mm/vmalloc.c` 5, `kernel/bpf` 4

About 63 of the conflicting commits are BPF or networking. Many of those conflict because
`sdm670` already carries part of the same change from `android-4.9-q` (for example
`BPF_MAP_TYPE_LRU_HASH`, the TCP fast-open sysctls, and nl80211 WPA3). Those just
need the duplicate dropped.

## What this does *not* prove

- **"Clean" only means it merges without conflicts.** It doesn't mean it builds or runs.
  Qualcomm/Samsung code in sdm670 that calls changed kernel APIs (networking drivers,
  `rmnet`, `qcacld`, IPA, `sec_net`) will still need build fixes.
- **Conflicted commits were committed with conflict markers.** So later commits
  touching the same files may conflict more than shown here, or less.
- Nothing was compiled or booted. That needs the Android kernel toolchain and the tablet.

## What it means for the plan

Track A no longer needs Phases 2–3 to be done from scratch. They become
**porting an existing, device-tested 4.9 series**:
- about 150 conflicts to resolve by hand
- then build fixes for the Qualcomm/Samsung drivers
- then device testing.

Rough estimate: **3–6 weeks** for one experienced developer, instead of 3–4
months. See [KERNEL-BACKPORT-PLAN.md](../../KERNEL-BACKPORT-PLAN.md).

Defconfig options the Exynos series turns on for 23.2, to copy into
`gts4lv_defconfig`/`gts4lvwifi_defconfig`:

```
CONFIG_ANDROID_BINDERFS=y  CONFIG_BPF_LSM=y        CONFIG_CFQ_GROUP_IOSCHED=y
CONFIG_DEBUG_INFO_BTF=y    CONFIG_FUSE_BPF=y       CONFIG_KPROBES=y
CONFIG_NET_ACT_BPF=y       CONFIG_PSI=y            CONFIG_UCLAMP_TASK=y
CONFIG_UCLAMP_TASK_GROUP=y CONFIG_UNICODE=y        CONFIG_USERFAULTFD=y
CONFIG_XDP_SOCKETS=y       CONFIG_XDP_SOCKETS_DIAG=y
# and disabled: CONFIG_USER_NS, CONFIG_RT_GROUP_SCHED, CONFIG_SCHED_TUNE (replaced by uclamp)
```

`CONFIG_DEBUG_INFO_BTF` needs `pahole` in the kernel build environment.
