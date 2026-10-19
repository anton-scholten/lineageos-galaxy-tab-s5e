Unofficial **LineageOS 24 (Android 17)** for the Samsung Galaxy Tab S5e: a full ROM plus a backport of the ExyHyperBrick 4.9 eBPF kernel series.
This is not an official LineageOS build; please don't report its bugs to the LineageOS team.

| Model | Codename | Status |
|---|---|---|
| SM-T720 / T720N (Wi-Fi) | `gts4lvwifi` | ✅ Works on the developer's SM-T720 |
| SM-T725 / T725C / T725N / T727* (LTE) | `gts4lv` | 🔨 Built, **untested** — testers wanted; mobile data may not work yet (see known issues) |

⚠️ **This build needs a clean install, which erases all data, also when coming from 24.0-20261016 or 23.2.** It is the first build signed with this project's own release keys (earlier builds used the public test keys). From now on, updates arrive **over the air** without wiping.

**What's new since 2026-10-16**
- **Over-the-air updates.** *Settings → System → Updater* now finds new builds of this ROM on GitHub, lists the latest few, and installs the one you pick (on 24 the recovery is updated too). Only builds signed with this project's keys are accepted.
- **App storage fixed.** Apps could not save files to shared storage (e.g. Wallcraft downloads did nothing, Termux showed an empty `/storage`). Cause: a kernel bug in FUSE-BPF stripped the group permissions Android sets on app folders. Fixed in the kernel, and the old sdcardfs path is switched off.
- **Security patch level** 2026-10-01.

**Files per model** (never mix codenames):
- `lineage-24.0-20261019-UNOFFICIAL-<codename>.zip`: the ROM, sideloaded from recovery
- `recovery-20261019-<codename>.img`: the 24 recovery for this build. **Required** for this install (the 22.2/23.2 recoveries can't install 24, and it trusts the new keys)
- `vbmeta-20261019-<codename>.img`: only needed when coming from Samsung stock (first unlock)
- `SHA256SUMS`: check your downloads with `sha256sum -c SHA256SUMS --ignore-missing`

**Install:** follow the [install guide](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e#install--upgrade). Back up your data first.
In short: flash `recovery-20261019-<codename>.img` (samloader/Odin/Heimdall, `RECOVERY`) → ⚠️ *Factory reset → Format data* (also formats `/metadata` on the OMR
partition, which Android 16/17 needs) → *Apply update → Apply from ADB* → `adb sideload` the zip → (optional) sideload [MindTheGapps 17.0.0 arm64](https://github.com/MindTheGapps/17.0.0-arm64/releases/latest) → reboot.
Google apps can only be added before the first boot. In recovery, plain `adb` shows *unauthorized*; that is normal. Use *Apply from ADB* (sideload mode).

**Bluetooth after a reinstall:** a phone that was paired with the tablet before keeps the old pairing and then refuses ("pairing rejected" / "failed to connect"). *Forget* the tablet on the phone first, then pair again.

**Works on SM-T720:** Wi-Fi, Google apps and Google setup, Bluetooth pairing and file transfer, audio, Dolby Atmos, camera, sensors, auto-rotate, app storage, charging indicator and sound, always-on display, PIN lock across reboots.
**Known issues:** screen casting fixed in the build but not yet confirmed on a receiver; no ANT+; LTE: no VoLTE/VoWiFi, and its radio HAL (1.4) is older than Android 17 formally allows, so mobile data on 24 is an open question. The Updater's *Recent changes* and *Report issues* links still point to LineageOS; that changes in the next build.

**LTE testers:** before flashing, run `adb shell ls -l /dev/block/by-name/omr` from any recovery and report the result in [Issues](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/issues).

**Sources** (branch `lineage-24.0`): [kernel](https://github.com/anton-scholten/android_kernel_samsung_sdm670/tree/lineage-24.0) (GPL-2.0) ·
[device tree](https://github.com/anton-scholten/android_device_samsung_gts4lv-common/tree/lineage-24.0) ·
[vendor](https://github.com/anton-scholten/proprietary_vendor_samsung_gts4lv-common/tree/lineage-24.0) ·
[Bluetooth](https://github.com/anton-scholten/android_packages_modules_Bluetooth/tree/lineage-24.0) ·
[build manifests](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/tree/main/local_manifests/24) (also forks system/core, vold, compat and sepolicy_vndr)

Kernel `4.9.337-g7bf5ff571b75`, device tree `be25398`, vendor `1e0cce7`, Bluetooth `11434c8f8a`, system/core `40a6fdb6d`, vold `f8c406d`.
Fixes that should go upstream are listed in [UPSTREAM.md](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/blob/main/UPSTREAM.md).
Thanks to krazey (ExyHyperBrick), the LineageOS team and gts4lv maintainers, TheMuppets, luk1337, topjohnwu and MindTheGapps.
