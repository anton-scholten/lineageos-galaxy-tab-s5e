<!-- task: K2b-4 | agent: Space Bunny Free (opencode) | date: YYYY-MM-DD -->
# K2b-4: conflict briefs — 8 required/moderate commits

## Summary

8 briefs, one per row of `analysis/agent-batches/K2b-4.tsv`, plus this summary. All 8 commits are
`group = required`, `size_class = moderate` in `conflict_detail.tsv` — needed for eBPF, not optional.

Verdicts: **5 MERGE, 2 PREREQ, 1 DROP, 0 HUMAN.** Confidence: 4 high, 4 medium, 0 low.
No stop-and-ask trigger fired (0 of 8 HUMAN).

Two things the lead must look at first:

1. **`f0cedc3ccda4` is the batch's only DROP** — sdm670 already has the change, so it must be dropped
   rather than merged, or code is duplicated. It is the one item here where a wrong call loses or
   duplicates code silently, so it is the one to re-check.
2. **`bca02018e7d0` has a 17-file isolated conflict list but only 1 real conflict.** This is the
   batch's methodological trap; the brief explains why the trial's single-file record is the correct
   work item. Two other agents in this batch independently hit the same over-reporting, so the pattern
   is general, not local.

Nothing in this batch proposed a resolution that requires a decision the lead cannot make from the
brief alone.

## Verdicts

| commit | subject | resolution | confidence |
|---|---|---|---|
| `0b68a58910d8` | BACKPORT: hrtimer: Unify hrtimer removal handling | MERGE | medium |
| `0ee2af35b905` | BACKPORT: bpf: tcp: Add bpf_skops_established() | PREREQ | medium |
| `1aadd98f9f8f` | BACKPORT: hrtimer: Make the remote enqueue check unconditional | MERGE | high |
| `2c3ab8405d6a` | BACKPORT: hrtimer: Prepare handling of hard and softirq based hrtimers | PREREQ | high |
| `bca02018e7d0` | BACKPORT: bpf: Implement CAP_BPF | MERGE | high |
| `d3d19b1558f4` | BACKPORT: hrtimer: Use irqsave/irqrestore around __run_hrtimer() | MERGE | high |
| `eb8726624efa` | BACKPORT: bpf: Add BPF LSM program support | MERGE | medium |
| `f0cedc3ccda4` | BACKPORT: bpf: Complete generic XDP map redirects | DROP | high |

## Notes on the batch

- Four commits are the `hrtimer` cleanup series (`0b68a58910d8`, `1aadd98f9f8f`, `2c3ab8405d6a`,
  `d3d19b1558f4`). They touch the same file and same state machine, so they should be resolved as a
  group against the final hrtimer layout, not one at a time in isolation. Each brief says which
  sdm670 CAF state (`HRTIMER_STATE_PINNED`, `cpu_base->running`) must survive.
- The two PREREQs name earlier series commits that the trial replayed `CLEAN`, so an in-order replay
  satisfies them automatically. They are ordering statements, not blockers — do **not** cherry-pick
  them against the bare tree.
- `eb8726624efa` (BPF LSM) depends on the `CONFIG_BPF_LSM` defconfig work; see
  `analysis/defconfig/` from task K6, which found `BPF_LSM` is currently **silently dropped** because
  none of its four dependencies are enabled in `gts4lv_defconfig`.
- `bca02018e7d0`'s `CAP_BPF`/`bpf_capable()` symbols come from `82aca390d199` (trial-`CLEAN`), so the
  capability gate compiles in series order but not out of order.

## How the batch was produced

Each commit was examined with `git show --stat`, the upstream trailer read from the message using the
K1 patterns (a `Change-Id:` trailer is a Gerrit ID and was never counted as a SHA), an isolated
`git merge-tree --write-tree --merge-base=C^ a30605a54f3b C`, and a presence check in sdm670 using at
least one line the commit *adds*. Every claim in every brief cites a 12+ character SHA or a
`file:line @ a30605a54f3b`. The shared kernel tree was read-only throughout: HEAD stayed at
`a30605a54f3b` and no ref was created, moved or deleted.

## Problems

Two agents were originally assigned this batch and terminated without handing in. This summary and the
`bca02018e7d0` brief were completed by the lead; the other 7 briefs are those agents' work, unmodified.
`bca02018e7d0` is the only file here not produced by the batch's original agent — worth knowing when
spot-checking, since it has had one reviewer rather than two.
