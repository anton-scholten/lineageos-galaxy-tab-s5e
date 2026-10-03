<!-- task: K2d-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# d5f2acfd8dc2: UPSTREAM: userfaultfd: require writable shmem and hugetlb VMAs
- Author / date: Andrea Arcangeli <aarcange@redhat.com>, 2018-11-26 (series copy by Mathias Gluszczynski)
- Upstream: 29ec90660d68bbdd69507c1c8b4e33aa299278b1
- Batch: K2d-2, size_class: moderate
## Conflicting files
- fs/userfaultfd.c
- mm/userfaultfd.c
## Why it conflicts
merge-tree on its own (`git merge-tree --write-tree --merge-base=d5f2acfd8dc2^ a30605a54f3b d5f2acfd8dc2`, tree
`d392eaf83530408b5ba8349e867255179b362360`) reports 3 blocks. Only one of them is a real duplicate; the other two are
stacked-replay artefacts.

- Block 1, mm/userfaultfd.c ~line 144 (merged file): ours = nothing after `mm_alloc_pmd()`; theirs = the whole
  `#ifdef CONFIG_HUGETLB_PAGE ... __mcopy_atomic_hugetlb() {...}` function. False positive: that function is already in
  sdm670's file after `880ea49bde40` is resolved (see that brief). The merge-base for this commit already contains it.
- Block 2, mm/userfaultfd.c ~line 451 (merged file): ours = nothing; theirs = the comment *"Check the vma is registered
  in uffd, this is required to enforce the VM_MAYWRITE check done at uffd registration time."* plus a **second**
  `if (!dst_vma->vm_userfaultfd_ctx.ctx) goto out_unlock;`. Also a false positive: after `e9357b031a71` the check is
  already at the position upstream wants (see that brief). Both of these "theirs" additions are comment/duplication
  only.
- Block 3, fs/userfaultfd.c ~line 843 (merged file), inside the `for (cur = vma; ...)` compatibility loop of
  `userfaultfd_register()`: ours = nothing there; theirs = the new 13-line block
  `ret = -EPERM; if (unlikely(!(cur->vm_flags & VM_MAYWRITE))) goto out_unlock;` with the *"UFFDIO_COPY will fill file
  holes even without PROT_WRITE..."* comment. **sdm670 already has this exact block, verbatim, 12 lines further down**
  - `fs/userfaultfd.c:844-853` @ `a30605a54f3b` (comment lines 844-850, `ret = -EPERM;` 851,
    `if (unlikely(!(cur->vm_flags & VM_MAYWRITE)))` 852, `goto out_unlock;` 853). The conflict is a pure duplicate
    insertion, so the resolution is to keep the empty side.
  (The isolated run also shows a `BUG_ON(vma->vm_ops)` vs `BUG_ON(!vma_can_userfault(vma))` block in
  `userfaultfd_register()`. That one is not in the trial's block list because earlier series commit
  `9114ddb3b20f` "UPSTREAM: userfaultfd: introduce vma_can_userfault" (CLEAN in the trial) already rewrote sdm670's
  line. Nothing to do there.)

## Already in sdm670?
**yes** - sdm670 already carries this exact upstream change, as commit
`3de7f84519282d2bfe0e97d5cdef5b2a4834d01c` "BACKPORT: userfaultfd: shmem/hugetlbfs: only allow to register
VM_MAYWRITE vmas" (Joel Fernandes, 2019-02-15), whose message says "commit
29ec90660d68bbdd69507c1c8b4e33aa299278b1 upstream" - the same upstream SHA this series commit carries. It is an
ancestor of the sdm670 tip (`git merge-base --is-ancestor 3de7f8451928 a30605a54f3b` -> YES).

All four functional hunks are already present in `a30605a54f3b`:
- shmem/hugetlb `VM_MAYWRITE` check in `userfaultfd_register()`: `fs/userfaultfd.c:851-853`
- `WARN_ON(!(vma->vm_flags & VM_MAYWRITE));` in `userfaultfd_register()`: `fs/userfaultfd.c:880`
- `WARN_ON(!(vma->vm_flags & VM_MAYWRITE));` in `userfaultfd_unregister()`: `fs/userfaultfd.c:1025`
- the `mm/userfaultfd.c` comment change ("Be strict ..." -> "Check the vma is registered in uffd ..."), which is
  literally the same edit as this commit's `mm/userfaultfd.c` hunk - see `git show 3de7f8451928 -- mm/userfaultfd.c`

Searched lines (all HIT in `a30605a54f3b`, i.e. presence proven): `if (unlikely(!(cur->vm_flags & VM_MAYWRITE)))`
(2 hits: 852 and the one in the merged region), `WARN_ON(!(vma->vm_flags & VM_MAYWRITE))` (880, 1025),
`Check the vma is registered in uffd` (`mm/userfaultfd.c`).
## Proposed resolution
DROP: skip this commit. Everything it changes is already in sdm670 via `3de7f8451928` (same upstream SHA
`29ec90660d68`), verified line by line above.

The only thing that would be "lost" is cosmetic: the *second* comment edit, inside `__mcopy_atomic_hugetlb()`, which
rewrites *"Only allow __mcopy_atomic_hugetlb on userfaultfd registered ranges."* into the CAF wording. That function only
exists in our tree after `880ea49bde40` and is inside `#ifdef CONFIG_HUGETLB_PAGE`, which is off in the gts4lv
defconfigs - so the comment is dead text either way.

If the lead would rather keep the series byte-faithful, the equivalent is: take everything except the `fs/userfaultfd.c`
insertion, i.e. resolve block 3 to the empty side. That is behaviourally identical to dropping the commit.
## Confidence
high: the proof is a commit in sdm670's own history carrying the same upstream SHA `29ec90660d68bbdd69507c1c8b4e33aa299278b1`,
and every one of the four hunks was located at a concrete `file:line` in `a30605a54f3b`.
## Problems
None
