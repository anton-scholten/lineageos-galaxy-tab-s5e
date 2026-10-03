# Runbook: finishing the port with the free model

For the **owner**. It says what to start, in which order, with which prompt, and what to check before going on.
The agents' own instructions are in [AGENTS.md](AGENTS.md) and [AGENT-TASKS.md](AGENT-TASKS.md). Progress is tracked in
[analysis/port/STATUS.md](analysis/port/STATUS.md).

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

## 1. Round 3 research (5 free agents in parallel, ≈½ day)

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

## 2. P1: kernel cherry-pick (1 free agent, sequential, ≈2–4 days)
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

## 3. 🔍 P1-R review, and P2 triage (in parallel, ≈1–2 days)
- **P2** (free, 1–4 agents, IDs `P2-1`…): split `~/work/pick-review/automerge/` alphabetically. Prompt as in step 1 with the ID `P2-<n>`, plus "Your files: <list>".
- **P1-R** (strong): prompt R below, with "task P1-R: AGENT-TASKS.md §6c 'Strong-model review' steps 1–3 and 6, for P1; packets in ~/work/pick-review".
- Rejected items go back to the P1 agent: start it with the P1 prompt plus "Apply the fix requests in analysis/port/review-P1.md as new commits with a Fix-by trailer".
- Then 🔍 **P2-R**: the strong model reads every SUSPECT and 10% of BENIGN.

## 4. P3: known fixes + defconfig (1 free agent, ≈½ day)
Needs K7 merged. Prompt: the P1 prompt with "task P3 (AGENT-TASKS.md §6c P3)". Writes to `port/pick`.

## 5. P4: build loop (1 free agent, ≈3–9 days) with 🔍 P4-R
Prompt: the P1 prompt with "task P4 (AGENT-TASKS.md §6c P4). Build with analysis/build-test/kbuild.sh. Never use a forbidden fix; escalate instead."
When it stops with `## Escalated` in `P4-log.md`: give that entry to the strong model (prompt R, task "P4 escalation"). Then restart P4.
🔍 P4-R: every few days, the strong model reviews the new `fixes/` packets (`check-pick.py` writes them).
**Done when** `~/work/out/arch/arm64/boot/Image.gz-dtb` exists and `check-pick.py` says `problems: 0`.

## 6. P5: device-tree commits (1 free agent, ≈½–1 day) with 🔍 P5-R
Needs R7–R9 merged. Prompt: "task P5 (AGENT-TASKS.md §6c P5)", device-tree clone in `~/work/dt`, branch `port/dt`.

## 7. Move the real branches forward (you, minutes)
After all 🔍 reviews pass:
```bash
cd ~/work/k670 && git fetch origin && git push origin origin/port/pick:refs/heads/lineage-23.2   # must be a fast-forward
cd ~/work/dt   && git fetch origin && git push origin origin/port/dt:refs/heads/lineage-23.2
```
If GitHub refuses ("non-fast-forward"), stop and ask the strong model. Never force-push.

## 8. ROM build, flash, test (you + tablet, ≈2–3 weeks)
1. Build: [PORTING-LINEAGE-23.2.md §3](PORTING-LINEAGE-23.2.md#3-building). Use `brunch lineage_gts4lvwifi`, **not** a bare `m`
   ([LEAD-SYNTHESIS.md §7.1](LEAD-SYNTHESIS.md)). Give build errors to a free agent (prompt R-style, "fix this build error in the device fork, port/dt").
2. Flash: [README.md](README.md) path A or B. ⚠️ **Unlocking and installing erases all data on the tablet.** Back up first.
3. If it doesn't boot: collect logs as in [TESTING.md](TESTING.md) after **every** crash (pstore keeps only the newest), and give them to the strong model.
4. Once it boots: `scripts/device-checks.sh`, then 24 h of normal use, then the LTE model.
5. Contact krazey (ExyHyperBrick) before publishing the kernel.

---

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
