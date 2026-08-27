#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Render publish/instructions.md to a PDF for the model listings.

  ./tools/make_pdf.py [out.pdf]

Printables and MakerWorld both take a PDF alongside the model files, and that
document has a different job from the README: it is read by someone who has
already downloaded the thing and wants to build it, not by someone deciding
whether the repository is worth their time.

There is no pandoc or weasyprint here, and adding one to print a single page
would be a poor trade. Chrome is already on any machine that slices, and
--headless --print-to-pdf is a competent renderer. The markdown subset below is
only what instructions.md actually uses; it is deliberately not a general
markdown parser, and it will quietly mangle anything cleverer.
"""

import html as _html
import re
import shutil
import subprocess
import sys
import time
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
SRC = ROOT / "publish" / "instructions.md"
DEFAULT_OUT = ROOT / "publish" / "SMD-magazines-instructions.pdf"

CHROME = next(
    (p for p in (
        "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
        "/Applications/Chromium.app/Contents/MacOS/Chromium",
        shutil.which("google-chrome") or "",
        shutil.which("chromium") or "",
    ) if p and Path(p).exists()),
    None,
)


def inline(s):
    """Bold, code, links. Escape first so the source cannot inject markup."""
    s = _html.escape(s)
    s = re.sub(r"`([^`]+)`", r"<code>\1</code>", s)
    s = re.sub(r"\*\*([^*]+)\*\*", r"<strong>\1</strong>", s)
    s = re.sub(r"(?<![*\w])\*([^*]+)\*(?!\w)", r"<em>\1</em>", s)
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', s)
    s = re.sub(r"&lt;(https?://[^&]+)&gt;", r'<a href="\1">\1</a>', s)
    return s


def convert(md):
    out, i = [], 0
    lines = md.split("\n")
    while i < len(lines):
        ln = lines[i]

        if re.match(r"^---+\s*$", ln):
            out.append("<hr>"); i += 1; continue

        m = re.match(r"^(#{1,4})\s+(.*)$", ln)
        if m:
            n = len(m.group(1))
            out.append(f"<h{n}>{inline(m.group(2))}</h{n}>"); i += 1; continue

        # table: a header row, a separator, then body rows
        if ln.startswith("|") and i + 1 < len(lines) and re.match(r"^\|[\s:|-]+\|?\s*$", lines[i+1]):
            head = [c.strip() for c in ln.strip().strip("|").split("|")]
            i += 2
            body = []
            while i < len(lines) and lines[i].startswith("|"):
                body.append([c.strip() for c in lines[i].strip().strip("|").split("|")])
                i += 1
            has_head = any(h for h in head)
            t = ["<table>"]
            if has_head:
                t.append("<thead><tr>" + "".join(f"<th>{inline(c)}</th>" for c in head) + "</tr></thead>")
            t.append("<tbody>")
            for row in body:
                t.append("<tr>" + "".join(f"<td>{inline(c)}</td>" for c in row) + "</tr>")
            t.append("</tbody></table>")
            out.append("".join(t)); continue

        # lists, ordered and not
        m = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", ln)
        if m:
            ordered = bool(re.match(r"\d+\.", m.group(2)))
            tag = "ol" if ordered else "ul"
            items = []
            while i < len(lines):
                m2 = re.match(r"^(\s*)([-*]|\d+\.)\s+(.*)$", lines[i])
                if not m2:
                    # a plain indented line continues the item above it
                    if items and lines[i].startswith("  ") and lines[i].strip():
                        items[-1] += " " + inline(lines[i].strip()); i += 1; continue
                    break
                items.append(inline(m2.group(3))); i += 1
            out.append(f"<{tag}>" + "".join(f"<li>{x}</li>" for x in items) + f"</{tag}>")
            continue

        if not ln.strip():
            i += 1; continue

        para = []
        while i < len(lines) and lines[i].strip() and not re.match(r"^(#|\||---+\s*$|\s*([-*]|\d+\.)\s)", lines[i]):
            para.append(lines[i].strip()); i += 1
        if para:
            out.append("<p>" + inline(" ".join(para)) + "</p>")
    return "\n".join(out)


CSS = """
@page { size: A4; margin: 18mm 16mm 16mm; }
* { box-sizing: border-box; }
body { font: 10.5pt/1.55 -apple-system, "Helvetica Neue", Arial, sans-serif;
       color: #16191b; margin: 0; }
h1 { font-size: 22pt; letter-spacing: -.01em; margin: 0 0 2mm; }
h2 { font-size: 13pt; margin: 8mm 0 2mm; padding-bottom: 1.5mm;
     border-bottom: .4pt solid #c9d1d3; break-after: avoid; }
h3 { font-size: 11pt; margin: 5mm 0 1.5mm; break-after: avoid; }
p, li { max-width: 62em; }
p { margin: 0 0 2.6mm; }
ul, ol { margin: 0 0 3mm; padding-left: 5mm; }
li { margin: 0 0 1.4mm; }
hr { border: 0; border-top: .4pt solid #c9d1d3; margin: 6mm 0; }
a { color: #0c6f79; text-decoration: none; }
code { font: 9.5pt ui-monospace, "SF Mono", Menlo, monospace;
       background: #eef2f2; padding: .3mm 1mm; border-radius: .6mm; }
table { border-collapse: collapse; width: 100%; margin: 0 0 4mm;
        font-size: 9.5pt; break-inside: avoid; }
th { text-align: left; font-size: 8pt; letter-spacing: .08em;
     text-transform: uppercase; color: #5b686c; border-bottom: .4pt solid #a9b3b6;
     padding: 1.5mm 3mm 1.5mm 0; }
td { border-bottom: .3pt solid #dde3e4; padding: 1.8mm 3mm 1.8mm 0;
     vertical-align: top; }
strong { font-weight: 600; }
"""


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT
    if not SRC.exists():
        sys.exit(f"missing {SRC}")
    if not CHROME:
        sys.exit("no Chrome or Chromium found; it is what renders the PDF")

    doc = ("<!doctype html><html><head><meta charset='utf-8'>"
           "<title>SMD Component Tape Magazines</title>"
           f"<style>{CSS}</style></head><body>{convert(SRC.read_text())}</body></html>")

    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()

    with tempfile.TemporaryDirectory() as td:
        page = Path(td) / "doc.html"
        page.write_text(doc)
        # A throwaway profile keeps this out of the real browser's session.
        #
        # Chrome writes the PDF and then does not exit: on macOS its auto-updater
        # keeps the process alive well past the render. Waiting for exit means
        # waiting forever for a file that is already on disk, so watch the file
        # instead - it is done when it stops growing - and then end the process.
        proc = subprocess.Popen(
            [CHROME, "--headless=new", "--disable-gpu", "--no-sandbox",
             "--no-first-run", "--disable-background-networking",
             "--disable-component-update", "--disable-sync",
             f"--user-data-dir={td}/profile", "--no-pdf-header-footer",
             f"--print-to-pdf={out}", page.as_uri()],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
        size, stable, waited = -1, 0, 0.0
        while waited < 60:
            time.sleep(0.4); waited += 0.4
            now = out.stat().st_size if out.exists() else -1
            stable = stable + 1 if now == size and now > 0 else 0
            size = now
            if stable >= 3:              # unchanged for ~1.2s: finished
                break
            if proc.poll() is not None and now > 0:
                break
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()

    if not out.exists() or out.stat().st_size == 0:
        sys.exit("Chrome produced nothing")
    print(f"{out}  ({out.stat().st_size/1024:.0f} KB)")


if __name__ == "__main__":
    main()
