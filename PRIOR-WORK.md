# Existing work by others (checked 2026-10-03)

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
| `gitea.com/console-ramoops/kernel_qcom_sdm845-bpf-4.9` | msm-4.9 sdm845 kernel with BPF backports, `lineage-23.0` branch | Couldn't inspect (gitea is blocked from this environment) | **High.** Same msm-4.9 CAF base as sdm670. Check this first for Phase 2/3 |
| [jojobear691/samsung_sdm845-kernel](https://github.com/jojobear691/samsung_sdm845-kernel) | Galaxy S9+ Snapdragon (SM-G965W) 4.9 kernel described as having "Android 16 BPF backports" | Repo now **returns 404** (deleted or private). Ask the author on XDA, or look for forks | **Very high, if recoverable.** Samsung's own SDM845 4.9 tree is the closest relative of the Tab S5e kernel |
| [Andrey0800770/samsung_sdm845-kernel](https://github.com/Andrey0800770/samsung_sdm845-kernel) (*inspected*) | Same Samsung SDM845 kernel, at 4.9.337 like ours | **No** BPF backports in `main`/`tmpdev` (41 BPF commits, all old) | Low for BPF. Useful as a build-fix reference for Samsung 4.9 trees with newer clang |
| Exynos 9810 (Galaxy S9) unofficial LineageOS 23.2 ([XDA](https://xdaforums.com/t/rom-s9-s9-note9-unofficial-lineageos-23-2-volte-vowifi-ota-14-08-2026.4763471/)) | Search results say its 4.9 kernel has "an eBPF backport initially done by ivanmeler, fixed, tested and updated for Android 16" | Couldn't inspect (XDA is blocked from here). Source link is in the thread | **Medium-high.** A 4.9 eBPF series tested on Android 16. Exynos, but the BPF/net core is the same |

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

- **Pixel 3a / 3a XL (sargo/bonito, SDM670, msm-4.9):** there's an [alpha LineageOS 23.0 GSI boot](https://xdaforums.com/t/alpha-gsi-16-0-lineageos-23-0-unofficial-pixel-3a-sargo-initial-bootable-base.4787590/) thread. Any Pixel 3a kernel BPF work would be the closest SoC match. It's worth watching.

## Tab S5e specific

- No Android 16 ROM for the Tab S5e turned up in searches. Evolution X and LineageOS stop at Android 15, and crDroid support has ended.
- [XDA: convert SM-T727V to SM-T725, unlock and install LineageOS 22.2](https://xdaforums.com/t/guide-convert-sm-t727v-to-sm-t725-unlock-bootloader-install-lineageos-22-2.4760328/post-90293075):
  a guide for **US Verizon models**, which normally can't be unlocked. See the README.

## Suggested next steps

1. Get the eBPF source from the Exynos 9810 LineageOS 23.2 thread, and the
   console-ramoops sdm845 repo. Diff both against `android_kernel_samsung_sdm670`.
2. Ask on XDA whether jojobear691's Samsung SDM845 BPF tree has a mirror.
3. Meanwhile, build 23.2 with this repo's patches plus fuck-bpf (Track B) to find the
   device-side bugs.
