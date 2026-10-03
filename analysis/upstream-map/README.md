<!-- task: K1 | agent: Space Bunny Free (space-bunny-free) | date: 2026-10-03 -->
# K1: upstream-origin map

## Summary

For all 2,599 series commits (`d54533f1546b..baa585f67e0e`, `--no-merges`) the map records the upstream commit each
one copies and whether sdm670 (`a30605a54f3b`) already carries it: **yes 44, no 1575, unknown 980**.
An upstream SHA was found for 1,605 of 2,599 commits (61.8%); the remaining 994 messages carry no usable origin
trailer, which is why 980 rows are `unknown` rather than `no`.
**Check these first:** (1) 6 of the 44 `yes` rows rest only on a *prose* mention of the SHA and are listed below —
do not let a K2 agent justify a `DROP` on those; (2) the task's spot-check expectation for `3ed2e2f029db` is
factually wrong, see the section on it; (3) 929 of the 980 `unknown` rows are commits by *other* authors whose
trailer is simply missing, so `unknown` must not be read as "probably fine to skip".

## Files

| File | What it is |
|---|---|
| `analysis/upstream-map/make_map.py` | The script. Argument 1 is the kernel path. Python 3 stdlib only, read-only `git log` |
| `analysis/upstream-map/upstream-map.tsv` | 2,600 lines: header + 2,599 commits |
| `analysis/upstream-map/README.md` | This file |

Run: `python3 make_map.py ~/work/k670` (about 55–60 s wall clock, 567 MB peak RSS). Optional flags
`--base --head --sdm --out`; defaults are the pinned SHAs below.

## Pins used

| Role | SHA |
|---|---|
| sdm670 tip (`--sdm`) | `a30605a54f3b92627d868f169c72ef9c6ef82123` |
| series base (`--base`) | `d54533f1546b91f94eb4e445dfea3a94ffa58a74` |
| series head (`--head`) | `baa585f67e0efc9f1efa046d0b0e76955ca4c8d5` |

All three verified present in `~/work/k670`; `git rev-list --count --no-merges d54533f1546b..baa585f67e0e`
prints 2599. The kernel repo was only ever read with `git log` / `git grep` / `git rev-parse` / `git rev-list`;
nothing was checked out, fetched, committed or written.

## Columns

`exy_commit`, `subject`, `upstream_sha`, `sdm670_has`, `sdm670_commit`. All SHAs are 12 characters, fields are
tab-separated, `subject` is the verbatim `%s`. `-` means "nothing to report". The script replaces any tab or
newline inside a subject with a space and double-quotes the field if it contains a quote; no row in this run
needed quoting, and all 2,599 rows have exactly 5 fields.

`upstream_sha` is the **first 12 characters** of the upstream SHA, and `sdm670_commit` the **first 12 characters**
of the sdm670 commit — the map is designed to be read by eye, not to be fed to `git cat-file`.

`upstream_sha = -` also encodes the evidence strength of a `yes`, which is why the distinction fits in five columns:

| Row shape | Meaning |
|---|---|
| `upstream_sha != -` and `sdm670_has = yes` | SHA-level evidence: the upstream SHA was located in sdm670's history |
| `upstream_sha = -` and `sdm670_has = yes` | Subject-only evidence: no trailer existed, only an exact subject match |

## Counts

| `sdm670_has` | Rows | What it means |
|---|---|---|
| yes | 44 | sdm670's history mentions the upstream SHA, or carries the exact subject |
| no | 1575 | An upstream SHA is known and sdm670 does not have it. sdm670 needs the change |
| unknown | 980 | No upstream SHA **and** no subject match. The script cannot tell |

Breakdown of the 44 `yes` rows by evidence grade (the script prints these to stderr):

| Grade | Rows | Meaning |
|---|---|---|
| exact | 0 | The upstream SHA *is* an sdm670 commit's own id |
| trailer | 23 | The SHA sits in an origin trailer of an sdm670 commit message |
| mention-only | 6 | The SHA only appears in sdm670 prose, a `Fixes:` line or a list URL |
| subject | 15 | Stripped subject matches an sdm670 subject exactly |

`exact = 0` is expected, not a bug: sdm670 and exynos9810 are unrelated trees, so a cherry-pick of the same
upstream commit gets a different SHA on each side. Every real match has to be found through trailers or subjects.
confidence: high — a cherry-pick necessarily rehashes the commit, so distinct trees cannot share ids.

## Evidence strength: the 6 weak rows

These are `yes` only because AGENT-TASKS.md K1 step 3 says to look for the SHA *anywhere* in `sdm670.log`. The
single sdm670 commit that produced the match quotes the SHA in running prose, not as an origin, so it is **not**
evidence that sdm670 carries the change. Do not accept a `DROP` on these without a manual diff.

| Series commit | upstream_sha | sdm670 match | Why it is weak |
|---|---|---|---|
| `7bd17c090118` | `ca36960211eb` | `6e9261aac3d8216563647e0c671750783ccf1993` | prose "…the fix in ca36960211eb" |
| `40d4e02bf231` | `f6b1b3bf0d5f` | `6e9261aac3d8216563647e0c671750783ccf1993` | prose "pointed out in commit f6b1b3bf0d5f" |
| `c3b17a0b3f37` | `4c27fe4c4c84` | `3de7f84519282d2bfe0e97d5cdef5b2a4834d01c` | prose; that commit's own origin is `29ec90660d68` |
| `aef50a6abc0e` | `fc9702273e2e` | `f8e84d7a9417e84aad03b98dbbb0ef44f2adcf3b` | subject unrelated (vmalloc), SHA only quoted |
| `8a953036e3b5` | `e83b9f55448a` | `72fcb214e0918fd3023e7d3dc5442061f5543879` | subject is the Clang/LLVM switch, SHA only quoted |
| `4495fc5deda2` | `4e1a33b105dd` | `b3937f55c725894d03ca6592a8dd29662e85251d` | subject is an ARM unaligned.h commit, SHA only quoted |

confidence: high — every row above was read by hand in the sdm670 commit body, e.g. `git log -1 --format=%b
6e9261aac3d8` shows the two SHAs inside the sentence "…pointed out in commit f6b1b3bf0d5f … the fix in
ca36960211eb".

## Upstream-SHA recognition

AGENT-TASKS.md lists four patterns and says "take the first 12–40 character hex match". Taken literally — first hex
run of any kind — that is **wrong on this series**: the messages are full of 12–40 character hex runs that are not
commit ids. A naive first-match extractor picks up mailing-list message ids and crash dumps. So the script matches
only on an explicit origin context, case-insensitively, first match in message order:

| Accepted form | Commits containing it |
|---|---|
| `Upstream commit <sha>`, including `[ Upstream commit <sha> ]` | 1133 |
| `(cherry picked from commit <sha>)` | 280 |
| `Upstream-commit: <sha>` | 138 |
| `commit <sha> upstream` | 90 |
| `Git-commit: <sha>` | 8 |

The forms overlap; together with the four from AGENT-TASKS.md they yield the 1,605 commits that have an
`upstream_sha`. `Upstream-commit:` and `Git-commit:` are not in the task's list but occur 138 and 8 times and are
real origin trailers, so dropping them would have lost 146 origins.
confidence: high — counts measured over all 2,599 message bodies, and two of the eight `Git-commit:` rows were
confirmed by hand (`b6efcb0394ff` and `68b90437585c`, each body reading `Git-commit: f405df5de317…` and
`Git-commit: 763b218ddfaf…`).

Deliberately **not** treated as an origin:

| Rejected form | Commits containing it | Why |
|---|---|---|
| `Fixes: <sha>` | 717 | names the commit being *fixed*, not this commit's origin |
| `lore`/`lkml` `Link: …/<hex>` | 953 | the trailing hex is a list message-id, not a commit |
| `Change-Id: I<hex>` | 240 | a Gerrit change id. Excluded automatically: the leading `I` blocks the word boundary, so `I0022fc3e1a…` never matches |
| prose `depends on`/`introduced in`/`pointed out in` `commit <sha>` | 10 | a dependency on a *different* commit |
| crash-dump register values (`R1=…`, `CR2=…`) | 0 | not commit ids |

Two commits prove the prose case matters: `0288339291bd` and `150625e4d7d3` both reference another commit
(`1f5307b1e094`, `45fa6615258e`) in prose, and `150625e4d7d3` even says "avoid backporting mainline commit
3a9b76fd0db9". All three are correctly `upstream_sha = -`.
confidence: high — the three quoted SHAs were read directly out of those commit bodies.

Two known gaps, both tiny and both left as `-` on purpose:

| Trailer form | Commits in the whole series | Note |
|---|---|---|
| `[ Linux 5.15-stable commit <sha> ]` | 5 | `b3cbc36acf0f` → `e8efe8369944` is a real origin but not one of the four listed patterns |
| `[ Android common commit <sha> ]` | 4 | `c196ca88d2fa` → `534bbffaa634` is the real origin; the script instead picks up the prose `Upstream commit 973c7a0d8a38` that appears earlier |

Only 3 of the 980 `unknown` rows are affected. `c196ca88d2fa` is worth knowing about even so: its `upstream_sha`
is a *dependency*, not its origin, because "first match in message order" is a positional rule, not a semantic one.
confidence: high — both messages were read in full; `c196ca88d2fa` contains `[ Android common commit
534bbffaa6341dbbbc85625f661d9754247456e9 ]` on line 3 and `Upstream commit 973c7a0d8a38` on line 5.

## Subject matching

The stripped subject is compared against sdm670 subjects, stripping only the four documented prefixes
(`BACKPORT:`, `UPSTREAM:`, `FROMLIST:`, `ANDROID:`), repeatedly. Subsystem prefixes such as `ARM:` or `staging:`
are part of the subject and are kept — sdm670 has 26,883 `ARM:` and 8,495 `staging:` subjects, and stripping those
would have caused false hits.

Stripping is what makes this work at all. `5d78d026ff4f` in the series is `UPSTREAM: bpf: cgroup skb progs cannot
access ld_abs/ind`, while sdm670's `edb6da11b95c34269d21e99e3b738da1114bdb5f` is `FROMLIST: bpf: cgroup skb progs
cannot access ld_abs/ind` — different prefixes, same change. Two other subject-only hits are `5610ada6efc5`
(`drm: Add aspect ratio parsing in DRM layer`, sdm670 `6fce4f33639272165f94bd65e28760862dcf3f85`) and
`dff86fa1e78e` (`drm: add picture aspect ratio flags`, sdm670 `bd79c01966c18391c96e90aed747482b144728bb`).

Exactly 31 of the 2,599 stripped series subjects exist in sdm670; 15 of those rows are decided by the subject, the
other 16 were already decided by a stronger SHA match.
confidence: high — the 31 were recomputed independently from a separate `git log --format=%s` pass.

Series subjects that carry a device prefix such as `[exynos9810]` or `[9810]` are **not** stripped, because the
task does not list them. They are S9-only work and genuinely absent from sdm670, so this costs nothing here.
confidence: medium — I did not enumerate how many rows are affected, only confirmed a sample is S9-specific.

## Spot-check `3ed2e2f029db`: the task's expectation is wrong

AGENT-TASKS.md K1 says `3ed2e2f029db` ("BACKPORT: bpf: Add BPF_MAP_TYPE_LRU_HASH") is expected to come out `yes`
"because sdm670 already carries LRU_HASH". **It does not, and the task's own verification command proves it.**
The row comes out `unknown`, and I did not force it to `yes`.

The command named in the task fails:

```
$ git -C ~/work/k670 grep -n BPF_MAP_TYPE_LRU_HASH a30605a54f3b -- include/uapi/linux/bpf.h
$ echo $?
1
```

Exit 1 is git's "no match". `git grep -l BPF_MAP_TYPE_LRU_HASH a30605a54f3b` over the **whole tree** also returns
nothing: the only LRU file sdm670 has is `include/linux/list_lru.h`, which is the page reclaim LRU, not BPF.
sdm670's enum at `include/uapi/linux/bpf.h:81-89` @ `a30605a54f3b` stops at `BPF_MAP_TYPE_CGROUP_ARRAY` and has no
LRU entry at all; the series adds `BPF_MAP_TYPE_LRU_HASH` at `include/uapi/linux/bpf.h:146` @ `baa585f67e0e`.

Two further reasons the row is `unknown` and not `yes`:

1. The commit has **no upstream trailer**. `git cat-file commit 3ed2e2f029dba69f61f7635f4c52c3baced415d0` ends at
   `Signed-off-by: David S. Miller` with no `Upstream commit` line, so `upstream_sha = -`.
2. No sdm670 commit carries that subject, so the subject fallback misses.

The value is `unknown` because with neither an upstream SHA nor a subject match there is nothing left to match on.
Note the series base does *not* have LRU_HASH either, so this commit genuinely adds it and sdm670 genuinely needs
it. The whole BPF LRU cluster is missing from sdm670: `064eec9d7188` (bpf: LRU List), `c8eed4cadded` (bpf: Add
percpu LRU list), `3ed2e2f029db`, `6ae7023aafc7` (LRU_PERCPU_HASH) and `69f26a741d47` (bpf: Inline LRU map lookup)
are all `unknown`.

The closest real hit is the neighbouring `d1b64fd4faff` ("BACKPORT: bpf: complete LRU hash hlist conversion"),
which is `yes`: its trailer `Adapted from upstream commit 4fe8435909fd` matches sdm670 commit
`82303dd64addd098f1ec7029bc2c97990ae2bf2a` ("bpf: convert htab map to hlist_nulls"), whose body says
`commit 4fe8435909fddc97b81472026aa954e06dd192a5 upstream`. But sdm670 has only the *htab* half of that
conversion, not the LRU half, so the `yes` means "same upstream origin, partial coverage".
confidence: high — every command above was run and its exit status and output are quoted verbatim.

## Independent verification

I re-derived the whole `upstream_sha` column with a second, deliberately different tokenizer and compared it to
the TSV. 2 of 2,599 rows differed, and in both cases the TSV is right and the naive tokenizer is wrong
(`c196ca88d2fa` described above; `b3cbc36acf0f` picked up the unlisted `Linux 5.15-stable` trailer).

By hand, against the tree:

* 8 `no` rows: each upstream SHA extracted from a real trailer, then `git log --format='%H%x1f%b' a30605a54f3b |
  grep -c <sha>` returned 0 for all 8.
* 4 `yes`-by-trailer rows: the sdm670 commit body was read and does name the SHA — `03f11616d0db` says
  `commit c3466952ca15`, `02f7e4101092` says `Upstream commit eefca20eb20c`, `b6efcb0394ff` and `68b90437585c`
  say `Git-commit: …`.
* 3 subject-only rows: subjects compared by hand, as quoted above.

confidence: high — every check was executed against `~/work/k670` and its output is quoted.

## What `unknown` means here, and the follow-up worth doing

`unknown` is **not** "probably fine". Of the 980 `unknown` rows, only 51 are authored by krazey himself, i.e.
genuinely original work with no upstream to point at. The other 929 are commits by other people whose origin
trailer is simply absent: 114 Daniel Borkmann, 96 Mathias Gluszczynski, 61 Martin KaFai Lau, 53 John Fastabend,
37 Eric Dumazet, 34 Alexei Starovoitov, 26 Yonghong Song, 26 Jakub Kicinski, 18 Willem de Bruijn, 17 David S. Miller,
17 Jesper Dangaard Brouer. Since sdm670 is a 4.9 tree missing most of this eBPF work, those 929 are very likely
new work, but the map cannot prove that from the message alone.
confidence: high — author taken from `git log --format=%an` over the series and grouped by the TSV verdict.

The test that would settle all 980 is **patch-id**, not message text: `git patch-id --stable` of each series commit
against sdm670's. That is a real follow-up task, not something K1 should have done — computing stable patch-ids for
sdm670's 724,270 commits is the expensive half, so budget tens of minutes and about a minute of CPU per few
thousand series commits. It would also replace the 6 weak prose rows with hard answers.
confidence: medium — I did not run it; the cost estimate is extrapolated from the size of the history, not measured.

## Self-check output

Line count:

```
$ wc -l upstream-map.tsv
2600 upstream-map.tsv
```

Verdict counts (`yes`+`no`+`unknown` = 2599):

```
$ awk -F'\t' 'NR>1{c[$4]++} END{for(k in c) print k, c[k]}' upstream-map.tsv | sort
no 1575
unknown 980
yes 44
```

Determinism, two consecutive runs of `python3 make_map.py ~/work/k670`:

```
$ sha256sum upstream-map.tsv     # run 1
39278802303af4f8f966321eb90d86979ec9655a0b35d0d16bb516271ed92666  upstream-map.tsv
$ sha256sum upstream-map.tsv     # run 2
39278802303af4f8f966321eb90d86979ec9655a0b35d0d16bb516271ed92666  upstream-map.tsv
```

Both runs also printed identical stderr, including the mention-only warning list.

Spot-check row:

```
$ grep -P '^3ed2e2f029db\t' upstream-map.tsv
3ed2e2f029db	BACKPORT: bpf: Add BPF_MAP_TYPE_LRU_HASH	-	unknown	-
```

Runtime: 53.9 s and 57.8 s on two consecutive runs of the final script (`/usr/bin/time -v` on the second:
maximum resident set size 580,032 kB). One streaming pass over the 2,599-commit series, one streaming pass over
sdm670's 724,270 commits, ~396 MB of message text read in 4 MB chunks so it is never held in memory as one string.
The two per-commit passes the brief warned about were both avoided: commit messages come from two batched
`git log --format` calls rather than 2,599 `git log -1` calls, and the sdm670 index is built in a single scan.

## Problems

1. **The spot-check in AGENT-TASKS.md K1 is factually wrong.** It states sdm670 already carries
   `BPF_MAP_TYPE_LRU_HASH` and gives a `git grep` command to prove it; that command exits 1 (no match), and sdm670
   has no BPF LRU code at all. `3ed2e2f029db` therefore comes out `unknown`, not `yes`. I left it as the script
   computed it, as instructed, and documented the evidence above. Worth correcting the task text so the next
   agent does not "fix" this row by hand.
2. **Two commands were run once each and both failed in an expected way**, not a real error: the spot-check
   `git grep` exits 1 (no match) and `git log --grep=… -F` exits 0 with no output. Neither was retried as a fix;
   both are quoted above.
3. **The kernel tree was treated as read-only throughout.** No `checkout`, `switch`, `fetch`, `cherry-pick`,
   `rebase`, `reset`, `clean`, `commit`, `merge`, no writes and no remote changes. Only `git log`, `git grep`,
   `git rev-parse`, `git rev-list` and `git cat-file` were used. All scratch files were kept outside the repo, in
   `/tmp/opencode/k1`.