#!/usr/bin/env bash
# Apply the LineageOS 23.2 porting patches to a synced source tree.
# Usage: ./apply-patches.sh /path/to/lineage-23.2 [--with-bpf-override]
set -euo pipefail

SRC=${1:?usage: $0 <lineage source root> [--with-bpf-override]}
HERE=$(cd "$(dirname "$0")" && pwd)

for p in "$HERE"/patches/device/samsung/gts4lv-common/*.patch; do
    # The BPF override must only go in once the kernel carries the eBPF backports.
    if [[ $p == *Override-kernel-BPF-version* && ${2:-} != --with-bpf-override ]]; then
        echo "skip  $(basename "$p") (pass --with-bpf-override once the kernel is ready)"
        continue
    fi
    echo "apply $(basename "$p")"
    git -C "$SRC/device/samsung/gts4lv-common" am -3 "$p"
done
