# Charging notification on 23.2: strong-model triage of the D1/D2 packet

Source packet: [charging-notification.md](charging-notification.md). Reviewed 2026-10-13.

| Item | Decision | State |
|---|---|---|
| **D2** thermal HAL reads `sec-*-thermistor` (sepolicy, +3 lines, `a8b5d8e`) | **Accepted.** Additive, narrow, same pattern as `1188e2b`. | Cherry-picked clean onto both device-fork branches and pushed: `lineage-24.0` `a9d9a0c`, `lineage-23.2` `278c7f9`. 24 is in build 18. 23.2 needs a rebuild to ship (no Format data needed, signing keys are identical). |
| **D1** ship only the Lineage AIDL health HAL (`647daf4`, `gts4lv.mk`) | **Held. Not merged. Elevate.** | Not pushed. Saved as [D1-health-hal.patch](D1-health-hal.patch) (applies to the device fork, cut from `c2fe044`). |

## Why D1 is held (I am not confident, so I did not ship it)

- The measured symptom is **8.7 s to 223 s lag between kernel `power_supply` and `BatteryService`**, plus **no notification ever posted**. D1 changes who owns `IHealth/default`
  on the *released* 23.2 build, which changes every battery field the framework sees (level, status, temperature, health). The packet itself rates it medium and says the
  Lineage HAL being *sufficient* is inferred, not verified.
- D1's own justification is the dead charging-control feature, not the notification. It is a feature change, not a bug fix for the reported symptom.
- Nothing links the symptom to the HAL choice with evidence: the lag model (a deferred wakeup alarm in the Samsung blob) is plausible but untested, and the **missing notification
  is explicitly "independent, unexplained"**. Fixing the HAL may not fix what the owner reported.
- It cannot be verified without a rebuild plus reflash of 23.2, and the tablet is currently used for the 24 bring-up.

## Also noted for the elevated reviewer

- The packet calls the empty `BAT` channel the missing "charging notification". That channel is the **low-battery** warning channel. AOSP posts no heads-up notification on plug-in;
  the plug-in feedback is the charging sound (`CHARGING_SOUNDS_ENABLED`) and the lock-screen/status indicator, both driven by `ACTION_BATTERY_CHANGED`/`BatteryController`.
  Confirm what the owner actually expects to see before chasing "never posted"; the 8.7-223 s `BatteryService` lag would already delay all of those.
- Cheapest next experiment, no flashing of 24: on 23.2, run the packet's probes after D1 only (A/B of the lag, packet section 10). Only then decide.
- Questions left open from the packet section 12: 1 (D1), 5 (notification triage), 6 (accept the blob's lag?), 7 (A/B). Question 4 (backport) is answered: D2 yes, D1 no.

## 2026-10-13 follow-up: D1 is wrong; new lead is the uevent BPF filter

Checked live on the tablet (23.2, fresh boot, USB cable to a PC only).

**D1 would remove the only `IHealth` provider.** `vendor.lineage.health-service.default` registers
only `vendor.lineage.health.IChargingControl/default` and `IFastCharge/default` (its VINTF fragment
and `service list` agree). It has never tried to own `IHealth/default`. Charging control is not dead
either: both interfaces are registered. Dropping `android.hardware.health-service.samsung` would
leave `BatteryService` without a health HAL, and also remove `vendor.charger` (off-mode charging).
**Do not apply D1.**

**The "Samsung blob" is source**, `hardware/samsung/aidl/health/Health.cpp` (79 lines): a stock
AOSP `libhealth_aidl_impl` + `HalHealthLoop`, no Samsung-specific polling policy. The packet's
"prebuilt with an alarm policy" model is wrong.

**Measured:** kernel calls `power_supply_changed()` (→ `kobject_uevent`) every ~10 s while charging
(`sec_bat_monitor_work`, `sec_battery.c:3556`). The HAL logs `healthd: battery` on every update. On
this boot: kernel `Status(Charging) Cable(USB)` from ≤99 s, HAL updates only at 17, 23 and 124 s,
then none to 344 s. Uevents are not reaching the HAL; it only updates on its fallback timer
(600 s on battery) or when something else asks. That explains the 8.7–223 s spread and why the icon,
charging sound and lock-screen text all stay unchanged.

**Suspect:** `HealthLoop: Successfully attached the BPF filter to the uevent socket`. The filter
(`hardware/interfaces/health/utils/libhealthloop/filterPowerSupplyEvents.c`) is built for kernels
≥ 5.10 only. It loads here because patch 0004 sets `ro.bpf.kver_override=5.15.178`
(netbpfload logs `kver:50f00b2`). On the backported 4.9 BPF it very likely drops the
`power_supply` uevents.

**Live test (needs Developer options → rooted debugging, wireless adb so the port is free):**
`adb root`; `rm /sys/fs/bpf/vendor/prog_filterPowerSupplyEvents_skfilter_power_supply`;
`setprop ctl.restart vendor.health-samsung` (expect the "failed to load BPF program" warning);
plug/unplug and check the `healthd: battery` line follows within ~1 s. Reboot restores everything.

**Fix if confirmed (confidence medium-high until tested):** keep the HAL from attaching the filter
on this device. Options: a `hardware/interfaces` (or `hardware/samsung` health) patch that skips
`AttachFilter` when the real kernel is < 5.10, or a 4.9 kernel fix for whatever makes the
program drop the packet. The HAL patch is smaller and needs no kernel work.

### Live test result (2026-10-13): confirmed

Unpinned the filter (`rm /sys/fs/bpf/vendor/prog_filterPowerSupplyEvents_skfilter_power_supply`) and
restarted `vendor.health-samsung`; the HAL logged the expected "failed to load BPF program" warning.
- Steady charging: the HAL now updates 2–4 ms after every `sec_bat_monitor_work` (was 3 updates in
  340 s with the filter).
- Four unplug/plug edges (USB and AC): `sec_bat_cable_work: End` → `healthd: battery` in
  **0.1–0.2 s** every time (was 8.7–223 s).

**The filter drops `power_supply` uevents on this kernel.** Root cause is in the 4.9 BPF backport
(the program is correct on real ≥ 5.10 kernels). Owner's call: fix the kernel, not libhealthloop.
Next: run the pinned program through `BPF_PROG_TEST_RUN` with a captured battery uevent, dump its
xlated instructions, and bisect interpreter vs JIT and the `LD_ABS`/`LD_IND` → `bpf_skb_load_helper_*_no_cache`
rewrite (`net/core/filter.c:8252`).

### Root cause and fix (2026-10-13): kernel, verified on device

`BPF_PROG_TEST_RUN` with a captured battery uevent (769 bytes, `SUBSYSTEM=` at offset 139) returned
**0 (DROP)**; a live `NETLINK_KOBJECT_UEVENT` socket with the pinned filter attached received 0 of 1
battery uevents. The verifier's xlated program showed why:

```
r1 = r7; r1 += -13      ; LD_IND offset computed in r1
r1 = r6                 ; ctx overwrites it
r2 = r1                 ; offset := ctx pointer
call bpf_skb_load_helper_*_no_cache   -> -EFAULT -> program returns 0
```

`bpf_gen_ld_abs()` (`net/core/filter.c`) in the backport `4113f8c5e4ec` ("BACKPORT: bpf: implement
ld_abs/ld_ind in native bpf") sets `R1 = ctx` **before** copying the `BPF_IND` source register into
`R2`. Upstream 5.15 emits the `R2` setup first. clang allocates R1 as the source register in this
program, so every packet load got a garbage offset.

**Fix:** kernel `8d39d4284f85` "bpf: filter: set R2 before R1 in bpf_gen_ld_abs()" (2-line reorder,
matches upstream). Built incrementally against the 23.2 tree (same clang r563880c), repacked into the
tablet's own boot image (header and ramdisk unchanged, unsigned AVB hash footer re-added; `vbmeta`
flags 3), written with `dd`. Results on `4.9.337-g8d39d4284f85`:
- `BPF_PROG_TEST_RUN`: retval 769 (keep); live socket with filter: 1 of 1 delivered.
- Six plug/unplug edges, including plug-in after 60 s idle with the screen off: HAL update
  **0.15-0.23 s** after `sec_bat_cable_work`. Owner: icon and charging sound immediate, screen wakes
  on plug-in.

No device-tree or libhealthloop change needed. D1 stays rejected. Probe tool source: `psfilt.c`
(session scratch, not kept; rebuild from the description above if needed).

Any other `LD_ABS`/`LD_IND` program using R1 as the index register was equally broken on this kernel, so
the fix may also help other mainline BPF programs that use packet loads.

### Upstream reference and other trees (2026-10-13)

- Upstream had the same bug from `e0cea7ce988c` (4.18) and fixed it in **`e6a18d36118b` "bpf: Fix
  clobbering of r2 in bpf_gen_ld_abs"** (Daniel Borkmann, v5.9; Fixes: `e0cea7ce988c`). Our
  `8d39d4284f85` is the same change. The ExyHyperBrick "5.15 level" BPF series missed it, so other 5.9-5.15
  `kernel/bpf` / `net/core/filter.c` fixes may be missing too; worth an audit against the 5.15 tree.
- **ExyHyperBrick** `android_kernel_samsung_exynos9810` `lineage-23.2` and `lineage-24.0`: same wrong order
  in `bpf_gen_ld_abs()`. Their `exynos9810-common` `common.mk` ships the same
  `android.hardware.health-service.samsung` and sets the same kver override, so the S9/S9+/Note9 builds
  should show the same late charging icon and sound. Owner to report it to krazey (cite `e6a18d36118b`).
- Pushed: kernel fork `lineage-23.2` and `lineage-24.0` → `8d39d4284f85` (fast-forward from `500658be3c16`).
