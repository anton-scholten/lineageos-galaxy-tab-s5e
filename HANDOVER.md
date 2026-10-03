# Handover: picking up this project in a new session

Read this first, then [WORKLOG.md](WORKLOG.md) for the full history.

## Goal
LineageOS 23.2 (Android 16) on the Samsung Galaxy Tab S5e: SM-T720/T720N (`gts4lvwifi`)
and SM-T725/C/N/T727* (`gts4lv`). Official LineageOS stops at 22.2.

## Where things stand (2026-10-03)

| Area | State |
|---|---|
| Repos | **Done.** Docs here (`main`). Work forks with `lineage-23.2`: device tree `anton-scholten/android_device_samsung_gts4lv-common` (tip `2e50286`), kernel `anton-scholten/android_kernel_samsung_sdm670` (= `a30605a`). Frozen backups of both ExyHyperBrick repos. Manifests point at the forks. Details: `REPO-SETUP.md` |
| Device tree | 0001–0004 committed in the fork. Not built yet. More changes expected (FCM level 6, sepolicy, …), which helper tasks R1–R6 will list |
| Kernel blocker | Android 16 needs 5.4-level eBPF; the kernel is 4.9.337. See `PORTING-LINEAGE-23.2.md` §1 |
| Kernel source to port | ExyHyperBrick S9 kernel `lineage-23.2` `baa585f67e0e` (4.9.337, eBPF at 5.15 level), backed up as `anton-scholten/android_kernel_samsung_exynos9810`. Trial replay onto sdm670: 2,335 clean / 150 conflicts (`analysis/exyhyperbrick-trial/`) |
| Conflicts | Classified: 84 required, 46 optional, 20 skip (`conflict_detail.tsv`). Split into helper batches (`analysis/agent-batches/`) |
| Build | Baseline sdm670 kernel builds (12 min on 4 cores). A blind merge of the series fails at the first compile step (`analysis/build-test/`) |
| Helper agents | Fully specified, **not started**: `AGENTS.md` (entry point), `AGENT-TASKS.md` (37 runs, model tiers, review steps), `scripts/check-agent-output.sh` |
| Estimate | About 7 weeks full-time, range 4–11 (`ESTIMATE.md`) |
| Nothing booted | No ROM built, no kernel port started, nothing flashed |

## Leftover work, in order
1. **Helper research (owner starts it).** Run the 37 tasks in [AGENT-TASKS.md](AGENT-TASKS.md) §2. Give each agent the prompt from
   [AGENTS.md](AGENTS.md), plus repo access (AGENT-TASKS §0.6). Pick models with §10.
2. **Review (lead).** AGENT-TASKS §11: run the format script, check every DROP/low/HUMAN, spot-check the rest, and merge the `agent/*` branches.
3. **Kernel port (lead or human),** on the kernel fork's `lineage-23.2`:
   - `git cherry-pick -x` the series `d54533f1546b..baa585f67e0e` (from the backup fork) in order. Skip commits whose subject starts
     with `[exynos9810]`/`[9810]`, and those whose `group` is `skip` in `conflict_detail.tsv`.
   - Resolve each conflict **by hand**, using the K2/K3 briefs. Don't take either side blindly; `analysis/build-test/README.md` shows why.
   - Apply the K4 findings (prerequisites, and sdm670 fixes to keep). Add the K6 defconfig fragment.
   - Keep the original authorship. Contact krazey (ExyHyperBrick) before publishing.
4. **Kernel build.** Run `analysis/build-test/kbuild.sh` until `Image.gz-dtb` links. Use K5 to predict the driver breakage.
5. **Device tree.** Commit the changes the R tasks found to the device fork's `lineage-23.2`.
6. **ROM build.** Full `lineage-23.2` sync (~150 GB) with `local_manifests/`. Needs a big machine, not a cloud session.
7. **Boot and test.** Use `pstore`/`last_kmsg` logs for crashes (T2), then `scripts/device-checks.sh` (T1) and `ESTIMATE.md` phase 6.
8. **Later.** The 46 optional conflicts (K2c/K2d), upstreaming to LineageOS Gerrit.

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
- Never sync or change the backup forks (`*_exynos9810*`).
- Kernel code: GPL-2.0, and keep the upstream authors. This repo's docs: Apache-2.0.
- Mark every user-facing step that erases data with a ⚠️ warning (README style).
- The owner prefers short, terse replies.
