# LineageOS 23.2 for Galaxy Tab S5e (SM-T720 `gts4lvwifi`, SM-T725/T727 `gts4lv`)

Work-in-progress port of LineageOS 23.2 (Android 16) to the Samsung Galaxy
Tab S5e, both Wi-Fi and LTE models. Officially, LineageOS supports these tablets only up to **22.2**
(Android 15).

## Will the tablet run LineageOS 23.2?

**Not yet.** The SoC and userspace are fine, and the device-tree changes are
in [`patches/`](patches/). The blocker is the kernel. Android 16 needs eBPF
features from Linux 5.4, and the tablet runs Linux 4.9. LineageOS only ships 23.x
on old kernels after they get a full eBPF backport (~1000+ commits) plus the
`close_range` and `epoll_pwait2` syscalls. No official LineageOS 4.9 kernel has this,
which is why every 4.9 Qualcomm device is still on 22.2. However, the community
Galaxy S9 kernel by ExyHyperBrick (also 4.9.337) has done it, and 94% of its
commits apply cleanly to the Tab S5e kernel
([trial](analysis/exyhyperbrick-trial/README.md)). Porting it is estimated at
about **7 weeks of full-time work** for the whole port
(range 4–11 weeks; about 5 months at hobby pace). See [ESTIMATE.md](ESTIMATE.md).

- Without the backports, a 23.2 build compiles but **will not boot**
  (bpfloader/netd fail).
- With the backports, it should run normally. The port is then unofficial,
  and you install builds you made yourself.

Details are in [PORTING-LINEAGE-23.2.md](PORTING-LINEAGE-23.2.md). The step-by-step plan to fix the kernel
is in [KERNEL-BACKPORT-PLAN.md](KERNEL-BACKPORT-PLAN.md).

There is no downloadable 23.2 build. Until the kernel work is done, the best
option for this tablet is **official LineageOS 22.2**.

## Repo contents

| Path | What |
|---|---|
| `PORTING-LINEAGE-23.2.md` | Analysis: kernel blocker, required changes, work order |
| `patches/device/samsung/gts4lv-common/` | Device tree patches against `lineage-22.2` |
| `KERNEL-BACKPORT-PLAN.md` | Plan, in phases, for the kernel work that unblocks 23.2, and why it takes time |
| `PRIOR-WORK.md` | Work other people have done online that can be reused |
| `ESTIMATE.md` | Time estimate built from measured conflict sizes and a real kernel build test |
| `WORKLOG.md` | Record of all work done so far, including blocked or failed steps |
| `REPO-SETUP.md` | Review of this repo's name and layout, and the recommended setup |
| `analysis/exyhyperbrick-trial/` | Trial port of the Galaxy S9 4.9 eBPF kernel series onto the Tab S5e kernel, and conflict classification |
| `analysis/build-test/` | Kernel build test: baseline vs. port tree |
| `local_manifests/gts4lv-common.xml` + `gts4lvwifi.xml` / `gts4lv.xml` | Repos to add to a `lineage-23.2` source tree |
| `apply-patches.sh` | Applies the patches (skips the BPF override unless `--with-bpf-override`) |

## Building (developers)

```bash
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --no-clone-bundle
mkdir -p .repo/local_manifests
cp <this repo>/local_manifests/gts4lv-common.xml .repo/local_manifests/
cp <this repo>/local_manifests/gts4lvwifi.xml .repo/local_manifests/   # LTE: gts4lv.xml
repo sync -c -j$(nproc)
<this repo>/apply-patches.sh "$PWD"          # add --with-bpf-override once the kernel is backported
source build/envsetup.sh && breakfast gts4lvwifi && mka bacon   # LTE: breakfast gts4lv
```

The build outputs `lineage-23.2-*-UNOFFICIAL-<codename>.zip`, `recovery.img`
and `vbmeta.img` to `out/target/product/<codename>/`.

---

## Which Tab S5e models can be upgraded?

All of them use the same chip (SDM670) and the same kernel. Once the kernel
work is done, **every model LineageOS supports today can run 23.2**. The LTE
model gets the same common patches. Its own device tree needs no further
changes, apart from checking the RIL/FCM level (see the plan).

| Model | Variant | Codename | Latest stock (Android 11) firmware |
|---|---|---|---|
| SM-T720 | Wi-Fi (global/US) | `gts4lvwifi` | T720XXS3DWA1 |
| SM-T720N | Wi-Fi (Korea) | `gts4lvwifi` | latest Android 11 for T720N |
| SM-T725 | LTE (global) | `gts4lv` | T725XXS3DWA1 |
| SM-T725C | LTE (China) | `gts4lv` | T725CZCS3DWA1 |
| SM-T725N | LTE (Korea) | `gts4lv` | T725NKOS3DWA1 |
| SM-T727 | LTE (T727 / T727U / T727V / T727R4) | `gts4lv` | T727JXS3DWA1 / T727UUES4DVI1 / T727VVRS4DVI3 / T727R4TYS4DVI2 |

> ⚠️ **US carrier models (SM-T727U/V/R4/A).** Samsung often ships US carrier
> devices **without an "OEM unlock" switch**. The LineageOS tree includes Wi-Fi
> firmware for these models, which suggests some of them can be unlocked. Check
> *Developer options* first: **if there is no "OEM unlock" switch, LineageOS can't
> be installed on that tablet at all**, whatever the version.
> For the **SM-T727V** (Verizon), XDA has a [guide to convert it to SM-T725 and unlock it](https://xdaforums.com/t/guide-convert-sm-t727v-to-sm-t725-unlock-bootloader-install-lineageos-22-2.4760328/post-90293075).
> I haven't checked it. Converting firmware is risky, so read the whole thread first.

The model number is on the back of the tablet, or under *Settings → About tablet*.

### How the steps differ between models

The steps below are the same for every model, except for these points:

| Step | Wi-Fi (`gts4lvwifi`) | LTE (`gts4lv`) |
|---|---|---|
| Files to download / build | `…-gts4lvwifi.zip`, its `recovery.img` and `vbmeta.img` | `…-gts4lv.zip`, its `recovery.img` and `vbmeta.img`. **Never mix the two codenames**: the installer refuses the wrong one, and a recovery built for the other codename may not boot |
| Updating Samsung firmware from recovery | `samloader flash --AP AP_*.tar.md5 --BL BL_*.tar.md5` | Also flash the modem: `samloader flash --AP AP_*.tar.md5 --BL BL_*.tar.md5 --CP CP_*.tar.md5` |
| Required firmware | Latest Android 11 for **your exact model** (table above). | Same. Use your model's own build, because the CP (modem) firmware is region-specific |
| Mobile data / calls | n/a | Data and SMS work. **VoLTE/VoWiFi (IMS) isn't supported** ("ims" quirk on the wiki), so calls fall back to 2G/3G, which may not work where those networks have been shut down |

Firmware images: <https://github.com/luk1337/gts4lv-fw/releases> (T720, T725,
T725C, T725N, T727). For other models, get the latest Android 11 through the stock
OTA *before* unlocking.

---

## Installing / upgrading

> ⚠️ **WARNING:** flashing custom firmware can brick the device and voids the
> Samsung warranty. Unlocking the bootloader permanently trips Knox, so Samsung
> Pay, Secure Folder and Samsung Health stop working, even after going back to stock.

**Tools:** a PC with [`adb`](https://developer.android.com/tools/releases/platform-tools)
and [`samloader-rs`](https://github.com/topjohnwu/samloader-rs/releases/latest),
a good USB-C cable, and battery above 50%.

**Button combos:**
- **Download mode:** power off, plug in USB, then hold *Vol Up + Vol Down + Power*.
- **Recovery:** power off, then hold *Vol Up + Power*.

### Back up first (everyone)

Every path below either can lose data or will lose data. Before you start:

1. Copy your files to a PC: `adb pull /sdcard/ ./tablet-backup/` (or use USB file transfer).
2. Back up your apps:
   - **On stock Android:** use Samsung Smart Switch or Google backup.
   - **On LineageOS:** use the built-in *Settings → System → Backup* (Seedvault) to a USB stick or microSD.
3. Make sure you know your Google account password and have 2FA codes available.

### A. From the original Samsung Android (stock One UI)

The last official Samsung release for the SM-T720 is **Android 11 (One UI 3.x)**.
LineageOS requires the **latest Android 11 firmware** as its base.

> ⚠️ **WARNING: Moving from stock to LineageOS always erases all data.**
> Unlocking the bootloader forces a factory reset. Stock and LineageOS
> encryption are also not compatible, so `/data` has to be formatted. Nothing on
> the internal storage survives. Restore from the backup afterwards.

1. **Update stock to the latest Android 11.** Go to *Settings → Software update*
   and install everything offered. This keeps your data.
2. **Unlock the bootloader.** ⚠️ *Erases data.*
   1. Connect to Wi-Fi.
   2. Open *Settings → About tablet → Software information* and tap *Build number* 7× to enable Developer options.
   3. In *Developer options*, enable **OEM unlock**.
   4. Boot into Download mode and choose *Device unlock mode*. Confirm. The tablet wipes itself.
   5. Go through setup again, re-enable Developer options, and check that *OEM unlock* is still on.
3. **Flash `vbmeta.img`** to disable verified boot. ⚠️ *Forces another factory reset.*
   1. Boot into Download mode.
   2. Run `samloader flash --partition VBMETA vbmeta.img`.
   3. Accept the factory reset the tablet asks for.
4. **Flash Lineage Recovery.**
   1. Boot into Download mode.
   2. Run `samloader flash --partition RECOVERY recovery.img --no-reboot`.
   3. Hold *Vol Down + Power* until the screen goes black. Then go **straight**
      into recovery with *Vol Up + Power*. If stock boots first, it replaces the recovery and you must flash it again.
5. **Install LineageOS.** ⚠️ *Erases data.*
   1. In recovery, choose *Factory reset → Format data / factory reset*.
   2. Choose *Apply update → Apply from ADB*.
   3. Run `adb -d sideload lineage-*.zip`.
   4. Optional: sideload Google Apps for the **same Android version** now, before the first boot. You can't add them later without another wipe.
6. Choose *Reboot system now*, then restore your backup.

Until 23.2 is bootable, use the official **22.2** files from
<https://download.lineageos.org/devices/gts4lvwifi> (Wi-Fi) or
<https://download.lineageos.org/devices/gts4lv> (LTE) in these steps. Later you
can move to 23.2 with path B.

### B. From LineageOS 22.2 to 23.2 (major-version upgrade)

The built-in Updater **cannot** do a major-version upgrade, so you have to
sideload. This path **can keep your data ("dirty flash")**, but only if both
of these are true:

- **Same signing keys.** The 23.2 build must be signed with the same keys as
  the 22.2 install. Official 22.2 uses LineageOS's private keys. A
  self-built/unofficial 23.2 uses different keys, and Android refuses to boot
  over existing data signed with the old keys.
  ⚠️ So **official 22.2 to unofficial 23.2 requires a data wipe** (step 5b).
  Data is kept only for official-to-official (if LineageOS ever ships 23.2
  for this tablet) or for your own 22.2 build to your own 23.2 build signed
  with the same keys.
- **Same Google Apps state.** If you had GApps on 22.2, sideload Android 16
  GApps in the same session. Adding or removing GApps needs a wipe.

The firmware requirement (Android 11) is already met on 22.2. Don't downgrade
the Samsung firmware.

Steps:

1. Update 22.2 to its latest build with *Settings → System → Updater*. Data is kept.
2. Back up (see above). Also do this even if you plan to keep your data.
3. Enable *Developer options → USB debugging*. Then run `adb -d reboot download`,
   or boot into Download mode with the buttons.
4. **Flash the 23.2 recovery** (data is kept):
   1. Run `samloader flash --partition RECOVERY recovery.img --no-reboot`.
   2. Hold *Vol Down + Power* until the screen goes black, then hold *Vol Up + Power* to enter recovery.
5. In recovery:
   1. **(a) Keep data:** this only works when the conditions above are met. Do **not** wipe anything.
   2. **(b) Different keys, or changing GApps:** ⚠️ *Erases data.* Choose *Factory reset → Format data / factory reset*.
6. Choose *Apply update → Apply from ADB*, then run `adb -d sideload lineage-23.2-*.zip`.
7. If you use GApps, choose *Apply update → Apply from ADB* again and sideload the Android 16 GApps package **before** rebooting.
   (*"Signature verification failed"* is expected for GApps. Choose *Yes* to continue.)
8. Choose *Reboot system now*. The first boot can take 5–10 minutes.

**If the tablet bootloops after a dirty flash:**
1. Boot into recovery.
2. ⚠️ Choose *Factory reset → Format data*. This *erases data.*
3. Sideload the zip again.

You can always go back to 22.2 with path A's step 5, starting from "Install LineageOS". ⚠️ Downgrading always erases data.

---

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
