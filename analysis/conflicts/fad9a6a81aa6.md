<!-- task: K2c-1 | agent: Space Bunny Free | date: 2026-10-03 -->
# fad9a6a81aa6: UPSTREAM: userfaultfd: use vma_is_anonymous
- Author / date: Andrea Arcangeli <aarcange@redhat.com>, 2017-02-22
- Upstream: a94720bf821dd63e72176da5f423ba7935dde67d
  (the trailer is `Upstream-commit: a94720bf821dd...`, hyphenated. Note for K1:
  that spelling does not match the four literal K1 patterns either, so a strict
  K1 run would log `-` here.)
- Batch: K2c-1, size_class: trivial
- Group in `analysis/exyhyperbrick-trial/conflict_detail.tsv`: **optional**
## Conflicting files
- fs/userfaultfd.c
(`mm/userfaultfd.c` is also touched and auto-merges cleanly.)
## Why it conflicts
merge-tree on its own: conflicts (tree `7c4e902c9ef2`, 1 file, 1 block).
The commit replaces four `->vm_ops` tests with `vma_is_anonymous()`. Three of
them merged cleanly; the fourth does not, because sdm670 has an extra vendor line
underneath it.
- Block 1, fs/userfaultfd.c ~line 1024, in the second loop of
  `userfaultfd_unregister()`: ours has **two** lines,
  `BUG_ON(vma->vm_ops);` and `WARN_ON(!(vma->vm_flags & VM_MAYWRITE));`;
  theirs replaces only the first with `BUG_ON(!vma_is_anonymous(vma));`.
## Already in sdm670?
no. Evidence:
- fs/userfaultfd.c:840, :877, :1010, :1024 @ a30605a54f3b still test
  `cur->vm_ops` / `vma->vm_ops`.
- mm/userfaultfd.c:198 @ a30605a54f3b still tests `if (dst_vma->vm_ops)`.
- `git grep -n 'vma_is_anonymous' a30605a54f3b -- fs/userfaultfd.c mm/userfaultfd.c`:
  no hits.
Searched for `vma_is_anonymous` in both files (nothing) and for `->vm_ops` in
both files (present, four + one sites).
The helper the series relies on does exist in sdm670, so there is no missing
prerequisite: include/linux/mm.h:1534 @ a30605a54f3b defines
`static inline bool vma_is_anonymous(struct vm_area_struct *vma)`.
## Proposed resolution
MERGE: keep both lines, i.e. resolve the block to
```
		BUG_ON(!vma_is_anonymous(vma));
		WARN_ON(!(vma->vm_flags & VM_MAYWRITE));
```
in that order — theirs' replacement first, then sdm670's vendor
`VM_MAYWRITE` check. Dropping the `WARN_ON` would silently lose a Samsung check
(sdm670/fs/userfaultfd.c:1026 @ a30605a54f3b) that the series tree does not have;
there is no reason to drop it, it is orthogonal to the `vm_ops` cleanup.
Note the commit author's own caveat in the message: `vma_is_anonymous()` is only
behaviour-identical to the `vm_ops` test for vmas without VM_PFNMAP set, which is
true for every userfaultfd-registered vma, so the swap is safe here.
Low stakes: pure cleanup, nothing to do with eBPF or boot, and safe to drop.
## Confidence
high: step 4 done with two searches per file, the vendor line is identified
exactly, and `vma_is_anonymous()` is confirmed to exist in sdm670 so the rest of
the commit applies without a prerequisite.
## Problems
None
