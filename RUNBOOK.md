# Runbook: finishing the port with the free model

For the **owner**. It says what to start, in which order, with which prompt, and what to check before going on.
The agents' own instructions are in [AGENTS.md](AGENTS.md) and [AGENT-TASKS.md](AGENT-TASKS.md). Progress is tracked in
[analysis/port/STATUS.md](analysis/port/STATUS.md).

> **Where we are (2026-10-04):** steps 1–6 are done and every 🔍 review has passed ([review-P4.md](analysis/port/review-P4.md)).
> The kernel builds. **Next: step 7 (you, minutes), then step 8a (B1, a free agent builds the ROM on your machine).**

**Roles**
- **Free model** ("Space Bunny Free" in OpenCode): every work step.
- **Strong model** (Claude, or another frontier model): the review steps marked 🔍, and anything a free agent escalates.
  If you have no strong model, see "Without a strong model" at the end.
- **You:** start agents, run the checks in this file, merge, and do the ROM build, flashing and testing.

---

## 0. One-time setup (≈30 min)

1. **Machine:** Linux, macOS or WSL2, about 20 GB free for steps 1–5, and **≈300 GB + 16 GB RAM for step 6** (the ROM build).
   Tools: [AGENT-TASKS.md §1.0](AGENT-TASKS.md#10-prerequisites), plus the build tools in §6c P4.
2. **Folder layout** (every prompt below assumes it):
   ```bash
   mkdir -p ~/work && cd ~/work
   git clone https://github.com/anton-scholten/lineageos-galaxy-tab-s5e docs          # private: use your token
   # Kernel clone, ≈2.3 GB, 10–30 min (AGENT-TASKS §1.2):
   git clone --single-branch -b lineage-23.2 https://github.com/anton-scholten/android_kernel_samsung_sdm670 k670
   cd k670 && git remote add exy https://github.com/anton-scholten/android_kernel_samsung_exynos9810
   git fetch --no-tags exy lineage-22.2:refs/remotes/exy/l222 lineage-23.2:refs/remotes/exy/l232
   ```
   **One worktree per agent, so agents never share a checkout:**
   `git -C ~/work/docs worktree add ~/work/wt/<task-id> -b agent/<task-id> origin/main`.
   Agents that only *read* the kernel can share `~/work/k670`. **Only P1/P3/P4 write to it**, one at a time.
3. **Tokens** (GitHub → Settings → Developer settings → Fine-grained tokens, 30-day expiry):
   - `docs-token`: repo `lineageos-galaxy-tab-s5e`, *Contents: Read and write*. Used by every agent.
   - `fork-token`: repos `android_kernel_samsung_sdm670` + `android_device_samsung_gts4lv-common`, *Contents: Read and write*. Only for P1, P3, P4, P5.
4. **Protect the real branches.** In each fork: Settings → Branches → add a rule for `lineage-23.2` → restrict pushes to you.
   In this repo, the same for `main`. Agents then *can't* break those branches, even by mistake.

---

## 1. ✅ Round 3 research (done 2026-10-03)

Start one agent per ID: `K7`, `K8`, `R7`, `R8`, `R9`. Prompt (change `<ID>`):
```text
You are a helper agent. Work in ~/work/wt/<ID> (git repo anton-scholten/lineageos-galaxy-tab-s5e, branch agent/<ID>).
Your task ID is <ID>. Read AGENTS.md, then AGENT-TASKS.md sections 0, 1, 9, 2.2 and the section for <ID> (section 6b).
The kernel clone is ~/work/k670 (read-only for you). Follow the steps exactly, run the self-check,
then commit and push branch agent/<ID>. If anything fails twice, write it under "## Problems" and stop. Don't guess.
```
**Check before step 2:** `bash scripts/check-agent-output.sh` prints `OK` (K8 also: `scripts/check-agent-output.sh K8`).
Then 🔍 review (prompt R below), and merge the `agent/*` branches into `main` (GitHub "Compare & pull request" → merge, or `git merge` locally).
P1 doesn't need to wait for this; P3 needs K7, and P5 needs R7–R9.

## 2. ✅ P1: kernel cherry-pick (done 2026-10-03)
```text
You are a helper agent doing task P1 (AGENT-TASKS.md §6c). Docs repo: ~/work/wt/P1 (branch agent/P1). Kernel clone: ~/work/k670.
Read AGENTS.md, then AGENT-TASKS.md sections 0, 1, 9, 2.3 and 6c ("Shared setup" and "P1") completely before starting.
Use the fork token for pushes to the kernel fork, branch port/pick ONLY. Never push anywhere else in the kernel fork.
Loop: run scripts/pick-series.sh, resolve the stop exactly as its brief says, run the self-check, continue.
Escalate instead of guessing (step 6). Push every 10 resolutions. Stop when pick-series.sh exits 0
and scripts/check-pick.py prints "problems: 0".
```
It runs long, so it's fine to restart the agent with the same prompt: the script resumes where it stopped.
**Check:** `python3 ~/work/docs/scripts/check-pick.py ~/work/k670 ~/work/pick-review` → `problems: 0`. Look at `## Blocked` in `analysis/port/P1-log.md`.

## 3. ✅ 🔍 P1-R review, and P2 triage (done 2026-10-04)
- **P2** (free, 1–4 agents, IDs `P2-1`…): split `~/work/pick-review/automerge/` alphabetically. Prompt as in step 1 with the ID `P2-<n>`, plus "Your files: <list>".
- **P1-R** (strong): prompt R below, with "task P1-R: AGENT-TASKS.md §6c 'Strong-model review' steps 1–3 and 6, for P1; packets in ~/work/pick-review".
- Rejected items go back to the P1 agent: start it with the P1 prompt plus "Apply the fix requests in analysis/port/review-P1.md as new commits with a Fix-by trailer".
- Then 🔍 **P2-R**: the strong model reads every SUSPECT and 10% of BENIGN.

## 4. ✅ P3: known fixes + defconfig (done 2026-10-04)
Make the worktree first: `git -C ~/work/docs fetch origin && git -C ~/work/docs worktree add ~/work/wt/P3 -b agent/P3 origin/main`.
```text
You are a helper agent doing task P3. Docs repo: ~/work/wt/P3 (branch agent/P3). Kernel clone: ~/work/k670.
Read AGENTS.md, then AGENT-TASKS.md sections 0, 1, 9 and 6c ("Shared setup" and "P3") completely, plus analysis/port/review-P1.md.
Work on kernel branch port/pick ONLY: start by fast-forwarding it to origin/port/pick as P3's first paragraph says.
Make exactly the 6 commits P3 lists, in order, each with its "Fix-by:" trailer, and run each item's check. Push port/pick after each commit.
If a line number or file doesn't match what the spec says, stop and write it under "## Problems" in analysis/port/P3-log.md. Don't guess.
When done, commit and push analysis/port/P3-log.md on branch agent/P3.
```
**Check:** `git -C ~/work/k670 log --oneline d73f07cf8b5c..origin/port/pick` shows 6 `P3:` commits, and
`python3 ~/work/docs/scripts/check-pick.py ~/work/k670 ~/work/pick-review` says `problems: 0` with `fix commits: 6`.
P3 is small and fully specified, so a strong review is optional. If you want one, give prompt R the task "P3 review: read pick-review/fixes/".

## 5. ✅ P4: build loop (done 2026-10-04) — both defconfigs link `Image.gz-dtb`; 🔍 P4-R still open

⚠️ **Rebuilding needs `~/work/llvmbin` on `PATH`.** Debian's `llvm-19` ships only versioned names
(`llvm-nm-19`) but kbuild's `LLVM=1` wants unversioned ones. Without the symlinks the build **still exits 0** while
`vdso_offset_sigtramp` is generated wrong — a silently broken sigreturn trampoline, not a build error:

```bash
mkdir -p ~/work/llvmbin
for f in /usr/bin/llvm-*-19; do ln -sf "$f" ~/work/llvmbin/"$(basename "$f" -19)"; done
export PATH="$HOME/work/llvmbin:$PATH"
```

`dtc` is not needed and is not in the §6c P4 list: arm64 `.dtsi` files compile through clang.
Needs P3. Install the build tools first: AGENT-TASKS §1.0 plus §6c P4
(`clang lld flex bison libssl-dev binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi gcc-aarch64-linux-gnu dwarves`).
Worktree: `git -C ~/work/docs worktree add ~/work/wt/P4 -b agent/P4 origin/main`.
```text
You are a helper agent doing task P4. Docs repo: ~/work/wt/P4 (branch agent/P4). Kernel clone: ~/work/k670, branch port/pick.
Read AGENTS.md, then AGENT-TASKS.md sections 0, 1, 9 and 6c ("Shared setup" and "P4") completely, plus analysis/port/review-P1.md.
First fast-forward port/pick to origin/port/pick. Then loop: build with
  bash ~/work/wt/P4/analysis/build-test/kbuild.sh ~/work/k670 ~/work/out ~/work/build.log
take the FIRST error in ~/work/build.log, fix it with an allowed fix only, commit with a "Fix-by:" trailer, push port/pick, repeat.
Apply the two "Expect early" decisions exactly as written. Never use a forbidden fix: write it under "## Escalated" in
analysis/port/P4-log.md, commit and push that log on agent/P4, and stop. Done when ~/work/out/arch/arm64/boot/Image.gz-dtb exists
for gts4lvwifi_defconfig and then for gts4lv_defconfig.
```
When it stops on `## Escalated`: give that entry to the strong model (prompt R, task "P4 escalation: <paste>"). Then start P4 again with the same prompt;
it continues from where the branch is.
🔍 **P4-R:** every couple of days, and at the end, prompt R with task "P4-R: review pick-review/fixes/ since the last review".
Run `check-pick.py` first so the packets are fresh.
**Done when** both builds produce `Image.gz-dtb`, and `check-pick.py` says `problems: 0`.

## 6. ✅ P5: device-tree commit (done 2026-10-04) — 1 commit on `port/dt`; 🔍 P5-R still open
Can run now, in parallel with P3/P4. Device-tree clone:
`git clone -b lineage-23.2 https://github.com/anton-scholten/android_device_samsung_gts4lv-common ~/work/dt` (push access via your SSH key or `fork-token`).
Worktree: `git -C ~/work/docs worktree add ~/work/wt/P5 -b agent/P5 origin/main`.
```text
You are a helper agent doing task P5. Docs repo: ~/work/wt/P5 (branch agent/P5). Device-tree clone: ~/work/dt.
Read AGENTS.md, then AGENT-TASKS.md sections 0, 1, 9 and 6c ("P5") completely, plus analysis/port/review-P1.md.
In ~/work/dt create branch port/dt from lineage-23.2. Make the ONE commit P5 item 1 describes (audio policy XML lists comma -> space),
check every changed XML with xmllint --noout, and push port/dt (never lineage-23.2).
Then write analysis/port/P5-log.md listing each skipped item from P5 item 2 as "considered, intentionally skipped" with its reason,
and commit and push it on agent/P5.
```
🔍 **P5-R:** prompt R with task "P5-R: review device fork port/dt against AGENT-TASKS §6c P5 and R6".

## 7. Move the real branches forward (you, minutes)
After all 🔍 reviews pass:
```bash
cd ~/work/k670 && git fetch origin && git push origin origin/port/pick:refs/heads/lineage-23.2   # must be a fast-forward
cd ~/work/dt   && git fetch origin && git push origin origin/port/dt:refs/heads/lineage-23.2
```
If GitHub refuses ("non-fast-forward"), stop and ask the strong model. Never force-push.

## 8. ROM build, flash, test (you + tablet, ≈2–3 weeks)
### 8a. B1: sync and first build (1 free agent on your machine: ≥300 GB disk, ≥16 GB RAM, ≈½–1 day unattended)
Needs step 7. Worktree: `git -C ~/work/docs fetch origin && git -C ~/work/docs worktree add ~/work/wt/B1 -b agent/B1 origin/main`.
```text
You are a helper agent doing task B1. Docs repo: ~/work/wt/B1 (branch agent/B1). Build tree: ~/android/lineage (create it).
Read AGENTS.md, then AGENT-TASKS.md sections 0, 9 and 6c ("B1") completely. First run B1's pre-check (both forks' lineage-23.2
must already point at the port); if it fails, stop and tell the owner. Then install the build packages and repo, sync, verify
the kernel and device-tree commits, and build with:  source build/envsetup.sh && brunch gts4lvwifi 2>&1 | tee ~/work/rom-build.log
Do not fix build errors yourself. Write analysis/port/B1-log.md, commit and push it on agent/B1, and stop.
```
The apt install needs `sudo`: run it yourself first if the agent can't. **Done when** the zip exists (B1-log.md has its path and sha256).
If the build failed, go to 8b.

### 8b. P6: ROM build-error loop (1 free agent) with 🔍 P6-R
Most errors will be in the device tree (sepolicy neverallows, VINTF, blob linkage). Worktree: `git -C ~/work/docs worktree add ~/work/wt/P6 -b agent/P6 origin/main`.
```text
You are a helper agent doing task P6. Docs repo: ~/work/wt/P6 (branch agent/P6). Android tree: ~/android/lineage (synced, lineage-23.2).
Read AGENTS.md, AGENT-TASKS.md sections 0, 9 and 6c ("P6"), plus analysis/port/review-P1.md and review-P4.md.
Take the FIRST error in ~/work/rom-build.log. Fix it in device/samsung/gts4lv-common on a branch port/dt-2 (from lineage-23.2) with one commit
per fix and a "Fix-by:" trailer, using only the allowed fixes in AGENT-TASKS 6c P6. Rebuild with
  source build/envsetup.sh && brunch gts4lvwifi 2>&1 | tee ~/work/rom-build.log
and repeat. Push port/dt-2 after each fix (never lineage-23.2). Escalate anything forbidden under "## Escalated" in
analysis/port/P6-log.md and stop. Done when the build produces out/target/product/gts4lvwifi/lineage-23.2-*.zip.
```
A kernel error in the ROM build goes back to P4's rules on `port/pick`. 🔍 P6-R: prompt R, task "P6-R: review port/dt-2".
Then fast-forward the device fork's `lineage-23.2` to `port/dt-2`, the same way as step 7.

### 8c. Flash and first boot (you + tablet), with P7 log triage
1. ⚠️ **Unlocking the bootloader and installing erase all data on the tablet.** Back up first ([README.md](README.md) "Back up first").
2. Flash: [README.md](README.md) path A (from stock) or B (from 22.2), using the zip, `recovery.img` and `vbmeta.img` from
   `out/target/product/gts4lvwifi/`. ⚠️ Path B from official 22.2 to this unofficial build also needs a data wipe (different signing keys).
3. Whatever happens, collect logs with a free agent (P7). Worktree `~/work/wt/P7` on `agent/P7`. Prompt:
   ```text
   You are a helper agent doing task P7, flash attempt <n>. Docs repo: ~/work/wt/P7 (branch agent/P7). The tablet is on USB with adb.
   Read AGENTS.md, AGENT-TASKS.md sections 0, 9 and 6c ("P7"), and TESTING.md. Collect the logs read-only exactly as P7 says (copy pstore
   BEFORE any reboot), write analysis/port/boot-<n>.md and the raw logs, commit and push on agent/P7, and stop.
   Never flash, wipe, format or reboot into download mode.
   ```
4. Give `boot-<n>.md` to the strong model (prompt R, task "boot debugging: analysis/port/boot-<n>.md"). Its fixes go to a free agent:
   kernel fixes with P4's rules on `port/pick`, device fixes with P6's rules on `port/dt-2`. Then rebuild (8a step 4 only) and flash again.
5. Early checks once it boots: Wi-Fi, audio playback and the mic (P5's change), `adb logcat -d | grep -iE 'lmkd|AudioPolicy|netbpfload|bpfloader'`.

### 8d. Test and finish
1. `scripts/device-checks.sh`, then 24 h of normal use, then repeat 8a–8c for the LTE model (`brunch gts4lv`).
2. Contact krazey (ExyHyperBrick) before publishing the kernel.

---

## Prompt O: free-model orchestrator (optional)
If you'd rather not run the steps yourself, a free-model session can run them, the way the round-1–3 lead did:
```text
You are the orchestrator for the LineageOS 23.2 Tab S5e port. Docs repo: ~/work/docs. Read CLAUDE.md, HANDOVER.md, RUNBOOK.md and
analysis/port/STATUS.md. Start the next agents RUNBOOK.md says are ready, each in its own worktree with its RUNBOOK prompt, and run the
RUNBOOK checks when they finish. Update analysis/port/STATUS.md and WORKLOG.md on a branch named lead/<date> and push it.
You may NOT: do any step marked 🔍 (ask the owner for a strong model, or for permission to use the "Without a strong model" fallback);
push to main or to any lineage-23.2 branch; force-push; delete branches. Stop and report to the owner when a step is blocked or done.
```

## Prompt R: strong-model review
```text
You are the reviewing lead for the LineageOS 23.2 Tab S5e port. Repo: ~/work/docs (read CLAUDE.md, HANDOVER.md, LEAD-SYNTHESIS.md first).
Task: <P1-R | P2-R | P4-R | P5-R | review round 3 | P4 escalation: paste the entry>.
Follow AGENT-TASKS.md §11 (research) or §6c "Strong-model review" (port). Check claims against the kernel tree ~/work/k670, not just the reports.
Never rewrite history or force-push. Write findings to analysis/port/review-<step>.md, and fix requests the free agent can follow exactly.
Update analysis/port/STATUS.md and WORKLOG.md when done.
```

## Without a strong model
The free model can review too, but not as well. If you must:
- Use a **fresh session** with prompt R, so it doesn't review its own work from memory. Add: "Reject anything you can't prove from the code. When unsure, reject."
- Always fully review `pick-review/full/` and every `Needs-review:` commit. Raise the spot-check to 50%.
- Let the compiler be the referee: P4 reaching `Image.gz-dtb` catches many bad resolutions. Booting catches more. Expect a longer step 8.
- Never let the free model handle `## Escalated` items in `kernel/bpf/`, `arch/arm64/net/` or `mm/` alone. Ask on the XDA thread or contact krazey.
