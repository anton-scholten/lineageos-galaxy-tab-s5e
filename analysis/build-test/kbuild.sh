#!/bin/bash
# usage: kbuild.sh <srcdir> <outdir> <log>
# LLVM=1 needs the UNVERSIONED tools (llvm-nm, llvm-objcopy, ...). Without them the build can still exit 0 with a silently
# wrong vdso_offset_sigtramp (broken sigreturn trampoline). Refuse to start instead. Fix: RUNBOOK.md §5 (llvmbin symlinks).
for t in clang ld.lld llvm-nm llvm-objcopy llvm-objdump llvm-ar llvm-readelf llvm-strip; do
    command -v "$t" >/dev/null || { echo "kbuild.sh: '$t' not on PATH (see RUNBOOK.md §5)"; exit 2; }
done
cd "$1"
M="make -j4 O=$2 ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang LD=ld.lld CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- SEC_BUILD_OPTION_VTS=true"
start=$(date +%s)
$M gts4lvwifi_defconfig > "$3" 2>&1
# Host-env workaround only: 32-bit vDSO link needs the AOSP prebuilt toolchain layout.
scripts/config --file "$2/.config" -d COMPAT_VDSO >> "$3" 2>&1
$M olddefconfig >> "$3" 2>&1
$M -k Image.gz-dtb >> "$3" 2>&1
echo "EXIT=$? SECONDS=$(( $(date +%s)-start ))" >> "$3"
