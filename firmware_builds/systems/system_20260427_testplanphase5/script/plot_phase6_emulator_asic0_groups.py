#!/usr/bin/env python3
"""Plot Phase-6 ASIC0 emulator rate and header-multiplicity histograms."""

from __future__ import annotations

import csv
import json
import re
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
REPORT_DIR = SYSTEM_DIR / "reports"
OUT_DIR = REPORT_DIR / "assets" / "phase6_emulator_asic0_20260502"
RATE_ORDER = [
    ("10k", 10_000.0),
    ("100k", 100_000.0),
    ("500k", 500_000.0),
    ("1M", 1_000_000.0),
]


def read_hist_csv(path: Path) -> tuple[list[float], list[int]]:
    centers: list[float] = []
    counts: list[int] = []
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            centers.append(float(row["bin_center"]))
            counts.append(int(row["count"]))
    return centers, counts


def weighted_quantile(centers: list[float], counts: list[int], fraction: float) -> float | None:
    total = sum(counts)
    if total <= 0:
        return None
    target = total * fraction
    acc = 0
    for center, count in zip(centers, counts):
        acc += count
        if acc >= target:
            return center
    return centers[-1] if centers else None


def load_rate_inputs() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for label, target_hz in RATE_ORDER:
        path = REPORT_DIR / f"phase6_emulator_asic0_rate_{label}_cluster31_20260502.csv"
        centers, counts = read_hist_csv(path)
        asic0 = counts[:32]
        nonzero = [value for value in asic0 if value > 0]
        mean_hz = sum(nonzero) / len(nonzero) if nonzero else 0.0
        rows.append(
            {
                "label": label,
                "target_hz_per_channel": target_hz,
                "path": str(path),
                "centers": centers,
                "counts": counts,
                "asic0_counts": asic0,
                "total": sum(counts),
                "nonzero_bins": sum(1 for value in counts if value > 0),
                "mean_hz_per_active_channel": mean_hz,
                "min_hz_per_active_channel": min(nonzero) if nonzero else 0.0,
                "max_hz_per_active_channel": max(nonzero) if nonzero else 0.0,
            }
        )
    return rows


def load_delay_inputs() -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for path in sorted(REPORT_DIR.glob("phase6_emulator_asic0_header_mult*_delay_hit_t_cluster31_20260502.csv")):
        match = re.search(r"mult(\d+)", path.name)
        if match is None:
            continue
        multiplicity = int(match.group(1))
        centers, counts = read_hist_csv(path)
        nonzero = [(center, count) for center, count in zip(centers, counts) if count > 0]
        total = sum(counts)
        in_window = sum(
            count for center, count in zip(centers, counts) if 0.0 <= center < 2000.0
        )
        low_out = sum(count for center, count in zip(centers, counts) if center < 0.0)
        high_out = sum(count for center, count in zip(centers, counts) if center >= 2000.0)
        out_window = total - in_window
        peak_center = max(nonzero, key=lambda item: item[1])[0] if nonzero else None
        q05 = weighted_quantile(centers, counts, 0.05)
        q95 = weighted_quantile(centers, counts, 0.95)
        rows.append(
            {
                "multiplicity": multiplicity,
                "path": str(path),
                "centers": centers,
                "counts": counts,
                "total": total,
                "nonzero_bins": len(nonzero),
                "peak_center": peak_center,
                "q05": q05,
                "q95": q95,
                "width_q05_q95": (q95 - q05) if q05 is not None and q95 is not None else None,
                "window_0_2000_in": in_window,
                "window_0_2000_out": out_window,
                "window_0_2000_in_pct": (100.0 * in_window / total) if total else 0.0,
                "window_0_2000_out_pct": (100.0 * out_window / total) if total else 0.0,
                "window_low_out": low_out,
                "window_high_out": high_out,
            }
        )
    return sorted(rows, key=lambda row: int(row["multiplicity"]))


def render_rate_group(rate_rows: list[dict[str, object]], out: Path) -> None:
    fig, axes = plt.subplots(2, 2, figsize=(13.5, 8.2), sharex=True)
    axes_flat = list(axes.flat)
    for ax, row in zip(axes_flat, rate_rows):
        counts = list(row["asic0_counts"])
        target = float(row["target_hz_per_channel"])
        channels = list(range(32))
        ax.bar(channels, [value / 1000.0 for value in counts], color="#2f6f9f", width=0.82)
        ax.axhline(target / 1000.0, color="#b3261e", linestyle="--", linewidth=1.5, label="target")
        ax.set_title(
            f"{row['label']} request: mean {float(row['mean_hz_per_active_channel']) / 1000.0:.1f} kHz/ch, "
            f"total {int(row['total']):,}"
        )
        ymax = max(max(counts) if counts else 0, target) / 1000.0
        ax.set_ylim(0.0, ymax * 1.18 if ymax > 0 else 1.0)
        ax.grid(True, axis="y", alpha=0.25)
        ax.set_xlim(-0.6, 31.6)
        ax.legend(loc="upper right", frameon=True)
    for ax in axes[-1, :]:
        ax.set_xlabel("ASIC0 channel bin")
    for ax in axes[:, 0]:
        ax.set_ylabel("Rate [kHz/channel]")
    fig.suptitle("ASIC0 Emulator Periodic-Mode Rate Sweep, Cluster Size 31", fontsize=15)
    fig.tight_layout(rect=(0, 0, 1, 0.96))
    fig.savefig(out, dpi=160)
    plt.close(fig)


def render_rate_saturation(rate_rows: list[dict[str, object]], out: Path) -> None:
    targets = [float(row["target_hz_per_channel"]) / 1000.0 for row in rate_rows]
    means = [float(row["mean_hz_per_active_channel"]) / 1000.0 for row in rate_rows]
    mins = [float(row["min_hz_per_active_channel"]) / 1000.0 for row in rate_rows]
    maxs = [float(row["max_hz_per_active_channel"]) / 1000.0 for row in rate_rows]
    labels = [str(row["label"]) for row in rate_rows]
    x = list(range(len(rate_rows)))
    fig, ax = plt.subplots(figsize=(8.6, 5.2))
    ax.plot(x, targets, "o--", color="#b3261e", label="requested")
    ax.plot(x, means, "o-", color="#2f6f9f", label="observed mean")
    ax.fill_between(x, mins, maxs, color="#2f6f9f", alpha=0.18, label="observed min..max")
    ax.set_xticks(x, labels)
    ax.set_ylabel("Rate [kHz/channel]")
    ax.set_title("ASIC0 Emulator Rate Saturation")
    ax.grid(True, alpha=0.25)
    ax.legend(loc="upper left", frameon=True)
    fig.tight_layout()
    fig.savefig(out, dpi=160)
    plt.close(fig)


def render_delay_group(delay_rows: list[dict[str, object]], out: Path) -> None:
    nonzero_centers = []
    for row in delay_rows:
        nonzero_centers.extend(
            center for center, count in zip(row["centers"], row["counts"]) if count > 0
        )
    xmin = min(0.0, min(nonzero_centers) - 96) if nonzero_centers else -1000
    xmax = max(2000.0, max(nonzero_centers) + 96) if nonzero_centers else 3096
    fig, ax = plt.subplots(figsize=(12.5, 6.8))
    colors = ["#2f6f9f", "#2f9f5f", "#b08a00", "#b85c38", "#7c4d99"]
    for idx, row in enumerate(delay_rows):
        total = int(row["total"])
        y = [(count / total * 100.0) if total else 0.0 for count in row["counts"]]
        ax.step(row["centers"], y, where="mid", linewidth=1.8, color=colors[idx % len(colors)], label=f"mult {row['multiplicity']}")
    ax.axvline(0, color="#555555", linewidth=1.0)
    ax.axvline(2000, color="#555555", linewidth=1.0)
    ax.set_xlim(xmin, xmax)
    ax.set_xlabel("Signed hit latency bin center [cycles]")
    ax.set_ylabel("Hits per bin [%]")
    ax.set_title("ASIC0 Emulator Header-Sync Delay Multiplicity, delay-hit-t")
    ax.grid(True, alpha=0.25)
    ax.legend(loc="upper right", frameon=True)
    fig.tight_layout()
    fig.savefig(out, dpi=160)
    plt.close(fig)


def write_summary_html(
    rate_rows: list[dict[str, object]],
    delay_rows: list[dict[str, object]],
    rate_plot: Path,
    saturation_plot: Path,
    delay_plot: Path,
    out: Path,
) -> None:
    lines = [
        "<!doctype html>",
        "<meta charset=\"utf-8\">",
        "<title>ASIC0 Emulator Histogram Groups 20260502</title>",
        "<style>body{font-family:Arial,sans-serif;margin:24px;max-width:1180px} img{max-width:100%;border:1px solid #ccc} table{border-collapse:collapse;margin:12px 0 28px} th,td{border:1px solid #ccc;padding:5px 8px;text-align:right} th:first-child,td:first-child{text-align:left} code{background:#eee;padding:1px 3px}</style>",
        "<h1>ASIC0 Emulator Histogram Groups</h1>",
        "<p>Inputs are JTAG 256-bin histogram CSV dumps collected with real MuTRiG lanes parked on emulator sources. The current hardware image accepts a maximum emulator cluster size of 31 because the 5-bit CSR wraps 32 to 0, and this image decodes 0 as one hit.</p>",
        f"<h2>Periodic Rate Group</h2><img src=\"{rate_plot.name}\" alt=\"rate group\">",
        f"<h2>Rate Saturation Summary</h2><img src=\"{saturation_plot.name}\" alt=\"rate saturation\">",
        "<table><tr><th>Request</th><th>Target kHz/ch</th><th>Observed mean kHz/ch</th><th>Min kHz/ch</th><th>Max kHz/ch</th><th>Total hits</th><th>Nonzero bins</th></tr>",
    ]
    for row in rate_rows:
        lines.append(
            "<tr>"
            f"<td>{row['label']}</td>"
            f"<td>{float(row['target_hz_per_channel']) / 1000.0:.3f}</td>"
            f"<td>{float(row['mean_hz_per_active_channel']) / 1000.0:.3f}</td>"
            f"<td>{float(row['min_hz_per_active_channel']) / 1000.0:.3f}</td>"
            f"<td>{float(row['max_hz_per_active_channel']) / 1000.0:.3f}</td>"
            f"<td>{int(row['total'])}</td>"
            f"<td>{int(row['nonzero_bins'])}</td>"
            "</tr>"
        )
    lines.extend(
        [
            "</table>",
            f"<h2>Header-Sync Delay Multiplicity Group</h2><img src=\"{delay_plot.name}\" alt=\"delay multiplicity\">",
            "<table><tr><th>Multiplicity</th><th>Total hits</th><th>Nonzero bins</th><th>Peak center</th><th>q05</th><th>q95</th><th>q95-q05</th><th>In [0,2000]</th><th>In %</th><th>Out %</th><th>Low out</th><th>High out</th></tr>",
        ]
    )
    for row in delay_rows:
        lines.append(
            "<tr>"
            f"<td>{row['multiplicity']}</td>"
            f"<td>{int(row['total'])}</td>"
            f"<td>{int(row['nonzero_bins'])}</td>"
            f"<td>{row['peak_center']}</td>"
            f"<td>{row['q05']}</td>"
            f"<td>{row['q95']}</td>"
            f"<td>{row['width_q05_q95']}</td>"
            f"<td>{int(row['window_0_2000_in'])}</td>"
            f"<td>{float(row['window_0_2000_in_pct']):.6f}</td>"
            f"<td>{float(row['window_0_2000_out_pct']):.6f}</td>"
            f"<td>{int(row['window_low_out'])}</td>"
            f"<td>{int(row['window_high_out'])}</td>"
            "</tr>"
        )
    lines.extend(
        [
            "</table>",
            "<p>Multiplicity 2 and 3, and multiplicity 4 and 5, collapse into near-identical CSV totals and shapes in this programmed image. That is consistent with the pre-ticket-FIFO emulator behavior where injector pulses arriving during an active burst are not fully queued.</p>",
        ]
    )
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    rate_rows = load_rate_inputs()
    delay_rows = load_delay_inputs()
    rate_plot = OUT_DIR / "phase6_emulator_asic0_rate_group.png"
    saturation_plot = OUT_DIR / "phase6_emulator_asic0_rate_saturation.png"
    delay_plot = OUT_DIR / "phase6_emulator_asic0_delay_multiplicity.png"
    summary_json = OUT_DIR / "phase6_emulator_asic0_group_stats.json"
    summary_html = OUT_DIR / "phase6_emulator_asic0_groups.html"
    render_rate_group(rate_rows, rate_plot)
    render_rate_saturation(rate_rows, saturation_plot)
    render_delay_group(delay_rows, delay_plot)
    summary_json.write_text(
        json.dumps(
            {
                "rate": [
                    {key: value for key, value in row.items() if key not in {"centers", "counts", "asic0_counts"}}
                    for row in rate_rows
                ],
                "delay": [
                    {key: value for key, value in row.items() if key not in {"centers", "counts"}}
                    for row in delay_rows
                ],
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    write_summary_html(rate_rows, delay_rows, rate_plot, saturation_plot, delay_plot, summary_html)
    print(rate_plot)
    print(saturation_plot)
    print(delay_plot)
    print(summary_html)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
