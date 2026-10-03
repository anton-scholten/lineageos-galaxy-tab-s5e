# Handover: picking up this project in a new session

Read this first, then [WORKLOG.md](WORKLOG.md) for the full history.

## Goal
LineageOS 23.2 (Android 16) on the Samsung Galaxy Tab S5e: SM-T720/T720N (`gts4lvwifi`)
and SM-T725/C/N/T727* (`gts4lv`). Official LineageOS stops at 22.2.

## Where things stand (2026-10-03, after helper rounds 1–2)

| Area | State |
|---|---|
| Repos | **Done.** Docs here (`main`). Work forks with `lineage-23.2`: device tree `anton-scholten/android_device_samsung_gts4lv-common` (tip `2e50286`), kernel `anton-scholten/android_kernel_samsung_sdm670` (= `a30605a`, port not started). Frozen ExyHyperBrick backups. Manifests point at the forks (`REPO-SETUP.md`) |
| Research | **Done and merged.** 39 helper tasks, reviewed. Start with [LEAD-SYNTHESIS.md](LEAD-SYNTHESIS.md). Briefs for all 150 conflicts (`analysis/conflicts/`: 76 MERGE, 22 PREREQ, 15 DROP), defconfig fragment, API audit, VINTF/sepolicy/Soong/blob audits, test script and crash-log guide (`TESTING.md`) |
| Kernel blocker | Android 16 needs 5.4-level eBPF; the kernel is 4.9.337. Fix = port the ExyHyperBrick series (2,599 commits, 150 conflicts) |
| Known kernel fixes, found ahead of the build | Add `arch/arm64/include/asm/set_memory.h`; `ipc_router_core.c:1384` gets `wakeup_source_register(NULL, …)`; move `TIF_UPROBE` off bit 4 and `FAULT_FLAG_INTERRUPTIBLE` off `0x200`; use the K6 fragment (`CGROUP_SCHED=y` or WALT is silently lost, `UPROBES=y`, `BPF_JIT=y`); copy `fs/unicode/` or drop `CONFIG_UNICODE`; Exynos-base prerequisites (randstruct macros, `ANDROID_VERSION`) |
| Known device-tree changes | `target-level` 5→6; delete the soundtrigger 2.2 block; LTE radio 1.4 is below level 6 (R8 decides); space-separated lists in the audio policy XML; `per_proxy_helper` file label; maybe vendor property names (R7). Livedisplay and CAF wiring need nothing. Build with `brunch`, not bare `m` |
| Open research | Round 3: 5 small tasks (K7, K8, R7, R8, R9) in [AGENT-TASKS.md](AGENT-TASKS.md) §2.2 |
| Estimate | About **5½ weeks full-time** left (range 3½–10). See `ESTIMATE.md` "Remaining work" |
| Nothing booted | No ROM built, no kernel port started, nothing flashed |

## Plan of remaining work
| # | Step | Who / where | Expected |
|---|---|---|---|
| 1 | **Round 3 research** (K7, K8, R7, R8, R9), then review with `scripts/check-agent-output.sh` + AGENT-TASKS §11 | helper agents; owner starts them | ½ day wall-clock, in parallel with step 2 |
| 2 | **Kernel cherry-pick** on the kernel fork's `lineage-23.2`: `git cherry-pick -x` the series `d54533f1546b..baa585f67e0e` (from the backup fork) in order. Skip `[exynos9810]`/`[9810]` commits and the `skip` group in `conflict_detail.tsv`. Apply the known kernel fixes above as their commits come up | lead (a Claude cloud session works: 2.3 GB clone) | 1 day |
| 3 | **Resolve conflicts by hand** with the briefs. Take the real conflict list from the cherry-pick, not `conflict_detail.tsv` (LEAD-SYNTHESIS §5). Resolve the linked groups as one unit: `fs/userfaultfd.c` ×6, `fs/fuse` ordering, the XDP rename (§4) | lead, or a human kernel dev for the 12 large ones | 7 days |
| 4 | **Build** with `analysis/build-test/kbuild.sh` + the K6 fragment until `Image.gz-dtb` links. Expect a tail of small prerequisite fixes only the compiler finds (§3), since the API audit covered 2% of the changed headers | lead (cloud OK; 12 min per build) | 5 days |
| 5 | **Device-tree commits** from the "known device-tree changes" row, R7–R9, and the first build's sepolicy errors | lead | 2 days |
| 6 | **ROM build**: full `lineage-23.2` sync (~150 GB) with `local_manifests/`, `brunch lineage_gts4lvwifi` (and `gts4lv`) | **owner's machine** (~300 GB disk, 16 GB+ RAM) | 2 days |
| 7 | **First boot and debugging**: flash per README (⚠️ erases data), collect logs per `TESTING.md` | owner + tablet; lead reads logs | 7 days (3–15) |
| 8 | **Testing**: `scripts/device-checks.sh`, BPF selftests, networking, 24 h soak, LTE model | owner + tablet | 4 days |
| 9 | Later: the 46 optional conflicts; contact krazey; upstream to LineageOS Gerrit | | |

Steps 2–5 can run in a Claude cloud session. Steps 6–8 need the owner's machine and the tablet.

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
