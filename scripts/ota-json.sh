#!/bin/bash
# Write the LineageOS Updater feed for one release, so tablets on an earlier build of the same
# version see the update in Settings → System → Updater.
#
#   scripts/ota-json.sh <release folder> <git tag>
#   e.g. scripts/ota-json.sh /mnt/build/releases/24.0-20261020 v24.0-20261020
#
# Writes ota/<version>/<codename>.json for every zip in the folder (the format the Updater's
# NetworkUpdate parser reads), using the zip's own OTA metadata and the GitHub release download URL.
# Commit and push the JSON only AFTER the GitHub release with that tag is published: until then the
# download URL does not exist. Builds read the feed through lineage.updater.uri (system.prop).
set -euo pipefail

rel=${1:?release folder}
tag=${2:?git tag of the GitHub release}
repo=anton-scholten/lineageos-galaxy-tab-s5e
out_root=$(cd "$(dirname "$0")/.." && pwd)/ota

shopt -s nullglob
zips=("$rel"/lineage-*-UNOFFICIAL-*.zip)
[ ${#zips[@]} -gt 0 ] || { echo "no lineage-*-UNOFFICIAL-*.zip in $rel" >&2; exit 1; }

for zip in "${zips[@]}"; do
	name=$(basename "$zip")
	ver=$(echo "$name" | sed -E 's/^lineage-([0-9.]+)-.*/\1/')
	dev=$(echo "$name" | sed -E 's/.*-UNOFFICIAL-(.*)\.zip$/\1/')
	meta=$(unzip -p "$zip" META-INF/com/android/metadata)
	get() { echo "$meta" | sed -n "s/^$1=//p" | head -1; }
	[ "$(get pre-device)" = "$dev" ] || { echo "$name: metadata device $(get pre-device) != $dev" >&2; exit 1; }
	mkdir -p "$out_root/$ver"
	python3 -I - "$out_root/$ver/$dev.json" <<EOF
import json, sys
entry = {
    "datetime": int("$(get post-timestamp)"),
    "type": "unofficial",
    "version": "$ver",
    "files": [{
        "filename": "$name",
        "sha256": "$(sha256sum "$zip" | cut -d' ' -f1)",
        "size": $(stat -c %s "$zip"),
        "url": "https://github.com/$repo/releases/download/$tag/$name",
        "os_patch_level": "$(get post-security-patch-level)",
        "os_sdk_level": int("$(get post-sdk-level)"),
    }],
}
with open(sys.argv[1], "w") as f:
    json.dump([entry], f, indent=2)
    f.write("\n")
EOF
	echo "wrote ota/$ver/$dev.json ($name)"
done
