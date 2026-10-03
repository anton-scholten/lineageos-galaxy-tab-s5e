# Reference device trees for lineage-23.2

No LineageOS repo for the Tab S5e has a `lineage-23.2` branch, because the 4.9 kernel blocks it.
So we make our own `lineage-23.2` branches. These other trees show what changed between 22.2 and 23.2,
and we copy from them. Checked 2026-10-03.

| Tree | Why it's useful | Commits 22.2 → 23.2 | List |
|---|---|---|---|
| [`LineageOS/android_device_samsung_sm7125-common`](https://github.com/LineageOS/android_device_samsung_sm7125-common) | **Official** LineageOS 23.2. Samsung + Qualcomm, same LineageOS "legacy" Qualcomm platform setup as ours. Kernel 4.14 | 26 | [`sm7125-common-22.2-to-23.2.tsv`](sm7125-common-22.2-to-23.2.tsv) |
| [`ExyHyperBrick/android_device_samsung_exynos9810-common`](https://github.com/ExyHyperBrick/android_device_samsung_exynos9810-common) | Unofficial 23.2 on a **4.9** kernel (Galaxy S9). Same author as our kernel series. Has the 4.9-specific userspace fixes | 143 | [`exynos9810-common-22.2-to-23.2.tsv`](exynos9810-common-22.2-to-23.2.tsv) |

Lists were made with `git log --reverse --format='%h%x09%ad%x09%an%x09%s' --date=short lineage-22.2..lineage-23.2`.

## sm7125-common: already covered by our patches

| sm7125 commit | Our patch |
|---|---|
| `a4c0bfb` Remove vendor/lineage device framework matrix inclusion | 0001 |
| `7bc5cf4` Update some soong config variables to bool type | 0002 |
| `39eb067` Migrate to LiveDisplay AIDL HAL | 0003 |
| `9849669` Override kernel BPF version (+ `fa32b8f` bump) | 0004 (we use `5.15.178`, not `5.4.299`) |

The other 22 are task R5 in [AGENT-TASKS.md](../../AGENT-TASKS.md). The likely important ones: `88c7b73` (manifest target-level 6),
`2642472` (gatekeeper sepolicy), `aef65d7` (soong_config_set moved to common.mk), `c6ef8e7` (Python extract-utils).
The NFC ones (`37cf59f`, `75d876d`, `ee1d616`) only matter if a Tab S5e model has NFC. The SM-T720/T725 don't, as far as we know: check.

## exynos9810-common: commits that look kernel-4.9-related
Found by searching the subjects for `bpf|uffd|kernel|power supply|freezer`. Task R6 checks all 143.

| Commit | Subject |
|---|---|
| `9b461a0`, `92fef2c` | Override kernel BPF version, bump to 5.15.178 (= our 0004) |
| `751da43` | **Override incompatible power supply BPF filter** |
| `5434d6c`, `a5aa7f1` | Enable UFFD GC / override `PRODUCT_ENABLE_UFFD_GC` to true (needs `CONFIG_USERFAULTFD`) |
| `de12372` | Set Android freezer timeout to 1s |
| `9f28bc7` | Drop kernel LMK minfree write |
| `1b81177` | Use the kernel's Samsung boot image packer (Exynos-specific, probably skip) |

## Dead ends (don't use)
- `LineageOS/android_device_xiaomi_sdm845-common` `lineage-23.2` is the same commit as its `lineage-22.2`. It's a placeholder, and the kernel has no 23.x branch.
- `LineageOS/android_device_google_bonito` (Pixel 3a, sdm670) `lineage-23.0` is *older* than its `lineage-22.2`, and `android_kernel_google_msm-4.9` has no 23.x branch.
  There is an unofficial "LineageOS 23.0 GSI Pixel 3a (sargo) initial bootable base" thread on XDA
  (<https://xdaforums.com/t/alpha-gsi-16-0-lineageos-23-0-unofficial-pixel-3a-sargo-initial-bootable-base.4787590/>).
  The owner already checked it: nothing usable yet (see [PRIOR-WORK.md](../../PRIOR-WORK.md)).
