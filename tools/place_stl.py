#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Move STLs onto the bed, in place.

    place_stl.py --at X,Y body.stl badge.stl

The offset is computed from the FIRST file's bounding box - its min x/y land on
X/Y and its min z on 0 - and the same offset is applied to every file listed.
That is what keeps a badge inside its body's recess: the two are positioned as
one rigid group, never placed independently.
"""
import argparse
import re
import struct
import sys
from pathlib import Path

FACET = re.compile(rb'vertex\s+(\S+)\s+(\S+)\s+(\S+)')


def read(path):
    data = Path(path).read_bytes()
    if data[:5] == b'solid' and b'facet' in data[:2000]:
        return "ascii", data, [tuple(map(float, m)) for m in FACET.findall(data)]
    n = struct.unpack('<I', data[80:84])[0]
    verts = []
    for i in range(n):
        o = 84 + i * 50
        for k in range(3):
            verts.append(struct.unpack('<fff', data[o + 12 + k*12: o + 24 + k*12]))
    return "binary", data, verts


def write_ascii(path, data, dx, dy, dz):
    def sub(m):
        x, y, z = (float(m.group(i)) for i in (1, 2, 3))
        return b'vertex %.6f %.6f %.6f' % (x + dx, y + dy, z + dz)
    Path(path).write_bytes(FACET.sub(sub, data))


def write_binary(path, data, dx, dy, dz):
    out = bytearray(data)
    n = struct.unpack('<I', data[80:84])[0]
    for i in range(n):
        o = 84 + i * 50
        for k in range(3):
            p = o + 12 + k * 12
            x, y, z = struct.unpack('<fff', data[p:p+12])
            out[p:p+12] = struct.pack('<fff', x + dx, y + dy, z + dz)
    Path(path).write_bytes(bytes(out))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--at", required=True, help="target X,Y for the first file's min corner")
    ap.add_argument("files", nargs="+")
    a = ap.parse_args()
    tx, ty = (float(v) for v in a.at.split(","))

    kind, data, verts = read(a.files[0])
    if not verts:
        sys.exit(f"{a.files[0]}: no vertices")
    dx = tx - min(v[0] for v in verts)
    dy = ty - min(v[1] for v in verts)
    dz = 0.0 - min(v[2] for v in verts)

    for f in a.files:
        kind, data, _ = read(f)
        (write_ascii if kind == "ascii" else write_binary)(f, data, dx, dy, dz)
    print(f"    placed {len(a.files)} file(s) at {tx},{ty}  (offset {dx:+.2f},{dy:+.2f},{dz:+.2f})")


if __name__ == "__main__":
    main()
