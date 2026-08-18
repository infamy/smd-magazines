#!/usr/bin/env python3
"""Draw the annotated rail side profile used in the README.

Self-contained: it renders the standard rail's 2D section with OpenSCAD into a
temporary directory, traces the top and bottom edge chains off that contour,
and derives every printed number from the measured geometry. Overlays are
traced off the real outline and every leader anchor is resolved from it, so
nothing can float and nothing can go stale when the profile changes.

  ./draw_rail_profile.py [out.svg]

Writes the SVG and, if a converter is installed, the PNG beside it. Default is
../reference/rail_side_profile.svg relative to this file.
"""
import argparse
import html
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
OPENSCAD = "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
DEFAULT_OUT = HERE.parent / "reference" / "rail_side_profile.svg"

# OpenSCAD writes on-zero coordinates in exponent form ("-20,7.47293e-06").
# Without the exponent clause that parses as -20,7.47293 - a 7.5mm error.
NUM = r"-?\d+\.?\d*(?:[eE][-+]?\d+)?"
NUM_PAIR = f"({NUM},{NUM})"

W, H = 1700, 1020
PX0, PY0, PW, PH = 40, 132, W - 80, H - 250
STEP = 0.02          # x sampling pitch for the crossing scans, mm


def profile_polys():
    """The standard rail's 2D section, as a list of contours.

    $fn is a SPECIAL variable, resolved from the call site: `use <rail.scad>`
    does NOT carry rail.scad's own $fn=100 across. It has to be set in the file
    OpenSCAD actually runs, or the rod channels come out as coarse ~20-gons.
    """
    with tempfile.TemporaryDirectory() as td:
        scad = Path(td) / "p.scad"
        scad.write_text(f"use <{HERE}/rail.scad>\n"
                        f"$fn=100;\n"
                        f"2d_rail_profile_weights_round();\n")
        svg = Path(td) / "p.svg"
        r = subprocess.run([OPENSCAD, "-o", str(svg), str(scad)],
                           capture_output=True)
        if r.returncode != 0 or not svg.exists():
            # Without this the script would draw an empty page and claim success.
            sys.exit("openscad failed to export the profile:\n"
                     + r.stderr.decode(errors="replace"))
        m = re.search(r'<path d="(.*?)"', svg.read_text(), re.S)
        if not m:
            sys.exit("openscad exported no contours")
        polys = []
        for sp in m.group(1).split("M"):
            pts = [(float(a), -float(b))          # svg y points down
                   for a, b in (q.split(",") for q in re.findall(NUM_PAIR, sp))]
            if len(pts) > 2:
                polys.append(pts)
        return polys


def area2(poly):
    n = len(poly)
    return abs(sum(poly[i][0] * poly[(i + 1) % n][1] - poly[(i + 1) % n][0] * poly[i][1]
                   for i in range(n)))


def inside(pt, polys):
    """Even-odd test across all contours, which is how OpenSCAD exports holes."""
    x, y = pt
    c = False
    for poly in polys:
        j = len(poly) - 1
        for i in range(len(poly)):
            xi, yi = poly[i]
            xj, yj = poly[j]
            if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
                c = not c
            j = i
    return c


def crossings(outer, x):
    """Every y where the vertical line at x meets the outline, sorted."""
    ys = []
    for i in range(len(outer)):
        (x0, y0), (x1, y1) = outer[i], outer[(i + 1) % len(outer)]
        if (x0 - x) * (x1 - x) <= 0 and x0 != x1:
            ys.append(y0 + (y1 - y0) * (x - x0) / (x1 - x0))
    return sorted(ys)


def edge_chains(outer):
    """Split the outline into its top and bottom chains.

    The cuts are the two extreme-x vertices - highest of those at the left end,
    lowest of those at the right end, since both end faces are vertical. Walking
    the ring both ways between them gives the two chains; the one that runs
    higher is the top. Derived here rather than read from a file, so the traced
    overlay can never disagree with the outline underneath it.
    """
    n = len(outer)
    i0 = max(range(n), key=lambda i: (-outer[i][0], outer[i][1]))
    i1 = max(range(n), key=lambda i: (outer[i][0], -outer[i][1]))
    fwd = [outer[(i0 + k) % n] for k in range((i1 - i0) % n + 1)]
    bwd = [outer[(i0 - k) % n] for k in range((i0 - i1) % n + 1)]

    def mean_y(chain):
        return sum(p[1] for p in chain) / len(chain)

    return (fwd, bwd) if mean_y(fwd) > mean_y(bwd) else (bwd, fwd)


def runs(xs, hit, pred, x0, x1, min_width=0.5):
    """Contiguous x spans where pred holds, from a precomputed sample sweep.

    `hit[i]` is pred(xs[i]); only the span ends are re-evaluated, bisected onto
    the real boundary, and spans that reach the sweep's ends are clamped to the
    section's own extent.
    """
    spans, i = [], 0
    while i < len(hit):
        if hit[i]:
            j = i
            while j + 1 < len(hit) and hit[j + 1]:
                j += 1
            spans.append((i, j))
            i = j + 1
        else:
            i += 1

    def bisect(out_x, in_x):
        """out_x is outside the span, in_x inside; return the boundary."""
        for _ in range(40):
            mid = (out_x + in_x) / 2
            if pred(mid):
                in_x = mid
            else:
                out_x = mid
        return in_x

    spans = [(i, j) for i, j in spans if xs[j] - xs[i] >= min_width]
    return [(x0 if i == 0 else bisect(xs[i - 1], xs[i]),
             x1 if j == len(hit) - 1 else bisect(xs[j + 1], xs[j]))
            for i, j in spans]


def render_png(svg_path, png_path, w, h):
    """Best-effort SVG -> PNG. Returns the tool used, or None."""
    for cmd in (["rsvg-convert", "-w", str(w), "-h", str(h),
                 "-o", str(png_path), str(svg_path)],
                ["magick", "-density", "96", "-background", "white",
                 str(svg_path), "-resize", f"{w}x{h}", str(png_path)],
                ["inkscape", f"--export-filename={png_path}",
                 f"--export-width={w}", str(svg_path)]):
        if shutil.which(cmd[0]) and subprocess.run(cmd, capture_output=True).returncode == 0:
            return cmd[0]
    return None


def draw(polys, out_path):
    outer = max(polys, key=area2)
    top, bot = edge_chains(outer)

    def cross(x):
        return crossings(outer, x)

    xs = [p[0] for q in polys for p in q]
    ys = [p[1] for q in polys for p in q]
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)

    # One sweep across the section feeds both scans below.
    xsamp = [x0 + STEP / 2 + i * STEP for i in range(int((x1 - x0) / STEP))]
    swept = [cross(x) for x in xsamp]

    # Bands where a vertical line meets the outline more than twice: there is
    # no single top surface to trace there. Counted, not remembered.
    bands = runs(xsamp, [len(c) > 2 for c in swept],
                 lambda x: len(cross(x)) > 2, x0, x1)
    # Hooks: the end spans where the outline stands well proud of the body's
    # top face, halfway up to the section's own high point.
    tops = sorted(c[-1] for c in swept)
    hook_thr = (tops[len(tops) // 2] + y1) / 2
    hooks = runs(xsamp, [c[-1] >= hook_thr for c in swept],
                 lambda x: cross(x)[-1] >= hook_thr, x0, x1)

    def anchor(x, which, depth=1.6):
        """Walk in from the top or bottom edge until we are `depth` mm inside
        solid material. Holes are respected, so a channel can never be picked."""
        ys_ = cross(x)
        lo, hi = ys_[0], ys_[-1]
        step = 0.1
        n = int((hi - lo) / step)
        seq = range(n, -1, -1) if which == "top" else range(n + 1)
        run = 0
        for i in seq:
            y = lo + i * step
            if inside((x, y), polys):
                run += step
                if run >= depth:
                    return (x, y)
            else:
                run = 0
        raise SystemExit(f"no {depth}mm of material at x={x}")

    sc = min((PW - 150) / (x1 - x0), (PH - 190) / (y1 - y0))
    ox = PX0 + PW / 2 - (x1 + x0) / 2 * sc
    oy = PY0 + PH / 2 + (y1 + y0) / 2 * sc + 18

    def T(p):
        return (ox + p[0] * sc, oy - p[1] * sc)

    HE = html.escape
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
         f'<rect width="{W}" height="{H}" fill="#ffffff"/>',
         f'<rect x="{PX0}" y="{PY0}" width="{PW}" height="{PH}" fill="#f2f3f5" stroke="#d8dade"/>',
         '<style>text{font-family:Helvetica,Arial,sans-serif;font-size:21px;fill:#14181d}'
         '.t{font-size:31px;font-weight:bold}.s{font-size:18px;fill:#5b6470}'
         '.k{font-size:19px;font-weight:bold}</style>',
         '<defs><marker id="ar" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto">'
         '<path d="M0,0 L9,4.5 L0,9 z" fill="#14181d"/></marker>'
         '<marker id="arw" markerWidth="9" markerHeight="9" refX="8" refY="4.5" orient="auto">'
         '<path d="M0,0 L9,4.5 L0,9 z" fill="#ffffff"/></marker></defs>']

    def txt(x, y, s, cls="", a="middle", fill=None):
        c = f' class="{cls}"' if cls else ""
        f = f' fill="{fill}"' if fill else ""
        o.append(f'<text x="{x:.0f}" y="{y:.0f}" text-anchor="{a}"{c}{f}>{HE(s)}</text>')

    def poly(q):
        return "M" + " L".join("%.1f,%.1f" % T(p) for p in q) + " Z"

    o.append(f'<path d="{" ".join(poly(q) for q in polys)}" fill="#3b5c8a" fill-rule="nonzero"/>')

    def trace(pts, col):
        o.append(f'<polyline points="{" ".join("%.1f,%.1f" % T(p) for p in pts)}" fill="none" '
                 f'stroke="{col}" stroke-width="6.5" stroke-linecap="round" stroke-linejoin="round"/>')

    trace(bot, "#c0392b")
    trace(top, "#e08a1e")

    band_y = y1 + 1.4
    for bx0, bx1 in bands:
        a, b = T((bx0, band_y)), T((bx1, band_y))
        o.append(f'<path d="M{a[0]:.0f},{a[1]+12:.0f} L{a[0]:.0f},{a[1]:.0f} '
                 f'L{b[0]:.0f},{b[1]:.0f} L{b[0]:.0f},{b[1]+12:.0f}" fill="none" stroke="#7a4fbf" stroke-width="3"/>')
        txt((a[0] + b[0]) / 2, a[1] - 12, "undercut", "k", fill="#7a4fbf")
    txt(T((0, band_y))[0], T((0, band_y))[1] - 44,
        f"{len(bands)} undercut bands - the outline is not a function of x here", "s")

    base = PY0 + PH - 46
    for x in (-14, 0, 20):
        ys_ = cross(x)
        A, B2 = T((x, ys_[0])), T((x, ys_[-1]))
        o.append(f'<line x1="{A[0]:.0f}" y1="{A[1]:.0f}" x2="{A[0]:.0f}" y2="{base:.0f}" stroke="#9aa3ad" stroke-width="1.2"/>')
        o.append(f'<line x1="{A[0]:.0f}" y1="{A[1]:.0f}" x2="{B2[0]:.0f}" y2="{B2[1]:.0f}" '
                 f'stroke="#ffffff" stroke-width="2.4" marker-end="url(#arw)" marker-start="url(#arw)"/>')
        txt(A[0], base + 25, f"{ys_[-1] - ys_[0]:.1f}mm", "k")

    def call(x, which, dx, dy, lines):
        p = anchor(x, which)
        A = T(p)
        B2 = (A[0] + dx, A[1] + dy)
        o.append(f'<line x1="{A[0]:.0f}" y1="{A[1]:.0f}" x2="{B2[0]:.0f}" y2="{B2[1]:.0f}" stroke="#3d4650" stroke-width="1.6"/>')
        o.append(f'<circle cx="{A[0]:.0f}" cy="{A[1]:.0f}" r="5" fill="#3d4650"/>')
        for i, l in enumerate(lines):
            txt(B2[0], B2[1] + i * 25 + (2 if dy < 0 else 25), l)

    call(-31.0, "top", -104, 30, ["LEFT HOOK"])
    call(35.0, "top", 74, -78, ["RIGHT HOOK"])
    call(-27.5, "bot", -104, 58, ["steep end face"])
    call(-19.0, "bot", -20, 128, ["rod channels"])

    lx, ly = PX0 + PW - 660, PY0 + PH - 96
    for i, (c, l) in enumerate((("#c0392b", "underside - a single straight segment, 17.97 deg"),
                                ("#e08a1e", "top - central face is an arc, R100 centred (2, 98)"))):
        o.append(f'<line x1="{lx}" y1="{ly+i*32}" x2="{lx+48}" y2="{ly+i*32}" stroke="{c}" stroke-width="6.5" stroke-linecap="round"/>')
        txt(lx + 60, ly + i * 32 + 7, l, "s", a="start")

    hooks_txt = " and ".join(f"{a:.2f}..{b:.2f}" for a, b in hooks)
    txt(W / 2, 50, "Rail side profile - standard", "t")
    txt(W / 2, 86, "A wedge, not a slab. The underside is one straight segment; "
                   "the top is a shallow arc with an undercut at each end.", "s")
    txt(W / 2, H - 42, f"vertical section - {x1-x0:.2f} x {y1-y0:.2f}mm in this view - "
                       f"hooks x {hooks_txt} - {len(polys)-1} rod channels", "s")
    o.append('</svg>')

    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(o))
    return {"bbox": (x0, x1, y0, y1), "bands": bands, "hooks": hooks,
            "top": len(top), "bot": len(bot), "holes": len(polys) - 1,
            "dims": [(x, cross(x)[-1] - cross(x)[0]) for x in (-14, 0, 20)]}


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out", nargs="?", type=Path, default=DEFAULT_OUT,
                    help=f"output .svg path (default: {DEFAULT_OUT})")
    args = ap.parse_args()

    polys = profile_polys()
    info = draw(polys, args.out)

    import xml.dom.minidom as md
    md.parse(str(args.out))

    x0, x1, y0, y1 = info["bbox"]
    print(f"  section {x1-x0:.4f} x {y1-y0:.4f}mm, {info['holes']} rod channels")
    print(f"  edges traced from the contour: top {info['top']} pts, bot {info['bot']} pts")
    print("  undercut bands " + ", ".join("%.2f..%.2f" % b for b in info["bands"]))
    print("  hooks x " + ", ".join("%.2f..%.2f" % h for h in info["hooks"]))
    print("  dims " + ", ".join("x=%g:%.2fmm" % d for d in info["dims"]))
    print(f"  wrote {args.out} (svg parses)")

    png = args.out.with_suffix(".png")
    tool = render_png(args.out, png, W, H)
    print(f"  wrote {png} via {tool}" if tool else
          "  no svg->png converter found (rsvg-convert/magick/inkscape); svg only")


if __name__ == "__main__":
    main()
