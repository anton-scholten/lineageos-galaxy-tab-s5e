# LineageOS 24 port: status

Updated by the owner or the strong model only (agents report in their own `L<n>.md`). Spec: [TASKS-L24.md](TASKS-L24.md).
Legend: ⬜ not started · ◐ in progress · ✅ done · 🔍 waiting for review · ⛔ blocked

| Task | State | Branch / output | Notes |
|---|---|---|---|
| L0 owner decision (start date, tree location) | ✅ | HANDOVER.md | Decided 2026-10-09: start now on branch tips; tree alongside 23.2 on the drive |
| L1 reference-tree changes | ✅ | `agent/L1` @ `36ffe11` | 96 rows: 6 yes, 9 unsure, 81 no. Kernel change: no |
| L2 FCM 7 audit | ✅ | `agent/L2` @ `4ff92c2` | 3 findings, **none break the build** (checkvintf COMPATIBLE) |
| L3 Android 17 legacy-device facts | ✅ | `agent/L3` @ `4ed0735` | No new L6 work; watch-list for L7/L8 |
| review L1–L3 (strong) | ✅ | `review-L1-L3.md` | L6 = 4 commits, not 7. VINTF drops withdrawn |
| L5 branches + manifests | ✅ | `lineage-24.0` on 3 forks, `local_manifests/24/` | Pushed, owner approved. All at the 23.2 SHA |
| L6 device-tree port | ✅ | `port/l24-dt-1` @ `5af53f1` | 4 commits, +10/−5 |
| L4 source tree | ✅ | `L4.md` | Commands written, **sync not started** |
| L7 build loop | ✅ DONE | `agent/L7` → `L7.md` | **ROM BUILT** — 16 rounds, 1.1 GB OTA zip, `unzip -t` clean (§7n). Next: B2 flash/boot |
| L8 boot attempts | ◐ | `boot-24-1.md`, `boot-24-2.md` | boot-24-2: vold half works, init half missing. Fixed in `android_system_core` `40a6fdb6d` (+ D2 sepolicy); **build 18 running** (no WITH_ADB_INSECURE), then boot-24-3 |
| L9 LTE radio (strong only) | ⛔ | | Blocked on decision: radio@1.4 vs FCM 7, no device-tree fix |
| L10 testing | ⬜ | `L10.md` | |
| L11 release | ⬜ | draft release | |

### 2026-10-12 (evening): build 17 with the vold fix, and boot-24-2

- ✅ **Build 17 succeeded**: `mka bacon -k 0` with `WITH_ADB_INSECURE=true`, **1 h 29 m 36 s**, 314 steps, 0 `FAILED:`.
  Zip `lineage-24.0-20261012-UNOFFICIAL-gts4lvwifi.zip`, 1,162,216,299 B, sha256 `1b1eb16a43bf91d782500cc343cdca893b5dd48a58c9e323d35b5a534a8dd1d3`,
  `unzip -t` clean. Kernel `4.9.337-g500658be3c16`. `/data` keeps `fileencryption=ice`; `/metadata` still OMR.
  vold's fallback string and `libkeyutils.so` are both in the image.
- ❌ **boot-24-2 still fails at `post-fs-data`, 15.34 s, but with a new error**: `Unable to find device keyring: Required key not
  available`. The old `Inappropriate ioctl for device` (ENOTTY) is **gone**, so the vold revert does what it was meant to.
- 🔴 **Root cause found.** AOSP removed the old-kernel session-keyring workaround in **three commits in two repos**; only one is
  restored. `5d7c35ce205f` ("init: remove session keyring workaround for old kernels", `system/core`) and `6dce39d61cf75`
  ("Remove libkeyutils", `system/core/libkeyutils`) are still in place, so **nothing creates the `"fscrypt"` keyring** that vold's
  `KeyUtil.cpp:291` searches for. Neither "Keyring created" nor "Keyring is already created" appears in the log, confirming it.
  Details, evidence and the (unapplied) fix: [boot-24-2.md](boot-24-2.md).
- ✅ **The 23.2 recovery installs 24 zips — proven twice.** README's "not tested" caveat is now wrong.
- ⚠️ `boot-log.sh`'s kernel-tag check false-alarms on a 524,288-byte `/proc/last_kmsg` cap; the script was not changed.
- Open for the strong model: where `libkeyutils` should live (the vold fork carries a private copy under `system/vold/libkeyutils/`).
  Restoring it needs a `system/core` fork and build 18 (~2–3 h, not the 1 h 30 m of build 17).

### 2026-10-10: state of the world

- **Drive**: WDC WD1002FAEX, now **`/dev/sdd`** on the current host (was `sda`, then `sdb`; the letter depends on plug
  order). Mounted at `/mnt/build` by UUID in `/etc/fstab`, so the letter no longer matters. Tree is at
  `/mnt/build/lineage-24`; no bind mount for it, so one mount covers both trees. See
  [MOVING-THE-DRIVE.md](../../MOVING-THE-DRIVE.md).
- **Sync: complete and verified.** `repo sync -c -j4` finished successfully. Base pin `2a50ca061bffe`.
  `prebuilts/sdk` and `prebuilts/rust-toolchain/linux-x86` needed manual `git checkout -f` after the copy
  was interrupted; both clean now.
- **Device tree**: local branch `l24` @ `5af53f1` in the tree (= `port/l24-dt-1`). Carries FCM 7.
- **L7 is moving: three Soong-bootstrap blockers found and fixed.** Each round died in ~1–2 min at bootstrap
  before compiling device code. Round 4 is past bootstrap and compiling.
  - R1 `hardware/qcom-caf/sdm845` namespace — fixed by `local_manifests/24/caf-sdm845.xml`.
  - R2 `libheif` — removed from `frameworks/av` in 24.0, but in `libwfdcommonutils.so`'s `DT_NEEDED`.
    Owner chose to re-add the 56 KB module rather than ship a stale `.so`. Restored as `device/samsung/
    gts4lv-common/libheif` on `port/l24-dt-2` @ `495967f`, sources verbatim from 23.2.
  - R3 `libshim_wfdservice` pulled AIDL `types` V4 while `libmedia_headers` now gives V5. Bumped to V5 @
    `0c5823a`; `AudioPort.aidl` (the only type the shim names) is byte-identical between the two versions.
- ⚠️ **The dominant risk in this port is the blob/platform age gap (22.2 blobs vs 24.0 platform), not FCM 7.**
  Two consecutive rounds died the same way: Android 17 deleted platform code the blobs still link against. Expect
  more. `review-L1-L3.md`'s "the work is device tree only" does not account for this at all.
- ✅ **L7 is DONE — LineageOS 24 builds.** Round 16 produced
  `lineage-24.0-20261012-UNOFFICIAL-gts4lvwifi.zip` (1,162,543,364 bytes) in 1h26m; `unzip -t` reports no errors.
  Contents are a complete OTA block package (`system.new.dat.br`, `boot.img`, `vbmeta.img`, transfer lists,
  `otacert`). Both round-15 blockers are confirmed fixed: §7l `KCFLAGS` (`c2fe044`) and §7m `libaudiobase` in
  `libwfdmmsrc_system` (`1e0cce7`) — the latter was the exact target that failed round 15 at 90%.

  Next task is **B2** (`analysis/port/B2-HANDOFF.md`): flash and first boot. Nothing about this ROM has been tested
  on hardware. Evidence: [L7.md](L7.md) §7n.

- ✅ The `hardware/lineage/compat` fork works — `libwfdservice_shim` links. Our whole contribution is **one line**,
  and upstream is only 2 commits ahead (both additive), so retiring the fork later is a two-command job.
- **Disk:** ~314 GB free of the ~300 GB `out/` needs, on a spinning disk (6.3 MB/s). Tight. The internal disk is a
  SATA 860 EVO with only 22 GB free, so `out/` cannot be moved there as previously suggested.
- **L9 is blocked**, not merely unstarted: `libril.so` hard-depends on `radio@1.4.so`, which FCM 7 does not
  allow. Needs a strong-model decision. Wi-Fi model unaffected.
