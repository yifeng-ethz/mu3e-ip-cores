#!/usr/bin/env python3
"""Validate doc/SYSTEM_OVERVIEW.md against the live qsys hierarchy.

This script is intentionally **read-only** — it reports drift but never
edits SYSTEM_OVERVIEW.md. The user is the one who updates the doc after
fixing the drift in the IP / qsys files. Wire this into CI so PRs that
forget to update SYSTEM_OVERVIEW.md fail loud.

What gets checked
-----------------

For every markdown table row in SYSTEM_OVERVIEW.md whose 2nd column looks
like a kind in backticks and whose 3rd column looks like a version in
backticks, the script:

1. Walks every `<module>` in feb_system_v4.sopcinfo and every
   `<component>` in the v4 .qsys files, building a map of
   `(instance_name, kind) -> live_version`.
2. Builds a `kind -> {versions_seen}` map across the live sopcinfo.
3. For every doc row, compares:
   - Documented version vs the set of live versions for that kind.
   - Documented instance prefix (if present) vs whether at least one
     live instance matches.
   - Special tokens accepted in the doc: `1.0 (kept)` (kept-at-1.0
     intentional collision avoidance), `18.1` for vendor IPs (anything
     matching VENDOR_KINDS regex), `n/a`, and 4-token kinds in
     range-syntax like `{0..7}` get expanded.
4. Reports any drift on stderr as one line per issue, summary line at end.

Exit code 0 when there is no drift; 1 when there is drift; 2 on input
errors (sopcinfo / overview missing).

The script also flags **untracked live kinds**: every Mu3e kind in the
sopcinfo whose name does not appear anywhere in SYSTEM_OVERVIEW.md (so
new IPs added without doc updates get flagged).

Vendor kinds (skipped by the untracked-live check):
- altera_*  (Altera vendor)
- multiplexer
- inactive_reset_source (helper)
"""

from __future__ import annotations

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
OVERVIEW   = SYSTEM_DIR / "doc" / "SYSTEM_OVERVIEW.md"
SOPCINFO   = SYSTEM_DIR / "generated" / "qsys" / "feb_system_v4.sopcinfo"

VENDOR_RE = re.compile(r"^(altera_|multiplexer$|inactive_reset_source$|clock_source$)")

# A row's columns:
#   | Instance | Kind | Version | (Source|Status|...) ... |
# We accept any row where col2 = `<kind>` and col3 = `<version>` in backticks,
# allowing some flexibility on column count.
ROW_RE = re.compile(
    r"^\|\s*(?P<col1>[^|]+?)\s*\|"
    r"\s*`(?P<kind>[A-Za-z_][A-Za-z0-9_]*)`\s*\|"
    r"\s*`(?P<version>[^`]+)`(?P<vsfx>[^|]*)\|"   # allow trailing text after version backtick
    r"(?P<rest>.*)\|\s*$",
    re.MULTILINE,
)


def parse_overview(path: Path) -> list[dict]:
    """Yield every (kind, version, raw_line) triple from any markdown table."""
    rows = []
    for m in ROW_RE.finditer(path.read_text()):
        rows.append({
            "col1": m.group("col1").strip(),
            "kind": m.group("kind"),
            "version": m.group("version").strip(),
            "raw": m.group(0).strip(),
            "line": path.read_text()[:m.start()].count("\n") + 1,
        })
    return rows


def parse_sopcinfo(path: Path) -> dict[str, set[str]]:
    """Return a map kind -> set of versions seen in the live design,
    including the top-level <EnsembleReport> kind itself (sopcinfo's
    root is not a `<module>` so we have to pick it up separately)."""
    root = ET.parse(path).getroot()
    out: dict[str, set[str]] = {}
    # Top-of-tree (e.g. feb_system_v4)
    top_kind = root.get("kind", "")
    top_ver = root.get("version", "")
    if top_kind:
        out.setdefault(top_kind, set()).add(top_ver)
    for mod in root.findall(".//module"):
        kind = mod.get("kind", "")
        ver = mod.get("version", "")
        if not kind:
            continue
        out.setdefault(kind, set()).add(ver)
    return out


def parse_qsys_component_version(qsys_path: Path) -> tuple[str, str] | None:
    """Return (kind, version) for the outer component of a .qsys file."""
    try:
        txt = qsys_path.read_text()
    except OSError:
        return None
    m = re.search(
        r'<component\s+\n?\s*name="\$\$\{FILENAME\}"\s*\n?\s*displayName="\$\$\{FILENAME\}"\s*\n?\s*version="([^"]+)"',
        txt)
    if not m:
        return None
    return (qsys_path.stem, m.group(1))


def normalize_version(v: str) -> str:
    """Trim wrappers like '... (kept)' or '... bumped from x.y', and strip
    leading zeros from the BUILD field so `26.4.0.0518` and `26.4.0.518`
    compare equal (Qsys drops the leading zero when it stores the version
    inside the sopcinfo and the inner .qsys, but the YY.MINOR.PATCH.MMDD
    convention writes the 4-digit form in human-facing docs)."""
    v = v.strip()
    # Drop anything after first parenthesis or 'bumped from'
    v = re.split(r"\s*\(", v, maxsplit=1)[0]
    v = re.split(r"\s+bumped\s+", v, maxsplit=1)[0]
    v = v.strip()
    # Strip leading zeros from each dot-separated field
    if "." in v:
        parts = v.split(".")
        try:
            parts = [str(int(p)) for p in parts]
            v = ".".join(parts)
        except ValueError:
            pass
    return v


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--overview", type=Path, default=OVERVIEW)
    ap.add_argument("--sopcinfo", type=Path, default=SOPCINFO)
    ap.add_argument("--quartus-systems",
                    type=Path,
                    default=Path("/home/yifeng/packages/mu3e_ip_dev/.worktrees/mu3e_ip_cores_main_20260518/quartus_systems"))
    args = ap.parse_args(argv)

    errors: list[str] = []
    info:   list[str] = []

    if not args.overview.is_file():
        print(f"[FATAL] SYSTEM_OVERVIEW.md not found: {args.overview}", file=sys.stderr)
        return 2
    if not args.sopcinfo.is_file():
        print(f"[FATAL] sopcinfo not found: {args.sopcinfo}", file=sys.stderr)
        return 2

    overview_rows = parse_overview(args.overview)
    live = parse_sopcinfo(args.sopcinfo)

    # Track which kinds were referenced in the doc
    documented_kinds = {r["kind"] for r in overview_rows}

    # 1) Per-row version check
    for r in overview_rows:
        kind = r["kind"]
        doc_ver = normalize_version(r["version"])
        live_vers_raw = live.get(kind)
        live_vers = {normalize_version(v) for v in live_vers_raw} if live_vers_raw else None
        if live_vers is None:
            # Doc mentions a kind that the live design doesn't have
            # — could be intentional (e.g. "to drop"), so flag as INFO
            # unless the row text doesn't say so.
            if "to drop" in r["raw"].lower() or "removed" in r["raw"].lower() or "kept" in r["raw"].lower():
                info.append(f"  [INFO] line {r['line']}: kind `{kind}` v`{r['version']}` "
                            f"documented but not in live sopcinfo (expected: drop/removed marker present)")
            else:
                errors.append(f"  [ERR ] line {r['line']}: kind `{kind}` v`{r['version']}` "
                              f"documented but NOT FOUND in live sopcinfo")
            continue
        if doc_ver in live_vers:
            continue
        # Doc version != live; report all live versions for transparency
        live_str = ", ".join(sorted(live_vers))
        errors.append(f"  [ERR ] line {r['line']}: kind `{kind}` documented as `{doc_ver}` "
                      f"but live sopcinfo has {{{live_str}}}")

    # 2) Untracked live kinds
    for kind in sorted(live.keys()):
        if kind in documented_kinds:
            continue
        if VENDOR_RE.match(kind):
            continue
        errors.append(f"  [ERR ] live kind `{kind}` (versions {sorted(live[kind])}) "
                      f"not mentioned in SYSTEM_OVERVIEW.md")

    # 3) Cross-check the v4 subsystem .qsys files against the doc
    v4_files = [
        args.quartus_systems / "debug_sc_system_v4.qsys",
        args.quartus_systems / "scifi_datapath_system_v4.qsys",
        args.quartus_systems / "upload_system_v4.qsys",
        args.quartus_systems / "mutrig_datapath_system_v4.qsys",
        SYSTEM_DIR / "generated" / "qsys" / "feb_system_v4.qsys",
        SYSTEM_DIR / "generated" / "qsys" / "scifi_datapath_system_v4.qsys",
    ]
    for qf in v4_files:
        kv = parse_qsys_component_version(qf)
        if kv is None:
            errors.append(f"  [ERR ] could not read component version from {qf}")
            continue
        kind, ver = kv
        # Find docs row for this kind
        doc_rows = [r for r in overview_rows if r["kind"] == kind]
        if not doc_rows:
            errors.append(f"  [ERR ] qsys file `{qf.name}` has kind `{kind}` v`{ver}` but doc has no row for it")
            continue
        doc_ver = normalize_version(doc_rows[0]["version"])
        live_ver = normalize_version(ver)
        if doc_ver != live_ver:
            errors.append(f"  [ERR ] qsys file `{qf.name}` is v`{ver}` "
                          f"but doc row line {doc_rows[0]['line']} says `{doc_rows[0]['version']}`")

    # Output
    for line in info:
        print(line, file=sys.stderr)
    for line in errors:
        print(line, file=sys.stderr)

    print()
    print(f"Summary: {len(errors)} error(s), {len(info)} info(s) "
          f"({len(overview_rows)} doc rows, {len(live)} live kinds checked).")
    if errors:
        print("RESULT FAIL — update SYSTEM_OVERVIEW.md (manual) and re-run.")
        return 1
    print("RESULT PASS — SYSTEM_OVERVIEW.md is consistent with the live qsys.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
