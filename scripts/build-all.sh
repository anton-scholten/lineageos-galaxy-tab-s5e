#!/bin/bash
# Release builds for the Tab S5e, in this order: 23.2 Wi-Fi, 23.2 LTE, 24 Wi-Fi, 24 LTE.
# Each finished build is verified as a release build (verify_release) before it is copied.
#
#   scripts/build-all.sh            check, then build everything
#   scripts/build-all.sh --check    only run the pre-build checks
#   ONLY="23.2:gts4lvwifi" scripts/build-all.sh    build a subset
#
# Trees live on the build drive at their real paths (no bind mounts, no symlinks):
#   /mnt/build/lineage-23.2   /mnt/build/lineage-24
# Results are copied (real copies, never hard links: the build rewrites outputs in place) to
#   /mnt/build/releases/<version>-<date the script started>/  with a SHA256SUMS file.
# File names: the zip keeps its build name (= ro.lineage.version, so never rename it); its recovery and
# vbmeta get the zip's date: recovery-<zip date>-<device>.img. A run that crosses midnight can therefore
# hold zips with two dates in one folder (the build date is fixed when each build starts).
# Logs: ~/work/build-<version>-<start date>-<device>.log, summary in ~/work/build-all-<start date>.log.
#
# Restarting: re-run the script on the same day. A build that was interrupted resumes where ninja stopped
# (same path, same environment); a device whose zip is already in the folder is skipped.
set -u

DATE=$(date +%Y%m%d) # script start date: names the logs and the release folders
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
	# A from-scratch build needs ~250 GB per tree; an incremental one (out/ exists) far less.
	local free want=50
	for b in "${BUILDS[@]}"; do
		IFS='|' read -r ver tree branch dev <<<"$b"
		[ -n "${ONLY:-}" ] && [[ " $ONLY " != *" $ver:$dev "* ]] && continue
		[ -e "$tree/out" ] || want=250
	done
	free=$(df --output=avail -BG /mnt/build | tail -1 | tr -dc 0-9)
	[ "$free" -ge $want ] || bad "only ${free} GB free on /mnt/build (want >= $want)"
	log "free on /mnt/build: ${free} GB"
	return $fail
}

# A release build must come out exactly like the published 20261008 release: userdebug with
# ro.debuggable=0, secure adb, no forced debuggability, SELinux not permissive on the kernel command line.
verify_release() { # out log -> prints problems, returns 1 if any
	local out=$1 blog=$2 props bad_=0 v
	# system_ext and product sit inside the system image on this device (system/system_ext/etc/build.prop).
	props="$out/system/build.prop $out/system/system_ext/etc/build.prop $out/system/product/etc/build.prop $out/system_ext/etc/build.prop $out/product/etc/build.prop $out/vendor/build.prop"
	getp() { grep -sh "^$1=" $props | head -1 | cut -d= -f2-; }
	for kv in ro.build.type=userdebug ro.debuggable=0 ro.secure=1 ro.adb.secure=1; do
		v=$(getp "${kv%%=*}")
		[ "$v" = "${kv#*=}" ] || { echo "${kv%%=*}=${v:-<unset>} (want ${kv#*=})"; bad_=1; }
	done
	[ "$(getp ro.force.debuggable)" = 1 ] && { echo "ro.force.debuggable=1"; bad_=1; }
	grep -qa "androidboot.selinux=permissive" "$out/boot.img" && { echo "boot.img cmdline has selinux=permissive"; bad_=1; }
	grep -qE "WITH_ADB_INSECURE=true|TARGET_BUILD_VARIANT=eng" "$blog" && { echo "build log shows an insecure/eng build"; bad_=1; }
	return $bad_
}

build_one() { # ver tree dev
	local ver=$1 tree=$2 dev=$3 out dest zip zdate
	dest=$REL/$ver-$DATE
	if ls "$dest"/lineage-$ver-*-UNOFFICIAL-$dev.zip >/dev/null 2>&1; then
		log "skip $ver $dev: already in $dest"
		return 0
	fi
	log "start $ver $dev ($tree)"
	# Drop stale zip names from earlier builds (hard links to the OTA zip; see below).
	rm -f "$tree/out/target/product/$dev"/lineage-$ver-*-UNOFFICIAL-$dev.zip
	env -i HOME="$HOME" USER="$USER" PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 \
		bash --noprofile --norc -c \
		"cd '$tree' && source build/envsetup.sh && breakfast $dev && mka bacon" \
		>"$HOME/work/build-$ver-$DATE-$dev.log" 2>&1
	local rc=$?
	out=$tree/out/target/product/$dev
	# Take the name from this build's own LINEAGE_VERSION: out/ can hold older zip names that are hard
	# links to the same OTA file the build rewrites in place, so "newest file" picks the wrong name.
	local lver
	lver=$(grep -m1 -oE "^LINEAGE_VERSION=[^ ]+" "$HOME/work/build-$ver-$DATE-$dev.log" | cut -d= -f2)
	zip=$out/lineage-$lver.zip
	[ -n "$lver" ] && [ -f "$zip" ] || zip=
	if [ $rc -ne 0 ] || [ -z "$zip" ]; then
		log "FAILED $ver $dev (exit $rc), see ~/work/build-$ver-$DATE-$dev.log"
		return 1
	fi
	local problems
	if ! problems=$(verify_release "$out" "$HOME/work/build-$ver-$DATE-$dev.log"); then
		log "FAILED $ver $dev: not a release build, not copied: $(echo $problems)"
		return 1
	fi
	zdate=$(basename "$zip" | sed -E "s/^lineage-$ver-([0-9]{8})-.*/\1/")
	mkdir -p "$dest"
	cp "$zip" "$dest/"
	cp "$out/recovery.img" "$dest/recovery-$zdate-$dev.img"
	cp "$out/vbmeta.img" "$dest/vbmeta-$zdate-$dev.img"
	(cd "$dest" && sha256sum lineage-*.zip recovery-*.img vbmeta-*.img >SHA256SUMS)
	log "done  $ver $dev: $dest/$(basename "$zip") (release props verified)"
}

check || { log "fix the checks above first; nothing built"; exit 1; }
[ "${1:-}" = "--check" ] && exit 0

for b in "${BUILDS[@]}"; do
	IFS='|' read -r ver tree branch dev <<<"$b"
	[ -n "${ONLY:-}" ] && [[ " $ONLY " != *" $ver:$dev "* ]] && continue
	build_one "$ver" "$tree" "$dev"
done

log "all done"
