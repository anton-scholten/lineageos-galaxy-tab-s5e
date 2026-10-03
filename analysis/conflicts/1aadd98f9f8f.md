<!-- task: K2b-4 | agent: Space Bunny Free | date: 2026-10-03 -->
# 1aadd98f9f8f: BACKPORT: hrtimer: Make the remote enqueue check unconditional
- Author / date: Anna-Maria Gleixner <anna-maria@linutronix.de>, 2017-12-21
- Upstream: 07a9a7eae86abb796468b225586086d7c4cb59fc
- Batch: K2b-4, size_class: moderate
## Conflicting files
- kernel/time/hrtimer.c
(include/linux/hrtimer.h is touched by the commit but merges cleanly - see below)
## Why it conflicts
merge-tree on its own: conflicts (2 blocks in kernel/time/hrtimer.c, trial counts ours_lines=3 / theirs_lines=10,
`analysis/exyhyperbrick-trial/conflict_detail.tsv`).
Command: `git -C ~/work/k670 merge-tree --write-tree --merge-base=1aadd98f9f8f^ a30605a54f3b 1aadd98f9f8f`
-> tree `2d8bc8aabe0e06fda8b0a2f30bc4ec99cf9b777c`, "CONFLICT (content): Merge conflict in kernel/time/hrtimer.c".

The commit has three parts:
1. `include/linux/hrtimer.h`: move `expires_next` out of `#ifdef CONFIG_HIGH_RES_TIMERS`. **Applies cleanly**
   (merge-tree: "Auto-merging include/linux/hrtimer.h"). Verified in the merged tree: `expires_next` ends up
   unguarded at `include/linux/hrtimer.h:197` @ tree 2d8bc8aa, while sdm670 has it guarded at
   `include/linux/hrtimer.h:191` @ a30605a54f3b.
2. `hrtimer_check_target()`: drop the `hrtimer_active`/`#ifdef` guards. **Applies cleanly** - merged result
   at `kernel/time/hrtimer.c:163-176` @ tree 2d8bc8aa (ours at `kernel/time/hrtimer.c:163-184` @ a30605a54f3b).
3. Delete the `hrtimer_init_hres()` helper and inline it in `hrtimers_prepare_cpu()`. **This is the conflict.**

- Block 1, kernel/time/hrtimer.c ~line 653 (merged tree 2d8bc8aa): ours = sdm670 keeps the Samsung 4.9 helper
  `hrtimer_init_hres()` (`kernel/time/hrtimer.c:657-666` @ a30605a54f3b), which sets `expires_next = KTIME_MAX`,
  `hang_detected = 0`, `hres_active = 0`, `next_timer = NULL`; theirs = series deletes the helper entirely
  (upstream removed it because the fields moved).
- Block 2, kernel/time/hrtimer.c ~line 1626 (merged tree 2d8bc8aa): ours = sdm670 calls `hrtimer_init_hres(cpu_base);`
  (`kernel/time/hrtimer.c:1629` @ a30605a54f3b) and has no `restore_pcpu_tick()`; theirs = series replaces it with
  `cpu_base->hres_active = 0; cpu_base->expires_next.tv64 = KTIME_MAX;` plus `#ifdef CONFIG_HIGH_RES_TIMERS`
  around `hang_detected`/`next_timer`, and its context line adds a `restore_pcpu_tick(cpu);` call.

Already in sdm670? **no.**
- Searched line 1: `git grep -n 'We do not migrate the timer when it is expiring' a30605a54f3b -- kernel/time/hrtimer.c`
  -> 0 hits (sdm670 still has the old comment "With HIGHRES=y we do not migrate the timer", `kernel/time/hrtimer.c:164`
  @ a30605a54f3b). So `hrtimer_check_target()` is still the old 4.9 form.
- Searched line 2: `git grep -n 'cpu_base->expires_next.tv64 = KTIME_MAX' a30605a54f3b -- kernel/time/hrtimer.c`
  -> 1 hit, `kernel/time/hrtimer.c:1353` @ a30605a54f3b, but that is inside `hrtimer_interrupt()` and is a different
  statement; it is **not** the new init in `hrtimers_prepare_cpu()`.
- Searched line 3: `git grep -c 'restore_pcpu_tick' a30605a54f3b -- kernel/time/hrtimer.c` -> rc=1, i.e. sdm670 has
  **no** `restore_pcpu_tick()` at all (it exists in the series tree at `kernel/time/tick-sched.c:1316` @
  1aadd98f9f8f^).
- Searched line 4: `include/linux/hrtimer.h:191` @ a30605a54f3b still has `expires_next` **inside**
  `#ifdef CONFIG_HIGH_RES_TIMERS`, so the header part of the commit is not in sdm670 either.

## Already in sdm670?

**Partly.** The two fields the commit writes already exist; the condition it changes does not.

Evidence at `a30605a54f3b`:
- `cpu_base->expires_next` — present, `include/linux/hrtimer.h:191`
- `cpu_base->hang_detected` — present, `include/linux/hrtimer.h:190`

Absent: the change to the remote-enqueue condition itself. Field presence is not change presence —
the commit's behaviour (making the check unconditional) is not in sdm670.

## Proposed resolution
MERGE: take **theirs** for both blocks, i.e. delete `hrtimer_init_hres()` and inline its body in `hrtimers_prepare_cpu()`.
Nothing is lost from ours, because:
- sdm670's `hrtimer_init_hres()` has exactly one caller, `hrtimers_prepare_cpu()` (`git grep -n hrtimer_init_hres
  a30605a54f3b` -> 3 hits, all in `kernel/time/hrtimer.c:660,735,1629`), and the series' inlined version also sets
  `cpu_base->hres_active = 0;`, which is the one field the Samsung helper adds (see block 2).
- The `#ifdef CONFIG_HIGH_RES_TIMERS`-only body `hrtimer_init_hres() { }` at `kernel/time/hrtimer.c:735` @ a30605a54f3b
  is deleted by theirs as well; nothing calls it.
**Do NOT copy `restore_pcpu_tick(cpu);`** from the theirs side of block 2 - that function does not exist in sdm670
(searched line 3 above); copying it is a link error.

⚠️ One portability note for the lead: the series' inlined `cpu_base->hres_active = 0;` sits **outside** any `#ifdef`
because in the series tree `hres_active` is unguarded. In sdm670 `hres_active` is a bitfield **inside**
`#ifdef CONFIG_HIGH_RES_TIMERS` (`include/linux/hrtimer.h:189` @ a30605a54f3b), so that line only compiles while
`CONFIG_HIGH_RES_TIMERS=y`. All four gts4lv defconfigs set it: `arch/arm64/configs/gts4lv_defconfig:4`,
`arch/arm64/configs/gts4lv_eur_open_defconfig:94`, `arch/arm64/configs/gts4lvwifi_defconfig:4`,
`arch/arm64/configs/gts4lvwifi_eur_open_defconfig:94` @ a30605a54f3b. Optional hardening: move the line inside the
`#ifdef` to match sdm670's struct layout.

Stacking: this is series position 2113; the hrtimer commits between it and `2c3ab8405d6a` (2117-2125) all replayed
CLEAN (`49fe68945d50`, `9fe1c0e173aa`, `babf7252e13f`, `1c767857110f`, `97c007529ec5`, `0e2338f22515`,
`22a309935838`, `1be8a780f6aa`, `755d2e7a1f01` - `analysis/exyhyperbrick-trial/results.tsv`).
## Confidence
high: merge-tree was run and both blocks read in the merged tree; the change is provably absent from sdm670 (three
independent greps); the only side of ours being deleted (`hres_active = 0`) is present in the theirs side verbatim,
and the helper has no other caller.
## Problems
None
