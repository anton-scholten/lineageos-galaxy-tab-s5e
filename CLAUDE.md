# CLAUDE.md

Project: port LineageOS 23.2 (Android 16) to the Samsung Galaxy Tab S5e
(`gts4lvwifi` SM-T720, `gts4lv` SM-T725/T727). This repo holds documentation, analysis,
local manifests and device-tree patches. It is not an Android source tree.

- Start with [HANDOVER.md](HANDOVER.md) (current state and next steps), then [WORKLOG.md](WORKLOG.md).
- Main docs: `README.md` (users), `PORTING-LINEAGE-23.2.md`, `KERNEL-BACKPORT-PLAN.md`,
  `ESTIMATE.md`, `PRIOR-WORK.md`, `REPO-SETUP.md`, `AGENT-TASKS.md` (work for helper agents).
- Patches: `patches/device/samsung/gts4lv-common/*.patch` (made with `git format-patch` against LineageOS
  `lineage-22.2` `d1b339b`). Apply with `./apply-patches.sh <src> [--with-bpf-override]`.
  Regenerate them with `git format-patch` from a real clone; don't hand-edit the hunks.
- When you change anything, update `WORKLOG.md`, plus `HANDOVER.md` if the state or next steps changed.
- Licences: this repo is Apache-2.0; kernel work is GPL-2.0 and belongs in a separate fork.
- Mark data-erasing user steps with ⚠️. Keep replies to the owner short.
