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
| L7 build loop | ⬜ | `port/l24-dt-<n>` | Blocked on L4 sync |
| L8 boot attempts | ⬜ | `boot-24-<n>.md` | |
| L9 LTE radio (strong only) | ⛔ | | Blocked on decision: radio@1.4 vs FCM 7, no device-tree fix |
| L10 testing | ⬜ | `L10.md` | |
| L11 release | ⬜ | draft release | |

### 2026-10-10: state of the world

- **Drive**: moved `sda` → `sdb` (WDC WD1002FAEX). Tree is at `/mnt/build/lineage-24`; no bind mount for it,
  one `sudo mount /dev/sdb /mnt/build` covers both trees. See [MOVING-THE-DRIVE.md](../../MOVING-THE-DRIVE.md).
- **Sync: complete and verified.** `repo sync -c -j4` finished successfully. Base pin `2a50ca061bffe`.
  `prebuilts/sdk` and `prebuilts/rust-toolchain/linux-x86` needed manual `git checkout -f` after the copy
  was interrupted; both clean now.
- **Device tree**: local branch `l24` @ `5af53f1` in the tree (= `port/l24-dt-1`). Carries FCM 7.
- **Next: L7, the first build.** Not started. ~315 GB free of the ~300 GB `out/` needs, on a spinning disk
  (6.3 MB/s). Moving `out/` to the internal NVMe (396 MB/s) is worth doing first.
- **L9 is blocked**, not merely unstarted: `libril.so` hard-depends on `radio@1.4.so`, which FCM 7 does not
  allow. Needs a strong-model decision. Wi-Fi model unaffected.
