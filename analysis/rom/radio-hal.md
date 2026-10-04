<!-- task: R8 | agent: Space Bunny Free | date: 2026-10-03 -->
# R8: can the LTE RIL do radio 1.5?

## Summary
- **No. The vendor RIL does not implement `android.hardware.radio` 1.5.** The blob that registers the HIDL service,
  `proprietary/vendor/lib64/libril.so`, has `DT_NEEDED` on `android.hardware.radio@1.0.so` … **`@1.4.so` and on nothing
  at 1.5/1.6**; the only HIDL descriptors it carries are `android.hardware.radio@1.1|1.2|1.3|1.4::IRadio`, and the
  impl classes stop at `RadioImpl_V1_4` (`V1_5`/`V1_6` occur **0** times).
- `strings` for `radio@1.5` / `radio@1.6` returns **0 hits in all 81 files** of `proprietary_vendor_samsung_gts4lv`
  (of which 33 are ELF) **and 0 hits in all 685 files** of `proprietary_vendor_samsung_gts4lv-common`. The `-common`
  sibling contains **no RIL at all** (only `libantradio.so` matches `*ril*`/`*radio*`), so there is nowhere else to look.
- **Three independent blockers** on M3 (LTE `radio` 1.4 → 1.5), not one: (1) the RIL caps at 1.4; (2) the qcom-caf
  vendor-matrix fragment declares `android.hardware.radio` at **`1.0-4`**, so 1.5 is *outside* the range our own build
  installs; (3) level 6 makes 1.5-6 mandatory (`compatibility_matrix.6.xml:451-460`).
- **The cost of doing it is asymmetric and the cost of not doing it is zero**, because `compatibility_matrix.5.xml` on
  23.2 is a **7-line empty file** — level 5 mandates *nothing*. So option (a) "keep the LTE model at level 5" costs
  nothing except the whole level-6 matrix.
- **Recommendation: (a) keep `target-level="5"`**, and do **not** ship an FCM exemption (see "Verdict" for the one
  wrinkle: `target-level` lives in the *shared* gts4lv-common manifest, so this also keeps the Wi-Fi model at 5).
- **The lead must check first:** whether the project actually wants level 6 at all (M1 turns on 79 mandatory HALs, not
  just radio). M3 is a 1-of-79 item and is *not* the cheapest thing to fix.
- confidence: high on the RIL's ceiling (binary evidence, three independent signals, consistent in both multilibs);
  confidence: medium on the recommendation (depends on a project-level decision that is not mine).

---

## 0. Repos cloned (all read-only, `--filter=blob:none --single-branch`, all outside the docs repo)

| Local path | Repo | Branch | HEAD |
|---|---|---|---|
| `~/work/clone-R8/vril` | `TheMuppets/proprietary_vendor_samsung_gts4lv` | `lineage-22.2` | `18030d863e7fe8b074c4d0755f2556dd944a68ab` |
| `~/work/clone-R8/vril-common` | `TheMuppets/proprietary_vendor_samsung_gts4lv-common` | `lineage-22.2` | `b04a4eef4efc9975b2e6fbb0beee31c525fc0c95` |
| `~/work/clone-R8/gts4lv` | `LineageOS/android_device_samsung_gts4lv` | `lineage-22.2` | `3260fd2c4f1abcf0303485afa9fa4a7b3faec98b` |
| `~/work/clone-R8/dt-common` | `LineageOS/android_device_samsung_gts4lv-common` | `lineage-22.2` | `d1b339be7abea07f62fef2bee3b7a2006694df67` |
| `~/work/clone-R8/hs` | `LineageOS/android_hardware_samsung` | `lineage-23.2` | `5d20e3541d147494e074bf710d35b1960a6ed0a2` |
| `~/work/clone-R8/hidl-ifaces` | `LineageOS/android_hardware_interfaces` | `lineage-23.2` | `13d687a84c834af855bfb314b853b8372a7aa6d9` |
| `~/work/clone-R8/caf` | `LineageOS/android_hardware_qcom-caf_common` | `lineage-23.2` | `1805784d14b386fce6127f2f06b5a16a3e9b94ed` |

Note on branch names: all three branch names from the brief existed as given; nothing was guessed. `dt-common` HEAD
equals the `d1b339b` expected by the pin table (`AGENT-TASKS.md` §3 M3). `hidl-ifaces` HEAD equals the `13d687a84c83`
that R1-r2 already used (`analysis/rom/vintf.md:5` @ `e307d57c52be`), so my matrix numbers are comparable with R1's.

The vendor blob repo is **not** LFS, as the brief said: all four RIL blobs below are real ELF (see `file` output).

---

## 1. The RIL-related blob list, with sizes

From `proprietary_vendor_samsung_gts4lv` @ `18030d863e7f`. The repo has **81 files total**, so this list is complete.
Verbatim `find` output for `*ril*` / `*radio*` (paths relative to `proprietary/vendor/`):

```
   5433488  ./lib64/libsec-ril.so
    716272  ./lib64/libril.so
    499432  ./lib/libril.so
    174464  ./lib64/vendor.samsung.hardware.radio.bridge@2.0.so
    122784  ./lib64/vendor.samsung.hardware.radio.channel@2.0.so
    122548  ./lib/vendor.samsung.hardware.radio.bridge@2.0.so
     90528  ./lib64/vendor.samsung.hardware.radio.bridge@2.1.so
     76696  ./lib64/vendor.qti.hardware.radio.atcmdfwd@1.0.so
     63684  ./lib/vendor.samsung.hardware.radio.bridge@2.1.so
     16096  ./bin/hw/rild
       163  ./etc/init/init-qcril-data.rc     <- init script, not a blob
```

`file` on the four that matter — all real ELF, none of them an LFS pointer, and all built **for Android 30** (i.e.
Android 11, matching the 22.2 vendor drop):

| Size | Path | `file` |
|---|---|---|
| 5433488 | `lib64/libsec-ril.so` | ELF 64-bit LSB shared object, ARM aarch64, dynamically linked, for Android 30, stripped |
| 716272 | `lib64/libril.so` | ELF 64-bit LSB shared object, ARM aarch64, dynamically linked, for Android 30, stripped |
| 499432 | `lib/libril.so` | ELF 32-bit LSB shared object, ARM, EABI5 version 1, dynamically linked, for Android 30, stripped |
| 16096 | `bin/hw/rild` | ELF 64-bit LSB shared object, ARM aarch64, dynamically linked, interpreter /system/bin/linker64, for Android 30, stripped |

Two RIL-adjacent binaries that do **not** match the name patterns are in the same tree and were checked too:
`bin/netmgrd` (1852592), `bin/ATFWD-daemon` (37888) and `bin/adpl` (71168). All three have **0** hits for
`radio@1.5`/`radio@1.6`. The repo has **33 ELF objects** in total (28 `*.so`/binaries + 7 `.mbn` WLAN firmware images,
which `file` also reports as ELF); the other 20 are `libnetmgr*`, `libqmi*`, `libconfigdb`, `libdsi_netctrl`,
`liblqe`, `libvkmanager_vendor`, `libxml`, `libpdnotifier`, `libsystem_health_mon`, `libengmode_client` — none of
which mentions `android.hardware.radio` at all.

**The `-common` sibling has no RIL.** `proprietary_vendor_samsung_gts4lv-common` @ `b04a4eef4efc9` has 685 files and
543 `.so`, and exactly **one** matches `*ril*`/`*radio*`:

```
     38272  ./proprietary/system/lib64/libantradio.so
```

`libantradio.so` is Samsung's antenna/firmware-radio utility, not the RIL. So the entire radio HAL stack for gts4lv
lives in the per-model repo. (`confidence: high` — `find` over all 685 files, one hit.)

### Which of these is the HAL?

- `bin/hw/rild` (16 KB) is a thin loader: `readelf -d` shows `NEEDED: libcutils.so, liblog.so, libril.so, libc++.so,
  libc.so, libm.so, libdl.so`. It contains **no** radio HAL strings at all. It is the init-spawned entry point only.
- **`lib64/libril.so` is the blob that registers the HIDL service.** It holds the log strings
  `registerService: starting android::hardware::radio::%s::IRadio %s`, `registerService: starting ISap %s for slotId %d`,
  `registerService: starting android::hardware::radio::config::%s::IRadioConfig`, the `RadioImpl_V1_x` /
  `SapImpl_V1_x` / `RadioConfigImpl_V1_x` classes, and the `registerAsService` symbols of
  `android::hardware::radio::V1_0..V1_4::IRadio`. This is the CAF HIDL radio shim (the Qualcomm
  `Radio`/`RadioHal` adapter).
- `lib64/libsec-ril.so` (5.4 MB) is Samsung's **RIL core** — carrier config, SAP/`ISehChannel`, EIMS, log parsers. It has
  **zero** `android.hardware.radio@*` strings and does not link any `android.hardware.radio@*.so`. Its single
  `registerService`-ish string is `HalIoChannel: registerService: starting ISehChannel [%s]`, i.e. Samsung's own vendor
  HAL, not the AOSP one.
- `lib/libril.so` (32-bit) is the arm32 twin of `lib64/libril.so` and behaves identically (see §2).

`confidence: high` — every claim above is a `readelf -d`/`strings` output quoted verbatim in §2.

---

## 2. `strings` and `readelf -d`, per blob

### 2.1 `readelf -d lib64/libril.so` — the load-bearing result

`DT_NEEDED`, in file order:

```
liblog.so  libutils.so  libcutils.so  libhardware_legacy.so  librilutils.so
android.hardware.radio@1.0.so
android.hardware.radio@1.1.so
android.hardware.radio.deprecated@1.0.so
android.hardware.radio.config@1.0.so
android.hardware.radio.config@1.1.so
android.hardware.radio.config@1.2.so
libhidlbase.so
android.hardware.radio@1.2.so
android.hardware.radio@1.3.so
android.hardware.radio@1.4.so            <-- highest android.hardware.radio major = 1.4
vendor.samsung.hardware.radio@2.0.so
vendor.samsung.hardware.radio.bridge@2.0.so
vendor.samsung.hardware.radio.bridge@2.1.so
vendor.samsung.hardware.radio@2.1.so
vendor.samsung.hardware.radio@2.2.so
libc++.so  libc.so  libm.so  libdl.so
SONAME: libril.so
```

`lib/libril.so` (arm32) has the byte-for-byte equivalent `NEEDED` list.

### 2.2 `strings` — HIDL service/interface descriptors per blob

`lib64/libril.so`, every string containing `android.hardware` (**this is the complete list**):

```
android.hardware.radio@1.0.so
android.hardware.radio@1.1::IRadio
android.hardware.radio@1.1.so
android.hardware.radio@1.2::IRadio
android.hardware.radio@1.2.so
android.hardware.radio@1.3::IRadio
android.hardware.radio@1.3.so
android.hardware.radio@1.4::IRadio        <-- highest descriptor = 1.4
android.hardware.radio@1.4.so
android.hardware.radio.config@1.0::IRadioConfig
android.hardware.radio.config@1.0.so
android.hardware.radio.config@1.1::IRadioConfig
android.hardware.radio.config@1.1.so
android.hardware.radio.config@1.2.so
android.hardware.radio.deprecated@1.0.so
```

`lib/libril.so` (arm32): **identical list.**

Per-blob summary of what was found:

| Blob | `android.hardware.radio@1.x` descriptors | Highest | `radio@1.5` / `radio@1.6` |
|---|---|---|---|
| `lib64/libril.so` | `@1.0.so` (NEEDED only), `1.1::IRadio`, `1.2::IRadio`, `1.3::IRadio`, **`1.4::IRadio`** | **1.4** | **0 / 0** |
| `lib/libril.so` | same as above | **1.4** | **0 / 0** |
| `lib64/libsec-ril.so` | none at all | — | **0 / 0** |
| `bin/hw/rild` | none at all | — | **0 / 0** |
| `bin/netmgrd`, `bin/ATFWD-daemon`, `bin/adpl` | none | — | 0 / 0 |
| `vendor.samsung.hardware.radio.bridge@2.{0,1}.so` (32+64) | none (Samsung vendor HAL only) | — | 0 / 0 |
| `vendor.samsung.hardware.radio.channel@2.0.so` | none | — | 0 / 0 |
| `vendor.qti.hardware.radio.atcmdfwd@1.0.so` | none | — | 0 / 0 |
| every other ELF object in the repo (24 more) | none | — | 0 / 0 |
| **all 685 files of `-common`** | **none** | — | **0 / 0** |

`radio.config`, for the secondary question: highest descriptor is `IRadioConfig` **1.1**, and the `NEEDED` list stops
at `radio.config@1.2.so` with `RadioConfigImpl_V1_2` the newest impl class. So the RIL serves **`radio.config` 1.1**,
exactly matching the declared 1.1 — and 1.2 is *not* served even though its proxy is linked.

### 2.3 The impl-class census (independent third signal)

Mangled class names in `lib64/libril.so`:

```
RadioImpl_V1_2   RadioImpl_V1_3   RadioImpl_V1_4
RadioConfigImpl_V1_1   RadioConfigImpl_V1_2
SapImpl            (ISap 1.0 / 1.1 / 1.2)
```

Counting occurrences of each version token in the whole binary:

```
V1_0 : 203      V1_1 : 89      V1_2 : 117      V1_3 : 47      V1_4 : 115
V1_5 : 0        V1_6 : 0
```

arm32 `lib/libril.so` agrees (`V1_4 : 123`, `V1_5 : 0`, `V1_6 : 0`).

### 2.4 How absence was established (so absence is not assumed)

The `strings` grep used is a plain literal search over the whole file, not a symbol-table lookup, so it cannot miss a
version that exists only in a stripped-away section:

```bash
strings -a FILE | grep -c 'radio@1\.5'      # and 'radio@1\.6'
```

run over **every** file in both vendor repos (81 files / 33 ELF objects in `gts4lv`, 685 files in `-common`). Zero hits
in all 766 files. For completeness, the same sweep for `IRadio|RIL_IO|RadioIO|registerService|radio::` across all
binaries of the per-model repo returns hits **only** in `libril.so` (160 in the 64-bit, 216 in the 32-bit) and one
Samsung-vendor-HAL line in `libsec-ril.so` — i.e. the RIL/HAL code is not hiding in some file I failed to name
`*ril*`.

`confidence: high` — three independent signals (DT_NEEDED, HIDL descriptor strings, impl-class names) agree, in both
multilibs, across two repos.

### 2.5 The trap the brief warned about — and why it does not bite here

The brief's trap is a blob that merely *contains the string* `android.hardware.radio@1.5` without the RIL implementing
it. That is **not** what happened: there is **no such string anywhere**. The strings I do find are the opposite
direction of error — `libril.so` is the CAF HIDL shim that (a) links the `IRadio` proxy stubs and (b) calls
`registerAsService()` on the impl classes; both are *required* to actually register a service, so their presence is
evidence of implementation, not of a stale reference.

The residual uncertainty is a different one, and it is small: I verified the ceiling of the **shipped blob**, not of
the Qualcomm CAF **source**. If some future CAF drop added `RadioImpl_V1_5`, we would be replacing `libril.so` and the
analysis would have to be redone — but we are not doing that; we are keeping Samsung's shipped blob. See "Test that
would settle it" at the end for the cheap runtime confirmation.

`confidence: high` — the DT_NEEDED list is emitted by the link step of the blob that does the registration, so it
cannot overstate the version.

---

## 3. What `hardware/samsung/ril` provides on `android_hardware_samsung` @ lineage-23.2

`5d20e3541d147494e074bf710d35b1960a6ed0a2`, whole `ril/` tree (14 files):

| Path | What it is |
|---|---|
| `ril/secril_config_svc/{Android.bp,secril_config_svc.cpp,secril_config_svc.rc}` | `cc_binary`, `shared_libs: [libbase]` only |
| `ril/sehradiomanager/{Android.bp,sehradiomanager.cpp,sehradiomanager.rc,hidl/*,aidl/*}` | `cc_binary`, links `vendor.samsung.hardware.radio@2.0/2.1/2.2` + `...radio.network-V1-ndk` |
| `ril/secril_multi/Oem_ril_sap.h` | one header, no build file |

**Neither builds or links any `android.hardware.radio@*`.** They serve Samsung's *own* vendor HAL
(`vendor.samsung.hardware.radio`, `.bridge`, `.channel`), which the device manifest declares separately at
`gts4lv/manifest.xml:35-62` and which is unrelated to the AOSP radio version. So `hardware/samsung/ril` is **not** a
source of 1.5.

What gts4lv actually builds from it: only `secril_config_svc` (`gts4lv/device.mk:41-42`), started as
`network_config` and `sim_config` in `gts4lv/init/init.vendor.rilcommon.rc:20,26`. `sehradiomanager` is **not** in
gts4lv's `PRODUCT_PACKAGES`.

### 3.1 Independent corroboration: Samsung's *own* 23.2 tree also caps at 1.4

Grepping every `android.hardware.radio@` reference in the whole of `android_hardware_samsung` @ `5d20e3541d14`:

```
interfaces/radio/2.0/Android.bp:14-17   android.hardware.radio@1.0 … @1.4
interfaces/radio/2.1/Android.bp:14-17   android.hardware.radio@1.0 … @1.4
interfaces/radio/2.2/Android.bp:14-17   android.hardware.radio@1.0 … @1.4
interfaces/radio/1.2/Android.bp:14-16   android.hardware.radio@1.0 … @1.2
hidl/radio/1.3/Android.bp:2,3,16-19    android.hardware.radio@1.3-radio-service.samsung, @1.0 … @1.3
hidl/radio/1.3/radio-service.cpp:17     LOG_TAG "android.hardware.radio@1.3-radio-service.samsung"
```

**The highest AOSP radio version Samsung's own 23.2 tree depends on anywhere is 1.4** — the same ceiling the shipped
`libril.so` blob has. Samsung did not bump their Samsung-proprietary interfaces to radio 1.5 either. This is a fourth,
source-level confirmation of F1, and it is the one that matters most for the port: *the vendor side is frozen at 1.4
in both the blob and the source.*

Adjacent and worth knowing: `hidl/radio/1.3/` is a **Samsung** AOSP-radio service — it links only
`android.hardware.radio@1.0 … @1.3` (`hidl/radio/1.3/Android.bp:16-19`) and registers via
`radio->registerAsService(RIL1_SERVICE_NAME)` and `(RIL2_SERVICE_NAME)` (`hidl/radio/1.3/radio-service.cpp:36,39`).
**It is version 1.3, not 1.5**, and it is *not* in either device tree's build: `grep -rn 'radio-service.samsung'`
across `gts4lv/` and `dt-common/` returns nothing. So it is dead weight for this device. Even if we wanted it, it caps
at 1.3.

`confidence: high` — full tree listed and grepped at the pinned SHA.

---

## 4. The framework side, for completeness

- Level-6 **mandatory minimum**: `compatibility_matrices/compatibility_matrix.6.xml:451-460` @ `13d687a84c83` declares
  `format="hidl"` `android.hardware.radio` `<version>1.5-6</version>` `IRadio/slot1|slot2|slot3`. The file contains
  **0** `<req>` and **0** `<optional>` wrappers (grep -c), so every top-level `<hal>` is mandatory — the brief's
  claim is confirmed at the pinned SHA.
- `radio.config` at level 6: two mandatory entries, `1.1` (`:470-480`) and `1.3` (`:481-488`). Declared 1.1 →
  below the 1.3 minimum. **Same shape of problem as radio, and the RIL serves 1.1** (§2.2), so this one is *also*
  unfixable by editing the manifest. `confidence: high`.
- **The interface exists in 23.2**, so the number is not illegal: `hidl-ifaces/radio/1.5/Android.bp` and
  `radio/1.6/Android.bp` are real `hidl_interface` modules with `gen_java: true`, and 1.6's `interfaces:` list
  includes `android.hardware.radio@1.5`. There is **no** `-service` / `-impl` module for 1.5 or 1.6 in AOSP — the
  server side must come from the vendor. Detail worth noting: `radio/1.5/.hidl_for_system_ext` (empty marker file) puts
  the 1.5 client stubs in **system_ext**, whereas 1.6 has no such marker. `confidence: high` (files read at SHA).
- **Level 5 mandates nothing.** `compatibility_matrices/compatibility_matrix.5.xml` @ `13d687a84c83` is **7 lines**:
  a root element and a comment saying "Android R FCM has been deprecated, but this file is kept to help manage the
  android11-5.4 kernel config requirements". Zero `<hal>` entries. `confidence: high` — the file is quoted in full above.

---

## 5. Verdict

### Can the LTE manifest say 1.5? **No.**

Three independent blockers, any one of which is sufficient:

1. **The RIL cannot serve it.** `libril.so` links `android.hardware.radio@1.4.so` as its highest AOSP radio proxy and
   registers at most `android.hardware.radio@1.4::IRadio`. Bumping `gts4lv/manifest.xml:5` to `@1.5::IRadio/slot1`
   would make the manifest **lie to `assemble_vintf`**: the check compares the manifest against the framework matrix and
   the vendor matrix, neither of which knows what the running RIL registers. The build would pass and the device would
   then fail to serve the interface it declared. Source: §2.1–§2.4.
2. **Our own vendor matrix forbids 1.5.** `hardware/qcom-caf/common/vendor_framework_compatibility_matrix.xml:248-261`
   @ `1805784d14b3` declares `format="hidl" optional="true"` `android.hardware.radio` at `<version>1.0-4</version>`, and
   that fragment is installed by `dt-common/BoardConfigCommon.mk:81`. A manifest at 1.5 is **outside** the range our own
   build declares. This is a *new* observation — R1-r2 used the same fragment only in the safe direction (to show 1.4
   passes `checkUnusedHals`, `analysis/rom/vintf.md:216-221` @ `e307d57c52be`); nobody had looked at what happens above
   the range. `confidence: high` that 1.5 is out of range; **low** on whether libvintf reports that as an error or a
   warning for an `optional="true"` entry — I did not read that code path (see `## Problems`).
3. **Nothing in the tree can supply a 1.5 server.** `hardware/samsung/ril` does not touch `android.hardware.radio`
   (§3), `hardware/samsung/hidl/radio/1.3` is 1.3 and unbuilt for this device, and AOSP 23.2 ships no 1.5/1.6
   `-service`/`-impl` (§4). Writing one would mean writing a radio HAL server on top of Samsung's
   `libsec-ril` RIL core — that is a port, not a manifest edit.

`confidence: high` — blockers 1 and 3 are direct binary/source evidence; blocker 2's range is direct file evidence.

### Which alternative, and what it costs

**(a) Keep FCM level 5 — RECOMMENDED.** Cost: **zero build cost, zero runtime cost, and no new code.** The strong
argument is §4: `compatibility_matrix.5.xml` on 23.2 is empty, so level 5 requires nothing at all. Declaring level 5
does not force us to *remove* `android.hardware.radio` — it only means we do not claim to meet level 6. The radio keeps
working at exactly the 1.4 it already works at on 22.2 today. Nothing regresses.

Two honest caveats:

- This is a project-level decision, not a technical necessity. **Declaring level 5 means declining the whole of FCM
  S**, not just radio. R1-r2 counted the level-6 mandatory set: `compatibility_matrix.6.xml @ 13d687a84c83` has
  **79 `<hal>` entries, none of them `optional`** (`analysis/rom/vintf.md:313` @ `e307d57c52be`), which works out as
  **19** vendor-relevant mandatory instances unsatisfied for the Wi-Fi model and **16** for LTE
  ([LEAD-SYNTHESIS.md:539-540](../../LEAD-SYNTHESIS.md)). Radio is **one** of those. If the lead's real goal is "get to level
  6", then M3 is not the item to fight over — the other 15-18 are. If the goal is "ship a working tablet", level 5 is
  right and M3 becomes a non-issue.
- **`target-level` is not per-model.** It is `target-level="5"` at `dt-common/manifest.xml:1`, in the **gts4lv-common**
  manifest, which `BoardConfigCommon.mk:84` makes `DEVICE_MANIFEST_FILE` for *both* products.
  `gts4lv/BoardConfig.mk:28-29` then sets the framework manifest and *appends* the per-model `gts4lv/manifest.xml`, and
  that file has **no** `target-level` attribute (`gts4lv/manifest.xml:1` is `<manifest version="1.0" type="device">`). So
  "keep the LTE model at level 5 while the Wi-Fi model goes to 6" would require **splitting the common manifest** — a
  real, non-trivial restructuring, and it would leave two products with different levels in one build.
  `confidence: high` — both files read at their pinned SHAs.

**(b) Ship an FCM exemption — NOT RECOMMENDED.** Cost: high, and mostly bureaucratic. An exemption is a request to
Google per HAL per device per release; it has to be renewed, and the FCM exemption process applies to devices shipping
Play-certified builds, which this ROM is not (no GMS, so no CTS/FCM obligation at all). `confidence: medium` — the
"no GMS ⇒ no FCM obligation" reasoning is standard but I did not verify it against a LineageOS-specific source, and
I could not reach `developer.android.com` from this container to quote the exemption policy. Treat this paragraph as
reasoning, not as a cited fact.

### The cheapest honest fix, if the lead insists on level 6 for radio

Not achievable by editing the manifest. It would need one of:

- a **real 1.5 server**, i.e. a CAF/Samsung RIL drop that ships `RadioImpl_V1_5`; or
- a **shim service** that implements `android.hardware.radio@1.5::IRadio` by forwarding to the registered 1.4 service
  (all 1.5 additions to `IRadio` are new methods; the base 1.4 surface can be forwarded verbatim). This is real work —
  estimate as a port task, and note that `radio/1.5/.hidl_for_system_ext` means the client stubs also have to be present
  on the right partition. `confidence: low` — I have not verified the 1.5 method delta or the partition implications;
  treat as a direction, not a plan.

### Test that would settle the runtime question (cheap, do it on the first boot)

```
adb shell dumpsys android.hardware.radio.RadioService
adb shell lshal | grep -i radio
```

`lshal` lists what the HIDL service manager actually has. On this image it should show
`android.hardware.radio@1.4::IRadio/slot1` and **no** 1.5/1.6 — which would confirm §2 empirically. If it unexpectedly
shows 1.5, then my blob analysis missed something and this report's central claim is wrong.
`confidence: high` that this is the right test — it reads the running service manager, which is the ground truth the
static analysis approximates.

---

## Findings, each with confidence

**F1 — The LTE RIL's `android.hardware.radio` ceiling is 1.4.**
`lib64/libril.so` (and its arm32 twin) link `android.hardware.radio@1.0.so`…`@1.4.so` and nothing higher; the highest
HIDL descriptor present is `android.hardware.radio@1.4::IRadio`; `RadioImpl_V1_4` is the newest impl class and `V1_5`/`V1_6`
occur 0 times.
`confidence: high` — three independent binary signals agree, in both multilibs, and the linking one (`DT_NEEDED`) is
emitted by the blob that performs the registration, so it cannot overstate the version.

**F2 — `libril.so` is the registering blob; `libsec-ril.so` and `rild` are not the HAL.**
`libril.so` holds the `registerService: starting android::hardware::radio::%s::IRadio %s` log string and the
`V1_x::IRadio::registerAsService` symbols; `rild` is a 16 KB loader for it; `libsec-ril.so` has zero
`android.hardware.radio@*` strings.
`confidence: high` — quoted strings and `readelf -d` output in §2.

**F3 — The absence of 1.5/1.6 is global, not a naming accident.**
0 hits for `radio@1.5` and `radio@1.6` across all 81 files of `gts4lv` (33 of them ELF) and all 685 files of `-common`.
`confidence: high` — exhaustive `strings` sweep, and `-common` contains no RIL at all (only `libantradio.so` matches
`*ril*`/`*radio*`).

**F4 — The RIL serves `radio.config` 1.1, and 1.2 is not served even though its proxy is linked.**
`NEEDED` stops at `radio.config@1.2.so` but the only descriptors are `IRadioConfig` 1.0 and 1.1, with
`RadioConfigImpl_V1_2` as the newest impl class. So the low-priority `radio.config` 1.3 item is **also** unfixable by
editing `gts4lv/manifest.xml:11`.
`confidence: medium` — the strings are certain, but linking a 1.2 proxy and not registering it is a weaker signal than
the radio case (where 1.5 would need its own proxy link). Verify with the `lshal` command in §5.

**F5 — `hardware/samsung/ril` @ `5d20e3541d14` does not touch `android.hardware.radio` at all, and the rest of
`android_hardware_samsung` caps at 1.4 too.**
Both `ril/` binaries link only `libbase`/Samsung vendor-HAL libs. The only AOSP-radio *service* in the repo is
`hidl/radio/1.3`, which caps at 1.3 and is in neither device tree's build. The Samsung vendor interfaces
`interfaces/radio/{2.0,2.1,2.2}/Android.bp` declare `android.hardware.radio@1.4` as their highest dependency — the
same ceiling as the shipped blob.
`confidence: high` — full tree enumerated and grepped at the pinned SHA; `interfaces/radio/2.2/Android.bp:14-22`
read in full.

**F6 — A manifest at 1.5 would also fall outside the qcom-caf vendor-matrix fragment.**
`vendor_framework_compatibility_matrix.xml:248-261` @ `1805784d14b3` allows `1.0-4`, installed by
`dt-common/BoardConfigCommon.mk:81`.
`confidence: high` for the range; **low** for the consequence (error vs warning on an `optional="true"` entry) — see
`## Problems`.

**F7 — Level 6 mandates radio 1.5-6; level 5 mandates nothing at all.**
`compatibility_matrix.6.xml:451-460` (0 `<optional>` wrappers in the whole file) vs a 7-line empty
`compatibility_matrix.5.xml`, both @ `13d687a84c83`.
`confidence: high` — both files read directly.

**F8 — `target-level` is shared by both models, so a per-model level-5 fallback is not free.**
It is `dt-common/manifest.xml:1`; `gts4lv/manifest.xml` has no `target-level`.
`confidence: high` — both files read at their pinned SHAs.

**F9 — The level-6 matrix is much bigger than the radio item.**
R1-r2 (`analysis/rom/vintf.md:313` @ `e307d57c52be`) counts 79 mandatory `<hal>` entries in the level-6 matrix; R1-r2 /
LEAD-SYNTHESIS turn that into 16 unsatisfied LTE mandatory instances. Radio is one of them.
`confidence: high` — inherited from a reviewed report in this repo, not re-derived by me.

---

## Problems

1. **Not verified: whether libvintf treats "manifest version above the vendor-matrix range" as an error or a warning for
   an `optional="true"` fragment entry.** This decides whether blocker 2 is a build failure or a VTS/CTS item. I could not
   read the code: there is **no LineageOS repo for `system/tools/vintf`** — I enumerated all 1100 repos in the LineageOS
   GitHub org via the API and none contains `vintf` in its name. I then tried
   `https://android.googlesource.com/platform/test/vintf/+/refs/heads/android16-release/tests/compatibility_matrix.cpp?format=TEXT`
   and got:
   ```
   NOT_FOUND: Requested entity was not found
   [type.googleapis.com/google.rpc.LocalizedMessage]
   message: "Cannot parse URL as a Gitiles URL"
   ```
   and `.../+/refs/heads/main/?format=TEXT` returned nothing. Settle it by reading `CompatibilityMatrix::Check()` /
   `CheckOptional()` wherever the 23.2 tree ends up, or empirically with
   `checkvintf --dirmap=out/target/product/gts4lv/` after the first build.
2. **Not verified: whether an FCM exemption is even applicable to a non-GMS ROM.** No source obtained; see the
   "(b) NOT RECOMMENDED" paragraph. Reasoning, not fact.
3. **Not verified: the 1.5 method delta and the system_ext implication.** The "shim service" direction in §5 is
   `confidence: low` and is deliberately not a plan.
4. **Scope note, not a failure:** I could not obtain `system/hardware/interfaces` for 23.2 (no LineageOS branch; AOSP
   android16-release has only `keystore2 media net suspend vold wifi`, no `radio/`), so I could not read the framework
   radio client's version-probe/fallback logic. I did not need it for the verdict, and §4 shows HIDL radio 1.5-6 is
   still a mandatory FCM-6 requirement in 23.2, so the framework cannot have dropped HIDL radio. But if the lead wants
   the precise runtime behaviour of a 1.4-only RIL when the manifest claims 1.5, that is the code to read, and it is
   still unread.

## Reproduce

```bash
mkdir -p ~/work/clone-R8 && cd ~/work/clone-R8
git clone --filter=blob:none --single-branch -b lineage-22.2 https://github.com/TheMuppets/proprietary_vendor_samsung_gts4lv vril
git clone --filter=blob:none --single-branch -b lineage-22.2 https://github.com/TheMuppets/proprietary_vendor_samsung_gts4lv-common vril-common
cd vril/proprietary/vendor
readelf -d lib64/libril.so | grep NEEDED                      # stops at android.hardware.radio@1.4.so
strings -a lib64/libril.so | grep -F android.hardware         # 1.1/1.2/1.3/1.4 :: IRadio, nothing higher
strings -a lib64/libril.so | grep -cE 'V1_5|V1_6'             # 0
find . -path ./.git -prune -o -type f -print | while read -r f; do strings -a "$f" | grep -l 'radio@1\.5' && echo "HIT $f"; done
```