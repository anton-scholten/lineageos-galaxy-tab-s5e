#!/usr/bin/env python3
"""Print the tree id of the stacked replay result at commit C (for a given path set)."""
import subprocess, sys, os
os.chdir(os.environ.get('K670', os.path.expanduser('~/work/k670')))  # kernel clone; set K670 to override
TARGET='a30605a54f3b92627d868f169c72ef9c6ef82123'; BASE='d54533f1546b91f94eb4e445dfea3a94ffa58a74'
LAST=sys.argv[1]; paths=sys.argv[2].split(',')
ENV=dict(os.environ,GIT_AUTHOR_NAME='r',GIT_AUTHOR_EMAIL='r@x',GIT_COMMITTER_NAME='r',GIT_COMMITTER_EMAIL='r@x',
         GIT_AUTHOR_DATE='1600000000 +0000',GIT_COMMITTER_DATE='1600000000 +0000')
def g(*a):
    r=subprocess.run(['git',*a],capture_output=True,text=True,env=ENV)
    if r.returncode not in (0,1): raise RuntimeError(r.stderr)
    return r
log=g('log','--reverse','--no-merges','--format=%H\t%s',f'{BASE}..{LAST}','--',*paths)
head=TARGET
for line in log.stdout.strip().split('\n'):
    h,s=line.split('\t',1)
    if s.startswith('[exynos9810]') or s.startswith('[9810]'): continue
    files=[f for f in g('diff-tree','--no-commit-id','--name-only','-r',h).stdout.split('\n') if f]
    if not any(f in paths for f in files): continue
    r=g('merge-tree','--write-tree','--name-only',f'--merge-base={h}^',head,h)
    tree=r.stdout.split('\n')[0].strip()
    if h.startswith(LAST):
        print(tree)
        break
    head=g('commit-tree',tree,'-p',head,'-m',f'pick {h}').stdout.strip()