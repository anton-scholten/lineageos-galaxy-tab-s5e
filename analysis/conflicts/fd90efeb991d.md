<!-- task: K2a-1 | agent: Space Bunny Free | date: 2026-10-03 -->
# fd90efeb991d: BACKPORT: net: Generic XDP
## Summary
The generic (SKB-mode) XDP path. sdm670 already has the **old** pre-4.12 XDP API
(`ndo_xdp` + `struct netdev_xdp` + `dev_change_xdp_fd(dev, fd)`) but no `xdp_prog` field, no
`netif_elide_gro()`, no generic XDP. Only one of the four reported conflicts is real; the other three
and the `gro_cells.c` modify/delete are artifacts of merging against a pristine sdm670 instead of the
stacked replay. Root cause of the real conflict: sdm670 lacks the 3-line `CONFIG_NETPM` block that the
exy base has, and the commit's added line lands right next to it.
- Author / date: David S. Miller <davem@davemloft.net>, 2017-04-18
- Upstream: -  (no trailer in this message. Note: the message of the later series commit
  fe669743040c refers to "b5cdae3291f7 (\"net: Generic XDP\")", which is the mainline SHA of this patch;
  it is in prose, not in one of the four K1 trailer patterns, and `git rev-parse b5cdae3291f7` does not
  resolve in this repo.)
- Batch: K2a-1, size_class: trivial
## Conflicting files
- include/linux/netdevice.h         (the only file the trial listed)
- include/uapi/linux/if_link.h      (also conflicts standalone)
- net/core/dev.c                    (also conflicts standalone)
- net/core/gro_cells.c              (modify/delete in the standalone run only)
- (net/core/rtnetlink.c is in the commit and merges automatically)
## Why it conflicts
merge-tree on its own: conflicts -> tree f63332bc99c07b43022b9321be92d2958a196314
- Block 1, include/linux/netdevice.h ~line 1915 (REAL), end of `struct net_device`:
  ours = `bool proto_down;` then `};`; theirs = `struct bpf_prog __rcu *xdp_prog;` +
  `#ifdef CONFIG_NETPM` / `bool netpm_use;` / `#endif`, then `};`.
  Cause: `git diff a30605a54f3b 41b749328282 -- include/linux/netdevice.h` shows the **only**
  sdm670-vs-base difference in `struct net_device` is those three NETPM lines
  (`@@ -1913,4 +1913,7 @@`, all `+`). The commit adds one line immediately before them, so git
  puts both sides in one block.
- Block 2, include/uapi/linux/if_link.h ~line 887 (artifact), "XDP section": ours = nothing;
  theirs = the whole `XDP_FLAGS_UPDATE_IF_NOEXIST` / `XDP_FLAGS_SKB_MODE` / `XDP_FLAGS_MASK` block.
  sdm670's if_link.h has no `XDP_FLAGS_*` at all; those arrive from c3b2fa149db1 (CLEAN,
  results.tsv:172, adds `XDP_FLAGS_UPDATE_IF_NOEXIST` and `IFLA_XDP_FLAGS`) plus this commit.
- Blocks 3 and 4, net/core/dev.c ~lines 7039 and 7070 (artifacts), both inside `dev_change_xdp_fd()`:
  ours = old-API body (`if (!ops->ndo_xdp) return -EOPNOTSUPP;`, `err = ops->ndo_xdp(dev, &xdp)`) and a
  2-argument signature; theirs = generic-XDP body (`xdp_op = ops->ndo_xdp; if (!xdp_op ||
  (flags & XDP_FLAGS_SKB_MODE)) xdp_op = generic_xdp_install;`, `ASSERT_RTNL();`, `err = xdp_op(...)`)
  and references `flags`. The `flags` parameter only exists after c3b2fa149db1, which is not applied in
  a standalone run.
- net/core/gro_cells.c: `CONFLICT (modify/delete): deleted in a30605a54f3b and modified in
  fd90efeb991d`. The commit's only change there is `!(dev->features & NETIF_F_GRO)` ->
  `netif_elide_gro(dev)`. The file is created earlier in the series by 41b749328282
  "BACKPORT: gro_cells: move to net/core/gro_cells.c" (CLEAN, results.tsv:313); sdm670 has no
  `gro_cells.c` at all (no commit in its history ever deleted one).
## Already in sdm670?
partly - the old XDP API only, not this change. Evidence:
- `git grep -n 'xdp' a30605a54f3b -- include/linux/netdevice.h` -> `struct netdev_xdp` at :826,
  `int (*ndo_xdp)(struct net_device *, struct netdev_xdp *)` at :1325-1326,
  `int dev_change_xdp_fd(struct net_device *dev, int fd);` at :3376 (2-arg), `enum xdp_netdev_command`
  at :811. That is the pre-4.12 API, identical to the exy base 41b749328282.
- Second probe, `git grep -n xdp_prog a30605a54f3b` -> no hits: no `xdp_prog` field, no `dev->xdp_prog`.
- Third probe, `git grep -n netif_elide_gro a30605a54f3b` -> no hits: the inline helper this commit
  adds is absent, so nothing here is a duplicate.
- sdm670 has no `XDP_FLAGS_*` (if_link.h:885-894 jumps from the comment straight to the enum).
## Proposed resolution
MERGE: the whole commit applies; only Block 1 needs a decision.
- include/linux/netdevice.h: insert `struct bpf_prog __rcu *xdp_prog;` immediately after
  `bool proto_down;` and **do not** take the three `#ifdef CONFIG_NETPM ... netpm_use ... #endif`
  lines - sdm670 has no `CONFIG_NETPM` anywhere (`git grep -ln CONFIG_NETPM a30605a54f3b` -> nothing),
  the whole NETPM patch is absent from this tree, so that block would be dead code.
- Keep the `netif_elide_gro()` inline that the same commit adds after `#define to_net_dev(d)`
  (it merges cleanly; it is already in the result tree at include/linux/netdevice.h:1925).
- Blocks 2/3/4 should disappear in a correct replay (c3b2fa149db1, 41b749328282 and 1751590b4d0c are
  all CLEAN and earlier). If they do appear, take theirs in all three - sdm670's side is only the
  old-API body that the series is superseding.
- Do not create `net/core/gro_cells.c` by hand; it comes from 41b749328282.
## Confidence
medium: step 4 done (three greps prove `xdp_prog`/`netif_elide_gro`/`XDP_FLAGS_*` are absent and the
old XDP API is present) and the Block 1 resolution is certain because the whole sdm670-vs-base delta
in `struct net_device` is 3 lines. Medium rather than high because the commit spans 5 files and the
other four reported conflicts are artifacts whose behaviour in a real replay I could only infer from
the trial's CLEAN/CONFLICT records, not observe directly.
## Problems
None