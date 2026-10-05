# Repository setup

All setup is done (2026-10-03). The history of how we got here is in [WORKLOG.md](WORKLOG.md).

## Repos

| Repo | What's in it | Branch to use | Licence |
|---|---|---|---|
| `anton-scholten/lineageos-galaxy-tab-s5e` (private) | This repo: docs, analysis, local manifests, patch record | `main` | Apache-2.0 |
| [`anton-scholten/android_device_samsung_gts4lv-common`](https://github.com/anton-scholten/android_device_samsung_gts4lv-common) | Device tree fork | `lineage-23.2` @ `d154fb4384fb` = LineageOS `d1b339b` + patches 0001–0004 + the audio-policy XML commit + the P6 `AntHalService` fix | Apache-2.0 |
| [`anton-scholten/android_kernel_samsung_sdm670`](https://github.com/anton-scholten/android_kernel_samsung_sdm670) | Kernel fork | `lineage-23.2` @ `801f3f20e54a` = LineageOS `a30605a54f3b` + the ported ExyHyperBrick eBPF series + build fixes (builds `Image.gz-dtb`) | GPL-2.0 |
| [`anton-scholten/android_kernel_samsung_exynos9810`](https://github.com/anton-scholten/android_kernel_samsung_exynos9810) | **Backup** of the ExyHyperBrick S9 kernel: the source of the eBPF series. All 48 branches | `lineage-22.2` `d54533f1546b` → `lineage-23.2` `baa585f67e0e` | GPL-2.0 |
| [`anton-scholten/android_device_samsung_exynos9810-common`](https://github.com/anton-scholten/android_device_samsung_exynos9810-common) | **Backup** of the ExyHyperBrick S9 device tree (4.9-specific 23.2 changes). All 24 branches | `lineage-22.2` `c7d22a36ba1e` → `lineage-23.2` `ced977559b13` | Apache-2.0 |

All forks are public, so anyone can clone them without credentials.
The two backups match ExyHyperBrick upstream exactly (checked 2026-10-03). **Never click "Sync fork" on them.**
They're snapshots, so that our pinned commits can't disappear if upstream rewrites its branches.

Used as-is, not forked:
- `LineageOS/android_device_samsung_gts4lv` and `..._gts4lvwifi` (`lineage-22.2`). Fork them only if a 23.2 change has to go there.
- `LineageOS/android_hardware_samsung` (has a real `lineage-23.2`).
- TheMuppets vendor repos (`lineage-22.2`).
- Reference only: `LineageOS/android_device_samsung_sm7125-common` (official 23.2). See [`analysis/reference-trees/`](analysis/reference-trees/README.md).

Why no repo has `lineage-23.2` for this tablet: LineageOS stopped at 22.2 because of the 4.9 kernel. So our forks carry
the only `lineage-23.2` branches, and we copy changes in from the reference trees.

## Rules
- Kernel work goes on the kernel fork's `lineage-23.2` as `git cherry-pick -x` commits, keeping the original authors.
- Device-tree work goes on the device fork's `lineage-23.2` as normal commits. `patches/` in this repo is only a record of 0001–0004.
  Don't add new patch files there.
- `local_manifests/gts4lv-common.xml` already points at both forks (`remote="anton"`, `lineage-23.2`).

## Attaching repos to a Claude cloud session
A session can only push to repos attached to it. Public repos can be read without attaching.
1. Once: let the Claude GitHub App reach the repos at <https://claude.ai/connect-github>
   ("All repositories", or add each one).
2. Then either:
   - **New session:** pick the repos in the repository selector on claude.ai/code. Or
   - **Running session:** ask Claude, for example "attach `anton-scholten/android_kernel_samsung_sdm670` with push access".
     The permission check may block it unless you ask in those words. Adding a permission rule for
     `mcp__claude-code-remote__add_repo` lets it through without asking.
3. Attached repos are cloned to `/home/user/<repo-name>`. The full kernel is ≈2.3 GB, so it takes 10–30 min.
   A `--depth 1` clone is enough to push a branch.

Helper agents that aren't Claude: see [AGENT-TASKS.md §0.6](AGENT-TASKS.md#06-access-for-agents-that-arent-claude-owner-sets-this-up-once).
