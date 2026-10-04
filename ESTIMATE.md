# Time estimate: LineageOS 23.2 on the Galaxy Tab S5e

## Remaining work (updated 2026-10-04: research, cherry-pick and its review are done)

| Step | Low | Expected | High | Notes |
|---|---|---|---|---|
| ~~Round 3, P1 cherry-pick, P1-R/P2~~ | | done | | Took about 1 day instead of the 3.5–5 estimated |
| P3 known fixes + defconfig (free) | 0.5 d | 0.5 d | 1 d | Six specified items |
| P4 build loop to `Image.gz-dtb` (free, strong for escalations) | 3 d | 5 d | 9 d | Unknown tail: the API audit covered 2% of changed headers |
| P5 device tree + review | 0.5 d | 0.5 d | 1 d | Now one commit; runs in parallel with P3/P4 |
| ROM sync + build + build fixes (owner's machine) | 1 d | 2 d | 4 d | |
| First boot and debugging (owner + tablet) | 3 d | 7 d | 15 d | Still the most uncertain step |
| Testing, 24 h soak, LTE (owner + tablet) | 3 d | 4 d | 6 d | |
| **Total left, wall-clock** | **≈ 10.5 d** | **≈ 18.5 d** | **≈ 35 d** | was 14.5 / 24.5 / 46 on 2026-10-03 |

About **3½–4 weeks wall-clock** (range 2–7). The next ~6 days are agents (P3, P4, P5) plus a few review sessions.
The rest needs the owner, the build machine and the tablet.

---

## Original estimate (before helper research)

Updated 2026-10-03. This replaces the rough figures in earlier documents. The
estimate is built bottom-up from measurements, listed in the next section.

## What was measured

| Input | Value | Source |
|---|---|---|
| Kernel series to port | ExyHyperBrick `lineage-22.2..lineage-23.2`, 2,599 commits | [trial](analysis/exyhyperbrick-trial/README.md) |
| Commits that merge cleanly onto sdm670 | 2,335 | same |
| Conflicting commits | 150 (238 conflict blocks, about 7,700 conflicting lines) | [`conflict_detail.tsv`](analysis/exyhyperbrick-trial/conflict_detail.tsv) |
| Conflict size classes | 57 trivial (≤10 lines), 58 moderate (≤60), 28 large, 7 modify/delete | same |
| Conflicts by need | **84 required** (BPF, networking, syscalls, core prerequisites), 46 optional (mm/sched/fuse-bpf/binder freezer), 20 skip (Exynos/f2fs/ext4-specific) | same, `group` column |
| Required conflicts by size | 37 trivial, 35 moderate, 12 large | same |
| Baseline kernel build | Builds cleanly; 12 min on 4 cores (≈5 min on a typical desktop) | [build test](analysis/build-test/README.md) |
| Port tree with blind conflict resolution | Fails at the first compile step. Shows missing prerequisites and lost sdm670 fixes | same |
| Device-tree changes | First four done (0001–0004, in the device fork). More expected from tasks R1–R6 | [AGENT-TASKS.md](AGENT-TASKS.md) |

## Effort model

The per-item times are typical for someone experienced in kernel work who has never seen this tree.

| Item | Rate | Required path | Optional extras |
|---|---|---|---|
| Trivial conflict | 10 min | 37 × 10 min ≈ 6 h | 18 × 10 min ≈ 3 h |
| Moderate conflict | 45 min | 35 × 45 min ≈ 26 h | 20 × 45 min ≈ 15 h |
| Large conflict | 3 h | 12 × 3 h ≈ 36 h | 5 × 3 h ≈ 15 h |
| **Conflicts total** | | **≈ 68 h** | **≈ 33 h** |

## Estimate by phase (one person, full-time days of about 6 productive hours)

| # | Phase | Low | Expected | High | Notes |
|---|---|---|---|---|---|
| 0 | Set up: sync LineageOS 23.2 (~150 GB), first ROM build (forks are done) | 1 d | 2 d | 3 d | Depends on download speed and machine |
| 1 | Cherry-pick the series, skipping the 114 Exynos-only and 20 skip-group commits | 0.5 d | 1 d | 1 d | Mostly mechanical (`git cherry-pick -x`) |
| 2 | Resolve the 84 required conflicts | 8 d | 11 d | 15 d | ≈68 h of conflict work, plus re-reading upstream commits |
| 3 | Missing prerequisites and build fixes, until `Image.gz-dtb` links | 3 d | 6 d | 10 d | The build test hit prerequisites in the first 10 s. Qualcomm code (`net/rmnet_data`, IPA, qcacld, cnss) uses changed networking APIs (task K5 maps it): 150 sdm670 files outside the shared upstream tree use `sk_buff` |
| 4 | ROM side: sepolicy neverallows, blob linkage, VINTF/FCM | 2 d | 3 d | 5 d | 0001–0004 done; tasks R1–R6 list the rest |
| 5 | First boot and debugging (kernel panics, netd/bpfloader, HAL crashes) | 3 d | 7 d | 15 d | **The most uncertain phase.** Needs `pstore/last_kmsg` or UART logs |
| 6 | Testing: BPF selftests, `bpf_existence_test`, networking checks, 24 h soak, LTE model | 3 d | 4 d | 6 d | |
| | **Total (required path)** | **≈ 21 d** | **≈ 34 d** | **≈ 55 d** | |
| 7 | *Optional:* the 46 optional conflicts (uclamp, binder freezer, fuse-bpf, process_mrelease, …) | 4 d | 6 d | 9 d | Gives better power and memory behaviour. Not needed to boot |

## In calendar time

| Who | Expected | Range |
|---|---|---|
| One experienced developer, full-time | **about 7 weeks** | 4–11 weeks |
| One experienced developer, ~10 h/week (hobby) | about 5 months | 3–9 months |
| Someone new to kernel porting | add 50–100% | |

**Faster unofficial route (Track B):** Doze-off/fuck-bpf userspace patches on the
current 4.9 kernel, plus phases 0, 4, 5 and 6 in a lighter form, gives a first bootable
23.2 in about **1–2 weeks** full-time. You get weaker network restrictions and
accounting, and no official path. See [KERNEL-BACKPORT-PLAN.md](KERNEL-BACKPORT-PLAN.md).

## What could change the estimate

- **Shorter:** krazey (ExyHyperBrick) or another S9 developer helps with conflicts; a second
  Samsung Qualcomm 4.9 device gets the same series first; most "moderate" conflicts turn out to
  be context-only.
- **Longer:** hidden dependencies on the Exynos base tree (1,079 generic commits in it are
  missing from sdm670, though most are filesystem updates); Qualcomm networking drivers
  breaking under the new `sk_buff`/netdevice code; a boot hang without serial logs; the LTE
  RIL failing the FCM level-6 check.
- **Not included:** waiting on review in upstream LineageOS Gerrit, or maintaining 24.0 later.
