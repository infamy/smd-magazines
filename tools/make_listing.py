#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
"""
Turn the listing descriptions into text that survives a paste.

  ./tools/make_listing.py           writes publish/*.txt beside the .md

Printables and MakerWorld both use rich-text editors, not markdown fields, and
pasting the .md files into them goes wrong twice over:

  * markdown is not interpreted, so **bold**, ## headings, backticks, tables
    and [links](url) all arrive as literal punctuation;

  * every hard line break is honoured as a break. The .md files are wrapped at
    80 columns for reading in a terminal, so a paragraph pastes in as eight
    separate lines and the editor's own wrapping has nothing left to do. Resize
    the window and the text does not reflow, because those are real newlines.

So the paragraphs are unwrapped to one line each - which is what a rich-text
editor wants - and the markup is reduced to something that reads correctly as
plain prose. Headings stay on their own line so they can be styled by hand
afterwards if you care to.

The .md files stay the source: they are the readable, diffable, reviewable
version, and these are disposable output.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = ["printables.md", "makerworld.md"]


def strip_inline(s):
    s = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1: \2", s)   # links -> text: url
    s = re.sub(r"`([^`]+)`", r"\1", s)                      # code spans
    s = re.sub(r"\*\*([^*]+)\*\*", r"\1", s)                # bold
    s = re.sub(r"(?<![*\w])\*([^*]+)\*(?!\w)", r"\1", s)    # italic
    s = s.replace("&mdash;", "—").replace("&nbsp;", " ")
    s = s.replace("‑", "-")                            # non-breaking hyphen
    return s.strip()


# Title and Summary are their own fields on the upload form, not part of the
# description body, so they come out separately rather than as headings in the
# middle of the text someone is about to paste into the wrong box.
FIELD_HEADINGS = {"title", "summary", "description"}


def convert(md):
    """Everything before the first '## Title' is notes to me, not the listing."""
    i = md.find("## Title")
    body = md[i:] if i >= 0 else md

    fields, current = {}, None
    out, buf = [], []

    def flush():
        if not buf:
            return
        text = strip_inline(" ".join(buf))             # the unwrap
        if current in ("title", "summary") and current not in fields:
            fields[current] = text
        else:
            out.append(text)
        buf.clear()

    for raw in body.split("\n"):
        line = raw.rstrip()

        if not line.strip():
            flush()
            if out and out[-1] != "":
                out.append("")
            continue

        if re.match(r"^#{1,4}\s", line):
            flush()
            head = strip_inline(re.sub(r"^#{1,4}\s+", "", line))
            if head.lower() in FIELD_HEADINGS:
                current = head.lower()          # its own form field, not a heading
                continue
            current = None
            if out and out[-1] != "":
                out.append("")
            out.append(head)
            out.append("")
            continue

        if re.match(r"^---+\s*$", line):        # rules do not survive a paste
            flush()
            continue

        m = re.match(r"^\s*[-*]\s+(.*)$", line)
        if m:
            flush()
            out.append("• " + strip_inline(m.group(1)))
            continue

        # a wrapped continuation of the list item above it
        if out and out[-1].startswith("• ") and raw.startswith("  ") and not buf:
            out[-1] += " " + strip_inline(line)
            continue

        buf.append(line.strip())

    flush()
    while out and out[-1] == "":
        out.pop()
    while out and out[0] == "":
        out.pop(0)

    head = []
    if "title" in fields:
        head += ["--- TITLE (its own field on the upload form) ---",
                 fields["title"], ""]
    if "summary" in fields:
        head += ["--- SUMMARY (its own field) ---", fields["summary"], ""]
    head += ["--- DESCRIPTION (everything below goes in the description box) ---",
             ""]
    return "\n".join(head + out) + "\n"


def main():
    wrote = 0
    for name in SOURCES:
        src = ROOT / "publish" / name
        if not src.exists():
            print(f"  missing {src}")
            continue
        dst = src.with_suffix(".txt")
        text = convert(src.read_text())
        dst.write_text(text, newline="\n")          # LF, never CRLF
        longest = max((len(l) for l in text.split("\n")), default=0)
        paras = sum(1 for l in text.split("\n") if l.strip())
        print(f"  {dst.name:22} {paras:3} blocks, longest line {longest}, "
              f"{'no markdown left' if not re.search(r'[*`#|]', text) else 'CHECK: markup remains'}")
        wrote += 1
    if not wrote:
        sys.exit("nothing to convert")
    print()
    print("  Paste these, not the .md. Headings are plain lines - style them in")
    print("  the editor if you want them bold.")


if __name__ == "__main__":
    main()
