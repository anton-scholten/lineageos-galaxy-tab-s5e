# Feasibility: LineageOS 24 (Android 17) on the Galaxy Tab S5e

Written 2026-10-09, after LineageOS 23.2 was brought up on the SM-T720 (see [HANDOVER.md](HANDOVER.md)).

## Verdict

**Feasible, and much cheaper than 23.2 was.** The hard part of 23.2 was the kernel (eBPF), and our kernel already exceeds
what the closest official LineageOS 24 devices needed. The new work is mostly in the device tree (VINTF/FCM level 7, legacy
libion) plus an unknown number of Android 17 surprises found by booting.
**Wi-Fi model: high confidence. LTE model: medium**, because its Samsung RIL only speaks radio HAL 1.4, which FCM level 7
doesn't allow.

**Recommended timing:** start once LineageOS 24 has official builds for a few devices. Branches exist (`lineage-24.0` in
`LineageOS/android` and many device/kernel repos) but no official release yet. A more settled base means fewer platform bugs to
chase that aren't ours.

## Evidence

| Finding | Source |
|---|---|
| Android 17 released 2026-06-16; LineageOS 24 "underway", no ETA (blog, 2026-07-07) | [LineageOS blog](https://lineageos.org/Infrastructure-Apps-Updates/) |
| `lineage-24.0` branches exist for `android`, `frameworks_base`, and **old-kernel** devices: Samsung sm7125 (4.14) and Motorola exynos9610 (4.14) | `git ls-remote` on LineageOS repos |
| **FCM levels 5 and 6 are removed in 24.0**: `compatibility_matrices` has 7, 8, 202404, 202504, 202604, 202704 (23.2 still had 5 and 6). Our tablet is at **5** | [android_hardware_interfaces `lineage-24.0`](https://github.com/LineageOS/android_hardware_interfaces/tree/lineage-24.0/compatibility_matrices) |
| In matrix 7 no HAL is mandatory (no `optional="false"`), but every declared HAL must be in the allowed version range | `compatibility_matrix.7.xml` @ lineage-24.0 |
| Motorola exynos9610 (4.14 kernel): already at BPF kver **5.10.239** and **FCM 7** on 23.2 → **0 kernel commits** for 24.0; device tree only added legacy libion and retrofit dynamic partitions | [kernel compare](https://github.com/LineageOS/android_kernel_motorola_exynos9610/compare/lineage-23.2...lineage-24.0), [device compare](https://github.com/LineageOS/android_device_motorola_exynos9610-common/compare/lineage-23.2...lineage-24.0) |
| Samsung sm7125 (4.14): BPF kver **5.4 → 5.10.239**, which meant **1,531 kernel commits** (≈600 BPF, LSM blob infrastructure, KFENCE, EROFS, `HIDRAW` "to satiate FCM 7 requirements"); device tree: FCM 6 → 7, `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false` ("until we fix kernel"), legacy libion | [kernel compare](https://github.com/LineageOS/android_kernel_samsung_sm7125/compare/lineage-23.2...lineage-24.0), [device compare](https://github.com/LineageOS/android_device_samsung_sm7125-common/compare/lineage-23.2...lineage-24.0) |
| krazey's ExyHyperBrick kernel: `lineage-24.0` == `lineage-23.2` == `baa585f` (2026-09-20). No 24-specific kernel work, nothing newer than what we ported | `git ls-remote` ExyHyperBrick |
| Android 17's own kernel list is 5.10+ (GKI); legacy devices run it via kver override + backports, as LineageOS does above | [Android common kernels](https://source.android.com/docs/core/architecture/kernel/android-common) |
| krazey is now an **official LineageOS maintainer** (Galaxy S23, `dm1q`) | LineageOS blog build roster |

## What we reuse

| Area | Reuse | Why |
|---|---|---|
| **Kernel** (`500658be3c16`) | **≈100 %** | BPF at **5.15** level (`ro.bpf.kver_override=5.15.178`), higher than sm7125/Motorola's 5.10 for 24.0. Already has `HIDRAW`, `BPF_LSM`, PSI, uclamp, userfaultfd, FUSE-BPF, binderfs, `process_mrelease` (not enabled), the SELinux avtab fix |
| Device fixes from 23.2 | High (re-apply, re-check) | cgroups (`cgroups_30.json` on vendor), lmkd PSI, **OMR as `/metadata`**, uclamp init + perf remap, SELinux wakeup/HAL fixes, WFD shim (re-check its symbol against Android 17's `AudioSystem`) |
| Vendor fork | Full | Same blobs; fixups already live in `extract-files.py` |
| Partitions | Full | Built system is ~1.8 GB of a 4.16 GiB partition, vendor 336 MB of 896 MiB. No repartition or dynamic partitions needed |
| Build and debug method | Full | Clean-shell builds, `USE_CCACHE` discipline, `out/keep/` real copies, debug build with `WITH_ADB_INSECURE`, `last_kmsg`/pstore + `scripts/pmsg-decode.py`, `scripts/device-checks.sh`, release flow (`gh`, draft release, XDA template) |

## What has to be added

| # | Work | Size | Notes |
|---|---|---|---|
| 1 | **New source tree** `lineage-24.0` | 1 day (unattended) | ⚠️ Internal disk has ~19 GB free. Either put the 24 tree on the external drive (565 GB free, slower USB HDD) or replace the 23.2 tree. A second full tree won't fit internally |
| 2 | Move manifests and forks to `lineage-24.0` branches; rebase the device tree on whatever LineageOS changed for 24 in the shared trees (`hardware/samsung`, `qcom-caf`) | ½–1 day | gts4lv has no official 24 branch, so we carry the 22.2→23.2→24 deltas ourselves, as for 23.2 |
| 3 | **FCM 5 → 7** in `manifest.xml` | ½–1 day | Wi-Fi: drop `gnss@1.1` (the fragment also declares `@2.1`) and `soundtrigger@2.2` (loses the hardware hotword DSP path). Remove the `framework_compatibility_matrix.xml` entries that only existed for level 5. Add `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false` if the kernel-config check complains, as sm7125 did |
| 4 | **LTE radio 1.4** (the open risk) | 1–5 days | Level 7 allows radio `1.2` (SAP) and `1.5–1.6` only. Our `libsec-ril` caps at `@1.4::IRadio` (LEAD-SYNTHESIS §M3). Options: (a) see whether LineageOS 24 tolerates it (VINTF deprecation is enforced at build/OTA, so we'll know at the first build); (b) a radio HIDL 1.4→1.5 shim service (new code); (c) LTE without telephony. Untestable without an LTE tablet |
| 5 | Legacy libion: `$(call soong_config_set_bool,libion,legacy_impl,true)` + `device/lineage/sepolicy/libion/sepolicy.mk` | 1 h | Both 4.14 devices needed it; our camera/media blobs use ION |
| 6 | Build fixes from the first full build (new Soong rules, new `check_elf_file` ABI breaks in blobs like P6's libwfdservice) | 1–3 days | Unknown count; 23.2 had one blob break |
| 7 | **Boot debugging** of Android 17 surprises (new kernel feature probes, SELinux policy changes, init/cgroup changes) | 2–7 days | 23.2 needed 4 boot fixes (SELinux avtab, cgroups, lmkd, /metadata), all now carried over. Expect 1–4 new ones |
| 8 | Optional kernel extras: `EROFS`, `KFENCE`, `WIREGUARD` | 0–1 day | sm7125 added them for 24.0. Not needed for an ext4 build; WireGuard is nice for VPN apps |
| 9 | Testing (TESTING.md, device-checks, 24 h soak), release | 2 days | Same as 23.2 |

## Time estimate (owner's machine, same workflow as 23.2)

| Phase | Wall-clock |
|---|---|
| Sync + first full build | 1–2 days (sync ½–1 day, first build ~16 h as for 23.2) |
| Device tree port, FCM 7, libion, build fixes | 1–3 days (23.2's device port and build fixes took ~1 day) |
| Boot debugging to a working Wi-Fi build | 1–5 days (23.2: recovery fix 1 day, then 4 boot fixes in 1 day) |
| Testing + release | 1–2 days |
| **Wi-Fi total** | **≈4–12 days elapsed**. 23.2 took ~6 days (2026-10-02 → 10-07), most of it the kernel backport, which 24 doesn't need |
| LTE on top | +1–5 days for the radio question, then untested as now |

Biggest uncertainties: the number of Android 17 boot surprises (item 7), and LTE radio 1.4 (item 4).

## Sources to use

| Source | Use |
|---|---|
| [LineageOS/android_device_samsung_sm7125-common `lineage-24.0`](https://github.com/LineageOS/android_device_samsung_sm7125-common/tree/lineage-24.0) | Closest Samsung + Qualcomm + legacy-kernel reference for every 24.0 device change (FCM 7, libion, VINTF kernel flag) |
| [LineageOS/android_kernel_samsung_sm7125 `lineage-24.0`](https://github.com/LineageOS/android_kernel_samsung_sm7125/tree/lineage-24.0) | Kernel config changes for 24 (`HIDRAW`, EROFS, KFENCE) and any 24-specific fix |
| [LineageOS/android_device_motorola_exynos9610-common `lineage-24.0`](https://github.com/LineageOS/android_device_motorola_exynos9610-common/tree/lineage-24.0) | Proof that a 4.14 kernel at BPF 5.10 / FCM 7 needs no kernel change for 24 |
| [ExyHyperBrick](https://github.com/ExyHyperBrick) (krazey) | Watch for a real `lineage-24.0` kernel or device branch for the S9. krazey is also now an official maintainer to ask |
| [LineageOS/android_hardware_interfaces `compatibility_matrices`](https://github.com/LineageOS/android_hardware_interfaces/tree/lineage-24.0/compatibility_matrices) | FCM 7 allowed HAL versions |
| [LineageOS/android_hardware_samsung](https://github.com/LineageOS/android_hardware_samsung) `lineage-24.0` | Samsung RIL/radio interfaces: check for a radio 1.5 path or shim |
| [LineageOS Gerrit](https://review.lineageos.org), topic `lineage-24.0` | Platform changes and legacy-device fixes as they land |
| Our own: [WORKLOG.md](WORKLOG.md), `analysis/port/boot-2…5.md`, [TESTING.md](TESTING.md), `scripts/` | Every 23.2 lesson and tool |
