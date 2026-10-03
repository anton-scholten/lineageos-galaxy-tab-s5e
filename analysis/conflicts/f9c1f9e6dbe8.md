<!-- task: K2a-4 | agent: Space Bunny Free | date: 2026-10-03 -->
# f9c1f9e6dbe8: BACKPORT: bpf: Check saved credentials for raw dumps
- Author / date: Kees Cook <keescook@chromium.org>, 2020-07-02
- Upstream: 160251842cd35a75edfb0a1d76afa3eb674ff40a (first of two; the commit also carries
  63960260457a02af2a6cb35d75e6bdb17299c882 "bpf: Remove prog->aux from attach type" side)
- Batch: K2a-4, size_class: trivial
## Conflicting files
- kernel/kallsyms.c (the only file the trial flagged; a standalone merge against sdm670 also flags
  `include/linux/filter.h`, `include/linux/kallsyms.h`, `kernel/bpf/syscall.c` and `kernel/module.c` -
  all four disappear once the earlier series commits are in, see below)
## Why it conflicts
merge-tree on its own: conflicts (5 files) - tree `0e84d50d293b59bf6ae3ef757c86309f5d67261f`
- Block 1, kernel/kallsyms.c ~line 27, include block right after `#include <linux/compiler.h>`:
  ours (sdm670 `a30605a54f3b:kernel/kallsyms.c:26-31`) adds nothing here, and instead has, further down
  after `#include <asm/sections.h>`, an **unconditional** `#include <linux/sec_debug.h>` +
  `#include <linux/sec_debug_summary.h>`;
  theirs (series) adds four lines: `#include <linux/security.h>`, `#ifdef CONFIG_SEC_DUMP_SUMMARY`,
  `#include <linux/sec_debug.h>`, `#endif`.
  I reproduced the trial's tree by replaying the three earlier series commits that touch
  `kernel/kallsyms.c` (`0fa93420be87`, `a3fce8d2ace1`, `06910dd01baf`, all **CLEAN** in the trial) onto
  sdm670's file, and applying this commit's `kernel/kallsyms.c` diff to that gives exactly **one** rejected
  hunk - this include block, 2 lines on ours / 4 lines on theirs, matching
  `analysis/exyhyperbrick-trial/conflict_detail.tsv`. Everything else in the file merges:
  `kallsyms_show_value(const struct cred *cred)` with `security_capable_noaudit(cred, &init_user_ns, CAP_SYSLOG)`,
  and `iter->show_value = kallsyms_show_value(file->f_cred);`.
- The other four files: `kernel/module.c` because sdm670 still has the plain
  `return seq_open(file, &modules_op);` (fixed by earlier commit `06910dd01baf`, CLEAN);
  `include/linux/kallsyms.h`, `include/linux/filter.h`, `kernel/bpf/syscall.c` because sdm670's BPF subsystem
  is pre-5.x (`a30605a54f3b:kernel/bpf/Makefile` has only syscall/verifier/inode/helpers/hashtab/arraymap/
  percpu_freelist), all replaced by earlier commits of the series.
## Already in sdm670?
no. Evidence: `git grep -n 'kallsyms_show_value' a30605a54f3b -- kernel/kallsyms.c` returns no hits, and
`git grep -n 'KALLSYM_FMT' a30605a54f3b -- kernel/ include/` returns no hits either (the symbol and the format
macro are both new). Searched for `kallsyms_show_value`, `KALLSYM_FMT`, `security_capable_noaudit`;
`security_capable_noaudit` *does* already exist in sdm670
(`a30605a54f3b:include/linux/security.h:207`, 4.9 signature `int (*cred, struct user_namespace *, int cap)`),
which is what the commit needs, so no extra backport is required for it.
## Proposed resolution
MERGE: resolve the include block to sdm670's layout plus the one include the commit genuinely needs:
```c
#include <linux/compiler.h>
#include <linux/security.h>

#include <asm/sections.h>

#include <linux/sec_debug.h>
#include <linux/sec_debug_summary.h>
```
i.e. add `#include <linux/security.h>` and **drop** theirs' `#ifdef CONFIG_SEC_DUMP_SUMMARY` /
`#include <linux/sec_debug.h>` / `#endif` trio. Reason: sdm670 already includes `<linux/sec_debug.h>`
unconditionally at `a30605a54f3b:kernel/kallsyms.c:30` plus `<linux/sec_debug_summary.h>` at `:31`, and
sdm670's kallsyms.c uses `CONFIG_SEC_DUMP_SUMMARY` nowhere (`git grep -c CONFIG_SEC_DUMP_SUMMARY
a30605a54f3b -- kernel/kallsyms.c` = 0 matches), so their guarded copy is a duplicate. Adding the guarded one
would also be harmless, but taking "ours" for the whole block is **not** safe: it would drop
`<linux/security.h>`, which `security_capable_noaudit()` at merged `kernel/kallsyms.c:718` needs.
Take the rest of the commit as-is.
If the lead does hit the other four conflicts (which means an earlier series commit was skipped):
- `include/linux/kallsyms.h`: accept theirs wholesale - sdm670 has neither `struct cred;` nor
  `kallsyms_show_value()` nor `KALLSYM_FMT`, all three are new and additive.
- `include/linux/filter.h`: keep theirs' `bpf_dump_raw_ok(const struct cred *)`; the surrounding
  `bpf_jit_*` prototypes around it belong to earlier BPF commits and are not this commit's business.
- `kernel/bpf/syscall.c`: needs the whole modern BPF syscall layer from earlier commits; if it is missing the
  commit cannot be applied at all.
## Confidence
high: I reconstructed the trial's exact stacked tree for this file and reproduced the single 2-vs-4-line
conflict block, verified `security_capable_noaudit()` exists in sdm670 with the signature the commit calls,
verified sdm670's `sec_debug.h`/`sec_debug_summary.h` includes are unconditional and that
`CONFIG_SEC_DUMP_SUMMARY` is unused in sdm670's kallsyms.c, and confirmed the change itself is absent from
sdm670 with three greps.
## Problems
None