<!-- task: K2c-1 | agent: Space Bunny Free | date: 2026-10-03 -->
# f4e1fe0bc47b: BACKPORT: kernfs: don't set dentry->d_fsdata
- Author / date: Shaohua Li <shli@fb.com>, 2017-07-12
- Upstream: -
- Batch: K2c-1, size_class: trivial
- Group in `analysis/exyhyperbrick-trial/conflict_detail.tsv`: **optional**
## Conflicting files
- fs/kernfs/inode.c
(The commit touches 6 files; `dir.c`, `file.c`, `kernfs-internal.h`, `mount.c`
and `symlink.c` all auto-merge. `git diff --stat a30605a54f3b 00d4a0995815`
shows all 6 changed, so nothing is silently dropped.)
## Why it conflicts
merge-tree on its own: conflicts (tree `00d4a0995815`, 1 file, 1 block).
- Block 1, fs/kernfs/inode.c ~line 206, in `kernfs_iop_getattr()`: ours has the
  4.9 prototype `kernfs_iop_getattr(struct vfsmount *mnt, struct dentry *dentry,
  struct kstat *stat)` and gets the node from `dentry->d_fsdata`; theirs has the
  newer prototype taking `const struct path *path` and gets it from
  `inode->i_private`. The function signature differs, so the body differs — git
  cannot tell that only the two initialiser lines really changed.
## Already in sdm670?
partly. Evidence:
- sdm670 already supports the "theirs" way of getting the node:
  fs/kernfs/inode.c:220 @ a30605a54f3b sets `inode->i_private = kn;`, and lines
  284, 298, 312, 328, 349 already read `kn = inode->i_private;`.
- sdm670 has NOT had the d_fsdata removal: `git grep -n 'd_fsdata' a30605a54f3b --
  fs/kernfs/` returns 21 hits (dir.c 10, file.c 4, inode.c 3, mount.c 4, symlink.c 1).
- Searched for the two distinctive added lines: `kernfs_dentry_node` and
  `inode->i_private` — the first has no hits in sdm670, the second only in the
  places listed above.
## Proposed resolution
MERGE: keep sdm670's 4.9 function prototype
`kernfs_iop_getattr(struct vfsmount *mnt, struct dentry *dentry, struct kstat *stat)`
and take theirs' body change, i.e. the two declarations become
`struct inode *inode = d_inode(dentry);` followed by
`struct kernfs_node *kn = inode->i_private;`. Both variables are still needed by
the rest of the function (`kernfs_refresh_inode(kn, inode)`, `generic_fillattr(inode, stat)`),
which is unchanged and outside the conflict markers.
Do not take "theirs" whole: that would replace the 4.9 prototype with a
`const struct path *path` version, which does not match sdm670's
`kernfs_iop_getattr` prototype as registered in its own
`kernfs_inode_operations` (`fs/kernfs/inode.c` @ a30605a54f3b) and would not build.
Taking "ours" whole would leave one `d_fsdata` user behind out of 21 and gain
nothing. `i_private` is guaranteed to be set for every kernfs inode by
fs/kernfs/inode.c:220, so the switch is safe.
The rest of the commit is a straight cleanup: it removes d_fsdata from dir.c,
file.c, symlink.c and mount.c and adds the `kernfs_dentry_node()` inline to
fs/kernfs/kernfs-internal.h (auto-merged, both copies present in the merged tree).
## Confidence
high: step 4 done with three searches; sdm670 has the i_private assignment that
the series side relies on, the conflict is one small fully-quoted block, and the
prototype mismatch is stated explicitly.
## Problems
None
