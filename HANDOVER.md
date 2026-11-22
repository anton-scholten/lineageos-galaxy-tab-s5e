# Handover: picking up this project in a new session

Read this first, then the end of [WORKLOG.md](WORKLOG.md) for recent detail (it holds the full history).

## Goal
Unofficial LineageOS 23.2 (Android 16) and 24 (Android 17) on the Samsung Galaxy Tab S5e: SM-T720/T720N
(`gts4lvwifi`) and SM-T725/C/N/T727* (`gts4lv`). Official LineageOS stops at 22.2 (4.9 kernel).

## Where things stand (2026-11-11)

Both versions are released for both models and update **over the air** (GitHub releases + `ota/` feeds on GitHub
Pages, [RELEASING.md](RELEASING.md)). Current releases: 24 `v24.0-20261109` (November 2026 ASB, volume panel fix; 20261105 added app bubbles #5 and 3-button nav fix #6;
OTA feed 20261109 / 20261105 / 20261026) and 23.2 frozen at `v23.2-20261026` (feed 20261026 / 20261022 / 20261019).
Local copies in `/mnt/build/releases/` match the feeds.

| Area | State |
|---|---|
| Wi-Fi (SM-T720) | Owner's daily tablet on 24.0-20261022; OTA 20261019 → 20261022 verified; double tap to wake, Updater links and Firefox (no more resume crashes) confirmed |
| LTE | Users report 23.2 and 24 working, incl. mobile data on 24 (radio HAL 1.4). Known issue: Dolby Atmos (waiting for logs). Not fixable: SIM on/off switch (needs radio HAL 1.5), VoLTE/VoWiFi |
| Forks | See [REPO-SETUP.md](REPO-SETUP.md) and `scripts/check-pins.sh`. Kernel `a668db21f3cf` (23.2) / `b7f69bb8d4ef` (24, + LZ4 zram, vidc 4K60 load fix, DT2W in AOD); device `f4c18f4` (23.2) / `6150e11` (24); frameworks/av fork `8ba1024bfc` (24, 10-bit thumbnails); Launcher3 fork (issue #6) |
| Upstream | [UPSTREAM.md](UPSTREAM.md): fixes owed to LineageOS and krazey (ExyHyperBrick), none reported yet |

### Build machine layout
External drive (ext4, mounted by hand: `sudo mount /dev/sdX /mnt/build`; check the letter, it changes with plug order).
Both trees are used at their real paths, **no bind mount, no symlink**:

| Path | What |
|---|---|
| `/mnt/build/lineage-24` | 24.0 tree (needs ≥55 GB RAM + swap; the machine has a 32 GiB `/swapfile`) |
| `/mnt/build/lineage-24-419` | 4.19 eval tree (issue #7, luk1337's port): test only, never released; git objects shared with `lineage-24` via `--reference` (never `repo gc`/prune 24 while it exists) |
| `/mnt/build/releases/<version>-<date>/` | release zips, recoveries, vbmetas, `SHA256SUMS`; only the latest release is kept locally (all are on GitHub Releases) |

Build everything with `scripts/build-all.sh` (checks forks, keys and settings first; `--check` = checks only;
`ONLY="24.0:gts4lvwifi"` for one build). The private signing keys live in `~/.android-certs` and
`vendor/lineage-priv/` in both trees: never read, print or commit them. The internal disk holds tools
(`~/bin/repo`, `~/Downloads/samloader`) and `~/work` (logs, `boot-backup/` with original and test boot images).

Test kernels: build in a tree (`m bootimage`), swap the kernel into the installed release's `boot.img` with
`unpack_bootimg.py`/`mkbootimg.py` (keep header and ramdisk), owner flashes with
`heimdall flash --BOOT <img>` from Download mode. Keep the original image to go back.

**From 2026-11-04 only LineageOS 24 is built and released.** 23.2 is frozen at `v23.2-20261026` (forks and
`ota/23.2/` feed kept as they are, build tree deleted 2026-11-13; `build-all.sh` has the 23.2 rows commented out).

## Next steps

- **4.19 eval (issue #7):** luk1337 (LineageOS) ported gts4lv to msm-4.19 and asks us to test and send fixes; no
  releases with it. Tree `/mnt/build/lineage-24-419` (`local_manifests/eval-4.19/luk-gts4lv.xml`), synced 2026-11-14:
  all 9 of his Gerrit picks are merged upstream, so the tree needs **no picks** any more. Device tree branch `eval-419`
  = his `8f83e07` + our drafts L4/L5 (`patches/luk-4.19/`, verified; L6 declined by luk). luk fixed L1, L7
  (Bluetooth) and L9 (silent mic) himself on 2026-11-15; build 20261115c (kernel `0db013b6a31f`) started to verify
  them. ⚠️ His tree now mounts `/metadata` from `omr` (p55) instead of `hidden` (p54): a dirty update of the tablet
  loses the metadata encryption key unless p54 is first copied to p55 from recovery, otherwise data must be wiped.
  Next: owner reviews and sends L4/L5, plus the L10 process_madvise note (UPSTREAM.md).
- **Next 24 build (committed 2026-11-20, not built):** rounded corners switch and half-size task snapshots (device
  `b6ee69f`), 10-bit HEVC/AV1 thumbnails (new fork `android_frameworks_av` `8ba1024bfc`,
  `local_manifests/24/frameworks-av-thumbnails.xml`), vidc 4K60 load fix (kernel `a548c1ceaed7`), double tap to wake with AOD (kernel `283bd808e63c` + `b7f69bb8d4ef`),
  recovery installer zip (`scripts/make-recovery-zip.sh`, tested from the official 22.2 recovery), "Hey Google" (device
  `b4e897d`, sound trigger HAL uevent socket, tested in permissive), LTE only: `debug.sf.enable_gl_backpressure=0`
  (device `6150e11`, fixed the reporter's recents/desktop lag on a T725). All tested on the
  SM-T720 as pushed debug modules / test boot image. Tree synced 2026-11-22, compat fork merged (`1da88ab0b0b7`). Release notes: `release/NOTES-24.0-20261122.md`. Before building:
  `repo sync` (picks up the new manifest), check ASB and LineageOS Bluetooth. Known limit: 4K60 H.264 above ~50
  Mbit/s still drops frames in Gallery (venus held at ~360 MHz in hardware; overclock tested, no gain).
- **Released 2026-11-20:** `v24.0-20261120` (volume tile no longer minimizes YouTube, device `c309439`; lz4 zram,
  kernel `29d0d71a4d35`, device `f896da9`), both models, feeds live. Wi-Fi zip installed on the SM-T720 with Updater →
  Local update over 20261116, `[lz4]` active.
- **Released 2026-11-16:** `v24.0-20261116` (exFAT fsck skip, vold `b70cf8f`; volume tile; device `adcd7eb` with
  22.2 `f2340a8`; stock Launcher3; LTE haptics; recovery and lineage-sdk security fixes), both models, feeds live.
  Wi-Fi zip tested on the SM-T720 over 20261109. Ask the 1 TB card reporter to confirm.
- **Released 2026-11-09:** `v24.0-20261109` (volume panel fix, verified on the SM-T720), feeds live.
- **Released 2026-11-05:** `v24.0-20261105`, feeds live. #5 and #6 verified on the SM-T720 (WORKLOG); confirm with the
  reporters. Next 24 build: `repo sync`, merge LineageOS into the Bluetooth and Launcher3 forks, check for a new ASB.
0. Owner's SM-T720 is on the 24.0-20261026 release build (no root).
1. LTE Dolby Atmos: engine and files identical to Wi-Fi, AudioFX and Twelve ruled out (WORKLOG 2026-10-25); need a longer
   unfiltered capture from an LTE user (request drafted) to see whether profile switches reach the engine on LTE.
2. Report upstream ([UPSTREAM.md](UPSTREAM.md)), krazey first: BPF `LD_IND` R1, fuse-bpf umask, MADV_PAGEOUT dirty bit,
   resume CPU uevents (4e).
3. **Composer crash (to do):** soft reboot when the screen goes off→on within ~0.2 s (hall/lid switch) with a USB mouse
   attached: `composer@2.3-service` SIGSEGV in `sdm::Rotator::Stop` → `HWCBufferAllocator::AllocateBuffer`, the
   allocator returns no buffer and the Qualcomm blob uses it unchecked (WORKLOG 2026-10-24). Reproduce first (mouse in,
   quick cover close/open or magnet over the sensor), then look for a workaround (shim or display setting).
4. Issue #4: fixed in 20261026 (kernel `a668db21f3cf`, UPSTREAM 4e); reporter confirmed (2026-10-27). Side finding: the
   tablet resumes about once a second when the Wi-Fi peer keeps a TCP keepalive (wireless adb); check normal idle wakeups.
5. Open, low priority: cast test on a Miracast receiver; iPhone/CarPlay pairing; stock 4.9 `move_ptes()` has the same
   hardware-dirty pattern as the MADV_PAGEOUT bug (not seen in practice).
6. **1 TB exFAT microSD not recognized: fixed in vold fork `b70cf8f`** (2026-11-15): skips fsck for cleanly unmounted
   exFAT volumes (LineageOS #458; a longer timeout would trip the StorageManager watchdog). Tested with a 256 GB card
   (WORKLOG); ships in the next 24 release; ask the reporter to confirm with the 1 TB card. ⚠️ Until then: don't
   accept the format prompt, eject/reinsert or `sm mount public:<major>,<minor>`.
7. **Future: hand-over release when luk's (or official) 24 ships.** The Updater feed cannot list an info-only entry:
   `NetworkUpdate.kt` reads only datetime, filename, size, url, version, type, os_patch_level, os_sdk_level,
   ota_property_files, with no message or "not installable" flag, and an entry pointing at his zip downloads and then
   fails signature verification (different keys). Moving needs ⚠️ a wipe anyway (different signing keys). Plan: one
   final OTA of ours that (a) overlays the Updater's `menu_changelog_url` ("Recent changes", default
   `download.lineageos.org/<device>/changes`) to a "Moving to the official build" page in this repo (wipe, Seedvault
   backup/restore, link to his release and install guide), (b) optionally points `lineage.updater.uri` at an empty
   feed so nothing new is offered after it, and (c) says the same at the top of its release notes and the README.
   Bigger option, only if that is not visible enough: fork the Updater to show a feed-driven banner. Link his release
   only once he publishes it and agrees; until then point at his official LineageOS device page.

## Rules
- Push to `main` here and to the forks' `lineage-23.2` / `lineage-24.0`; no PRs unless asked.
- Never sync or change the backup forks (`*_exynos9810*`).
- Kernel code: GPL-2.0, keep upstream authors. This repo: Apache-2.0.
- Mark every user-facing step that erases data with ⚠️. The owner prefers short replies.
