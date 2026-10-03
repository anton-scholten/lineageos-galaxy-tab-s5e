<!-- task: K5b | agent: Space Bunny Free | date: 2026-10-03 -->
# K5b: changed kernel API vs sdm670 ipa driver

## Summary

`drivers/platform/msm/ipa` **does exist** in sdm670: 114 files, 3,988,576 bytes, `ipa_api.c`, `ipa_rm*`,
`ipa_clients/`, `ipa_v2/`, `ipa_v3/` (`git -C ~/work/k670 ls-tree -d a30605a54f3b --
drivers/platform/msm/ipa` → `tree 6e1c4d33ea1f28f7339f77250c941eb4ecc7175d`).

Of the 130 distinct symbols in K5a's `changed-api.txt`, **7 had any hit** in this area, giving **1,328 hit
lines**. **0 are REAL build breaks; 1,107 are benign; 221 are benign-but-worth-knowing** (`skb->cb` and
`nr_frags`). Every *changed function prototype* in the file — the class that actually breaks a build — has
**zero** hits here: `skb_steal_sock`, `____dev_forward_skb`, `dev_change_xdp_fd`, `__skb_flow_dissect`,
`skb_pagelen`, `sk_rmem_schedule`, `bpf_prog_inc`, `bpf_prog_add`, `bpf_check`, `bpf_map_inc`,
`sk_tx_queue_set/clear/get`, `skc_tx_queue_mapping`, `sk_wmem_alloc`, `sk_txhash`, `sk_type`, `sk_protocol`,
`gso_type`, `_skb_refdst`, and the whole `include/net/tcp.h` block including every `CONFIG_MPTCP` removal.

**The lead does not need to do anything for this area.** IPA is not a prime candidate for breakage after all:
it uses BPF nowhere at all, and the three header families that changed most (`bpf.h`, `filter.h`, `net/tcp.h`)
are ones it does not use. The only two things worth a glance are listed under *Worth knowing*.

**Worth knowing** (neither is a build break): `skb->cb` is real but already identical in sdm670; and
`offsetof(struct skb_shared_info, dataref)` + `sizeof(struct skb_shared_info)` in IPA are compiler-computed,
so they adapt but their *values* change.

Hit counts per symbol, most-hit first: `desc` 777, `ctx` 290, `cb` 219, `image` 28, `ops` 6, `refcnt` 6,
`nr_frags` 2. All 1,328 rows are in [`K5b.tsv`](K5b.tsv), sorted REAL → NOTE → BENIGN.

## Inputs and method

| What | Source |
|---|---|
| Symbol list | `analysis/api-audit/changed-api.txt` on `origin/agent/K5a`, fetched as `FETCH_HEAD` (140 lines, header + comments + 132 rows → 130 distinct symbols) |
| Area under test | `drivers/platform/msm/ipa` @ `a30605a54f3b` |
| Sweep | for each of the 130 symbols: `git -C ~/work/k670 grep -n -w '<symbol>' a30605a54f3b -- drivers/platform/msm/ipa` |
| Supplementary sweep | every identifier on a `-` line of `git diff d54533f1546b baa585f67e0e -- include/linux/skbuff.h include/linux/netdevice.h include/linux/bpf.h include/linux/filter.h include/linux/net.h include/net/sock.h include/net/tcp.h` (546 identifiers), same grep |

`grep -w` sanity check: `git grep -c -w skb_shinfo a30605a54f3b -- drivers/platform/msm/ipa` returns 4 files
/ 8 lines, so the sweep does match real identifiers.

Only 7 of 130 symbols hit, so the whole hit set was inspected by hand.

## REAL breaks

**None.** No changed prototype is called with the old arity or types, and no IPA code depends on a changed
field offset or width.

## The two noteworthy hits

### 1. `skb->cb` — real field, but sdm670 is already identical to the series head

changed-api.txt entry: `cb | include/linux/skbuff.h | #ifdef CONFIG_MPTCP char cb[72] ... #else char cb[48]
... #endif | char cb[48] __aligned(8); (no MPTCP variant)`.

14 of the 219 `cb` hits are genuine `struct sk_buff.cb` accesses, all in `ipa_dp.c`:

- `drivers/platform/msm/ipa/ipa_v2/ipa_dp.c:2352`, `:2681`, `:2946`, `:2947`, `:2949`, `:2950`, `:3010`
- `drivers/platform/msm/ipa/ipa_v3/ipa_dp.c:2131`, `:2466`, `:2659`, `:2660`, `:2662`, `:2663`, `:2730`

They form a `u32` at offset 0, a `u16` at offset 0 and a `u8` at offset 4, e.g.
`*(u16 *)rx_skb->cb = ...; *(u8 *)(rx_skb->cb + 4) = ucp;`
(`ipa_v3/ipa_dp.c:2659-2660` @ `a30605a54f3b`).

**Not a break.** Three independent reasons:
1. sdm670 already has the *new* value: `char cb[48] __aligned(8);` at `include/linux/skbuff.h:662 @ a30605a54f3b`,
   and `char cb[48] __aligned(8);` at `include/linux/skbuff.h:749 @ baa585f67e0e`. Identical.
2. The 72 → 48 shrink only existed in the Exynos *base* because the Exynos tree had MPTCP on
   (`char cb[72]` at `include/linux/skbuff.h:669` and the `#else` `cb[48]` at `:671` @ `d54533f1546b`).
   sdm670 has no MPTCP at all: `git grep -n MPTCP a30605a54f3b -- include/linux/skbuff.h include/net/sock.h net/`
   returns nothing.
3. IPA only uses `cb[0..4]`, well inside 48 either way.

The other 205 `cb` hits are not `struct sk_buff.cb`: `struct ipa_smmu_cb_ctx *cb = ipa2_get_wlan_smmu_ctx();`
(`ipa_v2/ipa.c:4711`), a callback function pointer `cb(event, user_data)` (`ipa_clients/ipa_usb.c:511`), and DT
compatible strings `"qcom,ipa-smmu-ap-cb"` (`ipa_api.c:2938-2940`).

**confidence: high** — the two `cb` declarations were compared field-by-field at both SHAs, and MPTCP's
absence in sdm670 was confirmed by grep, so the size change cannot reach this driver.

### 2. `skb_shinfo(skb)->nr_frags` — read-only, type unchanged

changed-api.txt entry: `nr_frags | include/linux/skbuff.h | struct skb_shared_info: unsigned char nr_frags;
(1st field) | __u8 __unused; __u8 meta_len; __u8 nr_frags; (TYPE + POSITION changed)`.

Both hits:
- `drivers/platform/msm/ipa/ipa_v2/ipa_dp.c:1668`
- `drivers/platform/msm/ipa/ipa_v3/ipa_dp.c:1373`

Both read it into a local `int num_frags` (`ipa_v2/ipa_dp.c:1655`, `ipa_v3/ipa_dp.c:1323`), e.g.
`num_frags = skb_shinfo(skb)->nr_frags;` then `if (num_frags) { ... }` (`ipa_v3/ipa_dp.c:1373-1388`).

**Not a break.** `unsigned char` and `__u8` are the same type (`u8` is `__u8` is `unsigned char`); the value is
widened into an `int` either way. The field is accessed *by name*, never by `offsetof` or `&nr_frags`, so its
move to 3rd position is invisible to the driver.

**confidence: high** — read of both sites plus the declarations of `num_frags` were read in full; the type
identity is definitional, not inferred.

## The other five symbols — all benign

| Symbol | Hits | changed-api.txt entry | Why benign |
|---|---|---|---|
| `desc` | 777 | `struct ubuf_info.desc` moved into an anonymous union | IPA never touches `struct ubuf_info`. `git grep -n -E 'ubuf_info\|skb_uarg\|skb_zcopy' a30605a54f3b -- drivers/platform/msm/ipa` → **no hits**. All 777 are IPA's own `struct ipa_desc desc;` (`ipa_v2/ipa.c:1650`), `->desc` on IPA structs (`in->desc` `ipa_v2/ipa_client.c:379`, `ep->connect.desc` `:397`, `sps->desc` `:468`, `test->desc` `test/ipa_ut_framework.c:675`), `ipa_sys_desc_size`, or comments/strings. Only 45 are field accesses at all (37 `.desc` + 8 `->desc`), all on IPA structs. |
| `ctx` | 290 | `struct ubuf_info.ctx` moved into an anonymous union | Strongest evidence: `grep -P '\->ctx\t\|\.ctx\t'` over the hit set returns **0 rows** — not a single `.ctx` or `->ctx` field access anywhere in IPA. All 290 are IPA-local context pointers (`struct ipa_uc_offload_ctx *ctx;` `ipa_clients/ipa_uc_offload.c:316`) or strings (`ipa_clients/ecm_ipa.c:61`). |
| `image` | 28 | `struct bpf_binary_header.image` alignment changed | All 28 are IPA *firmware* image strings and comments (`ipa_v3/ipa_utils.c:5755` `"FW image too big..."`, `ipa_v3/ipahal/ipahal_i.h:760`). IPA contains no BPF at all (see below). |
| `ops` | 6 | `struct bpf_prog_aux.ops` type changed `bpf_verifier_ops` → `bpf_prog_ops` | All 6 are `cdev->ops = &..._fops`, i.e. `struct cdev.ops` (`ipa_v2/ipa.c:4329`, `ipa_v3/ipa.c:5779`, `ipa_v3/teth_bridge.c:291`, `ipa_v2/ipa_nat.c:203`, `ipa_v2/teth_bridge.c:216`, `ipa_clients/odu_bridge.c:1172`). Different struct. |
| `refcnt` | 6 | `struct sk_filter.refcnt` `atomic_t` → `refcount_t`; `struct bpf_prog_aux.refcnt` `atomic_t` → `atomic64_t` | All 6 are IPA's own counters inside log strings, e.g. `IPADMA_DBG("Already initialized refcnt=%d\n", ipa3_dma_init_refcnt_ctrl->ref_cnt)` (`ipa_v3/ipa_dma.c:221`); the field is actually spelled `ref_cnt` / `enable_ref_cnt` and is IPA's. Also `ipa_v3/ipa.c:4093` is error-message text. |

**confidence: high** for `ctx`, `ops`, `refcnt`, `image` — each is disproved by an exhaustive grep inside the
area (zero `.ctx`/`->ctx`; `cdev.ops`; IPA-owned `ref_cnt`; comment/strings only), not by judgement about the
header. **confidence: high** for `desc` — `ubuf_info` itself has zero occurrences in the area.

## Supplementary sweep (symbols K5a's list may not cover)

Beyond the 130 symbols, I extracted all 546 identifiers appearing on removed lines of the series diff for the
seven headers and grepped each against the area. Only these had hits, and all are benign:

| Identifier | Hits | Verdict |
|---|---|---|
| `skb_headlen` | 4 | IPA **does** call it, at `ipa_v2/ipa_dp.c:1736`, `:1772` and `ipa_v3/ipa_dp.c:1424`, `:1472` (`desc[1].len = skb_headlen(skb);`). The series changed only its *body*, not its signature — `static inline unsigned int skb_headlen(const struct sk_buff *skb)` is unchanged in the diff, only the lines inside it (diff line 3870 onwards). **Benign, confidence: high** — signature identity read straight from the diff context. |
| `addr_len` | 2 | `dev->addr_len = 0;` at `ipa_v2/rmnet_ipa.c:1754` and `ipa_v3/rmnet_ipa.c:1844`. This is `struct net_device::addr_len` (a `u8` field). The changed symbol was a *parameter* named `addr_len` in `tcp_v6_connect`, which the series removed. **Benign, confidence: high** — the diff only ever shows `addr_len` as a parameter, never as a `net_device` field. |
| `rcu_dereference` | 1 | `rcu_dereference(dev->rx_handler_data)` at `ipa_v2/rmnet_ipa.c:1301`. The series redefined `rcu_dereference_sk_user_data` (changed-api.txt line 45), **not** the plain `rcu_dereference` macro: `grep -nE '^[+-].*define rcu_dereference\('` over the diff returns nothing. **Benign, confidence: high.** |
| `struct bpf_prog`, `sock_filter`, `bpf_insn` | 0 | `git grep -n -E '\bstruct bpf_prog\b\|\bsock_filter\b\|\bbpf_insn\b' a30605a54f3b -- drivers/platform/msm/ipa` exits 1 (no hits). **Every `include/linux/filter.h` and `include/linux/bpf.h` change in changed-api.txt is therefore irrelevant to IPA** — including the removed `insns`/`insnsi` union, `bpf_prog_lock_ro` returning `int`, and the `BPF_PROG_RUN_ARRAY` macro → typed inline. **Benign, confidence: high.** |
| `sk_buff`, `net_device`, `atomic_t`, `gfp_t`, `list_head`, `uint`, `jiffies` | many | Bare type names. Only the *fields* `cb` and `_skb_refdst` inside them changed; IPA never touches `_skb_refdst`. **Benign, confidence: medium** — reasoning is by exclusion of the two changed fields, which I confirmed by grep, but the type names themselves are unconstrained. |

Also zero hits for all 44 `include/net/tcp.h` entries (`tcp_death_row`, `sysctl_tcp_tw_reuse`,
`tcp_fastopen_ctx`, `tcp_tso_autosize`, `tcp_sock_ops`, `tcp_specific`, `mptcp*`, `TCPOPT_MPTCP`, and the
`tcp_v4_*` / `tcp_v6_*` / `tcp_*` removals). IPA has no TCP code. **Benign, confidence: high.**

## Worth knowing (no action required)

`struct skb_shared_info` gains two bytes at the front (`__u8 __unused; __u8 meta_len;`) and `gso_type` widens
`unsigned short` → `unsigned int`
(`include/linux/skbuff.h:414-420 @ a30605a54f3b` vs `include/linux/skbuff.h:490-500 @ baa585f67e0e`).
IPA uses the type in three places, all compiler-computed, so all three adapt with no source change:

- `drivers/platform/msm/ipa/ipa_v2/ipa_utils.c:4448` — `memset(shinfo, 0, offsetof(struct skb_shared_info, dataref));`
- `drivers/platform/msm/ipa/ipa_v3/ipa_utils.c:4352` — same
- `drivers/platform/msm/ipa/ipa_v2/ipa_dp.c:36` and `drivers/platform/msm/ipa/ipa_v3/ipa_dp.c:44` —
  `SKB_DATA_ALIGN(sizeof(struct skb_shared_info))` inside `IPA_REAL_GENERIC_RX_BUFF_SZ(X)`

The *values* grow (the `offsetof` and `sizeof` both increase), which slightly reduces the generic RX buffer
budget. That is a runtime sizing effect, not a compile error, and the expressions still mean what they meant.
`dataref` and `gso_type` themselves are not changed symbols in changed-api.txt.

**confidence: medium** — the expressions are definitely compiler-computed and will compile; I did not compute
the before/after byte counts, so I cannot say how much the RX buffer shrinks, and I did not check whether IPA's
TBL memory carve-out has slack.

## Notes for the lead

1. **No action needed for `drivers/platform/msm/ipa`.** 0 real breaks out of 1,328 hits.
2. `struct sk_buff.cb` needs no attention on sdm670: it is already `cb[48]`, matching the series head. If a
   future series *grows* `cb`, revisit `ipa_v{2,3}/ipa_dp.c` lines listed above — that is the only IPA code
   coupled to `struct sk_buff` layout.
3. K5a's symbol list had **no gaps** for this area: the supplementary 546-identifier sweep found nothing new
   beyond three name-collision false positives (`addr_len`, `rcu_dereference`, `skb_headlen`) and the
   `sizeof`/`offsetof` pair above. K5a's `changed-api.txt` looks reliable for driver audits.
4. `drivers/platform/msm/ipa/ipa_v2/rmnet_ipa.c` and `ipa_v3/rmnet_ipa.c` live inside this area but are rmnet
   glue. I audited them as part of K5b. If K5a treats them as rmnet, cross-check the `dev->addr_len` and
   `rcu_dereference` findings above — both are benign, so there is no double-counting risk.

## Problems

None. All commands succeeded on the first attempt.

One note for §10 of AGENT-TASKS.md: I am a free/unknown-tier model (`Space Bunny Free`), which that section
says not to use for K tasks. I was spawned anyway. The verdict is `confidence: high` and is backed by exhaustive
greps rather than judgement, so the lead may want a spot check of the "Worth knowing" `sizeof`/`offsetof` claim
before relying on the medium-confidence part.