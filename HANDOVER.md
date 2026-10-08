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
| Repos | Docs: `main`. Kernel fork `lineage-23.2` @ **`500658be3c16`** (ExyHyperBrick port + SELinux avtab fix). Device fork `lineage-23.2` @ **`e38c0de`**. Vendor fork (new) `anton-scholten/proprietary_vendor_samsung_gts4lv-common` `lineage-23.2` @ **`bceca6f`** (TheMuppets 22.2 + patched `libwfdservice.so`). Manifest: `local_manifests/` |
| Device fixes since the first build | cgroups (`a7f1483`), lmkd PSI (`4f4a15c`), OMR as `/metadata` (`b26a9d6`), uclamp power setup (`3557101`), WFD shim (`e38c0de`). Boot logs: [boot-2](analysis/port/boot-2.md) … [boot-5](analysis/port/boot-5.md) |
| Build | **Clean**: no `FAILED:` since P8 (build8, 1 h 32 m incremental). `-k 0` not needed. Run builds in a clean shell (`env -i … bash --noprofile --norc`) with `USE_CCACHE` **unset** (that's how the tree was built; changing it forces a full rebuild) |
| ⚠️ Install note | Existing installs must format OMR once (`mke2fs -t ext4 /dev/block/by-name/omr` from recovery). A clean install with the new recovery's *Format data* handles `/metadata` |
| Checks | `scripts/device-checks.sh`: 5 PASS, 1 SKIP (needs root). NetBpfLoad loads all programs; 14 cgroup BPF programs attached |
| Known gaps | Casting (P8) is fixed at build level. **On-device cast test pending.** QTI perf HAL boost opcodes still target `/dev/stune` (vendor XML, silently ignored). `process_mrelease` not ported (lmkd works with PSI). LTE model unbuilt |

## Next steps

| # | Step | Who | Expected |
|---|---|---|---|
| 1 | Cast test (Miracast receiver, e.g. Windows "Wireless Display"); 24 h soak; heavy multitasking (lmkd); Bluetooth audio, USB file transfer, SD card, overnight battery | owner + tablet | 1–2 days |
| ~~2~~ | ~~**LTE build**~~ **done 2026-10-07** (2 h 51 m, no errors): `out/keep/lineage-23.2-20261007-UNOFFICIAL-gts4lv.zip` + `recovery-20261007-gts4lv.img`. Untested; testers must confirm `omr` exists first | done | |
| 3 | BPF verifier selftests (krazey's corpus), needs root (Lineage root via a debug build, or `adb root` on userdebug) | agent + owner | ½ day |
| 4 | Independent review of the 5 device commits + the vendor-fork commit (RUNBOOK prompt R) | strong model | ½ day |
| 5 | Publish: contact krazey (kernel author) first, then an unofficial release (XDA thread, GitHub release with zip + recovery, install guide incl. ⚠️ OMR format) | owner | |
| 6 | Upstream: email devrel@lineageos.org / the gts4lv maintainer with results; small device fixes to Gerrit; the SELinux avtab fix as a standalone kernel change | owner | |
| 7 | Optional: remap the QTI perf HAL's schedtune opcodes to uclamp; `process_mrelease` port if lmkd misbehaves | strong model | |

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
