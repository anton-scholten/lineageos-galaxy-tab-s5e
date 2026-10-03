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
| Open work | Round 3: 5 small research tasks. Round 4: the port itself (P1–P5), done by the free model and reviewed by a strong one. [AGENT-TASKS.md](AGENT-TASKS.md) §2.2–2.3 |
| Cherry-pick dry run | `scripts/pick-series.sh` + `scripts/check-pick.py`, tested over the whole series: **83 stops** (not 150), 2,373 clean picks, 4 apply-but-differ, 5 empty. `analysis/port/` |
| Estimate | About **5 weeks wall-clock** left (range 3–9); the owner's own hands-on time is much less until the ROM build. See `ESTIMATE.md` |
| Nothing booted | No ROM built, no kernel port started, nothing flashed |

## Plan of remaining work
The free model ("Space Bunny Free") does all the work steps; a strong model only reviews and takes escalations.
Task specs: [AGENT-TASKS.md](AGENT-TASKS.md) §2.2–2.3 and §6b–6c.

| # | Step | Who | Expected (wall-clock) |
|---|---|---|---|
| 1 | **Round 3 research**: K7 flag collisions, K8 two briefs, R7–R9 ROM questions | free model, 5 agents in parallel | ½ day |
| 2 | **P1 cherry-pick** of the whole series with `scripts/pick-series.sh`, resolving each stop from its brief, into kernel fork `port/pick` | free model, 1 agent (sequential) | 2–4 days (≈83 stops, measured by a dry run) |
| 3 | **P1-R + P2**: strong review of the resolutions (`scripts/check-pick.py` packets); free triage of auto-merge differences, then strong review of the SUSPECT ones | strong + free | 2–3 days |
| 4 | **P3 known fixes + defconfig** (set_memory.h, ipc_router, flag collisions, fs/unicode, fragment) | free | ½ day |
| 5 | **P4 build loop** until `Image.gz-dtb` links; strong model takes escalations (BPF/JIT/mm) and reviews each fix | free + strong | 4–6 days |
| 6 | **P5 device-tree commits** into `port/dt` (target-level 6, soundtrigger, audio XML, per_proxy_helper, R7/R8 outcomes) + review | free + strong | 1 day |
| 7 | Fast-forward both forks' `lineage-23.2` | strong / owner | minutes |
| 8 | **ROM build**: full `lineage-23.2` sync (~150 GB), `brunch lineage_gts4lvwifi` (and `gts4lv`); fix sepolicy/VINTF build errors (free + review) | **owner's machine** (~300 GB disk, 16 GB+ RAM) | 2–3 days |
| 9 | **First boot and debugging**: flash per README (⚠️ erases data), logs per `TESTING.md`; strong model reads logs | owner + tablet | 7 days (3–15) |
| 10 | **Testing**: `scripts/device-checks.sh`, BPF selftests, networking, 24 h soak, LTE model | owner + tablet | 4 days |
| 11 | Later: contact krazey before publishing; upstream to LineageOS Gerrit | owner | |

Steps 1–7 can run anywhere with a 10 GB disk (a Claude cloud session works for the strong steps). Steps 8–10 need the owner's machine and the tablet.

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
