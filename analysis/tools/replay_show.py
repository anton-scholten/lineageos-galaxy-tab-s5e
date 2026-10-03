#!/usr/bin/env python3
"""Replay the stack for paths P up to commit C, then dump the conflict blocks
that remain at C.  Same method as analysis/exyhyperbrick-trial/trial.py.
Usage: replay_show.py <C> <path1,path2,...> [max_lines_per_block]
"""
import subprocess, sys, os, re

os.chdir(os.environ.get('K670', os.path.expanduser('~/work/k670')))  # kernel clone; set K670 to override
TARGET = 'a30605a54f3b92627d868f169c72ef9c6ef82123'
BASE = 'd54533f1546b91f94eb4e445dfea3a94ffa58a74'
LAST = sys.argv[1]
paths = sys.argv[2].split(',')
MAXL = int(sys.argv[3]) if len(sys.argv) > 3 else 40

ENV = dict(os.environ, GIT_AUTHOR_NAME='replay', GIT_AUTHOR_EMAIL='r@x',
           GIT_COMMITTER_NAME='replay', GIT_COMMITTER_EMAIL='r@x',
           GIT_AUTHOR_DATE='1600000000 +0000', GIT_COMMITTER_DATE='1600000000 +0000')


def g(*a):
    r = subprocess.run(['git', *a], capture_output=True, text=True, env=ENV)
    if r.returncode not in (0, 1):
        raise RuntimeError(r.stderr)
    return r


log = g('log', '--reverse', '--no-merges', '--format=%H\t%s', f'{BASE}..{LAST}', '--', *paths)
entries = []
for line in log.stdout.strip().split('\n'):
    h, s = line.split('\t', 1)
    if s.startswith('[exynos9810]') or s.startswith('[9810]'):
        continue
    files = [f for f in g('diff-tree', '--no-commit-id', '--name-only', '-r', h).stdout.split('\n') if f]
    if not any(f in paths for f in files):
        continue
    entries.append((h, s, files))

head = TARGET
prior_conf = []
for h, s, files in entries:
    r = g('merge-tree', '--write-tree', '--name-only', f'--merge-base={h}^', head, h)
    lines = r.stdout.split('\n')
    tree = lines[0].strip()
    if r.returncode == 0:
        status, conf = 'CLEAN', []
    else:
        status = 'CONFLICT'
        conf = [l.split('\t')[-1] for l in lines[1:] if l and not l.startswith(('Auto-merging', 'CONFLICT'))]
    if h.startswith(LAST):
        print(f'== STACKED RESULT for {h}: {status} {conf}')
        for f in conf:
            print(f'\n######## {f}')
            txt = g('cat-file', '-p', f'{tree}:{f}').stdout.split('\n')
            i = 0
            nb = 0
            while i < len(txt):
                if txt[i].startswith('<<<<<<<'):
                    nb += 1
                    start = max(0, i - 2)
                    end = min(len(txt), i + MAXL)
                    for j in range(start, end):
                        print(f'{j+1}:{txt[j]}')
                    print('   ...')
                    i = end
                else:
                    i += 1
            print(f'-- {nb} block(s) in {f}')
        break
    if status == 'CONFLICT':
        prior_conf.append((h, s, conf))
    head = g('commit-tree', tree, '-p', head, '-m', f'pick {h}').stdout.strip()

print('\n== earlier stack commits that conflicted in these paths (trial kept markers):')
for h, s, conf in prior_conf:
    print(f'   {h} {s[:60]} -> {conf}')