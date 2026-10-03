# Work for parallel helper agents

Tasks sized for **less capable agents working in parallel**. Each one is small, has fixed
inputs, writes to its own output path, and has a check you can run to see that it's done.
A stronger agent or the owner reviews and merges the results. Judgment-heavy work (large
conflicts, first boot) is kept out of these tasks and listed at the end.

State checked 2026-10-03: see [HANDOVER.md](HANDOVER.md).

## Rules for every task
1. Work in this repo on your own branch `agent/<task-id>`. Write only to the output path the task names.
2. **Don't push to the forks** (`anton-scholten/android_kernel_samsung_sdm670`,
   `anton-scholten/android_device_samsung_gts4lv-common`). Only tasks S1–S3 touch them, and the owner does those.
3. Never resolve a kernel conflict by taking one side whole. These tasks only *propose* resolutions.
4. Every claim names its source: commit SHA, or `file:line` at a stated commit.
5. If you're unsure, write `confidence: low` and say why. A wrong answer given confidently costs more than no answer.
6. Kernel code is GPL-2.0. Don't paste kernel code longer than about 20 lines into this repo; give the SHA and path instead.

## Shared setup (kernel tasks)
Pinned commits (unchanged since the trial):

| Repo | Ref | Commit |
|---|---|---|
| `LineageOS/android_kernel_samsung_sdm670` (= fork) | `lineage-22.2` | `a30605a54f3b` |
| `ExyHyperBrick/android_kernel_samsung_exynos9810` | `lineage-22.2` | `d54533f1546b` |
| same | `lineage-23.2` | `baa585f67e0e` |

Use the clone recipe in [HANDOVER.md](HANDOVER.md#rebuilding-the-working-environment-cloud-container) (≈2.3 GB, 10–30 min).
If the ExyHyperBrick `lineage-23.2` head has moved past `baa585f67e0e`, keep using `baa585f67e0e`.

---

## S: setup (owner, on github.com or in a session with push access)

| ID | Task | Done when |
|---|---|---|
| S1 | Device fork: `git checkout -b lineage-23.2 origin/lineage-22.2 && git am patches/device/samsung/gts4lv-common/*.patch`, push | Branch `lineage-23.2` = `d1b339b` + 4 commits (checked to apply cleanly on 2026-10-03) |
| S2 | Kernel fork: push a `lineage-23.2` branch at `a30605a54f3b` (no changes yet) | Branch exists |
| S3 | Attach both forks to a Claude session with **push** access (`add_repo`, access `push`) | `git push` to the fork works from the session |

## M: manifests and repo housekeeping (no kernel clone needed)

| ID | Task | Output | Done when |
|---|---|---|---|
| M1 | After S1/S2: point `device/samsung/gts4lv-common` and `kernel/samsung/sdm670` in `local_manifests/gts4lv-common.xml` at the forks, branch `lineage-23.2`. Add a `<remote name="anton" fetch="https://github.com/anton-scholten" />` | `local_manifests/gts4lv-common.xml` | `xmllint --noout` passes; every `name`+`revision` exists (`git ls-remote`) |
| M2 | Check every link in the `*.md` files (relative paths and GitHub URLs) | `analysis/link-check.md` | Lists each broken link with file:line |
| M3 | Write `scripts/check-pins.sh`: prints the current SHA of every repo/branch in the manifests and the table above, and flags any that moved | `scripts/check-pins.sh` | Runs with only `git` + `bash`; exits non-zero if a pin moved |

## K: kernel research (read-only, many agents in parallel)

### K1: upstream-origin map (one agent)
For each of the 2,599 commits in `exy/l222..exy/l232`, pull the upstream Linux SHA out of the
message (`commit <sha> upstream`, `(cherry picked from commit <sha>)`, `Upstream commit <sha>`,
`[ Upstream commit <sha> ]`). Then check whether sdm670 `a30605a54f3b` already has that upstream
commit: same trailer in `git log`, or the same subject.

- Output: `analysis/upstream-map/upstream-map.tsv` with columns
  `exy_commit, subject, upstream_sha, sdm670_has(yes/no/unknown), sdm670_commit` and the script that made it.
- Done when: the script reruns and gives the same TSV; row count = 2,599.
- Why it helps: many of the 150 conflicts are changes sdm670 already carries from `android-4.9-q`. They just need the duplicate dropped.

### K2: conflict briefs (split into batches, one agent per batch)
For each commit in a batch, write a brief: `analysis/conflicts/<12-char sha>.md`.

Batches (rows of [`conflict_detail.tsv`](analysis/exyhyperbrick-trial/conflict_detail.tsv) by `group` and `size_class`):

| Batch | Filter | Commits | Agents |
|---|---|---|---|
| K2a | required + trivial | 37 | 3–4 (≈10 each) |
| K2b | required + moderate | 35 | 4 (≈9 each) |
| K2c | optional + trivial | 18 | 2 |
| K2d | optional + moderate/modify-delete | 23 | 2–3 |

Split a batch by row order, for example:
`awk -F'\t' '$9=="required" && $8=="trivial"' conflict_detail.tsv | sed -n '1,10p'`.

Each brief has these headings:
1. **Commit**: SHA, subject, author, upstream SHA (from K1 if done).
2. **Conflicting files** (from `results.tsv`).
3. **Why it conflicts**: run `git merge-tree --write-tree --merge-base=<sha>^ <sdm670-tip> <sha>` and quote only the conflicting hunk headers and a 1–2 line summary per hunk.
4. **Does sdm670 already have it?** yes / partly / no, with the sdm670 commit SHA.
5. **Proposed resolution**: one of `drop (already present)`, `take series hunk X, keep sdm670 hunk Y`, `needs prerequisite <sha>`, `needs human`.
6. **Confidence**: high / medium / low.

Done when: one brief per commit in the batch, all six headings filled.

### K3: large conflicts, facts only (one agent per 3 commits)
For the 12 `required + large` commits: brief headings 1–4 only, plus the list of later
series commits that touch the same files (`git log --format=%h exy/l222..exy/l232 -- <files>`).
**No proposed resolution**: a stronger agent or a human resolves these.

### K4: first build errors (one agent per error)
From [`analysis/build-test/port-first-errors.txt`](analysis/build-test/port-first-errors.txt):

| ID | Symbol |
|---|---|
| K4a | `randomized_struct_fields_end` (`include/linux/sched.h`) |
| K4b | `ANDROID_VERSION` (`include/uapi/asm-generic/socket.h`) |
| K4c | `TIF_FSCHECK` (`arch/arm64/include/asm/uaccess.h`) |
| K4d | `asm-offsets.c:49` offsetof error (probably follows from K4a/K4c) |

For each one: find the commit that defines the symbol in the ExyHyperBrick tree
(`git log -S<symbol> exy/l232`), and say whether that commit is in the series, was skipped as
Exynos-only, or comes from before `exy/l222` (a missing prerequisite). For `ANDROID_VERSION`, find where the
Exynos tree's Makefile or Kconfig sets it.
Output: `analysis/build-test/errors/<id>.md`. Done when: defining commit and its status are named.

### K5: driver API audit (one agent per area)
Areas: `drivers/net/ethernet/qualcomm/rmnet`, `drivers/platform/msm/ipa`, `drivers/staging/qcacld-3.0`,
`net/qrtr` + `drivers/soc/qcom/*dfc*`, `techpack/`, `drivers/net/wireless` (Samsung), `security/samsung` and `sec_net`.

1. Make the list of changed functions once (the first agent to start publishes it at
   `analysis/api-audit/changed-api.txt`): every exported function or struct field whose
   signature changes in `git diff a30605a54f3b <port tree>` for `include/linux/{skbuff,netdevice,bpf,filter,net}.h`
   and `include/net/*.h`. If no port tree exists yet, use `git diff d54533f1546b baa585f67e0e` on those headers in the ExyHyperBrick repo.
2. Grep your area for callers of each one.

Output: `analysis/api-audit/<area>.tsv` with columns `file:line, symbol, change`. Done when: every file in the area has been grepped.

### K6: defconfig fragment (one agent)
Make a config fragment of the 12 options in
[`analysis/exyhyperbrick-trial/README.md`](analysis/exyhyperbrick-trial/README.md), plus what they depend on.
Read each option's `depends on`/`select` in the **ExyHyperBrick** tree's Kconfig.
Output: `analysis/defconfig/gts4lv-23.2.fragment` and a short `README.md` listing the dependency of each option.
Done when: each option's dependencies are listed with the Kconfig file:line.

## R: ROM side research (no kernel clone; GitHub sources only)

| ID | Task | Output |
|---|---|---|
| R1 | VINTF: compare the HAL versions in the gts4lv-common `manifest.xml` (fork `lineage-22.2` + patches) with `hardware/interfaces/compatibility_matrices/compatibility_matrix.202504.xml` (or the FCM 6 / Android 16 matrix) on LineageOS `lineage-23.2`. List every HAL that is below the minimum or deprecated | `analysis/rom/vintf.md` |
| R2 | sepolicy: list types, attributes and macros used in gts4lv-common `sepolicy/` that were removed or renamed between `lineage-22.2` and `lineage-23.2` of `LineageOS/android_system_sepolicy` and `android_device_lineage_sepolicy` | `analysis/rom/sepolicy.md` |
| R3 | Soong config: list the `soong_config_set`/`SOONG_CONFIG_*` variables used by gts4lv-common, gts4lv and gts4lvwifi, and check each still exists in `hardware/samsung` and `hardware/qcom-caf` on `lineage-23.2` | `analysis/rom/soong.md` |
| R4 | Blobs: for each `.so` in TheMuppets `gts4lv-common` `lineage-22.2`, list `NEEDED` libraries (`readelf -d`) that aren't in a LineageOS 23.2 system or vendor image. Use the `proprietary-files.txt` and existing shims as the start | `analysis/rom/blob-deps.tsv` |
| R5 | Compare gts4lv-common with an sdm670/sdm845 device that has an official `lineage-23.x` branch (look one up on github.com/LineageOS). List the 23.x-specific commits that may need copying | `analysis/rom/reference-device.md` |

Done when: each file lists items with sources, or states "nothing found" and what was checked.

## T: test preparation (docs and scripts only)

| ID | Task | Output |
|---|---|---|
| T1 | Phase 6 checklist as an adb script: `uname -r`, BPF programs loaded (`ls /sys/fs/bpf`), `dumpsys netd`, `bpf_existence_test`/`kernel_config_test` from VTS where available, Wi-Fi and LTE data, tethering, 24 h soak log capture | `scripts/device-checks.sh` + `TESTING.md` |
| T2 | A "how to collect crash logs" page: `pstore`/`last_kmsg`, `adb logcat -b all`, ramoops settings in the gts4lv DTS, how to get to download mode. Mark any data-erasing step with ⚠️ | `TESTING.md` section |

---

## Not for helper agents
These need a strong agent or a human, using the K outputs above as input:
- Actually cherry-picking the series into the kernel fork, and resolving the conflicts (phases 1–2 in `ESTIMATE.md`).
- The 12 large required conflicts (K3 gives the facts only).
- Build fixes after the first link errors (phase 3).
- Full ROM build, first boot and debugging (phases 4–5). A full sync is ~150 GB, more than a cloud session's disk.
- Contacting krazey (ExyHyperBrick) before publishing the kernel branch.
- Track B (userspace version checks): an earlier session's safety classifier refused to write it. Don't assign it.

## Order and dependencies
- Can start now, all in parallel: M2, M3, K1, K2*, K3, K4*, K5, K6, R1–R5, T1, T2.
- K2 briefs get better once K1 is done. Agents can start before then and fill in heading 4 later.
- M1 needs S1 + S2.
- The cherry-pick work needs S2 + S3, and uses K1–K4.
