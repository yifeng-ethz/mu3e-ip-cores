#!/usr/bin/env python3
"""Build the FEB/SWB cosim sanity markdown report."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path


CHECKPOINTS = [
    ("pre-rbCAM", "pre_rbcam_hits", "pre_rbcam_lifetime_cycles"),
    ("post-rbCAM", "post_rbcam_hits", "post_rbcam_lifetime_cycles"),
    ("FEB egress", "expected_feb_hits", "feb_egress_lifetime_cycles"),
    ("SWB ingress", "opq_ingress_hits", "opq_ingress_lifetime_cycles"),
    ("OPQ egress", "opq_egress_hits", "opq_egress_lifetime_cycles"),
    ("RDMA egress", "dma_hits", "dma_lifetime_cycles"),
]


def read_key_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.exists():
        return values
    for line in path.read_text(encoding="ascii", errors="ignore").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def read_lifetime_stats(path: Path) -> dict[str, dict[str, str]]:
    stats: dict[str, dict[str, str]] = {}
    if not path.exists():
        return stats
    with path.open("r", encoding="ascii", newline="") as handle:
        for row in csv.DictReader(handle):
            stats[row["metric"]] = row
    return stats


def count_waveform_rows(path: Path) -> tuple[int, int]:
    if not path.exists():
        return 0, 0
    total = 0
    valid = 0
    with path.open("r", encoding="ascii", newline="") as handle:
        for row in csv.DictReader(handle):
            total += 1
            if row.get("valid", "0") == "1":
                valid += 1
    return total, valid


def parse_packet_counts(summary: dict[str, str]) -> tuple[int, int, int]:
    hit_packets = int(summary.get("opq_ingress_frames", "0"))
    return hit_packets, 0, 0


def write_markdown(
    report_dir: Path,
    output: Path,
    expected_hits: int,
    hit_period_8ns: int,
    run_window_8ns: int,
    asic_count: int,
) -> None:
    summary = read_key_values(report_dir / "feb_swb_trace_debug_summary.txt")
    lifetime = read_lifetime_stats(report_dir / "feb_swb_lifetime_hist_stats.csv")
    corun_summary = read_key_values(report_dir / "feb_swb_corun_summary.txt")
    feb_wave_cycles, feb_wave_valid = count_waveform_rows(
        report_dir / "feb_swb_feb_egress_waveform.csv"
    )
    swb_wave_cycles, swb_wave_valid = count_waveform_rows(
        report_dir / "feb_swb_swb_ingress_waveform.csv"
    )
    hit_packets, sc_packets, rc_packets = parse_packet_counts(summary)

    lines: list[str] = []
    lines.append("# COSIM_SANITY 1ms Periodic All-Channel Summary")
    lines.append("")
    lines.append("## Configuration")
    lines.append("")
    lines.append("- Source mode: periodic")
    lines.append(f"- ASIC count: {asic_count}")
    lines.append("- Channel mask: 0xFFFFFFFF per ASIC source")
    lines.append(f"- Hit period: {hit_period_8ns} x 8 ns")
    lines.append(f"- Run window: {run_window_8ns} x 8 ns")
    lines.append(f"- Expected hits: {expected_hits}")
    lines.append("- Run-control concept: 0x10 -> 0x11 -> 0x12 -> drain -> 0x13")
    lines.append("")
    lines.append("## Checkpoints")
    lines.append("")
    lines.append("| Checkpoint | Count | p05 cycles | p50 cycles | p95 cycles | Status |")
    lines.append("|---|---:|---:|---:|---:|---|")
    for label, count_key, metric in CHECKPOINTS:
        count = int(summary.get(count_key, "0"))
        row = lifetime.get(metric, {})
        status = "PASS" if count == expected_hits else "FAIL"
        lines.append(
            f"| {label} | {count} | {row.get('p05_cycles', '')} | "
            f"{row.get('p50_cycles', '')} | {row.get('p95_cycles', '')} | {status} |"
        )
    lines.append("")
    lines.append("## Packet Steering")
    lines.append("")
    lines.append("| Packet type | Count |")
    lines.append("|---|---:|")
    lines.append(f"| Hit | {hit_packets} |")
    lines.append(f"| Slow control | {sc_packets} |")
    lines.append(f"| Run control | {rc_packets} |")
    lines.append("")
    lines.append("## Raw Waveform Capture")
    lines.append("")
    lines.append("| Boundary | Cycles captured | Valid cycles |")
    lines.append("|---|---:|---:|")
    lines.append(f"| FEB egress | {feb_wave_cycles} | {feb_wave_valid} |")
    lines.append(f"| SWB ingress | {swb_wave_cycles} | {swb_wave_valid} |")
    lines.append("")
    lines.append("## Lossless Checks")
    lines.append("")
    for key in (
        "pass_hits",
        "fail_hits",
        "ghost_source_generation_hits",
        "ghost_pre_rbcam_hits",
        "ghost_post_rbcam_hits",
        "ghost_opq_ingress_hits",
        "ghost_opq_egress_hits",
        "ghost_dma_hits",
        "opq_drop_counter_total",
        "opq_handle_fifo_overflow_total",
        "issue_count",
    ):
        lines.append(f"- {key}: {summary.get(key, 'missing')}")
    for key in (
        "expected_hits",
        "actual_hits",
        "missing_hits",
        "ghost_hits",
        "fifo_overflow",
        "fifo_underflow",
    ):
        if key in corun_summary:
            lines.append(f"- {key}: {corun_summary[key]}")
    lines.append("")
    lines.append("## Verdict")
    lines.append("")
    all_counts = all(int(summary.get(count_key, "0")) == expected_hits
                     for _, count_key, _ in CHECKPOINTS)
    issue_count = int(summary.get("issue_count", "1"))
    fail_hits = int(summary.get("fail_hits", "1"))
    if all_counts and issue_count == 0 and fail_hits == 0:
        lines.append(
            f"PASS: all six checkpoints reached {expected_hits} hits "
            "with no analyzer issues."
        )
    else:
        lines.append("FAIL: one or more checkpoint counts or analyzer issue counters are nonzero.")

    output.write_text("\n".join(lines) + "\n", encoding="ascii")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report-dir", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--expected-hits", default=6400, type=int)
    parser.add_argument("--hit-period-8ns", default=5000, type=int)
    parser.add_argument("--run-window-8ns", default=125000, type=int)
    parser.add_argument("--asic-count", default=8, type=int)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    write_markdown(
        args.report_dir,
        args.output,
        args.expected_hits,
        args.hit_period_8ns,
        args.run_window_8ns,
        args.asic_count,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
