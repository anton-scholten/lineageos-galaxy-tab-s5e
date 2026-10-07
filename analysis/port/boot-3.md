# boot-3 (2026-10-07): 20261007 zip → boot animation loop

| | |
|---|---|
| Zip | `lineage-23.2-20261007-UNOFFICIAL-gts4lvwifi.zip`, sha256 `5a8a4830…4211e714` (+ MindTheGapps), no format |
| Kernel / device | `-g500658be3c16` / `port/dt-3` @ `a7f1483` (cgroup fix) |
| Logs | `last_kmsg`, pstore `console-ramoops-0` and `pmsg-ramoops-0` (decoded logcat), all from the 23.2 recovery; full files in `~/work/boot-3/` |
| Result | The cgroup fix works: `/sys/fs/cgroup/system/uid_*` exist, system_server starts. One reboot, then the boot animation loops for 1 h+ |

## Finding 1: lmkd never runs (confidence: high, fix `4f4a15c`)
```
init: starting service 'lmkd'...
init: Service 'lmkd' (pid 3256) exited with status 0      (≈20 ms later, every 5 s)
```
`lmkd.cpp` `main()` exits 0 only if `init()` fails. `product.prop` sets `ro.lmk.use_minfree_levels=true`, which selects the
old kill strategy. `init_psi_monitors()` then demands memcg v1 (`lmkd.cpp:3589`), and so does the vmpressure fallback
`init_mp_common()` (`:3619`). Android 16 mounts memcg only in cgroup v2 (`cgroups.json`: `Cgroups2` → `memory`).
The kernel does have PSI with triggers (`CONFIG_PSI=y`, `kernel/sched/psi.c:1007 psi_trigger_create`).
Fix: device `port/dt-3` @ `4f4a15c` drops the old-strategy props and sets `ro.lmk.use_psi=true`, like exynos9810-common's `vendor.prop`.
system_server only retries a missing lmkd (`ProcessList.java:868`), so this is probably **not** the loop's cause.

## Finding 2: system_server dies, unknown why (open)
About every 11 s: `Service 'zygote' received SIGKILL`, followed by audioserver, cameraserver, media, netd and wificond restarting.
zygote SIGKILLs itself when system_server dies. Just before that: `avc: denied { kill } … scontext=u:r:zygote:s0 tclass=capability`
(last_kmsg 406). The Java stack trace isn't in `pmsg` (the 256 KB ring holds only the following cycle).
adb is `unauthorized` during boot (fresh data, no key; Lineage userdebug has `ro.adb.secure=1`).

Next: a debug build with `WITH_ADB_INSECURE=true` (`vendor/lineage/config/common.mk:35`: `ro.adb.secure=0`, debuggable)
plus `4f4a15c`, then `adb logcat -b crash` and `-b all` during the loop. Don't ship that build.

## Noise (non-fatal)
`userfaultfd: MOVE ioctl seems unsupported` (ART GC falls back); Aconfig `Fail to mmap storage`; APM volume curves
`invalid volume index range`; zygote `onrestart` targets that don't exist (`media.tuner`, `vendor.audio-hal-aidl`).
