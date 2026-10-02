# Porting LineageOS 23.2 to the Galaxy Tab S5e Wi-Fi (SM-T720 / gts4lvwifi)

Status of the official port as of this analysis:

| Component | Official branches | Notes |
|---|---|---|
| `android_device_samsung_gts4lvwifi` | up to `lineage-22.2` | No changes needed beyond 22.2 |
| `android_device_samsung_gts4lv-common` | up to `lineage-22.2` | Patches in `patches/` |
| `android_kernel_samsung_sdm670` | up to `lineage-22.2` | Linux **4.9.337**. This is the blocker |
| `android_hardware_samsung` | `lineage-23.2` exists | Removed the HIDL HALs gts4lv still uses |
| `TheMuppets/proprietary_vendor_samsung_gts4lv*` | up to `lineage-22.2` | Blobs can be reused |
| `hudson/lineage-build-targets` | `gts4lvwifi userdebug lineage-22.2 W` | Same for every other 4.9 Qualcomm device (sdm845/sdm710) |

The platform itself is still supported: in `hardware/qcom-caf/common` on
lineage-23.2, `sdm710` is part of `UM_4_9_FAMILY`. It maps to
`QCOM_HARDWARE_VARIANT := sdm845`, and the `lineage-23.2-caf-sdm845` branches
of audio, display and media exist. `sepolicy_vndr` uses `lineage-23.2-legacy-um`.
Userspace is not what keeps the tablet on 22.2.

---

## 1. Blocker: the kernel (eBPF and new syscalls)

Android 16's mainline modules (bpfloader, netd, Tethering, ConnectivityService)
need eBPF functionality from Linux 5.4. In LineageOS 23 the project
supports an older kernel only if it carries **1:1 eBPF backports**
that make it feature-equivalent to `android12-5.4`. The device then advertises
this with `ro.bpf.kver_override=5.4.x`. When this analysis was done, those
backports had been done for 4.14 kernels but not for 4.9. That is why all
sdm845/sdm710 devices (enchilada, fajita, beryllium, crosshatch, gts4lv, …)
stayed on 22.2. Their `lineage-23.x` device branches (e.g.
`android_device_oneplus_sdm845-common`) are just copies of the 22.2 heads and
were never built.

Reference implementation: `LineageOS/android_kernel_samsung_sm7125`
(4.14). Its `lineage-22.2..lineage-23.2` first-parent history is:

1. `Merge remote-tracking branch 'sm8150/lineage-20' into lineage-23.0`. This
   brings in **about 1050 eBPF-related commits** (BPF core/verifier,
   BTF, sockmap/skmsg, flow_dissector, sk_storage, cgroup-bpf, test_run, TCP
   stats used by BPF helpers, bpfilter/umh…). Most are by Daniel Borkmann,
   Alexei Starovoitov, Jakub Kicinski, Martin KaFai Lau and John Fastabend.
2. `close_range()` backport (10 commits, starting with `BACKPORT: open: add close_range()`).
3. `epoll_pwait2()` backport (7 commits, starting with `UPSTREAM: fs: add do_epoll_*() helpers`).
4. Defconfig regeneration, plus disabling Samsung UH/RKP on those devices.

The sdm670 4.9 kernel today has `CONFIG_BPF_SYSCALL`, `CONFIG_CGROUP_BPF`,
`CONFIG_NET_CLS_BPF` and `CONFIG_NETFILTER_XT_MATCH_BPF`. Its uapi
`linux/bpf.h` predates 4.13: no `BPF_JLT/JLE/JSLT/JSLE`, no
`BPF_F_RDONLY_PROG`, no `bpf_ktime_get_boot_ns`, no ringbuf. It also lacks
`close_range` and `epoll_pwait2`. A 4.9 kernel therefore needs **everything a
4.14 kernel needed, plus the 4.9 to 4.14 BPF delta**.

### Kernel work items

1. Fork `android_kernel_samsung_sdm670` at `lineage-22.2`.
2. Backport the eBPF series to reach `android12-5.4` parity. Practical routes:
   - Use an existing community 4.9 eBPF backport as the base, e.g. the sdm845
     4.9 BPF series being developed for LineageOS 23
     (`gitea.com/console-ramoops/kernel_qcom_sdm845-bpf-4.9`). sdm670 and
     sdm845 share the same msm-4.9 CAF base, so this is the shortest path.
   - Or cherry-pick the 4.14 series from `android_kernel_samsung_sm8150`
     (`lineage-20`) after first backporting the 4.10 to 4.14 BPF commits
     (verifier rework, `BPF_JLT` family, `BPF_PROG_TYPE_SOCK_OPS`,
     `bpf_prog_info`, map-in-map, `BPF_F_NUMA_NODE`, …).
3. Backport `close_range()` and `epoll_pwait2()` (the same 17 commits as sm7125;
   the 4.9 arm64/compat syscall tables need hand-wiring).
4. Samsung UH/RKP: nothing to do. `CONFIG_UH`/`CONFIG_RKP_*` are already
   absent from `gts4lvwifi_defconfig`.
5. Validate on device with `atest netd_integration_test` / `bpf_existence_test`,
   or at least check that `bpfloader` finishes and `netd` stays up in `logcat`.
6. Only then apply `0004-gts4lv-common-Override-kernel-BPF-version.patch`.

A newer default clang in 23.2 may also produce new `-Werror` failures in
vendor drivers (qcacld, techpack). If so, either fix them or pin
`TARGET_KERNEL_CLANG_VERSION`.

---

## 2. Device tree changes (`device/samsung/gts4lv-common`)

All of these are in `patches/device/samsung/gts4lv-common/`, made with
`git format-patch` against `lineage-22.2` (`d1b339b`). They mirror changes
the maintainers made to other Samsung Qualcomm trees (sm7125-common,
sm8250-common) for 23.x.

| Patch | Why it is needed | Severity |
|---|---|---|
| `0001` Remove `vendor/lineage/config/device_framework_matrix.xml` from `DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE` (use `+=`) | File no longer exists on lineage-23.x (change `I78da6340f`) | **Build break** |
| `0002` Use `soong_config_set_bool` for `samsungCameraVars.needs_sec_reserved_field` and `lineage_health.charging_control_supports_bypass` | 23.2 `select()`s on these as booleans. As strings they fall through to `default`, so the camera HAL loses `CAMERA_NEEDS_SEC_RESERVED_FIELD` (camera breaks) and Lineage Health turns on bypass charging | **Runtime break** |
| `0003` LiveDisplay HIDL to AIDL (`vendor.lineage.livedisplay-service.samsung-qcom`, `format="aidl"` v1 in `manifest.xml`, file_contexts relabel) | `hardware/samsung` dropped the HIDL LiveDisplay service (`hidl: Disable LiveDisplay HIDL`, `livedisplay: Migrate to AIDL`) | **Build break** |
| `0004` `ro.bpf.kver_override=5.4.299` in `product.prop` | Needed by Android 16 mainline. **Apply only after the kernel work in §1** or the device bootloops | Kernel-dependent |

`0003` declares only `IAdaptiveBacklight` and `IDisplayModes`, the same as 22.2.
The AIDL service exits if it registers an interface that isn't declared in
VINTF. On this kernel, `mdnie/outdoor` and `mdnie/sensorRGB` exist but are
not chowned to `system`, so those two interfaces report as unsupported and
are never registered. If you later chown them in `init.qcom.rc`, also add
`ISunlightEnhancement` and `IDisplayColorCalibration` to the manifest.

### Checked and fine as-is

- `extract-files.py` / `setup-makefiles.py` already use Python extract-utils.
- Lineage Health already uses `soong_config_set` + `IFastCharge`; hardware/samsung's removed HIDL fastcharge isn't used.
- The camera provider (`android.hardware.camera.provider-service_32.samsung`) is AIDL and still in hardware/samsung 23.2. Only the HIDL camera was removed.
- `android.hardware.keymaster@4.0-service.samsung`, `health-service.samsung(-recovery)`, `sensors-service.samsung-multihal` and `biometrics.fingerprint-service.samsung` all still exist.
- The gatekeeper sepolicy doesn't use `/data/vendor/gatekeeper` (the cleanup other trees needed for AOSP `e8d66734`); it uses `/efs/gatekeeper`.
- `system_server self:capability sys_module` (a new neverallow in BP3A) isn't granted here; `macloader` has it, which is allowed.
- FCM `target-level="5"`: `compatibility_matrix.5.xml` is still in lineage-23.2 `hardware/interfaces`, so no bump is required. Bumping to 6 is possible: audio 6.0, mapper 2.1, composer 2.3 and soundtrigger 2.2/2.3 are all allowed by matrix 6.
- The forked audio HAL wrapper (`audio/impl`, `android.hardware.audio@6.0-impl.gts4lv`): upstream only added a `get_audio_port` null check and an opt-out for `speaker_layout_channel_mask` between 22.2 and 23.2. `audio.primary.sdm710` is built from source, so it needs no opt-out.
- `vendor/lineage/config/common_full_tablet_wifionly.mk` still exists.

### Things to watch when you first boot (can't be checked without a build)

- New Android 16 sepolicy neverallows hitting `sepolicy/vendor/*.te`. Fix whatever the build reports.
- Blobs that `NEEDED` the system `libtinyxml2.so`. BP4A updated tinyxml2 to an ABI-incompatible 10.x, so patch them with
  `blob_fixup().replace_needed('libtinyxml2.so', 'libtinyxml2-v34.so')` the way sm8250-common does. gts4lv ships its own
  `libtinyxml2_1.so`, which suggests most vendor blobs are already covered.
- Optional, as other trees did: `BOARD_WPA_SUPPLICANT_PRIVATE_LIB_EVENT := "ON"`, and merging the fstab into a single prebuilt.

`device/samsung/gts4lvwifi` needs no changes.

---

## 3. Building

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --no-clone-bundle
mkdir -p .repo/local_manifests
cp <this repo>/local_manifests/gts4lvwifi.xml .repo/local_manifests/
repo sync -c -j$(nproc)

# Device tree patches (BPF override skipped until the kernel is ready)
<this repo>/apply-patches.sh "$PWD"
# ...after the kernel backports are in:
# <this repo>/apply-patches.sh "$PWD" --with-bpf-override

source build/envsetup.sh
breakfast gts4lvwifi        # lineage_gts4lvwifi-bp4a-userdebug
mka bacon
```

Flashing works as on 22.2 (see the official
[install guide](https://wiki.lineageos.org/devices/gts4lvwifi/install/)).
Flash the 22.2 firmware baseline, then LineageOS Recovery via Odin/Heimdall, then
sideload. Going from 22.2 to 23.2 is a major version upgrade: use a clean flash
or the usual upgrade instructions.

## 4. Order of work

1. Sync 23.2, apply patches 0001 to 0003, and build. Fix any sepolicy neverallow
   or blob linkage errors. Getting this far proves the userspace port.
2. Do the kernel backports (§1). This is the bulk of the work: about 1000+ commits.
3. Apply 0004, boot, and verify networking: Wi-Fi, tethering, data usage
   accounting and VPN all depend on BPF.
4. Run a regression pass on camera, LiveDisplay, charging control, audio,
   fingerprint, sensors and Wi-Fi Display.

## References

- LineageOS 23 release notes (eBPF / kernel requirements): https://lineageos.org/Changelog-30/
- Device wiki: https://wiki.lineageos.org/devices/gts4lvwifi/
- XDA forum: https://xdaforums.com/c/samsung-galaxy-tab-s5e.9164/
- Reference trees: `LineageOS/android_device_samsung_sm7125-common` and `…_sm8250-common` (`lineage-22.2..lineage-23.2`)
- Reference kernel: `LineageOS/android_kernel_samsung_sm7125` (`lineage-22.2..lineage-23.2`)
