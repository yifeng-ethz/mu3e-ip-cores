#!/usr/bin/env python3
"""Plot FEB/SWB checkpoint delay histograms from analyzer CSV output."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


METRICS = [
    (
        "feb_to_opq_ingress_ns",
        "FEB egress to OPQ ingress",
        "#1f77b4",
    ),
    (
        "opq_ingress_to_opq_egress_ns",
        "OPQ ingress to OPQ egress",
        "#2ca02c",
    ),
    (
        "feb_to_opq_egress_ns",
        "FEB egress to OPQ egress",
        "#d62728",
    ),
]


def read_delay_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="ascii", newline="") as handle:
        return list(csv.DictReader(handle))


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    if len(values) == 1:
        return values[0]
    sorted_values = sorted(values)
    rank = (pct / 100.0) * (len(sorted_values) - 1)
    low = int(rank)
    high = min(low + 1, len(sorted_values) - 1)
    frac = rank - low
    return sorted_values[low] * (1.0 - frac) + sorted_values[high] * frac


def metric_values(rows: list[dict[str, str]], metric: str) -> list[float]:
    values: list[float] = []
    for row in rows:
        if row.get("status") != "PASS":
            continue
        value = row.get(metric, "")
        if value == "":
            continue
        values.append(float(value))
    return values


def write_stats(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="ascii", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "metric",
                "count",
                "min_ns",
                "p50_ns",
                "p95_ns",
                "max_ns",
                "mean_ns",
            ],
        )
        writer.writeheader()
        for metric, _, _ in METRICS:
            values = metric_values(rows, metric)
            if values:
                writer.writerow(
                    {
                        "metric": metric,
                        "count": len(values),
                        "min_ns": f"{min(values):.3f}",
                        "p50_ns": f"{percentile(values, 50):.3f}",
                        "p95_ns": f"{percentile(values, 95):.3f}",
                        "max_ns": f"{max(values):.3f}",
                        "mean_ns": f"{sum(values) / len(values):.3f}",
                    }
                )
            else:
                writer.writerow(
                    {
                        "metric": metric,
                        "count": 0,
                        "min_ns": "",
                        "p50_ns": "",
                        "p95_ns": "",
                        "max_ns": "",
                        "mean_ns": "",
                    }
                )


def plot_histograms(rows: list[dict[str, str]], png_path: Path, pdf_path: Path) -> None:
    fig, axes = plt.subplots(3, 1, figsize=(8.0, 7.2), constrained_layout=True)
    fig.suptitle("FEB/SWB ASIC0 all-channel checkpoint delay histograms", fontsize=12)

    for axis, (metric, label, color) in zip(axes, METRICS, strict=True):
        values = metric_values(rows, metric)
        if values:
            bins = min(48, max(8, int(len(values) ** 0.5)))
            axis.hist(values, bins=bins, color=color, alpha=0.82, edgecolor="white", linewidth=0.7)
            p50 = percentile(values, 50)
            p95 = percentile(values, 95)
            axis.axvline(p50, color="black", linewidth=1.0, linestyle="-", label=f"p50 {p50:.1f} ns")
            axis.axvline(p95, color="black", linewidth=1.0, linestyle="--", label=f"p95 {p95:.1f} ns")
            axis.legend(
                loc="upper right",
                fontsize=8,
                frameon=True,
                facecolor="white",
                framealpha=0.9,
                edgecolor="none",
            )
            axis.text(
                0.01,
                0.92,
                f"n={len(values)} min={min(values):.1f} ns max={max(values):.1f} ns",
                transform=axis.transAxes,
                fontsize=8,
                va="top",
                bbox={"facecolor": "white", "alpha": 0.85, "edgecolor": "none", "pad": 2.0},
            )
        else:
            axis.text(0.5, 0.5, "no passing samples", transform=axis.transAxes, ha="center")
        axis.set_title(label, fontsize=10)
        axis.set_xlabel("delay (ns)")
        axis.set_ylabel("hits")
        axis.grid(True, axis="y", alpha=0.25)

    fig.savefig(png_path, dpi=160)
    fig.savefig(pdf_path)
    plt.close(fig)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trace-dir", required=True, type=Path)
    args = parser.parse_args()

    delay_csv = args.trace_dir / "feb_swb_delay_trace.csv"
    rows = read_delay_rows(delay_csv)
    stats_csv = args.trace_dir / "feb_swb_delay_hist_stats.csv"
    png_path = args.trace_dir / "feb_swb_delay_hist.png"
    pdf_path = args.trace_dir / "feb_swb_delay_hist.pdf"

    write_stats(stats_csv, rows)
    plot_histograms(rows, png_path, pdf_path)
    print(f"DELAY_HIST_PASS stats={stats_csv} png={png_path} pdf={pdf_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
