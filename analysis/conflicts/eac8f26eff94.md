<!-- task: K3-1 | agent: Space Bunny Free | date: 2026-10-03 -->
# eac8f26eff94: BACKPORT: net/tcp_fastopen: Disable active side TFO in certain scenarios
- Author / date: Wei Wang <weiwan@google.com>, 2017-04-20
- Upstream: -  (no `commit <sha>`, `[ Upstream commit ... ]`, `(cherry picked from commit ...)` or `Change-Id:` in the message; scanned case-insensitively)
- Batch: K3-1, size_class: large
- Series position: 387 of 2599 (`git rev-list --count d54533f1546b..eac8f26eff94`); its parent is `208613d60d72`, i.e. the commit in the same batch, one position earlier
- Touches 8 files, +164/-7. 3 of them conflict.

## Conflicting files
- `include/net/tcp.h`
- `net/ipv4/sysctl_net_ipv4.c`
- `net/ipv4/tcp_fastopen.c`

Auto-merged cleanly (they carry the mechanism): `include/linux/tcp.h`, `net/ipv4/tcp.c`,
`net/ipv4/tcp_input.c`, `net/ipv4/tcp_ipv4.c`, `Documentation/networking/ip-sysctl.txt`.

**3 conflicting files, 3 conflict blocks (1 per file), 3 files examined to the end.**
The trial's own record for this commit agrees: `analysis/exyhyperbrick-trial/conflict_detail.tsv`,
row `eac8f26eff94` = 3 files / 3 blocks / 26 ours lines / 241 theirs lines.

## Why it conflicts
`merge-tree --write-tree --merge-base=eac8f26eff94^ a30605a54f3b eac8f26eff94` → conflicts on its own.
Tree `76df4a78b6491875a2d3d3dbf1d77be10b9216e3`. Merge base is `208613d60d72`.

Block 1, `include/net/tcp.h`, merged lines 1558-1582 (ours 0 lines, theirs 24 lines).
- ours: nothing at that spot. sdm670 goes from `struct tcp_fastopen_context` straight to
  `/* write queue abstraction */` / `tcp_write_queue_purge()`.
- theirs: 24 lines. Only the first 6 are from this commit
  (`extern unsigned int sysctl_tcp_fastopen_blackhole_timeout;` + 4 new prototypes,
  hunk `@@ -1583,6 +1583,12`). The other 18 (`enum tcp_chrono { ... }`, `tcp_chrono_start()`,
  `tcp_chrono_stop()`, and a forward declaration of `tcp_init_send_head()`) are pre-existing series
  code from `ac02ef0433e3`, 169 commits earlier.
- sdm670 has no `tcp_chrono` anywhere (`git grep -l tcp_chrono a30605a54f3b -- net include fs` → ABSENT),
  and `ac02ef0433e3` is itself one of the 150 trial conflicts (moderate, 1 file, 1 block,
  `conflict_detail.tsv` row for `ac02ef0433e3`, batch K2b-1). So most of the "theirs" side of this
  block belongs to a commit somebody else has to resolve first.
- sdm670 already defines `tcp_init_send_head()` as a real `static inline` at
  `include/net/tcp.h:1546` @ a30605a54f3b, with no forward declaration; theirs adds one.

Block 2, `net/ipv4/sysctl_net_ipv4.c`, merged lines 274-428 (ours 0 lines, theirs 154 lines).
- ours: nothing (end of `proc_tcp_fastopen_key()` then `static struct ctl_table ipv4_table[]`,
  `net/ipv4/sysctl_net_ipv4.c:219` and `:274` @ a30605a54f3b).
- theirs: 141 lines of context that sdm670 simply does not have — the `CONFIG_NETPM`
  `proc_netpm_ifdevs()` block plus `proc_configure_early_demux()` / `proc_tcp_early_demux()` /
  `proc_udp_early_demux()` from the previous series commit `208613d60d72` — followed by this
  commit's own ~13-line `proc_tfo_blackhole_detect_timeout()` (hunk `@@ -411,6 +411,19`).
  Same borrowed-context shape as the conflict in `208613d60d72`.
- This commit's second sysctl hunk auto-merged and it is a *deletion*: it replaces sdm670's existing
  `tcp_tw_recycle` table entry (`net/ipv4/sysctl_net_ipv4.c:331` @ a30605a54f3b) with
  `.procname = "tcp_fastopen_blackhole_timeout_sec"`. In tree `76df4a78b649` the string
  `tcp_tw_recycle` no longer appears in this file at all. That is a behaviour change on an existing
  knob, not a conflict.

Block 3, `net/ipv4/tcp_fastopen.c`, merged lines 365-486 (ours 26 lines, theirs 95 lines).
- ours: sdm670's `tcp_fastopen_defer_connect()` + `EXPORT_SYMBOL`, 26 lines
  (`net/ipv4/tcp_fastopen.c:358` @ a30605a54f3b).
- theirs: 95 lines of new TFO-blackhole machinery — `sysctl_tcp_fastopen_blackhole_timeout`,
  `tfo_active_disable_times` / `tfo_active_disable_stamp`,
  `tcp_fastopen_active_disable()`, `tcp_fastopen_active_timeout_reset()`,
  `tcp_fastopen_active_should_disable()`, `tcp_fastopen_active_disable_ofo_check()`.
- This one is a code-motion collision, not a semantic one: sdm670 has the *same*
  `tcp_fastopen_defer_connect()` function as the series base, just at a different place —
  `net/ipv4/tcp_fastopen.c:280` @ 208613d60d72 vs `:358` @ a30605a54f3b. Diffing base blob against
  sdm670 (`git diff 208613d60d72:net/ipv4/tcp_fastopen.c a30605a54f3b:net/ipv4/tcp_fastopen.c`)
  shows the function deleted at line ~272 and re-added at ~349 (34 added / 33 removed lines).

## Already in sdm670?
**No.** Lines searched with `git grep -l '<line>' a30605a54f3b -- net include fs`, all ABSENT:
`tcp_fastopen_active_disable_ofo_check`, `tcp_fastopen_active_should_disable`,
`sysctl_tcp_fastopen_blackhole_timeout`, `tfo_active_disable_stamp`, `tcp_chrono_start`,
`TCP_CHRONO_UNSPEC`, `syn_fastopen_ch`.
The one thing sdm670 does already have from the "theirs" block is `tcp_init_send_head`
(`include/net/tcp.h:1546` @ a30605a54f3b) — as a definition, not the forward declaration theirs adds.
confidence: high — eight independent distinctive identifiers, zero hits tree-wide.

## Notes for the lead
- Three blocks, three different causes: Block 3 is moved code (the same function on both sides);
  Blocks 1 and 2 are mostly *other* commits' code that sdm670 lacks, showing up because the
  conflicted region is large. Counting the conflicted lines: 24 (tcp.h) + 154 (sysctl) + 121
  (tcp_fastopen.c) = 299 lines, of which ~171 are context from earlier series commits
  (18 `tcp_chrono` lines + 141 sysctl lines from `208613d60d72`) and ~128 belong to this commit
  (`git show --numstat eac8f26eff94`: `net/ipv4/tcp_fastopen.c` +109/-0,
  `net/ipv4/sysctl_net_ipv4.c` +17/-3, `include/net/tcp.h` +6/-0).
- This commit is not self-contained in the series either: `syn_fastopen_ch:1` is added to
  `struct tcp_sock` in `include/linux/tcp.h` (auto-merged, visible at `include/linux/tcp.h:237`
  in tree `76df4a78b649`) and is read/written by the new tcp_fastopen.c code.
- `include/net/tcp.h` is the hottest file in the whole series: 56 later commits touch it, most of
  them BPF sockops work. `net/ipv4/sysctl_net_ipv4.c` and `net/ipv4/tcp_fastopen.c` get 12 each.
- `34d567fb3aa8` ("BACKPORT: ipv4: Namespaceify tcp_fastopen_blackhole_timeout knob") later moves the
  very symbol this commit introduces, in both of the conflicting files.
- `ac02ef0433e3` (batch K2b-1) is a hard dependency for the `tcp_chrono` part of Block 1; sdm670 has
  no `tcp_chrono` at all, so a resolution that keeps the `tcp_chrono` block also needs that commit in.
- The removed `tcp_tw_recycle` sysctl entry auto-merges out of existence. Nothing conflicts, but the
  knob disappears; `d9dfe4a76fb9` later namespaces `sysctl_tw_recycle`, so that later commit will
  notice the missing table entry.
- sdm670's `include/net/tcp.h` differs a lot from the series base around here (31 added / 82 removed
  lines): different `tcp_use_userconfig` prototypes, no `hrtimer_cancel(&tcp_sk(sk)->pacing_timer)`
  (sdm670 removed it, timer API differs), different `tcp_jiffies32` comment. Expect more surprises
  in this file than the 3 blocks suggest.
- This is the TFO-blackhole workaround, not eBPF. Its only connection to the port is that it sits in
  the middle of the series and churns `include/net/tcp.h`, which every later BPF sockops commit edits.
- Different SoC caution: the series is Exynos 9810, sdm670 is Qualcomm SDM670, but this code is
  SoC-neutral TCP, so the main risk here is 4.9-vs-4.9 API drift, not hardware differences.
- I did not check whether sdm670's `tcp_fastopen_defer_connect()` and the series' version are
  byte-identical; the diff hunk line counts (33 vs 34) suggest they differ by about one line.

## Later series commits touching the same files
`git log --oneline eac8f26eff94..baa585f67e0e -- include/net/tcp.h | head -30` — **56 later commits total, first 30**:
```
40a60987a65a BACKPORT: net: Expose socket option helpers to BPF
c49c98ee5ce7 BACKPORT: bpf: Add struct_ops and TCP congestion control
dcf26f80377e BACKPORT: bpf: tcp: Do not limit cb_flags when creating child sk from listen sk
c46c19870629 BACKPORT: bpf: tcp: Allow bpf prog to write and parse TCP header option
4d161a754796 BACKPORT: bpf: tcp: Add bpf_skops_hdr_opt_len() and bpf_skops_write_hdr_opt()
0ee2af35b905 BACKPORT: bpf: tcp: Add bpf_skops_established()
454b3a10a62b BACKPORT: tcp: adjust tail loss probe timeout
cbb22c3df3c6 BACKPORT: tcp: Use BPF timeout setting for SYN ACK RTO
13892e7d42e7 BACKPORT: tcp: bpf: Add TCP_BPF_RTO_MIN for bpf_setsockopt
53149c212910 BACKPORT: bpf: avoid unused variable warning in tcp_bpf_rtt()
2effbf13ee69 BACKPORT: bpf: Run BPF_CGROUP_SOCK_OPS callback on every RTT
1ec033300db2 BACKPORT: bpf: Add write access to tcp_sock and sock fields
9d50f14fd76f BACKPORT: bpf: Support passing args to sock_ops bpf function
a1168833d468 BACKPORT: bpf: Add access to snd_cwnd and others in sock_ops
5235bb2532fd BACKPORT: tcp: Avoid TCP syncookie rejected by SO_REUSEPORT socket
3aed69489066 BACKPORT: bpf: Fix wrong copied_seq calculation
10a2d1b5722a BACKPORT: bpf, sockmap: Correct copied_seq handling
a272cbc7e913 BACKPORT: tcp_bpf: Don't let child inherit parent protocol ops
3e6e2d947e8f BACKPORT: skmsg: Extract common receive and wait helpers
6638b97927ff BACKPORT: skmsg: Pass psock pointer to psock_update_sk_prot()
080e34a277b4 BACKPORT: sock: Introduce sk->sk_prot->psock_update_sk_prot()
1cf802e31c98 BACKPORT: skmsg: Move sk_redir from TCP_SKB_CB to skb
2493d8a83b60 BACKPORT: bpf: Compute data_end dynamically with JIT code
c9ce06ed2dd3 BACKPORT: skmsg: Lose offset info in sk_psock_skb_ingress
de5533f4e7b6 BACKPORT: bpf: Fix sockmap ingress receive race
b177955ebca1 BACKPORT: bpf: Preserve ingress redirects across apply_bytes
84d37c6fa5be BACKPORT: tcp: Always reinitialize congestion control changes
993f49608c23 bpf, sockmap: convert to generic sk_msg interface
b45d2c84d87e bpf: sockmap, convert bpf_compute_data_pointers to bpf_*_sk_skb
4687ee85dca6 bpf: sockmap, refactor sockmap routines to work with hashmap
```
`git log --oneline eac8f26eff94..baa585f67e0e -- net/ipv4/sysctl_net_ipv4.c | head -30` — **12 later commits**:
```
0724d4fb0cf4 BACKPORT: tcp: reflect tos value received in SYN to the socket
72367a0c6f41 BACKPORT: net: Introduce net.ipv4.tcp_migrate_req.
878a5767dc7f UPSTREAM: tcp: Namespace-ify sysctl_tcp_default_congestion_control
34d567fb3aa8 BACKPORT: ipv4: Namespaceify tcp_fastopen_blackhole_timeout knob
dc6e3d6b467d BACKPORT: ipv4: Namespaceify tcp_fastopen_key knob
e23ccd218472 ipv4: Remove the 'publish' logic in tcp_fastopen_init_key_once
46ceae9c1d1e BACKPORT: ipv4: Namespaceify tcp_fastopen knob
19aba572851c BACKPORT: ipv4: Namespaceify tcp_max_syn_backlog knob
d9dfe4a76fb9 BACKPORT: ipv4: Namespaceify tcp_tw_recycle and tcp_max_tw_buckets knob
139798d79eb3 BACKPORT: ipv4: Namespaceify tcp_tw_reuse knob
9ffe1af09558 BACKPORT: net: Avoid receiving packets with an l3mdev on unbound UDP sockets
004f6001c296 UPSTREAM: tcp: ULP infrastructure
```
`git log --oneline eac8f26eff94..baa585f67e0e -- net/ipv4/tcp_fastopen.c | head -30` — **12 later commits**:
```
0ee2af35b905 BACKPORT: bpf: tcp: Add bpf_skops_established()
6db5295cecb4 BACKPORT: tcp: uniform the set up of sockets after successful connection
9d50f14fd76f BACKPORT: bpf: Support passing args to sock_ops bpf function
50d965884404 BACKPORT: tcp: Preserve congestion-control initialization
1cf9402d636a BACKPORT: tcp: Only initialize congestion control once
34d567fb3aa8 BACKPORT: ipv4: Namespaceify tcp_fastopen_blackhole_timeout knob
2fc266aa42cc net/tcp_fastopen: Add snmp counter for blackhole detection
dc6e3d6b467d BACKPORT: ipv4: Namespaceify tcp_fastopen_key knob
e23ccd218472 ipv4: Remove the 'publish' logic in tcp_fastopen_init_key_once
46ceae9c1d1e BACKPORT: ipv4: Namespaceify tcp_fastopen knob
b6f7c415e6de UPSTREAM: tcp: Remove the unused parameter for tcp_try_fastopen.
eeed4aa5d804 BACKPORT: bpf: Add TCP connection BPF callbacks
```

## Confidence
high — block boundaries, line counts and symbol presence all come from `git merge-tree`,
`git cat-file`, `git grep` and `git diff` on the named trees/commits; no intent is inferred.

## Problems
None for this commit. Note for the reviewer: I am a free/untested model (AGENT-TASKS.md §10 says
not to use those for K tasks), so please read the citations rather than the prose.