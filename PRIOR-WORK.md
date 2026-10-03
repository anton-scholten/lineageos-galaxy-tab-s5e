# Existing work by others (checked 2026-10-03, updated with the owner's own checks of the blocked sites)

This is what already exists online that a Tab S5e LineageOS 23.2 port can reuse or learn
from. Repos marked *inspected* were cloned and their history checked. The others are
known only from search results.

## Userspace: booting Android 16 on old kernels without kernel backports

| Project | What it is | Status | Fit for Tab S5e |
|---|---|---|---|
| [Doze-off/fuck-bpf](https://github.com/Doze-off/fuck-bpf) (*inspected*) | 28 patches, about 2,900 lines, branch `lineage-23.2`, Apache-2.0. Lets ≤4.19 kernels boot 16 QPR2: relaxes Connectivity/netd/bpf checks, handles devices without BPF, adds an `epoll_pwait2` fallback in BLASTBufferQueue, brings back 4.9 kernel configs and compatibility matrices | Active (last update 2026-03-08). 4.9 is "not tested yet" | **High.** Fastest way to a first boot (Track B). Not acceptable for official LineageOS |

## Kernel: 4.9 eBPF backports

| Project | What it is | Status | Fit |
|---|---|---|---|
| **[ExyHyperBrick/android_kernel_samsung_exynos9810](https://github.com/ExyHyperBrick/android_kernel_samsung_exynos9810)** (*inspected*), branch `lineage-23.2` | Galaxy S9/S9+/Note9 kernel, **Linux 4.9.337, the same version as the Tab S5e**. 2,599 commits on top of 22.2: eBPF to **5.15 level**, `close_range`, `epoll_pwait2`, `process_mrelease`, FUSE-BPF, userfaultfd, uclamp, and a BPF verifier test corpus. Device tree uses `ro.bpf.kver_override=5.15.178`. Also has a `lineage-24.0` branch | Active (2026-09-20). Ships in the unofficial LineageOS 23.2 for the S9 ([XDA](https://xdaforums.com/t/rom-s9-s9-note9-unofficial-lineageos-23-2-volte-vowifi-ota-14-08-2026.4763471/)). Author: Mathias Gluszczynski (krazey) | **Best match.** A trial replay onto the sdm670 kernel: **2,335 of 2,485 generic commits apply cleanly (94%), 150 conflict.** See [analysis/exyhyperbrick-trial](analysis/exyhyperbrick-trial/README.md) |
| `gitea.com/console-ramoops/kernel_qcom_sdm845-bpf-4.9` | msm-4.9 sdm845 kernel with BPF backports | Owner checked: only a `lineage-23.0` branch, nothing for 23.2 | Low. Older than the ExyHyperBrick series |
| [jojobear691/samsung_sdm845-kernel](https://github.com/jojobear691/samsung_sdm845-kernel) | Galaxy S9+ Snapdragon kernel, said to have "Android 16 BPF backports" | 404 (also confirmed by the owner) | Gone |
| [Andrey0800770/samsung_sdm845-kernel](https://github.com/Andrey0800770/samsung_sdm845-kernel) (*inspected*) | Samsung SDM845 kernel at 4.9.337 | No BPF backports | Low |

## Forks of the ExyHyperBrick kernel (checked 2026-10-03)

All 22 forks listed on GitHub were checked. Branches whose tips differ from upstream were
fetched and compared with upstream `lineage-23.2`, both by commit and by commit subject (to catch rebased copies).

**Result: none of the forks improves on upstream's eBPF/kernel-core work.**
Upstream `lineage-23.2` is the most complete version. Its own older dev branches
(`-bpf-5.15-clean`, `-full-core-recovery`, `-perf`) were already folded into it, apart from 3–13 minor commits.

| Fork | Relation to upstream `lineage-23.2` | Anything for the Tab S5e? |
|---|---|---|
| royd-jpg/Project_Chimera | Built on upstream's *older* `lineage-23.2-bpf-test` (July), plus ~670 commits, mostly KernelSU/SUSFS (root and root-hiding) and CI workflow edits | No. Older BPF base, plus root-hiding work |
| gavdoc38 | `lineage-23.2`/`24.0` plus ~59 commits: KernelSU/SUSFS and the procfs/IDA backports they need | No (root-related) |
| xxPlayground `lineage-23.2-test` | Older base (307 behind) plus ~150 S9-specific tweaks (vibrator, wake gestures, O3/MLGO build flags) | No |
| M0d-4, xthorfinnx `16` | Upstream plus a few commits | Maybe one: *"usb: gadget: f_fs: name FunctionFS instances after their configfs name"*. It's generic, and worth checking if adb/MTP misbehaves on 23.2 |
| alpha9810, greenlapis | Upstream plus extra I/O schedulers (from lawrun) | No |
| Welpyes, adam-616, dotcomdomain, raffifu | Upstream plus 0–3 cosmetic or S9-display commits | No |
| saifanidk, matei9, pranay-miyan, khoi-ttc, LeahsAndroidPlayground, rouquocbao, RealFX-Code | Snapshots of upstream's old `bpf-test` branches | No (superseded) |
| swapnanil1, Exynos9810-developers, Localhorst04 | Only branches up to `lineage-22.2`/`21` | No |

## Kernel: 4.14 to 5.4 parity (Phase 3 reference)

| Project | What it is | Fit |
|---|---|---|
| `LineageOS/android_kernel_samsung_sm8150` `lineage-20`, merged into `LineageOS/android_kernel_samsung_sm7125` `lineage-23.2` (*inspected*) | basamaryan's series, about 1,770 commits from 2024-02 to 2025-10: BPF, sk_msg/TLS, flow dissector, BTF, FUSE passthrough. Plus close_range and epoll_pwait2 | **High** for Phase 1 and Phase 3. The exact commit list is in [KERNEL-BACKPORT-PLAN.md](KERNEL-BACKPORT-PLAN.md) |

## Kernel uprev to 4.19 (Track C precedent)

| Project | What it is | Fit |
|---|---|---|
| [duckyduckG/android_kernel_xiaomi_sdm845_419](https://github.com/duckyduckG/android_kernel_xiaomi_sdm845_419); crDroid `android_kernel_xiaomi_sdm845` branch `16.0` (*inspected*: 4.19.325) | Xiaomi SDM845 moved to a 4.19 kernel. Unofficial LineageOS 23.2 releases. Matching `hardware_qcom_*` forks use `caf-sm8150` | Shows an uprev is possible. For SDM670 plus Samsung drivers it would be a new project |
| Mainline Linux `sdm670` (Pixel 3a, postmarketOS) | SDM670 SoC support in upstream Linux | Not usable for Android with Samsung drivers. Only a reference for hardware |

## Same SoC, other devices

- **Pixel 3a / 3a XL (sargo/bonito, SDM670, msm-4.9):** the owner checked: nothing usable. There's an [alpha LineageOS 23.0 GSI boot](https://xdaforums.com/t/alpha-gsi-16-0-lineageos-23-0-unofficial-pixel-3a-sargo-initial-bootable-base.4787590/) thread. Any Pixel 3a kernel BPF work would be the closest SoC match. It's worth watching.

## Tab S5e specific

- No Android 16 ROM for the Tab S5e turned up in searches. The owner confirmed this on the XDA forum and the official thread, and found no 23.x changes on LineageOS Gerrit. Evolution X and LineageOS stop at Android 15, and crDroid support has ended.
- [XDA: convert SM-T727V to SM-T725, unlock and install LineageOS 22.2](https://xdaforums.com/t/guide-convert-sm-t727v-to-sm-t725-unlock-bootloader-install-lineageos-22-2.4760328/post-90293075):
  a guide for **US Verizon models**, which normally can't be unlocked. See the README.

## Suggested next steps

1. Fork `android_kernel_samsung_sdm670`, then replay the ExyHyperBrick `lineage-23.2` series
   (skipping `[exynos9810]` commits). Resolve the ~150 conflicts listed in
   `analysis/exyhyperbrick-trial/results.tsv`, then fix the build.
2. Copy the defconfig changes and `ro.bpf.kver_override=5.15.178` (instead of 5.4.299).
3. Contact krazey (ExyHyperBrick) before publishing, and keep the authorship and
   `Signed-off-by` lines (cherry-pick `-x`). The kernel is GPL-2.0.
4. Meanwhile, Track B (fuck-bpf) is still a quick way to find the tablet-specific bugs.
