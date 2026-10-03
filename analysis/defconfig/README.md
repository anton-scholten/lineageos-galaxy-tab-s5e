<!-- task: K6 | agent: Space Bunny Free | date: 2026-10-03 -->
# K6: defconfig fragment for gts4lv on 23.2

## Summary

17 options: **14 turn on**, **3 turn off**, plus `CONFIG_UPROBES=y`, which round 1 wrongly called optional
(Android 16's `bpfloader` uses uprobes, and `2d6869d3a4ce`'s `uprobes.c` + `signal.c` hook are dead code without it).
The fragment is **33 `CONFIG_*=y` lines** (14 requested + 1 correction + 8 dependencies that are not explicit lines
today + 10 already-satisfied dependencies re-stated) and **3 uncommented `# CONFIG_* is not set` lines**;
**9 dependencies had to be pulled in**, of which 2 are mandatory (`BPF_JIT`, `CGROUP_SCHED`) and 1 (`BLK_CGROUP`)
is only missing from the two `*_eur_open_defconfig` files. **Three blockers**: `UNICODE` is still a no-op
(`fs/unicode/` is absent from sdm670 and the series never brings it), `BPF_LSM` is still silently dropped without
its four-dep chain, and `CONFIG_CGROUP_SCHED=y` turns out to be **mandatory, not optional** — it is the only thing
keeping `SCHED_WALT=y` alive under the Exy form of `init/Kconfig`. Biggest correction to my round-1 report:
**do not** "fix" a WALT scheduler build error with `# CONFIG_FAIR_GROUP_SCHED is not set`, because the series head
has `SCHED_WALT depends on FAIR_GROUP_SCHED` — that would switch WALT off. `RT_GROUP_SCHED` is resolved in favour
of turning it **off** (reasoning in "The RT_GROUP_SCHED contradiction"). `DEBUG_INFO_BTF` needs **pahole ≥ v1.13**
on `PATH` in the kernel build environment, plus the new `tools/bpf/resolve_btfids` host tool. Nothing was applied to
any kernel tree; only the two files in this directory were written.

Output: [`gts4lv-23.2.fragment`](gts4lv-23.2.fragment) (this directory), this file.
Supersedes `origin/agent/K6` (`analysis/defconfig/`), whose 28-line fragment covered only 12 options and had no
turn-off lines.

Trees, all read-only, in `~/work/k670`:
sdm670 = `a30605a54f3b92627d868f169c72ef9c6ef82123`, series base = `d54533f1546b91f94eb4e445dfea3a94ffa58a74`,
series head = `baa585f67e0efc9f1efa046d0b0e76955ca4c8d5` (2,599 commits, verified).
The four defconfigs are `arch/arm64/configs/{gts4lv,gts4lvwifi}_defconfig` (810 / 808 lines, hand-written) and
`arch/arm64/configs/{gts4lv,gts4lvwifi}_eur_open_defconfig` (6,023 lines, header says "Automatically generated
file; DO NOT EDIT. Linux/arm64 4.9.227" = full `.config` dumps). The two `_defconfig` files differ only in three
lines (`diff`: `SEC_GTS4LV_EUR_PROJECT`, `SENSORS_SX9330`, `MSM_VIBRATOR`); the two `_eur_open` files differ only
in the same three options. **Every line in this fragment is identical in both pairs.**

---

## The 17 requested options

`depends on` is transcribed from the Kconfig block at the cited line, read out of the **series head**. The last
column says the state in all four defconfigs at `a30605a54f3b`; `gts4lv`/`gts4lvwifi` and
`gts4lv_eur`/`gts4lvwifi_eur` are always identical for these lines, so they are written as pairs.

### Turn on (14)

| option | Kconfig file:line @ `baa585f67e0e` | depends on | in sdm670 Kconfig? | already in sdm670 defconfig? |
|---|---|---|---|---|
| `ANDROID_BINDERFS` | `drivers/android/Kconfig:22` | `ANDROID_BINDER_IPC` (inside `if ANDROID`, `:8`; that needs `MMU && !M68K`, `:12`) | **no** — arrives with series `c286cded153a` | no line in any of the four |
| `BPF_LSM` | `init/Kconfig:1950` | `BPF_EVENTS`, `BPF_SYSCALL`, `SECURITY`, `BPF_JIT` (`:1952-1955`) | **no** — series `eb8726624efa` | no line in any of the four |
| `CFQ_GROUP_IOSCHED` | `block/Kconfig.iosched:35` | `IOSCHED_CFQ && BLK_CGROUP` (`:37`) | yes (same line) | **already `=y`**: `gts4lv:59`; `gts4lv_eur`: **absent** |
| `DEBUG_INFO_BTF` | `lib/Kconfig.debug:177` | `DEBUG_INFO` (`:179`) | **no** — series `8a953036e3b5`, `ae25ca2f3a61` | no line in any of the four (dep `DEBUG_INFO=y` at `gts4lv:775`) |
| `FUSE_BPF` | `fs/fuse/Kconfig:20` | `FUSE_FS`, `BPF_SYSCALL` (`:22-23`) | **no** — series `462a37becb45` | no line in any of the four (deps `=y` at `gts4lv:758`, `:42`) |
| `KPROBES` | `arch/Kconfig:43` | `MODULES`, `HAVE_KPROBES` (arm64 selects at `arch/arm64/Kconfig:101`); `select KALLSYMS` (`:47`) | yes (same line) | **off**: no line in `gts4lv`; `# ... is not set` at `gts4lv_eur:233` |
| `NET_ACT_BPF` | `net/sched/Kconfig:728` | `NET_CLS_ACT` (`:730`) | yes (same line) | **off**: no line in `gts4lv`; `# ... is not set` at `gts4lv_eur:1140` |
| `PSI` | `init/Kconfig:494` (= `init/Kconfig:486` @ `a30605a54f3b`) | none | yes | **already `=y`** at `gts4lv:11`; `gts4lv_eur:108` `# ... is not set` |
| `UCLAMP_TASK` | `init/Kconfig:972` | `CPU_FREQ_GOV_SCHEDUTIL` (`:974`) | **no** — series `74b2f258866b` | no line in any of the four (dep `=y` at `gts4lv:97`) |
| `UCLAMP_TASK_GROUP` | `init/Kconfig:1307` | `CGROUP_SCHED`, `UCLAMP_TASK` (`:1308-1309`); sits **outside** the `if CGROUP_SCHED` block | **no** — series `ed50d477d59a` | no line in any of the four |
| `UNICODE` | `fs/unicode/Kconfig:4` | none | **no, and neither is the code** | no line — see **Blocker 1** |
| `USERFAULTFD` | `init/Kconfig:2009` (= `init/Kconfig:1860` @ `a30605a54f3b`) | `MMU` (`:2011`) | yes | **off**: no line in `gts4lv`; `# ... is not set` at `gts4lv_eur:208` |
| `XDP_SOCKETS` | `net/xdp/Kconfig:2` | `BPF_SYSCALL` (`:4`) | **no** — series `f787c74339cb` | no line in any of the four (**new in this list**) |
| `XDP_SOCKETS_DIAG` | `net/xdp/Kconfig:12` (tristate) | `XDP_SOCKETS` (`:14`) | **no** — same commit | no line in any of the four (**new in this list**) |

### Turn off (3)

| option | Kconfig file:line @ `baa585f67e0e` | depends on | in sdm670 Kconfig? | state in sdm670 defconfig? |
|---|---|---|---|---|
| `USER_NS` | `init/Kconfig:1476` | **none** — `default n`, so nothing has to be on first | yes (`init/Kconfig:1380`) | **already off**: no line in `gts4lv` (Kconfig default does it); `gts4lv_eur:163` `# ... is not set` |
| `RT_GROUP_SCHED` | `init/Kconfig:1294` | `CGROUP_SCHED` (`:1295`), `default n`; inside the `if CGROUP_SCHED` block (closes `:1305`) | yes (`init/Kconfig:1200`) | **says `=y` at `gts4lv:28` and `gts4lv_eur:154`, but it is a dead line** — see below |
| `SCHED_TUNE` | `init/Kconfig:1520` | `!UCLAMP_TASK` (`:1521`), `SMP` (`:1522`), no default | yes (`init/Kconfig:1424`) | **says `=y` at `gts4lv:34` and `gts4lv_eur:167`**; dies by itself once `UCLAMP_TASK=y` |

### The round-2 correction

| option | Kconfig file:line | depends on | in sdm670 Kconfig? | state in sdm670 defconfig? |
|---|---|---|---|---|
| `UPROBES` | `arch/Kconfig:100` @ **both** trees | **none.** `def_bool n` — *not* `depends on KPROBES` | yes (`arch/Kconfig:100` @ `a30605a54f3b`) | **off**: no line in `gts4lv`; `gts4lv_eur:235` `# ... is not set`. Its prerequisite `ARCH_SUPPORTS_UPROBES` (`arch/arm64/Kconfig:248`, `def_bool y`) **does not exist in sdm670** — series `2d6869d3a4ce` |

confidence: high — every cell was read with `git show` / `git grep` against the two trees; the Kconfig line numbers
were re-derived independently in this round by grepping `^config <NAME>$` in both trees (paste in "Self-check"),
and every dependency chain was followed to its `def_bool y` / `select` terminus on arm64.

**9 of the 17 do not exist in sdm670's Kconfig at all** and arrive with the series: `ANDROID_BINDERFS`,
`BPF_LSM`, `DEBUG_INFO_BTF`, `FUSE_BPF`, `UCLAMP_TASK`, `UCLAMP_TASK_GROUP`, `UNICODE`, `XDP_SOCKETS`,
`XDP_SOCKETS_DIAG`. The other 8 already exist (`CFQ_GROUP_IOSCHED`, `KPROBES`, `NET_ACT_BPF`, `PSI`,
`USERFAULTFD`, `USER_NS`, `RT_GROUP_SCHED`, `SCHED_TUNE`, plus `UPROBES` = 9).
confidence: high — `git grep -n "^config X$"` returns nothing for the 9 in `a30605a54f3b` and a hit for the rest;
the four `*_eur_open` files were also checked for every name.

---

## Dependency closure — 9 dependencies pulled in

Nine lines in the fragment are not in the requested list. Without them the option they serve is **silently dropped**
by `oldconfig`: no build error, no warning, just a missing feature.

| # | dependency | needed by | Kconfig evidence | state before this fragment |
|---|---|---|---|---|
| 1 | `PERF_EVENTS=y` | `BPF_EVENTS` | `kernel/trace/Kconfig:482` needs `&& PERF_EVENTS`; `init/Kconfig:2063-2066`: `default y if PROFILING`, `depends on HAVE_PERF_EVENTS` (arm64 selects at `arch/arm64/Kconfig:95`) | **correcting round 1: not actually missing.** `gts4lv_defconfig:46` already has `CONFIG_PROFILING=y` (`gts4lv_eur:231`), and `init/Kconfig:2065` is `default y if PROFILING`, so it is already `=y` by default. Pinned anyway so the `BPF_LSM` chain does not silently depend on `PROFILING` staying on. |
| 2 | `KPROBE_EVENTS=y` | `BPF_EVENTS` | `kernel/trace/Kconfig:445-451`: `depends on KPROBES`, `depends on HAVE_REGS_AND_STACK_ACCESS_API` (arm64 selects at `arch/arm64/Kconfig:98`), `select TRACING`, `select PROBE_EVENTS`, `default y`. Reachable because it lives in `if TRACING_SUPPORT` (`kernel/trace/Kconfig:123-719`) and arm64 defines both of that symbol's deps `def_bool y` (`arch/arm64/Kconfig:176` `STACKTRACE_SUPPORT`, `:186` `TRACE_IRQFLAGS_SUPPORT`) | off in all four (`=y` needs `KPROBES=y` first) |
| 3 | `BPF_EVENTS=y` | `BPF_LSM` | `init/Kconfig:1952`; entry `kernel/trace/Kconfig:480-484`, no-prompt bool, `default y`, needs `BPF_SYSCALL` + `(KPROBE_EVENTS \|\| UPROBE_EVENTS) && PERF_EVENTS` | follows #1 + #2; listed so the chain is explicit |
| 4 | **`BPF_JIT=y`** | `BPF_LSM` | `init/Kconfig:1955`; entry `net/Kconfig:297-301`: `depends on HAVE_CBPF_JIT \|\| HAVE_EBPF_JIT` (arm64 selects `HAVE_EBPF_JIT` at `arch/arm64/Kconfig:73`), `depends on MODULES`, `depends on !CFI` | **`default n` — genuinely off.** `gts4lv_eur:1170` even says `# CONFIG_BPF_JIT is not set`. **Without this line `BPF_LSM` cannot be set at all.** |
| 5 | `KALLSYMS=y` | `KPROBES` (via `select`) | `arch/Kconfig:47` selects it; entry `init/Kconfig:1787-1789` (`default y`) | not pinned in `gts4lv`. Side note: `gts4lv_defconfig:41` has `CONFIG_KALLSYMS_ALL=y`, which needs `KALLSYMS` **and** `DEBUG_KERNEL` (`init/Kconfig:1797`); `DEBUG_KERNEL` (`lib/Kconfig.debug:424`) has no default and is absent from `gts4lv`, so that line is already dead. Only `gts4lv_eur:5516` sets it. Pre-existing, not caused by this fragment. |
| 6 | `IOSCHED_CFQ=y` | `CFQ_GROUP_IOSCHED` | `block/Kconfig.iosched:37`; entry `:24-26`, tristate, `default y` | `=y` by default, not pinned in `gts4lv`; `gts4lv_eur:355` has it |
| 7 | **`BLK_CGROUP=y`** | `CFQ_GROUP_IOSCHED` | `block/Kconfig.iosched:37`; entry `init/Kconfig:1234-1237`, `depends on BLOCK`, `default n` | `=y` at `gts4lv:27`, **but `gts4lv_eur:151` says `# CONFIG_BLK_CGROUP is not set`** → without this line `CFQ_GROUP_IOSCHED` is dropped on the two `eur_open` files |
| 8 | **`CGROUP_SCHED=y`** | `UCLAMP_TASK_GROUP` | `init/Kconfig:1308`; entry `menuconfig CGROUP_SCHED` at `init/Kconfig:1269-1271`, `default n` | **off** in `gts4lv` (default). `gts4lv_eur:152` already `=y`. **Mandatory, not just for uclamp — see Blocker 3.** |
| 9 | `UPROBES=y` | round-2 correction, not a dependency of another option | `arch/Kconfig:100-101` in both trees, `def_bool n`, no deps | off in all four |

Ten further dependencies are **already satisfied** and are re-stated in fragment section 3 so the file is
self-contained and can be appended to any of the four defconfigs without re-checking:
`ANDROID` (`gts4lv:704` / `eur:5072`), `ANDROID_BINDER_IPC` (`:705` / `:5073`), `BPF_SYSCALL` (`:42` / `:204`),
`SECURITY` (`:793` / `:5726`), `MODULES` (`:49` / `:299`), `DEBUG_INFO` (`:775` / `:5495`), `FUSE_FS`
(`:758` / `:5316`), `NET_CLS_ACT` (`:241` / `:1128`), `CPU_FREQ_GOV_SCHEDUTIL` (`:97` / `:693`), `MMU`
(`arm64 def_bool y`; `eur:8`).

Two automatic side effects, no fragment line needed:

- **`KPROBE_EVENTS` `select TRACING`** (`kernel/trace/Kconfig:449`). `TRACING` selects `DEBUG_FS`, `RING_BUFFER`,
  `STACKTRACE`, `TRACEPOINTS`, `NOP_TRACER`, `BINARY_PRINTF`, `EVENT_TRACING`, `TRACE_CLOCK`. None is in
  `gts4lv_defconfig` today. The kernel grows and ftrace becomes available. Unavoidable if `BPF_LSM` is wanted.
- **`CGROUP_SCHED=y` → `FAIR_GROUP_SCHED=y`** (`default CGROUP_SCHED`, `init/Kconfig:1278-1281`). See Blocker 3.

confidence: high — each line quoted verbatim from the Kconfig blocks read at `baa585f67e0e`; every "missing before"
claim comes from grepping all four defconfigs for the exact symbol.

---

## Blockers

### Blocker 1 — `CONFIG_UNICODE=y` is a no-op until someone copies the code

`fs/unicode/` exists at the series base `d54533f1546b` (10 files: `Kconfig`, `Makefile`, `utf8-core.c`,
`utf8-norm.c`, `utf8-selftest.c`, `utf8data.h_shipped`, `utf8n.h`, `mkutf8data.c`, `README.utf8data`, `.gitignore`)
and at the head `baa585f67e0e`, but it is **absent from sdm670**, and:

```
$ git -C ~/work/k670 log --oneline d54533f1546b..baa585f67e0e -- fs/unicode/ | wc -l
0
$ git -C ~/work/k670 ls-tree a30605a54f3b fs/unicode          # (no output = absent)
$ git -C ~/work/k670 ls-tree a30605a54f3b fs/unicode; git -C ... show a30605a54f3b:fs/Makefile | grep unicode
(no output for either)
```

So the series never brings it. After the cherry-pick the Kconfig entry will not exist at all, and the Makefile hook
`obj-$(CONFIG_UNICODE) += unicode/` (`fs/Makefile:96` @ `baa585f67e0e`) will be missing. **Either** copy
`fs/unicode/` from `d54533f1546b` and add that `fs/Makefile` line, **or** drop the `CONFIG_UNICODE=y` line. Keeping
it while copying nothing is the worst option: it looks done and delivers nothing. Without it, f2fs/ext4 NFD
(casefolding, compression) support is missing.

This is the same finding as round 1 and it still stands. confidence: high — three independent commands, quoted above.

### Blocker 2 — `BPF_LSM` is still silently dropped without its four-dep chain

`init/Kconfig:1950-1955` @ `baa585f67e0e` gives four separate `depends on`: `BPF_EVENTS`, `BPF_SYSCALL`,
`SECURITY`, `BPF_JIT`. Only `BPF_SYSCALL` (`gts4lv_defconfig:42`) and `SECURITY` (`:793`) are present today.
`BPF_JIT` is `default n` and is even explicitly off in `gts4lv_eur_open_defconfig:1170`. `BPF_EVENTS` is a
no-prompt bool (`kernel/trace/Kconfig:480-484`) that itself needs `(KPROBE_EVENTS || UPROBE_EVENTS) && PERF_EVENTS`
(`:482`). Without fragment lines 2.1–2.4 kconfig drops `BPF_LSM` **with no error and no warning** — the LSM hooks
simply do not exist, and you find out at runtime when a BPF LSM program fails to attach.

Unchanged from round 1. confidence: high — the four `depends on` lines and `default n` were read directly, and the
defconfig state comes from grepping all four files.

### Blocker 3 — `CONFIG_CGROUP_SCHED=y` is mandatory, and it is what keeps WALT alive

**This is the big new finding of round 2, and it inverts part of the round-1 advice.**

`SCHED_WALT`'s Kconfig differs between the two trees:

| tree | `config SCHED_WALT` |
|---|---|
| sdm670 | `init/Kconfig:407-410` @ `a30605a54f3b` — `depends on SMP` **only** |
| Exy base **and** head | `init/Kconfig:402-406` — `depends on SMP` **and `depends on FAIR_GROUP_SCHED`** |

The series does **not** introduce that dependency: `git log -S'depends on FAIR_GROUP_SCHED' d54533f1546b..baa585f67e0e -- init/Kconfig`
returns nothing, and it is already at the series base `d54533f1546b:init/Kconfig:405`. In sdm670 it only ever
existed as part of upstream CFS; the Android WALT commit `26c2154816c7` ("ANDROID: sched: Introduce Window Assisted
Load Tracking (WALT)") added `config SCHED_WALT` from scratch with `depends on SMP` and no `FAIR_GROUP_SCHED`
(`git log -L '/^config SCHED_WALT$/,+4:init/Kconfig' a30605a54f3b` returns that one commit only).

So the merged tree's WALT dependency is **at the mercy of conflict resolution**: the series rewrites `init/Kconfig`
immediately around that block (it adds `SCHED_WALT_DEFAULT` at `init/Kconfig:412` @ `baa585f67e0e`). If the Exy
form wins and `CONFIG_CGROUP_SCHED` is `n`, **`walt.o` silently stops being built** and the tablet loses its
scheduler — with no build error. Setting `CONFIG_CGROUP_SCHED=y` makes `SCHED_WALT=y` survive under *either*
resolution. It is needed for `UCLAMP_TASK_GROUP` anyway, so this costs nothing.

The companion guard is also at risk. sdm670 has `depends on !SCHED_WALT` on `CFS_BANDWIDTH`
(`init/Kconfig:1191` @ `a30605a54f3b`); the Exy tree has no such line at either base (`d54533f1546b:init/Kconfig:1230-1233`)
or head (`baa585f67e0e:init/Kconfig:1283-1286`). That guard is sdm670-local Android work — `d342ee64906f` and
`e032df4b1246` "ANDROID: sched: Disallow WALT with CFS bandwidth control", reverted by `45be79a2ec16`, present again
at the tip. The same `init/Kconfig` rewrite can drop it.

**Practical consequence for the lead, and a correction to round 1:** if the scheduler fails to build with
`FAIR_GROUP_SCHED=y && SCHED_WALT=y`, **do not** set `# CONFIG_FAIR_GROUP_SCHED is not set`. Round 1 suggested that;
it is wrong under the Exy form of the Kconfig, because it would switch `SCHED_WALT` off too. The right move is to
leave `CFS_BANDWIDTH` off — it is `default n` (`init/Kconfig:1286`) and **this fragment deliberately does not turn
it on** — and, if needed, to put `depends on !SCHED_WALT` back on `CFS_BANDWIDTH` by hand. That guard exists
precisely because WALT and CFS bandwidth control fight over the same scheduler state.

confidence: high on the Kconfig facts (every line quoted, both trees read, `git log -L` used to establish sdm670's
WALT history). medium on the merge outcome, which depends on how the lead resolves the `init/Kconfig` hunks — I did
not cherry-pick anything.

---

## The `RT_GROUP_SCHED` contradiction — how I resolved it

`gts4lv_defconfig:28` and `gts4lv_eur_open_defconfig:154` both say `CONFIG_RT_GROUP_SCHED=y`. This task's option
list says turn it **off**. The line is currently **dead**: `RT_GROUP_SCHED` `depends on CGROUP_SCHED`
(`init/Kconfig:1295` @ `baa585f67e0e`) and `CGROUP_SCHED` was `n` in the small defconfigs. Adding
`CONFIG_CGROUP_SCHED=y` (which Blocker 3 shows is mandatory) **revives** the stale `=y`.

**I turned it off, and left the `# CONFIG_RT_GROUP_SCHED is not set` line uncommented.** The fragment is appended to
the end of the defconfig, and kconfig reads a defconfig in one top-to-bottom pass in which the **last** line for a
symbol wins — verified in `scripts/kconfig/confdata.c` @ `baa585f67e0e`: `conf_read_simple()` (`:251`) first resets
every symbol to `tri = no` (`:310`), then on each `# CONFIG_X is not set` line sets `sym->def[def].tri = no`
(`:343`, gated by the `strncmp(p, "is not set", 10)` test at `:324`) and on each `CONFIG_X=y` line calls
`conf_set_sym_val()` (`:374`), which sets `tri = yes` (`confdata.c:126-148`). So the later `is not set` wins over
`gts4lv_defconfig:28`. Reasons:

1. **The reference defconfig this list came from has no `RT_GROUP_SCHED` line at all.**
   `arch/arm64/configs/exynos9810-starlte_defconfig` @ `baa585f67e0e` has zero hits for `RT_GROUP_SCHED`,
   `USER_NS` and `SCHED_TUNE` — all three take the Kconfig default of `n` — while the same file *does* explicitly
   pin the options that need pinning (`CONFIG_BLK_CGROUP=y` `:27`, `CONFIG_CGROUP_SCHED=y` `:28`,
   `CONFIG_BPF_JIT=y` `:236`). The list's three "turn off" entries are therefore describing "absent from the Exy
   defconfig", which for a `default n` symbol means off.
2. **The trial README lists `CONFIG_RT_GROUP_SCHED` as one of the three things the series disables**
   (`analysis/exyhyperbrick-trial/README.md:77-80`).
3. **Switching it on is not free.** `kernel/sched/rt.c` has 23 `#ifdef CONFIG_RT_GROUP_SCHED` blocks at
   `baa585f67e0e` (15 in sdm670) and `kernel/sched/core.c` has many more (`core.c:698`, `:5020`, `:8571`, `:8612`,
   `:9056`, `:9286`, `:10096`, `:10146` …). That is newly compiled C in the exact subsystem the series rewrites
   hardest — 14 of the 150 conflicts are in `kernel/sched`, per the trial README.
4. **Behaviour.** Its own help text (`init/Kconfig:1299-1300`) says it "will also make it impossible to schedule
   realtime tasks for non-root users until you allocate realtime bandwidth for them". Android does not ask for that.

**To go the other way:** delete the `# CONFIG_RT_GROUP_SCHED is not set` line and keep `gts4lv_defconfig:28`.
Expect `kernel/sched/rt.c` and `kernel/sched/core.c` to need build fixes.

`SCHED_TUNE` is easier: `init/Kconfig:1521` is `depends on !UCLAMP_TASK`, so `UCLAMP_TASK=y` makes it unreachable by
Kconfig on its own. `gts4lv_defconfig:34` and `gts4lv_eur:167` become dead lines; I still wrote the explicit
`is not set` so the defconfig stops asserting something untrue. `USER_NS` has no dependencies at all
(`init/Kconfig:1476-1478`, `default n`), is already `n` everywhere, and the line documents intent only.

**Companion that dies with `SCHED_TUNE`:** `CGROUP_SCHEDTUNE` `depends on SCHED_TUNE`
(`init/Kconfig:1182-1184`), so `gts4lv_defconfig:24` / `gts4lv_eur:145` (`=y`) become dead too. Also
`kernel/sched/Makefile` @ `baa585f67e0e` has `obj-$(CONFIG_SCHED_TUNE) += tune.o`, which stops being built — that is
a source change, not just a config change. I wrote the explicit line (fragment section 4.4) for the same reason.

confidence: medium — the Kconfig facts, the Exy defconfig contents and the trial README are all certain (quoted
above); items 3 and 4 are judgement about build risk and Android behaviour that I cannot verify from the trees.

---

## `DEBUG_INFO_BTF` needs pahole in the kernel build environment

As the task asks, stated plainly:

- **`pahole` must be on `PATH` in the kernel build environment, version ≥ v1.13.**
  `scripts/link-vmlinux.sh:209` errors out with "BTF: ${1}: pahole (${PAHOLE}) is not available", and `:214` is
  `if [ "${pahole_ver}" -lt "113" ]; then ... need at least v1.13` — both @ `baa585f67e0e`.
  `Makefile:366` @ `baa585f67e0e` is `PAHOLE = pahole`, i.e. **plain `pahole` from `PATH`**, not a pinned copy. On
  Android build hosts `pahole` is often absent or ancient, and this is a *link* failure, i.e. it looks like a kernel
  bug rather than a config problem. From v1.24 the script adds `--skip_encoding_btf_enum64` (`:218-219`).
- **It also builds a host tool that does not exist in sdm670.** `Makefile:1239-1249` @ `baa585f67e0e` builds
  `tools/bpf/resolve_btfids/` under `ifdef CONFIG_DEBUG_INFO_BTF`. `tools/bpf/resolve_btfids/` (Makefile + `main.c`)
  is absent from `a30605a54f3b` and arrives with series commit `d7b603054c46` "BACKPORT: bpf: Add resolve_btfids
  host tool".
- **`DEBUG_INFO_BTF_MODULES` switches itself on.** `lib/Kconfig.debug:185-188` @ `baa585f67e0e` is `default y`,
  `depends on DEBUG_INFO_BTF && MODULES`. It runs pahole on **every** `.ko` and its help text asks for
  **pahole 1.19 or later** (`:193`) — a higher bar than vmlinux itself. If module BTF generation fails, uncomment
  `# CONFIG_DEBUG_INFO_BTF_MODULES is not set` (fragment section 5).

Do not use `# CONFIG_DEBUG_INFO_BTF is not set` as the first answer (it is in fragment section 5 as the last
resort): without vmlinux BTF, `bpfloader` on Android 16 has nothing to work with. Fix the host tool.

confidence: high — read from `scripts/link-vmlinux.sh:205-224`, `Makefile:366,1239-1249` and `lib/Kconfig.debug:177-193`
@ `baa585f67e0e`.

---

## What changed relative to round 1

Round 1 is `origin/agent/K6:analysis/defconfig/`. Kept: all 12 of its findings that still hold, its dependency
closure for the 12, its `UNICODE` blocker, its `BPF_LSM` blocker, its `DEBUG_INFO_BTF` pahole note. Corrected or added:

| # | change | why |
|---|---|---|
| 1 | **Added `CONFIG_UPROBES=y`.** Round 1 called it optional; it is not. | `config UPROBES` is `def_bool n` with **no** `depends on KPROBES` in `arch/Kconfig:100` of **both** trees, so `KPROBES=y` does not bring it. `2d6869d3a4ce` adds `arch/arm64/kernel/probes/uprobes.c` (216 lines), the `obj-$(CONFIG_UPROBES) += uprobes.o` Makefile entry and the `arch/arm64/kernel/signal.c` hook — all dead without it. Its prerequisite `ARCH_SUPPORTS_UPROBES` (`arch/arm64/Kconfig:248`, `def_bool y`) is also new with that commit. Android 16 `bpfloader` uses uprobes. |
| 2 | **Added `CONFIG_XDP_SOCKETS=y` and `CONFIG_XDP_SOCKETS_DIAG=y`** (14 turn-on list, 15 turn-on lines). | `net/xdp/Kconfig:2` and `:12` @ `baa585f67e0e`. Round 1 listed them as "outside my 12" and left them out. Verified fully plumbed: `net/Makefile:16` `obj-$(CONFIG_XDP_SOCKETS) += xdp/`, `net/xdp/Makefile:4` for the diag object. Deps are just `BPF_SYSCALL` and `XDP_SOCKETS`, both already covered. |
| 3 | **Added all 3 turn-off lines, uncommented** — including `RT_GROUP_SCHED`. | Round 1 left them commented out, so the fragment did not actually turn anything off. `gts4lv_defconfig:28` and `:34` say `=y` for two of them; appending the later `is not set` lines is what overrides them. Full reasoning above. |
| 4 | **Added `CONFIG_BLK_CGROUP=y`.** | Round 1 only inspected `gts4lv_defconfig`, where `BLK_CGROUP=y` is at `:27`, so it classified the dep as satisfied. `gts4lv_eur_open_defconfig:151` and `gts4lvwifi_eur_open_defconfig:151` both say `# CONFIG_BLK_CGROUP is not set`, so `CFQ_GROUP_IOSCHED` would be dropped on those two files. The task says check all four. |
| 5 | **Corrected `PERF_EVENTS`.** | Round 1: "NOT in gts4lv_defconfig; default is only `y if PROFILING`". True as a statement about the line, but it implied the dep was missing. `gts4lv_defconfig:46` has `CONFIG_PROFILING=y`, so `PERF_EVENTS` is already `=y` by default (`init/Kconfig:2065`). Kept in the fragment anyway, as insurance — with the reasoning corrected. |
| 6 | **Reversed the WALT advice.** Round 1: "if the scheduler fails to build with `FAIR_GROUP_SCHED=y && SCHED_WALT=y`, the fix is `# CONFIG_FAIR_GROUP_SCHED is not set`". | Wrong. `SCHED_WALT` `depends on FAIR_GROUP_SCHED` at `baa585f67e0e:init/Kconfig:405`, so that fix switches WALT **off**. And it revealed the bigger point: `CGROUP_SCHED=y` is mandatory to keep `SCHED_WALT=y`, not merely a side effect. See Blocker 3. |
| 7 | **Added `CONFIG_MMU=y` to the re-stated deps, and corrected its location.** | It is the `depends on` of both `USERFAULTFD` (`init/Kconfig:2011`) and `ANDROID_BINDER_IPC` (`drivers/android/Kconfig:12`). It is per-arch, not in `init/Kconfig`: `arch/arm64/Kconfig:128` @ `baa585f67e0e`, `def_bool y`. |
| 8 | **Added `CONFIG_NET_CLS_ACT`'s Kconfig citation** (`net/sched/Kconfig:605`) and `KALLSYMS_ALL`/`DEBUG_KERNEL` note. | Round 1 claimed adding `KALLSYMS` makes the existing `CONFIG_KALLSYMS_ALL=y` (`gts4lv_defconfig:41`) effective. It also needs `DEBUG_KERNEL` (`init/Kconfig:1797`), which is absent from `gts4lv_defconfig` and has no default (`lib/Kconfig.debug:424`). So that line was already dead before this fragment. Pre-existing, unrelated to the option list, but worth knowing. |
| 9 | **Counts: 12 → 14 turn-on options; 28 → 33 `=y` lines; 0 → 3 turn-off lines.** | The spec's option list grew. |
| 10 | Added the `exynos9810-starlte_defconfig` comparison. | It is the defconfig the option list was derived from, so it is the best available evidence for what "turn off" means and for which deps the author considered necessary. It also settles the `PERF_EVENTS` question: it has `CONFIG_PROFILING=y` (`:47`) and no `PERF_EVENTS` line, exactly like sdm670. |

`DEBUG_INFO_BTF` is the one symbol that appears twice uncommented in the fragment: `CONFIG_DEBUG_INFO_BTF=y` in
section 1 and `# CONFIG_DEBUG_INFO_BTF is not set` in section 5. That is deliberate — section 5 is the documented
escape hatch, and if the lead uncomments it they must delete the section 1 line, because the section 5 one comes
later and would win.

---

## Which defconfig to apply this to

Any of the four. The two small files differ in three unrelated lines and the two `eur_open` files differ in the same
three options, so every line in this fragment is identical across both pairs (verified with `diff`). Note that the
`eur_open` files are full `.config` dumps that say "DO NOT EDIT" — if the build system does not use them, only
`gts4lv_defconfig` and `gts4lvwifi_defconfig` matter. Both pairs need the fragment: `KPROBES`, `PSI`,
`USERFAULTFD` and `NET_ACT_BPF` are explicitly `is not set` in the `eur_open` files, and `BLK_CGROUP` is off there too.

confidence: high — `diff` on both pairs, and every symbol grepped in all four files.

---

## Self-check

All commands below were run in `~/work/wt/K6-r2` and `~/work/k670`.

**The 14 turn-on options each appear exactly once as `CONFIG_<X>=y`:**
```
$ for o in ANDROID_BINDERFS BPF_LSM CFQ_GROUP_IOSCHED DEBUG_INFO_BTF FUSE_BPF KPROBES NET_ACT_BPF PSI \
           UCLAMP_TASK UCLAMP_TASK_GROUP UNICODE USERFAULTFD XDP_SOCKETS XDP_SOCKETS_DIAG; do \
           printf '%-22s %s\n' "$o" "$(grep -c "^CONFIG_$o=y$" analysis/defconfig/gts4lv-23.2.fragment)"; done
ANDROID_BINDERFS       1
BPF_LSM                1
CFQ_GROUP_IOSCHED      1
DEBUG_INFO_BTF         1
FUSE_BPF               1
KPROBES                1
NET_ACT_BPF            1
PSI                    1
UCLAMP_TASK            1
UCLAMP_TASK_GROUP      1
UNICODE                1
USERFAULTFD            1
XDP_SOCKETS            1
XDP_SOCKETS_DIAG       1
```

**The 3 turn-off options each appear exactly once as `# CONFIG_<X> is not set`:**
```
$ for o in USER_NS RT_GROUP_SCHED SCHED_TUNE; do \
           printf '%-22s %s\n' "$o" "$(grep -c "^# CONFIG_$o is not set$" analysis/defconfig/gts4lv-23.2.fragment)"; done
USER_NS                1
RT_GROUP_SCHED         1
SCHED_TUNE             1
$ printf '%-22s %s\n' UPROBES "$(grep -c '^CONFIG_UPROBES=y$' analysis/defconfig/gts4lv-23.2.fragment)"
UPROBES                1
```

**Counts:**
```
$ grep -c '^CONFIG_[A-Z0-9_]*=y$' analysis/defconfig/gts4lv-23.2.fragment
33
$ grep -c '^# CONFIG_[A-Z0-9_]* is not set$' analysis/defconfig/gts4lv-23.2.fragment
6
$ wc -l analysis/defconfig/gts4lv-23.2.fragment
474
```
The 6 "is not set" lines are the 3 requested ones, the `CGROUP_SCHEDTUNE` companion that dies with `SCHED_TUNE`,
and the two documented escape hatches in section 5 (`DEBUG_INFO_BTF_MODULES`, `DEBUG_INFO_BTF`). Only the first
three are load-bearing.

33 = 14 requested + 1 (`UPROBES`) + 8 dependencies not explicit today + 10 already-satisfied re-stated.
Of the 8, **2 are mandatory** (`BPF_JIT`, `CGROUP_SCHED`), **1 is needed only for the `eur_open` files**
(`BLK_CGROUP`), and 5 are defensive (`PERF_EVENTS`, `KPROBE_EVENTS`, `BPF_EVENTS`, `KALLSYMS`, `IOSCHED_CFQ`).

**Every enabled line was verified against a real Kconfig entry in the series head.** `CGROUP_SCHED` and `MODULES`
are `menuconfig`, hence the second grep:
```
$ for x in $(grep -o '^CONFIG_[A-Z0-9_]*=' analysis/defconfig/gts4lv-23.2.fragment | sed 's/CONFIG_//;s/=//' | sort -u); do \
    hit=$(git -C ~/work/k670 grep -n "^config $x\$" baa585f67e0e -- '*Kconfig*' | head -1); \
    [ -z "$hit" ] && hit=$(git -C ~/work/k670 grep -n "^menuconfig $x\$" baa585f67e0e -- '*Kconfig*' | head -1); \
    printf '%-26s %s\n' "$x" "${hit:-*** NONE ***}"; done
ANDROID                    baa585f67e0e:drivers/android/Kconfig:3:config ANDROID
ANDROID_BINDERFS           baa585f67e0e:drivers/android/Kconfig:22:config ANDROID_BINDERFS
ANDROID_BINDER_IPC         baa585f67e0e:drivers/android/Kconfig:10:config ANDROID_BINDER_IPC
BLK_CGROUP                 baa585f67e0e:init/Kconfig:1234:config BLK_CGROUP
BPF_EVENTS                 baa585f67e0e:kernel/trace/Kconfig:480:config BPF_EVENTS
BPF_JIT                    baa585f67e0e:net/Kconfig:297:config BPF_JIT
BPF_LSM                    baa585f67e0e:init/Kconfig:1950:config BPF_LSM
BPF_SYSCALL                baa585f67e0e:init/Kconfig:1938:config BPF_SYSCALL
CFQ_GROUP_IOSCHED          baa585f67e0e:block/Kconfig.iosched:35:config CFQ_GROUP_IOSCHED
CGROUP_SCHED               baa585f67e0e:init/Kconfig:1269:menuconfig CGROUP_SCHED
CPU_FREQ_GOV_SCHEDUTIL     baa585f67e0e:drivers/cpufreq/Kconfig:255:config CPU_FREQ_GOV_SCHEDUTIL
DEBUG_INFO                 baa585f67e0e:lib/Kconfig.debug:127:config DEBUG_INFO
DEBUG_INFO_BTF             baa585f67e0e:lib/Kconfig.debug:177:config DEBUG_INFO_BTF
FUSE_BPF                   baa585f67e0e:fs/fuse/Kconfig:20:config FUSE_BPF
FUSE_FS                    baa585f67e0e:fs/fuse/Kconfig:1:config FUSE_FS
IOSCHED_CFQ                baa585f67e0e:block/Kconfig.iosched:24:config IOSCHED_CFQ
KALLSYMS                   baa585f67e0e:init/Kconfig:1787:config KALLSYMS
KPROBE_EVENTS              baa585f67e0e:kernel/trace/Kconfig:445:config KPROBE_EVENTS
KPROBES                    baa585f67e0e:arch/Kconfig:43:config KPROBES
MMU                        baa585f67e0e:arch/arm64/Kconfig:128:config MMU
MODULES                    baa585f67e0e:init/Kconfig:2285:menuconfig MODULES
NET_ACT_BPF                baa585f67e0e:net/sched/Kconfig:728:config NET_ACT_BPF
NET_CLS_ACT                baa585f67e0e:net/sched/Kconfig:605:config NET_CLS_ACT
PERF_EVENTS                baa585f67e0e:init/Kconfig:2063:config PERF_EVENTS
PSI                        baa585f67e0e:init/Kconfig:494:config PSI
SECURITY                   baa585f67e0e:security/Kconfig:30:config SECURITY
UCLAMP_TASK                baa585f67e0e:init/Kconfig:972:config UCLAMP_TASK
UCLAMP_TASK_GROUP          baa585f67e0e:init/Kconfig:1307:config UCLAMP_TASK_GROUP
UNICODE                    baa585f67e0e:fs/unicode/Kconfig:4:config UNICODE
UPROBES                    baa585f67e0e:arch/Kconfig:100:config UPROBES
USERFAULTFD                baa585f67e0e:init/Kconfig:2009:config USERFAULTFD
XDP_SOCKETS                baa585f67e0e:net/xdp/Kconfig:2:config XDP_SOCKETS
XDP_SOCKETS_DIAG           baa585f67e0e:net/xdp/Kconfig:12:config XDP_SOCKETS_DIAG
```
No `*** NONE ***`. The README table above has a row for **all 17 requested options** plus `UPROBES`.

**The three blockers are each called out in the fragment as comments**, in a `BLOCKER n of 3` block at the top
(UNICODE, BPF_LSM, CGROUP_SCHED), each also repeated inline at the relevant option.

**Line-number citations for the two trees, side by side** (all `git grep -n "^config X$"`):
```
$ for x in ANDROID_BINDERFS BPF_LSM CFQ_GROUP_IOSCHED DEBUG_INFO_BTF FUSE_BPF KPROBES NET_ACT_BPF PSI \
           UCLAMP_TASK UCLAMP_TASK_GROUP UNICODE USERFAULTFD XDP_SOCKETS XDP_SOCKETS_DIAG \
           USER_NS RT_GROUP_SCHED SCHED_TUNE UPROBES; do
  h=$(git -C ~/work/k670 grep -n "^config $x\$" baa585f67e0e -- '*Kconfig*' | head -1)
  s=$(git -C ~/work/k670 grep -n "^config $x\$" a30605a54f3b | head -1)
  printf '%-18s head=%-8s sdm670=%-8s\n' "$x" "$([ -n "$h" ] && echo yes || echo NO)" "$([ -n "$s" ] && echo yes || echo NO)"
done
ANDROID_BINDERFS     head=yes    sdm670=NO
BPF_LSM              head=yes    sdm670=NO
CFQ_GROUP_IOSCHED    head=yes    sdm670=yes
DEBUG_INFO_BTF       head=yes    sdm670=NO
FUSE_BPF             head=yes    sdm670=NO
KPROBES              head=yes    sdm670=yes
NET_ACT_BPF          head=yes    sdm670=yes
PSI                  head=yes    sdm670=yes
UCLAMP_TASK          head=yes    sdm670=NO
UCLAMP_TASK_GROUP    head=yes    sdm670=NO
UNICODE              head=yes    sdm670=NO
USERFAULTFD          head=yes    sdm670=yes
XDP_SOCKETS          head=yes    sdm670=NO
XDP_SOCKETS_DIAG     head=yes    sdm670=NO
USER_NS              head=yes    sdm670=yes
RT_GROUP_SCHED       head=yes    sdm670=yes
SCHED_TUNE           head=yes    sdm670=yes
UPROBES              head=yes    sdm670=yes
```

**The four defconfigs agree on every line that matters** (`diff`):
```
$ diff <(git -C ... show a30605a54f3b:arch/arm64/configs/gts4lv_defconfig) \
       <(git -C ... show a30605a54f3b:arch/arm64/configs/gts4lvwifi_defconfig) | wc -l
8
$ diff <(git -C ... show a30605a54f3b:arch/arm64/configs/gts4lv_eur_open_defconfig) \
       <(git -C ... show a30605a54f3b:arch/arm64/configs/gts4lvwifi_eur_open_defconfig) | wc -l
14
```
Both diffs cover only the three model-specific options (`SEC_GTS4LV_EUR_PROJECT` vs
`SEC_GTS4LVWIFI_EUR_PROJECT`, `SENSORS_SX9330`, `MSM_VIBRATOR`) plus diff headers.

**No duplicate symbol** except the deliberate `DEBUG_INFO_BTF` pair (section 1 `=y` vs section 5 escape hatch):
```
$ grep -oE '^#? ?CONFIG_[A-Z0-9_]+' analysis/defconfig/gts4lv-23.2.fragment | sed 's/^# //' | sort | uniq -d
CONFIG_DEBUG_INFO_BTF
```

### How to apply

```bash
# in the kernel working tree, AFTER the series has been cherry-picked
cat analysis/defconfig/gts4lv-23.2.fragment >> arch/arm64/configs/gts4lv_defconfig
make ARCH=arm64 gts4lv_defconfig          # then: make olddefconfig

# 1. nothing was silently dropped - every line must still be =y
grep -E 'ANDROID_BINDERFS|BPF_LSM|CFQ_GROUP_IOSCHED|DEBUG_INFO_BTF|FUSE_BPF|KPROBES|NET_ACT_BPF|PSI|UCLAMP|UNICODE|USERFAULTFD|XDP_SOCKETS|UPROBES' .config
# 2. the three turn-offs really are n
grep -E 'CONFIG_(USER_NS|RT_GROUP_SCHED|SCHED_TUNE)=' .config
# 3. the trap: SCHED_WALT must still be built
grep -E 'CONFIG_(SCHED_WALT|FAIR_GROUP_SCHED|CGROUP_SCHED|CFS_BANDWIDTH)=' .config
# 4. optional: was the kernel module list produced?
grep -E 'CONFIG_(MODULES|MODULE_UNLOAD)=' .config
```
Step 3 is the one that catches Blocker 3: if `CONFIG_SCHED_WALT` is missing from `.config`, the merged Kconfig has
the Exy form and `CGROUP_SCHED` did not stick — put `CONFIG_CGROUP_SCHED=y` back and rebuild the config.

---

## Problems

None. Two deliberate deviations from the task text, both stated above:

1. I added **`CONFIG_UPROBES=y`**, which is not on the 17-option list. The task prompt instructed me to add it
   (another agent established `arch/Kconfig:100` is `def_bool n` independent of `KPROBES`, and that `2d6869d3a4ce`'s
   code is dead without it); I re-verified both from the trees. It is marked as a correction, not as a 15th
   requested option, so the count of requested options stays at 14.
2. I added the **10 already-satisfied dependencies** as real `CONFIG_*=y` lines rather than only describing them.
   They are all `=y` today, so re-stating them changes nothing; it makes the fragment applicable to all four
   defconfigs without the lead re-deriving the closure. If the lead prefers a minimal fragment, deleting fragment
   section 3 leaves a working (if less self-contained) file.

Not verified, stated as such: I did not build anything and did not cherry-pick, so the **compile-time** outcome of
`FAIR_GROUP_SCHED=y && SCHED_WALT=y` and of `2d6869d3a4ce`'s `thread_info.h` hunk (K4c's territory) is inferred
from Kconfig, not observed.
