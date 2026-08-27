#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Write a plain 3MF from STLs. No slicer needed to build one, and no slicer
profile embedded in it.

    make_3mf.py out.3mf --colours "#9AA0A6,#101010" \
        --object body.stl@1,badge.stl@2 --object lid.stl@1

This is core-spec 3MF (the 2015/02 namespace) and nothing else: geometry,
per-object material, and a build item per object. Any slicer will import it;
none of them will find print settings in it, which is the point - the settings
belong to whoever is printing, not to the model.

`--object a.stl@1,b.stl@2` groups parts into ONE build item, as 3MF components.
That is what keeps a badge locked in its recess: the two meshes are placed as
one rigid group, so Arrange in a slicer moves them together or not at all.
The `@n` is a 1-based index into --colours.
"""
import argparse
import re
import struct
import sys
import zipfile
from pathlib import Path

NS = "http://schemas.microsoft.com/3dmanufacturing/core/2015/02"
ASCII_VERTEX = re.compile(rb'vertex\s+(\S+)\s+(\S+)\s+(\S+)')

# Welding tolerance, in decimal places. STL is vertex soup - every triangle
# carries its own three corners - so identical corners have to be recognised
# here or the mesh comes out topologically shredded.
#
# The tolerance and the written precision MUST be the same number. They were
# not: the weld key used round(c, 6), six decimal places, while the writer used
# "%.6g", six significant digits, which at 30mm is four decimals. Two vertices
# 1e-5 apart were therefore kept as separate indices and then written as the
# same coordinates - a mesh split along a seam the file claims is joined, which
# is exactly what a slicer reports as non-manifold and silently "repairs".
#
# Four decimals - 0.1 micron - is not an arbitrary pick. Welding is a blunt
# instrument: too coarse and it merges distinct points, pinching the surface
# into a self-touching edge; too fine and it leaves coincident points
# unmerged. Swept across every body and rail, counting edges shared by more
# than two faces:
#
#     P=3   56        P=5   34
#     P=4   22        P=6   34      P=7  34
#
# 4 is the floor. Nothing below 3 decimals is meaningful to a printer anyway,
# and OpenSCAD's ASCII STL carries no more than 6 significant digits, which is
# why 5 and up all land in the same place.
PRECISION = 4

def quant(c):
    """Snap a coordinate to the grid the file is written on."""
    r = round(c, PRECISION)
    return r + 0.0 if r == 0 else r      # fold -0.0 onto 0.0

def fmt(c):
    """Write exactly what quant() keyed on, so the two cannot disagree."""
    return f"{c:.{PRECISION}f}"


def read_stl(path):
    """Vertices and triangles from an STL, ASCII or binary, de-duplicated."""
    data = Path(path).read_bytes()
    if len(data) < 84:
        sys.exit(f"{path}: too short to be an STL")
    if data[:5] == b'solid' and b'facet' in data[:2048]:
        raw = [tuple(map(float, m)) for m in ASCII_VERTEX.findall(data)]
    else:
        n = struct.unpack('<I', data[80:84])[0]
        if 84 + n * 50 != len(data):
            sys.exit(f"{path}: binary STL claims {n} facets but the file is "
                     f"{len(data)} bytes, not {84 + n * 50} - truncated?")
        raw = []
        for i in range(n):
            o = 84 + i * 50
            for k in range(3):
                raw.append(struct.unpack('<fff', data[o + 12 + k*12: o + 24 + k*12]))
    if not raw or len(raw) % 3:
        sys.exit(f"{path}: {len(raw)} vertices is not a whole number of triangles")

    index, verts, tris, dropped = {}, [], [], 0
    for i in range(0, len(raw), 3):
        tri = []
        for v in raw[i:i+3]:
            key = tuple(quant(c) for c in v)
            if key not in index:
                index[key] = len(verts)
                verts.append(key)
            tri.append(index[key])
        if len(set(tri)) == 3:       # a collapsed triangle is not geometry
            tris.append(tri)
        else:
            dropped += 1
    return verts, tris, dropped


def mesh_xml(verts, tris):
    v = "".join(f'<vertex x="{fmt(x)}" y="{fmt(y)}" z="{fmt(z)}"/>' for x, y, z in verts)
    t = "".join(f'<triangle v1="{a}" v2="{b}" v3="{c}"/>' for a, b, c in tris)
    return f"<mesh><vertices>{v}</vertices><triangles>{t}</triangles></mesh>"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out", help="path of the .3mf to write")
    ap.add_argument("--colours", default="#9AA0A6",
                    help="comma-separated hex colours, one per filament")
    ap.add_argument("--object", action="append", dest="objects", default=[],
                    metavar="STL@N[,STL@N...]",
                    help="one build item; comma-separated parts are grouped rigidly")
    a = ap.parse_args()
    if not a.objects:
        ap.error("at least one --object is required")

    colours = [c.strip() for c in a.colours.split(",") if c.strip()]
    for c in colours:
        if not re.fullmatch(r"#[0-9A-Fa-f]{6}", c):
            ap.error(f"colour {c!r} is not #RRGGBB")

    res, items, next_id = [], [], 2
    res.append('<basematerials id="1">' + "".join(
        f'<base name="filament{i+1}" displaycolor="{c}FF"/>'
        for i, c in enumerate(colours)) + '</basematerials>')

    total_dropped = 0
    for spec in a.objects:
        parts = []
        for piece in spec.split(","):
            stl, _, ex = piece.partition("@")
            try:
                idx = int(ex or 1)
            except ValueError:
                ap.error(f"{piece!r}: filament must be a number, e.g. {stl}@2")
            if not 1 <= idx <= len(colours):
                ap.error(f"{piece!r}: filament {idx} but only {len(colours)} colour(s) given")
            verts, tris, dropped = read_stl(stl)
            if not tris:
                sys.exit(f"{stl}: no triangles survived - refusing to write an empty object")
            total_dropped += dropped
            res.append(f'<object id="{next_id}" type="model" pid="1" pindex="{idx-1}">'
                       f'{mesh_xml(verts, tris)}</object>')
            parts.append((next_id, Path(stl).stem, len(tris), dropped))
            next_id += 1

        if len(parts) == 1:
            items.append(parts[0][0])
        else:                        # group them so a slicer cannot separate them
            res.append(f'<object id="{next_id}" type="model"><components>' + "".join(
                f'<component objectid="{p[0]}"/>' for p in parts) + '</components></object>')
            items.append(next_id)
            next_id += 1
        for oid, name, nt, drop in parts:
            note = f"  ({drop} degenerate dropped)" if drop else ""
            print(f"    {name:<14} filament {idx if len(parts)==1 else ''}"
                  f"{'':<2}{nt:6d} tris{note}")

    model = ('<?xml version="1.0" encoding="UTF-8"?>\n'
             f'<model unit="millimeter" xml:lang="en-US" xmlns="{NS}">'
             '<metadata name="Application">smd-magazine</metadata>'
             f'<resources>{"".join(res)}</resources>'
             '<build>' + "".join(
                 f'<item objectid="{i}" transform="1 0 0 0 1 0 0 0 1 0 0 0"/>'
                 for i in items) + '</build></model>')

    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(a.out, "w", zipfile.ZIP_DEFLATED) as z:
        z.writestr("[Content_Types].xml",
                   '<?xml version="1.0" encoding="UTF-8"?>'
                   '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
                   '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
                   '<Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>'
                   '</Types>')
        z.writestr("_rels/.rels",
                   '<?xml version="1.0" encoding="UTF-8"?>'
                   '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                   '<Relationship Id="rel0" Target="/3D/3dmodel.model" '
                   'Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>'
                   '</Relationships>')
        z.writestr("3D/3dmodel.model", model)
    if total_dropped:
        print(f"    {total_dropped} degenerate triangle(s) dropped in total")
    print(f"    -> {a.out}  ({len(items)} build item(s), {len(colours)} filament(s))")


if __name__ == "__main__":
    main()
