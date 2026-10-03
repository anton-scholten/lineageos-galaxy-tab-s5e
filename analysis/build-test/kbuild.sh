#!/bin/bash
# usage: kbuild.sh <srcdir> <outdir> <log>
cd "$1"
M="make -j4 O=$2 ARCH=arm64 LLVM=1 LLVM_IAS=1 CC=clang LD=ld.lld CLANG_TRIPLE=aarch64-linux-gnu- CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- SEC_BUILD_OPTION_VTS=true"
start=$(date +%s)
$M gts4lvwifi_defconfig > "$3" 2>&1
# Host-env workaround only: 32-bit vDSO link needs the AOSP prebuilt toolchain layout.
scripts/config --file "$2/.config" -d COMPAT_VDSO >> "$3" 2>&1
$M olddefconfig >> "$3" 2>&1
$M -k Image.gz-dtb >> "$3" 2>&1
echo "EXIT=$? SECONDS=$(( $(date +%s)-start ))" >> "$3"
