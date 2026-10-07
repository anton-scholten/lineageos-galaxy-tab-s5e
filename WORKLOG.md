# Work log

A record of everything done so far, including what failed, what was blocked
or skipped, and why. Newest last.

## 2026-10-02: initial analysis
- The repo started empty. I cloned LineageOS `android_device_samsung_gts4lvwifi`,
  `gts4lv-common`, `android_kernel_samsung_sdm670` and `android_hardware_samsung`
  at `lineage-22.2`/`23.2`, and compared them with Samsung trees that already moved to 23.x
  (`sm7125-common`, `sm8250-common`).
- Finding: every 4.9-kernel Qualcomm device (gts4lv, enchilada, beryllium, …) is still
  on 22.2 in `LineageOS/hudson`. The blocker is the eBPF kernel requirement.
- Wrote the device-tree patches 0001–0004, checked that they apply with `git am`, and wrote
  `PORTING-LINEAGE-23.2.md`, `local_manifests/` and `apply-patches.sh`.

## 2026-10-03
- **README and licence.** Install steps from stock Android 11 and from LineageOS 22.2, based on
  the LineageOS wiki source (`LineageOS/lineage_wiki`; the wiki site itself was
  blocked from this environment). Every step that erases data is marked.
  Licence: Apache-2.0, the same as LineageOS. Kernel patches have to stay GPL-2.0.
- **Kernel plan.** Found the exact kernel version checks in `packages/modules/Connectivity`
  (`NetBpfLoad.cpp`, `BpfHandler.cpp`). Wrote `KERNEL-BACKPORT-PLAN.md`: Track A (backport), Track B (userspace), Track C (kernel uprev).
- **Correction:** FCM level 5 is an empty placeholder on lineage-23.2, so a bump to 6 is needed.
- **Blocked:** an attempt to write a Track B patch (turning the Connectivity kernel version
  checks into warnings) was refused by the session's safety classifier, so no
  such patch is in this repo. Track B is only described, and an existing third-party
  implementation (Doze-off/fuck-bpf) is linked.
- **Variants.** Covered SM-T720/T720N (gts4lvwifi) and SM-T725/C/N, T727* (gts4lv). Split the local
  manifests into common, Wi-Fi and LTE files.
- **Prior work search.** `PRIOR-WORK.md`. Some sites were blocked here (gitea, XDA,
  lineageos.org, Gerrit); the repo owner checked them by hand: the sdm845 gitea repo only has
  `lineage-23.0`; jojobear691 returns 404; no Tab S5e / Pixel 3a / Gerrit work; and the
  S9 thread links to **ExyHyperBrick**.
- **ExyHyperBrick trial.** Their `android_kernel_samsung_exynos9810` `lineage-23.2` (4.9.337)
  carries a full eBPF (5.15-level) backport. Replayed it onto sdm670 with `git merge-tree`:
  2,335 clean, 150 conflicts, 114 skipped (`analysis/exyhyperbrick-trial/`). A first attempt with
  real `git cherry-pick` was too slow on the 2.3 GB repo and was replaced.
- **Forks.** Checked all 22 forks of the ExyHyperBrick kernel. None improves on upstream
  (`PRIOR-WORK.md`).
- **Repo setup review** (below). Creating a new GitHub repo from this session
  failed: `403 Resource not accessible by integration`.
- **Detailed estimate.**
  - Classified all 150 conflicts by size and need (`classify.py`, `conflict_detail.tsv`).
  - Built the baseline sdm670 kernel here (clean, 12 min on 4 cores).
  - Built the port tree with conflicts resolved blindly to the series side. It fails at the
    first compile step (`analysis/build-test/`).
  - Wrote `ESTIMATE.md`: about 7 weeks full-time expected, range 4–11.
- Changed patch 0004 to `ro.bpf.kver_override=5.15.178`, to match the ExyHyperBrick-based kernel.

## 2026-10-03: moved to the new repo
- The owner created `anton-scholten/lineageos-galaxy-tab-s5e`. It was attached to the session, and the full
  history pushed there as `main`.
- Added `HANDOVER.md` (state, next steps, how to rebuild the environment) and `CLAUDE.md`.
  Made the trial scripts' work directory configurable (`W=`), and moved the `group` classification
  into `classify.py`. Rerunning it reproduces `conflict_detail.tsv` exactly.

## 2026-10-03: repo check and helper-agent task list
- Checked the repos. Both forks exist (`anton-scholten/android_kernel_samsung_sdm670` at `a30605a`,
  `anton-scholten/android_device_samsung_gts4lv-common` at `d1b339b`), identical to LineageOS `lineage-22.2`,
  no `lineage-23.2` branch. They're public, so sessions can read them; pushing needs them attached with push access.
- Patches 0001–0004 still apply cleanly to the device fork with `git am`.
- All pins are unchanged: ExyHyperBrick `lineage-22.2` `d54533f`, `lineage-23.2` `baa585f`. gts4lv, gts4lvwifi
  and the TheMuppets vendor repos still stop at `lineage-22.2`; `hardware/samsung` has `lineage-23.2`.
- The old repo `anton-scholten/Lineage-OS-SM-T720` still exists (private). Archive it when you like.
- Removed committed `__pycache__` files and added `.gitignore`.
- Wrote `AGENT-TASKS.md`: small, checkable tasks for weaker agents working in parallel (conflict briefs,
  upstream-commit map, build-error prerequisites, driver API audit, defconfig, ROM-side research, test scripts).

## 2026-10-03: old repo, what to fork, attach steps, detailed agent tasks
- Old repo `Lineage-OS-SM-T720`: its only branch ends at `71029d0`, which is in this repo's `main`. It has no tags,
  issues, PRs or releases. Safe to archive or delete (`REPO-SETUP.md`).
- No repo anywhere has `lineage-23.2` for the Tab S5e, so we make the branch ourselves. Searched for trees with real 23.x work:
  - `LineageOS/android_device_samsung_sm7125-common` is official 23.2 (Samsung Qualcomm, 4.14): 26 commits from 22.2 to 23.2, and 4 of them are our 0001–0004.
  - `ExyHyperBrick/android_device_samsung_exynos9810-common` is unofficial 23.2 on a 4.9 kernel: 143 commits, some 4.9-specific (power supply BPF filter, UFFD GC).
  - Dead ends: Xiaomi sdm845-common `lineage-23.2` is the same commit as 22.2, and Pixel 3a `lineage-23.0` is stale. Neither kernel has a 23.x branch.
  - Commit lists are in `analysis/reference-trees/`.
- Recommended extra forks: the ExyHyperBrick kernel and exynos9810-common, as backups.
- Attached the device fork to this session with push access. Attaching the kernel fork was blocked by the session's permission check. Wrote the attach steps in `REPO-SETUP.md`.
- Rewrote `AGENT-TASKS.md` for weaker agents: setup commands with checks, exact steps per task, an output template,
  self-checks, when to stop and ask, and common mistakes. Added the pre-split conflict batches `analysis/agent-batches/`
  (the K2/K3 tasks, with file names) and the new tasks R6 (port list from sm7125) and R7 (sort the exynos9810-common commits).

## 2026-10-03: kernel fork attached, agent access
- The owner deleted `Lineage-OS-SM-T720`.
- Attached `anton-scholten/android_kernel_samsung_sdm670` to this session with push access. Both forks are attached now.
- The ExyHyperBrick repos' default branch is `lineage-24.0`. Added fork steps that untick "copy default branch only", so `lineage-23.2` comes along (`REPO-SETUP.md`).
- `AGENT-TASKS.md`: added which repo agents work in (this one, branches `agent/<task-id>`; everything else read-only) and how the owner gives non-Claude agents access (fine-grained token, collaborator, or patch files).

## 2026-10-03: lineage-23.2 branches, backups, manifests
- Checked the owner's backup forks `anton-scholten/android_kernel_samsung_exynos9810` (48 branches) and
  `..._exynos9810-common` (24 branches). They match ExyHyperBrick exactly: kernel `lineage-22.2` `d54533f1546b`, `lineage-23.2` `baa585f67e0e`;
  device `lineage-22.2` `c7d22a36ba1e`, `lineage-23.2` `ced977559b13`. Both are public.
- Pushed the device fork's `lineage-23.2` = `d1b339b` + `git am` patches 0001–0004 (tip `2e50286`).
- Pushed the kernel fork's `lineage-23.2` = `a30605a54f3b` (no changes yet).
- `local_manifests/gts4lv-common.xml` now points at both forks (`remote="anton"`, `lineage-23.2`).
- Removed `apply-patches.sh`, because the fork replaces it. `patches/` stays as a record.
- Updated `README.md`, `PORTING-LINEAGE-23.2.md`, `CLAUDE.md` and `HANDOVER.md`, and rewrote `REPO-SETUP.md` as a current-state doc.
- `AGENT-TASKS.md`: removed the done owner tasks and M1. Agents now clone from our forks and backups,
  with a table of which task needs which repo. The pin checker (M3) covers the forks.

## 2026-10-03: model tiers and output checker
- `AGENT-TASKS.md` §10: which OpenCode Go model handles which task. DeepSeek V4.1 Flash for the mechanical ones;
  Qwen3.7 Plus, MiniMax M3 or Kimi K2.7 Code for the ones needing judgment; a strong model or a human for section 7 and the review.
  The figures come from third-party write-ups, because opencode.ai was blocked from the container.
- §11: review order for the lead: format script first, then every DROP/low/HUMAN, then spot-check 20% of the high-confidence items.
- Added `scripts/check-agent-output.sh`, a format check of agent output that needs no AI. Tested against a sample brief.

## 2026-10-03: entry point and prerequisites for helper agents
- Added `AGENTS.md`, the file OpenCode, Codex and similar tools read on start. It covers: get your task ID, what to read,
  hard rules, and a ready-to-paste start prompt.
- `AGENT-TASKS.md` §1.0: prerequisites. git ≥ 2.40 (needed for `merge-tree --write-tree --merge-base`), bash 4+, Python 3.8+,
  extra tools per task with apt/brew install commands, disk and time per task, credentials, and where to put clones.
  §1.1 now branches from `origin/main` and checks the files exist. Added FCM/VINTF, sepolicy and device tree to the word list.
- Linked `AGENTS.md` from README, CLAUDE.md and HANDOVER.
- Note: `main` doesn't yet have this work (it's on `claude/vigilant-turing-jho5ul`). Agents branch from `main`, so it must be merged first.

## 2026-10-03: full repo review and cleanup
- The owner deleted `Lineage-OS-SM-T720`. All work is on `main` (pushed `41a46ac` as a plain fast-forward).
- Re-checked every doc, and fixed what had gone stale since the forks were set up:
  - README, PORTING, KERNEL-BACKPORT-PLAN, ESTIMATE, PRIOR-WORK: the device changes now live in the fork, not in `patches/`;
    the fork steps are marked done; 0004 is already in the fork; the ExyHyperBrick route is the chosen one (the old gitea sdm845 route is a fallback).
  - Checked against the kernel clone: sdm670 has no `drivers/net/ethernet/qualcomm/rmnet`, no `security/samsung`, and no KNOX `ncm`/`sec_net`;
    rmnet is `net/rmnet_data`, and `techpack/` is audio only. Fixed the docs that said otherwise.
- `AGENT-TASKS.md`:
  - §2 is now a table of all 37 task runs (tier, clone, output, time).
  - K4 now starts from the causes the build test already found, with candidate commits; 3 agents instead of 4.
  - K5 areas corrected to real paths; 5 agents.
  - K6 now has all 14 options to turn on plus 3 to turn off, and all four defconfigs.
  - R1 now targets `compatibility_matrix.6.xml`. R2 leaves out types we define ourselves. R3 has the real repo/branch names (checked with `git ls-remote`). R4 has no LFS (checked).
  - Renumbered R6/R7 to R5/R6, so there's no gap. §0.5 no longer repeats `checkout -b`.
- HANDOVER rewritten around an ordered "leftover work" list. Removed the stale "Not done yet" block from the middle of this log.

## 2026-10-03: helper rounds 1–2 reviewed and merged
- The owner ran all 39 helper tasks locally, every one on "Space Bunny Free", plus a lead synthesis
  (`lead/agent-results-2026-10-03`). Seven tasks were redone as `-r2` after the spec fixes.
- Merged into `main`: the final output of each task (r2 where present), `LEAD-SYNTHESIS.md` and `analysis/tools/`.
  Left out: the superseded round-1 outputs, the retired K4d/K5f, and the M2 link report (its one finding was already fixed).
  The `agent/*` branches are untouched.
- Review:
  - The format checker passes on all 17 batches (125 briefs + 17 summaries).
  - Re-verified 8 key lead claims against the trees, all confirmed: arm64 `set_memory.h` missing; LRU_HASH not in sdm670;
    WALT needs `CGROUP_SCHED`; TIF bit 4 and FAULT_FLAG 0x200 collisions; `ipc_router` wakeup API break; `fs/unicode` never arrives; `UPROBES` def_bool n.
  - Checked the 10 unverified DROPs line by line, all consistent. Sampled 14 MERGE/PREREQ "already in sdm670?" answers: 13 matched directly, 1 right on reading.
  - `check-pins.sh`: 8/8 OK. K1 table: 2,600 lines.
- Fixes:
  - Made the replay tools' kernel path configurable (`$K670`), and replaced the lead's local paths in the reports.
  - Fixed the AGENT-TASKS spec defects the agents reported: the wrong LRU_HASH spot-check, the K2 isolated merge-tree method (now the stacked replay), and the K5 coverage limits.
  - Added round 3 (K7 flag collisions, K8 two missing briefs, R7 property namespace, R8 LTE radio HAL, R9 soundtrigger/per_proxy_helper)
    and its batch file `analysis/agent-batches/K8.tsv`.
- Rewrote the HANDOVER state and plan (9 steps, who and where). Added a "Remaining work" estimate to ESTIMATE.md:
  ≈28 days expected (16.5–49.5), down from 34 (21–55).

## 2026-10-03: branches removed, round 4 (port by the free model) specified and dry-run tested
- The owner deleted the 47 `agent/*` and `lead/*` branches (this session's proxy refuses branch deletes). Remote now: `main` and `claude/vigilant-turing-jho5ul`.
- Decision: the free model ("Space Bunny Free") does all work steps; a strong model only reviews and handles escalations (AGENT-TASKS §10).
- New tooling, tested on a full clone with the whole series:
  - `scripts/pick-series.sh`: cherry-picks in order, stops at each conflict and prints its brief and review level, resumes, and records empty picks and drops.
  - `scripts/check-pick.py`: checks for leftover markers, trailers and the drop list, and writes review packets (`full/`, `spot/`, `automerge/`, `fixes/`).
  - `analysis/port/`: `full-review.txt` (27 commits), `dropped.tsv`, `dry-run-stops.tsv`, README.
- Dry run (mechanical resolutions, only to count): **83 stops** in 2,460 picks, not 150. 71 have a brief, 12 don't (6 are a zstd chain that follows skipped commits).
  2,373 clean, 4 apply-but-differ (e.g. `dff86fa1e78e` silently loses 5 removed lines), 5 empty.
  The dry run found 3 script bugs, all fixed: the first "cherry picked from" line was used instead of the last; an RST underline was flagged as a marker;
  a no-brief stop was labelled spot-check instead of full.
  A first dummy attempt was discarded: it deleted files on delete-type conflicts, which inflated the stops to 266 by half-way.
- AGENT-TASKS: §2.3 round 4 table; §6c specs P1 (cherry-pick), P2 (automerge triage), P3 (known fixes + defconfig), P4 (build loop with forbidden fixes
  and escalation), P5 (device tree), and the strong reviews. §0.4 now lets round-4 agents push `port/*` branches only. §0.6 covers fork tokens and protecting `lineage-23.2`. §10 says free model everywhere.
- HANDOVER plan and ESTIMATE redone: ≈24.5 days wall-clock expected (14.5–46), about 5 weeks. The first ~12 days are mostly unattended agents.

## 2026-10-03: ready for the free model to take over
- Added `RUNBOOK.md` for the owner: one-time setup (machine, `~/work` layout with a worktree per agent, two fine-grained tokens, branch protection),
  then each step in order with a copy-paste prompt and the check to run before moving on, a reviewer prompt ("Prompt R"),
  and what to do without a strong model.
- Added `analysis/port/STATUS.md`, a progress table the owner or lead updates.
- Rewrote `AGENTS.md` for research and port tasks: the port-branch exception, never force-push, never delete code to silence an error.
- AGENT-TASKS: round-4 paths now match the runbook (`$DOCS`, `~/work/k670`, `~/work/out`); P2 IDs and read-only use of the shared clone.
  Common mistakes now include the sandbox and history-rewrite traps the lead synthesis reported.
- Linked the runbook from README, CLAUDE.md and HANDOVER.

## 2026-10-03: all 39 helper-agent tasks complete; lead synthesis
Dispatched all 39 tasks in `AGENT-TASKS.md` as parallel sub-agents, each on its own branch
(`agent/<task-id>`) in its own git worktree, with the shared kernel tree mounted read-only.
One worktree per agent meant 39 concurrent agents produced zero HEAD collisions.

Results: 39 branches pushed, `main` never pushed to. 125 conflict briefs + 17 batch summaries,
4 build-error reports, 6-part driver API audit (~8,000 hits, **0 real breaks**), a 2,599-row
deterministic upstream map, 6 ROM-side reports. K2 verdicts: 76 MERGE, 22 PREREQ, 15 DROP,
0 HUMAN (75 high / 38 medium, 0 low).

Three findings that no single agent produced, now in
[`LEAD-SYNTHESIS.md`](LEAD-SYNTHESIS.md):

1. **The series does not build for arm64 as it stands.** `1f9378f37a88` (trial `CLEAN`) selects
   `ARCH_HAS_SET_MEMORY` on arm64 at `arch/arm64/Kconfig:25`, but `arch/arm64/include/asm/set_memory.h`
   exists in neither sdm670, nor ExyHyperBrick's base, nor the series head, and no commit in Exy's
   history creates it. The Exy base does *not* have that select, so the series introduces the break.
   Because both causing commits are `CLEAN`, no brief mentions it. **Fix before cherry-picking.**
2. **A whole prerequisite class is invisible to the trial**, which diffs base→head: anything living in
   ExyHyperBrick's `lineage-22.2` base, unchanged by the series, absent from sdm670. Four named
   instances now pinned: `randomized_struct_fields_end` (K4a), `ANDROID_VERSION` (K4b),
   `update_cpu_active_ratio` (K3-4), and the `set_memory.h` header. Only the compiler finds these.
3. **The isolated `merge-tree` method §K2 prescribes is unreliable in both directions** - it
   over-reports (files earlier commits have not created), under-reports (`CLEAN` commits that do
   conflict), and can report success while emitting uncompilable output. Six agents reported this
   independently. The stacked replay is correct; K2d-3 validated it against `conflict_detail.tsv`
   for all 7 of its commits. Scripts saved to [`analysis/tools/`](analysis/tools/).

Also established: all four first-build errors are **three** root causes, all blind-merge damage
(K4a/b/c), and K4d confirmed the dependency via an independent `git merge-file` replay.
Three flag/bitfield collisions found that produce **no** conflict and would silently fuse:
`TIF_*` bit 4, `FAULT_FLAG_* 0x200`, and `skc_tx_queue_mapping` narrowing to `unsigned short`.

Lead repairs: recovered K2b-1 and K2b-4 after their agents died mid-hand-in (wrote the missing brief
and the missing `## Already in sdm670?` sections); relaunched K2d-3 with incremental-commit
instructions after it produced nothing; and fixed K2a-2, which wrote verdicts as `**MERGE**` and so
failed `scripts/check-agent-output.sh` without noticing. All 17 batches now pass that checker.

Defects found in our own specs, worth fixing before the next batch: `AGENT-TASKS.md:255`'s LRU_HASH
spot-check is factually false (4 agents found it); §K6 says 11 options then lists 12; §R3's
`git ls-remote --heads https://github.com/LineageOS` returns Not Found; §K5's header list is
incomplete. And `HANDOVER.md:51`'s blocklist is stale - `wiki.lineageos.org` answers 200, only
xdaforums (403) and samfw (403) are blocked.

ROM side is in better shape than the docs implied: R6 found 1 of 22 sm7125 commits needed and
confirmed **0 of 685** vendor blobs reference NFC; R7 found 1 of 143 exynos commits needed;
R3 found 0 broken Soong variables; R4 found exactly 1 missing library of 4,711 `NEEDED` pairs.

## 2026-10-03: round 2 after the task spec was revised
`main` moved to `42b525d` "Review and clean up docs and helper tasks", which renumbered task IDs
(R6/R7 -> R5/R6), cut K4 to 3 agents, retired K5f, redefined the K5 areas, grew K6's option list to
14 on + 3 off, and corrected the R1-R4 repos and matrix level. Seven tasks were genuinely invalidated;
redone on `agent/<id>-r2` branches from `42b525d`, leaving round 1 intact for comparison.

New findings round 2 that round 1 missed, all verified by the lead against the kernel tree:
- **Silent scheduler loss.** The series' `SCHED_WALT` Kconfig adds `depends on FAIR_GROUP_SCHED`, and
  `CGROUP_SCHED` defaults to `n`, so `walt.o` can stop building with **no build error**. WALT is `y` in
  all four defconfigs. Prevented by the K6-r2 fragment's `CONFIG_CGROUP_SCHED=y`.
- **One real API break**, and not a merge conflict: `net/ipc_router/ipc_router_core.c:1384` calls the
  1-arg `wakeup_source_register()`, which `0c6f8a9a50ad` changes to 2 args. One-line fix.
- `changed-api.txt` was missing 31 changed/removed prototypes (132 -> 163 rows), including
  `bpf_jit_compile`, whose `!CONFIG_BPF_JIT` stub is deleted at head while BPF_JIT is off in all four
  defconfigs. Already defused by `CONFIG_BPF_JIT=y` in the K6-r2 fragment.
- Build with `brunch`, not bare `m`: `LINEAGE_BUILD` gates the whole `BoardConfigQcom.mk` include chain,
  and losing it empties the `qtiaudio`/`qtidisplay` namespace with no error.

Claims round 1 got wrong, corrected in round 2: `checkUnusedHals` is not a build gate;
`vendor.lineage.livedisplay` **is** covered; the combined matrix is not the union of levels <=
target-level; `fcm_exclude` is an exempt list not a deprecation list; `radio@1.4` passes the unused-HAL
check; `android_device_qcom_sepolicy` does have `lineage-23.2`; `charging_control_supports_bypass=false`
does disable bypass; `BoardConfigQcom.mk` **is** included; `sdm710` needs no manifest project.

**Retracted by this lead:** the "no `hardware/qcom-caf/*` in the 23.2 manifest" risk, which three agents
independently contradicted. It is present at `snippets/lineage.xml:102`, included at `default.xml:1030`.

Four methodology traps recorded, each of which had already fooled one agent: `ls-tree -d` hides
single-file paths; `menuconfig` hides from `^config X$`; a Kconfig `select` is invisible to a defconfig
grep; `prebuilts/api/**` in `android_system_sepolicy` is not compiled.

## 2026-10-03: round 3 complete, P1 cherry-pick complete
`main` reached `432d5f3` (rounds 1-2 merged and reviewed, round 4 planned, repo prepared for the free model).
Added `RUNBOOK.md`, `scripts/pick-series.sh` + `check-pick.py`, and `analysis/port/`. All 5 round-3 research
tasks run, plus P1 across two sessions.

**Round 3 (K7, K8, R7, R8, R9) — 6 branches, all passing `scripts/check-agent-output.sh`.**
- **K7** swept all 367 changed headers (224 examined) and found **6** bit collisions; only 2 were known.
  New: `VM_ARCH_2`/`VM_WIPEONFORK` both `0x2000000` — and the series *actively sets* that bit at
  `mm/madvise.c:99`. Also two uapi breaks in `input-event-codes.h` where `SW_MAX` itself moves, changing
  `evdev.c:813`'s `dev->swbit` sizing. K7 flagged that its own script's `suggest=` for `KEY_HOT` is `0xff`,
  a documented reserved code — do not trust `suggest=` unread.
- **K8** proved the two "unbriefed conflicts" from earlier rounds **apply cleanly** (stacked replay: 0 files,
  0 blocks, both). Those were reported as conflicts from isolated `merge-tree` — my error. K8 also found a
  **live bug** in brief `138179e5ccba.md`, which tells the reader to rename in "exactly two places" when
  sdm670 has **three** call sites; it was pushed to P1 as a correction before P1 reached it.
- **R7** closed a question two rounds failed on: the vendor property-namespace check needs
  `shippingApiLevel >= Q` (29) and ours is **28**, so it never runs. Do not set
  `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` (dead suppression) and do not rename the properties —
  `ro.fastbootd.available` is read by `system/core/init/reboot.cpp:1111` for the `adb reboot fastboot`
  fallback.
- **R8** found `target-level` is **not per-model** — it is only in `gts4lv-common/manifest.xml:1`; the LTE
  repo has no such attribute and 0 files mentioning it. And the RIL caps at radio 1.4 by four independent
  signals, with `android.hardware.radio@1.5` in 0 of 766 vendor files. So M3 is impossible, not optional.
- **R9** reversed M2: sm7125-common is at target-level 6, declares `soundtrigger@2.2` with no
  framework-matrix override, and **ships 23.2** — so keep our block. Also found no `per_proxy_helper` blob
  anywhere, so the domain is provably dead and the drafted `file_contexts` line must not be added.

Net effect on P5: **4 of its 6 items are no-ops, 1 is impossible, 1 is an owner decision.**

**P1 (kernel cherry-pick) — complete, across two sessions.**
`port/pick` at `d73f07cf8b5c`, **2,438 picks**, `check-pick.py` → **`problems: 0`** (2,372 clean, 60
hand-resolved = 23 full-review + 37 spot, 6 auto-merged-but-different). `lineage-22.2`, `lineage-23.2` and
`main` all verified untouched at `a30605a54f3b`; zero conflict markers in the tree. P1 stopped once for
context, resumed cleanly from the pushed branch, and applied all three K8 corrections.

Escalated by P1 and unresolved:
1. **`process_mrelease` is missing.** Its three introducing commits were silently removed by `classify.py:35`'s
   `EAS` regex matching inside `proc-EAS-s`/`rel-EAS-e` — the fuse-bfp defect class again, but larger. P1 could
   not verify the userspace fallback, so it escalated rather than decided. **Needs an owner answer: does the
   target `lmkd` need it?**
2. **Expect a whitespace-heavy diff at `1c225cfcb958`** — P1 introduced a `get_scan_count` tab drift, pinned
   it by tab-counting commits since the last push, and fixed it in the next commit because a rebase was
   forbidden.
3. P1 corrected its own earlier `dropped.tsv` claim that `MMF_OOM_SKIP` was absent; it is at
   `include/linux/sched.h:618`.

Deliberately unfixed: **`classify.py`**, because regenerating `conflict_detail.tsv` would change which
remaining commits `pick-series.sh` skips — a decision to make as one unit.

**Environment deviations, both deliberate and documented:**
- P1 uses a **private kernel clone** at `~/work/k670-p1` rather than `~/work/k670`, because K7/K8 read the
  latter for days while P1 moves HEAD and rewrites the tree. Cost 2.3 GB.
- **No `fork-token` was created.** SSH already has write access to both forks (verified by dry-run push), so
  no token is stored on disk.

**Next step is blocked on a strong model.** §2.3 marks P1-R, P2-R, P4-R and P5-R as **strong**. P1-R gates
P3, which gates P4 and P5. `RUNBOOK.md` "Without a strong model" permits a free-model fallback in a fresh
session with "reject anything you can't prove" and spot-checks raised to 50% — but a free model gating work a
free model produced, immediately before the build and boot phases, is the weakest link in the plan. Awaiting
an owner decision.

## 2026-10-03: P2 done, and a sweep of all 2,438 picks found 3 real defects

**P2 automerge triage — complete.** Six packets, split alphabetically 3/3 across `agent/P2-1` and `agent/P2-2`.
Result: **4 BENIGN, 2 SUSPECT** — and **both SUSPECTs are real**, which I confirmed myself against the tree
rather than accepting the verdicts.

- `agent/P2-1` (`a298309`): `15a7bd676275`, `3bfa719fe704`, `9c024897964d` — all BENIGN, high confidence. The
  first turned out to be an **xdiff artifact**: `git diff` between the two versions of `fs/fuse/backing.c` is
  empty and the two `fuse_i.h` ranges are textually identical, so only the *rendering* differed. It also
  correctly established that the two `hugetlb_fault_mutex_hash()` definitions in `mm/hugetlb.c` are the
  `#ifdef CONFIG_SMP`/`#else` pair, **not** a duplicate.
- `agent/P2-2` (`35e9029`): `ad8865db8663` BENIGN; **`d5f2acfd8dc2` and `dff86fa1e78e` SUSPECT**, both high
  confidence. It also **corrected the task premise**: `d5f2acfd8dc2` was not dropped by P1 — it was picked, with
  no `Resolved-by:` trailer, which is *why* `check-pick.py` filed it under `automerge/` rather than `full/`.
  It then generalised correctly: *the series change is already in sdm670, but the pick landed in a different
  place and duplicated it instead of being empty.*

Two process notes. `agent/P2-1` flagged that `analysis/port/P1-log.md` was absent from `origin/main` — **a false
alarm**, it is present on `origin/agent/P1` (`d497b00`, 472 lines); it is not on `main` only because nothing has
been merged yet. And `agent/P2-1` omitted §0.5's `<!-- task: … -->` markdown header from its TSV, reasoning
that a TSV parser would choke on it; defensible, `dropped.tsv` uses `#` comments for the same reason, but it is
a deviation from the letter of §0.5 and is recorded rather than waved through.

**Ad-hoc sweep — 3 confirmed defects, 183 false positives cleared.** Because P2 had established the shape of
the bug, I commissioned a sweep of **all 2,438 picks** (not a sample): 893 files, 8,848 added blocks, 186
candidates triaged. It found **two instances beyond the two P2 had already caught**, and established that P2's
pair were **7 macros, not 1** in the `drm_mode.h` case. Written up in
[`analysis/port/duplicate-picks.md`](analysis/port/duplicate-picks.md) with lead-verified line numbers.

The three: `include/uapi/drm/drm_mode.h` (7 duplicated macros), `fs/userfaultfd.c` (duplicated
`VM_MAYWRITE` check), and `arch/parisc/include/uapi/asm/socket.h` (`SO_PEERGROUPS` twice). All three are
currently **benign** — later definitions win, the check is idempotent, and parisc isn't built for arm64 — but
the first is a landmine: the series' `(0x0F<<19)` occupies bits 22:19 and **collides with
`DRM_MODE_FLAG_SUPPORTS_YUV420 (1<<22)`**, so the duplicate base copy is currently the only thing stopping that
collision.

**The F1 fix is counterintuitive and I want it recorded prominently: delete lines 92–104, the pick's copy —
*not* 106–124.** Deleting the base copy would drop `DRM_MODE_PICTURE_ASPECT_64_27` and `_256_135`, which only
it defines, *and* would leave `(0x0F<<19)` in force and cause the bit-22 collision. Two independent agents
(P2-2 and the sweep) both initially pointed at the wrong lines for different reasons; the sweep caught it.

**Third root cause found — and a correction to the sweep's own report.** F3 is not "already in base". The
series carries the **same upstream patch under two SHAs**: picks `d82d6d1f5370` (from `f013ca106eda`, 11
files) and `e78b1e3ce7ea` (from `a8793be79cac`, 1 file), same author, same timestamp. `blame` shows
`d82d6d1f5370` wrote line 98 and `e78b1e3ce7ea` wrote line 100. The sweep reported that *neither* commit
carries a `cherry picked from commit` trailer — **that is wrong; both do**, with different upstream SHAs. I
verified directly. It matters, because the trailers are the only reliable way to detect this class, and the
error would have propagated into the fix.

**What bounds the risk, and it is the most useful number here.** Two of the three defects were found in P2's
6-packet `automerge` bucket. Sweeping the **2,372-commit `clean` bucket that no human ever reviewed turned up
exactly one finding**, and it is in unbuilt `arch/parisc` and is legal C. That is real evidence the unreviewed
bucket is in better shape than the `ec3b287a8a17` anecdote suggested, and it should inform how much of the
37-commit spot-check pool genuinely needs reading before P3.

The sweep's own limitation, recorded so it is not over-read: it detects duplicate *definitions* and duplicate
*blocks*. It cannot detect a pick that landed a **semantically wrong but non-duplicated** change, which is the
larger blind spot and the reason the spot-check pool still matters.

**Still blocked on P1-R**, unchanged. §2.3 marks it **strong**. P3 waits behind it, and P4 and P5 behind P3.

## 2026-10-04: round 3, P1 and P2 reviewed and merged; P3–P5 re-specified
- Merged into `main`: K7, K8, R7, R8, R9, P1 (`P1-log.md`, `dropped.tsv`), P2-1, P2-2, and from the lead branch `LEAD-SYNTHESIS.md` (round 3 + P1 sections),
  `analysis/port/STATUS.md` and `analysis/port/duplicate-picks.md`. Local paths made generic. The format checker passes (incl. K8).
- **P1-R / P2-R done (strong model):**
  - `check-pick.py` on `port/pick` @ `d73f07cf8b5c`: 2,372 clean, 60 hand-resolved, 6 automerge, problems 0.
  - Read all 23 full-review trailers and all 69 `Needs-review:` notes. Verified the TIF, FAULT_FLAG, `get_scan_count`, oom_kill and fuse resolutions against the tree.
  - Spot-checked 8 of 37. One looked risky (`6ee017762dda`, `refcount.h`), but the result equals the series head and nothing was lost.
  - Confirmed F1/F2/F3. **No rejections.** Record: `analysis/port/review-P1.md`.
- Findings:
  - All 6 K7 collisions are already resolved in `port/pick`.
  - `wakeup_source_register` has 5 old-style callers.
  - `cpu_cgrp_id` comes from `CONFIG_CGROUP_SCHED`, not a missing commit.
  - `set_memory.h` and `fs/unicode` are still to do.
- Decisions:
  - Keep refusing KNOX NPA, CONFIG_NETPM and BINDER_SET_SYSTEM_SERVER_PID (absent from sdm670).
  - Accept the fuse-bpf override.
  - Defer `process_mrelease`.
  - Map `task_util_est()` onto WALT `task_util()`.
  - `target-level` stays 5 for the first build.
  - Leave F3.
  - Document the `classify.py` regex bug in the script instead of regenerating.
- AGENT-TASKS §6c: P3 rewritten (6 items, with "already done by P1, don't redo"); P4 gains the two decided early fixes; P5 reduced to the audio-XML commit plus a skip log.

## 2026-10-04: P3–P5 made ready for the free model
- Re-checked every P3 item against `port/pick` and wrote it as exact edits with a check per item:
  - `set_memory.h` only needs to include `asm/cacheflush.h`, because arm64 already declares and defines `set_memory_*`.
  - `fs/Makefile:93` / `fs/Kconfig:312` insertion points.
  - F1: delete `drm_mode.h:92-104`. Verified to give exactly the sdm670 base.
  - F2: delete `fs/userfaultfd.c:1417-1428`, the *second* copy, which leaves the block identical to the series head (duplicate-picks.md had proposed the first).
  - The defconfig merge rule and a 7-option `.config` check.
- P4: host-only `COMPAT_VDSO` note, build `gts4lv_defconfig` after `gts4lvwifi`, `pahole` requirement.
- RUNBOOK: steps 1–3 marked done. Dedicated copy-paste prompts and checks for P3, P4 (with the escalation loop and P4-R) and P5.
  New "Prompt O": a free-model orchestrator that may start agents and update STATUS but may not do 🔍 reviews or touch main/lineage-23.2.
- AGENTS.md: the open tasks are P3, P4, P5, and agents must follow `review-P1.md`.

## 2026-10-04: P5 and P3 complete, P4 builds — the kernel compiles for the first time

Owner installed the P4 toolchain between turns. Re-checked every item in §6c P4's list: clang 19.1.7, ld.lld
19.1.7, flex 2.6.4, bison 3.8.2, aarch64-linux-gnu-gcc 14.2.0, binutils for aarch64 and arm, dwarves 1.30,
libssl-dev, 296 GB free. `dtc` is absent and **not needed** — arm64 `.dtsi` files compile through clang, and it is
not in the spec's list. I also re-ran the spec's exact P3 item-6 command, `make O=... ARCH=arm64 LLVM=1
gts4lvwifi_defconfig`, which now exits 0, so P3 needed no deviation from the spec.

Housekeeping first: corrected `duplicate-picks.md`, which proposed deleting F2's *first* copy where the reviewer
overrode it to the *second* (`fs/userfaultfd.c:1417-1428`) to match the series head. Left alone, that file would have
sent P3 to the wrong lines. Also refreshed `STATUS.md`, which still said P1-R was blocked.

**P5 — done.** `port/dt` @ `e3ccc923bcf2`, one commit, one file: 79 lines / 499 commas in
`audio/configs/audio_policy_configuration.xml` converted from comma-separated to space-separated. `xmllint --noout`
clean, `lineage-23.2` untouched. I pre-verified its scope so it would not wander: exactly one `audio_policy*.xml`
exists, and `audio_platform_info.xml` / `audio_platform_info_diff.xml` are `audio_platform*` and out of scope —
"any other `audio_policy*.xml`" invites exactly that mistake.

I checked the commit by reversing the transform on the new file and comparing to `lineage-23.2`'s copy: **byte for
byte identical**, all 110 attributes' token lists equal, no token lost, no double or edge whitespace. That is what
distinguishes it from a blind `sed 's/,/ /g'`, which would have destroyed the 84 commas in the `sources=` route
attributes — and which the diffstat alone would not have revealed.

**My first attempt at that check returned `False`, and it was my bug**, not the agent's: I dropped the closing quote
in the replacement and mis-normalised the token lists. Third time this project an `&&` chain or a sloppy regex has
produced a wrong intermediate result. Worth stating plainly rather than quietly fixing.

**P3 — done.** `port/pick` @ `316352012ff2`, six commits, `problems: 0`, `fix commits: 6`. All verified by me:
F1 came out right (one `PIC_AR_MASK` at `<<24`, `_64_27` and `_256_135` intact, **zero** occurrences of `0x0F<<19`,
so the bit-22 collision with `SUPPORTS_YUV420` is gone), F2 down to one `VM_MAYWRITE` check, all four defconfigs
7/7. The two fragment options that cannot reach `.config` — `SCHED_TUNE` and `CGROUP_SCHEDTUNE` — are blocked by
`init/Kconfig:1536 depends on !UCLAMP_TASK` with `UCLAMP_TASK=y`, which I confirmed is the fragment's own §4.3/4.4
prediction rather than a failure.

Two things P3 did that the spec did not authorise, both correct and both documented:

- **It found a 6th `wakeup_source_register()` caller that neither the spec nor `review-P1.md` knew about.**
  `drivers/tty/serial/msm_geni_serial.c:2793` was passing a `const char *` into the new `struct device *` slot.
  Verified: `0c6f8a9a50ad`, the commit that changed the signature, touches **0** lines of that file, and the series
  has **0** commits touching it — so nothing anywhere fixed it, and `CONFIG_SERIAL_MSM_GENI=y` in all four defconfigs.
  It fixed this with `&pdev->dev`, following `wakeup.c:324` and `alarmtimer.c:1039`, and flagged it
  `Needs-review:`. **That flag is the one open question for P3-R**: `NULL` would preserve the original name-only
  behaviour more faithfully, `&pdev->dev` ties the wakeup source to device suspend. Both defensible; do not "fix" it
  without a ruling.
- **It skipped fragment section 5.** The spec's mechanical rule would have applied two `is not set` lines that are
  written as *comments*, cancelling section 1's `CONFIG_DEBUG_INFO_BTF=y` — the opposite of the fragment's intent.

P3 also caught and repaired an accident of its own: its first `git checkout port/pick` failed on a single-branch
clone, and because the command sat in an `&&` chain piped through `tail`, the following `git merge --ff-only` ran
anyway and fast-forwarded the **local** `lineage-23.2`. Repaired with `git branch -f` before any commit. I verified
the remote was never touched. Second time this project an `&&` chain swallowed a failure — the same shape that
produced round 2's two false "unbriefed conflicts".

**P4 — done, and the kernel compiles.** Both target defconfigs link `Image.gz-dtb` from clean output trees:
`gts4lvwifi_defconfig` EXIT=0 at 18,735,923 B and `gts4lv_defconfig` EXIT=0 at 18,743,864 B. All 20 warnings are
`DWARF2 only supports one section per compilation unit` from hand-written `.S` files, and the 22.2 baseline had
exactly the same 20. `check-pick.py` → `problems: 0`, `fix commits: 20`. Nothing escalated: no error needed a
forbidden fix, and no command failed twice.

I reviewed all 14 commits individually, because "no forbidden fix" was the claim most worth testing. Every diff is
1–36 lines and surgical; **nothing disables or deletes a check to silence an error.**

Two of P4's commits looked wrong to me and were not:

- **The vdso.** `include/generated/vdso-offsets.h` is 36 bytes and `vdso.so` is 3,576 B, which reads like a stub. It
  is not: arm64's vdso needs exactly **one** offset — `#define vdso_offset_sigtramp 0x0810` — and it is present,
  non-zero, with `vdso.so.dbg` linked, exporting `__kernel_clock_gettime`, `__kernel_gettimeofday`,
  `__kernel_clock_getres`, `__kernel_time` and `__kernel_rt_sigreturn` under SONAME `linux-vdso.so.1`. The large
  `__vdso_*` offset table is an x86 thing. My first check also failed outright because I looked for the binaries in
  `arch/arm64/boot/` when they live in `arch/arm64/kernel/vdso/`.
- **`5078de1ee272`, the one-line `select BPF_ARCH_SPINLOCK` P4 most wanted a ruling on.** I doubted it because the
  symbol is not in `kernel/bpf/Kconfig` and a `select` of an undefined symbol is a silent no-op. Wrong: it is defined
  in `kernel/Kconfig.locks:245`, evaluates to `CONFIG_BPF_ARCH_SPINLOCK=y` in both configs, and that makes
  `kernel/bpf/helpers.c:652` take the `arch_spinlock_t` branch, so the broken `atomic_cond_read_relaxed(l, !VAL)` at
  `:678` is no longer compiled. **The fix works.** It is not a restoration, though — neither the base nor the series
  head had that select on arm64; P4 added it, matching mainline arm64.

**The one real handoff gap.** The build needs `~/work/llvmbin` on `PATH`: Debian's `llvm-19` ships only
versioned names (`llvm-nm-19`) while `LLVM=1` looks for unversioned ones. P4 made persistent symlinks there.
Nothing in the repo, the kernel tree or `kbuild.sh` was changed — all verified clean. Without that directory on
`PATH`, `vdso.so.dbg` does not link and `vdso_offset_sigtramp` comes out **wrong**: a silently broken sigreturn
trampoline rather than a build failure. Documented in `STATUS.md` because it will bite anyone who rebuilds here.

**Open, and needing the owner or a strong model:**

- **P4-R** is now the highest-value review left. Five commits carry `Needs-review:`. I have pre-verified all five
  mechanically; what remains are judgement calls — chiefly whether to backport 4.11's `vfs_getattr()` or keep 4.9's
  two-argument form, and the fuse `pid_ns` backport.
- **The DRM format-modifier feature is half-present by the series' own design** (`1c21d6589088`). There is no
  `drm_mode_mod_get()` and no `DRM_MODE_MOD_*` anywhere in the series head, so no userspace can consume the
  `IN_FORMATS` blob it creates; no driver sets `allow_fb_modifiers`, so it is inert. P4 escalated rather than
  deleting the `drm_plane.c` hunk of `c72864d9d467`, because that would have been a deletion. Correct restraint.
- **`target-level`** is still the one open project decision. Harmless at 5 for a first build.
- **`process_mrelease`** remains unported on an unverified lmkd fallback. Check `logcat -s lmkd` at first boot.

**Next: P4-R, then step 7** — fast-forward `lineage-23.2` on both forks, which must be a fast-forward and is never
force-pushed. After that, the owner's ROM build, for which the one instruction that matters is
`brunch lineage_gts4lvwifi`, not a bare `m`.

## 2026-10-04: P3, P4, P5 reviewed and merged; kernel build independently confirmed
- Merged the lead branch `lead/2026-10-04` (it fast-forwarded: STATUS, HANDOVER, RUNBOOK, LEAD-SYNTHESIS, WORKLOG, duplicate-picks) and the
  P3/P4/P5 logs. Local paths made generic.
- **P3-R, P4-R, P5-R (strong model): all pass, no rejections** (`analysis/port/review-P4.md`).
  - Read all 20 fix commits on `port/pick` (6 P3 + 14 P4), and the `port/dt` commit.
  - Ruling: `&pdev->dev` at `msm_geni_serial.c:2793`.
  - Accepted: the BPF_ARCH_SPINLOCK select, cred-based binder LSM hooks, the 4.9 fuse/vfs_getattr forms, tracepoints widened 12→18, and the inert DRM `IN_FORMATS` property.
- **Independent build:** rebuilt `port/pick` @ `801f3f20e54a` here (clang 18, `gts4lvwifi_defconfig`).
  - `Image.gz-dtb` 18.7 MB, 0 errors.
  - WALT, CGROUP_SCHED, FAIR_GROUP_SCHED, BPF_SYSCALL/LSM/JIT, UPROBES, UNICODE and BTF all `=y`.
  - `vdso_offset_sigtramp` 0x810.
- P5: confirmed sm7125-common 23.2 ships space-separated audio policy lists (0 comma lists). Audio on HAL 6.0 is to be checked at first boot.
- `analysis/build-test/kbuild.sh` now refuses to run without the unversioned `llvm-*` tools (the silent broken-vDSO trap the lead found).
- Added P6 (ROM build-error loop, free model, with allowed and forbidden fixes) to AGENT-TASKS §6c, RUNBOOK §8 (8a–8d) and STATUS.
  Updated AGENTS.md (only P6 open), HANDOVER (owner to-do: fast-forward, ROM build) and ESTIMATE: ≈14 days wall-clock left (7.5–27).

## 2026-10-04: branches checked; ROM phase made ready for the free model
- The owner deleted `agent/P3`, `agent/P4`, `agent/P5` and `lead/2026-10-04`. Remote is clean. The forks' `lineage-23.2` are not fast-forwarded yet (owner step 7).
- **Fixed a command that would have failed:** the docs said `brunch lineage_gts4lvwifi`, but LineageOS 23.2's `breakfast` adds the `lineage_` prefix
  itself (`vendor/lineage/build/envsetup.sh`), so that becomes `lineage_lineage_gts4lvwifi` and fails. Now `brunch gts4lvwifi` everywhere
  (AGENT-TASKS, RUNBOOK, HANDOVER, STATUS, LEAD-SYNTHESIS, analysis/rom/soong.md). PORTING §3 no longer says the kernel has no port.
- New free-model tasks in AGENT-TASKS §6c with RUNBOOK prompts:
  - **B1**: ROM sync and first build on the owner's machine. It pre-checks that step 7 was done, installs packages and repo, syncs,
    verifies the kernel and device commits, builds, and doesn't fix errors itself.
  - **P7**: read-only boot-log triage per flash attempt into `analysis/port/boot-<n>.md` for the strong model.
- STATUS, AGENTS.md and HANDOVER updated to match (open: B1, P6, P7).

## 2026-10-04: step 7 done
- Fast-forwarded both forks' `lineage-23.2` with plain (non-force) pushes, after checking ancestry:
  kernel `a30605a54f3b` → `801f3f20e54a` (= `port/pick`), device tree `2e50286` → `e3ccc923bcf2` (= `port/dt`).
  The local manifests (which track `lineage-23.2`) now pull the port. Next is B1 (ROM sync and build). STATUS, HANDOVER, RUNBOOK, CLAUDE.md and REPO-SETUP updated.

## 2026-10-04: ROM phase reached — step 7 done, tree synced, build blocked by the host

**Step 7 verified.** Both forks' `lineage-23.2` fast-forwarded to the port: kernel `801f3f20e54a` (2,458 commits
past the sdm670 base), device `e3ccc923bcf2` (1 commit). `lineage-22.2` untouched on both. `port/pick` ==
`lineage-23.2` and `port/dt` == `lineage-23.2`, so nothing was clobbered.

**Toolchain and packages.** The owner installed the §6c P4 set plus B1's 30 packages. Everything present.
`libxml2` looked missing to `dpkg -s` but is installed for both amd64 and i386 — a multi-arch reporting quirk, not
a gap. All 30 exist in Debian 13 (trixie) with no renames needed. **My earlier suggestion to clear ccache was
wrong**: it was empty (0.0 of 5.0 GiB) and lives at `~/.cache/ccache`, so that would have freed nothing.

**Manifest pre-flight before fetching anything** — worth doing, because a bad manifest fails only at the end of a
multi-hour sync. All six projects resolve, and two land *exactly* on the ported commits (`801f3f20e54a`,
`e3ccc923bcf2`). Also verified LineageOS's own `default.xml` declares the `remote="github"` our manifest
references; an undeclared remote would otherwise have failed hours in.

**Sync: 1,170 projects, 181 GB.** Four repos lost to GitHub HTTP 429 rate-limiting at `-j12`
(`platform/external/tinyalsa_new`, `platform/tools/doc_generation`, `trusty/lib`, `trusty/user/desktop`).
Retrying at `-j4` recovered `trusty/user/desktop`; the other three sit in `.repo/projects/` with the checkout
skipped. **None is referenced by our device trees**, and `tinyalsa_new` is a Qualcomm audio library while sdm670
uses Samsung's own stack. `repo` reporting "finished successfully" while leaving three projects absent is a real
trap — the retry saw the git data and considered them done.

**`brunch gts4lvwifi` failed twice, both times OOM-killed during Soong's glob phase.** Direct evidence:

```
rombuild.service: A process of this unit has been killed by the OOM killer.
rombuild.service: Failed with result 'oom-kill'.
rombuild.service: 21min 24.848s CPU time, 14.2G memory peak, 13.6G memory swap peak.
```

Android's build system warned beforehand: *"You are building on a machine with 15.4GB of RAM. The minimum required
amount of free memory is around 16GB, and even with that, some configurations may not work."* Measured
`soong_build` at 13.6 GB RSS with 0 GB available and 8 GB of swap consumed. **No code was ever reached, so this is
not a port defect and not P6's work.** `-j` cannot help: globbing runs before ninja and is single-process. Disk was
never the constraint — 96 GB free held through both attempts.

### Three process failures worth remembering, all mine

1. **I diagnosed "not a memory problem" from `dmesg` showing no OOM kill.** Technically true and practically
   useless: the OS killed the *terminal session* for low memory, which killed the build. Absence of an OOM record
   is not absence of memory pressure. I over-claimed from a negative.
2. **`setsid` does not detach from the systemd cgroup.** It escapes the session ID but the job stays in the
   launching shell's scope, so a session kill takes it down. The cgroup was visible in `ps` and I read past it.
   `systemd-run --user --unit=…` gives a job its own unit; the retry under it was correctly isolated and *still*
   OOM'd, which is how we know fault one was real but not the only problem.
3. **My build wrapper masked the failure.** It captured `brunch`'s status then ran more commands, so the unit exited
   0 and systemd reported `Result=success` for a failed build. A unit wrapper must `exit $st`. Trusting that would
   have been a bad call.

Also: a waiter script I wrote reported `NOT SYNCED` for both repos and `tree size: 90M` because I ran it without
`cd ~/android/lineage`, so it looked relative to the docs repo. The real result was PASS. **A verification step
whose own working directory is wrong is worse than no verification**, because it looks authoritative.

**Left for the owner:** run the build on a machine with 32 GB. The tree is a normal `repo` checkout and is
portable; **[analysis/port/BUILD-HANDOFF.md](analysis/port/BUILD-HANDOFF.md)** is a self-contained recipe —
requirements, both ways to get the tree, the package list, the two commits to verify, the build command, the traps,
and P6's forbidden list. `P6` has deliberately **not** been started: there is no port error to hand it, and
pointing it at a memory shortage would only have it chase a phantom.

## 2026-10-04: B1 merged; cloud-session build ruled out
- Merged `agent/B1` (fast-forward). On the owner's 15 GB machine, sync and setup passed, but `brunch gts4lvwifi` was OOM-killed twice
  in Soong's glob phase (14.2 GB RSS + 13.6 GB swap). That's a host limit, not a port defect. `analysis/port/BUILD-HANDOFF.md` has the bigger-machine recipe.
- Checked whether a Claude Code cloud session could build instead: no. It has 4 CPUs, 15 GB RAM and ~25–30 GB of writable disk, against ~180 GB sync + ~40 GB out
  and the same RAM that already failed. Recorded in BUILD-HANDOFF.md.
- Fixed the stale comment in `local_manifests/gts4lv-common.xml` that B1 flagged.

## 2026-10-05: the ROM builds — `lineage-23.2-20261005-UNOFFICIAL-gts4lvwifi.zip`

```
1,133,973,020 bytes
sha256  cc2c82e796e7fa3678bf8169f8c6ba7ffdedfe2e79e3e0b697b55790927a39ea
```

All of `out/` (119 GB, zip included) is on the removable drive — a single bind mount of `/dev/sda[/out]`, no nested
mounts. `out.old` (46 GB) is still on the NVMe and can be reclaimed once the ROM is confirmed good.

**The host OOM was solved by the owner's 32 GB swapfile.** Peak went to 14.2 GB RSS + 28 GB swap and the build
survived; previously 15 GB RAM + 15 GB swap was killed twice. Android's own warning ("15.4GB of RAM… minimum is
around 16GB") was accurate but the swapfile bought the headroom.

**`out/` had to move to the drive mid-build.** At 40% the NVMe had 20 GB against a 30–50 GB `out/`. The relocation
itself was clean — `.ninja_log`, `.ninja_deps` and 39,261 object files all transferred, and `sda` turned out to run
at 1.6% utilisation, so the USB move cost nothing in speed. **But restarting afterwards cost 6.6 hours of build
time**, because `rom-build2.sh` omitted `USE_CCACHE=1` while the 6.6-hour run had it set. That changes every
command line ninja hashes, so all 92k completed targets were invalidated and the build restarted from zero.
**The wrapper now exports `USE_CCACHE=1` permanently, with a comment saying why.** A second restart attempt to
recover the lost work failed for the same class of reason, so ~7 hours went to that mistake.

**Also lost to my own diagnosis:** I reported the CPU as "pinned at 800 MHz, ~4x speedup available" from
`scaling_governor=powersave`. Later under sustained load it read 3,100 MHz with no change, so the governor biases
idle but `intel_pstate` boosts on its own under load. The finding was real but I overstated how permanent it was.
The owner was right to decline the change.

**Two errors fixed in the end, and neither needed a code change.**

1. `AntHalService` — a dangling `PRODUCT_PACKAGES` entry that kati refuses. `d154fb4` on `port/dt-2`. P6 found the
   precedent itself: `dd5671a31b39` added it with `com.dsi.ant.antradio_library`, and `635baf7e30aa` removed the
   latter as "no longer shipped by default with lineage-19.0" and left this behind.
2. `webview.apk` was a **134-byte git-lfs pointer**. `git-lfs` was installed at 10:35:20, three minutes *after* the
   tree was checked out at 10:32:32, so the sync predated the package install. `git lfs pull` fixed it.

**I briefed P6 on the wrong error.** I named `Disallowed PATH tool "arm-linux-gnueabi-ld.bfd"` as the blocker. P6
reproduced it, found it **non-fatal**, and went on to the real first error. The vDSO was linked by the in-tree
`ld.lld` by absolute path; `.path_interposer` was never the linker. P6 also **declined the fix I had suggested** —
point `CROSS_COMPILE_ARM32` at the host `/usr/bin/arm-linux-gnueabi-ld.bfd` — because it would make the ROM
non-hermetic and is not reachable from the device tree. It was right and it contradicted me.

P6 also introduced a technique worth keeping: **`mka bacon -k 0`** enumerates *every* remaining failure in one
pass. It covered 5,099 remaining targets in 1 h 11 min and found exactly one real error — versus one error per
15-hour run before. Any future P6 run should use it.

**The zip is not a from-scratch verified artifact.** It came from `mka bacon -k 0`: ninja packaged past a failure
and then exited 1. Contents are complete and it should flash, but a clean `brunch` has not been proven on this tree.
`confidence: medium`.

### Escalated, not fixed — needs an owner ruling

`libwfdservice` (32-bit) will fail to load. AOSP `709977845deb` added a 4th parameter (`bool deviceSwitch`) to
`AudioSystem::setDeviceConnectionState`; the 2019-era blob calls the 3-argument form. Proven from the shipped image:
3-arg call sites = 0, 4-arg = 1. CFI ruled out by direct test. **Latent, not certain** — nothing sets
`vendor.wfdservice=enable`, so it stays `disabled`, and WFD is only Wi-Fi Display.

P6 did not fix it because every option is destructive or out of scope: `allow_undefined_symbols` turns a build
error into a **boot-time `dlopen` failure** (the blob is `BIND_NOW`); dropping it removes WFD; the real fix is
extending `hardware/lineage/compat/libwfdservice/`, which is not P6's write scope. LineageOS already did exactly
this for a *different* symbol in `8a4285c0377`, so there is a known path. `confidence: high`.

### The lesson worth keeping

**A green build does not prove a fix is correct.** When the error is a *guard* rather than a missing symbol, the
cheapest green build is usually the guard being removed rather than the problem solved. For the linter-style errors
here, five fix shapes all produce a green build and are not equivalent — one correct, and four that silently drop
32-bit support or weaken a security boundary. `P6-log.md` now carries the five review questions to ask instead of
"does it build": does `CONFIG_COMPAT=y` still hold, was `vdso32` genuinely built rather than skipped, do the 32-bit
modules exist, was anything disabled or allowlisted rather than made to work, and is the real linker being used.

**Next:** the owner's flash, per `README.md`. ⚠️ **unlocking and installing erases all data on the tablet.** Then
P7 for log triage. `P6-R` is still worth running, mainly to rule on `libwfdservice` — flash with it, or fix it
first.

## 2026-10-05 (lead review): P6-R passed; device fork moved on; README rewritten

- **P6-R passed** ([review-P6.md](analysis/port/review-P6.md)). Fix 1 (`AntHalService`, `d154fb4384fb`) accepted. Fix 2 (git-lfs) needed no code change.
  The decision to leave the non-fatal `arm-linux-gnueabi-ld.bfd` message alone was accepted.
- **`libwfdservice` ruling:** flash allowed. It is latent and only affects Wi-Fi Display (screen casting).
  Upstream `hardware/lineage/compat` @ `8a4285c` shims `broadcastWifiDisplayAudioIntent`, but our `libwfdservice.so` doesn't link the shim.
  Fix later as P8: re-extract with an `add_needed` fixup, which needs a vendor fork, or drop WFD.
- **Device fork `lineage-23.2` fast-forwarded `e3ccc92` → `d154fb4384fb`.** Pins updated in CLAUDE, REPO-SETUP, AGENT-TASKS, BUILD-HANDOFF and the manifest comment.
- Merged `lead/2026-10-04-drive`, `agent/P6` and `lead/2026-10-05`. Fixed a broken STATUS row, and changed `/home/anton/` to `~/`.
- **README rewritten:**
  - current status (kernel ported and building, Wi-Fi ROM built, not booted);
  - a prior-work credits table;
  - concise install steps: a path chooser (stock → A, LineageOS 22.2 → B), Wi-Fi vs LTE differences, and ⚠️ on every data-erasing step;
  - the build command fixed to `brunch`.
- Next: owner flashes (⚠️ erases data), then P7. LTE build after the first boot.

## 2026-10-05 (helper lead): P6-R notes; zip ships recovery.img; README install tweaks

**P6-R: pass.** Device fork `lineage-23.2` fast-forwarded `e3ccc92` → `d154fb4384fb`. All four items accepted, with
one deferral. The review checked P6's `libwfdservice` diagnosis against upstream and found a better fix than P6
proposed: LineageOS `hardware/lineage/compat` @ `8a4285c` already re-implements
`WiFiDisplaySession::broadcastWifiDisplayAudioIntent(bool)`, and this device tree already ships
`libwfdservice_shim.so` (`extract-files.py:45-46`) — it simply is not listed in the `libwfdservice.so` fixup's
`shared_libs`, so the shim never interposes. So it is a one-line fix rather than a rewrite, deferred to a future
task because it needs a fork of `proprietary_vendor_samsung_gts4lv-common`. **Flash is allowed now** — WFD is
optional, `wfdservice` only starts on `vendor.wfdservice=enable`, and if it did fire only that one service would
fail. `allow_undefined_symbols` was rejected because it hides the check and leaves the runtime failure in place.

The review also accepted the `mka bacon -k 0` zip for a first flash: the only failed edge is `check_elf_file`, a
validation step, and P6 proved the installed blob is byte-identical — so the zip equals what a clean build would
give, minus that check.

**The kernel backport is still unproven until boot.** The reviewer was explicit about this: 2,458 commits are
ported, reviewed and building, but the real test is whether `bpfloader` and `netd` come up, then
`scripts/device-checks.sh` and the BPF tests.

### The zip ships its own recovery — verified, and it changes the flashing steps

Checked directly rather than assumed:

```
boot.img 64 MB   dtbo.img 8 MB   recovery.img 64 MB   vbmeta.img   system/vendor .dat.br
```

So **a separate recovery flash is a one-time bootstrap, not a per-install step.** The sideload installs
`recovery.img` itself. It is needed only when the recovery already on the tablet predates 23.2 — which is the
stock case (stock recovery cannot sideload, and stock boot overwrites the recovery partition on every boot), and
the 22.2 case.

**(Later withdrawn in `d87db77`: there is no Path B2/MicroG.)** Path B2 was added to `README.md` for MicroG, which was a genuine gap — the routing table only covered Samsung stock
and LineageOS 22.2, so a MicroG user had no documented route. Path B2's substantive points: data is erased (MicroG
is signed with different keys, so there is no keep-data option); MicroG ships **no Google apps, so add none**
afterwards; the recovery-version check decides whether step 3 is needed at all; and expect an **unverified-package
signature prompt**, because these builds are `UNOFFICIAL` — declining it is the most likely immediate failure.

Also corrected the "you need" line: `samloader` is only required on paths that flash recovery or vbmeta
themselves, not for a plain sideload.

## 2026-10-06 (lead review): flash blocker; install procedure corrected

- Merged `lead/2026-10-05b`: README tool install, MindTheGapps, FRP warning and the 47% sideload quirk (all checked
  against the LineageOS wiki source), plus FLASH-BLOCKER.md.
- **The A/B hypothesis is wrong:** `AB_OTA_UPDATER := false`, and the wiki gives a single `recovery` partition. Also,
  Lineage Recovery has no "disable signature verification" menu. Both are corrected in FLASH-BLOCKER.md.
- **Owner report:** the tablet cycles into Download mode. Likely cause: the force-reboot → recovery button sequence
  with USB plugged in (*Vol Up + Vol Down + Power* + USB = Download mode). Second possibility: the 23.2 recovery's
  untested kernel crashing.
- **README changes:**
  - Path B now installs from the **22.2 recovery** (it accepts the unofficial zip after a *Yes* prompt), so a
    working recovery stays on the tablet until 23.2 has booted.
  - Path A recommends going through official 22.2 first.
  - New section "Stuck in Download mode?".
  - "Unplug USB" added before the recovery button sequence.

## 2026-10-06 (lead review 2): the 23.2 recovery doesn't boot; likely the kernel is too big

- Merged the rest of `lead/2026-10-05b`. Its control test was good: the 22.2 recovery, flashed with the same samloader
  command, boots. So the procedure is fine and our `recovery.img` is the failing part. My earlier "button sequence /
  use the 22.2 recovery" ruling is withdrawn.
- **Sideloading 23.2 from the 22.2 recovery can't work:** Android 16 bionic `arc4random.h:63-64` aborts when
  `madvise(MADV_WIPEONFORK)` fails, and 22.2's base kernel lacks it. That is the SIGABRT (signal 6). Our kernel has it.
- **Likely cause of the recovery not booting:** `CONFIG_DEBUG_INFO_BTF=y` (P3 `316352012`) adds an 8.5 MB `.BTF` section.
  Rebuilt here without it: `Image` 48.7 → 40.2 MB, `image_size` 57.0 → 48.5 MB, `Image.gz-dtb` 18.7 → 16.1 MB.
  The 22.2 kernel is 15.6 MB. Pushed test branch `port/no-btf` @ `cfe0b6979` to the kernel fork (not `lineage-23.2` yet).
- README Path B: the 23.2 recovery flash is required again, with a "known issue" note. FLASH-BLOCKER has the test.

## 2026-10-06 (lead review 3): the no-BTF kernel failed too; it is the kernel, and we need its log

- Merged `lead/2026-10-05b` rulings 3–5. Their results:
  - the no-BTF recovery fails;
  - a with-BTF `boot.img` fails on `BOOT` (mislabelled `boot-nobtf.img`, which they caught themselves);
  - the AVB key, fstab and ramdisk all match the 22.2 recovery that boots.
  Corrected two things: the port is 2,458 commits, not 20; and tests should go on `RECOVERY`, so 22.2 keeps booting.
- Reviewer builds here:
  - base `a30605a54f3b`: `Image.gz-dtb` 15,588,530 bytes, `Image` 39.1 MB;
  - ours without BTF: 16,050,450 bytes, 40.2 MB.
  The appended DTBs are byte-identical, and the arm64 header flags and text_offset are identical. The port doesn't touch
  `arch/arm64/boot`, dtc or `head.S`. So the bootloader is very unlikely to be rejecting the image: our kernel most
  likely starts, then dies.
- **Next (FLASH-BLOCKER ruling 6, Step A):** flash the test kernel to `RECOVERY`, let it fail, boot 22.2, then read
  `/proc/last_kmsg` (Samsung `sec_log`) and pstore. No build needed.
- Step B is ready: kernel branch `test/base-config` (ported code + 22.2 defconfigs + `KPROBES` + `CGROUP_SCHED`)
  builds here (15,939,579 bytes). Found on the way: `KPROBES=n` with `UPROBES=y` doesn't build (`asm/kprobes.h`
  vs the stub in `linux/kprobes.h`). Not our config, so it is only noted.
- Owner ran Step A. Download mode showed nothing unusual. With `recovery-nobtf.img` in `RECOVERY`, even a normal
  boot fell into Download mode, until the with-BTF `recovery.img` was flashed instead. So after a failed recovery
  boot, the bootloader keeps trying recovery. Step A is revised: keep 22.2's recovery in `RECOVERY`, test
  kernels in `BOOT`, and read `/proc/last_kmsg` from the 22.2 recovery.

## 2026-10-06 (lead review 4): the cause, from last_kmsg

- The owner read `last_kmsg` from the 22.2 recovery after a test `boot.img` on `BOOT`. **Our kernel
  (`-gcfe0b6979655`) booted all its drivers.** Android 16 init then failed: `SELinux: avtab: invalid type or class`,
  then `Could not load policy`, then `InitFatalReboot`, then `reboot bootloader`, which is Samsung's Download mode.
- Cause: the Android M avtab compatibility hack in the base msm-4.9 `security/selinux/ss/avtab.c`. It misreads
  extended-permission rules with new specifiers (Android 16's nlmsg xperms). The S9 kernel doesn't have it.
- Fix: kernel branch `port/selinux-avtab` @ `500658be3c16` = `801f3f20e54a` + avtab.c set to the S9 version.
  It compiles here. Owner to test it on `RECOVERY`.
- Size/BTF/AVB/ramdisk theories are all closed. `port/no-btf` and `test/base-config` aren't needed for this; delete them later.

## 2026-10-06: the 23.2 recovery boots

- Owner built `recoveryimage bootimage` on `port/selinux-avtab` (`kernel.release` checked) and flashed `recovery.img`.
  **The LineageOS 23.2 recovery boots and shows 23.2.** First proof that the ported kernel runs Android 16 userspace.
- Kernel fork `lineage-23.2` fast-forwarded `801f3f20e54a` → `500658be3c16`. Pins updated in CLAUDE, REPO-SETUP,
  the manifest comment, HANDOVER, AGENT-TASKS and BUILD-HANDOFF. README marks the 20261005 zip as broken.
- Next: rebuild the zip with the fixed kernel (`mka bacon -k 0`), ⚠️ format data, sideload, first boot.
- The owner can delete these kernel branches: `port/no-btf`, `test/base-config`, `port/selinux-avtab` (now equal to `lineage-23.2`).

## 2026-10-07: handoff to a local agent for the full ROM (task B2)

- New **[analysis/port/B2-HANDOFF.md](analysis/port/B2-HANDOFF.md)**: a self-contained brief for a local agent. It covers:
  - the current commits (kernel `500658be3c16`, device `d154fb4384fb`);
  - the build (`mka bacon -k 0`) and its expected noise;
  - checking the kernel inside images;
  - the ⚠️ install steps the owner runs;
  - reading `/proc/last_kmsg` from the 23.2 recovery on failure;
  - the likely next failures;
  - the agent rules;
  - a current/future work table (B2, P7, P8, testing, LTE, process_mrelease, upstream/krazey/devrel, branch cleanup).
- Linked from AGENTS.md (open tasks B2 + P7), AGENT-TASKS §6c (B2 spec), RUNBOOK §8c (B2 prompt), HANDOVER (plan
  and owner to-do), STATUS (row 9), analysis/port/README.md (index) and TESTING.md (new §2a on `last_kmsg`).
- Fix branches for new work: `port/k-<n>` (kernel) and `port/dt-3` (device), both from `lineage-23.2`. `port/pick` is gone.
- HANDOVER marks the 20261005 zip as broken (pre-fix kernel).

## 2026-10-07: B2 build result — succeeded (expected failure only)

- `mka bacon -k 0` finished 08:17 after 16 h 31 m with `ninja failed with: exit status 1`. `zgrep "^FAILED:" out/verbose.log.gz`
  lists exactly one: `libwfdservice.so.check_elf_file` (the known P8 WFD blob break). Nothing else failed.
- Zip: `lineage-23.2-20261006-UNOFFICIAL-gts4lvwifi.zip`, sha256 `691512f32e27801342c454e249a25821c92e5aca8ccfb28040a1a376473d029f`.
  The `boot.img` inside it (gzip kernel, so plain `strings` finds nothing) decompresses to `Linux version 4.9.337-g500658be3c16`.
  `KERNEL_OBJ/.../kernel.release` agrees.
- The old `…-20261005-…zip` name is now a hardlink to the **same inode** as the new zip (and `lineage_gts4lvwifi-ota.zip`), so the
  broken 20261005 build no longer exists on disk. To avoid confusion, sideload the 20261006 name.
- Next: ⚠️ format data, sideload, MindTheGapps, first boot (B2-HANDOFF §3).

## 2026-10-07: boot-2, first full-ROM boot → Download mode; cgroup fix

- Old build files deleted (20261005 zip name, `~/work/{boot-nobtf,recovery,recovery-nobtf}.img`). The owner deletes the
  merged/superseded branches (`port/no-btf`, `test/base-config`, `port/selinux-avtab`, `lead/2026-10-05b`) over SSH.
- Owner flashed the 20261006 zip + MindTheGapps. Result: Download mode. `last_kmsg` from the 23.2 recovery shows
  `reboot,bootloader,bootstrap-apexd-failed` at 3.1 s. Cause: `first_api_level=28` loads `cgroups_28.json`, where
  `schedtune` is mandatory, but the uclamp kernel has no schedtune. Details: [analysis/port/boot-2.md](analysis/port/boot-2.md).
- Fix: device fork `port/dt-3` @ `a7f1483` ships `cgroups_30.json` + platform `task_profiles.json` on vendor (same
  approach as krazey's exynos9810 `385c2db`). Rebuilding to `~/work/rom-build4.log`.
- Build trap: in the agent's shell `grep` is `ugrep`, which breaks `envsetup.sh` (`breakfast` fails in 4 s). Run builds
  with `env -i … bash --noprofile --norc`.
- Rebuild done 10:25 (1 h 26 m, `USE_CCACHE` unset as on 10-06; setting it would have forced a full rebuild). Only
  `FAILED:` is libwfdservice. Zip `lineage-23.2-20261007-UNOFFICIAL-gts4lvwifi.zip`, sha256 `5a8a4830…4211e714`;
  kernel `-g500658be3c16`; `vendor.img` has `/etc/cgroups.json` with schedtune `Optional` and the 15069-byte
  platform `task_profiles.json`. Next: boot-3 (sideload, no format needed).

## 2026-10-07: boot-3 (20261007 zip) → boot-animation loop; lmkd fix; debug build

- Cgroup fix confirmed on the device. New loop: system_server dies about every 11 s ([analysis/port/boot-3.md](analysis/port/boot-3.md)).
- lmkd exits right after every start: `ro.lmk.use_minfree_levels=true` needs memcg v1, and Android 16 has only v2. Fix: device `port/dt-3` @ `4f4a15c` (PSI).
- The system_server cause isn't in pstore. Building with `WITH_ADB_INSECURE=true` (debug only, `~/work/rom-build5.log`) to get logcat during the loop.
- pstore's `pmsg-ramoops-0` is a binary logcat ring. Decode it with `scripts/pmsg-decode.py`.

## 2026-10-07: boot-4 (debug build) → system_server: no /metadata for aconfig; OMR as /metadata

- `logcat -b crash`: `Missing permission definition for permission "android.permission.RANGING" associated with app op 151`.
  Flag storage is unreadable because the tablet has no `/metadata`. Details: [analysis/port/boot-4.md](analysis/port/boot-4.md).
- Fix: device `port/dt-3` @ `b26a9d6` uses OMR as `/metadata` (same as official exynos9820-common `b6a153f`). ⚠️ Format OMR once from recovery.
- Rebuilding (debug, `~/work/rom-build6.log`).

## 2026-10-07: boot-5 — LineageOS 23.2 boots on SM-T720

- ⚠️ OMR formatted ext4 from recovery (20 MB). Debug zip sideloaded. Boot completes. No crashes. `/metadata` on OMR works,
  lmkd runs, and **NetBpfLoad loads all networking BPF programs** (the eBPF backport works). Details: [analysis/port/boot-5.md](analysis/port/boot-5.md).
- Device `port/dt-3` @ `b26a9d6` (3 fixes on `lineage-23.2`) is the booting tree. Next: owner testing, then a release build.
