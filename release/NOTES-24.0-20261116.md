Unofficial **LineageOS 24 (Android 17)** for the Samsung Galaxy Tab S5e. Install guide, status and known issues: [README](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e#readme).

**Coming from 24.0-20261022, 24.0-20261026, 24.0-20261105 or 24.0-20261109: update over the air** (*Settings → System → Updater*), no data is erased.

**What's new since 2026-11-09**
- **Large exFAT microSD cards (1 TB) are recognized again**: Android checks every card before mounting it and gives up after 45 s, which a big, full card can exceed, so the card was offered for formatting ([LineageOS #458](https://github.com/LineageOS/issues/issues/458)). The check now only runs when the card was not ejected cleanly, so cards also mount much faster (10 s → 1 s for a 256 GB card).
- **Quick Settings volume tile**: add *Volume* from the Quick Settings edit screen (also listed under Utilities).
- Longer haptic feedback on the LTE model, and haptics on the auto-brightness button.
- Recovery: touch and menu fixes.
- Security fixes in LineageOS profiles and LiveDisplay.
- Latest LineageOS updates.

Kernel `4.9.337-ga668db21f3cf`, device tree `adcd7eb`. Fixes owed upstream: [UPSTREAM.md](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/blob/main/UPSTREAM.md).
