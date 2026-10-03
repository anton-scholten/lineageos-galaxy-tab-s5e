# Round 4: the kernel port (working files)

Specs: [AGENT-TASKS.md](../../AGENT-TASKS.md) §2.3 and §6c. Scripts: [`scripts/pick-series.sh`](../../scripts/pick-series.sh)
(cherry-picks in order, stops at each commit that needs a person, resumable) and [`scripts/check-pick.py`](../../scripts/check-pick.py)
(automatic checks plus review packets for the strong model).

| File | Who writes it | What |
|---|---|---|
| `full-review.txt` | lead | Commits whose resolution always gets a full strong-model review: the 12 large conflicts, the linked groups (`fs/userfaultfd.c`, `fs/fuse`, XDP rename) and the known breakers. `pick-series.sh` prints `review: FULL` for these, and for any conflict without a brief |
| `dropped.tsv` | P1 agent (and `pick-series.sh` for empty picks) | Every series commit deliberately not picked, with the reason. `pick-series.sh` never retries these |
| `P1-log.md`, `P4-log.md`, `P5-log.md` | free-model agents | One line per stop or fix, plus `## Blocked` / `## Escalated` |
| `automerge-triage-<n>.tsv` | P2 agents | BENIGN/SUSPECT verdict per "auto-merged but different" commit |
| `review-P1.md`, `review-P4.md`, `review-P5.md` | strong model | What was checked, what was rejected, what was fixed |

## Tested on 2026-10-03
Both scripts were run on a real clone of the kernel fork, with the full series, on a throwaway branch.

- `pick-series.sh` picks, stops at the first conflict, resumes after a resolution, records empty picks and DROPs, and prints the brief and review level.
- `check-pick.py` separates clean picks from hand-resolved ones. It also found a third kind: **commits git applies without a conflict whose
  result still differs from the original**. For example, `dff86fa1e78e` lost its 5 removed lines because sdm670 has that code somewhere else.
  These go to `automerge/` for triage (task P2).
- **Dry run over the whole series** (every conflict resolved mechanically by taking the series side, only to count stops):
  **83 stops** in 2,460 picks (the trial said 150), 2,373 clean picks, 4 apply-but-differ, 5 empty picks. Of the stops, 71 have a brief,
  25 are marked FULL review. By file: 74 content conflicts, 10 delete-type (`DU`), 1 add/add.
  The list is [`dry-run-stops.tsv`](dry-run-stops.tsv). 6 of the 12 no-brief stops are a `lib/zstd` chain that follows commits in the `skip` group.
  Review packets for all 83 came to ≈280 KB. Real resolutions keep sdm670's lines, so the real run will differ somewhat.
- Two script bugs found by the dry run and fixed: series commits carry their own older "cherry picked from" lines (the scripts now use the last one),
  and a reStructuredText heading underline looked like a conflict marker.
