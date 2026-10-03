<!-- task: K2a-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# 7bae1fbba13b: net/tcp_fastopen: remove obsolete extern
- Author / date: Eric Dumazet <edumazet@google.com>, 2021-07-19 (acked Jakub Kicinski)
- Upstream: - (`Change-Id: Iad9d9482a8558f31476fcba0f7894d1f1ce5b60d` is a **Gerrit ID, not a SHA**, per AGENT-TASKS.md §K1 step 2. The message's only SHA is `Fixes: 3733be14a32b`, which is the *fixed* commit, not this one.)
- Batch: K2a-2, size_class: trivial

## Summary
A single-line deletion: `-extern unsigned int sysctl_tcp_fastopen_blackhole_timeout;` from
`include/net/tcp.h`. sdm670 has never had that symbol (two independent greps are empty) and no later
series commit re-adds it to `include/net/tcp.h`, so the commit is a no-op here: DROP it. The conflict
block's "theirs" side is *not* part of this commit - it is other series commits' `tcp_fastopen_active_*`
and `tcp_chrono` declarations, which sdm670 does not implement, so taking "theirs" would not compile.

## Conflicting files
- include/net/tcp.h

## Why it conflicts
merge-tree on its own: **conflicts** (tree `ceb05668064a89dfcbc9d850b50de81e8f3784ba`, exit 1), 1 block.
The commit is a **single-line deletion** (`1 file changed, 1 deletion(-)`):
`-extern unsigned int sysctl_tcp_fastopen_blackhole_timeout;`.

- Block 1, merged tree `ceb0566806` `include/net/tcp.h` lines 1558-1581, right after
  `struct tcp_fastopen_context { ... };` (merged 1552-1556) and before the
  `/* write queue abstraction */` comment:
  ours = **nothing** (sdm670 jumps straight from `};` at `a30605a54f3b:include/net/tcp.h:1556` to
  `/* write queue abstraction */` at `:1558`).
  theirs = 21 lines: the `tcp_fastopen_active_disable()` / `tcp_fastopen_active_should_disable()` /
  `tcp_fastopen_active_disable_ofo_check()` / `tcp_fastopen_active_timeout_reset()` prototypes,
  the `enum tcp_chrono { ... }` block, `tcp_chrono_start()` / `tcp_chrono_stop()`, and
  `static inline void tcp_init_send_head(struct sock *sk);`.
  Git could not simply drop the `extern` line because the surrounding base lines that "theirs"
  deleted-as-context do not exist in sdm670 at all.

**Warning:** the "theirs" side of this block is NOT part of this commit. It comes from other series
commits (`eac8f26eff94`, TFO chrono work). Taking "theirs" here would add declarations for functions
sdm670 does not implement and would not compile.

## Already in sdm670?
**The end state is already there — there is nothing to remove.**
- 1st searched line: `git grep -n 'sysctl_tcp_fastopen_blackhole_timeout' a30605a54f3b` (whole tree,
  not just `include/net/tcp.h`) → **no hits**, exit 1.
- 2nd searched line (as required before claiming absence):
  `git grep -in 'blackhole' a30605a54f3b -- include/net/tcp.h net/ipv4/tcp.c net/ipv4/sysctl_net_ipv4.c`
  → **no hits**.
- Cross-check on the "theirs" side: `git grep -n 'tcp_fastopen_active_' a30605a54f3b` (whole tree) →
  **no hits**; `git grep -c 'tcp_chrono' a30605a54f3b -- net/ipv4 include/net` → **no hits**.
  `tcp_init_send_head` needs no forward declaration in sdm670 because it is already *defined* earlier
  in the file (`a30605a54f3b:include/net/tcp.h:1546`).
- Series side, to prove the DROP does not break a later commit:
  the only commit that could reintroduce the global is
  `34d567fb3aa8` "BACKPORT: ipv4: Namespaceify tcp_fastopen_blackhole_timeout knob"
  (series position 723, `CLEAN`), and `git show --stat 34d567fb3aa8` shows it touches **only**
  `include/net/netns/ipv4.h`, `net/ipv4/sysctl_net_ipv4.c`, `net/ipv4/tcp_fastopen.c`,
  `net/ipv4/tcp_ipv4.c` — **it never adds the `extern` to `include/net/tcp.h`**
  (`git show 34d567fb3aa8 -- include/net/tcp.h` is empty). At series head the symbol only exists as
  `net->ipv4.sysctl_tcp_fastopen_blackhole_timeout` (`baa585f67e0e:include/net/netns/ipv4.h:137`).

## Proposed resolution
DROP — the commit is a no-op on sdm670. Evidence: `sysctl_tcp_fastopen_blackhole_timeout` does not
exist anywhere in `a30605a54f3b` (two independent greps, both empty), and no later series commit adds it
back to `include/net/tcp.h`.
Mechanically: resolve `include/net/tcp.h` by taking **ours** (delete the whole conflict block, i.e. the
file ends up byte-identical to `a30605a54f3b:include/net/tcp.h`), then
`git cherry-pick --skip` (or `--allow-empty` if you want to keep the commit in the series history).
Do **not** take "theirs" — that would add `tcp_fastopen_active_*`, `enum tcp_chrono`,
`tcp_chrono_start/stop` and a duplicate `tcp_init_send_head` forward declaration that sdm670 does not
implement.

## Confidence
high: the merged conflict block was read verbatim, absence of the symbol was confirmed with two
different greps (full symbol and the bare word `blackhole`) over the whole tree, and the "would a later
commit need it" question was answered by reading `git show --stat 34d567fb3aa8` rather than assumed.

## Problems
None