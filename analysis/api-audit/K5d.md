<!-- task: K5d | agent: Space Bunny Free | date: 2026-10-03 -->
# K5d: changed kernel API vs sdm670 net/qrtr, net/ipc_router, qmi_interface

## Summary
All three paths exist. `drivers/soc/qcom/qmi_interface*.c` matches **exactly one `.c` file**,
`drivers/soc/qcom/qmi_interface.c` (2233 lines); I also audited its private header
`qmi_interface_priv.h` and the public `include/soc/qcom/msm_qmi_interface.h` because they are the same
translation unit. Hit counts for the 130 symbols of `changed-api.txt`: **`net/qrtr` 1 hit, `net/ipc_router`
1 hit, `qmi_interface.c` 0 hits** — only **one** symbol hits at all (`ops`, 2 lines), so **129 of 130 symbols
have zero occurrences** and there is no "top 5". Both `ops` hits are **benign** (they are `struct sock.ops`,
not the `struct bpf_prog_aux.ops` the series retyped). **0 REAL breaks from the 130-symbol list.**
The series does **not touch this area at all** (empty `git diff --name-only d54533f1546b baa585f67e0e --
net/qrtr net/ipc_router drivers/soc/qcom`). The defconfigs build `ipc_router_core.c`,
`ipc_router_socket.c`, `ipc_router_security.c` and `qmi_interface.c`; they do **not** build `net/qrtr`
or `ipc_router_fifo_xprt.c`. Widening past the 7 audited headers (see §4) I found **1 REAL break**, in a
built file: `net/ipc_router/ipc_router_core.c:1384` calls `wakeup_source_register()` with the old
1-argument arity. **Lead: fix `ipc_router_core.c:1384` and check the 12 other 1-argument callers listed in
§4.2; nothing else in this area is at risk.**

## 0. Method and provenance
- Kernel tree `~/work/k670`, read-only, always via `git -C`. Verified tips:
  sdm670 `a30605a54f3b92627d868f169c72ef9c6ef82123`, series base `d54533f1546b91f94eb4e445dfea3a94ffa58a74`,
  series head `baa585f67e0efc9f1efa046d0b0e76955ca4c8d5`,
  `git rev-list --count --no-merges d54533f1546b..baa585f67e0e` = 2599 (matches AGENT-TASKS.md §1.2).
- Input list: `git fetch origin agent/K5a`; used the known-good revision
  `git show 5d2fae520f0a22813e79b83b0d4328f8aa7f2402:analysis/api-audit/changed-api.txt`
  (round-1 push; `git ls-remote --heads origin 'agent/K5*'` shows no `agent/K5a-r2`, so I did not wait).
  That file has 132 data rows (lines 10-141) and **130 unique bare identifiers** after de-duplicating
  `skc_tx_queue_mapping` (L27/L37) and `refcnt` (L64/L69). **`changed-api.txt` was not modified.**
- Every one of the 130 was grepped with
  `git -C ~/work/k670 grep -n -w '<symbol>' a30605a54f3b -- <area>`.
- Grep sanity check (a zero result can mean a broken command): `ctx`, `prog`, `desc`, `cb`, `items`,
  `insns`, `refcnt` all give 0 in `net/ipc_router`, while `skb`, `endpoint`, `priv`, `port_ptr`,
  `wakeup_source_register` give 31, 13, 24, 236, 2 respectively. The area really does not use those
  identifiers — `net/ipc_router/ipc_router_core.c` is 4494 lines of code that names things
  `port_ptr`/`rport_ptr`/`rtx_port`, never `ctx` or `prog`.

## 1. Which paths exist (enumerated, not guessed)

| Path asked for | Exists at `a30605a54f3b`? | Files | Built by the defconfigs? |
|---|---|---|---|
| `net/qrtr` | **yes** | 5: `Kconfig`, `Makefile`, `qrtr.c` (1004 L), `qrtr.h` (31 L), `smd.c` (121 L) | **NO** |
| `net/ipc_router` | **yes** (new this round; never audited before) | 7: `Kconfig`, `Makefile`, `ipc_router_core.c` (4494 L), `ipc_router_fifo_xprt.c`, `ipc_router_private.h`, `ipc_router_security.c`, `ipc_router_security.h`, `ipc_router_socket.c` | **partly** — 3 of 5 `.c` files |
| `drivers/soc/qcom/qmi_interface*.c` | **yes** | glob matches exactly **1** `.c`: `drivers/soc/qcom/qmi_interface.c` (2233 L). Same-unit headers also audited: `drivers/soc/qcom/qmi_interface_priv.h`, `include/soc/qcom/msm_qmi_interface.h` | **yes** |

Commands:
```
git -C ~/work/k670 ls-tree -d a30605a54f3b -- net/qrtr
  -> 040000 tree eef4fb910b409d3520e93745ac1da0e235fc368c	net/qrtr
git -C ~/work/k670 ls-tree -d a30605a54f3b -- net/ipc_router
  -> 040000 tree 3040733d72e03733d83adfb65b8fcb6930bd60af	net/ipc_router
git -C ~/work/k670 ls-tree -r --name-only a30605a54f3b -- drivers/soc/qcom | grep 'qmi_interface'
  -> drivers/soc/qcom/qmi_interface.c
     drivers/soc/qcom/qmi_interface_priv.h
```
Note the glob does **not** match `drivers/soc/qcom/sysmon-qmi.c`. Round 1's area was `drivers/soc/qcom`
files matching `*qmi*`, which did include `sysmon-qmi.c`; this round's spec says
`qmi_interface*.c`, so `sysmon-qmi.c` is out of scope and is **not** a gap — round 1 already adjudicated
its 5 `desc` hits as benign (`sysmon_notifier_register(struct subsys_desc *desc)` parameter named `desc`,
unrelated to `struct ubuf_info.desc`).

## 2. Does the series touch this area? No.

```
git -C ~/work/k670 diff --name-only d54533f1546b baa585f67e0e -- net/qrtr net/ipc_router drivers/soc/qcom
  -> (no output, exit 0)
git -C ~/work/k670 diff --stat d54533f1546b baa585f67e0e -- net/qrtr net/ipc_router drivers/soc/qcom
  -> (no output)
```
`git ls-tree -d a30605a54f3b -- net/ipc_router` confirms `net/ipc_router` really is present, so the empty
result is a real "series leaves this alone", not a typo in the path.
**confidence: high** — the command is unambiguous and the path is confirmed to exist.

The area's **own** API headers are also untouched, which is the stronger statement (the .c files could
still break on them):
```
git -C ~/work/k670 diff --stat d54533f1546b baa585f67e0e -- include/linux/qrtr.h \
  include/linux/ipc_router.h include/linux/msm_ipc.h include/linux/ipc_router_xprt.h \
  include/linux/qmi_encdec.h include/linux/soc/qcom/smd.h include/linux/ipc_logging.h \
  include/soc/qcom/msm_qmi_interface.h include/linux/android_aid.h
  -> (no output; all 9 UNCHANGED)
```
**confidence: high** — checked each header individually.

## 3. The 130-symbol sweep

| Area | Symbols with >=1 hit | Hit lines | REAL breaks | Benign |
|---|---|---|---|---|
| `net/qrtr` (not built) | 1 (`ops`) | 1 | 0 | 1 |
| `net/ipc_router` (partly built) | 1 (`ops`) | 1 | 0 | 1 |
| `drivers/soc/qcom/qmi_interface.c` + `qmi_interface_priv.h` + `include/soc/qcom/msm_qmi_interface.h` | 0 | 0 | 0 | 0 |
| **total** | **1 of 130** | **2** | **0** | **2** |

129 of the 130 symbols have **zero** occurrences in this area. There is therefore no "top 5 most-hit
symbols"; the only symbol that hits is listed below.

### 3.1 `ops` — 2 hits, both BENIGN

- `net/ipc_router/ipc_router_socket.c:207` — `sock->ops = &msm_ipc_proto_ops;`  **file IS built**
- `net/qrtr/qrtr.c:929` — `sock->ops = &qrtr_proto_ops;`  **file is NOT built**

The only `ops` entry in `changed-api.txt` is line 65:
`ops | include/linux/bpf.h | struct bpf_prog_aux: const struct bpf_verifier_ops *ops; | ... const struct
bpf_prog_ops *ops; (TYPE changed)`.

`changed-api.txt` line 6 states column 1 is a bare identifier, and this is the bare-identifier
false-positive it warns about: `ops` is a field name used by a dozen unrelated structs. Both hits are
`struct sock.ops`, which is `struct proto *ops` in `include/net/sock.h` — **unchanged by the series**
(`git diff d54533f1546b baa585f67e0e -- include/net/sock.h` shows no `ops` member change), and the
assignment is to a `struct proto *` either way. Nothing about `struct bpf_prog_aux` is involved.
`net/qrtr/qrtr.c` does not reference BPF at all.
**confidence: high** — the two members are distinct fields in distinct structs and only one of them changed.

### 3.2 The whole `(CONFIG_MPTCP)` block of `changed-api.txt` is irrelevant here

Roughly 60 of the 132 rows are marked `(CONFIG_MPTCP)` REMOVED (`tcp_sock_ops`, `tcp_specific`,
`mptcp`, `tcp_v6_*`, `tcp_queue_skb`, ...). Two independent reasons they cannot bite:
1. They are all zero-hit in this area (covered by the sweep above).
2. `# CONFIG_MPTCP is not set` in both `*_eur_open_defconfig`s and absent from the other two.

**confidence: high** — `CONFIG_MPTCP` state read straight out of all four defconfigs.

## 4. What the defconfigs actually build

```
git -C ~/work/k670 ls-tree -r --name-only a30605a54f3b arch/arm64/configs | grep gts4lv
  -> arch/arm64/configs/gts4lv_defconfig
     arch/arm64/configs/gts4lv_eur_open_defconfig
     arch/arm64/configs/gts4lvwifi_defconfig
     arch/arm64/configs/gts4lvwifi_eur_open_defconfig
```
| Config | `gts4lvwifi_defconfig` | `gts4lv_defconfig` | `gts4lvwifi_eur_open_defconfig` | `gts4lv_eur_open_defconfig` |
|---|---|---|---|---|
| `CONFIG_IPC_ROUTER` | `=y` (L254) | `=y` (L254) | `=y` (L1254) | `=y` (L1254) |
| `CONFIG_IPC_ROUTER_SECURITY` | `=y` (L255) | `=y` (L255) | `=y` (L1255) | `=y` (L1255) |
| `CONFIG_IPC_ROUTER_NODE_ID` | absent (=1 default) | absent (=1 default) | `=1` (L1256) | `=1` (L1256) |
| `CONFIG_IPC_ROUTER_FIFO_XPRT` | absent | absent | **not set** (L1257) | **not set** (L1257) |
| `CONFIG_QRTR` | absent | absent | **not set** (L1157) | **not set** (L1157) |
| `CONFIG_MSM_QMI_INTERFACE` | `=y` (L668) | `=y` (L668) | `=y` (L4658) | `=y` (L4658) |

Resulting build set (`net/ipc_router/Makefile` + `net/qrtr/Makefile` + `drivers/soc/qcom/Makefile:65`):

| File | Built? |
|---|---|
| `net/ipc_router/ipc_router_core.c` | **YES** (`obj-$(CONFIG_IPC_ROUTER) := ipc_router_core.o`) |
| `net/ipc_router/ipc_router_socket.c` | **YES** |
| `net/ipc_router/ipc_router_security.c` | **YES** |
| `drivers/soc/qcom/qmi_interface.c` | **YES** |
| `net/ipc_router/ipc_router_fifo_xprt.c` | no (`CONFIG_IPC_ROUTER_FIFO_XPRT` off) |
| `net/qrtr/qrtr.c`, `net/qrtr/smd.c` | no (`CONFIG_QRTR` off) |

Round 1's claim that `CONFIG_QRTR` is unset in all four defconfigs **still holds** — re-verified, not
assumed. It is absent (hence `n`) from the two short defconfigs and explicitly `# ... is not set` in the
two `eur_open` ones. So `net/qrtr` remains dead code for this device. Note `net/qrtr`'s Kconfig is
`depends on ARCH_QCOM`, which *is* satisfied; nothing but the defconfig keeps it off. **Do not enable it
as part of the port.**
**confidence: high** — four configs read individually, Makefiles read, no inference.

### 4.1 Are the 130 symbols harmless in the files that *are* built?
Yes, for a structural reason worth recording: this area contains **no BPF, no XDP and no TCP/MPTCP code**.
Every `bpf_*` / `BPF_*` / `filter` / `netdev_xdp` / `dev_change_xdp_fd` / `tcp_*` / `mptcp*` symbol in
`changed-api.txt` is structurally absent from it — hence the 129 zeros. The `sk_buff` risk that the
series does carry (`struct skb_shared_info` field reordering, `gso_type` widened, `struct ubuf_info`
reordering, `cb[]` shrinking) does not apply either: the area never touches `skb_shinfo()->nr_frags`,
`->gso_type`, `->cb` or `skb->cb` (0 hits for all four, independently confirmed).
I also enumerated the 27 distinct struct members the area reaches through
`sk->`/`skb->`/`dev->`/`pkt->` and checked each against the series head: `sk_callback_lock`,
`sk_data_ready`, `sk_rcvtimeo`, `sk_receive_queue`, `sk_shutdown`, `sk_sndbuf`, `sk_sndtimeo`,
`sk_state`, `sk_state_change`, `sk_write_space`, `sk_wmem_alloc`, `skb_shared_info`, `data`, `len` —
**all still present** in `baa585f67e0e:include/net/sock.h` / `include/linux/skbuff.h`.
The series *does* move `sk_sndtimeo`, `sk_rcvtimeo`, `sk_wmem_alloc` and `sk_txhash` to different offsets
inside `struct sock` (e.g. `include/net/sock.h` diff shows `- long sk_sndtimeo;` and `+ long
sk_sndtimeo;` further down) and turns `sk_type`/`sk_protocol` from bitfields into plain `u16`. That is a
**layout** change with the name and type preserved: every file is recompiled from scratch, so it is
recompile-safe. Only pre-built external modules would care, and this area builds none.
**confidence: high** — I read both sides of the `struct sock` diff and confirmed each member still exists.

### 4.2 REAL break: `ipc_router_core.c:1384` (found by widening past the 7 audited headers)

**This is the one thing in this area the lead has to act on.**

`changed-api.txt` only covers 7 headers (`skbuff.h`, `netdevice.h`, `bpf.h`, `filter.h`, `net.h`,
`sock.h`, `tcp.h`), so it cannot see this. Widening: I collected every removed prototype-like line from
the series diff over `include/`, `net/`, `drivers/base/`, `kernel/`, `mm/`, `fs/` (23,356 removed lines ->
1,466 candidate identifiers), grepped all of them against this area, and adjudicated the 127 that hit.
Everything that hit was a C keyword (`return`, `void`, `while`, `switch`, `sizeof`, `memcpy`, ...), a
`struct proto`/`struct proto_ops` member with the same name as a changed LSM hook (`name`, `queue`,
`release`, `shutdown`, `setsockopt`, `socket`), or an MPTCP-only removal behind an off config. Exactly
one non-keyword survived: `wakeup_source_register`.

| Item | Value |
|---|---|
| Break site | `net/ipc_router/ipc_router_core.c:1384` |
| The code | `port_ptr->port_rx_ws = wakeup_source_register(port_ptr->rx_ws_name);` |
| Series commit | `0c6f8a9a50ad602aa67e04a3aa3ddca622e59e89` — "BACKPORT: PM / wakeup: Show wakeup sources stats in sysfs" (Tri Vo, 2019-08-06; upstream `c8377adfa781`) |
| The change | `include/linux/pm_wakeup.h`: `-extern struct wakeup_source *wakeup_source_register(const char *name);` -> `+extern struct wakeup_source *wakeup_source_register(struct device *dev, const char *name);` (and the same for the `CONFIG_PM_SLEEP`-less stub) |
| Why it breaks | Old arity. One argument passed, two declared. Hard compile error (`too few arguments to function`), in a file that **is** built (`CONFIG_IPC_ROUTER=y`, and `module_init(msm_ipc_router_init)` at `ipc_router_core.c:4492`) |
| Why it is dangerous | **It is not a merge conflict, so the conflict list will never show it.** `git merge-tree --write-tree --merge-base=0c6f8a9a50ad^ a30605a54f3b 0c6f8a9a50ad` reports 5 conflicts (`drivers/base/power/wakeup.c`, `drivers/net/wireless/bcmdhd_101_16/dhd_linux_priv.h`, `drivers/rtc/rtc-s2mps17.c`, `drivers/rtc/rtc-s2mps18.c`, `kernel/power/wakelock.c`) and **zero** mentions of `ipc_router` or `qrtr` (grep count over the whole output = 0). It is a silent build break. |
| Suggested fix | `wakeup_source_register(NULL, port_ptr->rx_ws_name);` — see below for why `NULL` is right |
| Confidence | **high** — the diff hunk, the call site, the build config and the merge-tree output were each read directly |

Why `NULL` is the correct first argument, not a guess:
- The series' own implementation explicitly handles a NULL device:
  `baa585f67e0e:drivers/base/power/wakeup.c:302` -> `if (!dev || device_is_registered(dev)) {`.
- The series fixes the analogous "no device" caller by passing `NULL`:
  `baa585f67e0e:drivers/input/misc/gpio_input.c:305` -> `ds->ws = wakeup_source_register(NULL, wlname);`
- `msm_ipc_router_create_raw_port()` at `ipc_router_core.c:1354` takes no `struct device *` and has no
  platform device to hand, so `NULL` is the only correct argument without widening the API.
If the lead prefers a real device, that means threading a `struct device *` into the IPC router port
creation path and changing `struct msm_ipc_port` — a much bigger change with no benefit for a port whose
wakeup source is just a suspend vote. Recommend `NULL`.

This is the same class of finding as K2d-2's note about this file, and it is worth recording that the
merge-tree evidence contradicts a "conflict" reading: the commit applies cleanly and breaks the build.
Treat `0c6f8a9a50ad` as an **API break to fix**, not a conflict to resolve.
**confidence: high** — merge-tree output for that exact commit was inspected line by line.

**Context for the lead (outside my area, informational, not audited by me):** this is not the only
1-argument caller in sdm670. `git grep -n 'wakeup_source_register(' a30605a54f3b -- ':!include'` gives
13 files. The other 12 old-arity sites are `drivers/acpi/device_pm.c:436`,
`drivers/char/diag/diagchar_core.c:4148`, `drivers/input/misc/gpio_input.c:313`,
`drivers/power/supply/qcom/battery.c:1605`, `drivers/power/supply/qcom/smb1390-charger.c:779`,
`drivers/power/supply/qcom/step-chg-jeita.c:755`, `drivers/tty/serial/msm_geni_serial.c:2793`,
`fs/eventpoll.c:1268`, `fs/eventpoll.c:1274`, `kernel/power/autosleep.c:122`,
`kernel/time/alarmtimer.c:1023`. Which of those the series already fixes (`fs/eventpoll.c`,
`drivers/input/misc/gpio_input.c`, `kernel/power/autosleep.c`, `kernel/time/alarmtimer.c`,
`drivers/acpi/device_pm.c` are all in `0c6f8a9a50ad`'s file list) versus which it leaves broken is a
question for the agents owning those paths. One already looks handled: `drivers/staging/qca-wifi-host-cmn/
qdf/linux/src/qdf_lock.c:273` calls the **two**-argument form but is wrapped in
`#if (LINUX_VERSION_CODE >= KERNEL_VERSION(4, 19, 110)) || defined(WAKEUP_SOURCE_DEV)`, which is false on
4.9 — so that file does not need chasing.
**confidence: medium** — the call sites are real and confirmed by grep, but I did not check which of them
`0c6f8a9a50ad` or another series commit already patches; that needs a per-file look by whoever owns them.

## 5. Other things checked, found clean

- `include/linux/list.h` **is** changed by the series (43 lines) and my area calls `list_add`,
  `list_del` and `INIT_LIST_HEAD` 45 times. All changes are `x = y` -> `WRITE_ONCE(x, y)` conversions
  inside the hlist helpers plus one new `list_for_each_entry_from_reverse()`; no prototype or macro
  removed. Benign.
**confidence: high** — read the whole `-` side of the header diff (10 removed lines).
- The other 9 headers the area includes directly that the series changes
  (`interrupt.h`, `kernel.h`, `mm.h`, `module.h`, `netlink.h`, `rwsem.h`, `sched.h`, `socket.h`,
  `uaccess.h`; `hashtable.h`, `device.h`, `slab.h`, `types.h` are unchanged) remove only these
  identifiers: `___might_sleep`, `__might_sleep`, `totalram_pages`, `VM_ARCH_2`, `do_munmap`, an
  old `do_mmap` wrapper, `min_dump_alloc`, `PF_PERF_CRITICAL`, `locked_vm`, `AF_MAX`,
  `strncpy_from_unsafe_user`. Grepped all of them against this area: **0 hits**. (The `AF_MAX` change is
  worth a second look elsewhere — it goes from a `#define ... 43` to a generated range — but nothing
  here uses it.)
**confidence: high** — every removed line of those 9 headers was listed and each identifier grepped.
- The 159 headers the series changes *outside* `include/`: filtered to the 12 that could possibly be
  visible here (`arch/arm64/`, `include/asm-generic`, `drivers/*/include`) their removed identifiers are
  `SET_PERSONALITY`, `struct kprobe`, `kprobe_opcode_t`, `struct arch_specific_insn`, `__kprobes`,
  `TIF_*` masks, `__NR_compat_syscalls`, `debug_id`, `is_async`, `struct notifier_block notifier`,
  `pressure_status`, `totalram_pages`, and one `wakeup_source_register(name)` in
  `drivers/net/wireless/bcmdhd_101_16/dhd_linux_priv.h` (K5e's area). Grepped against this area: **0
  hits** besides the one already reported.
**confidence: medium** — the filter was `arch/arm64/`, `include/asm-generic` and `drivers/`, so a header
under some other `drivers/*/` include dir that this area reaches could have been missed; I judge that
unlikely because the area's include list (54 entries, all resolved) contains no such path.
- `CONFIG_MPTCP` is off, so all `mptcp`-named removals are moot (§3.2).
- No `#if 0` or comment-out blocks were found containing any of the audited symbols, so nothing had to
  be dismissed on that basis.

## 6. What the lead should do, in order

1. **`net/ipc_router/ipc_router_core.c:1384`** — one-line fix,
   `wakeup_source_register(port_ptr->rx_ws_name)` -> `wakeup_source_register(NULL, port_ptr->rx_ws_name)`.
   Do it as part of applying `0c6f8a9a50ad`, even though that commit applies cleanly. **This is the only
   mandatory change in this area.**
2. **Tell K5a the header list is too narrow.** `changed-api.txt` covers 7 headers; a 1-argument
   `wakeup_source_register()` call in built sdm670 code was invisible to it. Any K5b/K5c/K5e conclusion of
   the form "0 real breaks" should be read as "0 real breaks *in those 7 headers*". Widening
   `changed-api.txt` to every header the series actually changes (`git diff --name-only d54533f1546b
   baa585f67e0e -- 'include/*.h'` gives 210) would catch this class everywhere.
3. Triage the other 12 old-arity `wakeup_source_register()` callers (§4.2) with whoever owns those paths.
4. Do not enable `CONFIG_QRTR` or `CONFIG_IPC_ROUTER_FIFO_XPRT`. Nothing in the port needs them, and
   `net/qrtr` is the only code in this area the series has never looked at.
5. Nothing else. Do not spend cherry-pick time on `net/ipc_router` or `qmi_interface.c` conflicts — the
   series does not touch them.

## Problems
None. No command failed. The one deviation from the brief is deliberate and stated in §0: I widened the
audit past the 130 symbols in `changed-api.txt` to the full set of headers the series changes, because
the brief asked me to "look for more" and because that is where the one real break turned out to be. I
also read `origin/agent/K5d` (round 1) read-only to reconcile its 6 hits against my 2; I did not modify
or reuse its files.