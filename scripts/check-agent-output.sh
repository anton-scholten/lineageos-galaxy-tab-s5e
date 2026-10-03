#!/usr/bin/env bash
# Format check for helper-agent output (AGENT-TASKS.md §11). No AI needed.
# Usage: scripts/check-agent-output.sh            (checks everything present)
#        scripts/check-agent-output.sh K2a-1      (checks one batch)
# Exit 1 if anything fails.
set -uo pipefail
cd "$(dirname "$0")/.."
fail=0
err() { echo "FAIL $*"; fail=1; }

# 1. K2/K3 briefs: one per batch row, all sections, valid values.
for batch in analysis/agent-batches/*.tsv; do
    id=$(basename "$batch" .tsv)
    [[ $# -gt 0 && $1 != "$id" ]] && continue
    rows=$(tail -n +2 "$batch" | cut -f1)
    made=0
    for sha in $rows; do
        f="analysis/conflicts/${sha:0:12}.md"
        [[ -f $f ]] || continue
        made=$((made+1))
        head -1 "$f" | grep -q "^<!-- task: $id " || err "$f: header must start with '<!-- task: $id '"
        sections=("## Conflicting files" "## Why it conflicts" "## Already in sdm670?" "## Confidence" "## Problems")
        if [[ $id == K3-* ]]; then
            sections+=("## Notes for the lead" "## Later series commits touching the same files")
        else
            sections+=("## Proposed resolution")
            grep -A1 '^## Proposed resolution' "$f" | tail -1 | grep -qE '^(DROP|MERGE|PREREQ|HUMAN)\b' \
                || err "$f: resolution must start with DROP, MERGE, PREREQ or HUMAN"
        fi
        for s in "${sections[@]}"; do grep -qF "$s" "$f" || err "$f: missing '$s'"; done
        grep -A1 '^## Confidence' "$f" | tail -1 | grep -qE '^(high|medium|low)\b' \
            || err "$f: confidence must start with high, medium or low"
    done
    total=$(echo "$rows" | grep -c .)
    if [[ $made -gt 0 || $# -gt 0 ]]; then
        [[ $made -eq $total ]] || err "$id: $made of $total briefs present"
        [[ $id == K3-* || -f analysis/conflicts/$id-summary.md ]] || err "$id: missing analysis/conflicts/$id-summary.md"
        echo "checked $id: $made/$total briefs"
    fi
done

# 2. Every other agent report: header, Summary, Problems.
[[ $# -gt 0 ]] || for f in analysis/upstream-map/README.md analysis/build-test/errors/*.md analysis/api-audit/*.md \
        analysis/defconfig/README.md analysis/rom/*.md analysis/collisions/*.md analysis/link-check.md analysis/conflicts/*-summary.md; do
    [[ -f $f ]] || continue
    head -1 "$f" | grep -q '^<!-- task: ' || err "$f: missing '<!-- task: ... -->' header"
    grep -q '^## Summary' "$f" || err "$f: missing '## Summary'"
    grep -q '^## Problems' "$f" || err "$f: missing '## Problems'"
done

# 3. K1 table size.
if [[ $# -eq 0 && -f analysis/upstream-map/upstream-map.tsv ]]; then
    n=$(wc -l < analysis/upstream-map/upstream-map.tsv)
    [[ $n -eq 2600 ]] || err "upstream-map.tsv: $n lines, expected 2600"
fi

[[ $fail -eq 0 ]] && echo "OK" || exit 1
