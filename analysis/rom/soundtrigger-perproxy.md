<!-- task: R9 | agent: Space Bunny Free | date: 2026-10-03 -->
# R9: soundtrigger and per_proxy_helper

## Summary

Two findings, and **both reverse the plan in LEAD-SYNTHESIS §7.4–§7.5.**

1. **`soundtrigger`: the `manifest.xml` block must NOT be deleted.** `gts4lv.mk:58` really does build
   `android.hardware.soundtrigger@2.2-impl:32`, and that module exists in `hardware/interfaces`, and the
   2.2 implementation is genuinely registered at boot from inside `android.hardware.audio.service`. So the
   declared HAL is real, not a phantom. And the level-6 requirement R1 used comes from
   `compatibility_matrix.6.xml`, which **is not the matrix that governs this device**: Android 16 installs
   `compatibility_matrix.202504.xml` (the frozen matrix, which has **no** HIDL `soundtrigger` entry) as well,
   and LineageOS's own `sm7125-common` shipped 23.2 at `target-level="6"` with `soundtrigger@2.2` declared,
   changed by exactly one commit (`88c7b738785b`, 2 lines). Deleting the block therefore risks *creating* a
   `checkvintf` failure instead of preventing one. **P5 item 2 becomes a no-op.**
   Confidence: high — backed by an official LineageOS 23.2 device tree and by `checkvintf` being a hard
   build gate (`build/soong` `filesystem/filesystem.go:2168-2175`, `|| ( cat log && exit 1 )`).

2. **`per_proxy_helper`: there is no blob.** Neither vendor repo contains a file of that name, in any
   directory, and no blob in either repo contains the string. The sepolicy declaration is dead code with
   **zero** runtime effect — it is not a "latent runtime problem" as LEAD-SYNTHESIS §7.5 says, because
   nothing is ever exec'd, so `domain_auto_trans(init, $1_exec, $1)` never fires and nothing can fail.
   **P5 item 3 must not add a `file_contexts` line.** It would label a path that never exists.
   Confidence: high — verified by exhaustive listing of all 37 vendor binaries plus a content grep of both
   vendor trees.

Bonus finding: `kgsl_device` (`sepolicy/vendor/device.te:8`) is **genuinely dead**, and adding a label for it
would be actively wrong — `android_device_qcom_sepolicy_vndr` already labels `/dev/kgsl-3d0` as `gpu_device`.
Confidence: high.

**What the lead must check first:** whether it agrees that P5 items 2 and 3 should both become no-ops. If it
does not, item 3 in particular will not do what §6c promises it will do.

## Repos cloned (all read-only, all outside the docs repo)

| Dir | Repo | Branch | HEAD |
|---|---|---|---|
| `~/work/clone-R9/dt` | `anton-scholten/android_device_samsung_gts4lv-common` | `lineage-23.2` | `2e50286ebc01070c11be5e618ee557a6073709ff` |
| `…/dt` | same | `lineage-22.2` | `d1b339be7abea07f62fef2bee3b7a2006694df67` |
| `…/gts4lv` | `LineageOS/android_device_samsung_gts4lv` | `lineage-22.2` | `3260fd2c4f1abcf0303485afa9fa4a7b3faec98b` |
| `…/gts4lvwifi` | `LineageOS/android_device_samsung_gts4lvwifi` | `lineage-22.2` | `b54236c99ffb18aab2387833274cca7009c6c17c` |
| `…/vcommon` | `TheMuppets/proprietary_vendor_samsung_gts4lv-common` | `lineage-22.2` | `b04a4eef4efc9975b2e6fbb0beee31c525fc0c95` |
| `…/vlte` | `TheMuppets/proprietary_vendor_samsung_gts4lv` | `lineage-22.2` | `18030d863e7fe8b074c4d0755f2556dd944a68ab` |
| `…/hif` | `LineageOS/android_hardware_interfaces` | `lineage-23.2` | `13d687a84c834af855bfb314b853b8372a7aa6d9` |
| `…/audio660` | `LineageOS/android_hardware_qcom_audio` | `lineage-23.2-caf-sdm660` | `90647c475fc51315a1a09fd244cdf5592f0e295b` |
| `…/audio845` | `LineageOS/android_hardware_qcom_audio` | `lineage-23.2-caf-sdm845` | `d5ad5c133b7024606b0ab9a720265fd7f9f0e6b6` |
| `…/audio660-22` | `LineageOS/android_hardware_qcom_audio` | `lineage-22.2-caf-sdm660` | `90647c475fc51315a1a09fd244cdf5592f0e295b` (**same SHA as 23.2**) |
| `…/sm7125` | `LineageOS/android_device_samsung_sm7125-common` | `lineage-23.2` | `865ff7e3742428d282f17b4995f8d37908b7ca82` |
| `…/sm7125` | same | `lineage-22.2` | `b315034eba10611db905770958ab9c7379b9e5a3` |
| `…/qsepol` | `LineageOS/android_device_qcom_sepolicy` | `lineage-23.2` | `d903f8e1e0c47ef5a9df528ee98203cac6de6b43` |
| `…/qsevndr` | `LineageOS/android_device_qcom_sepolicy_vndr` | `lineage-23.2-legacy-um` | `0dbc76e4b759da5681b8c96b7e2bb7c1ae0cc6b1` |
| `…/sepol` | `LineageOS/android_system_sepolicy` | `lineage-23.2` | `885cc500f6078a766d1f6def5ce4c06c55841773` |
| `…/caf` | `LineageOS/android_hardware_qcom-caf_common` | `lineage-23.2` | `1805784d14b386fce6127f2f06b5a16a3e9b94ed` |
| `…/bsoong` | `LineageOS/android_build_soong` | `lineage-23.2` | `9aa045a2aef10b8089e32e847fed26d9aa3d61be` |
| `…/bmake` | `LineageOS/android_build` | `lineage-23.2` | `e5aaa62172df0f321e68133fa30f42316376bfe8` |

Two repos do not exist and could not be cloned (reported, not guessed):
`LineageOS/android_system_tools_vintf` and `aosp-mirror/platform_system_tools_vintf` both return
"could not read Username" (404). The `checkvintf` question is therefore settled from `build/soong` plus the
sm7125 tree instead.

---

## Part 1 — soundtrigger

### 1.1 Every hit, classified

Search commands actually run (all return codes clean):

```
git -C dt        grep -n -i "soundtrigger" 2e50286ebc01
git -C gts4lv    grep -n -i "soundtrigger" HEAD
git -C gts4lvwifi grep -n -i "soundtrigger" HEAD
git -C vcommon   grep -n -iE "soundtrigger|sound_trigger" HEAD -- '*.mk' '*.bp' '*.txt' '*.xml' '*.rc' '*.te' '*.conf' '*.prop'
git -C vcommon   ls-tree -r --name-only HEAD | grep -iE "sced|audio_trigger|sthal|sound_trigger"
git -C vlte      ls-tree -r --name-only HEAD | grep -iE "sced|audio_trigger|sthal|sound_trigger|proxy"
grep -rl "kgsl-3d0" vcommon/proprietary/vendor/ ; grep -rl "per_proxy" vcommon/proprietary vlte/proprietary
```

| # | `file:line` @ commit | Kind | Notes |
|---|---|---|---|
| 1 | `manifest.xml:102-110` @ `2e50286ebc01` (name `:103`, `hwbinder` `:104`, version 2.2 `:105`, `ISoundTriggerHw/default` `:107-108`) | **vintf device manifest** | the block R1 wants deleted. Identical at 22.2 `d1b339be7abe` (`:102-110`) |
| 2 | `gts4lv.mk:58` @ `2e50286ebc01` — `android.hardware.soundtrigger@2.2-impl:32 \` | **build** | `PRODUCT_PACKAGES`; installs `vendor/lib/hw/android.hardware.soundtrigger@2.2-impl.so`. Identical at 22.2 |
| 3 | `BoardConfigCommon.mk:51` @ `2e50286ebc01` — `BOARD_SUPPORTS_SOUND_TRIGGER := true` | **build flag** | `grep BOARD_SUPPORTS_SOUND_TRIGGER` in `build/make` @ `e5aaa621` returns nothing, so nothing in the build system reads it. Reader is in `frameworks/av` (not cloned) — see §1.5 |
| 4 | `proprietary-files.txt:572-575` @ `2e50286ebc01` (`# Soundtrigger`, `vendor/lib/hw/sound_trigger.primary.sdm710.so` at `:574`, `vendor/lib/libaudio_soundtrigger.so` at `:575`) | **blob list** | feeds `TheMuppets` extraction |
| 5 | `Android.bp:9023-9032` @ `b04a4eef4efc` — `cc_prebuilt_library_shared { name: "sound_trigger.primary.sdm710" … srcs: ["proprietary/vendor/lib/hw/sound_trigger.primary.sdm710.so"] }` | **build** | `android_arm` only, `soc_specific: true` |
| 6 | `Android.bp:9273-9299` @ `b04a4eef4efc` — `name: "libaudio_soundtrigger"`, src `:9282`, `shared_libs` includes `"sound_trigger.primary.sdm710"` `:9289`, `compile_multilib: "32"` `:9297` | **build** | 32-bit, matching `gts4lv.mk:58`'s `:32` |
| 7 | `Android.bp:8913` (`cc_prebuilt_library_shared {`), `:8914` (`name: "audio.primary.qcom"`) and `:8937` (`"libaudio_soundtrigger"` in its `shared_libs`) @ `b04a4eef4efc` | **build** | the soundtrigger blobs are DTEs of the primary audio HAL blob |
| 8 | `gts4lv-common-vendor.mk:322` `sound_trigger.primary.sdm710 \` and `:331` `libaudio_soundtrigger \` @ `b04a4eef4efc` | **build** | `PRODUCT_PACKAGES`, so both blobs really ship |
| 9 | `proprietary/vendor/lib/hw/sound_trigger.primary.sdm710.so`, `proprietary/vendor/lib/libaudio_soundtrigger.so` @ `b04a4eef4efc` | **blob** | both present as real files |
| 10 | `configs/sdm710/sdm710.mk:407-417`, name on `:411` — `android.hardware.soundtrigger@2.1-impl` | **build** | `PRODUCT_PACKAGES`; `90647c475fc5` is the *same SHA* on `lineage-22.2-caf-sdm660` and `lineage-23.2-caf-sdm660`, so this line is unchanged 22.2 → 23.2 |
| 11 | `configs/common/default.mk:24` (`@2.2-impl`), `:28` (`@2.3-impl`) @ `90647c475fc5` | **build, not inherited** | `configs/sdm710/sdm710.mk` contains no `inherit-product` of `configs/common/default.mk`, so neither is pulled in for sdm710 |
| 12 | `hal/Android.bp:51` `"true": ["audio_extn/soundtrigger.c"]`; `hal/audio_extn/soundtrigger.c:29` `#define LOG_TAG "soundtrigger"` @ `90647c475fc5` | **source** | the source inside `audio.primary` that the two blobs above replace |
| 13 | `audio/common/all-versions/default/service/service.cpp:115-122` @ `13d687a84c83` — `optionalInterfaces` entry `"Soundtrigger API"` listing `@2.3`, `@2.2`, `@2.1`, `@2.0` `ISoundTriggerHw` | **start mechanism** | see §1.2 |
| 14 | `…/service.cpp:155-160` @ `13d687a84c83` — `ALOGW_IF(!registerPassthroughServiceImplementations(iter, listIter.end()), "Could not register %s", …)` | **start mechanism** | soundtrigger is in `optionalInterfaces`, so failure is a **warning**, not `LOG_ALWAYS_FATAL` |
| 15 | `soundtrigger/2.2/default/Android.bp:25-45` @ `13d687a84c83` — `cc_library_shared { name: "android.hardware.soundtrigger@2.2-impl" (`:26`), `relative_install_path: "hw"` (`:27`), `vendor: true` (`:28`) }` | **build** | the module `gts4lv.mk:58` asks for. **It exists.** |
| 16 | `soundtrigger/2.2/default/SoundTriggerHw.h:23` @ `13d687a84c83` — `#include <hardware/sound_trigger.h>` | **mechanism** | 2.2 impl is a passthrough over the *legacy* `sound_trigger` hw module |
| 17 | `init/init.qcom.rc:785` @ `2e50286ebc01` — `service vendor.audio-hal /vendor/bin/hw/android.hardware.audio.service` | **start** | the binary that actually registers the soundtrigger HAL. **There is no soundtrigger init service** |
| 18 | `init/init.qcom.rc:468` @ `2e50286ebc01` — comment `#WDSP FW boot sysfs node used by STHAL` (`:469-470` `chown media audio /sys/kernel/wdsp0/boot`, `/sys/kernel/wcd_cpe0/fw_name`) | **comment + 2 chowns** | "STHAL" = the same soundtrigger HAL. Nothing that can fail |
| 19 | `framework_compatibility_matrix.xml:1-9` @ `2e50286ebc01` | **vintf fragment** | contains only `com.qualcomm.qti.ant@1.0`. No soundtrigger |
| 20 | `hardware/qcom-caf/common` @ `1805784d14b3` | **vintf fragment** | `git grep -i soundtrigger` → **0 hits** |
| 21 | `sm7125-common` `configs/manifest.xml:83-92` @ `865ff7e37424` (version 2.2 at `:86`, plus `<fqname>@2.2::ISoundTriggerHw/default</fqname>` at `:91`) and `common.mk:71` `android.hardware.soundtrigger@2.2-impl \` | **reference tree** | the same shape as ours, at `target-level="6"` |

**Negative results (all verified, not assumed):**

- `git -C gts4lv grep -n -i soundtrigger HEAD` → **0 hits**. Same for `gts4lvwifi` → **0 hits**.
- Every `service`/`oneshot` line in all 53 device-tree `init/*.rc`, all 32 vendor `*.rc` (`vcommon`) and the
  LTE `*.rc` (`vlte`) — **no line** matches `sound|trigger|sthal|sced`. So **no init service starts any
  soundtrigger binary.**
- No `sced`, `audio_trigger`, `sthal` file or string anywhere in `dt`, `gts4lv`, `gts4lvwifi`, `vcommon`,
  `vlte`. The real names in this device are `sound_trigger.primary.sdm710.so` and
  `libaudio_soundtrigger.so` (plus the framework library
  `android.hardware.soundtrigger@2.{1,2}-impl.so`).
- sepolicy references — **three exist, and all three must stay** (I initially missed these; see the correction
  note in `## Problems`):
  - `system/sepolicy` @ `885cc500f607` `private/hwservice_contexts:64` —
    `android.hardware.soundtrigger::ISoundTriggerHw                  u:object_r:hal_audio_hwservice:s0`.
    This is the **hwbinder context of the HAL we actually register**, and `hal_audio_hwservice` is
    `public/hwservice.te:11` `type hal_audio_hwservice, hwservice_manager_type, protected_hwservice;`.
    `vendor.audio-hal` runs as `hal_audio_default`, so this label is what makes binder access work. Deleting
    the manifest block does not make this line stale — it is per-*interface*, not per-manifest-entry.
  - `system/sepolicy` @ `885cc500f607` `private/audioserver.te:44` —
    `allow audioserver soundtrigger_middleware_service:service_manager find;`, with
    `public/service.te:250` `type soundtrigger_middleware_service, system_server_service, …`. That is the
    framework's always-on-hotword **middleware** binder, nothing to do with the HIDL HAL.
  - `private/service_contexts:120` `android.hardware.soundtrigger3.ISoundTriggerHw/default → hal_audio_service`
    — the AIDL `soundtrigger3`, which we do **not** ship. Harmless extra context.
  - Our own `sepolicy/vendor/hwservice_contexts` @ `2e50286ebc01` has **no** soundtrigger line (it only lists
    `vendor.samsung.*` HALs), and `git grep -ci soundtrigger` over our whole `sepolicy/` returns **0**.
    No soundtrigger domain, type or label is needed in the device tree: the registering process is the audio
    HAL server, already covered by `hal_audio_default`.
- `compatibility_matrices/compatibility_matrix.5.xml` @ `13d687a84c83` is **empty** apart from a comment, so
  at 22.2/target-level 5 nothing required soundtrigger at all. This is why the tree builds today.

### 1.2 What actually happens at boot

1. `init.qcom.rc:785` starts `/vendor/bin/hw/android.hardware.audio.service` as `vendor.audio-hal`.
2. That binary calls `registerPassthroughServiceImplementations()` for its `optionalInterfaces` list
   (`service.cpp:155-160`).
3. The list contains `"Soundtrigger API"` with `2.3`, `2.2`, `2.1`, `2.0` in that order
   (`service.cpp:115-122`). The passthrough registry tries `android.hardware.soundtrigger@2.3-impl.so`
   (not shipped), then `@2.2-impl.so` — which `gts4lv.mk:58` **does** ship, into `vendor/lib/hw/`.
4. `@2.2-impl` (`SoundTriggerHw.cpp/h`) is a passthrough over the legacy `sound_trigger` hw module
   (`SoundTriggerHw.h:23`), i.e. it loads `vendor/lib/hw/sound_trigger.primary.sdm710.so`, which is blob
   #9 above and a DTE of `audio.primary.qcom.so`.

So a real `android.hardware.soundtrigger@2.2::ISoundTriggerHw/default` is registered, and the device
manifest correctly declares it. **The declared HAL is not a phantom.**

### 1.3 Why R1's "level 6 requires 2.3" does not apply to this build

R1 (`analysis/rom/vintf.md:49-52`) compared against `compatibility_matrix.6.xml:540-547`
(`android.hardware.soundtrigger` **2.3**, `ISoundTriggerHw/default`, **no `optional` attribute** — I re-read
those lines, they are exactly as R1 says).

But that is not the whole framework matrix that ships. `hardware/interfaces`
`compatibility_matrices/Android.bp:45-54` @ `13d687a84c83`:

```
# These are the FCMs for A16 that are still supported during QPRs
SYSTEM_MATRIX_DEPS_A16 = [
    "framework_compatibility_matrix.5.xml",
    "framework_compatibility_matrix.6.xml",
    "framework_compatibility_matrix.7.xml",
    "framework_compatibility_matrix.8.xml",
    "framework_compatibility_matrix.202404.xml",
    "framework_compatibility_matrix.202504.xml",
    "framework_compatibility_matrix.device.xml",
]
```

and `framework_compatibility_matrix.202504.xml:1` declares `level="202504"`. The three date-named files are
AOSP's **frozen** matrices (the comment at `Android.bp:33-34` and the naming make this explicit). Grepping
all eight framework matrices for HIDL `soundtrigger`:

| matrix | HIDL `android.hardware.soundtrigger` |
|---|---|
| `compatibility_matrix.5.xml` | absent (file is empty apart from a comment) |
| `compatibility_matrix.6.xml:540-547` | **2.3** |
| `compatibility_matrix.7.xml:679-686` | **2.3** |
| `compatibility_matrix.8.xml:560-567` | **2.3** |
| `compatibility_matrix.202404.xml` | absent |
| `compatibility_matrix.202504.xml` | absent (only AIDL `soundtrigger3@1-3`) |
| `compatibility_matrix.202604.xml` | absent (only AIDL `soundtrigger3@1-3`) |

The frozen matrices are the ones that supersede the older level matrices, which is exactly why declaring
2.2 is legal. I could not read the rule itself (`system/tools/vintf` is not clonable — see `## Problems`),
so this specific mechanism is **confidence: medium**. The *conclusion* does not rest on it:

### 1.4 The decisive evidence: sm7125-common

`LineageOS/android_device_samsung_sm7125-common` is an official LineageOS tree for the same SoC family and
the same SoC generation as ours (Qualcomm, CAF, Samsung). Between 22.2 and 23.2:

- `b315034eba10` (22.2): `configs/manifest.xml:1` = `target-level="5"`; `:83-92` declares
  `android.hardware.soundtrigger` version **2.2**.
- `88c7b738785bd0903668a53136156fa7903d7d2c` (Yumi Yukimura, 2024-06-19) "sm7125-common: manifest: Bump
  target-level to 6": `configs/manifest.xml | 4 ++--` — **2 lines changed, the target-level attribute only.**
- `865ff7e37424` (23.2): `target-level="6"`, `soundtrigger` still **2.2** at `:84-91`, and
  `common.mk:71` still builds `android.hardware.soundtrigger@2.2-impl`.
- `git log -S'soundtrigger' b315034eba10..865ff7e37424` → **no commits**. Nobody touched soundtrigger when
  going to level 6.

`checkvintf` **is** a hard build gate here: `build/soong` @ `9aa045a2aef1`
`filesystem/filesystem.go:2168-2175` runs `checkvintf --check-one --dirmap /vendor:…` with
`|| ( cat <log> && exit 1 )`, and `filesystem/android_device.go:2056` does the same per SKU. So if
level-6 + `soundtrigger@2.2` broke the build, sm7125 could not have shipped 23.2. It shipped.

**Verdict: keep the `manifest.xml` block exactly as it is.** Deleting it does not "prevent" a checkvintf
failure; on the evidence it risks causing one, because the level-6 entry is mandatory and deleting the
declaration leaves it unsatisfied.

### 1.5 If the lead still deletes the block — every file and line that would have to change

This is the list the prompt asked for. Only **two** edits are needed, and **both are optional**:

1. `manifest.xml:102-110` — delete the whole `<hal format="hidl">…</hal>` block (line **105** is the
   `<version>2.2</version>` R1 cites; the block spans 102–110 inclusive).
2. `gts4lv.mk:58` — **recommended**: also drop
   `android.hardware.soundtrigger@2.2-impl:32 \` from the `PRODUCT_PACKAGES` block (lines 53-72).

Nothing else. Specifically, all of these stay as they are and cause no failure:

- `BoardConfigCommon.mk:51` `BOARD_SUPPORTS_SOUND_TRIGGER := true` — leave it. No consumer in `build/make`
  @ `e5aaa621`, and `frameworks/av`'s use of it is a runtime boolean, not a build dependency on the HAL
  being declared. (Consumer not located — **confidence: medium**.)
- `init/init.qcom.rc:785` — **must stay**. That service is the audio HAL; you cannot remove it, and it is
  not a soundtrigger service. Removing the manifest block does not make it try to register a HAL that no
  longer exists: `service.cpp:158` is `ALOGW_IF`, so a failed soundtrigger registration is a log warning.
- `init/init.qcom.rc:468-470` — leave it (comment + two `chown`s on DSP sysfs).
- `Android.bp:8913-8914`, `:9023-9032`, `:9273-9299`, `:8937` and `gts4lv-common-vendor.mk:322,:331` — leave them.
  These are the *audio HAL's* soundtrigger blobs, linked into `audio.primary.qcom.so`; they have nothing to
  do with the HIDL soundtrigger *service*. Deleting them would break the audio HAL.
- `proprietary-files.txt:572-575` — leave it; it describes vendor blobs, not VINTF.
- sepolicy — **no change needed.** Our `sepolicy/` has zero soundtrigger references; the three that exist in
  `system/sepolicy` (`hwservice_contexts:64`, `audioserver.te:44`, `service_contexts:120`) are all
  per-interface and all stay correct whatever the device manifest says (§1.1).
- `vintf` fragments — no change. Our own `framework_compatibility_matrix.xml` and the qcom-caf one contain
  no soundtrigger entry.

So the honest answer to "what else must go with it": **only `gts4lv.mk:58`, and even that is not required** —
leaving it ships an extra vendor library that the passthrough registry probes for and finds.

---

## Part 2 — `per_proxy_helper`

### 2.1 The declaration

`sepolicy/vendor/per_proxy_helper.te` @ `2e50286ebc01`, 8 lines, in full (under the 20-line limit):

```
1  type per_proxy_helper, domain;
2  type per_proxy_helper_exec, exec_type, vendor_file_type, file_type;
4  init_daemon_domain(per_proxy_helper)
6  allow per_proxy_helper firmware_file:file r_file_perms;
8  allow per_proxy_helper ssr_device:chr_file r_file_perms;
```

It was added by `e88df885ca241c4f05b25da79e40918b9b420e3a` (LuK1337, 2019-09-01) "gts4lv-common: sepolicy: Add
initial set of SELinux rules", whose own commit message says the rules are *"somewhat blindly reverse
engineered from stock"*. That is the key fact: it describes **stock firmware**, not this build.

`init_daemon_domain` does expand to `domain_auto_trans(init, $1_exec, $1)` (`public/te_macros` @ `885cc500f607`),
which does need the exec type labelled — **but only if something is ever exec'd.**

### 2.2 Blob search: no blob exists

Searches run, all clean:

```
git -C vcommon ls-tree -r --name-only HEAD | grep -iE "per.?proxy|proxy|helper"
git -C vlte    ls-tree -r --name-only HEAD | grep -iE "per.?proxy|proxy"
git -C vcommon grep -n -i "per_proxy_helper" HEAD
git -C dt      grep -n "per_proxy_helper\|perproxy\|proxy_helper" 2e50286ebc01
grep -rl "per_proxy" vcommon/proprietary vlte/proprietary        # binary content, both trees
grep -nE '^vendor/bin/.*(per|proxy)' <dt:proprietary-files.txt>
```

Results:

- **Path search: 0 hits** in either vendor repo for `per_proxy_helper`, `perproxy`, `per_proxy`.
- **Content search: 0 hits.** No blob in either vendor repo contains the string `per_proxy_helper`.
- `proprietary-files.txt` (768 lines) lists **34** `vendor/bin/**` entries. Cross-checked every one against
  the vendor repo: **all present** (the two `|hash` rows, `wfdhdcphalservice` and `wifidisplayhalservice`,
  are name|hash forms, not missing files). **No `per_proxy_helper` row exists.**
- I also listed **every** binary in both vendor repos. The closest name is
  `proprietary/vendor/bin/pm-proxy`. The complete `vendor/bin/**` list is in §2.3.

### 2.3 Is `pm-proxy` the binary? No — three independent pieces of evidence

1. `pm-proxy` is already fully labelled by the tree we inherit:
   `android_device_qcom_sepolicy_vndr` @ `0dbc76e4b759da5681b8c96b7e2bb7c1ae0cc6b1`
   `legacy/vendor/common/file_contexts:257`:
   `/(vendor|system/vendor)/bin/pm-proxy            u:object_r:vendor_per_mgr_exec:s0`
   i.e. it runs in `vendor_per_mgr`, the same domain as `pm-service`. No separate domain is needed or used.
   (The `generic/` variant has a separate `vendor_per_proxy` domain at
   `generic/vendor/common/per_proxy.te:28-36` with `generic/vendor/common/file_contexts:135`, but our branch
   is `lineage-23.2-legacy-um` and that branch's selected variant is `legacy/`.)
2. Our `per_proxy_helper` has no rules that fit `pm-proxy`. `pm-proxy` needs
   `vndbinder_use` / `binder_call(vendor_per_proxy, vendor_per_mgr)` (vndr `per_proxy.te:35-36`); ours only
   touches `firmware_file` and `ssr_device`. Different policy.
3. Our `per_proxy_helper` domain is declared but **never referenced anywhere**: `git grep per_proxy_helper`
   over the whole device tree returns only the 5 lines inside `per_proxy_helper.te` itself.

### 2.4 Verdict: dead code, no runtime effect, do not add a `file_contexts` line

An unlabelled `exec_type` that no file ever gets is **inert**: `domain_auto_trans(init, $1_exec, $1)` simply
has nothing to match, so no process is ever transitioned. There is no `neverallow`, no unused-type and no
unmatched-regex build check in `system/sepolicy`'s `checkfc` for this. Nothing at boot can fail because of
it. LEAD-SYNTHESIS §7.5 calls it a "latent runtime problem … worth fixing before first boot" — that
characterisation is wrong and P5 should not act on it.

Evidence that this whole class of leftover exists in this tree, and is equally harmless:
`secril_config_svc.te` (`:1`, `:2`, `:4`, `:6-14`) **is** labelled at
`sepolicy/vendor/file_contexts:19`, but there is **no `secril_config_svc` blob** in either vendor repo and no
init service for it (`grep -rl secril_config_svc vcommon/proprietary vlte/proprietary` → 0 hits). So we
already ship a fully-wired-but-empty domain, and the device builds and boots on 22.2. `per_proxy_helper` is
the same kind of stock leftover, one step less wired.

**The exact line, if the lead decides to keep the domain anyway** (for symmetry with `secril_config_svc`).
Style copied from `sepolicy/vendor/file_contexts:17-19`:

```
# Binaries
/(vendor|system/vendor)/bin/hw/macloader       u:object_r:macloader_exec:s0
/(vendor|system/vendor)/bin/secril_config_svc  u:object_r:secril_config_svc_exec:s0
```

Insert **after `sepolicy/vendor/file_contexts:19`** (i.e. it becomes line 20, before the blank line and the
`# Data files` heading), with the type column aligned to line 19 as it is today:

```
/(vendor|system/vendor)/bin/per_proxy_helper    u:object_r:per_proxy_helper_exec:s0
```

**But I recommend against adding it**, because the regex would match no file in the image. My choice, with
evidence: **remove `sepolicy/vendor/per_proxy_helper.te` (4 declarations, 8 lines) and change nothing else.**
It is provably dead (§2.2), it was reverse-engineered from a stock partition we do not ship, and deleting a
policy file that no blob can reach cannot regress anything. `confidence: medium` — high that it is dead,
medium that deleting is better than leaving it, because "leave it" is also perfectly safe and is the smaller
change. Either way **do not** add the label line.

---

## Part 3 — the sibling finding: `kgsl_device`

`sepolicy/vendor/device.te:8` — `type kgsl_device, dev_type;`. Same systematic check as `per_proxy_helper`,
over `file_contexts` + `genfs_contexts`:

| type | label lines found |
|---|---|
| `botablk_device`, `debug_block_device`, `dsp_block_device`, `dun_device`, `efsblk_device`, `fp_sensor_device`, `hiddenblk_device`, `omr_block_device`, `paramblk_device`, `sec_efsblk_device`, `steady_block_device`, `tz_device` | 1 each |
| **`kgsl_device`** | **0** |
| **`per_proxy_helper`, `per_proxy_helper_exec`** | **0** |
| `macloader`, `macloader_exec`, `secril_config_svc`, `secril_config_svc_exec` | 1 each |

**`kgsl_device` is genuinely unused, and adding a label would be actively wrong.** The device nodes exist
and are used — `init/ueventd.qcom.rc:38-41` creates `/dev/kgsl`, `/dev/kgsl-3d0`, `/dev/kgsl-2d0`,
`/dev/kgsl-2d1`, and **17** blobs in `vcommon` reference the string `kgsl-3d0` (`libgsl.so`,
`libadreno_utils.so`, `libCB.so`, `libqti-perfd.so`, `libgpudataproducer.so`, `libVkLayer_q3dtools.so`,
`egl/libq3dtools_esx.so`, `libSNPE.so`, `bin/thermal-engine`, `etc/perf/commonresourceconfigs.xml`, and
their `lib64` twins) — but the node is **already labelled** by the Qualcomm vendor sepolicy we inherit:

`android_device_qcom_sepolicy_vndr` @ `0dbc76e4b759` `legacy/vendor/common/file_contexts:36`

```
/dev/kgsl-3d0                                   u:object_r:gpu_device:s0
```

So the type is used (`gpu_device`, granted to `surfaceflinger` at `system_sepolicy`
`private/surfaceflinger.te:40` `allow surfaceflinger gpu_device:chr_file rw_file_perms;` @ `885cc500f607`),
but it is **`gpu_device`, not `kgsl_device`**. Adding a `kgsl_device` label would either be dead (nothing
would use the type) or, worse, re-label the node and break the GPU. **Leave `device.te:8` alone.**
`confidence: high`.

`android_device_qcom_sepolicy` @ `d903f8e1e0c4` and `android_system_sepolicy` @ `885cc500f607` contain **0**
references to `kgsl_device` or `per_proxy_helper`, so the two types are dead in the whole policy, not just in
ours.

---

## What P5 must do, as concrete edits

**Soundtrigger (AGENT-TASKS §6c item 2)**

1. **Do not touch `manifest.xml:102-110`.** Keep `android.hardware.soundtrigger` hidl 2.2. Reason and evidence:
   §1.4. `confidence: high`.
2. **Do not remove `gts4lv.mk:58`.** The module it names exists
   (`soundtrigger/2.2/default/Android.bp:26` @ `13d687a84c83`) and the HAL it installs is registered at boot
   by `init/init.qcom.rc:785`. `confidence: high`.
3. **Nothing else.** No `.rc`, no sepolicy, no blob list, no `Android.bp`, no `PRODUCT_*` var and no
   `vintf` fragment references soundtrigger. `confidence: high`.

**`per_proxy_helper` (AGENT-TASKS §6c item 3)**

4. **Do not add a `file_contexts` line.** There is no blob for it to label (§2.2). If the lead wants the
   domain kept for symmetry with `secril_config_svc`, the line would be
   `/(vendor|system/vendor)/bin/per_proxy_helper    u:object_r:per_proxy_helper_exec:s0`, inserted after
   `sepolicy/vendor/file_contexts:19`. `confidence: high` that it is unnecessary.
5. **Optional, lead's choice:** delete `sepolicy/vendor/per_proxy_helper.te` (all 8 lines) as dead policy.
   Do **not** delete `kgsl_device` from `sepolicy/vendor/device.te:8` and do **not** add a `/dev/kgsl*`
   label — the node is already `gpu_device` via `qsevndr`
   `legacy/vendor/common/file_contexts:36`. `confidence: medium` (see §2.4).
6. If item 5 is done, the commit message must not say it fixes a runtime failure — there is none.

**Also for P5's log**

7. Record in `analysis/port/P5-log.md` that §6c items 2 and 3 were **intentionally skipped**, with the
   reason, so P5-R does not read the missing commits as an oversight. `confidence: high`.

## Problems

- `LineageOS/android_system_tools_vintf` and `aosp-mirror/platform_system_tools_vintf` both fail to clone:
  `fatal: could not read Username for 'https://github.com': No such device or address` (i.e. 404). I did not
  guess at a replacement URL. Consequence: I could not read the code that implements the "frozen matrix
  supersedes older FCM levels" rule, so the *mechanism* in §1.3 is `confidence: medium`. The *conclusion*
  rests on the sm7125 tree instead, which is `confidence: high`.
- One batch of clones raced and left three directories (`audio660`, `audio845`, `audio660-22`) missing after
  reporting success, because `cd X && A & B & C & wait` binds `cd` only to the first background job. I
  re-ran the three clones sequentially and verified each HEAD SHA before using them. No bad data was used.
- **Self-correction, found by my own final self-check.** My first sepolicy grep for soundtrigger used
  `git grep -i soundtrigger <rev> -- 'private/*.te' 'public/*.te' 'vendor/*.te'`, which only matched `.te`
  files, and I wrote "no sepolicy reference exists". That was wrong: `private/hwservice_contexts:64`,
  `private/audioserver.te:44` and `private/service_contexts:120` @ `885cc500f607` do reference soundtrigger.
  The table and the negatives list in §1.1 are now corrected. No verdict changed: all three are
  per-interface labels that remain valid regardless of the device manifest, and none of them requires the
  `manifest.xml` block. The mistake was in the search pattern, not in the conclusion.
- I did not clone `frameworks/av`, so I could not name the consumer of
  `BOARD_SUPPORTS_SOUND_TRIGGER` (`BoardConfigCommon.mk:51`). It is a build/board flag, not a manifest entry,
  so it does not change any verdict; reported as `confidence: medium` rather than guessed.