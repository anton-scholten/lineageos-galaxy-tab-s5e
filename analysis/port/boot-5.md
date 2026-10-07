# boot-5 (2026-10-07): first successful boot of LineageOS 23.2 on SM-T720

| | |
|---|---|
| Zip | `lineage-23.2-20261007-UNOFFICIAL-gts4lvwifi.zip` (**debug**: `WITH_ADB_INSECURE=true`, `ro.debuggable=1`) |
| Kernel | `4.9.337-g500658be3c16` |
| Device | `port/dt-3` @ `b26a9d6` = `lineage-23.2` + `a7f1483` (cgroups) + `4f4a15c` (lmkd PSI) + `b26a9d6` (OMR as /metadata) |
| Prep | ⚠️ OMR (`mmcblk0p55`, 20 MB) formatted once from recovery: `mke2fs -t ext4 /dev/block/by-name/omr` |
| Logs | `~/work/boot-5/` (local) |

## Result
- `sys.boot_completed=1`, boot animation stopped, crash buffer empty.
- `/metadata` mounted from `mmcblk0p55`. `/metadata/aconfig/{boot,flags,maps}` populated.
- system_server stays up (same pid). lmkd stays up.
- **eBPF backport works**: NetBpfLoad loads `offload.o`, `test.o`, `clatd.o`, `dscpPolicy.o` and `netd.o` (`libbpf: 0`), then
  "done, transferring control to uprobestatsbpfload". netd runs.
- Wi-Fi enabled. audioserver runs.

## Still to do
- Owner: setup wizard, Wi-Fi connect, audio playback + mic, `scripts/device-checks.sh`, TESTING.md BPF tests, 24 h soak.
- Release build without `WITH_ADB_INSECURE`, from `port/dt-3` once it's reviewed and fast-forwarded into `lineage-23.2`.
- Flash the matching recovery (its fstab has `/metadata`) so *Format data* also wipes `/metadata`.
- `init.qcom.power.rc` still writes `/dev/stune/*`. Port those writes to uclamp (performance, not boot).
- P8 (WFD), LTE model (`gts4lv`).
