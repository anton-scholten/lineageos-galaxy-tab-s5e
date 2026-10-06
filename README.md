# LineageOS 23.2 for Galaxy Tab S5e (SM-T720 `gts4lvwifi`, SM-T725/T727 `gts4lv`)

Work-in-progress, unofficial port of LineageOS 23.2 (Android 16) to the Samsung Galaxy
Tab S5e, both Wi-Fi and LTE models. Officially, LineageOS supports these tablets only up to **22.2**
(Android 15).

## Status (2026-10-05)

| Part | State |
|---|---|
| Kernel backport | **Done.** 2,458 commits of the ExyHyperBrick 4.9 eBPF series ported onto the Tab S5e kernel (eBPF at Linux 5.15 level, `close_range`, `epoll_pwait2`, …). Reviewed, and it builds `Image.gz-dtb` for both models. Fork: [android_kernel_samsung_sdm670 `lineage-23.2`](https://github.com/anton-scholten/android_kernel_samsung_sdm670/tree/lineage-23.2) |
| Device tree | **Done for the build.** 6 commits on [android_device_samsung_gts4lv-common `lineage-23.2`](https://github.com/anton-scholten/android_device_samsung_gts4lv-common/tree/lineage-23.2) |
| ROM, Wi-Fi (`gts4lvwifi`) | **Built** (`lineage-23.2-20261005-UNOFFICIAL-gts4lvwifi.zip`), **not booted yet** |
| ROM, LTE (`gts4lv`) | Not built yet. Same kernel and common tree, so it should follow the Wi-Fi model |
| Known gaps | Screen casting (Wi-Fi Display) won't work: an old Samsung library no longer matches Android 16. ANT+ is gone. LTE: no VoLTE/VoWiFi |

**There is no download yet.** Nobody has booted 23.2 on this tablet. Flashing it now is a test, not an upgrade.
For daily use, stay on (or install) **official LineageOS 22.2**. Progress: [HANDOVER.md](HANDOVER.md).

## Prior work this port is built on

None of this would be possible without these projects. Full survey: [PRIOR-WORK.md](PRIOR-WORK.md).

| Project | Author | What we used |
|---|---|---|
| [ExyHyperBrick/android_kernel_samsung_exynos9810](https://github.com/ExyHyperBrick/android_kernel_samsung_exynos9810) | Mathias Gluszczynski (krazey) | **The kernel backport.** Its `lineage-22.2..lineage-23.2` series (Galaxy S9, also Linux 4.9.337) was cherry-picked with `-x`, keeping every original author. Backup: [our fork](https://github.com/anton-scholten/android_kernel_samsung_exynos9810) |
| [ExyHyperBrick/android_device_samsung_exynos9810-common](https://github.com/ExyHyperBrick/android_device_samsung_exynos9810-common) | krazey | Reference for the 4.9-specific 23.2 device changes, e.g. `ro.bpf.kver_override=5.15.178` |
| [LineageOS gts4lv trees](https://github.com/LineageOS/android_device_samsung_gts4lv-common) (`gts4lv-common`, `gts4lv`, `gts4lvwifi`) and [kernel](https://github.com/LineageOS/android_kernel_samsung_sdm670) | LineageOS maintainers | The 22.2 base that our forks start from |
| [LineageOS sm7125-common](https://github.com/LineageOS/android_device_samsung_sm7125-common) and [sm7125 kernel](https://github.com/LineageOS/android_kernel_samsung_sm7125) | LineageOS (basamaryan and others) | Reference for the official Samsung Qualcomm 22.2 → 23.2 changes |
| [LineageOS hardware/samsung](https://github.com/LineageOS/android_hardware_samsung) | LineageOS | Samsung HALs (used as-is, `lineage-23.2`) |
| [TheMuppets vendor blobs](https://github.com/TheMuppets/proprietary_vendor_samsung_gts4lv-common) | TheMuppets | Proprietary Samsung/Qualcomm files (used as-is) |
| [luk1337/gts4lv-fw](https://github.com/luk1337/gts4lv-fw/releases) | luk1337 | Stock Android 11 firmware images for the install steps |
| [Doze-off/fuck-bpf](https://github.com/Doze-off/fuck-bpf), [duckyduckG 4.19 kernel](https://github.com/duckyduckG/android_kernel_xiaomi_sdm845_419) | | Studied as alternatives; not used |

Licences: kernel GPL-2.0, device trees Apache-2.0. Ask krazey before publishing builds.

## Which models?

All models share the SDM670 chip and one kernel. Find your model number on the back, or under *Settings → About tablet*.

| Model | Type | Codename | Latest stock firmware (Android 11) |
|---|---|---|---|
| SM-T720 | Wi-Fi (global/US) | `gts4lvwifi` | T720XXS3DWA1 |
| SM-T720N | Wi-Fi (Korea) | `gts4lvwifi` | latest Android 11 for T720N |
| SM-T725 | LTE (global) | `gts4lv` | T725XXS3DWA1 |
| SM-T725C | LTE (China) | `gts4lv` | T725CZCS3DWA1 |
| SM-T725N | LTE (Korea) | `gts4lv` | T725NKOS3DWA1 |
| SM-T727 | LTE (T727 / U / V / R4) | `gts4lv` | T727JXS3DWA1 / T727UUES4DVI1 / T727VVRS4DVI3 / T727R4TYS4DVI2 |

> ⚠️ **US carrier models (SM-T727U/V/R4/A)** often have no *OEM unlock* switch. If *Developer options* has none,
> LineageOS can't be installed. For the SM-T727V there is an unchecked
> [XDA conversion guide](https://xdaforums.com/t/guide-convert-sm-t727v-to-sm-t725-unlock-bootloader-install-lineageos-22-2.4760328/post-90293075). It is risky.

**Wi-Fi vs LTE: the only differences**

| | Wi-Fi (`gts4lvwifi`) | LTE (`gts4lv`) |
|---|---|---|
| Files | `…-gts4lvwifi.zip`, its `recovery.img`, `vbmeta.img` | `…-gts4lv.zip`, its `recovery.img`, `vbmeta.img`. ⚠️ **Never mix codenames**: the wrong recovery may not boot |
| Stock firmware update (only if needed) | `samloader flash --AP AP_*.tar.md5 --BL BL_*.tar.md5` | Add the modem: `… --CP CP_*.tar.md5`. Use **your exact model's** firmware: CP is region-specific |
| Google Apps (only if you had them) | [MindTheGapps 16.0.0 **ARM64**](https://github.com/MindTheGapps/16.0.0-arm64/releases/latest) — sideloaded **in recovery, before the first reboot** | Same file. These 23.2 builds are arm64 |
| After install | | Data and SMS work. Calls fall back to 2G/3G (no VoLTE), which may fail where those networks are off |

Firmware: <https://github.com/luk1337/gts4lv-fw/releases> (T720, T725, T725C, T725N, T727). Other models: take the stock OTA before unlocking.

---

## Install / upgrade

> ⚠️ Flashing can brick the tablet and voids the warranty. Unlocking trips Knox for good: Samsung Pay, Secure Folder
> and Samsung Health stop working, even back on stock.

**Pick your path:**

| You are on | Go to | Data |
|---|---|---|
| Samsung stock (One UI) | **Path A** | ⚠️ **Always erased** |
| Official LineageOS 22.2 | **Path B** | ⚠️ **Erased** (23.2 builds here are unofficial, signed with other keys) |
| Your own 22.2 build, same signing keys as your 23.2 build | **Path B**, keep-data option | Kept (back up anyway) |
| LineageOS 22.2 **with Google Apps** | **Path B**, incl. the MindTheGapps step | ⚠️ **Erased**, and you must reinstall GApps |

**You need:** a PC with `adb`, a good USB-C cable, battery above 50%, and the files for **your codename**
(see the table above).

### Install the tools

**Debian / Ubuntu:**

```bash
sudo apt install -y adb fastboot usbutils
```

`samloader` is **only needed if a path below tells you to flash the recovery or vbmeta yourself** — not for a plain
sideload. It is a standalone Rust binary, **not** a pip or apt package. Download and unpack it:

```bash
mkdir -p ~/bin && cd ~/bin
curl -LO https://github.com/topjohnwu/samloader-rs/releases/download/2.2.0/samloader-v2.2.0-linux-x86_64.zip
unzip -o samloader-v2.2.0-linux-x86_64.zip && chmod +x samloader
export PATH="$HOME/bin:$PATH"      # so you can just type "samloader"
```

Grab the `linux-x86_64` build (3.4 MB) on an ordinary PC; there are also `linux-aarch64`, `macos-universal`,
`windows-x86_64` and `windows-aarch64` builds. Newer versions are listed on the
[releases page](https://github.com/topjohnwu/samloader-rs/releases/latest).

**Heimdroid is not an alternative** — it is not in Debian and also needs Java installed. **Odin is Windows-only.**
And `fastboot` from the `fastboot` package **does not work on Samsung**: the bootloader speaks Samsung's own
Download Mode protocol, which is the entire reason samloader, heimdroid and Odin exist.

**Buttons:** Download mode = power off, plug in USB, hold *Vol Up + Vol Down + Power*. Recovery = power off, hold *Vol Up + Power*.

### Back up first (all paths)

1. Files: `adb pull /sdcard/ ./tablet-backup/`, or copy them over USB.
2. Apps: Smart Switch or Google backup on stock; *Settings → System → Backup* (Seedvault) on LineageOS.
3. Have your Google password and 2FA codes ready.
4. ⚠️ **Remove all Google accounts from the tablet first** (or be ready to enter them during setup). After a
   factory reset, Factory Reset Protection locks the setup wizard behind the previous account's credentials.
   This is in the official install guide's basic requirements and it is the most common cause of a stuck setup.

### Path A: from Samsung stock

> **Recommended while 23.2 is untested:** do Path A with the **official 22.2** files (links at the end of this
> section), check that 22.2 works, then do Path B. If the 23.2 recovery fails, you can flash 22.2's back.

1. **Update stock to the latest Android 11:** *Settings → Software update*. Data kept.
   LTE: this also updates the modem (CP) firmware, which LTE needs.
2. **Unlock the bootloader.** ⚠️ **Erases all data.**
   1. Connect to Wi-Fi. Tap *Settings → About tablet → Software information → Build number* 7×.
   2. *Developer options → OEM unlock*: on.
   3. Boot to Download mode, choose *Device unlock mode*, confirm. The tablet wipes itself.
   4. Set it up again, re-enable Developer options, check *OEM unlock* is still on.
3. **Disable verified boot.** ⚠️ **Forces another factory reset.**
   In Download mode: `samloader flash --partition VBMETA vbmeta.img`, then accept the reset.
4. **Flash Lineage Recovery.** In Download mode: `samloader flash --partition RECOVERY recovery.img --no-reboot`.
   When the transfer finishes, the screen keeps saying *Downloading…*. That is normal.
   **Unplug USB**, hold *Vol Down + Power* until the screen goes black, release, then go **straight** to recovery with
   *Vol Up + Power*. If stock boots first, it overwrites the recovery: repeat this step.
5. **Install.** ⚠️ **Erases all data.**
   1. Recovery: *Factory reset → Format data / factory reset*.
   2. *Apply update → Apply from ADB*, then `adb -d sideload lineage-23.2-*.zip`.
   3. Optional: sideload Android 16 GApps now, before the first boot. Adding them later needs another wipe.
6. *Reboot system now*. First boot can take 5–10 min. Restore your backup.

To install official 22.2 instead, use the same steps with the files from
<https://download.lineageos.org/devices/gts4lvwifi> (Wi-Fi) or <https://download.lineageos.org/devices/gts4lv> (LTE).

### Path B: from LineageOS 22.2

The built-in Updater can't do a major upgrade, so you sideload. The Samsung firmware is already right; don't touch it.

⚠️ **Coming from official 22.2, your data will be erased.** Official builds use LineageOS's keys and these builds don't.
Android won't boot the old data. Keeping data is only possible between builds signed with the same keys, **and** with
the same GApps state (had GApps → sideload Android 16 GApps; had none → add none).

1. Update 22.2 to its last build (*Settings → System → Updater*) and back up.
2. Enable *Developer options → USB debugging*, then run `adb -d reboot download`.
3. **Flash the 23.2 recovery. This is required:** the 22.2 recovery **can't** install 23.2. Android 16's installer needs a
   kernel feature (`MADV_WIPEONFORK`) that 22.2's kernel lacks, so it aborts with *"killed by signal 6"*.
   Take `recovery.img` from your 23.2 build, then `samloader flash --partition RECOVERY recovery.img --no-reboot`.
   **Unplug USB**, hold *Vol Down + Power* until black, release, then *Vol Up + Power*. Check it says **version 23.2**.
   - ⚠️ **The 20261005 build is broken:** its recovery and system can't boot. Use a build with kernel `500658be3c16`
     or later (fixed 2026-10-06). The 23.2 recovery from such a build boots.
   - `vbmeta` was already done when you unlocked for 22.2. Don't flash it again.
4. **Wipe.** ⚠️ **Erases all data.** *Factory reset → Format data / factory reset*.
   Skip this only in the same-keys, same-GApps case.
5. *Apply update → Apply from ADB*, then `adb -d sideload lineage-23.2-*.zip`.
6. **If you had Google Apps, reinstall them — in recovery, before the first reboot.**
   Still in recovery after step 5, *Apply update → Apply from ADB*:
   [MindTheGapps for LineageOS 23 / Android 16, ARM64](https://github.com/MindTheGapps/16.0.0-arm64/releases/latest).
   *"Signature verification failed"* is normal here: choose *Yes*.

   ⚠️ **Do not reboot into the new LineageOS before the GApps are in.** The LineageOS wiki is explicit: reboot
   first and you must factory reset and install them again, otherwise expect crashes.

   If you had **no** Google Apps before, skip this and add none later — the two states have to match.
7. *Reboot system now*. The official guide allows up to **15 minutes** for the first boot. If it takes longer, something is wrong. Collect logs ([TESTING.md](TESTING.md)).
   ⚠️ `adb sideload` stopping at **47%** with `adb: failed to read command: Success` is **normal** and still
   succeeds — that is a known quirk, not a failure.

**Bootloop?** Boot to recovery, ⚠️ *Factory reset → Format data* (**erases all data**), sideload the zip again.

**Back to 22.2?** Path A, steps 4–6 with the 22.2 files. ⚠️ Downgrading always erases data.

### Stuck in Download mode?

Download mode shows a blue/cyan screen with *"Downloading… Do not turn off target"*. It's harmless: nothing is being written unless a PC tool is flashing.

1. **Unplug the USB cable.** Download mode is *Vol Up + Vol Down + Power* **with USB plugged in**. When you slide from
   *Vol Down* to *Vol Up* with the cable still in, you are briefly holding all three buttons, so you land straight back in Download mode.
2. Hold *Vol Down + Power* for 8–10 s until the screen goes black. **Release immediately.**
3. Then either:
   - do nothing, and the tablet boots the installed system; or
   - press *Vol Up + Power* right away (only those two, USB still unplugged) to boot recovery.
     Release when the logo appears.
4. If it keeps coming back to Download mode on its own, read the small text at the top-left and any **red** text
   (for example *"SECURE CHECK FAIL: recovery"*). Report it. Also tell whether the screen says **"Upload mode"** or
   **"RAMDUMP"** rather than *Downloading*: that means a kernel crash, not a flashing problem.
   To get back to a working state, flash the **22.2** `recovery.img` from
   <https://download.lineageos.org/devices/gts4lvwifi> (LTE: `gts4lv`) with
   `samloader flash --partition RECOVERY recovery.img --no-reboot`. Then repeat steps 1–3.


---

## Building (developers)

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --no-clone-bundle
mkdir -p .repo/local_manifests
cp <this repo>/local_manifests/gts4lv-common.xml .repo/local_manifests/
cp <this repo>/local_manifests/gts4lvwifi.xml .repo/local_manifests/   # LTE: gts4lv.xml
repo sync -c -j$(nproc)
source build/envsetup.sh && brunch gts4lvwifi   # LTE: brunch gts4lv
```

The build outputs `lineage-23.2-*-UNOFFICIAL-<codename>.zip`, `recovery.img`
and `vbmeta.img` to `out/target/product/<codename>/`.

Needs ~300 GB disk and 16 GB+ RAM (32 GB recommended). Install `git-lfs` **before** `repo sync`. Full recipe: [analysis/port/BUILD-HANDOFF.md](analysis/port/BUILD-HANDOFF.md).

## Repo contents

| Path | What |
|---|---|
| `HANDOVER.md` | **Start here when picking the project up:** state, plan of remaining work, environment setup |
| `RUNBOOK.md` | Owner's step-by-step for finishing the port with the free model: setup, order, copy-paste prompts, checks |
| `LEAD-SYNTHESIS.md` | Findings from the helper-agent research (must-fix items, risks), reviewed |
| `TESTING.md` | How to collect crash logs from the tablet |
| `PORTING-LINEAGE-23.2.md` | Analysis: kernel blocker, required changes, work order |
| `KERNEL-BACKPORT-PLAN.md` | Plan, in phases, for the kernel work that unblocks 23.2, and why it takes time |
| `PRIOR-WORK.md` | Work other people have done online that can be reused |
| `ESTIMATE.md` | Time estimate built from measured conflict sizes and a real kernel build test |
| `WORKLOG.md` | Record of all work done so far, including blocked or failed steps |
| `CLAUDE.md` | Short guide for Claude sessions working in this repo |
| `AGENTS.md` | Entry point for helper AI agents (OpenCode, Codex, …); points to `AGENT-TASKS.md` |
| `AGENT-TASKS.md` | Parallel research tasks for helper agents: steps, templates, prerequisites, model per task |
| `REPO-SETUP.md` | All repos (this one, the forks, the backups), which branch to use, and how to attach them to a Claude session |
| `analysis/exyhyperbrick-trial/` | Trial port of the Galaxy S9 4.9 eBPF kernel series onto the Tab S5e kernel, and conflict classification |
| `analysis/build-test/` | Kernel build test: baseline vs. port tree |
| `analysis/reference-trees/` | Device trees that already did 23.2 (sm7125-common, exynos9810-common), and their commit lists |
| `analysis/agent-batches/` | The conflict commits split into batches for helper agents |
| `analysis/conflicts/` | One brief per conflicting series commit, with a proposed resolution |
| `analysis/upstream-map/`, `api-audit/`, `defconfig/`, `rom/`, `build-test/errors/` | Helper research: upstream origin of each commit, driver API audit, defconfig fragment, ROM-side audits, first build errors |
| `analysis/tools/` | Stacked-replay scripts for inspecting a conflict the way an in-order cherry-pick sees it |
| `scripts/` | `check-agent-output.sh` (report format), `check-pins.sh` (pinned commits), `device-checks.sh` (on-device checks) |
| `local_manifests/gts4lv-common.xml` + `gts4lvwifi.xml` / `gts4lv.xml` | Repos to add to a `lineage-23.2` source tree (they point at our forks) |
| `patches/` | Record of the device-tree changes. They're already committed to the fork's `lineage-23.2` branch, so you don't need to apply them |

## License

The patches and scripts here modify LineageOS device trees, which are
licensed under the Apache License 2.0 (LineageOS's standard license for its own
code). This repository uses the same license, see [LICENSE](LICENSE).

Kernel patches, if added later, must stay under **GPL-2.0** like the Linux
kernel. GPL-3.0 is not compatible with the kernel's GPL-2.0-only license.

## References

- Device wiki: <https://wiki.lineageos.org/devices/gts4lvwifi/> (Wi-Fi), <https://wiki.lineageos.org/devices/gts4lv/> (LTE)
- Install guides: <https://wiki.lineageos.org/devices/gts4lvwifi/install/>, <https://wiki.lineageos.org/devices/gts4lv/install/>
- Firmware images: <https://github.com/luk1337/gts4lv-fw/releases>
- XDA forum: <https://xdaforums.com/c/samsung-galaxy-tab-s5e.9164/>
