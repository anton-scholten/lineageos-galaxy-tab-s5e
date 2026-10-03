#!/usr/bin/env bash
# ============================================================================
# task: T1 | agent: Space Bunny Free (opencode) | date: 2026-10-03
#
# device-checks.sh -- read-only health checks for a booted Galaxy Tab S5e
# (gts4lvwifi = SM-T720, gts4lv = SM-T725/T727) running the LineageOS 23.2
# port with the ExyHyperBrick eBPF backport.
# Spec: AGENT-TASKS.md section 6, task T1.
#
# WHAT IT DOES
#   Runs 6 checks over `adb` against a BOOTED tablet, prints PASS / FAIL / SKIP
#   per check plus a summary line, and saves everything it prints to
#   device-checks-<date>.log in the current directory (override with -l).
#
# READ-ONLY.  Every adb command below only reads. This script contains no
#   command that flashes, writes, formats, erases, wipes, factory-resets,
#   reboots, or enters download mode / recovery / fastboot, and no command that
#   touches /data, /system or any partition. The only thing it writes is the
#   .log file on the HOST, in the directory you run it from.
#
# USAGE
#   scripts/device-checks.sh                  # log -> ./device-checks-<date>.log
#   scripts/device-checks.sh -s SERIAL        # pick one of several devices
#   scripts/device-checks.sh -l /tmp/t1.log   # choose the log file
#   scripts/device-checks.sh -t 120           # wait up to 120 s for the device
#   scripts/device-checks.sh -h               # this help
#
# NEEDED
#   bash 4+, adb in PATH (Android platform-tools), USB debugging enabled and
#   accepted on the tablet. Check 2 also needs root; with no su it reports SKIP
#   rather than FAIL.
#
# THE 6 CHECKS
#   1  print `uname -r`; ro.bpf.kver_override must be exactly 5.15.178
#      (device-tree patch 0004, PORTING-LINEAGE-23.2.md)
#   2  `su -c 'ls /sys/fs/bpf'` must be non-empty  (SKIP if there is no su)
#   3  `dumpsys netd`, first 50 lines, must not mention an error
#   4  `logcat -d -b all`: no FATAL and no abort from bpfloader / netbpfload
#   5  `ping -c 3 8.8.8.8` must report 0% packet loss
#   6  record `uptime`, and remind to rerun after a 24 h soak
#      (KERNEL-BACKPORT-PLAN.md, step 4)
#
# EXIT CODE
#   0 = every check PASS or SKIP, 1 = at least one FAIL, or the script could
#   not start at all (no adb, no device, device not booted), 2 = bad usage.
#
# NOTES FOR THE LEAD
#   * *.log is not in .gitignore, so a log left in the repo after a test run
#     shows up in `git status`. Delete it, or add *.log to .gitignore yourself
#     (this task is only allowed to write this one file).
#   * Written on a machine with no tablet and no adb, so it has never run
#     against real hardware. Its control flow was tested against a fake `adb`
#     stub. See "## Problems" in the T1 hand-in.
# ============================================================================

set -uo pipefail

# ------------------------------------------------------------------ settings
readonly EXPECTED_KVER='5.15.178'          # device-tree patch 0004
DEVICE_WAIT_SECS="${DEVICE_WAIT_SECS:-60}" # how long to wait for a device
CMD_TIMEOUT="${CMD_TIMEOUT:-120}"          # how long any single adb call may run
SERIAL=''
LOG_FILE=''

# ------------------------------------------------------------------ counters
pass=0
fail=0
skip=0

# ------------------------------------------------------------------- helpers
die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    cat <<'EOF'
Usage: scripts/device-checks.sh [-s SERIAL] [-l LOGFILE] [-t SECONDS]

Read-only PASS/FAIL/SKIP health checks for a booted Galaxy Tab S5e over adb.
All output is also saved to LOGFILE (default: ./device-checks-<date>.log).

  -s SERIAL    run against this device only (needed if several are connected)
  -l LOGFILE   write the log here instead of ./device-checks-<date>.log
  -t SECONDS   how long to wait for the device to appear (default 60)
  -h           this help

Exit: 0 all checks PASS/SKIP, 1 a check FAILed or no usable device, 2 bad usage.
This script only reads from the device. It never flashes, wipes, formats,
erases, reboots or enters download/recovery/fastboot mode.
EOF
}

report() {  # report <PASS|FAIL|SKIP> <check-id> <message>
    case $1 in
        PASS) pass=$((pass + 1)) ;;
        FAIL) fail=$((fail + 1)) ;;
        SKIP) skip=$((skip + 1)) ;;
    esac
    printf '%s  %-14s %s\n' "[$1]" "$2" "$3"
}

note() { printf '       %s\n' "$*"; }

show() {  # show <text> [max-lines=20] -- print indented, truncated output
    local text=$1 max=${2:-20} n
    n=$(printf '%s\n' "$text" | wc -l)
    printf '%s\n' "$text" | sed -n "1,${max}p" | sed 's/^/         | /'
    if ((n > max)); then
        printf '         | ... %d more line(s)\n' "$((n - max))"
    fi
    return 0
}

# Run a command with a wall-clock limit, so no dead device can hang us.
# Uses coreutils `timeout` when present, otherwise a sleep+kill watchdog.
# Returns 124 on timeout (like GNU timeout), otherwise the command's status.
run_limited() {  # run_limited <seconds> <command> [args...]
    local secs=$1
    shift
    # </dev/null so the command can never eat this script's stdin.
    if [[ -n ${TIMEOUT_BIN:-} ]]; then
        "$TIMEOUT_BIN" "$secs" "$@" </dev/null
        return $?
    fi
    # Portable fallback for hosts without coreutils `timeout` (macOS). Three
    # details matter here:
    #   * `set -m` puts the command in its own process group, so the kill
    #     reaches the whole tree (adb spawns a real adb process, and a lingering
    #     descendant would keep the pipe open in `adb_do` and block the caller).
    #   * Polling, not a `sleep; kill` watchdog: the watchdog would inherit this
    #     function's stdout and hold the pipeline's pipe open after the command
    #     exited, so the caller would block until the watchdog died.
    #   * TERM then KILL, so a command ignoring TERM cannot wedge the run.
    local pid rc elapsed=0 killed=0
    set -m
    "$@" </dev/null &
    pid=$!
    set +m
    while kill -0 "$pid" 2>/dev/null; do
        if ((elapsed >= secs)); then
            kill -TERM -- "-$pid" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
            sleep 1
            kill -KILL -- "-$pid" 2>/dev/null || kill -KILL "$pid" 2>/dev/null
            killed=1
            break
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    wait "$pid"
    rc=$?
    if ((killed)) || [[ $rc -eq 143 || $rc -eq 137 ]]; then rc=124; fi
    return "$rc"
}

# adb <args...>, CR-stripped (adb sends CRLF on some hosts), time-limited.
# With `set -o pipefail` a failing adb call makes the function return non-zero.
adb_do() { run_limited "$CMD_TIMEOUT" "$ADB_BIN" "${ADB_ARGS[@]}" "$@" 2>&1 | tr -d '\r'; }

# Raw adb call for preflight, used before the device is known to be ready.
adb_raw() { run_limited "$CMD_TIMEOUT" "$ADB_BIN" "${ADB_ARGS[@]}" "$@" 2>&1 | tr -d '\r'; }

# Close the log pipe and wait for tee to flush the log. Call once, last thing.
finish_log() {  # finish_log <tee-pid> <fifo-dir>
    local tee_pid=${1:-} fifo_dir=${2:-}
    [[ -n $tee_pid ]] || return 0
    exec 1>&- 2>&-   # tee now sees EOF on its stdin and can finish
    wait "$tee_pid" 2>/dev/null
    [[ -n $fifo_dir ]] && rm -rf "$fifo_dir"
    return 0
}

# Trim leading/trailing whitespace from $1 into stdout.
trim() {
    local s=$1
    s=${s//$'\r'/}
    s=${s#"${s%%[![:space:]]*}"}
    s=${s%"${s##*[![:space:]]}"}
    printf '%s' "$s"
}

# ------------------------------------------------------------- preflight ---
# Prints exactly one clear error line and exits 1 on any problem, and creates
# no log file, so a bare run on a machine without a tablet fails fast and clean.
preflight() {
    local -a states=()
    local line state serial
    local -A seen=()

    TIMEOUT_BIN=$(command -v timeout || true)

    if ! command -v "$ADB_BIN" >/dev/null 2>&1; then
        die "adb not found in PATH (looked for '$ADB_BIN'). Install the Android platform-tools, then rerun."
    fi
    if [[ ! $DEVICE_WAIT_SECS =~ ^[0-9]+$ ]] || ((DEVICE_WAIT_SECS < 1)); then
        die "-t needs a positive number of seconds (got '$DEVICE_WAIT_SECS')."
    fi
    if [[ ! $CMD_TIMEOUT =~ ^[0-9]+$ ]] || ((CMD_TIMEOUT < 1)); then
        die "CMD_TIMEOUT needs a positive number of seconds (got '$CMD_TIMEOUT')."
    fi

    # What does `adb devices` see right now? ("serial<TAB>state")
    # NB: real adb also prints noise lines around the list ("* daemon not
    # running; starting now at tcp:5037", "List of devices attached", "adb
    # server version ... doesn't match"), so only accept a line of exactly the
    # shape "<serial> <state>".
    local listing rc
    listing=$(adb_raw devices)
    rc=$?
    if ((rc == 124)); then
        die "the adb server did not respond within ${CMD_TIMEOUT}s ('adb devices' timed out). Try 'adb kill-server' and replug the cable."
    fi

    while read -r serial state; do
        [[ -z $serial || -z $state ]] && continue
        seen["$serial"]=$state
        states+=("$state")
    done < <(printf '%s\n' "$listing" |
        awk 'NF >= 2 && $1 != "List" && $1 != "adb" && $1 !~ /^\*/ { print $1 "\t" $2 }')

    if ((${#states[@]} == 0)); then
        die "no device connected: 'adb devices' lists none. Plug the tablet in, enable USB debugging and unlock the screen."
    fi

    if [[ -z $SERIAL ]]; then
        if ((${#states[@]} > 1)); then
            die "$(( ${#states[@]} )) devices connected (${!seen[*]}); rerun with -s SERIAL to pick one."
        fi
        SERIAL=${!seen[*]}
    elif [[ -z ${seen[$SERIAL]+x} ]]; then
        die "device '$SERIAL' is not connected; 'adb devices' shows: ${!seen[*]}"
    fi
    ADB_ARGS=(-s "$SERIAL")

    state=${seen[$SERIAL]}
    case $state in
        device) : ;;
        unauthorized)
            note "'$SERIAL' is unauthorized; waiting up to ${DEVICE_WAIT_SECS}s for the 'Always allow' prompt on the tablet"
            if ! wait_for_device; then
                die "'$SERIAL' is still unauthorized after ${DEVICE_WAIT_SECS}s. Accept the USB debugging prompt on the tablet and unlock it."
            fi
            ;;
        offline)
            note "'$SERIAL' is offline; waiting up to ${DEVICE_WAIT_SECS}s for it to come back"
            if ! wait_for_device; then
                die "'$SERIAL' is still offline after ${DEVICE_WAIT_SECS}s. Replug the cable or 'adb reconnect offline'."
            fi
            ;;
        *)
            die "'$SERIAL' is in state '$state'. This script needs a booted Android device; boot the tablet before running it."
            ;;
    esac

    # adbd is up, but is the framework? Without it dumpsys/logcat give junk.
    local booted='' rc waited=0
    while ((waited < DEVICE_WAIT_SECS)); do
        booted=$(adb_do shell getprop sys.boot_completed); rc=$?
        booted=$(trim "$booted")
        if ((rc != 0)) && grep -qi 'device offline\|device unauthorized\|no devices' <<<"$booted"; then
            die "lost the device while waiting for it to boot: $booted"
        fi
        [[ $booted == 1 ]] && break
        sleep 2
        waited=$((waited + 2))
    done
    if [[ $booted != 1 ]]; then
        die "device '$SERIAL' is not finished booting (sys.boot_completed='${booted:-?}'). Wait for the boot animation to finish and rerun."
    fi
}

# `adb wait-for-device`, bounded. Never hangs on a dead device. Succeeds only if
# the device really reached state "device" afterwards, not just that wait-for-
# device returned.
wait_for_device() {
    # Note: adb prints the wait-for-device result to stderr, so it is dropped
    # here. Preflight messages go to stderr before the log file is opened,
    # which is why they are not captured in the log.
    run_limited "$DEVICE_WAIT_SECS" "$ADB_BIN" "${ADB_ARGS[@]}" wait-for-device </dev/null 2>/dev/null
    local rc=$?
    local state
    state=$(trim "$(adb_raw devices | awk -v s="$SERIAL" '$1 == s { print $2 }')")
    state=${state%%$'\n'*}
    if ((rc == 0)) && [[ $state == device ]]; then
        return 0
    fi
    if ((rc == 124)); then
        note "'adb wait-for-device' did not return within ${DEVICE_WAIT_SECS}s"
    fi
    [[ -n $state ]] && note "state is now '$state'"
    return 1
}

# ------------------------------------------------------------ device info ---
print_device_info() {
    printf '=== device ===\n'
    printf 'serial        : %s\n' "$SERIAL"
    printf 'model         : %s\n' "$(trim "$(adb_do shell getprop ro.product.model)")"
    printf 'device        : %s\n' "$(trim "$(adb_do shell getprop ro.product.device)")"
    printf 'build         : %s\n' "$(trim "$(adb_do shell getprop ro.build.display.id)")"
    printf 'android       : %s (SDK %s)\n' \
        "$(trim "$(adb_do shell getprop ro.build.version.release)")" \
        "$(trim "$(adb_do shell getprop ro.build.version.sdk)")"
    printf 'selinux       : %s\n' "$(trim "$(adb_do shell getenforce)")"
    printf 'adb host      : %s %s\n' "$ADB_BIN" "$(${ADB_BIN} --version 2>/dev/null | head -n 1)"
    printf '\n'
}

# ----------------------------------------------------------- the 6 checks ---

# Check 1: kernel release string + the BPF version override Android 16 needs.
check_kernel_and_kver() {
    local id='1-kernel-kver'
    local uname_r kver u_rc k_rc

    uname_r=$(adb_do shell uname -r); u_rc=$?
    uname_r=$(trim "$uname_r")
    kver=$(adb_do shell getprop ro.bpf.kver_override); k_rc=$?
    kver=$(trim "$kver")

    if ((u_rc != 0)) || [[ -z $uname_r ]]; then
        report FAIL "$id" "could not read 'uname -r' (adb rc=$u_rc)"
        note "an adb shell that cannot run uname means the session or the build is broken;"
        note "check 'adb shell' by hand before trusting any of these results"
        return
    fi
    if ((k_rc != 0)); then
        report FAIL "$id" "could not read 'getprop ro.bpf.kver_override' (adb rc=$k_rc)"
        note "uname -r was $uname_r"
        return
    fi

    if [[ -z $kver ]]; then
        report FAIL "$id" "uname -r = $uname_r, but ro.bpf.kver_override is EMPTY"
        note "device-tree patch 0004 sets ro.bpf.kver_override=$EXPECTED_KVER in product.prop"
        note "(PORTING-LINEAGE-23.2.md). Without it bpfloader and netd refuse to load BPF."
        note "Do not just add the property: on a kernel that is not yet at 5.15 BPF"
        note "level it makes the device bootloop (PORTING-LINEAGE-23.2.md, patch 0004)."
        return
    fi
    if [[ $kver != "$EXPECTED_KVER" ]]; then
        report FAIL "$id" "uname -r = $uname_r, ro.bpf.kver_override = $kver, expected $EXPECTED_KVER"
        note "$EXPECTED_KVER is what the ExyHyperBrick-based kernel that this port copies reports"
        note "(analysis/exyhyperbrick-trial/README.md). A 5.4.x value belongs to the"
        note "from-scratch 5.4-parity route, not to this one."
        return
    fi

    report PASS "$id" "uname -r = $uname_r, ro.bpf.kver_override = $kver (as expected)"
    note "uname -r stays 4.9.x on this port on purpose; the override is what bpfloader,"
    note "netbpfload, netd and UprobeStats are shown (kernel/sys.c in the backport)."
}

# Check 2: the bpffs must hold pinned BPF programs. Needs root.
check_bpf_fs() {
    local id='2-bpf-fs'
    local su_path out rc

    su_path=$(trim "$(adb_do shell 'command -v su || which su')")
    if [[ -z $su_path ]]; then
        report SKIP "$id" "no 'su' on the device, cannot check /sys/fs/bpf"
        note "expected: BPF programs pinned by netbpfload. Check by hand later with"
        note "'adb shell su -c \"ls -R /sys/fs/bpf\"' on a rooted build."
        return
    fi
    note "su found at '$su_path'"

    out=$(adb_do shell su -c 'ls /sys/fs/bpf'); rc=$?
    out=$(trim "$out")
    if ((rc != 0)); then
        report FAIL "$id" "'su -c \"ls /sys/fs/bpf\"' failed (rc=$rc)"
        show "$out" 10
        note "rc != 0 means su exists but refused this shell (no root grant), or the"
        note "command failed. Grant root to the shell user and rerun."
        return
    fi
    if [[ -z $out ]]; then
        report FAIL "$id" "/sys/fs/bpf is EMPTY: no BPF programs are pinned"
        note "netbpfload did not load anything. Cross-check with check 4 and with"
        note "'adb shell ps -A | grep -i netbpf' and 'adb logcat -b all -d | grep -i bpf'."
        return
    fi

    local n
    n=$(printf '%s\n' "$out" | wc -l)
    report PASS "$id" "/sys/fs/bpf has $n entry/entries (BPF is pinned)"
    show "$out" 20
}

# Check 3: netd must be alive and not logging errors.
check_netd() {
    local id='3-netd'
    local out hits

    out=$(adb_do shell dumpsys netd | head -n 50 || true)
    out=$(trim "$out")

    if [[ -z $out ]]; then
        report FAIL "$id" "'dumpsys netd' printed nothing: the netd service is not reachable"
        note "netd is the process that loads the networking BPF programs. If it is"
        note "missing, check 4 will say why."
        return
    fi
    if grep -qi "can't find service\|can't be found" <<<"$out"; then
        report FAIL "$id" "'dumpsys netd' says the service does not exist"
        show "$out" 10
        note "netd is not registered. That is the classic symptom of a netbpfload"
        note "failure on a kernel whose BPF is not at the advertised level."
        return
    fi

    if hits=$(grep -in 'error' <<<"$out"); then
        report FAIL "$id" "'error' appears in the first 50 lines of dumpsys netd"
        show "$hits" 10
        note "read the matching lines above: a real error fails this check, a harmless"
        note "counter or field name containing 'error' does not."
        return
    fi
    report PASS "$id" "no 'error' in the first 50 lines of dumpsys netd"
    show "$out" 50
}

# Check 4: bpfloader / netbpfload must not have died.
check_logcat_bpf() {
    local id='4-bpf-logcat'
    local raw rc lines hits n

    raw=$(adb_do shell logcat -d -b all); rc=$?
    if ((rc != 0)); then
        report FAIL "$id" "'logcat -d -b all' failed (rc=$rc)"
        show "$raw" 10
        return
    fi
    if grep -qi 'unable to open log device\|error: unable' <<<"$raw"; then
        report FAIL "$id" "could not read logcat: '$(grep -im1 'unable to open log device\|error: unable' <<<"$raw")'"
        note "some user builds hide the all-buffer from the shell user. Read it as root:"
        note "'adb shell su -c \"logcat -d -b all -t 5000\"'."
        return
    fi

    lines=$(grep -iE 'bpfloader|netbpfload' <<<"$raw" || true)
    if [[ -z $lines ]]; then
        report PASS "$id" "no FATAL and no abort from bpfloader/netbpfload (no output from either at all)"
        note "WARNING: no bpfloader or netbpfload lines in logcat. That can be good"
        note "(already clean) or mean neither ever ran. Confirm with"
        note "'adb shell ps -A | grep -iE \"bpfloader|netbpf\"' before calling this a pass."
        return
    fi
    n=$(printf '%s\n' "$lines" | wc -l)
    if hits=$(grep -inE 'fatal|abort' <<<"$lines"); then
        report FAIL "$id" "FATAL/abort from bpfloader/netbpfload in logcat ($n line(s) matched)"
        show "$hits" 20
        return
    fi
    report PASS "$id" "no FATAL/abort in the $n bpfloader/netbpfload line(s)"
    show "$lines" 15
}

# Check 5: basic connectivity out of the tablet.
check_network() {
    local id='5-network'
    local out rc

    out=$(adb_do shell ping -c 3 8.8.8.8); rc=$?
    out=$(trim "$out")

    if [[ -z $out ]]; then
        report FAIL "$id" "'ping -c 3 8.8.8.8' printed nothing (rc=$rc)"
        note "ping needs Android 10 or newer (or root). Check by hand with"
        note "'adb shell su -c \"ping -c 3 8.8.8.8\"'."
        return
    fi
    show "$out" 15
    local loss
    loss=$(grep -im1 'packet loss' <<<"$out")
    # Anchored on a non-digit: "100% packet loss" must not match "0% packet loss".
    if grep -qE '(^|[^0-9])0% packet loss' <<<"$out"; then
        report PASS "$id" "3 pings to 8.8.8.8, $loss"
        return
    fi
    # Any other loss figure fails. Note that `ping` exits non-zero on loss too,
    # so the loss text is what decides, not the exit code.
    report FAIL "$id" "expected 0% packet loss, got: ${loss:-no packet-loss line at all} (rc=$rc)"
    note "turn Wi-Fi on and unlock the tablet first, then rerun"
    note "'adb shell ping -c 3 <your-gateway>' to check the local link before"
    note "blaming the kernel. ICMP to the internet may also just be filtered."
}

# Check 6: record uptime; the real result of this one is the 24 h rerun.
check_uptime_soak() {
    local id='6-uptime-soak'
    local out

    out=$(trim "$(adb_do shell uptime)")
    if [[ -z $out ]]; then
        report FAIL "$id" "could not read 'uptime'"
        note "'adb shell uptime' printed nothing, so the soak cannot be timed."
        return
    fi
    report PASS "$id" "uptime recorded (informational): $out"
    note "This check only records. A soak is not done by one run: rerun this script"
    note "after 24 h of uptime and confirm no new FAILs appeared in the meantime"
    note "(KERNEL-BACKPORT-PLAN.md step 4). Watch for slow log growth too:"
    note "'adb shell su -c \"cat /sys/fs/pstore/console-ramoops*\"' after a crash."
}

# -------------------------------------------------------------------- main ---
main() {
    local opt
    while getopts ':s:l:t:h' opt; do
        case $opt in
            s) SERIAL=$OPTARG ;;
            l) LOG_FILE=$OPTARG ;;
            t) DEVICE_WAIT_SECS=$OPTARG ;;
            h) usage; exit 0 ;;
            \?) usage >&2; exit 2 ;;
        esac
    done
    shift $((OPTIND - 1))
    # getopts does not shift, so a leftover non-option argument means the user
    # wrote something we do not understand.
    [[ $# -eq 0 ]] || { printf 'unexpected argument: %s\n\n' "$1" >&2; usage >&2; exit 2; }

    local ADB_BIN=${ADB_BIN:-adb}
    local -a ADB_ARGS=()

    # Preflight first: on failure it prints one error line and exits 1 without
    # creating a log file.
    preflight

    [[ -n $LOG_FILE ]] || LOG_FILE="device-checks-$(date +%F).log"
    local logdir=${LOG_FILE%/*}
    [[ $logdir == "$LOG_FILE" ]] && logdir=.
    if [[ ! -d $logdir || ! -w $logdir ]]; then
        local why='no such directory'
        [[ -d $logdir ]] && why='directory not writable'
        printf 'WARNING: cannot write the log to %s (%s); continuing without logging.\n' \
            "$LOG_FILE" "$why" >&2
        LOG_FILE=/dev/null
    fi

    # Send everything to the terminal and the log at once. A FIFO plus an
    # explicit tee PID is used instead of `> >(...)`, so finish_log can wait for
    # tee without deadlocking: a bare `wait` would also wait for the tee child,
    # which cannot exit until this script closes its stdout.
    local fifo_dir='' fifo='' tee_pid=''
    if [[ $LOG_FILE != /dev/null ]]; then
        fifo_dir=$(mktemp -d "${TMPDIR:-/tmp}/device-checks.XXXXXX") \
            || die "cannot create a temp directory for the log pipe."
        fifo="$fifo_dir/log.pipe"
        if ! mkfifo "$fifo"; then
            rm -rf "$fifo_dir"
            die "cannot create the log pipe $fifo."
        fi
        tee -- "$LOG_FILE" < "$fifo" &
        tee_pid=$!
        exec 1>"$fifo" 2>&1
    fi

    printf '=== device-checks.sh: read-only checks, %s ===\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    printf 'log           : %s\n' "$LOG_FILE"
    printf 'expect kver   : %s (ro.bpf.kver_override)\n' "$EXPECTED_KVER"
    printf '\n'

    print_device_info

    check_kernel_and_kver
    check_bpf_fs
    check_netd
    check_logcat_bpf
    check_network
    check_uptime_soak

    printf '\n'
    printf 'SUMMARY: %d PASS, %d FAIL, %d SKIP, %d checks total\n' \
        "$pass" "$fail" "$skip" "$((pass + fail + skip))"
    if ((fail > 0)); then
        printf 'RESULT: FAILED (%d check(s) failed)\n' "$fail"
        printf 'Log kept at %s\n' "$LOG_FILE"
        finish_log "$tee_pid" "$fifo_dir"
        exit 1
    fi
    printf 'RESULT: OK (no failing checks)\n'
    printf 'Log kept at %s\n' "$LOG_FILE"
    finish_log "$tee_pid" "$fifo_dir"
    exit 0
}

main "$@"