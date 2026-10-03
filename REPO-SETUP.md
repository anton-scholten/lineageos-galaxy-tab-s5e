# Repository setup review

## Status (2026-10-03)

The owner created **`anton-scholten/lineageos-galaxy-tab-s5e`**, and the full history was pushed there as `main`.
That is now the home of this project. The forks (step 3 below) exist now, still at LineageOS `lineage-22.2`. Step 4 is left.

### Old repo `anton-scholten/Lineage-OS-SM-T720`: safe to delete
Checked 2026-10-03. Its only branch, `claude/nifty-lamport-yf0vex`, ends at `71029d0`, which is already in this
repo's `main`. So every commit and file is here. It has no other branches, tags, issues, pull requests or releases.
(Its wiki couldn't be checked from the session. Look at the Wiki tab first if you ever turned it on.)
⚠️ Deleting a repo can't be undone. **Archiving** (Settings → General → Archive this repository) is the safe option.

## Original state of the old repo

`anton-scholten/Lineage-OS-SM-T720`: private, only the branch
`claude/nifty-lamport-yf0vex`, no `main`, no description.

| Issue | Why it matters |
|---|---|
| The name says **SM-T720** only | The work covers every Tab S5e model: SM-T720/T720N (`gts4lvwifi`) and SM-T725/T725C/T725N/T727 (`gts4lv`) |
| "Lineage-OS" spelling | The project calls itself **LineageOS**, which matters when people search for it |
| No `main` branch | Everything sits on a working branch, so the default page is that branch |
| Kernel and device-tree changes are stored as `.patch` files | The LineageOS build pulls **separate git repos** (`kernel/samsung/sdm670`, `device/samsung/gts4lv-common`) through `repo`. A real port needs those as forks with a `lineage-23.2` branch, not patches in a documentation repo |
| Mixed licences | Docs and scripts are Apache-2.0, kernel code must be GPL-2.0. Keeping them in separate repos keeps that clean |

**Verdict:** this repo works as the project's documentation and analysis home, but
it should be renamed or moved, and the code should go into forks that follow LineageOS naming.

## Recommended layout

| Repo | Contents | Licence |
|---|---|---|
| `anton-scholten/lineageos-galaxy-tab-s5e` | This repo: README, plans, estimate, analysis, local manifests, scripts | Apache-2.0 |
| `anton-scholten/android_kernel_samsung_sdm670` | Fork of `LineageOS/android_kernel_samsung_sdm670`, branch `lineage-23.2` = the ported ExyHyperBrick series | GPL-2.0 |
| `anton-scholten/android_device_samsung_gts4lv-common` | Fork of the LineageOS repo, branch `lineage-23.2` = patches 0001–0004 as commits | Apache-2.0 |
| `gts4lv`, `gts4lvwifi` device repos | Not forked yet. Fork them when a 23.2 change needs them (task R6 may find one) | Apache-2.0 |
| Vendor blobs (TheMuppets) | No changes expected. Keep using `lineage-22.2` | |

Once the forks exist, `local_manifests/gts4lv-common.xml` points `device/samsung/gts4lv-common`
and `kernel/samsung/sdm670` at them, and `patches/` + `apply-patches.sh` can be retired.

## Steps (1–3 done)

This session can't create repositories. `create_repository` returned
`403 Resource not accessible by integration`, and GitHub access is limited to this one repo.
It needs to be done on github.com:

1. **Docs repo** (pick one):
   - **Rename** this repo to `lineageos-galaxy-tab-s5e` (Settings → General → Repository name).
     GitHub redirects the old URL, and nothing is lost. **Recommended.**
   - Or create an empty `lineageos-galaxy-tab-s5e` and attach it to a Claude session. The full
     history is then pushed there as `main`.
2. Make `main` the default branch: merge `claude/nifty-lamport-yf0vex` into `main` (or push it as `main`).
3. **Forks** (when the kernel port starts): on github.com, fork
   `LineageOS/android_kernel_samsung_sdm670` and `LineageOS/android_device_samsung_gts4lv-common`.
   Forks of public repos are always public.
4. Attach those repos to a Claude session with push access (below), so the `lineage-23.2` branches can be pushed.

## What to fork to get lineage-23.2

No repo anywhere has `lineage-23.2` for this tablet, because LineageOS stopped at 22.2 over the 4.9 kernel.
So nothing upstream can be forked "with 23.2". You create the branch yourself in your fork, starting from
`lineage-22.2`, and copy in the changes from other trees that already have 23.2.
See [`analysis/reference-trees/`](analysis/reference-trees/README.md).

| Repo | Fork? | Why |
|---|---|---|
| `LineageOS/android_kernel_samsung_sdm670` | ✅ done | Gets branch `lineage-23.2` = `lineage-22.2` + the ported ExyHyperBrick eBPF series |
| `LineageOS/android_device_samsung_gts4lv-common` | ✅ done | Gets branch `lineage-23.2` = `lineage-22.2` + patches 0001–0004 + more from the reference trees |
| `ExyHyperBrick/android_kernel_samsung_exynos9810` | **Recommended** | The source of the kernel series (`lineage-23.2`, 4.9 + eBPF at 5.15 level). It's one person's active work with many WIP branches. A fork keeps a copy if branches are rewritten or deleted. Don't change it, it's only a backup |
| `ExyHyperBrick/android_device_samsung_exynos9810-common` | Recommended | Same reason. It holds the 4.9-specific userspace changes for 23.2 |
| `LineageOS/android_device_samsung_gts4lv`, `..._gts4lvwifi` | Later, if needed | Only if a 23.2 change has to go in the per-model trees |
| `LineageOS/android_device_samsung_sm7125-common` | No | Read-only reference (official 23.2 Samsung Qualcomm tree) |
| `LineageOS/android_hardware_samsung` | No | Already has `lineage-23.2` |
| TheMuppets vendor repos | No | Blobs stay the same |

## Attaching repos to a Claude cloud session

A session only gets push access to the GitHub repos attached to it. Public repos (all the forks) can always be
*read* without attaching.

1. Once: make sure the Claude GitHub App can reach the repos. Go to <https://claude.ai/connect-github>
   (or GitHub → Settings → Applications → Claude → Configure) and either pick "All repositories" or add each fork.
2. Then either:
   - **New session:** on claude.ai/code, pick the repos in the repository selector when you start the session. You can pick more than one. Or
   - **Running session:** ask Claude, for example "attach `anton-scholten/android_kernel_samsung_sdm670` with push access".
     Claude calls `add_repo`. The session's permission check may ask you to approve, or block it unless you asked in those words.
     To allow it without asking, add a permission rule for `mcp__claude-code-remote__add_repo` in the session settings.
3. Attached repos are cloned to `/home/user/<repo-name>`. The kernel is ≈2.3 GB, so the first clone takes 10–30 min.

Status 2026-10-03: both forks are attached to session `session_016fF5iQ8x8B4G2hfnShauMQ` with push access.

## Backup forks of ExyHyperBrick (owner, on github.com)
Their default branch is `lineage-24.0`. GitHub's fork page copies **only the default branch** unless you untick the box,
and then `lineage-23.2` would be missing.

For each of `https://github.com/ExyHyperBrick/android_kernel_samsung_exynos9810` and
`https://github.com/ExyHyperBrick/android_device_samsung_exynos9810-common`:
1. Open the URL, then click **Fork** (top right).
2. Owner: `anton-scholten`. Keep the name.
3. **Untick "Copy the `lineage-24.0` branch only".**
4. Click **Create fork**.
5. Check: the branch list of the fork (`/branches/all`) shows `lineage-23.2`.

Never click "Sync fork" on these. They're snapshots, and a sync would bring in rewrites from upstream.
