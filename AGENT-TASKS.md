# Work for helper agents

These tasks are for **helper agents that are less capable than the lead agent**, working in parallel.
Every task gives you:
- the exact commands to run,
- a template for the output file,
- a self-check to run before you hand in,
- a list of times when you should **stop and ask** instead of guessing.

A lead agent or the owner reviews and merges your output. You never change the kernel or device tree
directly: you **research and write reports**. State checked on 2026-10-03; see [HANDOVER.md](HANDOVER.md).

> **Status (2026-10-04): rounds 1–3 and P1–P5 are done, reviewed and merged; the kernel builds.** Their sections stay as the format reference.
> **Open: B1 (ROM sync + build), then P6 (ROM build errors) and P7 (boot-log triage), all in §6c.** B1 waits for the owner's RUNBOOK step 7. Review records: [review-P1.md](analysis/port/review-P1.md), [review-P4.md](analysis/port/review-P4.md).
> The cross-agent findings are in [LEAD-SYNTHESIS.md](LEAD-SYNTHESIS.md).

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
   You clone them read-only. **Only exception, round 4:** P1/P3/P4 push to branch `port/pick` in the kernel fork, and P5/P6 to `port/dt` / `port/dt-2` in the
   device fork. Never to `lineage-23.2` or any other branch there.
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

**Round 4 also needs push to the two forks**, on `port/*` branches only. Use a fine-grained token with *Contents: Read and write* on
`android_kernel_samsung_sdm670` and `android_device_samsung_gts4lv-common`. In each fork, protect `lineage-23.2`
(Settings → Branches → rule for `lineage-23.2`, "Restrict who can push" or "Lock branch"). The lead moves it forward after review.

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

### 2.1 Rounds 1–2: done and merged
| Task | Output in `main` | Headline result |
|---|---|---|
| M2 link check | (fixed in the docs; report not kept) | 1 broken anchor, fixed |
| M3 pin checker | `scripts/check-pins.sh` | all 8 pins OK |
| K1 upstream map | `analysis/upstream-map/` | 2,599 rows: 44 yes, 1,575 no, 980 unknown |
| K2a–d conflict briefs (13) | `analysis/conflicts/` | 113 briefs: 76 MERGE, 22 PREREQ, 15 DROP, 0 HUMAN |
| K3 large conflicts (4) | `analysis/conflicts/` | 12 fact briefs |
| K4a–c build errors | `analysis/build-test/errors/` | randstruct and ANDROID_VERSION come from the Exynos base; TIF_FSCHECK is a bad conflict resolution |
| K5a–e API audit | `analysis/api-audit/` | 1 real break (`ipc_router`), but only 7 of 367 changed headers covered |
| K6 defconfig | `analysis/defconfig/` | 14 on + 3 off + UPROBES, BPF_JIT, **CGROUP_SCHED (mandatory)** |
| R1 VINTF | `analysis/rom/vintf.md` | level 6: soundtrigger 2.2 and LTE radio 1.4 too old |
| R2 sepolicy | `analysis/rom/sepolicy.md` | 0 missing; 15 vendor property names may fail the namespace check |
| R3 Soong | `analysis/rom/soong.md` | 0 broken |
| R4 blob deps | `analysis/rom/blob-deps.tsv` | 1 missing lib (`libclang_rt.ubsan_standalone-arm-android.so`) |
| R5 sm7125 port list | `analysis/rom/port-from-sm7125.md` | 1 needed: target-level 6 |
| R6 exynos9810 sort | `analysis/rom/port-from-exynos9810.md` | 1 needed: space-separated lists in the audio policy XML |
| T1 device checks | `scripts/device-checks.sh` | |
| T2 crash logs | `TESTING.md` | |

Round 1 ran under the old IDs R6/R7 (now R5/R6), K4d (folded into K4c) and K5f (retired). Superseded round-1 outputs stay on
their `agent/*` branches only. All agents ran on one free model; the review (§11) re-checked the load-bearing claims and they held.

### 2.2 Round 3: done (2026-10-03, reviewed 2026-10-04)
Small follow-ups the review found. Same rules, same hand-in. 5 agent runs, a few hours each.

| ID | Agents | Model (§10) | Clone needed | Output | Rough time |
|---|---|---|---|---|---|
| K7 flag/bitfield collisions | 1 | free | kernel (§1.2) | `analysis/collisions/K7.md` + `.tsv` | 3–5 h |
| K8 two missing conflict briefs | 1 | free | kernel | `analysis/conflicts/` (batch `K8`) | 2–3 h |
| R7 vendor property namespace | 1 | free | LineageOS repos (shallow) | `analysis/rom/property-namespace.md` | 1–2 h |
| R8 LTE radio HAL version | 1 | free | vendor blobs (gts4lv) | `analysis/rom/radio-hal.md` | 1–2 h |
| R9 soundtrigger and per_proxy_helper | 1 | free | device tree + vendor blobs | `analysis/rom/soundtrigger-perproxy.md` | 1–2 h |

### 2.3 Round 4: P1–P5 done and reviewed; P6 opens after the owner's first ROM build
The free model does the work; a strong model only reviews and handles escalations. Specs in §6c.

| ID | What | Agents | Model | Needs | Output |
|---|---|---|---|---|---|
| P1 | Cherry-pick the series, resolving each conflict from its brief | 1 (must be sequential) | free | K8 nice to have | kernel fork `port/pick`; this repo: `analysis/port/dropped.tsv`, `analysis/port/P1-log.md` |
| P1-R | Review P1 | 1 | **strong** | P1 | `analysis/port/review-P1.md`, fix requests |
| P2 | Triage the "auto-merged but different" commits | 2–4 in parallel | free | P1 | `analysis/port/automerge-triage.tsv` |
| P2-R | Review P2's SUSPECT items + 10% of BENIGN | 1 | **strong** | P2 | added to `review-P1.md` |
| P3 | Apply the known kernel fixes and the defconfig fragment | 1 | free | P1-R, K7 | commits on `port/pick` |
| P4 | Build loop: fix compile errors one at a time | 1 (sequential) | free, escalates | P3 | commits on `port/pick`; `analysis/port/P4-log.md` |
| P4-R | Review P3+P4 fix commits; handle escalations | 1 | **strong** | P4 (can run in chunks) | `analysis/port/review-P4.md` |
| P5 | Device-tree commits | 1 | free | R7–R9 | device fork `port/dt`; `analysis/port/P5-log.md` |
| P5-R | Review P5 | 1 | **strong** | P5 | `analysis/port/review-P4.md` (done) |
| B1 | ROM sync + first build | 1 | free | step 7 (owner) | `out/…zip`; `analysis/port/B1-log.md` |
| P6 | ROM build-error loop | 1 (sequential) | free, escalates | B1 fails | device fork `port/dt-2`; `analysis/port/P6-log.md` |
| P6-R | Review P6 | 1 | **strong** | P6 | `analysis/port/review-P6.md` |
| P7 | Boot-log triage, per flash attempt | 1 | free (strong diagnoses) | a flashed tablet | `analysis/port/boot-<n>.md` |

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
Spot-check: commit `3ed2e2f029db` ("BACKPORT: bpf: Add BPF_MAP_TYPE_LRU_HASH") must **not** come out `yes`: sdm670 does **not**
carry LRU_HASH (`git grep -n BPF_MAP_TYPE_LRU_HASH a30605a54f3b -- include/uapi/linux/bpf.h` finds nothing). An earlier version
of this spec said the opposite; four agents caught it.

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
3. Run the **stacked** replay: `K670=$W/k670 python3 analysis/tools/replay_show.py C <conflicting files>` (see
   [analysis/tools/README.md](analysis/tools/README.md); use a scratch clone, it creates commits). Only if that fails, fall back to the
   isolated `git merge-tree --write-tree --merge-base=C^ a30605a54f3b C`, and say so: the isolated form both over- and under-reports.
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

### K5: driver API audit (5 agents, one per area)
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

**Known limits (from round 2):** the 7 headers cover only 7 of the 367 headers the series changes. `git ls-tree -d` hides single-file
paths, so use `ls-tree -r --name-only`. A config can be on through another option's `select`, so check `git grep -n 'select X'` before calling it off.

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

## 6b. Round 3 task specs

### K7: flag and bitfield collisions (1 agent, free model)
**Why:** sdm670 already used some bit values that the series reuses for something else. Merging both sides gives *no* conflict and
*no* compiler error; two flags just silently share a bit. Known cases: `TIF_FSCHECK`/`TIF_UPROBE` both 4 in
`arch/arm64/include/asm/thread_info.h`, and `FAULT_FLAG_SPECULATIVE`/`FAULT_FLAG_INTERRUPTIBLE` both `0x200` in `include/linux/mm.h`
([LEAD-SYNTHESIS.md §2](LEAD-SYNTHESIS.md)). Find the rest.

**Steps**
1. List headers the series changes: `git diff --name-only d54533f1546b baa585f67e0e -- '*.h'` (≈367).
2. For each header that also exists in sdm670, extract `#define NAME <number>` lines (decimal, hex, `BIT(n)`, `1 << n`, `1UL << n`) and enum
   members with explicit values, from `a30605a54f3b:<file>` and `baa585f67e0e:<file>`. Write it as `analysis/collisions/find_collisions.py`
   (standard library only, takes the kernel path as argument).
3. Report a **collision** when the same file has, in the merged view, two *different* names with the same value and the same prefix
   (text before the first `_` after the common prefix, e.g. `TIF_`, `FAULT_FLAG_`, `MSG_`, `SOCK_`). Name A exists only in sdm670 and
   name B exists only in the series head. Same name with a changed value is a separate category, `VALUE_CHANGED`.
4. For each hit, say whether the bits are used as a mask (`_TIF_WORK_MASK`, `|` combinations) and suggest a free value.
5. Must find the two known cases. If it doesn't, the script is wrong.

**Output:** `analysis/collisions/K7.tsv` (`file	value	sdm670_name	series_name	category`), `analysis/collisions/K7.md` (§0.5 header, summary, table of real
collisions with suggested values, `## Problems`), and the script.

### K8: briefs for the two un-briefed conflicts (1 agent, free model)
Batch file: [`analysis/agent-batches/K8.tsv`](analysis/agent-batches/K8.tsv). Both commits are trial-`CLEAN`, but conflict in a real in-order
replay: `47d10743ccd7` "BACKPORT: mm: introduce MADV_PAGEOUT" (a prerequisite for `e7751e04e9d1`), and `0a115d7aaf34` "mm/vmalloc.c: convert
vmap_lazy_nr to atomic_long_t" (between two K2d-1 commits; read brief `7c9b3c4119eb.md` first). Follow §K2 exactly, using the stacked replay.
Output: two briefs + `analysis/conflicts/K8-summary.md`. Self-check: `scripts/check-agent-output.sh K8` prints `OK`.

### R7: vendor property namespace (1 agent, free model)
**Why:** 15 of 21 lines in our `sepolicy/vendor/property_contexts` lack the `vendor.` prefix that the 23.2 build check wants
(`check_prop_prefix.py`). sm7125-common has the same pattern and still builds, so something must exempt it ([LEAD-SYNTHESIS.md §7.2](LEAD-SYNTHESIS.md)).
**Steps:** shallow-clone `LineageOS/android_build_soong`, `android_build` (`lineage-23.2`), `android_vendor_lineage` (`lineage-23.2`), our device tree,
`LineageOS/android_device_samsung_gts4lvwifi` and `..._gts4lv` (`lineage-22.2`), and `android_device_samsung_sm7125-common` (`lineage-23.2`).
1. `git grep -n BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` in all of them.
2. Find `PRODUCT_SHIPPING_API_LEVEL` and `BOARD_SHIPPING_API_LEVEL` for gts4lv/gts4lvwifi and for one sm7125 device (for example `a52q`).
3. Read where `check_prop_prefix` is called in soong (`selinux_contexts.go`) and write down the exact condition that skips it.
4. Verdict: will our build fail the check? If yes, what is the smallest fix (rename the properties, or set the BUILD_BROKEN flag)?
**Output:** `analysis/rom/property-namespace.md`.

### R8: can the LTE RIL do radio 1.5? (1 agent, free model)
**Why:** FCM level 6 wants `android.hardware.radio` 1.5–1.6; the LTE model declares 1.4 (`gts4lv/manifest.xml`).
Bumping the number only works if the vendor RIL implements 1.5.
**Steps:** shallow-clone `TheMuppets/proprietary_vendor_samsung_gts4lv` (`lineage-22.2`) and `LineageOS/android_device_samsung_gts4lv` (`lineage-22.2`).
1. List RIL-related blobs (`rild`, `libsec-ril*`, `*radio*`).
2. `strings` / `readelf -d` them for `android.hardware.radio@1.5`, `@1.6`, `IRadio`, `radio.config@1.`.
3. Check what `hardware/samsung/ril` on `LineageOS/android_hardware_samsung` `lineage-23.2` provides.
4. Verdict: can the LTE manifest say 1.5? If not, the options are: keep level 5 for LTE only, or ship an FCM exemption. Cite sources.
**Output:** `analysis/rom/radio-hal.md`.

### R9: soundtrigger and per_proxy_helper (1 agent, free model)
**Why:** level 6 needs soundtrigger 2.3, and sdm710 builds only `soundtrigger@2.1-impl`. The plan is to delete the manifest block. Separately,
`per_proxy_helper` has a sepolicy domain but no `file_contexts` label ([LEAD-SYNTHESIS.md §7.4–7.5](LEAD-SYNTHESIS.md)).
**Steps:** in our device tree, the per-model trees and `TheMuppets/proprietary_vendor_samsung_gts4lv-common`:
1. Is any soundtrigger service built (`PRODUCT_PACKAGES`), started (`*.rc`) or shipped as a blob? If the manifest block is deleted,
   what else must go so that nothing tries to register it?
2. Where is the `per_proxy_helper` binary (blob path)? Write the exact `file_contexts` line it needs, in the style of the file's other lines.
**Output:** `analysis/rom/soundtrigger-perproxy.md`.

---

## 6c. Round 4 task specs (the port)

### Shared setup for P1, P3, P4
Layout (as in [RUNBOOK.md](RUNBOOK.md) §0): your docs worktree is `$DOCS` (e.g. `~/work/wt/P1`), the kernel clone is `~/work/k670`
(a full clone as in §1.2, not `--depth 1`: the cherry-pick needs the series history). **Only one of P1/P3/P4 runs at a time**; they share the clone.
```bash
DOCS=~/work/wt/<task-id>; cd ~/work/k670
git remote set-url --push origin https://<token>@github.com/anton-scholten/android_kernel_samsung_sdm670   # token from §0.6
git fetch origin port/pick 2>/dev/null && git checkout -b port/pick origin/port/pick || git checkout -b port/pick a30605a54f3b
git config user.name "<your model name> (helper)"; git config user.email "noreply@example.invalid"
```
The scripts live in the docs repo: `$DOCS/scripts/pick-series.sh`, `$DOCS/scripts/check-pick.py`. Commit your log files there, on `agent/<task-id>`.
**Never** run `git push --force`, `git rebase`, `git reset --hard` or `git commit --amend` on a commit that's already pushed. Fix mistakes with a new commit.

### P1: cherry-pick the series (free model, 1 agent)
The script picks every commit in order and **stops at the first one that needs you**. It skips Exynos-only commits, the `skip` group, and
anything already picked or listed in `analysis/port/dropped.tsv`. Empty picks (already in the tree) are recorded as dropped automatically.

**What to expect** (dry run on 2026-10-03, every conflict resolved mechanically; see [`analysis/port/dry-run-stops.tsv`](analysis/port/dry-run-stops.tsv)):
about **83 stops** in 2,460 picks, not the trial's 150. 71 have a brief, 25 are marked FULL review. There are also ~5 empty picks
(dropped automatically), and ~4 commits that apply but differ (task P2). Your real count will differ somewhat, because your resolutions keep sdm670's lines.

**Stops without a brief** (12 in the dry run): first check whether the commit only conflicts because an earlier commit was skipped.
Run `git log --oneline d54533f1546b..<sha>^ -- <file>` and look for commits in the `skip` group or in `dropped.tsv`. Example: 6 of them are a `lib/zstd`
chain whose earlier zstd commits are in the `skip` group. If so, DROP it the same way, reason `follows skipped <sha>`, and add the trailer
`Needs-review:` on the next commit you make, so the reviewer sees the chain. Otherwise resolve it and write a 3-line note in the commit message
(what conflicted, what you kept, why).

**Loop:**
1. `bash $DOCS/scripts/pick-series.sh .` → exit 0 means done (go to step 8); exit 1 means a conflict; read `.git/PORT_STATUS`.
2. Open the brief it names (`analysis/conflicts/<sha>.md`). Check the conflicting files match the brief's `## Conflicting files`. If they don't, or there's
   no brief, write down what you see before deciding.
3. Do what `## Proposed resolution` says:
   - **DROP** (whole commit): `git cherry-pick --skip`, then add a line to `analysis/port/dropped.tsv`: `<12-char sha><TAB>DROP per brief: <one line why><TAB><your model>`.
   - **DROP of one hunk/file** or **MERGE**: edit only the files in conflict. Remove every `<<<<<<<`, `=======`, `>>>>>>>`. Keep sdm670's lines and the series' lines
     exactly as the brief says. Never delete code the brief doesn't tell you to.
   - **PREREQ**: if the named prerequisite is already picked (`git log --grep=<sha>`), resolve as MERGE. If it isn't, and it's in the series later, write
     `PREREQ-ORDER` in the log and escalate (step 6). If it's from the Exynos base, cherry-pick it first: `git cherry-pick --abort`,
     `git cherry-pick -x <prereq>`, then rerun the script.
4. Finish the commit:
   ```bash
   git add <files>; GIT_EDITOR=true git cherry-pick --continue
   git commit --amend --no-edit --trailer "Resolved-by: <model>; brief <sha12>; <DROP-hunk|MERGE|PREREQ>"
   ```
   (`--amend` is allowed here: that commit isn't pushed yet.)
5. Self-check before moving on: `git diff HEAD~1 --stat` shows only the conflicted files, and
   `git show HEAD | grep -nE '^\+(<<<<<<<|>>>>>>>)'` prints nothing (and no `=======` line left in the files you edited).
6. **Escalate** instead of guessing when: `.git/PORT_STATUS` says `review: FULL` and the brief doesn't give a line-by-line plan; the brief says `HUMAN`;
   the brief doesn't match what you see; or you tried twice. To escalate: resolve as well as you can, add the trailer
   `Needs-review: <why>` as well, and keep going. The strong reviewer checks every such commit. If you truly can't produce a compiling-looking
   result, `git cherry-pick --abort`, write the commit and reason in `analysis/port/P1-log.md` under `## Blocked`, and **stop**.
7. Every 10 resolved conflicts: `git push origin port/pick`, and commit + push the docs repo (`dropped.tsv`, `P1-log.md`) on `agent/P1`.
8. When the script exits 0: `python3 $DOCS/scripts/check-pick.py . ~/work/pick-review` must print `problems: 0`. Push both repos.

`analysis/port/P1-log.md`: the §0.5 header, then one line per stop: `sha | brief verdict | what you did | escalated?`, then `## Blocked` and `## Problems`.

### P2: triage "auto-merged but different" commits (free model, 2–4 agents)
`check-pick.py` writes `pick-review/automerge/*.range-diff`: commits git applied without a conflict whose changed lines still differ from the original.
Example: `dff86fa1e78e` lost 5 removed lines, because sdm670 didn't have them where the patch expected. Split the files alphabetically between the agents.
For each one, read the range-diff and classify:
- **BENIGN**: same change, only placement or context differs; or a removal that found nothing to remove because sdm670 never had the lines.
  Prove it: `git grep` the lines in the result.
- **SUSPECT**: part of the change is missing or duplicated (e.g. a `#define` now defined twice, a removal that didn't happen while the lines still exist elsewhere).
Task IDs `P2-1` … `P2-4`; the owner tells each agent its share. Read-only on `~/work/k670` (don't check anything out there; use `git show`/`git grep <rev>`).
Output `analysis/port/automerge-triage-<n>.tsv`: `sha12	BENIGN|SUSPECT	reason	evidence`.

### P3: known fixes and defconfig (free model, 1 agent)
Every item below was checked by the reviewer against `port/pick` @ `d73f07cf8b5c` ([review-P1.md](analysis/port/review-P1.md)).
**Before starting:** `git -C ~/work/k670 fetch origin && git -C ~/work/k670 checkout port/pick && git -C ~/work/k670 merge --ff-only origin/port/pick`,
then `git log -1 --format=%h` must print `d73f07cf8b5c` (or a later commit, if P3 was already partly done: then skip the items already in `git log`).
One commit per item, message `P3: <what>`, trailer `Fix-by: <model>; <source>`. Push `port/pick` after each commit.
If a line number below doesn't match what you see, **stop and report**: don't guess a new location.

**Already done by P1, don't redo:** `TIF_UPROBE`→5 with `_TIF_WORK_MASK`, `FAULT_FLAG_INTERRUPTIBLE`→`0x800`, `VM_FLUSH_RESET_PERMS`→`0x200`
(never re-add the series' `0x100`). The other K7 rows are moot in this tree.

1. **New file `arch/arm64/include/asm/set_memory.h`.** arm64 already declares `set_memory_ro/rw/x/nx` in `asm/cacheflush.h:161-164` and defines them
   in `arch/arm64/mm/pageattr.c`. So the new header only has to pull those in. Exact content:
   ```c
   /* SPDX-License-Identifier: GPL-2.0 */
   #ifndef _ASM_ARM64_SET_MEMORY_H
   #define _ASM_ARM64_SET_MEMORY_H

   /* 4.9: set_memory_ro/rw/x/nx are declared in asm/cacheflush.h and defined in arch/arm64/mm/pageattr.c. */
   #include <asm/cacheflush.h>

   #endif /* _ASM_ARM64_SET_MEMORY_H */
   ```
   Source: LEAD-SYNTHESIS §1.3 (`arch/arm64/Kconfig:43` selects `ARCH_HAS_SET_MEMORY`; `include/linux/set_memory.h:12` includes this file).
2. **Five old-style `wakeup_source_register()` calls** get `NULL` as a new first argument, e.g. `wakeup_source_register(NULL, "DIAG_WS")`:
   - `drivers/char/diag/diagchar_core.c:4148`
   - `drivers/power/supply/qcom/battery.c:1605`
   - `drivers/power/supply/qcom/smb1390-charger.c:779`
   - `drivers/power/supply/qcom/step-chg-jeita.c:755`
   - `net/ipc_router/ipc_router_core.c:1384`

   Check: `git grep -n 'wakeup_source_register(' -- '*.c'`. Every call must now have two arguments (`qdf_lock.c:273` already does). Source: LEAD-SYNTHESIS §6.2.
3. **`fs/unicode`:** `git checkout baa585f67e0e -- fs/unicode`. Then two one-line insertions, both exactly where the series head has them:
   - `fs/Makefile`: after line 93, `obj-$(CONFIG_NLS)		+= nls/`, add `obj-$(CONFIG_UNICODE)		+= unicode/`
   - `fs/Kconfig`: after line 312, `source "fs/dlm/Kconfig"`, add `source "fs/unicode/Kconfig"`

   Source: LEAD-SYNTHESIS §1.6.
4. **F1, `include/uapi/drm/drm_mode.h`:** delete lines **92–104**: the pick's duplicate block, from `/* Picture aspect ratio options */` down to the
   `(DRM_MODE_PICTURE_ASPECT_16_9<<19)` line. Keep the `<<24` block that follows. Check: the region from `DRM_MODE_FLAG_SUPPORTS_YUV420` to
   `DRM_MODE_FLAG_PIC_AR_256_135` is then identical to the sdm670 base (`git show a30605a54f3b:include/uapi/drm/drm_mode.h`), and
   `grep -c 'PIC_AR_MASK' include/uapi/drm/drm_mode.h` prints `1`. Background: [duplicate-picks.md](analysis/port/duplicate-picks.md).
5. **F2, `fs/userfaultfd.c`:** delete lines **1417–1428**: the *second* copy of the `UFFDIO_COPY will fill file holes` comment and its
   `VM_MAYWRITE` check, the one *after* the hugetlb alignment block. Keep the first copy. That makes the block identical to the series head.
   (duplicate-picks.md proposed deleting the first copy; both are equivalent, but the reviewer chose the one that matches upstream.)
   Check: `grep -c 'if (unlikely(!(cur->vm_flags & VM_MAYWRITE)))' fs/userfaultfd.c` prints `1`.
6. **Defconfig:** merge `analysis/defconfig/gts4lv-23.2.fragment` into all four defconfigs: `arch/arm64/configs/gts4lvwifi_defconfig`,
   `gts4lv_defconfig`, `gts4lvwifi_eur_open_defconfig`, `gts4lv_eur_open_defconfig`. For each `CONFIG_X=y` or `# CONFIG_X is not set` line in the
   fragment (comment lines starting `# ` followed by anything else are notes, so skip those): if the defconfig has a line for `CONFIG_X` (either form),
   replace it; otherwise append it at the end. **Must end up with** `CONFIG_CGROUP_SCHED=y`, `CONFIG_UPROBES=y`, `CONFIG_BPF_JIT=y`, `CONFIG_UNICODE=y`.
   Check (needs the P4 build tools):
   `make O=~/work/out ARCH=arm64 LLVM=1 gts4lvwifi_defconfig` then
   `grep -E '^CONFIG_(CGROUP_SCHED|FAIR_GROUP_SCHED|SCHED_WALT|UPROBES|BPF_JIT|BPF_LSM|UNICODE)=y' ~/work/out/.config | wc -l` prints `7`.
   If one is missing, Kconfig dropped it because a dependency is off: find it with `make O=~/work/out ARCH=arm64 LLVM=1 menuconfig`'s search, or the
   fragment's comments. Add the dependency, don't drop the option.

**Done when** all 6 commits are pushed and these all hold: `ls arch/arm64/include/asm/set_memory.h fs/unicode/Kconfig` works, and the checks
in items 2, 4, 5 and 6 pass. Log one line per item in `analysis/port/P3-log.md` (on `agent/P3`), with the commit SHA.

Not P3: F3 (the parisc duplicate) stays. `restore_pcpu_tick` is no longer referenced. The uclamp symbols come in P4.

### P4: build loop (free model, 1 agent, escalates)
Build: `bash $DOCS/analysis/build-test/kbuild.sh . ~/work/out ~/work/build.log` (needs the §1.0 tools plus
`clang lld flex bison libssl-dev binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi gcc-aarch64-linux-gnu dwarves` (for `pahole`); about 10 GB disk;
12 min per full build on 4 cores, later builds are incremental).
**Expect early, already decided by the reviewer** ([review-P1.md](analysis/port/review-P1.md)):
- `cpu_cgrp_id` undefined (`kernel/sched/core.c:1354`, `:9396`): it's generated by `include/linux/cgroup_subsys.h` only when `CONFIG_CGROUP_SCHED=y`.
  P3's defconfig sets it. If you still see this error, P3's defconfig didn't take: fix the defconfig, not the code.
- `task_util_est()` undefined (`kernel/sched/core.c:1335`): **don't** cherry-pick upstream util_est (`d272fed29eea`). sdm670 uses WALT instead of PELT util_est.
  Add this shim next to `task_util()` in `kernel/sched/sched.h` (≈line 1955), as one commit with trailer `Fix-by: <model>; reviewer decision review-P1.md`:
  ```c
  /* 4.9/WALT: no PELT util_est here; WALT's task_util() is the equivalent estimate. */
  static inline unsigned long task_util_est(struct task_struct *p)
  {
  	return task_util(p);
  }
  ```

**Notes:**
- `kbuild.sh` turns off `CONFIG_COMPAT_VDSO`. That's a host workaround for building outside a LineageOS tree; the real ROM build keeps it on. Don't copy
  it into a defconfig.
- Build `gts4lvwifi_defconfig` first (the script's default). When `Image.gz-dtb` links, change the defconfig name in your copy of the command to
  `gts4lv_defconfig`, build once more, and fix anything new the same way.
- `DEBUG_INFO_BTF=y` needs `pahole` ≥ 1.13 (`dwarves` package) on `PATH`.

**Loop:** build → take the **first** error in `build.log` → fix it → commit → repeat until `Image.gz-dtb` exists.
Allowed fixes, in order of preference:
1. A missing prerequisite from the Exynos base: find it (`git log -S'<symbol>' exy/l222`), `git cherry-pick -x` it. Trailer `Fix-by: <model>; prerequisite for <error>`.
2. A call site still using an old API: change the call to the new signature, the way the series fixed the same API elsewhere (cite that file:line).
3. A missing `#include` or declaration.
**Forbidden** (escalate instead): deleting or `#if 0`-ing code; turning off a config from the fragment; casts that hide a type error; any change in
`kernel/bpf/`, `arch/arm64/net/`, `net/core/filter.c` or `mm/` beyond a one-line include; the same error after 3 tries.
To escalate: write it in `analysis/port/P4-log.md` under `## Escalated` (error text, file:line, what you tried) and **stop**. The strong model fixes it,
then you continue. Push `port/pick` after every fix commit. Log one line per fix: `error | file | fix | commit`.

### P5: device-tree commits (free model, 1 agent)
Round 3 turned most of the planned items into no-ops ([review-P1.md](analysis/port/review-P1.md), LEAD-SYNTHESIS §7.4). Clone our device tree,
branch `port/dt` from `lineage-23.2`, push with the fork token.
1. **Do:** `audio_policy_configuration.xml` (and any other `audio_policy*.xml` in the tree): turn comma-separated `samplingRates`, `channelMasks` and
   `formats` lists into space-separated ones (R6; commit `924cf7e4adcc` in the exynos9810-common backup shows the format). One commit, trailer
   `Fix-by: <model>; R6 924cf7e4adcc`. Check with `xmllint --noout`.
2. **Skip, and log as "considered, intentionally skipped"** in `analysis/port/P5-log.md`:
   - `target-level` stays **5** for the first build (reviewer decision; the owner may change it);
   - the soundtrigger block stays (R9);
   - no `per_proxy_helper` label (R9: no binary exists);
   - vendor property names unchanged (R7: the check doesn't run at API 28);
   - LTE radio stays 1.4 (R8: the RIL can't do 1.5).

### B1: ROM sync and first build (free model, 1 agent, on the owner's machine)
Unattended and long (hours), but mechanical. **Machine:** Linux x86-64, ≥300 GB free, ≥16 GB RAM (32 GB better), fast network.
**Before starting, check** that both forks' `lineage-23.2` point at the port:
`git ls-remote https://github.com/anton-scholten/android_kernel_samsung_sdm670 refs/heads/lineage-23.2` must print `801f3f20e54a…`, and the
device fork's must print `e3ccc923bcf2…`. If they still print `a30605a…` / `2e50286…`, the owner hasn't done RUNBOOK step 7. **Stop and say so.**
Don't edit the manifests to work around it.

1. Build packages. This is the LineageOS wiki's Ubuntu list; check it there if your distro differs:
   `sudo apt install bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs gnupg gperf imagemagick protobuf-compiler python3-protobuf lib32readline-dev lib32z1-dev libdw-dev libelf-dev lz4 libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool squashfs-tools xsltproc zip zlib1g-dev python-is-python3`.
   Then the `repo` tool: `mkdir -p ~/bin && curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo && chmod a+x ~/bin/repo`, with `~/bin` on `PATH`.
   Set `git config --global user.name/user.email` if unset. Optional: `export USE_CCACHE=1 CCACHE_EXEC=/usr/bin/ccache` and `ccache -M 50G`.
2. Sync, exactly as in [PORTING-LINEAGE-23.2.md §3](PORTING-LINEAGE-23.2.md#3-building), in `~/android/lineage`, with the docs repo as `<this repo>`:
   `repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --no-clone-bundle`, copy `local_manifests/gts4lv-common.xml`
   and `gts4lvwifi.xml` into `.repo/local_manifests/`, then `repo sync -c -j$(nproc) --force-sync`. If the sync fails, rerun it (it resumes).
   After 3 failures, stop and log the error.
3. Check the right code arrived: `git -C kernel/samsung/sdm670 log -1 --format=%h` prints `801f3f20e54a`, and
   `git -C device/samsung/gts4lv-common log -1 --format=%h` prints `e3ccc923bcf2`.
4. Build: `source build/envsetup.sh && brunch gts4lvwifi 2>&1 | tee ~/work/rom-build.log`. **`brunch gts4lvwifi`, not `brunch lineage_gts4lvwifi`**:
   breakfast adds the prefix itself, and the doubled name fails.
5. Result: a zip at `out/target/product/gts4lvwifi/lineage-23.2-*-UNOFFICIAL-gts4lvwifi.zip` → done (write its path, size and sha256 in the log).
   Otherwise hand over to P6 with `~/work/rom-build.log`. Don't fix anything yourself in B1.

Log in `analysis/port/B1-log.md` on `agent/B1`: the machine, the times for sync and build, the checks in steps 3 and 5, and the first error if any.

### P6: ROM build-error loop (free model, 1 agent, on the owner's machine)
Runs when B1's build fails (RUNBOOK §8b). Work in `device/samsung/gts4lv-common` of the synced tree, on branch
`port/dt-2` from `lineage-23.2`, with one commit per fix (trailer `Fix-by: <model>; <error line>`).
**Loop:** take the first error in `~/work/rom-build.log` → fix → `brunch gts4lvwifi 2>&1 | tee ~/work/rom-build.log` → repeat until the zip exists.
**Allowed:**
- sepolicy: add a missing type or label, or a narrow `allow` that names the exact source, target, class and permission from the denial;
- `proprietary-files.txt` / `blob_fixup()` entries (e.g. `replace_needed('libtinyxml2.so', 'libtinyxml2-v34.so')` as PORTING §2 describes);
- adding a missing package to `PRODUCT_PACKAGES`;
- removing a reference to a file or module 23.2 deleted, citing the LineageOS commit that deleted it.

**Forbidden** (escalate instead):
- `permissive` domains, wildcard `allow` rules, or `neverallow` exceptions;
- any `BUILD_BROKEN_*` flag;
- skipping VINTF checks (`PRODUCT_ENFORCE_VINTF_MANIFEST*`), or changing `target-level` (the owner decides that);
- raising `PRODUCT_SHIPPING_API_LEVEL` (R7: it would switch on the property-namespace check);
- editing any repo other than our device fork;
- the same error after 3 tries.

Log one line per fix in `analysis/port/P6-log.md` on `agent/P6`.

### P7: boot-log triage (free model, 1 agent, with the owner and the tablet)
After each flash that doesn't fully work. The free model collects and sorts the logs; the strong model diagnoses.
1. Collect, read-only, exactly as [TESTING.md](TESTING.md) says: `adb logcat -b all -d`, `adb shell dmesg`, `pstore`/`console-ramoops*` (copy it
   **before** another reboot; only the newest panic is kept), tombstones, and `scripts/device-checks.sh` if the tablet boots.
   Never run anything that flashes, wipes or formats; that's the owner's call (⚠️ in README).
2. Write `analysis/port/boot-<n>.md` (n = attempt number) on `agent/P7`:
   - build and commit IDs (kernel `port/pick`, device tree);
   - how far it got (no logo / bootloop / boots to UI);
   - the first 20 lines around the **first** error of each kind (kernel panic, `FATAL EXCEPTION`, `avc: denied`, `netbpfload`/`bpfloader`, `lmkd`, `AudioPolicy`), with timestamps;
   - your best guess, marked `confidence: low|medium|high`.
3. Put the raw logs in `analysis/port/boot-<n>/` (gzip anything over 1 MB). Then hand over to the strong model (RUNBOOK prompt R, "boot debugging").
   Kernel fixes then go through P4's rules on `port/pick`, device fixes through P6's rules on `port/dt-2`.

### Strong-model review (P1-R, P2-R, P4-R, P5-R, P6-R)
1. Run `python3 scripts/check-pick.py <kernel> pick-review`. It must say `problems: 0`.
2. Read **every** packet in `pick-review/full/` and every commit with a `Needs-review:` trailer.
3. Read 20% of `pick-review/spot/`, picked at random. If one is wrong, read the whole batch of 10 it came from.
4. Read every P2 `SUSPECT` and 10% of `BENIGN`.
5. Read every `fixes/` packet (P3, P4) and every P5 commit. They're small.
6. For anything wrong: don't rewrite history. Write the problem in `review-P*.md`. Either fix it yourself in a new commit (trailer `Fix-by: <model>; review`)
   or hand it back to the free agent with exact instructions.
7. When P1–P4 pass and `Image.gz-dtb` builds: fast-forward the fork's `lineage-23.2` to `port/pick`. Same for `port/dt` after P5-R.

---

## 7. Not for helper agents
- The reviews in round 4 (P1-R, P2-R, P4-R, P5-R) and every escalation: a strong model.
- Changes inside the BPF verifier/JIT (`kernel/bpf/`, `arch/arm64/net/`), if P4 escalates them.
- A full ROM build (~150 GB sync), flashing and first boot: the owner, with the tablet. Reading the boot logs: a strong model.
- Contacting krazey (ExyHyperBrick) before publishing the kernel branch.
- Track B (relaxing Android's kernel version checks).

## 8. Order and dependencies
```
Rounds 1–2:             done
Round 3, in parallel:   K7  K8  R7  R8  R9          (P1 may start at the same time)
Round 4 kernel:         P1 → P1-R and P2 (parallel) → P2-R → P3 (after K7) → P4 ⇄ P4-R → fast-forward lineage-23.2
Round 4 device tree:    (after R7–R9) P5 → P5-R → fast-forward lineage-23.2
Then:                   owner: ROM build, flash, boot (HANDOVER.md steps 6–8)
```

## 9. Common mistakes
- **Taking one side of a conflict whole.** A test build doing that failed in seconds ([build-test](analysis/build-test/README.md)). Always look at both sides.
- **Cloning ExyHyperBrick's original instead of our backup.** The original keeps moving. All numbers here are for `baa585f67e0e`.
- **Short SHAs that are ambiguous.** Use at least 12 characters.
- **Copying big code blocks.** Cite them instead (rule 7).
- **Saying "probably fine" without evidence.** Give a source or say `confidence: low`.
- **Killing a slow clone.** Wait. Big clones look stuck while they unpack.
- **Editing shared files** (`WORKLOG.md`, `HANDOVER.md`, `analysis/port/STATUS.md`). Don't; the owner or lead does. (P1 is the only agent that edits `analysis/port/dropped.tsv`.)
- **Writing outside your worktree.** Round 1 agents left a 2.3 GB clone, logs and junk files in shared folders. Put scratch files in `/tmp` or your own worktree.
- **Running `git checkout` in the shared kernel clone** when you're not P1/P3/P4. Use `git show <rev>:<file>` and `git grep <rev>` instead.
- **Rewriting pushed history** (`--force`, `rebase`, `reset --hard`, `--amend` after push) on `port/*`. Fix with a new commit.

## 10. Which model for which task
**Use the free model ("Space Bunny Free" on OpenCode) for every helper task**, including all of round 3 and the work steps of round 4
(P1–P5). Rounds 1–2 ran on it, and the review found the output sound: format 17/17, all 15 DROPs consistent, and 13 of 14 sampled
"already in sdm670?" answers matched directly (the 14th was right on reading).

Use a **strong model** (a frontier model, or Kimi K3 within its ≈490 requests/month) only for:
- the reviews (§11 and the round-4 `-R` steps), and
- escalations: anything a free agent marks `Needs-review:`, `## Blocked` or `## Escalated`.

If a free agent escalates more than about a third of its items, or the review rejects more than about a third, stop it. Hand the rest to the strong model:
past that point, review plus rework costs more than doing it directly.

Rough cost picture for round 4, from the dry run: the free model's work costs nothing. The strong model reads ~25 `full/` packets,
~12 of ~58 `spot/` packets, ~4 automerge packets, the P3/P4 fix commits and the escalations. The dry run's packets came to ≈280 KB
(≈70k tokens) for all 83 stops, so the review reads well under that. Doing the 83 resolutions itself would mean reading the same
material plus the briefs and the code around it, then writing the fixes.
Model names and limits come from third-party write-ups (opencode.ai is blocked from the cloud container). Check <https://opencode.ai/go>.

## 11. Reviewing the output (lead)
Checking costs much less than producing, because every claim cites a SHA or `file:line`. Order:
1. **Format, no AI needed:** `scripts/check-agent-output.sh` checks the header, the `Summary` and `Problems` sections,
   one brief per batch row, all brief sections present, and a valid resolution and confidence. Send failures back to the agent.
2. **Check fully:** every `DROP` (claims sdm670 already has the change; a wrong one silently loses code), every `low` and every `HUMAN`.
3. **Spot-check** about 20% of the `high`-confidence items per batch. If all hold up, accept the batch. If any fails, check that whole batch.
4. **K1:** rerun `make_map.py` and compare `sha256sum`. Then check 10 random rows by hand.
5. Record what was accepted in `WORKLOG.md`, and merge the `agent/*` branches into `main`.
