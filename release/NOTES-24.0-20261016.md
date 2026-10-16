Unofficial **LineageOS 24 (Android 17)** for the Samsung Galaxy Tab S5e: a full ROM plus a backport of the ExyHyperBrick 4.9 eBPF kernel series.
This is not an official LineageOS build; please don't report its bugs to the LineageOS team.
This is the **first 24 build**. If you need a stable tablet, stay on [23.2](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/releases).

| Model | Codename | Status |
|---|---|---|
| SM-T720 / T720N (Wi-Fi) | `gts4lvwifi` | ✅ Works on the developer's SM-T720 (in testing) |
| SM-T725 / T725C / T725N / T727* (LTE) | `gts4lv` | 🔨 Built, **untested** — testers wanted; mobile data may not work yet (see known issues) |

**What's in it**
- Everything in 23.2-20261016: instant charging status, Bluetooth pairing fix, always-on display updates, thermal sensors, tablet defaults (auto-rotate, auto-brightness, device name "Galaxy Tab S5e").
- Android 17 fixes for this 4.9 kernel:
  - **Google apps work**: Play services in MindTheGapps 17 is a compressed EROFS module, which the kernel could not mount, so Google setup hung at "Getting your tablet ready". EROFS added to the kernel.
  - **PIN/password kept after a reboot**: an Android 17 SELinux change stopped the lock screen from checking the PIN.
  - Encryption of `/data` on old kernels (keyring handling Android 17 removed), plus build fixes for the screen-casting shim and SELinux policy.

**Files per model** (never mix codenames):
- `lineage-24.0-20261016-UNOFFICIAL-<codename>.zip`: the ROM, sideloaded from recovery
- `recovery-20261016-<codename>.img`: the 24 recovery for this build. **Required** for a new install: the 22.2 recovery can't install 24
- `vbmeta-20261016-<codename>.img`: only needed when coming from Samsung stock (first unlock)
- `SHA256SUMS`: check your downloads with `sha256sum -c SHA256SUMS --ignore-missing`

**Install (also when coming from 23.2):** ⚠️ **a clean install, which erases all data.** Follow the [install guide](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e#install--upgrade).
In short: flash the 24 recovery (samloader/Odin/Heimdall, `RECOVERY`) → *Factory reset → Format data* (also formats `/metadata` on the OMR
partition, which Android 16/17 needs) → sideload the zip → (optional) sideload [MindTheGapps 17.0.0 arm64](https://github.com/MindTheGapps/17.0.0-arm64/releases/latest) → reboot.
Google apps can only be added before the first boot. Coming from official LineageOS 22.2 or Samsung stock also needs this clean install (different signing keys).

**Bluetooth after a reinstall:** a phone that was paired with the tablet before keeps the old pairing and then refuses ("pairing rejected" / "failed to connect"). *Forget* the tablet on the phone first, then pair again.

**Works on SM-T720:** Wi-Fi, Google apps and Google setup, Bluetooth pairing and file transfer, audio, camera, sensors, auto-rotate, charging indicator and sound, always-on display, PIN lock across reboots.
**Known issues:** screen casting fixed in the build but not yet confirmed on a receiver; no ANT+; LTE: no VoLTE/VoWiFi.
LTE model: its radio HAL (1.4) is older than Android 17 formally allows, so mobile data on 24 is an open question.

**LTE testers:** before flashing, run `adb shell ls -l /dev/block/by-name/omr` from any recovery and report the result.

**Sources** (branch `lineage-24.0`): [kernel](https://github.com/anton-scholten/android_kernel_samsung_sdm670/tree/lineage-24.0) (GPL-2.0) ·
[device tree](https://github.com/anton-scholten/android_device_samsung_gts4lv-common/tree/lineage-24.0) ·
[vendor](https://github.com/anton-scholten/proprietary_vendor_samsung_gts4lv-common/tree/lineage-24.0) ·
[Bluetooth](https://github.com/anton-scholten/android_packages_modules_Bluetooth/tree/lineage-24.0) ·
[build manifests](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/tree/main/local_manifests/24) (also forks system/core, vold, compat and sepolicy_vndr)

Kernel `4.9.337-g230ccf8e8e63`, device tree `702e1fd`, vendor `1e0cce7`, Bluetooth `11434c8f8a`, system/core `40a6fdb6d`, vold `f8c406d`.
Fixes that should go upstream are listed in [UPSTREAM.md](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/blob/main/UPSTREAM.md).
Thanks to krazey (ExyHyperBrick), the LineageOS team and gts4lv maintainers, TheMuppets, luk1337, topjohnwu and MindTheGapps.
