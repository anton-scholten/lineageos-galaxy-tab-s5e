<!-- task: K2b-1 | agent: claude-opus-5 | date: 2026-10-03 -->
# K2b-1: conflict briefs, batch 1 (required, moderate)

## Summary
9 briefs for the 9 commits in `analysis/agent-batches/K2b-1.tsv` (group `required`, size_class
`moderate`). Resolutions: **6 MERGE, 2 PREREQ, 1 MERGE (add/add, see note), 0 DROP, 0 HUMAN** - no
commit needed a human decision, and nothing is proposed to be silently dropped.

Read this first: **`analysis/exyhyperbrick-trial/conflict_detail.tsv` over-reports conflicts.** It is
computed on trees that still contain unresolved `<<<<<<<` text, because
`analysis/exyhyperbrick-trial/trial.py:30` does `commit-tree` on the *conflicted* tree of each pick.
Any commit that lands after another conflicted commit **on the same file** therefore picks up spurious
extra blocks (my commits `18d6a9c0ea43`, `d5bcc28ab29c`, `b7991ab91fb2`, `bb623117a0d0` all show more
blocks and lines in the trial than a real replay produces). Trust `git merge-tree` over the trial
numbers. Where I could, I rebuilt the real stacked state with `git merge-file -p --diff3` in /tmp and
re-ran the merge; those results are marked "verified" in the briefs.

Two findings that matter beyond this batch:
- **Order matters for the SRv6 pair.** Resolving `580a9db663e1` with `.accept_ra_prefix_route` placed
  *before* `.seg6_enabled` makes `18d6a9c0ea43` apply with **zero** conflicts (verified); the other
  order costs 2 blocks. Also, in the `addrconf_sysctl[]` table the opening `{` and the shared
  `.maxlen/.mode/.proc_handler` tail sit *outside* the conflict markers, so the second entry has to be
  written out in full.
- **The XDP chain is one unit.** `b7991ab91fb2` and `bb623117a0d0` are PREREQ, not conflicts: they
  cannot be resolved against sdm670 at all (sdm670 has no `net_device.xdp_prog`, no `XDP_ATTACHED_*`,
  no `bpf_prog_aux.id`). Only 3 commits in that chain need a human, all in
  `include/linux/netdevice.h`: `fd90efeb991d`, `228584365fac`, `fe669743040c` (other agents' batches).
  I replayed all 9 `include/linux/netdevice.h` commits of that chain for real and both of mine land
  with 0 conflicts once the 3 are resolved keep-both.
- **`6ee017762dda` is an add/add trap.** sdm670 already carries the same patch
  (`b6efcb0394ff`, same `Git-commit: f405df5de317`), but in a *newer* form. A plain DROP looks right
  and is not: `e9c1bdddb9a0` later adds `lib/refcount.c`, which would then duplicate sdm670's inline
  definitions.
- **`05e4636c5fed` drags in the Knox NPA block** if resolved by taking "theirs" in
  `include/uapi/asm-generic/socket.h`. That block contains `#if ANDROID_VERSION < 90000`, i.e. build
  error **K4b**. The commit itself only adds `SCM_TIMESTAMPING_PKTINFO 58`.

| commit | subject | resolution | confidence |
|---|---|---|---|
| `ddf82ae7e880` | UPSTREAM: bpf: reuse dev_is_mac_header_xmit for redirect | MERGE | high |
| `580a9db663e1` | BACKPORT: ipv6: implement Segment Routing Header dataplane | MERGE | high |
| `18d6a9c0ea43` | BACKPORT: ipv6: sr: add core files for SR HMAC support | MERGE | medium |
| `ac02ef0433e3` | BACKPORT: tcp: instrument tcp sender limits chronographs | MERGE | high |
| `d5bcc28ab29c` | BACKPORT: net/ipv6: support more tunnel interfaces for EUI64 link-local generation | MERGE | high |
| `b7991ab91fb2` | BACKPORT: net: Add IFLA_XDP_PROG_ID | PREREQ | medium |
| `bb623117a0d0` | BACKPORT: xdp: add reporting of offload mode | PREREQ | medium |
| `6ee017762dda` | refcount_t: Introduce a special purpose refcount type | MERGE | medium |
| `05e4636c5fed` | UPSTREAM: net: add new control message for incoming HW-timestamped packets | MERGE | medium |

Confidence tally: 4 high, 5 medium, 0 low, 0 HUMAN.

## Problems
None. No command failed. The only friction was that the trial's per-commit block counts cannot be
reproduced for commits that follow another conflicted commit on the same file (see Summary), which is
why I reconstructed the stacked merges myself in `/tmp/opencode/K2b-1/` (`stack.sh`, `stack_nd2.sh`,
`keep_both.py`). The shared kernel clone at `~/work/k670` was only ever read with `git -C`
plus `merge-tree --write-tree`; no ref was moved and no file there was modified.
