# LineageOS 24 (Android 17) port: tasks for helper agents

Written 2026-10-09 by the reviewing lead. Background and evidence: [FEASIBILITY-LINEAGE-24.md](../../FEASIBILITY-LINEAGE-24.md).
General agent rules: [AGENTS.md](../../AGENTS.md) and [AGENT-TASKS.md](../../AGENT-TASKS.md) §0 (they apply here too, with the
branch names below instead of the 23.2 ones).

**Marks used below**
- 🟢 **weak model OK**: mechanical, fully specified, with a self-check.
- 🔍 **strong-model review required** before anything is merged or acted on. The weak agent does the work and hands in;
  a strong model (RUNBOOK prompt R) reads and decides.
- 🔴 **strong model only**: judgement-heavy or new code where a mistake is expensive. A weak agent must not attempt it.
- 👤 **owner**: needs the tablet, flashing, a GitHub decision, or a ⚠️ data-erasing step.

## 0. Ground rules for these tasks

1. **Never start a task that isn't in your prompt.** Each task ID below is one agent's job.
2. Docs repo: commit only to `agent/<task-id>` (e.g. `agent/L1`). Never push to `main`.
3. Code repos (kernel, device, vendor forks of `anton-scholten`): push only to the branch your task names
   (`port/l24-dt-<n>` for the device tree, `port/l24-k-<n>` for the kernel). Always cut it from `lineage-24.0`
   (after task L5 created it). Never push to `lineage-23.2` or `lineage-24.0`. Never force-push, rebase or amend pushed commits.
4. One commit per fix, with a trailer `Fix-by: <model name>; <task-id>` and the source that justifies it in the message.
5. **Never** fix a build or boot error by disabling a check: no SELinux permissive, no `BUILD_BROKEN_*`, no
   `allow_undefined_symbols`, no `check_elf_files: false`, no deleting code. Write it under `## Escalated` instead.
6. Never flash, wipe or format anything. Prepare the exact command and the owner runs it. Mark data-erasing steps ⚠️.
7. Every fact needs a source: a 12+ character commit SHA, `file:line @ commit`, a log line number, or a URL. Every guess
   needs `confidence: low|medium|high`.
8. Builds: run in a clean shell (`env -i HOME=$HOME USER=$USER PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 bash --noprofile --norc`)
   with `USE_CCACHE` **unset**, and never change that between runs (it forces a full rebuild). Copy keeper outputs with `cp`,
   never hard links (the build rewrites outputs in place).
9. Stuck, or the same command failed twice: write what happened under `## Problems`, hand in, stop. Don't guess.

**Hand-in:** a report `analysis/l24/<task-id>.md` on `agent/<task-id>`, starting with
`# <task-id>: <title>`, `## Summary` (5 lines max), then the task's own sections, `## Problems`, `## Escalated`.

## 1. Task list

| ID | Task | Who | Needs | Output | Time |
|---|---|---|---|---|---|
| L0 | Decide start date and where the 24 source tree lives | 👤 | — | decision in HANDOVER | — |
| L1 | Reference-tree changes 23.2 → 24.0 (sm7125, exynos9610, others) | 🟢 + 🔍 | GitHub, `gh` | `L1.md` + `L1-changes.tsv` | ½ day |
| L2 | VINTF/FCM 7 audit of our builds | 🟢 + 🔍 | 23.2 `out/` dirs, `scripts/fcm-check.py` | `L2.md` | 1 h |
| L3 | Android 17 changes that hit legacy devices | 🟢 + 🔍 | GitHub, Gerrit search | `L3.md` | ½–1 day |
| L4 | Source tree setup commands | 🟢 (prepare) + 👤 (run) | L0 | `L4.md` (exact commands) | 1 day unattended |
| L5 | `lineage-24.0` branches on the forks + 24 manifests | 🟢 + 👤 (approve push) | L1 | branches, `local_manifests/24/` | 1 h |
| L6 | Device-tree port commits (FCM 7, libion, flags from L1/L3) | 🟢 + 🔍 | L1, L2, L3, L5 | `port/l24-dt-1` + `L6.md` | ½–1 day |
| L7 | First build and build-error loop | 🟢 + 🔍 (escalations: 🔴) | L4, L6 | fix commits + `L7.md` | 1–3 days |
| L8 | Install and boot-log triage, per attempt | 👤 + 🟢 (logs), 🔴 (diagnosis) | L7 | `boot-24-<n>.md` | 1–5 days |
| L9 | LTE radio HAL 1.4 vs FCM 7 | 🔴 | L2, L3 | decision + code if needed | 1–5 days |
| L10 | Testing and soak | 👤 + 🟢 | L8 boots | `L10.md` | 1–2 days |
| L11 | Release: notes, README, XDA post, GitHub release | 🟢 + 🔍 + 👤 (publish) | L10 | docs + draft release | ½ day |

Order: `L0 → (L1, L2, L3 in parallel) → L5 → L6 → L4 → L7 → L8 ⇄ fixes → L10 → L11`. L9 runs in parallel from L2/L3 on.

---

## 2. Task specs

### L1: reference-tree changes 23.2 → 24.0 (🟢, 🔍 review of the "applies to us" column)
**Goal:** a complete list of what LineageOS changed for 24.0 in device trees that are like ours, and whether each applies to gts4lv.

1. For each repo, list the commits on `lineage-24.0` that aren't on `lineage-23.2`:
   ```bash
   gh api "repos/LineageOS/<repo>/compare/lineage-23.2...lineage-24.0" --paginate --jq '.commits[] | [.sha[0:12], .commit.author.date[0:10], (.commit.message|split("\n")[0])] | @tsv'
   ```
   Repos: `android_device_samsung_sm7125-common` (closest match: Samsung + Qualcomm + legacy kernel),
   `android_device_motorola_exynos9610-common`, `android_device_samsung_exynos9820-common` (check whether a 24.0 branch exists first),
   `android_hardware_samsung`, `android_device_qcom_sepolicy_vndr` (`legacy-um` paths only).
2. Ignore commits dated before 2026-01-01 whose subject is a cleanup also present in 23.2 (compare subjects). Keep everything else.
3. Write `analysis/l24/L1-changes.tsv` with columns: `repo  sha  date  subject  category  applies_to_gts4lv  reason`.
   - `category`: one of `vintf`, `kernel-flag`, `sepolicy`, `build-flag`, `blob`, `hal`, `overlay`, `cleanup`, `other`.
   - `applies_to_gts4lv`: `yes`, `no` or `unsure`, with a one-line reason that cites our file (e.g. `gts4lv-common/manifest.xml:1 @ 1188e2b`).
4. In `L1.md`, list every `yes` and `unsure` with the exact diff (`gh api repos/LineageOS/<repo>/commits/<sha> --jq '.files[] | .filename, .patch'`).

Known starting points (verify, don't trust): sm7125 `6edc6f2518c5` FCM 6→7, `1d2a05927c04` `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false`,
`429c604442ac` legacy libion, kver override 5.4.299 → 5.10.239 (ours is 5.15.178: keep ours).
**Self-check:** every row has a source SHA; `wc -l` of the TSV equals the number of commits listed in step 1 minus the ignored ones (state both numbers).

### L2: VINTF/FCM 7 audit (🟢, 🔍)
1. Fetch the level-7 matrix from the target branch:
   ```bash
   curl -sLo /tmp/fcm7.xml https://raw.githubusercontent.com/LineageOS/android_hardware_interfaces/lineage-24.0/compatibility_matrices/compatibility_matrix.7.xml
   ```
2. Run the audit on the existing 23.2 outputs (Wi-Fi and LTE):
   ```bash
   scripts/fcm-check.py /tmp/fcm7.xml ~/android/lineage/out/target/product/gts4lvwifi ~/android/lineage/out/target/product/gts4lv
   ```
3. Expected today (2026-10-09): Wi-Fi `gnss@1.1`, `soundtrigger@2.2`; LTE also `radio@1.4`. For each finding, write in `L2.md`:
   the manifest file and line that declares it, the blob or service that provides it (`grep` in `vendor/samsung/gts4lv-common/proprietary`),
   and the candidate fix: **drop the entry**, **override it** (like sm7125's `<hal override="true">`), or **cannot fix → L9**.
4. Also list the device-manifest `<kernel target-level>` and `<sepolicy>` entries and the current `target-level="5"` line.

**Self-check:** the script's exit code and full output are pasted in `L2.md`.

### L3: Android 17 changes that hit legacy devices (🟢 collects, 🔍 interprets)
Collect facts only. The strong model decides what they mean.
1. In `LineageOS/android_packages_modules_Connectivity` (branch `lineage-24.0`), find the minimum kernel version and BPF features
   `netbpfload`/`bpfloader` require (search the source for `isAtLeastKernelVersion`, `kver`, `5, 10`, `5, 15`). Quote `file:line @ commit`.
   Our kernel reports 5.15.178 via `ro.bpf.kver_override`.
2. In `LineageOS/android_system_core` `lineage-24.0`: does `libprocessgroup/profiles/cgroups_28.json` still exist, and is `schedtune`
   still non-optional? (Our fix `a7f1483` ships `cgroups_30.json` on vendor.) Is `/metadata/aconfig` still required (`server_configurable_flags/aconfigd`)?
3. In `LineageOS/android_system_memory_lmkd` `lineage-24.0`: anything new that needs `process_mrelease` or a newer kernel feature?
4. `libion`: confirm `soong_config_set_bool,libion,legacy_impl,true` exists in 24.0 (`LineageOS/android_system_memory_libion` or wherever it lives) and what `device/lineage/sepolicy/libion` contains.
5. Search LineageOS Gerrit (`https://review.lineageos.org/q/branch:lineage-24.0+(4.9+OR+4.14+OR+legacy+OR+kver)`) and list relevant merged changes.
6. Bionic and ART: search `LineageOS/android_bionic` and `android_art` (`lineage-24.0`) for new syscalls used unconditionally since 23.2
   (`mseal`, `process_madvise`, `pidfd_*`, `clone3`, `MADV_*`, `landlock`). For each, check whether our kernel has it:
   `grep -n "<syscall>" ~/android/lineage/kernel/samsung/sdm670/include/uapi/asm-generic/unistd.h`.

**Self-check:** every item has a source or the text `not found` plus the exact search you ran.

### L4: source tree setup (🟢 prepares, 👤 runs)
Prepare, but don't run, the exact commands for a `lineage-24.0` tree in `L4.md`:
- Location decided in L0. ⚠️ The internal disk has ~19 GB free, so the new tree goes on the external drive or replaces the 23.2 tree.
  If it replaces it, first copy `out/keep/` and the 23.2 release files elsewhere.
- `repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs --no-clone-bundle`, copy `local_manifests/24/*.xml` (from L5), `repo sync -c -j4`.
- `git-lfs` installed before syncing. Expected size: ~150 GB of source plus ~300 GB of `out/`.

### L5: branches and manifests (🟢, 👤 approves the pushes)
1. Create `lineage-24.0` on each fork **from its `lineage-23.2`** (kernel `500658be3c16`, device `1188e2b` or later, vendor `51de1d4` or later):
   ```bash
   git push git@github.com:anton-scholten/<repo>.git <lineage-23.2 sha>:refs/heads/lineage-24.0
   ```
   Ask the owner before each push. Show the SHA.
2. Copy `local_manifests/*.xml` to `local_manifests/24/` and change every `revision="lineage-23.2"` to `lineage-24.0`.
   For repos without an official `lineage-24.0` branch (`LineageOS/android_device_samsung_gts4lv`, `gts4lvwifi`, TheMuppets'
   `gts4lv`), keep `lineage-22.2` and say so in a comment.

**Self-check:** `git ls-remote` shows each new branch at the intended SHA; `xmllint --noout local_manifests/24/*.xml` passes.

### L6: device-tree port commits (🟢, 🔍 every commit)
Branch `port/l24-dt-1` from the device fork's `lineage-24.0`. One commit per item, in this order:
1. `manifest.xml`: `target-level="5"` → `"7"`.
2. Each L2 finding marked "drop" or "override" (`gnss@1.1`: remove that `fqname` via an override manifest fragment in the device tree, never by editing the blob's XML;
   `soundtrigger@2.2`: remove the block and its `PRODUCT_PACKAGES` entry. Note in the message that the hardware hotword path is lost).
3. Legacy libion (exactly as sm7125 `429c604442ac`).
4. Every other `yes` from L1 and every concrete need from L3, citing the source commit.
5. `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false` **only** if L7's first build fails on kernel requirements. Then cite the error line.
Don't touch `ro.bpf.kver_override` (stays 5.15.178) or any of the 23.2 boot fixes.
**Self-check:** `git log --format='%h %s%n%b' lineage-24.0..port/l24-dt-1` shows one source per commit.

### L7: first build and build-error loop (🟢, 🔍; 🔴 for escalations)
Build `gts4lvwifi` first (clean shell, `breakfast gts4lvwifi && mka bacon -k 0 2>&1 | tee ~/work/l24-build-<n>.log`).
1. `grep -n "^FAILED:" <log>` lists every failure (`-k 0` continues past them). Handle them in order.
2. Allowed fixes on `port/l24-dt-<n>`: manifest/VINTF entries, missing `PRODUCT_PACKAGES`, renamed Soong modules, sepolicy syntax
   changes, blob fixups that only rename a dependency (`.replace_needed`), copying a pattern that a reference tree from L1 already uses.
3. **Escalate (🔴), don't fix:** any `check_elf_file` unresolved symbol in a blob (needs a shim like our `libshim_wfdservice`),
   any kernel compile error, any SELinux `neverallow` failure, any VINTF incompatibility you can't solve by dropping an entry L2 approved.
4. Per round, write the `FAILED:` lines, the fix commit SHA or the escalation, and the build time in `L7.md`.
**Done when:** `build completed successfully` without `-k 0`, plus the checks from the 23.2 flow: kernel `-g500658be3c16` inside `boot.img`
(decompress it; plain `strings` finds nothing), `/metadata` OMR line in `vendor/etc/fstab.qcom`, `cgroups.json` with optional schedtune.

### L8: install and boot-log triage (👤 flashes; 🟢 collects logs; 🔴 diagnoses)
The same procedure as 23.2's P7 ([AGENT-TASKS.md](../../AGENT-TASKS.md) §6c P7, [B2-HANDOFF.md](../port/B2-HANDOFF.md) §4, [TESTING.md](../../TESTING.md)).
- Use a **debug build** first (`WITH_ADB_INSECURE=true` in the build environment). Then adb works during a boot loop.
- ⚠️ Owner: a clean install (*Format data*) is required going from 23.2 to 24 unless both builds share signing keys.
- Download mode after a boot attempt: read `/proc/last_kmsg` from recovery (`grep -a`, the file has binary bytes). Boot-animation loop:
  `adb logcat -b crash -d` first. pstore Android log: `scripts/pmsg-decode.py`.
- Write `analysis/l24/boot-24-<n>.md` with excerpts only (no serial numbers or MACs), the first error of each kind with 20 lines of context,
  and a guess with confidence. Then hand over for diagnosis.

### L9: LTE radio 1.4 vs FCM 7 (🔴 strong model only)
`libsec-ril` implements `android.hardware.radio@1.4` at most (LEAD-SYNTHESIS §M3). Level 7 allows `1.2` (SAP) and `1.5–1.6`.
Decide between: (a) the build/runtime tolerates it (check `assemble_vintf` and `check_vintf` behaviour on 24.0 for deprecated HALs, and Telephony's HIDL radio support in 24.0);
(b) a 1.4→1.5 passthrough shim service; (c) LTE without telephony. Untestable without an LTE tablet: anything shipped is "untested".

### L10: testing (👤 + 🟢)
On the booted build: `scripts/device-checks.sh` (expect 5 PASS, 1 SKIP as on 23.2), the owner's feature list (Wi-Fi, hotspot, per-app data,
audio, mic, camera, GApps, casting), `adb logcat -b crash -d` after 24 h, a denial count and comparison with 23.2's (`grep -ac "avc:  denied"`).
Write `L10.md`.

### L11: release (🟢 drafts, 🔍 checks claims, 👤 publishes)
New release notes (`release/NOTES-<date>.md`, same layout as 20261008), README status and install changes, XDA post update, and a **draft** GitHub release:
per model the ROM zip, `recovery-<date>-<codename>.img`, `vbmeta-<date>-<codename>.img`, plus `SHA256SUMS`. Never publish.
Before release, scan the repo for personal data (home paths, host names, serials) as done on 2026-10-08.

---

## 3. Where a strong model is required (summary)

| Item | Why |
|---|---|
| L1/L3 interpretation ("applies to us", what a platform change means) | Judgement, not lookup. Round 1 got several such calls wrong (LEAD-SYNTHESIS §7.3) |
| Review of every L6 and L7 commit | Device-tree changes ship to users |
| Blob ABI breaks (new shims) | New C++ against unstable platform internals, like `libshim_wfdservice` |
| Kernel errors or new kernel features (`port/l24-k-<n>`) | Touches the backported BPF/mm code, so mistakes are subtle (cf. the silent vDSO trap in HANDOVER) |
| SELinux `neverallow` failures and policy design | Easy to "fix" by weakening policy |
| Boot-log diagnosis (L8) | 23.2's four boot blockers each needed source-level reasoning (cgroup loader, lmkd init, aconfig storage, fc_sort order) |
| L9 LTE radio | Design decision plus possible new HAL code, untestable here |
| Anything that would disable a check | Always escalate |
