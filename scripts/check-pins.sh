#!/usr/bin/env bash
# check-pins.sh -- are the 8 commits this project quotes still where we said they are?
#
# WHAT THIS IS FOR
#   Every commit SHA in this project's docs is a *pin*: a promise that a given
#   repo/branch is at a given commit, e.g. "our fork's lineage-23.2 is based on
#   LineageOS a30605a54f3b" or "the eBPF series ends at baa585f67e0e". A pin
#   rots in two ways: the branch moves on (someone pushed), or the branch is
#   deleted/renamed. Either way every report that cites that SHA is now talking
#   about a commit nobody can reach, and the numbers in it (2,335 clean applies,
#   150 conflicts, 2,599 commits) silently stop being reproducible.
#
# WHO RUNS IT
#   The lead agent, before trusting an older analysis and again at the start of
#   a work session; the owner, to see when it is time to re-pin the docs. It is
#   read-only and touches no repo but github.com.
#
# USAGE
#   bash scripts/check-pins.sh                            # 8 lines, exit 1 on drift
#   CHECK_PINS_VERBOSE=1 bash scripts/check-pins.sh        # + a counts summary
#   GIT_TIMEOUT=120 bash scripts/check-pins.sh            # per-row network timeout
#
# NEEDS
#   bash, git, coreutils (timeout, when present). No python, no jq, no curl.
#
# EXIT CODES
#   0  every pin still holds (fork rows may have moved: that is expected)
#   1  PIN DRIFT: a "pin" row (LineageOS base, or a frozen anton-scholten backup)
#      moved, its branch is gone, or the row could not be checked at all
#   2  this script is broken (e.g. the pin table lost a row) -- fix the script
#
# The two rows marked info below are NOT errors and cannot change the exit code:
#   * our own fork's lineage-23.2 branches are *meant* to move as the eBPF
#     backport and the device patches land;
#   * ExyHyperBrick's S9 kernel is a live upstream tree -- a move there just
#     means he pushed more work, which is news for the lead, not a problem.
#
# Pin table: AGENT-TASKS.md section 3, "M3: pin checker script".
#
# task: M3 | agent: Space Bunny Free (opencode) | date: 2026-10-03

set -uo pipefail

# Don't hang on an interactive credential prompt: every pin is a public repo, so
# anonymous access must work or the row is an error, not a question for a human.
export GIT_TERMINAL_PROMPT=0

GIT_TIMEOUT=${GIT_TIMEOUT:-60}
EXPECTED_ROWS=8

usage() {
	cat <<EOF
usage: bash scripts/check-pins.sh

Checks the ${EXPECTED_ROWS} pinned upstream commits with 'git ls-remote --exit-code'
and prints one line per row: OK, or "MOVED <newsha>".
Exit 0 = pins hold, 1 = pin drift, 2 = script broken.
Env: CHECK_PINS_VERBOSE=1 (counts summary), GIT_TIMEOUT=<seconds>.
EOF
}

case ${1-} in
-h | --help)
	usage
	exit 0
	;;
'') ;;
*)
	echo "check-pins: unknown argument '$1'" >&2
	usage >&2
	exit 2
	;;
esac

# ---------------------------------------------------------------------------
# Pin table:  class | repo | url | branch | expected sha prefix | note
#   class=pin   -> a move here is real drift and sets exit code 1
#   class=info  -> movement is expected or is only news; exit code stays 0
# ---------------------------------------------------------------------------
rows=()
while IFS='|' read -r class repo url branch want note; do
	[[ $class =~ ^[[:space:]]*$ ]] && continue
	[[ $class == \#* ]] && continue
	rows+=("$class|$repo|$url|$branch|$want|$note")
done <<'PINS'
pin|LineageOS/android_kernel_samsung_sdm670|https://github.com/LineageOS/android_kernel_samsung_sdm670|lineage-22.2|a30605a54f3b|LineageOS dropped the device after 22.2; this is the base commit of the sdm670 tree.
pin|LineageOS/android_device_samsung_gts4lv-common|https://github.com/LineageOS/android_device_samsung_gts4lv-common|lineage-22.2|d1b339be7abe|LineageOS device tree; the base our device fork is built on.
info|anton-scholten/android_kernel_samsung_sdm670|https://github.com/anton-scholten/android_kernel_samsung_sdm670|lineage-23.2|a30605a54f3b|OUR FORK, meant to move as the eBPF backport lands. Still equal to LineageOS.
info|anton-scholten/android_device_samsung_gts4lv-common|https://github.com/anton-scholten/android_device_samsung_gts4lv-common|lineage-23.2|2e50286|OUR FORK, meant to move as device patches land. Equals LineageOS d1b339be7abe + patches 0001-0004.
pin|anton-scholten/android_kernel_samsung_exynos9810|https://github.com/anton-scholten/android_kernel_samsung_exynos9810|lineage-22.2|d54533f1546b|FROZEN BACKUP of the S9 kernel: series start d54533f1546b (exy/l222).
pin|anton-scholten/android_kernel_samsung_exynos9810|https://github.com/anton-scholten/android_kernel_samsung_exynos9810|lineage-23.2|baa585f67e0e|FROZEN BACKUP of the S9 kernel: series end baa585f67e0e (exy/l232). All series counts depend on this.
pin|anton-scholten/android_device_samsung_exynos9810-common|https://github.com/anton-scholten/android_device_samsung_exynos9810-common|lineage-23.2|ced977559b13|FROZEN BACKUP of the S9 device tree (used by R7).
info|ExyHyperBrick/android_kernel_samsung_exynos9810|https://github.com/ExyHyperBrick/android_kernel_samsung_exynos9810|lineage-23.2|baa585f67e0e|UPSTREAM S9 kernel, a live tree. A move means ExyHyperBrick pushed more work: consider re-running K1-K6.
PINS

row_count=${#rows[@]}
if ((row_count != EXPECTED_ROWS)); then
	echo "check-pins: pin table has $row_count rows, expected $EXPECTED_ROWS - fix the table" >&2
	exit 2
fi

# ls_remote <url> <ref>: echo the ref's SHA, or nothing.
#   exit 0 -> ref found (SHA on stdout)
#   exit 2 -> ref not found: branch deleted or renamed (--exit-code gives 2)
#   other  -> could not ask (network, auth, repo gone); message on stdout
ls_remote() {
	local url=$1 ref=$2
	if command -v timeout >/dev/null 2>&1; then
		timeout "$GIT_TIMEOUT" git -c credential.helper= ls-remote --exit-code "$url" "$ref" 2>&1
	else
		git -c credential.helper= ls-remote --exit-code "$url" "$ref" 2>&1
	fi
}

ok=0 moved_pin=0 moved_info=0 gone_pin=0 gone_info=0 failed_pin=0 failed_info=0

for row in "${rows[@]}"; do
	IFS='|' read -r class repo url branch want note <<<"$row"
	tag="[$class]"
	out=$(ls_remote "$url" "refs/heads/$branch")
	rc=$?

	case $rc in
	0)
		sha=${out%%[[:space:]]*}
		if [[ ! $sha =~ ^[0-9a-fA-F]{40}$ ]]; then
			printf '%-46s %s %s@%s want %s cannot-parse %s\n' \
				"CHECK-FAILED" "$tag" "$repo" "$branch" "$want" "${sha:-<empty>}"
			note="could not parse a 40-hex SHA from git's answer; $note"
			if [[ $class == pin ]]; then
				failed_pin=$((failed_pin + 1))
			else
				failed_info=$((failed_info + 1))
			fi
			continue
		fi
		;;
	2)
		printf '%-46s %s %s@%s want %s branch does not exist\n' \
			"BRANCH-GONE" "$tag" "$repo" "$branch" "$want"
		note="the branch is gone (deleted or renamed), so this pin cannot be read any more; $note"
		if [[ $class == pin ]]; then
			gone_pin=$((gone_pin + 1))
		else
			gone_info=$((gone_info + 1))
		fi
		continue
		;;
	*)
		one_line=$(printf '%s' "${out%%$'\n'*}" | tr -s ' ')
		printf '%-46s %s %s@%s want %s git failed: %s\n' \
			"CHECK-FAILED" "$tag" "$repo" "$branch" "$want" "$one_line"
		note="could not reach the remote, so the pin is unverified; $note"
		if [[ $class == pin ]]; then
			failed_pin=$((failed_pin + 1))
		else
			failed_info=$((failed_info + 1))
		fi
		continue
		;;
	esac

	# Compare only as many characters as the pin promises (7 or 12 here),
	# case-insensitively, so a 7-char pin stays a 7-char promise.
	len=${#want}
	if [[ ${sha:0:len} == "${want,,}" || ${sha:0:len} == "$want" ]]; then
		printf '%-46s %s %s@%s want %s have %s\n' \
			"OK" "$tag" "$repo" "$branch" "$want" "$sha"
		ok=$((ok + 1))
	else
		printf '%-46s %s %s@%s want %s have %s\n' \
			"MOVED $sha" "$tag" "$repo" "$branch" "$want" "$sha"
		note="the branch moved: re-pin the docs that cite ${want:0:12}; $note"
		if [[ $class == pin ]]; then
			moved_pin=$((moved_pin + 1))
		else
			moved_info=$((moved_info + 1))
		fi
	fi

	[[ -z ${CHECK_PINS_VERBOSE-} || ${CHECK_PINS_VERBOSE-} == 0 ]] ||
		printf '         %s\n' "$note"
done

drift=$((moved_pin + gone_pin + failed_pin))

if [[ -n ${CHECK_PINS_VERBOSE-} && ${CHECK_PINS_VERBOSE-} != 0 ]]; then
	printf -- '--- %d rows: %d OK, %d moved (pin/info %d/%d), %d branch gone (pin/info %d/%d), %d unverified (pin/info %d/%d)\n' \
		"$row_count" "$ok" "$((moved_pin + moved_info))" "$moved_pin" "$moved_info" \
		"$((gone_pin + gone_info))" "$gone_pin" "$gone_info" \
		"$((failed_pin + failed_info))" "$failed_pin" "$failed_info"
	printf -- '--- pin drift: %d (exit 1 if > 0)\n' "$drift"
fi

exit $((drift > 0))