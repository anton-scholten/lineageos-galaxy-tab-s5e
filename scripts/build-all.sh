#!/bin/bash
# Release builds for the Tab S5e: LineageOS 23.2 and 24, Wi-Fi and LTE, one after another.
#
#   scripts/build-all.sh            check, then build everything
#   scripts/build-all.sh --check    only run the pre-build checks
#   ONLY="23.2:gts4lvwifi" scripts/build-all.sh    build a subset
#
# Trees live on the build drive at their real paths (no bind mounts, no symlinks):
#   /mnt/build/lineage-23.2   /mnt/build/lineage-24
# Results are copied (real copies, never hard links: the build rewrites outputs in place) to
#   /mnt/build/releases/<version>-<run start date>.partial/  while the run is going, then the folder is
#   renamed to <version>-<date the last build of that version finished> once all its devices are in.
# File names: the zip keeps its build name (= ro.lineage.version, so never rename it); its recovery and
# vbmeta get the zip's date: recovery-<zip date>-<device>.img. A run that crosses midnight can therefore
# hold zips with two dates (the build date is fixed when each build starts).
# Logs: ~/work/build-<version>-<run start date>-<device>.log, summary in ~/work/build-all-<run start date>.log.
#
# Restarting: re-run the script on the same day. A build that was interrupted resumes where ninja stopped
# (same path, same environment); a device whose zip is already in the .partial folder is skipped.
set -u

DATE=$(date +%Y%m%d) # run start date: names the logs and the .partial folders
REL=/mnt/build/releases
SUMMARY=$HOME/work/build-all-$DATE.log
BUILDS=(
	"23.2|/mnt/build/lineage-23.2|lineage-23.2|gts4lvwifi"
	"23.2|/mnt/build/lineage-23.2|lineage-23.2|gts4lv"
	"24.0|/mnt/build/lineage-24|lineage-24.0|gts4lvwifi"
	"24.0|/mnt/build/lineage-24|lineage-24.0|gts4lv"
)
KERNEL_FIX=8d39d4284f85 # charging indicator fix (BPF ld_abs R2); must be in every kernel we ship

mkdir -p "$HOME/work"
log() { echo "$(date '+%F %T') $*" | tee -a "$SUMMARY"; }
fail=0
bad() { log "CHECK FAILED: $*"; fail=1; }

check() {
	log "== pre-build checks"
	if pgrep -f "out/soong_ui --build-mode" >/dev/null || pgrep -x siso >/dev/null; then
		bad "another build is running"
	fi
	if mount | grep -q " $HOME/android/lineage "; then
		bad "old bind mount still at ~/android/lineage (sudo umount ~/android/lineage)"
	fi
	local done_trees=" "
	for b in "${BUILDS[@]}"; do
		IFS='|' read -r ver tree branch dev <<<"$b"
		[[ $done_trees == *" $tree "* ]] && continue
		done_trees+="$tree "
		[ -f "$tree/build/envsetup.sh" ] || { bad "$tree is not a source tree"; continue; }
		[ -L "$tree" ] && bad "$tree is a symlink"
		[ -e "$tree/out" ] && log "note: $tree/out exists (incremental build)"
		grep -q "remote=\"anton\" revision=\"$branch\"" "$tree"/.repo/local_manifests/gts4lv-common.xml ||
			bad "$tree local manifest does not track anton $branch"
		# Every project our local manifests take from the anton-scholten forks must sit exactly on the
		# fork branch tip, with no local changes.
		while read -r path name rev; do
			local url="https://github.com/anton-scholten/$name" g="$tree/$path" tip head
			tip=$(git ls-remote "$url" "refs/heads/$rev" | cut -c1-12)
			head=$(git -C "$g" rev-parse HEAD 2>/dev/null | cut -c1-12)
			[ -n "$tip" ] || { bad "$url has no branch $rev"; continue; }
			[ "$head" = "$tip" ] || bad "$g at $head, fork $rev tip is $tip"
			[ -z "$(git -C "$g" status --porcelain)" ] || bad "$g has uncommitted changes"
			log "ok  $ver $path @ $head"
		done < <(python3 -c '
import sys, xml.etree.ElementTree as ET
for f in sys.argv[1:]:
    for p in ET.parse(f).getroot().iter("project"):
        if p.get("remote") == "anton":
            print(p.get("path"), p.get("name"), p.get("revision"))' "$tree"/.repo/local_manifests/*.xml)
		git -C "$tree/kernel/samsung/sdm670" merge-base --is-ancestor $KERNEL_FIX HEAD 2>/dev/null ||
			bad "$tree kernel lacks $KERNEL_FIX"
		# Release = the 20261008 configuration: userdebug, ro.debuggable=0, no insecure adb, SELinux enforcing.
		if grep -rqE "^[^#]*(WITH_ADB_INSECURE|ro\.adb\.secure=0|ro\.secure=0|androidboot\.selinux=permissive|BUILD_BROKEN_)" \
			"$tree"/device/samsung/gts4lv* --include=*.mk --include=*.prop 2>/dev/null; then
			bad "$tree device tree has a debug/test option"
		fi
	done
	local free
	free=$(df --output=avail -BG /mnt/build | tail -1 | tr -dc 0-9)
	[ "$free" -ge 250 ] || bad "only ${free} GB free on /mnt/build (want >= 250)"
	log "free on /mnt/build: ${free} GB"
	return $fail
}

build_one() { # ver tree dev
	local ver=$1 tree=$2 dev=$3 out dest zip zdate
	dest=$REL/$ver-$DATE.partial
	if ls "$dest"/lineage-$ver-*-UNOFFICIAL-$dev.zip >/dev/null 2>&1; then
		log "skip $ver $dev: already in $dest"
		return 0
	fi
	log "start $ver $dev ($tree)"
	env -i HOME="$HOME" USER="$USER" PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 \
		bash --noprofile --norc -c \
		"cd '$tree' && source build/envsetup.sh && breakfast $dev && mka bacon" \
		>"$HOME/work/build-$ver-$DATE-$dev.log" 2>&1
	local rc=$?
	out=$tree/out/target/product/$dev
	zip=$(ls -t "$out"/lineage-$ver-*-UNOFFICIAL-$dev.zip 2>/dev/null | head -1)
	if [ $rc -ne 0 ] || [ -z "$zip" ]; then
		log "FAILED $ver $dev (exit $rc), see ~/work/build-$ver-$DATE-$dev.log"
		return 1
	fi
	zdate=$(basename "$zip" | sed -E "s/^lineage-$ver-([0-9]{8})-.*/\1/")
	mkdir -p "$dest"
	cp "$zip" "$dest/"
	cp "$out/recovery.img" "$dest/recovery-$zdate-$dev.img"
	cp "$out/vbmeta.img" "$dest/vbmeta-$zdate-$dev.img"
	(cd "$dest" && sha256sum lineage-*.zip recovery-*.img vbmeta-*.img >SHA256SUMS)
	log "done  $ver $dev: $dest/$(basename "$zip") ($(grep -m1 -E '^ro\.debuggable=' "$out/system/build.prop" 2>/dev/null))"
}

check || { log "fix the checks above first; nothing built"; exit 1; }
[ "${1:-}" = "--check" ] && exit 0

for b in "${BUILDS[@]}"; do
	IFS='|' read -r ver tree branch dev <<<"$b"
	[ -n "${ONLY:-}" ] && [[ " $ONLY " != *" $ver:$dev "* ]] && continue
	build_one "$ver" "$tree" "$dev"
done

# Finish: a version whose selected devices are all in its .partial folder gets its final name.
for ver in $(printf '%s\n' "${BUILDS[@]}" | cut -d'|' -f1 | sort -u); do
	part=$REL/$ver-$DATE.partial
	[ -d "$part" ] || continue
	complete=1
	for b in "${BUILDS[@]}"; do
		IFS='|' read -r v tree branch dev <<<"$b"
		[ "$v" = "$ver" ] || continue
		[ -n "${ONLY:-}" ] && [[ " $ONLY " != *" $v:$dev "* ]] && continue
		ls "$part"/lineage-$ver-*-UNOFFICIAL-$dev.zip >/dev/null 2>&1 || complete=0
	done
	if [ $complete = 1 ]; then
		final=$REL/$ver-$(date -r "$part/SHA256SUMS" +%Y%m%d)
		if [ -e "$final" ]; then
			log "not renaming $part: $final already exists"
		else
			mv "$part" "$final" && log "release folder: $final"
		fi
	else
		log "incomplete: $part (re-run to finish)"
	fi
done
log "all done"
