<!-- task: K2a-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# K2a-2: conflict briefs for batch K2a-2 (10 commits)
## Summary
10 commits, 10 briefs in `analysis/conflicts/`, all in group `required` (per
`analysis/exyhyperbrick-trial/conflict_detail.tsv`). Resolutions: 6 MERGE, 2 PREREQ, 2 DROP, 0 HUMAN.
All 10 were run through `git merge-tree --write-tree --merge-base=C^ a30605a54f3b C` against the
read-only kernel tree at `~/work/k670`; no `git show C` failed.

**Things the lead must look at first**

1. **`analysis/exyhyperbrick-trial/results.tsv` under-reports conflicts.** The trial stacked the
   commits and committed each result *with conflict markers still in the tree*
   (`analysis/exyhyperbrick-trial/trial.py`, the `commit-tree` line), so a commit marked `CLEAN` can
   still conflict when applied to a real sdm670 working tree, and a commit can be recorded with fewer
   conflicted files than it really has. Concrete cases found here:
   - `993f49608c23` is recorded as 1 file / 1 block; standalone it is **9 files / 12 blocks / ~5100 lines**.
   - `116e0762801b` (prerequisite of `856f611efb48`) is `CLEAN` but conflicts standalone in 3 files.
   - `b327d83996fc` (prerequisite of `59db77a70b7f`) is `CLEAN` but conflicts in `net/ipv4/udp.c`.
   - `86d4a3ab7e8d` (prerequisite of `993f49608c23`) is `CLEAN` but conflicts standalone in 6 files.
2. **Two briefs describe a build break that git will *not* report**, because the offending lines are
   in hunks that merge cleanly:
   - `d9dfe4a76fb9`: after the commit, the global `tcp_death_row` is deleted, but sdm670's own
     `tcp_tw_recycle` entry in `net/ipv4/sysctl_net_ipv4.c` (`ipv4_table[]`) survives and references it.
   - `2d6869d3a4ce`: taking "theirs" on `arch/arm64/include/asm/thread_info.h` deletes `TIF_FSCHECK`
     and reproduces build error **K4c** in `analysis/build-test/port-first-errors.txt` verbatim.
3. **Prerequisite chains** (`856f611efb48` → `116e0762801b`; `993f49608c23` → `86d4a3ab7e8d` →
   the sk_msg/tcp_bpf commits) must be walked in series order; several of those prerequisites are
   marked `CLEAN` but are not.
4. **Defconfig gap:** `2d6869d3a4ce` adds arm64 uprobes but sdm670's tablet defconfig has
   `# CONFIG_UPROBES is not set` (`gts4lvwifi_eur_open_defconfig:235`) as well as
   `# CONFIG_KPROBES is not set` (`:233`). The trial README's defconfig list only mentions
   `CONFIG_KPROBES=y`.
5. Model caveat: per `AGENT-TASKS.md` §10 this batch is tier-1 work and this agent is an unproven
   model (`Space Bunny Free`), so per §10/§11 the `high`-confidence items should be spot-checked.

| commit | subject | resolution | confidence |
|---|---|---|---|
| `5e25006aff43` | UPSTREAM: ipv6: constify inet6_protocol structures | DROP | high |
| `e9c1bdddb9a0` | BACKPORT: locking/refcount: Create unchecked atomic_t implementation | MERGE | high |
| `856f611efb48` | UPSTREAM: tcp: Export tcp_{sendpage,sendmsg}_locked() for ipv6. | PREREQ | high |
| `59db77a70b7f` | BACKPORT: net: ipv4: add second dif to inet socket lookups | MERGE | high |
| `e3a9e868eac2` | UPSTREAM: ipv6: do not set sk_destruct in IPV6_ADDRFORM sockopt | MERGE | high |
| `d9dfe4a76fb9` | BACKPORT: ipv4: Namespaceify tcp_tw_recycle and tcp_max_tw_buckets knob | MERGE | high |
| `7bae1fbba13b` | net/tcp_fastopen: remove obsolete extern | DROP | high |
| `993f49608c23` | bpf, sockmap: convert to generic sk_msg interface | PREREQ | medium |
| `2d6869d3a4ce` | arm64: Add uprobe support | MERGE | high |
| `495ac52546da` | BACKPORT: arch: wire-up close_range() | MERGE | high |

## Resolutions in one line each
- `5e25006aff43` DROP of the conflicting hunk: sdm670 already has
  `static const struct inet6_protocol udpv6_protocol` at `net/ipv6/udp.c:1470` (from sdm670's own
  `41135cc836a1`). Keep the cleanly-applied `net/ipv6/ip6_gre.c` hunk (still missing).
- `e9c1bdddb9a0` MERGE: keep sdm670's `CREATE_TRACE_POINTS` / `trace/events/exception.h` /
  `soc/qcom/minidump.h` include block, add `#include <linux/ratelimit.h>`, drop `linux/exynos-ss.h`.
- `856f611efb48` PREREQ on `116e0762801b` ("proto_ops: Add locked held versions of sendmsg and
  sendpage"): sdm670 has no `tcp_sendmsg_locked`/`tcp_sendpage_locked`, so the two EXPORT lines have
  nothing to attach to.
- `59db77a70b7f` MERGE: single block, take theirs (`th->dest, sdif, &refcounted;`). Needs
  `b327d83996fc` first, which is what adds `inet_sdif()`.
- `e3a9e868eac2` MERGE: take theirs, i.e. delete `sk->sk_destruct = inet_sock_destruct;` from the
  `IPV6_ADDRFORM` branch (one-line commit).
- `d9dfe4a76fb9` MERGE, 3 blocks + 2 mandatory manual follow-ups (see the brief).
- `7bae1fbba13b` DROP: `sysctl_tcp_fastopen_blackhole_timeout` does not exist anywhere in sdm670 and no
  later series commit re-adds it to `include/net/tcp.h`; taking "theirs" would add undeclared
  `tcp_fastopen_active_*` / `tcp_chrono` prototypes.
- `993f49608c23` PREREQ on `86d4a3ab7e8d` ("bpf: Check attach type at prog load time"), which carries
  the 2-argument `get_func_proto()` that sdm670 lacks. Per-block plan for later is in the brief.
- `2d6869d3a4ce` MERGE: keep `TIF_FSCHECK 4` **and** add `TIF_UPROBE 5` (bit 5 free), add
  `_TIF_UPROBE` to `_TIF_WORK_MASK`. Taking "theirs" is exactly build error K4c.
- `495ac52546da` MERGE: keep sdm670's `424 pidfd_send_signal` / `434 pidfd_open`, add
  `436 close_range`, drop the base's `397 statx`.

## Confidence
**medium-high** overall: 9 briefs are `high` because every claim is a `git merge-tree` output, a
`git grep` hit/miss with the exact line quoted, or a `git cat-file` existence check, and all
absence claims were made with two independent searched lines. `993f49608c23` is `medium` because a
2878-line BPF refactor cannot be certified by one 3-way merge.

## Problems
- The trial's stacked-replay method means the *number of conflicted files* recorded in
  `analysis/exyhyperbrick-trial/results.tsv` and `conflict_detail.tsv` understates reality for commits
  that follow an unresolved conflict. Every brief here was re-derived with pristine sdm670 as "ours",
  as `AGENT-TASKS.md` §K2 step 3 instructs, so the briefs may show more conflicted files than the TSVs do.
- `scripts/check-agent-output.sh` (AGENT-TASKS.md §11) was not run: it is not present in this
  worktree's `origin/main`. The self-check below was run by hand instead.
- Note for the reviewer: `AGENT-TASKS.md` §10 recommends a tier-1 model for K2a; this agent is an
  untested model, so §11's "check every `high` item" rule applies more strictly than usual here.