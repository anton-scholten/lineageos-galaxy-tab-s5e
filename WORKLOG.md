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
- Merged `lead/2026-10-04-drive`, `agent/P6` and `lead/2026-10-05`. Fixed a broken STATUS row, and replaced absolute home paths with `~/`.
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
- Device `lineage-23.2` = `b26a9d6` (boot-proven). `port/dt-3` @ `3557101` adds uclamp (untested). Next: owner testing, then a release build.

## 2026-10-07: post-boot work (owner: mic, camera, speakers, Wi-Fi, hotspot and per-app data usage all work)

- Docs branch `claude/vigilant-turing-jho5ul` deleted (merged into main). The other leftover branches were already gone.
- Device `port/dt-3` @ `3557101`: schedtune setup in `init.qcom.power.rc` replaced with uclamp. The cpuctl `cpu.uclamp.*`
  files were `root:root 0644`, so the platform task profiles couldn't boost anything. Modelled on krazey `385c2db`.
  **Not yet booted.**
- Device `lineage-23.2` fast-forwarded `d154fb4384fb` → `b26a9d6` (the three boot-proven fixes).
- `scripts/device-checks.sh` check 3 now uses `service list` + `dumpsys connectivity` BPF status: 5 PASS / 1 SKIP.
- Release build (no `WITH_ADB_INSECURE`) running: `~/work/rom-build7.log`.
- Known: the QTI perf HAL's `commonresourceconfigs.xml` (vendor blob) still targets `/dev/stune/*` nodes. Those boost
  opcodes fail silently; the cpufreq boosts still work. Possible follow-up: remap them to `cpu.uclamp.*`.

## 2026-10-07: P8 (Wi-Fi Display) fix

- Cause: `libwfdservice.so` (32-bit) was built against Android 15 QPR2 and references the 3-arg
  `AudioSystem::setDeviceConnectionState(state, AudioPort, format)`. Android 16 added `deviceSwitch`. LineageOS's
  `libwfdservice_shim` (hardware/lineage/compat) only covers pre-15-QPR2 blobs.
- Fix: device `port/dt-3` @ `e38c0de` adds `shims/libwfdservice` (`libshim_wfdservice`, which provides the old symbol and forwards with
  `deviceSwitch=false`) plus the blob fixup `.add_needed('libshim_wfdservice.so')`. The patched blob lives on the new vendor fork
  `anton-scholten/proprietary_vendor_samsung_gts4lv-common` `lineage-23.2` @ `bceca6f` (forked from TheMuppets `lineage-22.2` @ `b04a4ee`).
  `local_manifests/gts4lv-common.xml` now points vendor at that fork.
- Release + P8 build: `~/work/rom-build8.log` (the release-only build7 was stopped in favour of this one). Pass criterion:
  no `FAILED: …libwfdservice.so.check_elf_file`. On the device: cast to a Miracast receiver (e.g. the Windows "Wireless Display" app).
- build8 **completed successfully** (1 h 32 m): the first build with **no `FAILED:`**. `libwfdservice.so` DT_NEEDs `libshim_wfdservice`;
  kernel `-g500658be3c16`; `ro.adb.secure=1`, `ro.debuggable=0`. Zip `lineage-23.2-20261007-UNOFFICIAL-gts4lvwifi.zip`
  sha256 `237e7104575b3f55…`, kept as `out/keep/lineage-23.2-20261007-release-p8.zip` (hard link on the build drive). `-k 0` is no longer needed.

## 2026-10-07: release build + matching recovery flashed; branches merged

- Owner flashed `recovery-20261007-release-p8.img` (samloader `RECOVERY`) and sideloaded the release+P8 zip over the debug install. No problems.
- Device fork `lineage-23.2` fast-forwarded `b26a9d6` → `e38c0de` (uclamp + WFD shim). `port/dt-3` deleted. Local build-tree checkouts:
  device and vendor on `lineage-23.2`, stale local branches (`port/dt-2`, `port/dt-3`) deleted.
- Branches now: kernel `lineage-22.2`/`lineage-23.2`; device `lineage-22.2`/`lineage-23.2`; vendor `lineage-22.2`/`lineage-23.2`; docs `main`.
- HANDOVER, README and STATUS rewritten for the booting state and the next steps.

## 2026-10-07: crash-log check, LTE build, README, XDA draft

- Release build, 17 min uptime: crash buffer empty. Dropbox: 669 `system_server_crash`, all 09:00–12:17 (the
  pre-/metadata boot loops), none since. ~1,000 SELinux denials, mostly `system_suspend` → `/sys/class/wakeup/*`
  (labelled `sysfs`, should be `sysfs_wakeup`): only the wakelock stats are lost. Follow-up: genfs labels in the device sepolicy.
- LTE: `local_manifests/gts4lv.xml` added to the build tree (official `gts4lv` device + TheMuppets blobs, `lineage-22.2`).
  `brunch gts4lv` **completed successfully** in 2 h 51 m, no `FAILED:`. Kernel `-g500658be3c16` from `gts4lv_defconfig`;
  `libsec-ril`, qcril init and `android.hardware.radio` are in vendor; fstab has OMR. Zip sha256 `7f582ea168c69f8c…`.
  Kept in `out/keep/` with its recovery. **Untested** (no LTE hardware).
- README: per-model status, `/metadata`-on-OMR install notes (the 23.2 recovery's *Format data* formats it, `wipe_data.cpp:151`),
  credits. `release/XDA-POST.txt`: XDA thread draft.

## 2026-10-08: SELinux + perf HAL fixes

- Wakeup source paths read as root in recovery (70 sources, 33 parents). Device `lineage-23.2` @ `e7652fc`: 32 `sysfs_wakeup`
  genfs labels; allow rules for hal_usb_qti (backlight), hal_audio_default (`/efs` search, `csc_prop`), hal_gnss_qti (`csc_prop`),
  wcnss_service (kmsg), hal_perf_default (cgroup write). Vendor fork `lineage-23.2` @ `51de1d4`: perf HAL opcodes 0x1C/0x18/0x37
  remapped from schedtune to `cpu.uclamp.min` / `latency_sensitive`, recorded as a blob fixup.
- Wi-Fi build9 (no `-k 0`, so neverallow checks passed): **success**, 2 h 24 m. Zip `…-20261008-…-gts4lvwifi.zip` sha256 `6494c150ddc516c3…`.
- ⚠️ Lesson: hard links in `out/keep/` don't protect build outputs, because the build rewrites zips in place. The kept
  `release-p8.zip` was silently replaced by build9. `out/keep/` now holds real copies (`cp`). The superseded build isn't needed.
- LTE build with the same fixes: `~/work/rom-build-lte2.log`.
- LTE build with the same fixes: **success**, 2 h 28 m, no `FAILED:`. Zip `…-20261008-…-gts4lv.zip` sha256 `3d3cfff0af48b236…`.
  `out/keep/` = the 20261008 Wi-Fi and LTE zips + their recoveries (real copies, verified with `cmp`).

## 2026-10-08: on-device check of build9 (Wi-Fi)

- SELinux denials 1,275 → **97**. Gone: hal_usb_qti, hal_audio efs, hal_gnss/hal_audio `csc_prop`, wcnss kmsg, and the
  `sysfs_battery_supply`/most `sysfs` wakeup reads.
- Still denied: system_suspend reading `wakeup53–58` (battery power_supply) and `wakeup99`/`wakeup102` (Android-only, not visible
  from recovery). Cause: ueventd restorecons sysfs paths recursively on every uevent (`system/core/init/devices.cpp:378`), and
  vendor `file_contexts:187` (`…/soc:battery/power_supply(/.*)? -- sysfs_batteryinfo`) relabels the files inside the wakeup
  folders on each battery change event. The genfs label only survives on the folder. Fix (device, not yet committed): a generic
  `/sys/devices/.*/wakeup[0-9]+(/.*)? sysfs_wakeup` at the end of vendor `file_contexts` (the last match wins). Wi-Fi build10 running.
- One crash: DeskClock widget NPE (`WidgetModel.mPrefs`), app-level, once. Not port-related.
- Launch boost: the power HAL gets LAUNCH (`setMode 5`) and the perf HAL applies the cpufreq part (min 1747/1516 MHz, matching config
  0x1081), but **top-app `cpu.uclamp.min` stays 0.00**. No denial. The perf lib has no schedtune-specific code, so the cause is
  unknown and needs perf HAL debug logs (root). Harmless; open item.
- build10 on device: runtime wakeup sources fixed; the 6 battery wakeup nodes were still denied, because `fc_sort` ranks by stem
  length and the battery `power_supply` rule beat the generic one. Device `lineage-23.2` @ efd222f + next commit: a battery-specific
  wakeup rule (sorted after the battery rule in the installed `vendor_file_contexts`, lines 1011/1012) and thermal HAL read rules.
  Approach matches Pixel redbull (genfs) and Linaro dragonboard (file_contexts). Wi-Fi build11 OK: `out/keep/lineage-23.2-20261008c-UNOFFICIAL-gts4lvwifi.zip`
  (sha256 `532399f1b16ec5ae…`). **Not yet flashed. LTE not rebuilt with build10/11 fixes.**

## 2026-10-08: build11 on-device check (1 h 49 m uptime)

- **system_suspend: 0 denials, 0 "Permission denied"** (the wakeup labelling is complete). The 40 suspend-service "No such device"
  errors are wakeup sources unregistered while being read, a harmless race.
- 271 denials, nearly all app domains (`untrusted_app*` probing `isolated_app`, `shell_test_data_file`, netlink, rootfs;
  `isolated_app` → content_capture; GMS → `adbd_prop`). Normal on any Android build; not device policy. Left alone.
- Crashes: Syncthing-Android `ForegroundServiceDidNotStartInTimeException` (app bug under Android 14+ FGS rules; the original
  app is discontinued, Syncthing-Fork fixes it). Not ROM-related. No lowmemorykiller kills; MemAvailable 3.2 GB.
- uclamp decision: governor is schedutil (WALT kernel). The platform `task_profiles.json` only *defines* `UClampMin`; no profile
  sets it. So the only writer would be the perf HAL's 2 s launch boost, whose cpufreq part already works (min 1747/1516 MHz).
  Extra benefit from the uclamp part: big-core placement during launch, marginal. **Not worth root/debug builds.** The vendor
  remap stays (harmless, documented).
- Still to do: rebuild LTE with the build10/11 sepolicy fixes (device `1188e2b`).

## 2026-10-08: LTE build3 + GitHub release (draft)

- LTE with all sepolicy fixes: **success**, 2 h 18 m, no `FAILED:`. Recovery kernel `-g500658be3c16`.
- Draft release `v23.2-20261008` on this repo (needs `gh`, now set up): per model the ROM zip, `recovery-20261008-<codename>.img`,
  `vbmeta-20261008-<codename>.img`, plus `SHA256SUMS` (wifi zip `532399f1…`, lte zip `1be0f6a7…`). Local copies:
  `out/keep/release-20261008/`. Notes: `release/NOTES-20261008.md`. **Unpublished**: the owner publishes after contacting krazey.
- `release/XDA-POST.txt` download section now points at the release tag.
- Official LineageOS: no GitHub PRs (Gerrit only). Path: krazey → devrel@lineageos.org / gts4lv maintainer → Gerrit if accepted.
  The vendor fork never goes upstream (blob changes are `extract-files.py` fixups, as the charter requires).

## 2026-10-09: LineageOS 24 feasibility study

- [FEASIBILITY-LINEAGE-24.md](FEASIBILITY-LINEAGE-24.md): feasible. The kernel is already ahead of what LineageOS 24.0 legacy devices
  needed (BPF 5.15 vs 5.10); the new work is FCM 5→7, legacy libion, and Android 17 boot surprises. Wi-Fi ≈4–12 days; LTE radio 1.4 is the open risk.
- [analysis/l24/TASKS-L24.md](analysis/l24/TASKS-L24.md): the 24 port split into tasks L0–L11 for helper agents, marked weak-OK / strong-review / strong-only / owner.
  New `scripts/fcm-check.py`: audits built HAL versions against an FCM level (23.2 builds vs level 7: gnss@1.1, soundtrigger@2.2, LTE radio@1.4).

## 2026-10-09: build tree moved to the external drive

- `~/android/lineage` is now a bind mount of `/mnt/build/lineage` (refreshed with `rsync -aH`, timestamps kept). `out/` moved inside it.
  Test build (gts4lv): success, 98 packaging steps, no ninja regeneration. Dry-run rsync: 0 differences before deleting the internal copy.
  Internal copy and the 44 GB `out.old` deleted: internal disk 96% → 42% used. Mount commands: HANDOVER "Build machine layout".

## 2026-10-09: paths after the move, clean-up, LineageOS 24 handover

- Docs updated for the external-drive layout (BUILD-HANDOFF, STATUS, HANDOVER, TASKS-L24). `scripts/check-pins.sh`: 10 rows (current fork pins,
  vendor fork, ExyHyperBrick `lineage-24.0` watch row), all OK.
- Clean-up (local `~/work`, 28 GB → 2.6 GB): standalone kernel build outputs, duplicate kernel clone `k670-p1`, research clones `clone-R*`, a superseded
  recovery image, 63 merged agent worktrees (their local branches are kept). ⚠️ `clone-R4` and `clone-R7` showed local changes but were deleted in the
  same command. Read-only research clones whose findings are in the merged R4/R7 reports. The repo itself had no unused files.
- Handover for the weak model: RUNBOOK §9 (worktrees, prompt template, order, review points), `analysis/l24/STATUS.md`, AGENTS/CLAUDE/HANDOVER/README point to the L tasks.

- 2026-10-11 L24 L7 review: round 12's kernel diagnosis ("23.2 had CROSS_COMPILE_ARM32 in the launching shell") was wrong. 23.2 got it from
  `vendor/lineage` `BoardConfigKernel.mk:207-208` + the `arm-linux-androideabi-4.9` prebuilt; 24.0 dropped both. Fixed with
  `local_manifests/24/gcc-arm32.xml` (synced) and device fork `port/l24-dt-4` `6c8ea99`. Build round 13 not run yet. SELinux fix (delete stale
  `net.te` rule) re-checked against `system/sepolicy/private/net.te:30`: sound.
- 2026-10-11: added TASKS-L24 §2b (lessons from the L7 loop) and an AGENTS.md pointer, so later agents don't repeat the round 11/12 mistakes.
- 2026-10-11 L7 round 13: kernel host tools failed on partial bundled openssl headers. Cause: 24.0 removed 23.2's GCC-era host-OpenSSL flags (`21fb2c0c`). Fixed in device fork `fe8e363` (no kernel patch); L7.md §7k. Round 14 pending.

- 2026-10-12 Branch clean-up. Rule: one branch per Android release in every fork, `lineage-23.2` and `lineage-24.0` (`lineage-22.2` stays as the base the 23.2 port was cut from).
  Fast-forwarded `lineage-24.0` to the built port tips: device `c2fe044` (was `port/l24-dt-4`), vendor `1e0cce7` (`port/l24-vendor-1`), sepolicy_vndr `d4fc898`
  (new branch, `port/l24-sepolicy-1`), compat `eaf8275` (= `port/l24-compat-1` `b3b52a8` merged with upstream `07768b889b53`: 2 additive commits, **not build-tested**).
  Kernel fork needed nothing: `lineage-24.0` already equals `lineage-23.2` (`500658be3c16`; 24 uses it unchanged). Then deleted the `port/l24-*` branches on the forks
  and `agent/L1,L2,L3,L7` + `lead/2026-10-09-l24-review` here (all merged into `main`; old tips: L1 `36ffe11`, L2 `4ff92c2`, L3 `4ed0735`, L7 `d10db7e`, lead `2fce93c`).
  `local_manifests/24/*` now point at `lineage-24.0`. Backup forks untouched. New `lineage-23.2` branch here = tag `v23.2-20261008`.

- 2026-10-13 L8/D: merged agent/L8, D1, D2 docs into main. Fixed boot-24-2 (init half of the old-kernel keyring revert): new fork `android_system_core` `lineage-24.0` `40a6fdb6d`, manifest `system-core-keyring.xml`, build 18 started
  (without WITH_ADB_INSECURE, refused by the classifier; owner to decide). D2 (thermal sepolicy) cherry-picked onto device fork `lineage-24.0` `a9d9a0c` and `lineage-23.2` `278c7f9`. D1 (health HAL) held, see
  analysis/l24/charging-notification-review.md.

## 2026-10-13: charging indicator root cause narrowed
- Owner clarified the symptom: on plug-in the status-bar battery icon, the charging sound and the
  lock-screen text do not change at all; USB to a PC is enough to show it.
- Live checks on 23.2 overturned D1: the Lineage health HAL provides only `IChargingControl` and
  `IFastCharge`, not `IHealth`, so D1 would leave no health HAL. D1 must not be applied.
  The "Samsung blob" is AOSP `libhealth_aidl_impl` built from `hardware/samsung/aidl/health`.
- Kernel emits `power_supply` uevents every ~10 s while charging, but the HAL ignores them and only
  updates on its fallback timer. Suspect: the Android 16 uevent BPF filter (built for ≥ 5.10),
  which loads because of `ro.bpf.kver_override=5.15.178`. Live test blocked: `adb root` refused
  (rooted debugging toggle off). Details and test steps in
  `analysis/l24/charging-notification-review.md`.
- Live test confirmed it: with the uevent BPF filter unpinned and the health HAL restarted, plug and
  unplug reach the HAL in 0.1–0.2 s (was 8.7–223 s). The filter drops `power_supply` uevents on the
  4.9 BPF backport. Decision: fix it in the kernel. Not yet root-caused inside the kernel.
- **Root cause found and fixed in the kernel.** `bpf_gen_ld_abs()` in the ld_abs/ld_ind backport
  (`4113f8c5e4ec`) set `R1 = ctx` before copying the `LD_IND` source register to `R2`, so loads indexed
  by R1 used the ctx pointer as offset and the program returned 0. Fix `8d39d4284f85` (upstream
  order), local branch `fix-ld-ind-r1`, not pushed yet. Verified on the tablet with a repacked boot
  image written by `dd` (originals in `~/work/boot-backup/`): filter keeps battery uevents, plug and
  unplug reach the HAL in 0.15-0.23 s, owner confirms the icon and sound are immediate.
- Built the kernel outside Soong because the 24 build was using all the RAM; a temporary
  `~/android/lineage` symlink made the logged kernel command's paths resolve (removed afterwards).
- Pushed `8d39d4284f85` to the kernel fork (`lineage-23.2` and `lineage-24.0`); bumped the pins in
  `check-pins.sh`, `portability-check.sh`, `boot-log.sh`, `REPO-SETUP.md`, `CLAUDE.md`, `HANDOVER.md`.
  It matches upstream `e6a18d36118b` (v5.9), which the ExyHyperBrick series lacks; their 23.2 and 24.0
  kernels have the same bug (to be reported to krazey).
- The 24 build running at the time was already compiling the old kernel and was left alone. A stray
  `m bootimage` on the 23.2 tree (from an incompletely stopped background build) was killed.
- 23.2 tree's device repo moved to the fork tip `278c7f9` (D2) for the next release. Build chain
  `~/work/chain-builds-20261013.sh` (log `~/work/chain-builds-20261013.log`): waits for the running 24
  build, moves the 24 tree's kernel to `8d39d4284f85`, waits for the `~/android/lineage` bind mount,
  builds 23.2 `gts4lvwifi` then `gts4lv`, then rebuilds 24 `gts4lvwifi`.

## 2026-10-13: build drive cleanup, build script
- The 23.2 release build was a full rebuild (5,718/86,713 steps when stopped): both `out/` dirs came from the
  previous machine. So both `out/` dirs were deleted (drive 180 GB → 475 GB free), plus the obsolete `k670`
  kernel clone (both branches already in the fork) and the Oct 4 `handoff` folder.
- Kept: the 20261008 release files, moved to `/mnt/build/releases/23.2-20261008/` (`SHA256SUMS` verified).
  Deleted: 20261007/09 and 20261008b/c dev zips, the 24.0-20261012 test zip.
- 23.2 tree renamed `/mnt/build/lineage` → `/mnt/build/lineage-23.2`; no bind mount or symlink any more (repo
  uses relative git links, checked). Docs updated: HANDOVER layout, MOVING-THE-DRIVE, CLAUDE.md, TASKS-L24,
  `portability-check.sh` default path.
- New `scripts/build-all.sh`: pre-build checks (no other build, no old bind mount, every `anton` fork project in
  the local manifests at its branch tip and clean, kernel contains `8d39d4284f85`, no debug/test options in the
  device tree, ≥ 250 GB free), then 23.2 Wi-Fi, 23.2 LTE, 24 Wi-Fi, 24 LTE in clean shells, copying zip,
  recovery and vbmeta to `/mnt/build/releases/<version>-<date>/`. Restartable. Owner starts it.
- 24 tree kernel moved to `8d39d4284f85`. All 10 fork checkouts verified at their tips.

## 2026-10-14/15: release builds with the charging fix
- `scripts/build-all.sh` ran from scratch on both trees, no `FAILED:`, all `ro.debuggable=0`:
  23.2 Wi-Fi 9 h 06 m, 23.2 LTE 2 h 01 m, 24 Wi-Fi 12 h 56 m, 24 LTE 3 h 23 m (started 2026-10-14 07:04, done 10-15 10:30).
- Results: `/mnt/build/releases/23.2-20261014/` and `/mnt/build/releases/24.0-20261015-bluetooth-test/`, `SHA256SUMS` verified.
  The 24 run crossed midnight, so its zips are `24.0-20261014` (Wi-Fi) and `24.0-20261015` (LTE): the zip name is
  the ROM's `ro.lineage.version` and is never renamed. The 24 folder was renamed to its finish date and the LTE
  recovery/vbmeta to `20261015` to match their zip.
- Script fixed for that: recovery/vbmeta take their zip's date; each version builds into
  `releases/<version>-<start>.partial/`, renamed to `<version>-<finish date>` once all its devices are in.
- Free on `/mnt/build`: 140 GB.
- Simplified on the owner's request: the release folder is `<version>-<date the script started>`, no
  `.partial` folder and no renaming, so a run's Wi-Fi and LTE builds always share one folder. The 24 folder is
  back to `/mnt/build/releases/24.0-20261014/` (Wi-Fi zip `20261014`, LTE zip/recovery/vbmeta `20261015`).

## 2026-10-15: 23.2-20261014 on the tablet, draft release
- Owner flashed recovery + zip of 23.2-20261014 Wi-Fi over 20261008 (Heimdall + sideload, no Format data).
  Checked: `23.2-20261014-UNOFFICIAL-gts4lvwifi`, kernel `-g8d39d4284f85`, `userdebug`, `ro.debuggable=0`,
  `ro.adb.secure=1`, Enforcing. Charging: 9 edges, 0.002-0.23 s from cable event to health HAL; owner confirms
  icon, sound, screen wake and the idle plug-in case.
- Draft GitHub release `v23.2-20261014` with the 7 files from `/mnt/build/releases/23.2-20261014/`; notes in
  `release/NOTES-20261014.md` (what's new: charging fix, thermistor sepolicy; updating from an earlier build of
  this unofficial release needs no data wipe, even with the new recovery). Not published.

## 2026-10-15: LineageOS 24 boots (boot-24-3)
- Owner installed `24.0-20261014` Wi-Fi (24 recovery via Heimdall, ⚠️ Format data, sideload). It boots to the home
  screen. Logs reviewed over adb (root via Rooted debugging): no tombstones, ANRs or crashes, no kernel warnings,
  `device-checks.sh` 5 PASS / 0 FAIL / 1 SKIP, Wi-Fi/BT/sensors/audio/camera/keymaster/BPF up, charging fix active.
  Watch list (non-blocking SELinux denials for `tee`→gatekeeper and `macloader`, PA thermistor -20 °C): `analysis/l24/boot-24-3.md`.
- The tablet was first invisible on USB: a bad cable, not a 24 issue.

## 2026-10-15: user-reported bugs — Bluetooth pairing, frozen AOD; tablet defaults
- **AOD** did not update (clock, charging, notifications). The overlay declared `doze_suspend_display_state_supported=true`,
  so SystemUI parks DOZE_AOD in DOZE_SUSPEND, where this panel takes no updates. A/B on SM-T720 (24) with a runtime
  fabricated overlay: DOZE_SUSPEND froze clock and charging line, DOZE updated both (owner-confirmed). Fix: `false`.
  Device `lineage-23.2` `a0a2df4`, `lineage-24.0` `488b4b0`. Runtime test overlay disabled afterwards.
- **Defaults** (owner-approved, matching gta4xl/gta4l/gts7lwifi/gts7xlwifi): auto-rotate, auto-brightness, device name
  "Galaxy Tab S5e" (new SettingsProvider overlay). Device `lineage-23.2` `62c3868` `82ca61a`, `lineage-24.0` `2aa2d28` `9ea5dd9`.
- **Bluetooth**: pairing with a phone failed ("pairing rejected"), user's iPhone/CarPlay saw Bluetooth restart. Tombstone:
  `hci_layer.cc:283 handle_command_response: LE_EXTENDED_CREATE_CONNECTION(0x2043) was not expecting complete event`.
  The device tree already sets `bluetooth.hci.disabled_commands=377` (= that command) for this WCN3990 quirk, but the 23.x
  Bluetooth stack (controller.cc → controller_impl.cc rewrite) no longer reads the property; 22.2 did. New fork
  `anton-scholten/android_packages_modules_Bluetooth` restores it (validated parsing, no new deps): `lineage-23.2`
  `8c6d706e11` (on the tree's `03cb8e33c1`, i.e. what 20261014 shipped), `lineage-24.0` `11434c8f8a`. Manifests
  `local_manifests/bluetooth-disabled-commands.xml` and `24/`; both trees force-synced to the fork.
- `build-all.sh`: free-space check wants 50 GB for incremental builds, 250 GB only when `out/` is missing.
- New `UPSTREAM.md`: every fix owed to LineageOS Gerrit or krazey, linked from the README.
- 24 Wi-Fi test build started 16:18 (`ONLY="24.0:gts4lvwifi"`, estimate 1.5-2.5 h).
- 24 Wi-Fi test build done 19:56 (3 h 18 m, 0 `FAILED:`), `LINEAGE_VERSION=24.0-20261015`. The script copied it under the
  stale name `…20261014…`: in `out/` the old zip name is a hard link to the same OTA file the build rewrites, and
  `ls -t` picked it. Renamed in `/mnt/build/releases/24.0-20261015-bluetooth-test/` (sums regenerated; content verified identical
  to the 20261015 zip). `build-all.sh` now removes stale zip names before building and takes the name from the
  build log's `LINEAGE_VERSION`.
- 24.0-20261015 installed over 24 (sideload, data kept); Bluetooth fix active at stack start-up
  (`Disabled HCI command index 377`). Pairing test pending.
- **PIN rejected after the reboot** (owner thought it had changed). Not changed (spblob from 2026-10-15 17:20): every
  verify hits `avc: denied { read search } qseecomd → gatekeeper_vendor_data_file` and
  `keymaster_tee: nwd_gatekeeper.cpp:175 nwd_KM_OUTDATA_unpack err -506`. Android 16 allowed it in
  `system/sepolicy/private/tee.te`; Android 17 moved the type to `system/sepolicy/vendor/` without the `tee` rule. 23.2 is
  not affected. Fix: device `lineage-24.0` `702e1fd` (two `allow tee gatekeeper_vendor_data_file` rules). Not built yet
  (owner: test the other fixes first). To unlock meanwhile the owner runs `setenforce 0` via root adb (reverts on
  reboot); the agent's attempt was blocked by the permission classifier.

## 2026-10-16: fixes verified on 24.0-20261015
- **Bluetooth**: no crash anymore. First attempts still failed with `HCI_ERR_PAIRING_NOT_ALLOWED`; the HCI snoop log
  (bug report) showed the *phone* (OnePlus 7 Pro, LineageOS 24) refusing: tablet-initiated pairing got LMP "pairing not
  allowed" right after our `IO_Capability_Request_Reply` (DisplayYesNo, MITM+dedicated bonding); phone-initiated pairing
  asked for a stored link key and dropped with 0x05. The phone still held a bond from before the tablet's Format data (the
  BD address survives reinstalls). After the owner cleared it on the phone: BR/EDR bond, then LE bond via CTKD 0.2 s later
  (the path that used to abort), OPP file (1.38 MB) received. 0 crashes in the capture.
  User note for README/FAQ: after reinstalling the tablet, "Forget" it on every phone before pairing again.
- **AOD**: clock and charging line update on the build itself (no test overlay).
- **Charging** with the screen on: immediate.
- Still open: gatekeeper fix (`702e1fd`) needs a build; iPhone/CarPlay test; 23.2 build with the Bluetooth/AOD/defaults fixes.
- `build-all.sh` reviewed before the release run. Order confirmed (23.2 Wi-Fi, 23.2 LTE, 24 Wi-Fi, 24 LTE). New
  `verify_release`: after each build, refuses to copy unless `ro.build.type=userdebug`, `ro.debuggable=0`,
  `ro.secure=1`, `ro.adb.secure=1` (found in `system/system_ext/etc/build.prop`), `ro.force.debuggable`≠1, no
  `selinux=permissive` in `boot.img`, no insecure/eng variant in the log. Passes on 23.2-20261014 (both) and
  24.0-20261015, fails on a doctored copy. The Bluetooth test build folder was renamed
  `/mnt/build/releases/24.0-20261015-bluetooth-test/` so a same-day run cannot mistake it for a finished build.

## 2026-10-16: release builds with all fixes (23.2-20261016, 24.0-20261016)
- `build-all.sh` 2026-10-15 22:57 → 10-16 07:05, all four `release props verified`, 0 `FAILED:`, `SHA256SUMS` OK:
  23.2 Wi-Fi 2 h 24 m, 23.2 LTE 1 h 33 m, 24 Wi-Fi 57 m, 24 LTE 2 h 21 m. Files in
  `/mnt/build/releases/23.2-20261015/` and `/mnt/build/releases/24.0-20261015/` (folder = run start date; zips are
  `…-20261016-…` because each build started after midnight).
- Verified in the outputs, not just the source: kernel `4.9.337-g8d39d4284f85` in all four; Bluetooth fix in the linked
  `libbluetooth_jni.so` of both versions (the `.o` files are ThinLTO bitcode, so plain string search there finds
  nothing); SystemUI `doze_suspend_display_state_supported=false` in both; SettingsProvider defaults (auto-rotate,
  auto-brightness, "Galaxy Tab S5e") in the auto-generated vendor RRO `SettingsProvider__lineage_gts4lvwifi__auto_generated_rro_vendor.apk`;
  24 vendor CIL has `allow tee_202604 gatekeeper_vendor_data_file` (dir + file).
- Draft GitHub release `v20261016` ("2026-10-16 - LineageOS 23.2 and 24 (unofficial)", the owner's new title style):
  both versions, 4 zips + recovery/vbmeta per version and model (renamed `…-<codename>-<version>.img`, the plain names
  collide), one combined `SHA256SUMS`; staged as hard links in `/mnt/build/releases/20261016-github/`. All 13 asset
  sizes match. Notes: `release/NOTES-20261016.md`. Not published; the 24 PIN fix is still untested on the device.

## 2026-10-16: 24.0-20261016 tested; draft release changed to 23.2 only
- Owner on 24.0-20261016: **PIN fix works** (PIN accepted after reboot), Bluetooth and AOD work, defaults applied on the
  fresh install (auto-brightness, auto-rotate).
- **New 24 bug:** with MindTheGapps installed, Google setup after Wi-Fi shows "Getting your tablet ready…" (data sent to
  Google), then "Slow connection — try another network", and after *Skip* a blank screen (back button + battery icon only).
  Without GApps the LineageOS setup completes. Not yet diagnosed.
- Owner asked for a 23.2-only release: draft retitled "2026-10-16 - LineageOS 23.2 (unofficial)", tag `v23.2-20261016`,
  24 assets and the combined `SHA256SUMS` removed, 23.2 recovery/vbmeta renamed back to `…-<codename>.img`, 23.2
  `SHA256SUMS` uploaded, notes rewritten 23.2-only (`release/NOTES-20261016.md`). Staging folder removed.

## 2026-10-16: 24 GApps setup hang → missing EROFS
- With GApps added on top of a set-up 24 (adb still authorized): `com.google.android.gms` was not installed. MindTheGapps
  17.0.0 (20261006) ships Play services as an APEX, `com.google.android.gmssystem.prodvic.apex`, with an **EROFS** payload
  (MindTheGapps 16 shipped `GmsCore.apk`). apexd: `Mounting failed for package … gmssystem.prodvic.apex: No such device`;
  our kernel had no EROFS at all. Google setup waits for Play services → "Getting your tablet ready" → "Slow connection".
- Kernel test branch in worktree `/mnt/build/ewt` (not pushed), on `8d39d4284f85`: ExyHyperBrick `9266d5193fbc`
  (smp_cond_load_relaxed/atomic_cond_read_relaxed backport), their 6 `fs/erofs` import commits, `CONFIG_EROFS_FS=y` in
  `gts4lvwifi_defconfig`/`gts4lv_defconfig`, and a 22-line 4.9 compat patch inside `fs/erofs` (bi_error, bi_bdev, old
  getattr, local clear_and_wake_up_bit). Head `230ccf8e8e63`. Builds clean with both 24 (clang r596125) and 23.2
  (clang r563880c) toolchains.
- Repacked the installed 24.0-20261016 boot image with it (`~/work/boot-backup/boot-24.0-20261016-erofs-test.img`,
  original alongside); owner flashed it with Heimdall. Result: `erofs` in `/proc/filesystems`, the gmssystem APEX mounts,
  `com.google.android.gms` 26.11.36 installed, 3 GMS processes, 0 crashes. Pending: owner's sign-in/Play Store and
  fresh-install setup tests, then push to both kernel branches.
- Owner: with the test kernel, a fresh install (Format data, 24.0-20261016 + MindTheGapps 17, test boot via Heimdall)
  completes Google setup. (Download mode was not detected on one USB port; another port worked.)
- Pushed kernel `230ccf8e8e63` (8d39d4284f85 + 9 commits: 9266d5193fbc backport, 6 EROFS import commits, defconfig, 4.9
  compat) to fork `lineage-23.2` and `lineage-24.0` (fast-forward). Both build trees moved to it; test worktree and
  outputs removed. `build-all.sh` KERNEL_FIX → `230ccf8e8e63`; pins bumped (check-pins, portability-check, boot-log,
  CLAUDE.md, REPO-SETUP); UPSTREAM.md #4b.
- 24 Wi-Fi release build (recovery + ROM) started 10:27 (`ONLY="24.0:gts4lvwifi"`), for an end-to-end check.
- 24 Wi-Fi release build done 13:01 (2 h 23 m, 0 `FAILED:`, release props verified): `/mnt/build/releases/24.0-20261016/`.
  Verified in the images: boot and recovery kernels `4.9.337-g230ccf8e8e63` with EROFS; Bluetooth fix in
  `libbluetooth_jni.so`; SystemUI `doze_suspend…=false`; SettingsProvider RRO defaults; gatekeeper `tee` rules.
  Note: same version string `24.0-20261016` as the earlier (pre-EROFS) build in `releases/24.0-20261015/`; only the
  new folder is current. Owner to do the end-to-end fresh install with MindTheGapps 17.
- 24 LTE release build done 16:40 (2 h 35 m, 0 `FAILED:`, release props verified); Wi-Fi was skipped (today's verified
  build reused). LTE images checked like Wi-Fi (kernel `-g230ccf8e8e63` + EROFS in boot and recovery, AOD, defaults,
  gatekeeper; fingerprint = stock SM-T725 `T725XXS3DWA1`).
- Draft GitHub release `v24.0-20261016` ("2026-10-16 - LineageOS 24 (unofficial)"), 7 files from
  `/mnt/build/releases/24.0-20261016/`, all sizes match; notes `release/NOTES-24.0-20261016.md`. Not published.
- Open: Smart Switch appears after Google setup. Likely Google's Play Auto Install for the stock Samsung fingerprint
  (`ro.build.fingerprint` = stock SM-T720/T725, as in LineageOS trees); to be confirmed on the tablet (installer of the
  package). Changing the fingerprint is not recommended (certification). Plan: document "untick/uninstall".

## 2026-10-16: README rewritten
- Owner published v23.2-20261016 and v24.0-20261016 (24 is "Latest"). README rewritten 232 → 148 lines: 24 recommended,
  23.2 via its branch and releases (no version table); one status table; install changes as one table (fixed: the
  recovery-row contradiction, `.sha256sum` → `SHA256SUMS`, MindTheGapps 17 now tested, same-version updates need no
  wipe); troubleshooting incl. Bluetooth re-pairing; one sources table with all forks (kernel incl. BPF fix + EROFS,
  Bluetooth, the four 24-only forks); build steps for both versions (copy all manifests of the version; 23.2 now also
  needs `bluetooth-disabled-commands.xml`), `build-all.sh`, RAM/disk; the long compat-fork explanation dropped (in its
  manifest and UPSTREAM.md). All links checked.

## 2026-10-17: LineageOS Changelog 32 vs this port
- Changelog 32 (2026-10-11): LineageOS accepts only 22.2 submissions for 4.4/4.9 devices, even where 23.2/24 ports exist
  ("rather hacky" platform commits); 23.2/24 kernels need "1:1 eBPF backports, build fully without GCC"; shims are now
  commonized in `android_hardware_lineage_compat`. Charter exceptions need 3 Project Directors.
- Measured: kernel = 2,469 commits on LineageOS 22.2, ~2,445 upstream cherry-picks with `-x`, ~23 own glue commits;
  compiled entirely by clang/LLD (no GCC in `.comment`, no GCC tool in any `.cmd`); GCC arm32 prebuilt only satisfies the
  arm64 Makefile's `CROSS_COMPILE_ARM32` check for the compat vDSO.
- Upstream `libwfdservice_shim` (compat `lineage-24.0`) still lacks `libaudiobase`. UPSTREAM.md: policy section added;
  targets revised (device fixes → official `lineage-22.2`; keyring reverts not submittable; WFD bridge → common compat
  shim; new #10 GCC-free vDSO build; ld_abs fix to redo as `UPSTREAM:` cherry-pick).

## 2026-10-18: OTA, security updates, Dolby and storage reports (analysis only)
- **OTA**: LineageOS Updater reads `lineage.updater.uri` (placeholders `{device}`, `{type}`, `{incr}`), expects a JSON
  array of `{datetime, type, version, files:[{filename, sha256, size, url, os_patch_level?, os_sdk_level?}]}`, keeps
  builds newer than `ro.build.date.utc` with `type` = `ro.lineage.releasetype` (UNOFFICIAL) and an SDK not below the
  current one, then `RecoverySystem.verifyPackage`. Non-A/B: installs via recovery, and 24's Updater updates the recovery
  partition on the next boot. Our zips are signed with the AOSP **testkey**, trusted by both `system/etc/security/otacerts.zip`
  and the recovery (which also trusts `lineage.x509.pem`): OTA would verify, but testkey is public.
- **Dolby (LTE report)**: the tree ships only Samsung's `libswdap.so` effect ("dap", UUID 6ab06da4-…) and
  `vendor/etc/dolby/dax-default.xml`, `vendor.audio.dolby.ds2.enabled=false`; no Dolby app or service in the build.
  Same in many LineageOS Samsung trees. The user's Dolby UI must be a third-party app.
- **Storage (Wi-Fi report)**: our kernel has `CONFIG_SDCARD_FS=y`, no `emulated_storage.mk`, so vold uses sdcardfs
  (`IsSdcardfsUsed()`: kernel support && `external_storage.sdcardfs.enabled` default true). Seen on 24:
  `PackageSettings: Couldn't write -1 to /config/sdcardfs/<pkg>/appid`. ExyHyperBrick 23.2/24 instead: no sdcardfs,
  `CONFIG_UNICODE=y`, ext4/f2fs casefold backports, `emulated_storage.mk` (projid + casefold, sdcardfs off). Our ext4/f2fs
  have no casefold. Hypothesis, unconfirmed: per-app `Android/data` permissions under sdcardfs on Android 16/17.

## 2026-10-18: OTA and private keys set up (keys pending)
- Device `lineage-23.2` `c965a27`, `lineage-24.0` `cb3062c`: `lineage.updater.uri` → `ota/<version>/{device}.json` in this repo.
- `scripts/ota-json.sh <folder> <tag>`: writes the Updater feed from each zip's OTA metadata (tested on 24.0-20261016,
  URL resolves). New `RELEASING.md` (keys, release steps, OTA feed after publishing). `.gitignore` blocks key files.
- `build-all.sh`: requires our keys in `vendor/lineage-priv/keys` (existence only) and `ro.build.tags=release-keys`;
  currently fails by design until the owner generates the keys (RELEASING.md "Private keys").
- First release-keys build means one more clean install for current users; OTA works from then on.

## 2026-10-18: keys verified; storage bug traced to fuse-bpf umask; Dolby
- Owner generated the 12 keys (`~/.android-certs`): checked without printing any private data: all present, 2048-bit,
  unencrypted, each key matches its cert, 12 distinct, none equal to AOSP's public keys, valid to 2054; installed
  identically in both trees with `keys.mk` → releasekey. `build-all.sh --check` passes. **No encrypted backup yet.**
- Dolby: the Dolby UI is LineageOS **AudioFX** (`org.lineageos.audiofx`) driving Samsung's `libswdap.so` (DAP, "Dolby
  Laboratories"); works on the owner's SM-T720. LTE vs Wi-Fi builds: audio_effects, policy, platform info, mixer paths,
  dax-default.xml and libswdap.so are byte-identical, so the LTE report is runtime (effect not attached, e.g. offload
  path) and needs a log from that user.
- **Storage (Wallcraft, Telegram):** DownloadManager `FILE_ERROR: Failed to create parent for …/Android/data/<pkg>/files/…`
  (with sdcardfs). Runtime test without sdcardfs (`setprop external_storage.sdcardfs.enabled false`, `vdc volume reset`,
  framework restart): folders get created but writes fail with `Permission denied`. After deleting Wallcraft's
  `Android/data` (and a reinstall) vold creates the app dirs with default ACLs (vold `SetDefaultAcl` skips ACLs when
  sdcardfs is used), yet app-created subdirs are `2700` with an **empty ACL mask**. Cause: the 4.9 fuse-bpf backport
  (`fs/fuse/dir.c`, "Route node creation") strips the umask before the backing `vfs_mkdir/create/mknod`; upstream
  fuse-bpf applies it only `if (!IS_POSIXACL(backing_inode))`. FUSE-BPF is active here (`ro.fuse.bpf.is_running=true`).
  Fix in kernel test worktree `/mnt/build/ewt` `7bf5ff571b75` (not pushed), being built for an on-device test.
- Full fix needs both: the kernel fix and running without sdcardfs (vendor prop + project ids), i.e. one Format data.
- **Storage fix confirmed** on SM-T720 with the test kernel (`7bf5ff571b75`, flashed as a repacked boot image) and sdcardfs
  off at runtime: Wallcraft download `SUCCESS`, app folders now `drwxrws---` (ACL mask open), Termux sees shared storage.
- Pushed kernel `7bf5ff571b75` to fork `lineage-23.2` and `lineage-24.0` (fast-forward); device `external_storage.sdcardfs.enabled=0`
  in `vendor.prop`: `lineage-23.2` `e6329e0`, `lineage-24.0` `24c265b` (project ids / casefold stay off: no ext4 casefold
  in this kernel, projid only affects storage statistics). Both trees on the new kernel; pins and `KERNEL_FIX` bumped.
- Next release (both versions) = release-keys + storage fix + OTA feed property: **one clean install** for everyone.
  Existing installs would keep their sdcardfs-era app folders (no ACLs), so a dirty update would not fix them anyway.
- Dolby: the "Dolby Atmos" settings are LineageOS **SamsungDAP** (`hardware/samsung/packages/Dap`, `org.lineageos.dap`),
  not AudioFX (24's AudioFX only uses Equalizer/BassBoost/Virtualizer/PresetReverb). It creates the DAP effect (type
  `46d279d9…`, impl `6ab06da4…`) globally on session 0. On SM-T720 with music playing: track on mixer `AudioOut_15`
  (speaker, flags 0x000) and the Dolby effect in that thread's chain; toggling/profiles show no effect or HAL errors. No
  telephony dependency in the app or the (identical) LTE audio configs; the LTE report likely means music on another
  output (offload/direct, or call/VoIP mode) where a session-0 effect does not apply. Asked for `dumpsys
  media.audio_flinger` + logcat from that user. Key backup: owner reports done (not in `~`, not checked).

## 2026-10-19: OTA test build failed on the feed URL length; switched to GitHub Pages
- The 24 Wi-Fi OTA test build failed after 1 h 35 m: `gen_build_prop: lineage.updater.uri cannot exceed 91 bytes` (the
  raw.githubusercontent.com URL was 101). The chain correctly did not start the release builds.
- Enabled GitHub Pages for this repo (`main` /, `.nojekyll`; verified it serves files as-is). Device `lineage-23.2`
  `3640419`, `lineage-24.0` `be25398`: `lineage.updater.uri=https://anton-scholten.github.io/lineageos-galaxy-tab-s5e/ota/<version>/{device}.json` (80 bytes).
- `ota-json.sh` now merges: dedupe by sha256, newest first, keep 3 (`OTA_KEEP`); the Updater (v2 parser, keyed by sha256)
  lists all entries newer than the installed build. Other unofficial ROMs do the same with GitHub-hosted JSON (e.g.
  klabit87/OTA, R0rt1z2/OTA, ADeadTrousers/LineageOTAstatic on Pages).
- `build-all.sh`: fails early on non-ro property values over 91 bytes; the "another build is running" check now matches
  only real `soong_ui`/`siso` processes (it had matched a watcher's command line).

## 2026-10-19: release builds 20261019; Updater links
- All four release builds done (`/mnt/build/releases/23.2-20261019/`, `24.0-20261019/`): `release-keys`, kernel
  `4.9.337-g7bf5ff571b75`, SHA256SUMS ok. OTA test build (24 Wi-Fi, same date, older timestamp) kept in
  `24.0-20261019-ota-test/`; owner clean-installed it on SM-T720.
- Notes `release/NOTES-23.2-20261019.md`, `NOTES-24.0-20261019.md` (⚠️ one clean install: new keys + storage). Drafted
  GitHub releases `v23.2-20261019` and `v24.0-20261019`; after publishing: `scripts/ota-json.sh` for both, push `ota/`.
- adb in recovery: a stale second USB entry with the same serial (`usb:3-2`) blocks `adb sideload` ("more than one
  device"); `adb kill-server` clears it. Plain recovery adb is `unauthorized` on release-key builds after Format data
  (no stored keys, no prompt); sideload mode needs no authorization.
- Recovery keeps `lineage.x509.pem` (LineageOS default `PRODUCT_EXTRA_RECOVERY_KEYS`): OTAs are verified by the system
  against our key only; the extra recovery key only skips the sideload warning for official zips. Kept.
- Updater links (next build): device overlay `overlay/packages/apps/Updater/app/src/main/res/values/strings.xml`
  (auto-RRO) sets `menu_changelog_url` → releases, `report_issue_url` → issues, `header_download_url`,
  `blocked_update_info_url` → README install section. `lineage-23.2` `ff76d0d`, `lineage-24.0` `6c9f41b`.
- Owner published both releases; `ota/23.2` and `ota/24.0` feeds pushed (`5bccbf8`), live on Pages, download URLs return 200.

## 2026-10-19: double tap to wake (23.2 and 24)
- Report on 24: double tap to wake does nothing (double tap on the status bar to sleep works). Settings and
  `dumpsys power` show `mDoubleTapWakeEnabled=true`, but the QTI power HAL never logs `setMode: 0`, and the release
  power HAL binaries of **both** 23.2 and 24 contain no `aot_enable`.
- Cause: `vendor/qcom/opensource/power` was converted to Android.bp (`756cda2`, 2025-07-12, after 22.2) and dropped
  `TARGET_POWERHAL_MODE_EXT`; our `BoardConfigCommon.mk` still set it, so `power/power-mode.cpp` was not built and
  `MODE_EXT` was off.
- Fix: `cc_library_static libpowermodeext_gts4lv` (device `Android.bp`, namespace-qualified) +
  `soong_config_set,qtipower,mode_ext_lib`. Power HAL test build on 24 now contains `aot_enable,0/1` and
  `/sys/class/sec/tsp/cmd`; SELinux already allows `hal_power_default` on `sysfs_tsp`. Device `lineage-23.2`
  `99c0506`, `lineage-24.0` `40e38d8`. To verify on the tablet with the next (OTA) build.

## 2026-10-22: Firefox / Bromite on the SM-T720 (24.0-20261019, 6 GB)
- Firefox 158: no crashes and no LOW_MEMORY kills. Its background main process was SIGKILLed once (2026-10-21
  22:18:04, adj 905) by the **Seedvault** full backup (`full_backup_package: org.mozilla.firefox` →
  `full_backup_agent_failure: transport rejected` → `am_proc_died`); the same backup run killed ~140 other app
  processes (normal BackupManager tear-down). Candidate for the LTE user's "Firefox dies in the background" if they
  use Seedvault; ask in the log request.
- Bromite 108.0.5359.156 (Dec 2022, unmaintained): renderer ("Aw, Snap!") on every page, reproduced with
  en.wikipedia.org. Exit status 31 = SIGSYS (seccomp), only in Bromite renderers; the system WebView and Firefox
  sandboxes are fine, so an old Chromium seccomp policy vs Android 17 libc rather than the kernel. Not pursued;
  users should move to Cromite.

## 2026-10-22: Firefox crashes on resume = app compaction (process_madvise MADV_PAGEOUT) on our kernel
- Owner's SM-T720 (24.0-20261019): Firefox crashed twice (10:08:53, 10:11:27) the moment it was brought back from the
  background: tab process SIGSEGV (exit status 11) ~250 ms after `am_unfreeze`, then GPU and main process. Every
  crashed process had been frozen **and compacted** (`am_compact ... ANON`, 120-200 MB paged out) while in the background.
  No tombstones (Firefox's own crash handler catches the signal).
- Reproduced on demand, twice: fresh Firefox → HOME → `am freeze --sticky` + `am compact full` on main/tab/gpu pids →
  wait 30 s → `am unfreeze` + relaunch → tab SIGSEGV, then main and GPU. Control with `use_compaction=false` and freeze
  only: no crash. Setting restored afterwards (`device_config delete activity_manager use_compaction`).
- Only Firefox crashed; 33 other processes were compacted without problems. `process_madvise`/`MADV_PAGEOUT`/`MADV_COLD`
  come from our ExyHyperBrick port (`8a6d9a3d7644` ff.), not in the 22.2 kernel, where compaction silently did nothing.
  Matches the LTE user's "Firefox crashes when in the background" (same kernel on 23.2).
- Suspect: `reclaim_pages()` → 4.9 `shrink_page_list()`, which treats every anon page newly added to swap as a
  possible MADV_FREE page (`TTU_LZFREE`, discarded when the pte is clean and !PageDirty); upstream 5.x only discards
  `!PageSwapBacked` pages. Not proven yet. Firefox's allocator uses lazy freeing heavily, which would explain why only
  Firefox is hit.
- Bromite's "Aw, Snap!" (SIGSYS) is a separate, app-side problem (see above).
- **Root cause and fix (2026-10-22).** The backported `madvise_cold_or_pageout_pte_range()` clears the access flag via
  `ptep_get_and_clear_full()` + `pte_mkold()` + `set_pte_at()` (pmd: `pmdp_invalidate` + `set_pmd_at`). On 4.9 arm64,
  `set_pte_at()` sets `PTE_RDONLY` unless the *software* dirty bit is set (`CONFIG_ARM64_HW_AFDBM=y`), so pages dirtied
  only by the hardware come back clean; 4.9 `shrink_page_list()` then treats a clean anon page newly added to swap as
  MADV_FREE (`TTU_LZFREE`) and **discards** it. Firefox (mozjemalloc reuses MADV_FREE'd pages → writable-clean ptes →
  hardware-dirtied) lost memory and crashed on resume. Upstream arm64 stopped touching `PTE_RDONLY` in `set_pte_at()` in v4.14.
- Fix: `ptep_test_and_clear_young()` / `pmdp_test_and_clear_young()` instead, kernel `72f6ca56842c` on local branch
  `test-madv-dirty` (24 tree, not pushed). Test boot image `~/work/boot-backup/madv/boot-24.0-20261019-madv-test.img`
  (release boot with only the kernel swapped; original alongside), flashed with Heimdall.
- Verified on SM-T720: the freeze + `am compact full` + resume repro, which crashed 2/2 before, passed 2/2 from a fresh
  start plus 3 consecutive cycles: 0 SIGSEGV, all Firefox processes alive, page draws and scrolls.
- Same pattern in stock 4.9 `move_ptes()` (`mm/mremap.c`, ART's CMC GC uses MREMAP_DONTUNMAP); not changed, lower risk
  (pages there are normally software-dirty). Pending: owner soak, then push to both kernel branches and rebuild.

## 2026-10-22: release builds 20261022 (Firefox fix, double tap to wake, Updater links)
- Soak on the test kernel: no new crashes (only Syncthing's FGS start timeout at boot, also seen on 10-19 with the
  old kernel). Pushed kernel `72f6ca56842c` to fork `lineage-23.2` and `lineage-24.0` (fast-forward), trees moved,
  `KERNEL_FIX` and pins bumped, UPSTREAM 4d.
- `build-all.sh` 11:36-19:57, all four done, release props verified, SHA256SUMS ok. Checked: kernel
  `4.9.337-g72f6ca56842c` in all boot images, `release-keys`, power HAL with `aot_enable` (23.2 and 24), Updater RRO with
  our releases/issues URLs. `/mnt/build/releases/23.2-20261022/`, `24.0-20261022/`.
- Notes `release/NOTES-23.2-20261022.md`, `NOTES-24.0-20261022.md` (owner's style; OTA from 20261019, no wipe); GitHub
  releases `v23.2-20261022`, `v24.0-20261022` drafted. After publishing: `scripts/ota-json.sh` for both, push `ota/`.
- Owner published both; `ota/` feeds updated (2 builds each), live on Pages.

## 2026-10-23: LTE data on 24 works (user report); APN protocol left blank
- First LTE report on 24: mobile data works after adding an APN by hand and choosing **IPv4** for APN protocol and
  roaming protocol (then airplane mode off/on). Answers the open question: the 1.4 radio HAL carries data on 24.
- The APN database is in the build (`system/product/etc/apns-conf.xml`, ~3,900 entries, ~80% without `protocol=`;
  TelephonyProvider defaults those to `IP`), so auto APNs work for listed carriers; the user's carrier was likely
  missing or an MVNO.
- Settings' Compose APN editor (`network/apn/ApnStatus.kt`, AOSP, same in 23.2) starts a new APN with protocol index
  -1 and saves `""` if the user doesn't pick one; it reads `KEY_SETTINGS_DEFAULT_PROTOCOL_STRING` but only logs it.
  An empty protocol reaches the old 1.4 HAL as an unknown PDP type, so data fails until IPv4 (or IPv4/IPv6) is chosen.
  Upstream behaviour, not ours; possible small Settings fix (default to `IP` when unset).
- README: LTE status ✅ on 23.2 and 24 (mobile data reported working; known issue Dolby Atmos), OTA "Updates" section, wipe also needed from our pre-20261019 builds, troubleshooting (APN protocol, greyed SIM switch = radio HAL 1.4, Bromite → Cromite), kernel/device rows (memory fix, double tap to wake, Updater links). RELEASING step 3: release notes list only changes since the previous build, with a template; the README holds everything else.
- Deleted the four pre-OTA GitHub releases (v23.2-20261008, -20261014, -20261016, v24.0-20261016; test keys, no OTA) at the owner's request; git tags kept (`lineage-23.2` here = tag v23.2-20261008). README (wipe line, Updates), CLAUDE.md and AGENTS.md headers, HANDOVER history note; `release/XDA-POST.txt` rewritten for 24 + 23.2, LTE working, OTA, links to the releases page.
- Removed `release/XDA-POST.txt`, the stray kernel compile-command dumps `c232.sh`/`c240.sh` and the notes of the deleted releases; redacted the tablet serial in `analysis/l24/charging-notification.md` (still in history, commit d36f47a); `flash-logs/` (local, untracked, contains the serial) added to .gitignore.

## 2026-10-23: repo cleanup (history docs removed)
- Owner removed (on request) the port-era working docs: AGENT-TASKS, AGENTS, RUNBOOK, ESTIMATE, KERNEL-BACKPORT-PLAN,
  PORTING-LINEAGE-23.2, PRIOR-WORK, LEAD-SYNTHESIS, FEASIBILITY-LINEAGE-24, MOVING-THE-DRIVE, `analysis/`, `patches/`
  and the agent-only scripts `check-agent-output.sh`, `pick-series.sh`, `check-pick.py`. All remain in git history.
- README build section gained the useful parts of the deleted build handoff (packages, the 24 memory wall, pitfalls).
- HANDOVER.md and CLAUDE.md rewritten for the current state (released, OTA, current pins, next steps); references in
  TESTING, UPSTREAM, REPO-SETUP, script comments and manifest comments reworded. Older WORKLOG entries still link to
  the deleted files; use git history (`git show <commit>:<path>`) for them.
- Owner confirmed double tap to wake works on 24.0-20261022 (SM-T720).
- Owner confirmed the Updater links (Recent changes → releases, Report issues → issues) and Firefox (no crashes after a day) on 24.0-20261022. All 20261022 changes verified on the SM-T720.

## 2026-10-24: GitHub issue #4 (keyboard cover / USB input stops working after some uptime)
- Reporter's logs: the stm32 pogo keyboard driver detaches/attaches and registers the input device the same way in the
  good and the bad case; only the Android side differs (EventHub handles the hang-up 1.9 s after the kernel instead of
  4 ms; EventHub device id 91, fd 530). The attach part of the bad case is not in the logs yet.
- Suspect checked: `71943bdbbe91` (wakeup sources in sysfs). EventHub adds every device with `EPOLLWAKEUP`, so each
  input device creates a wakeup source + `/sys/class/wakeup/wakeupN`; a failure there would make `epoll_ctl` fail and
  EventHub drop the device (`Could not add fd to epoll instance`). Backported code matches upstream.
- Owner's SM-T720 (24.0-20261022, up 1 d 23 h), over wireless adb: wakeup sources normal (4 eventpoll, 9 timerfd, one
  per input device; from the bugreport's incident section). USB mouse ×3 and USB keyboard ×2 plugged/unplugged: all
  added by EventHub ~0.6 s after the kernel, no epoll errors. Not reproduced. Removal lag ~0.59 s after
  `USB disconnect` each time (likely the kernel's own HID teardown).
- Next: reporter's logs at attach time in the bad state (EventHub/epoll lines, `dumpsys input`, `/dev/input`, uptime).
- Stress test (owner, 2026-10-24 20:12-20:17, wireless adb): ~23 USB mouse plug-ins. Every one added by EventHub
  ~0.7 s after the kernel (constant, no growth), no `Could not add fd to epoll`, no failed add. Issue #4 not reproduced
  via USB; still needs the reporter's attach-time logs.
- Side findings:
  - **Soft reboot at 20:13:13** (kernel kept running): `android.hardware.graphics.composer@2.3-service` SIGSEGV, null
    deref in `hidl_handle::operator=` ← `BpHwAllocator::allocate` ← `HWCBufferAllocator::AllocateBuffer` ←
    `SessionManager::GetNextBuffer` ← `sdm::Rotator::Stop` (`libsdmextension.so`). The allocator returned no buffer and
    the Qualcomm blob used it unchecked. Happened during a 0.2 s screen off→on (`power_screen_state` reason 3 = lid
    switch / hall sensor) with the mouse attached. Thermal HAL abort right after is collateral (listener died).
    Not yet reproduced on purpose.
  - `android.display` Looper (system_server, input pointer code) logs `Error adding epoll events for fd N while
    rebuilding epoll set: Bad file descriptor` on mouse attach; the stale set grows slowly (256 → 256, 296 → 622).
    Framework-side (a pointer/vsync fd closed without removeFd); separate from EventHub, not the cause of #4.
- **Issue #4 reproduced (2026-10-24 20:33), mechanism found.** After 15 min of screen-off (suspend/resume about every
  16 s; 602 "Booted secondary processor" lines in 23 min), a second USB mouse (`1bcf:0005`) did nothing: the kernel
  registered `input62` and sysfs had `event8`/`mouse1` at 20:33:21.8, but `/dev/input/event8` and `mouse1` were only
  created at **20:35:01.7 (100 s later)**; EventHub added the mouse 20 ms after the node appeared. So the delay is
  **ueventd**, not the kernel input layer or InputReader.
- ueventd CPU from `am_cpu`: 0-4 % with the screen on; **26 % → 39 % → 68 %** of a core during the screen-off period
  (79 s user CPU in a 115 s window), back to 0 % after wake. Load scales with suspend/resume cycles.
- Each resume re-creates `/sys/devices/system/cpu/cpu{1..7}/cache/index{0..3}` (cpu3 index0 ctime = last resume,
  cpu0 = boot) → ~28 `add` + 7 `online` uevents, each `FixupSysPermissions` + recursive restorecon in ueventd. A
  recursive restorecon of `cpu3` takes 0.03-0.07 s from the shell, so these alone don't explain several seconds of
  ueventd CPU per resume: more uevents per resume than counted. Candidates: wakeup-source sysfs devices
  (`71943bdbbe91`; add/remove uevent per source), power_supply `change`, USB/wlan resume events. Seeing the uevent
  stream needs root (shell can't read `/sys/kernel/uevent_seqnum` or listen on netlink).
- Interim user advice: after attaching, wait ~2 min; a reboot clears the backlog.
- Composer crash: owner did ~40 screen off/on cycles (≈15 full panel power-offs, lid switch and power button, with and
  without the mouse): no crash. Rare race; the rotator is in use because the panel is mounted rotated
  (`ro.surface_flinger.primary_display_orientation=ORIENTATION_270`). Mitigation candidate
  `vendor.display.disable_rotator_ui=1` (shell can't set it; needs root or a build). Parked in HANDOVER.
- Debuggable test build for the ueventd investigation: `vendor/lineage/config/common.mk` line
  `PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG := true` commented out **locally, uncommitted** (adb stays secure, our keys),
  24 Wi-Fi `mka bacon`, zip in `/mnt/build/releases/24.0-debug-test/`. Not for release; revert the line before the
  next `build-all.sh`.

## 2026-10-25: issue #4 root cause — resume-time CPU "online" uevents swamp ueventd
- Debuggable test build (`24.0-debug-test`, adb root via Developer options → Rooted debugging) with a small netlink
  uevent logger (`uevlog`, built against `out/soong/ndk/sysroot`) and a 30 s sampler (seqnum, ueventd CPU, /dev vs
  sysfs input nodes) in `/data/local/tmp`. Note: restarting adbd (tcpip/root) kills processes started from adb shell.
- Overnight (mouse attached, no wireless adb): the tablet never suspended (30 s samples without gaps); 1,447 uevents in
  9.5 h, mostly battery `change`; ueventd 14 s CPU; mouse node created within 0.3 s. The remaining slowness was this
  low-speed mouse (`1bcf:0005`): connect at 1.5 Mb/s, lost during the 100 ms debounce, hub/dwc3 autosuspend, remote
  wake on D- ~5 s later, then enumeration: ~6.5 s every time, independent of uptime (full-speed mouse: ~1 s).
- 15 min screen-off with wireless adb: **reproduced** (sysfs `event8` present, `/dev/input/event8` missing). 6,894
  uevents: **5,831 `online cpu`** (+ 980 battery `change`), i.e. ~830 resumes in 16 min (`suspend_stats/success` 830).
  Every resume: `Resume caused by IRQ 81, WLAN_CE_2`, `WOW Wakeup: IPV4 TCP Packet` from this PC: the adb client's
  ~1 s TCP keepalive on wireless connections (`ss -tnoi`: `timer:(keepalive,460ms)`). Wireless adb exaggerates it,
  but any chatty network does the same.
- The `online` uevents come from `49d0e06a2539` "ANDROID: cpu: send KOBJ_ONLINE event when enabling cpus" (2016,
  also in the 22.2 base): 7 per resume, no offline counterpart. ueventd runs `FixupSysPermissions` + recursive
  restorecon on `/sys/devices/system/cpu/cpuN` for each (~26 ms CPU each), only while awake, so it falls minutes
  behind. On this device it's a no-op: cpu0 vs cpu3 labels identical (genfs `sysfs_devices_system_cpu`), no
  file_contexts rule for that path, and the `ueventd.rc` chown targets (`cpufreq/scaling_{max,min}_freq`) live in
  `cpufreq/policyN`, which persists across suspend (owned 1000:1000 since boot).
- Test fix: revert on local kernel branch `test-resume-uevent` (`a668db21f3cf`), repacked into the debug build's boot
  image (`~/work/boot-backup/uevent/`), to be verified with the same 15 min wireless-adb test.
