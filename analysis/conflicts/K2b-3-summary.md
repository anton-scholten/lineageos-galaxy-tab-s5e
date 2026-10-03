<!-- task: K2b-3 | agent: Space Bunny Free | date: 2026-10-03 -->
# K2b-3: conflict briefs, batch K2b-3 (required, moderate)
## Summary
9 commits, 9 briefs, all in `analysis/conflicts/<first 12 chars>.md`. Every commit was investigated with
`git show`, `git merge-tree --write-tree --merge-base=C^ a30605a54f3b C`, `git cat-file -p` on the
result tree, and at least two `git grep` absence checks against `a30605a54f3b`.

Result: **0 DROP, 3 MERGE, 6 PREREQ, 0 HUMAN.** No `high` confidence - all nine are `medium`, because
every one of them depends on commits that are not resolved yet.

Two independent clusters, and the lead should treat them as two ordered chains, not nine separate fixes:

1. **XDP API upgrade** (`19ce6ace41bb`, `27c560179112`, `2c0b7fe73b69` - all on include/linux/netdevice.h).
   sdm670 carries the pre-4.12 XDP API from `android-4.9-q` (`enum xdp_netdev_command`,
   `struct netdev_xdp`, `ndo_xdp(dev, struct netdev_xdp *)` at include/linux/netdevice.h:1325, 2-argument
   `dev_change_xdp_fd()` at :3376, **no `generic_xdp_install()` and no `xdp_prog` field in
   `struct net_device`**). The series upgrades it to the 5.x API. Nothing here can be resolved before
   `c3b2fa149db1` -> `fd90efeb991d` -> `fe669743040c` -> `b7991ab91fb2` -> `bb623117a0d0` ->
   `e00c40bbd2f4` -> `aba6e62026d6` are merged, and five of those seven are themselves conflict commits
   in other agents' batches.
2. **Android FUSE-BPF vs. Samsung FUSE passthrough** (`021499e96a40`, `04db905cb97f`,
   `35890c08a95c`; plus `de606935ba0f` and `1d79f995b6d3` which are BPF-core). sdm670 has Samsung's
   FUSE passthrough feature (fs/fuse/passthrough.c, `passthrough_filp` / `passthrough_enabled`), which
   the Exy tree never had. **Every one of these five is a "keep both sides" MERGE where taking the
   series side wholesale silently disables FUSE passthrough on this tablet.** No build error would
   catch it.

Cross-check finding for the lead (not part of my batch, do not act on it blindly): **sdm670 does NOT
carry `BPF_MAP_TYPE_LRU_HASH`.** `git grep -F BPF_MAP_TYPE_LRU_HASH a30605a54f3b` returns 0 hits
tree-wide, `include/uapi/linux/bpf.h:80-90` ends at `BPF_MAP_TYPE_CGROUP_ARRAY`, and
`kernel/bpf/bpf_lru_list.c` does not exist. The spot-check in AGENT-TASKS.md §K1 expects commit
`3ed2e2f029db` "BACKPORT: bpf: Add BPF_MAP_TYPE_LRU_HASH" to come out `yes`; in the trial it is a
CONFLICT commit on kernel/bpf/hashtab.c, so K1 will produce `no`. Same for the trial README's claim
that sdm670 "already carries part of the same change from android-4.9-q (for example
BPF_MAP_TYPE_LRU_HASH, the TCP fast-open sysctls, and nl80211 WPA3)" - the LRU_HASH part looks wrong.
I have not checked the other two.

## Table
| commit | subject | resolution | confidence |
|---|---|---|---|
| 19ce6ace41bb | BACKPORT: xdp: support simultaneous driver and hw XDP attachment | PREREQ | medium |
| 27c560179112 | BACKPORT: bpf, xdp: Maintain attached XDP programs in net_device | PREREQ | medium |
| 2c0b7fe73b69 | BACKPORT: bpf, xdp: Add bpf_link-based XDP attachment API | PREREQ | medium |
| 2d9316801144 | BACKPORT: net: Rename ->stream_memory_read to ->sock_is_readable | MERGE | medium |
| de606935ba0f | BACKPORT: bpf: allow zero-initializing hash map seed | PREREQ | medium |
| 1d79f995b6d3 | BACKPORT: bpf: Adds field bpf_sock_ops_cb_flags to tcp_sock | PREREQ | medium |
| 021499e96a40 | BACKPORT: ANDROID: fuse: Carry BPF request metadata | PREREQ + MERGE | medium |
| 04db905cb97f | BACKPORT: ANDROID: fuse-bpf: Resolve lookup reply fds | PREREQ + MERGE | medium |
| 35890c08a95c | BACKPORT: ANDROID: fuse-bpf: Contain lower file cache paths | PREREQ + MERGE | medium |

(HUMAN count: 0. DROP count: 0, so there is nothing in this batch where a wrong answer loses code
silently by omission.)

## What the lead must check first
1. **The trial's CLEAN verdicts inside the XDP block are unreliable.** The trial committed conflicted
   commits *with conflict markers* (analysis/exyhyperbrick-trial/README.md), so `aba6e62026d6`
   reported CLEAN on include/linux/netdevice.h only because its hunk matched around markers. Expect
   real conflicts there. Same caution for `de606935ba0f`, where three prerequisite commits
   (`ccba324207bf`, `86eb4528dd54`, `764e41da77ea`) reported CLEAN against a hashtab.c that sdm670's
   version does not resemble.
2. **Order matters more than the per-commit hunks in both clusters.** Do 19ce6ace41bb before
   27c560179112 before 2c0b7fe73b69; 27c560179112 deletes the `__dev_xdp_query()` that
   19ce6ace41bb adds, so hand-resolving the first in isolation wastes effort. Likewise the fuse trio
   needs `435bb390114e` (K3-1) and `462a37becb45` (K3-2) resolved first - `462a37becb45` is also what
   adds `config FUSE_BPF` to fs/fuse/Kconfig, which three other batches' commits depend on.
3. **Three of my commits sit directly on top of conflict commits owned by other agents.** Their
   resolutions may change mine: `3ed2e2f029db` (LRU_HASH, for de606935ba0f), `435bb390114e` and
   `462a37becb45` (fuse-bpf UAPI and dispatcher, for the three fuse commits),
   `f4cb49f3084c` (K2a-4, fuse function move) and `e00c40bbd2f4` (ndo_xdp -> ndo_bpf rename).
4. **Defconfig count**: the plan mentions `gts4lv*_defconfig`, but there are four
   (`gts4lv_defconfig`, `gts4lvwifi_defconfig`, `gts4lv_eur_open_defconfig`,
   `gts4lvwifi_eur_open_defconfig` @ a30605a54f3b). All four need `CONFIG_FUSE_BPF=y` if the fuse-bpf
   series is kept; none of them has a `FUSE_BPF` line today.
5. **`35890c08a95c` has no upstream SHA** (`upstream_sha = -`). It is authored by krazey and is an Exy
   -only hardening commit, so there is nothing to cross-check it against upstream. If the lead prefers
   to keep only upstream-traceable commits, this one needs an explicit decision.

## Confidence
medium (batch level): every per-commit finding is backed by a real `merge-tree` run plus at least two
absence greps against `a30605a54f3b`, and no brief claims `high`. Nothing in this batch is a DROP, so
there is no single answer here that could silently lose code. The reason for `medium` across the board
is that 6 of 9 commits are PREREQ on commits that other agents have not resolved yet; when those land,
the per-block instructions in the individual briefs still have to be applied to the real merged file.

## Problems
None. No command failed twice. All 9 `git show` calls and all 9 `merge-tree` runs behaved as expected;
the kernel repo was only ever read with `-C ~/work/k670`.
