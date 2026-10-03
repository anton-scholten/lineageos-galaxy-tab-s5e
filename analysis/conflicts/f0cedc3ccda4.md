<!-- task: K2b-4 | agent: Space Bunny Free | date: 2026-10-03 -->
# f0cedc3ccda4: BACKPORT: bpf: Complete generic XDP map redirects
- Author / date: Kumar Kartikeya Dwivedi <memxor@gmail.com>, 2021-07-02
- Upstream: 3 squashed commits, first `fe21cb91ae7bca1ae7805454be80b6d03bec85f7` (also 11941f8a8536,
  2ea5eabaf04a)
- Batch: K2b-4, size_class: moderate
## Conflicting files
- net/sched/act_mirred.c   (the one the trial reported; 1 block)
Everything else in this 8-file commit must be kept - see the warning below.
## Why it conflicts
Trial: 1 file, 1 block, 3 ours / 28 theirs, no modify/delete
(`analysis/exyhyperbrick-trial/conflict_detail.tsv`, `results.tsv`).
Command: `git -C ~/work/k670 merge-tree --write-tree --merge-base=f0cedc3ccda4^ a30605a54f3b f0cedc3ccda4`
-> tree `f2a3ca3e2a0dfcbbcdcf1c01836af9571c02375f`.

Against a **bare** sdm670 tip merge-tree also reports `include/linux/bpf.h` (2 blocks),
`include/linux/netdevice.h` (1), `net/core/dev.c` (2), `net/core/filter.c` (2) and modify/delete for
`kernel/bpf/cpumap.c` + `kernel/bpf/devmap.c`. **All of those are artifacts** - they are hunks belonging to
earlier series commits (`netif_get_rxqueue()`, `generic_xdp_install()` etc.; sdm670 has no
`kernel/bpf/cpumap.c` / `kernel/bpf/devmap.c` at all).

- Block 1, net/sched/act_mirred.c ~line 183 (in `tcf_mirred()`, tree f2a3ca3e): ours = sdm670's whole
  egress/mirror path, `if (!(at & AT_EGRESS)) { if (m->tcfm_ok_push) skb_push_rcsum(skb2, skb->mac_len); }`
  (`net/sched/act_mirred.c:183-186` @ a30605a54f3b), followed by `dev_queue_xmit(skb2)` at `:194`; theirs = the
  series' `if (m->tcfm_eaction == TCA_INGRESS_REDIR) { ... skb_set_redirected(skb2, true); netif_rx(skb2); } else { ... }`
  block (`net/sched/act_mirred.c:188-215` @ tree f2a3ca3e).
- **The commit's entire delta to this file is one line**: `+skb_set_redirected(skb2, true);` immediately before
  `netif_rx(skb2);` (`git show f0cedc3ccda4 -- net/sched/act_mirred.c`: 1 insertion, 0 deletions).

Already in sdm670? **no, and the code it would go into does not exist at all.**
- Searched line 1: `git grep -c 'TCA_INGRESS_REDIR' a30605a54f3b -- net/sched/act_mirred.c` -> exit=1, 0 hits.
- Searched line 2: `git grep -c 'netif_rx' a30605a54f3b -- net/sched/act_mirred.c` -> exit=1, 0 hits.
- Searched line 3: `git grep -n 'TCA_INGRESS_REDIR' a30605a54f3b -- include/uapi/linux/pkt_cls.h` -> exit=1, 0 hits
  (the tc action id itself was removed from the UAPI header in this CAF 4.9 tree).
- Searched line 4: `git grep -n 'skb_set_redirected' a30605a54f3b -- include/linux/skbuff.h` -> exit=1, 0 hits;
  there is no `skb_set_redirected()` helper and no `redirected` bit in sdm670 at this point.
For contrast, the series tree has all of them: `net/sched/act_mirred.c` @ `d54533f1546b` and @ `f0cedc3ccda4^`
has `TCA_INGRESS_REDIR` at line 183/184 and `netif_rx(skb2)` at 195/196.

## Already in sdm670?

**Partly — and this is precisely why the resolution is a scoped DROP rather than a whole-commit one.**

Evidence at `a30605a54f3b`:
- `dev_map_generic_redirect` — 0 hits in `kernel/bpf/`
- `cpu_map_generic_redirect` — 0 hits in `kernel/bpf/`
- `bpf_xdp_redirect` — 0 hits in `kernel/bpf/`
- `TCA_INGRESS_REDIR` — **absent from `include/uapi/linux/pkt_cls.h`**

So the generic-redirect machinery is genuinely absent and most of this commit must be applied. But the
one file that conflicts, `net/sched/act_mirred.c`, cannot take the series side: sdm670's `tcf_mirred()`
is at `net/sched/act_mirred.c:152` and runs `skb_clone()` → `skb_push_rcsum()` → `dev_queue_xmit()`,
with no ingress-redirect branch and no `TCA_INGRESS_REDIR` action id in the UAPI header to branch on.
The added line has no insertion point and no meaning there.

## Proposed resolution
DROP **this one hunk only**: reject `net/sched/act_mirred.c` (`git checkout --ours net/sched/act_mirred.c`,
i.e. keep sdm670's file verbatim). Proof it is safe: sdm670's `tcf_mirred()` is
`net/sched/act_mirred.c:152-205` @ a30605a54f3b and runs `skb_clone()` -> `skb_push_rcsum()` ->
`dev_queue_xmit()`; there is no ingress-redirect branch, no `netif_rx()`, and not even the `TCA_INGRESS_REDIR`
action id in the UAPI header, so the one added line has no insertion point and no meaning.

⚠️ **Do not drop the whole commit.** The other 7 files carry the actual generic-XDP work and the trial applied
them cleanly:
- `include/linux/skbuff.h` **adds** the `redirected:1` bit in `struct sk_buff` plus
  `skb_is_redirected()` / `skb_set_redirected()` / `skb_reset_redirect()` - this auto-merges and is what makes
  `net/core/dev.c`'s `skb_set_redirected()` calls compile. Keep it.
- `include/linux/bpf.h`, `include/linux/netdevice.h`, `kernel/bpf/cpumap.c`, `kernel/bpf/devmap.c`,
  `net/core/dev.c`, `net/core/filter.c` - keep as the series has them.

After dropping the act_mirred.c hunk, nothing references `skb_set_redirected()` from `act_mirred.c` any more,
which is fine: `skb_is_redirected()` / `skb_reset_redirect()` are still used from the BPF/XDP paths.
## Confidence
high: the delta to the file is a single line (read from the commit's own diff), and four independent greps
including the UAPI header all show the surrounding code path is absent from sdm670.
## Problems
None
