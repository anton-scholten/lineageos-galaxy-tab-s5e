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
