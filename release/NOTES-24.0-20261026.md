Unofficial **LineageOS 24 (Android 17)** for the Samsung Galaxy Tab S5e. Install guide, status and known issues: [README](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e#readme).

**Coming from 24.0-20261019 or 24.0-20261022: update over the air** (*Settings → System → Updater*), no data is erased.

**What's new since 2026-10-22**
- **Keyboard cover and USB keyboards/mice work right away again after a long sleep.** Was caused by a kernel change that flooded Android's device service with "CPU online" messages every time the tablet woke up, so new devices could appear minutes late. Removed in the kernel.
- **Lock screen account picture no longer cut off** at the top and bottom in the top-right corner.
- **Chromium WebView 156** (security fixes for web content shown inside apps).
- **More mobile carriers set up automatically** (LTE): the APN list now includes Google's Pixel APN list.
- Latest LineageOS updates for Bluetooth and Samsung hardware support.

Kernel `4.9.337-ga668db21f3cf`. Fixes owed upstream: [UPSTREAM.md](https://github.com/anton-scholten/lineageos-galaxy-tab-s5e/blob/main/UPSTREAM.md).
