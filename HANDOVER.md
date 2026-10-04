# Handover: picking up this project in a new session

Read this first, then [WORKLOG.md](WORKLOG.md) for the full history.

## Goal
LineageOS 23.2 (Android 16) on the Samsung Galaxy Tab S5e: SM-T720/T720N (`gts4lvwifi`)
and SM-T725/C/N/T727* (`gts4lv`). Official LineageOS stops at 22.2.

## Where things stand (2026-10-04)

| Area | State |
|---|---|
| Repos | Docs here (`main`). Kernel fork: **`lineage-23.2` = `port/pick` @ `801f3f20e54a`** (the ported kernel, 2,458 commits on top of `a30605a`). Device fork: **`lineage-23.2` = `port/dt` @ `e3ccc923bcf2`** (0001–0004 + the audio XML commit). Frozen ExyHyperBrick backups (`REPO-SETUP.md`) |
| Research | **All done and merged** (rounds 1–3). Findings: [LEAD-SYNTHESIS.md](LEAD-SYNTHESIS.md) |
| Kernel cherry-pick (P1) | **Done and reviewed.** 2,438 picks, 60 hand-resolved, 0 problems, no review rejections ([review-P1.md](analysis/port/review-P1.md)) |
| Known fixes (P3) | **Done.** 6 commits, `problems: 0`, `fix commits: 6`. Found a 6th `wakeup_source_register` caller the spec missed |
| **Build (P4)** | **Done — the kernel builds.** Both `gts4lvwifi_defconfig` and `gts4lv_defconfig` link `Image.gz-dtb`, `EXIT=0`, 14 commits, nothing escalated, `problems: 0`, `fix commits: 20` |
| Device tree (P5) | **Done.** 1 commit: space-separated lists in the audio policy XML, verified by a byte-for-byte reverse-transform |
| Deferred | `process_mrelease` (lmkd should fall back; **check `logcat -s lmkd` on first boot**); `target-level` stays 5 |
| Reviews | **All passed** (P1-R…P5-R). The reviewer independently rebuilt the kernel: `Image.gz-dtb`, 0 errors ([review-P4.md](analysis/port/review-P4.md)) |
| Not yet done | **No ROM built, nothing flashed, nothing booted.** The kernel compiles; that is as far as it has got |
| **Blocked** | **`brunch gts4lvwifi` OOM-killed twice on the 15.4 GB host** during Soong's glob phase (14.2 GB RAM + 13.6 GB swap peak). Not a port defect. Tree is synced and verified correct. **To finish on a machine with 32 GB: [analysis/port/BUILD-HANDOFF.md](analysis/port/BUILD-HANDOFF.md)** — a self-contained recipe, including the re-sync, the package list, the two commits to verify, and the traps that cost time here |

## Plan of remaining work
The free model ("Space Bunny Free") does all the work steps; a strong model only reviews and takes escalations.
**To run it: [RUNBOOK.md](RUNBOOK.md)** (setup, order, prompts, checks). Progress: [analysis/port/STATUS.md](analysis/port/STATUS.md).
Task specs: [AGENT-TASKS.md](AGENT-TASKS.md) §6c.

| # | Step | Who | Expected (wall-clock) |
|---|---|---|---|
| ~~1–3~~ | ~~Round 3, P1 cherry-pick, P1-R + P2 review~~ | done | |
| ~~4~~ | ~~P3 known fixes + defconfig, 6 items~~ **done** | done | |
| ~~5~~ | ~~P4 build loop until `Image.gz-dtb` links~~ **done, nothing escalated** | done | |
| ~~6~~ | ~~P5: 1 device-tree commit into `port/dt` + skip log~~ **done** | done | |
| ~~6.5~~ | ~~P3-R, P4-R and P5-R~~ **passed** ([review-P4.md](analysis/port/review-P4.md)); reviewer rebuilt the kernel independently | done | |
| ~~7~~ | ~~Fast-forward both forks' `lineage-23.2`~~ **done** (kernel `801f3f20e54a`, device `e3ccc923bcf2`) | done | |
| 8 | **ROM build**: full `lineage-23.2` sync (~150 GB), `brunch gts4lvwifi` (and `gts4lv`); build errors to a free agent + review | **owner's machine** (~300 GB disk, 16 GB+ RAM) | 2–3 days |
| 9 | **First boot and debugging**: flash per README (⚠️ erases data), logs per `TESTING.md`; strong model reads logs | owner + tablet | 7 days (3–15) |
| 10 | **Testing**: `scripts/device-checks.sh`, BPF selftests, networking, 24 h soak, LTE model; check lmkd without `process_mrelease` | owner + tablet | 4 days |
| 11 | Later: `process_mrelease` port if lmkd needs it; `target-level` 6 if wanted; contact krazey before publishing; upstream to LineageOS Gerrit | owner | |

**Owner to-do now (step 7, then 8):**
1. ~~Fast-forward both `lineage-23.2` branches~~ **Done 2026-10-04**: kernel `801f3f20e54a`, device tree `e3ccc923bcf2`.
2. Start a free agent on task **B1** on your own machine (RUNBOOK §8a: ~150 GB sync, then `brunch gts4lvwifi`). If the build fails,
   a free agent runs **P6** on the errors (§8b) and a strong model reviews the fixes.
3. First boot (⚠️ flashing erases data; back up first). After every attempt a free agent collects the logs (**P7**, §8c) for the strong model.
   Check audio and `logcat -s lmkd` early ([review-P4.md](analysis/port/review-P4.md)).

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
