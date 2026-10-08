# Unofficial LineageOS 23.2 for Galaxy Tab S5e (SM-T720 `gts4lvwifi`, SM-T725/T727 `gts4lv`)

> I used AI to make this happen. The tablet I have works well, no bugs so far.  
> Human TL;DR:  
> If your tablet has LineageOS 22.2 then follow the official LineageOS installation steps but use the provided Recovery and ROM in the latest release of this repo.
> 1. Backup the data on your tablet and remove your Google account from it.
> 2. Boot into Download mode
> 3. Flash the correct 23.2 recovery for your tablet
> 4. Boot into recovery, check it says 23.2.
> 5. ⚠️ "Factory reset"/"Format data" the tablet (make sure you have a backup!).
> 6. Select on the tablet "Apply update", "Apply from ADB", and sideload the correct ROM for your tablet using your PC.
> 7. Flash MindTheGapps at this time if you want them.
> 8. Reboot and you should be good.

Android 16 needs kernel features a 4.9 kernel doesn't have (mainly modern eBPF).
This port has two parts: a **kernel backport** (the ExyHyperBrick 4.9 eBPF series, about 2,450 commits) and a **full ROM** (device tree, blobs and fixes for Android 16).

## Status (2026-10-08)

| Model | State |
|---|---|
| **SM-T720 / T720N** (Wi-Fi, `gts4lvwifi`) | ✅ **Works.** |
| **SM-T725 / T725C / T725N / T727\*** (LTE, `gts4lv`) | 🔨 **Built (2026-10-08), untested** (I don't have an LTE tablet) |

**Works on SM-T720:** pretty much everything.  
**No tested:** screen casting (Miracast).  
**Not working:** ANT+. LTE builds: no VoLTE/VoWiFi (calls fall back to 2G/3G).

| Part | Source |
|---|---|
| Kernel | [android_kernel_samsung_sdm670 `lineage-23.2`](https://github.com/anton-scholten/android_kernel_samsung_sdm670/tree/lineage-23.2): the ExyHyperBrick series (eBPF at Linux 5.15 level, `close_range`, `epoll_pwait2`, FUSE-BPF, userfaultfd, uclamp, PSI) ported onto the Tab S5e kernel, plus an SELinux policy-loading fix |
| Device tree | [android_device_samsung_gts4lv-common `lineage-23.2`](https://github.com/anton-scholten/android_device_samsung_gts4lv-common/tree/lineage-23.2) |
| Blobs | [proprietary_vendor_samsung_gts4lv-common `lineage-23.2`](https://github.com/anton-scholten/proprietary_vendor_samsung_gts4lv-common/tree/lineage-23.2) (TheMuppets' 22.2 blobs + one patched Wi-Fi Display library) |

**There is no official public download yet.** Until a release is announced, use official LineageOS 22.2 for daily use (unless you really want Android 16, then use this repo).
Progress: [HANDOVER.md](HANDOVER.md).

> ⚠️ **`/metadata` on OMR.** Android 16 needs a `/metadata` partition, which this tablet doesn't have. Like official
> LineageOS on the Galaxy S10, this port uses Samsung's unused **OMR** partition (20 MB) as `/metadata`.
> The 23.2 recovery's *Format data* formats it for you, so follow the install steps exactly.
> Going back to stock firmware with Odin/samloader restores OMR.

## Prior work used

Big thanks to all the following:

| Project | Author | What we used |
|---|---|---|
| [ExyHyperBrick/android_kernel_samsung_exynos9810](https://github.com/ExyHyperBrick/android_kernel_samsung_exynos9810) | Mathias Gluszczynski (krazey) | **The kernel backport.** Its `lineage-22.2..lineage-23.2` series (for Galaxy S9 on Linux 4.9.337) was cherry-picked with `-x`, keeping every original author. [(fork as backup)](https://github.com/anton-scholten/android_kernel_samsung_exynos9810) |
| [ExyHyperBrick/android_device_samsung_exynos9810-common](https://github.com/ExyHyperBrick/android_device_samsung_exynos9810-common) | krazey | Reference for the 4.9-specific 23.2 device changes, e.g. `ro.bpf.kver_override=5.15.178` |
| [LineageOS gts4lv trees](https://github.com/LineageOS/android_device_samsung_gts4lv-common) (`gts4lv-common`, `gts4lv`, `gts4lvwifi`) and [kernel](https://github.com/LineageOS/android_kernel_samsung_sdm670) | LineageOS maintainers | The 22.2 base |
| [LineageOS sm7125-common](https://github.com/LineageOS/android_device_samsung_sm7125-common) and [sm7125 kernel](https://github.com/LineageOS/android_kernel_samsung_sm7125) | LineageOS (basamaryan and others) | Reference for official Samsung Qualcomm 22.2 to 23.2 changes |
| [LineageOS hardware/samsung](https://github.com/LineageOS/android_hardware_samsung) | LineageOS | Samsung HALs (used as-is, `lineage-23.2`) |
| [TheMuppets vendor blobs](https://github.com/TheMuppets/proprietary_vendor_samsung_gts4lv-common) | TheMuppets | Proprietary Samsung/Qualcomm files. Forked; one library (`libwfdservice.so`) patched to load our shim |
| [LineageOS exynos9820-common](https://github.com/LineageOS/android_device_samsung_exynos9820-common/commit/b6a153f436c88d8ef73a24d711a8db5cd7500b4e) | Tim Zimmermann (Linux4) | Idea to use Samsung's OMR partition as `/metadata` |
| [LineageOS hardware/lineage/compat](https://github.com/LineageOS/android_hardware_lineage_compat) | LineageOS | The existing `libwfdservice_shim`; ours covers the newer blob |
| [luk1337/gts4lv-fw](https://github.com/luk1337/gts4lv-fw/releases) | luk1337 | Stock Android 11 firmware images for the install steps (and big thanks for keeping the tablet updated all these years to 22.2 !) |
| [Doze-off/fuck-bpf](https://github.com/Doze-off/fuck-bpf), [duckyduckG 4.19 kernel](https://github.com/duckyduckG/android_kernel_xiaomi_sdm845_419) | | Studied as alternatives; not used |

Licences: kernel GPL-2.0 (full source in the kernel fork), device trees Apache-2.0.

---

## Install / upgrade

**You need:** a PC with `adb`, a good USB-C cable, battery above 50%, and the files for your device (wifi or LTE).

Follow the official LineageOS install guide for your model but with the changes listed in the table below.  
[Wi-Fi (`gts4lvwifi`) guide](https://wiki.lineageos.org/devices/gts4lvwifi/install/)  
[LTE (`gts4lv`) guide](https://wiki.lineageos.org/devices/gts4lv/install/)

| Step in the official guide | Do this instead |
|---|---|
| Download files | Take the ROM zip, `recovery-*.img` and `vbmeta-*.img` for **your codename** from the [latest release](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/releases/latest). Never mix Wi-Fi and LTE files |
| Flash recovery | Flash **the 23.2 recovery**. The 22.2 recovery can't install 23.2. Odin, Heimdall or [samloader](https://github.com/topjohnwu/samloader-rs/releases/latest) (`samloader flash --partition RECOVERY recovery-*.img --no-reboot`) all work |
| Factory reset | **Required**, also when coming from official 22.2 (different signing keys). ⚠️ Erases all data. It also formats `/metadata` (the OMR partition), which Android 16 needs |
| Install Google Apps | Use [MindTheGapps **16.0.0** arm64](https://github.com/MindTheGapps/16.0.0-arm64/releases/latest), sideloaded before the first boot |
| Sideload | *"Signature verification failed"* is expected: answer *Yes*. Stopping at 47% with `adb: failed to read command: Success` is normal |

Coming from Samsung stock: do the official guide's unlock and `vbmeta` steps first (with our `vbmeta-*.img`).  
Coming from LineageOS 22.2: skip the unlock and `vbmeta` steps.  
First boot can take up to 15 minutes.

**Stuck in Download mode?**  
Unplug USB, hold *Vol Down + Power* until the screen goes black, then immediately hold *Vol Up + Power* to enter recovery. If you keep USB plugged in you will get back into Download mode again.

**Boot loop?**  
Get logs from recovery first (`adb shell cat /proc/last_kmsg`, see [TESTING.md](TESTING.md)) and report them.
Then ⚠️ *Format data* and sideload again, or go back to 22.2 by flashing its recovery and zip (always erases data).

---

## Building (developers)

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --no-clone-bundle
mkdir -p .repo/local_manifests
cp <this repo>/local_manifests/gts4lv-common.xml .repo/local_manifests/
cp <this repo>/local_manifests/gts4lvwifi.xml .repo/local_manifests/   # LTE: gts4lv.xml
repo sync -c -j$(nproc)
source build/envsetup.sh && brunch gts4lvwifi   # LTE: brunch gts4lv
```

The build outputs `lineage-23.2-*-UNOFFICIAL-<codename>.zip`, `recovery.img`
and `vbmeta.img` to `out/target/product/<codename>/`. The manifests point at our kernel, device and vendor forks
(the vendor fork carries the patched WFD library), so no extra patches are needed. The Wi-Fi build completes with
no errors.

Needs ~300 GB disk and 16 GB+ RAM (32 GB recommended). Install `git-lfs` **before** `repo sync`. Full recipe: [analysis/port/BUILD-HANDOFF.md](analysis/port/BUILD-HANDOFF.md).

## Repo contents

| Path | What |
|---|---|
| `HANDOVER.md` | **Start here when picking the project up:** state, plan of remaining work, environment setup |
| `RUNBOOK.md` | Owner's step-by-step for finishing the port with the free model: setup, order, copy-paste prompts, checks |
| `LEAD-SYNTHESIS.md` | Findings from the helper-agent research (must-fix items, risks), reviewed |
| `TESTING.md` | How to collect crash logs from the tablet |
| `PORTING-LINEAGE-23.2.md` | Analysis: kernel blocker, required changes, work order |
| `KERNEL-BACKPORT-PLAN.md` | Plan, in phases, for the kernel work that unblocks 23.2, and why it takes time |
| `PRIOR-WORK.md` | Work other people have done online that can be reused |
| `ESTIMATE.md` | Time estimate built from measured conflict sizes and a real kernel build test |
| `WORKLOG.md` | Record of all work done so far, including blocked or failed steps |
| `CLAUDE.md` | Short guide for Claude sessions working in this repo |
| `AGENTS.md` | Entry point for helper AI agents (OpenCode, Codex, …); points to `AGENT-TASKS.md` |
| `AGENT-TASKS.md` | Parallel research tasks for helper agents: steps, templates, prerequisites, model per task |
| `REPO-SETUP.md` | All repos (this one, the forks, the backups), which branch to use, and how to attach them to a Claude session |
| `analysis/exyhyperbrick-trial/` | Trial port of the Galaxy S9 4.9 eBPF kernel series onto the Tab S5e kernel, and conflict classification |
| `analysis/build-test/` | Kernel build test: baseline vs. port tree |
| `analysis/reference-trees/` | Device trees that already did 23.2 (sm7125-common, exynos9810-common), and their commit lists |
| `analysis/agent-batches/` | The conflict commits split into batches for helper agents |
| `analysis/conflicts/` | One brief per conflicting series commit, with a proposed resolution |
| `analysis/upstream-map/`, `api-audit/`, `defconfig/`, `rom/`, `build-test/errors/` | Helper research: upstream origin of each commit, driver API audit, defconfig fragment, ROM-side audits, first build errors |
| `analysis/tools/` | Stacked-replay scripts for inspecting a conflict the way an in-order cherry-pick sees it |
| `scripts/` | `check-agent-output.sh` (report format), `check-pins.sh` (pinned commits), `device-checks.sh` (on-device checks) |
| `local_manifests/gts4lv-common.xml` + `gts4lvwifi.xml` / `gts4lv.xml` | Repos to add to a `lineage-23.2` source tree (they point at our kernel, device and vendor forks) |
| `patches/` | Record of the device-tree changes. They're already committed to the fork's `lineage-23.2` branch, so you don't need to apply them |

## License

The patches and scripts here modify LineageOS device trees, which are
licensed under the Apache License 2.0 (LineageOS's standard license for its own
code). This repository uses the same license, see [LICENSE](LICENSE).

The kernel work lives in its own fork under **GPL-2.0** like the Linux kernel. GPL-3.0 is not compatible with the
kernel's GPL-2.0-only license.

## References

- Device wiki: <https://wiki.lineageos.org/devices/gts4lvwifi/> (Wi-Fi), <https://wiki.lineageos.org/devices/gts4lv/> (LTE)
- Install guides: <https://wiki.lineageos.org/devices/gts4lvwifi/install/>, <https://wiki.lineageos.org/devices/gts4lv/install/>
- Firmware images: <https://github.com/luk1337/gts4lv-fw/releases>
- XDA forum: <https://xdaforums.com/c/samsung-galaxy-tab-s5e.9164/>
