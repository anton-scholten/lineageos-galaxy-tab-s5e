#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
task K1 | agent: Space Bunny Free (space-bunny-free) | date: 2026-10-03
K1: upstream-origin map for the ExyHyperBrick eBPF series.

For every commit of the series BASE..HEAD (2599 commits) this script records:
  exy_commit     12-char SHA of the series commit
  subject        its subject line, verbatim
  upstream_sha   12-char SHA of the mainline/android-common commit it copies,
                 or "-" if the message carries no upstream trailer
  sdm670_has     yes / no / unknown
  sdm670_commit  12-char SHA of the matching sdm670 commit, or "-"

HOW TO RUN
    python3 make_map.py /home/anton/work/k670
    python3 make_map.py /path/to/k670 --out analysis/upstream-map/upstream-map.tsv

The kernel path is argument 1. Optional flags:
    --base   series base   (default d54533f1546b91f94eb4e445dfea3a94ffa58a74)
    --head   series head   (default baa585f67e0efc9f1efa046d0b0e76955ca4c8d5)
    --sdm    sdm670 tip    (default a30605a54f3b92627d868f169c72ef9c6ef82123)
    --out    output TSV    (default <this script's dir>/upstream-map.tsv)

READ-ONLY: the only git subcommand used is `git log`. The script never writes
to, checks out, fetches or otherwise mutates the kernel repository.

Upstream-SHA recognition (case-insensitive, first match in message order wins).
  Accepted:  "commit <sha> upstream", "[ Upstream commit <sha> ]",
             "Upstream commit(s) <sha>", "(cherry picked from commit <sha>)",
             "Upstream-commit: <sha>", "Git-commit: <sha>"
  Rejected on purpose (all three are common in this series and would otherwise
  produce wrong answers -- see analysis/upstream-map/README.md):
    * "Change-Id: I<hex>"      -- a Gerrit ID, not a SHA
    * "Fixes: <sha>"           -- points at the *fixed* commit, not the origin
    * lore/lkml "Link: .../<hex>", crash-dump register values and prose
      mentions like "depends on ... introduced in commit <sha>" -- not origins

Python 3.8+, standard library only.
"""

import argparse
import os
import re
import subprocess
import sys

DEFAULT_BASE = "d54533f1546b91f94eb4e445dfea3a94ffa58a74"
DEFAULT_HEAD = "baa585f67e0efc9f1efa046d0b0e76955ca4c8d5"
DEFAULT_SDM = "a30605a54f3b92627d868f169c72ef9c6ef82123"
EXPECTED_SERIES = 2599

# Only these leading prefixes are stripped before comparing subjects. Subsystem
# prefixes such as "ARM:" or "staging:" are part of the subject and are kept.
SUBJECT_PREFIXES = (b"BACKPORT:", b"UPSTREAM:", b"FROMLIST:", b"ANDROID:")

SHA_RE = re.compile(rb"\b[0-9a-f]{12,40}\b")

# Contexts that really do name the commit this series commit copies.
UPSTREAM_RE = re.compile(
    rb"cherry\ picked\ from\ commit\s+([0-9a-f]{12,40})(?![0-9a-f])"
    rb"|upstream\ commits?\s+([0-9a-f]{12,40})(?![0-9a-f])"
    rb"|upstream-commit:\s*([0-9a-f]{12,40})(?![0-9a-f])"
    rb"|git-commit:\s*([0-9a-f]{12,40})(?![0-9a-f])"
    rb"|commit\s+([0-9a-f]{12,40})\s+upstream\b",
    re.IGNORECASE,
)

# Record/field separators: 0x1e and 0x1f cannot occur in a git commit message.
REC_SEP = b"\x1e"
FLD_SEP = b"\x1f"
LOG_FORMAT = "%x1e%H%x1f%s%x1f%b"


def git_log_stream(repo, *args):
    """Yield raw records from `git log` without buffering the whole output."""
    cmd = ["git", "-C", repo, "log", "--format=" + LOG_FORMAT] + list(args)
    proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    buf = b""
    try:
        while True:
            chunk = proc.stdout.read(1 << 22)
            if not chunk:
                break
            buf += chunk
            parts = buf.split(REC_SEP)
            buf = parts.pop()  # trailing partial record, keep for next round
            for part in parts:
                if part.strip():
                    yield part
        if buf.strip():
            yield buf
    finally:
        proc.stdout.close()
        err = proc.stderr.read()
        proc.stderr.close()
        rc = proc.wait()
        if rc != 0:
            raise RuntimeError("git log failed (%d): %s" % (rc, err.decode("utf-8", "replace")))


def split_record(rec):
    parts = rec.split(FLD_SEP, 2)
    sha = parts[0].strip()
    subject = parts[1] if len(parts) > 1 else b""
    body = parts[2] if len(parts) > 2 else b""
    return sha, subject, body


def strip_prefix(subject):
    """Strip repeated BACKPORT:/UPSTREAM:/FROMLIST:/ANDROID: prefixes (bytes)."""
    s = subject.strip()
    changed = True
    while changed:
        changed = False
        for p in SUBJECT_PREFIXES:
            if s.upper().startswith(p) and len(s) > len(p) and s[len(p):len(p) + 1] in (b" ", b"\t"):
                s = s[len(p):].strip()
                changed = True
                break
    return s


def upstream_sha_of(body):
    """Return the 12-char upstream SHA named by this message, or None."""
    m = UPSTREAM_RE.search(body)
    if not m:
        return None
    for group in m.groups():
        if group:
            return group[:12].decode("ascii")
    return None


def tsv_field(text):
    text = text.replace("\r", " ").replace("\n", " ").replace("\t", " ")
    if '"' in text:
        text = '"' + text.replace('"', '""') + '"'
    return text


def main(argv=None):
    ap = argparse.ArgumentParser(description="K1 upstream-origin map")
    ap.add_argument("kernel", help="path to the read-only kernel repo, e.g. /home/anton/work/k670")
    ap.add_argument("--base", default=DEFAULT_BASE)
    ap.add_argument("--head", default=DEFAULT_HEAD)
    ap.add_argument("--sdm", default=DEFAULT_SDM)
    ap.add_argument("--out", default=None)
    args = ap.parse_args(argv)

    repo = os.path.abspath(args.kernel)
    if not os.path.isdir(os.path.join(repo, ".git")) and not os.path.isfile(os.path.join(repo, ".git")):
        sys.exit("K1: %s is not a git repository" % repo)
    out_path = args.out or os.path.join(os.path.dirname(os.path.abspath(__file__)), "upstream-map.tsv")

    # ---- pass 1: the series ------------------------------------------------
    series = []          # (exy_sha12, subject str, stripped subject str, upstream sha12 or None)
    want_sha = set()     # upstream sha12                             (filled during the sdm670 scan)
    want_subj = set()    # stripped subject                           (filled during the sdm670 scan)
    for rec in git_log_stream(repo, "--reverse", "--no-merges", "%s..%s" % (args.base, args.head)):
        sha, subject, body = split_record(rec)
        subj_txt = subject.decode("utf-8", "replace")
        bare = strip_prefix(subject).decode("utf-8", "replace")
        up = upstream_sha_of(body)
        series.append((sha[:12].decode("ascii"), subj_txt, bare, up))
        if up:
            want_sha.add(up)
        want_subj.add(bare)

    if not series:
        sys.exit("K1: series %s..%s is empty -- wrong pins?" % (args.base, args.head))
    if len(series) != EXPECTED_SERIES:
        sys.stderr.write("K1: WARNING: series has %d commits, expected %d\n" % (len(series), EXPECTED_SERIES))

    # ---- pass 2: one streaming scan of the sdm670 history ------------------
    # Every hit is graded, because "the SHA appears somewhere in sdm670.log" is
    # much weaker evidence than "sdm670 has a commit that originated from it":
    #   exact   - the upstream SHA *is* this sdm670 commit's own id
    #   trailer - the SHA sits in an origin trailer of an sdm670 commit message
    #              ([ Upstream commit X ], (cherry picked from commit X), ...)
    #   mention - the SHA only turns up in prose, a "Fixes:" line or a mailing
    #              list URL. NOT evidence that sdm670 carries the change.
    #   subject - the stripped subject matches an sdm670 subject exactly
    RANK = {"mention": 1, "trailer": 2, "exact": 3}
    hit_sha = {}         # upstream sha12 -> (grade, sdm670 sha12)
    hit_subject = {}     # stripped subject -> sdm670 sha12
    pending = set(want_sha)
    n_records = 0
    for rec in git_log_stream(repo, args.sdm):
        n_records += 1
        sha, subject, body = split_record(rec)
        sha12 = sha[:12].decode("ascii")
        here = {}
        for m in SHA_RE.finditer(body):
            key = m.group(0)[:12].decode("ascii")
            if key in pending and RANK["mention"] > RANK.get(here.get(key, ("", ""))[0], 0):
                here[key] = ("exact" if sha.startswith(key.encode("ascii")) else "mention", sha12)
        for m in UPSTREAM_RE.finditer(body):
            grp = next((g for g in m.groups() if g), None)
            if grp is None:
                continue
            key = grp[:12].decode("ascii")
            if key in pending and RANK["trailer"] >= RANK.get(here.get(key, ("", ""))[0], 0):
                here[key] = ("exact" if sha.startswith(key.encode("ascii")) else "trailer", sha12)
        for key, val in here.items():
            if RANK[val[0]] > RANK.get(hit_sha.get(key, ("", ""))[0], 0):
                hit_sha[key] = val
        bare = strip_prefix(subject).decode("utf-8", "replace")
        if bare in want_subj and bare not in hit_subject:
            hit_subject[bare] = sha12
    del pending

    # ---- pass 3: emit ------------------------------------------------------
    # The TSV follows AGENT-TASKS.md K1 step 3 literally: yes when the upstream
    # SHA appears anywhere in sdm670.log, or the stripped subject matches.
    counts = {"yes": 0, "no": 0, "unknown": 0}
    grades = {"exact": 0, "trailer": 0, "mention": 0, "subject": 0}
    weak_rows = []      # rows whose only evidence is a prose/Fixes/link mention
    lines = ["exy_commit\tsubject\tupstream_sha\tsdm670_has\tsdm670_commit"]
    for exy, subj_txt, bare, up in series:
        found = None
        grade = None
        if up and up in hit_sha:
            grade, found = hit_sha[up]
            has = "yes"
        elif bare in hit_subject:
            grade, found = "subject", hit_subject[bare]
            has = "yes"
        elif up:
            has = "no"          # we know the upstream SHA, and sdm670 does not have it
        else:
            has = "unknown"     # no upstream trailer and no subject match: no idea
        counts[has] += 1
        if grade:
            grades[grade] += 1
            if grade == "mention":
                weak_rows.append((exy, up, found, subj_txt))
        lines.append("\t".join([
            exy,
            tsv_field(subj_txt),
            up or "-",
            has,
            found or "-",
        ]))

    with open(out_path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines) + "\n")

    sys.stderr.write(
        "K1: %d series commits, %d sdm670 commits scanned\n"
        "K1: yes=%d (exact %d, trailer %d, mention-only %d, subject %d)  no=%d  unknown=%d\n"
        "K1: strong=yes %d, weak(mention-only)=yes %d\n"
        "K1: wrote %s\n"
        % (len(series), n_records, counts["yes"], grades["exact"], grades["trailer"],
           grades["mention"], grades["subject"], counts["no"], counts["unknown"],
           counts["yes"] - grades["mention"], grades["mention"], out_path)
    )
    if weak_rows:
        sys.stderr.write("K1: mention-only (weak) rows, verify by hand before trusting:\n")
        for exy, up, found, subj_txt in weak_rows:
            sys.stderr.write("K1:   %s  upstream=%s  sdm670=%s  %s\n" % (exy, up, found, subj_txt[:70]))
    return 0


if __name__ == "__main__":
    sys.exit(main())