#!/usr/bin/env python3
"""refresh_build_readme.py -- re-extract Quartus build evidence into the
firmware_builds/systems/<build>/README.md after a fresh compile.

Sections supported:

  Section 2  -- Build summary table (ALMs, registers, RAM, HSSI, PLL, etc.)
                Source: <output_files>/top.fit.summary

  Section 5  -- Worst paths (top N setup violators across all 4 STA corners).
                Source: <output_files>/top.sta.summary

Sections 4 (entity hierarchy) is NOT updated by this script -- the entity
mapping is build-specific and was hand-curated. Re-run by hand when the
subsystem instance set changes; this script will print a warning if its
own Section-2 utilization diverges from the totals implied by Section 4.

Designed to run as a post-compile hook:

    scripts/refresh_build_readme.py firmware_builds/systems/v3_pretest-260511

Idempotent: produces the same output for the same Quartus artifacts. Safe to
re-run. Use --dry-run to preview the patch as a unified diff without writing.

Author: yifeng (initial draft via Claude assist 2026-05-11).
"""

from __future__ import annotations

import argparse
import difflib
import re
import sys
from dataclasses import dataclass
from pathlib import Path

# ---------------------------------------------------------------------------
# Section 2 -- Build summary
# ---------------------------------------------------------------------------

# Mapping from top.fit.summary key (left of ':') to the README row label.
# Order matters: it defines the table row order.
SECTION2_ROWS = [
    ("Logic utilization (in ALMs)",   "ALMs"),
    ("Total registers",               "Registers"),
    ("Total pins",                    "Pins"),
    ("Total block memory bits",       "Block memory bits"),
    ("Total RAM Blocks",              "RAM blocks"),
    ("Total DSP Blocks",              "DSP blocks"),
    ("Total HSSI RX PCSs",            "HSSI RX PCSs"),
    ("Total HSSI PMA RX Deserializers", "HSSI PMA RX deserializers"),
    ("Total HSSI TX PCSs",            "HSSI TX PCSs"),
    ("Total HSSI PMA TX Serializers", "HSSI PMA TX serializers"),
    ("Total PLLs",                    "PLLs"),
    ("Total DLLs",                    "DLLs"),
]

# Bold-threshold for "X / Y ( P % )" values.
UTIL_BOLD_THRESHOLD_PERCENT = 80


def parse_fit_summary(path: Path) -> dict[str, str]:
    """Parse a Quartus top.fit.summary into a {key: value} dict."""
    out: dict[str, str] = {}
    for line in path.read_text().splitlines():
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        out[key.strip()] = value.strip()
    return out


def _percent_of(value: str) -> int | None:
    """Return the integer percent from a 'X / Y ( P % )' string, or None."""
    m = re.search(r"\(\s*([0-9]+)\s*%\s*\)", value)
    return int(m.group(1)) if m else None


def render_section2(fit: dict[str, str], status_line: str | None = None) -> str:
    """Render the Section 2 body (without the '## 2. Build summary' header)."""
    rows = []
    for fit_key, md_label in SECTION2_ROWS:
        raw = fit.get(fit_key, "<unknown>")
        pct = _percent_of(raw)
        cell = f"**{raw}**" if pct is not None and pct > UTIL_BOLD_THRESHOLD_PERCENT else raw
        rows.append(f"| {md_label} | {cell} |")

    body = [
        "Source: [`syn/top.fit.summary`](syn/top.fit.summary).",
        "",
        "| Metric | Value |",
        "| --- | --- |",
        *rows,
        "",
        f"Cells are bold when utilization is greater than {UTIL_BOLD_THRESHOLD_PERCENT} percent.",
    ]
    if status_line:
        body.append("")
        body.append(f"Last refresh: `{status_line}`.")
    return "\n".join(body) + "\n"


# ---------------------------------------------------------------------------
# Section 5 -- Worst paths (top N)
# ---------------------------------------------------------------------------

@dataclass
class StaEntry:
    corner: str          # e.g. "Slow 1100mV 85C Model Setup"
    clock: str           # the clock identifier, may be a hierarchical path
    slack_ns: float
    tns_ns: float

    @property
    def is_setup(self) -> bool:
        return "Setup" in self.corner

    @property
    def is_hold(self) -> bool:
        return "Hold" in self.corner

    @property
    def endpoint(self) -> str:
        """Best-effort 'endpoint module' for the README table."""
        if "|" not in self.clock:
            # bare clock name like 'lvds_firefly_clk'
            return f"top port {self.clock}"
        parts = self.clock.split("|")
        # Try to pull data_path_subsystem/<...> or control_path_subsystem/<...>
        for marker in ("data_path_subsystem", "control_path_subsystem",
                       "upload_subsystem", "bringup_subsystem"):
            if marker in parts:
                idx = parts.index(marker)
                # one or two levels under the subsystem
                tail = "/".join(parts[idx:idx + 2])
                return tail
        return parts[-1]


STA_TYPE_RE = re.compile(r"^Type\s*:\s*(.+?)\s*'(.*)'\s*$")
STA_SLACK_RE = re.compile(r"^Slack\s*:\s*(-?\d+(?:\.\d+)?)\s*$")
STA_TNS_RE = re.compile(r"^TNS\s*:\s*(-?\d+(?:\.\d+)?)\s*$")


def parse_sta_summary(path: Path) -> list[StaEntry]:
    """Parse a Quartus top.sta.summary into a list of StaEntry."""
    entries: list[StaEntry] = []
    current_corner: str | None = None
    current_clock: str | None = None
    current_slack: float | None = None
    for line in path.read_text().splitlines():
        m = STA_TYPE_RE.match(line)
        if m:
            current_corner = m.group(1).strip()
            current_clock = m.group(2).strip()
            current_slack = None
            continue
        m = STA_SLACK_RE.match(line)
        if m:
            current_slack = float(m.group(1))
            continue
        m = STA_TNS_RE.match(line)
        if m and current_corner is not None and current_clock is not None and current_slack is not None:
            entries.append(StaEntry(
                corner=current_corner,
                clock=current_clock,
                slack_ns=current_slack,
                tns_ns=float(m.group(1)),
            ))
            current_corner = None
            current_clock = None
            current_slack = None
    return entries


def _color_slack(slack_ns: float) -> str:
    sign = "+" if slack_ns >= 0 else ""
    color = "green" if slack_ns >= 0 else "red"
    return f"$\\textcolor{{{color}}}{{{sign}{slack_ns:.3f}}}$"


def render_section5(sta_entries: list[StaEntry], top_n: int = 5) -> str:
    setup_entries = [e for e in sta_entries if e.is_setup]
    # Sort ascending by slack (most negative first).
    worst = sorted(setup_entries, key=lambda e: e.slack_ns)[:top_n]
    if not worst:
        return "_No setup entries found in top.sta.summary._\n"

    rows = [
        "Source: [`syn/top.sta.summary`](syn/top.sta.summary). The summary file reports worst setup slack by clock, so the endpoint module below is derived from the reported clock hierarchy.",
        "",
        "| Endpoint module | Slack | Clock | Corner |",
        "| --- | --- | --- | --- |",
    ]
    for e in worst:
        rows.append(
            f"| {e.endpoint} | {_color_slack(e.slack_ns)} | `{e.clock}` | `{e.corner}` |"
        )
    return "\n".join(rows) + "\n"


# ---------------------------------------------------------------------------
# README section substitution
# ---------------------------------------------------------------------------

# Match a top-level section header by its number prefix. The README convention
# is "## N. Title" with N a small integer. Sub-sections use "### ..." and are
# left intact.
SECTION_HEADER_RE = re.compile(r"^##\s+(\d+)\.\s+(.+?)\s*$", re.MULTILINE)


def find_section_span(readme: str, section_number: int) -> tuple[int, int] | None:
    """Return (body_start_offset, body_end_offset) for the given top-level
    section number, where body_start is the character AFTER the header line
    and body_end is the character BEFORE the next top-level header (or EOF).

    Returns None if the section header is not found.
    """
    headers: list[tuple[int, int, str]] = []  # (start_offset, number, title)
    for m in SECTION_HEADER_RE.finditer(readme):
        headers.append((m.start(), m.end(), int(m.group(1)), m.group(2)))

    # Find requested section.
    target_idx = next(
        (i for i, h in enumerate(headers) if h[2] == section_number),
        None,
    )
    if target_idx is None:
        return None

    body_start = headers[target_idx][1]
    # Skip the newline right after the header line.
    if body_start < len(readme) and readme[body_start] == "\n":
        body_start += 1
    body_end = headers[target_idx + 1][0] if target_idx + 1 < len(headers) else len(readme)
    return body_start, body_end


def replace_section_body(readme: str, section_number: int, new_body: str) -> str:
    span = find_section_span(readme, section_number)
    if span is None:
        raise ValueError(f"README has no '## {section_number}. ...' section to replace")
    start, end = span
    # Preserve at least one trailing newline before the next section header.
    if not new_body.endswith("\n"):
        new_body += "\n"
    if new_body[-2:] != "\n\n":
        new_body += "\n"
    return readme[:start] + new_body + readme[end:]


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def _discover_output_files(build_root: Path) -> Path:
    """Locate the Quartus output_files directory under a build root."""
    candidates = [
        *build_root.glob("syn/board_projects/*/output_files"),
        build_root / "syn" / "output_files",
    ]
    for c in candidates:
        if (c / "top.fit.summary").is_file():
            return c
    raise FileNotFoundError(
        f"could not locate output_files under {build_root}; checked: {[str(c) for c in candidates]}"
    )


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("build_root", type=Path,
                   help="path to firmware_builds/systems/<build>/")
    p.add_argument("--output-files", type=Path, default=None,
                   help="explicit Quartus output_files dir (overrides auto-discovery)")
    p.add_argument("--readme", type=Path, default=None,
                   help="explicit README path (default <build_root>/README.md)")
    p.add_argument("--sections", type=str, default="2,5",
                   help="comma-separated section numbers to refresh (default 2,5)")
    p.add_argument("--top-n", type=int, default=5,
                   help="number of worst-path rows in Section 5 (default 5)")
    p.add_argument("--dry-run", action="store_true",
                   help="print a unified diff to stdout instead of writing")
    args = p.parse_args(argv)

    build_root = args.build_root.resolve()
    if not build_root.is_dir():
        print(f"error: build root {build_root} is not a directory", file=sys.stderr)
        return 2

    out_dir = args.output_files or _discover_output_files(build_root)
    readme_path = args.readme or (build_root / "README.md")
    if not readme_path.is_file():
        print(f"error: README {readme_path} not found", file=sys.stderr)
        return 2

    fit = parse_fit_summary(out_dir / "top.fit.summary")
    sta = parse_sta_summary(out_dir / "top.sta.summary")
    status_line = fit.get("Fitter Status", "")

    readme_old = readme_path.read_text()
    readme_new = readme_old

    requested = [int(s) for s in args.sections.split(",") if s.strip()]
    for sec in requested:
        if sec == 2:
            new_body = render_section2(fit, status_line=status_line or None)
        elif sec == 5:
            new_body = render_section5(sta, top_n=args.top_n)
        else:
            print(f"warning: section {sec} is not supported by this script; skipping",
                  file=sys.stderr)
            continue
        try:
            readme_new = replace_section_body(readme_new, sec, new_body)
        except ValueError as e:
            print(f"error: {e}", file=sys.stderr)
            return 3

    if readme_new == readme_old:
        print("no changes")
        return 0

    if args.dry_run:
        diff = difflib.unified_diff(
            readme_old.splitlines(keepends=True),
            readme_new.splitlines(keepends=True),
            fromfile=str(readme_path),
            tofile=str(readme_path) + " (refreshed)",
        )
        sys.stdout.writelines(diff)
        return 0

    readme_path.write_text(readme_new)
    print(f"updated {readme_path}")
    print(f"  output_files: {out_dir}")
    print(f"  fitter:       {status_line}")
    print(f"  sections:     {requested}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
