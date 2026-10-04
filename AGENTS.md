# AGENTS.md: start here (any AI agent)

You are a helper agent on a project to port LineageOS 23.2 (Android 16) to the Samsung Galaxy Tab S5e.
This repo holds **docs, analysis, reports and scripts**, not Android source code. There are two kinds of tasks:
- **Research** (rounds 1–3, all done): you write a report into this repo. You don't change any kernel or device code.
- **Port** (round 4: P1–P5 done; **B1, P6, P7 open**): you change the kernel or device tree, but **only on a `port/*` branch** of the fork, following a brief or a spec exactly.
  A stronger model reviews everything you do.

The owner runs the project from [RUNBOOK.md](RUNBOOK.md). That's where your prompt came from.

## Your first 5 minutes
1. **Get your task ID.** Your prompt should name it. The open tasks are `B1` (ROM sync + build), `P6` (ROM build errors) and `P7` (boot-log triage), all in AGENT-TASKS.md §6c. B1 waits for the owner's RUNBOOK step 7. If it doesn't name one, **stop and ask**.
   Don't pick one yourself, because another agent may be doing it.
2. Read [`AGENT-TASKS.md`](AGENT-TASKS.md):
   - §0, all of it: project, words, repos, rules, how to hand in.
   - §1, setup and prerequisites.
   - §2.2 (round 3) or §2.3 (round 4): your row.
   - Your task's spec: §6b for K7, K8, R7, R8, R9. §6c for P1–P5 (read its "Shared setup" too).
   - §9, common mistakes.
3. Check your machine has what your task needs ([§1.0](AGENT-TASKS.md#10-prerequisites)).
4. Work in the folder your prompt gives you (normally `~/work/wt/<task-id>`, already on branch `agent/<task-id>`).
   If you have no worktree: `git checkout -b agent/<task-id> origin/main`.
5. Do the task. Run its self-check. Hand in (§0.5).

Background, if you need it:

| File | What it is |
|---|---|
| [`HANDOVER.md`](HANDOVER.md) | Current state and plan of the whole project |
| [`LEAD-SYNTHESIS.md`](LEAD-SYNTHESIS.md) | Findings from earlier research: known breakages and traps |
| [`analysis/conflicts/`](analysis/conflicts/) | One brief per conflicting kernel commit. **P1 follows these** |
| [`analysis/port/`](analysis/port/README.md) | Round-4 working files: `STATUS.md`, **`review-P1.md` and `review-P4.md` (reviewer decisions you must follow)**, `dropped.tsv`, `duplicate-picks.md` |
| [`analysis/agent-batches/`](analysis/agent-batches/) | Input lists for conflict-brief tasks |
| [`analysis/reference-trees/README.md`](analysis/reference-trees/README.md) | Other device trees that already did 23.2 |
| `CLAUDE.md` | Notes for the reviewing lead. Not for you |

## Hard rules (full list in AGENT-TASKS.md §0.4)
- Write **only** what your task names. In this repo, commit to `agent/<task-id>` only. Never push to `main`.
- Kernel and device repos are read-only, **except** round-4 tasks, which push only to `port/pick` (kernel fork) or `port/dt` / `port/dt-2` (device fork).
  Never push to `lineage-23.2`, never force-push, never rebase or amend pushed commits.
- Don't edit `WORKLOG.md`, `HANDOVER.md`, `README.md`, `AGENTS.md`, `AGENT-TASKS.md`, `RUNBOOK.md` or `analysis/port/STATUS.md`.
- Every fact needs a source (12+ character SHA, `file:line @ commit`, or URL), plus a confidence level.
- In code: never delete or disable code to make an error go away, and never take one side of a conflict blindly. Escalate instead (§6c).
- Stuck, or a command failed twice: write what happened under `## Problems` (or `## Blocked` / `## Escalated` in round 4), hand in what you have, and stop. Don't guess.
