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

**1. A/B slot mismatch — the leading hypothesis.** This device uses A/B. If samloader wrote the recovery for the slot
the bootloader is *not* booting from, the write genuinely succeeds, reports success, and changes nothing. That
matches every observation, including the confusing Download Mode behaviour. **Test:** `adb shell getprop
ro.boot.slot_suffix` — if it returns `_a` or `_b`, that is very likely the whole story. `ro.boot.slot_count` confirms
A/B is in use. If confirmed, the fix is either writing the *active* slot's recovery or switching slots, and **the
correct partition name or slot-switch mechanism for this device must come from a strong model or the owner, not from
me guessing at Samsung's partition naming.**

**2. samloader reported success but wrote nothing.** `exit=0` proves the USB conversation completed, not that a
partition was written. **Test:** the full samloader output, not just the exit code. Lines naming the partition or the
transfer will settle it.

**3. Something restored the old recovery.** The official guide warns that *stock* ROM overwrites a custom recovery on
every boot. This tablet is on LineageOS, which should not do that — but a failed write that left the partition
untouched is indistinguishable from this without the output from hypothesis 2.

**4. Wrong partition name for this device's partition table.** The official gts4lvwifi guide does say
`--partition RECOVERY`, so the name is right *for the 22.2-era PIT*. If the partition table changed, or if this
device's recovery lives under a slot-suffixed name, that would explain it. **This needs checking against the actual
partition list**, not assumed.

## Facts still missing — each is one command

| # | command | what it settles |
|---|---|---|
| 1 | `adb shell getprop ro.boot.slot_suffix` | A/B hypothesis. **Most informative single command.** |
| 2 | `adb shell getprop ro.boot.slot_count` | confirms A/B |
| 3 | full output of `samloader flash --partition RECOVERY recovery.img --no-reboot` | which partition it actually wrote |
| 4 | `adb -d reboot bootloader` + its output | what the bootloader reports about slots/partitions |
| 5 | the recovery version string, read carefully on the main menu | both 22.2 and 23.2 show the **LineageOS logo**, so the logo alone proves nothing |

## Alternative route that avoids the problem entirely

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