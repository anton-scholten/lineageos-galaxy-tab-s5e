<!-- task: K3-1 | agent: Space Bunny Free | date: 2026-10-03 -->
# K3-1: large conflicts, facts only — batch summary

## Summary
Facts-only briefs for the 3 `large` commits in `analysis/agent-batches/K3-1.tsv`. No resolution is
proposed anywhere in this batch, by design (AGENT-TASKS.md §4, K3). All measurements come from
`git merge-tree --write-tree`, `git cat-file`, `git grep` and `git log` run read-only against
`~/work/k670` (sdm670 tip `a30605a54f3b`, series base `d54533f1546b`, series head
`baa585f67e0e`, 2599 commits, all verified).

| commit | subject | series pos | conflicting files | blocks | later commits per file | already in sdm670? | upstream | confidence |
|---|---|---|---|---|---|---|---|---|
| `208613d60d72` | BACKPORT: net: Add sysctl to toggle early demux for tcp and udp | 386 | 2 | 2 | 13 (`net/ipv4/sysctl_net_ipv4.c`), 19 (`net/ipv6/udp.c`) | no (5 greps) | - | high |
| `eac8f26eff94` | BACKPORT: net/tcp_fastopen: Disable active side TFO in certain scenarios | 387 | 3 | 3 | 56 (`include/net/tcp.h`), 12 (`net/ipv4/sysctl_net_ipv4.c`), 12 (`net/ipv4/tcp_fastopen.c`) | no (8 greps) | - | high |
| `435bb390114e` | BACKPORT: ANDROID: fuse-bpf: Add request UAPI | 1982 | 1 | 1 | 1 (`include/uapi/linux/Kbuild`) | no (5 greps) | `57f3ff9648991998d008ecf32f2f9e78a08bfb8b` | high |

Cross-commit facts the lead should have in one place:
- **Nothing in this batch is already in sdm670.** 18 distinctive added lines were searched tree-wide
  at `a30605a54f3b`; all absent. Each brief lists the exact lines searched.
- **None of the 3 conflicts is a real semantic clash in both sides at once.** 5 of the 6 blocks are
  "ours is empty" (the series inserts code sdm670 simply does not have, or inserts code at a place
  sdm670 does not have), and the 6th (`net/ipv4/tcp_fastopen.c` in `eac8f26eff94`) is the *same
  function* on both sides at two different line numbers.
- **The "large" size is mostly borrowed context.** In `208613d60d72` only 52 of the 140 conflicted
  lines are that commit's; in `eac8f26eff94` ~171 of 299 conflicted lines belong to *earlier* series
  commits (`ac02ef0433e3` for `tcp_chrono`, `208613d60d72` for the sysctl block). Counting real
  change, these are small commits with wide conflict windows.
- **Two out-of-order dependencies inside the series**, both facts not opinions:
  1. `208613d60d72` references `udp_v6_early_demux` at `net/ipv6/udp.c:1387-1388` but the function
     is only defined later, by `c21831895871` (series pos 585 vs 386). sdm670 does have its own copy
     at `net/ipv6/udp.c:913` @ a30605a54f3b, so `c21831895871` (batch K2b-2) will also conflict.
  2. The `tcp_chrono` half of the `include/net/tcp.h` block in `eac8f26eff94` comes from
     `ac02ef0433e3` (pos 218, batch K2b-1), which is itself one of the 150 trial conflicts
     (`conflict_detail.tsv` row `ac02ef0433e3`). sdm670 has no `tcp_chrono` at all.
- **One silent behaviour change with no conflict at all:** `eac8f26eff94` auto-merges away sdm670's
  existing `tcp_tw_recycle` sysctl entry (`net/ipv4/sysctl_net_ipv4.c:331` @ a30605a54f3b) and puts
  `tcp_fastopen_blackhole_timeout_sec` in its place. Later commit `d9dfe4a76fb9` namespaces
  `sysctl_tw_recycle` and will hit the missing entry.
- **`include/net/tcp.h` is the hottest file in the series**: 56 later commits touch it after
  `eac8f26eff94`, almost all BPF sockops work.
- **Kbuild style is the whole story in `435bb390114e`**: the commit adds exactly 1 line
  (`header-y += android_fuse.h`), sdm670's `include/uapi/linux/Kbuild` is 40 lines with 1 `header-y`
  entry and 24 `no-export-headers`, the series' is 499-500 lines with 481 `header-y` entries. Both
  trees are 4.9, so this is vendor lineage, not kernel version.
- Only **1** later commit touches `include/uapi/linux/Kbuild` (`f787c74339cb`, batch K3-3), so that
  conflict is not revisited later.

## Problems
- **My block/file counts disagree with the trial's for one commit.** `conflict_detail.tsv` row
  `435bb390114e` says 2 blocks / 27 ours lines / 460 theirs lines; my direct read of the markers in
  tree `b9eb1e6534b7b341e4639f86d5392853585d2b72` finds **1** block spanning merged lines 8-220
  (2 ours lines, 208 theirs lines). The other two commits match the trial exactly. Flagged in
  `435bb390114e.md`; the lead may want to know why before trusting either number.
- **One deliberate scope gap:** for `435bb390114e` I did not determine whether `headers_install` in
  the sdm670 layout exports `include/uapi/linux/android_fuse.h` without a `header-y` line. That is
  a resolution question and out of scope for K3, but it is the first thing a human will need to know.
- **Model disclosure:** I am a free/untested model (`Space Bunny Free`). AGENT-TASKS.md §10 says not
  to use such models for K tasks. Every claim in the 3 briefs cites a commit SHA or `path:line`, so
  they can be spot-checked cheaply; per §10 the lead should rerun K3-1 with a tier-2 model or review
  by hand rather than accept on trust.
- No commands failed twice. No resolution verdicts (DROP/MERGE/PREREQ/HUMAN) appear in these files —
  verified with `grep -E '^(DROP|MERGE|PREREQ|HUMAN)\b' analysis/conflicts/{208613d60d72,eac8f26eff94,435bb390114e,K3-1-summary}.md`.