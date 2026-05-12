#!/usr/bin/env python3
"""Create Markdown summaries for the build-local dual-port histogram sim."""

from __future__ import annotations

import csv
import pathlib
import sys


def read_summary(path: pathlib.Path) -> dict[str, str]:
    with path.open(newline="") as f:
        return {row["key"]: row["value"] for row in csv.DictReader(f)}


def interval_sums(path: pathlib.Path) -> list[int]:
    sums: dict[int, int] = {}
    if not path.exists() or path.stat().st_size == 0:
        return []
    with path.open(newline="") as f:
        for row in csv.DictReader(f):
            interval = int(row["interval"])
            sums[interval] = sums.get(interval, 0) + int(row["count"])
    return [sums[idx] for idx in sorted(sums)]


def derive_interval_bins_from_trace(events_path: pathlib.Path, out_path: pathlib.Path) -> list[int]:
    bank_bins: dict[int, dict[int, int]] = {0: {}, 1: {}}
    intervals: list[tuple[int, dict[int, int]]] = []

    with events_path.open(newline="") as f:
        for row in csv.DictReader(f):
            if row["event"] == "hist_bin_write":
                bank = int(row["bank"])
                bin_idx = int(row["bin"])
                value = int(row["value"], 16)
                bank_bins[bank][bin_idx] = value
            elif row["event"] == "interval" and int(row["csr_total"]) > 0:
                active_bank = int(row["bank"])
                frozen_bank = 1 - active_bank
                intervals.append((frozen_bank, dict(bank_bins[frozen_bank])))

    sums: list[int] = []
    with out_path.open("w", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["interval", "bin", "count", "source", "frozen_bank"],
        )
        writer.writeheader()
        for idx, (frozen_bank, bins) in enumerate(intervals, start=1):
            interval_sum = 0
            for bin_idx in range(256):
                count = bins.get(bin_idx, 0)
                interval_sum += count
                writer.writerow(
                    {
                        "interval": idx,
                        "bin": bin_idx,
                        "count": count,
                        "source": "hist_bin_write_trace",
                        "frozen_bank": frozen_bank,
                    }
                )
            sums.append(interval_sum)
    return sums


def event_samples(path: pathlib.Path, event: str, limit: int = 3) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    with path.open(newline="") as f:
        for row in csv.DictReader(f):
            if row["event"] == event:
                rows.append(row)
                if len(rows) >= limit:
                    break
    return rows


def write_report(prefix: pathlib.Path, out_path: pathlib.Path, title: str) -> None:
    summary = read_summary(prefix.with_name(prefix.name + "_summary.csv"))
    events_path = prefix.with_name(prefix.name + "_events.csv")
    live_interval_path = prefix.with_name(prefix.name + "_interval_bins.csv")
    trace_interval_path = prefix.with_name(prefix.name + "_trace_interval_bins.csv")
    intervals = interval_sums(live_interval_path)
    interval_source = "live hist_bin AVMM readback"
    if not intervals or sum(intervals) == 0:
        intervals = derive_interval_bins_from_trace(events_path, trace_interval_path)
        interval_source = "trace-derived from internal hist_bin write events"
    p0_samples = event_samples(events_path, "hist_fill_in")
    p1_samples = event_samples(events_path, "fill_in_1")
    write_samples = event_samples(events_path, "hist_bin_write")

    expected = int(summary["expected_hits"])
    observed = sum(intervals)
    delta = observed - expected
    verdict = (
        "PASS"
        if summary.get("pass") == "1" and abs(delta) <= 8 and observed > 0
        else "FAIL"
    )

    lines = [
        f"# {title}",
        "",
        "## Summary",
        "",
        f"- Verdict: {verdict}",
        f"- Expected hits: {expected}",
        f"- Observed interval bin sum: {observed}",
        f"- Delta: {delta}",
        f"- Interval bin source: {interval_source}",
        f"- Port 0 handshakes (`hist_fill_in`): {summary['hist_fill_in_handshakes']}",
        f"- Port 1 handshakes (`fill_in_1`): {summary['fill_in_1_handshakes']}",
        f"- Internal `hist_bin` write pulses observed: {summary['hist_bin_write_pulses']}",
        f"- Max monitored `csr_total_hits`: {summary['max_csr_total_hits']}",
        "",
        "## Interval Bin Sums",
        "",
        "| Interval | Sum |",
        "|---:|---:|",
    ]
    for idx, value in enumerate(intervals, start=1):
        lines.append(f"| {idx} | {value} |")

    lines.extend([
        "",
        "## Trace Samples",
        "",
        "| Probe | Cycle | Data | Bin | Bank | Value | CSR total |",
        "|---|---:|---|---:|---:|---|---:|",
    ])
    for row in p0_samples + p1_samples + write_samples:
        lines.append(
            "| {event} | {cycle} | {data} | {bin} | {bank} | {value} | {csr_total} |".format(
                **row
            )
        )

    lines.extend([
        "",
        "## Artifacts",
        "",
        f"- Summary CSV: `{prefix.name}_summary.csv`",
        f"- Event CSV: `{prefix.name}_events.csv`",
        f"- Live per-interval bin CSV: `{prefix.name}_interval_bins.csv`",
        f"- Trace-derived per-interval bin CSV: `{prefix.name}_trace_interval_bins.csv`",
    ])

    out_path.write_text("\n".join(lines) + "\n")


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: summarize_hist_dualport.py <prefix> <out.md> <title>", file=sys.stderr)
        return 2
    write_report(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), sys.argv[3])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
