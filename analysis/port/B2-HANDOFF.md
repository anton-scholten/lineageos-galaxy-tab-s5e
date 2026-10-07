# B2: full ROM build, install and first-boot troubleshooting (local agent handoff)

Written 2026-10-07 by the reviewing lead. **This is the entry point for a local AI agent on the owner's machine.**
It is self-contained: read it top to bottom, then [AGENTS.md](../../AGENTS.md) for the general rules.
Background, only if you need it: [FLASH-BLOCKER.md](FLASH-BLOCKER.md) (how the boot problem was found, rulings 1–7),
[review-P6.md](review-P6.md), [TESTING.md](../../TESTING.md).

## 1. Where things stand (2026-10-07)

| Thing | State |
|---|---|
| Kernel fork `anton-scholten/android_kernel_samsung_sdm670` | `lineage-23.2` @ **`500658be3c16`** = the ported ExyHyperBrick eBPF series (`801f3f20e54a`) + the SELinux avtab fix |
| Device fork `anton-scholten/android_device_samsung_gts4lv-common` | `lineage-23.2` @ **`d154fb4384fb`** |
| Build tree | `~/android/lineage` (synced; the kernel is already checked out at `500658be3c16`) |
| Tablet | SM-T720 (`gts4lvwifi`). **`RECOVERY` = our 23.2 recovery, which boots.** `BOOT`/system: LineageOS 22.2, data intact |
| Proven | The ported kernel boots all its drivers, and the 23.2 recovery (Android 16 userspace) runs on it |
| Not yet proven | The full 23.2 system booting; bpfloader/netd; everything after that |
| Broken artifact | `lineage-23.2-20261005-UNOFFICIAL-gts4lvwifi.zip`: its `boot.img` has the pre-fix kernel. **Never flash it** |

**The one lesson that cost two days:** on this tablet, *falling into Download mode after a boot attempt* usually means
Android ran `reboot bootloader` itself (init's `InitFatalReboot`). It does **not** mean the bootloader rejected the
image. **Read `/proc/last_kmsg` before guessing** (§4). The SELinux cause was found in one read.

## 2. Build the full ROM

```bash
cd ~/android/lineage
git -C kernel/samsung/sdm670 fetch anton lineage-23.2 && git -C kernel/samsung/sdm670 checkout FETCH_HEAD
git -C kernel/samsung/sdm670 rev-parse --short=12 HEAD          # must print 500658be3c16 (or later)
git -C device/samsung/gts4lv-common rev-parse --short=12 HEAD   # must print d154fb4384fb (or later)
source build/envsetup.sh && breakfast gts4lvwifi
mka bacon -k 0 2>&1 | tee ~/work/rom-build3.log
cat out/target/product/gts4lvwifi/obj/KERNEL_OBJ/include/config/kernel.release   # must end in -g500658be3c16
ls -lt out/target/product/gts4lvwifi/lineage-23.2-*-UNOFFICIAL-gts4lvwifi.zip | head -1   # must be today's
sha256sum <that zip>
```

Known, expected build noise. **Don't "fix" any of these:**

| Message | What it is |
|---|---|
| `FAILED: …libwfdservice.so.check_elf_file` → `ninja failed with: exit status 1` | Known blob ABI break (screen casting only). `-k 0` packages the zip anyway. Fix is task P8, not yours. [review-P6.md](review-P6.md) |
| `Disallowed PATH tool "arm-linux-gnueabi-ld.bfd"` (4×) | Non-fatal. The vDSO is linked by in-tree `ld.lld`. [P6-log.md](P6-log.md) |

**Any other `FAILED:`** is a real build error. Run `grep -n "FAILED:" ~/work/rom-build3.log` to list them all, because
`-k 0` keeps going past errors. Fix device-tree errors under P6's rules (AGENT-TASKS.md §6c P6) on a new branch
`port/dt-3` from `lineage-23.2`. Kernel errors go on a new branch `port/k-1` from `lineage-23.2` under P4's rules.
Anything outside those rules goes to `## Escalated` (§6).

Build traps already hit on this machine (see [BUILD-HANDOFF.md](BUILD-HANDOFF.md)):
- Keep `USE_CCACHE=1` set the same on every run. Changing it invalidates all of ninja's work (7 hours lost once).
- The host needs the 32 GB swapfile (15 GB RAM).
- `git-lfs` must be installed before any `repo sync`.
- `brunch gts4lvwifi` / `breakfast gts4lvwifi`, never `lineage_gts4lvwifi`.
- `mka recoveryimage` doesn't rebuild `boot.img`.

**Before flashing anything, check the kernel inside the image.** A filename proves nothing; a mislabelled
`boot-nobtf.img` already wasted a test. Run `strings <img> | grep -m1 "Linux version"`. It must show `-g500658be3c16`.

## 3. Install (the owner does the ⚠️ steps; the agent may guide)

⚠️ **Step 2 erases all data on the tablet.** The owner must back up first and remove the Google account from the tablet
(Factory Reset Protection). Keeping data is impossible: official 22.2 and this build use different signing keys.

1. Boot the 23.2 recovery: USB unplugged, *Vol Down + Power* until black, then *Vol Up + Power*. Check that it says **23.2**.
2. ⚠️ *Factory reset → Format data / factory reset*.
3. *Apply update → Apply from ADB*, then `adb -d sideload <new zip>`. Answer **Yes** to *"Signature verification failed"*.
   Stopping at 47% with `adb: failed to read command: Success` is normal.
4. Still in recovery: sideload MindTheGapps 16.0.0 arm64 (<https://github.com/MindTheGapps/16.0.0-arm64/releases/latest>) the same way, answering **Yes**.
   Never reboot into the system before GApps are in.
5. *Reboot system now*. The first boot may take up to 15 minutes.

Getting out of Download mode: **unplug USB**, hold *Vol Down + Power* until black, release. With USB plugged in, the
button sequence lands you in Download mode again.

## 4. If it doesn't boot: read the log first (P7 rules, read-only)

| What you see | Do this |
|---|---|
| Falls into **Download mode** | Unplug USB, *Vol Down + Power* until black, then *Vol Up + Power* → 23.2 recovery → `adb shell cat /proc/last_kmsg > last_kmsg-<n>.txt` |
| **Bootloop** on the logo | Same: get into recovery, then `last_kmsg` |
| Boot animation forever | `adb logcat -b all -d > logcat-<n>.txt` (adb may work during boot), then the recovery `last_kmsg` |
| Boots to setup / UI | Run TESTING.md in full, plus the early checks in §5 |

`/proc/last_kmsg` is Samsung's `sec_log`: the **previous** boot's kernel log from its first line, readable in recovery.
pstore is the second copy: `adb shell 'mkdir -p /tmp/ps; mount -t pstore pstore /tmp/ps; cat /tmp/ps/*' > pstore-<n>.txt`.
Copy both **before** any further reboot, because each boot overwrites them.

Reading it:
```bash
grep -n "Linux version" last_kmsg-<n>.txt                     # -g500658be3c16 must be there, or the wrong kernel booted
grep -n -E "InitFatalReboot|Kernel panic|Unable to handle|avc: denied|SELinux:|init: .*(fail|abort|FATAL)|reboot:" last_kmsg-<n>.txt | head -40
```
- The last 40 lines before `reboot: Restarting system with command 'bootloader'` are the cause.
- `reboot … 'bootloader'` = init gave up. `Kernel panic` = the kernel died.

Write `analysis/port/boot-<n>.md`: kernel and device commits, how far it got, the first error of each kind with 20 lines
of context, and your guess with `confidence:`. **Commit only excerpts.** The full logs contain the device serial and MACs,
so keep them local (as with `flash-logs/boot-1-last_kmsg-excerpt.md`).

### Likely next failures, in order of expectation (all unverified, so check each against the log)

1. **More SELinux/init incompatibilities.** The policy now loads in recovery. The full system loads the *split*
   policy (`/system/etc/selinux` + `/vendor/etc/selinux`), which is a bigger and different policy. Look for `SELinux:` errors
   and `avc: denied` lines from early services. Kernel avtab/policydb fixes go on `port/k-1`. Policy fixes go in the device tree.
2. **bpfloader / netd** (the first real test of the eBPF backport): `grep -iE "bpfloader|netbpfload|netd|bpf" logcat`.
   An abort here makes the system reboot to Download mode. `ro.bpf.kver_override=5.15.178` is set by patch 0004.
   Lead's note (unverified): with `CONFIG_DEBUG_INFO_BTF` kept on, `/sys/kernel/btf/vmlinux` exists, so BTF isn't the
   suspect. A failing BPF program load is.
3. **lmkd**: `process_mrelease` is deliberately not ported. lmkd should fall back. `logcat -s lmkd`.
4. **Audio**: HAL 6.0 with space-separated policy lists (P5).
5. **WFD/screen casting**: known broken (P8). Ignore `wfdservice` load errors.

## 5. If it boots: early checks
Wi-Fi, audio (playback + mic), `adb logcat -d | grep -iE 'lmkd|AudioPolicy|netbpfload|bpfloader'`,
`scripts/device-checks.sh`, the BPF tests in TESTING.md. Then a 24 h soak. Record them in `analysis/port/boot-<n>.md`.

## 6. Rules for the local agent
- Docs repo: work on `agent/B2` (or `agent/P7` for log triage). **Never push to `main` or any `lineage-23.2`.**
  Never force-push, never delete branches.
- Code: kernel fixes only on `port/k-<n>`, device-tree fixes only on `port/dt-3`, both from `lineage-23.2`, one commit
  per fix with a `Fix-by:` trailer. Never take a fix that disables or allowlists a check (SELinux permissive,
  `allow_undefined_symbols`, `BUILD_BROKEN_*`, deleting code). Escalate those instead.
- **Never flash, wipe or format on your own.** Prepare the exact command and let the owner run it. Mark every
  data-erasing step ⚠️.
- **Escalate to the strong model** (RUNBOOK prompt R, "boot debugging: analysis/port/boot-<n>.md") when the cause is
  in kernel C code, when two fix attempts fail, or when the only fix you can find disables something.
  Write the escalation under `## Escalated` in `boot-<n>.md`.
- Every fact needs a source: file:line @ commit, a log line number, or a URL. Give a confidence for each guess.
- When done or blocked: update `analysis/port/STATUS.md` and `WORKLOG.md` on your branch, push, and stop.

## 7. Current and future work (after first boot)

| # | Work | Who | Notes |
|---|---|---|---|
| B2 | Build the full ROM, install, first boot (this file) | local agent + owner | **current** |
| P7 | Log triage for each failed boot | local free agent | AGENT-TASKS §6c P7; use §4 here for the Download-mode case |
| P8 | Restore Wi-Fi Display (`libwfdservice` 3-arg `setDeviceConnectionState`) | strong model / owner | [review-P6.md](review-P6.md). Needs a vendor-blob fork or a dropped WFD stack |
| T | Testing: `device-checks.sh`, BPF selftests, networking, 24 h soak | owner + agent | RUNBOOK §8d |
| LTE | `brunch gts4lv`, then the same install with LTE firmware (CP) | owner | after the Wi-Fi model is stable |
| K | `process_mrelease` port if lmkd misbehaves; `target-level` 6 if wanted | strong model | review-P1/P4 |
| U | Contact krazey (ExyHyperBrick) before publishing; then devrel@lineageos.org with test results | owner | the avtab fix is ours and generic to all msm-4.9 trees with the Android-M hack. Worth upstreaming |
| C | Cleanup: delete kernel branches `port/no-btf`, `test/base-config`, `port/selinux-avtab` (= `lineage-23.2`) and docs branch `lead/2026-10-05b` | owner | merged or superseded |
