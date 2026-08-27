#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Package the build for Printables and MakerWorld.

  ./tools/make_upload.py            after ./tools/build.sh

Both sites take the same files, so this makes one set:

  upload/SMD-magazines-3mf.zip      the 16 ready-to-print plates
  upload/SMD-magazines-stl.zip      every part as a separate STL
  upload/<instructions>.pdf         loose, so it can go up as its own file

The 3MFs are what almost everyone wants - three objects, four parts, the badge
already on filament 2. The STLs are for people who would rather arrange the
parts themselves, or whose slicer they do not trust with a 3MF.

STLs are rewritten as binary on the way in. OpenSCAD emits ASCII, which is
about four times the size for identical geometry - 111MB becomes roughly 27MB,
which is the difference between a comfortable upload and a painful one. Binary
STL is universally supported; nothing is lost but whitespace.

The 3MF plates are left exactly as the build made them, byte for byte. They are
the thing people print, and they have been checked by tools/check_3mf.py; this
script does not get to touch them.
"""

import re
import shutil
import struct
import sys
import zipfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
PRINT = ROOT / "print"
STL = ROOT / "stl"
OUT = ROOT / "upload"
PDF = ROOT / "publish" / "SMD-magazines-instructions.pdf"

FACET = re.compile(
    rb"facet\s+normal\s+(\S+)\s+(\S+)\s+(\S+)\s+outer\s+loop\s+"
    rb"vertex\s+(\S+)\s+(\S+)\s+(\S+)\s+"
    rb"vertex\s+(\S+)\s+(\S+)\s+(\S+)\s+"
    rb"vertex\s+(\S+)\s+(\S+)\s+(\S+)\s+"
    rb"endloop\s+endfacet", re.I)


def to_binary_stl(path):
    """ASCII STL -> binary STL bytes. Returns None if it is already binary."""
    data = path.read_bytes()
    if not data.lstrip()[:5].lower().startswith(b"solid"):
        return None                      # already binary, pass it through
    facets = FACET.findall(data)
    if not facets:
        return None                      # unparseable: ship the original
    out = bytearray()
    out += (f"binary STL from {path.name}".encode()[:80]).ljust(80, b"\0")
    out += struct.pack("<I", len(facets))
    for f in facets:
        out += struct.pack("<12fH", *[float(x) for x in f], 0)
    return bytes(out)


def add_stl(zf, src, arcname):
    """Add one STL, converted to binary, and report what that saved."""
    binary = to_binary_stl(src)
    if binary is None:
        zf.write(src, arcname)
        return src.stat().st_size, src.stat().st_size
    zf.writestr(arcname, binary)
    return src.stat().st_size, len(binary)


def main():
    if not PRINT.exists() or not any(PRINT.rglob("*.3mf")):
        sys.exit("no print/ - run ./tools/build.sh first")
    if not STL.exists() or not any(STL.rglob("*.stl")):
        sys.exit("no stl/ - run ./tools/build.sh first")

    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)

    # ---- the plates, untouched
    plates = sorted(PRINT.rglob("*.3mf"))
    zpath = OUT / "SMD-magazines-3mf.zip"
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for p in plates:
            z.write(p, str(Path("SMD-magazines") / p.relative_to(PRINT)))
    print(f"  {zpath.name:30} {len(plates):3} plates   "
          f"{zpath.stat().st_size/1024/1024:5.1f} MB")

    # ---- every part, as binary STL
    stls = sorted(STL.rglob("*.stl"))
    zpath = OUT / "SMD-magazines-stl.zip"
    was = now = 0
    with zipfile.ZipFile(zpath, "w", zipfile.ZIP_DEFLATED) as z:
        for s in stls:
            a, b = add_stl(z, s, str(Path("SMD-magazines-stl") / s.relative_to(STL)))
            was += a
            now += b
    print(f"  {zpath.name:30} {len(stls):3} parts    "
          f"{zpath.stat().st_size/1024/1024:5.1f} MB"
          f"   (STL {was/1024/1024:.0f} -> {now/1024/1024:.0f} MB as binary)")

    # ---- the instructions, loose
    if PDF.exists():
        shutil.copy(PDF, OUT / PDF.name)
        print(f"  {PDF.name:30}           {PDF.stat().st_size/1024:5.0f} KB")
    else:
        print(f"  {'(no instructions PDF)':30}           run tools/make_pdf.py")

    print()
    print(f"  upload/ ready - the same set goes to both Printables and MakerWorld.")


if __name__ == "__main__":
    main()
