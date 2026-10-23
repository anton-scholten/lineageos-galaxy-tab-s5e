# Charging notification on 23.2: investigation packet for the strong model

Written 2026-10-12 by a helper agent during an owner-directed debugging session. **Nothing here has
been reviewed yet.** Four commits are waiting on you:

| | task | repo | branch | commit |
|---|---|---|---|---|
| 1 | D1 — ship only the Lineage AIDL health HAL | device fork | `port/l24-dt-5` | `647daf4` |
| 2 | D2 — thermal HAL may read `sec-*-thermistor` | device fork | `port/l24-dt-6` | `a8b5d8e` |
| 3 | D1 task spec | docs repo | `agent/D1` | `4fddd58` |
| 4 | D2 task spec | docs repo | `agent/D2` | `162cb07` |

Both device branches are cut from the fork's `lineage-24.0` (`c2fe044`, which already contains the
L6/L7 port work). **Neither contains the other — both must be merged.** Nothing has been pushed and
**no build was run**.

---

## 1. The symptom

Reported by the owner on the 23.2 release build: the charging notification is **delayed, or does not
appear at all**. Tested on the tablet `SM-T720` / `gts4lvwifi` running
`ro.lineage.version=23.2-20261008-UNOFFICIAL-gts4lvwifi` (Android 16, SDK 36, `userdebug`).

The port brief did not ask about this. It surfaced during a debugging session and turned out to be
**two independent bugs wearing one coat**.

---

## 2. Verdict in one paragraph

**Not a kernel defect, and not caused by the port's power/battery work.** The kernel detects the
charger in **0.47 s**. All the latency is between the kernel's `power_supply` sysfs and
`BatteryService`, which is inside the **Samsung health HAL blob** — an erratic 8.7–223 s. Separately,
**the notification is never posted at all**, which that latency does not explain. Two genuine port
defects were found alongside and are fixed as D1 and D2.

---

## 3. Method, and why you can trust it

Two probes, both **uptime-relative** (`/proc/uptime`), because wall-clock logcat on this device is
unusable — auditd lines carry `12-31 13:00` while `sec-battery` lines carry `10-12 11:2x`, so the
clock jumps mid-session. `logcat -v monotonic` is uptime-relative and directly comparable to
`/proc/uptime` (verified: monotonic `349.870` vs uptime `349.99`).

- **Kernel probe** — `/data/local/tmp/batwatch.sh`, on-device, 1 Hz, samples
  `/sys/class/power_supply/{battery,ac,usb,pogo,wireless}`. Those six nodes exist because
  `drivers/battery_v2/sec_battery.c:9751-9795` registers `ps`, `wireless`, `usb`, `ac`, `battery`,
  `pogo`.
- **Framework probe** — `~/work/fwwatch.sh`, host-side, 1–2 s, one adb round trip per sample reading
  kernel sysfs *and* `dumpsys battery` in the same call.

### The instrument was validated as non-perturbing

The owner's suspicion was that adb polling was creating the very updates being measured. It is not:

- `BatteryService.dumpInternal()` (`frameworks/base/services/core/java/com/android/server/BatteryService.java:1668`)
  contains **no** refresh call. A forced refresh exists only behind
  `dumpsys battery get <key> --force-update` (`:1449-1454`). Plain `dumpsys battery` is a pure read
  of the cached `mHealthInfo`.
- The host poller ran continuously (121 samples, ~1.15 s apart, **no gaps**) and the framework flipped
  at `1315.728` **while it was still running**.

So the numbers below stand.

### One trap worth knowing

**`logcat -b all -c` breaks kernel-log ingestion.** After clearing, no attach/detach lines were
captured for two later plug cycles even though both provably happened; the buffer's max timestamp
stalled at `794.9 s`. Do not clear buffers for future captures — rely on the two probes.

---

## 4. Measurements

| # | edge | kernel flip | framework flip | lag |
|---|---|---|---|---|
| 1 | rising (plug) | 462.111 | 486.52 | **24.4 s** |
| 2 | falling (unplug) | 709.0 | 717.70 | **8.7 s** |
| 3 | rising (plug) | 775.41 | 788.03 | **12.0 s** |
| 4 | falling (unplug, device left idle) | 1002.83 | 1225.68 | **223 s** |
| 5 | rising (plug, screen held on) | 1266.66 | 1315.73 | **49.0 s** |

**Gap A (kernel) is 0.47 s**: CCIC IRQ at `461.643`, charger-enable pin ON at `461.884`,
`sec_bat_monitor_work: Status(Charging)` at `462.111`. The kernel was correct on **every** edge —
`ac/online` and `status` always tracked reality within a second.

**Gap B is everything else** — 8.7 s to 223 s, and it is not a constant.

---

## 5. Where the latency lives

`BatteryService` registers a **push** callback and never polls:

```
BatteryService.java:510   registerHealthCallback();
BatteryService.java:551   private void registerHealthCallback() {
BatteryService.java:555     mHealthServiceWrapper = HealthServiceWrapper.create(this::update);
```

Updates arrive only when the health HAL invokes the callback. `BatteryService` itself has no timer.
So the whole 8.7–223 s spread is the **Samsung health HAL blob's callback policy**. It is a prebuilt
binary (`gts4lv.mk:160-161`, `android.hardware.health-service.samsung`) with no source in the tree,
so its cadence cannot be read or changed from here.

---

## 6. Why it is erratic — working model, confidence medium-high

The lag is not constant, which rules out any fixed `sleep()` in SystemUI or a fixed timeout in
`BatteryService`. It is consistent with the HAL polling on an **elapsed-realtime wakeup alarm**, which
the kernel defers while the device is idle:

- Edge #4 (223 s) resolved at `1225.68`, immediately after the owner touched the screen. The device
  had been idle with no adb traffic, so the alarm could not fire.
- Edge #5 (49 s) happened with `mWakefulness=Awake` and the screen deliberately held on: the alarm
  fired on its normal cadence, but not instantly.
- The owner's impression that updates correlated with adb polling is explained the same way:
  **adb traffic keeps the device awake, which lets the deferred alarm fire.** Verified that adb
  polling neither causes nor blocks the update (section 3).

Practical consequence: severity depends on how idle the tablet is at plug-in time, which is why the
bug looks intermittent in normal use.

---

## 7. The absent notification — separate, still unexplained

`dumpsys notification` returned exactly **1** `NotificationRecord` at every check across all five
edges: an unrelated `pkg=android id=89 channel=TrustInterface.tv` notice. Nothing was ever posted to
the `BAT` channel ("Battery", importance 5, sound `LowBattery.ogg`), which exists but stays empty.
Checked at uptime 495, 1310 and 1374 — all while the framework held the correct state.

A 9–223 s delay would still eventually post it. It never appears, so this is an **independent bug in
the SystemUI / notification layer**, not a consequence of the HAL latency. `com.android.systemui` is
alive and its service registered (PID 2202); the specific cause was not identified.

Suggested next step for whoever triages it: capture a logcat ring on SystemUI while plugging in, and
check whether `BatteryController` receives `ACTION_BATTERY_CHANGED` and simply declines to post.

---

## 8. The two fixes

Full detail, evidence and per-task checklists are in **[D1.md](D1.md)** and **[D2.md](D2.md)**.

### D1 — `port/l24-dt-5` @ `647daf4`, `gts4lv.mk` +17/−5

`gts4lv.mk` shipped **two** health HALs and the wrong one won:

```
1098  android.hardware.health-service.samsung    <- registered IHealth/default
1119  vendor.lineage.health-service.default      <- ran, never registered
```

Only the blob ever appears in servicemanager's log, because it starts first. That starved
`vendor.lineage.health-service.default`, which is what implements Lineage's **charging control** —
configured by eleven `soong_config_set` calls at `gts4lv.mk:171-184`
(`charging_control_charging_path`, `fast_charge_node`, …). So that user-facing feature has been
**silently dead**.

D1 removes the blob and keeps the Lineage HAL. **The direction was chosen by build safety under the
"no build" constraint**, not by preference: the Lineage HAL provides the `lineage_health` Soong
config module (`hardware/lineage/interfaces/health/aidl/default/Android.bp:62`) that those eleven
calls read, so removing *it* would strand them — a build failure that cannot be checked without
building. The blob has no other reference in the tree (`grep -rn "health-service.samsung"` → only
`gts4lv.mk:160-161`; no init rc, no VINTF, no recovery root).

Supporting convention: `analysis/reference-trees/exynos9810-common-22.2-to-23.2.tsv` shows
`503ffa8` "Use bool Soong config for charging bypass" and `c837cad` "overlay: Enable battery cycle
count" — Lineage's own health HAL plus Soong config is what the sibling Exynos trees use.

**Confidence: medium.** The registration loss and dead feature are directly observed. That the Lineage
HAL is *sufficient* is inferred, not verified.

### D2 — `port/l24-dt-6` @ `a8b5d8e`, 3 sepolicy files, **+3/−0**

Three live denials, `permissive=0`:

```
hal_thermal_default -> /sys/devices/virtual/sec/sec-ap-thermistor/temperature
hal_thermal_default -> /sys/devices/virtual/sec/sec-pa-thermistor/temperature
hal_thermal_default -> /sys/devices/virtual/sec/sec-bk-thermistor/temperature
```

All resolve to generic `sysfs`. This is the same gap `1188e2b` closed one commit earlier — it granted
`hal_thermal_default` `sysfs_batteryinfo` and `sysfs_switch` but missed the thermistors. D2 follows
the established pattern (`e7652fc`, `efd222f`, `1188e2b`): new `sysfs_sec_thermistor` type in
`file.te:53`, labels in `file_contexts:193`, one `r_dir_file` in `hal_thermal_default.te:2`.

Pre-commit checks: no `file_contexts` rule shadows the new entry (the `fc_sort` stem-length hazard
from `1188e2b` does not apply — there is no broad `/sys/devices/virtual/sec` rule); and
`sysfs_sec_thermistor` is not already declared in platform sepolicy. **Confidence: high**, additive,
narrowly scoped. Unverified: that these are the *only* remaining thermal denials, and sepolicy
compilation, which needs a build.

---

## 9. The 23.2 backport — verified, and a recommendation

Both commits were cherry-picked with `-n` onto a scratch worktree of `anton/lineage-23.2`:
**both exit 0, zero conflicts, zero unmerged paths, 4 files / +20/−5.** (Scratch worktree deleted
afterwards; the live 24 build tree is untouched on `port/l24-dt-4`.)

Two independent reasons it applies cleanly:

- D2's three sepolicy files are **byte-identical** between the branches.
- D1's health block in `gts4lv.mk` is **byte-identical**. The 8/4 `gts4lv.mk` divergence is entirely
  elsewhere, all of it L6's FCM 7 work: `disable_configstore` removal, `libui legacy_gralloc`,
  `libion legacy_impl`.

What changes on a 23.2 build: D1 makes charging control live for the first time; D2 gives the thermal
HAL three sensors it was blocked from. Rebuild should be partial — the 23.2 `out/` is still warm
(161 GB, untouched since Oct 8). Reinstall needs **no Format data**: `testkey.pk8` and `platform.pk8`
are byte-identical across both trees and git-tracked in `build/make`, and the 23.2 recovery is
already on the tablet.

**Recommendation: split them.** Backport **D2 only** to 23.2 now (additive, effectively zero risk).
Hold **D1** until you have ruled on the medium-confidence question, because it is the only one that
changes user-facing behaviour.

---

## 10. D1 doubles as an experiment for the open question

Every lag figure in section 4 was measured with the **Samsung blob** owning `IHealth/default`. D1
replaces that implementation with Lineage's AIDL HAL, so **the propagation path changes entirely**.
Re-running the probe after D1 is a free A/B test of the erratic-lag model: if the 8.7–223 s spread
collapses, the blob's callback policy was the cause and D1 fixes the delay too. If it persists, the
problem is deeper than the HAL.

---

## 11. Disproved along the way — please don't re-litigate these

- **Not the port's kernel work.** `drivers/battery_v2/` has **zero** commits since 2021. The 446-line
  battery DTS was added by ExyHyperBrick's `5b2292881394` ("Import Samsung DTS from T725XXU2DUD1"), part
  of the upstream base. The only P-series commit touching `drivers/power/supply/` is `d6239359349d`
  (P3), which touches only **Qualcomm** drivers (`qcom/battery.c`, `qcom/smb1390-charger.c`,
  `qcom/step-chg-jeita.c`) this board does not instantiate. Measured end-to-end at 0.47 s.
- **`level(100%)` in kernel logs is not the battery percentage.** It is `battery->siop_level`, the
  charge-current limit: format string at `sec_battery.c:3495`, argument at `:3513`. It does not
  contradict `capacity=49`.
- **Kernel poll cadence is not the cause.** `battery,polling_time = <10 30 30 30 3600>` with
  `polling_type = <1>` (alarm) gives ~10 s charging / ~30 s discharging, but attach is IRQ-driven and
  does not wait for a poll.
- **`dumpsys battery` polling does not manufacture updates** (section 3).
- **adb polling does not cause or block the update** (section 3).

---

## 12. Decisions needed from you

1. **D1 — accept or reject?** Specifically: does `vendor.lineage.health-service.default` populate
   every battery field the Samsung blob did, on *this* device? Note `drivers/battery_v2/sec_battery.c`
   exports no `POWER_SUPPLY_CYCLE_COUNT` (grep returns nothing), so cycle count likely does not work
   either way — but that needs confirming on device, not assuming.
2. **D1's first runtime failure may be an untested feature, not a regression.** Charging control has
   never run on this device. Please judge it that way.
3. **Merge order** for `port/l24-dt-5` and `port/l24-dt-6`, and whether either should land before the
   notification question is understood.
4. **23.2 backport: D2 only (recommended) or both?**
5. **The absent notification** — how to triage it (SystemUI logcat during plug-in is my suggestion).
6. **The erratic 8.7–223 s propagation** — accept and document as blob behaviour, or chase it?
7. **Run the D1 A/B experiment** (section 10) or drop that thread?

---

## 13. State and provenance

**Device:** `SM-T720` / `gts4lvwifi`, serial `<serial>`, over **wireless** adb at
`192.168.86.233:5555` so the USB-C port stayed free for the charger. Build
`23.2-20261008-UNOFFICIAL-gts4lvwifi`, `userdebug`. `adb root` is refused by a Developer-options
toggle on this build; `dmesg` is denied to shell, but `logcat -b kernel` works and was used instead.

**Not done:** no build run, no push to any fork, nothing merged to `main`. The live 24 build tree is
untouched on `port/l24-dt-4`. The tablet is left charging and consistent; the only device-side file
written was `/data/local/tmp/bat-poll.log`.

**Artifacts** (local, `~/work/`, **not** in the repo): `batwatch.sh`, `fwwatch.sh`,
`fwwatch-fast.sh`, `precharge-logcat.txt` (27,694 lines), `charge-logcat.txt`,
`bat-poll-cycle2.log`, `fw-poll-cycle2.log`, `bat-poll.log`, `fw-poll-cycle3.log`,
`fw-poll-cycle3b.log`, `cycle2-logcat.txt`, `charging-notification-findings.md`.

Full `logcat -b all -d` dumps contain device serials and MACs and are git-ignored by project
convention; excerpts only belong in the repo. No dumps were committed.

**Worktrees created:** `~/work/wt/fork-D1` (`port/l24-dt-5`), `~/work/wt/fork-D2` (`port/l24-dt-6`),
`~/work/wt/D1` (`agent/D1`), `~/work/wt/D2` (`agent/D2`).