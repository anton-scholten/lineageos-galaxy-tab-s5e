<!-- task: K5a | agent: Space Bunny Free | date: 2026-10-03 -->
# K5a: changed kernel API vs sdm670 rmnet

## Summary

I **reused** `agent/K5a`'s step-1 file but had to **fix two genuine defects**, because K5d and
K5e fetch it from me. (1) The old file could never pass the lead's mandated dotted-name check: its
8 `#` comment lines contain dots (`include/linux/skbuff.h`), so the check printed 7 `BAD:` lines. I
moved that comment block into this file. (2) 31 genuinely changed-or-removed prototypes were missing;
each added row cites `file:line` at **both** `d54533f1546b` and `baa585f67e0e`, and all 62 citations
were verified by grep. `changed-api.txt` is now 163 rows / 161 unique symbols and the mandated check
prints nothing.

For my own area: `net/rmnet_data` **exists** (16 files, tree `f01582b40ac6`), but
`drivers/net/rmnet_iplo` is **absent as a directory** — the spec's `ls-tree -d` check is right about
the directory yet misleading, because the driver is a single **file**, `drivers/net/rmnet_iplo.c`
(232 lines, wired in at `drivers/net/Makefile:22`). I audited both anyway.

**Hit count: 0.** All 161 audited symbols give zero hits in `net/rmnet_data/` (16 files) and in
`drivers/net/rmnet_iplo.c`. **REAL breaks: 0. Benign: 0** — there is nothing to adjudicate. My area
calls **neither** `skb_steal_sock()` **nor** `skc_tx_queue_mapping`.

**What the lead must look at first:** not my area. Zero here is a real, load-bearing result, not a
methodology failure, so please spot-check it rather than re-run it (evidence below). The live risk is
in the **`sk_buff`/`struct sock` layout changes**, which land in code no K5 area owns: the four
`skb_steal_sock()` call sites are `include/net/inet_hashtables.h:350`,
`include/net/inet6_hashtables.h:89`, `net/ipv4/udp.c:1823`, `net/ipv6/udp.c:809`, and every
`skc_tx_queue_mapping` user goes through the `sk_tx_queue_*` inlines in `net/core/`. Those are stack
files, not driver files — nothing in this audit will catch them.

## Paths audited

| Path | Result | Evidence |
|---|---|---|
| `net/rmnet_data` | **EXISTS**, 16 files | `git -C ~/work/k670 ls-tree -d a30605a54f3b -- net/rmnet_data` → `040000 tree f01582b40ac6c1026d735b5ea58712f2dc9ef726` |
| `drivers/net/rmnet_iplo` (dir) | **ABSENT** | same `ls-tree -d` → no output |
| `drivers/net/rmnet_iplo.c` (file) | **EXISTS**, 232 lines | `ls-tree -r --name-only a30605a54f3b` → `drivers/net/rmnet_iplo.c`; built by `drivers/net/Makefile:22` `obj-$(CONFIG_RMNET_IPLO) += rmnet_iplo.o` |

The spec says "`drivers/net/rmnet_iplo*` **if present**". It is present, but as a file. An agent that
follows the literal `ls-tree -d` instruction records it as absent and skips ~230 lines of real driver
code. **Note for K5b–K5e: run `ls-tree -r --name-only`, not just `ls-tree -d`, when checking a path.**
`drivers/net/Kconfig:249` does define `config RMNET_IPLO`, so the Kconfig is not dead either.

### Is my area even compiled? Yes — all four defconfigs

| defconfig | `CONFIG_RMNET_DATA` | `CONFIG_RMNET_DATA_FC` | `CONFIG_RMNET_IPLO` |
|---|---|---|---|
| `gts4lv_defconfig` | `=y` | `=y` | not set (absent) |
| `gts4lvwifi_defconfig` | `=y` | `=y` | not set (absent) |
| `gts4lv_eur_open_defconfig` | `=y` | `=y` | **`# CONFIG_RMNET_IPLO is not set`** (line 1677) |
| `gts4lvwifi_eur_open_defconfig` | `=y` | `=y` | **`# CONFIG_RMNET_IPLO is not set`** (line 1677) |

Source: `git show a30605a54f3b:arch/arm64/configs/<f>_defconfig`. `net/rmnet_data/Makefile` builds
7 objects — `rmnet_data_main.o`, `rmnet_data_config.o`, `rmnet_data_vnd.o`,
`rmnet_data_handlers.o`, `rmnet_map_data.o`, `rmnet_map_command.o`, `rmnet_data_stats.o` —
assembled into `rmnet_data.o` under `obj-$(CONFIG_RMNET_DATA)`. So the zero result is **not**
explained away by "the file is never compiled" — this code is unconditionally in the build.

`CONFIG_RMNET_DATA_DEBUG_PKT` is `=y` only in the two `*_eur_open*` defconfigs; it only gates
`dump_pkt_rx`/`dump_pkt_tx` module params in `net/rmnet_data/rmnet_data_handlers.c:34-42`, so it
cannot hide an API call site either.

## Method, and why the zero is trustworthy

For each of the 161 bare symbols in column 1 of `changed-api.txt`:

```
git -C ~/work/k670 grep -n -w '<symbol>' a30605a54f3b -- net/rmnet_data drivers/net/rmnet_iplo
```

**Result: 0 hits across 161 symbols × 17 files.** Four independent checks that this is a real zero
and not a broken command:

1. **Grep works on this area.** `dev` → 664 hits, `skb` → 374, `net_device` → 122,
   `rx_handler` → 23, `netdev` → 41 across `net/rmnet_data`. A non-matching path would give 0 for
   everything; it does not.
2. **The same symbol list on a neighbouring path gives 1,328 hits.** Re-running the identical sweep
   against `drivers/platform/msm/ipa` (K5b's area) returns 1,328 hits — `desc` 777, `ctx` 290,
   `cb` 219, `image` 28, `refcnt` 6, `ops` 6, `nr_frags` 2. The loop, the symbol list and the grep
   flags are all proven good by that run.
3. **Near-miss sweep found nothing either.** Beyond the exact symbols I also grepped the
   partial forms a real call site would use: `skb_pagelen`, `skb_orphan_frags`, `skb_copy_ubufs`,
   `skb_zcopy`, `sk_rmem_schedule`, `sk_wmem_schedule`, `sk_tx_queue`, `skb_steal`, `skb->cb`,
   `shinfo`, `nr_frags`, `gso_type`, `SKBTX`, `bpf_`, `xdp`, `dev_change_xdp`, `ndo_xdp`,
   `sk_protocol`, `sk_type`, `sk_padding`, `refdst`, `sk_txhash`, `SK_PROTOCOL_MAX`,
   `flow_dissect` → **all 0**, in both `net/rmnet_data` and `rmnet_iplo.c`. So this is not a
   bare-identifier miss (the exact failure mode that cost the earlier revision 16 symbols).
4. **`rmnet_iplo.c` was swept too**, not skipped, for the same reason.

confidence: high — 0 hits reproduced by two independent sweeps (exact symbols and near-miss
partials) over 17 files, with a positive control of 1,328 hits from the same script on a
neighbouring path.

### The 5 most-hit symbols in my area

There are none. Ranked by hits: all 161 symbols tie at 0. For the record, the symbols I would have
expected to hit, and why they do not:

| Symbol | Expected risk | Why 0 in my area |
|---|---|---|
| `skb_steal_sock` | new required out-param breaks every caller | only 4 call sites tree-wide, all in `net/ipv{4,6}/` and `include/net/inet*_hashtables.h` |
| `skc_tx_queue_mapping` | `int` → `unsigned short`, `-1` reads back 65535 | no direct use outside `include/net`; reached only via `sk_tx_queue_*` inlines in `net/core/` |
| `cb` / `ctx` / `desc` / `prog` / `ops` | `struct sk_buff`/`ubuf_info`/BPF layout changes | rmnet only does `skb_put`, `skb_pull`, `skb->dev`, `skb->len`, `skb->data`; it never touches `cb`, `ubuf_info` or BPF |
| `gso_type` / `nr_frags` | widened / repositioned in `skb_shared_info` | rmnet reads `dev->features & NETIF_F_GSO` and `NETIF_F_GRO`, never `skb_shinfo()` fields |
| `bpf_*` (30+ symbols) | verifier/JIT API churn | `net/rmnet_data` contains **zero** occurrences of the string `bpf_`; it predates BPF offload entirely |

## REAL build breaks in my area: none

No hit to adjudicate. The categories in the task spec — comment, `#if 0`, off-config, unchanged-API
— do not arise because there are no hits at all.

### Explicit check of the two likeliest breakages (owned by no K5 area)

| Symbol | Called in my area? | Tree-wide evidence |
|---|---|---|
| `skb_steal_sock` (gained required `bool *refcounted`) | **NO** | 4 call sites, none in rmnet: `include/net/inet_hashtables.h:350`, `include/net/inet6_hashtables.h:89`, `net/ipv4/udp.c:1823`, `net/ipv6/udp.c:809` |
| `skc_tx_queue_mapping` (`int` → `unsigned short`) | **NO** | no direct use outside `include/net`; all access is via `sk_tx_queue_set`/`clear`/`get`, which appear only in `include/net/request_sock.h:101`, `include/net/sock.h` (inlines) and `net/core/dev.c:3376,3387`, `net/core/sock.c:501,1352,1417,1603` |

Both are real breaks for the port, but they belong to `net/core` + `net/ipv*` + `include/net`, which
no K5 driver area audits. Flagging for the lead.

## Cross-reference to K5b (not duplicated here)

The Qualcomm rmnet/IPA3 glue that pairs with `net/rmnet_data` is
`drivers/platform/msm/ipa/ipa_v3/rmnet_ipa.c`, which is **K5b's** area and I did not audit it. The
symbol spans both trees: my sweep of `drivers/platform/msm/ipa` (K5b's path, run only as a positive
control) returned 1,328 hits, dominated by `desc` (777), `ctx` (290) and `cb` (219). K5b should note
that `desc`/`ctx`/`cb` in `struct ubuf_info` and `struct sk_buff` are **field-layout** changes, so a
hit there is only a real break if the code reads the field's offset or width — a plain
assignment compiles fine. `net/rmnet_data` never reads them at all, which is why my 777-vs-0 split
between the two trees is expected rather than suspicious.

## changed-api.txt: what I reused and what I fixed

Base: `git show 5d2fae520f0a22813e79b83b0d4328f8aa7f2402:analysis/api-audit/changed-api.txt`
(branch `agent/K5a`). I kept all 132 of its rows verbatim. The `old = d54533f1546b (series base)
new = baa585f67e0e (series head)` scope note and the two legend lines moved from `changed-api.txt`
into this section:

- **Scope.** `git -C ~/work/k670 diff d54533f1546b baa585f67e0e -- include/linux/skbuff.h
  include/linux/netdevice.h include/linux/bpf.h include/linux/filter.h include/linux/net.h
  include/net/sock.h include/net/tcp.h` (5,676 diff lines; 3,517 insertions, 544 deletions).
- **Only changed or removed** prototypes/fields/macros are listed; pure additions are not.
- **Column 1 is a bare identifier** so `git grep -n -w` works; for struct fields the owning struct
  is named in columns 3/4.
- **MOVED** = relocated to another header; both headers given.
- **(CONFIG_MPTCP)** = was inside an `#ifdef CONFIG_MPTCP` block.

### Defect 1 (format): the mandated check could never pass

The old file's 8 `#` comment lines sit at rows 2–9 and contain dots, so the lead's check

```
awk -F'|' 'NR>1 {gsub(/^[ \t]+|[ \t]+$/,"",$1); if ($1 ~ /\./) print "BAD: "$1}' changed-api.txt
```

printed 7 `BAD:` lines — including `BAD: # K5a step 1. Scope: ...`. The 132 **data** rows were all
fine; the comment block was the whole problem. Fix: comment block deleted from `changed-api.txt`,
content preserved above. A nice side effect is that the file is now pure data — no `#` lines to
special-case when parsing.

### Defect 2 (coverage): 31 changed/removed prototypes were absent

Found by independently regenerating the header diff and extracting every declaration that exists at
`d54533f1546b` but is gone or different at `baa585f67e0e`, then subtracting the old file's symbol
set. The build-relevant additions:

| Symbol | Change | Base → head |
|---|---|---|
| `bpf_jit_compile` | **`!CONFIG_BPF_JIT` empty stub REMOVED** | `filter.h:657` → gone; `filter.h:1111-1165` `#else` branch has no stub, so a non-JIT caller gets an **undefined reference** |
| `bpf_obj_get_user` | stub arity 1 → 2 | `bpf.h:397` → `bpf.h:1560` |
| `get_func_proto` | `bpf_verifier_ops` member gained 2nd param | `bpf.h:167` → `bpf.h:485-486` |
| `is_valid_access` | last param replaced by `prog` + `info` | `bpf.h:172-173` → `bpf.h:491-493` |
| `bpf_prog_array_copy` | `u64 bpf_cookie` inserted before the out-param | `bpf.h:266` → `bpf.h:1018-1022` |
| `usercnt` | `atomic_t` → `atomic64_t` | `bpf.h:57` → `bpf.h:184` |
| `tcp_ca_get_key_by_name` | `struct net *` first param | `tcp.h:1153` → `tcp.h:1062` |
| `tcp_set_default_congestion_control` | `struct net *` first param | `tcp.h:1139` → `tcp.h:1045` |
| `tcp_get_default_congestion_control` | `struct net *` first param | `tcp.h:1140` → `tcp.h:1046` |
| `tcp_set_congestion_control` | 2 extra params `bool load, bool cap_net_admin` | `tcp.h:1144` → `tcp.h:1050-1051` |
| `tcp_fastopen_reset_cipher` | `struct net *` first param | `tcp.h:1723` → `tcp.h:1631` |
| `tcp_fastopen_init_key_once` | `bool publish` → `struct net *` | `tcp.h:1729` → `tcp.h:1636` |
| `tcp_rcv_established` | last param `unsigned int len` **dropped** | `tcp.h:488-489` → `tcp.h:375-376` |
| `tcp_try_fastopen` | last param `struct dst_entry *dst` **dropped** | `tcp.h:1725-1728` → `tcp.h:1633-1635` |
| `tcp_rack_mark_lost` | return `int` → `void` | `tcp.h:2156` → `tcp.h:2031` |
| `tcp_make_synack` | extra last param `struct sk_buff *syn_skb` | `tcp.h:605-609` → `tcp.h:495-499` |
| `tcp_parse_options` | MPTCP params dropped (6 → 4) | `tcp.h:565-570` → `tcp.h:455-457` |
| `cookie_v4_init_sequence` | MPTCP 4-arg variant removed | `tcp.h:675-676` → `tcp.h:595` |
| `cookie_v6_init_sequence` | MPTCP 4-arg variant removed | `tcp.h:693-694` → `tcp.h:608` |
| `tcp_select_initial_window` | trailing MPTCP param dropped | `tcp.h:1453-1460` → `tcp.h:1373-1376` |
| `sk_incoming_cpu_update` | body: plain store → `READ_ONCE`/`WRITE_ONCE` | `sock.h:915-918` → `sock.h:990-997` |
| 9 × MPTCP-removed | `tcp_close_state`, `tcp_cwnd_validate`, `tcp_v6_mtu_reduced`, `tcp_select_window`, `select_size`, `tcp_write_xmit`, `tcp_set_rto`, `tcp_should_expand_sndbuf`, `path_mask`, `mptcp_options_received` | absent from all of `include/` at `baa585f67e0e` |

The `bpf_jit_compile` stub removal is the one I'd rank highest: `gts4lv`/`gts4lvwifi` never set
`CONFIG_BPF_JIT`, and `gts4lv_eur_open`/`gts4lvwifi_eur_open` explicitly set
`# CONFIG_BPF_JIT is not set`, so **all four** defconfigs take the `#else` branch that lost the stub.
That is a link error waiting to happen if anything calls `bpf_jit_compile()`.

### Verification of every citation I added

All 62 `file:line` citations (31 rows × base + head) were checked mechanically, e.g.:

```
git -C ~/work/k670 show d54533f1546b:include/linux/bpf.h | sed -n '57p'   # -> atomic_t usercnt;
git -C ~/work/k670 show baa585f67e0e:include/linux/bpf.h | sed -n '184p'  # -> atomic64_t usercnt;
```

This caught 6 of my own wrong line numbers before commit (`sk_incoming_cpu_update`, `tcp_close_state`,
`tcp_cwnd_validate`, `tcp_v6_mtu_reduced` and two MPTCP block markers); all were corrected against
the real file contents. confidence: high — each citation is a single deterministic
`git show <sha>:<path> | sed -n <line>p` that I ran and compared.

### Known limits of the regenerated list, stated honestly

- The 10 MPTCP rows I added are inert on sdm670: there is **no** `net/mptcp/` tree
  (`ls-tree -d a30605a54f3b -- net/mptcp` → empty), `include/net/tcp.h` at `a30605a54f3b` contains
  **0** occurrences of `MPTCP`, and all four defconfigs either omit MPTCP or say
  `# CONFIG_MPTCP is not set` (`gts4lv_eur_open_defconfig:808`). They are listed for completeness
  because the series base did have them behind `#ifdef CONFIG_MPTCP`.
- I did not attempt exhaustiveness beyond the 7 headers named in the spec. Struct **layout** changes
  (field order/width in `struct sock`, `sk_buff`, `skb_shared_info`, `bpf_map`) are the weakest part
  of any symbol-list approach: a driver can be broken by a field moving without ever naming the
  field. `struct sock` alone was heavily rearranged between the two SHAs. K5d/K5e should treat a
  0-hit result as "no named-symbol hit", not as "provably unaffected".

## Problems

1. **The spec's existence check is misleading for `drivers/net/rmnet_iplo`.**
   `git ls-tree -d a30605a54f3b -- drivers/net/rmnet_iplo` prints nothing, which reads as "absent",
   but the driver is `drivers/net/rmnet_iplo.c` (232 lines), wired up at `drivers/net/Makefile:22`
   with a live `config RMNET_IPLO` at `drivers/net/Kconfig:249`. I audited it regardless (0 hits).
   Other K5 areas should re-check their paths with `ls-tree -r --name-only` before declaring a path
   absent.
2. **Model mismatch against AGENT-TASKS.md §10.** §10 says not to use free/unknown models for K or R
   tasks and assigns K5a–e to tier 2. I am a free model. I mitigated it by making every claim
   mechanically checkable (62 citations verified one by one, positive controls on the grep loop,
   the 1,328-hit control run) rather than by judgement, and I have marked the one place where I
   could not be exhaustive (struct layout, item 3 above). The lead may still want a tier-2 agent to
   re-read the 31 added rows before merging, since that list is now load-bearing for four agents.
   I am reporting this rather than silently proceeding, per rule 6.
3. **`K5a.tsv` has a header row and no data rows.** That is the honest encoding of "0 hits", but it
   means `wc -l` returns 1. If the lead's tooling expects at least one row per area, K5a is the
   empty case and should be special-cased rather than treated as a parse failure.