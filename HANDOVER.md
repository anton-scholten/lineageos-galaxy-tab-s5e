# Handover: picking up this project in a new session

Read this first, then [WORKLOG.md](WORKLOG.md) for the full history.

## Goal
LineageOS 23.2 (Android 16) on the Samsung Galaxy Tab S5e: SM-T720/T720N (`gts4lvwifi`)
and SM-T725/C/N/T727* (`gts4lv`). Official LineageOS stops at 22.2.

## Where things stand (2026-10-03)

| Area | State |
|---|---|
| Device tree | Patches 0001–0004 are committed in the fork `anton-scholten/android_device_samsung_gts4lv-common`, branch `lineage-23.2` (tip `2e50286`). Not built yet. More changes are likely (tasks R1–R7) |
| Kernel blocker | Android 16 needs 5.4-level eBPF; the kernel is 4.9.337. See `PORTING-LINEAGE-23.2.md` §1 |
| Kernel source to port | `ExyHyperBrick/android_kernel_samsung_exynos9810` `lineage-23.2` `baa585f67e0e`, frozen backup at `anton-scholten/android_kernel_samsung_exynos9810` (Galaxy S9, also 4.9.337, eBPF at 5.15 level). Trial replay onto sdm670: 2,335 clean / 150 conflicts (`analysis/exyhyperbrick-trial/`) |
| Conflicts | Classified: 84 required, 46 optional, 20 skip (`conflict_detail.tsv`, `group` column) |
| Build | Baseline sdm670 kernel builds (12 min on 4 cores). A blind merge of the series fails at the first compile step (`analysis/build-test/`) |
| Estimate | About 7 weeks full-time, range 4–11 (`ESTIMATE.md`) |
| Repos | All set up (`REPO-SETUP.md`). Kernel fork `anton-scholten/android_kernel_samsung_sdm670` `lineage-23.2` = `a30605a` (port not started). Backup forks of both ExyHyperBrick repos. Manifests point at the forks. Both work forks attached with push to session `session_016fF5iQ8x8B4G2hfnShauMQ` |
| Nothing booted | No ROM has been built or flashed |

## Next steps, in order
1. Run the helper-agent tasks in [AGENT-TASKS.md](AGENT-TASKS.md) in parallel (research only, reports in this repo).
   Reference trees for 23.2 device changes: `analysis/reference-trees/`.
2. Kernel, on the fork's `lineage-23.2`:
   - `git cherry-pick -x` the series (`d54533f1546b..baa585f67e0e`, from the backup fork) in order. Skip commits whose subject starts
     with `[exynos9810]`/`[9810]`, and those whose `group` is `skip` in `conflict_detail.tsv`.
   - Resolve each conflict **by hand**, using the agents' conflict briefs. Don't take either side blindly; `analysis/build-test/README.md` shows why.
   - Copy the defconfig options listed in `analysis/exyhyperbrick-trial/README.md` (task K6 makes the fragment).
   - Keep the original authorship. Contact krazey (ExyHyperBrick) before publishing.
3. Device tree, on the fork's `lineage-23.2`: add the changes the R tasks find (target-level 6, sepolicy, and so on).
4. Build with `analysis/build-test/kbuild.sh` until `Image.gz-dtb` links. Then do a full ROM build.
5. Boot, using `pstore`/`last_kmsg` logs for crashes, then test (see `ESTIMATE.md` phase 6).

## Rebuilding the working environment (cloud container)
```bash
# Toolchain: clang/lld are usually there already; add the cross binutils
apt-get install -y flex libssl-dev binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi \
  gcc-aarch64-linux-gnu gcc-arm-linux-gnueabi

W=/tmp/work; mkdir -p $W && cd $W
git clone --single-branch -b lineage-23.2 https://github.com/anton-scholten/android_kernel_samsung_sdm670 k670   # ~2.3 GB
cd k670 && git remote add exy https://github.com/anton-scholten/android_kernel_samsung_exynos9810   # frozen backup
git fetch --no-tags exy lineage-22.2:refs/remotes/exy/l222 lineage-23.2:refs/remotes/exy/l232
git log --reverse --no-merges --format='%H%x09%s' exy/l222..exy/l232 > $W/series.tsv
```
- To rerun the trial: `W=$W python3 analysis/exyhyperbrick-trial/trial.py` (takes ~10 min, writes `$W/trial2.log`), then
  `W=$W python3 analysis/exyhyperbrick-trial/classify.py` (writes `$W/conflict_detail.tsv`).
- The full clone and fetch take 10–30 min through the session proxy. Run them in the background.
- Some websites are blocked from the cloud container (XDA, lineageos.org, wiki, gitea, Gerrit).
  GitHub works. Ask the owner to check blocked pages.

## Rules from earlier sessions
- Only push to the branch you were assigned (or `main` here, if the owner asks). Don't open PRs unless asked.
- Kernel code: GPL-2.0, and keep the upstream authors. This repo's docs: Apache-2.0.
- Mark every user-facing step that erases data with a ⚠️ warning (README style).
- The owner prefers short, terse replies.
