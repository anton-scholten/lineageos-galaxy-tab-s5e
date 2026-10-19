# Unofficial LineageOS 24 for Galaxy Tab S5e (SM-T720 `gts4lvwifi`, SM-T725/T727 `gts4lv`)

> I used AI to make this happen. My tablet works well on 24, no bugs so far.  
> Human TL;DR:
> 1. Back up the data on your tablet and remove your Google account from it.
> 2. Boot into Download mode.
> 3. Flash the recovery from the [latest release](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/releases/latest) for your model.
> 4. Boot into recovery and check its version.
> 5. ⚠️ "Factory reset" → "Format data" (this erases everything, have a backup!).
> 6. On the tablet select "Apply update" → "Apply from ADB" and sideload the ROM for your model from your PC.
> 7. **Optional, only if you want Google apps:** before the first boot, "Apply from ADB" again and sideload MindTheGapps (see [Google apps](#google-apps-optional)).
> 8. Reboot and you should be good.

**LineageOS 24 (Android 17) is the recommended version.** LineageOS 23.2 (Android 16) remains available: branch
`lineage-23.2` (here and in every fork) and the [23.2 releases](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/releases).
`main` holds the current docs and the 24 work; `lineage-22.2` in the forks is only the upstream base.

Android 16/17 need kernel features a 4.9 kernel doesn't have. The port has two parts: a **kernel backport** (the
ExyHyperBrick 4.9 eBPF series, about 2,450 commits, plus EROFS for Google Play services) and a **full ROM** (device
tree, blobs and fixes for Android 16/17). It is not an official build: don't report its bugs to the LineageOS team.
Fixes that should go upstream are tracked in [UPSTREAM.md](UPSTREAM.md).

## Status

| Model | State |
|---|---|
| **SM-T720 / T720N** (Wi-Fi, `gts4lvwifi`) | ✅ Works |
| **SM-T725 / T725C / T725N / T727\*** (LTE, `gts4lv`) | 🔨 Built, untested (I don't have an LTE tablet). On 24, mobile data is unconfirmed: the radio HAL (1.4) is older than Android 17 formally allows |

**Not tested:** screen casting (Miracast; fixed in the build).  
**Not working:** ANT+. LTE: no VoLTE/VoWiFi (calls fall back to 2G/3G).

> ⚠️ **`/metadata` on OMR.** Android 16/17 need a `/metadata` partition, which this tablet doesn't have. Like official
> LineageOS on the Galaxy S10, the port uses Samsung's unused 20 MB **OMR** partition. The recovery's *Format data*
> formats it, so follow the install steps exactly. Going back to stock firmware with Odin/samloader restores OMR.

## Install / upgrade

**You need:** a PC with `adb`, a good USB-C cable, battery above 50%, and the files for your model from the
[latest release](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/releases/latest) (ROM zip, `recovery-*.img`,
`vbmeta-*.img`, `SHA256SUMS`; check them with `sha256sum -c SHA256SUMS --ignore-missing`). Never mix Wi-Fi and LTE files.

Follow the official LineageOS guide for your model ([Wi-Fi](https://wiki.lineageos.org/devices/gts4lvwifi/install/),
[LTE](https://wiki.lineageos.org/devices/gts4lv/install/)) with these changes:

| Step in the official guide | Do this instead |
|---|---|
| Unlock, `vbmeta` | Only when coming from Samsung stock, with our `vbmeta-*.img`. Skip when coming from LineageOS |
| Flash recovery | Flash the recovery of the version you install (the 22.2 recovery can't install 23.2 or 24). Odin, Heimdall or [samloader](https://github.com/topjohnwu/samloader-rs/releases/latest): `samloader flash --partition RECOVERY recovery-*.img --no-reboot` |
| Factory reset | ⚠️ **Required** (erases all data) when coming from Samsung stock, official 22.2 (different signing keys) or 23.2 → 24. Not needed when updating to a newer build of the same version |
| Sideload | *"Signature verification failed"* is expected: answer *Yes*. Stopping at 47% with `adb: failed to read command: Success` is normal |

First boot can take up to 15 minutes.

### Google apps (optional)

Google apps can only be added **before the first boot**; adding them later needs a factory reset. Use **arm64**
MindTheGapps matching the Android version: [17.0.0](https://github.com/MindTheGapps/17.0.0-arm64/releases/latest) for 24,
[16.0.0](https://github.com/MindTheGapps/16.0.0-arm64/releases/latest) for 23.2. Updating to a newer build keeps them.

```bash
adb sideload lineage-*-UNOFFICIAL-gts4lvwifi.zip   # recovery: Apply update > Apply from ADB (LTE: gts4lv)
adb sideload MindTheGapps-*-arm64-*.zip            # Apply from ADB again, without rebooting in between
```

### Troubleshooting

- **Stuck in Download mode:** unplug USB, hold *Vol Down + Power* until the screen goes black, then immediately *Vol Up + Power* for recovery (with USB plugged in you land in Download mode again).
- **Phone refuses to pair** ("pairing rejected" / "failed to connect") after a reinstall: the tablet keeps its Bluetooth address, so the phone still holds the old pairing. *Forget* the tablet on the phone, then pair again.
- **Boot loop:** get logs from recovery first (`adb shell cat /proc/last_kmsg`, see [TESTING.md](TESTING.md)) and report them. Then ⚠️ *Format data* and sideload again, or go back to an older version with its recovery and zip (always erases data).

## Sources

All forks use branch `lineage-24.0` (and `lineage-23.2` for 23.2).

| Part | Fork | What |
|---|---|---|
| Kernel (GPL-2.0, same for 23.2 and 24) | [android_kernel_samsung_sdm670](https://github.com/anton-scholten/android_kernel_samsung_sdm670) | The ExyHyperBrick series (eBPF at Linux 5.15 level, `close_range`, `epoll_pwait2`, FUSE-BPF, userfaultfd, uclamp, PSI) ported onto the Tab S5e kernel, plus an SELinux policy-loading fix, a BPF fix (charging status) and EROFS |
| Device tree | [android_device_samsung_gts4lv-common](https://github.com/anton-scholten/android_device_samsung_gts4lv-common) | Android 16/17 bring-up, OMR `/metadata`, SELinux, always-on display, tablet defaults |
| Blobs | [proprietary_vendor_samsung_gts4lv-common](https://github.com/anton-scholten/proprietary_vendor_samsung_gts4lv-common) | TheMuppets' 22.2 blobs + patched Wi-Fi Display library; 24 also relinks two blobs to the newer audio libraries |
| Bluetooth | [android_packages_modules_Bluetooth](https://github.com/anton-scholten/android_packages_modules_Bluetooth) | Restores `bluetooth.hci.disabled_commands` (pairing crash) |
| 24 only | [system/core](https://github.com/anton-scholten/android_system_core), [system/vold](https://github.com/anton-scholten/android_system_vold), [hardware/lineage/compat](https://github.com/anton-scholten/android_hardware_lineage_compat), [device/qcom/sepolicy_vndr](https://github.com/anton-scholten/android_device_qcom_sepolicy_vndr) | Old-kernel `/data` encryption keyring (core, vold), Wi-Fi Display shim link fix (compat), one stale SELinux rule against a new Android 17 `neverallow` (sepolicy_vndr) |

## Building (developers)

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs --no-clone-bundle   # 23.2: -b lineage-23.2
mkdir -p .repo/local_manifests
cp <this repo>/local_manifests/24/*.xml .repo/local_manifests/   # 23.2: local_manifests/*.xml
repo sync -c -j$(nproc)
source build/envsetup.sh && breakfast gts4lvwifi && mka bacon   # LTE: gts4lv
```

Outputs `lineage-*-UNOFFICIAL-<codename>.zip`, `recovery.img` and `vbmeta.img` in `out/target/product/<codename>/`; the
manifests point at all forks above, so no extra patches are needed. Release builds of both versions and models:
[`scripts/build-all.sh`](scripts/build-all.sh) (checks every fork and the release settings).

Needs ~300 GB of disk and `git-lfs` installed **before** `repo sync`. RAM: 16 GB+ for 23.2; **≥55 GB of RAM or swap for
24** (Soong peaks at ~53 GiB, [analysis/l24/L7.md](analysis/l24/L7.md) §10a). The 24 kernel needs `libssl-dev` on the
build host. Full recipe: [analysis/port/BUILD-HANDOFF.md](analysis/port/BUILD-HANDOFF.md).

## Prior work used

Big thanks to all the following:

| Project | Author | What we used |
|---|---|---|
| [ExyHyperBrick/android_kernel_samsung_exynos9810](https://github.com/ExyHyperBrick/android_kernel_samsung_exynos9810) | Mathias Gluszczynski (krazey) | **The kernel backport**: its `lineage-22.2..lineage-23.2` series (Galaxy S9, Linux 4.9.337), cherry-picked with `-x` to keep every original author, and its EROFS import. [(fork as backup)](https://github.com/anton-scholten/android_kernel_samsung_exynos9810) |
| [ExyHyperBrick/android_device_samsung_exynos9810-common](https://github.com/ExyHyperBrick/android_device_samsung_exynos9810-common) | krazey | Reference for the 4.9-specific device changes, e.g. `ro.bpf.kver_override=5.15.178` |
| [LineageOS gts4lv trees](https://github.com/LineageOS/android_device_samsung_gts4lv-common) (`gts4lv-common`, `gts4lv`, `gts4lvwifi`) and [kernel](https://github.com/LineageOS/android_kernel_samsung_sdm670) | LineageOS maintainers | The 22.2 base |
| [LineageOS sm7125-common](https://github.com/LineageOS/android_device_samsung_sm7125-common) and [sm7125 kernel](https://github.com/LineageOS/android_kernel_samsung_sm7125) | LineageOS (basamaryan and others) | Reference for official Samsung Qualcomm changes to 23.2 and 24 |
| [LineageOS hardware/samsung](https://github.com/LineageOS/android_hardware_samsung) | LineageOS | Samsung HALs, used as-is |
| [TheMuppets vendor blobs](https://github.com/TheMuppets/proprietary_vendor_samsung_gts4lv-common) | TheMuppets | Proprietary Samsung/Qualcomm files; `libwfdservice.so` patched to load our shim |
| [LineageOS exynos9820-common](https://github.com/LineageOS/android_device_samsung_exynos9820-common/commit/b6a153f436c88d8ef73a24d711a8db5cd7500b4e) | Tim Zimmermann (Linux4) | Idea to use Samsung's OMR partition as `/metadata` |
| [LineageOS hardware/lineage/compat](https://github.com/LineageOS/android_hardware_lineage_compat) | LineageOS | The existing `libwfdservice_shim`; ours covers the newer blob |
| [luk1337/gts4lv-fw](https://github.com/luk1337/gts4lv-fw/releases) | luk1337 | Stock Android 11 firmware for the install steps (and big thanks for keeping the tablet updated all these years to 22.2!) |
| [topjohnwu/samloader-rs](https://github.com/topjohnwu/samloader-rs) | topjohnwu | Flashing from Linux |
| [MindTheGapps](https://github.com/MindTheGapps) | MindTheGapps | Google apps packages |
| [Doze-off/fuck-bpf](https://github.com/Doze-off/fuck-bpf), [duckyduckG 4.19 kernel](https://github.com/duckyduckG/android_kernel_xiaomi_sdm845_419) | | Studied as alternatives; not used |

## Repo contents

| Path | What |
|---|---|
| `HANDOVER.md` | **Start here when picking the project up:** state, next steps, build machine layout |
| `WORKLOG.md` | Record of all work, including blocked or failed steps |
| `UPSTREAM.md` | Fixes owed to LineageOS (Gerrit) and the kernel author |
| `RELEASING.md` | How to build, sign, publish and push the OTA feed for a release |
| `release/`, `ota/` | Release notes and the XDA post; the Updater feeds (`ota/<version>/<device>.json`) |
| `TESTING.md` | How to collect crash logs from the tablet |
| `local_manifests/` (23.2), `local_manifests/24/` | Repos to add to a LineageOS source tree; each file explains its fork |
| `scripts/` | `build-all.sh` (release builds), `ota-json.sh` (OTA feed), `device-checks.sh` (on-device checks), `check-pins.sh` (pinned commits), `boot-log.sh`, `fcm-check.py`, `pmsg-decode.py`, `portability-check.sh`, kernel cherry-pick tooling |
| `PORTING-LINEAGE-23.2.md`, `KERNEL-BACKPORT-PLAN.md`, `PRIOR-WORK.md`, `ESTIMATE.md`, `LEAD-SYNTHESIS.md` | 23.2 analysis: kernel blocker, plan, prior work, estimate, research findings |
| `FEASIBILITY-LINEAGE-24.md`, `analysis/l24/` | 24 feasibility study, task specs, status and boot logs |
| `analysis/` (other folders) | Kernel trial port and conflict briefs, build tests, reference trees, audits, helper-agent research |
| `RUNBOOK.md`, `AGENTS.md`, `AGENT-TASKS.md`, `CLAUDE.md`, `REPO-SETUP.md` | How the work was run with AI agents, and all repos/branches |
| `MOVING-THE-DRIVE.md` | Moving the build drive to another machine |
| `patches/` | Record of the first device-tree changes (already in the fork; don't apply) |

## License

This repo is Apache-2.0, like the LineageOS device trees it modifies ([LICENSE](LICENSE)). The kernel work lives in its
own fork under **GPL-2.0** like the Linux kernel (GPL-3.0 is not compatible with the kernel's GPL-2.0-only license).

## References

- Device wiki: <https://wiki.lineageos.org/devices/gts4lvwifi/> (Wi-Fi), <https://wiki.lineageos.org/devices/gts4lv/> (LTE)
- Firmware images: <https://github.com/luk1337/gts4lv-fw/releases>
- XDA forum: <https://xdaforums.com/c/samsung-galaxy-tab-s5e.9164/>
