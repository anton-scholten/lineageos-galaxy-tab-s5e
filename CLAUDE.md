# CLAUDE.md

Project: LineageOS 23.2 (Android 16) on the Samsung Galaxy Tab S5e is **done**; GitHub release v23.2-20261008 is drafted (publishing pending);
next is LineageOS 24 ([FEASIBILITY-LINEAGE-24.md](FEASIBILITY-LINEAGE-24.md), tasks [analysis/l24/TASKS-L24.md](analysis/l24/TASKS-L24.md), RUNBOOK §9). The device is the Samsung Galaxy Tab S5e
(`gts4lvwifi` SM-T720, `gts4lv` SM-T725/T727). This repo holds documentation, analysis,
local manifests and device-tree patches. It is not an Android source tree.

- Start with [HANDOVER.md](HANDOVER.md) (current state and plan), then [LEAD-SYNTHESIS.md](LEAD-SYNTHESIS.md) (research findings), then [WORKLOG.md](WORKLOG.md).
- The work is run from [RUNBOOK.md](RUNBOOK.md): free-model agents do the steps, and you are usually called as the **reviewer** ("Prompt R").
  Track progress in `analysis/port/STATUS.md`.
- Main docs: `README.md` (users), `PORTING-LINEAGE-23.2.md`, `KERNEL-BACKPORT-PLAN.md`,
  `ESTIMATE.md`, `PRIOR-WORK.md`, `REPO-SETUP.md`, `AGENT-TASKS.md` (work for helper agents; their entry point is `AGENTS.md`).
- Code lives in the forks, branch `lineage-23.2`: `anton-scholten/android_device_samsung_gts4lv-common`
  (= LineageOS `d1b339b` + patches 0001–0004 + audio XML + P6 AntHalService fix + boot fixes, uclamp, WFD shim, SELinux; in the 20261008 release, `1188e2b`),
  `anton-scholten/android_kernel_samsung_sdm670` (= the ported ExyHyperBrick series + SELinux avtab fix, `500658be3c16`), and
  `anton-scholten/proprietary_vendor_samsung_gts4lv-common` (= TheMuppets `lineage-22.2` + patched `libwfdservice.so` + perf XML remap, `51de1d4`). `scripts/check-pins.sh` checks all pins.
- Build tree: external drive `/mnt/build/lineage`, bind-mounted at `~/android/lineage` (HANDOVER "Build machine layout").
  `patches/` is only a record of 0001–0004. New device-tree changes go into the fork as commits, not as new patch files.
- Backup forks (read-only snapshots, never sync): `anton-scholten/android_kernel_samsung_exynos9810`,
  `anton-scholten/android_device_samsung_exynos9810-common`.
- When you change anything, update `WORKLOG.md`, plus `HANDOVER.md` if the state or next steps changed.
- Licences: this repo is Apache-2.0; kernel work is GPL-2.0 and belongs in a separate fork.
- Mark data-erasing user steps with ⚠️. Keep replies to the owner short.
