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
| **sdm670 tree** | The Tab S5e kernel at commit `a30605a54f3b`: our fork `anton-scholten/android_kernel_samsung_sdm670` branch `lineage-23.2` (= LineageOS `lineage-22.2`) |
| **series** | The ExyHyperBrick commits `exy/l222..exy/l232`, i.e. from `d54533f1546b` to `baa585f67e0e` |
| **conflict** | A series commit that `git` can't apply to the sdm670 tree automatically |
| **upstream** | Mainline Linux (torvalds/linux) or the Android common kernel. Many series commits are copies of upstream commits |
| **brief** | The report you write for one conflict commit |
| **lead** | The stronger agent or the owner who reads your output |
| **device tree** | The Android build config for the tablet: our fork `anton-scholten/android_device_samsung_gts4lv-common`, branch `lineage-23.2` |
| **FCM / VINTF** | Android's rules for which hardware interface (HAL) versions a device must provide. Used in R1 |
| **sepolicy** | SELinux rules in the device tree. Used in R2 |

### 0.3 Which repos you work in
| Repo | You do | Access |
|---|---|---|
| `anton-scholten/lineageos-galaxy-tab-s5e` (**this repo**, private) | Write your report here, on branch `agent/<task-id>` | Read + push. The owner gives you a token or collaborator access (§0.6) |
| `anton-scholten/android_kernel_samsung_sdm670` (public) | Read only. **Our kernel.** Branch `lineage-23.2` = `a30605a54f3b` (same as LineageOS `lineage-22.2`) | Anonymous `git clone` |
| `anton-scholten/android_device_samsung_gts4lv-common` (public) | Read only. **Our device tree.** Branch `lineage-23.2` = LineageOS `d1b339b` + patches 0001–0004 | Anonymous `git clone` |
| `anton-scholten/android_kernel_samsung_exynos9810` (public) | Read only. Frozen backup of the ExyHyperBrick S9 kernel = **the eBPF series**. Use this, not the ExyHyperBrick original | Anonymous `git clone` |
| `anton-scholten/android_device_samsung_exynos9810-common` (public) | Read only. Frozen backup of the ExyHyperBrick S9 device tree (task R6) | Anonymous `git clone` |
| `LineageOS/*`, `TheMuppets/*` (public) | Read only. Reference trees (R tasks) | Anonymous `git clone` |

All your output goes into **this repo**. Nothing you do changes the kernel or the device tree.

Which task needs which repo:

| Tasks | Repos to clone |
|---|---|
| M2, M3, T1, T2 | This repo only |
| K1–K6 | Our kernel + the exynos9810 kernel backup, set up as in §1.2 |
| R1, R2, R3 | Our device tree (`lineage-23.2`) + the LineageOS repos named in the task |
| R4 | `TheMuppets/proprietary_vendor_samsung_gts4lv-common` |
| R5 | Our device tree + `LineageOS/android_device_samsung_sm7125-common` |
| R6 | Our device tree + the exynos9810-common backup |

### 0.4 Rules
1. **One task ID per agent.** Your task ID is something like `K2a-3` or `R6`. The owner gives it to you; if you have none, ask. Write only to the output path that task names.
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

### 0.5 How to hand in
```bash
cd /path/to/lineageos-galaxy-tab-s5e
git branch --show-current   # must print agent/<task-id> (you created it in §1.1)
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

### 0.6 Access for agents that aren't Claude (owner sets this up once)
This repo is private, so an outside agent needs credentials to clone it and push its branch. Pick one:
- **Fine-grained token (recommended):** GitHub → Settings → Developer settings → Fine-grained tokens → Generate.
  Repository access: *Only select repositories* → `lineageos-galaxy-tab-s5e`. Permissions: **Contents: Read and write**. Nothing else. Expiry: 30 days.
  The agent clones with `git clone https://<token>@github.com/anton-scholten/lineageos-galaxy-tab-s5e`.
  Revoke it when the work is done.
- **Collaborator:** if the agent runs under its own GitHub account, add it under repo Settings → Collaborators, with Write access.
- **No push at all:** the agent runs `git format-patch -1` after committing, and sends the `.patch` file. The lead applies it with `git am`.

Optional safety: add a branch protection rule on `main` (Settings → Branches), so only the owner can push to it.

---

## 1. Environment setup

### 1.0 Prerequisites
Nothing needs building or flashing. You need a shell, git, network access to github.com, and the tools for your task.

**Machine:** Linux, macOS or Windows with WSL2. Plain Windows (cmd/PowerShell) isn't supported: the commands are bash.

**Tools every task needs:**

| Tool | Minimum | Check | Install (Debian/Ubuntu · macOS) |
|---|---|---|---|
| git | **2.40** (for `git merge-tree --write-tree --merge-base`) | `git --version` | `apt install git` (Ubuntu 24.04+ has 2.43) · `brew install git` |
| bash | 4+ | `bash --version` | built in · `brew install bash` (macOS ships 3.2) |
| Python | 3.8+, standard library only | `python3 --version` | `apt install python3` · `brew install python` |
| Usual Unix tools | grep, sed, awk, cut, sort, wc | | built in |

**Extra tools per task:**

| Task | Extra tools | Install (Debian/Ubuntu · macOS) |
|---|---|---|
| M2 | `curl` | `apt install curl` · built in |
| M3, T1 | `shellcheck` (optional, for the self-check) | `apt install shellcheck` · `brew install shellcheck` |
| R1 | `xmllint` (optional, makes XML easier to read) | `apt install libxml2-utils` · built in |
| R4 | `readelf` | `apt install binutils` · `brew install binutils` (then use `greadelf` if `readelf` isn't found) |
| T1 | Nothing. You write the script; you don't need a tablet or `adb` to write it | |
| All others | Nothing extra | |

No compilers, Android SDK, `repo` tool, Docker or Python packages are needed for any helper task.

**Disk and time:**

| Task | Disk | First-time setup |
|---|---|---|
| K1–K6 | ≈6 GB (kernel + series) | 10–30 min to clone (§1.2) |
| R1–R3, R5, R6 | < 1 GB (shallow clones) | a few minutes |
| R4 | up to a few GB (vendor blobs) | 5–20 min |
| M2, M3, T1, T2 | < 50 MB | seconds |

**Credentials:** only to clone and push *this* repo (it's private; see §0.6). Every other repo is public, so clone it anonymously.

**Where to put clones:** outside this repo, e.g. `$HOME/work`. Never clone a kernel or device tree *inside* `lineageos-galaxy-tab-s5e/`.

### 1.1 This repo
```bash
git clone https://github.com/anton-scholten/lineageos-galaxy-tab-s5e   # add the token from §0.6 if you have one
cd lineageos-galaxy-tab-s5e
git checkout -b agent/<task-id> origin/main
ls AGENTS.md AGENT-TASKS.md analysis/agent-batches   # all three must exist; if not, stop and report it
```

### 1.2 Kernel trees (only for the K tasks)
The sdm670 clone is ≈2.3 GB and takes 10–30 minutes. **Start it in the background and don't kill it**, even when
it looks stuck at "Resolving deltas". Only one clone at a time.
```bash
W=$HOME/work; mkdir -p $W && cd $W
git clone --single-branch -b lineage-23.2 https://github.com/anton-scholten/android_kernel_samsung_sdm670 k670
cd k670
git remote add exy https://github.com/anton-scholten/android_kernel_samsung_exynos9810
git fetch --no-tags exy lineage-22.2:refs/remotes/exy/l222 lineage-23.2:refs/remotes/exy/l232
```
Check it worked. **All three lines must print a SHA:**
```bash
git rev-parse --verify a30605a54f3b      # sdm670 tip
git rev-parse --verify d54533f1546b      # series base
git rev-parse --verify baa585f67e0e      # series head
git rev-list --count --no-merges d54533f1546b..baa585f67e0e   # should print 2599
```
The backup fork is frozen, so `exy/l232` should be exactly `baa585f67e0e`. If it isn't, stop and report it. Don't use the moving ExyHyperBrick original.

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

## 2. All tasks at a glance
The repo setup is done (forks, branches, backups, manifests; see [REPO-SETUP.md](REPO-SETUP.md)). Only these research tasks are left for helpers.

| ID | Agents | Tier (§10) | Clone needed | Output | Rough time |
|---|---|---|---|---|---|
| M2 link check | 1 | 1 | this repo | `analysis/link-check.md` | < 1 h |
| M3 pin checker | 1 | 1 | this repo | `scripts/check-pins.sh` | < 1 h |
| K1 upstream map | 1 | 1 | kernel (§1.2) | `analysis/upstream-map/` | 2–4 h |
| K2a-1…4, K2c-1…2 trivial conflict briefs | 6 | 1 | kernel | `analysis/conflicts/` | 2–4 h each |
| K2b-1…4, K2d-1…3 moderate conflict briefs | 7 | 2 | kernel | `analysis/conflicts/` | 3–6 h each |
| K3-1…4 large conflicts, facts only | 4 | 2 | kernel | `analysis/conflicts/` | 2–4 h each |
| K4a–c first build errors | 3 | 1 | kernel | `analysis/build-test/errors/` | 1–2 h each |
| K5a–e driver API audit | 5 | 2 | kernel | `analysis/api-audit/` | 2–4 h each |
| K6 defconfig fragment | 1 | 1 | kernel | `analysis/defconfig/` | 1–2 h |
| R1 VINTF | 1 | 2 | device tree + LineageOS | `analysis/rom/vintf.md` | 2–3 h |
| R2 sepolicy | 1 | 2 | device tree + LineageOS | `analysis/rom/sepolicy.md` | 2–4 h |
| R3 soong config | 1 | 1 | device trees + LineageOS | `analysis/rom/soong.md` | 1–2 h |
| R4 blob deps | 1 | 1 | vendor blobs | `analysis/rom/blob-deps.tsv` | 1–2 h |
| R5 port list from sm7125 | 1 | 2 | device tree + sm7125-common | `analysis/rom/port-from-sm7125.md` | 2–3 h |
| R6 sort exynos9810 commits | 1 | 2 | device tree + exynos9810 backup | `analysis/rom/port-from-exynos9810.md` | 3–5 h |
| T1 device check script | 1 | 1 | this repo | `scripts/device-checks.sh` | 1 h |
| T2 crash-log guide | 1 | 1 | this repo | `TESTING.md` | 1 h |

**Total:** 37 agent runs. (IDs M1 and K5f were retired, so they don't appear.)

---

## 3. Housekeeping tasks (M): no kernel clone needed

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
| https://github.com/anton-scholten/android_kernel_samsung_sdm670 | lineage-23.2 | a30605a54f3b |
| https://github.com/anton-scholten/android_device_samsung_gts4lv-common | lineage-23.2 | 2e50286 |
| https://github.com/anton-scholten/android_kernel_samsung_exynos9810 | lineage-22.2 | d54533f1546b |
| https://github.com/anton-scholten/android_kernel_samsung_exynos9810 | lineage-23.2 | baa585f67e0e |
| https://github.com/anton-scholten/android_device_samsung_exynos9810-common | lineage-23.2 | ced977559b13 |
| https://github.com/ExyHyperBrick/android_kernel_samsung_exynos9810 | lineage-23.2 | baa585f67e0e |

Rows 3–4 (our work forks) and row 8 (ExyHyperBrick upstream) are *expected* to move. For those, print `MOVED` as information.
Exit code 1 only if one of the other rows (LineageOS upstream or our frozen backups) moved.
**Self-check:** `bash -n scripts/check-pins.sh` passes, and running it prints 8 lines.

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
(the §0.5 header with `## Summary`, then a table `commit | subject | resolution | confidence`, then `## Problems`).
Check your format with `scripts/check-agent-output.sh <batch>`. It must print `OK`.

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
Every brief has the header line, the title, and all six `##` sections from the template. `grep -L 'Confidence' analysis/conflicts/*.md` lists none of your files.

**Stop and ask** if: `git show C` fails (wrong SHA), or more than half of your commits come out `HUMAN`. Then hand in early with a note.

### K3: large conflicts, facts only (4 agents, batch files `K3-1` … `K3-4`, 3 commits each)
Same as K2 steps 1–4, **but don't propose a resolution.** Large conflicts need a human. Add one more section:
```markdown
## Later series commits touching the same files
<output of: git log --oneline C..baa585f67e0e -- <each conflicting file> | head -30>
```
Use the K2 template, with `## Proposed resolution` replaced by `## Notes for the lead` (what you noticed, ≤10 lines).

### K4: first build errors (3 agents)
A test build of the merged tree, with every conflict blindly resolved to the series side, stopped at 4 errors
([`port-first-errors.txt`](analysis/build-test/port-first-errors.txt)). [`analysis/build-test/README.md`](analysis/build-test/README.md)
already gives the likely *cause* of each. Your job is to find the exact **commits**, so the lead knows what to pick or keep.

| ID | Error | Likely cause (from the build-test README) | Find |
|---|---|---|---|
| K4a | `unknown type name 'randomized_struct_fields_end'` (`include/linux/sched.h:2284`) | Missing prerequisite. The Exynos base has newer `compiler*.h` randstruct macros; sdm670 doesn't | The commit(s) that add `randomized_struct_fields_start/end` to `include/linux/compiler*.h` in the Exynos tree, and whether each sits before the series base or in the series |
| K4b | `'ANDROID_VERSION' is not defined` (`include/uapi/asm-generic/socket.h:112`) | Samsung KNOX code from the Exynos tree came in with the conflict context | The series commit whose conflict in `socket.h` brought the `ANDROID_VERSION` block. Candidate: `05e4636c5fed` "UPSTREAM: net: add new control message for incoming HW-timestamped packets", the only conflict on that file |
| K4c | `use of undeclared identifier 'TIF_FSCHECK'` (`arch/arm64/include/asm/uaccess.h:89`) **and** the follow-on `asm-offsets.c:49` error | Taking the series side dropped an sdm670 security fix ("arm64/syscalls: Check address limit on user-mode return") | The sdm670 commit that added `TIF_FSCHECK`, and the series commit(s) whose conflicts remove it. Candidate: `2d6869d3a4ce` "arm64: Add uprobe support" (conflicts in `arch/arm64/include/asm/thread_info.h`) |

**Steps**
1. Find where the symbol is defined:
   - in the series head: `git grep -n '<symbol>' baa585f67e0e -- include/ arch/arm64/`
   - in sdm670: `git grep -n '<symbol>' a30605a54f3b -- include/ arch/arm64/`
   Note the defining line (`#define`, `struct`, enum), not just uses.
2. Find the commit that added the definition: `git log --format='%h %ad %s' --date=short -S'<symbol>' <tree> -- <file>`, with `<tree>` = `baa585f67e0e` or `a30605a54f3b`. Take the oldest.
3. Where does that commit sit?
   - `git merge-base --is-ancestor <sha> d54533f1546b && echo "before series base"` (a prerequisite the Exynos tree already had).
   - Otherwise it's in the series. Look up its status in `analysis/exyhyperbrick-trial/results.tsv` (`CLEAN`, `CONFLICT`, `SKIPDEV`, `SKIPDEV2`).
4. For a candidate conflict commit, run `git merge-tree --write-tree --merge-base=<cand>^ a30605a54f3b <cand>`, and show which conflict block contains the symbol (§1.3).
5. **K4c only:** check whether `asm-offsets.c:49` at `baa585f67e0e` uses something from `thread_info.h`, i.e. whether it's the same root cause.

**Output:** `analysis/build-test/errors/<ID>.md`: the §0.5 header, then sections `## Defined at`, `## Added by`, `## Where it sits`
(before base / in series + status), `## Conflict that loses or brings it`, `## Suggested fix` (for example "keep sdm670 lines X–Y in commit Z" or
"cherry-pick prerequisite <sha> first"), `## Confidence`, `## Problems`.

### K5: driver API audit (6 agents, one per area)
Areas (paths checked to exist in sdm670 on 2026-10-03):
- K5a `net/rmnet_data/`, `drivers/net/rmnet_iplo*` if present
- K5b `drivers/platform/msm/ipa/`
- K5c `drivers/staging/qcacld-3.0/`, `drivers/staging/qca-wifi-host-cmn/`
- K5d `net/qrtr/`, `net/ipc_router/`, `drivers/soc/qcom/qmi_interface*.c`
- K5e `drivers/net/wireless/cnss*/`, `drivers/soc/qcom/icnss*.c`, `net/embms_kernel/`

(sdm670 has no Samsung KNOX `ncm` or `sec_net` network code, and `techpack/` only holds audio, so those aren't audited.)
If a path in your list doesn't exist (`git ls-tree -d a30605a54f3b <path>` prints nothing), note that and carry on with the rest.

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
Options, from the end of [the trial README](analysis/exyhyperbrick-trial/README.md):
- **Turn on (14):** `ANDROID_BINDERFS BPF_LSM CFQ_GROUP_IOSCHED DEBUG_INFO_BTF FUSE_BPF KPROBES NET_ACT_BPF PSI UCLAMP_TASK UCLAMP_TASK_GROUP UNICODE USERFAULTFD XDP_SOCKETS XDP_SOCKETS_DIAG`
- **Turn off (3):** `USER_NS RT_GROUP_SCHED SCHED_TUNE` (SchedTune is replaced by uclamp). Write them as `# CONFIG_X is not set`.

The defconfigs are `arch/arm64/configs/gts4lvwifi_defconfig` and `gts4lv_defconfig` (there are also `*_eur_open_defconfig`s). Check all four.
Note in the README that `DEBUG_INFO_BTF` needs `pahole` in the kernel build environment.

**Steps, for each option `X`**
1. Find its Kconfig entry in the series head: `git grep -n "^config X$" baa585f67e0e -- '*Kconfig*'`.
2. Show it: `git show baa585f67e0e:<path> | sed -n '<line>,+25p'`. Copy the `depends on` and `select` lines.
3. For each dependency `Y`, check whether sdm670's defconfigs already enable it:
   `git show a30605a54f3b:arch/arm64/configs/gts4lvwifi_defconfig | grep -w "CONFIG_Y"`.
4. Does the Kconfig entry exist in sdm670 at all? (`git grep -n "^config X$" a30605a54f3b`). If not, it comes with the series.

**Output:** `analysis/defconfig/gts4lv-23.2.fragment` (lines `CONFIG_X=y`, dependencies included) and
`analysis/defconfig/README.md` (table `option | Kconfig file:line | depends on | already in sdm670 defconfig?`).

---

## 5. ROM-side research tasks (R): GitHub only, no kernel clone

Get these trees with shallow clones, e.g.
`git clone --depth 1 -b lineage-23.2 https://github.com/LineageOS/android_hardware_interfaces`.
Our device tree: `git clone --depth 1 -b lineage-23.2 https://github.com/anton-scholten/android_device_samsung_gts4lv-common`.
Per-model trees (unchanged, so use 22.2): `LineageOS/android_device_samsung_gts4lvwifi` and `..._gts4lv`, branch `lineage-22.2`.
Repo names checked on 2026-10-03: `android_hardware_interfaces`, `android_system_sepolicy`, `android_device_lineage_sepolicy`,
`android_hardware_samsung` and `android_hardware_qcom-caf_common` have `lineage-23.2`. `android_hardware_qcom_{audio,display,media}` use
branch `lineage-23.2-caf-sdm845` (our SoC's family). `android_device_qcom_sepolicy_vndr` uses `lineage-23.2-legacy-um`.
If a branch doesn't exist, list the branches with `git ls-remote --heads <url> | grep lineage-2` and report it. Don't guess.

| ID | Task | Output |
|---|---|---|
| R1 | **VINTF.** Our HALs are listed in `manifest.xml` in our device tree (`anton-scholten/android_device_samsung_gts4lv-common`, branch `lineage-23.2`). Today it says `target-level="5"`, which 23.2 no longer supports, so the plan is to move to **6**. Compare each `<hal>` name and version with `compatibility_matrices/compatibility_matrix.6.xml` in `LineageOS/android_hardware_interfaces` `lineage-23.2`. List each HAL whose version is outside the range the matrix allows. Do it for the LTE model too: its RIL is declared in `LineageOS/android_device_samsung_gts4lv` (`lineage-22.2`). Known suspects: soundtrigger 2.2 (matrix wants 2.3) and radio 1.4 (matrix wants 1.5–1.6) | `analysis/rom/vintf.md` |
| R2 | **sepolicy.** List every type, attribute and macro used in the `sepolicy/` folder of our device tree (branch `lineage-23.2`). Leave out names our own tree defines (`git grep -nE '^(type|attribute) <name>'` in our `sepolicy/`). Check each remaining one exists in `LineageOS/android_system_sepolicy`, `android_device_lineage_sepolicy` or `android_device_qcom_sepolicy_vndr` (`lineage-23.2-legacy-um`) with `git grep -w`. Report the missing ones, and the commit that removed them if you can find it | `analysis/rom/sepolicy.md` |
| R3 | **Soong config.** List each `soong_config_set` / `SOONG_CONFIG_` variable in the device fork and the `gts4lv` and `gts4lvwifi` repos. Check each is still read (`git grep` the namespace and variable name) by `LineageOS/android_hardware_samsung` `lineage-23.2`, `android_hardware_qcom-caf_common` `lineage-23.2`, `android_hardware_qcom_{audio,display,media}` `lineage-23.2-caf-sdm845`, or `android_vendor_lineage` `lineage-23.2` | `analysis/rom/soong.md` |
| R4 | **Blob deps.** From `TheMuppets/proprietary_vendor_samsung_gts4lv-common` `lineage-22.2` (use `--depth 1`; it doesn't use Git LFS), run `readelf -d` on each `.so` and list `NEEDED` libraries that aren't shipped in the vendor repo itself. The lead checks those against 23.2 | `analysis/rom/blob-deps.tsv` |
| R5 | **Port list from sm7125-common.** [`analysis/reference-trees/sm7125-common-22.2-to-23.2.tsv`](analysis/reference-trees/sm7125-common-22.2-to-23.2.tsv) lists the 26 commits LineageOS made to an official Samsung Qualcomm tree between 22.2 and 23.2. Four are done (see [the README](analysis/reference-trees/README.md)). For each of the other 22: read it (`git show <sha>` in a clone of `LineageOS/android_device_samsung_sm7125-common`), find the matching file or setting in our device fork, and say: `NEEDED` / `NOT NEEDED` / `ALREADY DONE` / `UNSURE`, with the reason and the file it would change in our tree | `analysis/rom/port-from-sm7125.md` |
| R6 | **4.9-specific changes in exynos9810-common.** [`exynos9810-common-22.2-to-23.2.tsv`](analysis/reference-trees/exynos9810-common-22.2-to-23.2.tsv) has 143 commits from ExyHyperBrick's Galaxy S9 tree. Clone it from the backup `anton-scholten/android_device_samsung_exynos9810-common`. Sort each into: `KERNEL-4.9` (works around the old kernel: BPF, uffd, LMK, freezer, power supply filters), `GENERIC-23.2` (a change every device needs for 23.2), `EXYNOS-ONLY` (audio, camera, RIL, Exynos hardware), `TUNING` (performance and memory tweaks). For `KERNEL-4.9` and `GENERIC-23.2`, say whether our device fork needs the same change | `analysis/rom/port-from-exynos9810.md` |

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
Now, all in parallel:   M2  M3  K1  K2*  K3*  K4a–c  K5a→K5b..e  K6  R1–R6  T1  T2
After K1:               lead re-checks K2 "Already in sdm670?" answers against upstream-map.tsv
After K1–K4:            lead starts the cherry-pick on the kernel fork's lineage-23.2 (section 7)
After R1–R6:            lead adds the needed device-tree commits to the device fork's lineage-23.2
```

## 9. Common mistakes
- **Taking one side of a conflict whole.** A test build doing that failed in seconds ([build-test](analysis/build-test/README.md)). Always look at both sides.
- **Cloning ExyHyperBrick's original instead of our backup.** The original keeps moving. All numbers here are for `baa585f67e0e`.
- **Short SHAs that are ambiguous.** Use at least 12 characters.
- **Copying big code blocks.** Cite them instead (rule 7).
- **Saying "probably fine" without evidence.** Give a source or say `confidence: low`.
- **Killing a slow clone.** Wait. Big clones look stuck while they unpack.
- **Editing shared files** (`WORKLOG.md`, `HANDOVER.md`). Don't; the lead does.

## 10. Which model for which task
Based on the OpenCode Go plan, checked 2026-10-03 from third-party write-ups. opencode.ai itself was blocked from the cloud container, so check the current list and limits at <https://opencode.ai/go>.

| Tier | Model (OpenCode Go) | Tasks | Why |
|---|---|---|---|
| 1, cheapest | **DeepSeek V4.1 Flash** ($0.15 / $0.60 per 1M tokens, ≈130k requests/month) | M2, M3, K1, K2a-1…4, K2c-1…2, K4a–c, K6, R3, R4, T1, T2 | Mechanical: run the given commands, grep, fill in a template, write a small script |
| 2, mid | **Qwen3.7 Plus**, **MiniMax M3** or **Kimi K2.7 Code** | K2b-1…4, K2d-1…3, K3-1…4, K5a–e, R1, R2, R5, R6 | Needs judgment: reading conflict hunks, comparing APIs, sepolicy, sorting commits |
| 3, strong | Kimi K3 (≈490 requests/month), a frontier model, or a human | Section 7 only, plus the review (§11) | Resolving conflicts, build fixes, boot debugging |

- Fallback for tier 1: GLM-5.3-Flash (similar price, ≈31k requests/month).
- Don't use free or unknown models (for example "Space Bunny Free") for K or R tasks. They haven't been tested on this kind of work.
- If a tier-1 agent marks more than half its items `HUMAN` or `low`, rerun that batch with a tier-2 model rather than reviewing it by hand.

## 11. Reviewing the output (lead)
Checking costs much less than producing, because every claim cites a SHA or `file:line`. Order:
1. **Format, no AI needed:** `scripts/check-agent-output.sh` checks the header, the `Summary` and `Problems` sections,
   one brief per batch row, all brief sections present, and a valid resolution and confidence. Send failures back to the agent.
2. **Check fully:** every `DROP` (claims sdm670 already has the change; a wrong one silently loses code), every `low` and every `HUMAN`.
3. **Spot-check** about 20% of the `high`-confidence items per batch. If all hold up, accept the batch. If any fails, check that whole batch.
4. **K1:** rerun `make_map.py` and compare `sha256sum`. Then check 10 random rows by hand.
5. Record what was accepted in `WORKLOG.md`, and merge the `agent/*` branches into `main`.
