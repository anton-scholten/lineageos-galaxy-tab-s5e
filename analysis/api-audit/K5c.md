<!-- task: K5c | agent: Space Bunny Free | date: 2026-10-03 -->
# K5c: changed kernel API vs sdm670 qcacld / qca-wifi-host-cmn

## Summary
Both areas exist and both are compiled: `drivers/staging/qcacld-3.0` (827 files, tree
`9102b783a67d`) and `drivers/staging/qca-wifi-host-cmn` (905 files, tree `1a7f41ec422d`) at
`a30605a54f3b`, and `arch/arm64/configs/gts4lvwifi_defconfig:615` sets `CONFIG_QCA_CLD_WLAN=y`
(`drivers/staging/Makefile:46` adds `qcacld-3.0/`, and `drivers/staging/qcacld-3.0/Kbuild:13`
pulls in `../qca-wifi-host-cmn` from the same build).
Of the 130 distinct symbols in `analysis/api-audit/changed-api.txt`, **only 10 have any hit at
all** in these two areas; 120 have zero. Total raw hits: 5578 (qcacld-3.0 1397, qca-wifi-host-cmn
4181). **0 REAL breaks, 1 WATCH, everything else benign.**
The 5 most-hit symbols are `ops` 3035, `desc` 1035, `ctx` 779, `cb` 540, `items` 140 - all five
are generic identifiers used as *driver-private* names; the changed APIs behind them
(`bpf_prog_aux.ops`, `ubuf_info.desc/ctx`, `sk_buff.cb`, `bpf_prog_array.items`) are **not
referenced anywhere in either area**: `git grep -w -E 'bpf_prog|bpf_map|bpf_verifier_ops|
bpf_prog_aux|sk_filter|ubuf_info|bpf_prog_array'` over both areas returns nothing.
The single most useful result for the lead is the negative one: the entire BPF/XDP/filter half of
changed-api.txt (lines 10-16 and 49-83, ~45 symbols) **cannot** affect the Wi-Fi drivers, so
Wi-Fi does not need to be re-checked for the eBPF backport API surface.
**What the lead must look at first:** `drivers/staging/qca-wifi-host-cmn/qdf/linux/src/i_qdf_nbuf.h:341-342`
(the one line whose correctness depends on `sizeof(sk_buff.cb)`), and secondarily the pre-existing
`SKB_GSO_UDP_L4` latent break noted in "Extra findings" below.

## Areas and whether they are built

| Area | Exists at `a30605a54f3b` | Files | Built by our defconfig |
|---|---|---|---|
| `drivers/staging/qcacld-3.0` | yes, tree `9102b783a67d` | 827 | yes |
| `drivers/staging/qca-wifi-host-cmn` | yes, tree `1a7f41ec422d` | 905 | yes |

Evidence:

- `git -C ~/work/k670 ls-tree -d a30605a54f3b -- drivers/staging/qcacld-3.0` ->
  `040000 tree 9102b783a67d5390e5d649194997fac90958db33	drivers/staging/qcacld-3.0`
- `git -C ~/work/k670 ls-tree -d a30605a54f3b -- drivers/staging/qca-wifi-host-cmn` ->
  `040000 tree 1a7f41ec422db8fb025a5b1e4dfc1c7e34b8c03f	drivers/staging/qca-wifi-host-cmn`
- `arch/arm64/configs/gts4lvwifi_defconfig:615` -> `CONFIG_QCA_CLD_WLAN=y` (line 607 -> `CONFIG_STAGING=y`).
  Same two lines in `arch/arm64/configs/gts4lv_defconfig`.
- `drivers/staging/Makefile:46` -> `obj-$(CONFIG_QCA_CLD_WLAN)	+= qcacld-3.0/`
- `drivers/staging/qcacld-3.0/Kconfig:3` -> `config QCA_CLD_WLAN` (tristate, `default n`), so the
  defconfig line is what turns it on.
- `drivers/staging/qcacld-3.0/Kbuild:13` -> `WLAN_COMMON_ROOT := ../qca-wifi-host-cmn`
  (and `:19` `WLAN_COMMON_ROOT ?= ../qca-wifi-host-cmn`), so `qca-wifi-host-cmn` is part of the
  same module built by that one `CONFIG_QCA_CLD_WLAN=y`. **So does the defconfig build these
  drivers? Yes, both of them, as the `wlan` module.**
- Profile used: `CONFIG_QCA_CLD_WLAN_PROFILE` appears 0 times in the defconfig, so
  `drivers/staging/qcacld-3.0/Kbuild:16` / `:22` (`WLAN_PROFILE ?= default`) selects
  `drivers/staging/qcacld-3.0/configs/default_defconfig` via `Kbuild:54`.

## Method

Input list: `analysis/api-audit/changed-api.txt` from `agent/K5a`, fetched with
`git fetch origin agent/K5a` and read with `git show FETCH_HEAD:...` (140 lines, 130 distinct
column-1 symbols after `awk -F' \\| '` + `sort -u`).

For each of the 130 symbols, for each of the two areas:

```bash
git -C ~/work/k670 grep -n -w -F -e '<symbol>' a30605a54f3b -- '<area>'
```

Grep-method validation (so the zeros are trustworthy):

- `git grep -w` behaves as whole-word here: all 3035 recorded `ops` hits contain a standalone
  `ops`, i.e. `-w` did not let `wmi_ops` through on its own.
- Positive control: `skb_shinfo` (not in the list) is present in 5 files of the areas.
- Negative control: `skb_pagelen` is absent from the areas even without `-w`.
- The kernel tree was used read-only: only `grep`, `ls-tree`, `show`, `rev-parse` ran in it.

Output: `analysis/api-audit/K5c.tsv` - 112 data rows, tab-separated `file:line | symbol | change`.
5529 of the 5578 raw hits are the generic identifiers `ops` / `desc` / `ctx` / `cb` / `items`
used as driver-private names; those are collapsed into one `AGGREGATE <area>` row per symbol per
area, and every hit that genuinely touches a changed kernel field is listed individually. The
aggregates are reproducible with the grep command above.

## Hit counts

Per area and symbol (raw `git grep` hits):

| symbol | qcacld-3.0 | qca-wifi-host-cmn | total | touches a changed kernel field? |
|---|---|---|---|---|
| `ops` | 335 | 2700 | 3035 | no |
| `desc` | 326 | 709 | 1035 | no |
| `ctx` | 378 | 401 | 779 | no |
| `cb` | 276 | 264 | 540 | yes, 53 lines |
| `items` | 72 | 68 | 140 | no |
| `nr_frags` | 4 | 27 | 31 | yes, 28 lines |
| `refcnt` | 0 | 7 | 7 | no (comments/log strings) |
| `gso_type` | 2 | 3 | 5 | yes, all 5 |
| `image` | 4 | 0 | 4 | no (comments) |
| `sk_wmem_alloc` | 0 | 2 | 2 | yes, both |
| **total** | **1397** | **4181** | **5578** | |

### The 120 symbols with zero hits

`af_callback_keys af_family_clock_key_strings bpf_check bpf_compute_data_end
bpf_fd_array_map_clear bpf_func bpf_helper_changes_skb_data bpf_jit_blinding_enabled
bpf_map_area_alloc bpf_map_inc bpf_map_type_list bpf_prog_add bpf_prog_inc bpf_prog_lock_ro
BPF_PROG_RUN BPF_PROG_RUN_ARRAY BPF_PROG_RUN_ARRAY_CHECK bpf_prog_run_xdp bpf_prog_type_list
bpf_prog_unlock_ro bpf_register_map_type bpf_register_prog_type BPF_REG_TMP bpf_skb_cb clear_sk
convert_ctx_access copy_skb_header dev_change_xdp_fd ____dev_forward_skb dss_off
inet6_sk_rx_dst_set inet_twsk_free insns insnsi linear_payload_sz MAX_BPF_JIT_REG mptcp
mptcp_flags mptcp_static_key ndo_xdp netdev_xdp prog prog_attached progs __pskb_trim_head
rcu_assign_sk_user_data rcu_dereference_sk_user_data reg_type retransmits_timed_out
skb_clone_fraglist __skb_flow_dissect skb_flow_dissect_flow_keys_buf skb_orphan_frags
skb_pagelen _skb_refdst skb_steal_sock skc_tx_queue_mapping SK_FLAGS_TIMESTAMP sk_padding
sk_prot_alloc sk_protocol SK_PROTOCOL_MAX sk_rmem_schedule sk_txhash sk_tx_queue_clear
sk_tx_queue_get sk_tx_queue_set sk_type sock_lock_init SOCK_MPTCP sysctl_tcp_tw_reuse
tcp_ack_probe tcp_adjust_pcount tcp_cwnd_test tcp_data_queue_ofo tcp_death_row
tcp_event_new_data_sent tcp_fastopen_ctx tcp_init_nondata_skb tcp_init_tso_segs
tcp_may_update_window tcp_minshall_update tcp_mss_split_point tcp_nagle_test tcp_need_reset
tcp_ofo_queue TCPOPT_MPTCP tcp_queue_rcv tcp_queue_skb tcp_set_skb_tso_segs tcp_snd_wnd_test
tcp_sock_ops tcp_specific tcp_transmit_skb tcp_try_coalesce tcp_tso_acked tcp_tso_autosize
tcp_urg_mode tcp_v4_cookie_check tcp_v4_reqsk_destructor tcp_v4_reqsk_send_ack tcp_v4_send_reset
tcp_v6_connect tcp_v6_conn_request tcp_v6_cookie_check tcp_v6_destroy_sock tcp_v6_do_rcv
tcp_v6_hash tcp_v6_hnd_req tcp_v6_reqsk_destructor tcp_v6_reqsk_send_ack tcp_v6_send_reset
tcp_v6_syn_recv_sock tcp_write_err tcp_write_timeout tcp_xmit_probe_skb tcp_xmit_size_goal
unpriv_array xdp_buff xdp_netdev_command`

Note that 61 of these 120 are `(CONFIG_MPTCP)` symbols. `CONFIG_MPTCP` appears 0 times in
`arch/arm64/configs/gts4lvwifi_defconfig` and 0 times in `gts4lv_defconfig` @ `a30605a54f3b`, so
they would be irrelevant even if they did hit.

## Findings

### REAL breaks: none

I found no line in either area that calls a changed prototype with the old arity/types, or that
depends on a changed field offset or width. **confidence: high** - every one of the 130 symbols
was grepped individually, and the four "risky" categories were each checked separately below.

### 1. WATCH - `sk_buff.cb` size, one compile-time assert

`drivers/staging/qca-wifi-host-cmn/qdf/linux/src/i_qdf_nbuf.h:341-342` @ `a30605a54f3b`:

```c
QDF_COMPILE_TIME_ASSERT(qdf_nbuf_cb_size,
	(sizeof(struct qdf_nbuf_cb)) <= FIELD_SIZEOF(struct sk_buff, cb));
```

This is the only line in either area whose *correctness* depends on `sizeof(sk_buff.cb)`. The
series change (`changed-api.txt` line 21) drops the `#ifdef CONFIG_MPTCP` 72-byte variant and
leaves only `char cb[48] __aligned(8)`, i.e. it can only ever make `cb` **smaller or equal**.
Verified at both ends of the series: `d54533f1546b:include/linux/skbuff.h:668-672` has the
`#ifdef CONFIG_MPTCP cb[72] / #else cb[48]` pair, and `baa585f67e0e:include/linux/skbuff.h:749`
has only `char cb[48] __aligned(8)`. So the assert is safe either way. The struct being asserted
on is documented as `MAX 48 bytes` in the comment ending at `i_qdf_nbuf.h:339`. Verdict: it
compiles and it holds. **confidence: high** - both header versions read directly, plus the defconfig.

### 2. BENIGN - `skb_shared_info.nr_frags` moved position (28 real field hits)

changed-api.txt line 19: `unsigned char nr_frags;` (field 0) -> `__u8 __unused; __u8 meta_len;
__u8 nr_frags;` (field 2). Verified:
`d54533f1546b:include/linux/skbuff.h:414-420` vs
`baa585f67e0e:include/linux/skbuff.h:490-494`. `__u8` is `unsigned char`, so the *type* did not
actually change; only the offset did.

Every hit reaches the field by name (`skb_shinfo(skb)->nr_frags`, `sh->nr_frags`), so the compiler
recomputes the offset against the new header. The 7 places that declare a
`struct skb_shared_info *` (`qca-wifi-host-cmn/qdf/linux/src/qdf_nbuf.c:897,3806,3914,3945,3979`
and `qcacld-3.0/core/dp/txrx3.0/dp_fisa_rx.c:769,885`) only take a pointer - no `memcpy`, no
`sizeof`, no `offsetof` on `struct skb_shared_info` exists anywhere in the two areas
(`grep -E 'sizeof\(\s*struct skb(_shared_info)?\s*\)'` and `grep -E 'offsetof\('` both come back
with only driver-local structs: `tDot11f*`, `struct bss_description`, `struct wlan_bcn_frame`,
`struct scan_chan_list_params`, `struct msdu_id_info`). The remaining 3 `nr_frags` hits are QCA's
own field (`qcacld-3.0/core/dp/ol/inc/ol_txrx_stats.h:49 uint8_t nr_frags;`, reached via
`TXRX_STATS_TSO_CURR_MSDU`). **confidence: high** - the two header versions were read and the
absence of `memcpy`/`sizeof`/`offsetof` on `skb_shared_info` was grepped.

### 3. BENIGN - `skb_shared_info.gso_type` widened 16 -> 32 bit (5 hits)

changed-api.txt line 20. Verified `unsigned short gso_type;`
(`d54533f1546b:include/linux/skbuff.h:420`) -> `unsigned int gso_type;`
(`baa585f67e0e:include/linux/skbuff.h:500`, also moved after `hwtstamps`).

- `qcacld-3.0/core/dp/txrx3.0/dp_fisa_rx.c:833` and `:897`: `shinfo->gso_type = SKB_GSO_UDP_L4;`
  - storing an `enum`/int constant compiles for either width. Extra: this file is not even
    compiled for our device (see "Extra findings"), so it is doubly inert.
- `qca-wifi-host-cmn/qdf/linux/src/i_qdf_nbuf.h:1505`: `(skb_shinfo(skb)->gso_type & SKB_GSO_TCPV4)`
  - bitmask test; the `SKB_GSO_*` values in sdm670 are `1 << 0` .. `1 << 15`
    (`a30605a54f3b:include/linux/skbuff.h:461-492`), all < 65536, so the widening cannot change
    the result.
- `qca-wifi-host-cmn/qdf/linux/src/i_qdf_nbuf.h:2045` and `:2056`:
  `gso_type == SKB_GSO_TCPV4` / `== SKB_GSO_TCPV6` - equality against a small bit value; the field
  only ever holds `SKB_GSO_*` bits, so widening is inert.

**confidence: high** - the enum values and both header versions were read.

### 4. BENIGN - `struct sock.sk_wmem_alloc` moved (2 hits)

`qca-wifi-host-cmn/qdf/linux/src/qdf_nbuf.c:3577` and `:3613`:
`atomic_sub(skb->truesize, &(skb->sk->sk_wmem_alloc));`. changed-api.txt line 35 says the field
only *moved* inside `struct sock`, type unchanged (`atomic_t`). Reached by name, `atomic_sub`
takes `&field` which the compiler resolves against the new header. **confidence: high.**

### 5. BENIGN - 53 `sk_buff.cb` hits

None of them depends on the size change:

- 8 x `qdf_mem_zero(skb->cb, sizeof(skb->cb))` / `memset(nbuf->cb, 0x0, sizeof(nbuf->cb))` /
  `memset(skb->cb, ...)`: use `sizeof`, so they follow whatever `cb` is.
- 6 x `(struct wlan_ipa_pm_tx_cb *)skb->cb` and 1 x `(void *)nbuf->cb`: the driver's own overlay
  struct, whose size is unchanged.
- 6 x IPA byte slots `skb->cb[0]`..`skb->cb[3]` (`qcacld-3.0/components/ipa/core/src/wlan_ipa_core.c:671,721,892,1034,1045,1046`
  and `qca-wifi-host-cmn/dp/wifi3.0/dp_ipa.c:1851`): a cross-driver contract with
  `drivers/platform/msm/ipa`, fixed byte indices in a driver-private layout, not a kernel field.
- 1 x `qca-wifi-host-cmn/qdf/linux/src/i_qdf_nbuf.h:2104`: `return &skb->cb[8];` - a hardcoded
  offset, but into the driver's own private area behind `struct qdf_nbuf_cb` (offset 0..7 is the
  QCA control block), not a kernel field.
- 2 x `qca-wifi-host-cmn/os_if/linux/qca_vendor.h:7447,7452`: `((void **)skb->cb)[2]` next to
  `nla_nest_cancel(skb, ...)` - here `skb` is an `nlmsghdr`, so this is `struct nlmsghdr.cb`.
- The rest are comments.

**confidence: high.**

### 6. BENIGN - `ops` 3035, `desc` 1035, `ctx` 779, `items` 140

These four symbols are the reason the raw count looks alarming; none of them is a use of the
changed field. Proof per symbol:

- `ops` -> changed fields are `bpf_prog_aux.ops` and `bpf_verifier_ops.{convert_ctx_access,
  reg_type}` (changed-api.txt lines 65, 82, 83). `git grep -w -E
  'bpf_verifier_ops|bpf_prog_ops|bpf_prog|bpf_map|bpf_skb|bpf_jit'` over both areas @ `a30605a54f3b`
  returns **nothing**. All 3035 hits are driver-private: `pld_context->ops->probe`,
  `soc->ops->ctrl_ops`, `wmi_handle->ops->convert_pdev_id_host_to_target`, `struct dsc_ops ops`,
  `struct wmi_ops *ops`.
- `desc` -> changed field is `sk_buff.ubuf_info.desc` (line 18). `git grep -w ubuf_info` over both
  areas returns **nothing**; neither does `zerocopy`, `tx_zerocopy_callback`,
  `tx_no_segment_cb`, `rx_zerocopy_callback`, `skb_zerocopy`, `tx_copy_threshold`,
  `zerocopy_threshold`, `tx_desc_unchunk`, `desc_frag_max`, `extract_frag_to_skb` - all 0 files.
  So neither driver implements the zerocopy callbacks that the `ubuf_info` re-layout
  (`baa585f67e0e:include/linux/skbuff.h:445-459`, anonymous union + new `atomic_t refcnt`) would
  affect. All 1035 hits are driver-private (`struct ol_txrx_fw_stats_desc_t *desc`,
  `tran->desc`, `iface_desc->desc`, and `struct ipa_rx_data` cast to `desc` at
  `qca-wifi-host-cmn/qdf/linux/src/i_qdf_ipa.h:209,211`, plus the `HAL_SET_FLD(desc, ...)` macros).
- `ctx` -> changed field is `sk_buff.ubuf_info.ctx` (line 17); same zero result for `ubuf_info`.
  All 779 hits are driver-private (`timer->ctx`, `sm->ctx`, `soc->ctx`, `wmi_handle->ctx[idx]`,
  the `QDF_NBUF_CB_{RX,TX}_FCTX` macros, `void *ctx` callback parameters).
- `items` -> changed field is `bpf_prog_array.items[]` (lines 62, 63). `git grep -w
  bpf_prog_array` returns **nothing**. All 140 hits are the English word in kernel-doc comments
  ("generic structure for all mlme CFG string items") plus QDF's own local arrays in
  `qca-wifi-host-cmn/qdf/test/` (`struct qdf_slist_test_item items[]`,
  `struct qdf_ptr_hash_test_item items[]`, `bool items[]`).

**confidence: high** - the negative greps are the evidence and they are cheap to re-run.

### 7. BENIGN - `refcnt` 7, `image` 4

`refcnt` hits are kernel-doc comments (`qca-wifi-host-cmn/dp/wifi3.0/dp_main.c:9821,9823`) and
`NAPI_DEBUG`/`QDF_DEBUG` format strings
(`qca-wifi-host-cmn/hif/src/hif_irq_affinity.c:503,514`, `hif_napi.c:1723,1734`), plus one doc
line `qca-wifi-host-cmn/umac/cmn_services/obj_mgr/inc/wlan_objmgr_cmn.h:353`. Neither
`struct sk_filter` nor `struct bpf_prog_aux` appears in either area. `image` hits are all comments
about the WLAN firmware image (`qcacld-3.0/components/ipa/core/src/wlan_ipa_core.c:3511`,
`core/hdd/inc/wlan_hdd_main.h:1795`, `core/hdd/src/wlan_hdd_driver_ops.c:65`,
`core/pld/inc/pld_common.h:93`); `struct bpf_binary_header` does not exist in these areas.
**confidence: high.**

## Extra checks beyond the changed-api.txt list

Done because a missed real break is the most expensive error here, and `changed-api.txt` covers
only 7 headers.

| Check | Result |
|---|---|
| `bpf_prog`, `bpf_map`, `bpf_verifier_ops`, `bpf_prog_ops`, `bpf_skb`, `bpf_jit` | 0 files in both areas |
| `bpf_prog_array`, `sk_filter`, `ubuf_info`, `bpf_prog_aux` | 0 files in both areas |
| `xdp`, `ndo_xdp`, `ndo_bpf`, `cls_bpf`, `bpf_tc_hook`, `dev_change_xdp_fd` | 0 files |
| `zerocopy`, `tx_zerocopy_callback`, `tx_no_segment_cb`, `rx_zerocopy_callback`, `skb_zerocopy`, `tx_copy_threshold`, `zerocopy_threshold`, `tx_desc_unchunk`, `desc_frag_max`, `extract_frag_to_skb` | 0 files |
| `skb_flow_dissect` (public wrapper, whose `net` param was added upstream but lives in `include/net/flow_dissector.h`, outside K5a's scope) | 0 files |
| `__skb_flow_dissect`, `____dev_forward_skb`, `dev_forward_skb` | 0 files |
| `skb_steal_sock`, `sk_tx_queue_set/clear/get`, `NO_QUEUE_MAPPING`, `skc_tx_queue_mapping` | 0 files |
| `tcp_tso_autosize`, all 60+ `tcp_*` symbols | 0 files |
| `skb_orphan_frags`, `skb_pagelen`, `skb_copy_ubufs`, `skb_set_owner_w` | 0 files |
| `sk_type`, `sk_protocol`, `sk_padding`, `sk_txhash`, `SK_PROTOCOL_MAX`, `sk_rcvbuf`, `sk_sndbuf`, `sk_ack_backlog` | 0 files |
| `offsetof(` against a kernel struct | none - all on `tDot11f*`, `bss_description`, `wlan_bcn_frame`, `scan_chan_list_params`, `msdu_id_info` |
| `sizeof(struct sk_buff)` / `sizeof(struct skb_shared_info)` | none |
| the other 9 `QDF_COMPILE_TIME_ASSERT` in the areas | all driver-local: power-of-two checks on `DP_RX_HIST_MAX`, `WLAN_HDD_ADAPTER_OPS_HISTORY_MAX`, and driver struct sizes (`dp_main.c:102,110,116,124`, `dp_tx.c:651`, `dp_types.h:986,989,992`, `wlan_hdd_main.h:1734`) |
| `skb_shared_info` | only `skb_shinfo(skb)` pointer use, never copied or sized |

## Extra findings (not series-caused, but worth passing on)

1. **`SKB_GSO_UDP_L4` does not exist in sdm670.**
   `drivers/staging/qcacld-3.0/core/dp/txrx3.0/dp_fisa_rx.c:833` and `:897` do
   `shinfo->gso_type = SKB_GSO_UDP_L4;`, but `git grep -F SKB_GSO_UDP_L4 a30605a54f3b` over the
   whole tree returns **only those two lines** - nothing defines it. sdm670's `SKB_GSO_*` enum in
   `include/linux/skbuff.h:461-492` ends at `SKB_GSO_SCTP = 1 << 15`; the symbol is also absent at
   the series base `d54533f1546b` and at the series head `baa585f67e0e`. This is a **pre-existing**
   latent break (present before any series commit is applied), so it is not K5c's finding to fix.
   It is harmless today only because the file is not compiled:
   `drivers/staging/qcacld-3.0/Kbuild:1488-1491` adds `dp_fisa_rx.o` only
   `ifeq ($(CONFIG_RX_FISA), y)`, and `CONFIG_RX_FISA := y` sits inside
   `ifeq ($(CONFIG_CNSS_QCA6490), y)` at
   `drivers/staging/qcacld-3.0/configs/default_defconfig:1044-1051`, while `CONFIG_CNSS_QCA6490`
   appears **0 times** in `arch/arm64/configs/gts4lvwifi_defconfig` @ `a30605a54f3b`.
   Flag it because it is one Kconfig flip away from breaking, and because if anyone ever turns
   `CONFIG_RX_FISA` on while cherry-picking, this line will fail for a reason that has nothing to
   do with the eBPF series. **confidence: high** - verified in all three trees plus the Kbuild and
   defconfig.

2. **Cross-driver `skb->cb` contract between Wi-Fi and IPA** (not a kernel-API issue).
   `qcacld-3.0/components/ipa/core/src/wlan_ipa_core.c:668-671` documents
   `skb->cb[0] = vdev_id`, `skb->cb[1].bit#1 = da_is_bcmc`, and `dp/wifi3.0/dp_ipa.c:1847-1851`
   documents the same. The writer is `drivers/platform/msm/ipa` (K5b's area). If the series or a
   conflict resolution changes either side's overlay struct, this is a *runtime* mismatch, not a
   build error, so it will not show up as a compiler error. Worth a one-line check by whoever owns
   K5b. **confidence: medium** - I did not read the IPA side; I only confirmed both Wi-Fi sides use
   the same fixed byte slots.

## Confidence

Overall: **high**. Every one of the 130 symbols was grepped individually against `a30605a54f3b` with
a validated whole-word grep (positive and negative controls in "Method"), the four categories that
could actually break a driver (changed prototype arity, changed field offset, changed field width,
`memcpy`/`offsetof`/`sizeof` against a changed struct) were each checked explicitly, and the
header-diff claims for `cb`, `nr_frags`, `gso_type` and `ubuf_info` were verified by reading
`include/linux/skbuff.h` at both `d54533f1546b` and `baa585f67e0e`. The verdict "no real break"
rests on a negative result, so it is only as good as the grep coverage; the one residual risk is
code that is only compiled under a config that is *off* today but might get turned on during the
port - the `dp_fisa_rx.c` / `CONFIG_RX_FISA` case in "Extra findings" is the concrete instance of
that risk and it is reported above.

## Problems

None. Every command succeeded on the first run. Two notes on the inputs, neither a failure:
- The prompt's example command `git -C /home/anon/work/k670 ...` has a typo; the tree is at
  `~/work/k670` and `pwd` confirmed it before anything was run. The kernel tree was
  never written to.
- `git fetch origin agent/K5a` and `git show FETCH_HEAD:analysis/api-audit/changed-api.txt`
  succeeded, so `changed-api.txt` was used as-is and was not regenerated.