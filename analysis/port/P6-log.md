<!-- task: P6 -->
# P6: ROM build-error loop

Log started 2026-10-04. One commit so far. The build is currently **running** — see "Build state" at the end.

## Fix 1 — `d154fb4384fb2331c5a186b19140209ee0235849`

**Error addressed**

```
[100% 16/16] finishing Make module rules: Adding module dependencies
FAILED:
build/make/core/main.mk:1074: warning: device/samsung/gts4lvwifi/lineage_gts4lvwifi.mk includes non-existent modules in PRODUCT_PACKAGES
Offending entries:
AntHalService
build/make/core/main.mk:1074: error: Build failed.
15:19:50 kati failed with: exit status 1
```

**Change** — `device/samsung/gts4lv-common/gts4lv.mk`, 4 lines deleted, nothing added:

```diff
-# ANT+
-PRODUCT_PACKAGES += \
-    AntHalService
-
 # Audio
 PRODUCT_PACKAGES += \
     android.hardware.audio@6.0-impl.gts4lv:32 \
```

Branch `port/dt-2`, cut from `lineage-23.2` @ `e3ccc92`. Trailer `Fix-by: Space Bunny Free (helper); main.mk:1074 AntHalService`.

**Why this is the right fix, and not a guess.** This is §6c P6's allowed case *"removing a reference to a file or
module 23.2 deleted"*. The module `AntHalService` does not exist anywhere in the LineageOS 23.2 tree: a whole-tree
`grep -rn --include='*.mk' --include='*.bp'` returns **exactly one hit**, the `PRODUCT_PACKAGES` entry itself. No
other samsung device tree references it.

The repo's own history says why it is dangling. Commit `dd5671a31b39` ("gts4lv-common: Enable ANT+ support") added
**two** entries together — `AntHalService` *and* `com.dsi.ant.antradio_library`. Commit `635baf7e30aa` removed the
second one with the message *"No longer shipped by default with lineage-19.0"* and left the first behind. So the
reference has been dead for several releases; this commit is the same cleanup, one commit later. `confidence: high`.

**The ANT blobs are unaffected.** They are installed by `PRODUCT_COPY_FILES` in `gts4lv-common-vendor.mk`, not by a
build module, so they still ship:

```
vendor/samsung/gts4lv-common/proprietary/vendor/lib64/com.qualcomm.qti.ant@1.0.so
vendor/samsung/gts4lv-common/proprietary/vendor/lib64/hw/com.qualcomm.qti.ant@1.0-impl.so
vendor/samsung/gts4lv-common/proprietary/system/lib64/libantradio.so
vendor/samsung/gts4lv-common/proprietary/system_ext/lib64/com.qualcomm.qti.ant@1.0.so
```

**Functional consequence, stated plainly:** ANT+ will not work on this build. There is no service module to host the
HAL, so the libraries have no caller. That is a real feature loss versus 22.2, and the alternative was a build that
does not finish. Flagging it rather than burying it. `confidence: high`.

## Build state

**Kati passed. Ninja is compiling** — 205,092 targets, 20% done (41,288) at last reading, ~2.5 targets/s.

This is the first time the ROM build has got past the `PRODUCT_PACKAGES` check, which is what fix 1 unblocked.

## Host notes, for whoever reads this next

- **Memory is solved but slow.** The box has 15 GB RAM + 47 GB swap (a 32 GB `/swapfile` on the NVMe plus the 15 GB
  partition). The build peaked at 13 GB RSS + 28 GB swap in the Soong glob phase and survived. Without the extra
  swap it was OOM-killed twice — see [B1-log.md](B1-log.md). Expect the build to be slow; that is the trade.
- **Disk is the live constraint: 41 GB free, `out/` already 24 GB.** A full LineageOS `out/` is typically 30–50 GB,
  so this probably fits, but not with much room. `/mnt/build` (the attached drive) has **684 GB free** and is
  unused by the build — it is the escape hatch if `out/` needs relocating.
- **Disk projections from the current phase are not trustworthy.** The build is presently in C++ compilation, which
  writes many small object files. The final phases (dex, APEX packaging, images) produce far fewer and much larger
  outputs. Do not extrapolate a linear bytes-per-target figure from here.
- **`out/build.ninja` does not exist** even though ninja is running; Android 16 keeps the graph in
  `out/soong/`. Do not treat its absence as a failure.

## What a successful build does and does not prove — read before approving fix 2

**A green build is necessary but not sufficient. It is not evidence that a fix is correct.**

A successful `brunch` proves exactly one thing: the build constraint stopped firing. It does **not** prove the
change did the right thing. In this project that distinction has a very concrete failure mode, because the error
being fixed is itself a *policy* check — so the easiest way to make it go away is to remove the thing the policy
is protecting.

For fix 2 (`Disallowed PATH tool "arm-linux-gnueabi-ld.bfd"`), these all produce a **green build** and are not
equivalent:

| fix shape | build | what it actually did |
|---|---|---|
| point the arm32 toolchain at the system `arm-linux-gnueabi-ld.bfd` | green | intended — 32-bit modules built as designed |
| **disable `CONFIG_COMPAT`** | green | **silently drops 32-bit support.** vdso32 gone, 32-bit HWC, and any 32-bit-only app path |
| **drop vdso32 from `Kbuild`** | green | **silently drops the 32-bit vDSO.** No error, no warning |
| **bypass or widen the PATH_Tools allowlist** | green | **weakens a security boundary** so the error stops being reported |
| stub `arm-linux-gnueabi-ld.bfd` to a no-op | green | produces a broken or absent 32-bit vDSO |

So the review question is **not** "does it build". It is:

1. Does `CONFIG_COMPAT=y` still hold in `out/target/product/gts4lvwifi/obj/KERNEL_OBJ/.config` afterwards?
2. Was `vdso32` actually **built** — is there a real 32-bit vDSO object in the kernel output, not just a skipped
   step? (`obj/KERNEL_OBJ/arch/arm64/kernel/vdso32/` should exist and be non-trivial.)
3. Do the 32-bit kernel modules exist under `vendor/lib/modules/`?
4. Did anything get **disabled, stubbed or allowlisted** rather than made to work? A diff that deletes a
   `Kbuild` line, flips a `CONFIG_`, or edits AOSP's `PATH_Tools` allowlist is a red flag, not a fix.
5. Is the linker used the **real** system linker, and not AOSP's `.path_interposer`?

`confidence: high` that this is the right framing; the specific fix has not been chosen yet.

The general rule this instantiates: **when the build error is a guard rather than a missing symbol, the cheapest
green build is usually the guard being removed rather than the problem being solved.** A fix that only makes the
checker quiet has moved the cost, not removed it.

## Escalated

None.

## Process note

The P6 agent that made fix 1 ended its session without writing this log, so the lead recorded it from the commit
itself and the build log. The commit and its message were left exactly as the agent wrote them.