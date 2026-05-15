#!/usr/bin/env python3
"""Build a simulator-friendly Qsys source list for Questa CDC."""

from __future__ import annotations

from collections import defaultdict, deque
from pathlib import Path
import argparse
import re
import sys


ENTITY_RE = re.compile(r"^\s*entity\s+([a-zA-Z][a-zA-Z0-9_]*)\s+is\b", re.IGNORECASE | re.MULTILINE)
PACKAGE_RE = re.compile(r"^\s*package\s+(?!body\b)([a-zA-Z][a-zA-Z0-9_]*)\s+is\b", re.IGNORECASE | re.MULTILINE)
DIRECT_ENTITY_RE = re.compile(r"\bentity\s+work\.([a-zA-Z][a-zA-Z0-9_]*)\b", re.IGNORECASE)
USE_WORK_RE = re.compile(r"\buse\s+work\.([a-zA-Z][a-zA-Z0-9_]*)\.", re.IGNORECASE)
WORK_UNIT_RE = re.compile(r"\bwork\.([a-zA-Z][a-zA-Z0-9_]*)\.", re.IGNORECASE)


def provided_units(path: Path) -> set[str]:
    text = path.read_text(errors="replace")
    return {
        *(name.lower() for name in ENTITY_RE.findall(text)),
        *(name.lower() for name in PACKAGE_RE.findall(text)),
    }


def required_units(path: Path) -> set[str]:
    text = path.read_text(errors="replace")
    return {
        *(name.lower() for name in DIRECT_ENTITY_RE.findall(text)),
        *(name.lower() for name in USE_WORK_RE.findall(text)),
        *(name.lower() for name in WORK_UNIT_RE.findall(text)),
    }


def stable_toposort(paths: list[Path]) -> list[Path]:
    providers: dict[str, Path] = {}
    for path in paths:
        for unit in provided_units(path):
            providers.setdefault(unit, path)

    edges: dict[Path, set[Path]] = {path: set() for path in paths}
    indegree: dict[Path, int] = {path: 0 for path in paths}

    for path in paths:
        for unit in required_units(path):
            provider = providers.get(unit)
            if provider is None or provider == path:
                continue
            if path not in edges[provider]:
                edges[provider].add(path)
                indegree[path] += 1

    original_index = {path: index for index, path in enumerate(paths)}
    ready = deque(sorted((path for path in paths if indegree[path] == 0), key=original_index.get))
    ordered: list[Path] = []

    while ready:
        path = ready.popleft()
        ordered.append(path)
        for dependent in sorted(edges[path], key=original_index.get):
            indegree[dependent] -= 1
            if indegree[dependent] == 0:
                ready.append(dependent)
        ready = deque(sorted(ready, key=original_index.get))

    if len(ordered) != len(paths):
        cycle = [str(path) for path, degree in indegree.items() if degree]
        raise SystemExit("dependency cycle or unresolved ordering: " + ", ".join(cycle[:10]))

    return ordered


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input")
    parser.add_argument("output")
    parser.add_argument("--add-source", action="append", default=[])
    parser.add_argument("--closure-source-list")
    parser.add_argument("--emit-plain-verilog")
    parser.add_argument("--exclude-plain-verilog", action="store_true")
    parser.add_argument("--exclude-suffix", action="append", default=[])
    args = parser.parse_args()

    in_path = Path(args.input)
    out_path = Path(args.output)
    paths = [Path(source) for source in args.add_source]
    paths.extend(Path(line.strip()) for line in in_path.read_text().splitlines() if line.strip())
    paths = list(dict.fromkeys(paths))
    if args.exclude_suffix:
        paths = [
            path for path in paths
            if not any(str(path).endswith(suffix) for suffix in args.exclude_suffix)
        ]
    if args.closure_source_list:
        available_paths = [
            Path(line.strip())
            for line in Path(args.closure_source_list).read_text().splitlines()
            if line.strip()
        ]
        available_paths = list(dict.fromkeys(available_paths))
        available_providers: dict[str, Path] = {}
        for path in available_paths:
            if path.suffix.lower() not in {".vhd", ".vhdl"}:
                continue
            for unit in provided_units(path):
                available_providers.setdefault(unit, path)

        while True:
            selected_providers: dict[str, Path] = {}
            for path in paths:
                if path.suffix.lower() not in {".vhd", ".vhdl"}:
                    continue
                for unit in provided_units(path):
                    selected_providers.setdefault(unit, path)
            needed = set()
            for path in paths:
                if path.suffix.lower() in {".vhd", ".vhdl"}:
                    needed.update(required_units(path))
            missing = sorted(unit for unit in needed if unit not in selected_providers)
            additions = [
                available_providers[unit]
                for unit in missing
                if unit in available_providers and available_providers[unit] not in paths
            ]
            if not additions:
                unresolved = [unit for unit in missing if unit not in available_providers]
                if unresolved:
                    print("Unresolved work units: " + ", ".join(unresolved))
                break
            paths = additions + paths
            paths = list(dict.fromkeys(paths))
    vhdl = [path for path in paths if path.suffix.lower() in {".vhd", ".vhdl"}]
    plain_verilog = [path for path in paths if path.suffix.lower() == ".v"]
    if args.emit_plain_verilog:
        Path(args.emit_plain_verilog).write_text(
            "\n".join(str(path) for path in plain_verilog) + ("\n" if plain_verilog else "")
        )
    sv_suffixes = {".sv"} if args.exclude_plain_verilog else {".sv", ".v"}
    sv = [path for path in paths if path.suffix.lower() in sv_suffixes]
    ordered = stable_toposort(vhdl) + sv
    out_path.write_text("\n".join(str(path) for path in ordered) + "\n")
    print(f"Wrote {out_path} with {len(ordered)} sources ({len(vhdl)} VHDL, {len(sv)} SV/Verilog)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
