<!-- task: R7 | agent: Space Bunny Free | date: 2026-10-03 -->
# R7: vendor property namespace

## Summary

**Our build will NOT fail `check_prop_prefix.py`.** The check is never run, because
`PRODUCT_SHIPPING_API_LEVEL` resolves to **28** and the check requires **>= 29 (Q)**.

`device/samsung/gts4lv-common/gts4lv.mk:18` @ `2e50286ebc01` inherits AOSP's
`build/target/product/product_launched_with_p.mk`, whose only line is
`PRODUCT_SHIPPING_API_LEVEL := 28` (`product_launched_with_p.mk:2` @ `e5aaa62172df`). Both
models (Wi-Fi and LTE) reach that line. The check is not advisory and no escape hatch is in
play: `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` is set by **nothing** in any repo of the config
chain, and `check_prop_prefix.py:89` would exit 1 on our 15 bad lines if it were called.

- **sm7125 passes because its file genuinely complies**, not because of an exemption: `a52q`
  sets `PRODUCT_SHIPPING_API_LEVEL := 30` (`lineage_a52q.mk:46` @ `f328f13fd1af`), so the check
  **does** run for it, and its 16 property lines produce **0** violations. This settles
  [LEAD-SYNTHESIS.md §7.2](../../LEAD-SYNTHESIS.md).
- The **15 vs 11** discrepancy between earlier rounds is now explained: 15 is the count at
  shipping API >= R, 11 is the count at <= R (at <= R the context-prefix rule is off and
  `persist.camera.` is allowed). We are at 28, so the tool is not called at all.
- **Smallest fix: none.** Do **not** set the flag and do **not** rename anything. See §6 for
  why a rename would be actively harmful.

confidence: high — every step below is a `git`/`python3` result on a pinned SHA; the 15-line count
is the tool's own output.

## 1. Clones

All in `~/work/clone-R7/`, all read-only, all `--filter=blob:none --single-branch`.

| dir | repo | branch | SHA |
|---|---|---|---|
| `soong` | `LineageOS/android_build_soong` | `lineage-23.2` | `9aa045a2aef10b8089e32e847fed26d9aa3d61be` |
| `build` | `LineageOS/android_build` | `lineage-23.2` | `e5aaa62172df0f321e68133fa30f42316376bfe8` |
| `avl` | `LineageOS/android_vendor_lineage` | `lineage-23.2` | `686d8669737d2207208ea21075320840b5ec8463` |
| `dt` | `anton-scholten/android_device_samsung_gts4lv-common` | `lineage-23.2` | `2e50286ebc01070c11be5e618ee557a6073709ff` |
| `gts4lvwifi` | `LineageOS/android_device_samsung_gts4lvwifi` | `lineage-22.2` | `b54236c99ffb18aab2387833274cca7009c6c17c` |
| `gts4lv` | `LineageOS/android_device_samsung_gts4lv` | `lineage-22.2` | `3260fd2c4f1abcf0303485afa9fa4a7b3faec98b` |
| `sm7125` | `LineageOS/android_device_samsung_sm7125-common` | `lineage-23.2` | `865ff7e3742428d282f17b4995f8d37908b7ca82` |
| `a52q` | `LineageOS/android_device_samsung_a52q` | `lineage-23.2` | `f328f13fd1af99b3c37c572ba3ed78c14fb03dc5` |
| `caf` | `LineageOS/android_hardware_qcom-caf_common` | `lineage-23.2` | `1805784d14b386fce6127f2f06b5a16a3e9b94ed` |
| `vndr` | `LineageOS/android_device_qcom_sepolicy_vndr` | `lineage-23.2-legacy-um` | `0dbc76e4b759da5681b8c96b7e2bb7c1ae0cc6b1` |
| `sepolicy` | `LineageOS/android_system_sepolicy` | `lineage-23.2` | `885cc500f6078a766d1f6def5ce4c06c55841773` |
| `core` | `LineageOS/android_system_core` | `lineage-23.2` | `eb2de7321317226bbc1951382b3171fa59bb4d1d` |
| `manifest` | `LineageOS/android` | `lineage-23.2` | `eabe68377217a88c81fa933db0136ea4146ff369` |
| `pvcommon` | `TheMuppets/proprietary_vendor_samsung_gts4lv-common` | `lineage-22.2` | `b04a4eef4efc9975b2e6fbb0beee31c525fc0c95` |

Extra refs fetched for comparison (no branch was checked out or modified):
`build` @ `ab5acb128103`, `sepolicy` @ `24428bf868b3`, `sm7125` @ `b315034eba10` — all
`lineage-22.2`.

Honest note: `bpf`, `build`, `core`, `dt`, `exy9810`, `k670`, `sepolicy` and `sm7125` already
existed in that shared directory from earlier rounds. I reused them after checking repo URL,
branch and SHA; the other six dirs are mine.

No branch name was guessed. `LineageOS/android_device_samsung_sm7125` does not exist (verified
with `git ls-remote --exit-code`); the per-model tree for the a52q is
`LineageOS/android_device_samsung_a52q`.

## 2. The exact skip condition

**Correction to the spec:** `selinux_contexts.go` is **not** in `android_build_soong`. It lives in
`LineageOS/android_system_sepolicy`, at `build/soong/selinux_contexts.go`. The soong repo has no
`selinux_contexts.go` and no reference to `check_prop_prefix` at all
(`grep -rn check_prop_prefix soong/` → 0 hits).

The decision is made here, `build/soong/selinux_contexts.go:419-423` @ `885cc500f607`:

```
419: shippingApiLevel := ctx.DeviceConfig().ShippingApiLevel()
420: ApiLevelQ := android.ApiLevelOrPanic(ctx, "Q")
421: if (ctx.SocSpecific() || ctx.DeviceSpecific()) && shippingApiLevel.GreaterThanOrEqualTo(ApiLevelQ) {
422:     builtCtxFile = m.checkVendorPropertyNamespace(ctx, builtCtxFile)
423: }
```

Answering the four sub-questions:

1. **Which value:** `ShippingApiLevel()`, i.e. the product variable `Shipping_api_level`, which is
   `PRODUCT_SHIPPING_API_LEVEL` (`build/core/soong_config.mk:291` @ `e5aaa62172df`;
   `soong android/config.go:2298-2304` @ `9aa045a2aef1`). Default when nothing sets it:
   `10000` (`build/core/product_config.mk:431-433` @ `e5aaa62172df`).
2. **Threshold:** `ApiLevelOrPanic(ctx, "Q")` = **29** (`soong android/api_levels.go:466-468`:
   `"P": 28, "Q": 29, "R": 30`). 28 is one below.
3. **Must a vendor partition exist?** Effectively yes, but indirectly. The test is on the *module*,
   not on the partition: `vendor_property_contexts` is `soc_specific: true`
   (`contexts/Android.bp:275-284` @ `885cc500f607`), and it is only built because something
   depends on the `selinux_policy_vendor` phony (`Android.bp:1147-1173`).
4. **Per-file or global:** the gate is per **module**; the verdict is global to the build — one
   bad line fails ninja. There is exactly one checked module for us: `vendor_property_contexts`
   (+ its `.recovery` twin). `odm_property_contexts` is also `device_specific: true` but its srcs
   are `{.odm}` only (`contexts/Android.bp:298-303`) and no repo sets `BOARD_ODM_SEPOLICY_DIRS`,
   so it is empty. `plat`/`system_ext`/`product` property contexts are not device/vendor specific
   and are never checked.

Inside the check, `selinux_contexts.go:364-406` @ `885cc500f607`:

- allowed property prefixes: `selinux_contexts.go:364-381` (16 of them, from VTS);
- `persist.camera.` added **only** when shipping API level <= R: `:383-386`;
- allowed context prefixes `vendor_`, `odm_` **only** when shipping API level >= R: `:388-396`;
- `--strict` added **unless** `BuildBrokenVendorPropertyNamespace()`: `:404-406`.

And `tests/check_prop_prefix.py:85-89` @ `885cc500f607` only fails the build inside `if args.strict`.
So the flag does not disable the check, it demotes it from *error* to *warning*.

**This code is byte-identical at 22.2** (`24428bf868b3`), which matters for §3.

confidence: high — quoted lines read directly from the pinned SHAs; the 22.2 comparison is a
`diff` of the extracted function bodies.

## 3. Resolved API levels

### gts4lv and gts4lvwifi: **28**

The chain, all `:=`-style `$(call inherit-product)`, last writer wins:

| Step | file:line | sets |
|---|---|---|
| 1 | `lineage_gts4lvwifi.mk:18` @ `b54236c99ffb` | `core_64_bit.mk` (no shipping level) |
| 2 | `lineage_gts4lvwifi.mk:19` @ `b54236c99ffb` | `full_base.mk` (no shipping level) |
| 3 | `lineage_gts4lvwifi.mk:22` → `device.mk:32` | `device/samsung/gts4lv-common/gts4lv.mk` |
| 4 | **`gts4lv.mk:18` @ `2e50286ebc01`** | **`product_launched_with_p.mk`** |
| 5 | `product_launched_with_p.mk:2` @ `e5aaa62172df` | **`PRODUCT_SHIPPING_API_LEVEL := 28`** |
| 6 | `lineage_gts4lvwifi.mk:25` | `vendor/lineage/config/common_full_tablet_wifionly.mk` — grep for `shipping` in all of `android_vendor_lineage` @ `686d8669737d`: **0 hits** |

The LTE model is the same chain through `device/samsung/gts4lv/device.mk:57` @
`3260fd2c4f1a` → `gts4lv.mk:18`. I also checked `core_64_bit.mk`, `full_base.mk`,
`full_base_telephony.mk` and `non_ab_device.mk` in `build/target/product/`: none of them
mentions `SHIPPING_API_LEVEL`. **Both models: 28.** That is `P`, one below `Q`.

### a52q (sm7125 reference): **30**

`lineage_a52q.mk:46` @ `f328f13fd1af` sets `PRODUCT_SHIPPING_API_LEVEL := 30` explicitly.
`android_device_samsung_sm7125-common` itself never inherits a `product_launched_with_*.mk`
(only `hardware/qcom-caf/common/common.mk` at `common.mk:18` and its own vendor.mk at `:445`),
so every sm7125 device depends on its per-model tree to set the level.

confidence: high — the chain is short, fully enumerated, and every file that could override the
value was grepped.

## 4. How sm7125 passes — the third option, proven

None of the three hypotheses in §7.2 of LEAD-SYNTHESIS is "the check is advisory". sm7125
passes because **the check runs and its file is clean**:

- `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` is **absent everywhere**. Grepped `avl`, `dt`,
  `gts4lv`, `gts4lvwifi`, `sm7125`, `a52q`, `caf`, `vndr`, `build`, `soong`, `sepolicy`, `core`,
  `manifest` — the only hits in the whole set are the definition in
  `build/core/board_config.mk:187` (the list of allowed `true|false` BoardConfig vars) and the
  two uses in `build/core/soong_config.mk:299`. Nobody sets it. (sm7125-common does set
  `BUILD_BROKEN_DUP_RULES` and `BUILD_BROKEN_ELF_PREBUILT_PRODUCT_COPY_FILES`,
  `BoardConfigCommon.mk:19-20` — so the pattern is there, just not for this check.)
- sm7125's API level is 30, i.e. **above** Q, so the check **does** run.
- I ran the tool's own predicate over its file with the exact flag set soong builds at
  `>= R`: **0 violations, exit 0**.

So the "something must exempt sm7125" premise was wrong: nothing exempts anything. sm7125's
`sepolicy/vendor/property_contexts` was simply written to comply (`vendor.`,
`persist.vendor.`, `ro.vendor.` everywhere), and it also complied at 22.2 (`b315034eba10`,
identical apart from two dropped `Power` lines).

confidence: high — the tool was actually executed on both files and the API level chain is in §3.

## 5. The violations, re-derived with the tool

Run on `dt/sepolicy/vendor/property_contexts` @ `2e50286ebc01` (21 non-comment lines):

| shipping API level | flags soong would pass | result |
|---|---|---|
| >= R (30 / 10000, i.e. sm7125's case) | 16 property prefixes + `vendor_`,`odm_` context prefixes + `--strict` | **15 violations, exit 1** |
| <= R (28/29, **our** case) | 16 prefixes + `persist.camera.`, no context prefixes + `--strict` | **11 violations, exit 1** |
| >= R, **without** `--strict` | same, flag set | 15 reported, **exit 0** |

The two earlier rounds were both right, about different API levels. R2's "15 of 21" is the
`>= R` number; the lead's hand-checked "at least 11" is the `<= R` number. The 4 extra lines at
`>= R` are the ones whose *property name* is fine but whose *context type* is not `vendor_`/`odm_`:

| line | entry | fails |
|---|---|---|
| 8 | `persist.vendor.camera.` → `sec_camera_prop` | context |
| 9 | `persist.vendor.camera.debug.logfile` → `sec_camera_prop` | context |
| 2 | `cnss_diag.service` → `sec_cnss_diag_prop` | property + context |
| 19 | `vendor.npu.usr_drv.log_mask` → `sec_camera_prop` | context |

Also verified clean, so they are not hidden offenders in a second file:
`system/sepolicy/reqd_mask/property_contexts` (also fed to `vendor_property_contexts`) → 0
violations; `system/sepolicy/vendor/property_contexts` does not exist; `BOARD_VENDOR_SEPOLICY_DIRS`
for our tree is only `$(COMMON_PATH)/sepolicy/vendor` (`BoardConfigCommon.mk:154` @ `2e50286ebc01`).
The vndr dirs added by `device/qcom/sepolicy_vndr/SEPolicy.mk` (the `sdm845 sdm710` branch, taken
because `TARGET_BOARD_PLATFORM=sdm710`) contain no `property_contexts`. Our `sepolicy/private`
directory does not exist at all, although `BoardConfigCommon.mk:155` adds it (harmless glob miss).

confidence: high — output of `python3 sepolicy/tests/check_prop_prefix.py` on the pinned files.

## 6. Verdict and the smallest fix

### Verdict: the build will not fail.

`28 >= 29` is false, so `checkVendorPropertyNamespace` is never called and the 15 bad lines are
never parsed. Nothing else in the build enforces the vendor property namespace: the only other
consumer, `init`, does a *parse* only and never rejects a non-vendor prefix
(`system/core/init/property_service.cpp:1232-1250` @ `eb2de7321317`, `ParsePropertyInfoFile` errors are
logged, "Individual parsing errors are reported but do not cause a failed boot"). There is no
`$(error)` about the namespace anywhere in `build/core/`.

confidence: high — the gate is a single boolean comparison I read at the pinned SHA, and nothing
else in the tree mentions the rule.

### Smallest fix: **none. Change nothing.**

Do not set `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` — it buys nothing (the check is not running)
and it would add a second, permanent suppression on top of the API-level exemption.

Do not rename the properties. I checked who sets the 15 names before saying this:

- `dt` + `gts4lv` + `gts4lvwifi` + `caf` + `sm7125` + `a52q`, all `*.mk`, `*.rc`, `*.prop`:
  **one** hit outside the property_contexts file, `dt/vendor.prop:119` → `ro.fastbootd.available=true`.
  That one **must not** be renamed: it is a platform property read by name in
  `system/core/init/reboot.cpp:1111` @ `eb2de7321317` (`GetBoolProperty("ro.fastbootd.available", false)`).
  Renaming it to `ro.vendor.fastbootd.available` would build cleanly and silently break the
  `adb reboot fastboot` → bootloader fallback. This is exactly the silent-failure class
  LEAD-SYNTHESIS warns about, and it is the only one of the 15 we can actually see being set.
- The other 14 are set from inside the closed vendor blobs: **0 of the 25** `*.rc` files in
  `TheMuppets/proprietary_vendor_samsung_gts4lv-common` @ `b04a4eef4efc` mention any of them, so
  the setters are `.so` code calling `property_set` with a hard-coded string. A rename cannot
  reach them.

### If the shipping API level is ever raised above 28 (not recommended)

Then the check turns on and the build fails with 15 violations. Ranked fixes:

1. **Keep it at 28.** One word in one line; zero risk. This is the status quo that has been
   building since 2018 and is what every 22.2 user runs today.
2. **`BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE := true`** in `BoardConfigCommon.mk`. One line, build
   passes, labels unchanged, boot behaviour unchanged — verified above that the no-`--strict`
   run exits 0. Cost: it is a permanent "known broken" marker and VTS
   `vts_treble_sys_prop_test` will still flag the 15. Do not use it as a substitute for
   understanding why the level is 28.
3. **Fix the file properly** — do **not** rename the properties. Move the 11 non-vendor-named
   lines from `sepolicy/vendor/property_contexts` to `sepolicy/private/property_contexts`
   (product partition, never namespace-checked), carrying the 7 `vendor_internal_prop` types in
   `sepolicy/vendor/property.te:1-10` across to a product-side `.te`; and rename the 4 types used
   by the context-prefix failures (`sec_camera_prop`, `sec_cnss_diag_prop`) to `vendor_`-prefixed
   names. Cost: a real sepolicy refactor that touches every `get_prop`/`set_prop` on those types,
   with the two property names you cannot move (`ro.fastbootd.available` is read by `init`;
   the rest are set by blobs) still needing to stay where they are. Not worth it for a
   device that has never needed it.

confidence: high on "no fix needed" (read at the pinned SHAs); medium on the cost ranking in
option 3, because I cannot compile sepolicy here and the blob-side setters are unverified beyond
the `.rc` sweep.

## 7. What the lead must check first

1. **Nothing to fix.** `AGENT-TASKS.md` §6b R7 item 5 and P5 item 5 ("whatever R7 decides for the
   vendor property names") can be closed with "no change". `analysis/rom/sepolicy.md` §S1's
   "Action for the lead" is answered; that file is not mine to edit, so the lead should retire
   the OPEN RISK there.
2. **The thing to actually watch is the shipping API level, not the property names.** Any patch
   that sets `PRODUCT_SHIPPING_API_LEVEL` to 29+ anywhere in the chain
   (`lineage_gts4lv*.mk`, `vendor/lineage/config/common_full_tablet*.mk`, or a future
   `target/product/*.mk`) silently turns this check on and the build starts failing. If someone
   ever asks "why is our shipping API level 28?", the answer is that Android 9 (P) is the level
   the Tab S5e first shipped with, and that LineageOS keeps inheriting
   `product_launched_with_p.mk` from AOSP for that reason. `28` also keeps several `>= 29`
   hard `$(error)` blocks in `build/core/config.mk` (lines 839-845, 912-918) from firing, so
   changing it is not a free edit either.
3. If a future ROM build log ever contains `checking namespace of vendor_property_contexts`,
   that means the level moved and someone should re-read this report before touching the file.

## Problems

- One command needed a second try, not a failure: `git sparse-checkout set -- '*.rc'` refused
  with `fatal: specify directories rather than patterns`; re-running with `--no-cone` worked.
  Because of it `pvcommon` has only the 25 `*.rc` files checked out, so the blob-side sweep in
  §6 covers init scripts but not `.so` string tables. `strings` over the blobs would close that
  gap; it is not needed for the verdict, since no fix is recommended.
- `git ls-remote` on `LineageOS/android_device_samsung_sm7125` and `.../android_device_lineage`
  fails with `could not read Username for 'https://github.com'`, i.e. those repos do not exist
  publicly. I did not guess around it: `a52q` is the per-model tree for the sm7125 platform and
  `device/lineage/*` is not in our config chain.
- I could not run `m`, so I did not read `ShippingApiLevel` out of a real build's
  `soong.variables`. The value is derived from the make chain instead (§3), which is a complete
  enumeration rather than a sample.