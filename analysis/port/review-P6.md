# Review P6-R: ROM build-error loop (2026-10-05)

Reviewed: device `port/dt-2` @ `d154fb4384fb` (1 commit on `e3ccc923bcf2`), [P6-log.md](P6-log.md) (`agent/P6` @ `be2195b`),
lead notes `lead/2026-10-05` @ `0569c50`.

## Verdict: **pass.** Device fork `lineage-23.2` fast-forwarded `e3ccc92` → `d154fb4384fb` (2026-10-05).

| Item | Ruling | Why |
|---|---|---|
| Fix 1 `d154fb4384fb`: drop `AntHalService` from `PRODUCT_PACKAGES` | **Accept** | Minimal (4 deletions in `gts4lv.mk`). The module doesn't exist in 23.2; its sibling `com.dsi.ant.antradio_library` was dropped the same way in `635baf7e30aa`. The ANT HAL blobs still ship via `PRODUCT_COPY_FILES`, so only the ANT+ app side is lost. Nobody uses ANT+ on a tablet. |
| Fix 2: webview.apk was a git-lfs pointer | **Accept** | It was a host problem, with no repo change. The lesson is now in BUILD-HANDOFF and README: install `git-lfs` **before** `repo sync`. |
| `Disallowed PATH tool arm-linux-gnueabi-ld.bfd` left alone | **Accept** | P6 proved it is non-fatal: the `try-run` probe drops `-fuse-ld=bfd`, and in-tree `ld.lld` links vdso32. Its evidence holds: `CONFIG_COMPAT=y`, real vdso32 offsets in `vdso32-offsets.h`, and nothing allowlisted. Leaving the log noise is right, because changing `CLANG_TARGET_ARM32` would risk a vDSO that already works. |
| `libwfdservice` ABI break, escalated | **Escalation correct; flash allowed now; fix later (task P8)** | See below. |
| `mka bacon -k 0` zip | **Accept for a first flash** | The only failed edge is `check_elf_file`, a validation step. P6 proved the installed blob is byte-identical. So the zip equals what a clean build would give, minus that check. |

## libwfdservice ruling

- **Diagnosis checked against upstream.** LineageOS `hardware/lineage/compat` @ `8a4285c` ("libwfdservice: Update for 16")
  re-implements `WiFiDisplaySession::broadcastWifiDisplayAudioIntent(bool)`. That function is the blob's caller of the old
  3-argument `AudioSystem::setDeviceConnectionState`. The shim calls the new 4-argument form with `false`. This device tree
  already adds `libwfdservice_shim.so` to `system_ext/bin/wfdservice` (`extract-files.py:45-46`), but only `libwfdservice.so`
  carries the undefined 3-argument symbol, and its `shared_libs` don't list the shim. So the build check fails.
- **Risk: low.** WFD (Wi-Fi Display, screen casting to a TV) is optional. `wfdservice` starts only on
  `vendor.wfdservice=enable`. If it is triggered, only that one service fails to load; the system keeps running.
  **This doesn't block the first boot.**
- **Rejected:** `allow_undefined_symbols` / `check_elf_files: false` on their own. They hide the check and leave the runtime
  failure in place.
- **P8 (later, after first boot): restore WFD.** Two options, both strong-model or owner work:
  1. Add `.add_needed('libwfdservice_shim.so')` to the `system_ext/lib/libwfdservice.so` fixup in `extract-files.py`. Then the
     shim's `broadcastWifiDisplayAudioIntent` interposes the blob's own copy. For the undefined 3-argument symbol, either add a
     3-argument forwarder to a device shim in `shims/`, or rewrite the symbol in the blob. Then re-extract
     and regenerate the vendor tree. That needs a fork of `TheMuppets/proprietary_vendor_samsung_gts4lv-common`.
  2. Or drop the WFD sink stack from the device tree, and accept no screen casting.

## Kernel backport: answer to "did it work?"
**It compiles and is reviewed. It is not proven until boot.** 2,458 commits ported, all reviewed (P1-R…P4-R). It builds `Image.gz-dtb`
for both defconfigs. The reviewer rebuilt it independently (review-P4.md), and it is inside the built ROM. The real test is
the first boot: does bpfloader/netd come up? Then `scripts/device-checks.sh` and the BPF tests in TESTING.md.

## Next
1. Owner: flash the Wi-Fi zip per README path A or B. ⚠️ Erases data. Then run P7 (log triage) after every attempt.
2. After a boot: build `gts4lv` (LTE) with `brunch gts4lv`. Then P8 (WFD).
