#!/usr/bin/env python3
"""Decode Android's pstore pmsg-ramoops (binary logcat ring) to text, sorted by time.

Usage (tablet in recovery, ADB enabled):
  adb shell 'mkdir -p /tmp/ps; mount -t pstore pstore /tmp/ps; cat /tmp/ps/pmsg-ramoops-0' > pmsg.bin
  python3 scripts/pmsg-decode.py pmsg.bin > pmsg.txt
"""
import datetime
import struct
import sys

PRIO = "??VDIWEF"


def decode(d):
    i, out = 0, []
    while i < len(d) - 18:
        # android_pmsg_log_header_t: magic 'l', len, uid, pid
        if d[i] != 0x6C:
            i += 1
            continue
        ln, uid, pid = struct.unpack_from("<HHH", d, i + 1)
        if ln < 18 or i + ln > len(d):
            i += 1
            continue
        # android_log_header_t: id, tid, sec, nsec
        lid, tid, sec, nsec = struct.unpack_from("<BHII", d, i + 7)
        pl = d[i + 18:i + ln]
        if lid in (0, 1, 3, 4) and pl and 2 <= pl[0] <= 7:
            parts = pl[1:].split(b"\0")
            tag = parts[0].decode(errors="replace")
            msg = (parts[1] if len(parts) > 1 else b"").decode(errors="replace")
            t = datetime.datetime.fromtimestamp(sec, datetime.timezone.utc).strftime("%H:%M:%S")
            out.append((sec, nsec, f"{t}.{nsec // 1000000:03d} {pid:5d} {tid:5d} {PRIO[pl[0]]} {tag}: {msg}"))
        i += ln
    return [line for _, _, line in sorted(out)]


if __name__ == "__main__":
    print("\n".join(decode(open(sys.argv[1], "rb").read())))
