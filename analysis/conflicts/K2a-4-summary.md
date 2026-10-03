<!-- task: K2a-4 | agent: Space Bunny Free | date: 2026-10-03 -->
# K2a-4: conflict briefs for batch K2a-4 (required, trivial - 7 commits)
## Summary
7 conflict commits briefed, all `group=required` / `size_class=trivial` in
[`analysis/exyhyperbrick-trial/conflict_detail.tsv`](../exyhyperbrick-trial/conflict_detail.tsv).
Resolutions: **5 MERGE, 1 PREREQ, 0 DROP, 0 HUMAN**, confidence: 7 high.
No commit is a DROP, so nothing in this batch is silently lost code.

All 7 conflicts were read directly out of `git merge-tree --write-tree --merge-base=<C>^ a30605a54f3b <C>`
against the read-only tree `~/work/k670` (sdm670 tip `a30605a54f3b`). In 2 of the 7 cases
(`f9c1f9e6dbe8`, `57dbd53a0638`) that standalone merge reports *more* conflicts than the trial did, because the
trial replayed the series stacked. I reproduced the trial's stacked pre-image in a scratch directory under
`/tmp` by replaying the earlier series commits that touch the same files, and confirmed I got exactly the trial's
1 conflict block each time. Those reconstructions are what the briefs point at.

**What the lead must check first**
1. **`d220f0d71646` is not resolvable on its own.** It needs `462a37becb45` ("fuse-bpf: Add request dispatcher"),
   which is itself an unresolved conflict in **batch K3-2** (`analysis/agent-batches/K3-2.tsv:2`, large, 4 blocks).
   Order matters.
2. **Do not lose `passthrough.o`.** Both `462a37becb45` and `d220f0d71646` rewrite the single object-list line in
   `fs/fuse/Makefile` from `fuse-objs := ... passthrough.o` to `fuse-y := ...` **without** `passthrough.o`.
   Samsung's FUSE passthrough is live code in sdm670 (`fuse_setup_passthrough()` at `fs/fuse/dev.c:1963`,
   `fuse_passthrough_read_iter`/`_write_iter`/`_release` in `fs/fuse/fuse_passthrough.h`). Whoever resolves those
   two Makefile hunks must keep `passthrough.o`.
3. **`57dbd53a0638` silently depends on `nr_descendants`.** sdm670's `kernel/cgroup.c` has no descendant
   accounting at all today. If the four prerequisites listed in that brief are skipped, the cgroup v2 freezer's
   hierarchical propagation is dead code (a parent cgroup never reports `frozen`). Do not resolve the
   `kernel/cgroup.c` hunks by taking ours.
4. **`0d4a90f470f7`: keep `HRTIMER_STATE_PINNED`.** The Exy tree deleted this CAF pinned-timer extension
   (`git grep HRTIMER_STATE_PINNED baa585f67e0e` = no hits), so "take theirs" would drop it. sdm670 uses it in 5
   places in `kernel/time/hrtimer.c` plus `include/linux/hrtimer.h:77`.
5. **`73a6a4136257` is behaviour-neutral for us, but verify the symbol is `y`.** The commit adds
   `select ARCH_HAS_NON_OVERLAPPING_ADDRESS_SPACE` to `arch/arm64/Kconfig`; if that select were lost, Android's
   `bpfloader`/`netbpfload` would lose `bpf_probe_read()`. Cross-check with task K6's defconfig fragment.

| commit | subject | resolution | confidence |
|---|---|---|---|
| `f4cb49f3084c` | BACKPORT: ANDROID: fuse: Move functions in preparation for fuse-bpf | MERGE | high |
| `d220f0d71646` | BACKPORT: ANDROID: fuse-bpf: Route read-only xattrs | PREREQ | high |
| `0d4a90f470f7` | BACKPORT: hrtimer: Store running timer in hrtimer_clock_base | MERGE | high |
| `0475d5694a93` | BACKPORT: bpf: Implement local storage for inodes | MERGE | high |
| `f9c1f9e6dbe8` | BACKPORT: bpf: Check saved credentials for raw dumps | MERGE | high |
| `73a6a4136257` | BACKPORT: bpf: Gate legacy probe reads by architecture | MERGE | high |
| `57dbd53a0638` | BACKPORT: cgroup: cgroup v2 freezer | MERGE | high |

Upstream SHAs (read from the commit messages with the K1 patterns; K1's `upstream-map.tsv` did not exist yet):

| commit | upstream |
|---|---|
| `f4cb49f3084c` | `88b7179fcdb59ade839972bb6042e2b986e7cd57` |
| `d220f0d71646` | `6be5b06e4195b002c52a1c2c82573ea7a76ce111` |
| `0d4a90f470f7` | `3f0b9e8eec7262648ab9c8321bf931624ee5c10a` |
| `0475d5694a93` | `8ea636848aca35b9f97c5b5dee30225cf2dd0fe6` |
| `f9c1f9e6dbe8` | `160251842cd35a75edfb0a1d76afa3eb674ff40a` (+`63960260457a02af2a6cb35d75e6bdb17299c882`) |
| `73a6a4136257` | `0ebeea8ca8a4d1d453ad299aef0507dab04f6e8d` (+`d195b1d1d1196681ac4775e0361e9cca70f740c2`, `66633abd0642f1e89d26e15f36fb13d3a1c535ff`) |
| `57dbd53a0638` | `76f969e8948d82e78e1bc4beb6b9465908e74873` |

Note for the lead re-reading K1's index: `f9c1f9e6dbe8` and `73a6a4136257` each squash **two** and **three**
upstream commits respectively, so a K1 row for them can only name the first one.

## Files
- `analysis/conflicts/f4cb49f3084c.md`
- `analysis/conflicts/d220f0d71646.md`
- `analysis/conflicts/0d4a90f470f7.md`
- `analysis/conflicts/0475d5694a93.md`
- `analysis/conflicts/f9c1f9e6dbe8.md`
- `analysis/conflicts/73a6a4136257.md`
- `analysis/conflicts/57dbd53a0638.md`

## Confidence
high for the batch: every commit's conflict block was read out of a real `git merge-tree` result against
`a30605a54f3b`, every "Already in sdm670?" answer is backed by named `git grep`/`git log -S` searches that were
actually run (each brief says which lines were searched for), and in the two cases where the standalone merge
showed more conflicts than the trial I reproduced the trial's stacked pre-image and got a byte-identical match to
the trial's recorded conflict counts. The one item to re-check by hand is `d220f0d71646`, because its
resolution depends on how the lead resolves `462a37becb45` (batch K3-2), not on anything I can see from here.

## Problems
None. `~/work/k670` was used read-only (`show`, `log`, `grep`, `cat-file`, `merge-tree`); the two
trial reconstructions were done on copies of single files in `/tmp/opencode/` with `git apply`, never in the
kernel tree, and no ref in any repo other than `agent/K2a-4` in this repo was created or moved.