#!/usr/bin/env python3
"""Check a built product's HIDL HAL versions against a framework compatibility matrix (FCM) level.

Read-only. Prints every HIDL HAL declared in the device's VINTF manifests whose version is outside the
range the matrix allows, and every android.hardware.* HAL the matrix doesn't list at all.

Usage:
  scripts/fcm-check.py <compatibility_matrix.N.xml> <out/target/product/<codename>> [more product dirs]
Get the matrix from the target branch, e.g.:
  curl -sLo fcm7.xml https://raw.githubusercontent.com/LineageOS/android_hardware_interfaces/lineage-24.0/compatibility_matrices/compatibility_matrix.7.xml
Exit code: 0 = nothing outside the range, 1 = findings, 2 = usage error.
"""
import glob
import re
import sys


def ranges_from_matrix(text):
    allow = {}
    for m in re.finditer(r'<hal format="(\w+)"[^>]*>(.*?)</hal>', text, re.S):
        name = re.search(r'<name>(.*?)</name>', m.group(2)).group(1)
        allow.setdefault((m.group(1), name), []).extend(re.findall(r'<version>(.*?)</version>', m.group(2)))
    return allow


def in_range(version, ranges):
    major, minor = map(int, version.split('.'))
    for r in ranges:
        low, _, high = r.partition('-')
        rmaj, rmin = map(int, low.split('.'))
        rmax = int(high) if high else rmin
        if major == rmaj and rmin <= minor <= rmax:
            return True
    return False


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    allow = ranges_from_matrix(open(sys.argv[1]).read())
    found = False
    for prod in sys.argv[2:]:
        files = sorted(glob.glob(f'{prod}/vendor/etc/vintf/manifest.xml')
                       + glob.glob(f'{prod}/vendor/etc/vintf/manifest/*.xml')
                       + glob.glob(f'{prod}/odm/etc/vintf/manifest*.xml'))
        outside, missing = set(), set()
        for f in files:
            text = open(f).read()
            for m in re.finditer(r'<hal format="hidl"[^>]*>(.*?)</hal>', text, re.S):
                body = m.group(1)
                name = re.search(r'<name>(.*?)</name>', body).group(1)
                versions = set(re.findall(r'<version>(.*?)</version>', body))
                versions |= {v.lstrip('@') for v in re.findall(r'<fqname>(@[\d.]+)::', body)}
                for v in versions:
                    if ('hidl', name) in allow:
                        if not in_range(v, allow[('hidl', name)]):
                            outside.add(f"{name}@{v}  allowed {allow[('hidl', name)]}  ({f.split('/vintf/')[-1]})")
                    elif name.startswith('android.hardware'):
                        missing.add(f"{name}@{v}  ({f.split('/vintf/')[-1]})")
        print(f"== {prod} ({len(files)} manifest files)")
        print("  OUTSIDE allowed range:" + ("".join(f"\n    {x}" for x in sorted(outside)) or " none"))
        print("  android.hardware HALs not in matrix:" + ("".join(f"\n    {x}" for x in sorted(missing)) or " none"))
        found |= bool(outside or missing)
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
