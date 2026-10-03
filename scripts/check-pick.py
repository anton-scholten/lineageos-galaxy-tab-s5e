#!/usr/bin/env python3
"""Automatic checks on a port/* branch made by scripts/pick-series.sh, plus review packets for the strong model.

Usage: scripts/check-pick.py <kernel-clone> [out-dir]

Checks (any failure -> exit 1):
  1. No conflict markers (<<<<<<< / >>>>>>>) were added anywhere since a30605a54f3b.
  2. Every picked commit names its original (-x trailer), and the original is in the series.
  3. A commit with no -x trailer (a fix commit) carries a "Fix-by:" trailer.
  4. Every line in analysis/port/dropped.tsv names a series commit and gives a reason.
Writes to out-dir (default ./pick-review) one range-diff per commit whose changed lines differ from the original:
  full/      hand-resolved ("Resolved-by:" trailer) and listed in analysis/port/full-review.txt, or with no brief
  spot/      the other hand-resolved ones
  automerge/ git applied it without a conflict, but the result still differs (e.g. a removal that found nothing to
             remove). Triage these: most are harmless, some silently lose part of the change.
plus fixes/ for fix commits, and summary.txt.
"""
import os, re, subprocess, sys

BASE = 'a30605a54f3b'
SERIES = 'd54533f1546b..baa585f67e0e'
K = sys.argv[1]
OUT = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else 'pick-review')
DOCS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def git(*a):
    return subprocess.run(['git', '-C', K, *a], capture_output=True, text=True, errors='replace', check=True).stdout

def patch_ids(rev_range):
    """Hash of each commit's changed lines only (+/- lines per file, no context, no line numbers).
    A clean cherry-pick onto different surrounding code keeps the same hash; a hand edit changes it."""
    import hashlib
    ids, cur, buf, fname = {}, None, [], ''
    def flush():
        if cur:
            ids[cur] = hashlib.sha1('\n'.join(buf).encode()).hexdigest()
    for line in git('log', '-p', '-U0', '--no-merges', '--format=commit %H', rev_range).splitlines():
        if line.startswith('commit ') and len(line) == 47:
            flush(); cur, buf = line[7:], []
        elif line.startswith('+++ ') or line.startswith('--- '):
            if line.startswith('+++ '):
                buf.append('F ' + line[4:])
        elif line[:1] in '+-' and line[:2] not in ('++', '--'):
            buf.append(line.rstrip())
    flush()
    return ids

fails = []
# 1. conflict markers
# Only the <<<<<<< / >>>>>>> markers: a bare "=======" line is also a reStructuredText heading underline.
added = [l for l in git('diff', BASE, 'HEAD').splitlines() if re.match(r'^\+(<<<<<<< |>>>>>>> )', l)]
if added:
    fails.append(f'{len(added)} conflict-marker lines added since {BASE}')

series = set(git('rev-list', '--no-merges', SERIES).split())
orig_ids = patch_ids(SERIES)
new_ids = patch_ids(f'{BASE}..HEAD')
full = {}
for l in open(os.path.join(DOCS, 'analysis/port/full-review.txt')):
    if l.strip() and not l.startswith('#'):
        sha, _, why = l.strip().partition(' ')
        full[sha] = why

for d in ('full', 'spot', 'automerge', 'fixes'):
    os.makedirs(os.path.join(OUT, d), exist_ok=True)
clean = resolved = automerged = fixes = 0
for c in git('rev-list', '--reverse', '--no-merges', f'{BASE}..HEAD').split():
    msg = git('log', '-1', '--format=%B', c)
    found = re.findall(r'cherry picked from commit ([0-9a-f]{40})', msg)   # last one = ours (-x appends at the end)
    m = re.match(r'(.*)', found[-1]) if found else None
    if not m:
        fixes += 1
        if 'Fix-by:' not in msg:
            fails.append(f'{c[:12]}: not a cherry-pick and no "Fix-by:" trailer')
        open(os.path.join(OUT, 'fixes', f'{fixes:03d}-{c[:12]}.diff'), 'w').write(git('show', '--stat', '-p', c))
        continue
    o = m.group(1)
    if o not in series:
        fails.append(f'{c[:12]}: -x names {o[:12]}, which is not in the series')
        continue
    if new_ids.get(c) == orig_ids.get(o):
        clean += 1
        continue
    short = o[:12]
    has_brief = os.path.exists(os.path.join(DOCS, 'analysis/conflicts', short + '.md'))
    if 'Resolved-by:' in msg:
        resolved += 1
        kind = 'full' if (short in full or not has_brief) else 'spot'
    else:
        automerged += 1
        kind = 'automerge'
    head = f'# {short} -> {c[:12]}  review: {kind}  {full.get(short, "" if has_brief else "no brief")}\n'
    open(os.path.join(OUT, kind, f'{short}.range-diff'), 'w').write(head + git('range-diff', f'{o}^!', f'{c}^!'))

# 4. dropped.tsv
for l in open(os.path.join(DOCS, 'analysis/port/dropped.tsv')):
    if l.startswith('#') or not l.strip():
        continue
    parts = l.rstrip('\n').split('\t')
    if len(parts) < 3 or not parts[1].strip():
        fails.append(f'dropped.tsv: line without a reason: {l.strip()}')
    elif not any(s.startswith(parts[0]) for s in series):
        fails.append(f'dropped.tsv: {parts[0]} is not in the series')

nfull = len(os.listdir(os.path.join(OUT, 'full'))); nspot = len(os.listdir(os.path.join(OUT, 'spot')))
summary = (f'picked clean: {clean}\nhand-resolved: {resolved} (full review: {nfull}, spot-check pool: {nspot})\n'
           f'auto-merged but different: {automerged} (triage)\n'
           f'fix commits: {fixes}\nproblems: {len(fails)}\n' + ''.join(f'  - {f}\n' for f in fails))
open(os.path.join(OUT, 'summary.txt'), 'w').write(summary)
print(summary + f'review packets: {OUT}')
sys.exit(1 if fails else 0)
