# CLAUDE.md

Project: unofficial LineageOS 23.2 (Android 16) and 24 (Android 17) for the Samsung Galaxy Tab S5e
(`gts4lvwifi` SM-T720, `gts4lv` SM-T725/T727), both released with over-the-air updates. **Only 24 is built
and released from 2026-11-04**; 23.2 is frozen at `v23.2-20261026`. This repo holds the
user docs, release notes, OTA feeds, local manifests and build scripts. It is not an Android source tree.

- Start with [HANDOVER.md](HANDOVER.md) (current state and next steps), then the end of [WORKLOG.md](WORKLOG.md).
- Docs: `README.md` (users and developers), `RELEASING.md`, `UPSTREAM.md`, `TESTING.md`, `REPO-SETUP.md`.
- Branch layout: every fork has `lineage-23.2` and `lineage-24.0` (compat, core, vold and sepolicy_vndr forks only
  `lineage-24.0`), plus `lineage-22.2` as the base. This repo: `main` (current) and `lineage-23.2` (= tag
  `v23.2-20261008`). New work branches are deleted once merged.
- Code lives in the forks (both branches unless noted): `anton-scholten/android_device_samsung_gts4lv-common`
  (23.2 `f4c18f4`, 24 `b6ee69f`), `anton-scholten/android_kernel_samsung_sdm670` (ExyHyperBrick series + SELinux avtab
  fix + BPF ld_abs R2 fix + EROFS + fuse-bpf umask fix + MADV_PAGEOUT dirty fix + no resume CPU uevents, 23.2
  `a668db21f3cf`, 24 `a548c1ceaed7` = + LZ4 for zram + vidc 4K60 load fix),
  `anton-scholten/proprietary_vendor_samsung_gts4lv-common` (23.2 `51de1d4`, 24 `1e0cce7`),
  `anton-scholten/android_packages_modules_Bluetooth` (23.2 `f500ef4c4a`, 24 `98188b0c39`; LineageOS merged 2026-11-04), `anton-scholten/android_packages_apps_Launcher3`
  (23.2 only, `4be5887bda`; nav button fix, upstream in 24), and for 24 the
  system/core, system/vold, frameworks/av (10-bit thumbnails, `8ba1024bfc`), hardware/lineage/compat and
  device/qcom/sepolicy_vndr forks. `scripts/check-pins.sh`
  checks all pins. Device-tree changes go into the fork as commits.
- Fixes owed upstream (LineageOS Gerrit, krazey) are tracked in [UPSTREAM.md](UPSTREAM.md); keep it current.
- Patches for LineageOS (Gerrit, or sent to luk1337 for the 4.19 port) follow the
  [AI charter](https://github.com/LineageOS/charter/blob/main/ai-coding-assistants.md): trailer
  `Assisted-by: LLM - Claude Opus 5.5` instead of `Co-Authored-By`, short commit messages (body only for the
  non-obvious), comments only for non-obvious logic, SPDX headers on new files, no proprietary/decompiled code.
  The owner reviews and must be able to explain every patch before it is sent. Our own forks keep `Co-Authored-By`.
- 4.19 eval (issue #7, luk1337's port): test tree only, never released, never signed with our release keys.
- Releases and OTA follow [RELEASING.md](RELEASING.md); release notes list only the changes since the previous build.
  Never read, print, commit or send the private signing keys (`*.pk8`, `vendor/lineage-priv/`, `~/.android-certs`).
- Build trees: external drive, real paths `/mnt/build/lineage-24` and the 4.19 eval tree `/mnt/build/lineage-24-419`
  (no bind mount or symlink; the 23.2 tree was deleted 2026-11-13, re-sync it if 23.2 is ever built again);
  release files in `/mnt/build/releases/<version>-<date>/`, latest release only. Build with `scripts/build-all.sh`.
- Builds are debug builds by default, as fast as possible: `m` (or `m bootimage` / `m <module>`) and flash through
  fastbootd (`adb reboot fastboot && fastboot flashall --skip-reboot && fastboot reboot recovery`, so the tablet
  stays in recovery to sideload MindTheGapps before first boot) or `adb sync`, no zip (README "Debug builds"). Only releases
  use `mka bacon` / `scripts/build-all.sh` and the full RELEASING.md flow. From the agent's shell, run builds in
  `env -i ... bash --noprofile --norc` (the tool shell's `grep` breaks `breakfast`), detached with `setsid nohup` so
  a session end does not kill them.
- Backup forks (read-only snapshots, never sync): `anton-scholten/android_kernel_samsung_exynos9810`,
  `anton-scholten/android_device_samsung_exynos9810-common`.
- When you change anything, update `WORKLOG.md`, plus `HANDOVER.md` if the state or next steps changed.
- Licences: this repo is Apache-2.0; kernel work is GPL-2.0 and belongs in a separate fork.
- Mark data-erasing user steps with ⚠️. Keep replies to the owner short.
