import subprocess, re, collections, os
# Work dir: set W (default /tmp/claude-0/w); expects $W/k670 (sdm670 clone with exy remotes) and $W/series.tsv
W = os.environ.get('W', '/tmp/claude-0/w')
os.chdir(W + '/k670')
def g(*a): return subprocess.run(['git',*a],capture_output=True,text=True,errors='replace')
# map series commit -> trial2 chain commit that picked it
chain={}
for line in g('log','--format=%H %s','lineage-22.2..trial2').stdout.splitlines():
    c,s=line.split(' ',1)
    if s.startswith('pick '): chain[s[5:]]=c
rows=[l.rstrip('\n').split('\t') for l in open(W + '/trial2.log',errors='replace') if l.startswith('CONFLICT')]
out=open(W + '/conflict_detail.tsv','w')
out.write('commit\tsubject\tfiles\tblocks\tours_lines\ttheirs_lines\tmodify_delete\tsize_class\tgroup\n')
# group: what 23.2 needs (keyword heuristic on the subject)
REQ=re.compile(r'bpf|btf|xdp|sock|tcp|udp|\bnet\b|net:|inet|ipv|flow_dissector|epoll|close_range|uprobe|perf|refcount|LSM|hrtimer|syscall|cgroup',re.I)
SKIP=re.compile(r'exynos|videodev2|stale merge-conflict|dex touchpad|hall|switch event|speaker|f2fs|ext4|SchedTune|EAS|zstd|lz4',re.I)
cls=collections.Counter()
for st,h,subj,*rest in rows:
    parent=g('rev-parse',chain[h]+'^').stdout.strip()
    r=g('merge-tree','--write-tree','--name-only','--messages',f'--merge-base={h}^',parent,h)
    lines=r.stdout.split('\n'); tree=lines[0]
    files=[]; i=1
    while i<len(lines) and lines[i]: files.append(lines[i]); i+=1
    msgs='\n'.join(lines[i:])
    md=len(re.findall(r'CONFLICT \((modify/delete|rename/delete|add/add)',msgs))
    blocks=ours=theirs=0
    for f in files:
        blob=g('show',f'{tree}:{f}').stdout
        for m in re.finditer(r'^<<<<<<< [^\n]*\n(.*?)^=======\n(.*?)^>>>>>>> ',blob,re.S|re.M):
            blocks+=1; ours+=m.group(1).count('\n'); theirs+=m.group(2).count('\n')
    size=ours+theirs
    c='trivial' if (size<=10 and md==0) else 'moderate' if size<=60 else 'large'
    if md and size==0: c='modify/delete'
    cls[c]+=1
    grp='skip' if SKIP.search(subj) else 'required' if REQ.search(subj) else 'optional'
    out.write(f'{h[:12]}\t{subj}\t{len(files)}\t{blocks}\t{ours}\t{theirs}\t{md}\t{c}\t{grp}\n')
print(dict(cls))
