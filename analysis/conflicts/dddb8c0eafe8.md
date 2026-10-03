<!-- task: K2b-2 | agent: Space Bunny Free | date: 2026-10-03 -->
# dddb8c0eafe8: BACKPORT: bpf: Add probe_read_{user,kernel}{,_str} helpers
- Author / date: Daniel Borkmann <daniel@iogearbox.net>, 2019-11-02
- Upstream: 31cfb5f7d21d795c59ba96c485c016903c7dcbfe ("(cherry picked from commit ...)")
- Batch: K2b-2, size_class: moderate
## Conflicting files
The trial recorded only `kernel/trace/bpf_trace.c`. merge-tree on its own reports three:
- kernel/trace/bpf_trace.c
- include/linux/bpf.h
- kernel/bpf/core.c
## Why it conflicts
merge-tree on its own: conflicts (tree `cbd28d4ad4bb74a2e9dd71dc593eba8a20d4ba01`).
The bpf.h and core.c blocks are artefacts of comparing against pristine sdm670: the forward declarations in
include/linux/bpf.h come from `46bd33883a6eb110778dfb76f5dc2e53382aa96a` (CLEAN, earlier), and the 3-argument
`__weak bpf_probe_read_kernel` comes from `5b18ca4a656b4add6ec842cbab50ce920659fe45` (CLEAN, earlier, the commit
right before this one in the same patch set). Both are ancestors of dddb8c0eafe8, so in the stacked replay they
are already there and only bpf_trace.c clashes.

- Block 1, kernel/trace/bpf_trace.c ~line 77: ours = sdm670's legacy pair, `BPF_CALL_3(bpf_probe_read, void *,
  dst, u32, size, const void *, unsafe_ptr)` with body `probe_kernel_read()` and `bpf_probe_read_str`, and
  protos `bpf_probe_read_proto` / `bpf_probe_read_str_proto`; theirs = **renames** those to
  `bpf_probe_read_user()` (body `probe_user_read()`) and `bpf_probe_read_user_str()`
  (`strncpy_from_unsafe_user()`), plus new `bpf_probe_read_kernel_common()`, `bpf_probe_read_kernel()`,
  `bpf_probe_read_kernel_str()` and the four `_proto` structs plus the two compat protos.
- Block 2, kernel/trace/bpf_trace.c ~line 589: ours = `static const struct bpf_func_proto *tracing_func_proto(
  enum bpf_func_id func_id)` (1 argument); theirs = the same function with a second argument
  `const struct bpf_prog *prog`. That second argument was introduced by `86d4a3ab7e8d` (CLEAN, earlier).
- Block 3, kernel/trace/bpf_trace.c ~line 603 (inside the `switch (func_id)`): ours =
  `case BPF_FUNC_probe_read: return &bpf_probe_read_proto; case BPF_FUNC_probe_read_str: return
  &bpf_probe_read_str_proto;` and nothing else there; theirs = `case BPF_FUNC_map_push_elem / map_pop_elem /
  map_peek_elem` (from `1b238c542e86`, CLEAN, earlier) - the probe_read cases have been moved further down.
- Block 4, kernel/trace/bpf_trace.c ~line 640: ours = nothing; theirs = the six new cases
  (`probe_read_user` -> user proto, `probe_read_kernel` -> kernel proto, `probe_read` -> compat proto,
  `probe_read_user_str`, `probe_read_kernel_str`, `probe_read_str` -> compat str proto) followed by
  `case BPF_FUNC_get_current_cgroup_id` (from `f6bb9492b38a`, CLEAN, earlier).
- Block 5, include/linux/bpf.h ~line 18: ours = sdm670 has only `struct perf_event; struct bpf_map;` before
  `struct bpf_map_ops`; theirs = adds the forward-declaration block and the declaration, which this commit
  rewrites to the 5-register form `u64 bpf_probe_read_kernel(u64 dst, u64 size, u64 unsafe_ptr, u64 r4, u64 r5);`
- Block 6, kernel/bpf/core.c ~line 530: ours = nothing; theirs = `u64 __weak bpf_probe_read_kernel(u64, u64, u64,
  u64, u64)` weak body `memset(...); return -EFAULT;`. Block 7, kernel/bpf/core.c ~line 928: ours = nothing;
  theirs = rewrites the four `LDX_PROBE_MEM_{B,H,W,DW}` interpreter labels to call the 5-argument form.
## Already in sdm670?
no. Six symbol greps at a30605a54f3b over include/linux/bpf.h, kernel/bpf/core.c, kernel/trace/bpf_trace.c,
all miss: `bpf_probe_read_user`, `bpf_probe_read_kernel`, `bpf_probe_read_user_str`,
`bpf_probe_read_kernel_str`, `bpf_probe_read_compat_proto`, `bpf_probe_read_kernel_proto`.
What sdm670 does have: only the legacy `BPF_CALL_3(bpf_probe_read, void *, ...)` at
a30605a54f3b:kernel/trace/bpf_trace.c:78, and `ARG_PTR_TO_UNINIT_MEM` is **not** in
a30605a54f3b:include/linux/bpf.h (it arrives with the earlier series commits `91722e2c9664` /
`bf98dbca4929`). The two libc helpers the new code calls do exist: `probe_user_read` and
`strncpy_from_unsafe_user` at a30605a54f3b:include/linux/uaccess.h.
## Proposed resolution
MERGE: take the series side; it is a rename plus additions, and it must be consistent with the three earlier
CLEAN commits named above. Per block:
- kernel/trace/bpf_trace.c block 1: take theirs. Do **not** keep sdm670's legacy `bpf_probe_read()` /
  `bpf_probe_read_str()` as well - the new `bpf_probe_read_compat_proto` / `bpf_probe_read_compat_str_proto`
  already serve the old helper IDs, so keeping both would give two symbols for one ID.
- block 2: take theirs (the `const struct bpf_prog *prog` parameter). sdm670's 1-argument form must go, or the
  `86d4a3ab7e8d` and BTF commits will not compile.
- block 3 + block 4: the merged switch must end up with all three groups - push/pop/peek (earlier commit),
  the six probe_read cases, and get_current_cgroup_id - and every `&bpf_probe_read_proto` /
  `&bpf_probe_read_str_proto` reference must be gone.
- include/linux/bpf.h block 5: take theirs for the signature; the forward declarations are already present
  from `46bd33883a6e`, so this hunk reduces to the one-line signature change.
- kernel/bpf/core.c blocks 6 + 7: take theirs. This is the "convert the interpreter bridge to the real
  five-register BPF helper ABI" from the backport note; it must land together with the include/linux/bpf.h
  signature change or `LDX_PROBE_MEM_*` will not build.
Build dependency the lead should know about: `bpf_probe_read_kernel_common()` calls
`probe_kernel_read_strict()`, which does **not** exist in sdm670 (no match at a30605a54f3b). It is supplied by
earlier series commit `d5cc8354a7d0bb47b40d5e4f99d8edea59aa0759` "UPSTREAM: uaccess: Add strict non-pagefault
kernel-space read function" (status CLEAN), which is an ancestor of this commit. On arm64 the only
implementation is the weak generic alias at baa585f67e0e:mm/maccess.c:56
(`long __weak probe_kernel_read_strict(...) __attribute__((alias("__probe_kernel_read")))`), i.e. on arm64 it
behaves exactly like `probe_kernel_read()`. There is no real arm64 implementation at baa585f67e0e (the only
non-weak one is baa585f67e0e:arch/x86/mm/maccess.c:29). That is expected and fine, but it means
`bpf_probe_read_kernel` on this device is not stricter than `probe_kernel_read` - do not let anyone "fix" that
by dropping the strict call.
## Confidence
medium: step 4 done with six symbol greps, and I verified every prerequisite symbol and commit (including the
arm64 behaviour of probe_kernel_read_strict), but this is a 162-line commit whose hunks interlock with three
earlier commits and I could not replay the stack to confirm the result compiles.
## Problems
None
