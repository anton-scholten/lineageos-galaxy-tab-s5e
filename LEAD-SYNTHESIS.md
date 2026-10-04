<!-- lead: Space Bunny Free (opencode) | date: 2026-10-03 | branch: lead/agent-results-2026-10-03 -->
# Lead synthesis: helper-agent run of 2026-10-03

> **Review and merge (2026-10-03, second lead):** this file and the final outputs of every task are now on `main`
> (the round-2 version where there is one; superseded round-1 outputs and the retired K4d/K5f stay on their `agent/*` branches).
> Independently re-checked against the kernel trees: the `set_memory.h` break (§1.3), LRU_HASH (§1.4), WALT/`CGROUP_SCHED` (§1.2),
> `TIF` bit 4 and `FAULT_FLAG 0x200` (§2), `wakeup_source_register` in `ipc_router` (§6.2), `fs/unicode` (§1.6) and `UPROBES` (§1.5): **all confirmed**.
> The 10 DROPs still listed as unverified in §9 were checked line by line. All 10 are consistent: 3 are partial drops, and `05e231887443` is a
> justified drop of optional, non-compiling DRM code. 13 of 14 randomly sampled "already in sdm670?" answers matched the line evidence, and
> the 14th was right on reading. The spec defects in §8 are fixed in `AGENT-TASKS.md`, and the follow-ups are round 3 there (§2.2).
> Note on §8.7: this run was on the owner's own machine, where lineageos.org works. From the Claude cloud container it's still blocked.

Cross-agent findings, verification log and next actions. This document holds what is **not** in any
individual agent report — conclusions that came out of comparing them, plus the checks the lead ran
directly. Per-task output stays on its own `agent/<task-id>` branch.

## Round 3 + P1 (2026-10-03, after `main` @ `432d5f3`)

The task spec was revised again and `RUNBOOK.md` added. All 5 round-3 research tasks ran, plus P1.
**P1 is complete:** kernel `port/pick` @ `d73f07cf8b5c`, **2,438 picks**, `check-pick.py` -> **`problems: 0`**
(2,372 clean, 60 hand-resolved = 23 full-review + 37 spot, 6 auto-merged-but-different). `lineage-22.2`,
`lineage-23.2` and `main` all verified untouched at `a30605a54f3b`. Progress is tracked in
[`analysis/port/STATUS.md`](analysis/port/STATUS.md).

**K7 found four more bit collisions** - see the rewritten
[section 2](#2-flag-and-bitfield-collisions--none-of-these-produce-a-conflict). The most serious new one,
`VM_ARCH_2`/`VM_WIPEONFORK` at `0x2000000`, is *actively* set by the series (`mm/madvise.c:99`), so it is a
live overlap rather than a latent one. Section 6c P3's list does not cover it.

**Round 3 overturned three round-2 conclusions** (section 7.4): the `target-level` change is a decision not
a change, the soundtrigger block should be kept, and the radio bump is impossible. Round 3 also *closed* the
vendor property-namespace question two rounds had failed on. Full detail in the WORKLOG.

### What P1 escalated, still open

1. **`process_mrelease` is missing.** Its three introducing commits were silently deleted by
   `classify.py:35`'s `EAS` regex matching inside `proc-EAS-s`/`rel-EAS-e` - the same defect class as the
   fuse-bpf pair, but larger. P1 could not verify the userspace fallback, so it escalated rather than
   decided. Porting it to 4.9 is expensive (no `mmap_lock` API; `rw_semaphore mmap_sem`).
   **This is a ROM question: does the target `lmkd` need it?**
2. **Expect a whitespace-heavy diff at `1c225cfcb958`.** P1 introduced a `get_scan_count` tab drift,
   isolated it by tab-counting every commit touching `mm/vmscan.c` since the last push, and fixed it in the
   *next* commit because fixing it in place would have required a forbidden rebase. `git diff -w` there shows
   only the intended comment swap, but a reviewer skimming it will see noise.

### Two landmines, deliberately not fixed

- **`classify.py` is unfixed on purpose.** Regenerating `conflict_detail.tsv` would change which *remaining*
  commits `pick-series.sh` skips, so it must be fixed as one unit with a decision, not piecemeal.
- **A clean cherry-pick is not evidence of correctness.** `ec3b287a8a17` applied cleanly and silently
  duplicated `bpf_probe_read_str` (sdm670 already had it); it healed at `dddb8c0eafe8`. `check-pick.py`'s
  *clean* bucket gets no human review, which is exactly why `pick-review/full/` and `spot/` exist.

### Three confirmed defects in `port/pick`, and what they tell us

P2's automerge triage found 2 real defects in its 6 packets; a sweep of **all 2,438 picks** found 1 more and
cleared 183 false positives. Full write-up with lead-verified line numbers:
[`analysis/port/duplicate-picks.md`](analysis/port/duplicate-picks.md).

**A clean cherry-pick is not evidence of correctness — there are now two distinct ways it lies.** The change
can be *already present in the sdm670 base* with git finding a non-overlapping insertion point for a duplicate
(F1 `drm_mode.h`, F2 `userfaultfd.c`), or the series can carry the **same upstream patch under two SHAs** so
the second pick is a pure duplicate (F3 `arch/parisc`). The second class is only detectable via the
`cherry picked from commit` trailers. Neither is visible to `check-pick.py`'s `clean` bucket.

**The counter-intuitive fix, recorded because two agents got it wrong:** for F1 delete `drm_mode.h` **92-104**,
the pick's `(0x0F<<19)` copy — **not** 106-124. The base copy is a superset (it alone defines
`DRM_MODE_PICTURE_ASPECT_64_27` and `_256_135`) and its `<<24` is what currently prevents a **bit-22 collision**
with `DRM_MODE_FLAG_SUPPORTS_YUV420 (1<<22)` at line 90. Deleting the wrong copy causes the collision it looks
like it prevents.

**The reassuring number:** sweeping the **2,372-commit `clean` bucket that nobody ever reviewed produced exactly
one finding**, in unbuilt `arch/parisc`, and it is legal C. The unreviewed bucket is in better shape than the
`ec3b287a8a17` anecdote implied. Factor this into how much of the 37-commit spot pool needs reading. The sweep's
limit, stated so it is not over-read: it finds duplicate *definitions* and *blocks*, not semantically wrong
non-duplicated picks.

### The next step is blocked on a strong model

Section 2.3 marks P1-R, P2-R, P4-R and P5-R **strong**. P1-R gates P3, which gates P4 and P5.
`RUNBOOK.md` "Without a strong model" allows a free-model fallback in a fresh session, with "reject
anything you can't prove from the code" and spot-checks raised from 20% to 50%. That is a judgement for the
owner, not for the agent that orchestrated P1.

## Round 2 (2026-10-03, after `main` @ `42b525d`)

`AGENT-TASKS.md` was revised: task IDs renumbered (R6/R7 -> R5/R6), K4 down to 3 agents, K5f retired,
K5 areas redefined, K6's option list grown, and the R1-R4 repos/matrix corrected. Seven tasks were
genuinely invalidated and were redone on `agent/<id>-r2` branches (round-1 branches left intact for
comparison). **46 agent runs total, all complete.**

| Task | What round 2 changed |
|---|---|
| K5a-r2 | area was a nonexistent path; now `net/rmnet_data/`. Grew `changed-api.txt` **132 -> 163 rows** |
| K5d-r2 | added `net/ipc_router/`; found the project's **one real API break** (§6.2) |
| K5e-r2 | area was `techpack/` (audio-only, now excluded); now cnss/icnss/embms |
| K6-r2 | 12 options -> **14 on + 3 off**; added `CONFIG_UPROBES=y`; found silent scheduler loss (§1.2) |
| R1-r2 | matrix level 7 -> **6**, plus the LTE model; reversed 7 round-1 findings (§7.3) |
| R2-r2 | 3 upstream repos + self-defined split; 255 rows, 0 missing (§7.5) |
| R3-r2 | added the `lineage-23.2-caf-sdm845` reader repos; **disproved the CAF manifest worry** (§7.1) |

No rework needed: K4 (K4d retired, its conclusion folded into K4c's), R4, R5, R6, K1, K2, K3, M2, M3, T1, T2.

**Round 2 corrected round 1 more than once, in both directions.** It found two real breakages round 1
missed, and overturned six round-1 claims — including one this document had promoted to a top risk. See
§7.1 for the retraction.

## Summary

All **39** helper tasks in [`AGENT-TASKS.md`](AGENT-TASKS.md) were dispatched and are complete:
39 branches pushed, 125 conflict briefs + 17 batch summaries, 4 build-error reports, a 6-part driver
API audit, a 2,599-row upstream map, and 6 ROM-side reports. `main` was never pushed to.

Three things the lead found that no single agent could:

1. **The series does not build for arm64 as it stands.** `1f9378f37a88` selects `ARCH_HAS_SET_MEMORY`
   on arm64, but `arch/arm64/include/asm/set_memory.h` exists nowhere — not in sdm670, not in ExyHyperBrick's
   base, not in the series head, and no commit in Exy's history creates it. Both commits involved are
   trial-`CLEAN`, so no brief mentions them. **This is the one thing to fix before anything else.**
2. **A whole class of prerequisite is structurally invisible to the trial**, which diffs base→head.
   Four named instances below. Only the compiler finds them.
3. **The isolated `merge-tree` method `AGENT-TASKS.md` §K2 prescribes is unreliable in both
   directions.** Six agents hit this independently. Use the stacked replay instead —
   [`analysis/tools/`](analysis/tools/) has working scripts.
4. **The driver API audit covers under 2% of the changed surface.** `changed-api.txt` is built from the
   7 headers the task names; the series changes **367**. K5d-r2 found a real break in a header that was
   never in the list. Read every "0 real breaks" as "0 within those 7 headers" — §6.1.
6. **Six bit collisions, four of them newly found.** K7 swept all 367 changed headers and found 6 real
   collisions; only 2 were known. Two are serious and one of those (`TIF_*` bit 4) also needs a
   `_TIF_WORK_MASK` fix or the tablet hangs. §2 has the table and P3 must cover all of them — `§6c P3`
   currently lists only the two known ones.
5. **One item produces no build error at all: silent scheduler loss.** If the series' `init/Kconfig`
   form of `SCHED_WALT` wins while `CGROUP_SCHED` is `n`, `walt.o` stops building and the tablet runs on
   plain CFS with no warning. `CONFIG_SCHED_WALT=y` is in all four defconfigs, so this is live. The
   K6-r2 fragment's `CONFIG_CGROUP_SCHED=y` prevents it — §1.2.

## 1. Must fix before the cherry-pick

| # | Item | Where | Why it is not in any brief |
|---|---|---|---|
| 1 | **Add `arch/arm64/include/asm/set_memory.h`** | new file, `arch/arm64/include/asm/` | both causing commits are trial-`CLEAN` |
| 2 | **Use the K6-r2 fragment, for `CONFIG_CGROUP_SCHED=y`** | `analysis/defconfig/` | see §1.2 — silent scheduler loss |
| 3 | **`AGENT-TASKS.md:255-256` is factually wrong** | the LRU_HASH spot-check | — |
| 4 | **Add `CONFIG_UPROBES=y`** | already in the K6-r2 fragment | round 1 of K6 got this backwards |
| 5 | **`fs/unicode/` never arrives** | copy the dir, or drop `CONFIG_UNICODE` | the series never brings it |
| 6 | **`ipc_router_core.c:1384` needs a 1-line fix** | when applying `0c6f8a9a50ad` | not a conflict, so no brief flagged it |

### 1.2 Silent scheduler loss — the most dangerous item here

**This one produces no build error.** A device that boots and runs, on the wrong scheduler.

`init/Kconfig`, the `SCHED_WALT` entry:

| Tree | Lines | Depends on |
|---|---|---|
| sdm670 `a30605a54f3b` | `407-409` | `SMP` only |
| series head `baa585f67e0e` | `402-405` | `SMP` **and `FAIR_GROUP_SCHED`** |

And the chain feeding it, at `baa585f67e0e:init/Kconfig`:

```
1269: menuconfig CGROUP_SCHED    default n            <-- off unless we turn it on
1278: config FAIR_GROUP_SCHED   depends on CGROUP_SCHED
1281:                            default CGROUP_SCHED
```

If the series' `init/Kconfig` hunk wins, `FAIR_GROUP_SCHED` goes to `n` (because `CGROUP_SCHED` defaults
to `n`), which makes `SCHED_WALT` `n`, and `kernel/sched/Makefile:22`
(`obj-$(CONFIG_SCHED_WALT) += walt.o boost.o`) stops building the scheduler.

**Severity: high.** `CONFIG_SCHED_WALT=y` is set in **all four** defconfigs, so WALT is genuinely in use
on this tablet. But only the two `*_eur_open_defconfig` files also set `CONFIG_CGROUP_SCHED=y`;
`gts4lv_defconfig` and `gts4lvwifi_defconfig` have **no** `CGROUP_SCHED` line at all, so they take
`default n`. Building against either of those without the fragment silently drops WALT.

**Fix:** `CONFIG_CGROUP_SCHED=y`, which makes `FAIR_GROUP_SCHED` default `y` and lets WALT survive either
way the `init/Kconfig` conflict resolves. The K6-r2 fragment has it — **use that fragment, not round 1's.**

Two related traps in the same hunk:

- **Do not "fix" this with `# CONFIG_FAIR_GROUP_SCHED is not set`.** `SCHED_WALT` *depends on*
  `FAIR_GROUP_SCHED` (`:405`), so that switches WALT **off**. Round 1 of K6 recommended exactly this;
  K6-r2 caught and reversed it.
- sdm670's `CFS_BANDWIDTH` carries a local `depends on !SCHED_WALT` guard (`init/Kconfig:1191`, from
  local Android work `d342ee64906f`/`e032df4b1246`, reverted `45be79a2ec16`, present at tip) that the
  Exy tree lacks. The fragment deliberately leaves `CFS_BANDWIDTH` off (`default n`). If the scheduler
  fails to build with `FAIR_GROUP_SCHED=y && SCHED_WALT=y`, leave `CFS_BANDWIDTH` off or restore the
  guard — **not** `FAIR_GROUP_SCHED=n`.

### 1.3 The arm64 `set_memory.h` break, in full

Verified chain:

| Step | Commit | Trial | Effect |
|---|---|---|---|
| 1 | `2e71fb11d9a8` "provide linux/set_memory.h" | **CLEAN** | `include/linux/set_memory.h` does `#include <asm/set_memory.h>` under `#ifdef CONFIG_ARCH_HAS_SET_MEMORY` |
| 2 | `1f9378f37a88` "arm64: Select ARCH_HAS_SET_MEMORY" | **CLEAN** | `arch/arm64/Kconfig:25` selects it, unconditionally |
| 3 | — | — | `arch/arm64/include/asm/set_memory.h` **does not exist** |

Checks run: `git cat-file -e <rev>:arch/arm64/include/asm/set_memory.h` against `a30605a54f3b`
(sdm670), `d54533f1546b` (Exy base) and `baa585f67e0e` (series head) — absent in all three.
`git log --diff-filter=A --all -- arch/arm64/include/asm/set_memory.h` — empty, so no commit in Exy
HyperBrick's history creates it. Only `arch/arm`, `arch/s390`, `arch/x86` and
`include/asm-generic/` have one. `arch/arm64/Kconfig:25` is also the **only** unconditional
`select ARCH_HAS_SET_MEMORY` in the tree (x86/arm/s390 select it elsewhere or not at all).

The Exy base does **not** have that select — `1f9378f37a88` is the only commit that adds it — so their
base was fine and the series introduces the breakage.

**Two briefs cover parts of this and neither connects them.** Task K2d-2's brief for `252eaf20e864`
covers the `arch/Kconfig` **declaration** of the symbol and says "nothing selects it yet" — true within
that commit only. It also states the commit is x86-only, which is right: `252eaf20e864` touches
`arch/Kconfig`, `arch/x86/mm/pageattr.c` and `include/linux/set_memory.h`, and supplies no arm64 header.

**Fix options**, best first:

1. Add `arch/arm64/include/asm/set_memory.h`. Template is `arch/arm/include/asm/set_memory.h` — 30
   lines, real prototypes under `CONFIG_MMU`, `static inline ... return 0;` stubs otherwise. A thin
   wrapper over the existing `include/asm-generic/set_memory.h` (12 lines) would satisfy the include.
2. Drop `1f9378f37a88`.
3. Make the arm64 select conditional.

**confidence: high** — every step is a direct `git cat-file`/`git log`/`git show` result.

### 1.4 `AGENT-TASKS.md` own verification example is false

Lines 255-256 state that sdm670 already carries `BPF_MAP_TYPE_LRU_HASH`, and give the command to prove
it. That command returns **exit 1**. A whole-tree grep also finds nothing; sdm670's
`enum bpf_map_type` ends at `BPF_MAP_TYPE_CGROUP_ARRAY` (`include/uapi/linux/bpf.h:81-89` @ `a30605a54f3b`),
and the series adds LRU_HASH at `include/uapi/linux/bpf.h:146` @ `baa585f67e0e`.

**Four agents found this independently** — K2a-1, K1, K2b-2, K2b-3 — and all four correctly refused
to drop the commit and MERGEd it instead. K2b-3 adds that `3ed2e2f029db` is a trial **CONFLICT**, so K1
reporting `unknown` rather than the documented `yes` is the correct outcome. K1's own run confirms:
the row is `upstream_sha=-`, `sdm670_has=unknown`.

Fix: one line. Left alone here because agents are not allowed to edit that file.

### 1.5 `CONFIG_UPROBES` — confirmed missing from round 1, fixed in round 2

`config UPROBES` at `arch/Kconfig` @ `baa585f67e0e` is `def_bool n`. K6's fragment sets
`CONFIG_KPROBES=y` but omits `CONFIG_UPROBES`. Meanwhile `2d6869d3a4ce` adds
`arch/arm64/kernel/probes/uprobes.c` (**216 lines**), its Makefile entry and the `signal.c` hook — all
dead code with `UPROBES` off. Android 16's `bpfloader` uses uprobes.

Verified: `CONFIG_KPROBES` and `CONFIG_UPROBES` are unset in `gts4lvwifi_defconfig` and `gts4lv_defconfig`,
and both are explicitly `# ... is not set` in `gts4lvwifi_eur_open_defconfig`.

K6's own caveat said "the config is optional, the define is mandatory"; K2a-2 said the opposite.
**K2a-2 is right.** `UPROBES` does not depend on `KPROBES` — it is independently `def_bool n` — so
neither option implies the other.

K6 *did* get `CONFIG_FUSE_BPF=y` right, with provenance back to `462a37becb45`, which no defconfig has.

### 1.6 `fs/unicode/` is never supplied

`fs/unicode/` exists at the series base `d54533f1546b` but is **absent from sdm670**, and
`git log --oneline d54533f1546b..baa585f67e0e -- fs/unicode/` is **empty** — the series never brings it.
So `CONFIG_UNICODE=y` in K6's fragment is a **no-op**: the Kconfig entry has no `obj-` target to build.
Someone must copy the directory and add `obj-$(CONFIG_UNICODE) += unicode/` to `fs/Makefile`
(`:96` @ `baa585f67e0e`), or drop the option.

## 2. Flag and bitfield collisions — none of these produce a conflict

sdm670 is old enough that the series reuses bit values and field widths sdm670 already spent. A
keep-both merge **silently fuses them** and no compiler error results.

Task K7 swept all 367 changed headers (224 examined, 143 skipped — 136 absent from sdm670, 7 deleted by
the series) and found **6 real collisions**. Its script is `analysis/collisions/find_collisions.py`, output
`K7.tsv` (46 findings, deterministic — verified by three identical sha256sums).

| # | File | Value | sdm670 | series | Free value | Severity |
|---|---|---|---|---|---|---|
| 1 | `arch/arm64/include/asm/thread_info.h` | `4` | `TIF_FSCHECK:83` | `TIF_UPROBE:88` | **5** | **high** — breaks the scheduler wakeup |
| 2 | `include/linux/mm.h` | `0x200` | `FAULT_FLAG_SPECULATIVE:293` | `FAULT_FLAG_INTERRUPTIBLE:320` | **0x800** | **high** — fuses two page-fault paths |
| 3 | `include/linux/mm.h` | `0x2000000` | `VM_ARCH_2:190` | `VM_WIPEONFORK:215` | **0x800000** | medium — see below |
| 4 | `include/linux/vmalloc.h` | `0x100` | `VM_LOWMEM:22` | `VM_FLUSH_RESET_PERMS:26` | `0x10` | **already handled by P1** — see below |
| 5 | `include/uapi/linux/input-event-codes.h` | `0x10` | `SW_HPHL_OVERCURRENT:824` | `SW_MACHINE_COVER:811` | **`0x14`** | medium — uapi, `SW_MAX` also moves |
| 6 | `include/uapi/linux/input-event-codes.h` | `252` | `KEY_DUMMY_HOME:339` | `KEY_HOT:340` | **`0x300`** | medium — 255 is reserved |

Rows 1 and 2 were already known; **rows 3-6 are new.** All six are live in all four defconfigs — none is
behind an off config, and `CONFIG_MPTCP` resolves to `n` everywhere, so nothing found is hidden behind it.

### 2.1 Row 1 is worse than a name clash

sdm670 `init/Kconfig:407-409` vs series `:402-405` — see §1.2. Fixing the bit is necessary but **not
sufficient**: the merged `_TIF_WORK_MASK` must list **both** `_TIF_FSCHECK` and `_TIF_UPROBE`, or
`TIF_FSCHECK` stops waking the task and the tablet hangs.

### 2.2 Row 3 is an *active* overlap, not a latent one

Verified: sdm670 `mm.h:190` `#define VM_ARCH_2 0x02000000`, series `mm.h:215`
`#define VM_WIPEONFORK 0x02000000`. The series **actively sets** it —
`mm/madvise.c:99`, `new_flags |= VM_WIPEONFORK;` for `MADV_DONTFORK`.

So after a `MADV_DONTFORK`, `/proc/pid/maps` shows the bit under sdm670's name, not the series' name.

**Severity: medium, not high** — K7's assessment checks out. `VM_MPX` is defined as `VM_ARCH_2`
(`mm.h:238` sdm670, `:263` series) but is **not used** anywhere in `arch/arm64` or `mm/`; its only reader
on this SoC is the `__def_vmaflag_names` trace table. So the impact is a wrong flag *name* in `/proc`,
not a misbehaving kernel. Fix by moving `VM_ARCH_2` to `0x800000`, or dropping it on arm64.

### 2.3 Row 4 is already resolved by P1 — do not let P3 re-add it

The series defines `VM_FLUSH_RESET_PERMS` at `0x100`, which is sdm670's `VM_LOWMEM`. **P1 already
avoided this**: its log for `4cf42717d891` records keeping `VM_LOWMEM 0x00000100` and adding
`VM_FLUSH_RESET_PERMS 0x00000200`, having verified `0x200` free in both trees. P1's value differs from
K7's suggestion (`0x10`) but both are valid; **what matters is that P3 must not re-apply the series'
`0x100` value** and undo P1's resolution.

### 2.4 Rows 5-6 are uapi breaks with a second-order effect

`input-event-codes.h` is a **uapi** header, so these reach userspace. Row 5 has two parts: `0x10` fuses,
**and** `SW_MAX` drops from `0x20` to `0x10`, which changes how `drivers/input/evdev.c:813` sizes
`dev->swbit`. Taking the series' list wholesale would also **delete Samsung headphone-overcurrent
reporting** (`SW_HPHL_OVERCURRENT` is used by `sound/core/jack.c:43`, and `CONFIG_SND_JACK=y` in both
`*_eur_open` defconfigs). K7 recommends keeping sdm670's block and adding `SW_MACHINE_COVER 0x14`, and
moving `INPUT_DEVICE_ID_SW_MAX` (`mod_devicetable.h:294`) with it.

**A caution about K7's own output:** its script's automatic `suggest=` for `KEY_HOT` is `0xff`, which is
**wrong** — code 255 is documented reserved (`input-event-codes.h:343`). K7 flagged this itself and
overrode it to `0x300` in the report. The script does not know reserved ranges, so do not trust
`suggest=` without reading the block.

### 2.5 Confirmed non-issues

- **`sk_buff.cb`** (the 72→48 shrink) **does not appear** — both trees declare `char cb[48]`. §2's earlier
  "no change needed" is confirmed by the sweep.
- Seven same-enum *renumbering* rows (`ARG_PTR_TO_STACK`→`ARG_PTR_TO_UNINIT_MAP_VALUE` and four siblings
  in `enum bpf_arg_type`, `PTR_TO_MAP_VALUE_ADJ`→`PTR_TO_SOCKET`, `CPUHP_AP_*`,
  `NL80211_ATTR_AUTH_DATA`→`NL80211_ATTR_SAE_DATA`) are **not fusions** — take those enums whole from the
  series and rename the call sites (`kernel/bpf/verifier.c`, `net/core/filter.c`, `kernel/trace/bpf_trace.c`).
  Never merge them hunk-by-hunk.
- 14 width/bitfield changes, 8 `VALUE_CHANGED` and 3 `TEXT_PREFIX_ONLY` (`EXT4_*` families hundreds of
  lines apart) round out the 46 findings.

### 2.6 One more thing for P3, from K7

`include/net/sock.h` has three layout changes that **compile cleanly**: `sk_type` and `sk_protocol` go
from bitfields inside one `unsigned int` to separate `u16` fields, and `sk_padding` narrows 2→1. These
are `BITFIELD_TO_FIELD` rather than collisions, but they **move every field after them** in `struct sock`.


## 3. Base-only prerequisites — a class the trial cannot see

`trial.py` diffs `d54533f1546b..baa585f67e0e`, i.e. base→head. It is therefore **blind to anything that
lives in ExyHyperBrick's `lineage-22.2` base, is unchanged by the series, and is missing from sdm670.**

Four confirmed instances. In every case: present in the Exy base, identical count in the series head
(so untouched), absent from sdm670.

| Symbol | sdm670 | Exy base | Series head | Found by |
|---|---|---|---|---|
| `randomized_struct_fields_end` | 0 | 3 | 3 | K4a |
| `ANDROID_VERSION` | 0 | 11 | 11 | K4b |
| `update_cpu_active_ratio` | 0 | 3 | 3 | K3-4 |
| `arch/arm64/include/asm/set_memory.h` | absent | absent | absent | lead — **series-internal**, see §1.1 |

The first three are why `AGENT-TASKS.md` §7 lists "build fixes after the first errors" as lead-only work.
They cannot be enumerated by research; only the compiler finds them. Expect a tail of small,
individually-cheap fixes after the conflicts clear.

`ESTIMATE.md`/`analysis/build-test/README.md` already noted 1,079 commits in the Exy base touch generic
kernel code and are not in sdm670. The three names above are the first concrete ones pinned down.

## 4. Cross-batch items that need a person, not a cherry-pick

**`fs/userfaultfd.c` — six commits, one nest.** K2d-3 found `10a07035a7e7`'s conflict region sits *nested
inside* conflict markers left by five earlier commits: `fad9a6a81aa6`, `f0f30b4639c2`, `9114ddb3b20f`,
`d5f2acfd8dc2`, `b07d07e8f011` — all trial `CONFLICT`, and **all in other batches**. The
`vma_is_anonymous` → `vma_can_userfault` chain has to be resolved as one unit.

**`fs/fuse` — an ordering hole with a wide tail.** `462a37becb45` (K3-2) needs `struct fuse_bpf_args`
from `include/uapi/linux/android_fuse.h`, added by `435bb390114e` (K3-1), a trial CONFLICT five rows
earlier. So **27 later commits** touching `fuse_i.h`/`backing.c` were replayed without it. Separately,
the series rewrites `fs/fuse/Makefile` from `fuse-objs := … passthrough.o` to `fuse-y := … acl.o`,
**dropping `passthrough.o`** — and `fuse_setup_passthrough()` is live at `fs/fuse/dev.c:1963`. K2a-4
and K2b-3 both found this; the lines K2b-3 cites are verified (`passthrough_filp` at
`fuse_i.h:160,241,396`; `dev.c:582-583`; `ff->passthrough_enabled = 0` at `file.c:2124` **and** `:2137`).

**The XDP rename group.** K2b-3: `27c560179112` deletes the `__dev_xdp_query()` that `19ce6ace41bb`
adds, so resolving the first in isolation is wasted work. K2b-2 adds that `e00c40bbd2f4`
(`ndo_xdp`→`ndo_bpf`) fights four other CONFLICT commits on the same lines — decide the rename once.

**Wi-Fi ↔ IPA runtime ABI through `skb->cb`.** Surfaced only by combining K5b and K5c: IPA **writes**
bytes 0–4 (`*(unsigned int *)rx_skb->cb`, `*(u8 *)(rx_skb->cb + 4)` at
`drivers/platform/msm/ipa/ipa_v3/ipa_dp.c:2659-2660`, plus `:2131`, `:2466`, `:2730`) and Wi-Fi
**reads** bytes 0–1 (`skb->cb[0]`, `skb->cb[1]` at
`drivers/staging/qcacld-3.0/components/ipa/core/src/wlan_ipa_core.c:1034,1045`). No compiler checks
this. The `cb` shrink is safe (both ends use bytes 0–4 of 48), but any future reordering breaks it
silently. Worth a comment at both sites.

## 5. `merge-tree` methodology — the briefs' numbers need re-deriving

`AGENT-TASKS.md` §K2 step 3 tells agents to run an **isolated**
`git merge-tree --write-tree --merge-base=C^ a30605a54f3b C`. Six agents reported it misleads:

| Failure | Who | Example |
|---|---|---|
| over-reports — flags files earlier commits have not created | K2c-2, K2b-4, K2a-1, K3-4 | `bca02018e7d0`: 17 paths flagged, **1** real; the other 16 are 8 modify/delete for files absent from sdm670 plus 8 content conflicts against a stack sdm670 doesn't have |
| reports success while emitting uncompilable code | K3-2 | `8381dabde508` (hrtimer): `HRTIMER_MODE_SOFT` is absent from sdm670 *and* from the series base, present only in the head — so the merged tree references a softirq clock base that 17 earlier commits were meant to create |
| `CLEAN` commits that do conflict | K2a-2 (×4), K2c-2, K2d-1 | `47d10743ccd7`, `0a115d7aaf34` — trial `CLEAN`, conflict standalone, **no brief exists for either** |
| `results.tsv` under-reports | K2a-2, K2a-3, K2b-3 | `993f49608c23` recorded 1 file/1 block, actually 9 files/12 blocks/~5,100 lines |

**The stacked replay is the trustworthy model**, because that is what an in-order cherry-pick does.
K2d-3 validated it: its stacked replay reproduced `conflict_detail.tsv`'s file and block counts for
**all 7** of its commits, while its isolated numbers over-reported on 2. Scripts:
[`analysis/tools/`](analysis/tools/).

Two consequences:

- **Don't schedule the resolve work from `conflict_detail.tsv`.** The 150 figure is right for an
  in-order replay, but the per-commit file and block counts are not, and `K2a-3` notes
  `ours_lines`/`theirs_lines` include leftover `<<<<<<<` markers, so they are not block sizes.
- **`trial.py`'s own replay is also unsound** — it commits each result *with conflict markers still in
  the tree* (`trial.py:29-31`) and marches on. So "CLEAN" after the first conflict is unreliable too.
  Neither source is trustworthy for counts; a real cherry-pick is.

**Two conflicts have no brief at all:** `47d10743ccd7` ("mm: introduce MADV_PAGEOUT", mandatory
prerequisite for `e7751e04e9d1`) and `0a115d7aaf34` (inside `__purge_vmap_area_lazy`, sits between two
K2d-1 commits). Both are trial-`CLEAN`.

## 6. The API audit found almost nothing — but read the coverage number first

| Task | Area | Hits | Real breaks |
|---|---|---|---|
| K5a | rmnet | 15 | 0 — area absent from both trees (round 1; redone as K5a-r2) |
| K5b | `drivers/platform/msm/ipa` | 1,328 | 0 |
| K5c | qcacld-3.0 + qca-wifi-host-cmn | 5,578 | 0 |
| K5d | `net/qrtr`, soc/qcom dfc/qmi | 6 | 0 — series never touches it (round 1) |
| K5e | `techpack/` | 836 | 0 — audio-only, zero net/socket use (round 1; area since retired) |
| K5f | Samsung wireless / security / sec_net | 236 | 0 |
| **K5d-r2** | **+ `net/ipc_router/`** | 2 | **1 — see below** |

~8,000 hits, **1 real break**. K5c's decisive evidence for its own area: grepping the whole BPF/XDP/filter
half of the changed API across both Wi-Fi trees returns nothing; only 10 of 130 symbols hit at all.

### 6.1 The coverage caveat that qualifies every "0 real breaks" above

`changed-api.txt` is built from **7 headers**, because `AGENT-TASKS.md` §K5 step 1 names 7. The series
actually changes **367 headers** (of 1,198 files total: 367 `.h`, 686 `.c`; 98 under `include/linux/`,
48 under `include/net/`, 45 under `include/uapi/`).

**So the audit covers 7 of 367 changed headers — under 2%.** Every "0 real breaks" must be read as
"0 within those 7 headers". This is not hypothetical: K5d-r2 found a real break in
`include/linux/pm_wakeup.h`, which was never in the list.

### 6.2 The one real break, and why no brief caught it

`net/ipc_router/ipc_router_core.c:1384` @ `a30605a54f3b`:

```c
port_ptr->port_rx_ws = wakeup_source_register(port_ptr->rx_ws_name);
```

Commit `0c6f8a9a50ad` changes the prototype (`include/linux/pm_wakeup.h:98` @ sdm670 →
`:109` @ `baa585f67e0e`):

```c
extern struct wakeup_source *wakeup_source_register(const char *name);
extern struct wakeup_source *wakeup_source_register(struct device *dev, const char *name);
```

Old arity, so a **compile error** — in a file the defconfigs build (`CONFIG_IPC_ROUTER=y` in all four).

**The important part: this is not a merge conflict.** `git merge-tree --write-tree
--merge-base=0c6f8a9a50ad^ a30605a54f3b 0c6f8a9a50ad` reports 5 conflicts (`wakeup.c`,
`bcmdhd_101_16/dhd_linux_priv.h`, `rtc-s2mps17.c`, `rtc-s2mps18.c`, `wakelock.c`) and **zero** occurrences
of `ipc_router` or `qrtr`. The commit applies cleanly and breaks the build afterwards. K2d-2's brief
recorded this file as a conflict; the evidence says otherwise — treat `0c6f8a9a50ad` as an API break.

Fix is one line: `wakeup_source_register(NULL, port_ptr->rx_ws_name)`. `NULL` is provably right, not a
guess — `baa585f67e0e:drivers/base/power/wakeup.c:302` is `if (!dev || device_is_registered(dev))`, and
the series fixes the analogous device-less caller the same way at
`baa585f67e0e:drivers/input/misc/gpio_input.c:305`. `msm_ipc_router_create_raw_port()` has no
`struct device *` to pass.

### 6.3 A Kconfig `select` is invisible to a defconfig grep

K5e-r2 overturned a K5f conclusion. `drivers/soc/qcom/Kconfig:693-695`:

```
config ICNSS
	tristate "Platform driver for Q6 integrated connectivity"
	select CNSS_UTILS
```

`CONFIG_ICNSS=y` in **all four** defconfigs, so `cnss_utils.c` **is** compiled — K5f had concluded it
was off. K5f had only read `gts4lv_defconfig`; the `*_eur_open_defconfig` files are 6,023 lines, not 810.

**Generalisable, and it applies to every K5 report:** any verdict of the form "config X is off because
the defconfig doesn't mention it" may be wrong the same way. The reliable test is:

```
git grep -n '<select X' <sha> -- '*Kconfig*'
```

Risk impact here was zero (0 hits), so this is a process fix, not a missed break. But it should be
re-run across all four defconfigs before trusting any such verdict.

Two structural facts worth keeping: `techpack/` in sdm670 is **audio-only** (332 files under
`techpack/audio`, 3 under `techpack/stub`) — no camera, sensors or GPS, contrary to what "Qualcomm OOT
bundle" suggests. And `security/samsung` and any `sec_net` path **do not exist** in sdm670; Samsung
security in the series is `security/tz_iccc` + `security/tima_ueccount`, which 0 series commits touch.

### 6.4 `net/embms_kernel/` is dead code

K5e-r2 found it has no Kconfig, is **not referenced by `net/Makefile`**, and its Makefile is out-of-tree
kbuild (`KERNEL_SRC ?= /lib/modules/$(shell uname -r)/build`, `Makefile:3,7`). It defines
`embms_tm_multicast_recv` (`embms_kernel.c:1006-1007`, consumed by `net/core/dev.c:4226-4239`) but
nothing builds it. No action, but do not spend time there.

### 6.5 Correction: the `skb->cb` contract is real

K5e-r2 reported "grepping `skb->cb` under `qcacld-3.0` + `qca-wifi-host-cmn` returns 0 lines, so the IPA
writer appears to have no in-kernel reader". **That is wrong** — it returns **13 files**:

```
drivers/staging/qca-wifi-host-cmn/dp/wifi3.0/dp_ipa.c:1847-1849        * WDI 3.0 skb->cb[] info from IPA driver
drivers/staging/qca-wifi-host-cmn/os_if/linux/qca_vendor.h:7447,7452   ((void **)skb->cb)[2] reads/writes
drivers/staging/qca-wifi-host-cmn/dp/wifi3.0/dp_types.h:1605-1606      flow_tag / protocol_tag read from skb->cb
```

plus the actual consumer at `drivers/staging/qcacld-3.0/components/ipa/core/src/wlan_ipa_core.c:1034,1045`
(`session_id = (uint8_t)skb->cb[0]`). §4's Wi-Fi↔IPA contract stands as written; ignore K5e's
"no in-kernel reader" claim.

**Coverage gap:** K5d-r1 flagged two built files its area definition missed
(`drivers/uio/msm_sharedmem/sharedmem_qmi.c`, `drivers/thermal/qcom/qmi_cooling.c`, both `=y` in
`gts4lv_defconfig`); the lead checked those against all 139 symbols — **0 hits, clean**.

### 6.6 `changed-api.txt` was incomplete — round 2 grew it from 132 to 163 rows

K5a-r2 re-derived the header diff independently and found **31 changed/removed prototypes missing** from
round 1's list. All 62 of its citations were verified mechanically, which caught 6 of its own wrong line
numbers before commit.

The highest-value gap is **`bpf_jit_compile`**. Round 1's list did not contain it, and it matters:

| Tree | `include/linux/filter.h` |
|---|---|
| base `d54533f1546b` | `:657-659` — `#else` **stub** `static inline void bpf_jit_compile(struct bpf_prog *fp) {}` |
| head `baa585f67e0e` | `:953` — prototype only, **the stub is gone** |

`CONFIG_BPF_JIT` is unset in two defconfigs explicitly (`# CONFIG_BPF_JIT is not set` in both
`*_eur_open`) and absent from the other two. So any caller outside a `CONFIG_BPF_JIT` guard gets an
**undefined reference at link time** — and, like the `ipc_router` break, not a merge conflict.

**This one is already defused:** the K6-r2 fragment sets `CONFIG_BPF_JIT=y` (line 261) as a mandatory
`BPF_LSM` dependency. K5a found the hazard and K6 independently pulled in the fix — the two interlock.
**Use the K6-r2 fragment.**

Other real gaps in that batch of 31: `bpf_obj_get_user` (stub arity 1→2), `get_func_proto` /
`is_valid_access` (params), `bpf_prog_array_copy` (`u64 bpf_cookie` before the out-param), `usercnt`
(`atomic_t` → `atomic64_t`), 10 `tcp.h` prototypes gaining `struct net *`,
`tcp_rcv_established`/`tcp_try_fastopen` losing trailing params, `tcp_rack_mark_lost` `int`→`void`.

### 6.7 The two symbols nobody owns — exact call sites

K5a-r2 pinned these down. Both are in stack files that **no K5 area covers**:

- `skb_steal_sock()` gained a required `bool *refcounted` out-param. Its four call sites:
  `include/net/inet_hashtables.h:350`, `include/net/inet6_hashtables.h:89`,
  `net/ipv4/udp.c:1823`, `net/ipv6/udp.c:809`.
- `skc_tx_queue_mapping` went `int` → `unsigned short`. All access goes through `sk_tx_queue_*` at
  `net/core/dev.c:3376,3387` and `net/core/sock.c:501,1352,1417,1603`.

`K5a.md` also notes the residual risk a symbol list **cannot** catch: struct *layout* changes.
`struct sock` was heavily rearranged in the series, so a driver can break without naming any changed
field. **confidence: medium** on K5a-r2's own claim that its 31 added rows are complete, for that reason.

### 6.8 Four methodology traps found in round 2 — each one has already fooled an agent

1. **`ls-tree -d` hides single-file paths.** `drivers/net/rmnet_iplo` is the *file* `rmnet_iplo.c`
   (232 lines), wired at `drivers/net/Makefile:22` with a live `config RMNET_IPLO` at
   `drivers/net/Kconfig:249`. `git ls-tree -d` prints nothing, so it reads as "absent". Use
   `ls-tree -r --name-only` before declaring a path absent.
2. **`menuconfig` hides from `^config X$`.** `CGROUP_SCHED` is `menuconfig CGROUP_SCHED`
   (`init/Kconfig:1269`), so `git grep '^config CGROUP_SCHED$'` finds **nothing**. This is why round 1
   of K6 could not find it.
3. **A Kconfig `select` is invisible to a defconfig grep** — see §6.3 (`ICNSS` → `CNSS_UTILS`).
   Reliable test: `git grep -n '<select X' <sha> -- '*Kconfig*'`.
4. **In `android_system_sepolicy`, `prebuilts/api/**` is not compiled** (`build_files.go:104-105` gives
   it separate versioned tags), so grepping the whole repo can resurrect a deleted symbol. Also the vndr
   clone checks out at `device/qcom/sepolicy_vndr/legacy-um`, so on-disk paths have **no** `legacy-um/`
   prefix — that mistake initially made all 35 vndr symbols look absent at 22.2.

## 7. ROM side is in better shape than the docs implied

| Task | Verdict |
|---|---|
| R5 (sm7125 22.2→23.2) | **1 of 22** NEEDED: `manifest.xml` target-level `5`→`6`. NFC definitively absent — **0 of 685** vendor blob files match `nfc` |
| R6 (exynos9810-common) | **1 of 143** NEEDED: space-separated `samplingRates`/`channelMasks` in audio policy XML (our file has 79 comma-separated list attributes) |
| R3 (Soong) | **0 BROKEN, 0 DEAD** of 10 variables |
| R4 (vendor blobs) | **1 MISSING** of 4,711 `NEEDED` pairs across 543 `.so`: `libclang_rt.ubsan_standalone-arm-android.so`, single consumer `libwfdhdcpservice_proprietary.so` |
| R1 (VINTF) | 23 of 25 HALs OK, **2 hard failures** |
| R2 (sepolicy) | **255 rows audited, 0 missing** (round 2; 75 self-defined, 179 upstream-verified, 1 keyword) |

R6 closes the open question at `analysis/reference-trees/README.md:25` (NFC) with evidence.

### 7.1 The CAF wiring gap — mostly a false alarm, with one real caveat

**Corrected 2026-10-03 after R3-r2.** An earlier version of this section, based on R1 and R6, overstated
the problem. Both claims have now been checked directly:

**`hardware/qcom-caf/common` IS in the 23.2 manifest** — `LineageOS/android`
@ `eabe68377217a`, `snippets/lineage.xml:102`:

```xml
<project path="hardware/qcom-caf/common" name="LineageOS/android_hardware_qcom-caf_common" groups="qcom" >
```

R1's claim that no `hardware/qcom-caf/*` appears in the 23.2 manifest is **wrong**; R6 reported the same
line correctly. The include chain works, and R3-r2 traced all of it:

| Step | File:line | Condition |
|---|---|---|
| 1 | `android_build` `core/config.mk:477-479` | `ifneq ($(LINEAGE_BUILD),)` → include `vendor/lineage/config/BoardConfigLineage.mk` |
| 2 | `android_vendor_lineage` `config/BoardConfigLineage.mk:10-11` | `ifeq ($(BOARD_USES_QCOM_HARDWARE),true)` → include `hardware/qcom-caf/common/BoardConfigQcom.mk` |
| 3 | our `BoardConfigCommon.mk:131` | `BOARD_USES_QCOM_HARDWARE := true` ✓ |

So `BoardConfigQcom.mk` **is** included — R3-r1's "nothing in our build includes it" was wrong.

**The one real caveat, and it is the same silent-failure class as §1.2:** `LINEAGE_BUILD` is exported
only by `android_vendor_lineage` `build/envsetup.sh:20`, i.e. only by **`brunch`**. Building with a bare
`m` skips the whole include chain, and the entire `qtiaudio.*` / `qtidisplay.*` soong namespace empties
**with no error and no warning**. Always build via `brunch lineage_gts4lvwifi`.

That namespace is *populated*, not defaulted — `drmpp=true` and `master_side_cp=true` fire automatically
(sdm710 ∈ `UM_4_9_FAMILY`, `qcom_defs.mk:8`), plus `target_uses_aligned_ycbcr_height=true` and
`target_uses_ycrcb_camera_preview=true` from our `BoardConfigCommon.mk:72-73`.

**`sdm710` is a non-issue.** The fact stands (`sdm710` appears in 0 files of the LineageOS manifest at
both 22.2 and 23.2, so it is *not* a 22.2→23.2 regression), but the consequence does not follow:
`gralloc.sdm710` is `gralloc.qcom` renamed at build time by `ANDROID.target_board_platform`, so **no
sdm710 manifest project is needed**. R4's 33 unshipped vendor libs are therefore not explained by this.

### 7.2 Unresolved: vendor property namespace

R2-r2 re-derived the count with the tool's own predicate and confirms **15 of 21** lines in
`sepolicy/vendor/property_contexts` violate the vendor property-namespace check
(`build/soong/selinux_contexts.go:357-412`, `check_prop_prefix.py:89` @ `885cc500f607`, which calls
`sys.exit(1)`). The lead confirmed at least **11** clearly lack a `vendor.` prefix after stripping
`ro.`/`persist.`: `camera.`, `mdc.`, `init.svc.compact_dump`, `persist.camera.`,
`persist.sys.bt.driver.version`, `persist.sys.ina.status`, `ro.csc.`, `ro.error.receiver.default`,
`ro.factory.factory_binary`, `ro.fastbootd.available`, `ro.netflix.channel`.

New data from round 2: the escape hatch `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` is absent from our tree
**and** from sm7125 22.2 — yet sm7125's own `property_contexts` passes 0-of-16. So something outside the
sepolicy clones sets it, or `shippingApiLevel` resolves below Q.

**Deliberately not settled.** Before the first build:
1. `grep BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` across the 23.2 manifest.
2. Print `PRODUCT_SHIPPING_API_LEVEL`.
**confidence: medium.** Watch the first ROM build's log.

### 7.3 VINTF at level 6 — round 2 reversed seven round-1 findings

R1-r2 used `compatibility_matrix.6.xml` (`level="6"`, FCM S / Android 12) from
`LineageOS/android_hardware_interfaces` @ `13d687a84c83`, combined with the three fragments
`BoardConfigCommon.mk:79-82` installs. Per model, manifest-vs-matrix (`checkUnusedHals`) direction:

| model | entries | OK | BELOW-MIN | NOT-COVERED | informational |
|---|---|---|---|---|---|
| Wi-Fi `gts4lvwifi` | 25 | 23 | 1 | 1 | 1 (`media.c2`, commented out) |
| LTE `gts4lv` | 32 | 30 | 1 | 1 | — |

On the *mandatory-minimum* axis: Wi-Fi 19 vendor-relevant mandatory instances unsatisfied (+47
framework-side), LTE 16 (+47).

**The reversals that matter most — round 1 got the *meaning* wrong, not just the facts:**

- **C2: `checkUnusedHals` is not a build gate.** `assemble_vintf` never calls it and it is not wired
  into Soong. So "NOT-COVERED" is a lint result, **not** a build failure. Round 1 presented two
  hard failures on that basis.
- **C7: `vendor.lineage.livedisplay@1` IS covered.** `android_hardware_lineage_interfaces`
  `compatibility_matrices/compatibility_matrix.lineage.xml:38-41` declares it at version 1, and it is
  installed via `vendor/lineage/config/common.mk:141`. **No action** — do *not* hand-add it to our
  `framework_compatibility_matrix.xml`. Round 1 called this a hard failure requiring a local fix.
- **C1: the combined matrix is not the union of levels ≤ target-level.** Round 1's reasoning about
  `CompatibilityMatrix::combine()` was wrong.
- **C3: `fcm_exclude.cpp` is an *exempt* list, not a deprecation list**, and `Level::R = 5` means the
  check already runs today.
- **C4: `hardware/qcom-caf/common` IS in the 23.2 manifest** — `snippets/lineage.xml:102`, included at
  `default.xml:1030`. Verified directly by the lead; independently reported by R6, R3-r2 and now R1-r2.
  Round 1's claim was wrong.
- **C5: `version="1.0"` plus an AIDL entry is legal** (`sunfish @ 52074bf3c0b6` ships `version="1.0"` at
  level 7). Round 1 flagged our manifest as suspicious for this.
- **C6: `radio@1.4` passes the unused-HAL check**, because the qcom-caf fragment allows `1.0-4` at
  `vendor_framework_compatibility_matrix.xml:248-261`.

### 7.4 What actually needs changing on the ROM side

| # | Change | Where |
|---|---|---|
| **M1** | **`target-level` — DECISION NEEDED. Do not bump blindly** | `manifest.xml:1` |
| **M2** | **No action** — keep the `soundtrigger` block. Reversed by R9 | `manifest.xml:102-110` |
| **M3** | **Impossible** — the RIL caps at radio 1.4. Do not bump | `gts4lv/manifest.xml:5` |
| M4 | **No action** for livedisplay; just verify `compatibility_matrix.lineage.xml` lands in the image | — |
| M5 | Do **not** add `<kernel target-level="6"/>` | `kEnforceDeviceManifestNoKernelLevel = Level::T` makes it a hard `assemble_vintf` error |
| **M6** | **No action** for the vendor property namespace — the check never runs at API 28. Do not set the flag, do not rename | `sepolicy/vendor/property_contexts` |
| **M7** | **No action** for `per_proxy_helper` — no blob exists, so no `file_contexts` line | `sepolicy/vendor/per_proxy_helper.te` |

#### M1 is now a decision, not a change — read this before P5

`target-level` is **not per-model**. Verified:

- `gts4lv-common/manifest.xml:1` @ `2e50286` → `<manifest version="1.0" type="device" target-level="5">`
- `gts4lv/manifest.xml:1` (the LTE per-model repo) → `<manifest version="1.0" type="device">` — **no
  `target-level` attribute**, and **0 files** in that whole repo mention `target-level`.

So one bump in the common tree moves **both** models. "LTE stays at 5, Wi-Fi goes to 6" would require
splitting the shared manifest — a restructuring nobody has costed.

And bumping to 6 is not free, because **neither model currently satisfies it**:

| | level 6 cost |
|---|---|
| Wi-Fi model | **19** vendor-relevant mandatory instances unsatisfied |
| LTE model | **16** unsatisfied, starting with `radio@1.4` |

The two facts that make this concrete, both verified directly:

- **`compatibility_matrix.5.xml` on 23.2 is a 7-line empty file.** Its whole body is a comment:
  *"Android R FCM has been deprecated, but this file is kept to help manage the android11-5.4 kernel config
  requirements."* It mandates **nothing**.
- **`compatibility_matrix.6.xml` has 80 `<version>` entries**, none wrapped in `<optional>`.

**The trade-off, stated plainly:**

- **Stay at 5** — zero VINTF validation, but nothing to satisfy and nothing that can fail. The radio keeps
  working at the 1.4 it already uses on 22.2. Requires no manifest surgery.
- **Go to 6** — real VINTF validation, which is genuinely useful for catching HAL breakage. But both models
  then have unsatisfied mandatory entries, `soundtrigger` needs deleting (M2), the LTE radio **cannot** be
  made compliant (M3), and `checkvintf` behaviour on an unsatisfied mandatory entry has to be settled.

**This is a project call, not a technical one**, and R8 — which found it — marked its own recommendation
`confidence: medium` for exactly that reason. It recommends staying at 5: level 5 costs nothing at build
time or runtime, and an FCM exemption is pointless for a ROM with no GMS.

**What P5 must not do without this decision:** §6c P5 item 1 says "bump target-level to 6". If the
decision is to stay at 5, P5 skips it.

**Also skip §6c P5 items 2, 3 and 5.** Items 2 (soundtrigger) and 3 (`per_proxy_helper`) are no-ops per R9,
and item 5 (vendor property names) is a no-op per R7. R9 asks that items 2 and 3 be logged in `P5-log.md` as
intentionally skipped — do that, so the reviewer sees they were considered rather than forgotten.

#### M2 is also a no-op — keep the soundtrigger block

**Reversed by R9.** R1-r2 recommended deleting the block. Do **not**.

The decisive fact is empirical: `LineageOS/android_device_samsung_sm7125-common` @ `865ff7e37424` is at
`target-level="6"` (`configs/manifest.xml:1`) and declares `android.hardware.soundtrigger` version **2.2**
(`configs/manifest.xml:84-88`), with **no** soundtrigger entry in any of its framework compatibility
matrices — and it ships 23.2. The commit that moved it to level 6 (`88c7b738785b`) touched soundtrigger in
**zero** commits.

Meanwhile `compatibility_matrix.6.xml:540-547` @ `13d687a84c83` does mandate 2.3, with no `<optional>`
wrapper. So the matrix and the shipping tree genuinely disagree, and the shipping tree is the ground truth.

**`confidence: medium` on the mechanism, `high` on the conclusion.** R9 could not read the rule that
explains it: `selinux_contexts.go` is in `android_system_sepolicy`, and the deciding code is in
`system/tools/vintf`, which is **not clonable** — `LineageOS/android_system_tools_vintf` and
`aosp-mirror/platform_system_tools_vintf` both 404. R9's best explanation is that a frozen matrix
supersedes the level-6 entry. Plausible, unproven. The decision does not depend on it: sm7125 does exactly
what we would do, and it ships.

R9 also confirmed the blast radius is tiny — if the block is ever removed, only **two** lines change:
`manifest.xml:102-110` and `gts4lv.mk:58`. No `.rc`, sepolicy, blob-list or `Android.bp` change, because
soundtrigger 2.2 is a passthrough over the legacy hw module started by the audio HAL service
(`init.qcom.rc:785`), not its own service.

#### M2b: `per_proxy_helper` — no blob, so no `file_contexts` line

R9 found **no `per_proxy_helper` binary anywhere**: 0 path hits and 0 content hits across both vendor
repos, absent from all 34 `vendor/bin/**` rows of `proprietary-files.txt`. The declaration came from
`e88df885ca24` (2019, *"somewhat blindly reverse engineered from stock"*).

So the domain is **provably dead** — with no exec label, `domain_auto_trans()` never fires. **Do not add
the `file_contexts` line** R9 drafted. Deleting `sepolicy/vendor/per_proxy_helper.te` (8 dead lines) is
optional; leaving it is equally safe and smaller.

`kgsl_device` is also genuinely dead and must stay that way: `qsevndr`
`legacy/vendor/common/file_contexts:36` already labels `/dev/kgsl-3d0` as `gpu_device`, and 17 blobs use
that node. **Do not label it.**

#### M1c: vendor property namespace — resolved, no change needed

**R7 closed this; two earlier rounds failed to.** The check will **not** run for us.

The condition is in `build/soong/selinux_contexts.go:419-423` @ `885cc500f607` — note that file is in
`android_system_sepolicy`, **not** `android_build_soong`:

```go
shippingApiLevel := ctx.DeviceConfig().ShippingApiLevel()
ApiLevelQ := android.ApiLevelOrPanic(ctx, "Q")
if (ctx.SocSpecific() || ctx.DeviceSpecific()) && shippingApiLevel.GreaterThanOrEqualTo(ApiLevelQ) {
    builtCtxFile = m.checkVendorPropertyNamespace(ctx, builtCtxFile)
}
```

`Q` = 29 (`soong android/api_levels.go:466-468`). Our level is **28**:

- `gts4lv.mk:18` @ `2e50286ebc01` → `build/target/product/product_launched_with_p.mk:2` @ `e5aaa62172df`
  → `PRODUCT_SHIPPING_API_LEVEL := 28`

`28 >= 29` is false, so the check never runs. `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` is set by nothing
in the whole chain (only its definition at `build/core/board_config.rb:187`).

**Do not set the flag** — it would be a permanent dead suppression. **Do not rename the properties**: only
one of the 15 is set anywhere outside the file (`vendor.prop:119` `ro.fastbootd.available=true`), and
`system/core/init/reboot.cpp:1111` reads that exact name — renaming builds fine and silently kills the
`adb reboot fastboot` fallback.

This also explains the 15-vs-11 discrepancy two rounds disagreed on: **15** lines fail at shipping API ≥ R,
**11** at ≤ R (the `persist.camera.` case is allowed and the `vendor_`/`odm_` context rule is off). We are
at 28, so 11.

**The thing actually worth guarding:** anything that raises `PRODUCT_SHIPPING_API_LEVEL` above 28 turns the
check on and the build starts failing. The same 28 also keeps the `>= 29` `$(error)` blocks in
`build/core/config.mk:839-845,912-918` quiet. **confidence: high**.

#### A pattern worth noting

Three of the ROM-side plan items (M1, M2, M3) were all questioned or overturned by round-3 agents, and in
each case it was a round-2 conclusion (R1-r2, R5) that did not survive. R1-r2's *facts* were sound; its
*inferences* about what they meant were not — twice it read a lint result as a build gate. When a round-3
agent contradicts a round-2 verdict on this device, check the claim against a shipping tree before acting
on either.

#### M3 is impossible, not just optional

R8 established with four independent signals that the vendor RIL **cannot** do radio 1.5:

| Evidence | Ceiling |
|---|---|
| `readelf -d lib64/libril.so` `NEEDED` | `android.hardware.radio@1.4.so` |
| HIDL descriptor strings in `lib/libril.so` | `@1.1\|1.2\|1.3\|1.4::IRadio` — no 1.5 or 1.6, 0 occurrences |
| Impl classes | `RadioImpl_V1_4` — no `V1_5`/`V1_6` |
| Samsung's own 23.2 source, `hardware/samsung/interfaces/radio/{2.0,2.1,2.2}/Android.bp:14-17` | highest dep is `android.hardware.radio@1.4` |

**`android.hardware.radio@1.5` appears nowhere** — 0 hits across all 81 files of `proprietary_vendor_samsung_gts4lv`
and all 685 of the `-common` sibling. Note the trap R8 was warned about did **not** fire: this is not one
binary carrying several version strings where the highest is aspirational. It carries four version strings
and the fourth really is the ceiling — `libril.so` is the CAF HIDL shim that both links the proxies and calls
`registerAsService()`.

There is also a second, independent blocker: the qcom-caf fragment our own build installs
(`vendor_framework_compatibility_matrix.xml:248-261` @ `1805784d14b3`) allows only radio `1.0-4`, so 1.5 is
*above our own declared range*. R1-r2 had used that fragment only in the safe direction.

`radio.config` has the same shape of problem: the RIL serves 1.1 and does not even register the 1.2 it
links, so `gts4lv/manifest.xml:11` cannot be bumped either.

On M2: `soundtrigger@2.2` is declared at `manifest.xml:105` and level 6 requires 2.3
(`compatibility_matrix.6.xml:540-547`). It cannot simply be bumped — `android_hardware_qcom_audio`
@ `90647c475fc5` `configs/sdm710/sdm710.mk:411` builds **only** `android.hardware.soundtrigger@2.1-impl`,
so no 2.2 or 2.3 exists for sdm710 at all.

### 7.5 Round-2 sepolicy branch pins (R2)

`android_device_qcom_sepolicy` DOES have `lineage-23.2`, at `d903f8e1e0c4` — round 1 of R2 claimed it
must stay pinned at 22.2. **Verified.** The repo carries `lineage-23.0/23.1/23.2/24.0`.

`android_device_qcom_sepolicy_vndr` genuinely has **no** plain `lineage-23.2`; the branch is
`lineage-23.2-legacy-um` (`0dbc76e4b759`). It also carries four `lineage-23.2-caf-sm{8450,8550,8650,8750}`
variants — **verified**, 15 `lineage-23*` branches in total.

R2-r2 also checked all 198 types and 18 macros against QSSI's *compiled* directories: 0 hits, so the
vndr pin cannot change any verdict.

**Latent runtime problem found (not a build break):** `per_proxy_helper` is declared at
`sepolicy/vendor/per_proxy_helper.te:2` but **no `file_contexts` line assigns it**, while
`init_daemon_domain(per_proxy_helper)` expands to `domain_auto_trans(init, $1_exec, $1)`
(`public/te_macros:163-165` @ `885cc500f607`) and needs it labelled. Also declared and never referenced:
`kgsl_device` (`device.te:8`). Worth fixing before first boot.

`sepolicy/public/property_contexts:1` remains **low** confidence in both rounds — the type is a platform
type in the product partition, but `public/attributes:134-137` shows product attributes are deliberate m4
aliases of the system ones, which argues against it being an error. No enforcing check was found either
way, and R2-r2 correctly declined to guess.

## 8. Defects found in the task specs themselves

Worth a pass over `AGENT-TASKS.md` before the next batch:

1. **§K1's LRU_HASH spot-check is false** (§1.2). Highest value-per-effort fix in the repo.
2. **§K6 says "options to add" then lists 12**, not 11.
3. **§R3's suggested command does not work** — `git ls-remote --heads https://github.com/LineageOS`
   returns `remote: Not Found`. R3 used the GitHub repository-search API instead.
4. **§K2 step 3's isolated `merge-tree` method is misleading** (§5). Six agents reported it.
5. **§K5's area definitions have blind spots** — `drivers/soc/qcom` `*qmi*` misses two built files
   outside that directory; `drivers/net/wireless` "Samsung parts" resolves to CNSS only.
6. **§K5 step 1's header list is incomplete** — three more headers were never audited (§6).
7. **HANDOVER.md:51's blocklist is stale.** It says `lineageos.org` is unreachable from the cloud
   container. **M2 and T2 both got HTTP 200 from `wiki.lineageos.org`**, and T2's device-page citations
   are the authoritative source for the recovery/download button combinations. Only `xdaforums.com`
   (403) and `samfw.com` (403) are actually blocked.

## 9. Branch artifacts and caveats

**Repair commits.** Three agents died mid-task without handing in:

| Task | What happened | What the lead did |
|---|---|---|
| K2b-1 | 9/9 briefs + summary written, never committed | added the missing `## Conflicting files` section to `05e4636c5fed.md`; committed and pushed |
| K2b-4 | 7/8 briefs, no summary, never committed | wrote the missing brief `bca02018e7d0.md` (all facts re-derived), wrote `K2b-4-summary.md`, and added the missing `## Already in sdm670?` section to all 7 inherited briefs; two commits |
| K2d-3 | **nothing at all** | relaunched with instructions to commit one brief at a time; it pushed 3 early, then completed 7/7 |

**Format-check failure found by the lead, not self-reported.** K2a-2 wrote its verdicts as
`**MERGE**` / `**high**`, which `scripts/check-agent-output.sh` rejects (it reads the line immediately
after the heading and requires a bare keyword). Its self-check verified section *presence* but never ran
the repo's own checker, so it reported success. The lead ran all 17 batches: **K2a-2 was the only
failure.** Fixed by un-bolding — formatting only, no content changed — and pushed as a second commit.
Lesson: the checker in `scripts/` is the only thing that catches this class, and one agent in six
forgot to run it.

**K2b-1 and K2b-4 therefore contain lead-authored content.** The added `## Already in sdm670?` sections
are sourced from fresh greps against `a30605a54f3b`, but `bca02018e7d0` has had **one** reviewer, not two.

**K5 blind spot.** K5b–f fetched `changed-api.txt` at K5a's **first** push, whose 16 compound symbol
names `git grep -w` cannot match. K5a fixed it at `5d2fae5` and the branch tip is correct, so merging K5a
resolves it. The 16 names are in
[`analysis/tools/k5a-compound16-blindspot.txt`](analysis/tools/k5a-compound16-blindspot.txt).

**Model tier.** Every agent ran on Space Bunny Free. `AGENT-TASKS.md` §10 says not to use untested free
models for K and R tasks. The lead re-verified a large share of the load-bearing claims directly against
the kernel tree and they held, but this does not substitute for the §11 review.

**Review order** (cheapest and highest-value first):

1. `bash scripts/check-agent-output.sh <task-id>` on all 17 conflict batches — no AI needed.
2. Re-derive conflict counts from a real cherry-pick on a scratch branch (§5).
3. Check every `DROP` — there are **15**, and a wrong one loses code silently:
   K2d-1 ×5, K2a-1 ×2, K2a-2 ×2, K2c-1 ×2, K2b-2 ×1, K2b-4 ×1, K2d-2 ×1, K2d-3 ×1.
   The lead verified 4 of them directly (K2a-1's two, K2c-1's two — all sound, identical upstream SHA
   *and* Change-Id as the sdm670 copy) plus K2d-2's `d5f2acfd8dc2`. **9 remain unverified.**
4. Every `low` and every `HUMAN`. There are **0 HUMAN and 0 low** across all 113 K2 briefs —
   75 `high`, 38 `medium`. So step 4 is nearly free; spend the effort on step 3 instead.
5. Spot-check ~20% of `high` per batch.

K2 verdict totals across all 113 briefs, parsed from the pushed files:

| Resolution | Count | | Confidence | Count |
|---|---|---|---|---|
| MERGE | 76 | | high | 75 |
| PREREQ | 22 | | medium | 38 |
| DROP | 15 | | low | 0 |
| HUMAN | 0 | | | |

## 10. Environment and reproduction

```
docs repo      <docs repo>   (main, never pushed to)
agent worktree ~/work/wt/<task-id>                                40 worktrees, one per task
kernel clone   ~/work/k670        READ-ONLY, shared by ~30 agents
```

Kernel tree verified state: sdm670 tip `a30605a54f3b92627d868f169c72ef9c6ef82123`, series base
`d54533f1546b91f94eb4e445dfea3a94ffa58a74`, series head
`baa585f67e0efc9f1efa046d0b0e76955ca4c8d5`, 2,599 commits, `exy/l222` + `exy/l232` fetched.

Two notes for the next run:

- **One worktree per agent, never `git checkout` in the shared repo.** All 39 agents ran concurrently
  without a single HEAD collision because each had its own worktree.
- **Agents repeatedly wrote outside their sandbox** — three separate times something landed in the main
  repo or the shared kernel tree: a 2.3 GB kernel clone, a `clone-dt.log`, 8 junk files from a mangled
  redirect (`hich\t|`, `ork_struct\t|`), and a 3.7 MB `csdi/` partial clone. All were found and removed,
  and `main` and the kernel tree are clean. Worth a pre-check hook rather than relying on catching it.

## 11. Not covered

- The 12 `large` required conflicts' **resolutions** — K3 briefs are facts-only by design.
- `include/linux/if_ether.h`, `include/net/ip.h`, `include/uapi/linux/bpf.h` against the changed API.
- Neverallow violations in sepolicy (needs a policy build).
- Whether CAF's `soundtrigger` is built at 2.3, and who declares `media.c2` — both need a built tree.
- The vendor property-namespace question (§7.2).
- Everything past the first compile error, by construction.

## Problems

- I pushed `agent/K2b-4` **before** running `scripts/check-agent-output.sh`; it had 12 failures at that
  point, including 7 briefs missing the section that carries their DROP/MERGE evidence. Fixed and pushed
  again in a follow-up commit. Both branches therefore have a repair commit in their history.
- I initially measured that 70.9% of trial-`CLEAN` commits conflict standalone and was about to report
  it as a major finding. Reading `trial.py:31` showed the trial replays **stacked and in order**, which
  is what an in-order cherry-pick does — so that number measured the wrong scenario and I withdrew it.
  §5 is the corrected version.
