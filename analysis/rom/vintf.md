<!-- task: R1 | agent: Space Bunny Free | date: 2026-10-03 -->
# R1: VINTF / FCM audit at target-level 6

## Summary
- Matrix used: **`compatibility_matrices/compatibility_matrix.6.xml`** (`level="6"`, FCM S / Android 12) from
  `LineageOS/android_hardware_interfaces` @ `13d687a84c83` (`lineage-23.2`), combined with the three fragments
  `BoardConfigCommon.mk:79-82` actually installs (ours, `hardware/qcom-caf/common`, `hardware/samsung`). The
  level is not a free pick: it is read from the device manifest's `target-level` (`parse_xml.cpp:1263`) and used as
  `deviceLevel` in `CompatibilityMatrix::combine` (`CompatibilityMatrix.cpp:365-372`).
- Audited **32** `<hal>` entries: 25 in `device/samsung/gts4lv-common/manifest.xml` @ `2e50286ebc01` (Wi-Fi model
  `gts4lvwifi`, which has **no** manifest of its own) plus **7** in `LineageOS/android_device_samsung_gts4lv`
  @ `3260fd2c4f1a` `manifest.xml` (LTE model only, wired in by `gts4lv/BoardConfig.mk:29`).
- Counts, manifest-vs-matrix (`checkUnusedHals`) direction, matrix = `compatibility_matrix.6.xml` + the three
  `BoardConfigCommon.mk:79-82` fragments only:
  **Wi-Fi (25 entries): OK 23, BELOW-MIN 1, NOT-COVERED 1. LTE (32 entries): OK 30, BELOW-MIN 1, NOT-COVERED 1.**
  The single NOT-COVERED entry, `vendor.lineage.livedisplay@1`, is an artefact of that fragment list: LineageOS
  installs a fourth covering fragment automatically (M4), so the shipped result is **Wi-Fi OK 24 / BELOW-MIN 1 /
  NOT-COVERED 0** and **LTE OK 31 / BELOW-MIN 1 / NOT-COVERED 0**.
- Counts, mandatory-minimum direction (platform level-6 matrix only, `optional != true`):
  **Wi-Fi: 19 vendor-relevant mandatory instances unsatisfied (+47 framework-side). LTE: 16 (+47).** Two of these are
  ours to fix directly: LTE `radio@1.4` and LTE `radio.config@1.1`.
- **What the lead must fix first:** raise `manifest.xml:1` to `target-level="6"`, then resolve `soundtrigger`
  (declared 2.2, required 2.3, and the sdm710 audio config only ships 2.1), then bump LTE `radio` 1.4 → 1.5.
  **Nothing needs to change for `vendor.lineage.livedisplay`** — round 1 was wrong about that (see C4/C7).

---

## What must change, in order

### M1 — `manifest.xml:1`: `target-level="5"` → `"6"` (the `version` bump is optional)
`manifest.xml:1 @ 2e50286ebc01` reads `<manifest version="1.0" type="device" target-level="5">`.

Why the bump is real: `compatibility_matrix.5.xml @ 13d687a84c83` contains **zero** `<hal>` elements; it is
`level="5"` with only a comment saying "Android R FCM has been deprecated". So today the enforcing HAL set from the
platform is empty, and raising the level to 6 switches on **79 `<hal>` entries / 87 expanded instances** for the
first time. Level 6 is also what the closest official relative uses: `LineageOS/android_device_samsung_sm7125-common`
@ `865ff7e37424` `configs/manifest.xml:1` is `<manifest version="2.0" type="device" target-level="6">`, bumped by
commit `88c7b738785b` "sm7125-common: manifest: Bump target-level to 6" (2024-06-19).

`version="1.0"` is **not** a break and **does not have to change** — see C5. Bumping it to `"2.0"` only matches
`sm7125-common @ 865ff7e37424` `configs/manifest.xml:1`; `LineageOS/android_device_google_sunfish @ 52074bf3c0b6`
ships `<manifest version="1.0" type="device" target-level="7">` (`manifest.xml:28`), so `version="1.0"` is
demonstrably fine even at level 7. Do it if you like, but it is not part of M1's substance.
confidence: high — both manifests and `compatibility_matrix.5.xml` were read directly at the cited commits.

### M2 — `manifest.xml:102-110`: `android.hardware.soundtrigger@2.2` is wrong twice over
Three separate facts, all verified:

1. **Below the level-6 minimum.** `compatibility_matrix.6.xml:540-547` requires HIDL `android.hardware.soundtrigger`
   version **2.3** `ISoundTriggerHw/default` (mandatory, no `optional` attribute). Same at level 7
   (`compatibility_matrix.7.xml:679-686`) and level 8 (`:560-567`). Our `manifest.xml:105` says `2.2`.
2. **Not in any device fragment.** `soundtrigger` appears 0 times in `framework_compatibility_matrix.xml`,
   `hardware/qcom-caf/common/vendor_framework_compatibility_matrix.xml` @ `1805784d14b` and
   `hardware/samsung/vintf/samsung_framework_compatibility_matrix.xml` @ `5d20e3541d14`.
3. **The tree does not ship 2.2 anyway.** `BoardConfigCommon.mk:20 @ 2e50286ebc01` sets
   `TARGET_BOARD_PLATFORM := sdm710`, and `LineageOS/android_hardware_qcom_audio` @ `90647c475fc5`
   (`lineage-23.2-caf-sdm660`, the branch LineageOS uses for this SoC family —
   `snippets/lineage.xml:135`) `configs/sdm710/sdm710.mk:411` builds **`android.hardware.soundtrigger@2.1-impl`**
   and nothing else. Only `kona`, `lahaina` and `bengal` configs get `2.2-impl`/`2.3-impl`
   (`configs/kona/kona.mk:454,458`). There is no 2.2 or 2.3 implementation for sdm710 anywhere in that repo.

So the honest options, none of them free:
- **Recommended:** delete the `soundtrigger` block from `manifest.xml`, and accept that nothing declares the
  mandatory 2.3. `checkUnusedHals` then passes; VTS `DeviceManifestTest` would still flag the missing 2.3, but
  nothing is left claiming a version that is neither built nor allowed.
- **Alternative:** patch `configs/sdm710/sdm710.mk` in a fork of `android_hardware_qcom_audio` to add
  `android.hardware.soundtrigger@2.3-impl`. Out of our repo's scope; the HAL implementation itself does not exist
  in that tree, so this is not a one-line change.

Do **not** copy `sm7125-common`'s line: it declares `soundtrigger@2.2` at `configs/manifest.xml:86` while sitting at
`target-level="6"` (`@ 865ff7e37424`), i.e. the official Samsung tree has the same level-6 violation. It is not a
working precedent.
confidence: high — three files read at the cited commits, line numbers quoted directly.

### M3 — LTE only: `LineageOS/android_device_samsung_gts4lv` `manifest.xml:5`: `radio@1.4` → `1.5`
The LTE model declares, at `manifest.xml:5-6`:
`<fqname>@1.4::IRadio/slot1</fqname>` and `<fqname>@1.2::ISap/slot1</fqname>`.

`compatibility_matrix.6.xml:451-460` makes HIDL `android.hardware.radio` **1.5-6** `IRadio/slot1` mandatory
(`:461-469` makes 1.2 `ISap/slot1|slot2` mandatory too). 1.4 is below that minimum. The requirement was tightened
by commit `add589fd42b338` "compatibility_matrices: Allow radio 1.5 on target-level 6" (2024-06-24), which changed
`<version>1.6</version>` to `<version>1.5-6</version>` in this exact file.

The reference fix is right there: `sm7125-common @ 865ff7e37424` `configs/manifest.xml:61-68` declares
`<fqname>@1.5::IRadio/slot1</fqname>`. Our tree must either mirror that or accept that the LTE model ships no
compliant RIL.

Second, smaller, same file: `compatibility_matrix.6.xml:481-488` also makes `radio.config` HIDL **1.3**
mandatory. Our LTE model declares **1.1** (`manifest.xml:11`); `sm7125-common` also declares 1.1
(`configs/manifest.xml:69-78`). `android.hardware.radio.config` does not appear at 1.2 or 1.3 anywhere in
`hardware/qcom-caf/common @ 1805784d14b` (only HIDL `1.0-1`, `vendor_framework_compatibility_matrix.xml:1011-1018`),
so there is no obvious in-tree source for 1.3. Low priority; record it, do not block on it.

Note this is **only** a mandatory-axis problem. `radio@1.4` *passes* `checkUnusedHals` at level 6 because
`vendor_framework_compatibility_matrix.xml:248-261` (qcom-caf) allows HIDL `android.hardware.radio` **1.0-4**
(`<version>` at `:250`) `IRadio/slot1|slot2` + `ISap/slot1|slot2`. See C6.
confidence: high — matrix, reference manifest and CAF fragment all read at the cited commits.

### M4 — nothing to do for `vendor.lineage.livedisplay@1` (round 1 said otherwise)
Our `manifest.xml:147-158` declares `vendor.lineage.livedisplay` AIDL 1 with `IAdaptiveBacklight/default` and
`IDisplayModes/default` (added by our patch `62cbdacfe76d`).

It is covered, automatically, by the normal LineageOS product chain:
- `LineageOS/android_vendor_lineage` @ `686d8669737d` commit **`60444c0dcd115fd9c436afd2917754a540e8e21d`**
  (2025-11-27, "lineage: Move device_framework_matrix.xml to hardware/lineage/interfaces") deleted
  `config/device_framework_matrix.xml` **and** the `DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE` line, and replaced
  it with `PRODUCT_PACKAGES += framework_compatibility_matrix.lineage.xml` at `config/common.mk:141`.
- That package is `hardware/lineage/interfaces/compatibility_matrices/compatibility_matrix.lineage.xml @ 805d25348106`,
  installed by `hardware/lineage/interfaces/compatibility_matrices/Android.bp:6-13` as a `product_specific`
  matrix fragment. It lists `vendor.lineage.livedisplay` AIDL `1` (`<hal>` at
  `compatibility_matrix.lineage.xml:37-80`) with `IAdaptiveBacklight/default` at `:41-42` and
  `IDisplayModes/default` at `:65-66`.
- Both of our products inherit it: `LineageOS/android_device_samsung_gts4lvwifi @ b54236c99ffb`
  `lineage_gts4lvwifi.mk:25` → `LineageOS/android_device_samsung_gts4lv @ 3260fd2c4f1a` `lineage_gts4lv.mk:25` →
  `vendor/lineage/config/common_full_tablet_wifionly.mk:2` / `common_full_tablet.mk:2` →
  `common_mobile_full.mk:2` → `common_mobile.mk:2` → `common.mk:141`.

So our patch `9ff7da83f972` ("Remove vendor/lineage device framework matrix inclusion") was **correct and
necessary**. Do not hand-add `livedisplay` to our `framework_compatibility_matrix.xml`; that would duplicate the
fragment. The only thing to verify on a built tree is that
`/product/etc/vintf/compatibility_matrix.lineage.xml` exists in the image.
confidence: high — the commit, the file, the Soong module and the full four-hop `inherit-product` chain were each read directly.

### M5 — do not add `<kernel target-level="6"/>` unless you are sure you will never reach level 7
`kEnforceDeviceManifestNoKernelLevel = Level::T` (= 7) at `constants-private.h:81`, enforced by
`checkDeviceManifestNoKernelLevel` at `AssembleVintf.cpp:542-553`, called from `assemble_vintf` at
`AssembleVintf.cpp:604`. A device manifest with `target-level >= 7` that also sets `<kernel target-level=...>` is a
**hard `assemble_vintf` error**. `sm7125-common @ 865ff7e37424` does set `<kernel target-level="6"/>`; copying that
line and later bumping to 7 would break the build.

Not setting it is also fine and is what our tree already does: `shouldCheckKernelCompatibility()`
(`HalManifest.cpp:503-505`) is false whenever `<kernel>` is absent, and `inferredKernelLevel()`
(`HalManifest.cpp:792-805`) falls back to `manifest.level()` for R and above. Our manifest has no `<kernel>`
element at all today.
confidence: high — constants and both code paths read at `2ef218d3586b`.

---

## The rule being applied, and where round 1 got it wrong

`checkUnusedHals` (`VintfObject.cpp:1112-1138`) calls `HalManifest::checkUnusedHals` (`HalManifest.cpp:349-390`),
which for every **manifest** instance asks `CompatibilityMatrix::matchInstance`
(`CompatibilityMatrix.cpp:452-463`) → `forEachInstanceOfVersion` (`CompatibilityMatrix.cpp:435-450`), which tests
`matrixInstance.versionRange().contains(expectVersion)`. `VersionRange::contains`
(`include/vintf/VersionRange.h:50-52`) is `minVer() <= ver && ver <= maxVer()`, and a `VersionRange` is always
**one major version with a minor interval** (`VersionRange.h:32-34`, comment: "A version range with the same major
version, e.g. 2.3-7"). AIDL `<version>1</version>` becomes `Version(SIZE_MAX, 1)`
(`parse_string.cpp:544-547`, `constants-private.h:30`). Failure text: `VintfObject.cpp:1124-1135`.

The enforcing matrix at `target-level="6"` is therefore **exactly**:
`compatibility_matrix.6.xml` + the three `DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE` fragments.

### C1 — the combined matrix is NOT the union of all levels ≤ target-level
`CompatibilityMatrix::combine` at `CompatibilityMatrix.cpp:355-372`:
- `e.level() < deviceLevel` → `addAllKernels` only, **HAL requirements dropped**
- `e.level() == deviceLevel` → `addAll` (hard)
- `e.level() > deviceLevel` → `addAllAsOptional`, and `addAllHalsAsOptional` bails out immediately when
  `other->level() <= level()` (`CompatibilityMatrix.cpp:193-196`)
- fragments with no `level=` attribute get `mLevel = deviceLevel` (`CompatibilityMatrix.cpp:348-352`), so they are hard

Round 1's "a device at level 7 must satisfy the union of levels 5+6+7" is wrong. In practice it does not change our
verdicts — I ran the audit both with only the hard level-6 set and with the realistic A16 set (level 6 hard plus
7/8/202404/202504 merged as optional) and got **identical** counts: Wi-Fi OK 23 / BELOW-MIN 1 / NOT-COVERED 1, LTE
OK 30 / BELOW-MIN 1 / NOT-COVERED 1. (Those figures are against the three `BoardConfigCommon.mk:79-82` fragments
only; add the automatic product fragment and both become NOT-COVERED 0.)
confidence: high — the combine logic was read and both variants computed mechanically.

### C2 — `checkUnusedHals` is **not** a build-time gate
Round 1 called `soundtrigger@2.2` and `livedisplay` "build blockers". They are not. `assemble_vintf` never calls
`checkUnusedHals` (no occurrence in `AssembleVintf.cpp`); it only calls `checkDualFile`
(`AssembleVintf.cpp:319-328`), which is gated on `PRODUCT_ENFORCE_VINTF_MANIFEST` — a variable that is **not set**
in our tree, in `sm7125-common @ 865ff7e37424`, or anywhere in the LineageOS 23.2 platform tree I grepped.
`checkUnusedHals` lives in `checkvintf` (`Android.bp:162-179`, call site `check_vintf.cpp:440`), a host binary used
by VTS. So M2 and C7 are `m checkvintf` / VTS failures, not "the ROM will not build".
confidence: high — grepped `AssembleVintf.cpp` for the symbol (0 hits), read the gating conditions, and grepped
`build/soong @ 533c3c2c9166` for `checkvintf` (0 hits, so it is not wired into Soong at all).

### C3 — `fcm_exclude.cpp` is an exempt list, not a deprecation list
Round 1 said `soundtrigger@2.2` is "on AOSP's deprecated list (`fcm_exclude.cpp:116`)". `fcm_exclude.cpp` defines
`ShouldCheckMissingHidlHalsInFcm` / `ShouldCheckMissingAidlHalsInFcm`
(`exclude/fcm_exclude.cpp:28, 166`), which are predicates for `VintfObject::checkMissingHalsInMatrices`
(`VintfObject.cpp:1275-1320`). `excluded_exact` (`fcm_exclude.cpp:45-146`, the HIDL one) is the list of packages that **may be installed without
appearing in any framework matrix**. `soundtrigger@2.0/2.1/2.2` are at `fcm_exclude.cpp:114-116` and
`radio@1.4`/`radio@1.5` at `fcm_exclude.cpp:112-113`, inside the `// b/392700935 for HALs deprecated in R`
group that starts at `:105` — so the effect is *exemption*, the
opposite of a deprecation error. Also note `radio.config@1.1`/`@1.3` are **commented out** at `fcm_exclude.cpp:136-137` under
`TODO(b/410953636)`.

Separately, round 1's claim that an empty level-5 matrix means "nothing is enforced at all" is wrong:
`check_vintf.cpp:439` runs `checkUnusedHals` when `targetFcm >= Level::R`, and `Level::R = 5`
(`include/vintf/Level.h:41`). So it already runs today, against the three device fragments plus levels 6+
merged as optional.
confidence: high — read the predicate definitions, the call sites and `Level.h`.

### C4 — `hardware/qcom-caf/common` **is** in the LineageOS 23.2 manifest
Round 1's F7 said it is missing and that the build "stops before VINTF is even checked". It is present, in an
included snippet that a `grep` of `default.xml` alone misses: `default.xml:1030` has
`<include name="snippets/lineage.xml" />`, and `snippets/lineage.xml:102` has
`<project path="hardware/qcom-caf/common" name="LineageOS/android_hardware_qcom-caf_common" groups="qcom" >`.
Also in that snippet: `vendor/lineage` (`:61`), `hardware/lineage/interfaces` (`:29`),
`hardware/qcom-caf/thermal-legacy-um` (`:188`), and this SoC family's own audio/display/media on
`lineage-23.2-caf-sdm660` (`:135-137`).
All from `LineageOS/android @ eabe68377217a8`.
confidence: high — both files read at the cited commit; the previous conclusion came from grepping only `default.xml`.

### C5 — `version="1.0"` with an AIDL `<hal>` is legal, and `sunfish` proves it
`metaVersion` is read from the root `version` attribute (`parse_xml.cpp:1324-1328`) and only rejected if it exceeds
`kMetaVersion{9,0}` (`include/vintf/constants.h:26`). AIDL HALs are handled identically at every metaVersion
(`parse_xml.cpp:681-689`). MetaVersion 1 merely *skips* strictness checks such as duplicate `<fqname>`/`<instance>`
(`parse_xml.cpp:982-1015`) and strict `arch` parsing (`parse_xml.cpp:306-315`). Independent confirmation:
`LineageOS/android_device_google_sunfish @ 52074bf3c0b6` `manifest.xml:28` ships
`<manifest version="1.0" type="device" target-level="7">`. So M1's `version="2.0"` is hygiene, not a fix for the
AIDL entry round 1 flagged.
confidence: high — parse code read directly, plus a shipping device manifest that uses the same root version.

### C6 — `radio@1.4` passes `checkUnusedHals` at level 6
Because `vendor_framework_compatibility_matrix.xml:248-261` (qcom-caf, `optional="true"`) allows HIDL
`android.hardware.radio` `1.0-4` with `IRadio/slot1|slot2` and `ISap/slot1|slot2`. Optionality is not stored per-HAL in
libvintf — `matchInstance`/`forEachInstanceOfVersion` never look at it — so an `optional="true"` fragment entry
satisfies the match just the same. M3's real problem is the *mandatory* side, not the unused side.
confidence: high — fragment read at `1805784d14b`; `matchInstance` read at `2ef218d3586b`.

### C7 — `vendor.lineage.livedisplay` **is** covered; see M4
Round 1's F2 predicted a build break and recommended hand-editing our `framework_compatibility_matrix.xml`.
Both wrong; see M4 for the actual mechanism and the four-hop `inherit-product` chain.
confidence: high — see M4.

---

## Verdict table — Wi-Fi model (`gts4lvwifi`), 25 entries in `manifest.xml` @ `2e50286ebc01`

Matrix = `compatibility_matrix.6.xml` @ `13d687a84c83` + the three `BoardConfigCommon.mk:79-82` fragments.
`gts4lvwifi @ b54236c99ffb` has **no** `manifest.xml` and **no** `framework_manifest.xml`, so this file is the whole
device manifest for the Wi-Fi model.

| # | HAL | ours | file:line | level-6 allows | covered by | verdict |
|---|---|---|---|---|---|---|
| 1 | `android.hardware.audio` | hidl 6.0 | `manifest.xml:2-10` | 6.0, 7.0-1 | platform | OK |
| 2 | `android.hardware.audio.effect` | hidl 6.0 | `manifest.xml:11-19` | 6.0, 7.0 | platform | OK |
| 3 | `android.hardware.bluetooth` | hidl 1.0 | `manifest.xml:20-28` | 1.0-1 | platform | OK |
| 4 | `android.hardware.drm` | hidl 1.3 `ICryptoFactory/wfdhdcp`, `IDrmFactory/wfdhdcp` | `manifest.xml:29-34` | 1.3-4 | platform | OK |
| 5 | `android.hardware.gatekeeper` | hidl 1.0 | `manifest.xml:35-43` | 1.0 `IGatekeeper/default` | platform (`samsung frag :6-12` uses instance `mdfpp`, so it does not cover ours) | OK |
| 6 | `android.hardware.graphics.allocator` | hidl 2.0 | `manifest.xml:44-52` | 2.0, 3.0, 4.0 | platform | OK |
| 7 | `android.hardware.graphics.composer` | hidl 2.3 | `manifest.xml:53-61` | 2.1-4 | platform | OK |
| 8 | `android.hardware.graphics.mapper` | hidl 2.1 | `manifest.xml:62-70` | 2.1, 3.0, 4.0 | platform | OK |
| 9 | `android.hardware.keymaster` | hidl 4.0 | `manifest.xml:71-79` | 3.0, 4.0-1 | platform | OK |
| — | `android.hardware.media.c2` | (whole block commented out) | `manifest.xml:80-88` | 1.0-2 `IComponentStore/software`, 1.0 `IConfigurable/{default,software}` | qcom-caf frag (hidl 1.0/1.1/1.2, `IComponentStore/default`, optional) | INFORMATIONAL — see note A |
| 10 | `android.hardware.media.omx` | hidl 1.0 | `manifest.xml:89-101` | 1.0 | platform | OK |
| 11 | `android.hardware.soundtrigger` | hidl **2.2** | `manifest.xml:102-110` (version at `:105`) | **2.3** | — | **BELOW-MIN — M2** |
| 12 | `com.qualcomm.qti.ant` | hidl 1.0 | `manifest.xml:111-119` | — | our own frag (`framework_compatibility_matrix.xml:2-9`, optional) | OK |
| 13 | `vendor.display.color` | hidl 1.2 | `manifest.xml:120-128` | — | qcom-caf frag 1.0-7 | OK |
| 14 | `vendor.display.config` | hidl 2.0 | `manifest.xml:129-137` | — | qcom-caf frag 2.0 | OK |
| 15 | `vendor.display.postproc` | hidl 1.0 | `manifest.xml:138-146` | — | qcom-caf frag 1.0 | OK |
| 16 | `vendor.lineage.livedisplay` | **aidl 1** | `manifest.xml:147-158` | — | product frag `hardware/lineage/interfaces` `compatibility_matrix.lineage.xml:37-80` | OK — M4 |
| 17 | `vendor.qti.hardware.capabilityconfigstore` | hidl 1.0 | `manifest.xml:159-167` | — | qcom-caf frag 1.0 | OK |
| 18 | `vendor.qti.hardware.dsp` | hidl 1.0 | `manifest.xml:168-176` | — | qcom-caf frag 1.0 | OK |
| 19 | `vendor.qti.hardware.perf` | hidl 2.2 | `manifest.xml:177-185` | — | qcom-caf frag 2.0-3 | OK |
| 20 | `vendor.qti.hardware.qseecom` | hidl 1.0 | `manifest.xml:186-194` | — | qcom-caf frag 1.0 | OK |
| 21 | `vendor.qti.hardware.tui_comm` | hidl 1.0 | `manifest.xml:195-203` | — | qcom-caf frag 1.0 | OK |
| 22 | `vendor.qti.hardware.vpp` | hidl 1.1 | `manifest.xml:204-212` | — | qcom-caf frag 1.1-4, 2.0 | OK |
| 23 | `vendor.qti.hardware.wifidisplaysession` | hidl 1.0 (4 interfaces) | `manifest.xml:213-233` | — | qcom-caf frag 1.0 | OK |
| 24 | `vendor.samsung.hardware.bluetooth` | hidl 2.0 | `manifest.xml:234-242` | — | samsung frag `:22-29` (hidl, version `2.0`, `ISehBluetooth/default`) | OK |
| 25 | `vendor.samsung.hardware.gnss` | hidl 2.0 | `manifest.xml:243-251` | — | samsung frag `:86-93` (hidl, version `2.0-1`, `ISehGnss/default`; the AIDL block at `:78-85` is version `2-3`) | OK |

**Wi-Fi counts (25 parsed entries): OK 23, BELOW-MIN 1 (soundtrigger), NOT-COVERED 1 (livedisplay).**
With the product fragment that LineageOS installs automatically (M4), livedisplay becomes OK and the shipped result is
**OK 24, BELOW-MIN 1, NOT-COVERED 0**. `android.hardware.media.c2` is commented out in our manifest
(`:80-88`), so it is not one of the 25 parsed entries and is reported separately as INFORMATIONAL.

Note A — `media.c2`: the level-6 matrix makes it mandatory, the qcom-caf fragment offers HIDL `1.0/1.1/1.2` with
`optional="true"` and instance `IComponentStore/default` — a **different instance** from the mandatory
`IComponentStore/software`. So CAF cannot satisfy the mandatory form; the service has to come from AOSP's software
C2. Nothing to change in our tree. **INFORMATIONAL / verify on a built tree.**
confidence: medium — matrix and fragment entries are certain; who ends up declaring the interface in the assembled
manifests cannot be determined without building.

---

## Verdict table — LTE model (`gts4lv`), 7 further entries in `LineageOS/android_device_samsung_gts4lv` @ `3260fd2c4f1a`

Wired in by `gts4lv/BoardConfig.mk:29` (`DEVICE_MANIFEST_FILE += $(DEVICE_PATH)/manifest.xml`), which appends to the
common file set at `BoardConfigCommon.mk:83`, so the LTE device manifest is these 7 plus the 25 above = 32.

| # | HAL | ours | file:line | level-6 allows | covered by | verdict |
|---|---|---|---|---|---|---|
| 26 | `android.hardware.radio` | hidl **1.4** `IRadio/slot1` + 1.2 `ISap/slot1` | `manifest.xml:2-7` (`fqname` at `:5`, `:6`) | **1.5-6** `IRadio/slot1`, 1.2 `ISap/slot1|slot2` (mandatory) | platform for `ISap@1.2`; qcom-caf frag `:248-261` `1.0-4` for the unused direction | OK unused-direction / **BELOW-MIN mandatory — M3** |
| 27 | `android.hardware.radio.config` | hidl 1.1 | `manifest.xml:8-16` (version `:11`) | 1.1 and **1.3** (both mandatory) | platform 1.1; qcom-caf frag `1.0-1` | OK for 1.1 / **1.3 not declared — M3 note** |
| 28 | `android.hardware.tetheroffload.config` | hidl 1.0 | `manifest.xml:17-25` | 1.0 `IOffloadConfig/default` | platform | OK |
| 29 | `android.hardware.tetheroffload.control` | hidl 1.1 | `manifest.xml:26-34` | 1.1 `IOffloadControl/default` | platform | OK |
| 30 | `vendor.samsung.hardware.radio` | hidl 2.1 | `manifest.xml:35-43` | — | samsung frag `:208-216` (version `2.0-2`) | OK |
| 31 | `vendor.samsung.hardware.radio.bridge` | hidl 2.0 | `manifest.xml:44-52` | — | samsung frag `:217-225` (version `2.0`, `ISehBridge`) | OK |
| 32 | `vendor.samsung.hardware.radio.channel` | hidl 2.0 (`epdgd`, `imsd`) | `manifest.xml:53-62` | — | samsung frag `:226-234` (version `2.0`, `ISehChannel`) | OK |

**LTE counts (its own 7 entries): OK 7 on the unused-HAL axis; BELOW-MIN 0; NOT-COVERED 0.**
**LTE counts (all 32 together, level-6 + 3 fragments): OK 30, BELOW-MIN 1 (soundtrigger, inherited), NOT-COVERED 1
(livedisplay, inherited). With the product fragment (M4): OK 31, BELOW-MIN 1, NOT-COVERED 0.**
On the mandatory axis the LTE model additionally misses `radio 1.5-6 IRadio/slot1` and `radio.config 1.3` — both M3.

Also present for the LTE model only: `gts4lv/framework_manifest.xml:2-10` declares
`vendor.qti.hardware.radio.atcmdfwd` **HIDL 1.0** `IAtCmdFwd/AtCmdFwdService` as a *framework* manifest
(`gts4lv/BoardConfig.mk:28`). The only matrix entry for that name is **AIDL 1** `IAtCmdFwd/AtCmdFwdAidl`
(`vendor_framework_compatibility_matrix.xml:1714-1721`). Verdict: **NOT-COVERED, no action needed** —
`checkUnusedHals` only inspects the device manifest (`VintfObject.cpp:1118`), no build-time check compares
framework-manifest HALs to the FCM (no such call in `AssembleVintf.cpp`), and `ShouldCheckMissingHidlHalsInFcm`
only inspects the `android.hardware.` prefix (`fcm_exclude.cpp:29-33`, `included_prefixes`), so `vendor.*` is never flagged. It is
legacy and a future cleanup candidate.
confidence: high — the file, the fragment entry and both gate conditions were read directly.

---

## Mandatory level-6 entries our manifests do not declare (the other direction)

`compatibility_matrix.6.xml @ 13d687a84c83` has **79 `<hal>` entries, none of them `optional`** (`optional` count verified as 0),
i.e. 87 version x interface x instance combinations are all mandatory. `checkUnusedHals` does not test this direction — `checkIncompatibleHals` is declared
at `include/vintf/HalManifest.h:191` but has **no definition and no caller** in `system/libvintf @ 2ef218d3586b` —
so these are CTS/VTS `DeviceManifestTest` items, not build breaks.

Not declared at all by our two trees: **66 instances (Wi-Fi)** / **63 (LTE)**. Of those, 47 are ordinary
framework-side HALs (camera, sensors, thermal, vibrator, usb, light, boot, health, power, neuralnetworks,
oemlock, secure_element, tv.*, uwb, identity, …) declared by the framework manifest, which Soong assembles outside
our tree. The 19 / 16 that a vendor is expected to provide:

| mandatory instance (level 6) | Wi-Fi | LTE | allowed by a device fragment? |
|---|---|---|---|
| `android.hardware.soundtrigger` 2.3 `ISoundTriggerHw/default` | missing | missing | **no fragment entry at all** → M2 |
| `android.hardware.radio` 1.5-6 `IRadio/slot1` | missing (no radio at all) | **1.4 declared** | qcom-caf frag 1.0-4 → M3 |
| `android.hardware.radio` 1.2 `ISap/slot1|slot2` | missing | `slot1` declared, `slot2` not | qcom-caf frag |
| `android.hardware.radio` 1.5-6 `IRadio/slot2`, `slot3` | n/a | not declared | — |
| `android.hardware.radio.config` 1.1 and 1.3 `IRadioConfig/default` | both missing | 1.1 declared, 1.3 not | qcom-caf frag `1.0-1` |
| `android.hardware.tetheroffload.config` 1.0 `IOffloadConfig/default` | missing | declared | platform |
| `android.hardware.tetheroffload.control` 1.1 `IOffloadControl/default` | missing | declared | platform |
| `android.hardware.gnss` 2.0-1 `IGnss/default` | missing | missing | qcom-caf frag **does** allow it (`vendor_framework_compatibility_matrix.xml:865-874`: hidl, `1.0-1` + `2.0-1`, instances `gnss_vendor` **and** `default`) — so this one is simply undeclared, not unreachable |
| `android.hardware.wifi.supplicant` 1.2-4 `ISupplicant/default` | missing | missing | qcom-caf frag allows only 1.0-2 |
| `android.hardware.nfc` 1.2 `INfc/default` | missing | missing | qcom-caf frag allows only 1.0 (hidl) / 1 (aidl) |
| `android.hardware.media.c2` 1.0-2 `IComponentStore/software` + 1.0 `IConfigurable/*` | missing | missing | qcom-caf frag instance mismatch → note A |
| `android.hardware.graphics.mapper` 3.0 and 4.0 `IMapper/default` | 2.1 declared only | same | strongbox versions; no fragment entry |
| `android.hardware.automotive.evs` 1.0-1 `IEvsEnumerator/default` | missing | missing | qcom-caf frag allows 1.1 |

Read this as a CTS/VTS work list, not a to-do list for this port: every one of these is also undeclared by the
official `sm7125-common @ 865ff7e37424` at `target-level="6"`, i.e. the whole LineageOS 23.2 CAF/Samsung family
ships the same gap. The two exceptions the lead should act on are `radio` 1.5 and `soundtrigger` 2.3, because those
are the ones our own manifests actively contradict.
confidence: high for the counts and the fragment contents (both computed mechanically from the cited files);
high for the "sm7125 has the same shape" statement (its `configs/manifest.xml` read directly).

---

## Vendor device compatibility matrix (secondary check, unchanged by the level)

`BoardConfigCommon.mk:84` sets `DEVICE_MATRIX_FILE := hardware/qcom-caf/common/compatibility_matrix.xml`.
That file @ `1805784d14b` has 7 `<hal>` entries, **5 mandatory**:
`android.frameworks.sensorservice@1.0` (`:29-36`), `android.hidl.allocator@1.0` (`:37-44`),
`android.hidl.manager@1.0` (`:45-52`), `android.hidl.memory@1.0` (`:53-60`),
`android.hidl.token@1.0` (`:61-68`). None appears in our manifests. The other two
(`vendor.qti.hardware.sigma_miracast`, `vendor.qti.hardware.qccsyshal`) are `optional="true"`.

libvintf does not auto-add the `android.hidl.*` entries (grep for `android.hidl` in `HalManifest.cpp` → 0 hits) and
neither does Soong (grep for `android.hidl` in `build/soong/android/*.go` → no `assemble_vintf` reference). But
`sm7125-common @ 865ff7e37424` declares none of them either, so this is a pre-existing family-wide state, not a
regression from this port. Verdict: **INFORMATIONAL / verify on a built tree**; it does not change with the target
level because the vendor DCM is not level-indexed.
confidence: medium — the two file contents are certain; whether VTS cares cannot be determined without building.

---

## Appendix A — retained level-7 material (kept short; the level-6 audit above is the deliverable)

Level 7 is **not** the target: `sm7125-common @ 865ff7e37424` uses 6, our tree is moving to 6, and M5 shows level 7
adds a hard constraint (`<kernel target-level>` becomes an error). But for completeness:

- `compatibility_matrix.7.xml` @ `13d687a84c83`: **99 `<hal>` entries**, 117 expanded instances.
- Auditing the same 32 entries against level 7 + the fragments gives **identical** verdicts:
  Wi-Fi OK 23 / BELOW-MIN 1 / NOT-COVERED 1, LTE OK 30 / BELOW-MIN 1 / NOT-COVERED 1. The only level-7 break for
  our entries is the same `soundtrigger` one; per C1 the level-6 and level-7 files are not additive.
- Levels 8 / 202404 / 202504 remain **out of reach**, and I checked this per-HAL rather than by impression. Taking
  the ten `android.hardware.*` HALs we declare as HIDL (`keymaster`, `gatekeeper`, `graphics.allocator`,
  `graphics.mapper`, `drm`, `graphics.composer`, `audio`, `audio.effect`, `media.omx`, `soundtrigger`):

  | matrix | HIDL still allowed | AIDL-only (our HIDL declaration becomes an unused HAL) | absent entirely |
  |---|---|---|---|
  | level 8 | `graphics.mapper` (2.1, 3.0, 4.0), `audio` (6.0, 7.0-1), `audio.effect` (6.0, 7.0), `media.omx` (1.0), `soundtrigger` (**2.3**) | `gatekeeper`, `graphics.allocator`, `drm`, `audio.effect` | `keymaster`, `graphics.composer` |
  | level 202404 | none | `gatekeeper`, `graphics.allocator`, `drm`, `audio.effect`, `radio.config` (aidl `3`) | the other six |
  | level 202504 | none | `gatekeeper`, `graphics.allocator`, `drm`, `audio.effect`, `radio.config` (aidl `3-4`) | the other six |

  (all read at `13d687a84c83`; level 8's `soundtrigger` is 2.3, so our 2.2 fails there too.)
  `202604` is not even installed in an Android 16 build — `compatibility_matrices/Android.bp:46-62` picks
  `SYSTEM_MATRIX_DEPS_A16` (5, 6, 7, 8, 202404, 202504) unless `RELEASE_AIDL_USE_UNFROZEN`.
- Level→Android mapping is code, not guesswork: `include/vintf/Level.h:41-49` gives
  `R=5, S=6, T=7, U=8, V=202404, B=202504, C=202604`.
confidence: high — file contents and `Android.bp` selection read at the cited commits; the level-7 audit was run
mechanically with the same script.

## Appendix B — inputs (all read-only, nothing was pushed to any of them)

| What | Repo | Branch | Commit |
|---|---|---|---|
| our device tree (Wi-Fi manifest) | `anton-scholten/android_device_samsung_gts4lv-common` | `lineage-23.2` | `2e50286ebc01070c11be5e618ee557a6073709ff` |
| LTE device tree | `LineageOS/android_device_samsung_gts4lv` | `lineage-22.2` | `3260fd2c4f1abcf0303485afa9fa4a7b3faec98b` |
| Wi-Fi device tree (no manifest) | `LineageOS/android_device_samsung_gts4lvwifi` | `lineage-22.2` | `b54236c99ffb18aab2387833274cca7009c6c17c` |
| platform matrices + `fcm_exclude` | `LineageOS/android_hardware_interfaces` | `lineage-23.2` | `13d687a84c834af855bfb314b853b8372a7aa6d9` |
| CAF framework + vendor matrices | `LineageOS/android_hardware_qcom-caf_common` | `lineage-23.2` | `1805784d14b386fce6127f2f06b5a16a3e9b94ed` |
| Samsung framework matrix | `LineageOS/android_hardware_samsung` | `lineage-23.2` | `5d20e3541d147494e074bf710d35b1960a6ed0a2` |
| LineageOS product fragment (livedisplay) | `LineageOS/android_hardware_lineage_interfaces` | `lineage-23.2` | `805d25348106e8cc6f378c0b153789f3cf8da667` |
| `PRODUCT_PACKAGES` chain | `LineageOS/android_vendor_lineage` | `lineage-23.2` | `686d8669737d2207208ea21075320840b5ec8463` |
| SoC audio repo (soundtrigger, audio@6.0) | `LineageOS/android_hardware_qcom_audio` | `lineage-23.2-caf-sdm660` | `90647c475fc51315a1a09fd244cdf5592f0e295b` |
| reference Samsung+Qualcomm tree | `LineageOS/android_device_samsung_sm7125-common` | `lineage-23.2` | `865ff7e3742428d282f17b4995f8d37908b7ca82` |
| reference Pixel tree (target-level cross-check) | `LineageOS/android_device_google_sunfish` | `lineage-23.2` | `52074bf3c0b66efcba89f557e605535feb29aaab` |
| platform manifest + snippets | `LineageOS/android` | `lineage-23.2` | `eabe68377217a88c81fa933db0136ea4146ff369` |
| VINTF rule source | AOSP `system/libvintf` | `android16-release` | `2ef218d3586bbef90c2f0c14bbda901c7d60460a` |
| Soong (checkvintf wiring) | AOSP `build/soong` | `android16-release` | `533c3c2c9166b49caa556518bb547d8f9acf9594` |

Every branch above was confirmed to exist with `git ls-remote --heads` before cloning; none was guessed.
This repo's own `local_manifests/*.xml @ 42b525d` pins `device/samsung/gts4lv-common` (row 1),
`device/samsung/gts4lv` and `device/samsung/gts4lvwifi` (rows 2-3), `kernel/samsung/sdm670` and
`hardware/samsung` — all at exactly the commits used above — so it changes no verdict in this report. It does **not**
add `hardware/qcom-caf/common`, `hardware/lineage/interfaces` or `vendor/lineage`; those come from
`LineageOS/android`'s own `snippets/lineage.xml` (C4).

## What I did not check
- CTS/VTS conformance itself. Only the build-time `assemble_vintf` rules and the `checkvintf` unused-HAL rule are
  modelled; `DeviceManifestTest` and `VtsHal` behaviour is inferred from the matrix contents, not executed.
- `PRODUCT_MANIFEST_FILES` / Soong `vintf_fragment` contributions from the HAL repos. Our tree has no other
  `*.xml` manifest and no `PRODUCT_MANIFEST_FILES`; extra device-manifest entries can be added outside our tree.
- The kernel side of FCM, deliberately out of scope (AGENT-TASKS §0.4 rule 8, §7). For the record: level 6 wants
  `kernel_config_s_4.14/4.19/5.4/5.10` and level 5 wants `kernel_config_r_5.4`
  (`compatibility_matrices/Android.bp:96-98` for level 5, `:107-112` for level 6). Our kernel is 4.9, below every one. That is the project's
  "Track B" question, not R1's.
- Whether `hardware/qcom-caf/sdm660/{display,media}` on `lineage-23.2-caf-sdm660` build a `media.c2` service, which
  note A depends on. Not cloned.

## Problems
None — every command succeeded on the first attempt, no branch name had to be guessed, and nothing was retried.
Two notes so the lead does not read them as failures:
- `wiki.lineageos.org` was not needed. Everything above comes from github.com and android.googlesource.com.
- I did not push a patch anywhere except this repo's `agent/R1-r2` branch, and I did not open a PR.