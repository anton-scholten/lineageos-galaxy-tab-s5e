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