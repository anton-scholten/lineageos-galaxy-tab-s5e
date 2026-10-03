<!-- task: K2a-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# d9dfe4a76fb9: BACKPORT: ipv4: Namespaceify tcp_tw_recycle and tcp_max_tw_buckets knob
- Author / date: Haishuang Yan <yanhaishuang@cmss.chinamobile.com>, 2017 (signed off David S. Miller); no upstream SHA trailer
- Upstream: - (mainline "ipv4: Namespaceify tcp_tw_recycle and tcp_max_tw_buckets knob", Haishuang Yan, v4.16 era)
- Batch: K2a-2, size_class: trivial

## Summary
Moves `struct inet_timewait_death_row` from a global into `struct netns_ipv4` (namespaceify
`tcp_tw_recycle` / `tcp_max_tw_buckets`), 12 files. sdm670 has the old global-only form, so the change
is genuinely needed. Three conflict blocks on a pristine tree (the TSVs list 1) plus **two manual
follow-ups git will not flag**: sdm670's own `tcp_tw_recycle` entry in `net/ipv4/sysctl_net_ipv4.c`'s
`ipv4_table[]` survives and references the now-deleted global `tcp_death_row` (undefined symbol), and
sdm670 has not namespaced `tcp_tw_reuse`, so taking "theirs" wholesale creates a duplicate
`/proc/sys/net/ipv4/tcp_tw_reuse`. Also: taking "ours" in `af_inet.c` would call `tcp_v4_init()` twice.

## Conflicting files
- (batch / trial) `net/ipv4/af_inet.c`
- (standalone merge onto pristine sdm670 — **3 files**, see below) `include/net/netns/ipv4.h`, `net/ipv4/af_inet.c`, `net/ipv4/sysctl_net_ipv4.c`

## Why it conflicts
merge-tree on its own: **conflicts** (tree `47a1da96071205ca2ba5da6f52f3d9245e23f01d`, exit 1) in 3 files.
The commit moves `struct inet_timewait_death_row` out of the global namespace into `struct netns_ipv4`
(12 files, 48 insertions / 42 deletions). The trial only lists 1 conflicted file because earlier series
commits had already namespaceified `tcp_tw_reuse` in its stacked tree; applied to a real sdm670 working
tree **all three** files below will conflict.

- Block 1, `include/net/netns/ipv4.h` merged lines 125-129, in `struct netns_ipv4` after
  `unsigned int sysctl_tcp_notsent_lowat;`:
  ours = nothing (sdm670 goes straight to `int sysctl_tcp_default_init_rwnd;` —
  `a30605a54f3b:include/net/netns/ipv4.h:113-115`; sdm670 has **no** `sysctl_tcp_tw_reuse` and no `tcp_death_row`);
  theirs = `int sysctl_tcp_tw_reuse;` + `struct inet_timewait_death_row tcp_death_row;`.
  (Only the second line is this commit's; the `sysctl_tcp_tw_reuse` line already existed in the series base.)
- Block 2, `net/ipv4/af_inet.c` merged lines 1858-1862, in `inet_init()` right after `ip_init();`:
  ours = blank line + `	tcp_v4_init();` (sdm670 `a30605a54f3b:net/ipv4/af_inet.c` has it after `ip_init();`);
  theirs = blank line only, i.e. **delete** it (the commit moves the call into `tcp_init()`).
- Block 3, `net/ipv4/sysctl_net_ipv4.c` merged lines 1011-1033, at the end of `ipv4_net_table[]` after the
  `tcp_notsent_lowat` entry:
  ours = nothing (sdm670's `ipv4_net_table[]` has no tw_* entries at all — `a30605a54f3b:net/ipv4/sysctl_net_ipv4.c:707`
  is where `ipv4_net_table[]` starts);
  theirs = three new per-net entries: `tcp_tw_reuse` -> `&init_net.ipv4.sysctl_tcp_tw_reuse`,
  `tcp_max_tw_buckets` -> `&init_net.ipv4.tcp_death_row.sysctl_max_tw_buckets`,
  `tcp_tw_recycle` -> `&init_net.ipv4.tcp_death_row.sysctl_tw_recycle`.

### Hidden build break that is NOT a conflict (most important part of this brief)
The naive "take theirs everywhere" resolution does **not** build. Two hunks that merged *cleanly* delete
the global `tcp_death_row`, but sdm670 has extra users the series base never had:

1. **Undefined symbol.** The commit's hunks in `include/net/tcp.h` (`-extern struct inet_timewait_death_row tcp_death_row;`)
   and `net/ipv4/tcp_minisocks.c` (`-struct inet_timewait_death_row tcp_death_row = { ... };` +
   `-EXPORT_SYMBOL_GPL(tcp_death_row);`) both merged cleanly, so in tree `47a1da96071205ca2ba5da6f52f3d9245e23f01d`
   the global is **gone** (`git cat-file -p 47a1da9607:include/net/tcp.h | grep tcp_death_row` -> no hits;
   `...:net/ipv4/tcp_minisocks.c | grep tcp_death_row` -> only the new local `... *tcp_death_row = &sock_net(...)`).
   But sdm670's own `tcp_tw_recycle` sysctl entry inside `ipv4_table[]`
   (`a30605a54f3b:net/ipv4/sysctl_net_ipv4.c:331-332`, `.data = &tcp_death_row.sysctl_tw_recycle`)
   survives untouched and sits at merged `net/ipv4/sysctl_net_ipv4.c:323-329`.
   The series base never had a `tcp_tw_recycle` entry in `ipv4_table[]` (checked
   `d9dfe4a76fb9^:net/ipv4/sysctl_net_ipv4.c`: only `tcp_max_tw_buckets` at 483, `tcp_tw_reuse` at 1212 in
   `ipv4_net_table`), so the commit's hunk that removes the global `tcp_max_tw_buckets` entry from
   `ipv4_table[]` merged cleanly and left sdm670's `tcp_tw_recycle` entry behind.
   => `net/ipv4/sysctl_net_ipv4.c` will fail to compile with an undeclared `tcp_death_row`.
2. **Duplicate sysctl.** sdm670 has **not** namespaced `tcp_tw_reuse`: it still has
   `a30605a54f3b:net/ipv4/tcp_ipv4.c:87  int sysctl_tcp_tw_reuse __read_mostly;`,
   `a30605a54f3b:include/net/tcp.h:260  extern int sysctl_tcp_tw_reuse;`,
   `a30605a54f3b:net/ipv4/tcp_ipv4.c:123  (!twp || (sysctl_tcp_tw_reuse && ...))` and its `ipv4_table[]`
   entry at `a30605a54f3b:net/ipv4/sysctl_net_ipv4.c:454-455` (survives at merged lines 446-452).
   Taking block 3 "theirs" adds a **second** `/proc/sys/net/ipv4/tcp_tw_reuse` in `ipv4_net_table[]`
   (merged line 1014). Also nothing sets/reads `net->ipv4.sysctl_tcp_tw_reuse` in the merged tree, so
   the new netns field from block 1 would be dead.

## Already in sdm670?
**no** — this change is genuinely missing and is needed.
- `git grep -n 'tcp_death_row' a30605a54f3b` -> 18 hits, **all** using the *global*:
  `a30605a54f3b:include/net/tcp.h:239`, `net/ipv4/proc.c:67`, `net/ipv4/sysctl_net_ipv4.c:312`,
  `net/ipv4/sysctl_net_ipv4.c:332`, `net/ipv4/tcp.c:3432`, `net/ipv4/tcp_input.c:6479`,
  `net/ipv4/tcp_ipv4.c:200,219,2515`, `net/ipv4/tcp_minisocks.c:32,36,156,269,272`,
  `net/ipv6/tcp_ipv6.c:266,281,1994`.
- `git grep -n 'net->ipv4.tcp_death_row' a30605a54f3b` -> **no hits**.
- `git grep -ln 'struct inet_timewait_death_row {' a30605a54f3b` -> only
  `a30605a54f3b:include/net/inet_timewait_sock.h` (series moves it to `include/net/netns/ipv4.h`).
- `git log --oneline a30605a54f3b --grep='Namespaceify tcp_tw_recycle' -F` -> **no hits**, so sdm670 has
  no own commit with that subject.
- searched lines: `tcp_death_row`, `net->ipv4.tcp_death_row`, `struct inet_timewait_death_row {`,
  and the exact subject as a fallback.
- The same commit's other hunks landed cleanly and are correct, e.g.
  `47a1da9607:net/ipv4/tcp.c:3388 inet_hashinfo_init(&tcp_hashinfo);` and `:3453 tcp_v4_init();`,
  `47a1da9607:net/ipv4/tcp_ipv4.c:2507-2509` per-net `tcp_death_row` init,
  `47a1da9607:net/ipv4/proc.c:67 net->ipv4.tcp_death_row.tw_count`.

## Proposed resolution
MERGE — take **theirs** on all three conflict blocks, with these three mandatory follow-ups.

1. `include/net/netns/ipv4.h`: take theirs, then **remove the `int sysctl_tcp_tw_reuse;` line** from the
   taken block so only `struct inet_timewait_death_row tcp_death_row;` is added. (Do not namespaceify
   `tcp_tw_reuse` in this commit — see option B below.)
2. `net/ipv4/af_inet.c`: take theirs, i.e. **delete** the `tcp_v4_init();` call from `inet_init()`.
   Do NOT take ours: the commit also adds `tcp_v4_init();` inside `tcp_init()`
   (`47a1da9607:net/ipv4/tcp.c:3453`), so keeping ours would call `register_pernet_subsys(&tcp_sk_ops)`
   twice and panic at boot.
3. `net/ipv4/sysctl_net_ipv4.c`: take theirs but **drop the `tcp_tw_reuse` entry** from the taken block
   (so only `tcp_max_tw_buckets` and `tcp_tw_recycle` are added to `ipv4_net_table[]`).
4. **Then delete sdm670's `tcp_tw_recycle` entry from `ipv4_table[]`** (merged
   `net/ipv4/sysctl_net_ipv4.c:323-329`, originally `a30605a54f3b:net/ipv4/sysctl_net_ipv4.c:331-332`).
   Without this the file does not compile. Keep sdm670's global `tcp_tw_reuse` entry in `ipv4_table[]`
   (merged lines 446-452) so `/proc/sys/net/ipv4/tcp_tw_reuse` stays single.
5. Sanity check after resolving: `git grep -n 'tcp_death_row' <resolved tree>` must show **only**
   `net->ipv4.tcp_death_row` / `ipv4.tcp_death_row` / `sock_net(...)->ipv4.tcp_death_row` uses.

Option B (more faithful to the series, more work, do it only if you also namespace `tcp_tw_reuse`):
keep `int sysctl_tcp_tw_reuse;` in `netns_ipv4` and the per-net `tcp_tw_reuse` entry, and additionally
(a) delete `a30605a54f3b:net/ipv4/sysctl_net_ipv4.c:454-455` (the `ipv4_table[]` entry),
(b) delete `a30605a54f3b:net/ipv4/tcp_ipv4.c:87` and its `extern` at `a30605a54f3b:include/net/tcp.h:260`,
(c) change `a30605a54f3b:net/ipv4/tcp_ipv4.c:123` to use `sock_net(sk)->ipv4.sysctl_tcp_tw_reuse`,
(d) set `net->ipv4.sysctl_tcp_tw_reuse = 0;` in `tcp_sk_init()`. Do **not** do this piecemeal.

## Confidence
high: merge-tree was run and all three blocks were read verbatim out of the resulting tree; every
claim about sdm670's current state is a `git grep` line reference; and the build break / duplicate-sysctl
findings were read directly out of the merged tree (`47a1da9607:net/ipv4/sysctl_net_ipv4.c:325` and
`:448` referencing a symbol whose deletion hunks merged cleanly) rather than inferred.

## Problems
None