# boot-4 (2026-10-07): debug build (`WITH_ADB_INSECURE=true`, device `4f4a15c`) → system_server loop

Logs: `adb logcat -b crash/-b all` during the loop (`~/work/boot-4/`, local only).

## Cause (confidence: high)
system_server dies about every 5 s in `AppOpsService.systemReady`:
```
java.lang.IllegalStateException: Missing permission definition for permission "android.permission.RANGING" associated with app op 151
  at com.android.server.permission.access.appop.AppOpService.createPermissionAppOpMapping(AppOpService.kt:128)
```
- `RANGING` is declared only when the aconfig flag `android.permission.flags.ranging_permission_enabled` is on
  (`frameworks/base/core/res/AndroidManifest.xml:2557-2562`). App op 151 maps to it regardless.
- Flag reads fail everywhere: `AconfigStorageReadException: ERROR_CANNOT_READ_STORAGE_FILE: Fail to mmap storage`.
- The tablet has **no `/metadata`**: there's no such partition in `by-name`, nothing in `fstab.qcom`, and `ls /metadata` says no such file.
  aconfigd keeps its boot flag storage in `/metadata/aconfig` (`aconfigd_commands.rs:27`, `aconfigd.rc:26-37`), so it never exists.
- krazey hit the same thing on exynos9810. Commit `e10756f` says "LineageOS no longer falls back to legacy aconfig storage
  when /metadata is absent". He repurposed the physical ODM partition as `/metadata` (first-stage mount,
  `BOARD_USES_METADATA_PARTITION := true`, `metadata_block_device` label, recovery symlink).

## lmkd
Couldn't check: the loop happens before boot completes. Check it on the next boot.

## Decision (2026-10-07): OMR as /metadata
Official precedent: LineageOS `exynos9820-common` `b6a153f` ("Use omr as /metadata", Tim Zimmermann, 2022). That's an
official 23.2 tree for Pie-launched Samsung devices. On gts4lv nothing uses OMR: the stock-imported label
`omr_block_device` has no rules, and no vendor blob references it.
Device `port/dt-3` @ `b26a9d6`: `BOARD_USES_METADATA_PARTITION := true`; fstab
`/dev/block/by-name/omr /metadata ext4 … wait,first_stage_mount,formattable,check`; label → `metadata_block_device`.
First-stage init skips a formattable partition that won't mount (`first_stage_mount.cpp:639`), and the 23.2 zip doesn't
flash recovery. So ⚠️ OMR must be formatted once from recovery (`mke2fs -t ext4 /dev/block/by-name/omr`) before
sideloading. Later, flash the matching recovery so *Format data* also wipes `/metadata` (`wipe_data.cpp`).
Sources: <https://github.com/LineageOS/android_device_samsung_exynos9820-common/commit/b6a153f436c88d8ef73a24d711a8db5cd7500b4e>,
krazey `exynos9810-common` `e10756f` (ODM as /metadata), konstakang RPi4 23.2 changelog ("add metadata partition for new aconfig storage").
