# Drafts for luk1337's 4.19 port (issue #7)

`git format-patch` from the eval tree (`device/samsung/gts4lv-common`, branch `eval-419` on luk's `8f83e07`, author Anton Scholten).
Charter format: `Assisted-by: LLM - Claude Opus 5.5`, Change-Id, SPDX on new files. **Drafts: the owner reviews
each one before sending.** Apply with `git am`.

| Patch | UPSTREAM.md | Tested on his build |
|---|---|---|
| 0001 Allow app bubbles alongside desktop windowing | L4 | Yes, 20261115 |
| 0002 Fit the keyguard user avatar into the status bar | L5 | Yes, 20261115 |

L1 (qseecomd gatekeeper write) was dropped: luk made the same change in his `b485746` (2026-11-15).
L6 (auto-rotate/auto-brightness defaults) was dropped: luk does not want it (2026-11-15).
