#!/usr/bin/env python3
"""Fail-loud checker that bans matplotlib / seaborn / plotly from any cotest
plot generator. Per the workspace house rule, only the DISLIN-based
`scientific-plotting` skill is allowed for cosim / sweep / lifetime plots.

Usage:
    python3 scripts/cotest/check_no_python_plotting.py [--strict] [<dir-or-file> ...]

With no arguments, defaults to scanning scripts/cotest/ recursively.

Default mode is WARN (exit 0 even when offenders are found, but prints them
clearly to stderr). Use `--strict` to make CI fail on any offender (exit 1).
Files that carry a top-of-file `# ALLOW_MATPLOTLIB_LEGACY` marker are
classified as "legacy" and tagged in the report but never block --strict.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

BANNED = (
    "matplotlib",
    "seaborn",
    "plotly",
    "pyplot",
    "pylab",
    "bokeh",
    "altair",
    "holoviews",
)
PATTERN = re.compile(
    r"^\s*(?:from\s+(" + "|".join(BANNED) + r")[\.\s]|import\s+(" + "|".join(BANNED) + r")(?:\s|$|,|\.))",
    re.MULTILINE,
)
SCAN_EXT = {".py", ".pyi", ".pyw"}


def scan_file(path: Path) -> list[tuple[int, str]]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    hits: list[tuple[int, str]] = []
    for idx, line in enumerate(text.splitlines(), start=1):
        if PATTERN.search(line):
            hits.append((idx, line.strip()))
    return hits


def is_legacy(path: Path) -> bool:
    try:
        head = path.read_text(encoding="utf-8", errors="ignore").splitlines()[:30]
    except OSError:
        return False
    return any("ALLOW_MATPLOTLIB_LEGACY" in line for line in head)


def main(argv: list[str]) -> int:
    strict = False
    args = list(argv)
    if "--strict" in args:
        strict = True
        args.remove("--strict")

    repo_root = Path(__file__).resolve().parents[2]
    targets: list[Path] = []
    if args:
        targets = [Path(a).resolve() for a in args]
    else:
        targets = [repo_root / "scripts" / "cotest"]

    files: list[Path] = []
    for t in targets:
        if t.is_file():
            files.append(t)
        elif t.is_dir():
            for p in t.rglob("*"):
                if p.suffix in SCAN_EXT:
                    files.append(p)

    # Exclude this checker itself
    self_path = Path(__file__).resolve()
    files = [f for f in files if f.resolve() != self_path]

    offenders: list[tuple[Path, int, str, bool]] = []
    for f in files:
        legacy = is_legacy(f)
        for ln, line in scan_file(f):
            offenders.append((f, ln, line, legacy))

    if not offenders:
        print(f"[OK] No banned plotting imports across {len(files)} python file(s).")
        return 0

    blocking = [o for o in offenders if not o[3]]
    level = "FAIL" if (strict and blocking) else "WARN"
    print(f"[{level}] Banned plotting library imports found (DISLIN only):", file=sys.stderr)
    for path, ln, line, legacy in offenders:
        rel = path.relative_to(repo_root) if path.is_absolute() and path.is_relative_to(repo_root) else path
        tag = " [LEGACY]" if legacy else ""
        print(f"  {rel}:{ln}{tag}: {line}", file=sys.stderr)
    print("", file=sys.stderr)
    print(
        "Plot generators must use the DISLIN-based scientific-plotting "
        "skill (`~/.codex/skills/scientific-plotting/SKILL.md`). "
        "Reimplement the plot in DISLIN (PDF output preferred). "
        "Legacy files may carry a top-of-file `# ALLOW_MATPLOTLIB_LEGACY` "
        "marker to defer migration; they still print as warnings.",
        file=sys.stderr,
    )
    return 1 if (strict and blocking) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
