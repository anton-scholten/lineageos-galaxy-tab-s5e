<!-- task: K2a-3 | agent: Space Bunny Free (space-bunny-free) | date: 2026-10-03 -->
# 7e93ac0afe0f: BACKPORT: bpf: Add dmabuf iterator
- Author / date: T.J. Mercier <tjmercier@google.com>, 2025-05-22
- Upstream: 76ea95534995adde1aa3cb1aa97ef33f50a617a9 (`(cherry picked from commit 76ea95534995...)`, the first hex match in the message). A second trailer, `(cherry picked from Android common commit 5594035ac7afd16ff7f924648d9306ab45a54488)`, is the Android-common copy, not the mainline one.
- Batch: K2a-3, size_class: trivial
## Conflicting files
- include/linux/dma-buf.h (the one the trial flagged)
- merge-tree on its own also reports: kernel/bpf/Makefile, drivers/dma-buf/dma-buf.c
- added by this commit with no conflict: kernel/bpf/dmabuf_iter.c (new file)
## Why it conflicts
merge-tree on its own: conflicts (tree `eff779ce8813cd35bb308293942cc0c5bec5fdbd`), 3 blocks, all insertions with `ours` empty.

- Block 1, drivers/dma-buf/dma-buf.c ~line 44 (top of file, after `static inline int is_dma_buf_file(struct file *);`): ours = sdm670's `struct dma_buf_list { struct list_head head; struct mutex lock; };` + `static struct dma_buf_list db_list;` (dma-buf.c:42-47) and its users lock `&db_list.lock` / walk `&db_list.head` (:72-74, :396-398, :868-911, :969-970); theirs = `static DEFINE_MUTEX(dmabuf_list_mutex);` + `static LIST_HEAD(dmabuf_list);` + `__dma_buf_list_add()`/`__dma_buf_list_del()` + this commit's new `dma_buf_iter_begin()`/`dma_buf_iter_next()`.
- Block 2, include/linux/dma-buf.h ~line 245 (end of the export list, before `#endif /* __DMA_BUF_H__ */`): ours = nothing; theirs = 5 lines - `dma_buf_set_privflag()`, `dma_buf_get_privflag()`, `get_dma_buf_file()` (**context**, not added by this commit) and the two actually-added lines `struct dma_buf *dma_buf_iter_begin(void);` / `struct dma_buf *dma_buf_iter_next(struct dma_buf *dmabuf);`.
- Block 3, kernel/bpf/Makefile ~line 10 (after `obj-$(CONFIG_CGROUP_BPF) += cgroup.o`): ours = nothing; theirs = three blocks - `ifeq ($(CONFIG_INET),y) ... reuseport_array.o`, `ifeq ($(CONFIG_SYSFS),y) ... sysfs_btf.o` (both from earlier commits) and `ifeq ($(CONFIG_DMA_SHARED_BUFFER),y) obj-$(CONFIG_BPF_SYSCALL) += dmabuf_iter.o endif`, which is the only line this commit adds.
## Already in sdm670?
no. Evidence:
- `git grep -n 'dma_buf_iter_begin\|dma_buf_iter_next\|dmabuf_iter' a30605a54f3b` -> **no hits anywhere in the tree**.
- Second check, the parts it builds on: `git grep -c get_file_rcu a30605a54f3b -- include/linux/fs.h` -> 2 hits (so the `get_file_rcu()` the iterator uses exists), `git grep -c 'dma_buf_put' a30605a54f3b -- include/linux/dma-buf.h` -> 3 hits, `git grep -c list_node a30605a54f3b -- include/linux/dma-buf.h` -> 2 hits (`struct list_head list_node;` at dma-buf.h:138). The list plumbing exists, only under sdm670's own `db_list` names.
- `git grep -n 'dma_buf_set_privflag\|dma_buf_get_privflag\|get_dma_buf_file' a30605a54f3b -- include/linux/dma-buf.h drivers/dma-buf/dma-buf.c` -> **no hits**. These three exist in exy at the series base (`git grep -c ... d54533f1546b -- include/linux/dma-buf.h` -> 1 hit each) and are untouched by every one of the 2599 series commits (`git log -S'dma_buf_set_privflag' d54533f1546b..baa585f67e0e` -> empty), so they are pure exy context that sdm670 never had.
- `BPF_ITER_RESCHED` and `bpf_iter_reg_target` are also absent from sdm670; they arrive with `b0c13acbe239` "BACKPORT: bpf: Permit rescheduling for safe iterator targets" and the other bpf_iter commits.
## Proposed resolution
PREREQ, then MERGE. Do **not** take any of the three blocks wholesale - two of them are mostly other commits' text.
- PREREQ (positions measured; this commit is pos 1945):
  - `bff4be212973` "BACKPORT: dma-buf: Rename debugfs symbols" (pos 1938) - this is the key one. It is the commit that replaces sdm670's `struct dma_buf_list` / `db_list` with `dmabuf_list_mutex` + `dmabuf_list` and adds `__dma_buf_list_add()` / `__dma_buf_list_del()`. Without it Block 1 cannot be resolved (the two sides use different list and mutex names), and the new iterator would walk the wrong list. It is not in the trial's conflict list, i.e. in the ordered replay it applied cleanly.
  - `b90ee5d15b13` (pos 1939) "BACKPORT: dma-buf: give each buffer a full-fledged inode" and `08d190f1da6e` (pos 1940) "BACKPORT: dma-buf: add DMA_BUF_SET_NAME ioctls" - the per-buffer inode / SET_NAME prerequisites the commit message names.
  - `57ab06cd8199` (pos 1145) for `reuseport_array.o` and `9dd9b06133f6` (pos 1266) for `sysfs_btf.o`, for Block 3.
  - `b0c13acbe239` for `BPF_ITER_RESCHED` (dmabuf_iter.c sets `.feature = BPF_ITER_RESCHED`).
- MERGE per block, after the PREREQs:
  - drivers/dma-buf/dma-buf.c: take *theirs* (with `bff4be212973` already applied the only remaining delta is `dma_buf_iter_begin()`/`dma_buf_iter_next()` plus the two added `#include`s). Do not reintroduce `struct dma_buf_list` / `db_list`.
  - include/linux/dma-buf.h: insert **only** the two iterator declarations. Leave out `dma_buf_set_privflag` / `dma_buf_get_privflag` / `get_dma_buf_file` - nothing in the whole series calls them (`git log -S` empty) and sdm670's drivers/dma-buf/dma-buf.c does not define them, so they would be declarations of functions that do not exist. Inserting them would also make this commit look like it carried more than its `2 ++` in the header.
  - kernel/bpf/Makefile: insert **only** the `ifeq ($(CONFIG_DMA_SHARED_BUFFER),y)` / `obj-$(CONFIG_BPF_SYSCALL) += dmabuf_iter.o` / `endif` block. With `57ab06cd8199` and `9dd9b06133f6` already applied the other two blocks are context.
- Worth knowing for the defconfig task (K6): `config DMA_SHARED_BUFFER` exists in sdm670 at drivers/base/Kconfig:251, and both tablet defconfigs already set it - `arch/arm64/configs/gts4lv_eur_open_defconfig:1296` and `arch/arm64/configs/gts4lvwifi_eur_open_defconfig:1296` are `CONFIG_DMA_SHARED_BUFFER=y`. So the guard is satisfied and `dmabuf_iter.o` really will be built and `BPF_ITER(dmabuf, ...)` really will be registered on this device; dropping this commit means losing that BPF iterator target entirely.
## Confidence
high: step 4 done with five checks, the supplying commits and their series positions were measured directly, and the 5-vs-2 line discrepancy in the header was traced (the first 3 lines are pre-series exy context, not part of this commit).
## Problems
None