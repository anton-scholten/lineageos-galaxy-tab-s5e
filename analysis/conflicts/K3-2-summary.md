<!-- task: K3-2 | agent: space-bunny-free | date: 2026-10-03 -->
# K3-2 summary: large conflicts, facts only

## Summary
Three `large` commits from `analysis/agent-batches/K3-2.tsv`, briefed as **facts only — no resolution proposed anywhere**
(the K3 rule: that section is replaced by `## Notes for the lead`). Each brief covers author/date, upstream SHA,
every conflicting file with a per-block description of the *ours* (sdm670 `a30605a54f3b`) and *theirs* (series `baa585f67e0e`
lineage) content, an "already in sdm670?" check with at least two greps, a `## Notes for the lead` section (observations, no
verdicts) and a `## Later series commits touching the same files` section with the `git log --oneline C..baa585f67e0e` output
per file.

| commit | subject | size_class | upstream | conflicting files (standalone merge-tree) | blocks examined | later series commits per file | sdm670 already has it? |
|---|---|---|---|---|---|---|---|
| `462a37becb45` | BACKPORT: ANDROID: fuse-bpf: Add request dispatcher | large | `57f3ff964899` | 2 (`fs/fuse/Makefile`, `fs/fuse/fuse_i.h`) | 2 | Makefile 1, fuse_i.h 27, backing.c 27 | no (4 greps, 0 hits) |
| `8381dabde508` | BACKPORT: hrtimer: Implement support for softirq based hrtimers | large | `5da70160462e` | 2 (`include/linux/hrtimer.h`, `kernel/time/hrtimer.c`) | 17 | hrtimer.h 0, hrtimer.c 1 | partly: 6 identifiers absent, 2 same-named functions with older signatures |
| `4d161a754796` | BACKPORT: bpf: tcp: Add bpf_skops_hdr_opt_len() and bpf_skops_write_hdr_opt() | large | `331fca4315ef` | 5 standalone (3 real: `net/ipv4/tcp_ipv4.c`, `net/ipv4/tcp_output.c`, `net/ipv6/tcp_ipv6.c`) | 5 (3 in the real files) | tcp_ipv4.c 1, tcp_output.c 2, tcp_ipv6.c 0, uapi/bpf.h 30, tools/uapi/bpf.h 22 | no (8 greps, 0 hits) |

Method notes the lead should know:
- Every conflict inventory comes from `git -C ~/work/k670 merge-tree --write-tree --merge-base=C^ a30605a54f3b C`
  and the resulting tree IDs (`fcd0eac2dfc9`, `42e320edfa8d`, `650f8baceb4c`). The kernel tree was only read; no ref moved.
- `conflict_detail.tsv` block counts (4, 12, 8) do **not** match the standalone counts (2, 17, 5). The trial replayed the
  series stacked, so its hunks differ from a per-commit test. Both numbers are stated in each brief.
- The three standalone block counts do not match the batch's `size_class=large` intuition either: `462a37becb45` and
  `4d161a754796` have very few blocks, but very large ones (557-line hunk in each `bpf.h`; 177-line add in `fuse_i.h`).

Cross-cutting facts that apply to more than one commit in this batch:
1. sdm670 descends from a Qualcomm `msm-4.9` line while the series source is a Samsung Exynos 4.9.337 tree; both report
   `VERSION/PATCHLEVEL/SUBLEVEL 4/9/337` and `NAME = Roaring Lionus` (`a30605a54f3b:Makefile`, `8381dabde508:Makefile`), so
   the differences are vendor divergences, not version gaps.
2. `merge-tree` silently *drops* anything sdm670 deleted relative to the merge base, even when the commit's own hunks need
   it. This bit `8381dabde508` (the `HRTIMER_MODE_SOFT` / `HRTIMER_BASE_*_SOFT` / `MASK_SHIFT` / `HRTIMER_ACTIVE_*`
   infrastructure disappeared while the conflicting hunks that use it survived) and produced the two phantom `bpf.h`
   hunks in `4d161a754796`.
3. Each commit in this batch has at least one earlier series commit that the trial recorded as `CONFLICT`, so the tree these
   commits were tried against was missing pieces the commits expect. Named per commit in the briefs
   (`435bb390114e` for the fuse case, `2c3ab8405d6a`/`d3d19b1558f4`/`0b68a58910d8` for the hrtimer case).

## Problems
- `/tmp/opencode/blocks.py` (a shared temp path recommended by the harness) was overwritten by another agent while I was
  using it. I moved my helper to `/tmp/opencode/k3-2/blocks.py`. No fact in any brief depends on it.
- `analysis/conflicts/` did not exist in my worktree; I created it. Other K3 agents writing to the same directory on their
  own branches may hit a directory-creation race on merge.
- No kernel command failed twice; nothing in the kernel tree was modified.