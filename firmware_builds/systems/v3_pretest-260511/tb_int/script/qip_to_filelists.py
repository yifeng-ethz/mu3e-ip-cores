#!/usr/bin/env python3
"""Extract Questa filelists from a Quartus QIP without editing generated output."""

from __future__ import annotations

import re
import sys
from pathlib import Path


ASSIGN_RE = re.compile(
    r'-name\s+(?P<kind>VHDL_FILE|VERILOG_FILE|SYSTEMVERILOG_FILE)\s+'
    r'\[file join \$::quartus\(qip_path\) "(?P<path>[^"]+)"\]'
)
VHDL_DEF_RE = re.compile(r"\b(?:entity|package)\s+(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s+is\b", re.IGNORECASE)
VHDL_WORK_REF_RE = re.compile(
    r"\b(?:entity\s+work\.|use\s+work\.)(?P<name>[A-Za-z_][A-Za-z0-9_]*)",
    re.IGNORECASE,
)


VHDL_DEP_PRIO = {
    "write_mask_gen.vhd": 10,
    "simple_dual_port_ram_single_clock.vhd": 10,
    "true_dual_port_ram_single_clock.vhd": 10,
    "search_for_extreme.vhd": 10,
    "search_for_extreme3.vhd": 10,
    "main_fifo.vhd": 20,
    "alt_parallel_add.vhd": 20,
    "bin_divider.vhd": 20,
    "hit_fifo.vhd": 20,
    "rr_arbiter.vhd": 20,
    "coalescing_queue.vhd": 20,
    "pingpong_sram.vhd": 20,
    "mutrig_ctrl.vhd": 30,
    "histogram_statistics_v2.vhd": 30,
    "histogram_statistics_v2_bool_core.vhd": 30,
    "feb_frame_assembly.vhd": 40,
}


def source_priority(path: Path) -> int:
    name = path.name.lower()
    is_pkg = name.endswith("_pkg.sv") or name.endswith("_pkg.vhd") or name.endswith("_pkg.vhdl")
    return 0 if is_pkg else VHDL_DEP_PRIO.get(name, 50)


def scan_vhdl_symbols(paths: list[Path]) -> tuple[dict[str, Path], dict[Path, set[str]]]:
    definitions: dict[str, Path] = {}
    references: dict[Path, set[str]] = {}
    for path in paths:
        if path.suffix.lower() not in {".vhd", ".vhdl"} or not path.is_file():
            references[path] = set()
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for match in VHDL_DEF_RE.finditer(text):
            definitions.setdefault(match.group("name").lower(), path)
        references[path] = {match.group("name").lower() for match in VHDL_WORK_REF_RE.finditer(text)}
    return definitions, references


def sort_sources(paths: list[Path]) -> list[Path]:
    unique = list(dict.fromkeys(paths))
    definitions, references = scan_vhdl_symbols(unique)
    deps: dict[Path, set[Path]] = {path: set() for path in unique}
    users: dict[Path, set[Path]] = {path: set() for path in unique}
    for path, refs in references.items():
        for ref in refs:
            provider = definitions.get(ref)
            if provider is None or provider == path:
                continue
            deps[path].add(provider)
            users[provider].add(path)

    remaining = set(unique)
    ready = [path for path in unique if not deps[path]]
    ordered: list[Path] = []
    while ready:
        ready.sort(key=lambda item: (source_priority(item), str(item)))
        path = ready.pop(0)
        if path not in remaining:
            continue
        remaining.remove(path)
        ordered.append(path)
        for user in sorted(users[path], key=lambda item: (source_priority(item), str(item))):
            deps[user].discard(path)
            if not deps[user]:
                ready.append(user)

    if remaining:
        ordered.extend(sorted(remaining, key=lambda item: (source_priority(item), str(item))))
    return ordered

def write_list(path: Path, sources: list[Path]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("".join(f"{src}\n" for src in sources), encoding="ascii")


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: qip_to_filelists.py <feb_system_v3.qip> <out-dir>", file=sys.stderr)
        return 2

    qip = Path(sys.argv[1]).resolve()
    out_dir = Path(sys.argv[2]).resolve()
    qip_dir = qip.parent
    buckets: dict[str, list[Path]] = {
        "VHDL_FILE": [],
        "VERILOG_FILE": [],
        "SYSTEMVERILOG_FILE": [],
    }

    for line in qip.read_text(encoding="utf-8", errors="replace").splitlines():
        match = ASSIGN_RE.search(line)
        if not match:
            continue
        buckets[match.group("kind")].append(qip_dir / match.group("path"))

    write_list(out_dir / "qsys_vhdl.f", sort_sources(buckets["VHDL_FILE"]))
    write_list(out_dir / "qsys_verilog.f", sort_sources(buckets["VERILOG_FILE"]))
    write_list(out_dir / "qsys_sv.f", sort_sources(buckets["SYSTEMVERILOG_FILE"]))
    print(f"wrote {out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
