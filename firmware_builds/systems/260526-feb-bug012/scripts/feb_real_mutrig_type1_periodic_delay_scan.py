#!/usr/bin/env python3
"""Real-MuTRiG Type1 periodic delay plateau scan.

The rate scan observes channel occupancy. This companion scan observes the
delay distribution for periodic injector mode with the explicit silicon check
window used in this debug session:

  x bin center = LEFT + bin * BIN_WIDTH + BIN_WIDTH/2, in cycles
  LEFT = 0, RIGHT = 1024, BIN_WIDTH = 4

For periodic mode the expected locked/healthy shape is a plateau inside
[0,1000]. Header-sync PLL-lock checks are collected separately.
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import time
from pathlib import Path
from typing import Any

import feb_hist_read as fh
import feb_real_mutrig_type0_type1_scan as rate_scan


N_BINS = 256
LEFT = 0
BIN_WIDTH = 4
RIGHT = LEFT + N_BINS * BIN_WIDTH
PLATEAU_LO = 0
PLATEAU_HI = 1000

CTRL_TYPE1_UP_DELAY = (1 << 16) | (0 << 2) | (1 << 4) | 1
CTRL_TYPE1_DOWN_DELAY = (2 << 16) | (0 << 2) | (1 << 4) | 1


def centers() -> list[int]:
    return [LEFT + idx * BIN_WIDTH + BIN_WIDTH // 2 for idx in range(N_BINS)]


def wr_verify(link: str, addr: int, value: int, mask: int = 0xFFFFFFFF,
              tries: int = 6, label: str = "") -> bool:
    return rate_scan.wr_verify(link, addr, value, mask, tries, label)


def arm_delay_histogram(link: str, ctrl: int) -> None:
    wr_verify(link, fh.HIST_CSR + fh.H_LEFT, LEFT & 0xFFFFFFFF, label="HIST.LEFT")
    wr_verify(link, fh.HIST_CSR + fh.H_RIGHT, RIGHT & 0xFFFFFFFF, label="HIST.RIGHT")
    wr_verify(link, fh.HIST_CSR + fh.H_BINW, BIN_WIDTH, label="HIST.BINW")
    fh.wr(link, fh.HIST_CSR + fh.H_CONTROL, ctrl)
    time.sleep(0.15)


def summarize(counts: list[int], dwell_s: float) -> dict[str, Any]:
    xs = centers()
    total = sum(counts)
    nonzero = [idx for idx, count in enumerate(counts) if count > 0]
    peak_bin = max(range(N_BINS), key=lambda idx: counts[idx]) if total else None
    in_plateau = sum(
        counts[idx] for idx, center in enumerate(xs)
        if PLATEAU_LO <= center <= PLATEAU_HI
    )
    nz_values = [counts[idx] for idx in nonzero]
    return {
        "total": int(total),
        "measured_hz": 0.0 if dwell_s <= 0 else float(total / dwell_s),
        "nonzero_bins": len(nonzero),
        "first_nonzero_center": None if not nonzero else xs[nonzero[0]],
        "last_nonzero_center": None if not nonzero else xs[nonzero[-1]],
        "peak_bin": peak_bin,
        "peak_center_cycles": None if peak_bin is None else xs[peak_bin],
        "peak_count": 0 if peak_bin is None else counts[peak_bin],
        "peak_fraction": 0.0 if total == 0 or peak_bin is None else counts[peak_bin] / total,
        "plateau_window_count": int(in_plateau),
        "plateau_window_fraction": 0.0 if total == 0 else in_plateau / total,
        "nonzero_min": 0 if not nz_values else int(min(nz_values)),
        "nonzero_mean": 0.0 if not nz_values else float(statistics.mean(nz_values)),
        "nonzero_max": 0 if not nz_values else int(max(nz_values)),
        "nonzero_std": 0.0 if not nz_values else float(statistics.pstdev(nz_values)),
    }


def run_delay_window(
    link: str,
    ctrl: int,
    interval: int,
    dwell_s: float,
    attempts: int,
    pulse_high: int,
    multiplicity: int,
    header_delay: int,
    header_ch: int,
) -> tuple[list[int], dict[str, int], list[dict], list[dict]]:
    rate_scan.set_real_path(link)
    rate_scan.configure_periodic_injector(
        link, interval, pulse_high, multiplicity, header_delay, header_ch)
    if not rate_scan.start_run(link, attempts):
        rate_scan.terminate_run(link)
        raise RuntimeError(f"could not enter RUNNING for interval={interval}")
    before = rate_scan.frame_snapshot(link)
    arm_delay_histogram(link, ctrl)
    rate_scan.enable_periodic_injector(link)
    time.sleep(dwell_s)
    bins = fh.read_frozen_bins(link, method="burst")
    stats = {
        "total": fh.rd(link, fh.HIST_CSR + fh.H_TOTAL) or 0,
        "last_interval": fh.rd(link, fh.HIST_CSR + fh.H_LASTINT) or 0,
    }
    after = rate_scan.frame_snapshot(link)
    rate_scan.terminate_run(link)
    return [bins.get(idx, 0) for idx in range(N_BINS)], stats, before, after


def parse_intervals(raw: str) -> list[int]:
    return [int(item.strip(), 0) for item in raw.split(",") if item.strip()]


def write_bins_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    xs = centers()
    with path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["interval", "requested_hz", "path", "bin", "center_cycles", "count"])
        for row in rows:
            for path_name in ("type1_up_counts", "type1_down_counts", "type1_combined_counts"):
                for idx, count in enumerate(row[path_name]):
                    writer.writerow([
                        row["interval"],
                        row["requested_hz"],
                        path_name.replace("_counts", ""),
                        idx,
                        xs[idx],
                        count,
                    ])


def write_summary_csv(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "interval", "requested_hz",
            "up_total", "down_total", "combined_total",
            "combined_nonzero_bins", "first_nonzero_center", "last_nonzero_center",
            "peak_center_cycles", "peak_fraction",
            "plateau_window_count", "plateau_window_fraction",
            "up_last_interval", "down_last_interval",
        ])
        for row in rows:
            summary = row["summary"]
            writer.writerow([
                row["interval"],
                row["requested_hz"],
                row["type1_up_summary"]["total"],
                row["type1_down_summary"]["total"],
                summary["total"],
                summary["nonzero_bins"],
                summary["first_nonzero_center"],
                summary["last_nonzero_center"],
                summary["peak_center_cycles"],
                summary["peak_fraction"],
                summary["plateau_window_count"],
                summary["plateau_window_fraction"],
                row["type1_up_stats"]["last_interval"],
                row["type1_down_stats"]["last_interval"],
            ])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--link", default="2")
    parser.add_argument("--intervals", default="50000,12500,5000")
    parser.add_argument("--dwell-s", type=float, default=2.0)
    parser.add_argument("--attempts", type=int, default=5)
    parser.add_argument("--pulse-high", type=int, default=5)
    parser.add_argument("--multiplicity", type=int, default=1)
    parser.add_argument("--header-delay", type=int, default=300)
    parser.add_argument("--header-ch", type=int, default=0)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    rows: list[dict[str, Any]] = []
    print(
        f"# feb_real_mutrig_type1_periodic_delay_scan link={args.link} "
        f"intervals={parse_intervals(args.intervals)} dwell_s={args.dwell_s} "
        f"window=[{LEFT},{RIGHT}] bw={BIN_WIDTH}"
    )
    print(
        f"# UIDs: HIST={fh.rd(args.link, fh.HIST_CSR)!r} "
        f"RUNCTL={fh.rd(args.link, fh.RUNCTL)!r} INJ={fh.rd(args.link, rate_scan.INJ)!r}"
    )

    try:
        for interval in parse_intervals(args.intervals):
            requested_hz = 125_000_000.0 / interval if interval else 0.0
            up, up_stats, up_before, up_after = run_delay_window(
                args.link, CTRL_TYPE1_UP_DELAY, interval, args.dwell_s, args.attempts,
                args.pulse_high, args.multiplicity, args.header_delay, args.header_ch)
            down, down_stats, down_before, down_after = run_delay_window(
                args.link, CTRL_TYPE1_DOWN_DELAY, interval, args.dwell_s, args.attempts,
                args.pulse_high, args.multiplicity, args.header_delay, args.header_ch)
            combined = [up[idx] + down[idx] for idx in range(N_BINS)]
            row = {
                "interval": interval,
                "requested_hz": requested_hz,
                "dwell_s": args.dwell_s,
                "type1_up_counts": up,
                "type1_down_counts": down,
                "type1_combined_counts": combined,
                "type1_up_stats": up_stats,
                "type1_down_stats": down_stats,
                "type1_up_summary": summarize(up, args.dwell_s),
                "type1_down_summary": summarize(down, args.dwell_s),
                "summary": summarize(combined, args.dwell_s),
                "frame_snapshots": {
                    "type1_up_before": up_before,
                    "type1_up_after": up_after,
                    "type1_down_before": down_before,
                    "type1_down_after": down_after,
                },
            }
            rows.append(row)
            summary = row["summary"]
            print(
                f"# interval={interval} requested={requested_hz:9.1f} Hz "
                f"total={summary['total']:8d} nz={summary['nonzero_bins']:3d}/256 "
                f"span=[{summary['first_nonzero_center']},{summary['last_nonzero_center']}] "
                f"peak={summary['peak_center_cycles']} cyc "
                f"plateau[0,1000]={100.0 * summary['plateau_window_fraction']:.4f}%"
            )
    finally:
        rate_scan.terminate_run(args.link)

    artifact = {
        "kind": "real_mutrig_type1_periodic_delay_plateau_scan",
        "link": args.link,
        "left": LEFT,
        "right": RIGHT,
        "bin_width": BIN_WIDTH,
        "n_bins": N_BINS,
        "plateau_window": [PLATEAU_LO, PLATEAU_HI],
        "hist_control": {
            "type1_up_delay": CTRL_TYPE1_UP_DELAY,
            "type1_down_delay": CTRL_TYPE1_DOWN_DELAY,
        },
        "rows": rows,
        "final": {
            "inj_mode": fh.rd(args.link, rate_scan.INJ + rate_scan.I_MODE),
            "runctl_status": fh.rd(args.link, fh.RUNCTL + fh.R_STATUS),
            "runctl_last_cmd": fh.rd(args.link, fh.RUNCTL + fh.R_LOCAL_CMD),
        },
    }
    json_path = args.out_dir / "real_mutrig_type1_periodic_delay_plateau.json"
    bins_csv = args.out_dir / "real_mutrig_type1_periodic_delay_plateau_bins.csv"
    summary_csv = args.out_dir / "real_mutrig_type1_periodic_delay_plateau_summary.csv"
    json_path.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    write_bins_csv(bins_csv, rows)
    write_summary_csv(summary_csv, rows)
    print(f"# wrote {json_path}")
    print(f"# wrote {bins_csv}")
    print(f"# wrote {summary_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
