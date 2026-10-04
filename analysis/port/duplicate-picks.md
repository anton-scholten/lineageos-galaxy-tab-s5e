# Duplicate-landing cherry-picks in `port/pick`

Written by the lead after P2 and after an ad-hoc verification sweep. **Not** a substitute for P1-R — it is
the list of things P1-R should look at first, plus two fixes P3 can apply.

Kernel branch `port/pick` @ `d73f07cf8b5c` (2,438 picks). Base `a30605a54f3b92627d868f169c72ef9c6ef82123`.
All line numbers below were re-verified by the lead against `port/pick`, not taken on trust.

## Why a clean cherry-pick is not evidence of correctness

`git cherry-pick` reports success in two distinct situations:

1. the change was genuinely absent and is now present — the normal case; and
2. **the change was already present, git found a non-overlapping insertion point, and landed a duplicate.**

Case 2 is invisible to `check-pick.py`'s `clean` bucket, which gets no human review. It compiles, because in C
a later `#define` or function silently wins. `ec3b287a8a17` (duplicated `bpf_probe_read_str`, self-healed at
`dddb8c0eafe8`) was the first instance found during P1; these three are the rest.

## The three findings

### F1 — `include/uapi/drm/drm_mode.h`, 7 duplicated macros — **fix this one**

Pick `91cf4dc6c832` (series commit `dff86fa1e78e`) added a second, conflicting picture-aspect block.

| | lines at `port/pick` | shift | ratios defined |
|---|---|---|---|
| **pick's copy** | **92–104** | `(0x0F<<19)` — bits 22:19 | NONE, 4_3, 16_9 |
| base's copy | 106–124 | `(0x0F<<24)` — bits 27:24 | NONE, 4_3, 16_9, **_64_27, _256_135** |

`DRM_MODE_FLAG_SUPPORTS_YUV420 (1<<22)` is at line 90. The pick's `<<19` occupies bits 22:19 and so **overlaps
it at bit 22** — the upstream range is genuinely wrong for this header, which is presumably why Samsung moved
it to 27:24. Today the build is correct only because the base's copy comes *later* and wins; the pick's copy is
the sole reason nothing collides.

**The fix is counterintuitive and the wrong one breaks things. Delete `port/pick` lines 92–104 — the pick's
copy. Do NOT delete 106–124.** Deleting the base copy would drop `DRM_MODE_PICTURE_ASPECT_64_27` and
`_256_135`, which only it defines, *and* would leave `(0x0F<<19)` in force, reintroducing the bit-22 collision
with `SUPPORTS_YUV420`.

**Currently:** benign (later definition wins) but a live landmine, and it emits a macro-redefinition warning on
every include. Related: P1 already dropped the companion core commit `5610ada6efc5` as "already in sdm670 as
`6fce4f336392`", so the series' DRM picture-aspect pair is **half-applied** — this is the half that should have
been an empty pick. `confidence: high`.

### F2 — `fs/userfaultfd.c`, duplicated `VM_MAYWRITE` check

Pick `36678a600282` (series commit `d5f2acfd8dc2`, upstream `29ec90660d68`) re-added an 11-line
`VM_MAYWRITE` / `-EPERM` check that the base already had via `3de7f8451928`.

```
fs/userfaultfd.c:1401   if (unlikely(!(cur->vm_flags & VM_MAYWRITE)))   <- pick 36678a600282
fs/userfaultfd.c:1427   if (unlikely(!(cur->vm_flags & VM_MAYWRITE)))   <- base 3de7f8451928
```

Ranges 1392–1402 and 1418–1428 are byte-identical. Nothing was lost: the two `WARN_ON` lines the patch wanted
are present at `:1461` and `:1633`. **Currently:** benign — the check is idempotent, so the second copy is
unreachable dead code. Fix: delete `fs/userfaultfd.c:1391–1403`. `confidence: high`.

Worth checking the rest of the `fs/userfaultfd.c` linked group (`10a07035a7e7`, `fad9a6a81aa6`, `f0f30b4639c2`,
`9114ddb3b20f`, `b07d07e8f011`) for the same "already present in base, landed anyway" shape.

### F3 — `arch/parisc/include/uapi/asm/socket.h`, `SO_PEERGROUPS` twice — **a different root cause**

```
socket.h:98   #define SO_PEERGROUPS  0x4034   <- d82d6d1f5370
socket.h:100  #define SO_PEERGROUPS  0x4034   <- e78b1e3ce7ea
```

`blame` gives it away: the two lines come from two picks of the **same upstream patch under two different SHAs**,
same author (David Herrmann) and same timestamp (2017-06-21 10:47:15 +0200):

| pick | upstream | scope |
|---|---|---|
| `d82d6d1f5370` | `f013ca106eda` | 11 `socket.h` files, parisc included |
| `e78b1e3ce7ea` | `a8793be79cac` | 1 file, parisc only |

The Samsung tree and mainline each carried a copy; the series picked up both. The second should have been an
empty pick. **Currently:** benign — byte-identical object-like macro redefinition is explicitly legal C with no
diagnostic required, and `arch/parisc` is not built for arm64. It matters only as a landmine: editing one copy
silently desynchronises them. `confidence: high`.

## Two root-cause classes

| class | mechanism | findings | how to detect |
|---|---|---|---|
| **A** | change already in the sdm670 base; the pick found a fresh insertion point and duplicated it | F1, F2 | added block present in base **and** ≥2× in the result |
| **B** | series carries the same upstream patch twice under two SHAs; second pick is a pure duplicate | F3 | group picks by `cherry picked from commit` trailer **and** by normalised subject |

Class B is the one that needed the trailers to see. Note for the reviewer: the ad-hoc sweep initially reported
that neither F3 commit carried a `cherry picked from commit` trailer. **That was wrong** — both do, with
different upstream SHAs. Verified directly. Recorded here because it is exactly the kind of detail that
propagates if a report is pasted unverified.

## How much this bounds the risk

The sweep covered **all 2,438 picks**, not a sample: 893 distinct files, 8,848 added blocks of ≥3 non-blank
lines, 186 raw candidates triaged, 183 cleared as false positives, **3 confirmed**.

Two of the three were found in P2's 6-commit `automerge/` bucket. The sweep of the **2,372-commit `clean`
bucket that no human ever reviewed turned up exactly one finding** — F3, which is in unbuilt `arch/parisc` and
is legal C. That is the single most useful fact in this document: it is real evidence that the unreviewed
bucket is in better shape than the `ec3b287a8a17` anecdote suggested, and it should inform how much of the
37-commit spot-check pool really needs reading.

The sweep deliberately did **not** use base patch-id comparison: a landed duplicate has a non-empty diff by
construction, so its patch-id can never equal the base's patch-id for the same change. Testing for
*presence in base **and** multiplicity in the result* is strictly stronger, and it found F2 directly.

## Left for P1-R

- Apply F1 and F2 (both one-block deletions; F1's target lines are load-bearing — see above).
- Read the rest of the `fs/userfaultfd.c` linked group for class A.
- Decide whether F3 is worth touching at all. It is benign; deleting it is cosmetic.
- The sweep's own caveat: it looked for duplicate *definitions* and duplicate *blocks*. It cannot detect a
  pick that landed a **semantically wrong** but non-duplicated change, which is the larger blind spot and the
  reason the spot-check pool still matters.