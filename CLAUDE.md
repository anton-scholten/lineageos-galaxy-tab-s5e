# CLAUDE.md

Project: LineageOS 23.2 (Android 16) on the Samsung Galaxy Tab S5e is **done**; GitHub releases v23.2-20261008 and v23.2-20261014 are published; v23.2-20261016 (Bluetooth/AOD fixes, tablet defaults) and v24.0-20261016 (first 24 release) are drafted;
next is LineageOS 24 ([FEASIBILITY-LINEAGE-24.md](FEASIBILITY-LINEAGE-24.md), tasks [analysis/l24/TASKS-L24.md](analysis/l24/TASKS-L24.md), RUNBOOK §9). The device is the Samsung Galaxy Tab S5e
(`gts4lvwifi` SM-T720, `gts4lv` SM-T725/T727). This repo holds documentation, analysis,
local manifests and device-tree patches. It is not an Android source tree.

- Start with [HANDOVER.md](HANDOVER.md) (current state and plan), then [LEAD-SYNTHESIS.md](LEAD-SYNTHESIS.md) (research findings), then [WORKLOG.md](WORKLOG.md).
- The work is run from [RUNBOOK.md](RUNBOOK.md): free-model agents do the steps, and you are usually called as the **reviewer** ("Prompt R").
  Track progress in `analysis/port/STATUS.md`.
- Main docs: `README.md` (users), `PORTING-LINEAGE-23.2.md`, `KERNEL-BACKPORT-PLAN.md`,
  `ESTIMATE.md`, `PRIOR-WORK.md`, `REPO-SETUP.md`, `AGENT-TASKS.md` (work for helper agents; their entry point is `AGENTS.md`).
- Branch layout (2026-10-12): every fork has just `lineage-23.2` (released) and `lineage-24.0` (built, ROM zip produced; compat fork has only `lineage-24.0`), plus `lineage-22.2` as the base. This repo: `main` (current, includes the 24 work) and `lineage-23.2` (= tag `v23.2-20261008`). No `port/*` or `agent/*` branches; new work branches are deleted once merged.
- Code lives in the forks, branch `lineage-23.2`: `anton-scholten/android_device_samsung_gts4lv-common`
  (= LineageOS `d1b339b` + patches 0001–0004 + audio XML + P6 AntHalService fix + boot fixes, uclamp, WFD shim, SELinux, AOD DOZE fix, tablet defaults; `82ca61a`; 20261008 release had `1188e2b`),
  `anton-scholten/android_kernel_samsung_sdm670` (= the ported ExyHyperBrick series + SELinux avtab fix + BPF ld_abs R2 fix + EROFS + fuse-bpf umask fix, `7bf5ff571b75`, same on `lineage-24.0`; 20261008 release had `500658be3c16`), and
  `anton-scholten/proprietary_vendor_samsung_gts4lv-common` (= TheMuppets `lineage-22.2` + patched `libwfdservice.so` + perf XML remap, `51de1d4`), and
  `anton-scholten/android_packages_modules_Bluetooth` (= LineageOS + `bluetooth.hci.disabled_commands` restored; 23.2 `8c6d706e11`, 24 `11434c8f8a`). `scripts/check-pins.sh` checks all pins.
- Fixes owed upstream (LineageOS Gerrit, krazey) are tracked in [UPSTREAM.md](UPSTREAM.md); keep it current.
- Releases and OTA follow [RELEASING.md](RELEASING.md). Never read, print, commit or send the private signing keys (`*.pk8`, `vendor/lineage-priv/`, `~/.android-certs`).
- Build trees: external drive, real paths `/mnt/build/lineage-23.2` and `/mnt/build/lineage-24` (no bind mount or symlink); release files in `/mnt/build/releases/<version>-<date>/`. Build with `scripts/build-all.sh` (HANDOVER "Build machine layout").
  `patches/` is only a record of 0001–0004. New device-tree changes go into the fork as commits, not as new patch files.
- Backup forks (read-only snapshots, never sync): `anton-scholten/android_kernel_samsung_exynos9810`,
  `anton-scholten/android_device_samsung_exynos9810-common`.
- When you change anything, update `WORKLOG.md`, plus `HANDOVER.md` if the state or next steps changed.
- Licences: this repo is Apache-2.0; kernel work is GPL-2.0 and belongs in a separate fork.
- Mark data-erasing user steps with ⚠️. Keep replies to the owner short.
