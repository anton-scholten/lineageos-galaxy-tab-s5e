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

## Not done yet
- No kernel port branch is published. The trial trees have unresolved or blindly resolved conflicts, so
  they're not fit to publish.
- Nothing has been built as a full ROM or booted on a tablet.

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
