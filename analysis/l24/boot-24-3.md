# boot-24-3 (2026-10-15): LineageOS 24 boots and runs on SM-T720

| | |
|---|---|
| Zip | `lineage-24.0-20261014-UNOFFICIAL-gts4lvwifi.zip`, from `/mnt/build/releases/24.0-20261014/` (`SHA256SUMS` there) |
| Build | `scripts/build-all.sh`, clean `out/`, 12 h 56 m, 0 `FAILED:`. Release settings: `userdebug`, `ro.debuggable=0`, `ro.adb.secure=1`, no `WITH_ADB_INSECURE` |
| Kernel | `4.9.337-g8d39d4284f85` (incl. the BPF ld_abs fix) |
| Device tree | `lineage-24.0` @ `a9d9a0c` (incl. D2) |
| Other forks | vendor `1e0cce7`, **system/core `40a6fdb6d`** (keyring fix from boot-24-2), vold `f8c406d`, compat `eaf8275`, sepolicy_vndr `d4fc898` |
| Install | Owner: 24 recovery via Heimdall, ⚠️ *Format data*, sideload, no GApps |
| Result | **Boots to the home screen.** `sys.boot_completed=1`, SELinux Enforcing, verified boot `orange` (unlocked, as on 23.2) |
| Logs | logcat all buffers at 15 min uptime (33,105 lines, kept local), `scripts/device-checks.sh` (`~/work/device-checks-24-2026-10-15.log`) |

## Summary

1. The boot-24-2 blocker is fixed: with the `system/core` keyring revert, `/data` FBE comes up and the boot completes.
2. **No crashes**: no tombstones, no ANRs, dropbox has only `SYSTEM_BOOT`, `SYSTEM_LAST_KMSG`, `storage_trim` and one
   (low-priority, empty) `keymaster` entry. No kernel `WARNING`/`BUG`/oops.
3. `device-checks.sh`: **5 PASS, 0 FAIL, 1 SKIP** (network, BPF, cgroups, PSI, …).
4. Working (checked over adb): Wi-Fi (connected, randomized per-network MAC by default), Bluetooth on, 21 h/w sensors,
   audio output threads, 2 cameras, keymaster 4.0 + gatekeeper HIDL, BPF traffic controller, thermal HAL, USB adb/MTP.
5. **Charging fix works on 24**: the health HAL's BPF uevent filter is attached and the HAL updates 3-6 ms after every
   `sec_bat_monitor_work` (USB connected).

## Things to watch (none blocking)

| Item | Evidence | Note |
|---|---|---|
| `tee` (qseecomd) denied `read` on `gatekeeper_vendor_data_file` dir ×6 | avc | **Not cosmetic (2026-10-15):** after a reboot a correct PIN is rejected (`nwd_KM_OUTDATA_unpack err -506`). Android 17 dropped `allow tee gatekeeper_vendor_data_file`. Fixed in device `lineage-24.0` `702e1fd`, not yet built |
| `macloader` denied `write` on `property_socket` ×2; `/sys/wifi/mac_addr` read gives `I/O error` | avc, shell | Only matters with "Use device MAC" (randomization off). Factory MAC is in `/mnt/vendor/efs/wifi/.mac.info`. Check on 23.2 whether the same |
| PA thermistor reads -20.0 °C (`sec-pa-thermistor` = -200) | `dumpsys thermalservice` | Wi-Fi model has no LTE PA; harmless reading, newly visible since D2 lets the HAL read it |
| `hal_sensors_default` denied `read` on input device names (`sysfs`) | avc | Sensors all registered and active |
| ~20 other vendor denials (`vendor_init` setting `persist.*`/`ro.*` props, `hal_audio` `radio_prop`, `hal_perf` `setuid`/`proc_meminfo`, `system_app` `proc_vmallocinfo`, `vold` `efs_file`) | avc | Same class as the boot-24-1/2 notes; no 23.2 baseline recorded to diff against |
| Log noise: `setupwizard.partner` provider missing ×1277 (no GApps), keystore2 `Km(UNIMPLEMENTED)` on blob delete (KM 4.0), `oem_lock` not published, `Failed to read dmabuf fd references` (4.9 kernel) | logcat E | Benign |
| USB gadget `rm`/`symlink` failures in `init.qcom.usb.rc` | init | Normal configfs noise; adb and MTP work |

## Next

- Owner: day-to-day use, the PIN test above, camera/audio/BT by hand, 24 h soak (rerun `device-checks.sh`).
- L9 (LTE) still blocked; L10 testing; L11 release (the `24.0-20261014` files are ready).
