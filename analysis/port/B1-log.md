<!-- task: B1 -->
# B1: ROM sync and first build

Started by the lead on 2026-10-04. B1's own steps 3–5 (verify, build, log) are still to be run by the
B1 agent; this entry records what the lead did directly, and why.

## Host

`anton@DellXPS`, Debian GNU/Linux 13 (trixie), x86-64, 12 cpus.

| | measured | B1 spec minimum | |
|---|---|---|---|
| disk free | 278 GB at start, 272 GB mid-sync | ≥300 GB | **below spec** |
| RAM | 15 GB total, ~9–10 GB available | ≥16 GB | **below spec** |
| swap | 15 GB total | not in spec | the margin that makes RAM survivable |

Both shortfalls are recorded rather than hidden. See "Risks" below.

## Step 7 precondition: PASS

Checked read-only before anything was pushed or fetched:

| fork | `lineage-23.2` | expected |
|---|---|---|
| kernel | `801f3f20e54a13b0b42e062b19eef871db87f53a` | `801f3f20e54a` ✅ |
| device | `e3ccc923bcf225482a0cc5fa5d92b1257dadf3b8` | `e3ccc923bcf2` ✅ |

`lineage-22.2` untouched on both forks (`a30605a54f3b` kernel, `d1b339be7abe` device).
`port/pick` == `lineage-23.2` and `port/dt` == `lineage-23.2`.

## Manifest pre-flight: PASS

Every project in `local_manifests/gts4lv-common.xml` + `gts4lvwifi.xml` resolves, and two of them land
**exactly on the ported commits**, so B1 step 3 is expected to pass:

| project | remote | branch | resolves to |
|---|---|---|---|
| `device/samsung/gts4lv-common` | anton | lineage-23.2 | `e3ccc923bcf2` ✅ the port tip |
| `kernel/samsung/sdm670` | anton | lineage-23.2 | `801f3f20e54a` ✅ the port tip |
| `hardware/samsung` | LineageOS | lineage-23.2 | `5d20e3541d14` |
| `vendor/samsung/gts4lv-common` | TheMuppets | lineage-22.2 | `b04a4eef4efc` |
| `device/samsung/gts4lvwifi` | LineageOS | lineage-22.2 | `b54236c99ffb` |
| `vendor/samsung/gts4lvwifi` | TheMuppets | lineage-22.2 | `31c7bccdc640` |

`remote="github"` used by `hardware/samsung` and `device/samsung/gts4lvwifi` **is** declared, by LineageOS's
own `default.xml` at `lineage-23.2`. Verified, because an undeclared remote name would have failed the sync
only at the end.

**Note:** the comment inside `gts4lv-common.xml` still says *"The kernel is still plain lineage-22.2 (the eBPF
port is not done yet), so a build boots only once the kernel work lands."* That is **stale** — the kernel work
has landed and `lineage-23.2` points at `801f3f20e54a`. The comment is the lead's to fix; it is not a
functional problem. `confidence: high`.

## Done by the lead

- `repo` launcher 2.65 installed to `~/bin/repo`, `~/bin` on `PATH` for the sync.
- `repo init -u https://github.com/LineageOS/android.git -b lineage-23.2 --git-lfs --no-clone-bundle` in
  `~/android/lineage`. Succeeded.
- `local_manifests/gts4lv-common.xml` and `gts4lvwifi.xml` copied to `.repo/local_manifests/`.
  (`gts4lv.xml`, the LTE variant, deliberately not copied — Wi-Fi model first.)
- **`repo sync -c -j12 --force-sync` started**, logging to `~/work/repo-sync.log`, `USE_CCACHE=1`.
  Running unattended; `repo` buffers its log when stdout is not a TTY, so an empty log does **not** mean a
  stalled sync — check for `git fetch` processes instead.

## Blocked on the owner: 20 missing packages

`sudo` needs a password, so the lead could not install these. All 20 exist in Debian 13 (trixie); none is
unavailable. The sync does not need them, but **the build does**.

```bash
sudo apt install -y bc bison build-essential ccache curl flex g++-multilib gcc-multilib git git-lfs \
  gnupg gperf imagemagick protobuf-compiler python3-protobuf lib32readline-dev lib32z1-dev libdw-dev \
  libelf-dev lz4 libsdl1.2-dev libssl-dev libxml2 libxml2-utils lzop pngcrush rsync schedtool \
  squashfs-tools xsltproc zip zlib1g-dev python-is-python3
```

Of these, the ones that will actually stop the build: `gcc-multilib` and `g++-multilib` (32-bit HALs),
`zlib1g-dev`, `libssl-dev`, `libelf-dev`, `libdw-dev`, `git-lfs`, `python-is-python3`.

## Risks, stated so they are not misread later

1. **An OOM kill is the host, not the port.** With ~9 GB available against a 16 GB spec, ninja can be
   OOM-killed during linking or dexing. That surfaces as `Killed`, `out of memory`, or
   `cgroup memory limit reached` — which looks exactly like a build error. **P6 must not "fix" it.** Free
   disk, add swap or RAM, and rerun. `confidence: medium` — it may well not happen; 15 GB of swap may absorb it.
2. **Disk is ~22 GB below spec.** Sync (~150 GB) plus `out/` (~40 GB) should fit in 272 GB with headroom, but
   a failed build's intermediate output is the first thing to consume it. Watch it during the build.
3. **`repo sync` may need to be rerun.** It resumes. The spec allows 3 attempts, then stop and log.

## Still to do (the B1 agent)

- Steps 3–5: confirm `kernel/samsung/sdm670` is `801f3f20e54a` and `device/samsung/gts4lv-common` is
  `e3ccc923bcf2`, then `source build/envsetup.sh && brunch gts4lvwifi 2>&1 | tee ~/work/rom-build.log`.
- Record the zip's path, size and sha256. **B1 fixes nothing itself** — a failure hands over to P6.
---

## Result: BLOCKED — the host cannot build this ROM

`brunch gts4lvwifi` **failed twice**, both times killed during Soong's glob phase. No code was reached, so this is
**not** a port defect and **not** P6's work. `confidence: high` — systemd and the kernel both say so directly.

### The evidence

```
rombuild.service: A process of this unit has been killed by the OOM killer.
rombuild.service: Failed with result 'oom-kill'.
rombuild.service: Consumed 21min 24.848s CPU time, 14.2G memory peak, 13.6G memory swap peak.
```

And the build system warned before starting:

> You are building on a machine with **15.4GB of RAM**. The minimum required amount of free memory is around
> **16GB**, and even with that, some configurations may not work. If you run into segfaults or other errors, try
> reducing your `-j` value.

Measured: `soong_build` reached **13.6 GB RSS** during `Running globs...`, with 0 GB RAM available and 8 GB of swap
consumed. Total demand was ~14.2 GB RAM plus ~13.6 GB swap against 15 GB RAM plus 15 GB swap shared with the desktop.
The kernel OOM-killed it. **`-j` does not help**: globbing happens before ninja starts, and it is single-process.

### Two separate faults, both mine

1. **The first attempt was not detached properly.** `setsid` escapes the session ID but **not the systemd cgroup**.
   The build was still inside `app-org.kde.konsole@...service`, so when the OS killed the terminal session for low
   memory the build died with it. Its cgroup was visible in `ps` and I did not act on it.
   **Fix:** run under `systemd-run --user`, which gives the job its own unit and cgroup.
2. **The second attempt was correctly isolated and still OOM'd** — in `rombuild.service`, `MemoryMax=infinity`,
   peak 14.2 GB. So fault 1 was real but was not the only problem.

### Also fixed: the wrapper masked the failure

The script captured `brunch`'s status into `$st` but then ran more `echo`s, so the unit exited **0** and systemd
reported `Result=success` for a build that had failed. A unit wrapper must `exit $st`. Anyone scripting a build
should not trust that unit status — read the log.

### What is needed to proceed

| option | effect |
|---|---|
| **Add swap** (needs the owner's `sudo`) | 32 GB extra would roughly double paging headroom. Uncertain: demand was ~28 GB and still failed |
| **Add RAM** | 32 GB total would be comfortable. This is the reliable fix |
| **Build on another machine** | The tree is portable; `~/android/lineage` is a normal `repo` checkout |
| Free disk | **Not the blocker** — 96 GB free held steady through both attempts |

Reducing `-j` will not fix this. Adding swap might, but RAM is the honest answer: Android's own build system
declares 15.4 GB insufficient before it starts.
