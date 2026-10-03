<!-- task: R7 | agent: Space Bunny Free | date: 2026-10-03 -->
# R7: what to port from exynos9810-common (22.2 -> 23.2)

## Summary

I classified all 143 commits of `lineage-22.2..lineage-23.2` in the frozen backup
`anton-scholten/android_device_samsung_exynos9810-common` (tip `ced977559b13`) against the actual diffs
(`git show <sha>`), not the subjects. Counts: **KERNEL-4.9 = 8, GENERIC-23.2 = 42, EXYNOS-ONLY = 77,
TUNING = 16** (sum 143).

Of the 50 KERNEL-4.9 + GENERIC-23.2 items, only **one is a clear NEEDED**: `924cf7e4adcc` (space-separated
lists in `audio_policy_configuration.xml`). **18 are ALREADY DONE** in our fork (mostly because patches
0001-0004 and our 22.2 base already contain them), **25 are NOT NEEDED**, and **6 are UNSURE**.

Read this first: **do not copy `PRODUCT_ENABLE_UFFD_GC := true` / `OVERRIDE_ENABLE_UFFD_GC := true`
(`5434d6c0b43b`, `a5aa7f1b9a1e`)**. Our 4.9 kernel has no `MREMAP_DONTUNMAP`, which AOSP requires for uffd GC.
Also **do not copy `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false` from `e1ee9d27f751`** - that is
exactly the "weaken Android's kernel version check" change that rule 8 puts out of scope, and it is
unnecessary because 23.2 already defaults it to `true` for us.

Sources used for every claim:

- Exynos tree: `anton-scholten/android_device_samsung_exynos9810-common` @ `ced977559b13` (all SHAs below)
- Our device tree: `anton-scholten/android_device_samsung_gts4lv-common` @ `2e50286ebc01`
- Our kernel: `anton-scholten/android_kernel_samsung_sdm670` @ `a30605a54f3b`
- `LineageOS/android_device_samsung_sm7125-common` @ sm7125 23.2 (official LineageOS 23.2 Samsung
  **Qualcomm** tree, kernel 4.14 - the closest official precedent to us)
- `LineageOS/android_build` @ `HEAD` lineage-23.2 (`core/product_config.mk`, `core/product.mk`,
  `core/art_config.mk`, `core/Makefile`)
- `LineageOS/android_system_core` @ lineage-23.2 (`rootdir/init-debug.rc`)
- `LineageOS/android_system_sepolicy` @ `885cc500f607`

---

## KERNEL-4.9 (8 commits)

These are the ones that matter most: our kernel is 4.9 too. Verdicts are for
`anton-scholten/android_device_samsung_gts4lv-common` @ `2e50286ebc01`.

| Commit | Subject | Files | Verdict for our fork | File in our tree it would change |
|---|---|---|---|---|
| `9b461a0e7c5f` | Override kernel BPF version | `product.prop` | **ALREADY DONE** | `product.prop:13` already has `ro.bpf.kver_override=5.15.178` @ `2e50286ebc01` (our patch 0004 = `2e50286ebc01`) |
| `92fef2cefab1` | Bump kernel BPF override to 5.15.178 | `product.prop` | **ALREADY DONE** | same line, same value; the Exy value matches ours exactly |
| `751da43bcb0b` | Override incompatible power supply BPF filter | `Android.bp` | **UNSURE** | `init/Android.bp` would need `overrides: ["filterPowerSupplyEvents.o"]` on the main `prebuilt_etc`; only if the symptom appears (see below) |
| `5434d6c0b43b` | Enable UFFD GC (`PRODUCT_ENABLE_UFFD_GC := true`) | `common.mk` | **NOT NEEDED** - and actively wrong for us | nothing; we have no such variable in `gts4lv.mk` |
| `a5aa7f1b9a1e` | `OVERRIDE_ENABLE_UFFD_GC := true` | `common.mk` | **NOT NEEDED** - actively wrong for us | nothing |
| `de12372ceae3` | Set Android freezer timeout to 1s | `configs/init/init.samsungexynos9810.rc` | **NOT NEEDED** | nothing; no `pm_freeze_timeout` write exists in our `init/*.rc` |
| `9f28bc712d57` | init: Drop kernel LMK minfree write | `configs/init/init.swap.rc` | **NOT NEEDED** | nothing; we never write `/sys/module/lowmemorykiller/parameters/minfree` |
| `e1ee9d27f751` | Migrate Lineage services to current interfaces (adds the 3 kernel product vars + `<kernel target-level="legacy"/>`) | `common.mk`, `manifest.xml` | **NOT NEEDED** - do not copy | `gts4lv.mk`, `manifest.xml`; we should leave all three variables unset |

### Notes per item

**`9b461a0e7c5f` + `92fef2cefab1` - ALREADY DONE.** The Exy tree went `ro.bpf.kver_override=5.10.239`
then `5.15.178`. Our `product.prop:13 @ 2e50286ebc01` is already `5.15.178`. Nothing to do.
confidence: high - both values read directly from the two commits and from our file.

**`5434d6c0b43b` + `a5aa7f1b9a1e` - NOT NEEDED, and copying them would break the build or the GC.**
Evidence, all from AOSP/LineageOS 23.2 build system:

- `LineageOS/android_build` `core/product.mk:438-449` @ lineage-23.2 documents the three values;
  unset means `default`, i.e. build system and runtime decide.
- `core/Makefile:5609-5613` @ lineage-23.2 says explicitly: *"Set PRODUCT_ENABLE_UFFD_GC to `true` if the
  kernel is a GKI kernel and is android12-5.4 or above, or a non-GKI kernel that supports userfaultfd(2)
  **and MREMAP_DONTUNMAP**."*
- Our kernel has **no** `MREMAP_DONTUNMAP`: `include/uapi/asm-generic/mman.h @ a30605a54f3b` has no
  `MREMAP_DONTUNMAP` / `MREMAP_DONTFORK` definitions.
- Our defconfigs also have no `CONFIG_USERFAULTFD`
  (`arch/arm64/configs/gts4lv_defconfig` and `gts4lvwifi_defconfig` @ `a30605a54f3b`). The `fs/userfaultfd.c`
  source exists, so task K6's `CONFIG_USERFAULTFD` would add it, but `MREMAP_DONTUNMAP` (Linux 5.7) is
  a separate problem that a defconfig cannot fix.
- `OVERRIDE_ENABLE_UFFD_GC` is just a higher-priority input to the same decision:
  `core/art_config.mk:15` @ lineage-23.2 - `$(firstword $(OVERRIDE_ENABLE_UFFD_GC) $(PRODUCT_ENABLE_UFFD_GC) default)`.
- The official Samsung Qualcomm 23.2 tree sets **neither** (`LineageOS/android_device_samsung_sm7125-common`
  @ lineage-23.2: no `PRODUCT_ENABLE_UFFD_GC`, no `OVERRIDE_ENABLE_UFFD_GC`, kernel 4.14).
- Leaving it unset is safe but produces a build warning, because with `default` the build needs the
  kernel version: `core/Makefile:5599-5607` @ lineage-23.2. That warning goes away if
  `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS` stays `true`, which is the default for us anyway
  (see `e1ee9d27f751` below).

**Recommendation:** set `PRODUCT_ENABLE_UFFD_GC := false` explicitly in `gts4lv.mk` if the lead wants a
deterministic build with no warning. That is what the Exy tree had between `e1ee9d27f751` and `5434d6c0b43b`.
confidence: high - every step is a direct file read in our kernel, in build/make, and in the official
Samsung 23.2 tree.

**`de12372ceae3` - NOT NEEDED.** It writes `/sys/power/pm_freeze_timeout`, which is a node from the
Samsung/Exynos per-task freezer stack, not part of mainline. Our kernel has no such node: `kernel/power/`
@ `a30605a54f3b` contains no `freezer.c` (only `autosleep.c`, `hibernate.c`, `main.c`, `qos.c`,
`snapshot.c`, `suspend.c`, `swap.c`, `user.c`, `wakelock.c`), and the Android cgroup freezer is what we use
(`CONFIG_CGROUP_FREEZER=y`, `arch/arm64/configs/gts4lvwifi_defconfig:21 @ a30605a54f3b`).
confidence: high - node absent from our kernel tree.

**`9f28bc712d57` - NOT NEEDED.** The Exy tree adds the LMK minfree write in `517c2259faa0` and removes it again here.
We never had it: no file under `init/` @ `2e50286ebc01` writes `minfree` or `/sys/module/lowmemorykiller`.
Moreover our kernel does not build the LMK at all - `arch/arm64/configs/gts4lvwifi_defconfig
@ a30605a54f3b` has no `ANDROID_LOW_MEMORY_KILLER` (the Kconfig name is `ANDROID_LOW_MEMORY_KILLER`,
`drivers/staging/android/Kconfig:17`), so `/sys/module/lowmemorykiller/parameters/minfree` cannot exist.
**Lead check:** our `product.prop:10 @ 2e50286ebc01` still sets `ro.lmk.use_minfree_levels=true`, which makes
lmkd read minfree from that non-existent node. That looks like a pre-existing bug in our tree; consider
dropping it or adding `CONFIG_ANDROID_LOW_MEMORY_KILLER`. This is outside R7's remit but came out of it.
confidence: high for the NOT NEEDED verdict; medium for the `use_minfree_levels` concern (no booted device
to confirm the lmkd fallback).

**`e1ee9d27f751` - NOT NEEDED; do not copy.** The kernel-relevant payload of this commit is three product
variables plus `<kernel target-level="legacy" />`:

| Line in `e1ee9d27f751` | 23.2 default for us | Verdict |
|---|---|---|
| `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false` | already `true` (`core/product_config.mk:527-531` @ lineage-23.2, when `PRODUCT_SHIPPING_API_LEVEL >= 29`) | NOT NEEDED, and it is the change rule 8 forbids |
| `PRODUCT_SET_DEBUGFS_RESTRICTIONS := true` | already `true` (`core/product_config.mk:535-540`, when `>= 31`) | NOT NEEDED (explicit no-op) |
| `PRODUCT_ENABLE_UFFD_GC := false` | `default` is fine | NOT NEEDED |
| `<kernel target-level="legacy" />` in `manifest.xml` | depends on the Track B decision | leave to the lead / R1 |

Our `manifest.xml:1 @ 2e50286ebc01` is `<manifest version="1.0" type="device" target-level="5">` with no
`<kernel>` element, and R6 item `88c7b73` (7-char SHA as printed in `analysis/reference-trees/sm7125-common-22.2-to-23.2.tsv`) bumps target-level to 6. The `<kernel target-level="legacy"/>`
element and `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS` are the sanctioned 23.2 mechanism, but
choosing them is a Track B decision for the lead, not an R7 finding. The rest of `e1ee9d27f751` (dropping the
Lineage fastcharge HIDL service, moving `vendor.lineage.livedisplay` to AIDL) is Samsung/Exynos service
naming and is **not** applicable to us.
confidence: high - defaults read from build/make source, our manifest read directly.

**`751da43bcb0b` - UNSURE, and this is the one to watch.** The commit message is explicit:

> The platform libhealthloop BPF filter drops Exynos9810 power-supply uevents with the 5.10 BPF backport.
> Charging state consequently stops updating. Override filterPowerSupplyEvents.o with the device init module.

What the filter is: `health/utils/libhealthloop/filterPowerSupplyEvents.c` in
`platform/hardware/interfaces` @ `android16-release` is a **cgroup SKB filter**
(`BPF_PROG_TYPE_CGROUP_SKB`) that drops packets whose sending thread's 15-char `comm` matches a hardcoded
list of Exynos kernel-thread names, and it contains a bounded loop of 25 iterations. Bounded loops in BPF
programs are a 5.3+ verifier feature, so behaviour on a 4.9 backport is genuinely different. That part is
SoC-independent and is why I keep this in KERNEL-4.9.

Why UNSURE for us:

1. The thread-name list in the platform file is Exynos-specific, so the exact symptom may not reproduce on
   a Qualcomm device even with the same kernel weakness.
2. Our tree ships `android.hardware.health-service.samsung` (`gts4lv.mk:159 @ 2e50286ebc01`), not AOSP healthd.
   If libhealthloop is not in our build, the filter is never attached and nothing is needed.
3. There is no smoke test in our repo for it.

Test to run before deciding (cheap): after first boot, check that the battery percentage and charging state
actually change - `adb shell dumpsys battery | head -20` before and after plugging in - and grep
`adb logcat -d -b all | grep -i bpf` for verifier errors. If the state stops updating, the fix to copy is
one line in `init/Android.bp` on the main `prebuilt_etc` (`init.qcom.rc`).
confidence: low - I cannot test without a booted device, and the deciding fact (does our health stack link
libhealthloop) is outside this repo.

---

## GENERIC-23.2 (42 commits)

### Verdict table

| Commit | Subject | Verdict | File in our tree | Why |
|---|---|---|---|---|
| `924cf7e4adcc` | audio: Use space-separated policy lists | **NEEDED** | `audio/configs/audio_policy_configuration.xml` | 79 comma-separated `samplingRates`/`channelMasks` attributes still present @ `2e50286ebc01`; the official 23.2 Samsung Qualcomm tree has zero |
| `10987278db44` | Add missing AIDL fingerprint props | **UNSURE** | `vendor.prop` next to `ro.vendor.fingerprint.type` | we already have `ro.vendor.fingerprint.type=side` (`vendor.prop:122`) but not `ro.vendor.fingerprint.supports_gestures` |
| `00d5dccf403c` | sepolicy: Label platform wakeup source nodes | **UNSURE** | `sepolicy/vendor/file_contexts` | generic `/sys/devices/platform/(.*)/wakeup[0-9]*` rule; we have no wakeup label today |
| `66d895b418cd` | sepolicy: Fix vendor init and Power HAL access | **NOT NEEDED** | - | `fwk_stats_service` and `hal_client_domain(hal_power_default, hal_thermal)` are needed by the *Samsung AIDL* power HAL; sm7125 23.2 also uses the QTI power HAL and has neither rule. The `set_prop(vendor_init, vendor_hwc_prop)` line is Exynos |
| `912dff7ddfae` | Inherit emulated_storage.mk | **UNSURE** | `gts4lv.mk` | `non_ab_device.mk` does **not** inherit it (`target/product/non_ab_device.mk` @ lineage-23.2); may already come via `hardware/qcom-caf/common` |
| `bde7e82c9ba9` | Add libutils-v32 shim for sensors.{bio,grip} | **UNSURE** | `extract-files.py`, new `shims/libutils-v32/` | we do ship 32-bit `vendor/lib/sensors.grip.so` (`proprietary-files.txt:557`); cross-check with R4 |
| `e876a8bd5cbe` | overlay: Enable multiple vibration intensity levels | **UNSURE** | `overlay/packages/apps/Settings/res/values/config.xml` | `config_vibration_supported_intensity_levels`; needs a check of what our vibrator HAL actually does |
| `123cbecf8fbc` | Drop obsolete Make build definitions | ALREADY DONE | - | no `Android.mk` anywhere in our tree @ `2e50286ebc01` |
| `3ae685986191` | Inherit non_ab_device.mk | ALREADY DONE | - | already at `gts4lv.mk:17` |
| `409d3b8fd1ee` | Switch to Python extract utilities | ALREADY DONE | - | we already have `extract-files.py` + `setup-makefiles.py`; same change as R6 `c6ef8e7` (short SHA from the sm7125 TSV) |
| `503ffa8be895` | Use bool Soong config for charging bypass | ALREADY DONE | - | our patch 0002 (`90e692ed01a8`) already made it `soong_config_set_bool` |
| `532787d0d03f` | Use default volume table from AOSP | ALREADY DONE | - | `gts4lv.mk` already copies `default_volume_tables.xml` from AOSP |
| `561935357575` | Enable adoptable storage | ALREADY DONE | - | `init/fstab.qcom:54` already has `voldmanaged=sdcard:auto,encryptable=userdata` |
| `6c3c503e748f` | Drop more obsolete Samsung init setup | ALREADY DONE | - | no `/data/log`, `/data/misc/wifi`, `/data/misc/reboot`, `/data/nfc` anywhere in our `init/` |
| `72e5bfc2c304` | Remove obsolete device framework matrix include | ALREADY DONE | - | our patch 0001 (`9ff7da83f972`) |
| `87afcab78b26` | Drop system_server sys_module allow | ALREADY DONE | - | our `sepolicy/vendor/system_server.te` has no `sys_module` allow |
| `9eecf55c502c` | Build init configs as Soong prebuilts | ALREADY DONE | - | `init/Android.bp` already uses `prebuilt_etc` |
| `acd84e0cab7b` | Convert libshim_sensorndkbridge to Soong | ALREADY DONE | - | `shims/libsensorndkbridge/Android.bp` exists |
| `b3f17a645e8f` | Remove shims Android.mk | ALREADY DONE | - | no `shims/Android.mk` |
| `b3e586bd2fc9` | Move Wi-Fi init configuration to the device tree | ALREADY DONE | - | our Wi-Fi dirs are already under `/data/vendor/wifi/...` (`init/init.qcom.rc:282-289`) |
| `d8469f6cd300` | init: Remove deprecated configuration | ALREADY DONE | - | same, plus the `wifi.rc` pattern; only the Exynos `.mac.info` part is missing |
| `ff0c0ff2236c` | Declare Samsung camera quirks as bool vars | ALREADY DONE | - | our patch 0002; `gts4lv.mk:90` uses `soong_config_set_bool` |
| `49aaf115b268` | Address missing gpsd and tee denials | ALREADY DONE | - | `tee efs_file` access already in `sepolicy/vendor/tee.te`; we have no vendor `gpsd.te` |
| `15a1d42677b3` | Define schedulerservice dependency as Soong prebuilt | NOT NEEDED | - | we do not list `android.frameworks.schedulerservice@1.0` at all |
| `d08fed651276` | Ship scheduler service from VNDK prebuilts | NOT NEEDED | - | same, and it needed `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES` |
| `237628ede142` | display: Allow panel minimum brightness | NOT NEEDED | - | panel-specific value, not a 23.2 requirement |
| `6984b36c717e` | display: Use calibrated brightness handling | NOT NEEDED | - | Exynos panel nits/backlight arrays |
| `f241e71a5852` | overlay: Use a linear brightness slider | NOT NEEDED | - | cosmetic, panel-specific |
| `344ff13eb93b` | Add missing touch HAL interfaces to manifest | NOT NEEDED | - | we ship no `vendor.lineage.touch` HAL (the sm7125 23.2 tree does) |
| `9b56b43dd287` | Switch to Touch AIDL | NOT NEEDED | - | same |
| `34f46818f325` | Enable blurs | NOT NEEDED | - | optional; Exynos Mali, ours is Adreno |
| `c837cadbd6ce` | overlay: Enable battery cycle count | NOT NEEDED | - | optional UX |
| `d3ed64dc17c0` | Reduce corner radius to 16dp | NOT NEEDED | - | cosmetic; our `dimens.xml:21` uses a different unit on purpose |
| `f4c25c9212db` | Enable expressive UI | NOT NEEDED | - | optional; also switches on blur |
| `b8bb0cdc80b7` | Add automatic display-density switching | NOT NEEDED | - | the author's own `com.krazey.resdensity` app, not a 23.2 requirement |
| `f3dd43dca335` | Don't force LTE icon | NOT NEEDED | - | we have no CarrierConfig vendor overlay |
| `385c2db501d5` | Switch test profiles to utilization clamping | NOT NEEDED | - | we ship neither `cgroups*.json` nor `task_profiles*.json`; sm7125 23.2 still ships `cgroups_30.json`/`task_profiles_30.json`, so this is a preference, not a requirement |
| `9683936a146d` | Refresh WifiOverlay for 23.2 | NOT NEEDED | - | **counter-evidence:** `rro_overlays/WifiOverlay/Android.bp` in sm7125 23.2 still has `theme: "WifiOverlay"` |
| `7b01b218567a` | Drop obsolete mobile TCP buffer override | NOT NEEDED | - | no `config_mobile_tcp_buffers` in our overlay today |
| `abf0815f83f5` | sepolicy: Allow Power HAL service callback | NOT NEEDED | - | `allow servicemanager hal_power_default:binder call` is for the Samsung AIDL power HAL in `hardware/samsung/aidl/power-libperfmgr`, which this tree does not use; our power HAL is `android.hardware.power-service-qti` (`gts4lv.mk:252`) |
| `7016ab8905e7` | Address missing audio denial | NOT NEEDED | - | `allow vendor_init audio_device:chr_file getattr` was for the Exynos ABOX audio proxy; nothing in our `init/` touches `/dev/snd` |
| `dbff734716ff` | Fix OTA updates with encrypted f2fs | NOT NEEDED | - | we have no `sepolicy/vendor/uncrypt.te` and `/data` is `ext4 ... fileencryption=ice` (`init/fstab.qcom:42`) |

### The one NEEDED item in detail

**`924cf7e4adcc` - audio: Use space-separated policy lists.** The commit converts
`samplingRates="44100,48000,..."` and `channelMasks="AUDIO_CHANNEL_OUT_MONO,AUDIO_CHANNEL_OUT_STEREO"`
to space-separated form in `configs/audio/audio_policy_configuration.xml`. Android's audio policy parser
splits these attributes on whitespace, so the comma form silently drops entries.

- Our `audio/configs/audio_policy_configuration.xml @ 2e50286ebc01` still has **79** comma-separated
  `samplingRates` / `channelMasks` attributes (first at line 80).
- `LineageOS/android_device_samsung_sm7125-common` @ lineage-23.2, same file, has **0** comma lists; its
  line 41 is `samplingRates="8000 11025 12000 ... 384000"`.

So the official LineageOS 23.2 Samsung Qualcomm tree made exactly this change and we have not.
confidence: high - both files read directly, 79 vs 0 counted.

### Two things the lead should look at even though the verdicts are "NOT NEEDED"

1. **`init/init.qcom.rc:33 @ 2e50286ebc01` does `mount debugfs debugfs /sys/kernel/debug` inside
   `on early-init`.** In 23.2, init mounts and then unmounts debugfs itself:
   `rootdir/init-debug.rc:10-16` @ `LineageOS/android_system_core` lineage-23.2 mounts it on the *same*
   trigger, `on early-init && property:ro.product.debugfs_restrictions.enabled=true`, and **umounts it on
   `sys.boot_completed`**. The property is already `true` for us by default
   (`core/product_config.mk:535-540` @ lineage-23.2). So both rc files fire in `early-init` and the
   platform one then unmounts debugfs after boot, which will break any device-init or HAL that expects
   `/sys/kernel/debug` to still be there. This observation came out of `f33df241b914`, which is classified
   EXYNOS-ONLY because most of it strips Samsung ABOX debugfs nodes.
   confidence: medium - I confirmed both mounts are in `early-init`, but I did not trace the load order of
   `init.rc` versus `init-debug.rc`, and there is no booted device to check whether the second mount
   actually fails or is a no-op.
2. **`912dff7ddfae` (emulated_storage.mk).** `target/product/non_ab_device.mk` @ lineage-23.2 only adds
   `applypatch`; it does **not** inherit `emulated_storage.mk`, which is what sets `PRODUCT_QUOTA_PROJID`
   and `PRODUCT_FS_CASEFOLD`. Our `init/fstab.qcom:42` mounts `/data` with `quota` already, so the
   behaviour may already be coming from `hardware/qcom-caf/common/common.mk`.
   confidence: medium - I tried to read `hardware/qcom-caf/common` but `LineageOS/android_hardware_qcom_caf_common`
   does not exist on GitHub (the repo is `android_hardware_qcom_caf`), so I did not confirm the inherit.

---

## EXYNOS-ONLY (77 commits) - do not port

Every one of these touches an Exynos/Samsung-specific path (Exynos audio proxy, `sec-ril`, Samsung camera
provider, Exynos NFC, Exynos powerhint, `star2lte`/`starlte` sysfs nodes, Exynos partitions), so they are
not applicable to a Qualcomm SDM670 tablet.

| Commit | Subject | Category | One-line reason |
|---|---|---|---|
| `02f6d09469c3` | Update properties for the Linaro graphics stack | EXYNOS-ONLY | `ro.hardware.egl=mali`, `ro.vendor.ddk.set.afbc` - Exynos Mali DDK |
| `03e8624241f8` | Use 32-bit Samsung camera libraries | EXYNOS-ONLY | swaps Exynos Samsung camera provider package; we already ship `android.hardware.camera.provider-service_32.samsung` (`gts4lv.mk:93`) |
| `095007f05b5f` | Remove obsolete shim definitions | EXYNOS-ONLY | duplicate `libsensorlistener.so` fixup key in their extract list |
| `0a225ffddea9` | audio: Drop unused proxy build definitions | EXYNOS-ONLY | `audio/proxy/Android.bp`, Exynos audio proxy only |
| `0b0d5ab6ee99` | Build "missing" keystore2 | EXYNOS-ONLY | needed for their keymaster 3.0 blob set; sm7125 23.2 does not do it |
| `0e5dee96d95a` | Add symlink for `/dev/block/persistent` | EXYNOS-ONLY | their recovery symlink to a `PERSISTENT` by-name partition we do not have |
| `0edbbe4601af` | Import libaudioproxy from exynos9820 | EXYNOS-ONLY | ~1100 lines of Exynos ABOX audio proxy |
| `1092faf892b4` | Drop obsolete legacy init setup | EXYNOS-ONLY | CPEFS mount and ASEC tmpfs, Exynos partitions |
| `12f65ca8c123` | Normalize packed RIL data-call MTUs | EXYNOS-ONLY | `shims/libsec-ril`, Samsung modem shim (also reverted by `79d71c5fa2b6`) |
| `190ec7d5cf9c` | Update VINTF declarations for source HALs | EXYNOS-ONLY | audio 7.1 `IDevicesFactory`, `gralloc.universal9810`, AIDL camera provider - all their source-HAL migration |
| `1ad6d71ab388` | Update vendor security patch to 2023-02-01 | EXYNOS-ONLY | matches their Exynos vendor blobs, not ours |
| `1b81177a0b1e` | Use the kernel's Samsung boot image packer | EXYNOS-ONLY | `Image.samsung`, `scripts/samsung_bootimg.py`, `SAMSUNG_BOOT_PAGESIZE` - Exynos kernel only. Our kernel is `Image.gz-dtb` with `dtbhtool`-style packaging (`BoardConfigCommon.mk:93-96 @ 2e50286ebc01`) |
| `1c1e171065d1` | nfc: Create framework NFC data directory | EXYNOS-ONLY | `/data/nfc` vs `/data/vendor/nfc` label dance, NFC only |
| `22f372ff2791` | init: Restore DAK labels before early HALs | EXYNOS-ONLY | `restorecon_recursive /mnt/vendor/efs/DAK`, Exynos attestation key |
| `2cd264c0006f` | Drop invalid BarTender RT bandwidth setup | EXYNOS-ONLY | `/dev/cpuctl/bg_cached` BarTender |
| `2fd39520f123` | init: Update vendor log paths | EXYNOS-ONLY | `mkdir /data/vendor/log/abox` for the Exynos audio DSP |
| `3233812b23f5` | Drop unsupported secure codec declarations | EXYNOS-ONLY | `OMX.Exynos.*.dec.secure` codec entries (reverted by `944cfb79960c`) |
| `39f0ed2cd02f` | sepolicy: Label star2lte power supply types | EXYNOS-ONLY | hard-coded `14360000.hsi2c/i2c-15` Exynos charger nodes |
| `3fb5904c2dad` | ril: Configure stock library paths | EXYNOS-ONLY | `vendor.rild.libpath=/vendor/lib64/libsec-ril.so` |
| `43189199ce4e` | Handle CPEFS as read-only storage | EXYNOS-ONLY | CPEFS partition, Exynos modem storage |
| `4ab6beeab01a` | Route HDMI audio through dedicated output | EXYNOS-ONLY | Exynos DP DMA / `pcmC0D15p` HAL path |
| `4ad9d44a8ee2` | ril: Restore the stock RIL blob set | EXYNOS-ONLY | Samsung `libsec-ril` blob hashes |
| `4b85993f5fbb` | Update product configuration for source HALs | EXYNOS-ONLY | `audio.primary.universal9810`, `gralloc.universal9810`, samsung_slsi-linaro namespaces |
| `582f6dac1f1f` | sepolicy: Label starlte power supply nodes | EXYNOS-ONLY | Exynos `max77705` charger/fuel gauge nodes |
| `5b20594a1cbc` | Add panel green-screen workaround | EXYNOS-ONLY | `panel_drv@001` Exynos DSI panel sysfs |
| `620692ce6c4a` | Switch to 32-bit Samsung AIDL camera provider | EXYNOS-ONLY | same package we already ship, but the reason is their AIDL camera HAL |
| `6281ada1b674` | Cleanup graphic vendor props | EXYNOS-ONLY | `debug.hwui.renderer=skiagl` / Mali properties |
| `68bae92183df` | ril: Normalize Samsung SMSC responses | EXYNOS-ONLY | `shims/libsec-ril` SMSC shim |
| `6a7577d49974` | Add double tap to wake support | EXYNOS-ONLY | writes `/sys/class/sec/tsp/cmd aod_enable,1` |
| `6b2eb395ff72` | Address missing denials | EXYNOS-ONLY | `sysfs_block` labels for Exynos UFS `sda`, `/efs/TEE` |
| `6fcc7f7b25d4` | audio: Initialize mixer lock before use | EXYNOS-ONLY | `pthread_rwlock_init` fix inside the Exynos audio proxy |
| `715877d76aa0` | Update board configuration for source HALs | EXYNOS-ONLY | `TARGET_CPU_ABI2 := arm`, `exynos_audio` soong namespace, `TARGET_CUSTOM_DTBTOOL := dtbhtoolExynos` |
| `7420fed0ec3d` | sepolicy: Restore Widevine vendor access | EXYNOS-ONLY | `/efs/wv.keys` and `secmem_device` |
| `79d71c5fa2b6` | Revert "Normalize packed RIL data-call MTUs" | EXYNOS-ONLY | revert of a Samsung RIL shim |
| `7dead47557f9` | camera: Match telephoto recording profiles to ID 50 | EXYNOS-ONLY | rewrites their `media_profiles_V1_0.xml` camera IDs |
| `82b2692de568` | Remove Built-In Back Mic from audio sources | EXYNOS-ONLY | Exynos secondary mic |
| `83f5d2b1484b` | audio: Trim libaudioproxy for Exynos9810 | EXYNOS-ONLY | trims the Exynos audio proxy, adds `exynos9810AudioVars` |
| `85fb227b5024` | init: Drop custom forcetouch handler | EXYNOS-ONLY | `/sys/class/sec/tsp/cmd set_pressure_*` |
| `88013fafa494` | Update policy for the source camera provider | EXYNOS-ONLY | `sysfs_gpu_writable` Exynos GPU clock + their camera provider |
| `89f9be00ad3a` | ril: Shim NULL SMSC for CS SMS | EXYNOS-ONLY | wraps `libsec-ril.so` |
| `8db08163eb7d` | Extract the ARM scheduler interface | EXYNOS-ONLY | 32-bit VNDK blob for their 32-bit Exynos HALs |
| `8fd4f84bc988` | Make media profile extraction repeatable | EXYNOS-ONLY | regex tweak for the camera-ID rewrite above |
| `944cfb79960c` | Revert "Drop unsupported secure codec declarations" | EXYNOS-ONLY | Exynos `OMX.Exynos.*.secure` codec entries |
| `9cf3e1f58439` | Update NFC firmware path variables | EXYNOS-ONLY | `sec_s3nrn82` NFC firmware; we have no NFC |
| `aa780f6aad75` | audio: Use strtok_r for microphone XML parsing | EXYNOS-ONLY | inside the Exynos audio proxy |
| `ae037ac276ab` | nfc: Restore S3NRN82 RFREG configuration | EXYNOS-ONLY | S3NRN82 NFC chip |
| `b11662c3904b` | camera: Alias auxiliary recording profiles | EXYNOS-ONLY | their camera-ID rewrite |
| `b2439925edfb` | Run keymaster 3.0 as system | EXYNOS-ONLY | `keymaster@3.0-override.rc`; we use `keymaster@4.0-service.samsung` |
| `b3056c8ec149` | sensors: Precreate FactoryApp metadata files | EXYNOS-ONLY | `/efs/FactoryApp` SensorHub metadata |
| `b4d07e88fd92` | audio: Refresh routes before first playback | EXYNOS-ONLY | Exynos audio proxy route refresh |
| `b9c117b0f189` | Add Samsung n770 RIL configuration | EXYNOS-ONLY | `mtu-conf.xml`, `pdpcnt-conf.xml` from an S9 firmware |
| `badadb10dec7` | audio: Disable ABOX mute control | EXYNOS-ONLY | `ABOX ERAP info Mute Primary` mixer control |
| `c207a5c1b316` | nfc: Enable legacy CORE_INIT_RSP handling | EXYNOS-ONLY | `ro.vendor.nfc.legacy_core_init_rsp`, NFC only |
| `c3fd3839d0b2` | audio: Let routes control the left amp | EXYNOS-ONLY | `Spk AmpL Power` mixer control |
| `c8a9471d3359` | Drop the broken sound trigger HAL | EXYNOS-ONLY | `exynos9810AudioVars,use_soundtrigger_hal` |
| `c8e557f96906` | audio: Drop obsolete proprietary blobs | EXYNOS-ONLY | removes Exynos ABOX dump blobs from their blob list |
| `c946eaf8e58e` | Extract pinned Dolby and VNDK dependencies | EXYNOS-ONLY | Motorola Dolby DMS blobs for Exynos |
| `c977ffab6f83` | Drop `/dev/sec-nfc` from sepolicy | EXYNOS-ONLY | Exynos NFC device node |
| `c98a4c4c4f6e` | Revert "remap bixby key to MENU" | EXYNOS-ONLY | Bixby key 703 |
| `cbf2bf8e5fad` | audio: Switch to Motorola Dolby | EXYNOS-ONLY | Exynos Dolby Atmos port with Exynos blobs |
| `cfadc9b85141` | Update green-screen recovery control | EXYNOS-ONLY | same Exynos `panel_drv@001` node |
| `cff99a141591` | audio: Restore refcounted reroutes | EXYNOS-ONLY | Exynos audio proxy reroute API |
| `d0e8cd00d0aa` | ril: Match VINTF to the stock interfaces | EXYNOS-ONLY | `vendor.samsung.hardware.radio.bridge` VINTF |
| `d2dc97e87951` | Add missing Lineage copyright notices | EXYNOS-ONLY | license headers for files we do not have |
| `d6e67871c481` | audio: Restore more Dolby profiles | EXYNOS-ONLY | Exynos Dolby app strings |
| `e10756fb501b` | Repurpose ODM for persistent metadata | EXYNOS-ONLY | turns their `ODM` by-name partition into `/metadata`; our `init/fstab.qcom` has no odm or metadata entry |
| `e5d44f34560e` | Switch to AIDL NFC HAL | EXYNOS-ONLY | `android.hardware.nfc-service.sec`; we have no NFC |
| `e8ca0504f34f` | Gate green screen workaround behind persist property | EXYNOS-ONLY | Exynos panel node |
| `e9db4cc43d75` | audio: Harden AP call route transitions | EXYNOS-ONLY | Exynos audio proxy |
| `eeaefab6a55d` | Add vendor security patch from crownlte | EXYNOS-ONLY | their vendor blob patch level |
| `f22083c81c08` | sepolicy: Label raw UFS block sysfs | EXYNOS-ONLY | `11120000.ufs/host0/.../block/sda` |
| `f33df241b914` | Remove obsolete services and sepolicy | EXYNOS-ONLY | strips ABOX debugfs/mobicore/sec_debug nodes - but see the debugfs note above |
| `f90b2ba26cce` | sepolicy: Allow kernel sensor calibration access | EXYNOS-ONLY | `/efs/FactoryApp` app_efs_file |
| `f9cb4bef3f24` | Fix LHD killer control access | EXYNOS-ONLY | Broadcom `/sys/bbd/lk_enable` |
| `fab82d534b2f` | Add missing efs denials | EXYNOS-ONLY | `cpdebug_efs_file`, `ssm_efs_file`, `/efs/wv.keys` |
| `fc85bcf57b6e` | sepolicy: Drop duplicate radio hwservice mappings | EXYNOS-ONLY | `vendor.samsung.hardware.radio.*` |
| `ff5ddab28d5c` | Allow Bluetooth HAL to read persisted bdaddr | EXYNOS-ONLY | `/efs/bluetooth/bt_addr` |

confidence for the whole EXYNOS-ONLY group: high for the mechanism (each diff names an Exynos/Samsung
symbol, path, blob or partition), medium for a few that are merely "Samsung-branded but SoC-independent"
(`b2439925edfb`, `0b0d5ab6ee99`, `1092f7`) - reason: I did not trace their HAL internals, only their build wiring.

---

## TUNING (16 commits) - optional, no verdict needed

All 16 are memory/reclaim/scheduler tuning for a 4 GB device with zram swap. Useful as a *menu* if the
lead sees OOM or jank; none of it is required for 23.2. Two are worth reading before anything else:
`517c2259faa0` adds an `init.swap.rc` with `min_free_kbytes 65536`, `page-cluster 0`, `swappiness 100` **plus the
LMK minfree write that `9f28bc712d57` later removes**; `d3097026039a` turns on `ro.lmk.use_psi=true`, which our
kernel can support because `CONFIG_PSI=y` (`arch/arm64/configs/gts4lvwifi_defconfig:11 @ a30605a54f3b`).

| Commit | Subject | Category | One-line reason |
|---|---|---|---|
| `189937ac4199` | Boost little CPUs during expensive rendering | TUNING | `powerhint.json` frequency values for `EXPENSIVE_RENDERING` |
| `1ee9e4176450` | Tighten LMKD under swap pressure | TUNING | `ro.lmk.swap_free_low_percentage=20`, `thrashing_limit=30` |
| `2e0ad89b0d7e` | Raise GPU floor for expensive rendering | TUNING | `GPUMinFreq` 338000 -> 455000 |
| `517c2259faa0` | init: Tune VM/LMK for zram-backed swap | TUNING | new `init.swap.rc` with VM knobs + the LMK minfree write |
| `64d401e91300` | init: Tune VM for PSI+lmkd | TUNING | `min_free_kbytes` 65536 -> 32768, `swappiness` -> 80 |
| `6b1e47963e6c` | Move memory optimizations prop to system | TUNING | moves `ro.config.avoid_gfx_accel` vendor -> system; later reverted by `a9a72cf22e76` |
| `7b13f3ad0fc1` | overlay: Drop static system file pinning | TUNING | empties `config_defaultPinnerServiceFiles` (we still pin 6 files, `overlay/.../config.xml:749`) |
| `7e017a512ee1` | Configure 4 GiB of LZ4 zram | TUNING | `zramsize=4294967296`; we use `zramsize=60%` (`init/fstab.qcom:57`) |
| `87f9e43dfe70` | Tune userspace LMKD for zram swap | TUNING | LMKD thresholds + `ro.vendor.init_dev_config.path` |
| `8a940fe9d8af` | Tune reclaim for compressed swap | TUNING | `swappiness` 80 -> 100, `ro.lmk.swap_compression_ratio=2` |
| `939dd248fba9` | overlay: Disable launcher file pinning | TUNING | `config_pinnerHomePinBytes=0` |
| `a9a72cf22e76` | Remove memory optimizations | TUNING | deletes `ro.config.avoid_gfx_accel` again - so the pair 6b1e479/a9a72cf is a no-op |
| `cebfddff53a4` | Reduce premature cached app kills | TUNING | `ro.lmk.lowmem_min_oom_score=1001`, `swap_free_low_percentage=10` |
| `ced977559b13` | Allow reclaiming low-priority cached apps | TUNING | `ro.lmk.lowmem_min_oom_score=950` |
| `d3097026039a` | Enable PSI lmkd and balanced OOM props | TUNING | `ro.lmk.use_psi=true` + thrash/swap thresholds; needs `CONFIG_PSI` (we have it) |
| `e0dab7e0a7eb` | Add little-cluster interaction boost | TUNING | adds `CPULittleClusterMinFreq` to `powerhint.json` |

---

## Self-check

- All 143 commits from `analysis/reference-trees/exynos9810-common-22.2-to-23.2.tsv` are classified exactly
  once. Every one was read with `git show <sha>` against the frozen backup @ `ced977559b13`; the category
  counts were computed from that list, not from the subjects.
- Category counts: **KERNEL-4.9 8 + GENERIC-23.2 42 + EXYNOS-ONLY 77 + TUNING 16 = 143**.
- Verdict counts over the 50 KERNEL-4.9 + GENERIC-23.2 items:
  **NEEDED 1, NOT NEEDED 25, ALREADY DONE 18, UNSURE 6 = 50**.
  - KERNEL-4.9: ALREADY DONE 2, NOT NEEDED 5, UNSURE 1, NEEDED 0.
  - GENERIC-23.2: NEEDED 1, NOT NEEDED 20, ALREADY DONE 16, UNSURE 5.
- Counts were recomputed from the finished tables (`awk` over the verdict cells), not typed by hand.
- Every KERNEL-4.9 and GENERIC-23.2 row has a NEEDED-style verdict, a source SHA/path and a confidence line.
- All 148 twelve-character SHAs that appear in this file were checked: 143 are the commits from the TSV,
  the other 5 are `2e50286ebc01` (our device tree tip), `a30605a54f3b` (our kernel tip),
  `885cc500f607` (LineageOS `android_system_sepolicy` 23.2 tip) and `90e692ed01a8` / `9ff7da83f972`
  (our patches 0002 and 0001).

### Classification rules I applied

- A commit that touches only Exynos/Samsung-specific paths (Exynos audio proxy, `sec-ril`, Samsung camera
  provider, Exynos NFC, `powerhint.json`, `star2lte`/`starlte` sysfs, Exynos partitions) is EXYNOS-ONLY even
  when the subject sounds generic. `1b81177a0b1e` ("Use the kernel's Samsung boot image packer") is the clearest
  example: it is a kernel change but it needs `Image.samsung`, `scripts/samsung_bootimg.py` and
  `SAMSUNG_BOOT_PAGESIZE`, none of which exist in a Qualcomm tree.
- A commit that is generic in intent but needs an Exynos implementation is EXYNOS-ONLY, with the reason
  spelled out: `715877d76aa0`, `4b85993f5fbb`, `190ec7d5cf9c`, `c946eaf8e58e`, `cbf2bf8e5fad`, `b2439925edfb`, `0b0d5ab6ee99`.
- `34f46818f325`-style opt-in UX features (blurs, expressive UI, corner radius, battery cycle count, vibration
  levels, display sliders) are GENERIC-23.2 with verdict NOT NEEDED, because they are SoC-independent but
  not required. They are in this table, not hidden, so the lead can decide.

## Problems

Two tooling issues and one missing repository, none affecting the result:

1. `git ls-tree -r --name-only` and `git show` on the blobless clone of our kernel
   (`anton-scholten/android_kernel_samsung_sdm670`, `--filter=blob:none --depth 1`) warned
   "Clone succeeded, but checkout failed" and `git grep` across the whole tree timed out at 300 s. I worked
   around it by fetching only the individual blobs I needed (`include/uapi/asm-generic/mman.h`,
   `kernel/power/` tree, `drivers/staging/android/Kconfig`, the two defconfigs). No conclusion depends on a
   tree-wide grep.
2. `git clone --filter=blob:none --single-branch -b lineage-23.2 .../android_device_samsung_exynos9810-common`
   in the task's suggested command line has a leading `~/work/clone-R7` typo that makes `cd` fail.
   I created the directory first and then ran the clone from inside it; tips verified as
   `ced977559b13e2d6e407fada711334132c37aaf5` (exy) and `2e50286ebc01070c11be5e618ee557a6073709ff` (ours),
   both matching AGENT-TASKS.md section 3.

3. `git ls-remote`/`git clone` for `LineageOS/android_hardware_qcom_caf_common` fails with
   "could not read Username" (the repository does not exist under that name; the real one is
   `LineageOS/android_hardware_qcom_caf`). This is why the `emulated_storage.mk` verdict
   (`912dff7ddfae`) and the "which power HAL" reasoning rest on `gts4lv.mk:252` plus the sm7125 23.2
   tree rather than on reading `hardware/qcom-caf/common` directly.

Nothing else failed. No verdict depends on a guess; the 6 UNSURE rows say exactly what test or file would
settle them.
