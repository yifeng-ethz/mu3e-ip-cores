#!/usr/bin/env python3
"""Extract an Avalon address map from a Qsys .sopcinfo file.

The primary use is generating a small SystemVerilog header consumed by
integration-formal decode properties, so the address windows come from the
generated system metadata instead of hand-maintained constants.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


@dataclass(frozen=True)
class MapEntry:
    master: str
    slave: str
    base: int
    span: int | None

    @property
    def end(self) -> int | None:
        if self.span is None:
            return None
        return self.base + self.span - 1


def parse_int(text: str | None) -> int | None:
    if text is None:
        return None
    text = text.strip()
    if not text:
        return None
    return int(text, 0)


def sanitize(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9]+", "_", name).strip("_").upper()


def collect_interface_spans(root: ET.Element) -> dict[str, int]:
    spans: dict[str, int] = {}
    for module in root.findall(".//module"):
        module_name = module.get("name")
        if not module_name:
            continue
        for interface in module.findall("./interface"):
            if interface.get("kind") not in {"avalon", "avalon_slave", "avalon_master"}:
                continue
            interface_name = interface.get("name")
            if not interface_name:
                continue
            span = None
            for param in interface.findall("./parameter"):
                if param.get("name") == "addressSpan":
                    value_node = param.find("./value")
                    span = parse_int(value_node.text if value_node is not None else param.text)
                    break
            if span is not None:
                spans[f"{module_name}.{interface_name}"] = span
    return spans


def collect_entries(root: ET.Element, masters: set[str]) -> list[MapEntry]:
    spans = collect_interface_spans(root)
    entries: list[MapEntry] = []
    for conn in root.findall(".//connection"):
        if conn.get("kind") != "avalon":
            continue
        start = conn.get("start")
        end = conn.get("end")
        if not start or not end:
            continue
        if masters and start not in masters:
            continue
        base = None
        for param in conn.findall("./parameter"):
            if param.get("name") == "baseAddress":
                value_node = param.find("./value")
                base = parse_int(value_node.text if value_node is not None else param.text)
                break
        if base is None:
            continue
        entries.append(MapEntry(master=start, slave=end, base=base, span=spans.get(end)))
    entries.sort(key=lambda entry: (entry.master, entry.base, entry.slave))
    return entries


def emit_json(entries: list[MapEntry]) -> str:
    payload = [
        {
            "master": entry.master,
            "slave": entry.slave,
            "base": entry.base,
            "span": entry.span,
            "end": entry.end,
        }
        for entry in entries
    ]
    return json.dumps(payload, indent=2, sort_keys=False) + "\n"


def emit_svh(entries: list[MapEntry], guard: str) -> str:
    lines = [
        f"`ifndef {guard}",
        f"`define {guard}",
        "",
        f"localparam int unsigned FE_SC_MAP_COUNT = {len(entries)};",
        "",
    ]

    for idx, entry in enumerate(entries):
        tag = sanitize(f"{entry.master}_{entry.slave}")
        lines.append(f"localparam int unsigned FE_SC_IDX_{tag} = {idx};")
        lines.append(f"localparam logic [31:0] FE_SC_BASE_{tag} = 32'h{entry.base:08X};")
        lines.append(
            f"localparam logic [31:0] FE_SC_SPAN_{tag} = 32'h"
            f"{(entry.span if entry.span is not None else 0):08X};"
        )
        lines.append(
            f"localparam logic [31:0] FE_SC_END_{tag} = 32'h"
            f"{(entry.end if entry.end is not None else entry.base):08X};"
        )
        lines.append(f"// {idx}: master={entry.master} slave={entry.slave}")
        if entry.span is None:
            lines.append(f"//     base=0x{entry.base:08X} span=<unknown>")
        else:
            lines.append(
                f"//     base=0x{entry.base:08X} span=0x{entry.span:08X} end=0x{entry.end:08X}"
            )
    lines.extend(["", "`endif", ""])
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("sopcinfo", type=Path, help="Input .sopcinfo file")
    parser.add_argument(
        "--master",
        action="append",
        default=[],
        help="Restrict output to one or more Avalon master interface names",
    )
    parser.add_argument(
        "--format",
        choices=("svh", "json"),
        default="svh",
        help="Output format",
    )
    parser.add_argument(
        "--guard",
        default="FE_SCIFI_V3_SC_MAP_SVH",
        help="Include guard for --format=svh",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        root = ET.parse(args.sopcinfo).getroot()
    except ET.ParseError as exc:
        print(f"error: failed to parse {args.sopcinfo}: {exc}", file=sys.stderr)
        return 1

    entries = collect_entries(root, set(args.master))
    if not entries:
        print("error: no matching Avalon connections found", file=sys.stderr)
        return 1

    if args.format == "json":
        sys.stdout.write(emit_json(entries))
    else:
        sys.stdout.write(emit_svh(entries, args.guard))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
