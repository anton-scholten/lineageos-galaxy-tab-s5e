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
| L7 build loop | ◐ | `agent/L7` → `L7.md` | 13 rounds. 7 blockers fixed; **the kernel now configures and compiles**. host-tool OpenSSL fixed in `fe8e363` (§7k: 24.0 removed 23.2's host-openssl flags); round 14 pending |
| L8 boot attempts | ⬜ | `boot-24-<n>.md` | |
| L9 LTE radio (strong only) | ⛔ | | Blocked on decision: radio@1.4 vs FCM 7, no device-tree fix |
| L10 testing | ⬜ | `L10.md` | |
| L11 release | ⬜ | draft release | |

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
- 🔴 **L7 is blocked in the kernel's host tools.** Rounds 12 and 13 cleared the arm32 toolchain
  (`CROSS_COMPILE_ARM32` now lands from `BoardConfigCommon.mk:104` plus `local_manifests/24/gcc-arm32.xml`, device
  fork `6c8ea99`), and **the kernel now configures and compiles**. It fails building `scripts/extract-cert.c` and
  `scripts/sign-file.c`: the OpenSSL ENGINE API (`ENGINE_by_id`, `ENGINE_init`, ...) is undeclared. The kernel
  correctly includes `<openssl/engine.h>`, but `vendor/lineage`'s `HOSTCFLAGS` puts the tree's bundled
  `prebuilts/kernel-build-tools/linux-x86/include` first, and that header declares only `ENGINE_new`. The host's
  OpenSSL 3.5.7 would work - it is merely shadowed. Every relevant file is identical in both trees, yet 23.2 produced
  these binaries and the 23.2 build log is gone, so the remaining difference is not yet established. Per TASKS-L24
  §2b lesson 1, diff `prebuilts/` between the trees before blaming the environment again.
  Full evidence: [L7.md](L7.md) §7j.

- ✅ The `hardware/lineage/compat` fork works — `libwfdservice_shim` links. Our whole contribution is **one line**,
  and upstream is only 2 commits ahead (both additive), so retiring the fork later is a two-command job.
- **Disk:** ~314 GB free of the ~300 GB `out/` needs, on a spinning disk (6.3 MB/s). Tight. The internal disk is a
  SATA 860 EVO with only 22 GB free, so `out/` cannot be moved there as previously suggested.
- **L9 is blocked**, not merely unstarted: `libril.so` hard-depends on `radio@1.4.so`, which FCM 7 does not
  allow. Needs a strong-model decision. Wi-Fi model unaffected.
