Unofficial **LineageOS 23.2 (Android 16)** for the Samsung Galaxy Tab S5e: a full ROM plus a backport of the ExyHyperBrick 4.9 eBPF kernel series.
This is not an official LineageOS build.
Please do not report bugs to the LineageOS team.

| Model | Codename | Status |
|---|---|---|
| SM-T720 / T720N (Wi-Fi) | `gts4lvwifi` | ✅ Works on my SM-T720 |
| SM-T725 / T725C / T725N / T727* (LTE) | `gts4lv` | 🧪 Being tested (see known issues) |

**Coming from 23.2-20261019: update over the air** (*Settings → System → Updater*), no data is erased.
Coming from an older build: ⚠️ this needs a clean install, which erases all data (see 23.2-20261019).

**What's new since 2026-10-19**
- **Firefox no longer crashes when you switch back to it.** Was caused by a kernel bug: when Android compacted the memory of apps in the background, some of it was thrown away instead of saved. Fixed in the kernel.
- **Double tap to wake works.** It was never built into the power service since Android 16.
- *Recent changes* and *Report issues* in the Updater now point to this GitHub.

**Files per model** (never mix codenames):
- `lineage-23.2-20261022-UNOFFICIAL-<codename>.zip`: the ROM you sideload from recovery
- `recovery-20261022-<codename>.img`: the 23.2 recovery for this build
- `vbmeta-20261022-<codename>.img`: only needed when coming from Samsung's stock OS on the first unlock of the bootloader
- `SHA256SUMS`: check your downloads with `sha256sum -c SHA256SUMS --ignore-missing`

**New install:** follow the [install guide](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e#install--upgrade).
Back up your data first.
In short: flash `recovery-20261022-<codename>.img` (samloader/Odin/Heimdall, `RECOVERY`) → ⚠️ *Factory reset → Format data* (also formats `/metadata` on the OMR partition, which Android 16 needs) → *Apply update → Apply from ADB* → `adb sideload` the zip → (optional) sideload [MindTheGapps 16.0.0 arm64](https://github.com/MindTheGapps/16.0.0-arm64/releases/latest) → reboot.

**Bluetooth after a reinstall:** a phone that was paired with the tablet before keeps the old pairing and then refuses ("pairing rejected" / "failed to connect"). *Forget* the tablet on the phone first, then pair again.

**Known issues:** screen casting fixed in the build but not yet confirmed on a receiver; no ANT+; LTE: no VoLTE/VoWiFi, Dolby Atmos reported unreliable on LTE (I need some logs to troubleshoot this one). Bromite shows "Aw, Snap!" on every page: it is no longer maintained and too old for this Android version, use Cromite instead.

**Sources:** [kernel](https://github.com/anton-scholten/android_kernel_samsung_sdm670/tree/lineage-23.2) (GPL-2.0) ·
[device tree](https://github.com/anton-scholten/android_device_samsung_gts4lv-common/tree/lineage-23.2) ·
[vendor](https://github.com/anton-scholten/proprietary_vendor_samsung_gts4lv-common/tree/lineage-23.2) ·
[Bluetooth](https://github.com/anton-scholten/android_packages_modules_Bluetooth/tree/lineage-23.2) ·
[build manifests](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/tree/main/local_manifests)

Kernel `4.9.337-g72f6ca56842c`, device tree `99c0506`, vendor `51de1d4`, Bluetooth `8c6d706e11`.
Fixes that should go upstream are listed in [UPSTREAM.md](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/blob/main/UPSTREAM.md).
Thanks to krazey (ExyHyperBrick), the LineageOS team and gts4lv maintainers, TheMuppets, luk1337, topjohnwu and MindTheGapps.
