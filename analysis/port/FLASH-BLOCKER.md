<!-- task: FLASH -->
> ## Reviewer ruling 6 (2026-10-06): the bootloader is almost certainly fine. Our kernel starts and dies. **Get its log next.**
>
> **New measurements** (reviewer's own builds, same toolchain, `gts4lvwifi_defconfig`):
>
> | | base `a30605a54f3b` (22.2 kernel) | ours `cfe0b6979` (no BTF) |
> |---|---|---|
> | `Image.gz-dtb` | 15,588,530 (official 22.2: 15,564,314) | 16,050,450 |
> | `Image` | 39,059,480 | 40,237,080 |
> | arm64 header `text_offset` / `image_size` / `flags` | 0x80000 / 47,308,800 / 0xa | 0x80000 / 48,508,928 / 0xa |
> | appended DTBs, sha256 | `120b38c3…0f92` | **`120b38c3…0f92`, byte-identical** |
>
> The port changes nothing under `arch/arm64/boot`, `scripts/dtc`, `head.S`, `vmlinux.lds.S` or `asm/memory.h`.
> So **what the bootloader parses is practically identical to the image that boots**: the same DTBs, the same header
> flags, and a 2.5% size difference. A bootloader-stage reject is unlikely. **Most likely our kernel starts, then dies early.**
> `confidence: medium-high`.
>
> **Prime suspects, by size of the early-boot change** (`git diff --stat a30605a54f3b 801f3f20e54a`):
> - `kernel/sched/core.c` **+1,035 lines**: the uclamp series and the hand-merged EAS/WALT conflicts. `sched_init` runs before the console.
> - `security/security.c` **−453/+**: "Refactor declaration of LSM hooks" + "Add BPF LSM program support"
>   (`fc1f07443`, `f71bbcac7`) rewrite LSM init on a Samsung tree.
> - Config-gated: `BPF_LSM`, `KPROBES`/`UPROBES`, `UCLAMP_TASK`, `USERFAULTFD`, `TASKS_RCU`, `BPF_JIT`.
>   The full added list: `CGROUP_SCHED`, `BPF_*`, `KPROBES`, `UCLAMP_*`, `USERFAULTFD`, `XDP_SOCKETS`, `FUSE_BPF`,
>   `ANDROID_BINDERFS`, `UNICODE`, `NET_SOCK_MSG`, `PELT_UTIL_HALFLIFE_32`. Removed: `SCHED_TUNE`, `RT_GROUP_SCHED`.
>
> **Corrections to rulings 4–5:**
> - "The whole port is the 20 commits `d73f07cf8b5c..801f3f20e54a`" is **wrong**. Those are only P3+P4. The port is
>   **2,458 commits** `a30605a54f3b..801f3f20e54a`. A blind `git bisect` would need about 12 builds.
> - **Don't test on `BOOT`.** Use `RECOVERY`: the test kernel goes there, and `BOOT` keeps 22.2, so the tablet always
>   boots normally afterwards and you can read the crash log from 22.2. No restore step is needed between tests.
>
> ### Step A: read the crash log (no build, ~15 min). Do this first.
> Samsung's `sec_log` (`CONFIG_SEC_LOG_LAST_KMSG=y`, `drivers/samsung/debug/sec_log_buf.c`) records printk from the
> first line. It shows the **previous** boot as `/proc/last_kmsg` (mode 0444). `pstore` ramoops (`0xA1300000`) is a second copy.
> 1. 22.2: *Developer options → Rooted debugging* on.
> 2. `adb -d reboot download`, then `samloader flash --partition RECOVERY ~/work/recovery-nobtf.img --no-reboot`
>    (check its header first: kernel 16,011,654).
> 3. **Unplug USB.** Hold *Vol Down + Power* until black, then *Vol Up + Power*. It falls into Download mode.
>    **Photograph the whole Download-mode screen**, including the small text.
> 4. USB still unplugged: hold *Vol Down + Power* until black and release. **22.2 boots** (`BOOT` is untouched).
> 5. Collect:
>    ```bash
>    adb root
>    adb shell cat /proc/last_kmsg > last_kmsg-1.txt
>    adb shell 'for f in /sys/fs/pstore/*; do echo "== $f"; cat $f; done' > pstore-1.txt
>    adb shell 'ls /proc | grep -i -e reset -e summary -e last'  > procs.txt
>    adb shell cat /proc/cmdline > cmdline.txt
>    grep -n "Linux version" last_kmsg-1.txt pstore-1.txt
>    ```
>    Commit them to `analysis/port/flash-logs/` (P7's job).
> 6. **Read it:**
>    - `Linux version 4.9.337-gcfe0b6979655` appears → **our kernel ran**. The last 50 lines show where it died.
>    - It reaches `Run /init` / `init: ...` and then dies → kernel OK; it is Android 16 userspace on this kernel (different fix).
>    - Only the previous 22.2 boot is there → either our kernel never started, or Download mode cleared the
>      buffer. Go to Step B.
>
> ### Step B (only if A shows nothing): config isolation, one build
> Kernel branch **`test/base-config`** @ `b3a9e9a99369`: the ported code with the **22.2 defconfigs**, every P3 option off except `KPROBES` (needed to build) and `CGROUP_SCHED` (needed by Android 16 init).
> The reviewer built it here: `Image.gz-dtb` 15,939,579 bytes, 0 errors. Build `mka recoveryimage` on it, flash to `RECOVERY`, repeat Step A.
> - **Boots** (or at least logs further) → the fault is in a config-gated feature. Re-enable options in halves.
> - **Same failure** → the fault is in always-on ported code (sched/core.c, security.c and others). Build the
>   base-kernel control (ruling 5 step 1, but on `RECOVERY`), then bisect.
>
> Rulings 1–5 below are kept as history. Their measurements stand; ruling 6 supersedes their next steps.

> ## Reviewer ruling 5 (2026-10-06): the recovery container is EXONERATED. Only the kernel is left.
> ### Read this first. It settles ruling 3's hypotheses 2, 3 and 4 with real measurements.
>
> Both remaining **risk-free** checks from ruling 3 have now been run. Neither required flashing anything.
>
> ### 1. AVB is NOT the cause — hypothesis 4 REFUTED
>
> Ruling 3 ranked AVB against AOSP's published test key as a live suspect and marked it untested, because the
> lead's hand-rolled AVB parse returned garbage. It has now been parsed with the real tool,
> `out/host/linux-x86/bin/avbtool info_image`:
>
> | image | result | public key (sha1) | algorithm | rollback idx | flags |
> |---|---|---|---|---|---|
> | ours, with BTF (FAILS) | 23.2 | `2597c218aae470a130f61162feaae70afd97f011` | SHA256_RSA4096 | 1 | 0 |
> | ours, no BTF (FAILS) | 23.2 | `2597c218aae470a130f61162feaae70afd97f011` | SHA256_RSA4096 | 1 | 0 |
> | **LineageOS 22.2 (BOOTS)** | 22.2 | **`2597c218aae470a130f61162feaae70afd97f011`** | **SHA256_RSA4096** | **1** | **0** |
>
> **The recovery that boots is signed with exactly the key we sign with.** Same key, same algorithm, same rollback
> index, same flags, same 67,108,864-byte image size. `Flags: 0` means the vbmeta does not demand verification.
> **Signing cannot be why ours fails. `confidence: verified, not inferred.**`
>
> ### 2. The fstab is NOT wrong — hypothesis 3 REFUTED
>
> Ruling 3 flagged `TARGET_RECOVERY_FSTAB := $(COMMON_PATH)/init/fstab.qcom` as "a Qualcomm path in a Samsung tree,
> simply wrong and nobody checks". **The name is a misnomer; the file it produces is correct.** Unpacked both
> ramdisks and diffed the fstab that actually ships:
>
> ```
> diff 22.2/x/system/etc/recovery.fstab  23.2/x/system/etc/recovery.fstab   ->  IDENTICAL
> ```
>
> It is byte-identical to the known-good one, and it is a proper Samsung fstab (`/dev/block/bootdevice/by-name/...`,
> `sec_efs`, `apnhlos`, `zram0`). The `# VOLD :: fstab_non_AB_variant.qcom` line is a **comment** on the original
> donor board, not a Qualcomm path being used. **`confidence: verified.`**
>
> ### 3. The recovery ramdisk is not the problem either — hypothesis 2 heavily weakened
>
> ```
> 22.2 recovery ramdisk: 321 files      ours: 321 files
> only in 22.2: res/Android.bp
> only in ours: system/bin/disable-overlays
> ```
>
> A two-line difference in a 321-file list, neither entry boot-critical. Structurally the two ramdisks are the
> same build product. This does not prove every byte is correct, but it removes "the ramdisk is wrong" as a
> leading explanation.
>
> ### What is left
>
> Every property of the **container** now matches the image that boots:
>
> | property | ours | 22.2 (boots) | verdict |
> |---|---|---|---|
> | flash tool, partition, procedure | samloader `RECOVERY` | samloader `RECOVERY` | identical (control test) |
> | image size | 67,108,864 | 67,108,864 | identical |
> | AVB key / algorithm / rollback / flags | sha1 `2597c218...`, SHA256_RSA4096, 1, 0 | **the same** | **identical** |
> | ramdisk file count | 321 | 321 | effectively identical |
> | `recovery.fstab` | Samsung `by-name` layout | **the same** | **byte-identical** |
> | **kernel bytes** | **ours (ported)** | **theirs (unported)** | **THE ONLY REAL DIFFERENCE** |
> | kernel size | 16,011,654 / 18,684,229 | 15,564,314 | disproven twice as the cause |
>
> **So the search collapses onto the kernel.** That is now the only hypothesis standing, and ruling 4's
> `confidence: medium-high` for "our ported kernel does not boot" is the working conclusion of this document.
>
> ### What this means for the bisect
>
> Do **not** spend time on AVB, fstab or ramdisk forensics. They are measured and equal. Go straight to
> **NEXT STEPS step 1**: build a `boot.img` from the unported base kernel `a30605a54f3b` and flash it. If the
> base kernel boots, the fault is inside the 20-commit port and step 2 bisects it. If the base kernel also
> silently falls back, the fault is in the Android 16 boot-image build path for this device rather than in the
> ported kernel code.
>
> ### Incidental correction to earlier notes
>
> The 22.2 control images are **not** at `~/Downloads/recovery.img` any more. They were extracted to
> **`~/Downloads/lineageos_22p2/`**, which holds both `recovery.img` and `boot.img` with the 15,564,314 kernel.
> Nothing was lost. Older notes and any command still saying `~/Downloads/recovery.img` are stale and will fail
> with `No such file or directory`.

> ## Reviewer ruling 4 (2026-10-06): the BOOT test also failed — and the test was mislabelled.
> ### Read this before rulings 2 and 3. It supersedes both on the central question.
>
> A `boot` image containing our kernel was flashed to the `BOOT` partition. Result: **the same silent fallback
> into Download mode.** No RAMDUMP, no panic, no console.
>
> **This is the answer to the question ruling 3 called highest-value: the failure is not recovery-specific.**
> Two partitions, two kernel variants, one symptom. The common factor is the kernel.
>
> ### CORRECTION — `boot-nobtf.img` is not a no-BTF image. The name is false.
>
> Verified by reading each image's boot header (`kernel_size`, header offset 8):
>
> | file | flashed to | kernel bytes | actually | result |
> |---|---|---|---|---|
> | `~/work/boot-nobtf.img` | `BOOT` | 18,684,229 | **WITH BTF** | failed -> Download mode |
> | `~/work/recovery-nobtf.img` | `RECOVERY` | 16,011,654 | no BTF | failed -> Download mode |
> | `~/work/recovery.img` (from our zip) | `RECOVERY` | 18,684,229 | WITH BTF | failed -> Download mode |
> | `~/Downloads/recovery.img` (LineageOS 22.2) | `RECOVERY` | 15,564,314 | n/a | **boots** |
>
> **Cause:** `mka recoveryimage` does **not** rebuild `boot.img`. After the no-BTF checkout,
> `out/target/product/gts4lvwifi/boot.img` still held the stale **with-BTF** 18,684,229 kernel (confirmed still true
> on disk), and whatever produced `boot-nobtf.img` copied that file.
>
> **Consequences, both of which a reviewer must not get wrong:**
>
> 1. **The no-BTF-on-`BOOT` test has not been performed.** It is low-value — the no-BTF *recovery* already failed
>    carrying the same 16,011,654 kernel — but it is untested, and it must not be reported as tested.
> 2. **The kernel sha256 of the two failed images differ** (`48de111b384eb3ac` vs `fa5292e82e866986`), so they are
>    genuinely two different kernels. They are not one image mislabelled twice.
>
> **What the test does still prove:** the with-BTF kernel fails on `BOOT`, and the no-BTF kernel fails on
> `RECOVERY`. **Both kernel variants fail, so BTF is not required for the failure.** Ruling 2's mechanism stays dead,
> for a second and independent reason.
>
> ### The conclusion, and its confidence
>
> **Our ported kernel does not boot. `confidence: medium-high`** — up from `medium` in ruling 3.
>
> Evidence: two independent partitions (`BOOT`, `RECOVERY`), two kernel builds, one symptom, and a control image
> (22.2's recovery) that boots with an identical samloader command. **Nothing has ever booted this kernel.** That is
> the claim P1-P4 exist to establish and it is now the open question, not a background assumption.
>
> Ruling 3's hypotheses 2-6 (recovery ramdisk, the Qualcomm fstab path, AVB against AOSP's test key,
> `librecovery_updater_samsung`, a recovery-only regression) are all now **downstream** of this. They stay on the
> list only as explanations for a residual failure *after* the kernel is fixed.
>
> ### Device state: the tablet is currently unbootable
>
> `BOOT` holds a non-booting image. `RECOVERY` still holds 22.2's, which boots, but 22.2's recovery cannot install
> a 23.2 zip (`MADV_WIPEONFORK` -> SIGABRT, closed above). **Restore `BOOT` before any further testing** —
> commands in "NEXT STEPS" below, step 0.
>
> ### Branch-state corrections. Verified 2026-10-06 with `git ls-remote`, and the old docs are misleading.
>
> **There is no `origin/port/pick`.** Anyone following older notes and checking out `port/pick` gets the wrong tree.
>
> | ref | commit | what it is |
> |---|---|---|
> | `origin/lineage-23.2` | `801f3f20e54a` | **the ported kernel the ROM was built from** (P4 tip) |
> | `origin/lineage-22.2` | `a30605a54f3b` | untouched pre-port tree, untouched by us |
> | `origin/port/no-btf` | `cfe0b6979655` | `801f3f20e54a` + BTF drop; what the no-BTF recovery was built from |
> | local `port/pick` | `d73f07cf8b5c` | **stale**, 20 commits behind (the whole P3+P4 set) and **no BTF** |
>
> `origin/lineage-23.2` is what RUNBOOK step 7 fast-forwards, so the port living there is expected, not a deviation.
> The stale local `port/pick` is a P2-era tip; do not build from it.
>
> **Where BTF came from, exactly:** `316352012ff2` ("P3: merge the gts4lv-23.2 defconfig fragment into all four
> defconfigs"), which set `CONFIG_DEBUG_INFO_BTF=y` in all four `gts4lv*` defconfigs. `port/no-btf` reverts exactly
> that. It is the first of the 20 commits between the stale `port/pick` and `801f3f20e54a`.
>
> ## Reviewer ruling 3 (2026-10-06): the BTF test FAILED. Read this before ruling 2.
>
> **Ruling 2's fix did not work.** `port/no-btf` @ `cfe0b6979655` was checked out, `mka recoveryimage` built
> cleanly (1:20:41, 0 errors), and the recovery kernel shrank as predicted:
>
> | | with BTF | without BTF | 22.2 (boots) |
> |---|---|---|---|
> | recovery kernel | 18,684,229 | **16,011,654** | 15,564,314 |
> | gap to 22.2 | +3,119,915 | **+447,340** | — |
>
> `CONFIG_DEBUG_INFO_BTF is not set` confirmed. **It still boots straight back into Download mode.**
> **Kernel size is therefore not the cause.** Ruling 2's BTF mechanism is disproven.
>
> ### The finding that reframes the problem
>
> **`boot.img` and `recovery.img` contain the same kernel image.**
>
> ```
> boot.img      kernel 18,684,229   ramdisk  1,494,329
> recovery.img  kernel 18,684,229   ramdisk 14,283,661   <- same kernel, bigger ramdisk
> ```
>
> So this stopped being a recovery-packaging question. Whatever stops the recovery from booting is a property of
> **our kernel**, and it will equally stop `boot.img`. **Nothing has ever flashed and booted this kernel** — that is
> the claim P1-P4 exist to establish, and it is still untested.
>
> ### Hypotheses, ranked. All are guesses except where marked verified.
>
> **1. Our kernel does not boot at all; the recovery is just where it shows first.** `confidence: medium`.
> The shared-kernel fact above is verified; the inference is not. Every symptom fits a kernel that never reaches
> its console: silent fallback to Download mode, no RAMDUMP, no `printk` output anywhere in the logs.
> **This is now the highest-value thing to test** and it is testable without touching recovery at all — see below.
>
> **2. Something the recovery ramdisk provides is missing or wrong, so it dies before the console.** `confidence: low`.
> The Android 16 recovery ramdisk is +1.8% over 22.2's. A ramdisk failure this early could be quiet. Faint support:
> `recovery_intermediates/` never contained an image, so exactly what ends up in the recovery ramdisk is not
> established. Faint counter: ramdisk failures usually still produce a panic or an init message.
>
> **3. `TARGET_RECOVERY_FSTAB := $(COMMON_PATH)/init/fstab.qcom` is a Qualcomm path in a Samsung tree.**
> `confidence: low`. Verified as written. If the recovery cannot mount what it needs it may die before the console.
> Untested. Listed because it is the kind of thing that is simply wrong and nobody checks.
>
> **4. AVB or signature enforcement on the recovery partition.** `confidence: low`.
> `BoardConfigCommon.mk:59-61` declares `BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096` and
> `BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem` — AOSP's **published test key**. If the
> bootloader enforces AVB on `recovery`, a test-key-signed image would be rejected at the bootloader stage, which is
> exactly the observed "straight to Download mode, no kernel execution". **I could not verify this**: see the
> retraction below. A reviewer with a working AVB parser should compare the footers of our `recovery.img` and the
> known-good 22.2 one. `avbtool info_image --image <file>` is the tool.
>
> **5. `librecovery_updater_samsung` — a 2020 vendor library in a 2026 recovery.** `confidence: low`. Verified as
> configured (`BoardConfigCommon.mk:142`). Unlikely to block *boot* rather than package installation, but it is a
> vendor component in an otherwise-AOSP recovery and it has no business being there.
>
> **6. The port changed something the recovery specifically cannot tolerate.** `confidence: low`. The recovery and
> boot kernels are the same build, so this collapses into hypothesis 1 unless it is recovery-only.
>
> ### The test I would run first
>
> **Flash `boot.img` and try to boot.** It tests the kernel directly, sidesteps recovery entirely, and answers the
> question everything else depends on:
>
> ```bash
> cd ~/android/lineage/out/target/product/gts4lvwifi   # boot.img still has the WITH-BTF kernel
> adb -d reboot download
> ~/bin/samloader flash --partition BOOT boot.img --no-reboot
> ```
>
> Then power on and watch: **boots to Android** → the kernel is fine, hypotheses 2-5 stand. **Panic, RAMDUMP, or a
> hang** → **the kernel does not boot**, and that is a far more important finding than the recovery ever was.
>
> ⚠️ **Risk:** the device will not boot until `BOOT` is replaced. The 22.2 `recovery.img` stays installed and can
> restore a working `boot.img`, so this is recoverable — but have the 22.2 `boot.img` to hand before starting.
> Getting a boot failure back needs only Download Mode plus samloader, which are proven working.
>
> **Cheaper and safer first:** `avbtool info_image --image` on both recovery images, and a diff of the two
> ramdisks' file lists. Neither risks anything.
>
> ### Fourth retracted forensic attempt — the lead's AVB parse
>
> The lead searched for the AVB footer magic and reported a parse yielding
> `version 16777216.0`, `vbmeta at 0x60e20100000000`, `vbmeta magic b''`. Those are garbage: the `AVBf` hit 64 bytes
> before EOF is a **byte coincidence, not a real footer**. **No claim about AVB is made**, and hypothesis 4 is
> untested. That is four wrong attempts at inspecting these images — wrong extraction offset, wrong arm64 magic
> constant, a string search that could not work, and now a bad AVB struct parse. Stop parsing them by hand and use
> `avbtool` / `unpack_bootimg`.


<!-- task: FLASH -->
# Flashing blocker: the 23.2 recovery is not taking

> ## Reviewer ruling 2 (2026-10-06): two causes, one fix to test. Read this first.
>
> **1. The 22.2 recovery can never install a 23.2 zip. That route is closed for good.** Android 16's bionic made the
> `MADV_WIPEONFORK` failure fatal: `libc/upstream-openbsd/android/include/arc4random.h:63-64` @ LineageOS
> `android_bionic` `lineage-23.2` reads `if (madvise(p, size, MADV_WIPEONFORK) == -1) async_safe_fatal(...)`.
> The 22.2 file has no `MADV_WIPEONFORK` at all. The zip's Android 16 `update-binary` runs on the 22.2 recovery's
> base 4.9 kernel, which lacks `MADV_WIPEONFORK`, so `async_safe_fatal` → `abort()` → **signal 6**. That explains the
> twice-printed message (stderr + the `libc` log tag), and why official 22.2 zips are fine. Our ported kernel has it
> (`mm/madvise.c:95`). `confidence: high`. So the 23.2 recovery **must** boot. (The `ENOENT` text is just a stale `%m`.)
>
> **2. Why the 23.2 recovery doesn't boot: most likely the kernel is too big for the bootloader.**
> `CONFIG_DEBUG_INFO_BTF=y` (added in P3 `316352012`, copied from the S9 defconfig) puts an **8.5 MB `.BTF`
> section** inside the kernel image. Measured on the reviewer's build of `801f3f20e54a` (`gts4lvwifi_defconfig`):
>
> | | with BTF (current) | without BTF |
> |---|---|---|
> | `Image` | 48,756,760 | 40,237,080 |
> | arm64 header `image_size` (incl. BSS) | 57,028,608 | 48,508,928 |
> | `Image.gz-dtb` | 18,731,172 | 16,050,450 |
>
> The 22.2 recovery's kernel is 15,564,314 bytes, so dropping BTF removes almost the whole size difference. The failure
> mode fits too: a bootloader-stage reject (straight back to Download mode, no RAMDUMP) rather than a kernel crash.
> Samsung's exact size limit isn't public, so this is a strong lead, not proof. `confidence: medium`.
> Other differences between the two recovery images: the Android 16 ramdisk (+1.8%) and the kernel's contents.
> Both would be next if this test fails.
>
> **Test (owner, about 1 h):** kernel branch `port/no-btf` @ `cfe0b6979` (4 defconfigs, BTF lines removed).
> ```bash
> cd ~/android/lineage
> git -C kernel/samsung/sdm670 fetch anton port/no-btf && git -C kernel/samsung/sdm670 checkout FETCH_HEAD
> source build/envsetup.sh && breakfast gts4lvwifi && mka recoveryimage
> # then flash out/target/product/gts4lvwifi/recovery.img with samloader exactly as before
> ```
> - **Recovery boots** → cause confirmed. Then run `mka bacon -k 0` (`-k 0` because of the known `libwfdservice` check,
>   see review-P6.md), sideload from the new recovery, and fast-forward `lineage-23.2` to `port/no-btf`.
>   Watch whether bpfloader/netd need `/sys/kernel/btf/vmlinux`. If they do, keep BTF and shrink the kernel elsewhere.
> - **Still Download mode** → read the small text and any red text on the Download-mode screen. Next suspects:
>   the 23.2 ramdisk/AVB footer, then the base-kernel bisect below.
>
> To get back to a working tablet meanwhile: flash the 22.2 `recovery.img` (proven to boot).
>
> Ruling 1 (the button sequence, "use the 22.2 recovery") is **withdrawn** by the control test and point 1 above.

Written 2026-10-06 by the lead, for a strong-model review. **Nothing here has been guessed at — every item is a
command that was run and its observed result.** Where I am inferring, it says so and gives the test that would settle
it.

This is a *deployment* problem, not a port problem. The port is complete and verified; see
[STATUS.md](STATUS.md) and [review-P6.md](review-P6.md).

## The situation

| | |
|---|---|
| Device | Samsung Galaxy Tab S5e **Wi-Fi**, SM-T720, codename **`gts4lvwifi`** |
| Currently running | LineageOS **22.2** + MindTheGapps |
| Target | this project's 23.2 build |
| ROM zip | `lineage-23.2-20261005-UNOFFICIAL-gts4lvwifi.zip`, 1,133,973,020 bytes, sha256 `cc2c82e796e7fa3678bf8169f8c6ba7ffdedfe2e79e3e0b697b55790927a39ea` |

## What is already settled — do not re-investigate these

**Step 7 (fast-forward) is done.** Both forks' `lineage-23.2` point at the port.

**`vbmeta` does not need flashing on this path.** The official guide flashes
`samloader flash --partition VBMETA vbmeta.img` at step 7 of the *bootloader unlock* sequence, which was already
completed when 22.2 was installed — unlocking wipes the device and is not repeated for an in-place upgrade. The
`vbmeta.img` in our zip is the same disabled/empty one. **Only required again if the bootloader is ever relocked, or
when starting from Samsung stock instead of LineageOS.**

**The recovery image is correct.** Verified directly, not assumed:

```
~/work/recovery.img   64.0 MB
sha256                fa7c34feb09d402d8f64bf3e7e446adc4fbca33f49a8ab3511770ac360690b1b
file                  Android bootimg, kernel (0x8000), ramdisk (0x2000000), page size: 4096
```

Its sha256 **matches the copy inside the zip** exactly, and `gts4lvwifi` is the correct codename for SM-T720. So the
file is neither corrupt nor mismatched.

**The zip contains `recovery.img` (64 MB)** alongside `boot.img`, `dtbo.img` and `vbmeta.img`, in `dat.br`
block-OTA form. This matters: it means the recovery flash is a *convenience*, not a hard requirement — see
"Alternative route" below.

## The failure — RESOLVED to a single variable

```bash
adb -d reboot download
samloader flash --partition RECOVERY <image> --no-reboot
```

### The control test settled it

The 22.2 recovery was flashed with the **identical** samloader command. It **boots, and the tablet auto-boots into
it without any button combination.** Therefore:

| component | verdict |
|---|---|
| `samloader`, and it reporting success | **proven good** |
| `--partition RECOVERY` being the right partition | **proven good** — no slots, single partition |
| the whole Download-mode → samloader → boot procedure | **proven good** |
| **our 23.2 `recovery.img`** | **the variable that fails** |

The earlier full samloader output confirms the write rather than merely implying it:

```
Downloading device's PIT file
RECOVERY flash successful   64.00 MiB/64.00 MiB (21.23 MiB/s)   [00:00:03]
```

`64.00 MiB` = 67,108,864 bytes = **exactly** the size of `recovery.img`, transferred in 3 s. So the image *is*
being written. It then fails to boot: the tablet falls back to Download Mode on its own after the flash, with no
RAMDUMP observed.

### Header comparison — structurally identical

Comparing our 23.2 `recovery.img` against the working 22.2 one:

| field | 22.2 (boots) | 23.2 (fails) |
|---|---|---|
| `magic` | `ANDROID!` | `ANDROID!` |
| `kernel_addr` | `0x00008000` | `0x00008000` |
| `ramdisk_addr` | `0x02000000` | `0x02000000` |
| `cmdline` | `SRPSA14B001` | `SRPSA14B001` |
| `kernel_size` | 15,564,314 | **18,684,229** (+20%) |
| `ramdisk_size` | 14,032,906 | 14,283,653 (+1.8%) |

**Every header field is identical except the two sizes.** The +3.1 MB kernel is *expected* — our recovery carries
2,458 ported commits including eBPF, BPF JIT and BTF — so size alone is probably not causal. `confidence: medium`.

⚠️ **An earlier `page_size = 0` reading in this document was a parser artifact.** The working 22.2 image reads
exactly the same. Do not treat it as a defect.

### New finding from the device tree

```
device/samsung/gts4lv-common/BoardConfigCommon.mk
  BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
  BOARD_AVB_RECOVERY_KEY_PATH       := external/avb/test/data/testkey_rsa4096.pem
  BOARD_KERNEL_OFFSET               := 0x00008000
  BOARD_KERNEL_TAGS_OFFSET          := 0x01E00000
```

The recovery is AVB-signed with **AOSP's published test key** and declares rollback index 1. The tablet's bootloader
is dated **2026-09-01**. Whether an unlocked Samsung bootloader enforces anything against that test key or a
rollback index on the recovery is **not established** and should not be guessed at. `confidence: low`.

`BOARD_KERNEL_OFFSET := 0x00008000` is the kernel's **load address**, not a file offset in the boot image.

## Lead's forensics — RETRACTED

Three attempts to compare the two kernels' *contents*, all wrong:

1. Extracted the kernel at file offset `0x8000`, which is `BOARD_KERNEL_OFFSET`, a **load address**. Read padding.
2. Used a wrong arm64 header magic constant, found nothing.
3. Reported "no strings found" from a search that **could not have worked** — and from it concluded *"the recovery
   kernel is not our ported kernel."* **That conclusion was an artifact of a broken method and is withdrawn.**

The arm64 `ARM\x64` image magic is present in neither file, so whatever the kernel payload is, it is not a plain
uncompressed arm64 `Image` at any offset tried. **Nothing about kernel contents has been established either way.**

## The bisect that would settle it

> Build a recovery from the **base `a30605a54f3b` kernel** (unported, stock 4.9) through the **same AOSP flow**,
> and flash it exactly as above.
>
> - **It boots** → the port broke the recovery kernel. Look at what the recovery's build config gained — the eBPF
>   work, BPF JIT, BTF — and what a recovery may not carry.
> - **It does not boot** → the AOSP recovery build path for this device is broken *independently of the port*, and
>   the answer lies in the device tree, not the kernel.

This is well defined and is a legitimate P4/P6-style task. **Do not run it before** answering the cheaper question
below, because it costs a kernel build.

## Cheaper question to answer first

**How did LineageOS produce a *working* 22.2 recovery for this device?** If it built one locally from the same base
kernel through the same flow, then our flow is equivalent and the kernel is the only difference. If 22.2's recovery
was a prebuilt, or came from a different path, then our recovery build differs in some way that is worth finding
before spending hours on a rebuild.

Relevant: `device/samsung/gts4lv-common/` has a `recovery/` subdirectory, and `TARGET_RECOVERY_FSTAB :=
$(COMMON_PATH)/init/fstab.qcom` uses a **Qualcomm** fstab path. Also note
`out/target/product/gts4lvwifi/obj/PACKAGING/recovery_intermediates/` contained **no image**, only a 0-byte
`ramdisk_files-timestamp` — the packaged `recovery.img` came from elsewhere in the build. Where, exactly, is not
established. `confidence: low`.

## Hypotheses, superseded

Ranked hypotheses 1-5 were written before the control test. The control test resolved the question: samloader, the
partition and the procedure are proven good, so hypotheses 1 (A/B), 3 (silent write failure), 4 (partition name) and
5 (button sequence) are all **eliminated**. What survives is a single question — *why does our 23.2 recovery image
fail to boot* — which the bisect above addresses.

## The recovery log so far — and one finding that reopens the recovery-flash route

Partial log from the failed sideload on the **22.2** recovery:

```
I:01d spl: 2026-09-01 new spl: 2026-09-01 CHECK passes
arc4random data MADV_WIPEONFORK failed: No such file or directory
libc: arc4random data MADV_WIPEONFORK failed: No such file or directory
ERROR: recovery: Error in /sideload/package.zip (killed by signal 6)
```

### `MADV_WIPEONFORK` is missing from the 22.2 kernel — verified

| tree | `MADV_WIPEONFORK` in `include/uapi/asm-generic/mman-common.h` |
|---|---|
| base `a30605a54f3b` (what 22.2 runs) | **0** definitions |
| `port/pick` @ `801f3f20e54a` (our kernel) | **2** definitions |

Introduced by two series commits, both titled *UPSTREAM: mm,fork: introduce MADV_WIPEONFORK* —
`fa5d3954b0e3` and `7b1c5c0a4417`.

So that warning is a **22.2-side mismatch**: 22.2's bionic calls `madvise(MADV_WIPEONFORK)` and 22.2's 4.9 kernel
does not implement it. It is benign on its own — bionic logs it and carries on — and it is **not evidence of a defect
in our port**. `confidence: high`.

**The useful consequence:** our 23.2 recovery boots **our** kernel, which does implement `MADV_WIPEONFORK`, so it
will not emit this warning at all. Combined with the reviewer's guidance to keep 22.2's recovery as the safety net
until a 23.2 boot is proven, this makes **getting the 23.2 recovery to boot the more promising route** rather than
debugging a SIGABRT inside a recovery whose kernel is known to be missing something the userspace wants.

### The SPL line

`spl: 2026-09-01 ... CHECK passes` is Samsung's bootloader self-check passing; it is informational and not an error.
The bootloader is dated **2026-09-01**, roughly five weeks before this ROM was built. `confidence: medium` on the
interpretation, `high` that it is not itself a failure.

### The SIGABRT — the `arc4random` lines are now the prime suspect

Confirmed with the owner: **there are no error lines between `MADV_WIPEONFORK` and `killed by signal 6`.** The two
`arc4random` lines are the last thing logged before the abort, which makes them **causally suspect rather than
incidental** — the opposite of what the lead wrote here an hour ago.

That said, two things argue against the warning being *sufficient* to cause it:

1. bionic's `arc4random` logs the `madvise` failure and continues; it is designed to survive it.
2. **Official LineageOS packages sideload fine from that same 22.2 recovery**, so anything the kernel's missing
   `MADV_WIPEONFORK` triggers is triggered by those installs too — and they do not abort.

So either the abort is independent and merely adjacent, or something about *our* package drives a code path the
official ones do not. `confidence: low` on causation either way; **not established.**

One loose end: `madvise` with an unsupported advice value returns **`EINVAL`** ("Invalid argument"), but the log says
**`ENOENT`** ("No such file or directory"). Those do not match. So either bionic is reporting a different failure than
the missing-advice case, or the call is not reaching `madvise` at all. Unresolved, and worth the recovery log to
settle.

**The decisive experiment is already available.** Our 23.2 recovery boots our kernel, which *does* implement
`MADV_WIPEONFORK`. If the abort is tied to that missing advice, the 23.2 recovery will install the package cleanly.
If it aborts there too, the cause is elsewhere. That makes getting the 23.2 recovery to boot both the fix and the
test.

**Still missing:** the messages logged *after* the abort. They are now the most valuable thing in the log, and may
name the reason. Specifically anything containing `terminate`, `Aborted`, `stack smashing`, `Assert`, `SIGABRT`, or a
`tombstone`.

## What is still needed

| # | what to get | what it settles |
|---|---|---|
| 1 | **How LineageOS produced a working 22.2 recovery for this device** — built locally from the base kernel, or a prebuilt? | the cheapest discriminator; see above. **Do this before the bisect.** |
| 2 | where `recovery.img` actually comes from in our build — `recovery_intermediates/` held no image | whether our recovery build path differs from upstream's |
| 3 | the bisect: recovery from base `a30605a54f3b`, flashed identically | settles port-vs-build-path |
| 4 | any `Upload mode / RAMDUMP` on the 23.2 recovery attempt | whether the recovery kernel panics rather than being rejected |

## CLOSED: the sideload-from-old-recovery route does not work

**Tried and failed.** Sideloading the 23.2 zip from the existing **22.2** recovery:

```
Verifying update package...
ERROR:   recovery: failed to verify whole-file signature
Update package verification took 65.8 s (result 1).
ERROR:   recovery: Signature verification failed
ERROR:   recovery: error: 21
Installing update...
ERROR:   recovery: Error in /sideload/package.zip (killed by signal 6)

Install completed with status 1.
Installation aborted.
```

`adb sideload` itself reported `Total xfer: 1.00x` — the transfer was fine and the *verification* rejected it, which
is a different failure from the transfer failing.

**Reading it — this is the part that changes the diagnosis.** `error: 21` is AOSP's
`INSTALL_PACKAGE_SIGNATURE_FAILED`. Per the reviewer's ruling there is **no menu to disable verification**; recovery
*asks* and you answer **Yes**. The log shows **`Installing update...` _after_ the verification error**, so the prompt
was answered and the install **proceeded**. Verification was therefore not the final failure — **`signal 6` (SIGABRT)
during the install is.** That is a different fault and it is unexplained. `adb sideload` reporting `Total xfer:
1.00x` confirms the transfer itself was clean.

A **specific lead for the SIGABRT: `BoardConfigCommon.mk:142` sets
`TARGET_RECOVERY_UPDATER_LIBS := librecovery_updater_samsung`.** Recovery does not use AOSP's updater; it uses a
Samsung-supplied library from the device's Android 11 era (2020). A 2020-era recovery updater aborting on a 2026
`dat.br` package would explain a SIGABRT neatly. `confidence: low` — a lead, not a finding; the recovery log's
assertion text will confirm or kill it.

Rule out the mundane cause first: **out of space in recovery's staging area** aborts installs the same way.

### This makes the recovery flash mandatory

There is no longer a sideload-only route. The 23.2 recovery is the only thing signed with the right keys for our
package, so **flashing it is on the critical path** — but the recovery-flash route has its own open problem (see
the hypotheses above), so neither route is currently working end to end.

**Correction to the lead's earlier advice.** The lead suggested that the old recovery's *Advanced* menu might have a
signature-verification toggle to turn off. That is a **TWRP** feature and LineageOS Recovery is not TWRP — the official
recovery is a minimal AOSP-derived build and does not carry TWRP's on-the-fly verifier bypass. *This needs
confirming against the actual recovery, but the attempt above is consistent with no such option being present or
effective.* If a strong model knows a supported bypass, it would unblock this immediately.

So: **`FLASH-BLOCKER.md`'s A/B hypothesis is now the whole problem.**

## Alternative route that avoids the problem entirely (superseded — see above)

**Sideloading from the existing 22.2 recovery may sidestep this whole issue.** The package contains `recovery.img`,
so if the old recovery accepts the package, the 23.2 recovery is installed *as part of the sideload* and the
partition question never arises.

1. Power off → **Vol Up + Power** into recovery
2. (Nothing to disable: Lineage Recovery shows *"Signature verification failed"* during the sideload. Choose **Yes**.)
3. *Factory reset → Format data* ⚠️ erases all data — expected, the signing keys differ from official 22.2
4. *Apply update → Apply from ADB* → sideload the zip, accept the unknown-key warning

This was recommended and **has not been reported as attempted.** A refused sideload costs nothing and is itself
diagnostic: it would prove the old recovery cannot handle the package, making the slot question unavoidable — but by
then the facts above would be in hand.

Note for whoever tries it: `adb sideload` stopping at 47% with `adb: failed to read command: Success` is **normal**
and still succeeds.

## What I recommend against doing on the present evidence

- **Do not flash `vbmeta` or Samsung firmware** to work around this. There is no evidence pointing at either, and
  firmware operations carry real risk.
- **Do not guess a partition name** such as `recovery_a` / `recovery_b`. If A/B is the cause, the right name and the
  slot-switch mechanism should be confirmed, not inferred.
- **Do not treat "samloader returned 0" as success.** It means the transfer completed.

## Once recovery does boot

The remaining steps are settled and documented in [README.md](../../README.md) Path B:

1. *Factory reset → Format data* ⚠️
2. Sideload the ROM, accept the unknown-key warning (`UNOFFICIAL` build)
3. **Still in recovery** — sideload [MindTheGapps 16.0.0 **ARM64**](https://github.com/MindTheGapps/16.0.0-arm64/releases/latest).
   Do **not** reboot first: the LineageOS wiki is explicit that rebooting before installing GApps requires a factory
   reset and reinstall, with crashes otherwise.
4. *Reboot system now* — up to **15 minutes** on first boot

⚠️ Remove Google accounts from the tablet before wiping, or be ready to enter them: Factory Reset Protection locks
the setup wizard behind the previous account's credentials.

## NEXT STEPS (2026-10-06) — the commands

Everything below assumes `~/android/lineage` and `~/bin/samloader` are as documented in
[BUILD-HANDOFF.md](BUILD-HANDOFF.md), and that `adb` is installed. `samloader` needs the device in Download Mode.

**Verify the kernel in every image before flashing it.** This is the check that would have caught the
`boot-nobtf.img` mislabel, and it costs nothing:

```bash
verify-bootimg() {
  python3 - "$1" <<'PY'
import struct, sys
p = sys.argv[1]
d = open(p, 'rb').read(64)
k, r = struct.unpack_from('<II', d, 8)
print(f"{p}\n  kernel {k:,}  ramdisk {r:,}")
PY
}
verify-bootimg "$1"
```

The number must be the one you expect: **18,684,229** = with BTF, **16,011,654** = no BTF,
**~15.5M** = a base `a30605a54f3b` kernel. Never flash on the strength of a filename.

### Step 0 — restore the tablet (do this first, it is unbootable)

Use the 22.2 images already on disk -- do not re-download, and note they live in `~/Downloads/lineageos_22p2/`,
not `~/Downloads/`:

```bash
cp ~/Downloads/lineageos_22p2/boot.img ~/work/boot-22.2-good.img
verify-bootimg ~/work/boot-22.2-good.img    # MUST print kernel 15,564,314
adb -d reboot download
~/bin/samloader flash --partition BOOT ~/work/boot-22.2-good.img --no-reboot
```

Power on. If this does **not** come up, stop and say so — that would invalidate the control in step 1.

### Step 1 — the base-kernel control. This is the decisive test.

Build a `boot.img` from the **pre-port** kernel `a30605a54f3b` (= `origin/lineage-22.2`), keeping our Android 16
ramdisk. This separates "our port broke the kernel" from "the 23.2 build path for this device is broken anyway".

```bash
cd ~/android/lineage/kernel/samsung/sdm670
git fetch origin
git checkout -b test/base-kernel origin/lineage-22.2
git rev-parse --short=12 HEAD        # MUST print a30605a54f3b — stop if it does not

cd ~/android/lineage
source build/envsetup.sh && breakfast gts4lvwifi
mka bootimage                        # ~35 min. NOT 'mka recoveryimage', which does not build boot.img
```

Confirm the build really is the base kernel. `kernel.release` embeds the HEAD sha, so it is a reliable
discriminator — the no-BTF build logged `4.9.337-gcfe0b6979655`:

```bash
cat ~/android/lineage/kernel/samsung/sdm670/include/config/kernel.release
# MUST contain 'ga30605a54f3b'. If it says gcfe0b6979655 or g801f3f20e54a, the build is stale — stop.
verify-bootimg ~/android/lineage/out/target/product/gts4lvwifi/boot.img   # expect ~15.5M, not 18,684,229
```

Then flash and boot:

```bash
cp ~/android/lineage/out/target/product/gts4lvwifi/boot.img ~/work/boot-base.img
adb -d reboot download
~/bin/samloader flash --partition BOOT ~/work/boot-base.img --no-reboot
```

**How to read the result:**

| outcome | meaning |
|---|---|
| **boots to Android** | our port broke the kernel. Go to step 2 and bisect. |
| **silent fallback to Download mode again** | the kernel is **exonerated**. The 23.2 Android 16 build path for this device is broken independent of the port — go to step 3. |

Note the ambiguity honestly: this image is *base kernel + our 23.2 ramdisk*, so a failure is consistent with either
"kernel broken" or "Android 16 ramdisk incompatible with a 22.2-era kernel". Step 3 separates those.

### Step 2 — if the base kernel boots, bisect the 20 commits

Order by risk, not by date. The whole port is the 20 commits `d73f07cf8b5c..801f3f20e54a`.

```bash
cd ~/android/lineage/kernel/samsung/sdm670
git checkout -b test/bisect origin/lineage-23.2
```

Candidate first removals, each with the reason it is the most likely culprit:

1. **`5078de1ee272` "P4: select BPF_ARCH_SPINLOCK on arm64 so bpf_spin_lock uses arch_spin_lock()"** — the single
   riskiest call in the whole port. `review-P1.md`/`review-P4.md` recorded this as unproven until boot.
2. **`316352012ff2` "P3: merge the gts4lv-23.2 defconfig fragment into all four defconfigs"** — brings in
   `CONFIG_BPF_LSM=y`, `CONFIG_UCLAMP_TASK=y`, BTF and the rest. `port/no-btf` is this commit minus one line, so
   `origin/port/no-btf` is a ready-made *partial* test of it.
3. **`1c21d6589088` "P4: add the DRM format-modifier declarations"** — touches `drm_mode.h`, the file `F1` already
   had to hand-edit at lines 92-104. See [duplicate-picks.md](duplicate-picks.md).
4. **`f58d0181a988` "P4: restore the braces the schedutil uclamp merge dropped"** — a hand-merged hunk in the
   scheduler, the classic place for a silent boot hang.

Fastest bisect: test `origin/port/no-btf` first, because it already exists and needs no new work. It only removes
BTF, so it does **not** bisect the defconfig fragment — it just re-confirms ruling 4. Then move to candidate 1.

### Step 3 — if the base kernel also fails, the kernel is not the problem

Ruling 3's recovery-side hypotheses are **measured and refuted** (AVB, fstab, ramdisk file list), so this branch is
a much smaller search than it looks. Ranked:

1. **The Android 16 boot-image build path for this device.** `confidence: low`.
   The base kernel boots 22.2 userland, but we are pairing it with an Android 16 ramdisk. If it fails, that
   pairing is suspect, and the discriminator is: build a `boot.img` from the base kernel **plus 22.2's ramdisk**,
   which is exactly `~/Downloads/lineageos_22p2/boot.img` and is already proven good. Repacking ours is then a
   diff in one variable.
2. **`librecovery_updater_samsung` — a 2020 vendor library in a 2026 recovery.** `confidence: low`.
   Verified as configured (`BoardConfigCommon.mk:142`). Never tested. The only recovery-side item ruling 5
   leaves untested. It is for package installation, not boot, so `low` is probably right — but it is the last
   untested recovery-side difference and it has no business in an AOSP recovery.
3. **Something in `init.rc` or the ramdisk's `first_stage_init` that differs at the byte level.** `confidence: low`.
   Ruling 5 compared *file lists* and the fstab, not every file's contents. A content diff is still possible:
   ```bash
   cd /tmp/opencode && diff -rq r22/x r23/x | head -40
   ```

### Whatever you do, do not

- Flash a boot or recovery image whose kernel size you have not read off the header.
- Trust a filename. `boot-nobtf.img` was the proof.
- Re-open AVB or fstab. They are measured, identical to the image that boots, and closed.
- Delete anything on the device side; everything here is reversible with Download Mode plus samloader.

## Once it boots

The kernel backport is **not proven until boot**, and this is the first real test of it. 2,458 commits were ported and
reviewed, and the kernel builds `Image.gz-dtb` for both defconfigs, but the specific thing to watch is whether
**`bpfloader` and `netd` come up** — that exercises the eBPF work, including the `BPF_ARCH_SPINLOCK` decision, which
was a judgement call and not a copy of upstream. Then `scripts/device-checks.sh` and the BPF tests in
[TESTING.md](../../TESTING.md).

Also check `logcat -s lmkd`: `process_mrelease` is deliberately not ported (reviewer decision, `review-P1.md`), on the
unverified assumption that AOSP's lmkd falls back to a plain kill on `ENOSYS`.

Known non-blocking defect carried into first boot: `libwfdservice` (32-bit) will fail to load. WFD only, stays
`disabled` because nothing sets `vendor.wfdservice=enable`. Ruling and the one-line fix are in
[review-P6.md](review-P6.md).