# Moving the build drive to another computer

Written 2026-10-10 after the `sda` → `sdb` drive swap and the interrupted copy. Companion to
[`scripts/portability-check.sh`](scripts/portability-check.sh), which checks most of this automatically.

**Short answer: the drive is not self-contained.** It holds both source trees and every commit, but three
things that matter live on the machine's internal disk, and one of them breaks the build *silently*.

## Contents of the drive

| Path | What | Portable |
|---|---|---|
| `/mnt/build/lineage` | LineageOS 23.2 tree, `.repo`, `out/` (incl. `out/keep/release-20261008/`) | source yes, `out/` **no** |
| `/mnt/build/lineage-24` | LineageOS 24.0 tree, synced, device tree on `l24` @ `5af53f1` | yes |
| `/mnt/build/k670` | ExyHyperBrick kernel clone | yes |
| `/mnt/build/handoff` | misc | yes |

## What does NOT travel

Three things live on the internal disk. Copy them or recreate them.

### 1. `~/bin/repo` — the repo launcher

```
cp ~/bin/repo <new-host>:~/bin/repo
chmod +x ~/bin/repo
```

`repo sync` and `repo init` both need it. It is a small Python launcher that bootstraps `.repo/repo` from
inside the tree.

### 2. `~/work/llvmbin/` — the one that silently breaks the build

Debian's `llvm-19` packages ship only **versioned** binary names (`llvm-nm-19`, `llvm-objcopy-19`), but the
kernel's kbuild with `LLVM=1` looks for the **unversioned** ones. Without this directory on `PATH`:

- the build **succeeds**
- `vdso.so.dbg` does **not** link
- `vdso_offset_sigtramp` is generated **wrong**

That is a silently broken sigreturn trampoline, not a build error. It surfaces much later as an unexplained
boot crash on the tablet. This is the single most important item on this page.

Recreate it on the new host:

```bash
mkdir -p ~/work/llvmbin
for f in /usr/bin/llvm-*-19; do ln -sf "$f" ~/work/llvmbin/"$(basename "$f" -19)"; done
export PATH="$HOME/work/llvmbin:$PATH"
```

Or copy it directly: `cp -a ~/work/llvmbin <new-host>:~/work/llvmbin`

### 3. `~/.gitconfig` — the SSH rewrite

```
[user]
	name = ahscholt
	email = 124476596+anton-scholten@users.noreply.github.com
[url "git@github.com:"]
	insteadOf = https://github.com/
```

The `insteadOf` rule matters: several project remotes in the trees are stored as
`https://github.com/anton-scholten/...`, which has no usable credentials. Without the rewrite,
`git fetch` and `git push` fail with `could not read Username for 'https://github.com'`.

## Host packages

On the new machine, Debian/Ubuntu:

```bash
apt-get install -y git git-lfs clang lld flex bison libssl-dev make rsync python3 \
  binutils-aarch64-linux-gnu binutils-arm-linux-gnueabi gcc-aarch64-linux-gnu dwarves
```

`git-lfs` is required: the tree was cloned with `--git-lfs`.
`dtc` is **not** needed — arm64 `.dtsi` files compile through clang.

## Mounting the drive

The drive is `/dev/sdb` (WDC WD1002FAEX, serial `WD-WCATRC405557`). **Check the letter on the new machine** —
it depends on plug order, and `/dev/sda` here is a different physical disk.

### Every boot

```bash
sudo mount /dev/sdb /mnt/build
sudo mount --bind /mnt/build/lineage ~/android/lineage
```

That is the whole sequence. The bind mount is what puts the 23.2 tree at the path the 23.2-era notes and
`out/` expect.

The 24.0 tree needs **no** bind mount. `/mnt/build` is `anton`-owned and writable, so
`/mnt/build/lineage-24` is used directly. That is deliberate: it needs no `sudo`, and it removes a class of
"bind mount missing, build writes somewhere else" failure. The cost is longer paths in build logs, which
nothing cares about.

### Make it survive a reboot

Neither mount was in `/etc/fstab`, which is why they must be redone manually. To fix that:

```bash
echo '/dev/sdb /mnt/build ext4 defaults,nofail 0 2' | sudo tee -a /etc/fstab
```

`nofail` lets the machine boot with the drive unplugged instead of dropping to an emergency shell. The bind
mount is not an `fstab` line; it needs a `mount --bind` after each boot, or a systemd unit.

Then verify:

```bash
findmnt -o TARGET,SOURCE,FSTYPE | grep -E "sdb|/mnt|android"
```

Expected, and only these:

```
/mnt/build                     /dev/sdb  ext4
/home/anton/android/lineage    /dev/sdb  ext4
```

### Paths are baked in

`out/` and `.repo` record absolute paths. Mount the drive at `/mnt/build` on the new machine, not somewhere
else, or everything built here becomes invalid.

## Before you unplug

```bash
bash scripts/portability-check.sh --preflight
```

Exit 0 means safe. It verifies `.repo` is present, every project is checked out, our four repos carry the
expected commits, `git fsck` passes, and it names the three things above that won't travel.

The two projects an interrupted copy damages are `prebuilts/sdk` and
`prebuilts/rust-toolchain/linux-x86` — they were the ones left half-written when the copy to `sdb` was
stopped, and the script checks them by name.

## After you plug in on the new host

```bash
bash scripts/portability-check.sh --on-new-host
```

It checks the `llvmbin` links, host tools, the mount, the SSH key, and free space.

## Signing keys

`build/target/product/security/*.pk8` lives in `out/`, and `out/` is machine-specific and not portable. If
the 24.0 build should install over the 23.2 build, both must be signed with the same keys. Otherwise a clean
install with **Format data** is required.

Decide this before installing, not after.

## Next steps, in order

Current state (2026-10-10): L0–L6 done, 24.0 tree synced and verified, L7 staged but **not started**.

### 1. First build (L7)

```bash
cd /mnt/build/lineage-24
env -i HOME=$HOME USER=$USER PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 \
  bash --noprofile --norc -c \
  'unset USE_CCACHE; source build/envsetup.sh && breakfast gts4lvwifi && mka bacon -k 0' \
  2>&1 | tee ~/work/l24-build-1.log
```

Then:

```bash
grep -n "^FAILED:" ~/work/l24-build-1.log
```

`USE_CCACHE` must stay **unset** for every build, and must not change between runs — it forces a full
rebuild. `env -i` keeps the environment clean so results are reproducible.

**Escalate, do not fix**, on any of these (TASKS-L24 §L7):

- `check_elf_file` unresolved symbol in a blob — needs a shim like `libshim_wfdservice`
- any kernel compile error
- any SELinux `neverallow` failure
- a VINTF incompatibility not solved by an entry L2 approved

Never disable a check to make an error go away: no SELinux permissive, no `BUILD_BROKEN_*`, no
`allow_undefined_symbols`, no `check_elf_files: false`, no deleting code.

### 2. Before building, consider moving `out/`

The drive is a spinning disk. Measured on it: **6.3 MB/s** sequential write, **1.9 MB/s** random 4K.
The internal NVMe does **396 MB/s**.

Free space right now is ~315 GB and `out/` needs roughly 300 GB, so it is tight. Builds will be slow.
Putting `out/` on the NVMe is a large win and frees the drive. Worth doing before the first build rather than
after three slow iterations.

### 3. What to expect in the first build

| Risk | Source | Note |
|---|---|---|
| `libui` link failure | motorola `013cbf52557f` | `-DLEGACY_GRALLOC` is new in 24.0; `frameworks/native/libs/ui/Android.bp:136-139`. The L6 commit should prevent this |
| ION symbol errors | sm7125 `429c604442ac` | legacy libion; `TARGET_USES_ION` is still set, so 24.0 should keep the legacy path |
| netbpfload fatal gates | `NetBpfLoad.cpp:1578`, `:1584` | 5.10 and 5.15 gates are now fatal `return 7`. Our 5.15.178 passes, but if the override stops being read we lose netd BPF entirely |
| `/apex/com.android.resolv` rejection | `NetBpfLoad.cpp:1542` | new in 24.0, absent in 23.2 |
| `/metadata/aconfig` SELinux | unchecked by L3 | our `b26a9d6` OMR fix depends on it; 24.0 also creates it at early-init |
| kernel requirements | matrix 7 wants ≥ 4.14.336, ours is 4.9.337 | harmless now; if it bites, sm7125's `PRODUCT_OTA_ENFORCE_VINTF_KERNEL_REQUIREMENTS := false` is the reference fix |

### 4. After a successful build (L8)

Debug build first, so adb works during a boot loop:

```bash
WITH_ADB_INSECURE=true breakfast gts4lvwifi && mka bacon -k 0
```

⚠️ A clean install (**Format data**) is required going from 23.2 to 24 unless both builds share signing keys.

### 5. LTE (L9) is still blocked

`libril.so` hard-depends on `android.hardware.radio@1.4.so`; FCM 7 allows only `1.2` (ISap) and `1.5–6`
(IRadio). No device-tree change fixes this. It needs a strong-model decision: tolerate it, write a
1.4→1.5 passthrough shim, or ship LTE without telephony. The Wi-Fi model is unaffected. **Build Wi-Fi first.**

### 6. Later

- **L8** boot-log triage → `analysis/l24/boot-24-<n>.md`
- **L10** testing: `scripts/device-checks.sh`, expect 5 PASS + 1 SKIP as on 23.2. Also check the BPF
  program count: our 23.2 build attaches 14 cgroup programs, and 24.0 keys program ranges on API level
- **L11** release

## Upstream is still moving

`lineage-24.0` is pre-release with no official 24.0 build for any device. `frameworks/base` took 165 commits
in the 30 days to 2026-10-09.

- Base pin: `2a50ca061bffe` (2026-09-30, "manifest: Track Canvas")
- Re-run L1's diff before cutting any new branches — `hardware/samsung` SHAs churn and its 30-commit list is
  mostly a rebase artifact
- Move the base with **targeted** `repo sync -c <project>` calls, never a blanket sync

Current state of the port: zero kernel commits needed for 24.0 (ExyHyperBrick's `lineage-24.0` ==
`lineage-23.2` == `baa585f67e0e`; Motorola's exynos9610 kernel compare is `ahead_by=0, behind_by=0`). The
work is device tree only.