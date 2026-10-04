# Handover: picking up this project in a new session

Read this first, then [WORKLOG.md](WORKLOG.md) for the full history.

## Goal
LineageOS 23.2 (Android 16) on the Samsung Galaxy Tab S5e: SM-T720/T720N (`gts4lvwifi`)
and SM-T725/C/N/T727* (`gts4lv`). Official LineageOS stops at 22.2.

## Where things stand (2026-10-04)

| Area | State |
|---|---|
| Repos | Docs here (`main`). Kernel fork: `lineage-23.2` = `a30605a` (untouched), **`port/pick` @ `d73f07cf8b5c` = the cherry-picked series**. Device fork: `lineage-23.2` @ `2e50286` (0001–0004). Frozen ExyHyperBrick backups (`REPO-SETUP.md`) |
| Research | **All done and merged** (rounds 1–3). Findings: [LEAD-SYNTHESIS.md](LEAD-SYNTHESIS.md) |
| Kernel cherry-pick (P1) | **Done and reviewed.** 2,438 picks, 60 hand-resolved, 0 problems, no review rejections ([review-P1.md](analysis/port/review-P1.md)). Flag collisions (TIF, FAULT_FLAG, vmalloc) already fixed in it |
| Next kernel step (P3) | 6 known fixes: `set_memory.h`, 5 `wakeup_source_register` callers, `fs/unicode`, two duplicate blocks (F1/F2), defconfig fragment (`CGROUP_SCHED=y` is mandatory) |
| Then (P4) | Build until `Image.gz-dtb` links. First expected errors are decided already (`task_util_est` shim; `cpu_cgrp_id` comes from the defconfig) |
| Device tree (P5) | Only **1 change** left: space-separated lists in the audio policy XML. `target-level` stays 5 for the first build; soundtrigger, `per_proxy_helper`, property names and LTE radio need nothing (R7–R9) |
| Deferred | `process_mrelease` (lmkd should fall back; check on first boot); the 46 optional conflicts are already in `port/pick` |
| Nothing booted | No kernel built yet, no ROM built, nothing flashed |

## Plan of remaining work
The free model ("Space Bunny Free") does all the work steps; a strong model only reviews and takes escalations.
**To run it: [RUNBOOK.md](RUNBOOK.md)** (setup, order, prompts, checks). Progress: [analysis/port/STATUS.md](analysis/port/STATUS.md).
Task specs: [AGENT-TASKS.md](AGENT-TASKS.md) §6c.

| # | Step | Who | Expected (wall-clock) |
|---|---|---|---|
| ~~1–3~~ | ~~Round 3, P1 cherry-pick, P1-R + P2 review~~ | done | |
| 4 | **P3 known fixes + defconfig** (6 items) on `port/pick` | free | ½ day |
| 5 | **P4 build loop** until `Image.gz-dtb` links; strong model takes escalations (BPF/JIT/mm) and reviews fixes (P4-R) | free + strong | 3–9 days |
| 6 | **P5**: 1 device-tree commit into `port/dt` + skip log; P5-R | free + strong | ½ day (can run now, in parallel) |
| 7 | Fast-forward both forks' `lineage-23.2` | owner | minutes |
| 8 | **ROM build**: full `lineage-23.2` sync (~150 GB), `brunch lineage_gts4lvwifi` (and `gts4lv`); build errors to a free agent + review | **owner's machine** (~300 GB disk, 16 GB+ RAM) | 2–3 days |
| 9 | **First boot and debugging**: flash per README (⚠️ erases data), logs per `TESTING.md`; strong model reads logs | owner + tablet | 7 days (3–15) |
| 10 | **Testing**: `scripts/device-checks.sh`, BPF selftests, networking, 24 h soak, LTE model; check lmkd without `process_mrelease` | owner + tablet | 4 days |
| 11 | Later: `process_mrelease` port if lmkd needs it; `target-level` 6 if wanted; contact krazey before publishing; upstream to LineageOS Gerrit | owner | |

**Owner to-do now:** protect `lineage-23.2` in both forks and `main` here (RUNBOOK §0.4; still open per STATUS). Then start P3 and P5 (RUNBOOK §4, §6).

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
- Some websites are blocked from the cloud container (XDA, lineageos.org, wiki, gitea, Gerrit, opencode.ai).
  GitHub works. From the owner's own machine, lineageos.org and the wiki work (round-1 agents used them). Ask the owner to check blocked pages.

## Rules from earlier sessions
- Only push to the branch you were assigned (or `main` here, if the owner asks). Don't open PRs unless asked.
- Never sync or change the backup forks (`*_exynos9810*`).
- Kernel code: GPL-2.0, and keep the upstream authors. This repo's docs: Apache-2.0.
- Mark every user-facing step that erases data with a ⚠️ warning (README style).
- The owner prefers short, terse replies.
