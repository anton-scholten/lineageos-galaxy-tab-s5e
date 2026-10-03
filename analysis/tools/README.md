# Tools recovered from the helper-agent run

Scripts and data that would otherwise have been lost in `/tmp`. Both Python scripts were written by
the **K2d-3** agent; the two `.txt` files were produced by the lead while verifying K5a's output.

## `replay_tree.py`, `replay_show.py` (from task K2d-3)

Reproduce the trial's **stacked** replay for a given set of paths, instead of an isolated
`git merge-tree` against pristine sdm670.

This matters because the two models disagree, and the stacked one is the correct one:

| model | over-reports | under-reports |
|---|---|---|
| isolated `merge-tree --write-tree --merge-base=C^ a30605a54f3b C` | flags files earlier commits have not created yet | can report success while emitting references to symbols earlier commits were meant to define |
| stacked replay (`trial.py` method) | — | can report `CLEAN` for a commit merged against a tree still carrying conflict markers |

`AGENT-TASKS.md` §K2 step 3 told the round-1/2 agents to use the isolated form (since corrected). Six agents independently reported
that it misleads. **K2d-3 validated the stacked form**: it reproduced `conflict_detail.tsv`'s file and
block counts for all 7 of its commits, while its isolated numbers over-reported on 2.

Usage. Both scripts `cd` into the kernel clone given by `$K670` (default `~/work/k670`):

```
python3 replay_tree.py <commit-sha> <path1,path2,...>
python3 replay_show.py <commit-sha> <path1,path2,...> [max_lines_per_block]
```

Expected kernel tree: sdm670 at `a30605a54f3b92627d868f169c72ef9c6ef82123`, series
`d54533f1546b91f94eb4e445dfea3a94ffa58a74..baa585f67e0efc9f1efa046d0b0e76955ca4c8d5`, with
`refs/remotes/exy/l222` and `exy/l232` fetched (see `AGENT-TASKS.md` §1.2).

These scripts create commits in the kernel clone (`git commit-tree`) as they replay. Point them at a
scratch clone, not the one other agents are reading.

## `k5a-compound16-blindspot.txt`

The 16 symbols from K5a's **first** push of `analysis/api-audit/changed-api.txt`, which used compound
names like `skb_shared_info.gso_type`. `git grep -w` **cannot match those** — it returns nothing, so an
agent auditing against that revision silently gets "0 hits" for 16 of 130 symbols.

K5a fixed this at `5d2fae520f0a22813e79b83b0d4328f8aa7f2402` (0 compound names). The final
`agent/K5a` has the corrected file, so merging K5a resolves it. Use this list to spot-check the K5b–f
audits; grep the part **after** the dot.

Verified clean against the two files K5d flagged as uncovered but which its defconfig builds
(`CONFIG_MSM_SMEM=y`, `CONFIG_QTI_QMI_COOLING_DEVICE=y`): 0 hits for all 139 symbols.

## `k5a-symbols-139.txt`

The 130 corrected symbols from `changed-api.txt` (at `5d2fae5`) plus the 16 bare tails from the file
above, deduplicated. Handy for re-running the K5 audits without re-deriving the list.

`changed-api.txt` only covers the 7 headers named in `AGENT-TASKS.md` §K5 step 1. Anything that broke in
`include/linux/if_ether.h`, `include/net/ip.h` or `include/uapi/linux/bpf.h` is **not** in this list and
has never been audited.
