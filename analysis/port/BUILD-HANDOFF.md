# Build handoff: running `brunch gts4lvwifi` on another machine

Written 2026-10-04 after B1 failed twice on the original host. Everything needed to produce the ROM zip on a
machine with enough RAM, and nothing else. Provenance for every claim is in [B1-log.md](B1-log.md).

## TL;DR

The kernel and device tree are done and verified. **The only thing left is one `brunch`.** It failed twice on a
15 GB-RAM host, both times OOM-killed by the kernel during Soong's glob phase. Nothing about the port is wrong.

```
brunch gts4lvwifi
```

That is the whole remaining task. If it fails, the error is a real port error and belongs to P6
([AGENT-TASKS.md §6c](../../AGENT-TASKS.md)). If it is OOM-killed again, it is the host.

## Not an option: a Claude Code cloud session (checked 2026-10-04)
A cloud session has 4 CPUs, **15 GB RAM** (the same as the host that was OOM-killed) and a writable-disk allowance of about 25–30 GB
(this session: 23 GB free), against the ~180 GB sync plus ~40 GB `out/`. Neither fits. Use a machine with ≥32 GB RAM and ≥250 GB disk:
the owner's machine with more RAM, a friend's PC, or a rented cloud VM. A Claude session is still useful for P6/P7 *reviews* (it reads logs, not the tree).

## Requirements

| | minimum | recommended |
|---|---|---|
| RAM | 16 GB, and Android warns "even with that, some configurations may not work" | **32 GB** |
| swap | 8 GB | 32 GB |
| disk free | 200 GB | 250 GB |
| OS | Linux x86-64 | any modern distro |
| network | fast — the sync is ~180 GB | |

The failed host had 15.4 GB RAM, 15 GB swap, 96 GB free disk. `soong_build` alone peaked at **14.2 GB RSS plus
13.6 GB swap** and was killed. **Disk was never the problem** — it stayed at 96 GB through both attempts.

## The two commits that must be in the tree

Verified present and correct on the failed host. Check these first on the new machine; if they match, the tree is
right and any failure is a genuine build error.

```bash
cd <tree>
git -C kernel/samsung/sdm670 rev-parse --short HEAD        # must print 801f3f20e54a
git -C device/samsung/gts4lv-common rev-parse --short HEAD # must print e3ccc923bcf2
```

Both are the `lineage-23.2` tips of the owner's forks, fast-forwarded in RUNBOOK step 7:

- kernel `https://github.com/anton-scholten/android_kernel_samsung_sdm670` → `801f3f20e54a…`
- device `https://github.com/anton-scholten/android_device_samsung_gts4lv-common` → `e3ccc923bcf2…`

## Getting the tree

Two options. **Re-syncing is the safer choice** — the existing tree is 181 GB and mostly `.repo` git metadata.

### Option A — re-sync from scratch (recommended)

```bash
mkdir -p ~/bin && curl https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo && chmod a+x ~/bin/repo
export PATH="$HOME/bin:$PATH"
git config --global user.name  "Your Name"
git config --global user.email "you@example.com"

mkdir -p ~/android/lineage && cd ~/android/lineage
repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --no-clone-bundle

# copy the manifests out of the docs repo (anton-scholten/lineageos-galaxy-tab-s5e)
mkdir -p .repo/local_manifests
cp <docs-repo>/local_manifests/gts4lv-common.xml <docs-repo>/local_manifests/gts4lvwifi.xml .repo/local_manifests/

repo sync -c -j$(nproc) --force-sync
```

Sync takes hours. **If it fails, just run it again** — it resumes. The original attempt hit GitHub **HTTP 429
rate-limiting** at `-j12` and lost four repos to it; retrying those at `-j4` fixed three of them. If a fetch fails
with `429` or `RESOURCE_EXHAUSTED`, wait a few minutes and re-run rather than raising `-j`.

Copy `gts4lv.xml` too and run `breakfast gts4lv` if you also want the LTE model. Wi-Fi first is the primary target.

### Option B — copy the existing tree

```bash
rsync -a --info=progress2 ~/android/lineage/ newhost:~/android/lineage/
```

181 GB. Preserves the 995 MB Soong Go build cache, so the bootstrap is a little faster. Verify the two commits
above after copying.

### The three repos that never synced

`repo sync` lost these to rate-limiting and they are **not** in `.repo/projects/…` working trees:
`platform/external/tinyalsa_new`, `platform/tools/doc_generation`, `trusty/lib`.

**None is referenced by `device/samsung/gts4lv-common` or `device/samsung/gts4lvwifi`** (grepped), and
`tinyalsa_new` is a Qualcomm audio library while sdm670 uses Samsung's own audio stack. If the build genuinely
needs one, it will fail with a specific missing-path error — that is a real error for P6, not a silent problem.
`trusty/user/desktop` did sync.

## Packages

```bash
sudo apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs \
  gnupg gperf imagemagick protobuf-compiler python3-protobuf lib32readline-dev lib32z1-dev libdw-dev \
  libelf-dev lz4 libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool \
  squashfs-tools xsltproc zip zlib1g-dev python-is-python3
```

All exist in Debian 13 (trixie); none needed renaming. The ones that will actually stop a build:
`gcc-multilib` and `g++-multilib` (32-bit HALs), `zlib1g-dev`, `libssl-dev`, `libelf-dev`, `libdw-dev`,
`git-lfs`, `python-is-python3`.

Note `libxml2` reports oddly to `dpkg -s` because it is a multi-arch package — check
`dpkg -l 'libxml2*'` instead. It was installed and fine.

## Build

```bash
cd ~/android/lineage
source build/envsetup.sh
brunch gts4lvwifi 2>&1 | tee ~/work/rom-build.log
```

**`brunch gts4lvwifi`, not `brunch lineage_gts4lvwifi`.** `breakfast` adds the `lineage_` prefix itself and the
doubled name fails. Not a bare `m` either — `PRODUCT_BUILD_FLAVOR` is only set by `envsetup.sh:20`, so a bare `m`
builds with no error and no warning but the wrong flavor.

To cap parallelism if memory is still tight, use `breakfast gts4lvwifi && mka bacon -j6`. This does **not** help
with the OOM above, because Soong's glob phase runs before ninja and is single-process.

## Success

```
out/target/product/gts4lvwifi/lineage-23.2-*-UNOFFICIAL-gts4lvwifi.zip
```

Record its path, size and `sha256sum` in [B1-log.md](B1-log.md). Then flashing, per `README.md` — ⚠️ **unlocking
and installing erases all data on the tablet.**

## Traps, all of which cost time on the failed host

1. **OOM during `Running globs...`** is the host, not the port. `systemd` says
   `A process of this unit has been killed by the OOM killer`. The tell is that it dies at 100% of the *bootstrap*
   step, `[100% 1/1] bootstrap blueprint`, never reaching `[100% 2/2] analyzing Android.bp files`. **P6 must not
   "fix" this.**
2. **Do not trust a wrapper's exit status.** The first wrapper here captured `brunch`'s status then ran more
   commands, so systemd reported `Result=success` for a build that had failed. A unit wrapper must `exit $st`.
   Read the log, not the exit code.
3. **`setsid` does not detach from the systemd cgroup.** It escapes the session ID but the job stays in the
   launching shell's scope, so an OS-initiated session kill takes the build with it. Use
   `systemd-run --user --unit=rombuild --collect --property=MemoryMax=infinity <script>` for long jobs you want to
   survive. Verify with `cat /proc/<pid>/cgroup` — it must not mention your terminal.
4. **`repo` buffers its log without a TTY.** An empty `repo-sync.log` does not mean a stalled sync. Check
   `pgrep -cf '.repo/repo/main.py'`.
5. **The vendor blobs are in `proprietary/`, not `proprietary-files.txt`.** TheMuppets layout. Do not go looking for
   the missing file — 681 blobs are present in `gts4lv-common/proprietary`.

## If the build fails

Hand `~/work/rom-build.log` to P6 ([AGENT-TASKS.md §6c](../../AGENT-TASKS.md)). P6 works on `port/dt-2` in the
device tree, one commit per fix, and **must not**:

- use `permissive`, wildcard `allow`, or `neverallow` exceptions
- set any `BUILD_BROKEN_*` flag
- skip VINTF checks or change `target-level`
- raise `PRODUCT_SHIPPING_API_LEVEL` (R7: at 29+ the vendor property-namespace check switches on and fails the
  build with 15 violations)
- edit any repo other than the device fork
- retry the same error more than 3 times

**`PRODUCT_SHIPPING_API_LEVEL` must stay at 28** (`gts4lv.mk:18` → `product_launched_with_p.mk`, which lives
outside this repo).

## If the kernel needs rebuilding

Unlikely — it is verified — but if it does, the build needs `~/work/llvmbin` on `PATH`, because Debian's
`llvm-19` ships only versioned names (`llvm-nm-19`) while `LLVM=1` wants unversioned ones:

```bash
mkdir -p ~/work/llvmbin
for f in /usr/bin/llvm-*-19; do ln -sf "$f" ~/work/llvmbin/"$(basename "$f" -19)"; done
export PATH="$HOME/work/llvmbin:$PATH"
```

Without it the build **still exits 0** while `vdso_offset_sigtramp` is generated wrong — a silently broken
sigreturn trampoline. `dtc` is not needed; arm64 `.dtsi` files compile through clang.

Verified kernel state: `port/pick` @ `801f3f20e54a` builds `Image.gz-dtb` for both `gts4lvwifi_defconfig` and
`gts4lv_defconfig`, `check-pick.py` reports `problems: 0` with `fix commits: 20`.