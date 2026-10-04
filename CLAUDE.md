# CLAUDE.md

Project: port LineageOS 23.2 (Android 16) to the Samsung Galaxy Tab S5e
(`gts4lvwifi` SM-T720, `gts4lv` SM-T725/T727). This repo holds documentation, analysis,
local manifests and device-tree patches. It is not an Android source tree.

- Start with [HANDOVER.md](HANDOVER.md) (current state and plan), then [LEAD-SYNTHESIS.md](LEAD-SYNTHESIS.md) (research findings), then [WORKLOG.md](WORKLOG.md).
- The work is run from [RUNBOOK.md](RUNBOOK.md): free-model agents do the steps, and you are usually called as the **reviewer** ("Prompt R").
  Track progress in `analysis/port/STATUS.md`.
- Main docs: `README.md` (users), `PORTING-LINEAGE-23.2.md`, `KERNEL-BACKPORT-PLAN.md`,
  `ESTIMATE.md`, `PRIOR-WORK.md`, `REPO-SETUP.md`, `AGENT-TASKS.md` (work for helper agents; their entry point is `AGENTS.md`).
- Code lives in the forks, branch `lineage-23.2`: `anton-scholten/android_device_samsung_gts4lv-common`
  (= LineageOS `d1b339b` + patches 0001–0004 + audio XML, `e3ccc923bcf2`) and `anton-scholten/android_kernel_samsung_sdm670` (= the ported ExyHyperBrick series, `801f3f20e54a`; builds).
  `patches/` is only a record of 0001–0004. New device-tree changes go into the fork as commits, not as new patch files.
- Backup forks (read-only snapshots, never sync): `anton-scholten/android_kernel_samsung_exynos9810`,
  `anton-scholten/android_device_samsung_exynos9810-common`.
- When you change anything, update `WORKLOG.md`, plus `HANDOVER.md` if the state or next steps changed.
- Licences: this repo is Apache-2.0; kernel work is GPL-2.0 and belongs in a separate fork.
- Mark data-erasing user steps with ⚠️. Keep replies to the owner short.
