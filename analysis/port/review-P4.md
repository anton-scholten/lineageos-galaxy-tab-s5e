<!-- review: P3-R + P4-R + P5-R | reviewer: strong model (Claude) | date: 2026-10-04 -->
# Review of P3, P4 and P5

**Verdict: all three pass, with no rejections.** The ported kernel builds, and the device-tree change is sound.
Both forks' `lineage-23.2` can be fast-forwarded (RUNBOOK §7):
- kernel `port/pick` @ `801f3f20e54a`;
- device `port/dt` @ `e3ccc923bcf2`.

## Independent build check
The reviewer rebuilt `port/pick` @ `801f3f20e54a` from scratch in a separate environment, with `analysis/build-test/kbuild.sh` and
`gts4lvwifi_defconfig` (Ubuntu clang 18.1.3, unversioned `llvm-*` tools present):
- `Image.gz-dtb` built, 18,731,172 bytes, **0 errors**, 20 warnings;
- `.config` has `CONFIG_SCHED_WALT`, `CGROUP_SCHED`, `FAIR_GROUP_SCHED`, `BPF_SYSCALL`, `BPF_LSM`, `UPROBES`, `BPF_JIT`, `UNICODE` and `DEBUG_INFO_BTF` all `=y`;
- `include/generated/vdso-offsets.h` has `vdso_offset_sigtramp 0x0810`, a real offset (the lead's "silently wrong vDSO" trap didn't happen).

This matches P4's own result. `gts4lv_defconfig` wasn't rebuilt here; P4's log reports it linking too.

## P3 (6 commits) and the ruling it asked for
All six match the spec. One deviation, accepted: P3 found a **sixth** old-style caller the spec missed,
`drivers/tty/serial/msm_geni_serial.c:2793`, and passed `&pdev->dev` instead of `NULL`.
**Ruling: `&pdev->dev` is correct.** It's a probe-time device that is already registered, so the new API parents the wakeup source under it
(`drivers/base/power/wakeup.c:302`). That's how upstream converted driver callers. `NULL` is right only where there's no device (the other five).

## P4 (14 commits)
Every commit was read. All use allowed fix types, and none touches the forbidden areas:
| Commit | What | Verdict |
|---|---|---|
| `5078de1ee` | arm64 selects `BPF_ARCH_SPINLOCK` | OK. The alternative was editing `kernel/bpf/`. The `select` sits under `config SMP`; moving it to the `config ARM64` select list would be tidier, but that's cosmetic and not required |
| `56a6f0373` | binder LSM hooks take `const struct cred *` | OK. Matches sdm670's binder/SELinux, which already use creds (the 4.9 CVE backport) |
| `a7f561e7e`, `d078fd143` | fuse-bpf calls adapted to 4.9's `fuse_req_init_context(req)` and two-argument `vfs_getattr()` | OK. Loses only the statx mask, which fuse-bpf passes through as 0 |
| `238647ed4` | `atomic_inc(&tmp_ref)` | OK. Matches sdm670's `atomic_t` |
| `6996e6845` | `include/linux/unicode.h` from the series head | OK. The P3 spec missed this header (reviewer's error) |
| `1cb9785b0` | `task_util_est()` → WALT `task_util()` | OK, exactly as decided in review-P1.md |
| `1c21d6589` | DRM `IN_FORMATS` property and declarations | OK. Harmless: nothing uses the blob yet. The full modifier series isn't needed for boot |
| `f58d0181a` | braces restored in `sugov_update_single()` | OK. Matches upstream |
| `618c893a7` | `u32 data[]` → `u32 *data` in two SDE tracepoints | OK. Same ABI |
| `d1ff974a4` | `bpf_probe_read_str` arg types after the rename | OK. Upstream values |
| `c8f303aba`, `62e4f2ade`, `801f3f20e` | BPF tracepoint arity 12 → 18 | OK. A generic, backward-compatible extension needed for long Qualcomm tracepoints |

## P5 (1 commit on `port/dt`)
79 `samplingRates`/`channelMasks` lists in `audio/configs/audio_policy_configuration.xml` go from comma- to space-separated. `xmllint` is clean.
R6's open question (does the parser accept spaces?) is answered as well as it can be without a build:
`LineageOS/android_device_samsung_sm7125-common` `lineage-23.2` uses space-separated lists with **zero** comma lists.
Caveat: sm7125 uses audio HAL 7.0, while gts4lv uses 6.0. **Check audio on first boot** (playback, mic, and `logcat | grep -i AudioPolicy` for profile errors).
The five skipped items are logged correctly in `P5-log.md`.

## Carried forward to first boot (not blockers)
- Audio profiles parse with spaces under HAL 6.0 (above).
- lmkd without `process_mrelease` (`logcat -s lmkd`).
- The silent-scheduler risk is closed: `CGROUP_SCHED` and `FAIR_GROUP_SCHED` are on, and WALT builds.
