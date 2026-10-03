# Port status

Updated by the owner or the reviewing lead after each step, **not** by working agents. Steps and prompts: [RUNBOOK.md](../../RUNBOOK.md).

| Step | State | Branch / output | Notes |
|---|---|---|---|
| 0 Setup: tokens, branch protection, clones | ☐ | | |
| 1 Round 3: K7 | ☐ | `agent/K7` | |
| 1 Round 3: K8 | ☐ | `agent/K8` | |
| 1 Round 3: R7 | ☐ | `agent/R7` | |
| 1 Round 3: R8 | ☐ | `agent/R8` | |
| 1 Round 3: R9 | ☐ | `agent/R9` | |
| 1 🔍 Round 3 review + merge | ☐ | `main` | |
| 2 P1 cherry-pick | ☐ | kernel `port/pick`, `agent/P1` | dry run: ~83 stops expected |
| 3 🔍 P1-R | ☐ | `review-P1.md` | |
| 3 P2 automerge triage | ☐ | `agent/P2-*` | dry run: ~4 packets |
| 3 🔍 P2-R | ☐ | `review-P1.md` | |
| 4 P3 known fixes + defconfig | ☐ | kernel `port/pick`, `agent/P3` | needs K7 |
| 5 P4 build loop | ☐ | kernel `port/pick`, `agent/P4` | done = `Image.gz-dtb` |
| 5 🔍 P4-R | ☐ | `review-P4.md` | |
| 6 P5 device tree | ☐ | device `port/dt`, `agent/P5` | needs R7–R9 |
| 6 🔍 P5-R | ☐ | `review-P5.md` | |
| 7 Fast-forward both `lineage-23.2` | ☐ | | |
| 8 ROM build | ☐ | | owner's machine |
| 8 First boot | ☐ | | |
| 8 Tests + 24 h soak | ☐ | | |

States: ☐ not started · ◐ running · ✅ done · ⛔ blocked (say why in Notes).
