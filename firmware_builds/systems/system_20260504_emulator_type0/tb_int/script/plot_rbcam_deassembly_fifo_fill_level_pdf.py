#!/usr/bin/env python3
"""Render rbCAM deassembly-FIFO fill-level PDFs for ASIC0 full32 runs."""

from __future__ import annotations

import argparse
import csv
import math
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402


CASE_SET = [
    ("010k", "10 kHz/ch", "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_010k_1ms_gap1ms_20260507"),
    ("100k", "100 kHz/ch", "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_100k_1ms_gap1ms_20260507"),
    ("500k", "500 kHz/ch", "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_500k_1ms_gap1ms_20260507"),
    ("1000k", "1 MHz/ch", "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_1000k_1ms_gap1ms_20260507"),
]

FIFO_DEPTH_WORDS = 64
PARTITION_COUNT = 4


@dataclass(frozen=True)
class FifoStats:
    rate: str
    case_name: str
    partition: int
    samples: int
    mean: float
    median: float
    p95: float
    p99: float
    peak_bin: int
    peak_pct: float
    max_fill: int
    zero_pct: float
    full_samples: int
    full_pct: float
    wrreq_samples: int
    rdack_samples: int


def percentile(values: list[int], pct: float) -> float:
    if not values:
        return math.nan
    ordered = sorted(values)
    pos = (len(ordered) - 1) * pct / 100.0
    lo = int(math.floor(pos))
    hi = int(math.ceil(pos))
    if lo == hi:
        return float(ordered[lo])
    return ordered[lo] * (hi - pos) + ordered[hi] * (pos - lo)


def require_columns(fieldnames: list[str] | None) -> None:
    if fieldnames is None:
        raise RuntimeError("empty rbcam_fill_trace.csv")
    missing = [
        f"p{idx}_deasm_usedw"
        for idx in range(PARTITION_COUNT)
        if f"p{idx}_deasm_usedw" not in fieldnames
    ]
    if missing:
        raise RuntimeError(
            "rbcam_fill_trace.csv does not contain deassembly FIFO columns; "
            "rerun the simulation with the updated TB. Missing: " + ", ".join(missing)
        )


def load_fifo_values(case_dir: Path) -> tuple[list[list[int]], list[list[int]], list[list[int]], list[list[int]]]:
    path = case_dir / "rbcam_fill_trace.csv"
    values = [[] for _ in range(PARTITION_COUNT)]
    full = [[] for _ in range(PARTITION_COUNT)]
    wrreq = [[] for _ in range(PARTITION_COUNT)]
    rdack = [[] for _ in range(PARTITION_COUNT)]
    with path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        require_columns(reader.fieldnames)
        for row in reader:
            if row["stable_capture_active"] != "1":
                continue
            if row["all_running"] != "1":
                continue
            for idx in range(PARTITION_COUNT):
                values[idx].append(int(row[f"p{idx}_deasm_usedw"]))
                full[idx].append(int(row.get(f"p{idx}_deasm_full", "0")))
                wrreq[idx].append(int(row.get(f"p{idx}_deasm_wrreq", "0")))
                rdack[idx].append(int(row.get(f"p{idx}_deasm_rdack", "0")))
    return values, full, wrreq, rdack


def stats_for(
    rate: str,
    case_name: str,
    partition: int,
    values: list[int],
    full: list[int],
    wrreq: list[int],
    rdack: list[int],
) -> FifoStats:
    counts = Counter(values)
    samples = len(values)
    if samples == 0:
        return FifoStats(rate, case_name, partition, 0, math.nan, math.nan, math.nan, math.nan, 0, 0.0, 0, math.nan, 0, math.nan, 0, 0)
    peak_bin, peak_count = counts.most_common(1)[0]
    full_samples = sum(full)
    return FifoStats(
        rate=rate,
        case_name=case_name,
        partition=partition,
        samples=samples,
        mean=sum(values) / samples,
        median=percentile(values, 50.0),
        p95=percentile(values, 95.0),
        p99=percentile(values, 99.0),
        peak_bin=peak_bin,
        peak_pct=100.0 * peak_count / samples,
        max_fill=max(values),
        zero_pct=100.0 * counts.get(0, 0) / samples,
        full_samples=full_samples,
        full_pct=100.0 * full_samples / samples,
        wrreq_samples=sum(wrreq),
        rdack_samples=sum(rdack),
    )


def plot_case(
    rate: str,
    case_name: str,
    rate_key: str,
    values_by_partition: list[list[int]],
    full_by_partition: list[list[int]],
    wrreq_by_partition: list[list[int]],
    rdack_by_partition: list[list[int]],
    out_dir: Path,
) -> list[FifoStats]:
    stats = [
        stats_for(
            rate,
            case_name,
            idx,
            values_by_partition[idx],
            full_by_partition[idx],
            wrreq_by_partition[idx],
            rdack_by_partition[idx],
        )
        for idx in range(PARTITION_COUNT)
    ]
    fig, axes = plt.subplots(2, 2, figsize=(16, 10), constrained_layout=False)
    fig.subplots_adjust(left=0.075, right=0.985, top=0.83, bottom=0.105, hspace=0.5, wspace=0.24)
    fig.suptitle(
        f"rbCAM Deassembly FIFO Fill-Level PDF: ASIC0 ch0..31 {rate}",
        fontsize=18,
        fontweight="bold",
        y=0.965,
    )
    fig.text(
        0.5,
        0.925,
        "active path = hit_stack_subsystem_0 ring_buffer_cam_0..3; plotted FIFO = v2_core.deassembly_fifo "
        "(SV depth 64); one sample per 8 ns core cycle",
        ha="center",
        fontsize=10,
    )
    fig.text(
        0.5,
        0.895,
        "PDF over stable RUNNING cycles only; zero-probability bins omitted; log-y",
        ha="center",
        fontsize=10,
    )

    for idx, ax in enumerate(axes.flat):
        values = values_by_partition[idx]
        counts = Counter(values)
        xs = sorted(counts)
        ys = [100.0 * counts[x] / len(values) for x in xs] if values else []
        ax.bar(xs, ys, width=0.9, color="#2f7df6", edgecolor="#2f7df6", linewidth=0.2, alpha=0.78)
        ax.set_yscale("log")
        ax.set_xlim(-1, FIFO_DEPTH_WORDS)
        ax.set_ylim(1e-3, 100)
        ax.set_title(f"Partition {idx}; INTERLEAVING_INDEX={idx}", fontsize=13)
        ax.set_xlabel("deassembly FIFO fill level [words]")
        ax.set_ylabel("PDF [% / word]")
        ax.grid(True, which="major", color="#999999", alpha=0.35)
        ax.grid(True, which="minor", axis="y", color="#bbbbbb", alpha=0.18)
        ax.set_xticks(list(range(0, FIFO_DEPTH_WORDS + 1, 32)))
        stat = stats[idx]
        ax.text(
            0.985,
            0.965,
            f"n={stat.samples}  mean={stat.mean:.1f}  med={stat.median:.0f}\n"
            f"p95={stat.p95:.0f}  p99={stat.p99:.0f}  max={stat.max_fill}\n"
            f"peak={stat.peak_bin} ({stat.peak_pct:.2f}%)  full={stat.full_pct:.3f}%",
            transform=ax.transAxes,
            fontsize=8.5,
            ha="right",
            va="top",
            family="monospace",
            bbox={"facecolor": "white", "edgecolor": "#aaaaaa", "alpha": 0.88, "boxstyle": "round,pad=0.25"},
        )

    stem = f"rbcam_deassembly_fifo_fill_level_pdf_asic0_full32_{rate_key}"
    png_path = out_dir / f"{stem}.png"
    pdf_path = out_dir / f"{stem}.pdf"
    fig.savefig(png_path, dpi=180)
    fig.savefig(pdf_path)
    plt.close(fig)
    return stats


def write_summary(rows: list[FifoStats], path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "rate",
        "case",
        "partition",
        "samples",
        "mean",
        "median",
        "p95",
        "p99",
        "peak_bin",
        "peak_pct",
        "max_fill",
        "zero_pct",
        "full_samples",
        "full_pct",
        "wrreq_samples",
        "rdack_samples",
    ]
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow({
                "rate": row.rate,
                "case": row.case_name,
                "partition": row.partition,
                "samples": row.samples,
                "mean": f"{row.mean:.6f}",
                "median": f"{row.median:.6f}",
                "p95": f"{row.p95:.6f}",
                "p99": f"{row.p99:.6f}",
                "peak_bin": row.peak_bin,
                "peak_pct": f"{row.peak_pct:.6f}",
                "max_fill": row.max_fill,
                "zero_pct": f"{row.zero_pct:.6f}",
                "full_samples": row.full_samples,
                "full_pct": f"{row.full_pct:.6f}",
                "wrreq_samples": row.wrreq_samples,
                "rdack_samples": row.rdack_samples,
            })


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sim-root", type=Path)
    parser.add_argument("--case-dir", type=Path)
    parser.add_argument("--rate-key", default="1000k")
    parser.add_argument("--rate-label", default="1 MHz/ch")
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--rates", nargs="*", choices=[item[0] for item in CASE_SET])
    args = parser.parse_args()

    if args.case_dir is None and args.sim_root is None:
        parser.error("one of --sim-root or --case-dir is required")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    all_stats: list[FifoStats] = []

    if args.case_dir is not None:
        values, full, wrreq, rdack = load_fifo_values(args.case_dir)
        stats = plot_case(args.rate_label, args.case_dir.name, args.rate_key, values, full, wrreq, rdack, args.out_dir)
        all_stats.extend(stats)
        print(f"{args.rate_label}: " + ", ".join(
            f"p{row.partition} mean={row.mean:.2f} p99={row.p99:.0f} max={row.max_fill} full={row.full_samples}"
            for row in stats
        ))
        summary_path = args.out_dir / "rbcam_deassembly_fifo_fill_level_pdf_asic0_full32_summary.csv"
        write_summary(all_stats, summary_path)
        print(summary_path)
        return 0

    selected = {rate for rate in args.rates} if args.rates else {item[0] for item in CASE_SET}
    for rate_key, rate_label, case_name in CASE_SET:
        if rate_key not in selected:
            continue
        values, full, wrreq, rdack = load_fifo_values(args.sim_root / case_name)
        stats = plot_case(rate_label, case_name, rate_key, values, full, wrreq, rdack, args.out_dir)
        all_stats.extend(stats)
        print(f"{rate_label}: " + ", ".join(
            f"p{row.partition} mean={row.mean:.2f} p99={row.p99:.0f} max={row.max_fill} full={row.full_samples}"
            for row in stats
        ))

    summary_path = args.out_dir / "rbcam_deassembly_fifo_fill_level_pdf_asic0_full32_summary.csv"
    write_summary(all_stats, summary_path)
    print(summary_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
