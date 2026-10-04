<!-- task: R3 | agent: Space Bunny Free | date: 2026-10-03 -->
# R3: Soong config variable audit (round 2)

## Summary

Re-ran the audit with the three reader repos the round-1 spec missed. **All 9 named clones existed on the
branch the spec named**, including all three of `android_hardware_qcom_{audio,display,media}` on
`lineage-23.2-caf-sdm845` - round 1's "no `lineage-*` branch at all" was an artefact of searching for repo
names containing `qcom-caf`, which finds a different, dead `-caf`-suffixed set of repos.
**Our 10 variables: OK 10, DEAD 0, BROKEN 0.** The three new repos read **none** of them: they read
`qtiaudio.*` (6), `qtidisplay.*` (10) and `ANDROID.target_board_platform` only.
Two round-1 conclusions are **wrong and are corrected here**:
1. **`charging_control_supports_bypass=false` does disable bypass.** Round 1 inferred an empty make value
   would fall to the reader's `default:`. Soong's typed-bool path turns it into a real `false`, which
   matches the reader's `false:` key. Proof chain below.
2. **`hardware/qcom-caf/common/BoardConfigQcom.mk` *is* included in our build** (via `android_build`
   `core/config.mk:478` -> `vendor/lineage/config/BoardConfigLineage.mk:10`, gated on
   `BOARD_USES_QCOM_HARDWARE := true`, which we set). So the `qtidisplay`/`qtiaudio` namespaces **are**
   populated, and `qtidisplay.drmpp=true`, `qtidisplay.master_side_cp=true` and
   `rmnetctl.old_rmnet_data=true` reach modules we package. The qtidisplay question is **settled**.
Also settled: `TARGET_BOARD_PLATFORM := sdm710` needs **no** sdm710 manifest project - `gralloc.sdm710` is
`gralloc.qcom` renamed at build time by `ANDROID.target_board_platform`.
**Lead must check first:** nothing here breaks the build. The one real gap is 9 `lineage_health.*`
variables the reader wants and we do not set (safe defaults), and the fact that **`LINEAGE_BUILD` must be
set** or `BoardConfigQcom.mk` is silently skipped - so always build via `brunch gts4lvwifi`.

## Method and pinned commits

Clones in `~/work/clone-R3r2` (`--filter=blob:none --single-branch`, read-only, outside this repo).
Every SHA below was re-verified with `git cat-file -e`; every `path:line` was re-verified by printing the line.

| Role | Repo | Branch | Tip SHA used |
|---|---|---|---|
| a) our device fork | `anton-scholten/android_device_samsung_gts4lv-common` | `lineage-23.2` | `2e50286ebc01070c11be5e618ee557a6073709ff` |
| b) LTE device | `LineageOS/android_device_samsung_gts4lv` | `lineage-22.2` | `3260fd2c4f1abcf0303485afa9fa4a7b3faec98b` |
| c) Wi-Fi device | `LineageOS/android_device_samsung_gts4lvwifi` | `lineage-22.2` | `b54236c99ffb18aab2387833274cca7009c6c17c` |
| reader | `LineageOS/android_hardware_samsung` | `lineage-23.2` | `5d20e3541d147494e074bf710d35b1960a6ed0a2` |
| reader | `LineageOS/android_hardware_qcom-caf_common` | `lineage-23.2` | `1805784d14b386fce6127f2f06b5a16a3e9b94ed` |
| reader (NEW) | `LineageOS/android_hardware_qcom_audio` | `lineage-23.2-caf-sdm845` | `d5ad5c133b7024606b0ab9a720265fd7f9f0e6b6` |
| reader (NEW) | `LineageOS/android_hardware_qcom_display` | `lineage-23.2-caf-sdm845` | `601faec098fd0eb5ad98bc323d62e5479417f623` |
| reader (NEW) | `LineageOS/android_hardware_qcom_media` | `lineage-23.2-caf-sdm845` | `c14d81523fa2a24769ecec5e3c488aa96c1a6708` |
| reader | `LineageOS/android_vendor_lineage` | `lineage-23.2` | `686d8669737d2207208ea21075320840b5ec8463` |
| reader (found, outside spec) | `LineageOS/android_hardware_lineage_interfaces` | `lineage-23.2` | `805d25348106e8cc6f378c0b153789f3cf8da667` |
| reference | `LineageOS/android_device_samsung_sm7125-common` | `lineage-23.2` | `865ff7e3742428d282f17b4995f8d37908b7ca82` |
| reference (default branch of the same display repo) | `LineageOS/android_hardware_qcom_display` | `lineage-23.2-caf-msm8953` | `fd1cfe095f3cb4073f2ac6216e4d4457ba50f312` |
| manifest | `LineageOS/android` | `lineage-23.2` | `eabe68377217a88c81fa933db0136ea4146ff369` |
| build system | `LineageOS/android_build` | `lineage-23.2` | `e5aaa62172df0f321e68133fa30f42316376bfe8` |
| build system | `LineageOS/android_build_soong` | `lineage-23.2` | `9aa045a2aef10b8089e32e847fed26d9aa3d61be` |
| build system | `LineageOS/android_build_blueprint` | `lineage-22.2` (newest that exists) | `c7c63940d4be6a08a01a30ababca3abc0d1ac3da` |

Commands: `git ls-remote --heads`, `git grep -n 'soong_config'`, `git grep -n 'soong_config_variable('`,
a Python pass that attributes every read site to the module that contains it, and a Python pass that
parses every `PRODUCT_PACKAGES` token out of our tree and intersects it with the module names each reader
repo defines.

### Which branches exist - round 1's claim was based on the wrong repos

`git ls-remote --heads <url> | grep -E 'lineage-2'` on the three repos round 1 could not read. **All three
have `lineage-23.2-caf-sdm845`**, and many more per-SoC branches:

- `android_hardware_qcom_audio`: `lineage-23.2`, `lineage-23.2-caf-{msm8953,msm8998,sdm660,sdm845,sm8150,sm8250,sm8350}` (+ `lineage-24.0-caf-*`)
- `android_hardware_qcom_display`: `lineage-23.2-caf-{msm8953,msm8998,sdm660,sdm845,sm8150,sm8250,sm8350,sm8450,sm8450-6.6,sm8550,sm8650,sm8750}` - **no plain `lineage-23.2`**
- `android_hardware_qcom_media`: `lineage-23.2-caf-{msm8953,msm8998,sdm660,sdm845,sm8150,sm8250,sm8350}` - **no plain `lineage-23.2`**

Why round 1 concluded otherwise: it ran a repository search for the string `qcom-caf`, which returns the
**`-caf`-suffixed** repos `android_hardware_qcom_{audio,display,media}-caf` (CM11-era, no `lineage-*`
branch). Those are not the repos the LineageOS manifest uses. The manifest uses the **unsuffixed** repos -
`snippets/lineage.xml:138-140` (`eabe68377217`):
`hardware/qcom-caf/sdm845/{audio,display,media}` = `LineageOS/android_hardware_qcom_{audio,display,media}`
at `lineage-23.2-caf-sdm845`. Round 2 read exactly those.
confidence: high - `git ls-remote --heads` output plus `snippets/lineage.xml:138-140 @ eabe68377217`.

**Which branch we actually get at sync time.** `snippets/lineage.xml` also lists *unpinned* copies at
`hardware/qcom/{audio,display,media}` (lines 66, 71, 73), and `default.xml:1030` includes
`snippets/lineage.xml` unconditionally, so a plain `repo sync` fetches both. An unpinned project resolves
to the repo's **GitHub default branch**, which is *not* sdm845 for two of the three:
`android_hardware_qcom_audio` -> `lineage-23.2`; `android_hardware_qcom_display` -> `lineage-23.2-caf-msm8953`;
`android_hardware_qcom_media` -> `lineage-23.2-caf-msm8953` (GitHub API `/repos/LineageOS/<name>`).
The tree that matters is the sdm845 one, because `cafcommon/BoardConfigQcom.mk:359-360` sets
`QCOM_HARDWARE_VARIANT := sdm845` for our platform (see the qtidisplay section), so
`QCOM_SOONG_NAMESPACE := hardware/qcom-caf/sdm845` (`BoardConfigQcom.mk:387`). The spec's choice of
`lineage-23.2-caf-sdm845` was therefore the right one.
confidence: high for the manifest lines; medium for the "which copy actually wins" claim, because group
filtering of the unpinned copies is a `repo` behaviour I did not test.

### The per-model repos (round 1's claim re-verified)

`git ls-remote --heads https://github.com/LineageOS/android_device_samsung_gts4lv` -> **0** branches matching
`lineage-23`, newest `lineage-22.2` (`3260fd2c4f1a`). Same for `..._gts4lvwifi`: 0, newest `lineage-22.2`
(`b54236c99ffb`). Confirmed, and it matches our own `local_manifests/*.xml`, which pins both to `lineage-22.2`.
confidence: high - direct `git ls-remote` output.

## Definitions in our three device repos

| Repo | `soong_config_set*` | literal `SOONG_CONFIG_*` | `soong_config_module_type` |
|---|---|---|---|
| a) our fork `2e50286ebc01` | **10**, all in `gts4lv.mk` | 0 | 0 |
| b) `gts4lv` `3260fd2c4f1a` | **0** (`git grep -c soong_config` -> exit 1) | 0 | 0 |
| c) `gts4lvwifi` `b54236c99ffb` | **0** (`git grep -c soong_config` -> exit 1) | 0 | 0 |

Round 1's claim re-verified. **b) and c) contribute nothing**, and both variants reach a)'s definitions:
`gts4lv/device.mk:57` and `gts4lvwifi/device.mk:32` both
`$(call inherit-product, device/samsung/gts4lv-common/gts4lv.mk)` (verified line by line). The only
`soong` hits in b)/c) are `soong_namespace {` in their `Android.bp:1` and `PRODUCT_SOONG_NAMESPACES` in
their `device.mk` - not variable definitions.
There are no literal `SOONG_CONFIG_*` make variables in any of the three; `build/make` generates them at
build time (`android_build` @ `e5aaa62172df` `core/config.mk:309-334`) and serialises them
(`core/soong_config.mk:258-273`).
confidence: high - `git grep` exit codes plus the two `inherit-product` lines printed verbatim.

## Main table: the 10 variables our tree defines

Verdict key: **OK** = read by a module our build installs, with a matching type · **DEAD** = set, never read ·
**BROKEN** = read but no longer defined, or type mismatch.

| # | Variable (`namespace.name`) | Defined where (repo:path:line @ commit) | Declared type | Read by (repo:path:line @ commit) | Reader module in our build? | Verdict | Confidence |
|---|---|---|---|---|---|---|---|
| 1 | `rfs.mpss_firmware_symlink_target` | `gts4lv-common` `gts4lv.mk:21` @ `2e50286ebc01` | string | `qcom-caf_common` `Android.bp:239` and `:606` @ `1805784d14b3` | yes - `rfs_mdm_mpss_readonly_firmware_symlink`, added by `common.mk:36`, inherited at `gts4lv.mk:22` | **OK** | high |
| 2 | `samsungCameraVars.needs_sec_reserved_field` | `gts4lv-common` `gts4lv.mk:90` @ `2e50286ebc01` | **bool** | `android_hardware_samsung` `aidl/camera/libhardware_headers/Android.bp:17` @ `5d20e3541d14` | yes - `samsung_camera3_defaults` -> `camera_service_aidl_defaults.samsung` (`aidl/camera/provider/Android.bp:8`) -> `android.hardware.camera.provider-service_32.samsung` at `gts4lv.mk:93` | **OK** | high |
| 3 | `lineage_health.charging_control_charging_path` | `gts4lv-common` `gts4lv.mk:170` @ `2e50286ebc01` | string | `hardware_lineage_interfaces` `health/aidl/default/Android.bp:62` @ `805d25348106` | yes - `vendor.lineage.health-service.default` at `gts4lv.mk:168` | **OK** | high |
| 4 | `lineage_health.charging_control_charging_enabled` | `gts4lv-common` `gts4lv.mk:171` @ `2e50286ebc01` | string | `hardware_lineage_interfaces` `health/aidl/default/Android.bp:74` @ `805d25348106` | yes | **OK** | high |
| 5 | `lineage_health.charging_control_charging_disabled` | `gts4lv-common` `gts4lv.mk:172` @ `2e50286ebc01` | string | `hardware_lineage_interfaces` `health/aidl/default/Android.bp:77` @ `805d25348106` | yes | **OK** | high |
| 6 | `lineage_health.charging_control_supports_bypass` | `gts4lv-common` `gts4lv.mk:173` @ `2e50286ebc01` | **bool** | `hardware_lineage_interfaces` `health/aidl/default/Android.bp:80-83` @ `805d25348106` | yes | **OK** (round 1 said the `false` might not stick - **that was wrong**, see below) | high |
| 7 | `lineage_health.fast_charge_node` | `gts4lv-common` `gts4lv.mk:174` @ `2e50286ebc01` | string | `hardware_lineage_interfaces` `health/aidl/default/Android.bp:96` @ `805d25348106` | yes | **OK** | high |
| 8 | `lineage_health.fast_charge_value_none` | `gts4lv-common` `gts4lv.mk:175` @ `2e50286ebc01` | string | `hardware_lineage_interfaces` `health/aidl/default/Android.bp:99` @ `805d25348106` | yes | **OK** | high |
| 9 | `lineage_health.fast_charge_value_fast_charge` | `gts4lv-common` `gts4lv.mk:176` @ `2e50286ebc01` | string | `hardware_lineage_interfaces` `health/aidl/default/Android.bp:102` @ `805d25348106` | yes | **OK** | high |
| 10 | `samsungVars.target_keymaster4_library` | `gts4lv-common` `gts4lv.mk:190` @ `2e50286ebc01` | string | `android_hardware_samsung` `hidl/keymaster/Android.bp:20` @ `5d20e3541d14` | yes - `android.hardware.keymaster@4.0-service.samsung` at `gts4lv.mk:188` | **OK** | high |

**Counts: OK 10 · DEAD 0 · BROKEN 0.**

Reader repos that supplied each verdict: `android_hardware_samsung` 2, `android_hardware_qcom-caf_common` 1,
`android_hardware_lineage_interfaces` 7. **`android_hardware_qcom_audio`, `..._display`, `..._media` and
`android_vendor_lineage` supplied 0 of our 10** - they read only `qtiaudio.*`, `qtidisplay.*`,
`ANDROID.target_board_platform`, `lineage_bootanimation.*` and `lineage_charger.density`, none of which we set.
confidence: high - every row is a `git grep` hit plus a `PRODUCT_PACKAGES` line, both printed.

### `charging_control_supports_bypass=false` really does disable bypass (round 1 said maybe not)

Round 1 flagged this `medium` because it could not find Soong's `select` coercion rules. Round 2 found them.
The make side, `android_build` @ `e5aaa62172df` `core/config.mk:330-334`, verbatim:

```make
define soong_config_set_bool
$(call soong_config_define_internal,$1,$2) \
$(eval SOONG_CONFIG_$(strip $1)_$(strip $2):=$(filter true,$3))
$(eval SOONG_CONFIG_TYPE_$(strip $1)_$(strip $2):=bool)
endef
```

The filter is `$(filter true,$3)` - **only** `true` - so our `false` yields an **empty string**, plus
`SOONG_CONFIG_TYPE_... := bool`. The build system comment at `core/config.mk:323-327` states the intent:
*"It will only accept "true" for its value, any other value will be treated as false."*

Soong side, `android_build_soong` @ `9aa045a2aef1` `android/module.go:2965-2999`, the `soong_config_variable`
case of `EvaluateConfiguration`. Line 2983, verbatim: `return proptools.ConfigurableValueBool(v == "true")`.
So the empty make value becomes a **typed bool `false`**, not undefined and not an empty string.

Matching side, `android_build_blueprint` @ `c7c63940d4be` `proptools/configurable.go:323-342`
(`matchesValue`), verbatim lines 327, 333, 339-340:

```go
	if v.typ == configurableValueTypeUndefined {
		return false
	}
	...
	if p.typ != v.typ.patternType() {
		return false
	}
	...
	case configurablePatternTypeBool:
		return p.boolValue == v.boolValue
```

The reader (`hli` @ `805d25348106` `health/aidl/default/Android.bp:80-83`) has
`true: [...]` / `false: []` / `default: [-DHEALTH_CHARGING_CONTROL_SUPPORTS_BYPASS]`. A `false:` pattern is
`configurablePatternTypeBool` with `boolValue == false`; the value is `ConfigurableValueBool(false)`; the two
types agree, so **the `false:` branch matches and bypass is disabled.**

This also explains *why* the type declaration matters, which is the point of our patch 0002. With a plain
`soong_config_set(...,false)`, `module.go:2981` would return `ConfigurableValueString("false")`; its
`patternType()` is `configurablePatternTypeString`, which does not equal the `false:` pattern's
`configurablePatternTypeBool`, so `matchesValue` returns false at line 333 and control falls to
`default:` - bypass silently **enabled**. Same mechanism in reverse for
`samsungCameraVars.needs_sec_reserved_field`: without `_bool`, `true:` cannot match and
`-DCAMERA_NEEDS_SEC_RESERVED_FIELD` is dropped. A wrong type is a **silent behaviour change, never a build
error**, so the first build will not catch a regression here.

Cross-checked against AOSP `main` (`platform/build/blueprint`, `refs/heads/main`,
`proptools/configurable.go:349-372`, fetched over `android.googlesource.com`): the same rule, with
`int64` added. `LineageOS/android_build_blueprint` has **no `lineage-23.2` branch** (newest `lineage-22.2`,
`git ls-remote` output: `lineage-22.0`, `lineage-22.1`, `lineage-22.2`), which is why this one file is read
at 22.2 and cross-checked on AOSP main.
confidence: high - three files read directly, plus an independent AOSP-main copy of the matcher.

### The other 8 string-typed variables: reader shapes match

- `samsungVars.target_keymaster4_library` must stay a string: `hidl/keymaster/Android.bp:20-23` uses
  `any @ flag_val: [flag_val]`. Correctly kept as `soong_config_set`. sm7125 `7bc5cf4c4cde` did not touch it.
- `rfs.mpss_firmware_symlink_target` must stay a string: both readers match literal string keys
  (`Android.bp:240-242` and `:607-610`). Ours is `firmware_modem` -> `/vendor/firmware-modem` (`:241`).
- The 6 string `lineage_health` variables use `any @ flag_val:` - string. Correct.
confidence: high - reader blocks printed in full.

## Type changes

`LineageOS/android_device_samsung_sm7125-common` `7bc5cf4c4cdea094016cb5384d8c1f22c2322fb8`
("sm7125-common: Update some soong config variables to bool type", 2025-11-24) changed three setters, and
`aef65d7727ecbf19708622ff5c7222628040e749` ("sm7125-common: move soong_config_set calls to common.mk",
2025-12-09) later moved two of them between files. Both SHAs verified present in `sm7125 @ 865ff7e37424`.

| Variable | sm7125 change | In our tree? | Verdict |
|---|---|---|---|
| `samsungCameraVars.needs_sec_reserved_field` | `soong_config_set` -> `_bool` | yes, `gts4lv.mk:90` | **correct** |
| `lineage_health.charging_control_supports_bypass` | `soong_config_set` -> `_bool` | yes, `gts4lv.mk:173` | **correct** |
| `samsungVibratorVars.duration_amplitude` | `soong_config_set` -> `_bool` | we never define it | **N/A** |

**Our patch 0002 is `90e692ed01a8e91d23f5548eeca1a3e9dd99e6de`** ("gts4lv-common: Update some soong config
variables to bool type"), parent `9ff7da83f972` = patch 0001, on LineageOS 22.2 base `d1b339be7abe`. Its diff
is exactly 2 lines (`gts4lv.mk:90`, `gts4lv.mk:173`), `1 file changed, 2 insertions(+), 2 deletions(-)`.
It is a **faithful subset** of sm7125 `7bc5cf4c4cde`: identical before/after text for both of our lines,
with sm7125's third hunk (`samsungVibratorVars.duration_amplitude`) correctly omitted. It **added and
removed no variables** - all 10 already existed at `d1b339be7abe`. Round 1's assessment re-verified.
confidence: high - `git show 90e692ed01a8` and `git show 7bc5cf4c4cde` diffs read side by side.

**`aef65d7727ec` is NOT APPLICABLE to our tree.** Its whole diff is a move of two lines from
`BoardConfigCommon.mk` to `common.mk` (2 files, +4/-6). Our tree has **no `common.mk`** -
`git ls-tree -r --name-only HEAD` in `dt` lists only `BoardConfigCommon.mk` and `gts4lv.mk`, and all 10 of
our calls already live in `gts4lv.mk`. There is nothing to move. **No action for the lead.**
confidence: high - `git show aef65d7727ec` and the file list of our fork.

## Reverse direction: read by the 6 assigned reader repos, not defined by us

None of these are build breaks. Every one has a `default:` (or `conditions_default:`) branch, so Soong
silently takes the default. Listed because "read but never set" is what makes an upstream feature quietly do
nothing - and because four of these *are* in modules we package.

| Variable | Read by (repo:path:line @ commit) | Reader module; in our build? | Verdict |
|---|---|---|---|
| `rfs.persist_symlink_target` | `qcom-caf_common` `Android.bp:60,94,104,114,148,158,168,202,212,222,257,267,319,353,363,373,407,417,427,461,471,481,525,535,569,579,589,625,635,687,721,731,741,775,785` @ `1805784d14b3` | `install_symlink`s pulled in by `common.mk` (inherited `gts4lv.mk:22`) | OK - default `/mnt/vendor/persist/...` |
| `rfs.firmware_symlink_target` | `qcom-caf_common` `Android.bp:77,131,185,336,390,444,498,552,704,758` @ `1805784d14b3` | same | OK - default `/vendor/firmware_mnt` |
| `qtiaudio.feature_gki` | `qcom_audio` `hal/Android.bp:68`, `post_proc/Android.bp:21` @ `d5ad5c133b70` | `libqcompostprocbundle` (`post_proc`) - **we package it**; `audio.primary.*` (`hal`) - no | OK - **but see the qtiaudio table below** |
| `qtiaudio.feature_instance_id` | `qcom_audio` `hal/Android.bp:71`, `post_proc/Android.bp:24` @ `d5ad5c133b70` | `libqcompostprocbundle` - **yes** | OK - see below |
| `qtiaudio.{feature_ext_amplifier,feature_gef_support,feature_sound_trigger,feature_extended_compress_format}` | `qcom_audio` `hal/Android.bp:44,47,50,59,62,65,74,128` @ `d5ad5c133b70` | `audio.primary.*` only - **not in our build** | N/A |
| `ANDROID.target_board_platform` | `qcom_audio` `hal/Android.bp:77`, `post_proc/Android.bp:65`; `qcom_media` `mm-core/Android.bp:8`, `mm-video-v4l2/vidc/venc/Android.bp:19` @ `d5ad5c133b70` / `c14d81523fa2` | **always set** by `android_build` `core/android_soong_config_vars.mk:313`; consumers `libvolumelistener`, `libOmxVenc` **we package both** | OK - value `sdm710` |
| `qtidisplay.wide_color` | `qcom_display` `sdm/libs/hwc2/Android.bp:16` @ `601faec098fd` | `hwcomposer.qcom` - **we package it** (`gts4lv.mk:128`) | OK - see qtidisplay table |
| `qtidisplay.udfps` | `qcom_display` `sdm/libs/hwc2/Android.bp:19`, `sdm/libs/core/Android.bp:18` @ `601faec098fd` | `hwcomposer.qcom` - **yes** | OK - see below |
| `qtidisplay.drmpp` | `qcom_display` `sdm/libs/core/Android.bp:12` @ `601faec098fd` | `libsdmcore`, a `shared_libs` of `hwcomposer.qcom` - **yes** | OK - see below |
| `qtidisplay.headless` | `qcom_display` `Android.bp:8`, `sdm/libs/core/Android.bp:15,53` @ `601faec098fd` | `display_defaults` / `libsdmcore` - **yes** | OK - default off |
| `qtidisplay.target_uses_aligned_ycbcr_height` | `qcom_display` `gralloc/Android.bp:100` @ `601faec098fd` | `libgrallocutils` -> `gralloc.sdm710` - **yes** | OK - **set to `true` by our tree** |
| `qtidisplay.target_uses_ycrcb_camera_preview` | `qcom_display` `gralloc/Android.bp:65` @ `601faec098fd` | `libgralloccore` -> `gralloc.sdm710` - **yes** | OK - **set to `true` by our tree** |
| `qtidisplay.{target_uses_aligned_ycrcb_height,target_uses_unaligned_nv21_zsl,target_uses_unaligned_ycrcb,target_uses_ycrcb_venus_camera_preview}` | `qcom_display` `gralloc/Android.bp:97,103,106,68` @ `601faec098fd` | `libgrallocutils` / `libgralloccore` - **yes** | OK - all default off |
| `lineage_bootanimation.{height,width,half_res,prebuilt_file}` | `vendor_lineage` `bootanimation/Android.bp:19-22` @ `686d8669737d` | `gen-bootanimation.zip`; we set none of these and package no bootanimation | N/A |
| `lineage_charger.density` | `vendor_lineage` `charger/Android.bp:6` @ `686d8669737d` | charger image; not packaged | N/A |
| `samsungCameraVars.{needs_fps_field,needs_sec_get_cam_pos_v1,needs_sec_get_cam_pos_v2,usage_64bit,extra_ids}` | `android_hardware_samsung` `aidl/camera/libhardware_headers/Android.bp:8,11,14,20`, `aidl/camera/provider/Android.bp:12` @ `5d20e3541d14` | yes - camera modules we package | OK - no flags |
| `samsungVars.target_specific_header_path` | `android_hardware_samsung` `Android.bp:8-22` (its only `soong_config_module_type`, `samsungVars`) @ `5d20e3541d14` | `samsung_header_path_defaults` not packaged | OK - unused |
| `samsungCodec2Vars.{c2_instance_type,target_componentstore_library,uses_legacy_component_store}` | `android_hardware_samsung` `aidl/codec2/Android.bp:30,49,54` @ `5d20e3541d14` | `android.software.media.c2-service.samsung` not packaged | N/A |
| `samsungVibratorVars.duration_amplitude` | `android_hardware_samsung` `aidl/vibrator/Android.bp:11` @ `5d20e3541d14` | `android.hardware.vibrator-service.samsung` not packaged | N/A |
| `samsungUdfpsVars.{dim_layer_zorder,udfps_zorder}` | `android_hardware_samsung` `fingerprint/Android.bp:10,13` @ `5d20e3541d14` | `libudfps_extension.samsung` not packaged | N/A |
| `samsungUsbGadgetVars.gadget_name` | `android_hardware_samsung` `aidl/usb/gadget/Android.bp:32` @ `5d20e3541d14` | `android.hardware.usb.gadget-service.samsung` not packaged | N/A |
| `samsungAudioVars.soundbooster_dsp_library` | `android_hardware_samsung` `soundbooster/Android.bp:14` @ `5d20e3541d14` | `libsamsungSoundbooster_plus` not packaged | N/A |

**Counts: OK 20 · N/A 10 · BROKEN 0.**
confidence: high for the "not packaged" verdicts - I extracted every `PRODUCT_PACKAGES` token from
`gts4lv.mk` + `BoardConfigCommon.mk` (74 tokens) and confirmed each absent name against that set, and
confirmed each present name against the module list of the repo that defines it. Medium only for
`samsungCodec2Vars` / `samsungUsbGadgetVars` / `samsungAudioVars`, where a module could in principle be
reached transitively rather than by name.

## The qtidisplay question: SETTLED - `BoardConfigQcom.mk` *is* included in our build

Round 1 concluded *"nothing in our build includes `BoardConfigQcom.mk`"* and rated that `medium`. **That is
wrong.** The include is in the build system and in `vendor/lineage`, neither of which round 1 read. The
chain, each link verified:

1. `android_build` @ `e5aaa62172df` `core/config.mk:477-479`: `ifneq ($(LINEAGE_BUILD),)` /
   `include vendor/lineage/config/BoardConfigLineage.mk` / `endif`.
2. `android_vendor_lineage` @ `686d8669737d` `config/BoardConfigLineage.mk:9-11`:
   `ifeq ($(BOARD_USES_QCOM_HARDWARE),true)` / `include hardware/qcom-caf/common/BoardConfigQcom.mk` / `endif`.
3. Our tree sets **`BOARD_USES_QCOM_HARDWARE := true`** at `BoardConfigCommon.mk:131`.
4. We inherit `hardware/qcom-caf/common/common.mk` at `gts4lv.mk:22`, so the CAF common tree is present.

**The one condition is `LINEAGE_BUILD`.** It is not a make variable any device tree sets - `git grep
LINEAGE_BUILD` in all three of our device repos returns nothing. It is an **environment** variable exported
by `android_vendor_lineage` @ `686d8669737d` `build/envsetup.sh:15-20`, which sets it to the product name
minus the `lineage_` prefix and exports it. So `brunch gts4lvwifi` -> `LINEAGE_BUILD=gts4lvwifi` ->
included. **A bare `m`/`mm` without going through `envsetup.sh`'s brunch path would silently skip
`BoardConfigQcom.mk`.** Worth stating because the failure is silent.

What `BoardConfigQcom.mk` @ `1805784d14b3` contains, and what it evaluates to for `TARGET_BOARD_PLATFORM := sdm710`
(our `BoardConfigCommon.mk:20`). `sdm710` is in `UM_4_9_FAMILY` (`qcom_defs.mk:8`, verbatim
`UM_4_9_FAMILY := sdm845 sdm710`), and `BoardConfigQcom.mk:15,27,35` build `UM_PLATFORMS`,
`LEGACY_UM_PLATFORMS` and `QSSI_SUPPORTED_PLATFORMS` from those families.

Counts (re-verified): **38 `soong_config_set` calls**, **28 legacy `SOONG_CONFIG_qtidisplay_*` variables**,
**28 members in the `SOONG_CONFIG_qtidisplay` list** at `BoardConfigQcom.mk:167-195`, namespace declared at
`:164`. These agree with round 1's numbers.

Effective `qtidisplay` values for sdm710, and what our build therefore gets:

| `qtidisplay.*` | Value | Source | Reaches our build? |
|---|---|---|---|
| `drmpp` | `true` | `BoardConfigQcom.mk:278-280` (sdm710 in `UM_4_9_FAMILY`) | yes -> `libsdmcore` gets `-DPP_DRM_ENABLE` (`sdm/libs/core/Android.bp:12-14`) |
| `master_side_cp` | `true` | `BoardConfigQcom.mk:321-324` | yes (consumed inside display libs) |
| `displayconfig_enabled` | `false` | `BoardConfigQcom.mk:293-295` needs sdm710 **not** in `UM_PLATFORMS` (the `:= true` is at `:294`) | n/a |
| `gralloc4`, `smmu_proxy`, `ubwcp_headers` | `false` | need 4.14+ / 6.1+ families; the `:= true` assignments at `:284`, `:299`, `:304` are behind the guards at `:283`, `:298`, `:303` | n/a |
| `headless`, `wide_color`, `udfps` | `false` | defaults at `:200`, `:217`, `:204`; we set none of `TARGET_HAS_WIDE_COLOR_DISPLAY`, `TARGET_USES_FOD_ZPOS`, `TARGET_DISPLAY_SHIFT_*` | yes, all off |
| `target_uses_aligned_ycbcr_height` | **`true`** | we set `TARGET_USES_ALIGNED_YCBCR_HEIGHT := true` (`BoardConfigCommon.mk:72`) -> `BoardConfigQcom.mk:252-254` | yes -> `libgrallocutils` |
| `target_uses_ycrcb_camera_preview` | **`true`** | we set `TARGET_USES_YCRCB_CAMERA_PREVIEW := true` (`BoardConfigCommon.mk:73`) -> `BoardConfigQcom.mk:268-269` | yes -> `libgralloccore` |
| `target_uses_aligned_ycrcb_height`, `target_uses_unaligned_nv21_zsl`, `target_uses_unaligned_ycrcb`, `target_uses_ycrcb_venus_camera_preview` | `false` | defaults `:221-224` | yes, off |
| `headers_namespace` | `vendor/qcom/opensource/commonsys-intf/display` | `BoardConfigQcom.mk:394-403`; sdm710 is QSSI-supported via `UM_4_9_FAMILY` at `:38` | yes |
| `gralloc_handle_has_custom_content_md_reserved_size` / `_has_reserved_size` / `_has_ubwcp_format` | `false`/`false`/`false` | `BoardConfigQcom.mk:332-345` (4.14+/6.1+ only) -> `soong_config_set` at `:347-349` | set, but **not read anywhere in `601faec098fd`** |
| Also fired: `qti_thermal.netlink := false` (`:50-52`, sdm710 in `LEGACY_UM_PLATFORMS`) and `soong_config_set,rmnetctl,old_rmnet_data,true` (`:327-328`) | | | |

These string-typed legacy values line up correctly with the readers, which match on **string** keys
(`sdm/libs/core/Android.bp:13` `"true":`, `sdm/libs/hwc2/Android.bp:17` `"true":`) - no type change needed.
`QCOM_HARDWARE_VARIANT := sdm845` for our platform (`BoardConfigQcom.mk:359-360`) and
`QCOM_SOONG_NAMESPACE := hardware/qcom-caf/sdm845` (`:387`).
**Verdict: no build break; `qtidisplay` is populated, not defaulted.** The one nit is three
`gralloc_handle_has_*` variables that are set but read by nothing in this branch of the display repo -
harmless, and not our variables.
confidence: high for the include chain (four files, each line printed) and for the counts. medium for the
per-variable *evaluated* values, because they come from reading `ifeq` conditions by hand rather than
running `m`; I traced every gate to a family list that I did print, but I did not execute make.

### `qtiaudio`: set, but the modules that read the interesting flags are not ours

Same mechanism populates `qtiaudio` (all 31 `qtiaudio` `soong_config_set` calls are behind
`AUDIO_FEATURE_*` / `BOARD_SUPPORTS_*` gates at `BoardConfigQcom.mk:55-161`). Of the 6 `qtiaudio` flags
`android_hardware_qcom_audio` reads, the only two whose reading modules we package are `feature_gki` and
`feature_instance_id`, both in `libqcompostprocbundle`. The other four are read only by `audio.primary.*`,
which we do not build - we package `android.hardware.audio@6.0-impl.gts4lv` (`gts4lv.mk:54`), the Exynos
AOSP audio HAL. So the `qtiaudio` feature flags have no effect on this device either way.
One latent trap, not triggered: `qcom-caf_common/Android.bp:36-54` declares a `soong_config_module_type`
in namespace `android_hardware_audio` with `bool_variables: ["run_64bit"]` and **no** `conditions_default`.
`run_64bit` is set by nothing - `git grep run_64bit` finds it only in that file, and not in
`android_build` either. The `cc_defaults` `android_hardware_qtiaudio_config_defaults` it defines is
referenced by neither `qcom-caf_common` nor `qcom_audio`, and we do not package it, so it does not bite.
confidence: high for "not referenced anywhere" (grepped all six trees); medium for "therefore harmless",
because I did not confirm which mutator stage resolves it.

## `TARGET_BOARD_PLATFORM := sdm710` needs no sdm710 manifest project (round 1's flag, resolved)

Round 1 asked the lead to check whether an sdm710 display project exists, because
`LineageOS/android` @ `eabe68377217` has **no `sdm710` entry** anywhere (`git grep sdm710 -- '*.xml'` in
the manifest: no hits). That observation is right, but the conclusion ("no sdm710 display project") was a
false alarm: `android_hardware_qcom_display` @ `601faec098fd` only defines `gralloc.qcom`
(`gralloc/Android.bp:12`), never `gralloc.sdm710`, in either the sdm845 or the msm8953 23.2 branch
(`fd1cfe095f3c`, checked: module list is identical apart from two `libdisplayconfig`/`libgrallocutils`
differences). Yet our tree packages `gralloc.sdm710` at `gts4lv.mk:127`.

The name is produced at build time. `gralloc/Android.bp:11-20` is a `soong_config_module_type` over
`cc_library_shared` with `config_namespace: "ANDROID"`, `value_variables: ["target_board_platform"]`, and
`name: "gralloc.%s"` (`:15`) under a `conditions_default` of `gralloc.qcom` (`:16-18`). And
`android_build` @ `e5aaa62172df` `core/android_soong_config_vars.mk:313` sets
`soong_config_set,ANDROID,target_board_platform,$(TARGET_BOARD_PLATFORM)`. With
`TARGET_BOARD_PLATFORM := sdm710`, the module is named `gralloc.sdm710` at build time. Same mechanism in
`android_hardware_qcom_audio` `hal/Android.bp:11-19` (`name: "audio.primary.%s"`).
**Nothing for the lead to fix here.** `config/sdm710.mk:11` in the display repo merely adds the name to
`PRODUCT_PACKAGES`; it is not an include we need.
confidence: high - the module-type definition, the namespace setter and `TARGET_BOARD_PLATFORM` were each
printed, and I checked both candidate 23.2 branches for the absence of a literal `gralloc.sdm710` module.

## `android_hardware_lineage_interfaces`: what I can and cannot establish

7 of our 10 variables (all `lineage_health.*`) are read **only** by
`LineageOS/android_hardware_lineage_interfaces` @ `805d25348106`, which is **not** among the six repos this
task names, so round 1 was right to report it separately.

- **Can establish:** the repo exists on `lineage-23.2` @ `805d25348106`; it is in the upstream 23.2 manifest
  as `hardware/lineage/interfaces` with **no revision override** (`snippets/lineage.xml:29` @
  `eabe68377217`), and that snippet is included unconditionally (`default.xml:1030`); the repo's GitHub
  default branch is `lineage-23.2`; and our `local_manifests/*.xml` neither pins nor `remove-project`s it.
  So a plain `repo sync` of our manifests gets it at 23.2.
- **Cannot establish:** what happens if someone adds a `remove-project` or a `lineage-22.2` pin later. The
  consequence would be silent, not a build error: all 9 `charging_control_*` and 4 `fast_charge_*` reads at
  `health/aidl/default/Android.bp:62-108` have `default:` branches, so the health service would compile with
  `-DHEALTH_CHARGING_CONTROL_CHARGING_PATH=` (empty) and the Lineage Health charging UI would quietly do
  nothing. I cannot rule this out without seeing the lead's final manifest.

## Adjacent finding: 9 `lineage_health` variables the reader wants and we do not set

At `health/aidl/default/Android.bp:65-71, 84-95, 105` the same `cc_binary` also reads
`charging_control_deadline_path`, `charging_control_limit_start_path`, `charging_control_limit_stop_path`,
`charging_control_supports_deadline`, `charging_control_supports_limit`, `charging_control_supports_toggle`,
`fast_charge_value_super_fast_charge` - 7 distinct variables we never set. All have `default:` branches, and
three of the four `*_supports_*` ones default to **off** (`default: []` at `:87`, `:91`), so the resulting
behaviour is "no deadline / no charge limit / no toggle", which matches a tablet with no such hardware.
**Verdict: OK (safe defaults), not a defect.** Do not add them without a reason.
confidence: high - read directly from the cited lines.

**Also worth the lead's attention (same class of issue, outside this task's scope):** that repo reads six
more namespaces that our tree sets **nothing** for - `lineagelight.*` (2), `livedisplay_sdm.*` (2),
`livedisplay_sysfs.*` (11), `lineage_powershare.*` (3), `lineage_usb.*` (3),
`power_libperfmgr.mode_extension_lib` (1) - in modules
`android.hardware.light-service.lineage`, `vendor.lineage.livedisplay-service.{sdm,sysfs}`,
`vendor.lineage.powershare-service.default`, `android.hardware.usb@1.3-service.basic` and
`android.hardware.power-service.lineage-libperfmgr`. Our fork's `62cbdacfe76d` ("Migrate to LiveDisplay
AIDL HAL") is the likely reason this matters now. Each has a default, and our tree packages the **Samsung**
livedisplay service (`vendor.lineage.livedisplay-service.samsung-qcom`, `aidl/livedisplay/Android.bp` in
`android_hardware_samsung`), not the `hli` one, so nothing is currently affected - but it is the same
"silently does nothing" shape that R3 exists to catch.
confidence: medium - I confirmed the reader sites and that the module we package comes from `hardware/samsung`,
but I did not audit the `hli` livedisplay modules' internal defaults.

## Cross-repo consistency: what sm7125 sets that we don't

`sm7125-common` @ `865ff7e37424` sets `samsungVibratorVars.duration_amplitude=true`,
`samsungCameraVars.needs_sec_get_cam_pos_v1`, `..._v2`, and `TARGET_USES_FOD_ZPOS := true` (visible in the
`7bc5cf4c4cde` diff context). We set none of them. All their readers either have safe defaults or live in
modules we do not build (`android.hardware.vibrator-service.samsung` is not packaged). **Optional feature
gaps, not defects.** Do not copy them without also copying the corresponding `PRODUCT_PACKAGES` entries -
adding `samsungVibratorVars.duration_amplitude` alone would do nothing.
confidence: medium - I read sm7125's `7bc5cf4c4cde` diff context and its `BoardConfigCommon.mk`, but did not
diff sm7125's full soong-config block against ours line by line (that is task R5's job).

## What the lead must check first

1. **Build with `brunch gts4lvwifi` / `lineage_gts4lv`, not a bare `m`.** `LINEAGE_BUILD` is only
   exported by `android_vendor_lineage` `build/envsetup.sh:20`; without it
   `android_build` `core/config.mk:477` skips `BoardConfigLineage.mk`, which skips
   `BoardConfigQcom.mk`, which silently empties the whole `qtiaudio`/`qtidisplay` namespace. No error,
   no warning. (Not an R3 fix - just do not be surprised.)
2. **Nothing blocks the build.** 0 broken, 0 dead. Soong config is a clean bill of health.
3. **Do not re-apply sm7125 `aef65d7727ec`** - our tree has no `common.mk`, so there is nothing to move.
4. **Do not treat the missing `samsungVibratorVars` / `samsungUdfpsVars` / `samsungCodec2Vars` /
   `samsungUsbGadgetVars` / `samsungAudioVars` values as a gap** - those reader modules are not in our
   `PRODUCT_PACKAGES`.
5. **Keep `hardware/lineage/interfaces` unpinned.** It is the sole reader of 7 of our 10 variables and it is
   not in our `local_manifests`; if it ever gets pinned to 22.2 or removed, the Lineage Health charging UI
   silently stops working with no build error.
6. **Do not change the two `_bool` setters back to `soong_config_set`.** The type declaration is the only
   thing that makes `false:` / `true:` match; getting it wrong is a silent behaviour change, never a build
   error, so no build will catch it.
7. Optional, for whoever wires up the display HAL: confirm that `hardware/qcom-caf/sdm845/{display,audio,media}`
   is the copy in use, since the manifest also carries unpinned copies at `hardware/qcom/{audio,display,media}`
   that resolve to *different* default branches (see "Which branch we actually get at sync time").

## Problems

1. `LineageOS/android_build_blueprint` has **no `lineage-23.2` branch**, so `proptools/configurable.go` (the
   `select` matcher) was read at `lineage-22.2` @ `c7c63940d4be`. Mitigated by also reading AOSP
   `platform/build/blueprint` `refs/heads/main` (`proptools/configurable.go:349-372`), which is identical
   apart from an added `int64` case. The Soong half of the same chain
   (`android_build_soong` @ `9aa045a2aef1`, `android/module.go:2965-2999`) *is* at 23.2.
2. The per-variable `qtidisplay` / `qtiaudio` **values** in the qtidisplay table are derived by reading
   `ifeq` conditions and family lists by hand, not by running `make`. Each gate is cited to a line I printed,
   but they are `medium` confidence for that reason. The include *chain* itself is `high`.
3. `git ls-remote --heads https://github.com/LineageOS` still does not work (`remote: Not Found`), so branch
   discovery was done per full repo name, and repo default branches via
   `https://api.github.com/repos/LineageOS/<name>`.
4. "Which manifest copy of `android_hardware_qcom_{audio,display,media}` wins at sync time" was not tested;
   I report both candidate branches and name the sdm845 one as the intended one, with `medium` confidence.
