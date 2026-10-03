<!-- task: K2b-3 | agent: Space Bunny Free | date: 2026-10-03 -->
# 19ce6ace41bb: BACKPORT: xdp: support simultaneous driver and hw XDP attachment
- Author / date: Jakub Kicinski <jakub.kicinski@netronome.com>, 2018-07-13
- Upstream: a25717d2b604347d9af8da81deea7b08e8c94220
- Batch: K2b-3, size_class: moderate
## Conflicting files
- include/linux/netdevice.h   (only file in the trial replay; 4 files if applied to a clean sdm670)
- include/uapi/linux/if_link.h   (isolated merge-tree only)
- net/core/dev.c                 (isolated merge-tree only)
- net/core/rtnetlink.c           (isolated merge-tree only)
## Why it conflicts
merge-tree on its own: conflicts (13 conflict blocks over 4 files). The trial replay listed
only `include/linux/netdevice.h`, because in the stacked replay the other three files had
already been rewritten by earlier series commits.

Isolated result tree: `8ba2c16ae2e93ebd03598b99c22a3909e8c8465e`.

- Block 1, include/linux/netdevice.h ~line 824 (`enum bpf_netdev_command`): ours = the enum simply ends
  after `XDP_QUERY_PROG,` - sdm670 has **no** `enum bpf_netdev_command` at all (it only has the old
  `enum xdp_netdev_command`, include/linux/netdevice.h:811-824 @ a30605a54f3b) and no `BPF_OFFLOAD_*`;
  theirs = adds `XDP_QUERY_PROG_HW,` plus the whole `BPF_OFFLOAD_VERIFIER_PREP` … `BPF_OFFLOAD_MAP_FREE`
  run, which the *base* of this hunk already contained in the Exy tree.
- Block 2, include/linux/netdevice.h ~line 3390: ours = Samsung-specific
  `struct sk_buff *dev_hard_start_xmit_list(struct sk_buff *skb, struct net_device *dev,
  struct netdev_queue *txq, int *ret);` (include/linux/netdevice.h:3380 @ a30605a54f3b);
  theirs = `typedef int (*bpf_op_t)(...)`, `int dev_change_xdp_fd(dev, fd, expected_fd, u32 flags);`
  and `u32 __dev_xdp_query(dev, bpf_op_t xdp_op, enum bpf_netdev_command cmd);`.
  These are adjacent lines, not competing code.
- Block 3, include/uapi/linux/if_link.h ~line 887: ours = nothing (sdm670's `enum { IFLA_XDP_* }` has only
  UNSPEC/FD/ATTACHED); theirs = the `XDP_FLAGS_*` defines and `XDP_ATTACHED_*` enum including
  `XDP_ATTACHED_MULTI`.
- Block 4, include/uapi/linux/if_link.h ~line 914: ours = `__IFLA_XDP_MAX` follows directly after
  `IFLA_XDP_ATTACHED`; theirs = inserts `IFLA_XDP_FLAGS, IFLA_XDP_PROG_ID, IFLA_XDP_DRV_PROG_ID,
  IFLA_XDP_SKB_PROG_ID, IFLA_XDP_HW_PROG_ID, IFLA_XDP_EXPECTED_FD,`.
- Blocks 5-7, net/core/dev.c ~lines 6889/6935/6944: ours = the 2-argument
  `dev_change_xdp_fd(struct net_device *dev, int fd)` (net/core/dev.c:6896 @ a30605a54f3b) using
  `ops->ndo_xdp`; theirs = new `__dev_xdp_query()` + `dev_xdp_install()` and the 4-argument
  `dev_change_xdp_fd()` built on `ops->ndo_bpf`.
- Blocks 8-13, net/core/rtnetlink.c ~lines 905/1263/1317/1329/1601/2302: ours = `rtnl_xdp_size()` counts
  1 byte for XDP_ATTACHED, `rtnl_xdp_fill()` calls `dev->netdev_ops->ndo_xdp()` directly, policy has only
  `[IFLA_XDP_ATTACHED]`, do_setlink checks only `xdp[IFLA_XDP_ATTACHED]`; theirs = per-mode
  `rtnl_xdp_prog_skb/drv/hw()` helpers + `rtnl_xdp_report_one()`, bigger size accounting, new policy
  entries, and the new multi-attribute check.

Root cause: sdm670 carries the **pre-4.12 XDP API** from `android-4.9-q` (`enum xdp_netdev_command`,
`struct netdev_xdp` with a `bool prog_attached`, `ndo_xdp(dev, struct netdev_xdp *)` at
include/linux/netdevice.h:1325, 2-arg `dev_change_xdp_fd()` at include/linux/netdevice.h:3376), while the
series upgrades it to the 4.12+ API (`enum bpf_netdev_command`, `struct netdev_bpf`, `ndo_bpf`).
`sdm670` has **no** `generic_xdp_install()` in net/core/dev.c.
## Already in sdm670?
no. Searched in a30605a54f3b over all four files for five added lines of this commit:
`XDP_QUERY_PROG_HW`, `__dev_xdp_query`, `XDP_ATTACHED_MULTI`, `IFLA_XDP_DRV_PROG_ID`,
`rtnl_xdp_prog_hw` - **all five misses** (0 hits each).
Evidence: a30605a54f3b include/linux/netdevice.h:811-824, :1325, :3376 and net/core/dev.c:6896.
## Proposed resolution
PREREQ: this commit cannot be applied before the XDP-API upgrade chain has been merged into sdm670.
In series order the prerequisites are, all of which conflict themselves and must be resolved first:
- `c3b2fa149db1` UPSTREAM: bpf, xdp: allow to pass flags to dev_change_xdp_fd (2-arg -> 4-arg
  `dev_change_xdp_fd`; the sdm670 prototype at include/linux/netdevice.h:3376 must be updated)
- `fd90efeb991d` BACKPORT: net: Generic XDP (adds `generic_xdp_install`, `dev_xdp_*`; sdm670 has none)
- `fe669743040c` BACKPORT: xdp: refine xdp api with regards to generic xdp
- `b7991ab91fb2` BACKPORT: net: Add IFLA_XDP_PROG_ID
- `bb623117a0d0` BACKPORT: xdp: add reporting of offload mode
- `e00c40bbd2f4` BACKPORT: net: bpf: rename ndo_xdp to ndo_bpf (creates `enum bpf_netdev_command` /
  `struct netdev_bpf`, the enum this commit extends)
- `aba6e62026d6` BACKPORT: bpf: offload: add infrastructure for loading programs for a specific netdev
  (adds the `BPF_OFFLOAD_*` enum values that block 1 expects to already exist)

Once those are in, apply this commit with **MERGE** on the two adjacent-block cases:
- include/linux/netdevice.h block 1: take `XDP_QUERY_PROG_HW,` from theirs, keep the `BPF_OFFLOAD_*`
  values already added by `aba6e62026d6`.
- include/linux/netdevice.h block 2: take theirs (typedef + `dev_change_xdp_fd` + `__dev_xdp_query`)
  **and keep** Samsung's `dev_hard_start_xmit_list()` prototype - they are unrelated adjacent declarations,
  dropping either one breaks the build (`net/core/dev.c` defines `dev_hard_start_xmit_list`).

Note for the lead: the trial's "CLEAN" verdicts inside this XDP block are unreliable. The trial
committed conflicted commits *with conflict markers* (see
analysis/exyhyperbrick-trial/README.md), so `aba6e62026d6` reported CLEAN on include/linux/netdevice.h
only because its hunk matched around those markers. Expect real conflicts in it too.
## Confidence
medium: every block is quoted from a real `merge-tree` run and "absent from sdm670" is backed by five
distinct greps, but I could not verify that the six prerequisite commits will all merge successfully -
if any of them is dropped or deferred, this commit's hunks change.
## Problems
None
