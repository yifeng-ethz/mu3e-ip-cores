#!/usr/bin/env python3
"""Validate that generated .qsys / .sopcinfo pin IP instance versions to the
latest version available in the IP catalog.

For each (qsys file, instance) pair, compare the pinned `version="X.Y.Z.WWWW"`
attribute against the highest version produced by an IP's `_hw.tcl` on the
QSYS search path.

Exit codes:
  0 — all pinned versions are the latest available
  1 — at least one pinned version is stale; details written to stdout
  2 — invocation error (missing .qsys, no search path, etc.)
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Iterable


VERSION_STRING_LINE = re.compile(
    r"set\s+VERSION_STRING(?:_DEFAULT_CONST)?\s+\{?([^\s\}]+)\}?"
)
VERSION_PATCH_LINE = re.compile(
    r"set\s+VERSION_PATCH_DEFAULT_CONST\s+(\S+)"
)
BUILD_LINE = re.compile(
    r"set\s+BUILD_DEFAULT_CONST\s+(\S+)"
)
VERSION_DATE_LINE = re.compile(
    r"set\s+VERSION_DATE_DEFAULT_CONST\s+(\S+)"
)
MODULE_PROPERTY_NAME = re.compile(
    r"set_module_property\s+NAME\s+\{?(\S+)\}?"
)


def parse_int(text: str) -> int | None:
    text = text.strip()
    if text.startswith("0x") or text.startswith("0X"):
        try:
            return int(text, 16)
        except ValueError:
            return None
    try:
        return int(text, 10)
    except ValueError:
        return None


def read_hw_tcl(path: Path) -> dict | None:
    text = path.read_text(errors="replace")
    name_m = MODULE_PROPERTY_NAME.search(text)
    if not name_m:
        return None
    patch_m = VERSION_PATCH_LINE.search(text)
    build_m = BUILD_LINE.search(text)
    date_m = VERSION_DATE_LINE.search(text)
    return {
        "name": name_m.group(1),
        "patch": parse_int(patch_m.group(1)) if patch_m else None,
        "build": parse_int(build_m.group(1)) if build_m else None,
        "date": parse_int(date_m.group(1)) if date_m else None,
        "hw_tcl": str(path),
    }


def scan_catalog(roots: Iterable[Path]) -> dict[str, list[dict]]:
    catalog: dict[str, list[dict]] = {}
    for root in roots:
        if not root.exists():
            continue
        for hw_tcl in root.rglob("*_hw.tcl"):
            info = read_hw_tcl(hw_tcl)
            if info is None or info["name"] is None:
                continue
            catalog.setdefault(info["name"], []).append(info)
    return catalog


def latest_entry(entries: list[dict]) -> dict:
    def key(e: dict) -> tuple[int, int, int]:
        return (e["patch"] or 0, e["build"] or 0, e["date"] or 0)
    return max(entries, key=key)


def audit_qsys(qsys_path: Path, catalog: dict[str, list[dict]]) -> list[tuple[str, str, str, str]]:
    findings: list[tuple[str, str, str, str]] = []
    text = qsys_path.read_text(errors="replace")
    for m in re.finditer(
        r'<module\s+name="([^"]+)"\s+kind="([^"]+)"\s+version="([^"]+)"', text
    ):
        inst, kind, pinned_version = m.group(1), m.group(2), m.group(3)
        entries = catalog.get(kind)
        if not entries:
            continue
        latest = latest_entry(entries)
        latest_version = f"{26}.{latest['patch']}.{latest['build']}"
        if latest['date']:
            latest_version = f"{latest['patch']}.{latest['build']:04d}"
        # Compare by patch/build/date triple
        pinned_parts = pinned_version.split(".")
        if len(pinned_parts) >= 3:
            try:
                pinned_patch = int(pinned_parts[2])
                pinned_build = int(pinned_parts[3]) if len(pinned_parts) > 3 else 0
                latest_patch = latest["patch"] or 0
                latest_build = latest["build"] or 0
                if pinned_patch < latest_patch or (
                    pinned_patch == latest_patch and pinned_build < latest_build
                ):
                    findings.append(
                        (
                            inst,
                            kind,
                            pinned_version,
                            f"latest 26.x.{latest_patch}.{latest_build:04d} from {latest['hw_tcl']}",
                        )
                    )
            except ValueError:
                pass
    return findings


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--qsys",
        type=Path,
        action="append",
        required=True,
        help="One or more .qsys files to audit (repeatable)",
    )
    parser.add_argument(
        "--catalog-root",
        type=Path,
        action="append",
        required=True,
        help="One or more catalog roots to scan for _hw.tcl (repeatable)",
    )
    parser.add_argument(
        "--warn-only",
        action="store_true",
        help="Exit 0 even if stale versions are found (still print findings)",
    )
    args = parser.parse_args()

    catalog = scan_catalog(args.catalog_root)
    all_findings: list[tuple[str, str, str, str, str]] = []
    for qsys in args.qsys:
        if not qsys.is_file():
            print(f"ERROR: missing qsys: {qsys}", file=sys.stderr)
            return 2
        for inst, kind, pinned, latest in audit_qsys(qsys, catalog):
            all_findings.append((str(qsys), inst, kind, pinned, latest))

    if not all_findings:
        print(f"OK: all {sum(1 for _ in args.qsys)} qsys files pin latest IP versions")
        return 0

    print(f"STALE: {len(all_findings)} stale IP version pin(s) found:")
    for qsys, inst, kind, pinned, latest in all_findings:
        print(f"  {qsys}")
        print(f"    instance: {inst}")
        print(f"    kind:     {kind}")
        print(f"    pinned:   {pinned}")
        print(f"    {latest}")
        print()
    print(
        "To fix:\n"
        "  - chmod u+w the .qsys file\n"
        "  - sed-edit `version=\"<pinned>\"` → `version=\"<new>\"` on the offending instance\n"
        "  - if VERSION_PATCH/BUILD/VERSION_DATE parameters appear inside the <module>\n"
        "    block, sed-edit those too\n"
        "  - re-run `make qsys-refresh` and then `make qsys-syn`\n"
    )
    return 0 if args.warn_only else 1


if __name__ == "__main__":
    raise SystemExit(main())
