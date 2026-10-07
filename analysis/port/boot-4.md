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

## Decision needed (owner)
gts4lvwifi has no ODM partition. Options: repurpose a spare Samsung partition (`hidden`, `omr`, `fota`/`bota`, or `cache`) as
`/metadata`, or test first with a tmpfs `/metadata` (not persistent). Partition sizes still need reading in recovery (root).
