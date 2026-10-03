# AGENTS.md: start here (any AI agent)

You are a helper agent on a project to port LineageOS 23.2 (Android 16) to the Samsung Galaxy Tab S5e.
This repo holds **docs, analysis and reports**, not Android source code. Your job is one small **research task**.
You write a report into this repo. You don't change any kernel or device code.

## Your first 5 minutes
1. **Get your task ID.** Whoever started you should have given one, like `K2a-3`, `R6` or `T1`.
   If you didn't get one, **stop and ask**. Don't pick one yourself, because other agents may be doing it.
2. Read [`AGENT-TASKS.md`](AGENT-TASKS.md):
   - §0, all of it: project, words, repos, rules, how to hand in.
   - §1, setup.
   - Your task's own section. Find it by searching for your task ID's letter and number, e.g. `### K2`, `| R6 |`.
   - §9, common mistakes.
3. Check your machine has what your task needs ([§1.0 of AGENT-TASKS.md](AGENT-TASKS.md#10-prerequisites)).
4. Make your branch: `git checkout -b agent/<task-id> origin/main`.
5. Do the task. Run its self-check. Hand in (§0.5).

You don't need to read the other docs. If you want background:

| File | What it is |
|---|---|
| [`HANDOVER.md`](HANDOVER.md) | Current state of the whole project |
| [`analysis/exyhyperbrick-trial/README.md`](analysis/exyhyperbrick-trial/README.md) | How the 150 conflicts were found |
| [`analysis/agent-batches/`](analysis/agent-batches/) | Input lists for the K2/K3 tasks (one file per batch) |
| [`analysis/reference-trees/README.md`](analysis/reference-trees/README.md) | Input for tasks R6/R7 |
| `CLAUDE.md` | Notes for the lead agent. Not for you |

## Hard rules (full list in AGENT-TASKS.md §0.4)
- Write **only** to the output path your task names. Commit to `agent/<task-id>` only. Never push to `main`.
- Never push to any other repo. Kernel and device repos are clone-and-read only.
- Don't edit `WORKLOG.md`, `HANDOVER.md`, `README.md`, `AGENTS.md` or `AGENT-TASKS.md`.
- Every fact needs a source (12+ character SHA, `file:line @ commit`, or URL), plus a confidence level.
- Stuck, or a command failed twice: write what happened under `## Problems`, then hand in what you have. Don't guess.
- Don't run anything that flashes, wipes or formats a device. Don't install software system-wide unless your task's prerequisites say so.

## Prompt the owner can paste to start an agent
```text
You are working in the git repo https://github.com/anton-scholten/lineageos-galaxy-tab-s5e (branch main).
Your task ID is <TASK-ID>. Read AGENTS.md, then AGENT-TASKS.md sections 0, 1, 9 and the section for <TASK-ID>.
Follow the steps exactly, run the self-check, and push your output on branch agent/<TASK-ID>.
If anything is unclear or fails twice, write it under "## Problems" and stop. Don't guess.
```
