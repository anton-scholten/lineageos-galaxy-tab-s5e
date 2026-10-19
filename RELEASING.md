# Releasing (with OTA updates)

How a build gets from the build drive to users, so that the LineageOS **Updater** on their tablets offers it.

## How OTA works here

- Every build carries `lineage.updater.uri` (device tree `system.prop`), pointing at a feed in this repo:
  `ota/23.2/{device}.json` or `ota/24.0/{device}.json` (`{device}` = `gts4lvwifi` / `gts4lv`). One feed per version, so
  a 23.2 tablet is never offered 24 (that move needs a wipe).
- The Updater shows a build when its `datetime` is newer than `ro.build.date.utc`, its `type` is `unofficial`
  (= `ro.lineage.releasetype`) and its SDK level is not lower. It downloads the zip from the GitHub release, verifies
  the signature against the keys in the ROM, reboots to recovery and installs; on 24 it then also updates the recovery.
- The signature only verifies if the update is signed with **the same keys** as the installed build. Builds from
  2026-10-18 on are signed with our private keys; the older test-key builds (20261008 … 20261016) cannot update to them
  over the air.

## Private keys (once)

⚠️ **Never** commit, paste, upload, print or attach the private keys (`*.pk8`). This repo's `.gitignore` blocks them;
scripts only check that the files exist. Losing them means users cannot update over the air any more and must do a
clean install with new keys, so keep an encrypted backup.

They are Android signing keys (RSA + X.509 certificate per role), not a GitHub key: GitHub only holds public keys, and
SSH/GPG keys cannot sign Android builds.

1. Generate them on this computer, outside any repo (press **Enter** at the password prompt: inline signing needs
   unencrypted keys; the backup in step 3 is what gets encrypted):
   ```bash
   cd /mnt/build/lineage-24
   subject='/C=US/O=Galaxy Tab S5e LineageOS/CN=Galaxy Tab S5e LineageOS'
   mkdir -p ~/.android-certs && chmod 700 ~/.android-certs
   for cert in bluetooth cyngn-app media networkstack nfc platform releasekey sdk_sandbox shared testcert testkey verity; do ./development/tools/make_key ~/.android-certs/$cert "$subject"; done
   ```
   The subject ends up in the public certificates: keep it generic (no personal email).
2. Install them into both build trees (inline signing: `vendor/lineage/config/common.mk` includes
   `vendor/lineage-priv/keys/keys.mk`):
   ```bash
   for t in /mnt/build/lineage-23.2 /mnt/build/lineage-24; do mkdir -p $t/vendor/lineage-priv && cp -r ~/.android-certs $t/vendor/lineage-priv/keys && echo 'PRODUCT_DEFAULT_DEV_CERTIFICATE := vendor/lineage-priv/keys/releasekey' > $t/vendor/lineage-priv/keys/keys.mk; done
   ```
3. Back them up encrypted, off this computer (USB stick, cloud drive), with the passphrase in a password manager:
   ```bash
   tar -C ~ -czf - .android-certs | gpg --symmetric --cipher-algo AES256 -o ~/android-certs.tar.gz.gpg
   ```
   Restore: `gpg -d android-certs.tar.gz.gpg | tar -C ~ -xzf -`, then step 2.

`scripts/build-all.sh` refuses to build without the keys and fails a build that is not `release-keys`.

## Every release

1. **Build**: `scripts/build-all.sh` (or `ONLY="24.0:gts4lvwifi 24.0:gts4lv" scripts/build-all.sh`). It checks every
   fork and the keys first, verifies the release settings afterwards, and copies zip, recovery, vbmeta and `SHA256SUMS`
   to `/mnt/build/releases/<version>-<date>/`.
2. **Test** at least the Wi-Fi zip on the tablet (an OTA from the previous release is the best test, see below).
3. **Notes**: `release/NOTES-<version>-<date>.md`, same layout as the previous release; say whether a wipe is needed.
4. **Draft** the GitHub release, tag `v<version>-<zip date>` (the date in the zip name), title
   `<YYYY-MM-DD> - LineageOS <version> (unofficial)`, all files of the folder:
   ```bash
   cd /mnt/build/releases/<version>-<date>
   gh release create v<version>-<zipdate> --draft --target main --title "<date> - LineageOS <version> (unofficial)" --notes-file <repo>/release/NOTES-<version>-<date>.md lineage-*.zip recovery-*.img vbmeta-*.img SHA256SUMS
   ```
5. **Publish** the release (owner).
6. **OTA feed**, only after publishing (the download URLs must exist):
   ```bash
   scripts/ota-json.sh /mnt/build/releases/<version>-<date> v<version>-<zipdate>
   git add ota/ && git commit -m "OTA: <version>-<zipdate>" && git push
   ```
   Tablets see the update within minutes (raw.githubusercontent.com caching), via Settings → System → Updater.
7. **Check** on a tablet on the previous build: Updater → refresh → the new build appears, downloads, installs, boots.

If a release is broken: revert the commit that changed `ota/<version>/<device>.json` (the Updater only offers what the
feed lists) and fix forward.
