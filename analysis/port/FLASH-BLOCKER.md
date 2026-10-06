<!-- task: FLASH -->
# Flashing blocker: the 23.2 recovery is not taking

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

## The failure

```bash
adb -d reboot download
samloader flash --partition RECOVERY recovery.img --no-reboot
```

Observed:

| check | result |
|---|---|
| `samloader detect` | **succeeds** — the tool communicates with the tablet |
| `samloader flash …; echo $?` | **`exit=0`** — samloader reports success |
| after the flash, the tablet | boots by itself into **LineageOS 22.2** |
| `adb -d reboot recovery` | lands in the **22.2** recovery, not 23.2 |
| earlier in the session | the tablet would sit in / return to **Download Mode** |

So samloader claims a successful write, yet the recovery the bootloader actually boots is unchanged. The recovery
partition still holds 22.2's.

## Hypotheses, ranked

**1. ~~A/B slot mismatch.~~ RULED OUT.** The lead proposed this and it is **wrong**.
`device/samsung/gts4lv-common/BoardConfigCommon.mk:39` sets `AB_OTA_UPDATER := false`, and the LineageOS
wiki gives `recovery_partition_name: recovery` — a single partition, no slots. There is no slot mismatch
to explain anything. *The lead should have read the device tree before reaching for A/B by default.*

**2. The 23.2 recovery's kernel has never booted and may crash.** The most likely cause of the
Download-mode cycle. Samsung shows *Upload mode/RAMDUMP* when a kernel panics early, which looks like the
same thing from the outside. Untested — the recovery has never been seen running. **Test:** boot it and
watch for RAMDUMP.

**3. samloader reported success but wrote nothing.** `exit=0` proves the USB conversation completed, not
that a partition was written. Still open. **Test:** the full samloader output, not just the exit code.

**4. ~~Wrong partition name.~~ RULED OUT.** `RECOVERY` is correct per the official guide, and with no
A/B there are no slot-suffixed variants to try.

**5. The button sequence with USB still plugged.** Download mode is *Vol Up + Vol Down + Power* with USB
connected. Moving straight from the *Vol Down + Power* force-reboot to *Vol Up + Power* briefly holds all
three, which requests Download mode. Per the reviewer's ruling this is the most likely explanation of the
cycle, and it is a **user-interface** cause, not a flashing one.

## What is still needed, and what each item would settle

| # | what to get | what it settles |
|---|---|---|
| 1 | **the recovery install log** — recovery's *Advanced → View logs*, then `adb pull /data/misc/logged_recovery/` after booting back into Android | **The `killed by signal 6` abort is the live failure and its cause is unknown.** The assertion or error text will name it. *Most informative single item.* |
| 2 | full output of `samloader flash --partition RECOVERY recovery.img --no-reboot` | which partition it actually wrote (hypothesis 3) |
| 3 | whether the device shows *Upload mode/RAMDUMP* while trying to boot the 23.2 recovery | hypothesis 2 — did the recovery kernel crash? |
| 4 | free space on the tablet | an out-of-space condition in recovery's staging area also aborts the install |

## Alternative route that avoids the problem entirely (superseded — see above)

**Sideloading from the existing 22.2 recovery may sidestep this whole issue.** The package contains `recovery.img`,
so if the old recovery accepts the package, the 23.2 recovery is installed *as part of the sideload* and the
partition question never arises.

1. Power off → **Vol Up + Power** into recovery
2. *Advanced* → disable **package/signature verification**
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