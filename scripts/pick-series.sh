#!/usr/bin/env bash
# Cherry-pick the ExyHyperBrick series onto the kernel, in order, and stop at the first commit that needs a person.
# Resumable: run it again after each resolution, and it skips everything already picked or dropped.
#
# Usage: scripts/pick-series.sh <kernel-clone> [max-commits]
#   <kernel-clone>  sdm670 clone with remote "exy" = anton-scholten/android_kernel_samsung_exynos9810 (AGENT-TASKS.md §1.2),
#                   checked out on a branch named port/* that starts at a30605a54f3b.
#   max-commits     optional: stop after picking this many (handy for testing).
#
# Exit codes: 0 = series finished, 1 = stopped at a conflict (see .git/PORT_STATUS), 2 = setup problem,
#             3 = a cherry-pick is already in progress, 4 = max-commits reached.
set -euo pipefail

K=${1:?usage: $0 <kernel-clone> [max-commits]}
MAX=${2:-0}
DOCS=$(cd "$(dirname "$0")/.." && pwd)
RES=$DOCS/analysis/exyhyperbrick-trial/results.tsv
DET=$DOCS/analysis/exyhyperbrick-trial/conflict_detail.tsv
DROPPED=$DOCS/analysis/port/dropped.tsv
FULL=$DOCS/analysis/port/full-review.txt
BASE=a30605a54f3b

cd "$K"
branch=$(git rev-parse --abbrev-ref HEAD)
[[ $branch == port/* ]] || { echo "Check out a branch named port/* first (git checkout -b port/pick $BASE)."; exit 2; }
git merge-base --is-ancestor "$BASE" HEAD || { echo "HEAD doesn't contain $BASE."; exit 2; }
if [[ -e .git/CHERRY_PICK_HEAD ]]; then
    echo "A cherry-pick is in progress. Finish it first (AGENT-TASKS.md §P1 step 4), then run this again."
    exit 3
fi
[[ -z $(git status --porcelain --untracked-files=no) ]] || { echo "Working tree has uncommitted changes. Commit or stash them."; exit 2; }

# Already handled: picked (the -x trailer names the original) or listed in dropped.tsv.
done_list=$(mktemp); trap 'rm -f "$done_list"' EXIT
# Use the LAST "cherry picked from" line of each commit: many series commits carry their own older one, and -x appends ours at the end.
git log --format='--C--%n%B' "$BASE"..HEAD | awk '/^--C--$/{if(l)print l; l=""; next}
    match($0,/cherry picked from commit [0-9a-f]{40}/){l=substr($0,RSTART+26,12)} END{if(l)print l}' > "$done_list"
{ grep -v '^#' "$DROPPED" || true; } | cut -f1 | cut -c1-12 >> "$done_list"
skip_group=$(awk -F'\t' 'NR>1 && $9=="skip"{print $1}' "$DET")

picked=0
while IFS=$'\t' read -r status sha subject _; do
    [[ $status == status ]] && continue
    short=${sha:0:12}
    [[ $status == SKIPDEV || $status == SKIPDEV2 ]] && continue      # Exynos-only (trial classification)
    grep -qx "$short" <<<"$skip_group" && continue                     # skip group in conflict_detail.tsv
    grep -qx "$short" "$done_list" && continue
    if [[ $MAX -gt 0 && $picked -ge $MAX ]]; then echo "Stopped after $picked commits (max-commits)."; exit 4; fi

    if git cherry-pick -x "$sha" >/dev/null 2>&1; then
        picked=$((picked+1)); continue
    fi
    # Empty pick: the change is already in the tree. Record it as dropped and move on.
    if [[ -e .git/CHERRY_PICK_HEAD && -z $(git diff --name-only --diff-filter=U) && -z $(git status --porcelain --untracked-files=no) ]]; then
        git cherry-pick --skip >/dev/null 2>&1
        printf '%s\tempty pick (already in tree)\tpick-series.sh\n' "$short" >> "$DROPPED"
        echo "$short" >> "$done_list"
        continue
    fi
    # A real conflict: stop and describe it.
    brief=$DOCS/analysis/conflicts/$short.md
    full=$(grep "^$short " "$FULL" | cut -d' ' -f2- || true)
    {
        echo "commit:   $sha"
        echo "subject:  $subject"
        echo "files:    $(git diff --name-only --diff-filter=U | tr '\n' ' ')"
        if [[ -f $brief ]]; then echo "brief:    analysis/conflicts/$short.md"; else echo "brief:    NONE (write a short note in the commit message; it gets a full review)"; fi
        if [[ -n $full ]]; then echo "review:   FULL ($full)"
        elif [[ ! -f $brief ]]; then echo "review:   FULL (no brief)"
        else echo "review:   spot-check"; fi
        echo "picked this run: $picked"
    } | tee .git/PORT_STATUS
    exit 1
done < "$RES"

echo "Series finished. Picked this run: $picked. Next: python3 scripts/check-pick.py $K"
exit 0
