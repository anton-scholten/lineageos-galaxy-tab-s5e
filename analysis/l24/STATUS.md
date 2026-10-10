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
| L7 build loop | ◐ | `agent/L7` → `L7.md` | Round 1 blocked at Soong bootstrap (CAF/sdm845). Fixed via manifest; round 2 pending |
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
- **Next: L7 round 2.** Round 1 ran 2m09s and died at Soong bootstrap, not a compile error: LineageOS dropped all
  CAF support for SDM845 in `android @ a462d457ca85`, and the vendor blobs import the now-missing
  `hardware/qcom-caf/sdm845` namespace. Fixed with `local_manifests/24/caf-sdm845.xml` (pins the three CAF repos at
  their newest upstream revision, `lineage-23.2-caf-sdm845`; **no 24.0 CAF branch for this SoC exists**).
  Synced and verified against the 23.2 tree. Details and the known 23.2-CAF-on-24.0-platform risk: [L7.md](L7.md).
- ⚠️ **`review-L1-L3.md`'s "the work is device tree only" is incomplete.** L1 compared device trees; nobody compared
  the CAF manifest snippet, which is where the platform dropped SDM845. Do not rely on that sentence.
- **Disk:** ~314 GB free of the ~300 GB `out/` needs, on a spinning disk (6.3 MB/s). Tight. The internal disk is a
  SATA 860 EVO with only 22 GB free, so `out/` cannot be moved there as previously suggested.
- **L9 is blocked**, not merely unstarted: `libril.so` hard-depends on `radio@1.4.so`, which FCM 7 does not
  allow. Needs a strong-model decision. Wi-Fi model unaffected.
