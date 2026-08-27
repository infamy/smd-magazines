#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""Compare a grown magazine against the standard, point by point.

Every seam bug we have hit has the same shape: a constant that did not
follow the growth, leaving the XL subtly different from the standard
somewhere we were not looking. Checks that only look *inside* the XL -
manifold, connected, lid clearance - cannot see any of them.

This slices both sizes at several heights and asks, for a grid of sample
points: is the material at (x, y) in the standard also material at
gp(x, y) in the grown part? gp() is the same mapping features go through,
so away from the seam the answer must be yes everywhere.

  ./compare_sizes.py [--grow 12.5] [--width 12] [--step 1.5]

Reports the mismatching regions, clustered, largest first.
"""
import argparse
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
CONTAINER = HERE.parent / "scad" / "container.scad"

# build.sh honours $OPENSCAD; so does this, or a machine that has OpenSCAD
# somewhere else can build but cannot check what it built.
OPENSCAD = os.environ.get(
    "OPENSCAD", "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD")

# What magazine_plate.scad renders at. $fn is a SPECIAL variable: OpenSCAD
# resolves it from the CALL SITE, and `use <>` does not carry the used file's
# value across - so a generated file that only says `use <container.scad>`
# renders every arc at the coarse default $fa/$fs no matter what
# container.scad says. The shipping build sets $fn = 100 at the top level of
# magazine_plate.scad; a harness that does not do the same is comparing
# geometry that never leaves this directory. Keep the two in step.
FN = 100

# OpenSCAD writes coordinates that land on zero in exponent form, e.g.
# "-20,7.47293e-06". A pattern without the exponent clause reads that as
# -20,7.47293 - off by 7.5mm, and it happens precisely on the x=0 / y=0 split
# lines this script exists to check. Keep the exponent clause.
NUM = r"-?\d+\.?\d*(?:[eE][-+]?\d+)?"
NUM_PAIR = f"({NUM},{NUM})"

# Top-level `name = number;` in container.scad. Anchored at column 0, which is
# where the globals live and where nothing else does.
ASSIGN = re.compile(rf"^([A-Za-z_]\w*)\s*=\s*({NUM})\s*;", re.M)

# OpenSCAD will not write an SVG for a projection that comes out empty; it
# says this and exits non-zero. That is not always a failure - lid() is only
# side_wall_thickness tall, so every level above 1.25 legitimately has no
# material in it. A build that is genuinely broken prints the SAME line,
# though, so this string can never be trusted on its own.
NO_GEOMETRY = "Current top level object is not a 2D object"

# ...hence these. A missing module is only a WARNING to OpenSCAD, and it
# produces an empty result that is otherwise indistinguishable from a cut
# plane above the part - which is how a broken build gets read as "nothing
# here" and waved through as CLEAN. Treat them as fatal. Not listed, and
# deliberately so: "Too many unnamed arguments", which lid(width) raises on
# every run because lid() takes none.
FATAL = ("ERROR:", "Ignoring unknown module", "Ignoring unknown function",
         "Parser error", "Compilation failed", "assertion failed")


def scad_globals(*names):
    """Read container.scad's globals instead of retyping them here.

    Anything spelled out twice drifts. These are the values the geometry is
    actually built from, so read them from the source of truth and fail loudly
    if one is renamed rather than quietly checking against a stale number.
    """
    found = dict(ASSIGN.findall(CONTAINER.read_text()))
    missing = [n for n in names if n not in found]
    if missing:
        sys.exit(f"{CONTAINER.name} no longer defines {', '.join(missing)} "
                 f"as a top-level global - this script's derivations are stale")
    return {n: float(found[n]) for n in names}


G = scad_globals("side_wall_thickness", "tape_spacing",
                 "window_d", "window_slot_w")


def setting(extra, name):
    """Effective value of a container.scad global in the GROWN build."""
    if name not in extra:
        return G[name]
    try:
        return float(extra[name])
    except ValueError:
        sys.exit(f"--set {name}={extra[name]} is not a number")


def part_height(width):
    """Total height of the body, straight off container.scad's body_base():
    2 * side_wall_thickness + (width + tape_spacing). 15.3 at --width 12,
    19.3 at --width 16."""
    return 2 * G["side_wall_thickness"] + width + G["tape_spacing"]


def z_levels(width, pitch=3.0):
    """Heights to slice at, derived from the part rather than hardcoded.

    The old list stopped at 14.6, which is just under the top of a --width 12
    part and 4.7mm short of the top of a --width 16 one - so the whole lid
    seat of every 16mm build went unchecked, silently and with no way to tell
    from the output. Anchor the bottom levels absolutely (they track the
    1.25mm outer skin, which does not scale with width), the top two to the
    top face, and ladder the middle at a fixed pitch so a taller part gets
    MORE samples rather than the same eight spread thinner.
    """
    h = part_height(width)
    low = [0.6,    # inside the outer skin, where the window and level slot are
           1.8,    # just above it, in the tape pocket
           3.0]    # the wall proper
    high = [h - 1.8,   # under the lid pocket, which starts at wall + width
            h - 0.7]   # inside the pocket
    n = int((high[0] - low[-1]) / pitch)
    mid = [low[-1] + pitch * k for k in range(1, n + 1)]
    out = []
    for z in low + mid + high:
        z = round(z, 3)
        if not out or z - out[-1] >= 0.4:   # never two slices in one feature
            out.append(z)
    return out


def section(part, z, grow, width, extra):
    """2D cross-section of `part` at height z, as a list of polygons.

    Returns None when the part has no material at this height at all, which
    is a real answer and not an error - see NO_GEOMETRY.
    """
    with tempfile.TemporaryDirectory() as td:
        scad = Path(td) / "s.scad"
        scad.write_text(
            f'use <{CONTAINER}>\n'
            # $fn is resolved from the call site and `use` does not carry it,
            # so this line - not anything in container.scad - is what decides
            # the facet count of every arc measured below. It has to match
            # magazine_plate.scad or the harness checks a part we never print.
            f'$fn = {FN};\n'
            f'projection(cut=true) translate([0,0,-{z}]) {part}({width});\n')
        svg = Path(td) / "s.svg"
        cmd = [OPENSCAD, "-D", f"grow_x={grow}", "-D", f"grow_y={grow}"]
        for k, v in extra.items():
            cmd += ["-D", f"{k}={v}"]
        cmd += ["-o", str(svg), str(scad)]
        r = subprocess.run(cmd, capture_output=True)
        err = r.stderr.decode(errors="replace")
        if r.returncode != 0 or not svg.exists():
            if NO_GEOMETRY in err and not any(f in err for f in FATAL):
                return None      # nothing at this height; main() sanity-checks
            # Without this the tool returns [] on a broken build, every
            # comparison is empty, and it confidently prints CLEAN.
            sys.exit(f"openscad failed for {part} at z={z}:\n{err}")
        paths = re.findall(r'<path d="(.*?)"', svg.read_text(), re.S)
        if not paths:
            return []
        polys = []
        for sp in "".join(paths).split("M"):
            pts = [tuple(map(float, q.split(",")))
                   for q in re.findall(NUM_PAIR, sp)]
            if len(pts) > 2:
                polys.append([(x, -y) for x, y in pts])   # svg y is negated
        return polys


def inside(pt, polys):
    """Even-odd test across all contours, which is how OpenSCAD exports holes."""
    x, y = pt
    c = False
    for poly in polys:
        n = len(poly)
        j = n - 1
        for i in range(n):
            xi, yi = poly[i]
            xj, yj = poly[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                c = not c
            j = i
    return c


def gp(pt, grow):
    x, y = pt
    return (x + (grow if x >= 0 else -grow),
            y + (grow if y >= 0 else -grow))


# How far past a feature's true edge its mask reaches. Covers the fill-and-
# re-cut ring around the seam features and one sampling step of slop.
MASK_PAD = 2.0

# Literals inside container.scad modules, not globals - no -D reaches them, so
# there is nothing to derive them from and they are written out here with the
# module that owns them. If one of these moves, it moves here too.
SLOT_Y = (9.51, 28.00)      # 2d_slot_fill() / 2d_face_cut() endpoints
# The opening is an intersection with 2d_lid_opening_stock()'s clip square,
# so the square (x +-22, y 8..31) bounds it but does not give it; these are the
# measured extents and stay measured rather than widening the mask to the clip.
LID_OPENING = (-22, 22, 7.0, 30.5)
LABEL_SLOT = (-31, 15, 29.5, 37.0)   # the two cubes under "// LABEL" in body()


def deliberate_mask(extra):
    """Regions where the XL is deliberately NOT a gp() image of the standard,
    in standard coordinates. Everything else must map exactly.

    The window and the level slot are sized by globals the grown build
    overrides (build.sh passes -D window_d=22), so their masks follow the
    override: a mask pinned to one variant's numbers stops covering the
    feature the moment anyone changes it, and then reports the change as a
    defect. Take the larger of the two builds' values, since the mask has to
    cover the feature in whichever size it is bigger.
    """
    win_r = max(G["window_d"], setting(extra, "window_d")) / 2 + MASK_PAD
    slot_w = max(G["window_slot_w"], setting(extra, "window_slot_w")) / 2 + MASK_PAD
    lx0, lx1, ly0, ly1 = LID_OPENING
    bx0, bx1, by0, by1 = LABEL_SLOT
    return [
        ("round window",
         lambda x, y: x * x + y * y <= win_r ** 2),
        ("level slot",
         lambda x, y: abs(x) <= slot_w
         and SLOT_Y[0] - MASK_PAD <= y <= SLOT_Y[1] + MASK_PAD),
        ("lid access opening",
         lambda x, y: lx0 <= x <= lx1 and ly0 <= y <= ly1),
        ("label slot",
         lambda x, y: bx0 <= x <= bx1 and by0 <= y <= by1),
    ]


def cluster(pts, reach=3.0):
    """Group mismatches so one defect reports as one finding."""
    out = []
    for p in sorted(pts):
        for g in out:
            if any(abs(p[0]-q[0]) <= reach and abs(p[1]-q[1]) <= reach for q in g):
                g.append(p)
                break
        else:
            out.append([p])
    return sorted(out, key=len, reverse=True)


def samples(lo, hi, step):
    """lo..hi inclusive, by integer count.

    `while v <= hi: v += step` accumulates rounding, and when the drift goes
    the wrong way the last row lands a hair above hi and is dropped - losing
    the outermost row of the part, which is exactly where the seam is. Count
    the steps instead of walking a float.
    """
    n = int((hi - lo) / step + 1e-9)
    return [lo + i * step for i in range(n + 1)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grow", type=float, default=12.5)
    ap.add_argument("--width", type=float, default=12)
    ap.add_argument("--step", type=float, default=1.5)
    ap.add_argument("--margin", type=float, default=1.5,
                    help="skip points this close to a split line, where the "
                         "mapping is one-to-many by construction")
    ap.add_argument("--set", action="append", default=[],
                    help="extra -D for the grown build, e.g. --set window_d=22")
    args = ap.parse_args()

    extra = dict(s.split("=", 1) for s in args.set)
    mask = deliberate_mask(extra)
    levels = z_levels(args.width)
    findings = []

    print(f"  width {args.width:g}, part height {part_height(args.width):.2f}, "
          f"$fn {FN}, {len(levels)} levels: "
          f"{' '.join(format(z, 'g') for z in levels)}")

    for part in ("body", "lid"):
        measured = 0
        for z in levels:
            std = section(part, z, 0, args.width, {})
            xl = section(part, z, args.grow, args.width, extra)
            if std is None and xl is None:
                continue          # above the top of this part; nothing to see
            if (std is None) != (xl is None):
                # Growth is in XY only, so both sizes must reach the same
                # height. If they disagree, one of them did not build.
                sys.exit(f"{part} at z={z}: "
                         f"{'standard' if std is None else 'grown'} part has no "
                         f"material here but the other does - broken build, "
                         f"not a seam defect")
            if not std and not xl:
                continue
            xs = [p[0] for poly in std for p in poly]
            ys = [p[1] for poly in std for p in poly]
            if not xs:
                continue
            measured += 1
            bad = []
            for y in samples(min(ys), max(ys), args.step):
                for x in samples(min(xs), max(xs), args.step):
                    if abs(x) > args.margin and abs(y) > args.margin:
                        if not any(f(x, y) for _, f in mask) and \
                                inside((x, y), std) != inside(gp((x, y), args.grow), xl):
                            bad.append((round(x, 1), round(y, 1)))
            for g in cluster(bad):
                gx = [p[0] for p in g]
                gy = [p[1] for p in g]
                findings.append((len(g), part, z, min(gx), max(gx), min(gy), max(gy)))
            print(f"  {part:5s} z={z:5.2f}  {len(bad):4d} mismatched samples", flush=True)
        if not measured:
            # Every level came back empty. Nothing was compared, so reporting
            # CLEAN below would be a lie about a part nobody looked at.
            sys.exit(f"{part}: no level produced any geometry - nothing was "
                     f"measured; check the build before trusting this run")

    print()
    if not findings:
        print("  CLEAN - the grown part matches the standard at every sampled point")
        return 0
    print(f"  {len(findings)} mismatching regions, largest first:")
    for n, part, z, x0, x1, y0, y1 in sorted(findings, reverse=True)[:20]:
        print(f"    {part:5s} z={z:5.2f}  {n:4d} pts   "
              f"x {x0:7.1f}..{x1:6.1f}   y {y0:7.1f}..{y1:6.1f}")
    return 1


if __name__ == "__main__":
    sys.exit(main())
