# review L1–L3: what applies to gts4lv for LineageOS 24.0

Reviewed 2026-10-09 by the lead. Inputs: `L1.md` + `L1-changes.tsv` (`agent/L1` @ `36ffe11`),
`L2.md` (`agent/L2` @ `4ff92c2`), `L3.md` + `L3-gerrit-merged.tsv` (`agent/L3` @ `4ed0735`).

This is the input L6 works from. Every claim below I re-checked against the upstream source or our
own tree; where an agent's reasoning was wrong I say so and give the corrected basis.

## Summary

1. **Kernel: no changes.** Confirmed three independent ways. Our `ro.bpf.kver_override=5.15.178` already satisfies
   every netbpfload gate on 24.0.
2. **L6 is small: 4 commits, not 7.** Two of TASKS-L24's planned steps are dropped (see §3), one is promoted
   from "unsure" to **mandatory** (`disable_configstore`).
3. **L2's measurement overturns the plan for VINTF.** Nothing needs dropping. sm7125 ships `soundtrigger@2.2`
   at FCM 7 and builds.
4. **`android_hardware_samsung` contributes zero work.** Its 30-commit list is a rebase artifact.
5. **One hard blocker found for L6 step 2**: `disable_configstore` is deleted in 24.0, so keeping it in
   `PRODUCT_PACKAGES` is an unresolvable module reference, not a cleanup.

## 1. Kernel: no commits for 24.0

L1 answered "no" and the reasoning holds. Confirmed:

| Check | Source | Result |
|---|---|---|
| Our override | `product.prop:7` @ `1188e2b` | `ro.bpf.kver_override=5.15.178` |
| 5.15 supported by loader | `KernelUtils.h:105` @ `7c04d866538e` | `isKernelVersion(5, 15)  // first supported in Android T` |
| Highest 24.0 gate | `NetBpfLoad.cpp:1584` | `REQUIRE(5, 15, 136)` — 5.15.178 passes |
| Upstream kernel work, motorola | `android_kernel_motorola_exynos9610` compare | `ahead_by=0, behind_by=0` |
| Upstream kernel work, ours | `ExyHyperBrick/android_kernel_samsung_exynos9810@lineage-24.0` | `== lineage-23.2 == baa585f67e0e` |

**L1 correction, accepted:** the ExyHyperBrick repo is `android_kernel_samsung_exynos9810`.
`android_kernel_samsung_exynos9820` returns 404. The conclusion is unchanged.

**Do not touch** `ro.bpf.kver_override`, and do not port anything from sm7125's 1,531 kernel commits. Those exist
to make a 4.14 tree *behave* like 5.10; our tree is a real 5.15.

### Watch-list for L7/L8 (not device-tree work)

| Risk | Source | Why |
|---|---|---|
| New 5.15 gate is **fatal** | `NetBpfLoad.cpp:1584-1586` (`ALOGE` + `return 7`) | 23.2 had no such gate. We pass, but if the override ever stops being read we lose netd BPF entirely |
| 5.10 gate severity changed | 23.2 `:1636-1638` = `ALOGW`, no return; 24.0 `:1578-1580` = `ALOGE` + `return 7` | We pass either way |
| `/apex/com.android.resolv` hard check | 24.0 `NetBpfLoad.cpp:1542-1544`, **absent in 23.2** | New rejection path; if our DNS resolver runs from that APEX it stops loading |
| BPF program ranges keyed on API level | L3 §1.4 | Our 23.2 build attaches 14 cgroup programs. If the keying changed, the count will differ. Check at L10, expect 14 |
| `/metadata/aconfig` SELinux labelling | L3 §Problems.3 (unchecked) | Our `b26a9d6` OMR fix depends on this path. `/metadata/aconfig` is now also created at early-init |

**L3 correction, accepted:** the claim that `cgroupskb` BPF programs were removed in 24.0 is **wrong**.
`NetBpfLoad.cpp` has zero hits for `cgroupskb` on *both* branches — gone since before 23.2. Not a 24.0 change,
not a risk for us.

**L3 correction, accepted:** the SDK level for 24.0 is read from AOSP `platform/build/release`
@ `android-17.0.0_r1` (`cp2a` → 37.0), because `LineageOS/android_build_release` has no `lineage-24.0` branch.
L3 marked this medium confidence. It only affects whether the 5.15 gate is reachable; L7 settles it.

## 2. L2: no VINTF drops. The plan's step 2 is withdrawn

L2 measured this rather than inferring it, and I confirmed the reasoning independently.

**Mechanism.** `compatibility_matrix.7.xml` (839 lines) contains **zero** `optional="false"` attributes. Nothing in
level 7 is mandatory. Declared HALs outside the allowed range are forgiven by `checkUnusedHals` when a listed child
covers the interface. L2 ran the tree's own `checkvintf --check-compat` against `target-level="7"` on copies of
the built manifests: **COMPATIBLE, exit 0.**

**Independent corroboration.** sm7125 at `target-level="7"` on 24.0 declares `soundtrigger@2.2` at
`configs/manifest.xml:84-92` (verified), while matrix 7 `:682` allows only `2.3`. It builds. Its
`override="true"` count is **27 on both 23.2 and 24.0** — unchanged, so those blocks are pre-existing
infrastructure, not an FCM-7 remedy.

**L2 correction, accepted:** the task brief's override reference is wrong. `1c75d13fdad6` is
"Remove no longer needed local FCM" (2024-12-30, deletes `configs/framework_compatibility_matrix.xml`);
`6edc6f2518c5` only bumps the level and drops `<kernel target-level="6"/>`. There is no FCM-7 override
commit to copy.

**L1 correction, accepted:** L1 said our `framework_compatibility_matrix.xml` declares `com.qualcomm.qti.ant`.
It does not — the file is a 4-line stub containing only `<version>1.0</version>`. The ANT declaration is
`manifest.xml:112-118` in the *device* manifest. L1's verdict on `1c75d13fdad6` was already `unsure`, so
no decision changes, but the basis was wrong.

### Decision: keep all three, drop nothing

| Finding | Declared at | Provided by | Decision |
|---|---|---|---|
| `gnss@1.1` | `android.hardware.gnss@2.1-service-qti.xml:32` (blob fragment, `@1.1::IGnss/default`), installed by `gts4lv-common-vendor.mk:456` | `vendor.samsung.hardware.gnss` + qti blob | **keep** |
| `soundtrigger@2.2` | `manifest.xml:102-110` @ `1188e2b` | `gts4lv.mk:54` + `sound_trigger.primary.sdm710.so` | **keep** |
| `radio@1.4` (LTE only) | `device/samsung/gts4lv/manifest.xml:2-7` @ `3260fd2c` | `libril.so` hard-depends on `android.hardware.radio@1.4.so` | **keep → L9** |

Dropping `soundtrigger` would lose the hardware hotword path to fix a check that passes. Not a trade worth making.

Also confirmed: a `<hal override="true">` **cannot** suppress a blob fragment. L2 measured `Conflicting FqInstance`
because `manifest.xml` is parsed before the fragment directory. So even if we later wanted to drop `gnss@1.1`,
the fix is to stop shipping the fragment in the vendor repo — not an override.

**Kernel requirement note (L2 §7), accepted:** matrix 7 wants kernel ≥ 4.14.336; ours is **4.9.337**
(`Makefile` VERSION=4 PATCHLEVEL=9 SUBLEVEL=337 @ `500658be3c16`). Currently harmless because the build never
passes `--kernel` to `checkvintf`. This is exactly why sm7125 set `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false`.
Defer to L7 per TASKS-L24 L6 step 5.

## 3. L6: exactly 4 commits, in this order

Branch `port/l24-dt-1`, cut from the device fork's `lineage-24.0`. One commit each, each citing its source.

| # | Commit | Source | Our line | Notes |
|---|---|---|---|---|
| 1 | `manifest.xml`: `target-level="5"` → `"7"` | sm7125 `6edc6f2518c5` | `manifest.xml:1` | Also drop any `<kernel target-level>` if present — ours has none |
| 2 | **`disable_configstore`: remove from `PRODUCT_PACKAGES`** | motorola `ccc6b60a7fb7` | `gts4lv.mk:121-122` | **Mandatory, see §4** |
| 3 | legacy libion: `include device/lineage/sepolicy/libion/sepolicy.mk` + `$(call soong_config_set_bool,libion,legacy_impl,true)` | sm7125 `429c604442ac` / motorola `f612e062b75e` (same Change-Id `Ic063618d694`) | `BoardConfigCommon.mk:106`, `BoardConfigCommon.mk:153` region | Exact two-file change |
| 4 | `$(call soong_config_set_bool,libui,legacy_gralloc,true)` | motorola `013cbf52557f` | `gts4lv.mk:128` `gralloc.sdm710` | New for us; see §4 |

**Withdrawn from TASKS-L24 §L6:**

- Step 2 (drop `gnss@1.1` via override, drop `soundtrigger@2.2`) — **withdrawn**, §2.
- Step 3's companion `5fbe9c467542` (remove `TARGET_USES_ION` / `TARGET_DISABLED_UBWC`) — **withdrawn as a
  separate commit.** It is the same edit as legacy libion's target, and we still need `TARGET_USES_ION := true`
  until legacy libion is actually in the build. Folding it into commit 3 would be correct only once the build
  proves it; if L7 shows ION still referenced, restore it. **Do not pre-apply.**
- Step 5 (`PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false`) — **deferred to L7**, only on a real
  kernel-requirements failure, citing the error line.

**Explicitly untouched:** `ro.bpf.kver_override`, all five 23.2 boot fixes (`a7f1483`, `4f4a15c`, `b26a9d6`,
`3557101`, `e38c0de`), and every `unsure` row in L1's TSV.

## 4. Two findings L1 missed that change the commits

### 4.1 `disable_configstore` is deleted in 24.0 — not a cleanup, a build break

L1 marked motorola `ccc6b60a7fb7` `yes` as "stop shipping `disable_configstore`", reading it as tidiness.
It is load-bearing:

- `hardware/interfaces/configstore/1.1/default/Android.bp:137-138` defines `name: "disable_configstore"` on 23.2.
- On `lineage-24.0` the whole `configstore/` directory **does not exist**
  (`contents/configstore?ref=lineage-24.0` → `Not Found`; root tree has 65 entries vs 66).
- Deleting commit: `d9c2fe8e62c5` "delete configstore", 2026-02-05.

So `PRODUCT_PACKAGES += disable_configstore` at `gts4lv.mk:122` becomes a reference to a module that no longer
exists. Left in place it will fail the build. L6 commit 2 is **mandatory**, not cosmetic.

**Do not also remove `manifest.xml:160`** (`vendor.qti.hardware.capabilityconfigstore`, declared, with a real
implementation: `vendor.qti.hardware.capabilityconfigstore@1.0-impl.so`, service installed at
`gts4lv-common-vendor.mk:468`). motorola has no such declaration on either branch, so its commit is not a
precedent for touching ours. Level 7 is silent on this vendor HAL and nothing in L2 flags it. **Leave it, but
watch for a build error referencing it** and escalate if it appears.

### 4.2 `legacy_gralloc` is new in 24.0 — and it is a define, not a package

L1 marked motorola `013cbf52557f` `yes` for `gralloc.sdm710` at `gts4lv.mk:128`. Correct, and the mechanism
matters because it does not exist on 23.2:

- 23.2 `frameworks/native/libs/ui/Android.bp`: **zero** occurrences of `legacy_gralloc`.
- 24.0 `libs/ui/Android.bp:136-139`:
  ```python
  }) + select(soong_config_variable("libui", "legacy_gralloc"), {
      true: ["-DLEGACY_GRALLOC"],
      default: [],
  }),
  ```

So it adds `-DLEGACY_GRALLOC` to `libui`. We ship a first-generation gralloc (`gralloc.sdm710`) that lacks the
gralloc2/3/4 interfaces 24.0 expects. **Without this, the first build will very likely fail to link `libui`**,
because 24.0 references symbols that only exist under that define. Treat L6 commit 4 as near-certainly
required, and confirm the failure mode in L7 before changing anything else.

## 5. Watch-list handed to L9 (strong model, LTE)

`radio@1.4` cannot be fixed in the device tree. `libril.so` has a hard `NEEDED android.hardware.radio@1.4.so`;
matrix 7 `:575-596` allows `1.2` (ISap) and `1.5-6` (IRadio), and the matrix comment at `:583-586` says
"Android 17 has special extended support for IRadio for devices launching using FCM Level 6" — an explicit
carve-out that does not cover a 4.14-era 1.4 RIL at level 7.

Options, unchanged from TASKS-L24 §L9: (a) the build tolerates it, (b) a 1.4→1.5 passthrough shim,
(c) LTE without telephony. Untestable without an LTE tablet — anything shipped is "untested".

Wi-Fi model is unaffected. Nothing in L1–L3 touches the Wi-Fi path.

## 6. Volatility

`lineage-24.0` is pre-release and moving: `frameworks/base` took 165 commits in the 30 days to 2026-10-09.
Concretely:

- **Re-run L1 step 1 before L5 cuts branches.** `hardware/samsung` SHAs will churn and will keep churning.
- **The `yes` set is stable.** Both reference trees made the libion Change-Id independently, which is a strong
  signal it is required, not a tree-specific preference.
- **`disable_configstore` and `legacy_gralloc` are structural.** They follow from files being deleted and a
  define being added in the platform. They will not flip back.
- `1d2a05927c04` is unsettled upstream by its own admission ("until we fix kernel"). We are not taking it.

## 7. Self-check

- Every decision above cites a commit SHA ≥12 chars, a `file:line @ commit`, or a measured command result.
- The four L6 commits each have exactly one upstream source.
- Two agent errors corrected (`android_kernel_samsung_exynos9820` repo name; `cgroupskb` removal claim).
- One more corrected (`framework_compatibility_matrix.xml` content), verdict unchanged.
- One item L1 missed and one it under-classified (`disable_configstore` deleted; `legacy_gralloc` mechanism).
- Read-only throughout. Nothing in `~/android/lineage` or any fork branch was modified.

## Problems

None blocking. Open items, all tracked above: `/metadata/aconfig` SELinux labelling unverified (L3 §Problems.3,
ours to fix in L7/L8 if it bites); L3's Gerrit paging note (`S=`, not `s=`) recorded in its report.