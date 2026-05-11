#!/usr/bin/env python3
"""Render RTL ASIC0 post-rbCAM delay histograms."""

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
INPUT_DIR = SYSTEM_DIR / "model" / "phase4" / "inputs"
OUT_DIR = SYSTEM_DIR / "reports" / "assets" / "phase6_rtl_post_rbcam_20260502"

CASES = [
    {
        "name": "header_sync_mult5",
        "title": "Header sync, multiplicity 5",
        "base_dir": INPUT_DIR / "rtl_asic0_post_rbcam_smoke_abs_20260502_wide",
        "plot": "rtl_asic0_post_rbcam_delay_hist.png",
    },
    {
        "name": "periodic_100k",
        "title": "Periodic mode 2, 100 kHz/channel",
        "base_dir": INPUT_DIR / "rtl_asic0_post_rbcam_rate100k_20260502",
        "plot": "rtl_asic0_post_rbcam_periodic100k_delay_hist.png",
    },
]

STATUS_RE = re.compile(
    r"TB_POST_HIST_STATUS .* total=0x(?P<total>[0-9a-fA-F]+) "
    r"dropped=0x(?P<dropped>[0-9a-fA-F]+) under=0x(?P<under>[0-9a-fA-F]+) "
    r"over=0x(?P<over>[0-9a-fA-F]+)"
)
WINDOW_RE = re.compile(
    r"TB_POST_HIST_WINDOW rbCAM=\[0,2000\] in=(?P<in_count>\d+) "
    r"\((?P<in_pct>[0-9.]+)%\) out=(?P<out_count>\d+) "
    r"\((?P<out_pct>[0-9.]+)%\) configured_under=(?P<under_count>\d+) "
    r"\((?P<under_pct>[0-9.]+)%\) configured_over=(?P<over_count>\d+) "
    r"\((?P<over_pct>[0-9.]+)%\)"
)
DELAY_RE = re.compile(
    r"TB_POST_HIST_DELAY total=(?P<csv_reported_total>\d+) "
    r"active=(?P<active_reported>\d+) min_nonzero=(?P<min_nonzero>\d+) "
    r"max_nonzero=(?P<max_nonzero>\d+) peak_bin=(?P<peak_bin>\d+) "
    r"peak_center_cycles=(?P<peak_center_cycles>-?\d+)"
)
INJECTOR_RE = re.compile(
    r"TB_POST_HIST_INJECTOR mode=(?P<mode>\d+) "
    r"pulse_interval=(?P<pulse_interval>\d+) pulse_high=(?P<pulse_high>\d+)"
)
CFG0_RE = re.compile(
    r"TB_POST_HIST_CFG lane=0 hit_rate=0x(?P<hit_rate>[0-9a-fA-F]+) "
    r"noise_rate=0x(?P<noise_rate>[0-9a-fA-F]+) hit_mode=(?P<hit_mode>\d+) "
    r"burst_size=(?P<burst_size>\d+) burst_center=(?P<burst_center>\d+)"
)


def read_hist(path: Path) -> dict[str, object]:
    centers: list[int] = []
    counts: list[int] = []
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            centers.append(int(row["latency_center_cycles"]))
            counts.append(int(row["count"]))
    return {
        "centers": centers,
        "counts": counts,
        "csv_total": sum(counts),
        "active_bins": sum(1 for count in counts if count > 0),
    }


def parse_log(path: Path) -> dict[str, object]:
    status: dict[str, int] | None = None
    window: dict[str, float | int] | None = None
    delay: dict[str, int] | None = None
    injector: dict[str, int] | None = None
    cfg0: dict[str, int] | None = None
    passed = False

    for line in path.read_text(encoding="utf-8").splitlines():
        match = STATUS_RE.search(line)
        if match:
            status = {key: int(value, 16) for key, value in match.groupdict().items()}
            continue
        match = WINDOW_RE.search(line)
        if match:
            window = {
                "in_count": int(match.group("in_count")),
                "in_pct": float(match.group("in_pct")),
                "out_count": int(match.group("out_count")),
                "out_pct": float(match.group("out_pct")),
                "under_count": int(match.group("under_count")),
                "under_pct": float(match.group("under_pct")),
                "over_count": int(match.group("over_count")),
                "over_pct": float(match.group("over_pct")),
            }
            continue
        match = DELAY_RE.search(line)
        if match:
            delay = {key: int(value) for key, value in match.groupdict().items()}
            continue
        match = INJECTOR_RE.search(line)
        if match:
            injector = {key: int(value) for key, value in match.groupdict().items()}
            continue
        match = CFG0_RE.search(line)
        if match:
            cfg0 = {
                "hit_rate": int(match.group("hit_rate"), 16),
                "noise_rate": int(match.group("noise_rate"), 16),
                "hit_mode": int(match.group("hit_mode")),
                "burst_size": int(match.group("burst_size")),
                "burst_center": int(match.group("burst_center")),
            }
            continue
        if "Results: 6 PASSED, 0 FAILED" in line:
            passed = True

    return {
        "status": status,
        "window": window,
        "delay": delay,
        "injector": injector,
        "cfg0": cfg0,
        "passed": passed,
    }


def percent_counts(hist: dict[str, object], log: dict[str, object]) -> list[float]:
    status = log["status"] or {}
    total = int(status.get("total", hist["csv_total"]))
    return [(count / total * 100.0) if total else 0.0 for count in hist["counts"]]


def caption(hist: dict[str, object], log: dict[str, object]) -> str:
    status = log["status"] or {}
    window = log["window"] or {}
    total = int(status.get("total", hist["csv_total"]))
    return (
        f"total={total}, csv_total={hist['csv_total']}, active_bins={hist['active_bins']}; "
        f"in[0,2000]={window.get('in_count', 0)} ({window.get('in_pct', 0.0):.3f}%), "
        f"out={window.get('out_count', 0)} ({window.get('out_pct', 0.0):.3f}%)"
    )


def render_plot(
    title: str,
    hist: dict[str, object],
    log: dict[str, object],
    out: Path,
    color: str,
    edgecolor: str,
) -> None:
    fig, ax = plt.subplots(figsize=(11.2, 6.4))
    ax.bar(hist["centers"], percent_counts(hist, log), width=13.5, color=color, edgecolor=edgecolor)
    ax.axvline(0, color="#1f9d55", linewidth=1.6, label="rbCAM window edge")
    ax.axvline(2000, color="#1f9d55", linewidth=1.6)
    ax.set_xlim(-1050, 3100)
    ax.set_xlabel("Signed hit latency bin center [cycles]")
    ax.set_ylabel("Hits per bin [% of accounted hits]")
    ax.set_title(f"RTL ASIC0 Post-rbCAM Delay - {title}")
    ax.grid(True, axis="y", alpha=0.25)
    ax.text(0.0, -0.18, caption(hist, log), transform=ax.transAxes, ha="left", va="top", fontsize=10)
    ax.legend(loc="upper right", frameon=True)
    fig.tight_layout()
    fig.savefig(out, dpi=160)
    plt.close(fig)


def render_comparison(cases: list[dict[str, object]], out: Path) -> None:
    fig, axes = plt.subplots(len(cases), 1, figsize=(11.2, 7.8), sharex=True, sharey=True)
    if len(cases) == 1:
        axes = [axes]

    for ax, case in zip(axes, cases):
        hist = case["histogram"]
        log = case["log"]
        ax.bar(
            hist["centers"],
            percent_counts(hist, log),
            width=13.5,
            color=case["color"],
            edgecolor=case["edgecolor"],
        )
        ax.axvline(0, color="#1f9d55", linewidth=1.35)
        ax.axvline(2000, color="#1f9d55", linewidth=1.35)
        ax.set_xlim(-1050, 3100)
        ax.set_ylabel("% of hits")
        ax.set_title(case["title"], loc="left", fontsize=12)
        ax.grid(True, axis="y", alpha=0.25)
        ax.text(0.01, 0.91, caption(hist, log), transform=ax.transAxes, ha="left", va="top", fontsize=9)

    axes[-1].set_xlabel("Signed hit latency bin center [cycles]")
    fig.suptitle("RTL ASIC0 Post-rbCAM Delay Modes", fontsize=14)
    fig.tight_layout()
    fig.savefig(out, dpi=160)
    plt.close(fig)


def collect_case(case: dict[str, object], color: str, edgecolor: str) -> dict[str, object]:
    base_dir = case["base_dir"]
    hist = read_hist(base_dir / "post_rbcam_delay_hist.csv")
    log = parse_log(base_dir / "run.log")
    plot_path = OUT_DIR / str(case["plot"])
    render_plot(str(case["title"]), hist, log, plot_path, color, edgecolor)
    return {
        "name": case["name"],
        "title": case["title"],
        "base_dir": str(base_dir),
        "plot": str(plot_path),
        "histogram": hist,
        "log": log,
        "color": color,
        "edgecolor": edgecolor,
    }


def compact_summary(case: dict[str, object]) -> dict[str, object]:
    hist = case["histogram"]
    log = case["log"]
    return {
        "name": case["name"],
        "title": case["title"],
        "base_dir": case["base_dir"],
        "plot": case["plot"],
        "csv_total": hist["csv_total"],
        "active_bins": hist["active_bins"],
        "status": log["status"],
        "window": log["window"],
        "delay": log["delay"],
        "injector": log["injector"],
        "cfg0": log["cfg0"],
        "passed": log["passed"],
    }


def main() -> int:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    palette = [("#2f6f9f", "#1e4c73"), ("#b45f06", "#7a3f04")]
    cases = [
        collect_case(case, color, edgecolor)
        for case, (color, edgecolor) in zip(CASES, palette)
    ]
    comparison_path = OUT_DIR / "rtl_asic0_post_rbcam_delay_modes.png"
    summary_path = OUT_DIR / "rtl_asic0_post_rbcam_delay_summary.json"
    render_comparison(cases, comparison_path)
    summary_path.write_text(
        json.dumps(
            {
                "cases": [compact_summary(case) for case in cases],
                "comparison_plot": str(comparison_path),
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    for case in cases:
        print(case["plot"])
    print(comparison_path)
    print(summary_path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
