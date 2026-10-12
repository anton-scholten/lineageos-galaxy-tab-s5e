# boot-24-2 (2026-10-12): second LineageOS 24 boot → `enablefilecrypto_failed`, **new** error

| | |
|---|---|
| Zip | `lineage-24.0-20261012-UNOFFICIAL-gts4lvwifi.zip`, 1,162,216,299 B, sha256 `1b1eb16a43bf91d782500cc343cdca893b5dd48a58c9e323d35b5a534a8dd1d3`, `unzip -t` clean |
| Build | round 17, `~/work/l24-build-17.log`, **1 h 29 m 36 s**, 314 steps, 0 `FAILED:`. `WITH_ADB_INSECURE=true`, `mka bacon -k 0` |
| Kernel | `4.9.337-g500658be3c16` |
| Device tree | `lineage-24.0` @ `c2fe044` |
| Vendor blobs | `lineage-24.0` @ `1e0cce7` |
| **vold fork** | `anton-scholten/android_system_vold` `lineage-24.0` @ **`f8c406dbd981`** — the fix proposed in boot-24-1's review, first time built and booted |
| Other forks | compat `eaf8275`, sepolicy_vndr `d4fc898` |
| Log | `/proc/last_kmsg`, 5073 lines / 524,288 B, via `scripts/boot-log.sh`. Raw copy local in `flash-logs/20261012-131245/` (has serial + MACs, git-ignored) |
| Install | BLOCK OTA sideloaded from the **23.2** recovery. ⚠️ `/data` formatted (ext4) by recovery's *Format data* |
| Result | Boots once, fails at **15.34 s**, reboots to recovery: *"Can't load Android system… Reason: enablefilecrypto_failed"* |

## Summary

1. **The vold revert from boot-24-1 works.** The old error, `Failed to install fscrypt key to /data: Inappropriate ioctl for device` (ENOTTY), is **gone**. vold now detects the missing `FS_IOC_ADD_ENCRYPTION_KEY` and takes the legacy session-keyring path, exactly as it does on 23.2.
2. It fails **one step later**, with a different errno: `vold: Unable to find device keyring: Required key not available` (ENOKEY, `last_kmsg:4076`).
3. Cause: AOSP removed the old-kernel session-keyring workaround in **three commits across two repos**. We restored one (`0e87a83`, vold). The other two are in `system/core` and are still missing, so **nothing creates the `"fscrypt"` keyring that vold now looks for**.
4. The 23.2 recovery installs 24 zips fine — proven twice now, so README line 85's "not tested" is wrong.
5. Boot is otherwise identical to boot-24-1 and otherwise clean: same stage, same time (15.3 s vs 15.2 s), 10 avc denials all of the known `persist.*`/`vendor_init` class.

## How far it got

Identical to boot-24-1. Kernel, both init stages, all `.rc` parsing, the split SELinux policy (89,114 rules), `apexd-bootstrap`, `vold`, `vdc checkpoint prepareCheckpoint` — all clean. First hard failure in the storage path, at `post-fs-data`.

## The failure (`last_kmsg` 4068–4082)

```
[   15.291152]  [6:           init:    1] init: starting service 'exec 5 (/system/bin/vdc --wait cryptfs enablefilecrypto)'...
[   15.318205]  [6:   binder:656_2:  656] vold: keystore2 Keystore generateKey returned service specific error: -67
[   15.318288]  [6:   binder:656_2:  656] vold: Failed to generate rollback-resistant key.  This is expected if keystore doesn't
                                       support rollback resistance.  Falling back to non-rollback-resistant key.
[   15.337383]  [6:   binder:656_2:  656] vold: Unable to find device keyring: Required key not available
[   15.337768]  [6:            vdc:  713] vdc: Command: cryptfs enablefilecrypto Failed: Status(-8, EX_SERVICE_SPECIFIC): '0: '
[   15.338581]  [6:           init:    1] init: Service 'exec 5 (…)' exited with status 25 waiting took 0.044000 seconds
[   15.339117]  [6:           init:    1] init: Exec service failed, status 25: Rebooting into recovery, reason: enablefilecrypto_failed
[   15.339190]  [6:           init:    1] init: Rebooting into recovery
```

The `keystore2 … -67` / rollback-resistance pair is the **expected noise** boot-24-1 already documented. The one line that matters is
`Unable to find device keyring: Required key not available`.

## What changed from boot-24-1 (the fix did its job)

| | boot-24-1 | boot-24-2 |
|---|---|---|
| vold build | upstream `11d8982` | our fork `f8c406dbd981` |
| path taken | `installKey()` → `ioctl(FS_IOC_ADD_ENCRYPTION_KEY)` → **ENOTTY** | `isFsKeyringSupported()` false → `installKeyLegacy()` |
| error | `Failed to install fscrypt key to /data: Inappropriate ioctl for device` | `Unable to find device keyring: Required key not available` |
| failure time | 15.23 s | 15.34 s |

Verified in the built image, before flashing:

```
$ strings -a out/target/product/gts4lvwifi/system/bin/vold | grep -i "session keyring"
Kernel doesn't support FS_IOC_ADD_ENCRYPTION_KEY.  Falling back to session keyring
$ ls -l out/target/product/gts4lvwifi/system/lib64/libkeyutils.so
-rwxr-xr-x 1 anton anton 10648 Oct 12 12:25 libkeyutils.so
```

Both the vold revert and its `libkeyutils` copy are in the ROM. `/data` keeps `fileencryption=ice`, so FBE is still on, as on 23.2.

## Root cause (confidence: high)

The workaround AOSP deleted came in **three commits in two repos**. We restored one.

| Commit | Repo / files | Status |
|---|---|---|
| `0e87a83cbacd` (2023-11-22) "vold: remove session keyring workaround for old kernels" | `system/vold`: `Android.bp`, `FsCrypt.cpp`, `KeyUtil.cpp`, `KeyUtil.h` | ✅ **restored** by `f8c406dbd981` |
| `5d7c35ce205f` (2023-11-22) "init: remove session keyring workaround for old kernels" | `system/core`: `init/Android.bp`, `init/builtins.cpp`, `init/fscrypt_init_extensions.{cpp,h}`, `init/fuzzer/Android.bp`, `init/init.cpp` | ❌ **still removed** |
| `6dce39d61cf75` (2025-03-28) "Remove libkeyutils" | `system/core/libkeyutils/` (whole module) | ❌ **still removed** (the vold fork carries a private copy) |

Evidence from the two trees, `/mnt/build/lineage` (23.2) and `/mnt/build/lineage-24` (24.0):

```
$ diff .../lineage/system/core/init/fscrypt_init_extensions.cpp \
       .../lineage-24/system/core/init/fscrypt_init_extensions.cpp
37d36
< #include <keyutils.h>
43,57d41
< bool FscryptInstallKeyring() {
<     if (keyctl_search(KEY_SPEC_SESSION_KEYRING, "keyring", "fscrypt", 0) != -1) { … }
<     key_serial_t device_keyring = add_key("keyring", "fscrypt", 0, 0, KEY_SPEC_SESSION_KEYRING);
<     …
< }

$ grep -rn FscryptInstallKeyring .../lineage/system/core/init/     # 23.2: 4 hits
$ grep -rn FscryptInstallKeyring .../lineage-24/system/core/init/   # 24.0: 0 hits
$ grep -n libkeyutils .../lineage/system/core/init/Android.bp       # 23.2:205 "libkeyutils"
$ grep -n libkeyutils .../lineage-24/system/core/init/Android.bp    # 24.0: nothing
```

`FscryptInstallKeyring()` is what creates the keyring, and 23.2's `init/builtins.cpp:596` calls it in exactly the branch this device takes:

```cpp
} else if (code == FS_MGR_MNTALL_DEV_FILE_ENCRYPTED ||
           code == FS_MGR_MNTALL_DEV_IS_METADATA_ENCRYPTED ||
           code == FS_MGR_MNTALL_DEV_NEEDS_METADATA_ENCRYPTION) {
    if (!FscryptInstallKeyring()) {                      // 23.2 only
        return Error() << "FscryptInstallKeyring() failed";
    }
    SetProperty("ro.crypto.state", "encrypted");
```

`fileencryption=ice` on the `/data` line puts fs_mgr in `FS_MGR_MNTALL_DEV_FILE_ENCRYPTED`, so on 23.2 this runs. vold then looks the keyring up — `KeyUtil.cpp:291`, identical in both trees:

```cpp
*device_keyring = keyctl_search(KEY_SPEC_SESSION_KEYRING, "keyring", "fscrypt", 0);
if (*device_keyring == -1) {
    PLOG(ERROR) << "Unable to find device keyring";     // KeyUtil.cpp:293 — our log line
    return false;
}
```

The search only **looks**; it never creates. On 24.0 nobody creates it, so it returns ENOKEY.

**The log agrees:** neither `"Keyring created with id"` nor `"Keyring is already created"` appears anywhere in `last_kmsg`, and the only other keyring line is the kernel's unrelated `Initialise system trusted keyrings` (`last_kmsg:383`).

### The part that is easy to miss

`5d7c35ce205f` also removed, from `init/init.cpp` `SecondStageMain()`, the call that creates the **shared** session keyring in the first place:

```cpp
-    // Set up a session keyring that all processes will have access to. It
-    // will hold things like FBE encryption keys. No process should override
-    // its session keyring.
-    keyctl_get_keyring_ID(KEY_SPEC_SESSION_KEYRING, 1);
```

Its own commit message says so: *"It also removes the code that created the session keyring itself, since the only reason that Android even created a session keyring was just to hold the 'fscrypt' keyring."* init's children inherit that keyring, which is how vold ever saw the keyring on 23.2. Restoring only `FscryptInstallKeyring()` without this would put the keyring in init's own anonymous session keyring where vold cannot reach it.

## The fix — **NOT APPLIED**, needs a strong model

TASKS-L24 §L8 reserves boot-log diagnosis for the strong model, and this is a second platform fork plus new code in `init`. Nothing below has been applied, synced or built.

Mechanically it is `git revert 5d7c35ce205f` plus restoring `system/core/libkeyutils/` from `6dce39d61`:

1. `init/init.cpp` — restore `keyctl_get_keyring_ID(KEY_SPEC_SESSION_KEYRING, 1)` in `SecondStageMain()` + `#include <keyutils.h>`
2. `init/fscrypt_init_extensions.{cpp,h}` — restore `FscryptInstallKeyring()` and its declaration (verbatim from 23.2: cpp lines 37, 43–57)
3. `init/builtins.cpp` — restore the 3-line call in the `FS_MGR_MNTALL_DEV_FILE_ENCRYPTED ||` branch (23.2 lines 596–597)
4. `init/Android.bp` — restore `"libkeyutils"` in `libinit_cc_defaults.static_libs` (23.2 line 205)
5. `system/core/libkeyutils/` — restore the module (`Android.bp`, `NOTICE`, `include/keyutils.h`, `keyutils.cpp`, `.clang-format`); test target not needed
6. `init/fuzzer/Android.bp` — restore `"libkeyutils"` (only matters if init's fuzzers are built)

**Open decision for the strong model:** where `libkeyutils` should live. Our vold fork already carries a copy at `system/vold/libkeyutils/`. Two clean options:

- restore `system/core/libkeyutils` (its historical home) and point **both** forks at it — needs a vold patch edit to drop its private copy, plus the `Android.bp` path change;
- keep the two copies (one per fork) — less churn now, two copies to carry, and both need the same upstream Gerrit change later.

Both forks' `lineage-24.0` branches would need pushing, and the local manifest gains a `system/core` entry (`remove-project`/`project` pair) like `vold-keyring.xml`.

**Cost:** `init/Android.bp` changes, and init links into essentially every process. Expect **2–3 h**, not the 1 h 20 m – 2 h that build 17 took.

**Upstream note:** `5d7c35ce205f` is a deliberate Eric Biggers removal, justified by *"upgrading even just to Android 14 requires at minimum a android-4.14-stable kernel"*. Our kernel is 4.9, so both vold and init reverts are the same upstream argument. A combined Gerrit change is the honest long-term answer; the `vold-keyring.xml` comment already flags it.

## Process notes

- **The debug build did what it was meant to.** `WITH_ADB_INSECURE=true` kept `ro.debuggable=1` (it skips `PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG`, `vendor/lineage/config/common.mk:43`). `ro.adb.secure=0` did **not** land: LineageOS puts it in `PRODUCT_SYSTEM_EXT_PROPERTIES` (`common.mk:37`) and gts4lv has no `system_ext` partition. `brunch` defaults to userdebug, so build 16 was userdebug too — same signing, which is why the OTA applied over the existing install without a key mismatch.
- **adb never got the chance.** The failure is at 15.3 s in `post-fs-data`; adbd starts much later. Whether `ro.debuggable=1` yields a usable `adb root` is still unverified on hardware.
- **The 23.2 recovery installs 24 zips — twice now.** README line 85 says "**not tested**" for this and should drop that caveat. No 24 recovery was flashed for this attempt; the tablet still has the 23.2 one.
- **`/proc/last_kmsg` is capped at 524,288 B**, so `boot-log.sh`'s kernel-tag check false-alarms "WRONG kernel booted" when the banner is the part that wrapped out. The log itself starts at `[ 0.000000]` and runs contiguously to 16.10 s, and `proc_version.txt` confirms `4.9.337-g500658be3c16`. Recommend the script stop inferring the kernel from `last_kmsg` and compare `/proc/version` of the recovery plus the `androidboot.em.model=` cmdline instead. **Not changed.**
- pstore was pulled this time (290,786 B, `flash-logs/20261012-131245/pstore.txt`); it holds the same keystore2/keymaster noise, no new information.

## Other noise (non-fatal, unchanged from boot-24-1)

- `seemp_logk_init: SCM call failed` (×2) — log-key daemon, harmless.
- `liblp ReadMetadata … /dev/block/by-name/super: No such file or directory` — no `super` partition on this device. Cosmetic; `liblp` will keep logging it.
- `vold: Error getting bootctrl v1.0 module.` — no `android.hardware.boot.IBooTControl` in the VINTF manifest. Expected for this platform.
- `[drm-dp] secdp_init: DRM DP gpio request failed` (46 lines) — DisplayPort init; the Wi-Fi Display area the port already knows is shaky (P8).
- **10 `avc: denied`**, all `persist.*` property sets from `u:r:vendor_init:s0` at ~3.15 s (`persist.backup.ntpServer`, `persist.demo.hdmirotationlock`, `persist.debug.wfd.enable`, …). Same class as 23.2's documented vendor_init denials, not fatal.

## Next

1. Strong model decides the `libkeyutils` question and approves the `system/core` fork.
2. New branch(es), patch, then **build 18** (~2–3 h).
3. Flash, boot, log as **boot-24-3**. This should be the first attempt that gets past `post-fs-data`; expect the *next* blocker to be later in boot, which is also the first attempt where the debug build's adb can matter.

## Problems

None. The log was complete, the two trees were both on disk for a direct diff, and every claim above is cited to a file, line and commit.