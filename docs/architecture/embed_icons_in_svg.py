#!/usr/bin/env python3
"""
embed_icons_in_svg.py — make a Graphviz/diagrams SVG fully self-contained.

THE PROBLEM
-----------
When the `diagrams` library renders an SVG, every node icon is written as an
absolute path reference to a file inside your local Python install, e.g.:

    <image xlink:href="C:\\Users\\you\\AppData\\...\\site-packages\\resources/aws/compute\\lambda.png" .../>

That path only exists on the machine that generated the file. Open the SVG on
any other computer, commit it to GitHub, or drop it in a slide deck, and every
icon shows up as a broken/empty box because the referenced file isn't there.

THE FIX
-------
This script rewrites every local image reference into an inline base64 `data:`
URI, so the pixels live inside the SVG itself. The result has zero external
dependencies and renders identically everywhere.

    <image xlink:href="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAA..." .../>

USAGE
-----
As a CLI:
    python embed_icons_in_svg.py docs/architecture.svg
    python embed_icons_in_svg.py docs/architecture.svg -o docs/architecture.portable.svg
    python embed_icons_in_svg.py *.svg          # shells expand the glob

As a library (import it from your generator script):
    from embed_icons_in_svg import embed_icons_in_svg
    embed_icons_in_svg("docs/architecture.svg")

DESIGN NOTES
------------
- Idempotent: references that are already `data:` URIs are left untouched, so
  running it twice is safe.
- Skips remote refs (`http://`, `https://`, `//`) and in-document anchors (`#id`).
- Handles `href` and `xlink:href`, single or double quotes.
- Understands `file://` URIs and percent-encoded paths (spaces as %20, etc.).
- Caches reads, so an icon used by ten nodes is encoded once.
- Warns and leaves the reference alone if a file is missing instead of crashing,
  so one bad path never loses you the whole diagram.
- Pure standard library. No third-party imports.
"""
from __future__ import annotations

import argparse
import base64
import glob
import mimetypes
import os
import re
import sys
import urllib.parse
import urllib.request

# Matches href="..." or xlink:href='...', capturing the attribute name, the
# quote character, and the reference value. Non-greedy value match stays inside
# one attribute. re.DOTALL is not needed: attribute values never span newlines
# in graphviz output, and avoiding it keeps the match tight.
_HREF_RE = re.compile(r"""(?P<attr>\b(?:xlink:href|href))\s*=\s*(?P<q>["'])(?P<val>.*?)(?P=q)""")

# References we must never try to inline.
_SKIP_PREFIXES = ("data:", "http://", "https://", "//", "#")

# Extension -> MIME, for the data URI. mimetypes covers most; this fills gaps.
_MIME_OVERRIDES = {
    ".svg": "image/svg+xml",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
    ".ico": "image/x-icon",
}


def _guess_mime(path: str) -> str:
    ext = os.path.splitext(path)[1].lower()
    if ext in _MIME_OVERRIDES:
        return _MIME_OVERRIDES[ext]
    guessed, _ = mimetypes.guess_type(path)
    return guessed or "application/octet-stream"


def _ref_to_local_path(ref: str, svg_dir: str) -> str | None:
    """Turn an SVG href value into a filesystem path, or None if it isn't one.

    Handles:
      - plain absolute/relative paths, including Windows paths with spaces
      - mixed separators (graphviz emits e.g. ...site-packages\\resources/aws/...)
      - file:// URIs
      - percent-encoded characters (%20 -> space)
    """
    ref = ref.strip()
    if not ref or ref.startswith(_SKIP_PREFIXES):
        return None

    # file:// URI -> real path.
    if ref.lower().startswith("file:"):
        parsed = urllib.parse.urlparse(ref)
        local = urllib.request.url2pathname(parsed.path)
        return local

    # Percent-decode (graphviz sometimes escapes spaces). A bare Windows path
    # like C:\Users\... has no percent signs, so this is a no-op for it. Guard
    # against accidentally decoding a literal '%' that isn't an escape by only
    # decoding when a valid %XX sequence is present.
    if re.search(r"%[0-9A-Fa-f]{2}", ref):
        ref = urllib.parse.unquote(ref)

    # Normalize mixed separators to the OS separator so os.path works.
    candidate = ref.replace("\\", os.sep).replace("/", os.sep)

    if not os.path.isabs(candidate):
        candidate = os.path.join(svg_dir, candidate)

    return os.path.normpath(candidate)


def embed_icons_in_svg(
    svg_path: str,
    output_path: str | None = None,
    *,
    verbose: bool = True,
) -> int:
    """Rewrite local image references in an SVG into inline base64 data URIs.

    Args:
        svg_path: path to the SVG to process.
        output_path: where to write the result. Defaults to overwriting svg_path.
        verbose: print a short per-file summary.

    Returns:
        The number of references successfully inlined.
    """
    if not os.path.isfile(svg_path):
        raise FileNotFoundError(f"SVG not found: {svg_path}")

    with open(svg_path, "r", encoding="utf-8") as fh:
        svg = fh.read()

    svg_dir = os.path.dirname(os.path.abspath(svg_path))
    cache: dict[str, str] = {}        # local path -> data URI
    stats = {"inlined": 0, "skipped": 0, "missing": 0, "already": 0}

    def _replace(match: re.Match) -> str:
        attr = match.group("attr")
        quote = match.group("q")
        ref = match.group("val")

        if ref.startswith("data:"):
            stats["already"] += 1
            return match.group(0)

        local = _ref_to_local_path(ref, svg_dir)
        if local is None:
            stats["skipped"] += 1
            return match.group(0)

        if local in cache:
            data_uri = cache[local]
        else:
            if not os.path.isfile(local):
                stats["missing"] += 1
                if verbose:
                    print(f"  warning: icon not found, left as-is: {local}", file=sys.stderr)
                return match.group(0)
            with open(local, "rb") as img:
                encoded = base64.b64encode(img.read()).decode("ascii")
            data_uri = f"data:{_guess_mime(local)};base64,{encoded}"
            cache[local] = data_uri

        stats["inlined"] += 1
        return f'{attr}={quote}{data_uri}{quote}'

    new_svg = _HREF_RE.sub(_replace, svg)

    out = output_path or svg_path
    with open(out, "w", encoding="utf-8") as fh:
        fh.write(new_svg)

    if verbose:
        print(
            f"{os.path.basename(svg_path)} -> {os.path.basename(out)}: "
            f"{stats['inlined']} inlined, {stats['already']} already inline, "
            f"{stats['skipped']} external/skipped, {stats['missing']} missing"
        )
    return stats["inlined"]


def _expand_inputs(patterns: list[str]) -> list[str]:
    """Expand globs the shell may not have (Windows cmd doesn't)."""
    files: list[str] = []
    for pat in patterns:
        matches = glob.glob(pat)
        files.extend(matches if matches else [pat])
    # De-dupe while preserving order.
    seen: set[str] = set()
    ordered: list[str] = []
    for f in files:
        if f not in seen:
            seen.add(f)
            ordered.append(f)
    return ordered


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Inline local icon references in an SVG as base64 data URIs "
        "so the file is portable.",
    )
    parser.add_argument("svg", nargs="+", help="SVG file(s) or glob(s) to process")
    parser.add_argument(
        "-o", "--output",
        help="output path (only valid with a single input; default overwrites in place)",
    )
    parser.add_argument("-q", "--quiet", action="store_true", help="suppress per-file output")
    args = parser.parse_args(argv)

    inputs = _expand_inputs(args.svg)
    if not inputs:
        print("No input SVG files matched.", file=sys.stderr)
        return 1
    if args.output and len(inputs) > 1:
        print("-o/--output cannot be used with multiple input files.", file=sys.stderr)
        return 2

    total = 0
    failures = 0
    for svg_file in inputs:
        try:
            total += embed_icons_in_svg(
                svg_file,
                args.output if len(inputs) == 1 else None,
                verbose=not args.quiet,
            )
        except (FileNotFoundError, OSError, UnicodeDecodeError) as err:
            print(f"error processing {svg_file}: {err}", file=sys.stderr)
            failures += 1

    if not args.quiet:
        print(f"Total references inlined: {total}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
