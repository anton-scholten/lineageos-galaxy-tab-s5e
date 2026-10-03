# Repository setup review

## Current state

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
| `gts4lv`, `gts4lvwifi` device repos and vendor blobs | No changes needed. Keep using LineageOS / TheMuppets `lineage-22.2` | |

Once the forks exist, `local_manifests/gts4lv-common.xml` points `device/samsung/gts4lv-common`
and `kernel/samsung/sdm670` at them, and `patches/` + `apply-patches.sh` can be retired.

## Why it isn't done yet

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
4. Start a session with those repos attached, so the `lineage-23.2` branches can be pushed.
