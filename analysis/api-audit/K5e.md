<!-- task: K5e | agent: Space Bunny Free (space-bunny-free) | date: 2026-10-03 -->
# K5e: changed kernel API vs sdm670 cnss / icnss / embms

## Summary
- **All three assigned paths exist at `a30605a54f3b`**, and I audited all of them:
  `drivers/net/wireless/{cnss, cnss2, cnss_crypto, cnss_genl, cnss_prealloc, cnss_utils}` = **42 files**;
  `drivers/soc/qcom/icnss.c` = **1 file** (plus its header `include/soc/qcom/icnss.h`);
  `net/embms_kernel/` = **3 files**. There is no `drivers/soc/qcom/icnss2.c` and no other
  `icnss*.c` — `icnss` is exactly one `.c` file.
- **Reused from the retired K5f, then re-verified from scratch.** I re-ran every command myself and
  **regenerated my TSV from my own sweep**; no row was copied from `K5f.tsv`. My 142 cnss hits are
  a *strict superset-by-identity* of K5f's: the 140 unique `file:line` pairs in
  `origin/agent/K5f:analysis/api-audit/K5f.tsv` for the cnss area all appear in my TSV, and every
  `file:line` I add is in `icnss` or the bonus `wcnss` sweep. So K5f's cnss sweep is confirmed
  independently, hit for hit.
- **Hit counts (130 unique symbols, 132 rows, from `agent/K5a`):** cnss family **142**
  (`ctx` 89, `cb` 22, `desc` 15, `image` 13, `ops` 3); `icnss.c` + `icnss.h` **52**
  (`ops` 40, `ctx` 12); `net/embms_kernel/` **0**; bonus `drivers/soc/qcom/wcnss/` **1**.
  **TSV = 195 rows.** 5 most-hit symbols overall: `ctx` 101, `ops` 43, `cb` 22, `desc` 15, `image` 13.
- **REAL breaks: 0. Benign: 195 (100%).** Every hit is a generic-name collision with a driver-local
  variable or struct member (`priv->ops`, `evt->cb`, `struct logger_context *ctx`,
  `struct esoc_desc *desc`, and firmware-image log strings). Nothing in my area names
  `sk_buff.cb`, `ubuf_info`, `skb_shared_info`, `bpf_prog`, `netdev_xdp`, `ndo_xdp` or any BPF type.
- **What the lead must look at first.** Two things, neither an API break:
  1. **I overturned K5f's defconfig conclusion.** `CONFIG_CNSS_UTILS` is **not** off —
     `drivers/soc/qcom/Kconfig:693-695` has `config ICNSS … select CNSS_UTILS`, and `CONFIG_ICNSS=y`
     in **all four** defconfigs, so `drivers/net/wireless/cnss_utils/cnss_utils.c` **is** compiled.
     K5f only read `gts4lv_defconfig`; the two `*_eur_open_defconfig` files are 6023 lines, not 810.
  2. **`net/embms_kernel/` is dead code.** It has no Kconfig, is **not** referenced by `net/Makefile`,
     and its Makefile is an out-of-tree kbuild file (`KERNEL_SRC ?= /lib/modules/…`). It is never
     compiled by the kernel build, so the series cannot break it — but it is also silently not built.
  3. Nothing in my area touches the `skb->cb` 0-4 handoff contract, and **the series touches
     zero files in my entire area** (only the 7 nonexistent `bcmdhd_101_16` commits under
     `drivers/net/wireless`, all `SKIPDEV`).

---

## 1. Which paths exist — and which do not

All existence checks at `a30605a54f3b`.

| Assigned path | Exists? | Evidence |
|---|---|---|
| `drivers/net/wireless/cnss*/` | **Yes, 6 dirs, 42 files** | see file list below |
| `drivers/soc/qcom/icnss*.c` | **Yes — exactly one file, `drivers/soc/qcom/icnss.c`** | `git ls-tree -r --name-only a30605a54f3b -- drivers/soc/qcom \| grep -i icnss` → `drivers/soc/qcom/icnss.c` |
| `net/embms_kernel/` | **Yes, 3 files, 1264 lines** | `git ls-tree -r --name-only a30605a54f3b -- net/embms_kernel` → `Makefile`, `embms_kernel.c` (1031 lines), `embms_kernel.h` (233 lines) |

Whole-tree existence sweep for `icnss` (3 hits, so nothing is missed):

```
git -C ~/work/k670 ls-tree -r --name-only a30605a54f3b | grep -i icnss
→ Documentation/devicetree/bindings/cnss/icnss.txt
  drivers/soc/qcom/icnss.c
  include/soc/qcom/icnss.h
```

Files audited in the cnss family (42):

| Dir | files | Kconfig symbol |
|---|---|---|
| `cnss/` | 12 (`Kconfig`, `Makefile`, `cnss_common.c`, `cnss_common.h`, `cnss_pci.c`, `cnss_sdio.c`, `logger/{Kconfig,Makefile,debugfs.c,logger.h,main.c,nl_service.c}`) | `CONFIG_CNSS`, `CONFIG_CNSS_PCI`, `CONFIG_CNSS_SDIO`, `CONFIG_CNSS_LOGGER` |
| `cnss2/` | 20 | `CONFIG_CNSS2` |
| `cnss_crypto/` | 2 (`Makefile`, `cnss_secif.c`) | `CONFIG_CNSS_CRYPTO` |
| `cnss_genl/` | 3 (`Kconfig`, `Makefile`, `cnss_nl.c`) | `CONFIG_CNSS_GENL` |
| `cnss_prealloc/` | 2 | `CONFIG_WCNSS_MEM_PRE_ALLOC` |
| `cnss_utils/` | 3 (`Kconfig`, `Makefile`, `cnss_utils.c`) | `CONFIG_CNSS_UTILS` |

**Negative findings carried over from K5f and re-confirmed** (both still valid, both outside my
assigned area now, listed so the lead knows they were not skipped):

| Check | Result |
|---|---|
| Samsung / Exynos / `wcn*` / `ssr` directory under `drivers/net/wireless/` | **none** — `ls-tree -d --name-only a30605a54f3b -- drivers/net/wireless/` returns 22 dirs, none matching |
| `security/samsung` | **does not exist** (`ls-tree -d` empty) |
| any path matching `sec_net` | **none** |

---

## 2. What the defconfigs actually build from my area — and a correction to K5f

All four defconfigs exist:

```
git -C ~/work/k670 ls-tree -r --name-only a30605a54f3b arch/arm64/configs | grep gts4lv
→ arch/arm64/configs/gts4lv_defconfig              (810 lines)
  arch/arm64/configs/gts4lv_eur_open_defconfig     (6023 lines)
  arch/arm64/configs/gts4lvwifi_defconfig          (808 lines)
  arch/arm64/configs/gts4lvwifi_eur_open_defconfig (6023 lines)
```

| File | built by | hits on the 130 symbols |
|---|---|---|
| `drivers/net/wireless/cnss_genl/cnss_nl.c` | `CONFIG_CNSS_GENL=y` (all 4 defconfigs) | **6** |
| `drivers/net/wireless/cnss_prealloc/cnss_prealloc.c` | `CONFIG_WCNSS_MEM_PRE_ALLOC=y` (all 4) | 0 |
| `drivers/net/wireless/cnss_utils/cnss_utils.c` | **`CONFIG_CNSS_UTILS=y` — forced by `select` from `ICNSS`** (all 4) + explicitly `=y` in both `eur_open` defconfigs | 0 |
| `drivers/soc/qcom/icnss.c` | `CONFIG_ICNSS=y` (all 4) | **46** |
| `drivers/soc/qcom/wlan_firmware_service_v01.c` | `CONFIG_ICNSS=y`, same Makefile line | 0 |
| `drivers/net/wireless/cnss/{cnss_common.c, cnss_pci.c, cnss_sdio.c, logger/*}` (33 + 94 hits) | **NOT built**: `CONFIG_CNSS` off, `CONFIG_CNSS_LOGGER` off | 136 (irrelevant) |
| `drivers/net/wireless/cnss2/*` (9 hits) | **NOT built**: `# CONFIG_CNSS2 is not set` | — |
| `drivers/net/wireless/cnss_crypto/cnss_secif.c` | **NOT built**: `# CONFIG_CNSS_CRYPTO is not set` | 0 |

### The correction to K5f — `CONFIG_CNSS_UTILS` is ON

K5f wrote "the defconfig builds only `cnss_genl` … and `cnss_prealloc` … `cnss`, `cnss2`,
`cnss_utils`, `cnss_crypto` are off". That is **wrong for `cnss_utils`**, and the reason is a Kconfig
`select`, which a defconfig grep cannot see:

```
drivers/soc/qcom/Kconfig:693-695  @ a30605a54f3b
  config ICNSS
          tristate "Platform driver for Q6 integrated connectivity"
          select CNSS_UTILS
```

`CNSS_UTILS` is a `bool` (`drivers/net/wireless/cnss_utils/Kconfig:1`), so `select` forces it to `y`
whenever `ICNSS` is on. `CONFIG_ICNSS=y` at `gts4lv_defconfig:675`, `gts4lvwifi_defconfig:675`,
`gts4lv_eur_open_defconfig:4666`, `gts4lvwifi_eur_open_defconfig:4666`. The `eur_open` defconfigs
also set it literally (`gts4lv_eur_open_defconfig:2049 CONFIG_CNSS_UTILS=y`).
So **`drivers/net/wireless/cnss_utils/cnss_utils.c` is compiled** — 483 lines, 18 `EXPORT_SYMBOL`s,
and it includes only `<linux/module.h> <linux/kernel.h> <linux/slab.h> <linux/etherdevice.h>
<linux/debugfs.h> <net/cnss_utils.h>` — no `skbuff.h`, no `struct sk_buff`.
**Risk impact: none** (0 hits), but the defconfig-built surface of this area is larger than reported.

K5f's root cause of the error: it checked `gts4lv_defconfig` only, and its claim that
`gts4lvwifi_defconfig` is "identical … in every Wi-Fi line" is true, but it never opened the two
`eur_open` defconfigs, which are a completely different and much larger file.

**confidence: high** — `ls-tree`, four `git show … | grep` reads, and the Kconfig text quoted above.

---

## 3. The 5 symbols that hit at all, and what each hit actually is

Only **5 of the 130** symbols produce a single hit anywhere in my area. The other 125 produce zero.
That alone is the headline: the changed API simply has no surface in CNSS/ICNSS/eMBMS.

### `ctx` — 101 hits (89 cnss, 12 icnss) — the changed field is `struct ubuf_info.ctx`

`ubuf_info.ctx` moved inside an anonymous union after `unsigned long desc`. **Nothing in my area
declares or uses `ubuf_info`** — explicit check:
`git grep -n 'ubuf_info' a30605a54f3b -- <my area>` → **0 lines**.

| Where | What the hit is | count |
|---|---|---|
| `cnss/logger/*` (`debugfs.c`, `logger.h`, `main.c`, `nl_service.c`) | the logger's own `struct logger_context *ctx`, defined at `drivers/net/wireless/cnss/logger/logger.h:78`; 79 of the 89 | 79 |
| `cnss/cnss_common.c:429,434,441,446`, `cnss/cnss_sdio.c:724,736,740,751,758` | `void *ctx` parameter of the TSF-captured IRQ handler pair | 9 |
| `cnss2/main.c:1240` | `void *ctx` in `int (*cb)(void *ctx, void *event, int event_len)` | 1 |
| `icnss.c:797,799,1253,1255,1265,1267,3315,3343,3360,3386`, `icnss.h:126,129` | `void *ctx` parameter of `icnss_vph_notify` / `fw_error_fatal_handler` / `fw_crash_indication_handler` / `__icnss_request_irq` / `icnss_ce_free_irq` | 12 |

Verified example — `cnss/cnss_common.c:428-437` @ `a30605a54f3b` is
`cnss_common_register_tsf_captured_handler(struct device *dev, irq_handler_t handler, void *ctx)`
forwarding `ctx` to `pf_ops->register_tsf_captured_handler(handler, ctx)`. Plain pass-through of a
caller's cookie; no `ubuf_info` involved anywhere on the path.
**confidence: high** — read at the cited lines; `ubuf_info` count is 0.

### `ops` — 43 hits (3 cnss/cnss2, 40 icnss) — the changed field is `struct bpf_prog_aux.ops`

`bpf_prog_aux.ops` changed from `const struct bpf_verifier_ops *` to `const struct bpf_prog_ops *`.
**Nothing in my area mentions BPF at all** —
`git grep -n -E 'bpf_prog_aux|struct bpf_prog|bpf_prog_array|bpf_verifier_ops' a30605a54f3b -- <my area>`
→ **0 lines**.

| Where | What the hit is | count |
|---|---|---|
| `icnss.c:430,2128,2137,2318,2330,2358,2366,2388,2404,2487,2493,2570,2573,2596,2621,2629,2630,2637,2732,2744,2755,2767,3255,3267,3273,3279,3289,3300,5338,5342,5367,5371,5396,5400,5425,5429` + `icnss.h:111,112,113,116` | the driver's own `struct icnss_driver_ops *ops`, defined at `include/soc/qcom/icnss.h:39`, stored as `priv->ops` (`icnss.c:430` inside `static struct icnss_priv`) and `penv->ops`; its members are `probe`, `remove`, `shutdown`, `reinit`, `uevent`, `set_therm_state`, `idle_shutdown`, `idle_restart`, `pm_suspend`, `pm_resume`, `suspend_noirq`, `resume_noirq` | 40 |
| `cnss2/genl.c:90` | `.ops = cnss_genl_ops` — a `struct genl_ops` initializer | 1 |
| `cnss_genl/cnss_nl.c:73,76` | `static int cld80211_pre_doit(const struct genl_ops *ops, struct sk_buff *skb, …)`, then `u8 cmd_id = ops->cmd;` — the netlink pre_doit parameter | 2 |

**confidence: high** — `struct icnss_driver_ops` read at `include/soc/qcom/icnss.h:39-42`;
`icnss.c:430` read at the cited line; the BPF grep returns 0.

### `cb` — 22 hits (22 cnss, 0 icnss) — the changed item is `struct sk_buff.cb` (72→48, MPTCP only)

**Nothing in my area reads or writes `skb->cb` as bytes.** Only 4 `->cb` token hits exist in the whole
area and all are the logger's own struct member:

```
git grep -n -- '->cb' a30605a54f3b -- <my area>
→ cnss/logger/nl_service.c:127,129,210,234     (evt->cb / cur->cb)
```
`evt` and `cur` are `struct logger_event_handler` entries — `list_for_each_entry(evt, &cur->event_list,
list)` at `nl_service.c:125` — and that struct's `cb` member is declared
`int (*cb)(struct sk_buff *skb);` at `drivers/net/wireless/cnss/logger/logger.h:43-48` (line 47).
The member *takes* a `struct sk_buff *`; it does not live inside one.

| Where | What the hit is | count |
|---|---|---|
| `cnss/logger/nl_service.c:127,129,189,194,210,222,227,234,262,269,276,286,293,300` + `logger/logger.h:47` | the logger's own per-event callback slot | 15 |
| `cnss_genl/cnss_nl.c:45,83,111,128` | `cld80211_cb cb;` — the callback member of the driver's own `struct cld_ops`, defined at `cnss_nl.c:44-47`; `cld80211_cb` is typedef'd at `include/net/cnss_nl.h:84` (Qualcomm header, **untouched by the series**) | 4 |
| `cnss2/main.c:1240` | `int (*cb)(void *ctx, void *event, int event_len)` signature | 1 |
| `cnss2/pci.c:2813,2837` | the strings `"MHI status cb is called with reason …"` / `"Unsupported MHI status cb reason: …"` | 2 |

**On the 72→48 shrink:** it is not a risk here, and it is not a risk anywhere on sdm670.
`git show a30605a54f3b:include/linux/skbuff.h | grep -n 'cb\['` → `662: char cb[48] __aligned(8);`
— sdm670 already has the 48-byte form, it never had the MPTCP variant. And the `cb[72]` line the
series deletes was inside `#ifdef CONFIG_MPTCP` in the base (visible in
`git diff d54533f1546b baa585f67e0e -- include/linux/skbuff.h`), while
`grep -c '^CONFIG_MPTCP'` is **0** in all four defconfigs.
**confidence: high** — every hit read; both `cb[48]` lines quoted from the two trees.

### `desc` — 15 hits (all `cnss/cnss_pci.c`) — the changed field is `struct ubuf_info.desc`

`ubuf_info` count is 0 in my area, so none of these can be it.

| Where | What the hit is | count |
|---|---|---|
| `cnss/cnss_pci.c:2949,3013,3014,3015,3016,3019` | `struct esoc_desc *desc;` local of the eSOC/member-CLUT power-profile lookup, stored into `penv->esoc_desc` | 7 |
| `cnss/cnss_pci.c:3435,3444,3445,3446,3447,3448,3453,3454` | `struct hash_desc desc;` local of the SHA256 firmware-signature check (`crypto_alloc_hash` / `crypto_hash_digest`) | 8 |
| `cnss/cnss_pci.c:1272` | the string `"cnss: image desc allocation failure"` | 1 (overlaps the `image` hit) |

**confidence: high** — read at the cited lines.

### `image` — 13 hits (all cnss/cnss2) — the changed item is `struct bpf_binary_header.image`

`bpf_binary_header` does not appear in my area (BPF grep = 0). Every hit is a comment or a
`pr_err()`/`pr_dbg()`/`pr_info()`/`cnss_fatal_err()` **string literal** about the WLAN firmware
image: `cnss/cnss_pci.c:175` (comment `/* FW image descriptor lists */`), `1240` (comment
`/* meta data file has image details */`), `1272`, `1328`, `1333`, `1353` (comment
`/* one region for one image file */`), `1396`, `1959`, `1962`; and
`cnss2/pci.c:2137` (`"Failed to load M3 image: %s"`), `2686`, `2696`, `2712`.
**confidence: high** — string literals and comments, no identifier.

### `net/embms_kernel/` — 0 hits, and it is not compiled at all

Two independent facts, both worth reporting.

**(a) 0 of the 130 symbols appear.** 1264 lines of code, zero hits. Sanity-checked: the same grep
machinery finds `skb` 10 times in `embms_kernel.c`, so the 0 is real, not a broken pathspec.

**(b) The directory is dead code — the kernel build never sees it.**

| Evidence | Command / result |
|---|---|
| no Kconfig | `git ls-tree -r --name-only a30605a54f3b -- net/embms_kernel` → only `Makefile`, `embms_kernel.c`, `embms_kernel.h` |
| not referenced by the build | `git show a30605a54f3b:net/Makefile \| grep -i embms` → exit 1, no output |
| out-of-tree kbuild Makefile | `net/embms_kernel/Makefile:3` `KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build`, `:7` `obj-m += embms_kernel.o`, plus hand-rolled `all:` / `modules_install:` / `clean:` targets |
| it is a loadable module | `embms_kernel.c:1029-1031` `module_init(start_embms); module_exit(stop_embms); MODULE_LICENSE("GPL v2");` |
| nothing else in the tree references it | `git grep -n 'embms_kernel' a30605a54f3b` → only its own `Makefile:7` and `embms_kernel.c:39` |

Its one interesting hook is `embms_kernel.c:1006-1007`,
`RCU_INIT_POINTER(embms_tm_multicast_recv, …)`, which fills the consumer slot exported by
`net/core/dev.c:4226-4227` and called at `net/core/dev.c:4314-4316`. That slot is in core TCP, **not**
in my area, and the module is never built, so the eMBMS tunnel is simply absent on this device —
which is almost certainly what you want, since eMBMS is a Qualcomm legacy multicast feature.
**confidence: high** for both (a) and (b); every command above is reproducible.

---

## 4. The `skb->cb` bytes 0-4 handoff contract (IPA ↔ WLAN) — nothing in my area touches it

The producer is as described in my brief. I verified it at `a30605a54f3b`:

`drivers/platform/msm/ipa/ipa_v3/ipa_dp.c:2653-2660`
```
2653  /* Metadata Info ... |   3     |   2     |    1        |   0   | ... */
2659  *(u16 *)rx_skb->cb = ((metadata >> 16) & 0xFFFF);
2660  *(u8 *)(rx_skb->cb + 4) = ucp;
```

**Answer: no. Zero files in `drivers/net/wireless/cnss*/`, `drivers/soc/qcom/icnss.c`,
`include/soc/qcom/icnss.h` or `net/embms_kernel/` read or write those bytes.** The only `->cb` tokens in
the whole area are the 4 logger struct-member hits at `cnss/logger/nl_service.c:127,129,210,234`,
and the `sk_buff.cb` size is unchanged at 48 on sdm670 (see §3 `cb`).

The real partner on the WLAN side is `drivers/staging/qca-wifi-host-cmn/dp/wifi3.0/dp_ipa.c`, which
is **K5c's area, not mine**. A grep for `skb->cb` under `drivers/staging/qca-wifi-host-cmn` and
`drivers/staging/qcacld-3.0` returned **0 lines**, so on sdm670 the producer at `ipa_dp.c:2659-2660`
appears to have **no in-kernel reader at all** — the WLAN RX path goes through QDF buffers rather
than IPA-owned `skb`s. K5c should confirm this; if it is right, the `skb->cb` 0-4 contract is not a
live risk on this SoC and the `cb[72]`→`cb[48]` question is moot.
**confidence: medium** — the 0-hit result is solid, but "no reader" is a stronger claim than "no hit
on this grep" and I did not trace every QDF receive path.

---

## 5. Does the series touch my area? No — and this is the cheapest strong result in the report

```
git -C ~/work/k670 diff --name-only d54533f1546b baa585f67e0e -- drivers/net/wireless net/embms_kernel drivers/soc/qcom
→ drivers/net/wireless/bcmdhd_101_16/Makefile
  drivers/net/wireless/bcmdhd_101_16/dhd_linux_priv.h
  drivers/net/wireless/bcmdhd_101_16/dhd_pcie_linux.c
  drivers/net/wireless/bcmdhd_101_16/wl_android.c
  drivers/net/wireless/bcmdhd_101_16/wl_cfg80211.c
  drivers/net/wireless/bcmdhd_101_16/wl_cfg80211.h
  drivers/net/wireless/bcmdhd_101_16/wl_cfgvendor.c
```

Broken down per area:

| Area | Files the series changes |
|---|---|
| `drivers/net/wireless/cnss*` | **0** |
| `net/embms_kernel` | **0** (`git diff --name-only … -- net/embms_kernel \| wc -l` → 0) |
| `drivers/soc/qcom` | **0** (`… \| wc -l` → 0) |
| `include/soc/qcom`, `include/net/cnss_nl.h`, `include/net/cnss_utils.h` | **0** |
| `drivers/net/wireless/` (any) | 7 files, all under `bcmdhd_101_16` |

`icnss` and `embms` do not even exist in the series tree: `git ls-tree -r --name-only <c> | grep -iE
'icnss|embms'` returns nothing at either `d54533f1546b` (series base) or `baa585f67e0e` (series head).
So there is no counterpart to diff against, and no conflict is possible in any file I audited.

### The 7 `bcmdhd_101_16` commits: modify/delete, resolution DROP

`bcmdhd_101_16` **does not exist** in sdm670 (`git ls-tree -d a30605a54f3b -- drivers/net/wireless/bcmdhd_101_16`
→ empty; the tree uses Qualcomm `qcacld-3.0`). 8 series commits touch `drivers/net/wireless/`
(`git log --oneline d54533f1546b..baa585f67e0e -- drivers/net/wireless/`), and cross-referencing
`analysis/exyhyperbrick-trial/results.tsv` shows they are already handled without content work:

| commit | subject (short) | `results.tsv` status |
|---|---|---|
| `f52b4ac0d5e4` | bcmdhd: Arm cold reset after repeated SET_SSID timeouts | `SKIPDEV` |
| `5a507f5b48ca` | bcmdhd: Disable PCIe runtime PM | `SKIPDEV` |
| `0c6f8a9a50ad` | BACKPORT: PM / wakeup: Show wakeup sources stats in sysfs | `CONFLICT` (modify/delete; it is a `kernel/power` commit — `conflict_detail.tsv` group `optional`) |
| `a2955f44d252` | bcmdhd_101_16: Don't require userspaces to set MFP params | `SKIPDEV` |
| `c5966ddb2d1a` | bcmdhd: preserve saved PCI state on suspend | `SKIPDEV` |
| `a692b92845f6` | bcmdhd: Send HANGED hang reason as nlattr | `SKIPDEV` |
| `fafe98309690` | bcmdhd: Harden cfgvendor async event payloads | `SKIPDEV` |
| `e3c22ea2b21a` | bcmdhd: Normalize country code, prevent "00" regdom breakage | `SKIPDEV` |

So only `0c6f8a9a50ad` reaches the conflict set, and only because it is a PM commit — the
`bcmdhd_101_16/dhd_linux_priv.h` edit is a side effect. **No Wi-Fi work survives the port**, which is
expected and correct: sdm670 uses `qcacld-3.0`.
**confidence: high** — read from `ls-tree`, `log`, and `results.tsv`.

---

## 6. Bonus sweep, outside my assigned area

`drivers/soc/qcom/wcnss/` (4 files: `Kconfig`, `Makefile`, `wcnss_vreg.c`, `wcnss_wlan.c`) is
**assigned to nobody**: K5f called it "K5d's area", but §4's K5d area is `net/qrtr/`, `net/ipc_router/`,
`drivers/soc/qcom/qmi_interface*.c`, which does not include it. I swept it anyway (130 symbols):
**1 hit**, `drivers/soc/qcom/wcnss/wcnss_wlan.c:1966` `static void wcnss_notify_vbat(enum qpnp_tm state,
void *ctx)` — a `void *ctx` parameter, benign. The row is in the TSV, clearly labelled `BONUS`.
It is gated on `CONFIG_WCNSS_CORE` (`drivers/soc/qcom/Makefile:113`), which is **not set** in any of
the four defconfigs (`# CONFIG_WCNSS_CORE is not set` at `gts4lv_eur_open_defconfig:4695`, absent from
the two small ones), so it is not compiled either way.
Also swept `drivers/soc/qcom/wlan_firmware_service_v01.{c,h}` (compiled by `CONFIG_ICNSS=y`,
`drivers/soc/qcom/Makefile:71`): **0 hits**. Neither bonus row needs the lead's attention.
**confidence: high** — grep results plus the `Makefile`/defconfig lines quoted.

---

## 7. Full verdict table

| Area | audited files | hits | real breaks | benign |
|---|---|---|---|---|
| `drivers/net/wireless/cnss/` + `logger/` | 12 | 127 | 0 | 127 |
| `drivers/net/wireless/cnss2/` | 20 | 9 | 0 | 9 |
| `drivers/net/wireless/cnss_genl/` | 3 | 6 | 0 | 6 |
| `drivers/net/wireless/cnss_utils/` | 3 | 0 | 0 | 0 |
| `drivers/net/wireless/cnss_prealloc/` | 2 | 0 | 0 | 0 |
| `drivers/net/wireless/cnss_crypto/` | 2 | 0 | 0 | 0 |
| `drivers/soc/qcom/icnss.c` | 1 | 46 | 0 | 46 |
| `include/soc/qcom/icnss.h` (header, bonus) | 1 | 6 | 0 | 6 |
| `net/embms_kernel/` | 3 | 0 | 0 | 0 |
| **assigned-area total** | **47** | **194** | **0** | **194** |
| bonus `drivers/soc/qcom/wcnss/` | 4 | 1 | 0 | 1 |
| **TSV total** | | **195** | **0** | **195** |

**REAL breaks: 0.** Not one call site in this area passes an old arity, relies on a changed field
offset, or names a removed symbol.

## 8. What I re-verified vs overturned from K5f

**Confirmed (6 of 7 claims):**
1. No Samsung/Exynos/`wcn*`/`ssr` directory under `drivers/net/wireless/` — 22 dirs, none matching.
2. `security/samsung` absent; no `sec_net` path anywhere.
3. **142 hits in the CNSS family, all benign — exact match, and my 140 unique `file:line` pairs are
   identical to K5f's set** (`comm` shows nothing in K5f's cnss set that I lack).
4. The 6 defconfig-built cnss hits are all in `cnss_genl/cnss_nl.c` and resolve to `struct cld_ops.cb`
   (`cnss_nl.c:44-45`, typedef `include/net/cnss_nl.h:84`) and the netlink `struct genl_ops *ops`
   parameter (`cnss_nl.c:73,76`) — not `sk_buff.cb`, not `bpf_prog_aux.ops`.
5. `techpack/` holds only `audio` and `stub`; there is no `techpack/wlan`.
6. 8 series commits touch `drivers/net/wireless`, all `bcmdhd_101_16`, which sdm670 does not have, so
   they are modify/delete. (I added the bonus: 7 are `SKIPDEV`, only `0c6f8a9a50ad` is `CONFLICT`.)
7. The real WLAN driver is `drivers/staging/qcacld-3.0` under `CONFIG_QCA_CLD_WLAN=y` — K5c's area.

**Overturned / corrected (1 claim):**
- **"`cnss_utils` is off / the defconfig-built surface is one file."** Wrong. `config ICNSS`
  `select CNSS_UTILS` (`drivers/soc/qcom/Kconfig:693-695`) and `CONFIG_ICNSS=y` in all four
  defconfigs, so `cnss_utils.c` **is** compiled. Root cause: only 2 of the 4 defconfigs were read.
  Risk impact **zero** (0 hits), but the built surface is `cnss_nl.c` + `cnss_utils.c` +
  `cnss_prealloc.c` + `icnss.c` + `wlan_firmware_service_v01.c`.

**Ownership note, not an error:** K5f assigned `drivers/soc/qcom/wcnss` to K5d; per §4 that file is in
nobody's area. Swept as a bonus (1 benign hit) and it is not compiled (`CONFIG_WCNSS_CORE` off).

## 9. Reproducing this

```bash
K=~/work/k670; SHA=a30605a54f3b
AR="drivers/net/wireless/cnss drivers/net/wireless/cnss2 drivers/net/wireless/cnss_crypto \
    drivers/net/wireless/cnss_genl drivers/net/wireless/cnss_prealloc drivers/net/wireless/cnss_utils \
    drivers/soc/qcom/icnss.c include/soc/qcom/icnss.h net/embms_kernel"
# input file (K5a owns it; revision used here is the tip of agent/K5a, 81f43cc)
git show origin/agent/K5a:analysis/api-audit/changed-api.txt   # 140 lines, 132 rows, 130 symbols
# the sweep, one git grep per symbol
while IFS= read -r s; do git -C $K grep -n -w -- "$s" $SHA -- $AR; done < symbols.txt
# the load-bearing negatives
git -C $K grep -n -- '->cb'        $SHA -- $AR   # 4 hits, all logger struct members
git -C $K grep -n 'ubuf_info'      $SHA -- $AR   # 0
git -C $K grep -n 'bpf_prog_aux'   $SHA -- $AR   # 0
git -C $K grep -n 'skb_shinfo'     $SHA -- $AR   # 0
git -C $K diff --name-only d54533f1546b baa585f67e0e -- drivers/soc/qcom net/embms_kernel | wc -l   # 0
```

Input-file note: I used the **tip of `agent/K5a` (`81f43cc`)**, not the `5d2fae5` revision named in my
brief. The tip is a superset (same `changed-api.txt` content plus two later K5a commits about stray
files in the shared kernel tree); the file itself is byte-identical in the part that matters — column 1
is a bare identifier in every row, so `git grep -w` matches. If K5a pushes a changed
`changed-api.txt`, the symbol set could grow; re-run §9's loop.

## Problems
None in execution: no command failed, none was retried. Both fallbacks I was given were unnecessary —
`git show origin/agent/K5f:analysis/api-audit/K5f.{md,tsv}` and
`git show origin/agent/K5a:analysis/api-audit/changed-api.txt` both worked first time.

Three things the lead must weigh, none of them a failure of the method:

1. **I overturned a K5f conclusion (§2).** K5f read only `gts4lv_defconfig`. Any other K5x report that
   reasoned from a single defconfig should be re-checked against all four. Confidence high: the
   `select` and the four `CONFIG_ICNSS=y` lines are quoted above.
2. **A Kconfig `select` is invisible to a defconfig grep.** If another audit concluded "config X is
   off because the defconfig does not mention it", it may be wrong for the same reason. The reliable
   test is `git grep -n '<select X' <sha> -- '*Kconfig*'`.
3. **Process note carried over from K5f, unchanged:** AGENT-TASKS.md §10 lists "Space Bunny Free"
   among models "not tested on this kind of task" and asks for a tier-2 model for K5a–f. I am that
   model. Every finding above is a grep or a file read with a cited line number, which is the class of
   claim §11.3 spot-checking is built for, but the lead should weight my `high` ratings accordingly —
   particularly the negative results, where a wrong pathspec would look identical to a clean area.