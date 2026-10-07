<!-- task: T2 | agent: Space Bunny Free | date: 2026-10-03 -->
# T2: crash-log collection guide

## Summary

Write-up of how to collect crash logs from the Galaxy Tab S5e (`gts4lvwifi` / `gts4lv`) on a
LineageOS 23.2 build: `logcat`, `pstore`, `dmesg`, tombstones/dropbox, plus a live-capture recipe.
Every command here is read-only. Nothing in this section flashes, wipes or formats anything; the
data-erasing recovery actions are listed separately at the end, each behind a ⚠️ warning.

Look at these first:

1. **All URLs here were verified reachable on 2026-10-03** (`curl -o /dev/null -w '%{http_code}' -L`),
   see [Verified sources](#verified-sources). Note that `wiki.lineageos.org` **is** reachable from this
   machine, contrary to the block list in [HANDOVER.md](HANDOVER.md) §"Rebuilding the working
   environment". Only `xdaforums.com` and `samfw.com` returned 403. The lead may want to fix that list.
2. **The button combinations now have a real source.** The LineageOS device pages for both codenames
   list them verbatim under "Special boot modes", and they match `README.md` lines 121-123. No XDA
   citation is needed, so nothing here is unverified.
3. **`pstore` is confirmed enabled in our kernel**, so `/sys/fs/pstore/console-ramoops*` is the right
   path: `CONFIG_PSTORE`, `CONFIG_PSTORE_CONSOLE`, `CONFIG_PSTORE_RAM` are all `y` in
   `gts4lvwifi_defconfig` and `gts4lv_defconfig` at `a30605a54f3b` (citations below).
4. **Only one panic is kept.** Each new panic overwrites `console-ramoops-0`, so the file must be
   copied off the tablet after every crash, before rebooting again. Verified from
   `fs/pstore/ram.c:280-284` + `ram.c:148-149,219-221`.

Everything in this file that is read-only is safe to run at any time, including on a device that
is in a bootloop.

## Collecting crash logs

Scope: what to collect, in what order, after which kind of failure. Nothing here changes the
device. Phase 5 of [ESTIMATE.md](ESTIMATE.md) ("first boot and debugging: kernel panics,
netd/bpfloader, HAL crashes") needs `pstore`/`last_kmsg`, and phase 6 (testing) needs the same
files when something goes wrong during a soak.

### Prerequisites

| Need | Why | Note |
|---|---|---|
| `adb` on the PC | all of it | <https://developer.android.com/studio/command-line/adb>, or the platform-tools zip at <https://developer.android.com/tools/releases/platform-tools> (both 200) |
| USB-C **data** cable, not a charge-only one | `adb` sees nothing otherwise | A charging-only cable gives `no devices/emulator found` and looks like a driver problem |
| Root on the tablet | `pstore`, `dmesg`, tombstones and dropbox are all root-only | LineageOS: *Settings → System → Developer options → Root access*, then use `su -c` |
| USB debugging enabled | `adb` access | *Settings → About tablet → Software information → Build number* (tap 7×), then *Developer options → USB debugging* |
| Enough free space on the PC | a full `logcat -b all -d` is tens of MB, plus a bugreport zip | check with `ls -lh` once you have one |

Work in a folder per crash so the files can be lined up against a timeline:

```bash
mkdir -p crashlogs/$(date +%Y%m%d-%H%M%S) && cd crashlogs/$(date +%Y%m%d-%H%M%S)
```

### Which log answers which question

| Symptom | Log to collect |
|---|---|
| App, system or HAL process died, `FATAL EXCEPTION`, `netd`/`bpfloader` abort | [1. logcat](#1-logcat-userspace-logs) + [4. tombstones / dropbox](#4-tombstones-anr-and-dropbox-hal-crashes) |
| Boot hangs, screen freezes, then reboots itself | [2. pstore](#2-pstore-the-kernel-log-from-the-crash-itself) **first** — it is gone after the next reboot |
| Reboot loop, kernel never reaches userspace | [2. pstore](#2-pstore-the-kernel-log-from-the-crash-itself) on every single boot |
| Something breaks only under load, over hours | [5. live capture](#5-capturing-a-crash-as-it-happens) |
| Bug present in the running kernel, no panic | [3. dmesg](#3-dmesg-the-live-kernel-ring-buffer) |

### 1. logcat (userspace logs)

```bash
adb logcat -b all -d > logcat.txt
```

- `-b all` is the important part. It dumps **every** buffer: `main`, `system`, `radio`, `events`,
  `crash` and `kernel`. Plain `adb logcat -d` misses `kernel` and `crash`, which is exactly where
  a bpf/netd or native crash shows up. The kernel buffer is a second source for the same messages
  `dmesg` gives in §3, and it survives a userspace crash that `main` did not record.
- `-d` means "dump and exit". Without `-d` this command streams forever.
- Size warning: `-b all` on a busy system produces tens of megabytes of text. Check before copying
  it around with `ls -lh logcat.txt`, and compress it if it has to be committed or mailed:
  `xz -9 logcat.txt` (or `gzip -9`). The exact size depends on the device and the uptime; measure
  it rather than trusting a guess.
- Quick triage without opening the file:
  ```bash
  grep -nE 'FATAL EXCEPTION|ANR in|Fatal signal|DEBUG *:|abort|Watchdog' logcat.txt | head -50
  grep -c 'FATAL EXCEPTION' logcat.txt          # how many crashes at all
  ```
- If the device has rebooted, `-b all` only holds what was logged **since that boot**. It says
  nothing about the previous boot; that is §2's job.

### 2a. When the tablet falls into Download mode: `/proc/last_kmsg` from recovery

On this tablet a failed boot usually ends in **Download mode**. Often that is Android's own
`reboot bootloader` (init gave up), not a bootloader reject. The system never comes up, so the
commands below that need `adb` to the system won't work. Read the previous boot's kernel log from recovery instead:

1. USB unplugged: *Vol Down + Power* until black, then *Vol Up + Power* → recovery (23.2, or 22.2 if testing).
2. `adb shell cat /proc/last_kmsg > last_kmsg.txt`. This is Samsung `sec_log` (`CONFIG_SEC_LOG_LAST_KMSG=y`). It holds the
   **previous** boot from its first printk line, and recovery's adbd runs as root.
3. Then `grep -n -E "Linux version|InitFatalReboot|Kernel panic|SELinux:|avc: denied|reboot:" last_kmsg.txt`.
   The lines before `reboot: Restarting system with command 'bootloader'` are the cause.

This is how the SELinux blocker was found ([analysis/port/FLASH-BLOCKER.md](analysis/port/FLASH-BLOCKER.md) ruling 7). The file
contains the device serial and MACs, so commit excerpts only.

### 2. pstore (the kernel log from the crash itself)

**What pstore is, in one line:** pstore copies the last kernel messages into a reserved block of
RAM (the *ramoops* backend) as the kernel dies, so they are still there after the reboot — a
kernel panic wipes nothing that RAM is holding, which is why it survives.

Only useful **after** a crash reboot; on a healthy tablet the directory is empty.

```bash
adb shell su -c 'cat /sys/fs/pstore/console-ramoops*' > pstore.txt
adb shell su -c 'ls -l /sys/fs/pstore/'      # which files exist, and how big
```

Run it **every** time the tablet has come back from a panic, and copy the file to the PC before
rebooting it again. Two verified reasons:

- The console record is a single RAM zone, not a ring: `persistent_ram_write(cxt->cprz, ...)` on
  every dump (`fs/pstore/ram.c:280-284`), and it is read back with `max_dump_cnt = 1`
  (`fs/pstore/ram.c:219-221`). Every new panic overwrites the last one.
- The file name is always `console-ramoops-0`: `scnprintf(name, ..., "console-%s-%lld", psname, id)`
  (`fs/pstore/inode.c:344-346`) with `id` = the array index (`fs/pstore/ram.c:148-149`) and the
  backend named `"ramoops"` (`fs/pstore/ram.c:397`). Hence the `console-ramoops*` glob in the
  command above, and hence there is never a `-1`, `-2`, ... variant to fall back on.

Other files you may see in the same directory, all worth grabbing:

| File | What it holds |
|---|---|
| `console-ramoops-0` | the console log, dumped on panic/oops. The one you want |
| `dmesg-ramoops-0.enc.z` | a compressed oops dump, when the log was too big to fit raw. Name from `fs/pstore/inode.c:340-343`; needs `xz -d` to read |
| `ftrace-ramoops-0`, `pmsg-ramoops-0` | ftrace buffer and userspace `pmsg`, only if those zones were configured |

Notes and gotchas:

- **This kernel does have pstore.** `CONFIG_PSTORE=y`, `CONFIG_PSTORE_CONSOLE=y`,
  `CONFIG_PSTORE_PMSG=y`, `CONFIG_PSTORE_RAM=y` in
  [`arch/arm64/configs/gts4lvwifi_defconfig:767-770`](https://github.com/anton-scholten/android_kernel_samsung_sdm670/blob/a30605a54f3b/arch/arm64/configs/gts4lvwifi_defconfig#L767-L770)
  and [`gts4lv_defconfig:769-772`](https://github.com/anton-scholten/android_kernel_samsung_sdm670/blob/a30605a54f3b/arch/arm64/configs/gts4lv_defconfig#L769-L772)
  at `a30605a54f3b`. The `console-*` name only exists because `CONFIG_PSTORE_CONSOLE` is set;
  if the port ever drops it, this whole step returns an empty directory.
- `CONFIG_PANIC_TIMEOUT=5` (`gts4lvwifi_defconfig:775`) means the kernel reboots 5 seconds after a
  panic, so the file can never be read before the reboot — collect it after, not during.
- `cat` of a missing file prints an error and nothing else. Treat "no such file" as **"there was no
  panic"**, and check `ls -l /sys/fs/pstore/` before concluding the log is empty.
- If `su` is not there, `adb root` on a build that permits it also works; the files themselves are
  mode `0444` (`fs/pstore/inode.c:329`), so it is SELinux, not file permissions, that normally
  blocks the unprivileged read.
- `dmesg-ramoops-0.enc.z` is raw xz. `xz -dc dmesg-ramoops-0.enc.z > dmesg-pstore.txt`.
- Do **not** "clear" pstore by writing to it; it is read-only, and you cannot: it is a RAM copy,
  so only the next panic replaces it. There is no cleanup step, by design.

### 3. dmesg (the live kernel ring buffer)

```bash
adb shell dmesg > dmesg.txt                 # plain adb shell first
adb shell su -c dmesg > dmesg.txt          # if the plain one gives EPERM
```

- **Only the current boot.** The ring buffer lives in RAM and is re-created by the bootloader on
  every start, so after a panic reboot `dmesg` shows a healthy boot and nothing about the crash.
  This is the single most common mistake when reading a bug report: a clean `dmesg` after a crash
  means nothing. §2 is what holds the panic.
- Useful for the kernel-version and driver state, and for warnings that never escalate to a panic:
  ```bash
  grep -nE 'bpf|BPF|verifier|netd|Call trace|BUG|WARN|oops|panic' dmesg.txt | head -80
  ```
- Needs root on Android in most builds (`kernel.dmesg_restrict`). `Permission denied` → use `su -c`.
- `dmesg -T` (human-readable timestamps) is not available in every toybox build. If it errors, drop
  the flag; the raw `[   12.345678]` timestamps are perfectly usable.
- `adb shell dmesg | wc -l` gives the number of lines, so you can tell a real capture from a stub.

### 4. Tombstones, ANR and dropbox (HAL crashes)

For a native crash the tombstone is the real evidence; `logcat` only shows the summary. All
read-only, all root-only, all wiped by a factory reset (see [7](#7-recovery-actions-that-erase-data-last-resort-only)).

```bash
adb shell su -c 'ls -lt /data/tombstones/'                    # newest first
adb shell su -c 'cat /data/tombstones/tombstone_XX' > tombstone_XX.txt
adb shell su -c 'ls -lt /data/anr/'                           # ANR traces
adb shell su -c 'ls -lt /data/system/dropbox_data/'         # dropbox entries (read, then dive in)
adb shell su -c 'dumpsys dropbox --print' > dropbox.txt       # big; grep it
adb shell su -c 'logcat -b crash -d' > logcat-crash.txt       # just the crash buffer
```

- `tombstone_00` is always the most recent; older ones are `tombstone_01`, `02`, ...
- `dumpsys dropbox --print` is very large. Pull it, then read it on the PC:
  `grep -nE 'SYSTEM_TOMBSTONE|SYSTEM_ANR|data_app_crash|SYSTEM_SERVER_CRASH' dropbox.txt`.
- The two bpf-related processes to look for by name: `netd` (which loads the eBPF programs and is
  the first thing Android 16 breaks on a 4.9 kernel) and `bpfloader`. In `logcat.txt`:
  ```bash
  grep -nE 'bpfloader|netbpfload|BPF_|bpf_prog_load|libbpf' logcat.txt | head -50
  ```
- ANRs for system_server, and `system_app_anr`/`data_app_anr` in dropbox, explain "the tablet
  froze for a minute and came back" better than any kernel log.

### 5. Capturing a crash as it happens

For an intermittent fault, dumping after the fact may be too late. Stream instead.

```bash
# live logcat, all buffers, timestamped, no rotation
adb logcat -b all -v threadtime -T "$(date '+%m-%d %H:%M:%S.000')" | tee live-logcat.txt

# in a second terminal, keep following the kernel ring buffer while you reproduce the fault
adb shell su -c 'dmesg -w' | tee live-dmesg.txt

# watch for the panic markers while you reproduce
adb shell su -c 'dmesg -w' | grep --line-buffered -nE 'Call trace|BUG:|Oops|panic|Internal error'
```

- `adb logcat -G <size>` enlarges the on-device ring buffer so a slow-to-reproduce bug still lands in
  it, e.g. `adb logcat -G 64M` (needs root; harmless, and it only changes memory use).
- `dmesg -w` follows the buffer; if toybox lacks `-w`, use `adb shell su -c 'cat /proc/kmsg'` —
  but note that reading `/proc/kmsg` **consumes** the buffer, so it can eat messages other tools
  still need. Prefer `dmesg -w`.
- Once it crashes and comes back up, go straight to §2 for pstore.

### 6. Entering recovery mode and download mode (Tab S5e)

Both codenames behave the same. From powered off:

| Mode | Buttons | Source |
|---|---|---|
| **Recovery** | hold **Volume Up + Power** until the Android Recovery screen appears (about 10-15 s), then release | [LineageOS wiki `gts4lv`](https://wiki.lineageos.org/devices/gts4lv/) and [`gts4lvwifi`](https://wiki.lineageos.org/devices/gts4lvwifi/), section "Special boot modes"; wording confirmed verbatim by [Verizon's Galaxy Tab S5e knowledge base](https://www.verizon.com/support/knowledge-base-226706/) |
| **Download / Odin / bootloader (fastboot)** | with the USB cable **already plugged in**, hold **Volume Up + Volume Down + Power** | [LineageOS wiki `gts4lv`](https://wiki.lineageos.org/devices/gts4lv/) and [`gts4lvwifi`](https://wiki.lineageos.org/devices/gts4lvwifi/), "Special boot modes"; also repeated on the wiki's [installation page](https://wiki.lineageos.org/devices/gts4lv/install/) |
| Forced restart (both volume keys soft-reset it) | hold **Volume Down + Power** until the screen goes black, then **Volume Up + Power** for recovery | [README.md](README.md) lines 161-162 and 202 |

Notes:

- Both are **non-destructive**: entering either mode erases nothing.
- In download mode the tablet shows a big red/blue warning screen; press **Volume Up** to continue.
  In recovery the volume keys move, **Power/Side** selects, exactly as on a phone.
- If *Vol Up + Power* from powered off boots stock instead, you flashed the recovery over it and
  stock replaced it ([README.md](README.md) line 161). Not a crash; re-flash the recovery.
- Download mode is where `Device unlock mode` / `Unlock the bootloader` lives. Choosing it
  **erases all userdata** — see [7](#7-recovery-actions-that-erase-data-last-resort-only).
- `adb reboot recovery` and `adb reboot bootloader` are the keyboard equivalents and need no
  buttons at all. From download mode, Odin/samloader uses USB, while `adb reboot bootloader` gives
  a real fastboot where `fastboot devices` and `fastboot flashing getvar product` work.
- Confidence: **high** for both combinations. Both are quoted verbatim from the official LineageOS
  device pages for these two codenames, which returned HTTP 200 with that text on 2026-10-03, and
  they match `README.md` lines 121-123 already in this repo. The recovery combination is
  independently confirmed by a carrier support page for the same model. The only thing I could not
  check is a Samsung-official page: `www.samsung.com` article URLs I tried did not resolve (one
  404, one landed on an unrelated "Mobile Accessories" article), and `xdaforums.com` and
  `samfw.com` both return 403 from this machine, so no XDA or SamFw citation is made here.

### 7. Recovery actions that erase data (last resort only)

⚠️ None of the following is part of collecting logs. Each one destroys data and can leave the
tablet unbootable. Collect §1-§5 **first**, every time, because each of these either wipes the RAM
holding pstore or the `/data` partition holding tombstones and dropbox.

⚠️ **Factory reset / *Wipe data* in recovery — erases every file on internal storage, and on a
Galaxy Tab S5e that also trips the encrypted-storage state.** Recovery → *Factory reset → Wipe
data*. Only for a tablet that boots but is unusable, or that you have already re-imaged.

⚠️ **`fastboot -w` / wiping in fastboot — erases userdata and cache, so it also destroys
`/data/tombstones`, `/data/anr` and dropbox.** Use it only when a build will not boot because the
old `/data` is from a different Android version. Recovery's *Format data* is the gentler equivalent
and is what a LineageOS install normally wants.

⚠️ **Flashing any partition (`fastboot flash`, `samloader flash`, or the LineageOS installer) —
wrong image or a cable dropping mid-write can leave the tablet unbootable, and the LineageOS
installer refuses to flash over data signed with different keys.** Full install procedure, with the
per-step warnings, is in [README.md](README.md) §"Installing / upgrading" — deliberately not
duplicated here. `recovery.img` and `vbmeta.img` must match the codename
(`gts4lvwifi` vs `gts4lv`).

⚠️ **Unlocking the bootloader in download mode — Samsung erases all userdata as part of the unlock,
permanently trips Knox, and voids the warranty.** Only once per tablet, at the start of the project
([README.md](README.md) step A2).

Ordering rule that matters most: **collect pstore (§2) before you run anything in this section.**

### What to attach to a bug report

Minimum useful set, in this order, named so it is obvious which is which:

```
<date>/logcat.txt        from adb logcat -b all -d          (§1)
<date>/pstore.txt        from /sys/fs/pstore/console-ramoops*  (§2)
<date>/dmesg.txt         from adb shell dmesg              (§3)
<date>/tombstone_*.txt   native crashes                     (§4)
<date>/dropbox.txt       ANRs and system crashes            (§4)
<date>/repro.md          what you did, what you expected, what happened,
                         and whether it is 100% or 1-in-20
```

Two free extras that cost nothing and are worth adding:

```bash
adb shell getprop | sort > getprop.txt     # build fingerprint, ro.bpf.kver_override, selinux
adb shell su -c 'uptime' >> getprop.txt
```

- **`adb bugreport` (read-only, bundles most of the above into one zip)** is a convenience, not a
  requirement: run it while the tablet is still in its crashed state, before doing anything else.
  It is large, and it is not needed if the individual commands above already worked.
- Say in the report whether the build is a self-built 23.2 or official 22.2, and whether the tablet
  is `gts4lvwifi` or `gts4lv`. Different keys and different vendor blobs produce completely
  different failures, and it is the first question anyone will ask.

### Verified sources

Every URL below was fetched with
`curl -s -o /dev/null -w '%{http_code}' --max-time 25 -L` on **2026-10-03** and returned 200 with
the content described. Nothing here is cited from memory.

| Source | Used for | HTTP |
|---|---|---|
| <https://wiki.lineageos.org/devices/gts4lv/> | "Special boot modes": recovery and download combinations, LTE model | 200 |
| <https://wiki.lineageos.org/devices/gts4lvwifi/> | same, Wi-Fi model (`gts4lvwifi`) | 200 |
| <https://wiki.lineageos.org/devices/gts4lv/install/> | repeats the download-mode combination | 200 |
| <https://www.verizon.com/support/knowledge-base-226706/> | independent, model-specific confirmation of *Vol Up + Power* for recovery (10-15 s) | 200 |
| <https://docs.kernel.org/admin-guide/ramoops.html> | what ramoops/pstore is and why the log survives a reboot (kernel docs) | 200 |
| [`gts4lvwifi_defconfig:767-775` @ `a30605a54f3b`](https://github.com/anton-scholten/android_kernel_samsung_sdm670/blob/a30605a54f3b/arch/arm64/configs/gts4lvwifi_defconfig#L767-L775) | `CONFIG_PSTORE`, `CONFIG_PSTORE_CONSOLE`, `CONFIG_PSTORE_PMSG`, `CONFIG_PSTORE_RAM`, `CONFIG_PANIC_TIMEOUT=5` | 200 |
| [`gts4lv_defconfig:769-777` @ `a30605a54f3b`](https://github.com/anton-scholten/android_kernel_samsung_sdm670/blob/a30605a54f3b/arch/arm64/configs/gts4lv_defconfig#L769-L777) | same for the LTE model | 200 |
| [`fs/pstore/inode.c:329,340-346` @ `a30605a54f3b`](https://github.com/anton-scholten/android_kernel_samsung_sdm670/blob/a30605a54f3b/fs/pstore/inode.c#L344-L346) | file naming `console-ramoops-0` / `dmesg-ramoops-0.enc.z`, mode `0444` | 200 |
| [`fs/pstore/ram.c:148-149,219-221,280-284,397` @ `a30605a54f3b`](https://github.com/anton-scholten/android_kernel_samsung_sdm670/blob/a30605a54f3b/fs/pstore/ram.c) | backend name `ramoops`, single console zone, each panic overwrites the last | 200 |
| <https://developer.android.com/studio/command-line/adb> | `adb` reference for the commands used here | 200 |
| <https://developer.android.com/tools/releases/platform-tools> | where to get `adb` | 200 |

Not reachable from this machine, and therefore **not cited**: `xdaforums.com` (403),
`samfw.com` (403), and the `www.samsung.com` support-article URLs I tried (404, or an unrelated
article). `wiki.lineageos.org` **is** reachable, so
[HANDOVER.md](HANDOVER.md) §"Rebuilding the working environment" (line 51) may want updating.

### Confidence

| Claim | Confidence | Reason |
|---|---|---|
| Recovery = Vol Up + Power, powered off | **high** | quoted verbatim from two LineageOS device pages (200), plus a carrier page for the same model; matches `README.md` |
| Download mode = USB plugged in + Vol Up + Vol Down + Power | **high** | quoted verbatim from both LineageOS device pages and their install page (200); matches `README.md` |
| `/sys/fs/pstore/console-ramoops*` is the right path on our kernel | **high** | config lines and the file-name construction read directly from `a30605a54f3b` |
| Only the most recent panic is kept | **high** | `fs/pstore/ram.c` read directly at that commit |
| `dmesg` needs root on these builds | **medium** | depends on `kernel.dmesg_restrict` and SELinux in the built image; documented as "try plain, fall back to `su -c`" rather than asserted |
| `adb bugreport` bundles the above into one zip | **low** | not run against a real device here (no tablet attached); offered as a convenience only, nothing depends on it |
| Exact `logcat` buffer names on Android 16 | **medium** | `main`, `system`, `radio`, `events`, `crash`, `kernel` have been stable for years, but the Android 16 list was not checked against the 23.2 source |

## Problems

None. Two notes for the lead:

1. `wiki.lineageos.org` is reachable from this machine (HTTP 200), contrary to the block list in
   [HANDOVER.md](HANDOVER.md) line 51 and the task brief. `xdaforums.com` and `samfw.com` are not
   (403), which is consistent with the brief. The block list may be worth re-testing before the
   next round of agents relies on it.
2. `www.samsung.com` support articles could not be located by direct URL guessing, so there is no
   Samsung-official citation for the button combinations. The LineageOS wiki is the primary source
   instead, and it is device-specific, so this is not a real gap.
