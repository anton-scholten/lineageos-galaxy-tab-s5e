# Build test: Tab S5e kernel with and without the ExyHyperBrick series

Environment: cloud container, 4 cores, 15 GB RAM, Ubuntu clang 18.1.3 + ld.lld,
`binutils-aarch64-linux-gnu`. Script: [`kbuild.sh`](kbuild.sh)
(`LLVM=1 LLVM_IAS=1`, `gts4lvwifi_defconfig`, `SEC_BUILD_OPTION_VTS=true`).

> `CONFIG_COMPAT_VDSO` was turned off **only to work around this host**. Its 32-bit vDSO link
> needs the AOSP prebuilt toolchain layout that a LineageOS tree provides.

## 1. Baseline: `android_kernel_samsung_sdm670` `lineage-22.2` (`a30605a54f3b`)

- **Builds cleanly:** `Image.gz-dtb` is 15.6 MB, 0 errors, 20 warnings.
- **Full build time:** 12 min 12 s on 4 cores. A typical 8–16-core desktop needs about 4–7 min.

So the toolchain works, and each kernel build-test cycle during the port is short.
Most of each cycle is flashing the tablet and booting it.

## 2. Port tree: series replayed and conflicts auto-resolved to the series side

This is the `trial.py` result (see [`../exyhyperbrick-trial`](../exyhyperbrick-trial/README.md)).
All 238 conflict blocks were taken from the ExyHyperBrick side without review,
and the defconfig options the series enables were added.

**Result:** the build stops while generating `asm-offsets`, the very first
compile step, with 4 errors ([`port-first-errors.txt`](port-first-errors.txt)):

| Error | Cause |
|---|---|
| `unknown type name 'randomized_struct_fields_end'` (`sched.h`) | The series assumes a newer `compiler.h` that the Exynos base had and sdm670 doesn't. A missing prerequisite |
| `'ANDROID_VERSION' is not defined` (`uapi/asm-generic/socket.h`) | A Samsung KNOX block from the Exynos tree came along with the patch context. sdm670 doesn't build with that define |
| `use of undeclared identifier 'TIF_FSCHECK'` (`arm64 uaccess.h`) | Taking the series side dropped a security fix that sdm670 already had (`arm64/syscalls: Check address limit on user-mode return`) |
| `offsetof ... 'int' invalid` (`asm-offsets.c`) | A result of the above |

## What this shows

1. **Conflicts can't be resolved blindly.** Taking "theirs" throws away
   sdm670 fixes, and pulls in Samsung/Exynos code from the patch context. Each of the ~150
   conflicts needs a person to read it. That's what the estimate's conflict effort is based on.
2. **Some prerequisites sit in the Exynos tree's base, not in the series.** 1,079
   commits in ExyHyperBrick's `lineage-22.2` base touch generic kernel code and aren't in
   sdm670 (matched by commit title). Most are f2fs/ext4/block/fscrypt updates that BPF doesn't need.
   A small number (like the `compiler.h` randstruct macros) are needed, and they only show up
   as build errors.
3. **Every build error past this first stage is still unknown.** The prerequisites have to be
   fixed one at a time before the compiler gets as far as the BPF, networking and Qualcomm driver code.
