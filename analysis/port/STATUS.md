# Port status

Updated by the owner or the reviewing lead after each step, **not** by working agents. Steps and prompts: [RUNBOOK.md](../../RUNBOOK.md).

| Step | State | Branch / output | Notes |
|---|---|---|---|
| 0 Setup: tokens, branch protection, clones | ◐ | | SSH keys already have write access to both forks, so no `fork-token` is needed and none is stored on disk. Branch protection **not** set up by me — owner action. |
| 1 Round 3: K7 | ✅ | `agent/K7` | 6 bit collisions found, 4 previously unknown. 367 headers swept. |
| 1 Round 3: K8 | ✅ | `agent/K8` | Proved both "unbriefed conflicts" apply **cleanly** — the trial was right. |
| 1 Round 3: R7 | ✅ | `agent/R7` | Check never runs: our API level is 28, it needs ≥29. |
| 1 Round 3: R8 | ✅ | `agent/R8` | RIL caps at radio 1.4. Level 6 is unreachable for LTE. |
| 1 Round 3: R9 | ✅ | `agent/R9` | soundtrigger + `per_proxy_helper` both no-ops. |
| 1 🔍 Round 3 review + merge | ✅ | `main` | Reviewed and merged 2026-10-04 ([review-P1.md](review-P1.md)). |
| 2 P1 cherry-pick | ✅ | kernel `port/pick` @ `d73f07cf8b5c`, `agent/P1` | **2,438 picks. `check-pick.py` → `problems: 0`.** 60 hand-resolved, 23 full-review + 37 spot. `lineage-23.2` untouched. 27 `Needs-review:`. |
| 3 🔍 P1-R | ✅ | [review-P1.md](review-P1.md) | Passed, no rejections. All 6 K7 collisions already resolved in `port/pick`. |
| 3 P2 automerge triage | ✅ | `agent/P2-1`, `agent/P2-2` | 6 packets: **4 BENIGN, 2 SUSPECT — both SUSPECTs are real defects**, now confirmed by the lead. |
| 3 🔍 P2-R | ✅ | [review-P1.md](review-P1.md) | F1, F2 confirmed → P3 items 4–5. F3 left as is. |
| 4 P3 known fixes + defconfig | ☐ **next** | kernel `port/pick`, `agent/P3` | 6 items (AGENT-TASKS §6c P3, rewritten 2026-10-04). Can start now. |
| 5 P4 build loop | ✅ | kernel `port/pick` @ `801f3f20e54a`, `agent/P4` @ `89ef1fa` | **BOTH defconfigs link `Image.gz-dtb`.** 14 commits, all `Fix-by:`. `problems: 0`, `fix commits: 20`. Nothing escalated. |
| 5 🔍 P4-R | ☐ | `review-P4.md` | **Now the highest-value review left**: 5 commits carry `Needs-review:`. Lead has pre-verified all 5 mechanically; the open questions are the `vfs_getattr` and `fuse_req_init_context` backport alternatives. |
| 6 P5 device-tree commits | ☐ **can start** | device `port/dt`, `agent/P5` | Now 1 commit (audio policy XML) + a log of the skipped items. `target-level` stays 5. |
| 6 🔍 P5-R | ☐ | `review-P5.md` | Strong-model step. **Worth it for one thing only:** R6's claim that the parser splits on whitespace is unverified — `frameworks/av` isn't cloned. P5 logged that as medium confidence, the space-separated form itself high. |
| 7 Fast-forward both `lineage-23.2` | ☐ | | Only after every 🔍 review passes. Never force-push. |
| 8 ROM build | ☐ | | Owner's machine. Use `brunch lineage_gts4lvwifi`, **not** a bare `m`. |
| 8 First boot | ☐ | | Collect logs after **every** crash — pstore keeps only the newest. |
| 8 Tests + 24 h soak | ☐ | | Then the LTE model. |

States: ☐ not started · ◐ running · ✅ done · ⛔ blocked (say why in Notes).

## Three confirmed defects in `port/pick`

Found by P2 (2 of 3) plus an ad-hoc sweep of all 2,438 picks (1 of 3). Full detail, with verified line numbers
and the counterintuitive fix for F1, in [`duplicate-picks.md`](duplicate-picks.md).

| | file | what | now | fix |
|---|---|---|---|---|
| **F1** | `include/uapi/drm/drm_mode.h` | 7 macros duplicated; pick's copy at **92–104** (`0x0F<<19`) vs base's at 106–124 (`0x0F<<24`) | benign — later wins — but the `<<19` copy is the only thing preventing a **bit-22 collision** with `SUPPORTS_YUV420` at line 90 | delete **92–104**. Deleting 106–124 drops `_64_27`/`_256_135` *and* causes the collision. |
| **F2** | `fs/userfaultfd.c` | 11-line `VM_MAYWRITE` check duplicated at `:1401` and `:1427` | benign, idempotent — dead code | delete `:1391–1403` |
| **F3** | `arch/parisc/include/uapi/asm/socket.h` | `SO_PEERGROUPS` at `:98` and `:100` — the series carries the same upstream patch twice, under two SHAs | benign — legal C, and parisc isn't built for arm64 | cosmetic; P1-R's call |

**Two root-cause classes:** (A) the change was already in the sdm670 base and the pick landed a duplicate
anyway — F1, F2; (B) the series carries one upstream patch under two SHAs so the second pick is a pure
duplicate — F3. Neither is visible to `check-pick.py`'s `clean` bucket, which gets no human review.

**What bounds the risk:** 2 of the 3 were found in P2's 6-packet `automerge` bucket. Sweeping the
**2,372-commit `clean` bucket that nobody ever reviewed turned up exactly one finding**, and it is in unbuilt
`arch/parisc` and is legal C. The unreviewed bucket is in better shape than the `ec3b287a8a17` anecdote
suggested. This should inform how much of the 37-commit spot-check pool really needs reading.

## Open items carried into the next step

**P1 escalated three things (decided 2026-10-04 in [review-P1.md](review-P1.md)):**

1. **`process_mrelease` is missing** — its three introducing commits were silently removed by
   `classify.py:35`'s `EAS` regex matching inside `proc-EAS-s`/`rel-EAS-e`. Same defect class as the fuse-bpf
   pair, but larger. P1 could not verify the userspace fallback, so it escalated rather than decided. Porting
   it to 4.9 is expensive (no `mmap_lock` API; `rw_semaphore mmap_sem`).
   **Decided: defer.** lmkd should fall back without it; check `logcat -s lmkd` on first boot. The chain to pick later is in review-P1.md.
2. **Three confirmed duplicate-landing picks** (F1/F2/F3 above). F1 and F2 are one-block deletions; F1's
   target lines are load-bearing, so read [`duplicate-picks.md`](duplicate-picks.md) before touching it.
3. **Expect a whitespace-heavy diff at `1c225cfcb958`.** P1 introduced a `get_scan_count` tab drift, pinned
   it by tab-counting every commit touching `mm/vmscan.c` since the last push, and fixed it in the next
   commit because a rebase was forbidden. `git diff -w` there shows only the intended comment swap — but a
   reviewer skimming that commit will see noise.

**Two known landmines, deliberately not fixed:**

- **`classify.py` is unfixed on purpose.** Regenerating `conflict_detail.tsv` would change which *remaining*
  commits `pick-series.sh` skips, so it has to be fixed as one unit with a decision, not piecemeal.
- **A clean cherry-pick is not evidence of correctness.** P1 found `ec3b287a8a17` apply cleanly and silently
  duplicate `bpf_probe_read_str` because sdm670 already had it (it healed at `dddb8c0eafe8`). `check-pick.py`'s
  *clean* bucket gets no human review — which is why `pick-review/full/` and `spot/` exist.

**Round-3 agents corrected three round-2 conclusions** (the `target-level` decision, the soundtrigger block,
the radio bump). When a round-3 agent contradicts a round-2 verdict on this device, check it against a
shipping tree before acting on either. Details in [LEAD-SYNTHESIS.md §7.4](../../LEAD-SYNTHESIS.md).
