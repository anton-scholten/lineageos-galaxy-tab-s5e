<!-- task: P5 | agent: Space Bunny Free (opencode helper) | date: 2026-10-04 -->
# P5: device-tree commits

## Summary

Device-tree fork `anton-scholten/android_device_samsung_gts4lv-common`, branch `port/dt`, branched from
`lineage-23.2` @ `2e50286ebc01` and pushed. **One commit: `e3ccc923bcf2` "P5: audio: use space-separated
policy lists"**, trailer `Fix-by: Space Bunny Free; R6 924cf7e4adcc`.

It converts all **79** comma-separated `samplingRates`/`channelMasks` attribute values (499 commas) in
`audio/configs/audio_policy_configuration.xml` to the space-separated form. The other **84** commas in
that file are untouched — they are the comma-separated `sources=` attributes of the 19 `<route>` elements
plus XML comment text. `lineage-23.2` was not moved (still `2e50286ebc01` on the remote).

Round 3 turned the other five planned items into no-ops, so there are **no other commits on `port/dt`**.
They are logged below as *considered, intentionally skipped*, with the round-3 text that decided each one
quoted rather than paraphrased. The lead's attention is wanted on skip 1 (`target-level`): that one is a
**project decision the reviewer explicitly left open**, not a technical no-op.

Device tree used: `~/work/dt`, on `port/dt`. Read-only clones reused for verification only:
`~/work/clone-R6/sm7125`, `~/work/clone-R6/exy`, `~/work/clone-R6/dev-gts4lv`, `~/work/clone-R6/caf232`,
`~/work/clone-R7/build`.

---

## The commit

| | |
|---|---|
| repo | `anton-scholten/android_device_samsung_gts4lv-common` |
| branch | `port/dt` (new, forked from `lineage-23.2` @ `2e50286ebc01`) |
| commit | `e3ccc923bcf225482a0cc5fa5d92b1257dadf3b8` |
| file | `audio/configs/audio_policy_configuration.xml` (the **only** `audio_policy*.xml` in the tree) |
| trailer | `Fix-by: Space Bunny Free; R6 924cf7e4adcc` |

### Scope check before editing

`git ls-files | grep -i audio_policy` → exactly one file, `audio/configs/audio_policy_configuration.xml`.
The other two files in `audio/configs/` are `audio_platform_info.xml` and `audio_platform_info_diff.xml`;
they are `audio_platform*`, not in scope, and were not touched.

### What was changed, and what was deliberately not

110 attribute values matched `samplingRates=` / `channelMasks=` / `formats=` in the file (57
`samplingRates`, 53 `channelMasks`, **0** `formats=` — the file only ever uses the singular `format=`
with one value and no comma). They contained 499 commas, all of which became single spaces.

The file has 583 commas in total. The **84 that stayed** are:

- **19 `sources=` attributes** of `<route>` elements (lines 300–341), e.g.
  `sources="primary output,deep_buffer,direct_pcm,compressed_offload,voip_rx,mmap_no_irq_out"` at line 300.
  These are comma-separated *by design* — the mix-port names themselves contain spaces (`"primary output"`),
  so a whitespace split could not work there. For reference,
  `LineageOS/android_device_samsung_sm7125-common` @ `865ff7e37424`, which ships 23.2 with this same file
  space-separated, still has **15** comma-separated `sources=` lines. Not touched.
- **65 commas in XML comments**: the Apache licence header (lines 2, 7, 13, 14, 15) and the module
  documentation comment (lines 21–47, 208, 262, 297, e.g. `“primary”, “A2DP”, “remote_submix”, “USB”`).

The `flags=` attributes were already pipe-separated (`AUDIO_OUTPUT_FLAG_FAST|AUDIO_OUTPUT_FLAG_PRIMARY`),
so they needed nothing.

### Why

`exynos9810-common` `924cf7e4adcc` "exynos9810-common: audio: Use space-separated policy lists", whose own
message is "The audio policy schema expects sampling rates and channel masks to be separated by spaces",
adapted from `LineageOS/android_device_samsung_exynos9820-common@001baf054f38`. Verified directly in
`~/work/clone-R6/exy`: the commit touches `configs/audio/audio_policy_configuration.xml`, 4 insertions /
4 deletions, and each hunk changes nothing but `,` → ` ` inside a `samplingRates` and a `channelMasks`
value. `~/work/clone-R6/sm7125` @ `865ff7e37424` (an official 23.2 tree for the same SoC family) has
**0** comma-separated `samplingRates`/`channelMasks` values, with e.g.
`samplingRates="8000 11025 12000 16000 22050 24000 32000 44100 48000 64000 88200 96000 176400 192000 352800 384000"`
at its line 41.
confidence: high — both reference files read at pinned SHAs, and the exynos9810 diff re-read hunk by hunk.

R6's own claim that Android's parser splits these attributes on whitespace (`analysis/rom/port-from-exynos9810.md:204`)
is **not** something I verified: `frameworks/av` was not cloned, and R6 marked the whole item
`confidence: high` on the strength of the two shipped trees rather than of the parser code. Two trees that
ship the same ROM both use spaces is good enough evidence for the change, and the change is reversible, so
I did not chase it. confidence: high that space-separated is the 23.2 shipping form; medium on the exact
mechanism by which the comma form fails.

### Verification of the edit

The strongest check: reverse the intended transformation on the new file and require **byte-identity** with
the old one. It holds, which proves no other byte in the file moved.

```
reverse-transform == original: True
attributes: ['channelMasks', 'samplingRates'] orig values: {'samplingRates': 57, 'channelMasks': 53} new values: {'samplingRates': 57, 'channelMasks': 53}
token lists identical: True
orig double-space-in-value: 0 | value with leading/trailing space: 0
new double-space-in-value: 0 | value with leading/trailing space: 0
new: trailing-whitespace lines: []
new: lines: 383 orig lines: 383
```

Also: 0 added lines contain a comma; 499 removed commas; 0 diff lines touch `sources=`, `<!--` or the
licence text; line count unchanged (383 → 383); no trailing whitespace introduced.

---

## Considered, intentionally skipped

These five were in the P5 scope. None produced a commit. Each entry quotes the round-3 or reviewer text
that decided it, because round 3 overturned earlier round-2 conclusions here and a paraphrase from memory
would be worthless to P5-R.

### 1. `target-level` stays **5** for the first build — reviewer decision, still open

**Decided by:** `analysis/port/review-P1.md:48`, Decisions table.

> `| `target-level` | **Stay at 5 for the first build** | Level 5 has an empty matrix on 23.2, so nothing can fail. Level 6 is unreachable for LTE (radio 1.4) and is shared by both models. Revisit after first boot. P5 skips the bump |`

Backing text, LEAD-SYNTHESIS §7.4 M1:

> "**Stay at 5** — zero VINTF validation, but nothing to satisfy and nothing that can fail. The radio keeps working at the 1.4 it already uses on 22.2. Requires no manifest surgery." (LEAD-SYNTHESIS.md:731-732)
>
> "This is a project call, not a technical one, and R8 — which found it — marked its own recommendation `confidence: medium` for exactly that reason. It recommends staying at 5: level 5 costs nothing at build time or runtime, and an FCM exemption is pointless for a ROM with no GMS." (LEAD-SYNTHESIS.md:737-739)

Verified in our tree, `lineage-23.2` @ `2e50286ebc01`:

- `manifest.xml:1` = `<manifest version="1.0" type="device" target-level="5">`. Unchanged.
- It is the **common** manifest, so one bump moves **both** models:
  > "So one bump in the common tree moves **both** models. 'LTE stays at 5, Wi-Fi goes to 6' would require splitting the shared manifest — a restructuring nobody has costed." (LEAD-SYNTHESIS.md:712-713)
- Level 6 would demand real work on both models: 19 unsatisfied mandatory vendor-relevant instances on the
  Wi-Fi model, 16 on the LTE model (LEAD-SYNTHESIS.md:719-720); `compatibility_matrix.5.xml` on 23.2 is a
  7-line empty file while `compatibility_matrix.6.xml` has 80 mandatory `<version>` entries
  (LEAD-SYNTHESIS.md:724-727).

**Not done, on purpose.** confidence: high on the facts; the *decision itself* is the owner's and is
explicitly marked revisitable by `review-P1.md:48`.

### 2. The `soundtrigger` block stays — R9

**Decided by:** `analysis/rom/soundtrigger-perproxy.md` (task R9), §1.4:

> "**Verdict: keep the `manifest.xml` block exactly as it is.** Deleting it does not 'prevent' a checkvintf failure; on the evidence it risks causing one, because the level-6 entry is mandatory and deleting the declaration leaves it unsatisfied." (`analysis/rom/soundtrigger-perproxy.md:210-212`)

and LEAD-SYNTHESIS §7.4 M2, which records the reversal explicitly:

> "#### M2 is also a no-op — keep the soundtrigger block
> **Reversed by R9.** R1-r2 recommended deleting the block. Do **not**." (LEAD-SYNTHESIS.md:748-750)

R9's summary, quoted:

> "**`soundtrigger`: the `manifest.xml` block must NOT be deleted.** `gts4lv.mk:58` really does build `android.hardware.soundtrigger@2.2-impl:32`, and that module exists in `hardware/interfaces`, and the 2.2 implementation is genuinely registered at boot from inside `android.hardware.audio.service`. … Deleting the block therefore risks *creating* a `checkvintf` failure instead of preventing one. **P5 item 2 becomes a no-op.**" (`analysis/rom/soundtrigger-perproxy.md:8-16`)

R9's decisive evidence is a shipping tree, not a lint result: `LineageOS/android_device_samsung_sm7125-common`
is at `target-level="6"` with `soundtrigger@2.2` declared and ships 23.2 (`analysis/rom/soundtrigger-perproxy.md:191-208`).

Verified in our tree, `lineage-23.2` @ `2e50286ebc01`: `manifest.xml:102-110` still holds the
`<hal format="hidl">` block for `android.hardware.soundtrigger`, `<version>2.2</version>` on line 105.
`gts4lv.mk:58` still builds the 2.2 impl. Untouched.

confidence: high on the conclusion (backed by a shipping 23.2 tree and by `checkvintf` being a hard build
gate). R9 itself is explicit that the *mechanism* — a frozen matrix superseding the level-6 entry — is
`confidence: medium` because `system/tools/vintf` is not clonable (LEAD-SYNTHESIS.md:761-766).

### 3. No `per_proxy_helper` sepolicy label — R9

**Decided by:** `analysis/rom/soundtrigger-perproxy.md` §2.4 and §2.2.

> "**Path search: 0 hits** in either vendor repo for `per_proxy_helper`, `perproxy`, `per_proxy`." (`analysis/rom/soundtrigger-perproxy.md:283`)
>
> "An unlabelled `exec_type` that no file ever gets is **inert**: `domain_auto_trans(init, $1_exec, $1)` simply has nothing to match, so no process is ever transitioned. There is no `neverallow`, no unused-type and no unmatched-regex build check in `system/sepolicy`'s `checkfc` for this. Nothing at boot can fail because of it." (`analysis/rom/soundtrigger-perproxy.md:309-312`)

R9's own instruction to P5, quoted:

> "**Do not add a `file_contexts` line.** There is no blob for it to label (§2.2)." (`analysis/rom/soundtrigger-perproxy.md:398`)

LEAD-SYNTHESIS §7.4 M2b adds that the domain is *provably* dead: 0 path hits and 0 content hits across both
vendor repos, absent from all 34 `vendor/bin/**` rows of `proprietary-files.txt`
(LEAD-SYNTHESIS.md:775-777), so **no `file_contexts` line** was drafted.

R9 also offers deleting `sepolicy/vendor/per_proxy_helper.te` as optional dead policy. I did **not** delete
it either: it is outside the P5 scope list, and R9 itself says "leaving it is equally safe and smaller"
(`analysis/rom/soundtrigger-perproxy.md:341-343`, `confidence: medium`). If the owner wants the 8 dead
lines gone, that is a one-line follow-up commit and it must not be described as fixing a runtime failure.

Verified in our tree, `lineage-23.2` @ `2e50286ebc01`: `sepolicy/vendor/per_proxy_helper.te` exists with
its 5 content lines (`:1`, `:2`, `:4`, `:6`, `:8`), and `git grep -n per_proxy lineage-23.2 -- sepolicy/`
returns **only** those 5 lines — i.e. there is still no `file_contexts` entry, which is the intended state.
`grep -c proxy sepolicy/vendor/file_contexts` → 0.

confidence: high.

### 4. Vendor property names unchanged — R7

**Decided by:** `analysis/rom/property-namespace.md` (task R7) §6.

> "### Smallest fix: **none. Change nothing.**
> Do not set `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` — it buys nothing (the check is not running) and it would add a second, permanent suppression on top of the API-level exemption.
> Do not rename the properties." (`analysis/rom/property-namespace.md:211-215`)

The condition, quoted from the pinned source:

> "```go
> shippingApiLevel := ctx.DeviceConfig().ShippingApiLevel()
> ApiLevelQ := android.ApiLevelOrPanic(ctx, "Q")
> if (ctx.SocSpecific() || ctx.DeviceSpecific()) && shippingApiLevel.GreaterThanOrEqualTo(ApiLevelQ) {
>     builtCtxFile = m.checkVendorPropertyNamespace(ctx, builtCtxFile)
> }
> ```" (`analysis/rom/property-namespace.md:72-77`, from `build/soong/selinux_contexts.go:419-423` @ `885cc500f607`)

`Q` = 29 and our level is 28, so `28 >= 29` is false and the check never runs (LEAD-SYNTHESIS.md:802-808).
Re-verified the level myself: `gts4lv.mk:18` @ `2e50286ebc01` is
`$(call inherit-product, $(SRC_TARGET_DIR)/product/product_launched_with_p.mk)`, and that file's line 2 is
`PRODUCT_SHIPPING_API_LEVEL := 28` (read from the tree at `e5aaa62172df`).

R7 also names the one rename that would actively hurt, quoted:

> "That one **must not** be renamed: it is a platform property read by name in `system/core/init/reboot.cpp:1111` @ `eb2de7321317` … Renaming it to `ro.vendor.fastbootd.available` would build cleanly and silently break the `adb reboot fastboot` → bootloader fallback." (`analysis/rom/property-namespace.md:221-224`)

R7's watch-item, quoted, because it is the one thing here that can change under us:

> "**The thing to actually watch is the shipping API level, not the property names.** Any patch that sets `PRODUCT_SHIPPING_API_LEVEL` to 29+ anywhere in the chain … silently turns this check on and the build starts failing." (`analysis/rom/property-namespace.md:261-264`)

Verified in our tree, `lineage-23.2` @ `2e50286ebc01`: `sepolicy/vendor/property_contexts` is present and
untouched; no `BUILD_BROKEN_VENDOR_PROPERTY_NAMESPACE` added anywhere.
confidence: high.

### 5. LTE radio stays 1.4 — R8

**Decided by:** `analysis/rom/radio-hal.md` (task R8).

> "**No. The vendor RIL does not implement `android.hardware.radio` 1.5.** The blob that registers the HIDL service, `proprietary/vendor/lib64/libril.so`, has `DT_NEEDED` on `android.hardware.radio@1.0.so` … **`@1.4.so` and on nothing at 1.5/1.6**; the only HIDL descriptors it carries are `android.hardware.radio@1.1|1.2|1.3|1.4::IRadio`, and the impl classes stop at `RadioImpl_V1_4` (`V1_5`/`V1_6` occur **0** times)." (`analysis/rom/radio-hal.md:5-8`)

> "**Three independent blockers** on M3 (LTE `radio` 1.4 → 1.5), not one: (1) the RIL caps at 1.4; (2) the qcom-caf vendor-matrix fragment declares `android.hardware.radio` at **`1.0-4`**, so 1.5 is *outside* the range our own build installs; (3) level 6 makes 1.5-6 mandatory (`compatibility_matrix.6.xml:451-460`)." (`analysis/rom/radio-hal.md:12-14`)

LEAD-SYNTHESIS §7.4 lists it as impossible rather than optional:

> "| **M3** | **Impossible** — the RIL caps at radio 1.4. Do not bump | `gts4lv/manifest.xml:5` |" (LEAD-SYNTHESIS.md:698)

Verified myself, both halves:

- **The file is not in our fork.** `git grep -n 'android.hardware.radio' lineage-23.2` in
  `~/work/dt` → **0 hits**. The LTE radio declaration lives in the per-model repo
  `LineageOS/android_device_samsung_gts4lv`, whose `manifest.xml:5` is
  `<fqname>@1.4::IRadio/slot1</fqname>` (read in `~/work/clone-R6/dev-gts4lv` @ `3260fd2c4f1a`,
  branch `lineage-22.2`). So even if 1.5 were possible, P5 has no file to edit in this repository.
- **The ceiling is real.** `~/work/clone-R6/caf232` @ `1805784d14b3`,
  `vendor_framework_compatibility_matrix.xml:249-253` declares `android.hardware.radio` at `<version>1.0-4</version>`,
  so 1.5 is above the range our own build installs.

Note `android.hardware.radio.config` has the same shape: the RIL serves 1.1 and does not register the 1.2
it links, so `gts4lv/manifest.xml` cannot be bumped either (LEAD-SYNTHESIS.md:852-853) — same conclusion,
same reason.
confidence: high.

---

## Self-check (real output)

```
$ git -C ~/work/dt log --oneline lineage-23.2..origin/port/dt
e3ccc92 P5: audio: use space-separated policy lists

$ git -C ~/work/dt log -1 --format=%h lineage-23.2
2e50286

$ git -C ~/work/dt ls-remote origin 'refs/heads/port/dt' 'refs/heads/lineage-23.2' 'refs/heads/lineage-22.2'
d1b339be7abea07f62fef2bee3b7a2006694df67	refs/heads/lineage-22.2
2e50286ebc01070c11be5e618ee557a6073709ff	refs/heads/lineage-23.2
e3ccc923bcf225482a0cc5fa5d92b1257dadf3b8	refs/heads/port/dt

$ cd ~/work/dt && xmllint --noout audio/configs/audio_policy_configuration.xml; echo "exit=$?"
exit=0

$ grep -cE '(samplingRates|channelMasks|formats)="[^"]*,' audio/configs/audio_policy_configuration.xml
0

$ git -C ~/work/dt diff HEAD~1 --stat
 audio/configs/audio_policy_configuration.xml | 158 +++++++++++++--------------
 1 file changed, 79 insertions(+), 79 deletions(-)
```

Comma counts in `audio/configs/audio_policy_configuration.xml`, before and after:

| | before | after |
|---|---|---|
| lines with a comma inside `samplingRates`/`channelMasks`/`formats` | **79** | **0** |
| commas inside those three attributes | 499 | 0 |
| commas elsewhere (`sources=`, comments) | 84 | 84 |
| commas in the file, total | 583 | 84 |

`git status --porcelain` after the commit was empty. No PR was opened. `lineage-23.2` was checked out,
branched from and never pushed to; the push created `port/dt` only.

## Problems

None. One deviation from the task prompt worth recording for the lead: the prompt's self-check list did not
include `git status --porcelain`, and I ran `git log -1 --format=%h lineage-23.2` while on `port/dt`,
which is why the `lineage-23.2` tip check above is a no-op by construction — the `ls-remote` output is the
one that actually proves the remote branch did not move.