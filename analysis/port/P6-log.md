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

## Fix 2 — the missing git-lfs object for `webview.apk` (no code change)

**The error addressed — the *first* `FAILED:` in `~/work/rom-build2.log`, not the linker message.**

```
rom-build2.log:158681  FAILED: out/soong/.intermediates/external/chromium-webview/webview/android_common/enforce_uses_libraries.status
rom-build2.log:158683  external/chromium-webview/prebuilt/arm64/webview.apk: error: failed opening zip: Invalid file.
rom-build2.log:158684  error: Command '['out/host/linux-x86/bin/aapt2', 'dump', 'badging',
                       'external/chromium-webview/prebuilt/arm64/webview.apk']' returned non-zero exit status 1.
```

**Root cause: the file was never fetched — it was a 134-byte git-lfs *pointer*, not an APK.**

```
$ file external/chromium-webview/prebuilt/arm64/webview.apk     # before the fix
external/chromium-webview/prebuilt/arm64/webview.apk: ASCII text
$ head -c 60 external/chromium-webview/prebuilt/arm64/webview.apk
version https://git-lfs.github.com/spec/v1
oid sha256:3b98460ccd41b2a1851c5a46e6dec6f86f14302ff2fa4dbe1d781e3f89a4
```

**Why the pointer survived `repo sync --git-lfs`: git-lfs was installed three minutes *after* the tree was checked
out.**

```
$ stat -c '%y' external/chromium-webview/prebuilt/arm64/.gitattributes
2026-10-04 10:32:32 -0400                 <- repo checkout
$ grep git-lfs /var/log/dpkg.log
2026-10-04 10:35:20 install git-lfs:amd64 <none> 3.6.1-1+deb13u1   <- package installed
2026-10-04 10:35:35 status installed git-lfs:amd64 3.6.1-1+deb13u1
```

This is the same root cause as B1-log.md §"Blocked on the owner: 20 missing packages", which listed `git-lfs`
among the packages the sync ran without. `confidence: high` — dpkg and file(1) are direct.

**Scope: four files, all of them the same artifact in four webview prebuilt repos.**

```
$ find . -name .lfsconfig -not -path './out/*' -not -path './.repo/*'
./external/chromium-webview/prebuilt/arm64/.lfsconfig
./external/chromium-webview/prebuilt/x86_64/.lfsconfig
./external/chromium-webview/prebuilt/arm/.lfsconfig
./external/chromium-webview/prebuilt/x86/.lfsconfig
```

No other repo in the tree declares `filter=lfs`, so nothing else is affected. `confidence: high`.

**The fix** (host-side, no repository edited, nothing committed):

```bash
git -C external/chromium-webview/prebuilt/arm64 lfs pull   # 267,260,603 bytes
git -C external/chromium-webview/prebuilt/arm   lfs pull   #  96,770,476 bytes
```

```
$ file external/chromium-webview/prebuilt/arm64/webview.apk
external/chromium-webview/prebuilt/arm64/webview.apk: Android package (APK), with AndroidManifest.xml
$ unzip -l external/chromium-webview/prebuilt/arm64/webview.apk | head -6
Archive:  external/chromium-webview/prebuilt/arm64/webview.apk
  Length   Date    Time    Name
---------  ------- -----   ----
    28564  2001-01-01 00:00   AndroidManifest.xml
    28526  2001-01-01 00:00   assets/chrome_100_percent.pak+com.android.webview+
```

The x86 and x86_64 prebuilts are left as pointers: this product builds only `arm`/`arm64`, and pulling 500 MB
of x86 WebView onto a disk with 19 GB free would be waste. If a future flavor needs them, pull them then.

**Nothing was disabled to make this go away.** No sepolicy edit, no `PRODUCT_PACKAGES` edit, no
`BUILD_BROKEN_*`, no `PRODUCT_SHIPPING_API_LEVEL`, no `target-level`. The device tree is unchanged by fix 2;
`git -C device/samsung/gts4lv-common diff --stat e3ccc923bcf2..HEAD` is still just fix 1's four deletions.

## The `arm-linux-gnueabi-ld.bfd` message is a *report*, not a failure — no fix made, deliberately

**Finding: it never stopped the build and it did not damage the 32-bit vDSO.** `confidence: high`.

Line numbers in `rom-build2.log` settle the ordering. The webview `FAILED:` is at line 158681; the four
`Disallowed PATH tool` lines are at 158697, 158709, 158722 and 158734 — *after* it. Ninja only stopped at
163599, and only because of the webview edge. The kernel edge that emitted the message finished:

```
out/.ninja_log:  51291436  51804226  ...  out/target/product/gts4lvwifi/obj/KERNEL_OBJ/arch/arm64/boot/Image.gz-dtb
```

so `Image.gz-dtb`, `modules`, `modules_install`, `depmod` and the vendor module copy all completed
(`out/target/product/gts4lvwifi/vendor/lib/modules/*.ko`, mtime 14:43, after `Image.gz-dtb` at 14:42).

**Why the message cannot fail the build.** `build/soong/ui/build/paths/config.go:64-77,79-84` makes every tool
name absent from `Configuration` a `Missing` entry: `Symlink: true, Log: true, Error: true`. The interposer
therefore exits non-zero *instead of* running the tool. The only consumer is a feature probe,
`arch/arm64/kernel/vdso32/Makefile:26-28`:

```make
cc32-ldoption = $(call try-run,\
        $(CC_ARM32) $(1) -nostdlib -x c /dev/null -o "$$TMP",$(1),$(2))
...
VDSO_LDFLAGS += $(call cc32-ldoption,-fuse-ld=bfd)
```

`try-run` swallows the failure and simply omits `-fuse-ld=bfd` from `VDSO_LDFLAGS`. The real vDSO link then
uses clang's default linker. Reproduced directly (`clang-real -v`):

```
# B) the same command WITHOUT -fuse-ld=bfd, i.e. what actually built vdso.so.raw
"~/android/lineage/prebuilts/clang/host/linux-x86/clang-r563880c/bin/ld.lld"
exit=0

# C) with out/.path first on PATH, i.e. the real build environment
"arm-linux-gnueabi-ld.bfd" is not allowed to be used. See .../Changes.md#PATH_Tools ...
clang-real: error: linker command failed with exit code 1
clang exit=1
```

So the linker that did the work is **in-tree AOSP `ld.lld`**, reached by absolute path — never
`.path_interposer`, never the host `/usr/bin/arm-linux-gnueabi-ld.bfd`.

**Why there is nothing for the device tree to fix here.** `arm-linux-gnueabi-ld.bfd` does not exist anywhere
in the tree, so there is no in-tree linker for that name to find:

```
$ ls prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/ | grep -E 'ld|gnueabi'
arm-linux-androideabi-ld          arm-linux-androidkernel-ld
arm-linux-androideabi-ld.bfd      arm-linux-androidkernel-ld     <- no .bfd variant, no gnueabi names
arm-linux-androideabi-ld.gold
```

The name is fixed by the kernel at `kernel/samsung/sdm670/arch/arm64/Makefile:69`:

```make
export CLANG_TARGET_ARM32 := --target=arm-linux-gnueabi
```

and `arch/arm64/Makefile:53-73` derives everything else from `CROSS_COMPILE_ARM32`, which
`vendor/lineage/config/BoardConfigKernel.mk:207-208` hardcodes from `KERNEL_TOOLCHAIN_arm` +
`KERNEL_TOOLCHAIN_PREFIX_arm` (both unconditional `:=` at lines 156-157). No device-tree variable reaches any
of them, and `TARGET_KERNEL_ADDITIONAL_FLAGS` lands on the make command line *before* `CROSS_COMPILE_ARM32`,
which therefore always wins.

The four shapes that *would* silence it, and why each is wrong here:

| option | verdict |
|---|---|
| override `CLANG_TARGET_ARM32=--target=arm-linux-androideabi` in `BoardConfigCommon.mk` so clang finds the in-tree `arm-linux-androideabi-ld.bfd` | **technically works, deliberately not done.** It changes the 32-bit ABI triple of a vDSO that is *already building correctly* and already has non-zero sigreturn offsets. Trading a working vDSO for a shorter log line is the exact "move the cost, don't remove it" move this log's own review section warns about. It is also outside P6's allowed-fix list (AGENT-TASKS.md §6c). |
| point the arm32 toolchain at the host `/usr/bin/arm-linux-gnueabi-ld.bfd` | **rejected.** Makes the ROM build depend on a distro package, i.e. non-hermetic in exactly the way `config.go:113-114` exists to prevent. |
| add `arm-linux-gnueabi-ld.bfd` to `paths.Configuration` | **rejected.** Editing `build/soong` — outside the device fork, and it is the security boundary itself. |
| `CROSS_COMPAT` off / drop `vdso32` from `Kbuild` / stub the linker | **rejected.** Silently drops 32-bit support; see the table in "What a successful build does and does not prove". |

Recorded for the strong reviewer rather than silently ignored: every remaining ROM build of this tree will
print four of these lines until the tree gains an in-tree `arm-linux-gnueabi-ld.bfd` or someone changes
`CLANG_TARGET_ARM32`. It is cosmetic noise, not a defect in the port. `confidence: medium` — medium only
because I cannot rule out that some *other* 32-bit link in this kernel also silently loses a flag to the same
interposer; the vdso32 path is the only place `rom-build2.log` shows it happening.

## The five review checks, with real output

Measured on `out/target/product/gts4lvwifi/obj/KERNEL_OBJ` as produced by the `rom-build2.log` run
(15.2 h, 117,916/142,782 targets). Re-verified after the fix-2 rebuild; see "Build result" at the end.

**1. `CONFIG_COMPAT=y` still set.**

```
$ grep -n 'CONFIG_COMPAT' out/target/product/gts4lvwifi/obj/KERNEL_OBJ/.config
624:CONFIG_COMPAT=y
625:CONFIG_COMPAT_VDSO=y
```

**2. `vdso32` genuinely built, not skipped.**

```
$ ls -la out/target/product/gts4lvwifi/obj/KERNEL_OBJ/arch/arm64/kernel/vdso32/
-rw-rw-r--  8888  vdso.o          4275  .vdso.o.cmd
-rw-------  3780  vdso.so           127  .vdso.so.cmd
-rw------- 17576  vdso.so.dbg       161  .vdso.so.dbg.cmd
-rwxr-xr-x 17576  vdso.so.raw       171  .vdso.so.raw.cmd
-rw-rw-r-- 17104  vgettimeofday.o  8747  .vgettimeofday.o.cmd
-rw-rw-r--  2416  sigreturn.o      2796  .sigreturn.o.cmd

$ file .../vdso32/vdso.so.raw
ELF 32-bit LSB shared object, ARM, EABI5 version 1 (SYSV), dynamically linked, BuildID[sha1]=..., with debug_info
```

It is embedded in the arm64 image, not merely built beside it — `.rodata` of `vdso.o` begins with the 32-bit
ELF header, and Kbuild extracted real sigreturn offsets from it:

```
$ readelf -x .rodata .../vdso32/vdso.o | head -3
Hex dump of section '.rodata':
  0x00000000 7f454c46 01010100 ... .ELF............
$ cat out/target/product/gts4lvwifi/obj/KERNEL_OBJ/include/generated/vdso32-offsets.h
#define vdso_offset_compat_rt_sigreturn_arm	0x0bb0
#define vdso_offset_compat_rt_sigreturn_thumb	0x0bd0
#define vdso_offset_compat_sigreturn_arm	0x0ba0
#define vdso_offset_compat_sigreturn_thumb	0x0bc0
```

All four offsets are inside the first 4 KB page (`-Wl,-z,max-page-size=4096`), which is what makes the
trampolines reachable from the compat sigreturn page. `confidence: high`.

**3. 32-bit modules under `vendor/lib/modules/`.** **Not applicable to this device — and that is the correct
state, not damage.** The kernel has exactly two modular symbols and both are architecture-neutral TCP
congestion controls:

```
$ grep '=m$' out/target/product/gts4lvwifi/obj/KERNEL_OBJ/.config
CONFIG_TCP_CONG_WESTWOOD=m
CONFIG_TCP_CONG_HTCP=m
$ file out/target/product/gts4lvwifi/vendor/lib/modules/*.ko
tcp_htcp.ko:     ELF 64-bit LSB relocatable, ARM aarch64, ... not stripped
tcp_westwood.ko: ELF 64-bit LSB relocatable, ARM aarch64, ... not stripped
$ find vendor/samsung -name '*.ko' | wc -l
0
```

Every other driver is built in, and the vendor blobs ship no kernel modules at all, so there is no 32-bit
`.ko` that this build is *supposed* to produce. The check as written cannot pass and its absence is not
caused by any fix. `confidence: high` — three independent measurements agree.

**4. Nothing disabled, stubbed or allowlisted.**

```
$ for r in build/soong build/make vendor/lineage/build kernel/samsung/sdm670; do
    printf '%-24s %s\n' "$r" "$(git -C $r status --porcelain | wc -l)"; done
build/soong             0
build/make              0
vendor/lineage/build    0
kernel/samsung/sdm670   0

$ git -C device/samsung/gts4lv-common diff --stat e3ccc923bcf2..HEAD
 gts4lv.mk | 4 ----
 1 file changed, 4 deletions(-)
```

Four read-only repos untouched; the only device-tree change in the whole port is fix 1. `CONFIG_COMPAT=y` and
`CONFIG_COMPAT_VDSO=y` are intact (check 1), `arch/arm64/kernel/vdso32/Kbuild` is unmodified, and
`paths.Configuration` was not edited. `confidence: high`.

**5. The linker used is the real system one, not `.path_interposer`.** The vDSO link was done by AOSP's in-tree
`ld.lld`, by absolute path; the interposer was never the linker. Reproduced above (probe B), and the recorded
command line shows no `-fuse-ld=bfd`, i.e. no attempt to reach the rejected tool at all:

```
$ cat out/target/product/gts4lvwifi/obj/KERNEL_OBJ/arch/arm64/kernel/vdso32/.vdso.so.raw.cmd
cmd_arch/arm64/kernel/vdso32/vdso.so.raw := clang --target=arm-linux-gnueabi \
  --gcc-toolchain=~/android/lineage/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9 \
  --prefix=~/android/lineage/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/ ... \
  -Wl,--hash-style=sysv -Wl,--build-id -Wl,-T arch/arm64/kernel/vdso32/vdso.lds ... -o .../vdso.so.raw
```

Two honest qualifications, stated rather than buried:

- The prompt's suggestion — "make Kbuild's arm32 toolchain prefer the system linker" — is **not** what I did.
  The system linker exists (`/usr/bin/arm-linux-gnueabi-ld.bfd`, GNU ld 2.44) but the build never needed it and
  depending on it would make the ROM non-hermetic. The build reached a real in-tree linker on its own.
- "prefer the system linker" also cannot be done from the device tree; see the rejected-options table above.
  `confidence: high`.

## Host note added by this session

`git-lfs` was missing at `repo sync` time (see fix 2). **Anyone who re-syncs this tree must install `git-lfs`
*before* `repo sync`, then check `repo status` / spot-check an LFS path with `file`.** Otherwise the WebView
build fails at 82% after ~15 hours. The same trap applies to `repo sync --force-sync` after this log.

## Fix 3 — NOT MADE. `libwfdservice` is escalated: every available fix is destructive

**The error, from `~/work/rom-enum.log:183-192` — and it is the only one left.**

```
FAILED: out/soong/.intermediates/vendor/samsung/gts4lv-common/libwfdservice/android_arm_armv8-a_shared/libwfdservice.so.check_elf_file
vendor/samsung/gts4lv-common/proprietary/system_ext/lib/libwfdservice.so: error: Unresolved symbol:
  _ZN7android11AudioSystem24setDeviceConnectionStateE24audio_policy_dev_state_tRKNS_5media5audio6common9AudioPortE14audio_format_t
```

**Root cause: AOSP changed a C++ signature; the 2019-era blob calls the old one.** Not CFI, not a missing
dependency, not a packaging mistake. Commit `709977845deb` in `frameworks/av` ("audio policy: optimize Bluetooth
device switch", 2025-01-16, in `lineage-23.2`) appended a fourth parameter `bool deviceSwitch` to
`AudioSystem::setDeviceConnectionState`:

```
frameworks/av/media/libaudioclient/include/media/AudioSystem.h:299-302
    static status_t setDeviceConnectionState(audio_policy_dev_state_t state,
                                             const android::media::audio::common::AudioPort& port,
                                             audio_format_t encodedFormat,
                                             bool deviceSwitch);      <- new
```

The trailing `b` in the mangled name **is** that `bool`. Proof from the shipped image, not from intermediates:

```
$ readelf -W --dyn-syms img-libaudioclient.so | grep -c 'setDeviceConnectionStateE...E14audio_format_t$'      # 3-arg
0
$ readelf -W --dyn-syms img-libaudioclient.so | grep -c 'setDeviceConnectionStateE...E14audio_format_tb$'     # 4-arg
1
```

I first suspected CFI mangling and tested it directly — a C++ method mangles identically with and without
`-fsanitize=cfi` (`_ZN1A1C1fEiRKNS_1PEi` both ways), so CFI is ruled out. `confidence: high`.

**Scope: exactly one blob, exactly one symbol, 32-bit only.**

```
$ find vendor/samsung/gts4lv-common/proprietary -name '*.so' -print0 | xargs -0 -P8 -I{} \
    sh -c "readelf -W --dyn-syms '$1' | grep -q 'UND _ZN7android11AudioSystem24setDeviceConnectionStateE..._t\$' && echo \"\$1\""
vendor/samsung/gts4lv-common/proprietary/system_ext/lib/libwfdservice.so      <- the only hit
```

There is no 64-bit `libwfdservice.so` (`system_ext/lib64/` has none), which is why only the `[arm]` edge failed
and every other WFD prebuilt — 33 of them, all listed in `rom-enum.log` — passed `check elf file`.

**Why I am not fixing it.** Every option costs something the reviewer, not me, should decide:

| option | why not |
|---|---|
| `allow_undefined_symbols: true` on the module | The check exists to catch exactly this. The blob has `FLAGS BIND_NOW`, so the dynamic linker resolves it eagerly at `dlopen` and **`wfdservice` would fail to start at boot**. This trades a build error for a runtime crash. |
| drop `libwfdservice` from `PRODUCT_PACKAGES` | Silently removes WFD (Miracast sink) — a real feature loss, and it still leaves `bin/wfdservice` (which `NEEDED`s it) broken. |
| rebuild the blob | Impossible; no source. |
| drop the whole WFD sink stack | Large feature removal decided by a helper agent. Not mine to make. |
| edit `vendor/samsung/gts4lv-common/Android.bp` | **Forbidden** — AGENT-TASKS §6c P6: "editing any repo other than our device fork". That file is also where the `shared_libs` list lives, so it is the only place a real fix could go. |

**The fix a strong model should make, and where.** LineageOS already solved this exact symbol for other
devices: `hardware/lineage/compat/libwfdservice/libwfdservice_shim.cpp` (commit `8a4285c0377`, "libwfdservice:
Update for 16", which cites `709977845deb` as its Ref) is a shim whose whole purpose is to re-provide the old
WFD entry points on 16. But it only exports `WiFiDisplaySession::broadcastWifiDisplayAudioIntent`, **not** the
3-argument `setDeviceConnectionState` this blob wants, and it is not in this blob's `shared_libs`
(`vendor/samsung/gts4lv-common/Android.bp:12761-12782`, zero `shim` entries). So the honest options are: extend
that shim (a `hardware/lineage/compat` change, outside my write scope), or drop WFD. Both are owner calls.

**Note for whoever picks this up:** the check is a *validation* edge, not a link step
(`build/soong/cc/linker.go:714-761`, `--allow-undefined-symbols` at :733). That is why
`mka bacon -k 0` still produced a zip: the prebuilt is copied and installed regardless. Confirmed by extracting
it back out of `system.img`:

```
$ debugfs -R "dump /system_ext/lib/libwfdservice.so ..." system-raw.img
$ sha256sum <extracted> vendor/.../libwfdservice.so
dc04cf2353957298ae718e45a0743c9538b046459295085c95563a8d732eafc6  extracted
dc04cf2353957298ae718e45a0743c9538b046459295085c95563a8d732eafc6  blob     <- byte-identical
```

So **the zip is real but the ROM has a latent boot-time fault**: `wfdservice` (32-bit) will fail to load. It is
started only by `on property:vendor.wfdservice=enable`
(`vendor/samsung/gts4lv-common/proprietary/system_ext/etc/init/wfdservice.rc:15-22`), and nothing in this tree
sets that property — so the service stays `disabled` and the fault may never trigger. **It is a latent fault,
not a certain boot failure, and it is not something to discover for the first time by flashing.** `confidence:
high` on the diagnosis, `medium` on the runtime consequence (I cannot test it without a tablet).

## Enumerating the remaining errors in one pass

The 23.2 build stops at the *first* `FAILED` edge, which costs ~1.5 h per error discovered. `mka bacon -k 0`
tells ninja to continue, so one run lists everything still broken:

```bash
source build/envsetup.sh && breakfast gts4lvwifi && mka bacon -k 0
```

Result on `~/work/rom-enum.log`: **5,099 targets, exactly one `FAILED:`** (line 183, the WFD blob above). So
after fix 2 the build had exactly one real error left, not an unknown number. Recommend every later P6 run use
`-k 0`. `confidence: high`.

## Escalated

**One item: `libwfdservice` / `check_elf_file`** — see "Fix 3" above for the full diagnosis, the five options and
why each is wrong. It needs either a `hardware/lineage/compat` change or a decision to drop WFD; neither is in
P6's write scope and neither is a helper agent's call.

Fix 2 needed no repository change, so there is nothing else for a strong model to review in code. The other
judgement call worth a reviewer's eye is the decision **not** to silence the `arm-linux-gnueabi-ld.bfd` message;
reasoning and rejected alternatives are in their own section, and the reviewer may disagree — that disagreement
would cost one line in `BoardConfigCommon.mk`, not a rebuild.

## Build result

A zip exists, **but the build did not pass** and the ROM has the latent WFD fault above. Reported plainly so
nobody mistakes this for a finished ROM.

```
path   ~/android/lineage/out/target/product/gts4lvwifi/lineage-23.2-20261005-UNOFFICIAL-gts4lvwifi.zip
size   1133973020 bytes  (1.06 GiB)
sha256 cc2c82e796e7fa3678bf8169f8c6ba7ffdedfe2e79e3e0b697b55790927a39ea
```

It came from `mka bacon -k 0` (`~/work/rom-enum.log`), not from a clean `brunch`: ninja continued past the
`check_elf_file` failure and packaged anyway, then exited 1 (`rom-enum.log`, `ninja failed with: exit status 1`,
18:50:40). Contents are complete — `boot.img`, `dtbo.img`, `recovery.img`, `vbmeta.img`, both `.dat.br` payloads,
both transfer lists, `update-binary`, `otacert` — and `libwfdservice.so` is genuinely inside `system.img`,
byte-identical to the blob. **Flashing it should work; WFD sink will not.** Whether to flash before the WFD
decision is the owner's call, not mine.

The five review checks were re-run against this build and all still hold — see "The five review checks" above;
nothing in the port changed between the `rom-build2` run and this one.

## Process note

The P6 agent that made fix 1 ended its session without writing this log, so the lead recorded it from the commit
itself and the build log. The commit and its message were left exactly as the agent wrote them.