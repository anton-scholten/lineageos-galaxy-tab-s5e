# Work for helper agents

These tasks are for **helper agents that are less capable than the lead agent**, working in parallel.
Every task gives you:
- the exact commands to run,
- a template for the output file,
- a self-check to run before you hand in,
- a list of times when you should **stop and ask** instead of guessing.

A lead agent or the owner reviews and merges your output. You never change the kernel or device tree
directly: you **research and write reports**. State checked on 2026-10-03; see [HANDOVER.md](HANDOVER.md).

---

## 0. Read this first

### 0.1 What the project is
We want LineageOS 23.2 (Android 16) on the Samsung Galaxy Tab S5e. Code names: `gts4lvwifi` (SM-T720) and
`gts4lv` (SM-T725/T727). The chip is a Qualcomm SDM670.
LineageOS stopped supporting it at 22.2, because Android 16 needs eBPF features from Linux 5.4+,
and the tablet's kernel is Linux 4.9.

The plan is to copy a big eBPF backport (about 2,600 commits) from another 4.9 kernel: the Galaxy S9 kernel by
ExyHyperBrick (author: Mathias Gluszczynski, "krazey"). 2,335 commits apply cleanly. **150 conflict.**
Most tasks here help someone resolve those 150 conflicts faster and more safely.

### 0.2 Words used here
| Word | Meaning |
|---|---|
| **sdm670 tree** | The Tab S5e kernel: `LineageOS/android_kernel_samsung_sdm670`, branch `lineage-22.2`, commit `a30605a54f3b` |
| **series** | The ExyHyperBrick commits `exy/l222..exy/l232`, i.e. from `d54533f1546b` to `baa585f67e0e` |
| **conflict** | A series commit that `git` can't apply to the sdm670 tree automatically |
| **upstream** | Mainline Linux (torvalds/linux) or the Android common kernel. Many series commits are copies of upstream commits |
| **brief** | The report you write for one conflict commit |
| **lead** | The stronger agent or the owner who reads your output |

### 0.3 Rules
1. **One task ID per agent.** Your task ID is something like `K2a-3` or `R6`. Write only to the output path that task names.
2. **Branch:** commit on a new branch `agent/<task-id>` in *this* repo (`anton-scholten/lineageos-galaxy-tab-s5e`) and push it.
   Don't push to `main`. Don't open a pull request unless you're told to.
3. **Never push to these repos:** `android_kernel_samsung_sdm670`, `android_device_samsung_gts4lv-common`, or anything from LineageOS, ExyHyperBrick or TheMuppets.
   You clone them read-only.
4. **Don't edit** `WORKLOG.md`, `HANDOVER.md`, `README.md` or any file outside your output path. Many agents run at once,
   and edits to shared files cause merge conflicts. The lead updates the shared files.
5. **Every fact needs a source:** a commit SHA (at least 12 characters), or `path/to/file:line @ <commit>`, or a URL.
6. **Say how sure you are.** Each finding ends with `confidence: high | medium | low` and one line of reason.
   "I don't know, because X" is a good answer. A wrong answer said confidently is the worst answer.
7. **Licence:** kernel code is GPL-2.0, and this repo is Apache-2.0. Don't paste more than **20 lines** of kernel code. Cite SHA + path + line numbers instead.
8. **Don't** write code that disables or weakens Android's kernel version checks (that's "Track B"). Not in scope.
9. If a command fails twice, **stop**. Put the exact command and error in your output under `## Problems`, then hand in what you have.

### 0.4 How to hand in
```bash
cd /path/to/lineageos-galaxy-tab-s5e
git checkout -b agent/<task-id>
git add <your output files only>
git status            # check: only your files are listed
git commit -m "<task-id>: <one-line summary>"
git push -u origin agent/<task-id>
```
Every output file starts with this header:
```markdown
<!-- task: <task-id> | agent: <your name/model> | date: YYYY-MM-DD -->
# <task-id>: <title>
## Summary
<3–6 lines: what you did, what you found, how many items, anything the lead must look at first>
```
and ends with `## Problems` (write "None" if there were none).

---

## 1. Environment setup

### 1.1 This repo
```bash
git clone https://github.com/anton-scholten/lineageos-galaxy-tab-s5e
cd lineageos-galaxy-tab-s5e
```

### 1.2 Kernel trees (only for the K tasks)
The sdm670 clone is ≈2.3 GB and takes 10–30 minutes. **Start it in the background and don't kill it**, even when
it looks stuck at "Resolving deltas". Only one clone at a time.
```bash
W=$HOME/work; mkdir -p $W && cd $W
git clone --single-branch -b lineage-22.2 https://github.com/LineageOS/android_kernel_samsung_sdm670 k670
cd k670
git remote add exy https://github.com/ExyHyperBrick/android_kernel_samsung_exynos9810
git fetch --no-tags exy lineage-22.2:refs/remotes/exy/l222 lineage-23.2:refs/remotes/exy/l232
```
Check it worked. **All three lines must print a SHA:**
```bash
git rev-parse --verify a30605a54f3b      # sdm670 tip
git rev-parse --verify d54533f1546b      # series base
git rev-parse --verify baa585f67e0e      # series head (we use THIS one, even if exy/l232 has moved)
git rev-list --count --no-merges d54533f1546b..baa585f67e0e   # should print 2599
```
If `exy/l232` no longer contains `baa585f67e0e`, fetch it directly: `git fetch exy baa585f67e0e`. If that fails, stop and report it.

**Disk:** you need ≈6 GB free. If you get "No space left on device", delete build output and other clones you don't need.

### 1.3 Useful commands
| You want | Command |
|---|---|
| Message and files of a commit | `git show --stat <sha>` |
| Full diff of a commit | `git show <sha>` |
| Does sdm670 have a commit with this subject? | `git log --oneline a30605a54f3b --grep='<exact subject>' -F` |
| Does sdm670 have a given line of code? | `git grep -n '<text>' a30605a54f3b -- <path>` |
| Who added a symbol in the series | `git log --oneline -S'<symbol>' d54533f1546b..baa585f67e0e` |
| Where a symbol is defined in the series head | `git grep -n '<symbol>' baa585f67e0e -- include/` |
| Try to apply one commit onto sdm670, without changing anything | `git merge-tree --write-tree --merge-base=<sha>^ a30605a54f3b <sha>` |

The `merge-tree` command prints a tree ID, then, if it conflicts, a list of conflicting files and messages.
To see the conflict markers in one file: `git cat-file -p <tree-id>:<path> | grep -n -A30 '^<<<<<<<'`.

---

## 2. Owner tasks (S, F): on github.com, not for helper agents

| ID | Task | Done when |
|---|---|---|
| S1 | Device fork: `git checkout -b lineage-23.2 origin/lineage-22.2 && git am <this repo>/patches/device/samsung/gts4lv-common/*.patch`, push | Branch `lineage-23.2` = `d1b339b` + 4 commits. They were checked to apply cleanly on 2026-10-03 |
| S2 | Kernel fork: push a `lineage-23.2` branch at `a30605a54f3b` (no changes yet) | Branch exists |
| S3 | Attach the kernel fork with push access. The device fork is already attached to the 2026-10-03 session. See [REPO-SETUP.md](REPO-SETUP.md#attaching-repos-to-a-claude-cloud-session) | `git push` works from the session |
| F1 | Fork `ExyHyperBrick/android_kernel_samsung_exynos9810` and `ExyHyperBrick/android_device_samsung_exynos9810-common` as backups | Forks exist |

---

## 3. Housekeeping tasks (M): no kernel clone needed

### M1: point the manifests at the forks
*Wait for S1 + S2.*
1. Edit `local_manifests/gts4lv-common.xml`. Add `<remote name="anton" fetch="https://github.com/anton-scholten" />`.
2. For `device/samsung/gts4lv-common`, set `name="android_device_samsung_gts4lv-common" remote="anton" revision="lineage-23.2"`.
   Do the same for `kernel/samsung/sdm670` with `android_kernel_samsung_sdm670`.
3. Update the comment at the top of the file to match.

**Self-check:** `xmllint --noout local_manifests/*.xml` prints nothing, and for each changed project
`git ls-remote https://github.com/anton-scholten/<name> refs/heads/lineage-23.2` prints a SHA.

### M2: link check
For every `*.md` file in this repo, check every link.
- Relative links (`[x](PATH.md)`, `[x](analysis/...)`): the file must exist. Also check `#anchors` against the headings.
- GitHub links: `curl -s -o /dev/null -w '%{http_code}' <url>` must print `200` (or `301`).
- Skip xdaforums.com, lineageos.org and gerrit links (blocked in the cloud). List them as "not checked".

Output `analysis/link-check.md`: a table `file:line | link | result`. Only broken and not-checked links.

### M3: pin checker script
Write `scripts/check-pins.sh` (bash + git only). For each of these, run `git ls-remote <url> refs/heads/<branch>`, compare with the expected SHA prefix, and print `OK` or `MOVED <new sha>`:

| URL | Branch | Expected |
|---|---|---|
| https://github.com/LineageOS/android_kernel_samsung_sdm670 | lineage-22.2 | a30605a54f3b |
| https://github.com/LineageOS/android_device_samsung_gts4lv-common | lineage-22.2 | d1b339be7abe |
| https://github.com/ExyHyperBrick/android_kernel_samsung_exynos9810 | lineage-22.2 | d54533f1546b |
| https://github.com/ExyHyperBrick/android_kernel_samsung_exynos9810 | lineage-23.2 | baa585f67e0e |

Exit code 1 if anything moved. **Self-check:** `bash -n scripts/check-pins.sh` passes, and running it prints 4 lines.

---

## 4. Kernel research tasks (K): need the setup in §1.2

### K1: upstream-origin map (1 agent, the most useful task, do first)
**Goal:** for each of the 2,599 series commits, find the upstream Linux commit it copies, and whether sdm670 already has it.

**Steps**
1. List the series: `git log --reverse --no-merges --format='%H' d54533f1546b..baa585f67e0e > series.txt` (2,599 lines).
2. For each commit, read the message (`git log -1 --format=%B <sha>`) and look for an upstream SHA with these patterns (case-insensitive):
   - `commit <sha> upstream`
   - `[ Upstream commit <sha> ]`
   - `(cherry picked from commit <sha>)`
   - `Upstream commit <sha>`
   - `Change-Id:` doesn't count. It's a Gerrit ID, not a SHA.
   Take the **first** 12–40 character hex match. If none, `upstream_sha` = `-`.
3. Build an index of sdm670 once: `git log --format='%H%x09%s%x09%b' a30605a54f3b > sdm670.log` (big file, that's fine). Then for each commit:
   - `sdm670_has=yes` if the upstream SHA appears in sdm670.log, **or** the exact subject (with `BACKPORT: `, `UPSTREAM: `, `FROMLIST: `, `ANDROID: ` prefixes removed) appears as a subject in sdm670.log.
   - Otherwise `no`. If there was no upstream SHA and no subject match: `unknown`.
   - `sdm670_commit` = the matching sdm670 SHA (12 characters), or `-`.
4. Write this as a Python 3 script `analysis/upstream-map/make_map.py` that takes the kernel path as its first argument. Use `subprocess` with `git`. Don't use any library outside the standard library.

**Output:** `analysis/upstream-map/make_map.py`, `analysis/upstream-map/upstream-map.tsv`
(columns `exy_commit	subject	upstream_sha	sdm670_has	sdm670_commit`, 12-character SHAs) and `analysis/upstream-map/README.md` (header, summary with counts of yes/no/unknown).

**Self-check:** the TSV has 2,600 lines (header + 2,599). Running the script twice gives an identical file (`sha256sum`).
Spot-check: commit `3ed2e2f029db` ("BACKPORT: bpf: Add BPF_MAP_TYPE_LRU_HASH") is expected to be `yes`, because sdm670 already
carries LRU_HASH (`git grep -n BPF_MAP_TYPE_LRU_HASH a30605a54f3b -- include/uapi/linux/bpf.h`). If it comes out `no`, look at why
(different subject? no upstream trailer?) and describe the reason in your README. Don't force it to `yes`.

### K2: conflict briefs (13 agents)
**Goal:** for each conflict commit in your batch, write one brief that tells the lead what the conflict is and how to fix it.

**Your batch** is a file in [`analysis/agent-batches/`](analysis/agent-batches/). Columns: `commit, subject, size_class, conflicting_files`.

| Batch files | What | Commits per file |
|---|---|---|
| `K2a-1` … `K2a-4` | required, trivial | ≈10 |
| `K2b-1` … `K2b-4` | required, moderate | ≈9 |
| `K2c-1`, `K2c-2` | optional, trivial | 9 |
| `K2d-1` … `K2d-3` | optional, moderate or modify/delete | ≈8 |

"Required" means needed for eBPF or boot. "Optional" means nice to have (power, memory).
The full classification is in [`conflict_detail.tsv`](analysis/exyhyperbrick-trial/conflict_detail.tsv).

**Steps, for each commit `C` in your batch file**
1. `git show --stat C`: note the author, the date and the files.
2. Find the upstream SHA (from K1's TSV if it exists, or read the message as in K1 step 2).
3. Run `git merge-tree --write-tree --merge-base=C^ a30605a54f3b C`.
   - If it prints **only a tree ID** (no conflict), write that down. The trial applied the commits stacked on top of each other, so this commit probably only conflicts because of an earlier one. Name the earlier commit: `git log --oneline d54533f1546b..C^ -- <conflicting file>` shows the candidates.
   - If it conflicts, look at each conflict block in each file (see §1.3). For each block, write 1–2 lines: what "ours" (sdm670) has, and what "theirs" (series) has.
4. Check whether sdm670 already has the change: look for the key lines of `git show C` in sdm670 with `git grep -n '<distinctive line>' a30605a54f3b -- <file>`.
   Pick a line that the commit *adds*, is unusual (not just `}` or `return 0;`), and is short.
5. Choose **one** proposed resolution:
   - `DROP`: sdm670 already has the same change. Give the sdm670 SHA or file:line.
   - `MERGE`: combine both sides. Say per block what to keep from each side.
   - `PREREQ`: needs another commit first. Name it (SHA + subject).
   - `HUMAN`: you can't tell. Say what you'd need to know.
6. Set the confidence. Use `high` only if you checked step 4 and the case is simple.

**Output:** one file per commit, `analysis/conflicts/<first 12 chars of C>.md`, plus `analysis/conflicts/<batch>-summary.md`
(header, then a table `commit | subject | resolution | confidence`).

**Brief template** (copy it exactly):
```markdown
<!-- task: K2a-1 | agent: <name> | date: YYYY-MM-DD -->
# 3ed2e2f029db: BACKPORT: bpf: Add BPF_MAP_TYPE_LRU_HASH
- Author / date: <name>, YYYY-MM-DD
- Upstream: <sha or "-">
- Batch: K2a-1, size_class: trivial
## Conflicting files
- kernel/bpf/hashtab.c
## Why it conflicts
merge-tree on its own: <conflicts | applies cleanly (conflict comes from earlier commit <sha>)>
- Block 1, kernel/bpf/hashtab.c ~line <n>: ours = <…>; theirs = <…>
## Already in sdm670?
<yes | partly | no>. Evidence: <sha or file:line @ a30605a54f3b>
## Proposed resolution
<DROP | MERGE | PREREQ | HUMAN>: <details>
## Confidence
<high | medium | low>: <reason>
## Problems
None
```

**Self-check:** the number of `.md` files you made = the number of rows in your batch file (minus the header), plus 1 summary.
Every brief has all eight sections. `grep -L 'Confidence' analysis/conflicts/*.md` lists none of your files.

**Stop and ask** if: `git show C` fails (wrong SHA), or more than half of your commits come out `HUMAN`. Then hand in early with a note.

### K3: large conflicts, facts only (4 agents, batch files `K3-1` … `K3-4`, 3 commits each)
Same as K2 steps 1–4, **but don't propose a resolution.** Large conflicts need a human. Add one more section:
```markdown
## Later series commits touching the same files
<output of: git log --oneline C..baa585f67e0e -- <each conflicting file> | head -30>
```
Use the K2 template, with `## Proposed resolution` replaced by `## Notes for the lead` (what you noticed, ≤10 lines).

### K4: first build errors (4 agents, one per error)
A test build of the merged tree stopped at these errors ([`port-first-errors.txt`](analysis/build-test/port-first-errors.txt)):

| ID | Symbol | Where it failed |
|---|---|---|
| K4a | `randomized_struct_fields_end` | `include/linux/sched.h:2284` |
| K4b | `ANDROID_VERSION` | `include/uapi/asm-generic/socket.h:112` |
| K4c | `TIF_FSCHECK` | `arch/arm64/include/asm/uaccess.h:89` |
| K4d | offsetof error | `arch/arm64/kernel/asm-offsets.c:49` |

**Steps**
1. Where is it defined in the series head? `git grep -n '<symbol>' baa585f67e0e`. Find the line that *defines* it
   (`#define`, `struct`, Kconfig, Makefile `-D`), not just uses.
2. Which commit added that definition? `git log --format='%h %ad %s' --date=short -S'<symbol>' baa585f67e0e -- <file>`. Take the oldest.
3. Is that commit:
   - in the series (`git merge-base --is-ancestor d54533f1546b <sha>` succeeds, so it's after the base), and was it skipped? Check `analysis/exyhyperbrick-trial/results.tsv` for its status (`SKIPDEV`, `SKIPDEV2`, `CONFLICT`, `CLEAN`);
   - or **before** the series base (`git merge-base --is-ancestor <sha> d54533f1546b` succeeds)? Then it's a missing prerequisite: the Exynos tree had it, sdm670 doesn't.
4. Does sdm670 have it? `git grep -n '<symbol>' a30605a54f3b`.
5. K4b only: `ANDROID_VERSION` is usually passed by the build system. Look in the Exynos `Makefile` and `arch/arm64/Makefile` for `ANDROID_VERSION`, and say how the Exynos build sets it.
6. K4d only: open `arch/arm64/kernel/asm-offsets.c` line 49 at `baa585f67e0e`. Say which struct or field it needs, and whether that follows from K4a or K4c.

**Output:** `analysis/build-test/errors/<ID>.md` with sections: Summary, Defined at, Added by, Status (in series/skipped/prerequisite), Present in sdm670, Suggested fix, Confidence, Problems.

### K5: driver API audit (6 agents, one per area)
Areas:
- K5a `drivers/net/ethernet/qualcomm/rmnet`
- K5b `drivers/platform/msm/ipa`
- K5c `drivers/staging/qcacld-3.0`, `drivers/staging/qca-wifi-host-cmn`
- K5d `net/qrtr`, and `drivers/soc/qcom` files matching `*dfc*` or `*qmi*`
- K5e `techpack/`
- K5f `drivers/net/wireless` (Samsung parts), `security/samsung`, any `sec_net` path

If an area doesn't exist in sdm670 (`git ls-tree -d a30605a54f3b <path>` prints nothing), say so and stop.

**Steps**
1. **Only K5a does this step**, and pushes it first so the others can use it. Make `analysis/api-audit/changed-api.txt`:
   run `git diff d54533f1546b baa585f67e0e -- include/linux/skbuff.h include/linux/netdevice.h include/linux/bpf.h include/linux/filter.h include/linux/net.h include/net/sock.h include/net/tcp.h`,
   and list each function prototype or struct field that was **changed or removed** (not just added), one per line:
   `symbol | header | old form | new form`.
   The others: wait until `git fetch origin agent/K5a` shows the file, or work from the same diff yourself.
2. For each symbol: `git grep -n -w '<symbol>' a30605a54f3b -- <your area>`.
3. Record each hit.

**Output:** `analysis/api-audit/<ID>.tsv` (`file:line	symbol	change`) and `analysis/api-audit/<ID>.md` (header, summary: hit count, the 5 most-hit symbols).

### K6: defconfig fragment (1 agent)
Options to add (from [the trial README](analysis/exyhyperbrick-trial/README.md)):
`ANDROID_BINDERFS BPF_LSM CFQ_GROUP_IOSCHED DEBUG_INFO_BTF FUSE_BPF KPROBES NET_ACT_BPF PSI UCLAMP_TASK UCLAMP_TASK_GROUP UNICODE USERFAULTFD`.

**Steps, for each option `X`**
1. Find its Kconfig entry in the series head: `git grep -n "^config X$" baa585f67e0e -- '*Kconfig*'`.
2. Show it: `git show baa585f67e0e:<path> | sed -n '<line>,+25p'`. Copy the `depends on` and `select` lines.
3. For each dependency `Y`, check whether sdm670's defconfigs already enable it:
   `git show a30605a54f3b:arch/arm64/configs/gts4lvwifi_defconfig | grep -w "CONFIG_Y"`
   (the defconfig might be in `arch/arm64/configs/vendor/`. Find it with `git ls-tree -r --name-only a30605a54f3b arch/arm64/configs | grep gts4lv`).
4. Does the Kconfig entry exist in sdm670 at all? (`git grep -n "^config X$" a30605a54f3b`). If not, it comes with the series.

**Output:** `analysis/defconfig/gts4lv-23.2.fragment` (lines `CONFIG_X=y`, dependencies included) and
`analysis/defconfig/README.md` (table `option | Kconfig file:line | depends on | already in sdm670 defconfig?`).

---

## 5. ROM-side research tasks (R): GitHub only, no kernel clone

Get these trees with shallow clones, e.g.
`git clone --depth 1 -b lineage-23.2 https://github.com/LineageOS/android_hardware_interfaces`.
If a branch doesn't exist, list the branches with `git ls-remote --heads <url> | grep lineage-2` and report it. Don't guess.

| ID | Task | Output |
|---|---|---|
| R1 | **VINTF.** Our HALs are listed in `manifest.xml` in the device fork (`lineage-22.2` + patches, or branch `lineage-23.2` once S1 is done). Compare each `<hal>` name and version with the compatibility matrix for the target FCM level in `LineageOS/android_hardware_interfaces` `lineage-23.2` `compatibility_matrices/` (find the file whose `level=` is the newest. Write down which one you used). List each HAL that is missing, below the minimum version, or listed as deprecated | `analysis/rom/vintf.md` |
| R2 | **sepolicy.** List every type, attribute and macro used in the device fork's `sepolicy/` folder. Check each exists in `LineageOS/android_system_sepolicy` `lineage-23.2` (`git grep -w`). Report the missing ones, and the 22.2 commit that removed them if you can find it | `analysis/rom/sepolicy.md` |
| R3 | **Soong config.** List each `soong_config_set` / `SOONG_CONFIG_` variable in the device fork and the `gts4lv` and `gts4lvwifi` repos. Check each is still read by `LineageOS/android_hardware_samsung` or `android_hardware_qcom-caf_*` `lineage-23.2` (`git grep`) | `analysis/rom/soong.md` |
| R4 | **Blob deps.** From `TheMuppets/proprietary_vendor_samsung_gts4lv-common` `lineage-22.2` (big, so use `--depth 1`; if files are Git LFS pointers, say so and stop), run `readelf -d` on each `.so` and list `NEEDED` libraries that aren't shipped in the vendor repo itself. The lead checks those against 23.2 | `analysis/rom/blob-deps.tsv` |
| R6 | **Port list from sm7125-common.** [`analysis/reference-trees/sm7125-common-22.2-to-23.2.tsv`](analysis/reference-trees/sm7125-common-22.2-to-23.2.tsv) lists the 26 commits LineageOS made to an official Samsung Qualcomm tree between 22.2 and 23.2. Four are done (see [the README](analysis/reference-trees/README.md)). For each of the other 22: read it (`git show <sha>` in a clone of `LineageOS/android_device_samsung_sm7125-common`), find the matching file or setting in our device fork, and say: `NEEDED` / `NOT NEEDED` / `ALREADY DONE` / `UNSURE`, with the reason and the file it would change in our tree | `analysis/rom/port-from-sm7125.md` |
| R7 | **4.9-specific changes in exynos9810-common.** [`exynos9810-common-22.2-to-23.2.tsv`](analysis/reference-trees/exynos9810-common-22.2-to-23.2.tsv) has 143 commits from ExyHyperBrick's Galaxy S9 tree. Sort each into: `KERNEL-4.9` (works around the old kernel: BPF, uffd, LMK, freezer, power supply filters), `GENERIC-23.2` (a change every device needs for 23.2), `EXYNOS-ONLY` (audio, camera, RIL, Exynos hardware), `TUNING` (performance and memory tweaks). For `KERNEL-4.9` and `GENERIC-23.2`, say whether our device fork needs the same change | `analysis/rom/port-from-exynos9810.md` |

**Self-check for R tasks:** every listed item has a source (SHA or URL + path) and a verdict. The summary gives counts per verdict.

---

## 6. Test preparation (T): docs and scripts only

### T1: device check script
Write `scripts/device-checks.sh`. It runs over `adb` against a booted tablet, prints `PASS`/`FAIL`/`SKIP` per check, and saves all output to `device-checks-<date>.log`.
Checks:
1. `adb shell uname -r` → print it. `adb shell getprop ro.bpf.kver_override` → should be `5.15.178`.
2. `adb shell su -c 'ls /sys/fs/bpf'` → non-empty. (Needs root. Print SKIP if `su` is missing.)
3. `adb shell dumpsys netd | head -50` → no "error".
4. `adb shell logcat -d -b all | grep -iE 'bpfloader|netbpfload'` → no `FATAL` or `abort`.
5. Wi-Fi: `adb shell ping -c 3 8.8.8.8` → 0% loss.
6. Uptime soak: `adb shell uptime`, plus a note to rerun after 24 h.

**Self-check:** `bash -n` passes, and `shellcheck` passes if you have it. With no device connected, the script prints one clear error and exits 1.
**Don't** include any command that flashes, wipes, formats or reboots to bootloader.

### T2: crash-log guide
Write `TESTING.md`, section "Collecting crash logs":
- `adb logcat -b all -d > logcat.txt`
- `adb shell su -c 'cat /sys/fs/pstore/console-ramoops*'` after a crash reboot (what pstore is, in one line).
- `adb shell dmesg`
- How to get into recovery and download mode on the Tab S5e (button combinations; give a source URL).
- Any step that can erase data (flashing, `fastboot -w`, factory reset, formatting `/data`) **must** start with ⚠️ and a one-line warning.

---

## 7. Not for helper agents
These need the lead or a human. They use the outputs above as input:
- Cherry-picking the series into the kernel fork, and resolving the conflicts (phases 1–2 in [ESTIMATE.md](ESTIMATE.md)).
- The 12 large required conflicts (K3 gives facts only).
- Build fixes after the first errors (phase 3).
- A full ROM build (~150 GB sync), first boot and debugging (phases 4–5).
- Contacting krazey (ExyHyperBrick) before publishing the kernel branch.
- Track B (relaxing Android's kernel version checks).

## 8. Order and dependencies
```
Now, all in parallel:   M2  M3  K1  K2*  K3*  K4*  K5a→K5b..f  K6  R1–R4  R6  R7  T1  T2
After S1+S2:            M1
After K1:               lead re-checks K2 "Already in sdm670?" answers against upstream-map.tsv
After K1–K4 + S2 + S3:  lead starts the cherry-pick (section 7)
```

## 9. Common mistakes
- **Taking one side of a conflict whole.** A test build doing that failed in seconds ([build-test](analysis/build-test/README.md)). Always look at both sides.
- **Using `exy/l232` instead of `baa585f67e0e`.** The branch keeps moving. All numbers here are for `baa585f67e0e`.
- **Short SHAs that are ambiguous.** Use at least 12 characters.
- **Copying big code blocks.** Cite them instead (rule 7).
- **Saying "probably fine" without evidence.** Give a source or say `confidence: low`.
- **Killing a slow clone.** Wait. Big clones look stuck while they unpack.
- **Editing shared files** (`WORKLOG.md`, `HANDOVER.md`). Don't; the lead does.
