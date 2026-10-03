import subprocess, sys, os
os.chdir('/tmp/claude-0/w/k670')
def g(*a, inp=None, check=True):
    r = subprocess.run(['git', *a], capture_output=True, text=True, input=inp)
    if check and r.returncode not in (0, 1): raise RuntimeError(r.stderr)
    return r
# directory set of target tree for "device-only" detection
dirs = set(g('ls-tree', '-r', '-d', '--name-only', 'lineage-22.2').stdout.split('\n')) | {''}
head = g('rev-parse', 'lineage-22.2').stdout.strip()
out = open('/tmp/claude-0/w/trial2.log', 'w')
for line in open('/tmp/claude-0/w/series.tsv'):
    h, s = line.rstrip('\n').split('\t', 1)
    files = [f for f in g('diff-tree', '--no-commit-id', '--name-only', '-r', h).stdout.split('\n') if f]
    if s.startswith('[exynos9810]') or s.startswith('[9810]'):
        out.write(f'SKIPDEV\t{h}\t{s}\n'); continue
    # device-only: every file lives in a directory missing from target (exynos drivers etc.)
    if files and all(os.path.dirname(f) not in dirs and not f.startswith(('tools/','include/','kernel/','net/','mm/','fs/','lib/','arch/arm64/kernel','arch/arm64/net','arch/arm64/include','Documentation/','samples/','security/','block/')) for f in files):
        out.write(f'SKIPDEV2\t{h}\t{s}\n'); continue
    r = g('merge-tree', '--write-tree', '--name-only', f'--merge-base={h}^', head, h)
    lines = r.stdout.split('\n')
    tree = lines[0].strip()
    if r.returncode == 0:
        status = 'CLEAN'; conf = ''
    else:
        conf = ' '.join(l for l in lines[1:] if l and not l.startswith(('Auto-merging','CONFLICT')) )[:600]
        status = 'CONFLICT'
    # commit result tree (conflicted tree contains markers; keep going like "-X ours of markers") 
    c = g('commit-tree', tree, '-p', head, '-m', f'pick {h}').stdout.strip()
    head = c
    out.write(f'{status}\t{h}\t{s}\t{conf}\n'); out.flush()
g('update-ref', 'refs/heads/trial2', head)
out.write('DONE\n'); out.close()
