#!/usr/bin/env python3
# <!-- task: K7 | agent: Space Bunny Free (opencode) | date: 2026-10-03 -->
"""K7: flag and bitfield collisions between the sdm670 tree and the ExyHyperBrick series.

Usage:
    python3 analysis/collisions/find_collisions.py /path/to/kernel/repo [out.tsv]

Reads (read-only, never checks anything out):
    a30605a54f3b...  sdm670 tip            (our fork, branch lineage-23.2)
    d54533f1546b...  series base           (ExyHyperBrick lineage-22.2)
    baa585f67e0e...  series head           (ExyHyperBrick lineage-23.2)

A *collision* is: one header, the merged view (sdm670 file + the series' changes), two
different names that only exist on one side each, with the same numeric value and the same
prefix.  Merging both sides fuses the two flags silently -- no conflict, no compiler error.
Same name with a different value is the separate category VALUE_CHANGED; a struct member or
bitfield whose declared type/width changed is WIDTH_CHANGED / BITFIELD_WIDTH_CHANGED.

Standard library only.  Deterministic: same input, byte-identical output.
"""

import os
import re
import subprocess
import sys
from collections import defaultdict

SDM670 = "a30605a54f3b92627d868f169c72ef9c6ef82123"
SERIES_BASE = "d54533f1546b91f94eb4e445dfea3a94ffa58a74"
SERIES_HEAD = "baa585f67e0efc9f1efa046d0b0e76955ca4c8d5"

DEFCONFIGS = [
    "arch/arm64/configs/gts4lv_defconfig",
    "arch/arm64/configs/gts4lvwifi_defconfig",
    "arch/arm64/configs/gts4lv_eur_open_defconfig",
    "arch/arm64/configs/gts4lvwifi_eur_open_defconfig",
]
DEFCONFIG_LABEL = {
    "arch/arm64/configs/gts4lv_defconfig": "gts4lv",
    "arch/arm64/configs/gts4lvwifi_defconfig": "gts4lvwifi",
    "arch/arm64/configs/gts4lv_eur_open_defconfig": "gts4lv_eur_open",
    "arch/arm64/configs/gts4lvwifi_eur_open_defconfig": "gts4lvwifi_eur_open",
}

# ---------------------------------------------------------------------------
# git plumbing (read-only)
# ---------------------------------------------------------------------------


def git(repo, *args):
    """Run a read-only git command; return stdout as text."""
    cmd = ["git", "-C", repo] + list(args)
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode != 0:
        raise RuntimeError("%s failed: %s" % (" ".join(cmd), p.stderr.decode("utf-8", "replace")))
    return p.stdout.decode("utf-8", "replace")


class CatBatch(object):
    """Persistent `git cat-file --batch`, for reading many blobs fast."""

    def __init__(self, repo):
        self.p = subprocess.Popen(
            ["git", "-C", repo, "cat-file", "--batch"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
        )

    def read(self, spec):
        self.p.stdin.write((spec + "\n").encode("utf-8"))
        self.p.stdin.flush()
        head = self.p.stdout.readline().decode("utf-8", "replace").strip()
        if head.endswith(" missing") or " missing" in head:
            return None
        parts = head.split(" ")
        if len(parts) < 3:
            raise RuntimeError("unexpected cat-file header: %r" % head)
        size = int(parts[2])
        data = b""
        while len(data) < size:
            chunk = self.p.stdout.read(size - len(data))
            if not chunk:
                break
            data += chunk
        self.p.stdout.read(1)  # trailing newline
        return data.decode("utf-8", "replace")

    def close(self):
        try:
            self.p.stdin.close()
            self.p.wait()
        except Exception:
            pass


# ---------------------------------------------------------------------------
# value parsing
# ---------------------------------------------------------------------------

SUFFIX = r"(?:[uUlL]|ULL|LLU|ull|llu)*"


def strip_parens(s):
    s = s.strip()
    while len(s) >= 2 and s[0] == "(" and s[-1] == ")":
        depth = 0
        ok = True
        for ch in s[1:-1]:
            if ch == "(":
                depth += 1
            elif ch == ")":
                depth -= 1
                if depth < 0:
                    ok = False
                    break
        if not ok or depth != 0:
            break
        s = s[1:-1].strip()
    return s


def parse_int(expr):
    """Integer value of a #define / enum RHS, or None if it is not a plain constant."""
    e = strip_parens(expr)
    if not e:
        return None
    m = re.fullmatch(r"0[xX]([0-9a-fA-F]+)" + SUFFIX, e)
    if m:
        return int(m.group(1), 16)
    m = re.fullmatch(r"0[bB]([01]+)" + SUFFIX, e)
    if m:
        return int(m.group(1), 2)
    m = re.fullmatch(r"(\d+)" + SUFFIX, e)
    if m:
        return int(m.group(1))
    m = re.fullmatch(r"BIT\(\s*(\d+)\s*\)", e)
    if m:
        return 1 << int(m.group(1))
    m = re.fullmatch(r"(?:1|0[xX]1|0X1)" + SUFFIX + r"\s*<<\s*(\d+)", e)
    if m:
        return 1 << int(m.group(1))
    return None


def is_pow2(v):
    return v > 0 and (v & (v - 1)) == 0


# ---------------------------------------------------------------------------
# #if / #ifdef guard tracking
# ---------------------------------------------------------------------------

IDENT_RE = re.compile(r"[A-Za-z_]\w*")


def analyse_if(expr):
    """-> (required, excluded, complex_syms) for a #if condition."""
    required = set()
    excluded = set()
    complex_syms = set()
    e = expr.strip()
    if "||" in e:
        complex_syms |= set(IDENT_RE.findall(e))
    e2 = re.sub(r"!\s*defined\s*\(\s*[A-Za-z_]\w*\s*\)", " ", e)
    e3 = re.sub(r"defined\s*\(\s*[A-Za-z_]\w*\s*\)", " ", e2)
    for m in re.finditer(r"!\s*defined\s*\(\s*([A-Za-z_]\w*)\s*\)", e):
        excluded.add(m.group(1))
    for m in re.finditer(r"defined\s*\(\s*([A-Za-z_]\w*)\s*\)", e2):
        required.add(m.group(1))
    rest = e3
    for m in re.finditer(r"!\s*([A-Za-z_]\w*)", rest):
        if m.group(1) not in ("defined",):
            excluded.add(m.group(1))
    rest = re.sub(r"!\s*[A-Za-z_]\w*", " ", rest)
    if re.fullmatch(r"[\s&|()]*", rest) is None:
        complex_syms |= set(IDENT_RE.findall(e))
    for m in re.finditer(r"\b([A-Za-z_]\w*)\b", rest):
        tok = m.group(1)
        if tok in ("defined",):
            continue
        required.add(tok)
    required -= excluded
    complex_syms -= excluded
    return required, excluded, complex_syms


# ---------------------------------------------------------------------------
# header scanning
# ---------------------------------------------------------------------------


class Rec(object):
    __slots__ = ("kind", "name", "value", "explicit", "line", "typ", "size", "scope",
                 "req", "exc", "cx", "els")

    def __init__(self, kind, name, value, explicit, line, typ="", req=frozenset(),
                 exc=frozenset(), cx=frozenset(), size="", scope="", els=()):
        self.kind = kind
        self.name = name
        self.value = value
        self.explicit = explicit
        self.line = line
        self.typ = typ
        self.size = size
        self.scope = scope
        self.req = req
        self.exc = exc
        self.cx = cx
        self.els = tuple(els)


BLOCK_OPEN = re.compile(r"\b(enum|struct|union)\b([^{;()]*)\{")


def blank_comments(text):
    """Replace comment bodies with spaces, keeping every other offset identical.

    Needed before block scanning: kernel doc comments say things like "for struct sock and
    struct inet_timewait_sock", and without this the regex starts matching inside a comment.
    """
    out = list(text)
    i = 0
    n = len(text)
    while i < n:
        if text.startswith("/*", i):
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            for k in range(i, j):
                if out[k] != "\n":
                    out[k] = " "
            i = j
            continue
        if text.startswith("//", i):
            j = text.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j):
                out[k] = " "
            i = j
            continue
        i += 1
    return "".join(out)


def logical_lines(text):
    """(start_line, joined_text) with backslash continuations folded in."""
    out = []
    buf = ""
    start = 0
    for i, line in enumerate(text.split("\n"), 1):
        if not buf:
            start = i
        s = line.rstrip("\r")
        if s.endswith("\\"):
            buf += s[:-1] + " "
        else:
            buf += s
            out.append((start, buf))
            buf = ""
    if buf:
        out.append((start, buf))
    return out


def join_lines(text):
    """Join logical lines, keeping a lookup from joined offset to original line number.

    Returns (joined_text, [(start_offset, original_line_number)]).
    """
    parts = logical_lines(text)
    joined = "\n".join(t for _, t in parts)
    offs = []
    pos = 0
    for ln, txt in parts:
        offs.append((pos, ln))
        pos += len(txt) + 1
    return joined, offs


def line_at(offs, offset):
    """Original line number for an offset in `joined` (binary search)."""
    lo, hi, res = 0, len(offs) - 1, 1
    while lo <= hi:
        mid = (lo + hi) // 2
        if offs[mid][0] <= offset:
            res = offs[mid][1]
            lo = mid + 1
        else:
            hi = mid - 1
    return res


def block_spans(text):
    """[(kind, name, body_start, body_end)] for every enum/struct/union block, in order.

    Comments are blanked first: kernel doc comments mention types by name ("for struct sock
    and struct inet_timewait_sock"), and without this the regex starts matching inside one.
    Offsets are into the comment-blanked joined text, which `blank_comments` keeps
    length-identical to the original.
    """
    joined = blank_comments(join_lines(text)[0])
    out = []
    for m in BLOCK_OPEN.finditer(joined):
        depth = 0
        i = m.end() - 1
        while i < len(joined):
            if joined[i] == "{":
                depth += 1
            elif joined[i] == "}":
                depth -= 1
                if depth == 0:
                    break
            i += 1
        if i >= len(joined):
            continue
        namem = re.match(r"\s*([A-Za-z_]\w*)", m.group(2))
        name = namem.group(1) if namem else ""
        out.append((m.group(1), name, m.end(), i))
    return out


def label_blocks(spans):
    """Give every block a unique scope name; anonymous blocks get a path-qualified id.

    Two different anonymous structs are not the same type, so `anon#3` alone is not enough:
    the number of preceding anonymous blocks differs between the two trees.  Counting only
    the anonymous siblings *inside the same parent* is stable when a struct is added or
    removed earlier in the file.
    """
    counts = defaultdict(int)
    labelled = []
    for idx, (kind, name, s, e) in enumerate(spans):
        # innermost enclosing block
        parent = None
        for j, (_k, _n, ps, pe) in enumerate(spans):
            if j != idx and ps < s and e < pe:
                if parent is None or (ps > spans[parent][2]):
                    parent = j
        if name:
            scope = name
        else:
            key = parent if parent is not None else -1
            scope = "%s/anon%d" % (
                labelled[parent][3] if parent is not None else "top",
                counts[key])
            counts[key] += 1
        labelled.append((kind, name, s, e, scope))
    return labelled


def find_blocks(text, keyword, anon_counter=None):
    """Yield (kind, name, body, body_start_offset, offs, scope) for matching blocks."""
    joined, offs = join_lines(text)
    for kind, name, s, e, scope in label_blocks(block_spans(text)):
        if kind != keyword:
            continue
        yield kind, name, joined[s:e], s, offs, scope


def strip_comment(s):
    i = s.find("/*")
    if i >= 0:
        s = s[:i]
    i = s.find("//")
    if i >= 0:
        s = s[:i]
    return s


def split_top_off(text, sep):
    """Split on `sep` at brace/paren depth 0, keeping each chunk's start offset."""
    out = []
    depth = 0
    start = 0
    for i, ch in enumerate(text):
        if ch in "{([":
            depth += 1
        elif ch in "})]":
            depth -= 1
        if ch == sep and depth == 0:
            out.append((text[start:i], start))
            start = i + 1
    out.append((text[start:], start))
    return out


def split_top(text, sep):
    return [c for c, _ in split_top_off(text, sep)]


_TYPE_HEAD = re.compile(
    r"^(?:const\s+|volatile\s+|struct\s+|union\s+|enum\s+)*"
    r"(?:unsigned\s+|signed\s+)?"
    r"(?:long\s+long|short|long|int|char|_Bool|bool|"
    r"__u8|__s8|__u16|__s16|__u32|__s32|__u64|__s64|"
    r"u8|s8|u16|s16|u32|s32|u64|s64|uint\d+_t|int\d+_t|"
    r"[A-Za-z_]\w*)\s*[*]*\s*$")


def expand_declarators(stmt):
    """Split one C declaration statement into individual declarators.

    Handles `u32 a : 3, b : 5;` and `u32 a, b;`, where only the first declarator names the
    type.  Anything it cannot understand is returned unchanged.
    """
    parts = [p.strip() for p in split_top(stmt, ",")]
    if len(parts) == 1:
        return [stmt]
    first = parts[0]
    if ":" in first:
        # bitfield list: only the first declarator carries the type
        base = first.split(":")[0].strip()
        base = re.sub(r"[A-Za-z_]\w*$", "", base).strip()
        out = []
        for p in parts:
            if p.startswith(base + " ") or not base:
                out.append(p)
            else:
                out.append((base + " " + p).strip())
        return out
    # plain list: only valid if the first part is "<type> <name>" and the rest are names
    m = re.match(r"^(.*?[\s*])([A-Za-z_]\w*)$", first)
    if not m or not _TYPE_HEAD.match(first):
        return [stmt]
    out = [first]
    for p in parts[1:]:
        if not re.fullmatch(r"\*?[A-Za-z_]\w*(\s*\[[^\]]*\])?", p):
            return [stmt]
        out.append(m.group(1) + p)
    return out


def scan_header(text):
    """-> (records, raw_defines) for one header."""
    records = []
    raw = {}
    lines = logical_lines(text)
    for kind, name, body, boff, offs, scope in find_blocks(text, "enum"):
        body = blank_comments(body)
        nxt = 0
        for chunk, coff in split_top_off(body, ","):
            c = strip_comment(chunk).strip()
            c = re.sub(r"__attribute__\s*\(\(.*?\)\)", " ", c).strip()
            if not c:
                continue
            mm = re.match(r"^([A-Za-z_]\w*)\s*(?:=\s*(.*))?$", c, re.S)
            if not mm:
                continue
            ename = mm.group(1)
            rhs = mm.group(2)
            if rhs is None:
                val = nxt
                expl = False
                nxt = val + 1
            else:
                val = parse_int(rhs)
                if val is None:
                    continue
                expl = True
                nxt = val + 1
            lead = len(chunk) - len(chunk.lstrip())
            records.append(Rec("enum@%s" % scope, ename, val, expl,
                               line_at(offs, boff + coff + lead), scope=scope))
    for kind, name, body, boff, offs, scope in find_blocks(text, "struct"):
        # Preprocessor lines carry no ';' and would glue onto the next declaration.
        # `randomized_struct_fields_start` is a bare marker macro with no ';' either.
        body = re.sub(r"^[ \t]*randomized_struct_fields_(?:start|end)[ \t]*$", "", body,
                      flags=re.M)
        # Blank preprocessor lines instead of deleting them: a directive has no ';' of its
        # own and would glue onto the next declaration, but deleting the line would shift
        # every offset after it and make the reported line numbers wrong.
        body = re.sub(r"^[^\n]*#[^\n]*$", lambda m: " " * len(m.group(0)), body,
                      flags=re.M)
        # Comments may contain ';' or ',', so remove them before splitting.
        body = blank_comments(body)
        for chunk, coff in split_top_off(body, ";"):
            c = re.sub(r"__attribute__\s*\(\(.*?\)\)", " ", chunk).strip()
            c = re.sub(r"\b__packed\b|\b__force\b|\b__iomem\b|\b____cacheline_aligned\b", " ", c)
            c = re.sub(r"\b__aligned\s*\([^)]*\)", " ", c)
            c = re.sub(r"\s+", " ", c).strip()
            if not c or "(" in c or "{" in c or "}" in c:
                continue
            # `u32 a : 3, b : 5;` and `u32 a, b;` declare more than one member
            for d in expand_declarators(c):
                bf = re.match(r"^(?:(.*?[\s*])?\s*)?([A-Za-z_]\w*)\s*:\s*(\d+)$", d)
                # skip the whitespace/newlines a chunk starts with, so the reported line is
                # the line the declaration is actually written on
                lead = len(chunk) - len(chunk.lstrip())
                ln = line_at(offs, boff + coff + lead)
                if bf:
                    records.append(Rec("bf@%s" % scope, bf.group(2),
                                       int(bf.group(3)), True, ln,
                                       (bf.group(1) or "").strip(), scope=scope))
                    continue
                arr = re.match(r"^(.*?[\s*])([A-Za-z_]\w*)\s*(\[[^\]]*\])?$", d)
                if arr:
                    rec = Rec("field@%s" % scope, arr.group(2), None,
                              True, ln, arr.group(1).strip(), scope=scope)
                    rec.size = (arr.group(3) or "").strip()
                    records.append(rec)
                    continue
                pl = re.match(r"^(.*?[\s*])([A-Za-z_]\w*)$", d)
                if pl:
                    rec = Rec("field@%s" % scope, pl.group(2), None,
                              True, ln, pl.group(1).strip(), scope=scope)
                    rec.size = ""
                    records.append(rec)
    gm = guard_map(text)
    zero = (frozenset(), frozenset(), frozenset(), ())
    # enum/struct members: give each one the guard covering its own line
    for r in records:
        r.req, r.exc, r.cx, r.els = gm.get(r.line, zero)
    # #defines, taking the guard that covers each line
    for ln, line in lines:
        s = line.strip()
        m = re.match(r"#\s*define\s+([A-Za-z_]\w*)(\()?", s)
        if not m:
            continue
        name = m.group(1)
        if m.group(2):  # function-like macro: no numeric value
            continue
        val_txt = strip_comment(s[m.end():]).strip()
        raw[name] = val_txt
        val = parse_int(val_txt)
        if val is None:
            continue
        req, exc, cx, els = gm.get(ln, zero)
        records.append(Rec("define", name, val, True, ln, "", req, exc, cx, els=els))
    return records, raw


def guard_map(text):
    """line number -> (required, excluded, complex, else-flags) in effect at that line."""
    out = {}
    stack = []
    cur = (frozenset(), frozenset(), frozenset(), ())
    for ln, line in logical_lines(text):
        s = line.strip()
        if s.startswith("#"):
            m = re.match(r"#\s*ifdef\s+([A-Za-z_]\w*)", s)
            if m:
                stack.append({"req": {m.group(1)}, "exc": set(), "cx": set(), "els": False})
                cur = fold(stack)
                continue
            m = re.match(r"#\s*ifndef\s+([A-Za-z_]\w*)", s)
            if m:
                stack.append({"req": set(), "exc": {m.group(1)}, "cx": set(), "els": False})
                cur = fold(stack)
                continue
            m = re.match(r"#\s*if\s+(.*)$", s)
            if m:
                req, exc, cx = analyse_if(m.group(1))
                stack.append({"req": req, "exc": exc, "cx": cx, "els": False})
                cur = fold(stack)
                continue
            m = re.match(r"#\s*elif\b\s*(.*)$", s)
            if m and stack:
                req, exc, cx = analyse_if(m.group(1))
                lv = stack[-1]
                lv["cx"] |= cx | lv["req"] | lv["exc"]
                lv["req"], lv["exc"] = set(), set()
                cur = fold(stack)
                continue
            if re.match(r"#\s*else\b", s) and stack:
                stack[-1]["els"] = True
                cur = fold(stack)
                continue
            if re.match(r"#\s*endif\b", s):
                if stack:
                    stack.pop()
                cur = fold(stack)
                continue
        out[ln] = cur
    return out


def fold(stack):
    req, exc, cx, els = set(), set(), set(), []
    for lv in stack:
        if lv["els"]:
            req |= lv["exc"]
            exc |= lv["req"]
            els.append("1")
        else:
            req |= lv["req"]
            exc |= lv["exc"]
            els.append("0")
        cx |= lv["cx"]
    return frozenset(req), frozenset(exc), frozenset(cx), tuple(els)




def is_include_guard(sym, path):
    """True for the `#ifndef _LINUX_FOO_H / #define _LINUX_FOO_H` boilerplate.

    Those guards are satisfied by definition, so counting them as a config dependency would
    make every record in the header look conditional.
    """
    base = os.path.basename(path)
    stem = re.sub(r"[.-]", "_", os.path.splitext(base)[0]).upper()
    return sym.startswith("_") and (stem in sym or
                                    sym == "_%s_H" % stem or
                                    sym.startswith("_UAPI_" + stem))


def live_verdict(rec, cfg, explicit, path):
    """LIVE / OFF / UNKNOWN for one record under one defconfig.

    Only CONFIG_*-style guards count: a plain `#ifdef __KERNEL__` is not a config question,
    and neither is the file's own include guard.
    """
    if rec.cx:
        syms = [s for s in sorted(rec.cx) if s.startswith("CONFIG_")]
        if len(syms) == len(rec.cx):
            return "OFF(cond %s)" % ",".join(syms[:3])
        return "UNKNOWN(%s)" % ",".join(sorted(rec.cx)[:3])
    bad = None
    for s in sorted(rec.req):
        if not s.startswith("CONFIG_") or is_include_guard(s, path):
            continue
        v = cfg.value(s, explicit)
        if v != "y":
            bad = "OFF(needs %s=%s)" % (s, v)
            break
    if bad:
        return bad
    for s in sorted(rec.exc):
        if not s.startswith("CONFIG_") or is_include_guard(s, path):
            continue
        v = cfg.value(s, explicit)
        if v != "n":
            return "OFF(needs %s off, is %s)" % (s, v)
    req = [s for s in sorted(rec.req) if s.startswith("CONFIG_")
           and not is_include_guard(s, path)]
    if req:
        return "LIVE(needs %s)" % ",".join(req)
    return "LIVE"


# ---------------------------------------------------------------------------
# Kconfig / defconfig resolution
# ---------------------------------------------------------------------------


class Config(object):
    """Kconfig symbol table plus a per-defconfig `y`/`m`/`n` resolver.

    A defconfig grep is not enough.  LEAD-SYNTHESIS 6.3 records an agent concluding a file
    was not compiled because the symbol was absent from the defconfig, when a Kconfig
    `select` turned it on.  So this follows `select`, `default` and `default ... if`.
    """

    def __init__(self, repo, rev):
        self.rev = rev
        self.defaults = {}   # sym -> [(lit, cond_syms)]
        self.selectors = defaultdict(list)  # sym -> [selecting symbol]
        files = sorted(
            f for f in git(repo, "ls-tree", "-r", "--name-only", rev).split("\n")
            if os.path.basename(f) == "Kconfig")
        batch = CatBatch(repo)
        for f in files:
            txt = batch.read("%s:%s" % (rev, f))
            if txt is None:
                continue
            cur = None
            for _ln, line in logical_lines(txt):
                s = strip_comment(line).strip()
                m = re.match(r"(?:menu)?config\s+([A-Za-z_]\w*)", s)
                if m:
                    cur = m.group(1)
                    self.defaults.setdefault(cur, [])
                    continue
                if cur is None:
                    continue
                m = re.match(r"select\s+([A-Za-z_]\w*)", s)
                if m:
                    self.selectors[m.group(1)].append(cur)
                    continue
                m = re.match(r"default\s+(.*)$", s)
                if m:
                    body = m.group(1)
                    mi = re.search(r"\bif\b(.*)$", body)
                    cond = set()
                    if mi:
                        cond = set(IDENT_RE.findall(mi.group(1)))
                        body = body[:mi.start()]
                    body = body.strip()
                    if body in ("y", "m", "n"):
                        self.defaults[cur].append((body, frozenset(cond)))
        batch.close()
        self.cache = {}

    def parse_defconfig(self, repo, path):
        """`CONFIG_FOO=y` / `=m` / `# CONFIG_FOO is not set` -> {FOO: 'y'|'m'|'n'}."""
        explicit = {}
        txt = git(repo, "show", "%s:%s" % (self.rev, path))
        for line in txt.split("\n"):
            line = line.strip()
            m = re.match(r"^CONFIG_([A-Za-z_]\w*)=(.+)$", line)
            if m:
                v = m.group(2).strip().strip('"')
                explicit[m.group(1)] = v if v in ("y", "m", "n") else "y"
                continue
            m = re.match(r"^# CONFIG_([A-Za-z_]\w*) is not set$", line)
            if m:
                explicit[m.group(1)] = "n"
        return explicit

    def value(self, sym, explicit):
        """Resolve a symbol given either as `FOO` or as `CONFIG_FOO`."""
        if sym.startswith("CONFIG_"):
            sym = sym[len("CONFIG_"):]
        return self.resolve(sym, explicit)

    def resolve(self, sym, explicit, seen=None):
        if sym in explicit:
            return explicit[sym]
        if sym in self.cache:
            return self.cache[sym]
        if seen is None:
            seen = set()
        if sym in seen:
            return "n"
        seen = seen | {sym}
        self.cache[sym] = "n"  # cycle guard
        if sym not in self.defaults:
            out = "n"
        else:
            out = None
            for sel in self.selectors.get(sym, []):
                v = self.resolve(sel, explicit, seen)
                if v in ("y", "m"):
                    out = v
                    break
            if out is None:
                for lit, cond in self.defaults[sym]:
                    if cond and any(self.resolve(c, explicit, seen) != "y"
                                    for c in sorted(cond)):
                        continue
                    if lit in ("y", "m", "n"):
                        out = lit
                        break
            if out is None:
                out = "n"
        self.cache[sym] = out
        return out


# ---------------------------------------------------------------------------
# type normalisation: which declared types are the same width
# ---------------------------------------------------------------------------

# Multi-word integer spellings, longest first so "unsigned short" wins over "unsigned".
_TYPE_MAP = [
    # token sequence -> canonical size class
    (("unsigned", "long", "long", "int"), "u64"),
    (("unsigned", "long", "long"), "u64"),
    (("long", "long", "unsigned", "int"), "u64"),
    (("unsigned", "long", "int"), "u64"),
    (("unsigned", "long"), "u64"),
    (("long", "long", "int"), "s64"),
    (("long", "long"), "s64"),
    (("long", "int"), "s64"),
    (("unsigned", "long", "long", "unsigned", "int"), "u64"),
    (("long",), "s64"),
    (("unsigned", "short", "int"), "u16"),
    (("unsigned", "short"), "u16"),
    (("short", "unsigned", "int"), "u16"),
    (("short", "int"), "s16"),
    (("short",), "s16"),
    (("signed", "int"), "s32"),
    (("signed",), "s32"),
    (("unsigned", "int"), "u32"),
    (("unsigned",), "u32"),
    (("int",), "s32"),
    (("unsigned", "char"), "u8"),
    (("signed", "char"), "s8"),
    (("char",), "s8"),
    (("signed", "char"), "s8"),
]
_SIMPLE_MAP = {
    "u8": "u8", "__u8": "u8", "__u8_t": "u8", "__be8": "u8", "__le8": "u8", "u_char": "u8",
    "s8": "s8", "__s8": "s8", "__s8_t": "s8",
    "u16": "u16", "__u16": "u16", "__u16_t": "u16", "__le16": "u16", "__be16": "u16",
    "__sum16": "u16", "u_short": "u16", "uint16_t": "u16",
    "s16": "s16", "__s16": "s16", "__s16_t": "s16", "int16_t": "s16",
    "u32": "u32", "__u32": "u32", "__u32_t": "u32", "__le32": "u32", "__be32": "u32",
    "__sum32": "u32", "u_int": "u32", "uint32_t": "u32",
    "s32": "s32", "__s32": "s32", "__s32_t": "s32", "int32_t": "s32",
    "u64": "u64", "__u64": "u64", "__u64_t": "u64", "__le64": "u64", "__be64": "u64",
    "__sum64": "u64", "u_long": "u64", "uint64_t": "u64", "__aligned_u64": "u64",
    "s64": "s64", "__s64": "s64", "__s64_t": "s64", "int64_t": "s64",
    "bool": "bool", "_Bool": "bool", "__bool": "bool", "int8_t": "s8",
    # pointers and opaque objects: width not derivable from the spelling
    "void": "void", "char": "s8",
    "size_t": "size_t", "__size_t": "size_t", "__kernel_size_t": "size_t",
    "ssize_t": "ssize_t", "__kernel_ssize_t": "ssize_t", "ptrdiff_t": "ssize_t",
    "loff_t": "loff_t", "__kernel_long_t": "s64", "__kernel_ulong_t": "u64",
    "phys_addr_t": "u64", "resource_size_t": "u64", "dma_addr_t": "u64",
    "ktime_t": "s64", "__kernel_time64_t": "s64", "gfp_t": "unsigned",
    "pid_t": "s32", "__kernel_pid_t": "s32", "dev_t": "u32", "umode_t": "u16",
    "mode_t": "u16", "sector_t": "u64", "blkcnt_t": "u64", "suseconds_t": "u64",
    "atomic_t": "atomic_t", "atomic64_t": "atomic64_t", "refcount_t": "refcount_t",
}
_WIDTH_RANK = {"bool": 0, "s8": 0, "u8": 0, "void": 0,
               "s16": 1, "u16": 1,
               "s32": 2, "u32": 2, "atomic_t": 2, "unsigned": 2, "s64": 3, "u64": 3,
               "size_t": 3, "ssize_t": 3, "loff_t": 3, "refcount_t": 3, "atomic64_t": 3}


def norm_type(t):
    """Canonical spelling of a declared type, or None when it is a pointer/opaque."""
    if not t:
        return None
    t = t.replace("__percpu", " ").replace("__rcu", " ").replace("__read_mostly", " ")
    t = re.sub(r"\b(const|volatile|register|__init|__exit)\b", " ", t)
    t = t.replace("struct", " ").replace("union", " ")
    t = re.sub(r"\s+", " ", t).strip()
    stars = t.count("*")
    if stars:
        # only pointer-ness matters; the pointee layout is checked separately
        return "ptr" if stars else t
    toks = t.split(" ")
    # `unsigned long int` == `unsigned long`: drop a redundant trailing `int`
    if len(toks) > 1 and toks[-1] == "int":
        toks.pop()
    if not toks:
        return None
    joined = " ".join(toks)
    if joined in _SIMPLE_MAP:
        return _SIMPLE_MAP[joined]
    for seq, cls in _TYPE_MAP:
        if tuple(toks) == seq:
            return cls
    return joined if re.fullmatch(r"[A-Za-z_]\w*", joined) else joined


RUN_WINDOW = 60


def family_runs(records, pfx):
    """Split the pfx-prefixed records into runs of closely-spaced declarations.

    Kernel headers write one flag family as one contiguous block (`TIF_FSCHECK` line 83 next
    to `TIF_UPROBE` line 88).  Two same-value names that are hundreds of lines apart in the
    same file are different families that merely share a text prefix -- `EXT4_IO_ENCRYPTED`
    (an ext4 ioctl flag, line 205) and `EXT4_MOUNT_NO_MBCACHE` (a mount flag, line 1114) can
    both be 0x1 forever without fusing anything.  Runs are what distinguishes a real fused
    bitfield from a coincidental textual match.
    """
    items = sorted((r for r in records if r.name.startswith(pfx) and r.value is not None),
                   key=lambda r: r.line)
    runs = []
    for r in items:
        if runs and r.line - runs[-1][-1].line <= RUN_WINDOW:
            runs[-1].append(r)
        else:
            runs.append([r])
    return runs


def same_run(a, b, runs):
    for run in runs:
        if a in run and b in run:
            return True
    return False


def guard_sig(rec):
    """The #if/#ifdef environment a record sits in, as a comparable string.

    The `els` component matters: two branches of the same `#if/#else` can end up with the
    same req/exc sets (when the condition is complex and unresolvable), and pairing them
    would compare a record against its own alternative.
    """
    return "|req=%s|exc=%s|cx=%s|els=%s" % (
        ",".join(sorted(rec.req)), ",".join(sorted(rec.exc)),
        ",".join(sorted(rec.cx)), ",".join(rec.els))


def prefix_of(a, b):
    """Common prefix of two flag names, cut at the last '_' (e.g. TIF_, FAULT_FLAG_)."""
    i = 0
    n = min(len(a), len(b))
    while i < n and a[i] == b[i]:
        i += 1
    if i == 0:
        return None
    cut = a.rfind("_", 0, i + 1)
    if cut < 0:
        return None
    return a[:cut + 1]


def free_value(used, value, index_style=False):
    """Smallest free slot in the same prefix group, from the merged view of both trees.

    `index_style` families (TIF_NOHZ 7) store a bit *index*; the rest store a mask.
    """
    if index_style:
        cand = 0
        while cand in used:
            cand += 1
        return str(cand)
    if not is_pow2(value):
        cand = value + 1
        while cand in used:
            cand += 1
        return hex(cand)
    bit = 1
    while bit in used:
        bit <<= 1
    return hex(bit)


def main(argv):
    if len(argv) < 2:
        sys.stderr.write("usage: find_collisions.py <kernel-repo> [out.tsv]\n")
        return 2
    repo = os.path.abspath(argv[1])
    out_path = argv[2] if len(argv) > 2 else os.path.join(
        os.path.dirname(os.path.abspath(__file__)), "K7.tsv")
    for rev in (SDM670, SERIES_BASE, SERIES_HEAD):
        git(repo, "rev-parse", "--verify", rev + "^{commit}")

    # ---- 1. headers the series changes, present in both trees
    series_headers = sorted(set(
        f for f in git(repo, "diff", "--name-only", SERIES_BASE, SERIES_HEAD, "--", "*.h").split("\n") if f))
    sdm_files = set(f for f in git(repo, "ls-tree", "-r", "--name-only", SDM670).split("\n") if f)
    head_files = set(f for f in git(repo, "ls-tree", "-r", "--name-only", SERIES_HEAD).split("\n") if f)
    both = [f for f in series_headers if f in sdm_files and f in head_files]
    skipped_absent_sdm = [f for f in series_headers if f not in sdm_files]
    skipped_absent_head = [f for f in series_headers if f in sdm_files and f not in head_files]

    # ---- 2. read and scan
    batch = CatBatch(repo)
    recs = {}
    raws = {}
    for rev, tag in ((SDM670, "sdm"), (SERIES_HEAD, "head")):
        d = {}
        rw = {}
        for f in both:
            txt = batch.read("%s:%s" % (rev, f))
            if txt is None:
                continue
            r, raw = scan_header(txt)
            d[f] = r
            rw[f] = raw
        recs[tag] = d
        raws[tag] = rw
    batch.close()

    # ---- 3. index by name
    def index(tag, f):
        m = {}
        for r in recs[tag][f]:
            m.setdefault(r.name, []).append(r)
        for nm in m:
            m[nm].sort(key=lambda r: (guard_sig(r), r.line))
        return m

    findings = []
    detail = []
    n_bit = n_val = n_changed = n_width = n_bf = 0

    for f in both:
        sdm_recs = recs["sdm"][f]
        head_recs = recs["head"][f]
        sdm_names = set(r.name for r in sdm_recs)
        head_names = set(r.name for r in head_recs)
        sdm_by_name = index("sdm", f)
        head_by_name = index("head", f)
        by_value_sdm = defaultdict(list)
        by_value_head = defaultdict(list)
        for r in sdm_recs:
            if r.value is not None:
                by_value_sdm[r.value].append(r)
        for r in head_recs:
            if r.value is not None:
                by_value_head[r.value].append(r)

        # --- collision: name only on one side, same value, same prefix
        for value in sorted(set(by_value_sdm) & set(by_value_head)):
            if value == 0:
                cand = [(a, b) for a in by_value_sdm[value] for b in by_value_head[value]
                        if a.kind == "define" and b.kind == "define"]
            else:
                cand = [(a, b) for a in by_value_sdm[value] for b in by_value_head[value]]
            for a, b in cand:
                if a.name == b.name:
                    continue
                if a.name in head_names or b.name in sdm_names:
                    continue
                # Both must exist only on their own side *at the same guard*: `#ifdef A`
                # in one tree and `#ifdef B` in the other is two unrelated declarations.
                if guard_sig(a) != guard_sig(b):
                    continue
                # Same namespace only: two #defines, or two members of the *same* enum.
                # bpf.h alone has `BPF_FUNC_*` (enum bpf_func) and `BPF_F_*` (enum bpf_ret)
                # sharing the text prefix `BPF_`; those are separate namespaces, not a clash.
                if a.kind == "define" or b.kind == "define":
                    if not (a.kind == "define" and b.kind == "define"):
                        continue
                elif a.kind != b.kind:
                    continue
                pfx = prefix_of(a.name, b.name)
                if pfx is None:
                    continue
                if a.kind != "define" and a.scope == b.scope:
                    # Both members of the *same* enum.  An inserted member renumbers
                    # everything after it, so the sdm670 name silently changes meaning.
                    fused, cat = True, "ENUM_INSERT_RENUMBER"
                else:
                    runs = family_runs(sdm_recs + head_recs, pfx)
                    fused = same_run(a, b, runs)
                    if fused:
                        cat = "BIT_COLLISION" if is_pow2(value) else "VALUE_COLLISION"
                    else:
                        cat = "TEXT_PREFIX_ONLY"
                findings.append((f, hex(value), a.name, b.name, cat))
                used = set()
                for r in sdm_recs + head_recs:
                    if r.name.startswith(pfx) and r.value is not None:
                        used.add(r.value)
                # `TIF_NOHZ 7` is a *bit index*, not a mask: every value in the family is
                # small and consecutive-ish.  A free slot is then an unused index, not an
                # unused power of two.
                index_style = len(used) > 2 and max(used) <= 64
                if cat == "BIT_COLLISION":
                    n_bit += 1
                elif cat == "VALUE_COLLISION":
                    n_val += 1
                detail.append({
                    "file": f, "value": hex(value), "sdm": a, "head": b, "prefix": pfx,
                    "suggest": free_value(used, value, index_style) if fused else "n/a",
                    "kind": "COLLISION", "fused": fused,
                })

        # --- VALUE_CHANGED: same name, different value
        # A name can legitimately appear twice in one header under different #ifdefs
        # (RWSEM_ACTIVE_MASK is defined for CONFIG_64BIT and again for !CONFIG_64BIT).
        # Compare only records with the same guard signature, so the two branches do not get
        # cross-multiplied into bogus pairs.
        for name in sorted(sdm_names & head_names):
            for a in sdm_by_name[name]:
                for b in head_by_name[name]:
                    if a.kind != "define" or b.kind != "define":
                        continue
                    if guard_sig(a) != guard_sig(b):
                        continue
                    if a.value is None or b.value is None or a.value == b.value:
                        continue
                    if a.value == 0 or b.value == 0:
                        continue
                    findings.append((f, "%s->%s" % (hex(a.value), hex(b.value)), name, name,
                                     "VALUE_CHANGED"))
                    n_changed += 1
                    detail.append({
                        "file": f, "value": "%s->%s" % (hex(a.value), hex(b.value)),
                        "sdm": a, "head": b, "prefix": name.rsplit("_", 1)[0] + "_",
                        "suggest": "keep both? see report", "kind": "VALUE_CHANGED",
                    })

        # --- WIDTH_CHANGED / BITFIELD_WIDTH_CHANGED: same struct member, other type
        sdm_f = {}
        for r in sdm_recs:
            if r.kind.startswith("field@") or r.kind.startswith("bf@"):
                sdm_f.setdefault((r.kind.split("@", 1)[1], r.name), []).append(r)
        head_f = {}
        for r in head_recs:
            if r.kind.startswith("field@") or r.kind.startswith("bf@"):
                head_f.setdefault((r.kind.split("@", 1)[1], r.name), []).append(r)
        for key in sorted(set(sdm_f) & set(head_f)):
            # same guard only, so an #ifdef CONFIG_X member is not matched against an
            # unconditional one with the same name
            pairs = [(x, y) for x in sdm_f[key] for y in head_f[key]
                     if guard_sig(x) == guard_sig(y)]
            for a, b in pairs:
                if not a.name or not a.name[0].isalpha():
                    continue
                if a.kind.startswith("bf@") and b.kind.startswith("bf@"):
                    if a.value == b.value:
                        continue
                    findings.append((f, "%s->%s" % (a.value, b.value), a.name, a.name,
                                     "BITFIELD_WIDTH_CHANGED"))
                    n_bf += 1
                    detail.append({"file": f, "value": "%s->%s" % (a.value, b.value),
                                   "sdm": a, "head": b, "prefix": key[0] + ".",
                                   "suggest": "n/a", "kind": "BITFIELD_WIDTH_CHANGED"})
                    continue
                if a.kind.startswith("bf@") or b.kind.startswith("bf@"):
                    # bitfield on one side, plain member on the other: layout change
                    tb, tf = (a, b) if a.kind.startswith("bf@") else (b, a)
                    findings.append((f, "bitfield:%s->field:%s" % (tb.typ or "?", tf.typ or "?"),
                                     a.name, a.name, "BITFIELD_TO_FIELD"))
                    n_bf += 1
                    detail.append({"file": f,
                                   "value": "bitfield:%s->field:%s" % (tb.typ or "?", tf.typ or "?"),
                                   "sdm": a, "head": b, "prefix": key[0] + ".",
                                   "suggest": "n/a", "kind": "BITFIELD_TO_FIELD"})
                    continue
                if (a.size or "") != (b.size or ""):
                    findings.append((f, "size %s->%s" % (a.size or "", b.size or ""),
                                     a.name, a.name, "ARRAY_SIZE_CHANGED"))
                ta, tb = norm_type(a.typ), norm_type(b.typ)
                if ta is None or tb is None or ta == tb:
                    continue
                findings.append((f, "%s->%s" % (ta, tb), a.name, a.name, "WIDTH_CHANGED"))
                n_width += 1
                detail.append({"file": f, "value": "%s->%s" % (ta, tb),
                               "sdm": a, "head": b, "prefix": key[0] + ".",
                               "suggest": "n/a", "kind": "WIDTH_CHANGED"})

    # ---- 4. write TSV
    def prio(row):
        """Sort key: real collisions first, then real breaks, then cosmetic noise."""
        cat, val = row[4], row[1]
        if cat in ("BIT_COLLISION", "VALUE_COLLISION", "ENUM_INSERT_RENUMBER",
                   "BITFIELD_WIDTH_CHANGED", "BITFIELD_TO_FIELD"):
            return (0, cat, row[0], val, row[2], row[3])
        if cat == "TEXT_PREFIX_ONLY":
            return (2, cat, row[0], val, row[2], row[3])
        if cat == "WIDTH_CHANGED":
            return (1, cat, row[0], val, row[2], row[3])
        if cat == "VALUE_CHANGED":
            return (2, cat, row[0], val, row[2], row[3])
        return (3, cat, row[0], val, row[2], row[3])

    findings.sort(key=prio)
    with open(out_path, "w") as fh:
        fh.write("file\tvalue\tsdm670_name\tseries_name\tcategory\n")
        for row in findings:
            fh.write("\t".join(row) + "\n")

    # ---- 5. config resolution + mask analysis for the report
    cfg_sdm = Config(repo, SDM670)
    cfg_head = Config(repo, SERIES_HEAD)
    explicit = {}
    for dc in DEFCONFIGS:
        explicit[dc] = cfg_sdm.parse_defconfig(repo, dc)

    def mask_refs(tag, f, name):
        out = []
        for other, txt in sorted(raws[tag][f].items()):
            if other == name:
                continue
            if re.search(r"\b%s\b" % re.escape(name), txt) and ("MASK" in other or "|" in txt):
                out.append(other)
        return out

    # File-level gates: every CONFIG_* a header mentions in any #if/#ifdef.  A definition
    # with no guard of its own can still sit in a header that no build reaches, so the
    # reviewer needs both signals.  Per LEAD-SYNTHESIS 6.3 a Kconfig `select` is invisible
    # to a defconfig grep, so the resolver below follows selects and defaults.
    file_gates = {}
    for tag in ("sdm", "head"):
        for f in both:
            syms = set()
            for rec in recs[tag][f]:
                syms |= set(rec.req) | set(rec.exc) | set(rec.cx)
            syms = set(s for s in syms if s.startswith("CONFIG_")
                       and not is_include_guard(s, f))
            file_gates[(tag, f)] = sorted(syms)

    detail.sort(key=lambda d: (d["file"], d["value"], d["sdm"].name))
    for d in detail:
        s = d["sdm"]
        h = d["head"]
        dl = [live_verdict(s, cfg_sdm, explicit[dc], d["file"]) for dc in DEFCONFIGS]
        hl = [live_verdict(h, cfg_head, explicit[dc], d["file"]) for dc in DEFCONFIGS]
        d["sdm_live"] = dl
        d["head_live"] = hl
        d["sdm_mask"] = mask_refs("sdm", d["file"], s.name)
        d["head_mask"] = mask_refs("head", d["file"], h.name)
        gates = set(file_gates.get(("sdm", d["file"]), []))
        gates |= set(file_gates.get(("head", d["file"]), []))
        d["file_gates"] = sorted(gates)
        d["file_gate_values"] = {s2: cfg_sdm.value(s2, explicit[DEFCONFIGS[0]])
                                 for s2 in d["file_gates"]}

    def fmt(rec, live):
        return "%s:%d" % (rec.kind, rec.line)

    out = sys.stdout
    out.write("K7 flag/bitfield collision scan\n")
    out.write("sdm670   %s\n" % SDM670[:12])
    out.write("base     %s\n" % SERIES_BASE[:12])
    out.write("head     %s\n" % SERIES_HEAD[:12])
    out.write("series headers changed : %d\n" % len(series_headers))
    out.write("headers examined        : %d\n" % len(both))
    out.write("skipped (absent sdm670) : %d\n" % len(skipped_absent_sdm))
    out.write("skipped (absent head)   : %d\n" % len(skipped_absent_head))
    out.write("BIT_COLLISION           : %d\n" % n_bit)
    out.write("VALUE_COLLISION         : %d\n" % n_val)
    out.write("ENUM_INSERT_RENUMBER    : %d\n" % sum(
        1 for r in findings if r[4] == "ENUM_INSERT_RENUMBER"))
    out.write("TEXT_PREFIX_ONLY        : %d\n" % sum(
        1 for d in detail if d.get("kind") == "COLLISION" and not d.get("fused")))
    out.write("VALUE_CHANGED           : %d\n" % n_changed)
    out.write("WIDTH_CHANGED           : %d\n" % n_width)
    out.write("BITFIELD_WIDTH_CHANGED  : %d\n" % n_bf)
    out.write("findings rows           : %d\n" % len(findings))
    out.write("\nDETAIL (live/mask per defconfig, order %s)\n" % ", ".join(
        DEFCONFIG_LABEL[d] for d in DEFCONFIGS))
    for d in detail:
        out.write("\n%s | %s | %s | %s | prefix=%s | suggest=%s\n" % (
            d["file"], d["value"], d["sdm"].name, d["head"].name, d["prefix"], d["suggest"]))
        out.write("    sdm  %-18s line %-6s live: %s\n" % (fmt(d["sdm"], None), "", " ".join(
            "%s=%s" % (DEFCONFIG_LABEL[dc][:9], d["sdm_live"][i][:34]) for i, dc in enumerate(DEFCONFIGS))))
        out.write("    head %-18s line %-6s live: %s\n" % (fmt(d["head"], None), "", " ".join(
            "%s=%s" % (DEFCONFIG_LABEL[dc][:9], d["head_live"][i][:34]) for i, dc in enumerate(DEFCONFIGS))))
        out.write("    masks: sdm=%s head=%s\n" % (
            ",".join(d["sdm_mask"]) or "-", ",".join(d["head_mask"]) or "-"))
        if d["file_gates"]:
            out.write("    file gates: %s\n" % ", ".join(
                "%s=%s" % (s2, d["file_gate_values"][s2]) for s2 in d["file_gates"]))

    # MPTCP is absent from all four defconfigs, so anything behind CONFIG_MPTCP is inert.
    out.write("\nCONFIG_MPTCP per defconfig: %s\n" % ", ".join(
        "%s=%s" % (DEFCONFIG_LABEL[dc], explicit[dc].get("MPTCP", "<absent>"))
        for dc in DEFCONFIGS))
    out.write("CONFIG_MPTCP resolve: %s\n" % ", ".join(
        "%s=%s" % (DEFCONFIG_LABEL[dc], cfg_sdm.value("CONFIG_MPTCP", explicit[dc]))
        for dc in DEFCONFIGS))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))