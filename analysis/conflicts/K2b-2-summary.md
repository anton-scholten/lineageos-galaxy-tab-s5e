<!-- task: K2b-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# K2b-2: conflict briefs, batch K2b-2 (required, moderate)
## Summary
9 commits, all in group `required`, all size_class `moderate`. **0 DROP, 0 HUMAN, 9 MERGE.**
Each brief follows AGENT-TASKS.md §4 step by step: `git show --stat`, upstream SHA read out of the message,
`git merge-tree --write-tree --merge-base=C^ a30605a54f3b C` with every conflict block quoted, then greps for
the change in sdm670 at `a30605a54f3b`.

Two structural findings the lead should read before starting:

1. **merge-tree over-reports conflicts.** It compares each commit against the *pristine* sdm670 tip, but the
   trial replayed the series stacked. For 5 of my 9 commits the trial recorded one conflicting file while
   merge-tree reported three to five (2c9a33a16d6d, dddb8c0eafe8, e00c40bbd2f4, 9dd9b06133f6, c3e95a25fa4a).
   In every case the extra merge-tree blocks are "ours is empty / theirs adds a block" artefacts of earlier
   CLEAN series commits not being in the compared tree. Resolution per block is given in each brief, but do not
   read the merge-tree block count as the work estimate.

2. **sdm670 does not have the eBPF features the task docs assume.** AGENT-TASKS.md §K1 step 4 says commit
   `3ed2e2f029db` ("BACKPORT: bpf: Add BPF_MAP_TYPE_LRU_HASH") is expected to be `yes` "because sdm670 already
   carries LRU_HASH", with the check `git grep -n BPF_MAP_TYPE_LRU_HASH a30605a54f3b -- include/uapi/linux/bpf.h`.
   **That grep returns nothing.** At a30605a54f3b `enum bpf_map_type` (include/uapi/linux/bpf.h:80-90) ends at
   `BPF_MAP_TYPE_CGROUP_ARRAY`, and `git grep -n BPF_MAP_TYPE_LRU_HASH a30605a54f3b` over the whole tree matches
   nothing. sdm670 also has no `kernel/bpf/bpf_lru_list.c`. So `3ed2e2f029db` is **not** a DROP and whoever
   briefs it (K2a-1) must not treat it as one - see the cross-batch note below, my commit f9e766e1bf7e does not
   compile without it.

Cross-batch ordering dependencies found (all verified with `git log -S` / `--is-ancestor` / results.tsv):

| My commit | Needs | Status of the needed commit |
|---|---|---|
| f9e766e1bf7e (bpf_map_do_batch deadlock fix) | `3ed2e2f029db` BACKPORT: bpf: Add BPF_MAP_TYPE_LRU_HASH - supplies `bpf_lru_push_free()`, `struct bpf_lru_node lru_node`, `htab->lru`, and `__htab_map_lookup_and_delete_batch()` | **CONFLICT** (batch K2a-1) |
| 9dd9b06133f6 (embed vmlinux BTF) | `8a953036e3b5` BACKPORT: kbuild: Add vmlinux BTF generation option - supplies `PAHOLE = pahole` and `export ... PAHOLE ...` in the top-level Makefile. sdm670 has no `PAHOLE` anywhere | **CONFLICT** (another batch) |
| c3e95a25fa4a (ambient bpf_run_ctx) | `randomized_struct_fields_start`/`_end` macros - **no series commit supplies them**; sdm670 has no such macro in the whole tree, the series base has them in include/linux/compiler.h:477-479 and compiler-gcc.h:293-294. This is a missing prerequisite, the same class as task K4a | not in the series at all |
| 9e672484dfc9 (skb-less SYN cookie) | `ebe3b00d3481` BACKPORT: bpf: add bpf_tcp_gen_syncookie helper calls the new helpers | CLEAN, so a DROP here would break the build |
| dddb8c0eafe8 (probe_read_user/kernel) | `probe_kernel_read_strict()` from `d5cc8354a7d0`; on arm64 only the weak generic alias exists | CLEAN |

## Table

| commit | subject | resolution | confidence |
|---|---|---|---|
| c21831895871 | BACKPORT: net: ipv6: Add early demux handler for UDP unicast | DROP | high |
| 9e672484dfc9 | UPSTREAM: tcp: add skb-less helpers to retrieve SYN cookie | MERGE | high |
| e00c40bbd2f4 | BACKPORT: net: bpf: rename ndo_xdp to ndo_bpf | MERGE | medium |
| 2c9a33a16d6d | BACKPORT: bpf: Hooks for sys_connect | MERGE | medium |
| 7ace0da94189 | BACKPORT: bpf: Make use of probe_user_write in probe write helper | MERGE | medium |
| dddb8c0eafe8 | BACKPORT: bpf: Add probe_read_{user,kernel}{,_str} helpers | MERGE | medium |
| f9e766e1bf7e | BACKPORT: bpf: Fix a potential deadlock with bpf_map_do_batch | MERGE | medium |
| 9dd9b06133f6 | BACKPORT: btf: Embed and expose vmlinux BTF data | MERGE | high |
| c3e95a25fa4a | BACKPORT: bpf: Add ambient BPF runtime context stored in current | MERGE | high |

## The single DROP and its proof
`c21831895871` - sdm670 already contains the identical patch as commit
**`f6c002e7cd85219d69269c4ede51f5e219514ccc`** "net: ipv6: Add early demux handler for UDP unicast", same
author (subashab@codeaurora.org) and same timestamp (2017-03-08 16:36:49 -0700), 61 insertions vs the series'
58 - the 4.9 adaptation of that very commit. It is wired up:
`git grep -n 'udp_v6_early_demux' a30605a54f3b` gives a30605a54f3b:net/ipv6/udp.c:913 (definition) and
a30605a54f3b:net/ipv6/udp.c:1471 (`.early_demux = udp_v6_early_demux,` in `udpv6_ops`).
Taking the series side would not even compile: the series body calls `__udp6_lib_lookup(net, ..., dif, 0,
&udp_table, NULL)` (9 args) while sdm670's prototype at a30605a54f3b:net/ipv6/udp.c:206-209 takes 8.

## What the lead must check first
1. **Re-check the LRU assumption.** `3ed2e2f029db` must be MERGE, not DROP - see finding 2 above. Two of my
   briefs (f9e766e1bf7e, and indirectly the hashtab LRU work) stop compiling if it is dropped.
2. **`PAHOLE` in the top-level Makefile.** `8a953036e3b5` is a CONFLICT commit. Without its `PAHOLE = pahole`
   line, 9dd9b06133f6's `gen_btf()` hits `command -v ` with an empty argument, returns 1, and the build exits
   with "Failed to generate BTF for vmlinux" - a hard build stop, not a missing feature.
3. **`randomized_struct_fields_end`.** Nobody supplies the macro (finding 2, third row). Anyone resolving
   c3e95a25fa4a's sched.h hunk by taking the "theirs" side verbatim imports the bare identifier and reproduces
   the K4a error in analysis/build-test/port-first-errors.txt:1. Take only the `bpf_ctx` field.
4. **`e00c40bbd2f4` (ndo_xdp -> ndo_bpf) interacts with four other CONFLICT commits** that edit the same lines:
   `fd90efeb991d` (Generic XDP), `fe669743040c`, `b7991ab91fb2` (IFLA_XDP_PROG_ID), `bb623117a0d0` (offload mode
   reporting). Decide the rename once and apply it consistently in all four. Good news: the complete set of
   sdm670 files mentioning `ndo_xdp`/`netdev_xdp` is exactly the five files this commit touches, so there are no
   Qualcomm-only users to chase.
5. **Preserve sdm670's extras when merging.** Concretely: `dev_hard_start_xmit_list()` prototype in
   include/linux/netdevice.h (used by net/core/dev.c and net/sched/sch_generic.c), the RTIC MP placeholder and
   size-check blocks in scripts/link-vmlinux.sh, and CAF's `extra_elems` / `enum extra_elem_state` in
   kernel/bpf/hashtab.c. Each is on the "ours" side of one of my conflict blocks.
6. **`2c9a33a16d6d` must keep the uapi attach-type numbering** `BPF_CGROUP_INET4_CONNECT` /
   `BPF_CGROUP_INET6_CONNECT` directly after `BPF_CGROUP_INET4_BIND = 8` / `INET6_BIND = 9`; a reordering breaks
   netd.

Confidence summary: 4 high (c21831895871, 9e672484dfc9, 9dd9b06133f6, c3e95a25fa4a), 5 medium
(e00c40bbd2f4, 2c9a33a16d6d, 7ace0da94189, dddb8c0eafe8, f9e766e1bf7e). No low, no HUMAN. The medium ones are
medium because merge-tree could not show me the real (stacked) conflict hunk - either it applies cleanly to
pristine sdm670 so the trial conflict came from an earlier commit (7ace0da94189), or the commit's hunks interlock
with earlier commits I could not replay.

## Problems
None. No command failed. Note for the record: `git rev-parse --verify` rejects multiple revisions in one call
(`fatal: Needed a single revision`), so the three pins from AGENT-TASKS.md §1.2 have to be checked one at a
time; all three resolved (a30605a54f3b92627d868f169c72ef9c6ef82123, d54533f1546b91f94eb4e445dfea3a94ffa58a74,
baa585f67e0efc9f1efa046d0b0e76955ca4c8d5) and `git rev-list --count --no-merges d54533f1546b..baa585f67e0e`
printed 2599.
