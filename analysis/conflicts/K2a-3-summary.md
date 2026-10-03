<!-- task: K2a-3 | agent: Space Bunny Free (space-bunny-free) | date: 2026-10-03 -->
# K2a-3: conflict briefs for batch K2a-3 (10 required, trivial conflicts)

## Summary
10 briefs, one per row of `analysis/agent-batches/K2a-3.tsv`. All 10 commits are `size_class: trivial` and `group: required`
(`analysis/exyhyperbrick-trial/conflict_detail.tsv`). Every commit was examined with
`git merge-tree --write-tree --merge-base=C^ a30605a54f3b C` against the bare sdm670 tip, and step 4 (does sdm670
already have the change?) was done for every commit with at least two greps.

Resolutions: 3 MERGE, 7 PREREQ, **0 DROP, 0 HUMAN, 0 low confidence**. Nothing in this batch can be dropped -
sdm670 has none of the sockmap/BPF-iterator stack and no `epoll_pwait2`, no `PAHOLE`, no `RESOLVE_BTFIDS`.

The 7 PREREQ verdicts are all *ordering* statements, not "the patch is unresolvable": in every case the named
prerequisite commits are **earlier in the same 2599-commit series** and all of them are absent from the trial's
conflict list, i.e. an in-order replay satisfies them automatically. Each brief gives the per-block resolution to
apply once they are in. Do not cherry-pick any of these 7 commits alone against the bare sdm670 tree.

What the lead should look at first, in order of risk:
1. **`7e93ac0afe0f` (dmabuf iterator), Block 1** - the only genuine API-shape conflict in the batch. sdm670 keeps
   the DMA-buf global list as `struct dma_buf_list` / `db_list.lock` / `db_list.head`
   (drivers/dma-buf/dma-buf.c:42-47, used at :72-74, :396-398, :868-911, :969-970), the series uses
   `dmabuf_list_mutex` + `dmabuf_list`. Taking "theirs" here without `bff4be212973` applied first would give two
   different list objects. Note also that the header block shows 5 lines but only 2 are this commit's - the other 3
   are pre-series exy context that no series commit ever touches and that sdm670 never had.
2. **`8058ab5ed5e5` (accept-queue migration)** - the auto-merged body calls `reuseport_migrate_sock()`, which does
   **not** exist in sdm670 at all (`git grep reuseport_migrate_sock a30605a54f3b` -> no hits). PREREQ
   `cb85688b1ba5` (immediately preceding in the series). Applied out of order it is an implicit-declaration build
   error, not a merge error, so it is easy to miss.
3. **`080e34a277b4` and `3aed69489066`, include/net/tcp.h** - both report one conflict block covering exy's whole
   114-128 line sock-ops/ULP tail, because sdm670's include/net/tcp.h ends at line 1996 and has none of
   `tcp_call_bpf()` / `TCP_ULP_*`. The declarations these commits actually add auto-merge fine; do not get confused
   by the size of the conflict marker.
4. **`abea5381a52a`** - the only commit whose resolution is a genuine two-sided `MERGE` of a semantic difference:
   keep sdm670's *absence* of `#ifdef CONFIG_MPTCP` (its `sk_prot_creator` field is unconditional,
   include/net/sock.h:415, and net/core/sock.c mentions CONFIG_MPTCP nowhere) but take the `prot` local. Taking
   theirs verbatim silently drops MPTCP creator bookkeeping.
5. **`27ac083f317b`, net/core/Makefile** - keep sdm670's `obj-$(CONFIG_SOCKEV_NLMCAST) += sockev_nlmcast.o` line,
   which exy does not have. Nothing needs deleting: sdm670 never had the two sockmap lines this commit removes.

Two facts worth passing to other tasks:
- `CONFIG_DMA_SHARED_BUFFER=y` is already in both tablet defconfigs (arch/arm64/configs/gts4lv_eur_open_defconfig:1296,
  gts4lvwifi:1296) and `config DMA_SHARED_BUFFER` exists at drivers/base/Kconfig:251, so `7e93ac0afe0f`'s
  `ifeq ($(CONFIG_DMA_SHARED_BUFFER),y)` guard is satisfied and the `BPF_ITER(dmabuf, ...)` target really will be
  registered on this device. Relevant to K6.
- `8a953036e3b5` deliberately does **not** add the vmlinux BTF link rule (see Mathias Gluszczynski's note in the
  commit message); it only adds `PAHOLE = pahole` + `CONFIG_DEBUG_INFO_BTF`. `e42fe4677e9c` then adds the
  `prepare-resolve_btfids` hook. So `CONFIG_DEBUG_INFO_BTF` on its own produces no BTF in this tree.

## Table
| commit | subject | resolution | confidence |
|---|---|---|---|
| 7bea7dea3ed7 | BACKPORT: epoll: wire up syscall epoll_pwait2 | MERGE | medium |
| 8a953036e3b5 | BACKPORT: kbuild: Add vmlinux BTF generation option | MERGE | high |
| e42fe4677e9c | BACKPORT: bpf: Build resolve_btfids before kernel link | PREREQ | medium |
| 27ac083f317b | BACKPORT: bpf: Clean up sockmap related Kconfigs | PREREQ | high |
| 1cf802e31c98 | BACKPORT: skmsg: Move sk_redir from TCP_SKB_CB to skb | PREREQ | high |
| 080e34a277b4 | BACKPORT: sock: Introduce sk->sk_prot->psock_update_sk_prot() | PREREQ | high |
| abea5381a52a | BACKPORT: net, sk_msg: Annotate lockless access to sk_prot on clone | MERGE | high |
| 3aed69489066 | BACKPORT: bpf: Fix wrong copied_seq calculation | PREREQ | high |
| 8058ab5ed5e5 | BACKPORT: tcp: Migrate sockets in accept queues. | PREREQ | high |
| 7e93ac0afe0f | BACKPORT: bpf: Add dmabuf iterator | PREREQ | high |

## Upstream SHAs found (K1 cross-check)
| commit | upstream_sha | how |
|---|---|---|
| 7bea7dea3ed7 | `-` | no upstream trailer, only an lkml `Link:` and a Gerrit `Change-Id:` |
| 8a953036e3b5 | e83b9f55448afce3fe1abcd1d10db9584f8042a6 | `[ Upstream commit ... ]` |
| e42fe4677e9c | 33a57ce0a54d498275f432db04850001175dfdfa | `[ Upstream commit ... ]` |
| 27ac083f317b | 887596095ec2a9ea39ffcf98f27bf2e77c5eb512 | `[ Upstream commit ... ]` |
| 1cf802e31c98 | e3526bb92a2084cdaec6cb2855bcec98b280426c | `[ Upstream commit ... ]` |
| 080e34a277b4 | 8a59f9d1e3d4340659fdfee8879dc09a6f2546e1 | `[ Upstream commit ... ]` |
| abea5381a52a | b8e202d1d1d0f182f01062804efb523ea9a9008c | `[ Upstream commit ... ]` |
| 3aed69489066 | 36b62df5683c315ba58c950f1a9c771c796c30ec | `[ Upstream commit ... ]` |
| 8058ab5ed5e5 | 54b92e84193749c9968aff2dd46e3b0f42643e18 | `[ Upstream commit ... ]` |
| 7e93ac0afe0f | 76ea95534995adde1aa3cb1aa97ef33f50a617a9 | first `(cherry picked from commit ...)`, before the Android-common trailer 5594035ac7af |

## Cross-batch dependency map
Series positions from `git rev-list --no-merges --reverse d54533f1546b..baa585f67e0e`. None of these are in my
batch, so if any of them lands in someone else's brief the two must agree.

| needed by | must already be applied | pos |
|---|---|---|
| e42fe4677e9c | `d7b603054c46` (resolve_btfids host tool), `8a953036e3b5` | 1269, 1265 |
| 27ac083f317b, 1cf802e31c98, 080e34a277b4, 3aed69489066 | `993f49608c23` (creates skmsg.h, skmsg.c, sock_map.c, tcp_bpf.c) | 953 |
| 27ac083f317b | `f50d4f252709` (creates include/linux/bpf_types.h), `61a1c4021e3f` (BPF_STREAM_PARSER Kconfig) | 294, 552 |
| 080e34a277b4, 3aed69489066 | `baf9c935c8e3`, `0b56de0ab5e1`, `a6b06e3852ea`, `c74253716f57` (tcp_call_bpf tail) | 406-413 |
| 8058ab5ed5e5 | `cb85688b1ba5` (adds `reuseport_migrate_sock()`) | 1756 |
| 7e93ac0afe0f | `bff4be212973` (db_list -> dmabuf_list), `b90ee5d15b13`, `08d190f1da6e` | 1938-1940 |
| 7e93ac0afe0f | `57ab06cd8199` (reuseport_array.o), `9dd9b06133f6` (sysfs_btf.o), `b0c13acbe239` (BPF_ITER_RESCHED) | 1145, 1266, - |

## Method notes / caveats for the reviewer
- The trial's `conflicting_files` column usually lists **one** file, but `merge-tree` on the bare sdm670 tip reports
  more, because the trial replayed the series stacked. In this batch every brief lists both. Where the extra files
  are `modify/delete` ("deleted in a30605a54f3b"), the file is created by an earlier series commit and the brief
  says which one.
- Confidence `medium` was used twice, both times because the *decision* (not the merge) is a judgement call:
  `7bea7dea3ed7` (nothing in eBPF itself calls `epoll_pwait2`; only the `required` label in conflict_detail.tsv
  argues for keeping it) and `e42fe4677e9c` (depends on whether `CONFIG_DEBUG_INFO_BTF` will be enabled).
- Model used: Space Bunny Free. AGENT-TASKS.md §10 recommends a paid model for K tasks; every claim here cites a
  measured command output, but spot-checking the two `medium` rows is cheap.
- No commands failed twice; nothing was written outside `analysis/conflicts/`. The shared kernel tree
  `~/work/k670` was only read (`show`, `log`, `grep`, `ls-tree`, `merge-tree`, `cat-file`, `rev-list`);
  `merge-tree --write-tree` wrote loose objects there as expected.

## Problems
None