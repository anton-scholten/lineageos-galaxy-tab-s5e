# boot-24-1 (2026-10-12): first LineageOS 24 boot → `enablefilecrypto_failed`

| | |
|---|---|
| Zip | `lineage-24.0-20261012-UNOFFICIAL-gts4lvwifi.zip`, sha256 `7b7b1a486f90ecd2da095f083e262bb64645f56354043a66feae13e8c758adeb` (1,162,543,364 B, `unzip -t` clean) |
| Kernel | `4.9.337-g500658be3c16` (`last_kmsg`; confirmed by `boot-log.sh` kernel-tag check) |
| Device tree | `port/l24-dt-4` @ `c2fe044` |
| Vendor blobs | `port/l24-vendor-1` @ `1e0cce7` |
| Log | `/proc/last_kmsg`, 5529 lines, read from the **23.2** recovery via `scripts/boot-log.sh`. Raw copy local in `flash-logs/20261012-102651/` (contains serial + MACs, git-ignored) |
| Install | BLOCK OTA sideloaded from the 23.2 recovery. `/data` formatted (ext4) by recovery's *Format data* |
| Result | Boots once, fails at 15.23 s, reboots to recovery: *"Can't load Android system… Reason: enablefilecrypto_failed"* |

## How far it got

Much further than boot-2/3/4. Kernel, first- and second-stage init, all `.rc` parsing, the **split** SELinux
policy (89,114 rules) and `vold` itself all come up cleanly. `apexd-bootstrap` starts. The failure is at
`post-fs-data`, in the `installkey /data` exec — and the step immediately before it,
`vdc checkpoint prepareCheckpoint`, **succeeded**. Nothing is wrong with early boot; this is the first
hard failure in the storage path.

Note: plain `grep` treats `last_kmsg` as binary and prints "binary file matches" — use `grep -a`. (Same
trap as boot-2.md line 40; `scripts/boot-log.sh` now passes `-a` throughout.)

## The failure (`last_kmsg` 4585–4607)

```
[   15.178300]  [7:            vdc:  712] libbinder.BackendUnifiedServiceManager: Thread Pool max thread count is 0. Cannot cache binder as
[   15.178418]  [7:            vdc:  712] vdc: Waited 0ms for vold
[   15.179169]  [7: servicemanager:  644] servicemanager: Caller(pid=656,uid=0,sid=u:r:vold:s0) Could not find android.hardware.boot.IBooTCo
[   15.180995]  [7:   binder:656_2:  656] vold: Error getting bootctrl v1.0 module.
[   15.182027]  [7:           init:    1] init: Service 'exec 4 (/system/bin/vdc checkpoint prepareCheckpoint)' (pid 712) exited with status
[   15.182128]  [7:           init:    1] init: Sending SIGKILL to service 'exec 4 (/system/bin/vdc checkpoint prepareCheckpoint)' (pid 712)
[   15.182411]  [7:           init:    1] libprocessgroup: Removed cgroup /sys/fs/cgroup/system/uid_1000/pid/712
[   15.185444]  [7:           init:    1] init: starting service 'exec 5 (/system/bin/vdc --wait cryptfs enablefilecrypto)'...
[   15.188222]  [7:           init:    1] libprocessgroup: Created cgroup /sys/fs/cgroup/system/uid_0/pid/713
[   15.189072]  [7:           init:    1] init: ... started service 'exec 5 (/system/bin/vdc --wait cryptfs enablefilecrypto)' has pid 713
[   15.189176]  [7:           init:    1] init: SVC_EXEC service 'exec 5 (/system/bin/vdc --wait cryptfs enablefilecrypto)' pid 713 (uid 0 gid 0+0 context default)
[   15.198234]  [7:            vdc:  713] libbinder.BackendUnifiedServiceManager: Thread Pool max thread count is 0. Cannot cache binder as
[   15.198361]  [7:            vdc:  713] vdc: Waited 0ms for vold
[   15.212895]  [7:   binder:656_2:  656] vold: keystore2 Keystore generateKey returned service specific error: -67
[   15.212979]  [7:   binder:656_2:  656] vold: Failed to generate rollback-resistant key.  This is expected if keystore doesn't support rol
[   15.232462]  [6:   binder:656_2:  656] vold: Failed to install fscrypt key to /data: Inappropriate ioctl for device
[   15.232874]  [6:            vdc:  713] vdc: Command: cryptfs enablefilecrypto Failed: Status(-8, EX_SERVICE_SPECIFIC): '0: '
[   15.233688]  [6:           init:    1] init: Service 'exec 5 (/system/bin/vdc --wait cryptfs enablefilecrypto)' (pid 713) exited with sta
[   15.233793]  [6:           init:    1] init: Sending SIGKILL to service 'exec 5 (/system/bin/vdc --wait cryptfs enablefilecrypto)' (pid 7
[   15.234085]  [6:           init:    1] libprocessgroup: Removed cgroup /sys/fs/cgroup/system/uid_0/pid/713
[   15.234191]  [6:           init:    1] init: Exec service failed, status 25: Rebooting into recovery, reason: enablefilecrypto_failed
[   15.234267]  [6:           init:    1] init: Rebooting into recovery
[   15.236636]  [6:           init:    1] init: Got shutdown_command 'reboot,recovery' Calling HandlePowerctlMessage()
```

The `keystore2 … -67` / "rollback-resistant key" lines are **expected noise** — vold says so itself and
falls back to a non-rollback-resistant key. They are not the cause. The one line that matters is
`Failed to install fscrypt key to /data: Inappropriate ioctl for device`.

## Cause (confidence: high)

The kernel **does not implement the fscrypt ioctl interface at all**, so Android's file-based encryption
path can never succeed on it.

Verified in the tree at `500658be3c16`:

| Check | Result |
|---|---|
| `fs/fscrypt.c` | **does not exist** |
| `FS_IOC_ADD_ENCRYPTION_KEY` in `include/uapi/linux/fs.h` | **not defined** |
| `FS_IOC_ADD_ENCRYPTION_KEY` case in `fs/ext4/ioctl.c` | **absent** → falls through to `default: return -ENOTTY` (`fs/ext4/ioctl.c:901`) |
| Any other reference in the kernel | one hit only, in `tools/testing/selftests/filesystems/fuse/backing-casefold.c`, which is not built |

`CONFIG_FS_ENCRYPTION=y`, `CONFIG_EXT4_FS_ENCRYPTION=y` and `CONFIG_F2FS_FS_ENCRYPTION=y` are all set,
but `fs/ext4/Kconfig:110-113` makes `EXT4_FS_ENCRYPTION` depend on Samsung's own **`EXT4_ENCRYPTION`**, and
`Kconfig:115` adds `EXT4_FS_ICE_ENCRYPTION`. Those are Samsung inline-crypto (ICE), which is a different
mechanism. **Setting those configs does not provide the upstream fscrypt ioctl that vold calls.**

The chain that reaches it:

1. `init.rc:719` → `installkey /data` at `post-fs-data`
2. `system/core/init/builtins.cpp:1125-1127` → `is_file_crypto()` is true iff `ro.crypto.type == "file"`
3. `system/fs/fs_mgr/fs_mgr.cpp:1161-1163` — the fstab `/data` line carries `fileencryption=ice`, so
   mounting returns `FS_MGR_MNTALL_DEV_FILE_ENCRYPTED`
4. `fs_mgr.cpp:1169-1177` → `set_type_property()` does `SetProperty("ro.crypto.type", "file")`
5. `builtins.cpp:1180-1188` → `ExecVdcRebootOnFailure("enablefilecrypto")`
6. `system/vold/vdc.cpp:161` → `vold->fbeEnable()` → `VoldNativeService.cpp:624` →
   `fscrypt_initialize_systemwide_keys()` (`FsCrypt.cpp:551`)
7. `install_userdata_key()` → `system/vold/KeyUtil.cpp:330` →
   `ioctl(fd, FS_IOC_ADD_ENCRYPTION_KEY, arg)` → **ENOTTY**
8. returns false → init status 25 → `enablefilecrypto_failed` → reboot to recovery

There is **no fallback**: `fscrypt_initialize_systemwide_keys()` returns false on the first failure, and
`do_installkey()` only has the early-out *into* the FBE path, never out of it.

`/data` is **ext4** (superblock magic `53 ef` little-endian at offset 0x438, read off
`/dev/block/mmcblk0p57` from recovery), so there is no f2fs ICE route either.

### Why the factory reset could not have fixed it

Worth stating plainly, because it was tried: a reset recreates the *filesystem*. The missing thing is a
*kernel* ioctl. No amount of formatting reaches it. Resetting was never going to change this outcome.

## Proposed fix (NOT applied — needs review before building)

`device/samsung/gts4lv-common/init/fstab.qcom`, `/data` line:

```
- /dev/block/bootdevice/by-name/userdata  /data  ext4  … latemount,wait,check,fileencryption=ice,quota,formattable,reservedsize=128M
+ /dev/block/bootdevice/by-name/userdata  /data  ext4  … latemount,wait,check,forceencrypt,quota,formattable,reservedsize=128M
```

Dropping `fileencryption=ice` stops fs_mgr returning `FS_MGR_MNTALL_DEV_FILE_ENCRYPTED`, so
`ro.crypto.type` is never set to `file`, `installkey` returns early at `builtins.cpp:1181`, and vold takes
the **block-encryption** path instead. `forceencrypt` keeps `/data` encrypted rather than silently
dropping to plain.

Block encryption is supported by this kernel's `.config`: `BLK_DEV_DM=y`, `DM_CRYPT=y`, `DM_BUFIO=y`,
`CRYPTO_XTS=y`, `CRYPTO_AES=y`, `CRYPTO_CBC=y`.

Fallback if `forceencrypt` misbehaves: drop both flags, which boots with an unencrypted `/data`. That is
worse but proves the diagnosis.

**Cost:** a `.rc` change, so Soong re-analysis is unavoidable but no `Android.bp` work is forced.

## Process notes for whoever picks this up

- **This was not a debug build.** TASKS-L24 §L8 says use `WITH_ADB_INSECURE=true` first so adb works during
  a boot loop. That was not done, so adb was only usable from recovery and `logcat` could not be collected
  during the failure itself. Everything above comes from `last_kmsg`. The next attempt should be a debug
  build, which would also give `logcat -b crash -d` per §L8.
- `/data` **was** formatted, as §L8 requires. That is what put this failure on the path — see the open
  question below.

## Open question for review (confidence: low on the explanation, high on the facts)

**Why did 23.2 boot successfully with a byte-identical fstab and a byte-identical kernel `.config`?**

Checked and ruled out as explanations:

| | 23.2 | 24.0 |
|---|---|---|
| kernel `.config` | identical | identical |
| `init/fstab.qcom` | byte-identical | byte-identical |
| `init.rc:719` `installkey /data` | present | present |
| `is_file_crypto()` guard | identical | identical |
| `ro.crypto.type` preset in build props | no | no |

Since `init.rc`, the guard and the fstab are all identical, and the kernel cannot have provided the ioctl
in 23.2 either, the only remaining variable is **the state of `/data` at first boot**.

Best hypothesis (**unverified**): `fileencryption=ice` is an old tree setting, never revisited by this
port — no encryption decision appears anywhere in `B1-log.md`, `FLASH-BLOCKER.md` or `boot-2..5.md`. If
the 23.2 `/data` was already encrypted (f2fs from stock, or an earlier install), `fs_mgr`'s mount would
return a status that does **not** set `ro.crypto.type=file`, `installkey` would return early, and boot
would proceed. This time *Format data* produced a **fresh ext4** volume, so `fileencryption=ice` took
effect and demanded fscrypt.

That would mean this is latent since 22.2 and only surfaced because the `/data` was refreshed — which
also means **a reflash of 23.2 onto a freshly formatted `/data` may reproduce it**. Worth testing if a 23.2
log or a spare 23.2 zip is to hand: it would either confirm the hypothesis or refute it.

If the hypothesis is right, the same reasoning implies the fix is not really about fstab: it is that this
kernel can do block encryption but not file-based, and `fileencryption=ice` has been asking for the
impossible all along.

## Other noise in this boot (non-fatal, check later)

- `vold: Error getting bootctrl v1.0 module.` (line 4588) — no `android.hardware.boot.IBooTControl` in the
  VINTF manifest. Expected for this platform; noted only because it precedes the real error.
- `seemp: seemp_logk_init: SCM call failed with ret val = 0 -3 0` (line 1762) — log-key daemon, harmless.
- `init: [liblp] ReadMetadata … /dev/block/by-name/super: No such file or directory` (line 3727) —
  there is no `super` partition on this device. Cosmetic here, but `liblp` will keep logging it.
- `[drm-dp] secdp_init: DRM DP gpio request failed` (line 3155) — DisplayPort init. Watch on the first
  real boot; this is the Wi-Fi Display area the port already knows is shaky (P8).

## Handling note

I deleted the first copy of this log with a stray `rm -rf flash-logs/2*` while cleaning up test fixtures.
Nothing was lost — the tablet still held all 5529 lines and they were re-pulled — but it is exactly the
failure the tooling warns about, and it is why `boot-log.sh` refuses to touch existing directories.