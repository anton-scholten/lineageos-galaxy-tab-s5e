#!/bin/bash
# SPDX-FileCopyrightText: 2026 Anton Scholten
# SPDX-License-Identifier: Apache-2.0
#
# make-recovery-zip.sh -- a flashable zip that installs our recovery from another LineageOS recovery
# (official 22.2, our 23.2) over USB-OTG, SD card or sideload, without a PC flashing tool.
#
#   scripts/make-recovery-zip.sh <tree> <device> <recovery.img> <out.zip>
#
# The installer (scripts/recovery-installer/update-binary) is a shell script: the Android 16/17 updater
# binary aborts on the 22.2 recovery's kernel (no MADV_WIPEONFORK), so it can't be used here.
# The zip is signed like the ROM (signapk -w with the tree's releasekey); other recoveries show
# "Signature verification failed" and the user answers Yes. The key files are only passed to signapk.
set -euo pipefail

[ $# -eq 4 ] || { sed -n 5,13p "$0"; exit 2; }
tree=$1 dev=$2 img=$3 out=$4
here=$(cd "$(dirname "$0")" && pwd)
key=$tree/vendor/lineage-priv/keys/releasekey
host=$tree/out/host/linux-x86

case $dev in gts4lv | gts4lvwifi) ;; *) echo "unknown device $dev" >&2; exit 2 ;; esac
[ -f "$img" ] || { echo "no $img" >&2; exit 1; }
[ -f "$key.pk8" ] && [ -f "$key.x509.pem" ] || { echo "no releasekey in $tree" >&2; exit 1; }
[ -f "$host/framework/signapk.jar" ] || { echo "no signapk.jar in $tree/out (build first)" >&2; exit 1; }

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/META-INF/com/google/android"
sed "s/@DEVICE@/$dev/" "$here/recovery-installer/update-binary" >"$work/META-INF/com/google/android/update-binary"
echo "# dummy, the installer is update-binary" >"$work/META-INF/com/google/android/updater-script"
cp "$img" "$work/recovery.img"
(cd "$work" && sha256sum recovery.img >recovery.img.sha256)
(cd "$work" && zip -q -X -r "$work/unsigned.zip" META-INF recovery.img recovery.img.sha256)

java -Djava.library.path="$host/lib64" -jar "$host/framework/signapk.jar" -w \
	"$key.x509.pem" "$key.pk8" "$work/unsigned.zip" "$out"
echo "$out"
