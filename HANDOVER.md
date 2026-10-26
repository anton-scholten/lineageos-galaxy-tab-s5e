# Handover: picking up this project in a new session

Read this first, then the end of [WORKLOG.md](WORKLOG.md) for recent detail (it holds the full history).

## Goal
Unofficial LineageOS 23.2 (Android 16) and 24 (Android 17) on the Samsung Galaxy Tab S5e: SM-T720/T720N
(`gts4lvwifi`) and SM-T725/C/N/T727* (`gts4lv`). Official LineageOS stops at 22.2 (4.9 kernel).

## Where things stand (2026-10-23)

Both versions are released for both models and update **over the air** (GitHub releases + `ota/` feeds on GitHub
Pages, [RELEASING.md](RELEASING.md)). Current releases: `v23.2-20261019` / `v24.0-20261019` (own release keys, storage
fix, OTA; needed one clean install) `v23.2-20261022` / `v24.0-20261022` (Firefox resume-crash kernel fix, double
tap to wake, Updater links) and `v23.2-20261026` / `v24.0-20261026` (ueventd / late input devices fix, lock screen avatar,
WebView 156, 23.2 patch level 2026-10, Pixel APN list); OTA, no wipe. Local copies of these three in `/mnt/build/releases/`. The pre-OTA releases (20261008-20261016) were deleted; their tags remain.

| Area | State |
|---|---|
| Wi-Fi (SM-T720) | Owner's daily tablet on 24.0-20261022; OTA 20261019 → 20261022 verified; double tap to wake, Updater links and Firefox (no more resume crashes) confirmed |
| LTE | Users report 23.2 and 24 working, incl. mobile data on 24 (radio HAL 1.4). Known issue: Dolby Atmos (waiting for logs). Not fixable: SIM on/off switch (needs radio HAL 1.5), VoLTE/VoWiFi |
| Forks | See [REPO-SETUP.md](REPO-SETUP.md) and `scripts/check-pins.sh`. Kernel `a668db21f3cf` on both branches; device `f4c18f4` (23.2) / `83ab401` (24) |
| Upstream | [UPSTREAM.md](UPSTREAM.md): fixes owed to LineageOS and krazey (ExyHyperBrick), none reported yet |

### Build machine layout
External drive (ext4, mounted by hand: `sudo mount /dev/sdX /mnt/build`; check the letter, it changes with plug order).
Both trees are used at their real paths, **no bind mount, no symlink**:

| Path | What |
|---|---|
| `/mnt/build/lineage-23.2` | 23.2 tree |
| `/mnt/build/lineage-24` | 24.0 tree (needs ≥55 GB RAM + swap; the machine has a 32 GiB `/swapfile`) |
| `/mnt/build/releases/<version>-<date>/` | release zips, recoveries, vbmetas, `SHA256SUMS` |

Build everything with `scripts/build-all.sh` (checks forks, keys and settings first; `--check` = checks only;
`ONLY="24.0:gts4lvwifi"` for one build). The private signing keys live in `~/.android-certs` and
`vendor/lineage-priv/` in both trees: never read, print or commit them. The internal disk holds tools
(`~/bin/repo`, `~/Downloads/samloader`) and `~/work` (logs, `boot-backup/` with original and test boot images).

Test kernels: build in a tree (`m bootimage`), swap the kernel into the installed release's `boot.img` with
`unpack_bootimg.py`/`mkbootimg.py` (keep header and ramdisk), owner flashes with
`heimdall flash --BOOT <img>` from Download mode. Keep the original image to go back.

## Next steps

0. Owner's SM-T720 is on the debuggable test build until it takes the 24.0-20261026 OTA (then root is gone again).
1. LTE Dolby Atmos: engine and files identical to Wi-Fi, AudioFX and Twelve ruled out (WORKLOG 2026-10-25); need a longer
   unfiltered capture from an LTE user (request drafted) to see whether profile switches reach the engine on LTE.
2. Report upstream ([UPSTREAM.md](UPSTREAM.md)), krazey first: BPF `LD_IND` R1, fuse-bpf umask, MADV_PAGEOUT dirty bit,
   resume CPU uevents (4e).
3. **Composer crash (to do):** soft reboot when the screen goes off→on within ~0.2 s (hall/lid switch) with a USB mouse
   attached: `composer@2.3-service` SIGSEGV in `sdm::Rotator::Stop` → `HWCBufferAllocator::AllocateBuffer`, the
   allocator returns no buffer and the Qualcomm blob uses it unchecked (WORKLOG 2026-10-24). Reproduce first (mouse in,
   quick cover close/open or magnet over the sensor), then look for a workaround (shim or display setting).
4. Issue #4: fixed in 20261026 (kernel `a668db21f3cf`, UPSTREAM 4e); confirm with the reporter. Side finding: the
   tablet resumes about once a second when the Wi-Fi peer keeps a TCP keepalive (wireless adb); check normal idle wakeups.
5. Open, low priority: cast test on a Miracast receiver; iPhone/CarPlay pairing; stock 4.9 `move_ptes()` has the same
   hardware-dirty pattern as the MADV_PAGEOUT bug (not seen in practice).

## Rules
- Push to `main` here and to the forks' `lineage-23.2` / `lineage-24.0`; no PRs unless asked.
- Never sync or change the backup forks (`*_exynos9810*`).
- Kernel code: GPL-2.0, keep upstream authors. This repo: Apache-2.0.
- Mark every user-facing step that erases data with ⚠️. The owner prefers short replies.
