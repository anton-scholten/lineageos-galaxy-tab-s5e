<!-- task: R2 | agent: Space Bunny Free | date: 2026-10-03 -->
# R2: sepolicy symbol audit

## Summary
Round 2 of R2. Every SELinux symbol our device tree's `sepolicy/` folder declares or references is
classified and traced to the repo that supplies it. **255 items: 198 types/attributes (75 self-declared
by our own tree, 122 supplied upstream, 1 TE keyword), 18 macros, 15 object classes, 20 permissions,
4 ioctl constants. 0 MISSING.** Upstream dependencies: 140 items from
`LineageOS/android_system_sepolicy` `lineage-23.2` (`885cc500f607`), 35 from
`LineageOS/android_device_qcom_sepolicy_vndr` **`lineage-23.2-legacy-um`** (`0dbc76e4b759`) and 4 from
`LineageOS/android_device_lineage_sepolicy` `lineage-23.2` (`0a9e75292f0e`). Every one of the 122
upstream types is also declared at 22.2, so **there is no "22.2 commit that removed a symbol" to cite**.
**Check first:** `sepolicy/vendor/property_contexts` has **15 of 21 lines that violate the vendor
property-namespace check**; the escape hatch is not set anywhere in our tree. Still open, unrelated to
symbols, and it will surface on the first ROM build - see S1.

## Verdict counts

| verdict | count | meaning |
|---|---|---|
| `SELF` | **75** | declared by our own `sepolicy/`; no upstream dependency |
| `OK` | **179** | declared in a 23.2 tree we actually compile |
| `KEYWORD` | **1** | `self`, a TE keyword, not a declaration |
| `MISSING` | **0** | would break the sepolicy build |
| **total** | **255** | |

Split of the 179 `OK` items by supplier:

| supplier | types/attrs | macros | classes | perms | ioctl consts | total |
|---|---|---|---|---|---|---|
| `android_system_sepolicy` `lineage-23.2` (`885cc500f607`) | 84 | 17 | 15 | 20 | 4 | **140** |
| `android_device_qcom_sepolicy_vndr` `lineage-23.2-legacy-um` (`0dbc76e4b759`) | 35 | 0 | 0 | 0 | 0 | **35** |
| `android_device_lineage_sepolicy` `lineage-23.2` (`0a9e75292f0e`) | 3 | 1 | 0 | 0 | 0 | **4** |

Type/attribute namespace only (198 items): **75 self-declared, 122 upstream, 1 keyword, 0 missing.**
No symbol is supplied by more than one repo, so the three dependency sets are disjoint.

## Sources used

| repo | branch | commit | note |
|---|---|---|---|
| `anton-scholten/android_device_samsung_gts4lv-common` (ours) | `lineage-23.2` | `2e50286ebc01070c11be5e618ee557a6073709ff` | the tree under audit |
| `LineageOS/android_system_sepolicy` | `lineage-23.2` | `885cc500f6078a766d1f6def5ce4c06c55841773` | 140 items |
| `LineageOS/android_system_sepolicy` | `lineage-22.2` | `24428bf868b3ee9e4e304615a5564e88ea8f41e5` | removal check |
| `LineageOS/android_device_qcom_sepolicy_vndr` | `lineage-23.2-legacy-um` | `0dbc76e4b759da5681b8c96b7e2bb7c1ae0cc6b1` | 35 items. **There is no `lineage-23.2` branch in this repo** - see S4 |
| `LineageOS/android_device_qcom_sepolicy_vndr` | `lineage-22.2-legacy-um` | `6d3b8e5a7baa5271c8823171bee35f0a528b328f` | removal check |
| `LineageOS/android_device_lineage_sepolicy` | `lineage-23.2` | `0a9e75292f0ed1a83c31a311b1b32367a9faff75` | 4 items |
| `LineageOS/android_device_lineage_sepolicy` | `lineage-22.2` | `0bced8cc068e75352f3ee6fd03812bc9e11768c9` | removal check |
| `LineageOS/android_device_qcom_sepolicy` | `lineage-23.2` | `d903f8e1e0c47ef5a9df528ee98203cac6de6b43` | QSSI; see S4 |
| `LineageOS/android_device_samsung_sm7125-common` | `lineage-22.2` | `b315034eba10611db905770958ab9c7379b9e5a3` | comparison device, see S1 |
| `LineageOS/android_build` | `lineage-23.2` | `e5aaa62172df0f321e68133fa30f42316376bfe8` | S4 |

## Method, and the traps that produce wrong answers

`sepolicy/` at `2e50286ebc01` is 39 files: 34 `.te`, plus `vendor/{file,genfs,hwservice,property}_contexts`
and `public/property_contexts`. I parsed them with a script rather than reading them, then verified all
410 citations in the tables below by reading the cited `file:line` back out of the clone.

What counts as a use, and what does not:

* `type X, A, B;` -> declares `X` **and** uses attributes `A`, `B`. The 11 attributes we use that way are
  listed separately (section "Attributes").
* `allow SRC TGT:CLASS PERMS` -> uses `SRC` and `TGT`; `CLASS` is an object class; the tokens in `PERMS`
  are permissions or perms-macros. `self` is a TE keyword, not a type.
* A macro call `MACRO(a,b)` uses the macro **and** every identifier argument. `r_dir_file(tee, efs_file)`
  uses `efs_file`; `vendor_internal_prop(csc_prop)` both *declares* `csc_prop` and uses the macro.
* The `u:object_r:NAME:s0` field of a `file_contexts` / `genfs_contexts` / `hwservice_contexts` /
  `property_contexts` line is a real use of `NAME`. This matters: `hal_thermal_default_exec`
  (`vendor/file_contexts:175`), `hal_audio_hwservice` (`vendor/hwservice_contexts:3`) and
  `exported_system_prop` (`public/property_contexts:1`) are used **only** there, so a `.te`-only grep
  misses all three.
* Nothing in our `sepolicy/` sits inside an `#ifdef`, and the only conditional is
  `userdebug_or_eng(\` ... ')` at `vendor/hal_sensors_default.te:18-20`, whose body is live on
  userdebug/eng. I counted it as a use and flagged it separately.

Five traps I hit, so the lead does not repeat them:

1. **A symbol in a `.te` file can be a declaration or a reference.** `sepolicy/vendor/device.te` declares
   13 block-device types that exist nowhere else; `sepolicy/vendor/kernel.te:1` merely *uses*
   `block_device`. A `git grep -nE '^(type|attribute) <name>'` over our own tree is how you tell them
   apart - and it must be run over our tree first, before any upstream lookup.
2. **AOSP declares most property types with a macro, not with `type`.** `exported_default_prop` is
   `system_vendor_config_prop(exported_default_prop)` at `public/property.te:156` @ `885cc500f607`.
   A `git grep -w '^type exported_default_prop,'` finds nothing and you would wrongly report it missing.
   The property macros themselves chain: `vendor_internal_prop` (`public/te_macros:1030`) calls
   `define_prop` (`public/te_macros:944`), and *that* is where the `type` statement is
   (`public/te_macros:945`). My first two attempts at detecting "type-declaring macros" missed that
   chain and reported 6 real symbols as missing; they are present (verified by hand at
   `public/property.te:156,219,221,229,230,241`).
3. **Only the COMPILED directories count.** `android_system_sepolicy` carries frozen snapshots under
   `prebuilts/api/{29.0..34.0,202404,202504}/`. Those feed `precompiled_policy` compat checks and are
   given the separate tags `.plat_public_<ver>` / `.plat_private_<ver>`
   (`build/soong/build_files.go:104-105` @ `885cc500f607`), so they are **not** part of the built
   policy. Grepping the whole repo lets a symbol that was already deleted survive via `prebuilts/` and
   look fine. The compiled set is `public`, `private`, `vendor`, `reqd_mask`
   (`build_files.go:84-93`) - `compat/` and `microdroid/` are not ours either.
4. **`android_device_qcom_sepolicy_vndr` must be searched per-branch and per-directory.** It has **no
   `lineage-23.2` branch**; the branch is `lineage-23.2-legacy-um`. Inside that branch only
   `legacy/vendor/...` is compiled for us, because `TARGET_BOARD_PLATFORM := sdm710`
   (`BoardConfigCommon.mk:20` @ `2e50286ebc01`) makes `SEPolicy.mk:68` take the
   `ifneq (,$(filter sdm845 sdm710, ...))` branch. `generic/vendor/...` and `qva/vendor/...` in the same
   repo are **not** compiled. See the dedicated section below.
5. **`git grep` prints a `path:line:` prefix it will not match in its own pattern**, and `git grep -E` is
   POSIX ERE, so `(?:...)` silently matches nothing. Both mistakes make every symbol look missing.

## S1 - OPEN RISK, not a symbol question: 15 vendor `property_contexts` lines violate the namespace check

I did **not** try to settle this and it is **not** part of the 255-item verdict. It is restated because
it will fail the build and must not get lost.

`LineageOS/android_system_sepolicy` runs `check_prop_prefix.py` over every **vendor** `property_contexts`.
`build/soong/selinux_contexts.go:421-422` @ `885cc500f607` calls it whenever the module is
`SocSpecific()` or `DeviceSpecific()` and the shipping API level is >= Q; our
`vendor_property_contexts` is `soc_specific: true` (`contexts/Android.bp:274-281`), so it applies. The
tool exits 1 on any violation (`tests/check_prop_prefix.py:89`) unless
`BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE := true` (`selinux_contexts.go:404`). The allowed property
prefixes are listed at `selinux_contexts.go:364-382` and the context-type prefixes (`vendor_`, `odm_`) at
`:389-393`; `persist.camera.` is allowed only when the shipping API level is <= R (`:383-385`).

`sepolicy/vendor/property_contexts` breaks one or both rules on **15 of 21 lines**. I re-derived this
with the tool's own predicate:

| line | entry | context type | breaks |
|---|---|---|---|
| 1 | `camera.` | `camera_prop` | prefix + type |
| 2 | `cnss_diag.service` | `sec_cnss_diag_prop` | prefix + type |
| 3 | `init.svc.compact_dump` | `compact_dump_prop` | prefix + type |
| 4 | `mdc.` | `csc_prop` | prefix + type |
| 5 | `persist.camera.` | `camera_prop` | prefix + type (`persist.camera.` only to API 30) |
| 6 | `persist.sys.bt.driver.version` | `vendor_bluetooth_prop` | prefix |
| 7 | `persist.sys.ina.status` | `ina_status_prop` | prefix + type |
| 8 | `persist.vendor.camera.` | `sec_camera_prop` | type |
| 9 | `persist.vendor.camera.debug.logfile` | `sec_camera_prop` | type |
| 11 | `ro.csc.` | `csc_prop` | prefix + type |
| 12 | `ro.error.receiver.default` | `receiver_error_prop` | prefix + type |
| 13 | `ro.factory.factory_binary` | `vendor_factory_prop` | prefix |
| 14 | `ro.fastbootd.available` | `exported_default_prop` | prefix + type |
| 15 | `ro.netflix.channel` | `csc_prop` | prefix + type |
| 19 | `vendor.npu.usr_drv.log_mask` | `sec_camera_prop` | type |

New information this round: the escape hatch is **not** in our device tree, and **not** in the
comparison device either. I grepped `*.mk` and `*.bp` in `android_device_samsung_gts4lv-common`
`2e50286ebc01` and in `LineageOS/android_device_samsung_sm7125-common` `lineage-22.2`
(`b315034eba10611db905770958ab9c7379b9e5a3`): no `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE`, no
`BOARD_VENDOR_API_LEVEL`, no `PRODUCT_SHIPPING_API_LEVEL`. sm7125's own
`sepolicy/vendor/property_contexts` is **0 of 16 lines** in violation, i.e. it was written to pass. So
the 22.2 gts4lv build was not surviving this by an escape hatch in a device tree - either a repo I did
not clone set it, or `shippingApiLevel` resolved below Q. That last one is the open question, and it is
answerable in one command during the build.

**Action for the lead:** before the first build, grep the assembled manifest for
`BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` **and** print `PRODUCT_SHIPPING_API_LEVEL`. If the shipping API
level is >= Q and the flag is unset, either set the flag or fix the 15 lines.
confidence: high on the rule and on the 15 lines (both are the tool's own predicate, read at
`885cc500f607`); medium on the outcome, because I cannot run `m` and so cannot read the resolved
`shippingApiLevel`.

## S2 - the 39 symbols that are NOT in AOSP `android_system_sepolicy`

These are the ones a naive "grep AOSP sepolicy" would wrongly flag. Each is fine, but each is a
dependency on a repo outside AOSP, so if the manifest ever points at a different branch they break.

### 35 types from `android_device_qcom_sepolicy_vndr` `lineage-23.2-legacy-um` (`0dbc76e4b759`)

All in the compiled `legacy/vendor/...` dirs. Each is also declared at `lineage-22.2-legacy-um`
(`6d3b8e5a7baa5271c8823171bee35f0a528b328f`) at the same path, so nothing was removed. Full table below.

### 3 types + 1 macro from `android_device_lineage_sepolicy` `lineage-23.2` (`0a9e75292f0e`)

`hal_lineage_health_default`, `hal_lineage_livedisplay_sysfs`, `hal_lineage_livedisplay_sysfs_exec` from
`common/vendor/`, and the macro `rw_dir_file` from `common/public/te_macros:5`. All four are present at
22.2 (`0bced8cc068e`) too.

`rw_dir_file` is the trap from last round and it holds up: it is **not** an AOSP macro. It is absent
from `android_system_sepolicy` in both 22.2 and 23.2, so a `git grep -w rw_dir_file` there returns
nothing and looks like a removal. It is not. The other seven property types last round named
(`camera_prop`, `graphics_vulkan_prop`, `sensors_dbg_prop`, `vendor_iop_prop`, `vendor_radio_prop`,
`vendor_bluetooth_prop`, `vendor_sysfs_usb_data_enabled`) are also Qualcomm's, in
`legacy/vendor/common/{property,file}.te` - confirmed again this round.

`common/vendor` reaching the build is conditional and the condition holds for us.
`common/sepolicy.mk:6-10` sets `TARGET_USES_PREBUILT_VENDOR_SEPOLICY ?= true` only when
`TARGET_COPY_OUT_VENDOR == vendor` **and** `BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE` is empty. Our tree sets
`TARGET_COPY_OUT_VENDOR := vendor` (`BoardConfigCommon.mk:119`) but also
`BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4` (`BoardConfigCommon.mk:116`), so the `?=` does not fire,
the `else` branch at `common/sepolicy.mk:22-26` runs, and `common/dynamic` + `common/vendor` are added.
If anyone ever drops that `ext4` line, three types disappear.
confidence: high - read directly from both `.mk` files and `BoardConfigCommon.mk`.

## S3 - which `sepolicy_vndr` directories are compiled, and `vendor_log_file`

This decides whether a symbol exists, so it is worth spelling out. `TARGET_BOARD_PLATFORM := sdm710`
(`BoardConfigCommon.mk:20` @ `2e50286ebc01`), so `android_device_qcom_sepolicy_vndr/SEPolicy.mk` takes the
**`ifneq (,$(filter sdm845 sdm710, $(TARGET_BOARD_PLATFORM)))`** branch at `0dbc76e4b759:68-95`, not
the `ifeq (,...)` branch at `:35-66`. Compiled vendor dirs:

```
device/qcom/sepolicy_vndr/legacy-um                       (root; no policy files)
  legacy/vendor/ssg                                  SEPolicy.mk:72
  legacy/vendor/common                               SEPolicy.mk:73
  legacy/vendor/common/logdump                       SEPolicy.mk:78  (unless TARGET_USES_LOGDUMP_AS_METADATA)
  legacy/vendor/common/debugfs                       SEPolicy.mk:88  (eng only, unless PRODUCT_SET_DEBUGFS_RESTRICTIONS)
  legacy/vendor/test                                 SEPolicy.mk:91  (eng only)
  legacy/vendor/test/debugfs                         SEPolicy.mk:89  (eng only, unless PRODUCT_SET_DEBUGFS_RESTRICTIONS)
  legacy/vendor/test/sysmonapp                       SEPolicy.mk:92  (eng only)
  legacy/vendor/test/mst_test_app                    SEPolicy.mk:93  (eng only)
  legacy/vendor/sdm710                               SEPolicy.mk:82  (TARGET_SEPOLICY_DIR is empty)
```

`generic/vendor/...` and `qva/vendor/...` are therefore **not** compiled for us, even though they sit in
the same repo. Note the repo is checked out at `device/qcom/sepolicy_vndr/legacy-um`, so the on-disk
paths inside the clone are `legacy/vendor/...` with no `legacy-um/` prefix; I hit this and it initially
made all 35 symbols look absent at 22.2.

Consequences worth carrying forward:

* **`vendor_log_file` is declared twice in the tree but compiled once.** Ours:
  `sepolicy/vendor/file.te:6` @ `2e50286ebc01`. Qualcomm's: `generic/vendor/common/file.te:111` @
  `0dbc76e4b759` - in a directory we do **not** compile. Harmless today; a duplicate-`type` policy build
  error the moment the platform moves off `sdm710`/`sdm845`.
* **Grepping the whole `sepolicy_vndr` repo gives the wrong path for 8 symbols** (`firmware_file`,
  `vendor_audio_data_file`, `vendor_firmware_file`, `vendor_radio_data_file`,
  `vendor_sysfs_usb_data_enabled`, `vendor_bluetooth_prop`, `vendor_radio_prop`, `vendor_log_file`)
  because the `generic/vendor/common` copy sorts first. All 8 are also in `legacy/vendor/common`, which
  is what the table below cites.
* **M4DEF renaming trap.** `qcom/sepolicy.mk:25-40` @ `0a9e75292f0e` adds
  `BOARD_SEPOLICY_M4DEFS` renames (`display_vendor_data_file=vendor_display_vendor_data_file`,
  `hal_gnss_qti=vendor_hal_gnss_qti`, `hal_perf_default=vendor_hal_perf_default`,
  `sysfs_battery_supply=vendor_sysfs_battery_supply`, `sysfs_devfreq=vendor_sysfs_devfreq`, + 9 more)
  **only** when neither `device/qcom/sepolicy-legacy-um/legacy/vendor/common` nor
  `device/qcom/sepolicy_vndr/legacy-um/legacy/vendor/common` is in `BOARD_VENDOR_SEPOLICY_DIRS`. For us
  the latter *is* added (`SEPolicy.mk:73` @ `0dbc76e4b759`), so the `else` branch at `:41-43` applies and
  only `location_domain=location` is set. The plain names in our `.te` files are correct. If the platform
  ever moves off `sdm710`/`sdm845`, **five** symbols we use (`display_vendor_data_file`, `hal_gnss_qti`,
  `hal_perf_default`, `sysfs_battery_supply`, `sysfs_devfreq`) get renamed at once and five of our `.te`
  files break together.
confidence: high - read directly from `SEPolicy.mk:35-95` and `qcom/sepolicy.mk:25-43` at the commits
cited, plus `BoardConfigCommon.mk:20`.

## S4 - manifest branch pins: what the lead must set

`git ls-remote --heads` (checked 2026-10-03):

| repo | `lineage-23.2`? | branch to use |
|---|---|---|
| `LineageOS/android_system_sepolicy` | yes (`885cc500f607`) | `lineage-23.2` |
| `LineageOS/android_device_lineage_sepolicy` | yes (`0a9e75292f0e`) | `lineage-23.2` |
| `LineageOS/android_device_qcom_sepolicy_vndr` | **no** | **`lineage-23.2-legacy-um`** (`0dbc76e4b759`) |
| `LineageOS/android_device_qcom_sepolicy` (QSSI) | **yes** (`d903f8e1e0c4`) | `lineage-23.2` |

This **corrects last round's claim** that `android_device_qcom_sepolicy` has no `lineage-23.2` branch.
It does: `d903f8e1e0c47ef5a9df528ee98203cac6de6b43`. Its `lineage-23.2-legacy-um` is
`8204f3a2895517f82bcc76e69996e51d4ea820fc`, which is the same commit as `lineage-23.0/23.1` and
`lineage-22.2-legacy-um`. The repo does still need to be pinned deliberately - QSSI is a separate repo
from vndr, and our tree does `include device/qcom/sepolicy_vndr/SEPolicy.mk`
(`BoardConfigCommon.mk:151`) but never names the QSSI repo, so it arrives via the manifest alone.

QSSI *is* compiled too. `android_device_qcom_sepolicy/SEPolicy.mk:9-15` @ `d903f8e1e0c4` adds
`generic/public` and `generic/private` to the system_ext policy dirs and `:19-25` adds
`generic/product/{public,private}` and `qva/product/{public,private}` to the product policy dirs; the
`qva/*` system_ext dirs are added by `android_device_qcom_sepolicy_vndr/SEPolicy.mk:14-21` @
`0dbc76e4b759`. I checked all 198 of our type/attribute names and all 18 macros against that compiled
dir set: **0 hits**. So dropping or re-pinning QSSI cannot change any verdict in this report.
confidence: high - branch list from `git ls-remote`, commits resolved, and the zero-hit check was run
over the compiled dir set from its own `SEPolicy.mk`.

## S5 - things I could NOT check statically

A symbol existing does not mean the rule is still legal. Android 16 adds `neverallow` rules a
symbol-level audit cannot see, notably `neverallow { domain -coredomain } { system_property_type
-system_public_property_type }:property_service set;` (`private/property.te:182-185` @ `885cc500f607`)
against our eight `set_prop(vendor_init, ...)` lines in `sepolicy/vendor/vendor_init.te:9-14`, and the
`treble_sysprop_neverallow` block that `vendor_internal_prop` wraps around every property it declares
(`public/te_macros:1030-1034`). Only a real policy build reports those. Not attempted.

One item I could not settle either way, and I will not guess:

**`sepolicy/public/property_contexts:1`** is `service.camera.client u:object_r:exported_system_prop:s0`,
and it lands in the **product** partition (`PRODUCT_PUBLIC_SEPOLICY_DIRS`,
`BoardConfigCommon.mk:156` @ `2e50286ebc01`). `exported_system_prop` is a **platform** property type
(`system_public_prop(exported_system_prop)` at `public/property.te:230` @ `885cc500f607`), and
`service.camera.client` carries no ownership prefix. This is the sort of thing product separation
rejects, but I could not find the enforcing check: the `neverallow` set in `private/property.te` operates
on the m4-expanded type, and `public/attributes:134-137` shows the product attributes are m4 aliases of
the system ones (`product_public_property_type` expands to `system_public_property_type`), which
argues the alias is deliberate and legal. Last round called this low confidence; I still cannot do better
without a build. The clean fix, if it does bite, is to declare a product/vendor property type for it in
our own `sepolicy/public/` instead of borrowing the platform one. Note that dir currently holds only this
one `property_contexts` file, so adding a `property.te` there is cheap.
confidence: low - the type and the partition are certain, the enforcing rule is not; I am reporting the
uncertainty rather than a verdict.

## Notes on scope

* Which of our 39 files are compiled: `sepolicy/vendor` (38 files) via `BOARD_VENDOR_SEPOLICY_DIRS`
  (`BoardConfigCommon.mk:154`), `sepolicy/public` (1 file) via `PRODUCT_PUBLIC_SEPOLICY_DIRS` (`:156`),
  and `sepolicy/private` referenced at `:155` but **absent from the tree** - dead config, the build
  globs and finds nothing. All 39 real files are compiled.
* 2 of the 75 self-declared symbols are declared and never used: `kgsl_device`
  (`sepolicy/vendor/device.te:8`) and `per_proxy_helper_exec` (`sepolicy/vendor/per_proxy_helper.te:2`).
  Neither appears anywhere else in `sepolicy/`. `per_proxy_helper_exec` is the more interesting one:
  `init_daemon_domain(per_proxy_helper)` (`per_proxy_helper.te:4`) expands to
  `domain_auto_trans(init, $1_exec, $1)` (`public/te_macros:163-165` @ `885cc500f607`), which needs
  `per_proxy_helper_exec` to be a **labelled** type, but no `file_contexts` line assigns it. That is a
  latent runtime problem, not a build problem, so it does not change any verdict above.
* `sensors_dbg_prop` is the one conditional symbol: `legacy/vendor/test/property.te:27` is in an
  **eng/userdebug-only** directory (`SEPolicy.mk:91`), and our only use of it is inside
  `userdebug_or_eng(\`...')` at `sepolicy/vendor/hal_sensors_default.te:18-20`. Consistent, so fine -
  but the two conditions must be kept in step.
* Blocked and not used: xdaforums.com, lineageos.org, gerrit, gitea. Nothing in this report needs them.


## Self-defined symbols (75) - declared by our own `sepolicy/`

These have **no** upstream dependency: 65 via a plain `type` statement, 10 via `vendor_internal_prop()` in `sepolicy/vendor/property.te:1-10`. None is declared anywhere else, so nothing here can break from a 22.2 -> 23.2 sepolicy change.

| `app_efs_file` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:9 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `battery_efs_file` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:10 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `bin_nv_data_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:11 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `biometrics_vendor_data_file` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:2 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `botablk_device` | self-defined type | contexts-type | `sepolicy/vendor/device.te`:1 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `carrier_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:12 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `compact_dump_prop` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/property.te` `vendor_internal_prop()` @ `2e50286ebc01` | **our own tree** | SELF | high |
| `cpk_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:13 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `csc_prop` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/property.te` `vendor_internal_prop()` @ `2e50286ebc01` | **our own tree** | SELF | high |
| `debug_block_device` | self-defined type | contexts-type, type | `sepolicy/vendor/device.te`:2 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `drm_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:14 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `dsms_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:15 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `dsp_block_device` | self-defined type | contexts-type | `sepolicy/vendor/device.te`:3 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `dun_device` | self-defined type | contexts-type | `sepolicy/vendor/device.te`:4 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `efs_gsm_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:16 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `efsblk_device` | self-defined type | contexts-type | `sepolicy/vendor/device.te`:5 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `fp_sensor_device` | self-defined type | contexts-type, type | `sepolicy/vendor/device.te`:6 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `gatekeeper_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:17 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `hal_bluetooth_a2dp_hwservice` | self-defined type | contexts-type, type | `sepolicy/vendor/hwservice.te`:1 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `hiddenblk_device` | self-defined type | contexts-type | `sepolicy/vendor/device.te`:7 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `imei_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:18 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `ina_status_prop` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/property.te` `vendor_internal_prop()` @ `2e50286ebc01` | **our own tree** | SELF | high |
| `iss_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:19 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `kpm_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:20 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `macloader` | self-defined type | macro-arg, type | `sepolicy/vendor/macloader.te`:1 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `macloader_exec` | self-defined type | contexts-type | `sepolicy/vendor/macloader.te`:2 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `mb_po_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:21 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `nfc_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:22 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `nv_core_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:23 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `omr_block_device` | self-defined type | contexts-type | `sepolicy/vendor/device.te`:9 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `otadm_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:24 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `paramblk_device` | self-defined type | contexts-type | `sepolicy/vendor/device.te`:10 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `pdp_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:25 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `per_proxy_helper` | self-defined type | macro-arg, type | `sepolicy/vendor/per_proxy_helper.te`:1 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `pfw_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:26 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `proc_default_smp_affinity` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:39 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `proc_last_kmsg` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:40 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `proc_reset_reason` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:41 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `proc_simslot_count` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:42 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `proc_swappiness` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:43 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `prov_efs_file` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:27 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `receiver_error_prop` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/property.te` `vendor_internal_prop()` @ `2e50286ebc01` | **our own tree** | SELF | high |
| `retailmode_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:28 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sec_camera_prop` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/property.te` `vendor_internal_prop()` @ `2e50286ebc01` | **our own tree** | SELF | high |
| `sec_cnss_diag_prop` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/property.te` `vendor_internal_prop()` @ `2e50286ebc01` | **our own tree** | SELF | high |
| `sec_efs_file` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:29 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sec_efsblk_device` | self-defined type | contexts-type | `sepolicy/vendor/device.te`:11 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sec_poc_file` | self-defined type | contexts-type, macro-arg, type | `sepolicy/vendor/file.te`:30 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `secril_config_svc` | self-defined type | macro-arg, type | `sepolicy/vendor/secril_config_svc.te`:1 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `secril_config_svc_exec` | self-defined type | contexts-type | `sepolicy/vendor/secril_config_svc.te`:2 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `snap_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:31 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `snapsec_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:32 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `ssm_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:33 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `steady_block_device` | self-defined type | contexts-type | `sepolicy/vendor/device.te`:12 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sysfs_audio_writable` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:46 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sysfs_camera_writable` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:47 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sysfs_fpc` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:48 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sysfs_lcd_writable` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:49 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sysfs_mdnie_writable` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:50 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sysfs_sec_keypad` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:51 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sysfs_sec_switch` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/file.te`:52 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sysfs_tsp` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:53 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `sysfs_wifi` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:54 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `tee_efs_file` | self-defined type | contexts-type | `sepolicy/vendor/file.te`:34 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `tz_device` | self-defined type | contexts-type, type | `sepolicy/vendor/device.te`:13 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `vaultkeeper_efs_file` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:35 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `vendor_audiopcm_data_file` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:3 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `vendor_convergence_data_file` | self-defined type | contexts-type, macro-arg, type | `sepolicy/vendor/file.te`:4 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `vendor_factory_prop` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/property.te` `vendor_internal_prop()` @ `2e50286ebc01` | **our own tree** | SELF | high |
| `vendor_gps_file` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:5 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `vendor_log_file` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:6 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |
| `vendor_members_prop` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/property.te` `vendor_internal_prop()` @ `2e50286ebc01` | **our own tree** | SELF | high |
| `vendor_qseecomd_prop` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/property.te` `vendor_internal_prop()` @ `2e50286ebc01` | **our own tree** | SELF | high |
| `vendor_tztsdaemon_prop` | self-defined type | contexts-type, macro-arg | `sepolicy/vendor/property.te` `vendor_internal_prop()` @ `2e50286ebc01` | **our own tree** | SELF | high |
| `wifi_efs_file` | self-defined type | contexts-type, type | `sepolicy/vendor/file.te`:36 @ `2e50286ebc01` `type` | **our own tree** | SELF | high |

## Supplied by `LineageOS/android_system_sepolicy` `lineage-23.2` (84 types/attributes)

Each is a plain `type` or `attribute` declaration in the compiled dirs of `885cc500f6078a766d1f6def5ce4c06c55841773`. Every one is also declared at 22.2 (`24428bf868b3`), so none was removed.

| `appdomain` | type/attribute | macro-arg | `public/attributes`:204 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `audio_device` | type/attribute | contexts-type | `public/device.te`:5 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `block_device` | type/attribute | type | `public/device.te`:9 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `bluetooth_efs_file` | type/attribute | contexts-type, type | `public/file.te`:531 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `boot_block_device` | type/attribute | contexts-type | `public/device.te`:95 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `cgroup` | type/attribute | type | `public/file.te`:94 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `ctl_default_prop` | type/attribute | macro-arg | `public/property.te`:219 @885cc500f607 `system_public_prop` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `ctl_start_prop` | type/attribute | macro-arg | `public/property.te`:221 @885cc500f607 `system_public_prop` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `data_file_type` | type/attribute | attr-in-own-decl | `public/attributes`:40 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `dev_type` | type/attribute | attr-in-own-decl | `public/attributes`:8 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `domain` | type/attribute | attr-in-own-decl | `public/attributes`:14 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `dumpstate_options_prop` | type/attribute | macro-arg | `public/property.te`:229 @885cc500f607 `system_public_prop` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `efs_file` | type/attribute | contexts-type, macro-arg, type | `public/file.te`:513 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `exec_type` | type/attribute | attr-in-own-decl | `public/attributes`:37 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `exported_default_prop` | type/attribute | contexts-type | `public/property.te`:156 @885cc500f607 `system_vendor_config_prop` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `exported_system_prop` | type/attribute | contexts-type | `public/property.te`:230 @885cc500f607 `system_public_prop` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `file_type` | type/attribute | attr-in-own-decl | `public/attributes`:34 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `frp_block_device` | type/attribute | contexts-type | `public/device.te`:83 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `fs_type` | type/attribute | attr-in-own-decl | `public/attributes`:19 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `graphics_device` | type/attribute | type | `public/device.te`:29 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_audio_default` | type/attribute | type | `vendor/hal_audio_default.te`:1 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_audio_hwservice` | type/attribute | contexts-type | `public/hwservice.te`:11 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_bluetooth_hwservice` | type/attribute | contexts-type | `public/hwservice.te`:14 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_camera_default` | type/attribute | macro-arg, type | `vendor/hal_camera_default.te`:1 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_camera_default_exec` | type/attribute | contexts-type | `vendor/hal_camera_default.te`:4 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_fingerprint_default` | type/attribute | type | `vendor/hal_fingerprint_default.te`:1 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_fingerprint_default_exec` | type/attribute | contexts-type | `vendor/hal_fingerprint_default.te`:4 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_gatekeeper_default` | type/attribute | macro-arg, type | `vendor/hal_gatekeeper_default.te`:1 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_gnss_default` | type/attribute | macro-arg | `vendor/hal_gnss_default.te`:1 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_gnss_hwservice` | type/attribute | contexts-type | `public/hwservice.te`:27 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_graphics_allocator_default` | type/attribute | macro-arg | `vendor/hal_graphics_allocator_default.te`:1 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_graphics_composer_default` | type/attribute | macro-arg | `vendor/hal_graphics_composer_default.te`:1 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_graphics_mapper_hwservice` | type/attribute | type | `public/hwservice.te`:84 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_health_default` | type/attribute | macro-arg, type | `vendor/hal_health_default.te`:2 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_health_default_exec` | type/attribute | contexts-type | `vendor/hal_health_default.te`:8 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_keymaster_default` | type/attribute | macro-arg, type | `vendor/hal_keymaster_default.te`:1 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_keymaster_default_exec` | type/attribute | contexts-type | `vendor/hal_keymaster_default.te`:4 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_power_default` | type/attribute | type | `vendor/hal_power_default.te`:1 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_sensors_default` | type/attribute | macro-arg, type | `vendor/hal_sensors_default.te`:1 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_sensors_default_exec` | type/attribute | contexts-type | `vendor/hal_sensors_default.te`:4 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_telephony_hwservice` | type/attribute | contexts-type | `public/hwservice.te`:43 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_thermal_default_exec` | type/attribute | contexts-type | `vendor/hal_thermal_default.te`:4 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hal_thermal_hwservice` | type/attribute | contexts-type | `public/hwservice.te`:45 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hwservice_manager_type` | type/attribute | attr-in-own-decl | `public/attributes`:176 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hwservicemanager_prop` | type/attribute | macro-arg | `public/property.te`:241 @885cc500f607 `system_public_prop` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `init` | type/attribute | type | `public/init.te`:2 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `input_device` | type/attribute | type | `public/device.te`:31 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `kernel` | type/attribute | type | `public/kernel.te`:2 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `kmsg_device` | type/attribute | type | `public/device.te`:37 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `mlstrustedobject` | type/attribute | attr-in-own-decl | `public/attributes`:201 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `mnt_vendor_file` | type/attribute | type | `public/file.te`:424 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `proc` | type/attribute | type | `public/file.te`:6 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `proc_hung_task` | type/attribute | type | `public/file.te`:44 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `proc_meminfo` | type/attribute | contexts-type | `public/file.te`:54 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `proc_net` | type/attribute | type | `public/file.te`:58 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `proc_sched` | type/attribute | contexts-type, type | `public/file.te`:70 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `proc_stat` | type/attribute | type | `public/file.te`:72 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `proc_sysrq` | type/attribute | type | `public/file.te`:74 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `proc_type` | type/attribute | attr-in-own-decl | `public/attributes`:61 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `properties_device` | type/attribute | type | `public/device.te`:64 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `radio_device` | type/attribute | contexts-type | `public/device.te`:20 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `rild` | type/attribute | macro-arg, type | `vendor/rild.te`:2 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `rootfs` | type/attribute | type | `public/file.te`:5 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `socket_device` | type/attribute | type | `public/device.te`:44 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sysfs` | type/attribute | type | `public/file.te`:96 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sysfs_batteryinfo` | type/attribute | contexts-type, macro-arg, type | `public/file.te`:99 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sysfs_bluetooth_writable` | type/attribute | contexts-type | `public/file.te`:100 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sysfs_devices_system_cpu` | type/attribute | type | `public/file.te`:151 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sysfs_net` | type/attribute | type | `public/file.te`:120 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sysfs_power` | type/attribute | contexts-type | `public/file.te`:121 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sysfs_rtc` | type/attribute | contexts-type | `public/file.te`:122 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sysfs_type` | type/attribute | attr-in-own-decl | `public/attributes`:72 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sysfs_wlan_fwpath` | type/attribute | type | `public/file.te`:155 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `system_block_device` | type/attribute | contexts-type | `public/device.te`:87 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `system_file` | type/attribute | type | `public/file.te`:196 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `system_server` | type/attribute | type | `public/system_server.te`:5 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `tee` | type/attribute | macro-arg, type | `public/tee.te`:4 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `tee_device` | type/attribute | type | `public/tee.te`:7 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `tun_device` | type/attribute | type | `public/device.te`:59 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `vendor_data_file` | type/attribute | type | `public/file.te`:334 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `vendor_file_type` | type/attribute | attr-in-own-decl | `public/attributes`:58 @885cc500f607 `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `vendor_init` | type/attribute | macro-arg, type | `public/vendor_init.te`:2 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `vendor_shell_exec` | type/attribute | type | `public/vendor_shell.te`:2 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `vold` | type/attribute | type | `public/vold.te`:2 @885cc500f607 `type` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |

## Supplied by `LineageOS/android_device_qcom_sepolicy_vndr` `lineage-23.2-legacy-um` (35 types/attributes)

All in the compiled `legacy/vendor/...` dirs of `0dbc76e4b759`. All are also declared at `lineage-22.2-legacy-um` `6d3b8e5a7baa` at the same path, so none was removed. This is the whole set a naive "grep AOSP" would wrongly flag as missing.

| `adsprpcd` | type/attribute | type | `legacy/vendor/common/adsprpcd.te`:29 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `camera_prop` | type/attribute | contexts-type, macro-arg | `legacy/vendor/common/property.te`:52 @0dbc76e4b759 `vendor_restricted_prop` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `diag_device` | type/attribute | type | `legacy/vendor/common/device.te`:29 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `display_vendor_data_file` | type/attribute | type | `legacy/vendor/common/file.te`:202 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `firmware_file` | type/attribute | type | `legacy/vendor/common/file.te`:29 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `graphics_vulkan_prop` | type/attribute | macro-arg | `legacy/vendor/common/property.te`:98 @0dbc76e4b759 `vendor_restricted_prop` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `hal_bluetooth_qti` | type/attribute | macro-arg, type | `legacy/vendor/common/hal_bluetooth_qti.te`:28 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `hal_gnss_qti` | type/attribute | macro-arg, type | `legacy/vendor/common/hal_gnss_qti.te`:29 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `hal_perf_default` | type/attribute | macro-arg, type | `legacy/vendor/common/hal_perf_default.te`:28 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `hal_usb_qti` | type/attribute | type | `legacy/vendor/common/hal_usb.te`:28 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `location_data_file` | type/attribute | type | `legacy/vendor/common/file.te`:184 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `persist_file` | type/attribute | type | `legacy/vendor/common/file.te`:77 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `qti_init_shell` | type/attribute | macro-arg, type | `legacy/vendor/common/init_shell.te`:31 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `sensors` | type/attribute | type | `legacy/vendor/common/sensors.te`:29 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `sensors_dbg_prop` | type/attribute | macro-arg | `legacy/vendor/test/property.te`:27 @0dbc76e4b759 `vendor_restricted_prop` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `sensors_persist_file` | type/attribute | type | `legacy/vendor/common/file.te`:96 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `sensors_vendor_data_file` | type/attribute | type | `legacy/vendor/common/file.te`:416 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `ssr_device` | type/attribute | type | `legacy/vendor/common/device.te`:82 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `sysfs_audio` | type/attribute | contexts-type | `legacy/vendor/common/file.te`:343 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `sysfs_battery_supply` | type/attribute | contexts-type, type | `legacy/vendor/common/file.te`:127 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `sysfs_devfreq` | type/attribute | macro-arg | `legacy/vendor/common/file.te`:150 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `sysfs_mmc_host` | type/attribute | type | `legacy/vendor/common/file.te`:152 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `sysfs_sensors` | type/attribute | contexts-type, type | `legacy/vendor/common/file.te`:97 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `thermal-engine` | type/attribute | macro-arg, type | `legacy/vendor/common/thermal-engine.te`:29 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `time_daemon` | type/attribute | macro-arg | `legacy/vendor/common/time_daemon.te`:29 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `timeservice_app` | type/attribute | macro-arg | `legacy/vendor/common/timeservice_app.te`:28 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `vendor_audio_data_file` | type/attribute | type | `legacy/vendor/common/file.te`:212 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `vendor_bluetooth_prop` | type/attribute | contexts-type | `legacy/vendor/common/property.te`:122 @0dbc76e4b759 `vendor_restricted_prop` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `vendor_firmware_file` | type/attribute | type | `legacy/vendor/common/file.te`:32 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `vendor_iop_prop` | type/attribute | macro-arg | `legacy/vendor/common/property.te`:61 @0dbc76e4b759 `vendor_restricted_prop` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `vendor_radio_data_file` | type/attribute | contexts-type | `legacy/vendor/common/file.te`:310 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `vendor_radio_prop` | type/attribute | contexts-type, macro-arg | `legacy/vendor/common/property.te`:142 @0dbc76e4b759 `vendor_restricted_prop` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `vendor_sysfs_usb_data_enabled` | type/attribute | contexts-type | `legacy/vendor/common/file.te`:401 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `wcnss_service` | type/attribute | macro-arg, type | `legacy/vendor/common/wcnss_service.te`:28 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |
| `wifi_vendor_wpa_socket` | type/attribute | type | `legacy/vendor/common/file.te`:269 @0dbc76e4b759 `type` | LineageOS/android_device_qcom_sepolicy_vndr `lineage-23.2-legacy-um` | OK | high |

## Supplied by `LineageOS/android_device_lineage_sepolicy` `lineage-23.2` (3 types/attributes)

All in `common/vendor/`, all also at 22.2 (`0bced8cc068e`). See S2 for the `common/vendor` condition.

| `hal_lineage_health_default` | type/attribute | macro-arg | `common/vendor/hal_lineage_health_default.te`:1 @0a9e75292f0e `type` | LineageOS/android_device_lineage_sepolicy `lineage-23.2` | OK | high |
| `hal_lineage_livedisplay_sysfs` | type/attribute | type | `common/vendor/hal_lineage_livedisplay_sysfs.te`:1 @0a9e75292f0e `type` | LineageOS/android_device_lineage_sepolicy `lineage-23.2` | OK | high |
| `hal_lineage_livedisplay_sysfs_exec` | type/attribute | contexts-type | `common/vendor/hal_lineage_livedisplay_sysfs.te`:4 @0a9e75292f0e `type` | LineageOS/android_device_lineage_sepolicy `lineage-23.2` | OK | high |

## Attributes used in our own `type` declarations (11)

A `type X, A, B;` statement uses its attributes too, so these are real uses even though no `allow` mentions them. All are plain `attribute` declarations in `android_system_sepolicy/lineage-23.2`.

| symbol | kind | how we use it | declared at | supplied by | verdict | confidence |
|---|---|---|---|---|---|---|
| `data_file_type` | attribute used in our own `type` decl | `sepolicy/vendor/file.te:2` | `public/attributes`:40 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `dev_type` | attribute used in our own `type` decl | `sepolicy/vendor/device.te:1` | `public/attributes`:8 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `domain` | attribute used in our own `type` decl | `sepolicy/vendor/secril_config_svc.te:1` | `public/attributes`:14 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `exec_type` | attribute used in our own `type` decl | `sepolicy/vendor/secril_config_svc.te:2` | `public/attributes`:37 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `file_type` | attribute used in our own `type` decl | `sepolicy/vendor/secril_config_svc.te:2` | `public/attributes`:34 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `fs_type` | attribute used in our own `type` decl | `sepolicy/vendor/file.te:39` | `public/attributes`:19 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hwservice_manager_type` | attribute used in our own `type` decl | `sepolicy/vendor/hwservice.te:1` | `public/attributes`:176 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `mlstrustedobject` | attribute used in our own `type` decl | `sepolicy/vendor/file.te:9` | `public/attributes`:201 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `proc_type` | attribute used in our own `type` decl | `sepolicy/vendor/file.te:39` | `public/attributes`:61 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sysfs_type` | attribute used in our own `type` decl | `sepolicy/vendor/file.te:46` | `public/attributes`:72 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `vendor_file_type` | attribute used in our own `type` decl | `sepolicy/vendor/secril_config_svc.te:2` | `public/attributes`:58 @ `885cc500f607` `attribute` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |

## Macros (18)

10 are called directly by name in our `.te` files, 8 more are perms-macros appearing at the end of an `allow`. One is **not** from AOSP: `rw_dir_file` is LineageOS's, at `common/public/te_macros:5` @ `0a9e75292f0e` - see S2.

| macro | how we use it | declared at | supplied by | verdict | confidence |
|---|---|---|---|---|---|
| `binder_call` | macro-call | `public/te_macros`:459 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `create_dir_perms` | perms-macro | `public/global_macros`:38 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `create_file_perms` | perms-macro | `public/global_macros`:32 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `create_socket_perms_no_ioctl` | perms-macro | `public/global_macros`:50 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `get_prop` | macro-call | `public/te_macros`:409 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hwbinder_use` | macro-call | `public/te_macros`:437 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `init_daemon_domain` | macro-call | `public/te_macros`:164 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `r_dir_file` | macro-call | `public/te_macros`:69 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `r_dir_perms` | perms-macro | `public/global_macros`:34 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `r_file_perms` | perms-macro | `public/global_macros`:26 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `rw_dir_file` | macro-call | `common/public/te_macros`:5 @ `0a9e75292f0e` | LineageOS/android_device_lineage_sepolicy `lineage-23.2` | OK | high |
| `rw_dir_perms` | perms-macro | `public/global_macros`:37 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `rw_file_perms` | perms-macro | `public/global_macros`:30 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `rx_file_perms` | perms-macro | `public/global_macros`:28 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `set_prop` | macro-call | `public/te_macros`:398 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `vendor_internal_prop` | macro-call | `public/te_macros`:1030 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `vndbinder_use` | macro-call | `public/te_macros`:449 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `w_file_perms` | perms-macro | `public/global_macros`:27 @ `885cc500f607` | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |

## Object classes, permissions and ioctl constants (39)

Not types, but they are symbols the policy compiler resolves, so they are audited too. Each permission is checked against the class it is actually used on, not just its existence.

| symbol | kind | how we use it | declared at | supplied by | verdict | confidence |
|---|---|---|---|---|---|---|
| `blk_file` | class | allow-class | `private/access_vectors`:2 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `capability` | class | allow-class | `private/access_vectors`:3 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `chr_file` | class | allow-class | `private/access_vectors`:1 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `dir` | class | allow-class | `private/access_vectors`:1 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `fifo_file` | class | allow-class | `private/access_vectors`:2 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `file` | class | allow-class | `private/access_vectors`:1 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `hwservice_manager` | class | allow-class | `private/access_vectors`:7 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `key` | class | allow-class | `private/access_vectors`:4 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `lnk_file` | class | allow-class | `private/access_vectors`:1 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `netlink_generic_socket` | class | allow-class | `private/access_vectors`:5 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `netlink_socket` | class | allow-class | `private/access_vectors`:2 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sock_file` | class | allow-class | `private/access_vectors`:2 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `system` | class | allow-class | `private/access_vectors`:3 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `tun_socket` | class | allow-class | `private/access_vectors`:5 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `udp_socket` | class | allow-class | `private/access_vectors`:2 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `SIOCGIFFLAGS` | ioctl-constant | allowxperm-ioctl | `public/ioctl_defines`:1890 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `SIOCSIFFLAGS` | ioctl-constant | allowxperm-ioctl | `public/ioctl_defines`:1996 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `TUNSETIFF` | ioctl-constant | allowxperm-ioctl | `public/ioctl_defines`:2455 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `TUNSETPERSIST` | ioctl-constant | allowxperm-ioctl | `public/ioctl_defines`:2461 @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `add` | permission | allow-perm on hwservice_manager | `private/access_vectors` (class `_`, `a`, `c`, `e`, `g`, `h`, `i`, `m`, `n`, `r`, `s`, `v`, `w`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `chown` | permission | allow-perm on capability | `private/access_vectors` (class `a`, `c`, `p`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `create` | permission | allow-perm on tun_socket,udp_socket | `private/access_vectors` (class `e`, `f`, `i`, `l`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `find` | permission | allow-perm on hwservice_manager | `private/access_vectors` (class `_`, `a`, `c`, `e`, `g`, `h`, `i`, `m`, `n`, `r`, `s`, `v`, `w`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `fowner` | permission | allow-perm on capability | `private/access_vectors` (class `a`, `c`, `p`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `fsetid` | permission | allow-perm on capability | `private/access_vectors` (class `a`, `c`, `p`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `getattr` | permission | allow-perm on file | `private/access_vectors` (class `e`, `f`, `i`, `l`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `ioctl` | permission | allow-perm on udp_socket | `private/access_vectors` (class `e`, `f`, `i`, `l`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `kill` | permission | allow-perm on capability | `private/access_vectors` (class `a`, `c`, `p`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `module_load` | permission | allow-perm on system | `private/access_vectors` (class `e`, `m`, `s`, `t`, `y`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `module_request` | permission | allow-perm on system | `private/access_vectors` (class `e`, `m`, `s`, `t`, `y`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `mounton` | permission | allow-perm on dir,file | `private/access_vectors` (class `e`, `f`, `i`, `l`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `net_admin` | permission | allow-perm on capability | `private/access_vectors` (class `a`, `c`, `p`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `net_raw` | permission | allow-perm on capability | `private/access_vectors` (class `a`, `c`, `p`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `open` | permission | allow-perm on file | `private/access_vectors` (class `e`, `f`, `i`, `l`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `read` | permission | allow-perm on file | `private/access_vectors` (class `e`, `f`, `i`, `l`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `search` | permission | allow-perm on dir,key | `private/access_vectors` (class `e`, `k`, `y`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `setattr` | permission | allow-perm on file | `private/access_vectors` (class `e`, `f`, `i`, `l`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `sys_module` | permission | allow-perm on capability | `private/access_vectors` (class `a`, `c`, `p`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |
| `write` | permission | allow-perm on file | `private/access_vectors` (class `e`, `f`, `i`, `l`) @885cc500f607 | LineageOS/android_system_sepolicy `lineage-23.2` | OK | high |

## Self-check

* every row in the five tables above carries a `declared at` cell with a `file:line` plus a 12-character
  commit, a `supplied by` cell naming the repo and branch, a verdict and a confidence line;
* I re-read all 410 `file:line` citations out of the clones and confirmed the cited line actually
  contains the symbol it is cited for - 410 verified, 0 mismatches, 0 unresolvable;
* the summary gives counts per verdict (SELF 75, OK 179, KEYWORD 1, MISSING 0, total 255) and splits
  them by supplier and by self-defined vs upstream-verified;
* self-defined symbols are in their own table, separate from the three upstream tables;
* MISSING list: empty, so there is no removing commit to report. I still checked: all 84 sp-supplied
  types, all 17 sp-supplied macros, all 35 vndr types and all 3 LineageOS types are declared at their
  respective 22.2 branches, so nothing we use was removed between 22.2 and 23.2.


## Problems

1. **The vendor property-namespace violation in S1 is unresolved and I did not settle it.** The 15 '
   'lines and the rule are certain; whether the build actually fails depends on '
   '`PRODUCT_SHIPPING_API_LEVEL` and `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE`, which I cannot resolve '
   'without running the build. Two candidate device trees (`2e50286ebc01` and sm7125 `b315034eba10`) '
   'contain neither variable, so at least one of them must come from a repo I did not clone - most '
   'likely `device/lineage/lineage_common` or `vendor/lineage`, which are not in the R2 clone list.'
   'I deliberately did not guess which.
2. **`sepolicy/public/property_contexts:1` (S5) stays low confidence.** I confirmed the type is a '
   'platform type and that the file lands in the product partition, and I found that the product '
   'attributes are deliberate m4 aliases of the system ones (`public/attributes:134-137`), which argues '
   'against it being an error - but I could not find the enforcing check either way, so I am not '
   'claiming it fails.'
3. **The compiled-directory reasoning is derived, not observed.** I read `SEPolicy.mk` files rather than '
   'running `m`, so the final `BOARD_VENDOR_SEPOLICY_DIRS` is inferred. It depends on three variables I '
   'cannot see: `TARGET_SEPOLICY_DIR`, `TARGET_USES_LOGDUMP_AS_METADATA` and '
   '`PRODUCT_SET_DEBUGFS_RESTRICTIONS`. The first one is the one that matters (it decides whether '
   '`legacy/vendor/sdm710` or some other dir is added); I re-ran the audit with `legacy/vendor/sdm710` '
   'both in and out of the compiled set and the result is identical - still 0 missing, and still the '
   'same 35 rows, none sourced from `sdm710`. The lead can confirm in one command by printing '
   '`BOARD_VENDOR_SEPOLICY_DIRS`.
4. **Neverallow legality is out of reach for a symbol audit** (S5). A policy build is required; I did '
   'not attempt it and did not guess.
5. **I could not reach `LineageOS/android_device_samsung_samsungexynos` or '
   '`LineageOS/android_hardware_samsung_sepolicy`** (404 from GitHub). If Samsung's shared device '
   'sepolicy lives in a private LineageOS repo it could in principle be a second provider for some '
   'symbol. This does not affect any verdict: all 122 upstream symbols are positively located in a '
   'public repo, and the three dependency sets are disjoint, so no symbol is ambiguous.

