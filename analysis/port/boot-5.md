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

## device-checks.sh (16 min uptime)
4 PASS, 1 FAIL, 1 SKIP. The FAIL (`3-netd`: "dumpsys netd: Can't find service") is a **false alarm in the script**:
`service list` shows `netd` and `android.system.net.netd.INetd/default`, netd runs, and Wi-Fi is validated. Android 16
doesn't let the shell dump netd. `dumpsys connectivity` → "Bpf Program Status" shows all 14 cgroup BPF programs attached
(INET ingress/egress, sock create/release, bind/connect v4/v6, UDP send/recvmsg, get/setsockopt).
SKIP (`2-bpf-fs`): no `su`. Follow-up: change check 3 to use `service check netd` + `dumpsys connectivity`.
Owner reports: microphone, camera, speakers and Wi-Fi all work.
