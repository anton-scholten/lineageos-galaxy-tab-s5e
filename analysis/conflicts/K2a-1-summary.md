<!-- task: K2a-1 | agent: Space Bunny Free | date: 2026-10-03 -->
# K2a-1: conflict briefs, batch K2a-1 (required, trivial)
## Summary
Ten conflict commits, all classified `required` / `trivial` in
[analysis/exyhyperbrick-trial/conflict_detail.tsv](../exyhyperbrick-trial/conflict_detail.tsv).
Output: 10 briefs + this summary. No HUMAN verdicts, so no early hand-in was needed.
Resolutions: 7 MERGE, 2 DROP, 1 PREREQ; 9 high confidence, 1 medium.
Three things the lead should check first:

1. **AGENT-TASKS.md §K1 has a wrong spot-check.** It says `3ed2e2f029db` ("BPF_MAP_TYPE_LRU_HASH")
   should resolve to "sdm670 already has it". It does **not**:
   `git grep -n BPF_MAP_TYPE_LRU_HASH a30605a54f3b -- include/uapi/linux/bpf.h` returns nothing, and
   neither does a whole-tree grep or `git grep -n lru a30605a54f3b -- kernel/bpf/hashtab.c`. Do not
   DROP that commit. Any other brief that repeats the §K1 claim needs re-checking.

2. **The trial's per-commit `conflicting_files` column under-reports, and its replay tree is
   polluted.** [analysis/exyhyperbrick-trial/trial.py](../exyhyperbrick-trial/trial.py) commits the
   *conflicted* tree (conflict markers and all) with `commit-tree` and keeps going, so every later
   commit is merged against a tree full of markers. My briefs therefore report two things per commit:
   what the trial listed, and what
   `git merge-tree --write-tree --merge-base=C^ a30605a54f3b C` produces against a pristine sdm670.
   Most extra files in my lists are artifacts of earlier CLEAN commits not being applied
   (c3b2fa149db1, 41b749328282, fe327aaab7c1, 1751590b4d0c, da36ef9c01aa, baf9c935c8e3, a1a72fa9e5c7 -
   all CLEAN in results.tsv). Two systematic sources of conflict in this batch:
   sdm670 has **no `CONFIG_NETPM`** anywhere (the exy base has ~3 lines in `struct net_device` and 172
   lines in `net/ipv4/sysctl_net_ipv4.c`) - never import those blocks; and sdm670's XDP is the
   **pre-4.12 API** (`ndo_xdp` + `struct netdev_xdp` + 2-arg `dev_change_xdp_fd`), which the series
   progressively replaces.

3. **A silent code-loss trap in `a6b06e3852ea`**: taking the `net/ipv4/tcp_minisocks.c` block verbatim
   declares `int mss;` twice (sdm670 already has `int mss = dst_metric_advmss(dst);` at
   net/ipv4/tcp_minisocks.c:376). Take only `u32 rcv_wnd;` from that side.

| commit | subject | resolution | confidence |
|---|---|---|---|
| 74d484967de7 | BACKPORT: tcp: tsq: add tsq_flags / tsq_enum | MERGE | high |
| 1c3b123b0ad6 | UPSTREAM: security: selinux: allow per-file labeling for bpffs | DROP | high |
| 3ed2e2f029db | BACKPORT: bpf: Add BPF_MAP_TYPE_LRU_HASH | MERGE | high |
| 5128fe02b819 | UPSTREAM: net/ipv6: allow sysctl to change addr_gen_mode | DROP | high |
| 299f338c4b31 | BACKPORT: bpf: BPF for lightweight tunnel infrastructure | MERGE | high |
| fd90efeb991d | BACKPORT: net: Generic XDP | MERGE | medium |
| 228584365fac | UPSTREAM: net: move xdp_prog field in RX cache lines | PREREQ | high |
| fe669743040c | BACKPORT: xdp: refine xdp api with regards to generic xdp | MERGE | high |
| 004f6001c296 | UPSTREAM: tcp: ULP infrastructure | MERGE | high |
| a6b06e3852ea | BACKPORT: bpf: Support for setting initial receive window | MERGE | high |

**DROP proofs** (both are the same patch under a different SHA, not a partial overlap):
- `1c3b123b0ad6` -> sdm670 `09db023b40261570c862844c03072a5e4ca3037b`, same subject/author/date,
  same `(cherry picked from commit 4ca54d3d3022ce27170b50e4bdecc3a42f05dbdc)`, same Change-Id
  `I8234b9047f29981b8140bd81bb2ff070b3b0b843`; result present at security/selinux/hooks.c:828.
- `5128fe02b819` -> sdm670 `1524ee00a2c69d42fe9a554f2de6a00f9931cf55` (also a second copy
  d1f8a9bb810e), same upstream `d35a00b8e33dab7385f724e713ae71c8be0a49f4`, same Change-Id
  `Ia526e6c1de55e51e35b4b83d95749121fee5d0d1`; 13 `addr_gen_mode` sites in
  net/ipv6/addrconf.c plus include/linux/ipv6.h:71.

**PREREQ:** `228584365fac` needs `fd90efeb991d` "BACKPORT: net: Generic XDP" first - that is the only
commit in the series that introduces `xdp_prog` into `struct net_device`.

**Upstream SHAs:** only 3 of 10 have a K1-pattern trailer. `1c3b123b0ad6` -> 4ca54d3d3022 (second
trailer d52ac987ad2a), `5128fe02b819` -> d35a00b8e33d, `74d484967de7` -> d55a05b5e87e. The other seven
have no trailer and are recorded as `-`; a Change-Id was not counted. `analysis/upstream-map/` did not
exist when I ran, so I read the messages myself; K1 may fill these in later.

## Confidence
Batch-level: high for the 10 verdicts as a set. Every one of them was decided after step 4
(`git grep` on a distinctive added line at a30605a54f3b, usually two or three probes) plus a full read
of each conflict block in the merge-tree result tree. The single `medium` is fd90efeb991d, where the
resolution of the one real block is certain but three of the five reported files are artifacts I could
only infer from the trial's records. The two `DROP`s are the ones to re-verify first, since a wrong
DROP silently loses code - each has an independent sdm670 commit with matching upstream SHA and
Change-Id as proof, so the check is a 30-second `git show <sha>`.

## Problems
None. No command failed twice. The kernel tree was only read with `git -C ~/work/k670`
(`show`, `log`, `grep`, `ls-tree`, `rev-parse`, `merge-base`, `cat-file`, `merge-tree --write-tree`);
no ref was created, moved or deleted.