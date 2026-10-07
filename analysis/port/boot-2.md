# boot-2 (2026-10-07): first full 23.2 ROM boot → Download mode

| | |
|---|---|
| Zip | `lineage-23.2-20261006-UNOFFICIAL-gts4lvwifi.zip`, sha256 `691512f3…473d029f` (+ MindTheGapps 16.0.0 arm64 20260915) |
| Kernel | `4.9.337-g500658be3c16` (`last_kmsg` line 1707) |
| Device tree | `d154fb4384fb` |
| Log | `/proc/last_kmsg` read from the 23.2 recovery. Full file kept locally in `~/work/boot-1/` (contains the serial) |
| Result | Same failure on both boot attempts in the buffer (lines 316–335 and 4886–4900) |

## How far it got
The kernel, first-stage init and SELinux (split policy, 80070 rules) are all fine. Second-stage init parses every `.rc`,
then dies in `early-init` at 3.13 s, before anything else runs (bpfloader/netd never start).

## The failure (last_kmsg 316–335, 466, 508)
```
<14>[    3.105564]  [6:           init:    1] init: Parsing file /product/etc/init/init.openssh.rc...
<14>[    3.106626]  [6:           init:    1] init: processing action (SetupCgroups) from (<Builtin Action>:0)
<11>[    3.109073]  [6:           init:    1] libprocessgroup: Failed to mount controller schedtune: No such file or directory
<11>[    3.109143]  [6:           init:    1] libprocessgroup: Failed to setup schedtune cgroup
<14>[    3.109218]  [6:           init:    1] init: Command 'SetupCgroups' action=SetupCgroups (<Builtin Action>:0) took 2ms and failed: Failed to setup cgroups: No such file or directory
<14>[    3.111538]  [6:           init:    1] init: processing action (TestPerfEventSelinux) from (<Builtin Action>:0)
<14>[    3.111808]  [6:           init:    1] init: processing action (early-init) from (/system/etc/init/hw/init.rc:15)
<14>[    3.117410]  [6:           init:    1] init: starting service 'ueventd'...
<11>[    3.120407]  [6:           init:    1] libprocessgroup: Failed to make and chown /sys/fs/cgroup/system/uid_0: No such file or directory
<14>[    3.122351]  [6:           init:    1] init: Command 'exec_start init_dev_config' action=early-init (/system/etc/init/hw/init.rc:79) took 0ms and failed: Could not start exec service: Cannot expand path: property 'ro.vendor.init_dev_config.path' doesn't exist while expanding '${ro.vendor.init
<14>[    3.123110]  [6:           init:    1] init: starting service 'apexd-bootstrap'...
<11>[    3.125661]  [6:           init:    1] libprocessgroup: Failed to make and chown /sys/fs/cgroup/system/uid_0: No such file or directory
<10>[    3.125905]  [6:           init:  458] init: Service 'apexd-bootstrap' failed to start due to a fatal error
<10>[    3.127155]  [0:           init:  457] init: Service 'ueventd' failed to start due to a fatal error
<14>[    3.127213]  [6:           init:    1] init: Command 'exec_start apexd-bootstrap' action=early-init (/system/etc/init/hw/init.rc:84) took 4ms and failed: Could not start exec service: createProcessGroup(0, 458, 0) failed for service 'apexd-bootstrap': No such file or directory
<14>[    3.127395]  [6:           init:    1] init: Service 'apexd-bootstrap' (pid 458) exited with status 6 oneshot service took 0.001000 seconds in background
<14>[    3.127482]  [6:           init:    1] init: Sending SIGKILL to service 'apexd-bootstrap' (pid 458) process group...
<11>[    3.127607]  [6:           init:    1] libprocessgroup: Failed to open /sys/fs/cgroup/system/uid_0/pid_458/cgroup.procs: No such file or directory
<11>[    3.127691]  [6:           init:    1] init: Service apexd-bootstrap has 'reboot_on_failure' option and failed, shutting down system.
<14>[    3.128517]  [6:           init:    1] init: Got shutdown_command 'reboot,bootloader,bootstrap-apexd-failed' Calling HandlePowerctlMessage()
<14>[   13.131944]  [0:           init:    1] init: Reboot start, reason: reboot,bootloader,bootstrap-apexd-failed, reboot_target: bootloader,bootstrap-apexd-failed
<0>[   13.259085]  [0:           init:    1] reboot: Restarting system with command 'bootloader,bootstrap-apexd-failed'
```
Note: plain `grep` treats `last_kmsg` as binary and prints nothing. Use `grep -a`.

## Cause (confidence: high)
1. `ro.product.first_api_level=28` (vendor/build.prop), so `ReadDescriptors()` also loads
   `/system/etc/task_profiles/cgroups_28.json` (`system/core/libprocessgroup/util/util.cpp:197`).
   That file declares `schedtune` (`/dev/stune`) **without** `"Optional": true`.
2. The ported kernel has `# CONFIG_SCHED_TUNE is not set` (`gts4lvwifi_defconfig:34` @ `500658be3c16`, set by
   P3's `316352012ff2`). It uses `CONFIG_UCLAMP_TASK` instead, and `init/Kconfig:1536` makes `SCHED_TUNE`
   depend on `!UCLAMP_TASK`. The 22.2 kernel (`a30605a`) had `CONFIG_SCHED_TUNE=y`. So the cgroup v1 mount with
   option `schedtune` fails with ENOENT.
3. `CgroupSetup()` returns false on the first non-optional controller that fails
   (`setup/cgroup_map_write.cpp:294`), before it creates `/sys/fs/cgroup/{apps,system}`. Every later
   `createProcessGroup()` then fails, `apexd-bootstrap` (`reboot_on_failure`) can't start, and init reboots with
   `bootloader,bootstrap-apexd-failed`. That reboot lands in Download mode.

The ExyHyperBrick origin hit the same thing: its kernel also replaced schedtune with uclamp, and krazey's device
commit `385c2db` (exynos9810-common) stopped shipping `cgroups_28.json`/`task_profiles_28.json` on vendor and ships
the platform `task_profiles.json` instead.

## Fix
Device fork, branch `port/dt-3`, commit `a7f1483`: copy AOSP's `cgroups_30.json` (identical, but `schedtune` is
`Optional`) to `/vendor/etc/cgroups.json`, and the platform (uclamp) `task_profiles.json` to
`/vendor/etc/task_profiles.json`. Vendor files are loaded last and replace same-named entries (`util.cpp:109`), so
`schedtune` becomes optional and the API-28 schedtune profiles are replaced by uclamp ones.
This doesn't switch off a check: it describes the kernel as it actually is, which is what AOSP's API-30 file does.

Not a fix: re-enabling `CONFIG_SCHED_TUNE`, which would mean dropping the uclamp port.

## Other noise in this boot (non-fatal, check later)
- `init_dev_config`: `ro.vendor.init_dev_config.path` is not set (line 325).
- `init.qcom.rc:481` / `init.qcom.power.rc:255`: `unexported property trigger` (lines 159, 164).
- `init.qcom.power.rc` still writes to `/dev/stune/*`. Those writes now fail harmlessly. Porting them to uclamp is a follow-up.
- 3 `persist.*` props in `/vendor/build.prop` are refused by SELinux (lines 119–123).
