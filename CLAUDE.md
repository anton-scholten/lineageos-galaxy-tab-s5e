# CLAUDE.md

Project: unofficial LineageOS 23.2 (Android 16) and 24 (Android 17) for the Samsung Galaxy Tab S5e
(`gts4lvwifi` SM-T720, `gts4lv` SM-T725/T727), both **released** with over-the-air updates. This repo holds the
user docs, release notes, OTA feeds, local manifests and build scripts. It is not an Android source tree.

- Start with [HANDOVER.md](HANDOVER.md) (current state and next steps), then the end of [WORKLOG.md](WORKLOG.md).
- Docs: `README.md` (users and developers), `RELEASING.md`, `UPSTREAM.md`, `TESTING.md`, `REPO-SETUP.md`.
- Branch layout: every fork has `lineage-23.2` and `lineage-24.0` (compat, core, vold and sepolicy_vndr forks only
  `lineage-24.0`), plus `lineage-22.2` as the base. This repo: `main` (current) and `lineage-23.2` (= tag
  `v23.2-20261008`). New work branches are deleted once merged.
- Code lives in the forks (both branches unless noted): `anton-scholten/android_device_samsung_gts4lv-common`
  (23.2 `f4c18f4`, 24 `83ab401`), `anton-scholten/android_kernel_samsung_sdm670` (ExyHyperBrick series + SELinux avtab
  fix + BPF ld_abs R2 fix + EROFS + fuse-bpf umask fix + MADV_PAGEOUT dirty fix + no resume CPU uevents, `a668db21f3cf`
  on both),
  `anton-scholten/proprietary_vendor_samsung_gts4lv-common` (23.2 `51de1d4`, 24 `1e0cce7`),
  `anton-scholten/android_packages_modules_Bluetooth` (23.2 `f500ef4c4a`, 24 `297e808335`; LineageOS merged 2026-10-25), and for 24 the
  system/core, system/vold, hardware/lineage/compat and device/qcom/sepolicy_vndr forks. `scripts/check-pins.sh`
  checks all pins. Device-tree changes go into the fork as commits.
- Fixes owed upstream (LineageOS Gerrit, krazey) are tracked in [UPSTREAM.md](UPSTREAM.md); keep it current.
- Releases and OTA follow [RELEASING.md](RELEASING.md); release notes list only the changes since the previous build.
  Never read, print, commit or send the private signing keys (`*.pk8`, `vendor/lineage-priv/`, `~/.android-certs`).
- Build trees: external drive, real paths `/mnt/build/lineage-23.2` and `/mnt/build/lineage-24` (no bind mount or
  symlink); release files in `/mnt/build/releases/<version>-<date>/`. Build with `scripts/build-all.sh`.
- Backup forks (read-only snapshots, never sync): `anton-scholten/android_kernel_samsung_exynos9810`,
  `anton-scholten/android_device_samsung_exynos9810-common`.
- When you change anything, update `WORKLOG.md`, plus `HANDOVER.md` if the state or next steps changed.
- Licences: this repo is Apache-2.0; kernel work is GPL-2.0 and belongs in a separate fork.
- Mark data-erasing user steps with ⚠️. Keep replies to the owner short.
