# Handover: picking up this project in a new session

Read this first, then [WORKLOG.md](WORKLOG.md) for the full history.

## Goal
LineageOS 23.2 (Android 16) on the Samsung Galaxy Tab S5e: SM-T720/T720N (`gts4lvwifi`)
and SM-T725/C/N/T727* (`gts4lv`). Official LineageOS stops at 22.2.

## Where things stand (2026-10-07)

**LineageOS 23.2 boots and runs on the SM-T720.** A release build (no debug adb), with its matching recovery, is flashed on the
owner's tablet. Owner tests pass: Wi-Fi, hotspot, per-app data usage (eBPF), microphone, speakers, camera.

| Area | State |
|---|---|
| Repos | Docs: `main`. Kernel fork `lineage-23.2` = `lineage-24.0` @ **`8d39d4284f85`** (ExyHyperBrick port + SELinux avtab fix + BPF ld_abs R2 fix, 2026-10-13; the 20261008 release has `500658be3c16`). Device fork `lineage-23.2` @ **`e38c0de`**. Vendor fork (new) `anton-scholten/proprietary_vendor_samsung_gts4lv-common` `lineage-23.2` @ **`bceca6f`** (TheMuppets 22.2 + patched `libwfdservice.so`). Manifest: `local_manifests/` |
| Device fixes since the first build | cgroups (`a7f1483`), lmkd PSI (`4f4a15c`), OMR as `/metadata` (`b26a9d6`), uclamp power setup (`3557101`), WFD shim (`e38c0de`). Boot logs: [boot-2](analysis/port/boot-2.md) … [boot-5](analysis/port/boot-5.md) |
| Build | **Clean**: no `FAILED:` since P8 (build8, 1 h 32 m incremental). `-k 0` not needed. Run builds in a clean shell (`env -i … bash --noprofile --norc`) with `USE_CCACHE` **unset** (that's how the tree was built; changing it forces a full rebuild) |
| ⚠️ Install note | Existing installs must format OMR once (`mke2fs -t ext4 /dev/block/by-name/omr` from recovery). A clean install with the new recovery's *Format data* handles `/metadata` |
| Checks | `scripts/device-checks.sh`: 5 PASS, 1 SKIP (needs root). NetBpfLoad loads all programs; 14 cgroup BPF programs attached |
| Known gaps | Casting (P8) is fixed at build level. **On-device cast test pending.** QTI perf HAL boost opcodes still target `/dev/stune` (vendor XML, silently ignored). `process_mrelease` not ported (lmkd works with PSI). LTE model unbuilt |

### Build machine layout (since 2026-10-13)
External drive (ext4, mounted by hand: `sudo mount /dev/sdX /mnt/build`; check the letter, it changes with plug order).
Both trees are used at their real paths, **no bind mount, no symlink**:

| Path | What |
|---|---|
| `/mnt/build/lineage-23.2` | 23.2 tree (renamed from `/mnt/build/lineage`; older notes saying `~/android/lineage` mean this) |
| `/mnt/build/lineage-24` | 24.0 tree |
| `/mnt/build/releases/<version>-<date>/` | release zips, recoveries, vbmetas, `SHA256SUMS` (real copies). `23.2-20261008/` = the drafted GitHub release |

Both `out/` dirs were deleted on 2026-10-13 (they came from the previous machine, so every build was a full rebuild
anyway). Build everything with `scripts/build-all.sh` (checks first; `--check` = checks only); it is restartable.
The internal disk holds tools (`~/bin/repo`, `~/Downloads/samloader`) and `~/work` (logs, `boot-backup/`).

## Next steps

**Release 20261022 (2026-10-22):** published (`v23.2-20261022`, `v24.0-20261022`): Firefox resume-crash kernel fix (`72f6ca56842c`), double tap to wake, Updater links; OTA feeds live (2 builds each). Next: owner OTA test on the SM-T720.

**Previous plan (2026-10-18 on):** signed with our private keys (RELEASING.md), OTA feed property, storage without sdcardfs + kernel `7bf5ff571b75` (fuse-bpf umask fix: Telegram/Wallcraft downloads, Termux). ⚠️ One clean install for all users; after that, updates arrive over the air. Open: Dolby on the LTE model (needs that user's log), key backup.

**Release builds with all fixes done (2026-10-16):** `23.2-20261016` and `24.0-20261016`, Wi-Fi + LTE, in `/mnt/build/releases/23.2-20261015/` and `24.0-20261015/` (verified: kernel, Bluetooth, AOD, defaults, 24 gatekeeper). **Draft GitHub release `v23.2-20261016`** (23.2 only, [notes](release/NOTES-20261016.md)); owner publishes. 24.0-20261016 verified on the tablet (PIN fix, Bluetooth, AOD, defaults). The 24 GApps setup hang was missing EROFS in the kernel (Play services is an EROFS APEX in MindTheGapps 17); fixed in kernel `230ccf8e8e63` (both branches), verified on device. **Draft GitHub release `v24.0-20261016`** (Wi-Fi + LTE, [notes](release/NOTES-24.0-20261016.md)), owner publishes after the fresh-install test. 23.2 picks up the EROFS kernel at its next build. Open: Smart Switch auto-installed by Google setup (to confirm and document). iPhone/CarPlay still untested. Upstream list: [UPSTREAM.md](UPSTREAM.md).

**LineageOS 24 boots** (2026-10-15, [boot-24-3](analysis/l24/boot-24-3.md)): release build `24.0-20261014` runs on the owner's SM-T720, no crashes. Next: owner use/soak, L10 testing, L11 release.
**LineageOS 24:** [FEASIBILITY-LINEAGE-24.md](FEASIBILITY-LINEAGE-24.md) → tasks [analysis/l24/TASKS-L24.md](analysis/l24/TASKS-L24.md),
run from [RUNBOOK.md](RUNBOOK.md) §9, tracked in [analysis/l24/STATUS.md](analysis/l24/STATUS.md). First step is the owner's L0.

**23.2 leftovers:**

| # | Step | Who | Expected |
|---|---|---|---|
| 1 | Cast test (Miracast receiver, e.g. Windows "Wireless Display"); 24 h soak; heavy multitasking (lmkd); Bluetooth audio, USB file transfer, SD card, overnight battery | owner + tablet | 1–2 days |
| ~~2~~ | ~~**LTE build**~~ **done 2026-10-07** (2 h 51 m, no errors): superseded by the 20261008 release files in `out/keep/release-20261008/`. Untested; testers must confirm `omr` exists first | done | |
| 3 | BPF verifier selftests (krazey's corpus), needs root (Lineage root via a debug build, or `adb root` on userdebug) | agent + owner | ½ day |
| 4 | Independent review of the 5 device commits + the vendor-fork commit (RUNBOOK prompt R) | strong model | ½ day |
| 5 | Publish: contact krazey (kernel author) first, then an unofficial release (XDA thread, GitHub release with zip + recovery, install guide incl. ⚠️ OMR format) | owner | |
| 6 | Upstream: email devrel@lineageos.org / the gts4lv maintainer with results; small device fixes to Gerrit; the SELinux avtab fix as a standalone kernel change | owner | |
| 7 | Optional: remap the QTI perf HAL's schedtune opcodes to uclamp; `process_mrelease` port if lmkd misbehaves | strong model | |
| 8 | **Charging indicator fix (2026-10-13)**: kernel `8d39d4284f85` (= upstream `e6a18d36118b`), on both kernel fork branches. **Release builds done 2026-10-14/15** with it: `/mnt/build/releases/23.2-20261014/` (Wi-Fi + LTE) and `/mnt/build/releases/24.0-20261014/` (Wi-Fi zip `24.0-20261014`, LTE zip `24.0-20261015`). Owner flashed 23.2-20261014 Wi-Fi (recovery + zip, no Format data) on 2026-10-15: charging, idle plug-in and all power tests good. **GitHub release v23.2-20261014 is a draft** ([notes](release/NOTES-20261014.md)); owner publishes. Report the bug to krazey (ExyHyperBrick has it too). Details: [charging-notification-review.md](analysis/l24/charging-notification-review.md) | owner | |

## Rebuilding the working environment (cloud container)
```bash
# Toolchain: clang/lld are usually there already; add the cross binutils
apt-get install -y clang lld flex bison libssl-dev binutils-aarch64-linux-gnu \
  binutils-arm-linux-gnueabi gcc-aarch64-linux-gnu dwarves
# dtc is NOT needed: arm64 .dtsi files compile through clang.

# ⚠️ CRITICAL, easy to miss: Debian's llvm-19 ships only versioned names (llvm-nm-19) but
# kbuild's LLVM=1 looks for unversioned ones. Without this, the build still SUCCEEDS but
# vdso.so.dbg does not link and vdso_offset_sigtramp is generated WRONG - a silently
# broken sigreturn trampoline, not a build error.
mkdir -p ~/work/llvmbin
for f in /usr/bin/llvm-*-19; do ln -sf "$f" ~/work/llvmbin/"$(basename "$f" -19)"; done
export PATH="$HOME/work/llvmbin:$PATH"

W=/tmp/work; mkdir -p $W && cd $W
git clone --single-branch -b lineage-23.2 https://github.com/anton-scholten/android_kernel_samsung_sdm670 k670   # ~2.3 GB
cd k670 && git remote add exy https://github.com/anton-scholten/android_kernel_samsung_exynos9810   # frozen backup
git fetch --no-tags exy lineage-22.2:refs/remotes/exy/l222 lineage-23.2:refs/remotes/exy/l232
git log --reverse --no-merges --format='%H%x09%s' exy/l222..exy/l232 > $W/series.tsv
```
- To rerun the trial: `W=$W python3 analysis/exyhyperbrick-trial/trial.py` (takes ~10 min, writes `$W/trial2.log`), then
  `W=$W python3 analysis/exyhyperbrick-trial/classify.py` (writes `$W/conflict_detail.tsv`).
- The full clone and fetch take 10–30 min through the session proxy. Run them in the background.
- Some websites are blocked from the cloud container (XDA, lineageos.org, wiki, gitea, Gerrit, opencode.ai).
  GitHub works. From the owner's own machine, lineageos.org and the wiki work (round-1 agents used them). Ask the owner to check blocked pages.

## Rules from earlier sessions
- Only push to the branch you were assigned (or `main` here, if the owner asks). Don't open PRs unless asked.
- Never sync or change the backup forks (`*_exynos9810*`).
- Kernel code: GPL-2.0, and keep the upstream authors. This repo's docs: Apache-2.0.
- Mark every user-facing step that erases data with a ⚠️ warning (README style).
- The owner prefers short, terse replies.
