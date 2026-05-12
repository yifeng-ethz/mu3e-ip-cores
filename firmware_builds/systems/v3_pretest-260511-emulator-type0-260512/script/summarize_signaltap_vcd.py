#!/usr/bin/env python3
"""Summarize Quartus SignalTap VCD exports.

The parser is intentionally small and VCD-specific: SignalTap exports a flat
sample stream, often with individual bus bits.  This script reconstructs those
indexed buses and emits both control-signal metrics and payload summaries.
"""

from __future__ import annotations

import argparse
import csv
import re
from collections import defaultdict
from dataclasses import dataclass
from pathlib import Path


INDEX_RE = re.compile(r"^(?P<base>.+)\[(?P<index>\d+)\]$")


@dataclass(frozen=True)
class VarDef:
    ident: str
    name: str
    size: int


@dataclass
class SignalMetric:
    known_samples: int = 0
    one_samples: int = 0
    rise_count: int = 0
    first_one_ps: int | None = None
    last_one_ps: int | None = None
    final: str = "x"
    previous: str = "x"

    def update(self, time_ps: int, value: str) -> None:
        v = value.lower()
        if v in {"0", "1"}:
            self.known_samples += 1
            if v == "1":
                self.one_samples += 1
                self.last_one_ps = time_ps
                if self.first_one_ps is None:
                    self.first_one_ps = time_ps
                if self.previous != "1":
                    self.rise_count += 1
        self.final = v
        self.previous = v


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vcd", type=Path, help="Input VCD file")
    parser.add_argument("--out-dir", type=Path, help="Directory for CSV summaries")
    parser.add_argument("--sample-limit", type=int, default=32, help="Per-bus sample rows to keep")
    return parser.parse_args()


def parse_var(parts: list[str], scopes: list[str]) -> VarDef | None:
    if len(parts) < 6:
        return None
    try:
        size = int(parts[2])
    except ValueError:
        return None
    ident = parts[3]
    ref = " ".join(parts[4:-1])
    full_name = ".".join([*scopes, ref]) if scopes else ref
    return VarDef(ident=ident, name=full_name, size=size)


def read_vcd(path: Path) -> tuple[list[int], list[VarDef], list[dict[str, str]]]:
    scopes: list[str] = []
    vars_by_id: dict[str, VarDef] = {}
    current: dict[str, str] = {}
    times: list[int] = []
    snapshots: list[dict[str, str]] = []
    current_time: int | None = None

    def snapshot() -> None:
        if current_time is None:
            return
        times.append(current_time)
        snapshots.append(dict(current))

    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("$scope"):
                parts = line.split()
                if len(parts) >= 3:
                    scopes.append(parts[2])
                continue
            if line.startswith("$upscope"):
                if scopes:
                    scopes.pop()
                continue
            if line.startswith("$var"):
                item = parse_var(line.split(), scopes)
                if item is not None:
                    vars_by_id[item.ident] = item
                    current.setdefault(item.ident, "x" * max(item.size, 1))
                continue
            if line.startswith("#"):
                snapshot()
                current_time = int(line[1:])
                continue
            if line.startswith("$"):
                continue
            if line[0] in "01xXzZ":
                current[line[1:].strip()] = line[0].lower()
                continue
            if line[0] in "bB":
                fields = line.split()
                if len(fields) == 2:
                    current[fields[1]] = fields[0][1:].lower()

    snapshot()
    return times, list(vars_by_id.values()), snapshots


def metric_rows(times: list[int], vars_: list[VarDef], snapshots: list[dict[str, str]]) -> list[dict[str, str]]:
    metrics = {item.ident: SignalMetric() for item in vars_}
    by_id = {item.ident: item for item in vars_}
    for time_ps, sample in zip(times, snapshots):
        for ident, item in by_id.items():
            value = sample.get(ident, "x")
            if item.size == 1:
                metrics[ident].update(time_ps, value)

    rows: list[dict[str, str]] = []
    for item in vars_:
        if item.size != 1:
            continue
        metric = metrics[item.ident]
        rows.append(
            {
                "name": item.name,
                "first_one_ps": str(metric.first_one_ps) if metric.first_one_ps is not None else "never",
                "last_one_ps": str(metric.last_one_ps) if metric.last_one_ps is not None else "never",
                "rise_count": str(metric.rise_count),
                "one_samples": str(metric.one_samples),
                "known_samples": str(metric.known_samples),
                "final": metric.final,
            }
        )
    return rows


def collect_buses(vars_: list[VarDef]) -> dict[str, dict[int, str]]:
    buses: dict[str, dict[int, str]] = defaultdict(dict)
    for item in vars_:
        match = INDEX_RE.match(item.name)
        if match:
            buses[match.group("base")][int(match.group("index"))] = item.ident
        elif item.size > 1:
            buses[item.name][0] = item.ident
    return dict(buses)


def value_to_int(value: str, width: int | None = None) -> int | None:
    bits = value.lower()
    if any(ch not in "01" for ch in bits):
        return None
    if width is not None and len(bits) == 1:
        return int(bits, 2)
    return int(bits, 2)


def bus_value(bus: dict[int, str], sample: dict[str, str]) -> tuple[int | None, bool]:
    if len(bus) == 1 and 0 in bus and len(sample.get(bus[0], "")) > 1:
        value = sample.get(bus[0], "x")
        parsed = value_to_int(value)
        return parsed, parsed is not None

    value = 0
    for index, ident in bus.items():
        bit = sample.get(ident, "x").lower()
        if bit not in {"0", "1"}:
            return None, False
        if bit == "1":
            value |= 1 << index
    return value, True


def find_name_id(vars_: list[VarDef], name: str) -> str | None:
    for item in vars_:
        if item.name == name:
            return item.ident
    return None


def qualifier_for_bus(base: str, vars_: list[VarDef]) -> tuple[str, str | None]:
    parent, _, leaf = base.rpartition(".")
    candidates: list[str] = []
    if leaf.endswith("_data"):
        candidates.append(f"{parent}.{leaf[:-5]}_valid")
    if leaf.endswith("_channel"):
        candidates.append(f"{parent}.{leaf[:-8]}_valid")
    if leaf.endswith("_error"):
        candidates.append(f"{parent}.{leaf[:-6]}_valid")
    if leaf in {"i_data", "p_frame_len", "p_word_cnt"}:
        candidates.extend([f"{parent}.p_new_word", f"{parent}.n_new_word", f"{parent}.asi_rx8b1k_valid"])
    if leaf == "asi_rx8b1k_data":
        candidates.append(f"{parent}.asi_rx8b1k_valid")
    candidates.append(f"{parent}.valid")

    for candidate in candidates:
        ident = find_name_id(vars_, candidate)
        if ident is not None:
            return candidate, ident
    return "", None


def summarize_buses(
    times: list[int],
    vars_: list[VarDef],
    snapshots: list[dict[str, str]],
    sample_limit: int,
) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    buses = collect_buses(vars_)
    summary_rows: list[dict[str, str]] = []
    sample_rows: list[dict[str, str]] = []

    for base, bus in sorted(buses.items()):
        width = max(bus) + 1 if bus else 0
        qualifier_name, qualifier_id = qualifier_for_bus(base, vars_)
        known_samples = 0
        unknown_samples = 0
        nonzero_samples = 0
        qualifier_one_samples = 0
        first_known_ps: int | None = None
        first_nonzero_ps: int | None = None
        first_change_ps: int | None = None
        previous_value: int | None = None
        final_value: int | None = None
        unique_values: set[int] = set()
        captured = 0

        for time_ps, sample in zip(times, snapshots):
            value, known = bus_value(bus, sample)
            qualifier_on = True
            if qualifier_id is not None:
                qualifier_on = sample.get(qualifier_id, "x") == "1"
                if qualifier_on:
                    qualifier_one_samples += 1
            if not known or value is None:
                unknown_samples += 1
                continue

            known_samples += 1
            final_value = value
            unique_values.add(value)
            if first_known_ps is None:
                first_known_ps = time_ps
            if previous_value is not None and first_change_ps is None and value != previous_value:
                first_change_ps = time_ps
            previous_value = value
            if value != 0:
                nonzero_samples += 1
                if first_nonzero_ps is None:
                    first_nonzero_ps = time_ps

            if qualifier_on and captured < sample_limit:
                sample_rows.append(
                    {
                        "bus": base,
                        "time_ps": str(time_ps),
                        "value_hex": f"0x{value:x}",
                        "value_dec": str(value),
                        "qualifier": qualifier_name,
                    }
                )
                captured += 1

        summary_rows.append(
            {
                "bus": base,
                "width": str(width),
                "known_samples": str(known_samples),
                "unknown_samples": str(unknown_samples),
                "nonzero_samples": str(nonzero_samples),
                "first_known_ps": str(first_known_ps) if first_known_ps is not None else "never",
                "first_nonzero_ps": str(first_nonzero_ps) if first_nonzero_ps is not None else "never",
                "first_change_ps": str(first_change_ps) if first_change_ps is not None else "never",
                "unique_values": str(len(unique_values)),
                "final_hex": f"0x{final_value:x}" if final_value is not None else "unknown",
                "qualifier": qualifier_name,
                "qualifier_one_samples": str(qualifier_one_samples),
            }
        )

    return summary_rows, sample_rows


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    if not rows:
        path.write_text("", encoding="utf-8")
        return
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def important_signal(name: str) -> bool:
    terms = (
        "valid",
        "ready",
        "reset",
        "run_generating",
        "receiver_go",
        ".enable",
        "p_new_word",
        "n_new_word",
        "i_byteisk",
    )
    return any(term in name for term in terms)


def main() -> int:
    args = parse_args()
    times, vars_, snapshots = read_vcd(args.vcd)
    signal_rows = metric_rows(times, vars_, snapshots)
    bus_rows, bus_sample_rows = summarize_buses(times, vars_, snapshots, args.sample_limit)

    if args.out_dir is not None:
        args.out_dir.mkdir(parents=True, exist_ok=True)
        write_csv(args.out_dir / "signal_metrics.csv", signal_rows)
        write_csv(args.out_dir / "bus_summary.csv", bus_rows)
        write_csv(args.out_dir / "bus_samples.csv", bus_sample_rows)

    print(f"VCD={args.vcd}")
    print(f"timestamps={len(times)}")
    print(f"signals={len(vars_)}")
    print("name, first_one_ps, last_one_ps, rise_count, one_samples, known_samples, final")
    for row in signal_rows:
        if important_signal(row["name"]):
            print(
                "{name}, {first_one_ps}, {last_one_ps}, {rise_count}, {one_samples}, {known_samples}, {final}".format(
                    **row
                )
            )

    print("")
    print("bus, width, known_samples, nonzero_samples, first_nonzero_ps, unique_values, final_hex, qualifier, qualifier_one_samples")
    for row in bus_rows:
        print(
            "{bus}, {width}, {known_samples}, {nonzero_samples}, {first_nonzero_ps}, "
            "{unique_values}, {final_hex}, {qualifier}, {qualifier_one_samples}".format(**row)
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
