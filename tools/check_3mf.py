#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Check the 3MFs the build produces, before a slicer has to.

  ./tools/check_3mf.py [path ...]        default: every 3MF under print/

Slicers do not refuse a bad mesh, they quietly repair it and carry on, so a
file can be wrong for a long time without anything saying so. This says so.

What it looks at, per object:

  duplicate positions   two vertices at the same coordinates. The mesh is split
                        along a seam the file claims is joined - the classic
                        cause of a slicer reporting errors and auto-repairing.
  boundary edges        an edge with one face. A hole; the solid is open.
  odd edges             an edge with an odd number of faces. Also open.
  wrong winding         an edge traversed the same way by both its faces, so
                        one of them faces inwards.
  self-touching         an edge with four faces: two surfaces meeting exactly
                        along a line. Closed, and it slices, but it is
                        non-manifold and a slicer may well say so.

The first four are faults. The last is reported separately because it is a
property of the geometry rather than a defect in the file, and the build does
not currently produce zero of them.

Cross-checked against lib3mf 2.5.0, the 3MF Consortium's reference
implementation. It reads every file this build produces without complaint, so
the hand-written XML is spec-valid, and its IsManifoldAndOriented() flags
exactly the same seven plates this reports as self-touching - the six XL
magazine bodies and rail-xl-100mm. Two independent implementations agreeing
is the reason for trusting either.

That is also the answer to "why not just use lib3mf". For writing: what this
project emits is a fixed, small subset - geometry, base materials, components -
and the reference library confirms the output is correct, against a build that
otherwise needs nothing but OpenSCAD and the Python standard library. For
checking: IsManifoldAndOriented() is one call against the forty lines below,
which is a real argument for it, but it does not say which edges or where, and
it would not have caught the weld bug that prompted all this - lib3mf takes
vertices by index, so the soup-to-indexed-mesh step stays ours either way.
"""

import collections
import re
import sys
import zipfile
from pathlib import Path

VERTEX = re.compile(r'<vertex x="([^"]+)" y="([^"]+)" z="([^"]+)"\s*/>')
TRIANGLE = re.compile(r'<triangle v1="(\d+)" v2="(\d+)" v3="(\d+)"')
OBJECT = re.compile(r'<object id="(\d+)"([^>]*)>(.*?)</object>', re.S)


def check_mesh(body):
    verts = VERTEX.findall(body)
    tris = [tuple(map(int, t)) for t in TRIANGLE.findall(body)]

    dup = sum(c - 1 for c in collections.Counter(verts).values() if c > 1)
    degen = sum(1 for a, b, c in tris if a == b or b == c or a == c)
    used = {i for t in tris for i in t}
    unref = len(verts) - len(used)
    oob = sum(1 for t in tris for i in t if i >= len(verts))

    edges = collections.Counter()
    directed = collections.Counter()
    for a, b, c in tris:
        for u, v in ((a, b), (b, c), (c, a)):
            edges[frozenset((u, v))] += 1
            directed[(u, v)] += 1

    return {
        "verts": len(verts), "tris": len(tris),
        "duplicate": dup, "degenerate": degen, "unreferenced": unref,
        "out-of-range": oob,
        "boundary": sum(1 for n in edges.values() if n == 1),
        "odd": sum(1 for n in edges.values() if n % 2),
        # Winding only means anything for an edge with exactly two faces: they
        # should traverse it in opposite directions, so neither direction should
        # be used twice. An edge with four faces repeats a direction by
        # construction, so including those would report every tangency twice -
        # once as bad winding, once as what it actually is.
        "winding": sum(1 for (u, v), n in directed.items()
                       if n > 1 and edges[frozenset((u, v))] == 2),
        "touching": sum(1 for n in edges.values() if n > 2),
    }


FAULTS = ("duplicate", "degenerate", "out-of-range", "boundary", "odd", "winding")


def check_file(path):
    try:
        z = zipfile.ZipFile(path)
    except zipfile.BadZipFile:
        print(f"  BAD   {path}  not a zip archive")
        return 1, 0
    names = set(z.namelist())
    missing = {"[Content_Types].xml", "_rels/.rels", "3D/3dmodel.model"} - names
    if missing:
        print(f"  BAD   {path}  missing {', '.join(sorted(missing))}")
        return 1, 0

    model = z.read("3D/3dmodel.model").decode()
    meshes, bad, touch = 0, 0, 0
    lines = []
    ids = set(re.findall(r'<object id="(\d+)"', model))
    for ref in re.findall(r'objectid="(\d+)"', model):
        if ref not in ids:
            lines.append(f"        dangling reference to object {ref}")
            bad += 1

    for m in OBJECT.finditer(model):
        oid, body = m.group(1), m.group(3)
        if "<mesh>" not in body:
            continue
        meshes += 1
        r = check_mesh(body)
        touch += r["touching"]
        hit = {k: r[k] for k in FAULTS if r[k]}
        if hit:
            bad += 1
            lines.append(f"        object {oid}: "
                         + "  ".join(f"{k} {v}" for k, v in hit.items()))
        elif r["touching"]:
            lines.append(f"        object {oid}: self-touching {r['touching']}"
                         "  (closed, slices, non-manifold)")

    tag = "BAD " if bad else "ok  "
    print(f"  {tag}  {path}  {meshes} mesh object(s)")
    for ln in lines:
        print(ln)
    return bad, touch


def main():
    args = sys.argv[1:]
    paths = [Path(a) for a in args] if args else sorted(Path("print").rglob("*.3mf"))
    if not paths:
        sys.exit("nothing to check; run tools/build.sh first")
    bad = touch = 0
    for p in paths:
        b, t = check_file(p)
        bad += b
        touch += t
    print()
    print(f"  {len(paths)} file(s), {bad} with faults, "
          f"{touch} self-touching edge(s) in total")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
