<!-- task: K2d-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# K2d-2: conflict briefs, batch `optional` / moderate + modify/delete
## Summary
8 commits, 8 briefs, 0 HUMAN. 2 of the 8 are modify/delete commits (3 files + 1 file); the other 6 are moderate
content conflicts. Verdicts: 1 DROP, 6 MERGE, 1 MERGE-that-includes-accepting-a-deletion, 0 PREREQ, 0 HUMAN.

**Read this first, in this order:**

1. **`d5f2acfd8dc2` is a DROP and it is the one to check.** sdm670 already has that exact upstream change
   (`29ec90660d68`) as its own commit `3de7f8451928`; proof is at `file:line` in the brief. A wrong DROP is the worst
   outcome in this project, so please re-read that brief before acting on it.
2. **`0c6f8a9a50ad` (wakeup sysfs stats) breaks 3 sdm670-only files** that no commit in the 2599-commit series ever
   fixes (`drivers/char/diag/diagchar_core.c:4148`, `drivers/tty/serial/msm_geni_serial.c:2793`,
   `net/ipc_router/ipc_router_core.c:1384` - all three enabled by the gts4lv defconfigs). One-line fixes are in the
   brief. It is group `optional`, so dropping it whole is also defensible.
3. **`8f50d9eb049e` (binder oneway spam) needs 3 hand edits**, and the auto-merge it produces is *wrong*: it would
   overflow the 32-bit `struct binder_buffer` bitfield (sdm670 already has `clear_on_free:1`, the Exy tree does not).
   `debug_id` must go 28 -> 27, and the Exynos-only `BINDER_SET_SYSTEM_SERVER_PID` / `system_server_pid` halves must
   be dropped.
4. **`c286cded153a` (BinderFS) is really required**, despite group `optional` - it is the only commit that creates
   `drivers/android/binderfs.c` and `/dev/binder-control`, and K6 already plans `CONFIG_ANDROID_BINDERFS`. Its one
   real conflict is `include/uapi/linux/android/Kbuild`, which must be **created, not deleted**; and sdm670's
   `include/uapi/linux/Kbuild` is missing `header-y += android/`, so the new file is inert until that line is added.

Method notes worth knowing before reading the briefs:

- Several isolated `merge-tree` conflicts are **stacked-replay artefacts**: the trial applied the commits on top of each
  other, so a hunk that conflicts against `a30605a54f3b` alone merges cleanly once an earlier series commit has already
  created the file. Confirmed for: `include/linux/set_memory.h` (from `2e71fb11d9a8`), `drivers/android/binder_internal.h`
  (from `5a82a1082d45`), `drivers/base/power/wakeup.c` (from `88a7f62f2d3f`), `kernel/power/wakelock.c` (from `d36231c0e786`),
  and 2 of the 3 blocks in `d5f2acfd8dc2`. Each is spelled out in the relevant brief. Do not "fix" those.
- `analysis/exyhyperbrick-trial/conflict_detail.tsv` line counts (`ours_lines`/`theirs_lines`) include leftover
  `<<<<<<<` markers from earlier conflicts, because the trial kept conflicted markers in its tree
  (`analysis/exyhyperbrick-trial/trial.py`, comment on line ~22). For `e9357b031a71` it says `ours_lines=16 theirs_lines=8`;
  the true block is 8 lines vs 0. Where it mattered I reconstructed the stacked file with `git merge-file` on the file
  blobs instead of trusting the isolated merge.
- Only 2 of my 8 commits conflict in a way that means "sdm670 deleted a file". The other 6 are ordinary content
  conflicts in generic files, and in every one of them sdm670's side was a *CAF/Samsung local addition* next to the
  series' change, never a deletion.

| commit | subject | resolution | confidence |
|---|---|---|---|
| `252eaf20e864` | PARTIAL: x86/mm/cpa: Add set_direct_map_*() functions | MERGE | high |
| `0c6f8a9a50ad` | BACKPORT: PM / wakeup: Show wakeup sources stats in sysfs | MERGE (accept deletion of 3 Exynos-only files) | high |
| `8f50d9eb049e` | BACKPORT: binder: report oneway spam to userspace | MERGE | high |
| `c286cded153a` | BACKPORT: binder: add BinderFS support for 4.9 | MERGE (create the deleted file) | high |
| `880ea49bde40` | UPSTREAM: hugetlb: add __mcopy_atomic_hugetlb for huge page UFFDIO_COPY | MERGE | high |
| `e9357b031a71` | UPSTREAM: userfaultfd: return ENOENT for incompatible copy VMAs | MERGE | high |
| `d5f2acfd8dc2` | UPSTREAM: userfaultfd: require writable shmem and hugetlb VMAs | DROP (already in sdm670 as `3de7f8451928`) | high |
| `62d6ffb0111f` | BACKPORT: userfaultfd/sysctl: add vm.unprivileged_userfaultfd | MERGE | high |

## modify/delete handling (2 of 8)
- `0c6f8a9a50ad` - `drivers/net/wireless/bcmdhd_101_16/dhd_linux_priv.h`, `drivers/rtc/rtc-s2mps17.c`,
  `drivers/rtc/rtc-s2mps18.c`. **sdm670 deleted (never had) them, the series modifies them.** Leaning: accept the
  deletion. They are Exynos silicon (Broadcom `bcmdhd` WiFi, Samsung S2MP[17/18] PMIC RTC) and sdm670 is a Qualcomm
  SDM670 board, so there is nothing to keep. The commit's change to them was purely the extra `wakeup_source_register()`
  argument. Nothing is lost; taking the merge-tree tree as-is would instead *add* Exynos driver files.
- `c286cded153a` - `include/uapi/linux/android/Kbuild`. **sdm670 deleted (predates) it, the series modifies it.**
  Leaning: take "theirs" and create the file. Generic, not Exynos-specific, and needed by Android 16 userspace
  (`linux/android/binderfs.h`). A second modify/delete in the same commit,
  `drivers/android/binder_internal.h`, is a false positive (provided by `5a82a1082d45`, CLEAN in the trial).
- Because the batch is `optional` (nice-to-have), I did not wave the drops through: each is argued from the SoC and the
  userspace, and the one DROP that is not an Exynos-only file is the one I would most expect a reviewer to challenge.

## Confidence
high overall: every finding cites a commit SHA or `file:line`, absence claims use at least two greps, and the one DROP
rests on an sdm670 commit carrying the same upstream SHA as the series commit.
## Problems
None
