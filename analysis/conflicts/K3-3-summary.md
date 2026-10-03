<!-- task: K3-3 | agent: space-bunny-free | date: 2026-10-03 -->
# K3-3 summary: large conflicts, facts only

## Summary
Batch `K3-3` = 3 `large` conflicts, all in group `required`. Facts only: **no resolution proposed anywhere in
this batch**, per AGENT-TASKS.md §4 K3. 3 briefs written, 0 resolution verdicts.

| commit | subject | standalone replay | trial (`conflict_detail.tsv`) | later series commits on its files |
|---|---|---|---|---|
| `3315da4f9970` | BACKPORT: security: Refactor declaration of LSM hooks | conflicts: 2 files / 2 blocks | 2 files / 2 blocks | `include/linux/lsm_hooks.h` 0, `security/security.c` 1 |
| `f787c74339cb` | BACKPORT: xdp: Add AF_XDP sockets and XSK maps | conflicts: 18 paths / 25 blocks (15 files with blocks, 3 modify/delete) | 5 files / 8 blocks | max 37 (`kernel/bpf/verifier.c`), 25 (`net/core/filter.c`), 12,12,9,6,3,3,2,2,1; 7 files with 0 |
| `1f85fb24ef92` | BACKPORT: bpf: Add TC socket assignment | conflicts: 2 files / 4 blocks | 1 file / 6 blocks | `net/core/filter.c` 21, `net/ipv6/udp.c` 0 |

All three conflict even when replayed alone onto `a30605a54f3b`, so none of them is purely an artefact of an
earlier series commit. Upstream SHAs (first listed in each message; no `Change-Id:` trailers present):
`98e828a0650f348be85728c69875260cf78069e6` (1 upstream commit),
`68e8b849b221b37a78a110a0307717d45e3593a0` (first of 24),
`cf7fbe660f2dbd738ab58aea8e9b0ca6ad232449` (first of 5).
`analysis/upstream-map/upstream-map.tsv` did not exist when I ran, so I read the messages myself.

### Things the lead should look at first
1. **`bpf_helper_changes_skb_data` vs `bpf_helper_changes_pkt_data`.** sdm670 has the `_skb_data` name
   (`a30605a54f3b:net/core/filter.c:2201`, one occurrence), the series has `_pkt_data` (one occurrence).
   Because of that single identifier, git's diff3 makes everything between the two definitions one conflict
   region: 1792 lines in `f787c74339cb` and 1821 lines in `1f85fb24ef92`, both in `net/core/filter.c`.
   This one name is what makes two of the three commits "large".
2. **`f787c74339cb` reports 18 paths standalone but 5 in the trial.** 10 of the extra paths have an *empty*
   "ours" side: they are insertion-position conflicts where the missing text is what *earlier* series commits
   add. Examples: `include/uapi/linux/bpf.h` (commit adds 1 line, conflict block is 21), `net/core/filter.c`
   block 1 (commit adds 1 include, block is 24), `kernel/bpf/verifier.c` (commit adds 3 lines, blocks are 62+50).
3. **`include/uapi/linux/Kbuild`**: sdm670's file is 40 lines with no `header-y` list at all; the series' is
   508 lines. The commit adds 2 lines. The conflict covers the whole file.
4. **`3315da4f9970` is much closer than its size suggests**: sdm670's hook list has 208 entries, the series
   table 207; only `inode_post_create` is sdm670-only and the table adds nothing. 7 signatures differ
   (4 binder hooks `const struct cred *` vs `struct task_struct *`, 3 cosmetic `unsigned` vs `unsigned int`).
   sdm670 also keeps `__lsm_ro_after_init` on `security_hook_heads`; the series side drops it.
5. **`1f85fb24ef92`, `net/ipv6/udp.c` block 1**: sdm670's `__udp6_lib_lookup_skb()` has no `sk`, no
   `skb_steal_sock()`, no `refcounted` (`a30605a54f3b:net/ipv6/udp.c:276-285`). The conflicted blob contains
   the inserted `skb_steal_sock()` call but no `struct sock *sk;` declaration, so the "theirs" side as
   produced by `merge-tree` is not compilable by itself.
6. **Cross-commit coupling inside this batch**: `f787c74339cb` is earlier in the series than `1f85fb24ef92`
   and both touch `net/core/filter.c` and `include/net/sock.h`; `3315da4f9970` is a prerequisite for
   `eb8726624efa` ("BPF LSM", another agent's conflict), which generates `bpf_lsm_<hook>` prototypes straight
   from the `lsm_hook_defs.h` table this commit introduces.

Confidence: high for all file/line/block counts (each verified by `git show`, `git cat-file` on the
`merge-tree` tree, and `grep -c '^<<<<<<<'`); the one interpretation ("diff3 blow-up") is flagged as such in
both briefs where it appears.

## Problems
None. No command failed more than once; `merge-tree` exiting 1 with a tree ID on line 1 is normal for a
conflicted replay and is not treated as a failure. I did not re-run the trial's stacked replay, so where my
standalone block counts differ from `conflict_detail.tsv` I recorded both numbers instead of picking one.