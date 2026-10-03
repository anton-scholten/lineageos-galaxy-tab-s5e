<!-- task: R6 | agent: Space Bunny Free (opencode) | date: 2026-10-03 -->
# R6: what to port from sm7125-common (22.2 -> 23.2)

## Summary

I read all 26 commits in [`analysis/reference-trees/sm7125-common-22.2-to-23.2.tsv`](../reference-trees/sm7125-common-22.2-to-23.2.tsv) and compared each one with our device
fork `anton-scholten/android_device_samsung_gts4lv-common` branch `lineage-23.2` tip `2e50286` (= LineageOS 22.2 `d1b339b` + our patches 0001-0004).
**Counts: NEEDED 1 · NOT NEEDED 11 · ALREADY DONE 10 · UNSURE 0** (22 rows).

Only **one** commit needs a change in our tree: `88c7b73` (manifest `target-level` 5 → 6), which the project docs had already decided on
([`PORTING-LINEAGE-23.2.md:109`](../../PORTING-LINEAGE-23.2.md), [`KERNEL-BACKPORT-PLAN.md:236`](../../KERNEL-BACKPORT-PLAN.md)).
Ten are already in the desired end state in our tree, and eleven are irrelevant to a Wi-Fi-only SDM670 tablet with no in-display fingerprint, no NFC
and no custom `libinit` / `sensors/Sensor.cpp`.
**The lead must look at the side findings first**, in this order: (1) the Tab S5e has **no NFC at all** - checked, three independent sources;
(2) `da8d9f3` (fstab merge) is described as "optional" in [`PORTING-LINEAGE-23.2.md:117`](../../PORTING-LINEAGE-23.2.md) but our tree **already has it done**;
(3) `LineageOS/android_hardware_qcom-caf_common` (note the hyphen) **does have a `lineage-23.2` branch**, so the "other repos stay on lineage-22.2"
comment in `local_manifests/gts4lv-common.xml` may be wrong;
(4) our `manifest.xml` is `version="1.0"` while every 23.2 reference tree uses `version="2.0"`, and our patch 0003 put an AIDL HAL into it.

## Verdicts at a glance

| Verdict | Count | Commits |
|---|---|---|
| NEEDED | 1 | `88c7b73` |
| NOT NEEDED | 11 | `b5f74a0`, `6dc4ee4`, `8fdc0d1`, `ee1d616`, `2642472`, `9c66b3e`, `75d876d`, `37cf59f`, `1c94382`, `02babb7`, `865ff7e` |
| ALREADY DONE | 10 | `45a382c`, `da8d9f3`, `0e16238`, `aed63ad`, `995b08b`, `22e3445`, `aef65d7`, `fa32b8f`, `c6ef8e7`, `6234a16` |
| UNSURE | 0 | - |

`9849669` and `a4c0bfb`, `7bc5cf4`, `39eb067` are the 4 commits the reference README marks as covered by our patches 0001-0004, so they are not in the
table. `fa32b8f` (the `5.4.299` bump) is the second half of our patch 0004, so it *is* in the table and comes out ALREADY DONE.

## The one NEEDED commit

### `88c7b73` - sm7125-common: manifest: Bump target-level to 6

- **What it changes:** `configs/manifest.xml` - `<manifest ... target-level="5">` → `6`, and `<kernel target-level="5"/>` → `6`.
- **Our tree:** `manifest.xml:1` is `<manifest version="1.0" type="device" target-level="5">` @ `2e50286`. There is **no `<kernel>` element at all** in our
  manifest, so for us the change is the single `target-level` attribute on line 1.
- **Why needed:** the project already analysed this and decided yes - on `lineage-23.2` `compatibility_matrix.5.xml` is only an empty placeholder
  ("Android R FCM has been deprecated"), so a level-5 device has no real matrix to check against
  ([`PORTING-LINEAGE-23.2.md:109`](../../PORTING-LINEAGE-23.2.md)).
- **Known risk (from the docs, not from me):** the LTE model's RIL declares `android.hardware.radio@1.4::IRadio` and matrix 6 wants 1.5-1.6;
  if `check_vintf` fails, keep `gts4lv` (LTE) at 5 and bump only the Wi-Fi model
  ([`KERNEL-BACKPORT-PLAN.md:236-243`](../../KERNEL-BACKPORT-PLAN.md)). Note our common manifest is shared by both models, so a per-model bump means
  splitting the manifest; the model repos also have their own `manifest.xml` (`device/samsung/gts4lv/manifest.xml`, LTE, declares `android.hardware.radio@1.4`).
- **Counter-evidence I found (so the lead can weigh it):** the attribute is per-device, not enforced per release. The exynos9810-common 4.9-kernel 23.2 tree
  is still `target-level="5"` (`manifest.xml:2` @ `ced9775`) while the official 23.2 sm8250-common tree is at `target-level="7"`
  (`configs/manifest.xml:1` @ `5f45d212a6dd`). So this is an FCM-policy decision, not a build blocker.
- confidence: **high** that the attribute is still `5` in our tree and is what sm7125 bumped; **medium** that a bump is required (the project docs say yes,
  the two other 23.2 trees show it is not mechanically enforced).

## Side findings for the lead

1. **NFC: the Tab S5e has none.** Checked, not assumed. No NFC HAL in `manifest.xml`, no NFC package in `gts4lv.mk`, no NFC blob in `proprietary-files.txt`,
   no `configs/nfc/` directory, and **0 of 685** files in `TheMuppets/proprietary_vendor_samsung_gts4lv-common` `lineage-22.2` match `nfc`. Neither official
   device repo (`android_device_samsung_gts4lv`, `android_device_samsung_gts4lvwifi`, both `lineage-22.2`) mentions NFC anywhere. Only leftovers exist:
   `init/init.samsung.rc:97-104` (`/dev/sec-nfc`, `/dev/pn547`), `init/ueventd.qcom.rc:301-304`, `sepolicy/vendor/file.te:22` (`nfc_efs_file`) and
   `sepolicy/vendor/file_contexts:77` (`/efs/nfc`). Those are harmless dead rules from the platform tree.
   confidence: **high** - three independent repos (device fork, vendor blobs, both model repos) contain no NFC.
2. **`da8d9f3` (merge fstab into one `prebuilt_etc`) is already done in our tree**, not "optional" as [`PORTING-LINEAGE-23.2.md:119`](../../PORTING-LINEAGE-23.2.md) says:
   `init/fstab.qcom` is a `prebuilt_etc` module (`init/Android.bp:5-11`), `TARGET_RECOVERY_FSTAB := $(COMMON_PATH)/init/fstab.qcom`
   (`BoardConfigCommon.mk:137`) and there is no `recovery/root/fstab.*` left (`recovery/` holds only `Android.bp` and `recovery_updater.cpp`).
   confidence: **high** - read the files at `2e50286`.
3. **CAF `lineage-23.2` exists.** `local_manifests/gts4lv-common.xml` says "The other repos have no lineage-23.2 branch and stay on lineage-22.2", but
   `LineageOS/android_hardware_qcom-caf_common` (hyphen, not underscore - that is why a naive clone URL 404s) has `lineage-23.2` = `1805784d14b386fce6127f2f06b5a16a3e9b94ed`
   and it is the repo's **default branch**. It is included by `LineageOS/android` `lineage-23.2` at `snippets/lineage.xml:102`.
   confidence: **high** - `git ls-remote --heads` plus a successful clone of `lineage-23.2`.
4. **Manifest schema version.** Our `manifest.xml:1` is `version="1.0"`, and our patch 0003 (`62cbdac`) inserted an `<hal format="aidl">` entry
   (`manifest.xml:147-158`) into it. All three reference trees use `version="2.0"` (`sm7125-common`, `sm8250-common` and `exynos9810-common` @ `ced9775`).
   AIDL HALs in VINTF came with manifest 2.0, so if `checkvintf` complains while applying `88c7b73` (same file, same edit), bump `version` to `2.0` too.
   confidence: **low** - I could not read the libvintf parser from this machine (`LineageOS/android_system_libvintf` has only `lineage-16.0`), so this is a
   "check it" item, not a finding.
5. **Where our power HAL lives on 23.2** (this came out of checking `6dc4ee4`): `android.hardware.power-service-qti` (`gts4lv.mk:252`) is **not** in
   `hardware/qcom-caf/common` (39 files at both `lineage-22.2` `cd600d7` and `lineage-23.2` `1805784`, no power directory). It is built by
   `LineageOS/android_vendor_qcom_opensource_power` (`Android.bp:8`) at path `vendor/qcom/opensource/power`, which has a `lineage-23.2` branch - but the
   LineageOS 23.2 manifest lists it group-gated (`snippets/lineage.xml:209`, `groups="qcom,pakala-vendor"`), and our local manifest does not request groups.
   If the first 23.2 sync/build misses that repo, this is why. confidence: **medium** - module name confirmed in the repo, manifest wiring read once.
6. **sm7125 replaced the QTI power HAL with the Lineage libperfmgr one** (`common.mk:319-322` @ `865ff7e`: `android.hardware.power-service.pixel-libperfmgr`),
   which is the real reason behind their `6dc4ee4`. We keep the QTI service, so we do not need that switch. `vendor/qcom/opensource/power` at `lineage-23.2`
   has no `libperfmgr` reference and ships no `.te` files, so the libperfmgr sepolicy is not needed either. confidence: **medium** (checked the provider repo,
   did not trace every rule the power HAL needs).

## Full verdict table (22 rows)

| # | sm7125 commit | What it does | Verdict | File in our tree it would change | Reason (source) | Confidence |
|---|---|---|---|---|---|---|
| 1 | `b5f74a0` Move UDFPS config to new soong namespace | `soong_config_set,samsung_udfps,udfps_zorder` → `samsungUdfpsVars` in `common.mk` | **NOT NEEDED** | none - `gts4lv.mk` has no UDFPS soong config | Our tree sets no UDFPS variable at all: `grep -rniE 'udfps\|fod'` over the whole fork returns nothing, and `gts4lv.mk:149-150` builds only `android.hardware.biometrics.fingerprint-service.samsung` with no `libudfps_extension`. hardware/samsung `lineage-23.2` (`5d20e3541d14`) does read `samsungUdfpsVars` (`fingerprint/Android.bp:10,13`), so the rename is real - it just cannot affect a device that sets nothing. Tab S5e has a side sensor, sm7125 (Tab S6) has an in-display one. | high |
| 2 | `88c7b73` manifest: Bump target-level to 6 | `target-level="5"` → `6` | **NEEDED** | `manifest.xml:1` | See the section above. `manifest.xml:1` @ `2e50286` still says `target-level="5"`. | high (fact) / medium (need) |
| 3 | `6dc4ee4` explicitly include common Lineage libperfmgr sepolicy | adds `include device/lineage/sepolicy/libperfmgr/sepolicy.mk`, deletes the device's own `vendor_power_prop` rules | **NOT NEEDED** | none - `BoardConfigCommon.mk:151-156` (the `# SELinux` block) would get the include | The deletions are moot: `vendor_power_prop` appears nowhere in our fork (`sepolicy/vendor/property.te`, `sepolicy/vendor/hal_power_default.te`, `sepolicy/vendor/vendor_init.te`, `property_contexts` all clean). The include is only needed if we build a libperfmgr power service; we build `android.hardware.power-service-qti` (`gts4lv.mk:252`), whose provider `LineageOS/android_vendor_qcom_opensource_power` @ `4914c6f68893` has no `libperfmgr` reference and no `.te` files. sm7125 needs it because they switched to `android.hardware.power-service.pixel-libperfmgr` (`common.mk:319-322`). | medium |
| 4 | `8fdc0d1` Correct libinit path | `init/` → `libinit/` for `Android.bp`, `init_sm7125.cpp/.h` | **NOT NEEDED** | none - no `libinit/` in our fork | Our `init/` contains only `.rc`, `.sh` and `fstab.qcom` prebuilts (`init/Android.bp`); there is no `init_sm7125.cpp` and no custom init binary to move. | high |
| 5 | `45a382c` Rename rootdir to init and migrate to blueprints | moves `rootdir/**` → `init/**`, `rootdir/Android.mk` → `init/Android.bp` | **ALREADY DONE** | already: `init/Android.bp` (153-line blueprint), no `rootdir/` at all | Present in the 22.2 base, not in our patches: `git ls-tree -r d1b339b` lists `init/Android.bp` + 16 `init/` files and **0** `rootdir` entries. | high |
| 6 | `da8d9f3` Merge fstab and make it a prebuilt_etc module | one `init/fstab.default` `prebuilt_etc`, `TARGET_RECOVERY_FSTAB` retargeted, `recovery/root/fstab.default` deleted | **ALREADY DONE** | already: `init/Android.bp:5-11`, `BoardConfigCommon.mk:137` | Same as above: `fstab.qcom` is a `prebuilt_etc` with `ramdisk_available: true`, `TARGET_RECOVERY_FSTAB` points at it, `recovery/` has no fstab. Corrections side finding 2. | high |
| 7 | `0e16238` init: add `formattable` flag for /data | adds `formattable` to the fs_mgr flags of the `/data` entry | **ALREADY DONE** | already: `init/fstab.qcom:42` | `init/fstab.qcom:42` ends `latemount,wait,check,fileencryption=ice,quota,formattable,reservedsize=128M`. Same change landed in our fork as `985419a` (already in 22.2). | high |
| 8 | `aed63ad` Use LOCAL_PATH in the common product makefile | `$(COMMON_PATH)` → `$(LOCAL_PATH)` in the product makefile, moves the prop files to `BoardConfigCommon.mk` | **ALREADY DONE** | already: `gts4lv.mk:38-40` (and every other path), `BoardConfigCommon.mk:125-128` | `gts4lv.mk` uses `$(LOCAL_PATH)` only (lines 38-40, 46, 74-81, 143, 164, 184, 193-197, 260, 276-280) and all four `TARGET_*_PROP` lines are already in `BoardConfigCommon.mk:125-128`. | high |
| 9 | `995b08b` releasetools: make it work for incremental OTA | passes the zip into `OTA_Assertions` explicitly, sets `info.input_zip = info.target_zip` in `IncrementalOTA_InstallEnd` | **ALREADY DONE** (one divergence, see note) | none; possible tweak at `releasetools.py:63` | Our `releasetools.py:59-63` already takes the zip as a parameter (`AddTrustZoneAssertion(info, info.input_zip)` / `(info, info.target_zip)`) and `releasetools.py:55-57` already does `info.input_zip = info.target_zip` before `OTA_InstallEnd` - i.e. the substance of the fix is in the 22.2 base. Divergence: sm7125 reads `info.input_zip` in `IncrementalOTA_Assertions` (the incremental package, which carries the source build's requirements) where we read `info.target_zip`. Affects only trustzone-version assertions on incremental OTAs. | medium |
| 10 | `22e3445` Don't declare BOARD_VENDOR | deletes `BOARD_VENDOR := samsung` | **ALREADY DONE** | none - no `BOARD_VENDOR` in our fork | `grep -rn BOARD_VENDOR --include='*.mk'` finds only `BOARD_VENDORIMAGE_*` and `BOARD_VENDOR_SEPOLICY_DIRS`. We never declared it, and `BOARD_VENDOR` is deprecated in modern Android, so staying silent is also the forward-safe choice. | high |
| 11 | `ee1d616` sepolicy: Commonize SEC NFC device label | deletes `/dev/sec-nfc u:object_r:nfc_device:s0` | **NOT NEEDED** | none - `sepolicy/vendor/file_contexts` has no `/dev/sec-nfc` line | No NFC hardware: see the NFC section. Our only NFC labels are `sepolicy/vendor/file.te:22` (`nfc_efs_file`) and `sepolicy/vendor/file_contexts:77` (`/efs/nfc`), both for the eSE/NFC partition that does not exist. | high |
| 12 | `2642472` sepolicy: Adapt gatekeeper HAL rules | deletes the device-declared `gatekeeper_vendor_data_file` type, its `/data/vendor/gatekeeper` label, `hal_gatekeeper_default.te` and the `tee` allows | **NOT NEEDED** | nothing to delete - `sepolicy/vendor/file.te:17`, `file_contexts:64`, `hal_gatekeeper_default.te`, `tee.te` stay as they are | Our type is named differently: `sepolicy/vendor/file.te:17` declares `gatekeeper_efs_file` and `sepolicy/vendor/file_contexts:64` labels `/efs/gatekeeper`, not `/data/vendor/gatekeeper`. The reason sm7125 had to delete theirs is that AOSP now declares the type itself - `private/file.te:187` `type gatekeeper_vendor_data_file, ...` and `private/file_contexts:764` in `LineageOS/android_system_sepolicy` `lineage-23.2` (`885cc500f607`). `gatekeeper_efs_file` does **not** exist in 23.2 platform sepolicy, so we have no duplicate. [`PORTING-LINEAGE-23.2.md:107`](../../PORTING-LINEAGE-23.2.md) already reached the same conclusion. | high |
| 13 | `9c66b3e` Remove MODULE_SUFFIX in proprietary-files | drops `;MODULE_SUFFIX=_vendor` from 10 audio libs | **NOT NEEDED** | keep `proprietary-files.txt:15,417,418,766` as they are | `MODULE_SUFFIX` is still supported by the 23.2 extract-utils: `extract_utils/file.py:56` (`MODULE_SUFFIX = 'MODULE_SUFFIX'`) and `extract_utils/makefiles.py:157-159` in `LineageOS/android_tools_extract-utils` @ `44e3b07397a339c2721c637e40cb73159c78ad46`. It was optional cleanup on sm7125's side (their blobs no longer needed the `_vendor` rename). | high |
| 14 | `6234a16` kill face interface and permissions | drops `android.hardware.biometrics.face.xml` from the permissions copy list | **ALREADY DONE** | already: the copy list at `gts4lv.mk:216-248` has no face entry | `gts4lv.mk:217-248` copies 31 `frameworks/native/data/etc/*.xml` permission files and none of them is `android.hardware.biometrics.face.xml`; no face HAL in `manifest.xml`. (`faced` still appears in the *model* repos' init rc files, but that is the fake face service, not a face feature.) | high |
| 15 | `aef65d7` move soong_config_set calls to common.mk | moves 2 `soong_config_set_bool` calls from `BoardConfigCommon.mk` to `common.mk` | **ALREADY DONE** | already: `gts4lv.mk:90,170-176,190`; nothing in `BoardConfigCommon.mk` | True in the 22.2 base, before our patches: `git show d1b339b:BoardConfigCommon.mk \| grep soong_config` returns nothing, while `gts4lv.mk` holds all 10 `soong_config*` calls. Our patch 0002 (`90e692e`) only changed two of them to `soong_config_set_bool`. | high |
| 16 | `75d876d` Update NFC firmware path variables | `RF_DIR_PATH` → `RF_HW_DIR_PATH` etc. in `configs/nfc/libnfc-sec-vendor.conf` | **NOT NEEDED** | none - no `configs/nfc/` in our fork | No NFC hardware and no NFC config files: `git ls-files configs/` lists only `privapp-permissions-hotword.xml` and `public.libraries.txt`. | high |
| 17 | `37cf59f` Switch to NFC AIDL HAL | `android.hardware.nfc@1.2-service.samsung` → `android.hardware.nfc-service.sec`, adds `hardware/samsung_slsi/nfc` to `lineage.dependencies`, retargets the exec label | **NOT NEEDED** | none - `gts4lv.mk` has no NFC package, `lineage.dependencies` needs no new repo, `sepolicy/vendor/file_contexts` has no NFC exec label | No NFC hardware: see the NFC section. Our `lineage.dependencies` lists only `android_hardware_samsung` and `android_kernel_samsung_sdm670`. | high |
| 18 | `fa32b8f` Bump kernel BPF version override to 5.4.299 | `product.prop`: `ro.bpf.kver_override` 5.4.186 → 5.4.299 | **ALREADY DONE** | already: `product.prop:13` | `product.prop:13` is `ro.bpf.kver_override=5.15.178`, set by our patch 0004 (`2e50286`). We use `5.15.178`, not `5.4.299` - deliberate, see `analysis/reference-trees/README.md:21`. | high |
| 19 | `1c94382` overlay: enable fp screen off unlock, off by default | adds `config_screen_off_udfps_enabled` + `config_screen_off_udfps_default_on` to the framework overlay | **NOT NEEDED** | none - `overlay/frameworks/base/core/res/res/values/config.xml` has no screen-off UDFPS entry | No in-display fingerprint sensor, so the feature does not apply: `grep -rn 'screen_off\|udfps' overlay/` returns nothing, and `grep -rniE 'udfps\|fod'` over the whole fork returns nothing. | high |
| 20 | `c6ef8e7` Migrate to Python Extract Utils | adds `extract-files.py` (Python extract-utils), deletes `extract-files.sh` and `setup-makefiles.sh` | **ALREADY DONE** | already: `extract-files.py:1`, `setup-makefiles.py:1` | `extract-files.py:1` is already the `PYTHONPATH=../../../tools/extract-utils` shebang script with `ExtractUtilsModule(...)`, and `setup-makefiles.py` is the one-line `--regenerate_makefiles` wrapper. No `.sh` files in the fork. Also confirmed in [`PORTING-LINEAGE-23.2.md:103`](../../PORTING-LINEAGE-23.2.md). | high |
| 21 | `02babb7` add missing hashes and fix warnings | un-`-`-prefixes 6 `vendor/etc/vintf/...` entries, adds a pre-fixup hash to 6 libs | **NOT NEEDED** | keep `proprietary-files.txt` as it is | Two parts, both no-ops for us. (a) The `-` prefix still means "is a package" in 23.2 (`extract_utils/file.py:108-110` @ `44e3b07397a3`), and our list has **zero** `-` entries, so there is nothing that warns. Our 3 `vendor/etc/vintf/**` entries (`proprietary-files.txt:206,272,600`) are already un-prefixed. (b) The second hash column is `hash\|fixup_hash` (pre-/post-fixup, `file.py:165-177`); adding one is optional pinning. Our 6 libs that have blob fixups in `extract-files.py:44-60` (`libwvhidl.so`, `libwvdrmengine.so`, `gatekeeper.mdfpp.so`, `libskeymaster4device.so`, `libkeymaster_helper.so`, `libsensorlistener.so`) are all **unpinned** (no `|hash` at `proprietary-files.txt:207,211,264,403,407,547`), and unpinned files are not hash-checked, so they cannot produce a mismatch warning. | high |
| 22 | `865ff7e` sensors: Delay enabling the sensor by 200ms | 200 ms sleep in `SysfsPollingOneShotSensor::activate` before re-enabling the TSP | **NOT NEEDED** | none - our fork has no `sensors/Sensor.cpp` | `git ls-files \| grep -i sensor` returns only `init/init.qcom.sensors.sh`, `shims/libsensorndkbridge/*`, two overlay/sepolicy files - no `sensors/` directory and no sensor HAL source. We use the prebuilt `android.hardware.sensors-service.samsung-multihal` (`gts4lv.mk:264`), so there is no local code to delay. The underlying fix lives in `hardware/samsung` (referenced in the commit message). | high |

## Method and sources

Reference tree: `git clone --filter=blob:none https://github.com/LineageOS/android_device_samsung_sm7125-common sm7125` (all branches;
`lineage-22.2` = `b315034eba10611db905770958ab9c7379b9e5a3`, `lineage-23.2` = `865ff7e3742428d282f17b4995f8d37908b7ca82`,
`git rev-list --count --no-merges b315034..865ff7e` = **26**, matching the TSV).

Our tree: `git clone --filter=blob:none --single-branch -b lineage-23.2 https://github.com/anton-scholten/android_device_samsung_gts4lv-common dt`,
tip `2e50286`, base `d1b339b`.

Supporting clones, all outside this repo in `~/work/clone-R6/`:

| Clone | Branch / tip | Used for |
|---|---|---|
| `LineageOS/android_device_samsung_gts4lv` | `lineage-22.2` | model repo, NFC/face check |
| `LineageOS/android_device_samsung_gts4lvwifi` | `lineage-22.2` | model repo, NFC/face check |
| `TheMuppets/proprietary_vendor_samsung_gts4lv-common` | `lineage-22.2`, 685 files | NFC blob check, MODULE_SUFFIX check |
| `LineageOS/android_device_samsung_sm8250-common` | `lineage-23.2` = `5f45d212a6dd` | target-level comparison (`7`) |
| `anton-scholten/android_device_samsung_exynos9810-common` | `lineage-23.2` = `ced9775` | 4.9-kernel 23.2 target-level comparison (`5`, `<kernel target-level="legacy"/>`) |
| `LineageOS/android_tools_extract-utils` | `lineage-23.2` = `44e3b07397a3` | `MODULE_SUFFIX`, `-` prefix, two-hash semantics |
| `LineageOS/android_system_sepolicy` | `lineage-23.2` = `885cc500f607` | `gatekeeper_vendor_data_file` now platform-owned |
| `LineageOS/android_device_lineage_sepolicy` | `lineage-23.2` = `0a9e75292f0e` | `libperfmgr/sepolicy.mk` contents |
| `LineageOS/android_hardware_samsung` | `lineage-23.2` = `5d20e3541d14` | `samsungUdfpsVars` namespace, power/powershare |
| `LineageOS/android_hardware_qcom-caf_common` | `lineage-23.2` = `1805784`, `lineage-22.2` = `cd600d7651ae` | CAF 23.2 exists; no power HAL there |
| `LineageOS/android_vendor_qcom_opensource_power` | `lineage-23.2` = `4914c6f68893` | provider of `android.hardware.power-service-qti` |
| `LineageOS/android` | `lineage-23.2`, `lineage-22.2` | manifest snippets, repo names, groups |

Self-check: 22 rows, every row has a verdict, a reason, a source and the file it would change; the summary counts match the table
(1 NEEDED + 11 NOT NEEDED + 10 ALREADY DONE + 0 UNSURE = 22).

## Problems

None. (Two commands "failed" in a way worth recording: `git ls-remote --heads https://github.com/LineageOS/android_hardware_qcom_caf_common`
asks for credentials because the repo name uses a **hyphen** (`android_hardware_qcom-caf_common`); and `raw.githubusercontent.com` returns 404 from this
machine, so all file contents were read with `git show`/`git grep` from clones instead. `LineageOS/android_system_libvintf` is not mirrored past
`lineage-16.0`, which is why side finding 4 is `confidence: low`.)