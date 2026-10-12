#!/usr/bin/env bash
# ============================================================================
# boot-log.sh -- read the tablet's boot logs over adb, and triage them
#
# Written 2026-10-12, for the B2 first-boot of LineageOS 24. Companion to
# analysis/port/B2-HANDOFF.md section 4, which says WHAT to look for; this
# says HOW to get it off the tablet and puts the greps in one place.
#
# WHAT IT DOES
#   Read-only. Never writes to the tablet, never reboots it, never runs
#   anything that could change state.
#
#     boot-log.sh              pull logs once, if a device is connected
#     boot-log.sh --wait       wait for a device to appear, then pull
#     boot-log.sh --list       just show what adb sees
#
#   Saves into flash-logs/<timestamp>/ (git-ignored, see below) and prints a
#   triage summary to stdout.
#
# WHY THE SOURCES ARE WHAT THEY ARE
#   /proc/last_kmsg is Samsung's sec_log: the PREVIOUS boot's kernel log from
#   its very first line, and it survives into recovery. That is the single
#   most useful file when the tablet won't boot, because it is the only place
#   the dead boot's own words still exist. pstore is the second copy, written
#   by the panic notifier.
#
#   THE TRAP: every boot OVERWRITES both. Pull them before doing anything else,
#   including before any further reboot or any other flash attempt.
#
# WHY NOT COMMIT THE LOGS
#   They contain the device serial and the Wi-Fi/BT MAC addresses. The repo
#   keeps short redacted excerpts (flash-logs/boot-1-last_kmsg-excerpt.md)
#   and the raw files stay local. .gitignore covers flash-logs/*.
#
# STATES THAT MATTER
#   device                booted into a system; full shell, logcat available
#   recovery              recovery; root shell, last_kmsg + pstore available
#   sideload-authorized   sideload ONLY - no shell. Exit and reboot to
#                         recovery; you cannot read logs in this state.
#   unauthorized          accept the prompt on the tablet, or run
#                         "adb kill-server && adb start-server"
# ============================================================================

set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTROOT="$REPO/flash-logs"
ADB="${ADB:-adb}"

# The kernel this port builds. If last_kmsg does not contain this, the wrong
# kernel booted and every conclusion drawn from the log is about the wrong OS.
EXPECTED_KERNEL_TAG="g500658be3c16"

WAIT=0
LISTONLY=0
case "${1:-}" in
  --wait) WAIT=1 ;;
  --list) LISTONLY=1 ;;
  "")     ;;
  *)      echo "usage: $(basename "$0") [--wait|--list]" >&2; exit 2 ;;
esac

c_red=$'\033[31m'; c_grn=$'\033[32m'; c_yel=$'\033[33m'; c_dim=$'\033[2m'; c_off=$'\033[0m'
say()  { printf '%s\n' "$*"; }
info() { printf '%s==>%s %s\n' "$c_dim" "$c_off" "$*"; }
warn() { printf '%s!! %s%s\n' "$c_yel" "$*" "$c_off"; }
die()  { printf '%sXX %s%s\n' "$c_red" "$*" "$c_off"; exit 1; }

command -v "$ADB" >/dev/null 2>&1 || die "$ADB not found. Install it: sudo apt install adb"

# --------------------------------------------------------------------------
# 1. find the device
# --------------------------------------------------------------------------
# Any entry counts as "attached", NOT just state "device". A tablet sitting in
# sideload-authorized is attached and must be reported as such, not as absent.
device_serial() { "$ADB" devices | awk 'NR>1 && NF>=2 && $1 !~ /^\(/{print $1; exit}'; }
device_state()  {
  local s; s=$(device_serial) || true
  [ -n "${s:-}" ] || return 1
  "$ADB" -s "$s" get-state 2>/dev/null
}

if [ "$LISTONLY" = 1 ]; then
  info "adb sees:"; "$ADB" devices -l; exit 0
fi

if ! device_serial >/dev/null 2>&1; then
  if [ "$WAIT" = 1 ]; then
    warn "no device yet - waiting. Plug in USB, boot to recovery, then hold on."
    info "(Ctrl-C to give up)"
    for _ in $(seq 1 300); do
      sleep 2
      device_serial >/dev/null 2>&1 && break
    done
  fi
fi

SER=$(device_serial 2>/dev/null || true)
if [ -z "${SER:-}" ]; then
  die "no device attached. Boot the tablet to recovery
     USB plugged in. Volume Down + Power until black, release, then
     Volume Up + Power. Check the screen says 23.2 recovery."
fi

STATE=$(device_state 2>/dev/null || echo "unknown")
info "device ${SER:0:8}...  state: $STATE"

case "$STATE" in
  sideload-authorized)
    die "state is 'sideload-authorized': adb can sideload but NOT run a shell,
     so no logs can be read.
     In recovery choose 'Reboot > Recovery' (not 'Reboot > System'), then rerun."
    ;;
  unauthorized)
    die "device is 'unauthorized'. Accept the prompt on the tablet screen.
     If there is no prompt: $ADB kill-server && $ADB start-server"
    ;;
  bootloader) warn "state is 'bootloader' (fastboot), not a shell. Boot to recovery." ;;
esac

A=("$ADB" -s "$SER" shell)

# --------------------------------------------------------------------------
# 2. pull everything, before anything can overwrite it
# --------------------------------------------------------------------------
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$OUTROOT/$STAMP"
mkdir -p "$OUT" || die "cannot create $OUT"
info "saving to flash-logs/$STAMP/"

pull() { # <remote-path> <local-name>
  if "${A[@]}" "cat $1" > "$OUT/$2" 2>/dev/null && [ -s "$OUT/$2" ]; then
    printf '    %-34s %s\n' "$2" "$(wc -l < "$OUT/$2" | tr -d ' ') lines"
  else
    rm -f "$OUT/$2"
    printf '    %-34s %s\n' "$2" "(not present)"
  fi
}

# The important one first, in case something goes wrong after.
pull /proc/last_kmsg        last_kmsg.txt
pull /proc/version          proc_version.txt
pull /proc/cmdline          proc_cmdline.txt

# pstore: one file per crashed boot, names vary
"${A[@]}" 'mkdir -p /tmp/ps && mount -t pstore pstore /tmp/ps 2>/dev/null; cat /tmp/ps/* 2>/dev/null' \
  > "$OUT/pstore.txt" 2>/dev/null
if [ -s "$OUT/pstore.txt" ]; then
  printf '    %-34s %s\n' pstore.txt "$(wc -l < "$OUT/pstore.txt" | tr -d ' ') lines"
else
  rm -f "$OUT/pstore.txt"; printf '    %-34s %s\n' pstore.txt "(not present)"
fi

pull /proc/uptime           proc_uptime.txt
"${A[@]}" dmesg             > "$OUT/dmesg.txt" 2>/dev/null
[ -s "$OUT/dmesg.txt" ] || rm -f "$OUT/dmesg.txt"
"${A[@]}" getprop           > "$OUT/getprop.txt" 2>/dev/null

# logcat only exists if a system actually came up
if "$ADB" -s "$SER" logcat -b all -d > "$OUT/logcat.txt" 2>/dev/null && [ -s "$OUT/logcat.txt" ]; then
  printf '    %-34s %s\n' logcat.txt "$(wc -l < "$OUT/logcat.txt" | tr -d ' ') lines"
else
  rm -f "$OUT/logcat.txt"; printf '    %-34s %s\n' logcat.txt "(no booted system)"
fi

# --------------------------------------------------------------------------
# 3. triage  (the greps from B2-HANDOFF.md section 4)
# --------------------------------------------------------------------------
say ""
info "triage"

LOG="$OUT/last_kmsg.txt"
[ -s "$LOG" ] || LOG="$OUT/dmesg.txt"

if [ -s "$LOG" ]; then
  # Which kernel is this? Everything else depends on it being the right one.
  if grep -aq "$EXPECTED_KERNEL_TAG" "$LOG"; then
    printf '    %sOK%s   right kernel (%s)\n' "$c_grn" "$c_off" "$EXPECTED_KERNEL_TAG"
  else
    printf '    %sWARN%s  no "%s" in the log - the WRONG kernel booted.\n' \
           "$c_yel" "$c_off" "$EXPECTED_KERNEL_TAG"
  fi
  grep -am1 "Linux version" "$LOG" | sed 's/^/          /' || true

  # The fatal patterns, in the order B2-HANDOFF lists them.
  PAT='InitFatalReboot|Kernel panic|Unable to handle|avc: *denied|SELinux:|init: .*(fail|abort|FATAL)|reboot:'
  HITS=$(grep -acE "$PAT" "$LOG" 2>/dev/null || echo 0)
  if [ "$HITS" -gt 0 ]; then
    printf '    %sHITS%s  %s fatal-looking line(s):\n' "$c_red" "$c_off" "$HITS"
    grep -anE "$PAT" "$LOG" | head -12 | sed 's/^/          /'
    say ""
    info "the last 40 lines before any 'reboot: Restarting system' are the cause:"
    LAST=$(grep -an "reboot: Restarting system" "$LOG" | tail -1 | cut -d: -f1)
    if [ -n "${LAST:-}" ]; then
      # Show the 40 lines before the marker, or the whole file if it is shorter.
      FROM=$(( LAST > 40 ? LAST - 40 : 1 ))
      sed -n "${FROM},${LAST}p" "$LOG" | sed 's/^/          /'
    else
      warn "no 'reboot: Restarting system' marker - init did not report cleanly"
    fi
  else
    printf '    %sclean%s no panic/denied/init-fatal patterns\n' "$c_grn" "$c_off"
  fi
else
  warn "no kernel log to triage"
fi

# The known-suspect subsystems from B2-HANDOFF section 4, if a system booted.
if [ -s "$OUT/logcat.txt" ]; then
  printf '    %s----%s  from logcat:\n' "$c_dim" "$c_off"
  grep -iE 'bpfloader|netbpfload|netd|bpf' "$OUT/logcat.txt" | head -5 | sed 's/^/          /'
  grep -iE 'lmkd' "$OUT/logcat.txt" | head -3 | sed 's/^/          /'
fi

say ""
info "next: write analysis/port/boot-<n>.md from these files, and commit only"
info "short excerpts - the raw logs hold the serial and MAC addresses."