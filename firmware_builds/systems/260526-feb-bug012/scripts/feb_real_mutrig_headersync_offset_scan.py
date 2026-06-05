#!/usr/bin/env python3
"""Collect per-ASIC real-MuTRiG header-sync delay histograms at several offsets."""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import feb_real_mutrig_per_asic_delay_scan as delay_scan  # noqa: E402
import feb_real_mutrig_type0_type1_scan as rate_scan  # noqa: E402
import feb_hist_read as fh  # noqa: E402


def parse_int_list(text: str) -> list[int]:
    out: list[int] = []
    for token in text.split(","):
        token = token.strip()
        if token:
            out.append(int(token, 0))
    if not out:
        raise argparse.ArgumentTypeError("list must not be empty")
    return out


def write_csvs(out_dir: Path, rows: list[dict[str, Any]]) -> tuple[Path, Path]:
    bins_csv = out_dir / "real_mutrig_headersync_offset_delay_bins.csv"
    summary_csv = out_dir / "real_mutrig_headersync_offset_delay_summary.csv"
    xs = delay_scan.centers()
    with bins_csv.open("w", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["asic", "header_delay", "expected_center_cycles", "bin", "center_cycles", "count"])
        for row in rows:
            expected = 910 - int(row["header_delay"])
            for idx, count in enumerate(row["counts"]):
                writer.writerow([row["asic"], row["header_delay"], expected, idx, xs[idx], count])
    with summary_csv.open("w", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow([
            "asic", "header_delay", "expected_center_cycles", "total", "measured_hz",
            "nonzero_bins", "first_nonzero_center", "last_nonzero_center",
            "peak_center_cycles", "peak_fraction", "window_fraction_0_1000",
            "p05_center_cycles", "p95_center_cycles", "p05_p95_width_cycles",
        ])
        for row in rows:
            s = row["summary"]
            expected = 910 - int(row["header_delay"])
            writer.writerow([
                row["asic"], row["header_delay"], expected, s["total"], s["measured_hz"],
                s["nonzero_bins"], s["first_nonzero_center"], s["last_nonzero_center"],
                s["peak_center_cycles"], s["peak_fraction"], s["window_fraction_0_1000"],
                s["p05_center_cycles"], s["p95_center_cycles"], s["p05_p95_width_cycles"],
            ])
    return bins_csv, summary_csv


def restore_full_bank_asic2_last(
    out_dir: Path,
    link: str,
    tdc_overrides: dict[int, dict[str, int]],
    lvds_settle_s: float,
) -> list[dict[str, Any]]:
    steps = []
    steps.append(delay_scan.run_config(out_dir, "restore_all_tdc_mask_off", link, "0-7", 0, False))
    steps.append(
        delay_scan.run_config(
            out_dir,
            "restore_all_except2_tdc_full32_cmlflush",
            link,
            "0,1,3,4,5,6,7",
            0xFFFFFFFF,
            True,
            tdc_overrides,
        )
    )
    steps.append(
        delay_scan.run_config(
            out_dir,
            "restore_asic2_tdc_full32_cmlflush_last",
            link,
            "2",
            0xFFFFFFFF,
            True,
            {2: tdc_overrides[2]} if 2 in tdc_overrides else {},
        )
    )
    lvds = delay_scan.soft_reset_lvds(link, lvds_settle_s)
    print(f"# restored full-bank ASIC2-last config; LVDS {lvds}")
    return steps


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--link", default="2")
    parser.add_argument("--asics", type=delay_scan.parse_asics, default=delay_scan.parse_asics("0-7"))
    parser.add_argument("--header-delays", type=parse_int_list, default=parse_int_list("100,300,500"))
    parser.add_argument("--dwell-s", type=float, default=0.9)
    parser.add_argument("--attempts", type=int, default=6)
    parser.add_argument("--periodic-interval", type=int, default=1250)
    parser.add_argument("--pulse-high", type=int, default=5)
    parser.add_argument("--multiplicity", type=int, default=1)
    parser.add_argument("--header-interval", type=int, default=1)
    parser.add_argument("--header-ch", type=int, default=1)
    parser.add_argument("--lvds-settle-s", type=float, default=1.0)
    parser.add_argument("--set-tdc", action="append", type=delay_scan.parse_tdc_override, default=[])
    parser.add_argument("--no-config", action="store_true")
    parser.add_argument("--no-restore-full", action="store_true")
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    tdc_overrides = delay_scan.tdc_override_map(args.set_tdc)
    config_steps: list[dict[str, Any]] = []
    rows: list[dict[str, Any]] = []
    try:
        if not args.no_config:
            config_steps.append(
                delay_scan.run_config(args.out_dir, "configure_all_tdc_mask_off_start", args.link, "0-7", 0, False)
            )
        for asic in args.asics:
            if not args.no_config:
                active_tdc = {asic: tdc_overrides[asic]} if asic in tdc_overrides else {}
                config_steps.append(
                    delay_scan.run_config(
                        args.out_dir,
                        f"configure_asic{asic}_tdc_full32_cmlflush",
                        args.link,
                        str(asic),
                        0xFFFFFFFF,
                        True,
                        active_tdc,
                    )
                )
            lvds = delay_scan.soft_reset_lvds(args.link, args.lvds_settle_s)
            print(f"# ASIC{asic} LVDS after reset: {lvds}")
            for header_delay in args.header_delays:
                row = delay_scan.run_delay_window(
                    args.link,
                    asic,
                    "headersync",
                    args.dwell_s,
                    args.attempts,
                    args.periodic_interval,
                    args.pulse_high,
                    args.multiplicity,
                    header_delay,
                    args.header_interval,
                    args.header_ch,
                )
                row["header_delay"] = header_delay
                row["header_interval"] = args.header_interval
                row["header_ch"] = args.header_ch
                row["expected_center_cycles"] = 910 - header_delay
                row["lvds_after_reset"] = lvds
                rows.append(row)
            if not args.no_config:
                config_steps.append(
                    delay_scan.run_config(
                        args.out_dir,
                        f"configure_asic{asic}_tdc_mask_off_after_measure",
                        args.link,
                        str(asic),
                        0,
                        False,
                    )
                )
    finally:
        rate_scan.terminate_run(args.link)
        if not args.no_config and not args.no_restore_full:
            config_steps.extend(
                restore_full_bank_asic2_last(args.out_dir, args.link, tdc_overrides, args.lvds_settle_s)
            )

    bins_csv, summary_csv = write_csvs(args.out_dir, rows)
    artifact = {
        "kind": "real_mutrig_headersync_offset_delay_scan",
        "args": {
            "link": args.link,
            "asics": args.asics,
            "header_delays": args.header_delays,
            "dwell_s": args.dwell_s,
            "header_interval": args.header_interval,
            "header_ch": args.header_ch,
            "tdc_overrides": tdc_overrides,
        },
        "left": delay_scan.LEFT,
        "right": delay_scan.RIGHT,
        "bin_width": delay_scan.BIN_WIDTH,
        "n_bins": delay_scan.N_BINS,
        "window_0_1000": [delay_scan.WINDOW_LO, delay_scan.WINDOW_HI],
        "config_steps": config_steps,
        "rows": rows,
        "outputs": {
            "bins_csv": str(bins_csv),
            "summary_csv": str(summary_csv),
        },
        "final": {
            "inj_mode": fh.rd(args.link, rate_scan.INJ + rate_scan.I_MODE),
            "runctl_status": fh.rd(args.link, fh.RUNCTL + fh.R_STATUS),
            "runctl_last_cmd": fh.rd(args.link, fh.RUNCTL + fh.R_LOCAL_CMD),
            "lvds_losn_dpalock_lanego": [
                fh.rd(args.link, 0x0400C),
                fh.rd(args.link, 0x0400D),
                fh.rd(args.link, 0x04004),
            ],
        },
    }
    json_path = args.out_dir / "real_mutrig_headersync_offset_delay_scan.json"
    json_path.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(f"# wrote {json_path}")
    print(f"# wrote {bins_csv}")
    print(f"# wrote {summary_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
