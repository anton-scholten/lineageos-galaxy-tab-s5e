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
