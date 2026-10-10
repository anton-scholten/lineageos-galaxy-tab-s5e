#!/usr/bin/env bash
# ============================================================================
# portability-check.sh -- can this build tree move to another computer?
#
# Written 2026-10-10 by the lead, after the drive move and the interrupted
# copy to /dev/sdb. Background: HANDOVER.md "Build machine layout",
# FEASIBILITY-LINEAGE-24.md, analysis/l24/L4.md.
#
# WHAT IT DOES
#   Two modes, both read-only:
#     --preflight   before you unplug: checks that the tree is complete and
#                   the things that DON'T travel are noted
#     --on-new-host after you plug in on the other machine: checks that the
#                   tools it needs are present
#   Prints PASS / FAIL / WARN / SKIP per check plus a summary, and a final
#   VERDICT line. Exit 0 = safe to move, 1 = something will break the build.
#
# THE ONE THAT BIT US
#   The Debian llvm-19 packages ship only VERSIONED binary names
#   (llvm-nm-19, not llvm-nm) but kbuild's LLVM=1 looks for the unversioned
#   ones. Without the llvmbin symlink directory on PATH:
#     * the build still SUCCEEDS
#     * vdso.so.dbg does not link
#     * vdso_offset_sigtramp is generated WRONG
#   That is a silently broken sigreturn trampoline, not a build error. It
#   shows up much later as an unexplained boot crash on hardware. This is
#   the single most important thing in this script.
#
# USAGE
#   bash scripts/portability-check.sh --preflight
#   bash scripts/portability-check.sh --on-new-host
#   VERBOSE=1 bash scripts/portability-check.sh --preflight
#
# NEEDS
#   bash, coreutils, git. The optional checks degrade to SKIP rather than
#   failing when their tool is absent.
#
# EXIT CODES
#   0  safe to move (FAIL: 0)
#   1  at least one FAIL: do not move yet
#   2  this script is broken
# ============================================================================

set -uo pipefail

MODE="${1:---preflight}"
VERBOSE="${VERBOSE:-0}"
TREE="${TREE:-/mnt/build/lineage-24}"
TREE232="${TREE232:-/mnt/build/lineage}"

PASS=0; FAIL=0; WARN=0; SKIP=0
declare -a FAILED=() WARNS=()

c_pass() { PASS=$((PASS+1)); printf 'PASS  %s\n' "$1"; }
c_fail() { FAIL=$((FAIL+1)); FAILED+=("$1"); printf 'FAIL  %s\n     -> %s\n' "$1" "${2:-}"; }
c_warn() { WARN=$((WARN+1)); WARNS+=("$1"); printf 'WARN  %s\n     -> %s\n' "$1" "${2:-}"; }
c_skip() { SKIP=$((SKIP+1)); printf 'SKIP  %s\n' "$1"; [ "${VERBOSE:-0}" = 1 ] && printf '     -> %s\n' "${2:-}"; return 0; }
v() { [ "$VERBOSE" = 1 ] && printf '     %s\n' "$1"; return 0; }

echo "=============================================================================="
echo " portability-check.sh -- mode: $MODE"
echo " tree: $TREE"
echo "=============================================================================="

# ---------------------------------------------------------------- preflight --

preflight() {
  echo "-- the tree itself --------------------------------------------------"

  if [ ! -d "$TREE" ]; then
    c_fail "tree exists at $TREE" "not found. Is the drive mounted?"
  else
    c_pass "tree exists at $TREE"
  fi

  [ -d "$TREE/.repo" ] \
    && c_pass ".repo present" \
    || c_fail ".repo present" "missing: this is not a repo tree, or the copy was interrupted"

  if [ -d "$TREE/out" ]; then
    c_warn "out/ exists ($(du -sh "$TREE/out" 2>/dev/null | cut -f1))" \
      "out/ is NOT portable: it hardcodes this machine's paths and toolchain. Do not copy it; it will be rebuilt."
  else
    c_skip "out/ absent" "correct for a tree that has never been built"
  fi

  echo
  echo "-- are all repos actually checked out? ------------------------------"

  # repo's own answer is authoritative when repo is available.
  if [ -x "$HOME/bin/repo" ] || command -v repo >/dev/null 2>&1; then
    local REPO; REPO="$HOME/bin/repo"; command -v repo >/dev/null 2>&1 && [ ! -x "$HOME/bin/repo" ] && REPO="$(command -v repo)"
    if (cd "$TREE" && timeout 120 "$REPO" status 2>/dev/null | grep -qvE '^\s*$'); then
      local dirty; dirty=$(cd "$TREE" && "$REPO" status --porcelain 2>/dev/null | head -20)
      if [ -z "$dirty" ]; then
        c_pass "repo status clean (all projects checked out)"
      else
        c_fail "repo status clean" "$(echo "$dirty" | head -5 | tr '\n' ' ')"
      fi
    else
      c_skip "repo status" "repo not runnable or produced no output"
    fi
  else
    c_skip "repo status" "no repo launcher found (~/bin/repo)"
  fi

  # The two projects an interrupted copy damages. Cheap, targeted, no repo needed.
  for p in prebuilts/sdk prebuilts/rust-toolchain/linux-x86; do
    if [ -d "$TREE/$p/.git" ]; then
      local n; n=$(git -C "$TREE/$p" status --porcelain 2>/dev/null | wc -l)
      if [ "$n" = "0" ]; then c_pass "$p checkout complete"
      else c_fail "$p checkout complete" "$n uncommitted entries: run 'git -C $TREE/$p checkout -f <sha>'"; fi
    else
      c_skip "$p" "not present"
    fi
  done

  echo
  echo "-- our own repos: do they carry the right commits? ------------------"

  check_pin() { # path expected-sha description
    if [ ! -d "$TREE/$1/.git" ]; then c_skip "$3" "$1 not present"; return; fi
    local have; have=$(git -C "$TREE/$1" rev-parse --short=12 HEAD 2>/dev/null)
    if [ "$have" = "$2" ]; then c_pass "$3 @ $2"
    else c_fail "$3 @ $2" "have $have"; fi
  }
  # The device tree may legitimately be on either the unported lineage-24.0 tip
  # or the L6 port branch, so it gets its own check accepting both.
  check_device_tree() {
    local base=1188e2b14a5a port=5af53f12e9eb have
    [ -d "$TREE/device/samsung/gts4lv-common/.git" ] || { c_skip "device tree" "not present"; return; }
    have=$(git -C "$TREE/device/samsung/gts4lv-common" rev-parse --short=12 HEAD 2>/dev/null)
    if [ "$have" = "$port" ]; then c_pass "device tree @ $port (L6 port branch, expected before a build)"
    elif [ "$have" = "$base" ]; then c_warn "device tree @ $base (unported)" "L6 lives on port/l24-dt-1; check that out before building"
    else c_fail "device tree" "have $have, expected $base (lineage-24.0) or $port (port/l24-dt-1)"; fi
  }
  check_device_tree
  check_pin kernel/samsung/sdm670        500658be3c16 "kernel"
  check_pin vendor/samsung/gts4lv-common 51de1d4fa3f7 "vendor blobs"

  if [ -d "$TREE/device/samsung/gts4lv-common/.git" ]; then
    local fcm; fcm=$(grep -o 'target-level="[0-9]*"' "$TREE/device/samsung/gts4lv-common/manifest.xml" 2>/dev/null | head -1)
    if [ "$fcm" = 'target-level="7"' ]; then
      c_pass "device tree carries the L6 port (FCM 7)"
    elif [ "$fcm" = 'target-level="5"' ]; then
      c_warn "device tree is the unported 23.2 one (FCM 5)" \
        "expected on lineage-24.0. L6 lives on branch port/l24-dt-1; check it out before building."
    else
      c_warn "device tree FCM" "could not read target-level from manifest.xml"
    fi
  fi

  echo
  echo "-- git object integrity (the copy was interrupted once) --------------"

  for p in device/samsung/gts4lv-common kernel/samsung/sdm670; do
    if [ -d "$TREE/$p/.git" ]; then
      local out; out=$(timeout 300 git -C "$TREE/$p" fsck --no-progress --connectivity-only 2>&1 | grep -viE "^Checking|^$" | head -3)
      if [ -z "$out" ]; then c_pass "$p git fsck"
      else c_fail "$p git fsck" "$(echo "$out" | head -2 | tr '\n' ' ')"; fi
    else
      c_skip "$p git fsck" "not present"
    fi
  done

  echo
  echo "-- things that do NOT travel ---------------------------------------"
  cat <<'EOF'
  These live on the machine's internal disk, NOT on the drive. Recreate them
  on the new host (see HANDOVER.md and scripts/portability-check.sh --on-new-host):

    ~/bin/repo                     the repo launcher itself
    ~/work/llvmbin/                llvm-19 versioned -> unversioned symlinks
    ~/.gitconfig                   ssh insteadOf rule + user.name/email
EOF

  local llvm; llvm=$(ls "$HOME/work/llvmbin" 2>/dev/null | wc -l)
  if [ "$llvm" -gt 0 ]; then c_warn "llvmbin has $llvm links HERE" "must be recreated on the new host, or the build silently breaks vdso"
  else c_skip "llvmbin" "not found on this host either (tree may never have been built here)"; fi
}

# ------------------------------------------------------------- on-new-host --

on_new_host() {
  echo "-- the tool that silently breaks things -----------------------------"

  # The links keep the llvm- prefix: llvm-nm -> llvm-nm-19. Only the -19 is
  # stripped. kbuild's LLVM=1 looks for these unversioned names.
  local llvmbin="$HOME/work/llvmbin"
  if [ -e "$llvmbin/llvm-nm" ] && [ -e "$llvmbin/llvm-ar" ] && [ -e "$llvmbin/llvm-objcopy" ]; then
    c_pass "llvmbin links exist ($(ls "$llvmbin" 2>/dev/null | wc -l) files)"
    if "$llvmbin/llvm-nm" --version >/dev/null 2>&1; then
      c_pass "llvmbin/llvm-nm runs: $("$llvmbin/llvm-nm" --version 2>/dev/null | head -1)"
    else
      c_fail "llvmbin/llvm-nm runs" "broken symlink or not executable"
    fi
  else
    c_fail "llvmbin symlink dir" \
      "MISSING. Build SUCCEEDS but vdso.so.dbg won't link and vdso_offset_sigtramp is wrong. Run:
       mkdir -p ~/work/llvmbin
       for f in /usr/bin/llvm-*-19; do ln -sf \"\$f\" ~/work/llvmbin/\"\$(basename \"\$f\" -19)\"; done
       export PATH=\"\$HOME/work/llvmbin:\$PATH\""
  fi

  # And it must actually be on PATH for the build to see it.
  case ":$PATH:" in
    *":$llvmbin:"*) c_pass "llvmbin is on PATH" ;;
    *) c_warn "llvmbin is on PATH" "not in \$PATH right now. The build must be run with: export PATH=\"\$HOME/work/llvmbin:\$PATH\"" ;;
  esac

  local pv; pv=$(command -v llvm-nm 2>/dev/null)
  if [ -n "$pv" ]; then c_skip "llvm-nm on PATH" "found at $pv"
  else c_skip "llvm-nm on PATH" "not on PATH; only reachable through llvmbin"; fi

  echo
  echo "-- build tools ------------------------------------------------------"

  need_cmd() { # cmd pkg human
    if command -v "$1" >/dev/null 2>&1; then c_pass "$3 ($1)"
    else c_fail "$3 ($1)" "install: apt-get install -y $2"; fi
  }
  need_cmd git   git                "git"
  need_cmd git-lfs git-lfs          "git-lfs (required: tree was cloned with --git-lfs)"
  need_cmd clang clang              "clang"
  need_cmd ld.lld lld                "lld"
  need_cmd flex  flex                "flex"
  need_cmd bison bison              "bison"
  need_cmd make  make                "make"
  need_cmd rsync rsync              "rsync"

  if command -v python3 >/dev/null 2>&1; then c_pass "python3 ($(python3 --version 2>&1 | cut -d' ' -f2))"
  else c_fail "python3" "install: apt-get install -y python3"; fi

  # dtc is deliberately NOT needed: arm64 .dtsi files compile through clang.
  if command -v dtc >/dev/null 2>&1; then c_skip "dtc present" "not needed; arm64 dtsi goes through clang"
  else c_skip "dtc absent" "correct, not needed"; fi

  echo
  echo "-- mount and paths --------------------------------------------------"

  if mount | grep -qE " on /mnt/build "; then
    c_pass "/mnt/build is mounted"
    # sort -u because a stacked double mount lists the same line twice
    local src; src=$(mount | grep " on /mnt/build " | awk '{print $1}' | sort -u | head -1)
    if [ "$src" = "/dev/sdb" ]; then c_pass "/mnt/build is /dev/sdb"
    else c_warn "/mnt/build is $src" "expected /dev/sdb. Paths are baked in; mount it wherever you mounted it HERE."; fi
  else
    c_fail "/mnt/build mounted" "run: sudo mount /dev/sdb /mnt/build"
  fi

  [ -d "$TREE/.repo" ] && c_pass "24.0 tree at $TREE" || c_fail "24.0 tree at $TREE" "not found"
  [ -d "$TREE232/.repo" ] && c_pass "23.2 tree at $TREE232" || c_warn "23.2 tree at $TREE232" "absent; only needed to rebuild 23.2"

  echo
  echo "-- ssh access to the forks ------------------------------------------"

  if git config --global --get-regexp 'url\..*insteadof' >/dev/null 2>&1; then
    c_pass "git insteadOf rule configured: $(git config --global --get url.'git@github.com:'.insteadOf 2>/dev/null)"
  else
    c_warn "no git insteadOf rule" \
      "if a tree remote is https://github.com/, fetches and pushes will fail for lack of credentials. Run:
       git config --global url.\"git@github.com:\".insteadOf https://github.com/"
  fi

  # Note: `ssh -T git@github.com` exits NON-ZERO on success ("GitHub does not
  # provide shell access"), so its output must be captured and matched, never
  # used as a pipeline status under `set -o pipefail`.
  local sshout
  if command -v ssh >/dev/null 2>&1; then
    sshout=$(timeout 30 ssh -o BatchMode=yes -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1)
    if printf '%s' "$sshout" | grep -q "successfully authenticated"; then
      c_pass "ssh key works for github.com"
    else
      c_fail "ssh key works for github.com" \
        "run 'ssh -T git@github.com'. Without it the tree cannot fetch its own projects. Got: $(printf '%s' "$sshout" | head -1)"
    fi
  else
    c_fail "ssh present" "install: apt-get install -y openssh-client"
  fi

  echo
  echo "-- disk space -------------------------------------------------------"

  local avail; avail=$(df --output=avail -B1 /mnt/build 2>/dev/null | tail -1 | tr -d ' ')
  if [ -n "$avail" ]; then
    local gb=$((avail/1000000000))
    if [ "$gb" -ge 300 ]; then c_pass "$gb GB free on /mnt/build"
    else c_warn "$gb GB free on /mnt/build" "out/ needs roughly 300 GB. Move out/ to the internal disk or free space."; fi
  else
    c_skip "free space" "df --output not supported here"
  fi

  echo
  echo "-- signing keys (decide before you install) -------------------------"

  local k1 k2
  k1=$(find "$TREE232/build/target/product/security" -name '*.pk8' 2>/dev/null | head -1)
  k2=$(find "$TREE/build/target/product/security" -name '*.pk8' 2>/dev/null | head -1)
  if [ -n "$k1" ] && [ -n "$k2" ] && [ "$(dirname "$k1")" = "$(dirname "$k2")" ]; then
    c_warn "signing keys live in build/, not in the repo" \
      "they are NOT portable: out/ is machine-specific. Set TARGET_BUILD_VARIANT and keys explicitly, or expect a clean install."
  else
    c_warn "signing keys not compared" \
      "23.2 and 24.0 builds need the same keys to install over each other, or a clean install (*Format data*) is required."
  fi
}

# ------------------------------------------------------------------- main --

case "$MODE" in
  --preflight)   preflight ;;
  --on-new-host) on_new_host ;;
  -h|--help)     sed -n '2,45p' "$0"; exit 0 ;;
  *) echo "usage: $0 [--preflight|--on-new-host]" >&2; exit 2 ;;
esac

echo
echo "=============================================================================="
printf 'summary: %d PASS, %d FAIL, %d WARN, %d SKIP\n' "$PASS" "$FAIL" "$WARN" "$SKIP"
if [ ${#FAILED[@]} -gt 0 ]; then printf '  FAILED: %s\n' "${FAILED[@]}"; fi
if [ ${#WARNS[@]}  -gt 0 ]; then printf '  WARNED: %s\n' "${WARNS[@]}"; fi
echo "=============================================================================="

if [ "$FAIL" -gt 0 ]; then
  echo "VERDICT: NOT SAFE. Fix the FAILs above before moving the drive."
  exit 1
fi
echo "VERDICT: safe to move / safe to build. Read the WARNs."
exit 0