#!/usr/bin/env python3
"""Render RTL integration ASIC0 emulator header/rate sweep plots."""

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
BASE_DIR = (
    SYSTEM_DIR
    / "model"
    / "phase4"
    / "inputs"
    / "rtl_asic0_emulator_groups_20260502"
)
OUT_DIR = SYSTEM_DIR / "reports" / "assets" / "phase6_rtl_asic0_emulator_groups_20260502"
HEADER_CASES = [(idx, f"header_mult{idx}") for idx in range(1, 6)]
RATE_CASES = [
    ("10k", "rate_10k", 10_000.0, 12_500),
    ("100k", "rate_100k", 100_000.0, 1_250),
    ("500k", "rate_500k", 500_000.0, 250),
    ("1M", "rate_1M", 1_000_000.0, 125),
]
LVDS_CLOCK_HZ = 125_000_000.0

RUN_RE = re.compile(r"TB_MEAS run_cycles=(?P<run_cycles>\d+)")
RATE_STATUS_RE = re.compile(
    r"TB_MEAS_RATE_STATUS ctrl=0x(?P<ctrl>[0-9a-fA-F]+) "
    r"total=0x(?P<total>[0-9a-fA-F]+) dropped=0x(?P<dropped>[0-9a-fA-F]+) "
    r"under=0x(?P<under>[0-9a-fA-F]+) over=0x(?P<over>[0-9a-fA-F]+)"
)
LAT_STATUS_RE = re.compile(
    r"TB_MEAS_LAT_STATUS ctrl=0x(?P<ctrl>[0-9a-fA-F]+) "
    r"total=0x(?P<total>[0-9a-fA-F]+) dropped=0x(?P<dropped>[0-9a-fA-F]+) "
    r"under=0x(?P<under>[0-9a-fA-F]+) over=0x(?P<over>[0-9a-fA-F]+)"
)


def parse_log(path: Path) -> dict[str, object]:
    result: dict[str, object] = {
        "run_cycles": None,
        "rate_status": None,
        "lat_status": None,
    }
    for line in path.read_text(encoding="utf-8").splitlines():
        if result["run_cycles"] is None:
            match = RUN_RE.search(line)
            if match:
                result["run_cycles"] = int(match.group("run_cycles"))
                continue
        match = RATE_STATUS_RE.search(line)
        if match:
            result["rate_status"] = {
                key: int(value, 16) for key, value in match.groupdict().items()
            }
            continue
        match = LAT_STATUS_RE.search(line)
        if match:
            result["lat_status"] = {
                key: int(value, 16) for key, value in match.groupdict().items()
            }
    return result


def read_rate_csv(path: Path) -> dict[str, object]:
    bins: list[int] = []
    counts: list[int] = []
    channel_counts: dict[int, int] = {}
    asic_counts: dict[int, int] = {}
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            idx = int(row["bin"])
            asic = int(row["asic"])
            channel = int(row["channel"])
            count = int(row["count"])
            bins.append(idx)
            counts.append(count)
            asic_counts[asic] = asic_counts.get(asic, 0) + count
            channel_counts[channel] = channel_counts.get(channel, 0) + count
    nonzero_channels = [ch for ch, count in channel_counts.items() if count > 0]
    return {
        "bins": bins,
        "counts": counts,
        "asic_counts": dict(sorted(asic_counts.items())),
        "channel_counts": dict(sorted(channel_counts.items())),
        "total": sum(counts),
        "active_bins": sum(1 for count in counts if count > 0),
        "active_channels": sorted(nonzero_channels),
    }


def read_latency_csv(path: Path) -> dict[str, object]:
    centers: list[int] = []
    counts: list[int] = []
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            centers.append(int(row["latency_cycles"]))
            counts.append(int(row["count"]))
    total = sum(counts)
    nonzero = [(center, count) for center, count in zip(centers, counts) if count > 0]
    return {
        "centers": centers,
        "counts": counts,
        "total": total,
        "active_bins": len(nonzero),
        "min": min((center for center, _ in nonzero), default=None),
        "max": max((center for center, _ in nonzero), default=None),
        "p50": weighted_quantile(centers, counts, 0.50),
        "p90": weighted_quantile(centers, counts, 0.90),
        "p99": weighted_quantile(centers, counts, 0.99),
    }


def weighted_quantile(centers: list[int], counts: list[int], fraction: float) -> int | None:
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


def load_case(case_dir: str) -> dict[str, object]:
    path = BASE_DIR / case_dir
    summary = json.loads((path / "summary.json").read_text(encoding="utf-8"))
    log = parse_log(path / "run.log")
    return {
        "name": case_dir,
        "path": str(path),
        "summary": summary,
        "log": log,
        "rate": read_rate_csv(path / "pre_rbcam_rate_hist.csv"),
        "latency": read_latency_csv(path / "emulator_dispatch_latency_hist.csv"),
    }


def render_header_latency(rows: list[dict[str, object]], out: Path) -> None:
    fig, ax = plt.subplots(figsize=(10.8, 6.2))
    colors = ["#4060a8", "#2f8a5b", "#aa7a00", "#b4553d", "#7550a0"]
    for idx, row in enumerate(rows):
        latency = row["latency"]
        total = int(latency["total"])
        if total <= 0:
            continue
        y_values = [count / total * 100.0 for count in latency["counts"]]
        ax.step(
            latency["centers"],
            y_values,
            where="mid",
            linewidth=1.8,
            color=colors[idx % len(colors)],
            label=f"mult {row['multiplicity']}",
        )
    ax.set_xlim(805, 835)
    ax.set_xlabel("Dispatch latency [cycles]")
    ax.set_ylabel("Hits per latency bin [%]")
    ax.set_title("RTL ASIC0 Header-Sync Delay Multiplicity")
    ax.grid(True, alpha=0.25)
    ax.legend(loc="upper right", frameon=True)
    fig.tight_layout()
    fig.savefig(out, dpi=160)
    plt.close(fig)


def render_header_width(rows: list[dict[str, object]], out: Path) -> None:
    mult = [int(row["multiplicity"]) for row in rows]
    active = [int(row["latency"]["active_bins"]) for row in rows]
    span = [
        0 if row["latency"]["min"] is None else int(row["latency"]["max"]) - int(row["latency"]["min"])
        for row in rows
    ]
    hits = [int(row["rate"]["total"]) for row in rows]
    fig, ax = plt.subplots(figsize=(8.8, 5.4))
    ax.plot(mult, active, "o-", color="#4060a8", label="active latency bins")
    ax.plot(mult, span, "s-", color="#b4553d", label="latency span [cycles]")
    ax.set_xlabel("Header multiplicity")
    ax.set_ylabel("Width")
    ax.set_xticks(mult)
    ax.grid(True, alpha=0.25)
    ax2 = ax.twinx()
    ax2.plot(mult, hits, "^-", color="#2f8a5b", label="accepted hits")
    ax2.set_ylabel("Accepted hits")
    lines = ax.get_lines() + ax2.get_lines()
    ax.legend(lines, [line.get_label() for line in lines], loc="upper left", frameon=True)
    ax.set_title("RTL ASIC0 Header-Sync Width Growth")
    fig.tight_layout()
    fig.savefig(out, dpi=160)
    plt.close(fig)


def render_rate_saturation(rows: list[dict[str, object]], out: Path) -> None:
    labels = [str(row["label"]) for row in rows]
    xvals = list(range(len(rows)))
    target = [float(row["target_hz"]) / 1000.0 for row in rows]
    observed = [float(row["observed_hz_per_channel"]) / 1000.0 for row in rows]
    fig, ax = plt.subplots(figsize=(8.8, 5.4))
    ax.plot(xvals, target, "o--", color="#b3261e", label="requested")
    ax.plot(xvals, observed, "o-", color="#2f6f9f", label="observed ASIC0 mean")
    ax.set_xticks(xvals, labels)
    ax.set_ylabel("Rate [kHz/channel]")
    ax.set_title("RTL ASIC0 Periodic Injector Rate Sweep")
    ax.grid(True, alpha=0.25)
    ax.legend(loc="upper left", frameon=True)
    fig.tight_layout()
    fig.savefig(out, dpi=160)
    plt.close(fig)


def render_rate_channels(rows: list[dict[str, object]], out: Path) -> None:
    fig, axes = plt.subplots(2, 2, figsize=(12.8, 7.8), sharex=True)
    for ax, row in zip(axes.flat, rows):
        run_s = int(row["run_cycles"]) / LVDS_CLOCK_HZ
        rates = [
            int(row["rate"]["channel_counts"].get(ch, 0)) / run_s / 1000.0
            for ch in range(32)
        ]
        ax.bar(range(32), rates, width=0.82, color="#2f6f9f")
        ax.axhline(float(row["target_hz"]) / 1000.0, color="#b3261e", linestyle="--", linewidth=1.3)
        ax.set_title(
            f"{row['label']} request, observed {float(row['observed_hz_per_channel']) / 1000.0:.1f} kHz/ch"
        )
        ax.set_xlim(-0.6, 31.6)
        ax.grid(True, axis="y", alpha=0.25)
    for ax in axes[-1, :]:
        ax.set_xlabel("ASIC0 channel")
    for ax in axes[:, 0]:
        ax.set_ylabel("Rate [kHz/channel]")
    fig.suptitle("RTL ASIC0 Periodic Injector Per-Channel Rates", fontsize=15)
    fig.tight_layout(rect=(0, 0, 1, 0.96))
    fig.savefig(out, dpi=160)
    plt.close(fig)


def write_html(
    header_rows: list[dict[str, object]],
    rate_rows: list[dict[str, object]],
    plots: dict[str, Path],
    out: Path,
) -> None:
    lines = [
        "<!doctype html>",
        "<meta charset=\"utf-8\">",
        "<title>RTL ASIC0 Emulator Groups 20260502</title>",
        "<style>body{font-family:Arial,sans-serif;margin:24px;max-width:1180px} img{max-width:100%;border:1px solid #ccc} table{border-collapse:collapse;margin:12px 0 28px} th,td{border:1px solid #ccc;padding:5px 8px;text-align:right} th:first-child,td:first-child{text-align:left} code{background:#eee;padding:1px 3px}</style>",
        "<h1>RTL ASIC0 Emulator Groups</h1>",
        "<p>All cases use <code>TB_DP_ACTIVE_LANE_MASK=0x01</code>, injector fanout enabled, and source RTL overrides for the emulator ticket-FIFO and histogram IP.</p>",
        f"<h2>Header-Sync Delay Multiplicity</h2><img src=\"{plots['header_latency'].name}\">",
        f"<h2>Header-Sync Width Summary</h2><img src=\"{plots['header_width'].name}\">",
        "<table><tr><th>Multiplicity</th><th>Accepted hits</th><th>Active channel bins</th><th>Latency samples</th><th>Latency min</th><th>Latency max</th><th>Active latency bins</th></tr>",
    ]
    for row in header_rows:
        lat = row["latency"]
        lines.append(
            "<tr>"
            f"<td>{row['multiplicity']}</td>"
            f"<td>{int(row['rate']['total'])}</td>"
            f"<td>{int(row['rate']['active_bins'])}</td>"
            f"<td>{int(lat['total'])}</td>"
            f"<td>{lat['min']}</td>"
            f"<td>{lat['max']}</td>"
            f"<td>{int(lat['active_bins'])}</td>"
            "</tr>"
        )
    lines.extend(
        [
            "</table>",
            f"<h2>Periodic Rate Sweep</h2><img src=\"{plots['rate_saturation'].name}\">",
            f"<h2>Per-Channel Rate Bins</h2><img src=\"{plots['rate_channels'].name}\">",
            "<table><tr><th>Request</th><th>Period cycles</th><th>Run cycles</th><th>Expected hits</th><th>Observed hits</th><th>Observed kHz/ch</th><th>Active bins</th><th>Rate dropped</th><th>Rate under</th><th>Rate over</th></tr>",
        ]
    )
    for row in rate_rows:
        status = row["log"]["rate_status"] or {}
        lines.append(
            "<tr>"
            f"<td>{row['label']}</td>"
            f"<td>{row['period_cycles']}</td>"
            f"<td>{row['run_cycles']}</td>"
            f"<td>{row['expected_hits']:.0f}</td>"
            f"<td>{int(row['rate']['total'])}</td>"
            f"<td>{float(row['observed_hz_per_channel']) / 1000.0:.3f}</td>"
            f"<td>{int(row['rate']['active_bins'])}</td>"
            f"<td>{status.get('dropped', 0)}</td>"
            f"<td>{status.get('under', 0)}</td>"
            f"<td>{status.get('over', 0)}</td>"
            "</tr>"
        )
    lines.append("</table>")
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    header_rows: list[dict[str, object]] = []
    for mult, case_name in HEADER_CASES:
        row = load_case(case_name)
        row["multiplicity"] = mult
        header_rows.append(row)

    rate_rows: list[dict[str, object]] = []
    for label, case_name, target_hz, period_cycles in RATE_CASES:
        row = load_case(case_name)
        run_cycles = int(row["log"]["run_cycles"])
        run_s = run_cycles / LVDS_CLOCK_HZ
        active_bins = int(row["rate"]["active_bins"])
        mean_count = int(row["rate"]["total"]) / active_bins if active_bins else 0.0
        row["label"] = label
        row["target_hz"] = target_hz
        row["period_cycles"] = period_cycles
        row["run_cycles"] = run_cycles
        row["expected_hits"] = target_hz * run_s * 31.0
        row["observed_hz_per_channel"] = mean_count / run_s if run_s > 0 else 0.0
        rate_rows.append(row)

    plots = {
        "header_latency": OUT_DIR / "rtl_asic0_header_multiplicity_latency.png",
        "header_width": OUT_DIR / "rtl_asic0_header_multiplicity_width.png",
        "rate_saturation": OUT_DIR / "rtl_asic0_periodic_rate_saturation.png",
        "rate_channels": OUT_DIR / "rtl_asic0_periodic_channel_rates.png",
    }
    render_header_latency(header_rows, plots["header_latency"])
    render_header_width(header_rows, plots["header_width"])
    render_rate_saturation(rate_rows, plots["rate_saturation"])
    render_rate_channels(rate_rows, plots["rate_channels"])

    summary_json = OUT_DIR / "rtl_asic0_emulator_group_stats.json"
    summary_json.write_text(
        json.dumps(
            {
                "base_dir": str(BASE_DIR),
                "header": [
                    {
                        "multiplicity": row["multiplicity"],
                        "accepted_hits": row["rate"]["total"],
                        "active_channel_bins": row["rate"]["active_bins"],
                        "latency": {
                            key: row["latency"][key]
                            for key in ["total", "active_bins", "min", "max", "p50", "p90", "p99"]
                        },
                    }
                    for row in header_rows
                ],
                "rate": [
                    {
                        "label": row["label"],
                        "period_cycles": row["period_cycles"],
                        "run_cycles": row["run_cycles"],
                        "target_hz_per_channel": row["target_hz"],
                        "expected_hits": row["expected_hits"],
                        "observed_hits": row["rate"]["total"],
                        "observed_hz_per_channel": row["observed_hz_per_channel"],
                        "active_bins": row["rate"]["active_bins"],
                        "rate_status": row["log"]["rate_status"],
                        "latency": {
                            key: row["latency"][key]
                            for key in ["total", "active_bins", "min", "max", "p50", "p90", "p99"]
                        },
                        "ts_summary": row["summary"]["log"]["ts_summary"],
                    }
                    for row in rate_rows
                ],
                "plots": {key: str(path) for key, path in plots.items()},
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    summary_html = OUT_DIR / "rtl_asic0_emulator_groups.html"
    write_html(header_rows, rate_rows, plots, summary_html)
    for path in [*plots.values(), summary_json, summary_html]:
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
