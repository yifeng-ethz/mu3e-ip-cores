#!/usr/bin/env python3
"""Run and summarize FEB/SWB Poisson iid OPQ throughput scan points."""

from __future__ import annotations

import argparse
import csv
import math
import os
import re
import subprocess
from pathlib import Path

CHANNELS_PER_ASIC = 32
DEFAULT_ASICS = 8
FRAME_STRIDE_8NS = 2048
SUBHEADER_STRIDE_8NS = 16
DEFAULT_RUN_WINDOW_8NS = 125000
DEFAULT_N_HIT = 2047
DEFAULT_DMA_HIT_CAPACITY_PER_FRAME = FRAME_STRIDE_8NS - 1
DEFAULT_ACTIVE_HIT_LANES = 2

SELECTED_RATES_KHZ = [
    50.0,
    100.0,
    200.0,
    400.0,
    500.0,
    650.0,
    800.0,
    900.0,
    950.0,
    975.0,
    1000.0,
]

SCAN_COLUMNS = [
    "rate_hz_per_channel",
    "actual_rate_hz_per_channel",
    "hit_period_8ns",
    "run_window_8ns",
    "active_channels",
    "frames",
    "measured_valid",
    "expected_hits",
    "actual_hits",
    "missing_hits",
    "ghost_hits",
    "dma_payload_words",
    "opq_beats",
    "ft_wr_hit",
    "ft_rd_hit",
    "lane0_wr_hit",
    "lane0_drop_hit",
    "lane0_handle_drop_hit",
    "measured_delivered_mhits_s",
    "measured_drop_mhits_s",
    "measured_delivery_fraction",
    "measured_drop_fraction",
    "model_expected_hits",
    "model_delivered_hits",
    "model_dropped_hits",
    "model_delivered_mhits_s",
    "model_drop_mhits_s",
    "model_delivery_fraction",
    "model_drop_fraction",
    "format_model_expected_hits",
    "format_model_delivered_hits",
    "format_model_dropped_hits",
    "format_model_delivered_mhits_s",
    "format_model_drop_mhits_s",
    "format_model_delivery_fraction",
    "format_model_drop_fraction",
    "model_active_hit_lanes",
    "model_dma_hit_capacity_per_frame",
    "lane1_wr_hit",
    "lane1_drop_hit",
    "lane1_handle_drop_hit",
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--report-dir", default="report_rate_scan")
    parser.add_argument("--run-window-8ns", type=int, default=DEFAULT_RUN_WINDOW_8NS)
    parser.add_argument("--asic-count", type=int, default=DEFAULT_ASICS)
    parser.add_argument("--n-hit", type=int, default=DEFAULT_N_HIT)
    parser.add_argument("--dma-hit-capacity-per-frame", type=int, default=DEFAULT_DMA_HIT_CAPACITY_PER_FRAME)
    parser.add_argument("--active-hit-lanes", type=int, default=DEFAULT_ACTIVE_HIT_LANES)
    parser.add_argument("--seed", type=int, default=20260508)
    parser.add_argument("--rates-khz", default=",".join(str(x) for x in SELECTED_RATES_KHZ))
    parser.add_argument("--prescan-only", action="store_true")
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--make", default="make")
    parser.add_argument("--questa-home", default="/data1/questaone_sim-2026.1_1/questasim")
    parser.add_argument("--musip-root", default="/home/yifeng/packages/musip_2604")
    parser.add_argument("--opq-source-mode", default="native_sv_signoff")
    parser.add_argument("--opq-debug-level", type=int, default=1)
    parser.add_argument("--opq-lane-fifo-depth", type=int, default=65536)
    parser.add_argument("--opq-ticket-fifo-depth", type=int, default=65536)
    parser.add_argument("--opq-handle-fifo-depth", type=int, default=64)
    parser.add_argument("--opq-page-ram-depth", type=int, default=65536)
    parser.add_argument("--drain-swb-cycles", type=int, default=500000)
    return parser.parse_args()


def period_for_rate(rate_hz: float) -> int:
    return max(1, int(round(125_000_000.0 / rate_hz)))


def actual_rate_from_period(period_8ns: int) -> float:
    return 125_000_000.0 / float(period_8ns)


def frame_durations_8ns(run_window_8ns: int) -> list[int]:
    frames = int(math.ceil(run_window_8ns / FRAME_STRIDE_8NS))
    durations: list[int] = []
    for frame in range(frames):
        start = frame * FRAME_STRIDE_8NS
        remaining = max(0, run_window_8ns - start)
        durations.append(min(FRAME_STRIDE_8NS, remaining))
    return durations


def subheader_durations_8ns(run_window_8ns: int) -> list[int]:
    buckets = int(math.ceil(run_window_8ns / SUBHEADER_STRIDE_8NS))
    durations: list[int] = []
    for bucket in range(buckets):
        start = bucket * SUBHEADER_STRIDE_8NS
        remaining = max(0, run_window_8ns - start)
        durations.append(min(SUBHEADER_STRIDE_8NS, remaining))
    return durations


def normal_pdf(x: float) -> float:
    return math.exp(-0.5 * x * x) / math.sqrt(2.0 * math.pi)


def normal_cdf(x: float) -> float:
    return 0.5 * (1.0 + math.erf(x / math.sqrt(2.0)))


def expected_min_poisson(lam: float, cap: int) -> float:
    if lam <= 0.0:
        return 0.0
    sigma = math.sqrt(lam)
    if float(cap) >= lam + 12.0 * sigma + 16.0:
        return lam
    if lam < 700.0:
        p = math.exp(-lam)
        cdf = p
        partial_mean = 0.0
        for k in range(1, cap + 1):
            p *= lam / float(k)
            cdf += p
            partial_mean += float(k) * p
        return partial_mean + float(cap) * max(0.0, 1.0 - cdf)
    z = (float(cap) + 0.5 - lam) / sigma
    phi = normal_pdf(z)
    cdf = normal_cdf(z)
    return lam * cdf - sigma * phi + float(cap) * (1.0 - cdf)


def capped_poisson_sum(
    actual_rate: float,
    active_channels: int,
    durations_8ns: list[int],
    cap: int,
) -> tuple[float, float, float]:
    expected_hits = 0.0
    delivered_hits = 0.0
    for duration_8ns in durations_8ns:
        lam = active_channels * actual_rate * duration_8ns * 8.0e-9
        expected_hits += lam
        delivered_hits += expected_min_poisson(lam, cap)
    dropped_hits = max(0.0, expected_hits - delivered_hits)
    return expected_hits, delivered_hits, dropped_hits


def capped_poisson_sum_per_lane(
    actual_rate: float,
    active_channels: int,
    active_lanes: int,
    durations_8ns: list[int],
    cap_per_lane: int,
) -> tuple[float, float, float]:
    lanes = max(1, active_lanes)
    lane_channels = active_channels / float(lanes)
    expected_hits = 0.0
    delivered_hits = 0.0
    dropped_hits = 0.0
    for _lane in range(lanes):
        lane_expected, lane_delivered, lane_dropped = capped_poisson_sum(
            actual_rate,
            int(round(lane_channels)),
            durations_8ns,
            cap_per_lane,
        )
        expected_hits += lane_expected
        delivered_hits += lane_delivered
        dropped_hits += lane_dropped
    return expected_hits, delivered_hits, dropped_hits


def expected_arrivals(
    actual_rate: float,
    active_channels: int,
    durations_8ns: list[int],
) -> float:
    expected_hits = 0.0
    for duration_8ns in durations_8ns:
        expected_hits += active_channels * actual_rate * duration_8ns * 8.0e-9
    return expected_hits


def model_row(
    rate_hz: float,
    run_window_8ns: int,
    asics: int,
    n_hit: int,
    dma_hit_capacity_per_frame: int,
    active_hit_lanes: int,
) -> dict[str, float | int | str]:
    period = period_for_rate(rate_hz)
    actual_rate = actual_rate_from_period(period)
    active_channels = asics * CHANNELS_PER_ASIC
    expected_hits = expected_arrivals(
        actual_rate,
        active_channels,
        frame_durations_8ns(run_window_8ns),
    )
    delivered_hits = expected_hits
    dropped_hits = 0.0
    format_expected_hits, format_delivered_hits, format_dropped_hits = capped_poisson_sum_per_lane(
        actual_rate,
        active_channels,
        active_hit_lanes,
        subheader_durations_8ns(run_window_8ns),
        n_hit,
    )
    seconds = run_window_8ns * 8.0e-9
    return {
        "rate_hz_per_channel": rate_hz,
        "actual_rate_hz_per_channel": actual_rate,
        "hit_period_8ns": period,
        "run_window_8ns": run_window_8ns,
        "active_channels": active_channels,
        "frames": len(frame_durations_8ns(run_window_8ns)),
        "measured_valid": 0,
        "expected_hits": "",
        "actual_hits": "",
        "missing_hits": "",
        "ghost_hits": "",
        "dma_payload_words": "",
        "opq_beats": "",
        "ft_wr_hit": "",
        "ft_rd_hit": "",
        "lane0_wr_hit": "",
        "lane0_drop_hit": "",
        "lane0_handle_drop_hit": "",
        "lane1_wr_hit": "",
        "lane1_drop_hit": "",
        "lane1_handle_drop_hit": "",
        "measured_delivered_mhits_s": "",
        "measured_drop_mhits_s": "",
        "measured_delivery_fraction": "",
        "measured_drop_fraction": "",
        "model_expected_hits": expected_hits,
        "model_delivered_hits": delivered_hits,
        "model_dropped_hits": dropped_hits,
        "model_delivered_mhits_s": delivered_hits / seconds / 1.0e6,
        "model_drop_mhits_s": dropped_hits / seconds / 1.0e6,
        "model_delivery_fraction": delivered_hits / expected_hits if expected_hits else 0.0,
        "model_drop_fraction": dropped_hits / expected_hits if expected_hits else 0.0,
        "format_model_expected_hits": format_expected_hits,
        "format_model_delivered_hits": format_delivered_hits,
        "format_model_dropped_hits": format_dropped_hits,
        "format_model_delivered_mhits_s": format_delivered_hits / seconds / 1.0e6,
        "format_model_drop_mhits_s": format_dropped_hits / seconds / 1.0e6,
        "format_model_delivery_fraction": (
            format_delivered_hits / format_expected_hits if format_expected_hits else 0.0
        ),
        "format_model_drop_fraction": format_dropped_hits / format_expected_hits if format_expected_hits else 0.0,
        "model_active_hit_lanes": active_hit_lanes,
        "model_dma_hit_capacity_per_frame": dma_hit_capacity_per_frame,
    }


def read_key_values(path: Path) -> dict[str, str]:
    out: dict[str, str] = {}
    if not path.exists():
        return out
    for line in path.read_text().splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        out[key.strip()] = value.strip()
    return out


def parse_key_value_tokens(line: str) -> dict[str, int]:
    out: dict[str, int] = {}
    for key, value in re.findall(r"([A-Za-z0-9_]+)=([0-9]+)", line):
        out[key] = int(value)
    return out


def parse_opq_summary(log_path: Path) -> dict[str, int]:
    out: dict[str, int] = {}
    if not log_path.exists():
        return out
    for line in log_path.read_text(errors="replace").splitlines():
        if "OPQ_NATIVE_SUMMARY" in line:
            out.update({f"ft_{k}": v for k, v in parse_key_value_tokens(line).items()})
        elif "OPQ_NATIVE_LANE_SUMMARY" in line:
            fields = parse_key_value_tokens(line)
            lane = fields.get("lane")
            if lane is not None:
                out.update({f"lane{lane}_{k}": v for k, v in fields.items()})
    return out


def measured_row(
    report: Path,
    requested_rate_hz: float,
    run_window_8ns: int,
    asics: int,
    n_hit: int,
    dma_hit_capacity_per_frame: int,
    active_hit_lanes: int,
) -> dict[str, float | int | str]:
    model = model_row(
        requested_rate_hz,
        run_window_8ns,
        asics,
        n_hit,
        dma_hit_capacity_per_frame,
        active_hit_lanes,
    )
    summary = read_key_values(report / "feb_swb_corun_summary.txt")
    opq = parse_opq_summary(report / "run_swb_corun.log")
    seconds = run_window_8ns * 8.0e-9
    expected_hits = int(summary.get("expected_hits", "0"))
    actual_hits = int(summary.get("actual_hits", "0"))
    missing_hits = int(summary.get("missing_hits", "0"))
    actual_rate = float(summary.get("hit_rate_hz_per_channel", model["actual_rate_hz_per_channel"]))
    delivered_mhits_s = actual_hits / seconds / 1.0e6
    drop_mhits_s = missing_hits / seconds / 1.0e6
    model.update(
        {
            "actual_rate_hz_per_channel": actual_rate,
            "measured_valid": 1,
            "expected_hits": expected_hits,
            "actual_hits": actual_hits,
            "missing_hits": missing_hits,
            "ghost_hits": int(summary.get("ghost_hits", "0")),
            "dma_payload_words": int(summary.get("dma_payload_words", "0")),
            "opq_beats": int(summary.get("opq_beats", "0")),
            "ft_wr_hit": opq.get("ft_wr_hit", ""),
            "ft_rd_hit": opq.get("ft_rd_hit", ""),
            "lane0_wr_hit": opq.get("lane0_wr_hit", ""),
            "lane0_drop_hit": opq.get("lane0_drop_hit", ""),
            "lane0_handle_drop_hit": opq.get("lane0_handle_drop_hit", ""),
            "lane1_wr_hit": opq.get("lane1_wr_hit", ""),
            "lane1_drop_hit": opq.get("lane1_drop_hit", ""),
            "lane1_handle_drop_hit": opq.get("lane1_handle_drop_hit", ""),
            "measured_delivered_mhits_s": delivered_mhits_s,
            "measured_drop_mhits_s": drop_mhits_s,
            "measured_delivery_fraction": actual_hits / expected_hits if expected_hits else 0.0,
            "measured_drop_fraction": missing_hits / expected_hits if expected_hits else 0.0,
        }
    )
    return model


def write_csv(path: Path, rows: list[dict[str, float | int | str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=SCAN_COLUMNS)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def run_point(args: argparse.Namespace, report: Path, rate_hz: float) -> None:
    period = period_for_rate(rate_hz)
    env = os.environ.copy()
    cmd = [
        args.make,
        "run_swb_corun_scan_point",
        f"QUESTA_HOME={args.questa_home}",
        f"MUSIP_ROOT={args.musip_root}",
        f"OPQ_SOURCE_MODE={args.opq_source_mode}",
        f"OPQ_DEBUG_LEVEL={args.opq_debug_level}",
        f"OPQ_LANE_FIFO_DEPTH={args.opq_lane_fifo_depth}",
        f"OPQ_TICKET_FIFO_DEPTH={args.opq_ticket_fifo_depth}",
        f"OPQ_HANDLE_FIFO_DEPTH={args.opq_handle_fifo_depth}",
        f"OPQ_PAGE_RAM_DEPTH={args.opq_page_ram_depth}",
        f"ASIC_COUNT={args.asic_count}",
        f"RUN_WINDOW_8NS={args.run_window_8ns}",
        f"HIT_PERIOD_8NS={period}",
        "SOURCE_MODE=poisson",
        f"POISSON_SEED={args.seed}",
        f"DRAIN_SWB_CYCLES={args.drain_swb_cycles}",
        f"REPORT_DIR={report}",
        f"RUN_LOG={report / 'run_swb_corun.log'}",
    ]
    subprocess.run(cmd, check=True, env=env)


def selected_rates(args: argparse.Namespace) -> list[float]:
    return [float(x.strip()) * 1000.0 for x in args.rates_khz.split(",") if x.strip()]


def write_prescan(args: argparse.Namespace, report_root: Path, rates_hz: list[float]) -> None:
    dense_rates_hz = [float(khz) * 1000.0 for khz in range(50, 1001, 10)]
    write_csv(
        report_root / "feb_swb_rate_prescan.csv",
        [
            model_row(
                rate,
                args.run_window_8ns,
                args.asic_count,
                args.n_hit,
                args.dma_hit_capacity_per_frame,
                args.active_hit_lanes,
            )
            for rate in dense_rates_hz
        ],
    )
    points_path = report_root / "feb_swb_rate_scan_points.txt"
    points_path.write_text(
        "\n".join(
            [
                "# selected Poisson iid rates for RTL scan",
                "# denser around the two-hit-lane zero-backlog service-rate knee",
                "# OPQ N_HIT is the semantic per-subheader/subframe cap; that knee is outside this scan",
                "# model delivery is lossless after post-window drain; measured missing is reported separately",
                f"# format_subheader_knee_hz_per_channel={args.n_hit * args.active_hit_lanes * 125_000_000.0 / (args.asic_count * CHANNELS_PER_ASIC * SUBHEADER_STRIDE_8NS):.3f}",
                f"# active_hit_lanes={args.active_hit_lanes}",
                f"# zero_backlog_full_frame_knee_hz_per_channel={(args.dma_hit_capacity_per_frame * args.active_hit_lanes) * 125_000_000.0 / (args.asic_count * CHANNELS_PER_ASIC * FRAME_STRIDE_8NS):.3f}",
                f"# zero_backlog_finite_window_capacity_hz_per_channel={(args.dma_hit_capacity_per_frame * args.active_hit_lanes * len(frame_durations_8ns(args.run_window_8ns))) / (args.asic_count * CHANNELS_PER_ASIC * args.run_window_8ns * 8.0e-9):.3f}",
                *[f"{rate/1000.0:.3f} kHz/ch" for rate in rates_hz],
                "",
            ]
        )
    )


def main() -> int:
    args = parse_args()
    report_root = Path(args.report_dir).resolve()
    rates_hz = selected_rates(args)
    write_prescan(args, report_root, rates_hz)
    if args.prescan_only:
        print(f"RATE_PRESCAN_PASS report={report_root} points={len(rates_hz)}")
        return 0

    measured_rows: list[dict[str, float | int | str]] = []
    for rate_hz in rates_hz:
        period = period_for_rate(rate_hz)
        actual_rate = actual_rate_from_period(period)
        label = f"{int(round(actual_rate / 1000.0))}k"
        point_report = report_root / f"rate_{label}"
        if args.force or not (point_report / "feb_swb_corun_summary.txt").exists():
            run_point(args, point_report, rate_hz)
        measured_rows.append(
            measured_row(
                point_report,
                rate_hz,
                args.run_window_8ns,
                args.asic_count,
                args.n_hit,
                args.dma_hit_capacity_per_frame,
                args.active_hit_lanes,
            )
        )
        write_csv(report_root / "feb_swb_rate_scan.csv", measured_rows)
        print(
            "RATE_SCAN_POINT "
            f"rate_khz={actual_rate/1000.0:.3f} "
            f"expected={measured_rows[-1]['expected_hits']} "
            f"actual={measured_rows[-1]['actual_hits']} "
            f"drop_fraction={float(measured_rows[-1]['measured_drop_fraction']):.6f}"
        )

    print(f"RATE_SCAN_PASS report={report_root} points={len(measured_rows)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
