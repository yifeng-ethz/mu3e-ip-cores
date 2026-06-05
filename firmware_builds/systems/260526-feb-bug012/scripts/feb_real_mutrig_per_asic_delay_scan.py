#!/usr/bin/env python3
"""Collect per-ASIC real-MuTRiG Type1 delay histograms.

Each ASIC is isolated by disabling TDC-test on all ASICs, enabling one ASIC's
32 TDC-test channels, flushing the channel CML setting 0 -> 8 -> 0, and then
running two delay windows:

* periodic mode, pulse_interval=1250 by default -> 100 kHz per enabled channel
* header-sync mode, header_interval=1 -> one pulse per frame

The histogram window is 256 bins over [0,1024] cycles with bin width 4 cycles,
matching the real-MuTRiG plateau/lock checks in the current report.
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import subprocess
import sys
import time
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = Path(__file__).resolve().parents[4]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import feb_hist_read as fh  # noqa: E402
import feb_real_mutrig_type0_type1_scan as rate_scan  # noqa: E402


CONFIG_RUNNER = Path(
    "/home/yifeng/packages/mu3e_ip_dev/.worktrees/"
    "mu3e_ip_cores_phase6_closure_20260430/firmware_builds/systems/"
    "system_20260427_testplanphase5/script/configure_mutrig_from_xml_v4addr.py"
)
SC_TOOL = Path("/home/yifeng/packages/online_dpv2/online/install/bin/sc_tool")
BSP = REPO_ROOT / "toolkits/fe_scifi/system_console/lib/mutrig_controller_bsp.tcl"
SMB3_XML = REPO_ROOT / "board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt"
SMB5_XML = REPO_ROOT / "board_test_system/trash_bin/good_ribbon_0/config_smb5_tdc.txt"

N_BINS = 256
LEFT = 0
BIN_WIDTH = 4
RIGHT = LEFT + N_BINS * BIN_WIDTH
WINDOW_LO = 0
WINDOW_HI = 1000

CTRL_TYPE1_UP_DELAY = (1 << 16) | (1 << 4) | 1
CTRL_TYPE1_DOWN_DELAY = (2 << 16) | (1 << 4) | 1

LVDS_SOFT_RESET = 0x04006
LVDS_ALL_LANES = 0x000001FF


def centers() -> list[int]:
    return [LEFT + idx * BIN_WIDTH + BIN_WIDTH // 2 for idx in range(N_BINS)]


def parse_asics(text: str) -> list[int]:
    out: list[int] = []
    for item in text.split(","):
        item = item.strip()
        if not item:
            continue
        if "-" in item:
            lo, hi = [int(v, 0) for v in item.split("-", 1)]
            out.extend(range(lo, hi + 1))
        else:
            out.append(int(item, 0))
    bad = [asic for asic in out if asic < 0 or asic > 7]
    if bad:
        raise argparse.ArgumentTypeError(f"ASIC out of range: {bad}")
    return sorted(dict.fromkeys(out))


def parse_tdc_override(text: str) -> tuple[int, str, int]:
    try:
        asic_text, assignment = text.split(":", 1)
        field, value_text = assignment.split("=", 1)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            "TDC override must be ASIC:FIELD=VALUE, e.g. 0:vnvcodelay=18"
        ) from exc
    asic = int(asic_text, 0)
    if asic < 0 or asic > 7:
        raise argparse.ArgumentTypeError(f"ASIC out of range: {asic}")
    field = field.strip()
    if field not in {"vncnt", "vnvcodelay", "vnhitlogic"}:
        raise argparse.ArgumentTypeError(f"unsupported TDC field: {field}")
    return asic, field, int(value_text, 0)


def tdc_override_map(items: list[tuple[int, str, int]]) -> dict[int, dict[str, int]]:
    out: dict[int, dict[str, int]] = {}
    for asic, field, value in items:
        out.setdefault(asic, {})[field] = value
    return out


def run_config(
    out_dir: Path,
    label: str,
    link: str,
    asics: str,
    tdctest_mask: int,
    cml_flush: bool,
    tdc_overrides: dict[int, dict[str, int]] | None = None,
) -> dict[str, Any]:
    log_path = out_dir / f"{label}.log"
    md_path = out_dir / f"{label}.md"
    json_path = out_dir / f"{label}.json"
    cmd = [
        sys.executable,
        str(CONFIG_RUNNER),
        "--link",
        str(link),
        "--sc-tool",
        str(SC_TOOL),
        "--bsp",
        str(BSP),
        "--smb3-xml",
        str(SMB3_XML),
        "--smb5-xml",
        str(SMB5_XML),
        "--asics",
        asics,
        "--channel-enable-mask",
        "0xffffffff",
        "--tdctest-channel-mask",
        f"0x{tdctest_mask:08x}",
        "--set-channel",
        "recv_all=1",
        "--set-channel",
        "cml_sc=0",
        "--allow-idle-after-config",
        "--output",
        str(md_path),
        "--json-output",
        str(json_path),
    ]
    for asic, fields in sorted((tdc_overrides or {}).items()):
        for name, value in sorted(fields.items()):
            cmd.extend(["--set-tdc", f"{asic}:{name}={value}"])
    if cml_flush:
        cmd.extend([
            "--cml-flush-after-config",
            "--cml-start-value",
            "0",
            "--cml-flush-value",
            "8",
            "--cml-final-value",
            "0",
        ])
    print(
        f"# configure {label}: asics={asics} tdctest=0x{tdctest_mask:08x} "
        f"cml={int(cml_flush)} tdc_overrides={tdc_overrides or {}}"
    )
    proc = subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    log_path.write_text(proc.stdout)
    print(proc.stdout, end="")
    if proc.returncode != 0:
        raise RuntimeError(f"configuration {label} failed; see {log_path}")
    data = json.loads(json_path.read_text()) if json_path.exists() else {}
    return {
        "label": label,
        "log": str(log_path),
        "report": str(md_path),
        "json": str(json_path),
        "returncode": proc.returncode,
        "summary": data.get("summary"),
        "tdc_overrides": tdc_overrides or {},
    }


def wr_verify(link: str, addr: int, value: int, mask: int = 0xFFFFFFFF, label: str = "") -> bool:
    return rate_scan.wr_verify(link, addr, value, mask=mask, label=label)


def soft_reset_lvds(link: str, settle_s: float) -> dict[str, int | None]:
    fh.wr(link, LVDS_SOFT_RESET, LVDS_ALL_LANES)
    time.sleep(settle_s)
    return {
        "phy_losn": fh.rd(link, 0x0400C),
        "phy_dpa_locked": fh.rd(link, 0x0400D),
        "lane_go": fh.rd(link, 0x04004),
    }


def arm_delay_histogram(link: str, ctrl: int) -> None:
    wr_verify(link, fh.HIST_CSR + fh.H_LEFT, LEFT & 0xFFFFFFFF, label="HIST.LEFT")
    wr_verify(link, fh.HIST_CSR + fh.H_RIGHT, RIGHT & 0xFFFFFFFF, label="HIST.RIGHT")
    wr_verify(link, fh.HIST_CSR + fh.H_BINW, BIN_WIDTH, label="HIST.BINW")
    fh.wr(link, fh.HIST_CSR + fh.H_CONTROL, ctrl)
    time.sleep(0.15)


def configure_injector(
    link: str,
    mode: str,
    periodic_interval: int,
    pulse_high: int,
    multiplicity: int,
    header_delay: int,
    header_interval: int,
    header_ch: int,
    enable: bool,
) -> None:
    wr_verify(link, rate_scan.INJ + rate_scan.I_MODE, 0, 0xF, label="INJ.MODE")
    wr_verify(link, rate_scan.INJ + rate_scan.I_HCH, header_ch, 0xFF, label="INJ.HEADER_CH")
    wr_verify(link, rate_scan.INJ + rate_scan.I_HDELAY, header_delay, label="INJ.HEADER_DELAY")
    wr_verify(link, rate_scan.INJ + rate_scan.I_HINTERVAL, header_interval, label="INJ.HEADER_INTERVAL")
    wr_verify(link, rate_scan.INJ + rate_scan.I_MULT, multiplicity, label="INJ.MULT")
    wr_verify(link, rate_scan.INJ + rate_scan.I_PINT, periodic_interval, label="INJ.PULSE_INTERVAL")
    wr_verify(link, rate_scan.INJ + rate_scan.I_PHIGH, pulse_high, 0xFF, label="INJ.PULSE_HIGH")
    mode_value = 1 if mode == "headersync" else 2
    wr_verify(link, rate_scan.INJ + rate_scan.I_MODE, mode_value if enable else 0, 0xF, label="INJ.MODE")


def percentile_center(counts: list[int], pct: float) -> int | None:
    total = sum(counts)
    if total <= 0:
        return None
    threshold = total * pct
    acc = 0
    xs = centers()
    for idx, count in enumerate(counts):
        acc += count
        if acc >= threshold:
            return xs[idx]
    return xs[-1]


def summarize(counts: list[int], dwell_s: float) -> dict[str, Any]:
    xs = centers()
    total = sum(counts)
    nonzero = [idx for idx, count in enumerate(counts) if count > 0]
    peak_bin = max(range(N_BINS), key=lambda idx: counts[idx]) if total else None
    in_window = sum(
        counts[idx]
        for idx, center in enumerate(xs)
        if WINDOW_LO <= center <= WINDOW_HI
    )
    nz_values = [counts[idx] for idx in nonzero]
    p05 = percentile_center(counts, 0.05)
    p95 = percentile_center(counts, 0.95)
    return {
        "total": int(total),
        "measured_hz": 0.0 if dwell_s <= 0 else float(total / dwell_s),
        "nonzero_bins": len(nonzero),
        "first_nonzero_center": None if not nonzero else xs[nonzero[0]],
        "last_nonzero_center": None if not nonzero else xs[nonzero[-1]],
        "peak_bin": peak_bin,
        "peak_center_cycles": None if peak_bin is None else xs[peak_bin],
        "peak_count": 0 if peak_bin is None else int(counts[peak_bin]),
        "peak_fraction": 0.0 if total <= 0 or peak_bin is None else counts[peak_bin] / total,
        "window_count_0_1000": int(in_window),
        "window_fraction_0_1000": 0.0 if total <= 0 else in_window / total,
        "p05_center_cycles": p05,
        "p95_center_cycles": p95,
        "p05_p95_width_cycles": None if p05 is None or p95 is None else p95 - p05,
        "nonzero_min": 0 if not nz_values else int(min(nz_values)),
        "nonzero_mean": 0.0 if not nz_values else float(statistics.mean(nz_values)),
        "nonzero_max": 0 if not nz_values else int(max(nz_values)),
        "nonzero_std": 0.0 if not nz_values else float(statistics.pstdev(nz_values)),
    }


def run_delay_window(
    link: str,
    asic: int,
    mode: str,
    dwell_s: float,
    attempts: int,
    periodic_interval: int,
    pulse_high: int,
    multiplicity: int,
    header_delay: int,
    header_interval: int,
    header_ch: int,
) -> dict[str, Any]:
    ctrl = CTRL_TYPE1_UP_DELAY if asic < 4 else CTRL_TYPE1_DOWN_DELAY
    path_name = "type1_up" if asic < 4 else "type1_down"
    rate_scan.set_real_path(link)
    configure_injector(
        link,
        mode,
        periodic_interval,
        pulse_high,
        multiplicity,
        header_delay,
        header_interval,
        header_ch,
        False,
    )
    if not rate_scan.start_run(link, attempts):
        rate_scan.terminate_run(link)
        raise RuntimeError(f"could not enter RUNNING for ASIC{asic} {mode}")
    before = rate_scan.frame_snapshot(link)
    arm_delay_histogram(link, ctrl)
    configure_injector(
        link,
        mode,
        periodic_interval,
        pulse_high,
        multiplicity,
        header_delay,
        header_interval,
        header_ch,
        True,
    )
    time.sleep(dwell_s)
    bins = fh.read_frozen_bins(link, method="burst")
    counts = [int(bins.get(idx, 0)) for idx in range(N_BINS)]
    stats = {
        "hist_total": fh.rd(link, fh.HIST_CSR + fh.H_TOTAL) or 0,
        "hist_last_interval": fh.rd(link, fh.HIST_CSR + fh.H_LASTINT) or 0,
    }
    after = rate_scan.frame_snapshot(link)
    rate_scan.terminate_run(link)
    summary = summarize(counts, dwell_s)
    print(
        f"# ASIC{asic} {mode}: path={path_name} total={summary['total']} "
        f"nz={summary['nonzero_bins']}/256 peak={summary['peak_center_cycles']} "
        f"in[0,1000]={100.0 * summary['window_fraction_0_1000']:.3f}%"
    )
    return {
        "asic": asic,
        "mode": mode,
        "path": path_name,
        "hist_control": ctrl,
        "counts": counts,
        "summary": summary,
        "stats": stats,
        "frame_before": before,
        "frame_after": after,
    }


def write_csvs(out_dir: Path, rows: list[dict[str, Any]]) -> tuple[Path, Path]:
    bins_csv = out_dir / "real_mutrig_per_asic_delay_bins.csv"
    summary_csv = out_dir / "real_mutrig_per_asic_delay_summary.csv"
    xs = centers()
    with bins_csv.open("w", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow(["asic", "mode", "path", "bin", "center_cycles", "count"])
        for row in rows:
            for idx, count in enumerate(row["counts"]):
                writer.writerow([row["asic"], row["mode"], row["path"], idx, xs[idx], count])
    with summary_csv.open("w", newline="") as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow([
            "asic", "mode", "path", "total", "measured_hz", "nonzero_bins",
            "first_nonzero_center", "last_nonzero_center", "peak_center_cycles",
            "peak_fraction", "window_fraction_0_1000", "p05_center_cycles",
            "p95_center_cycles", "p05_p95_width_cycles",
        ])
        for row in rows:
            s = row["summary"]
            writer.writerow([
                row["asic"], row["mode"], row["path"], s["total"], s["measured_hz"],
                s["nonzero_bins"], s["first_nonzero_center"], s["last_nonzero_center"],
                s["peak_center_cycles"], s["peak_fraction"], s["window_fraction_0_1000"],
                s["p05_center_cycles"], s["p95_center_cycles"], s["p05_p95_width_cycles"],
            ])
    return bins_csv, summary_csv


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--link", default="2")
    parser.add_argument("--asics", type=parse_asics, default=parse_asics("0-7"))
    parser.add_argument("--periodic-interval", type=int, default=1250)
    parser.add_argument("--periodic-dwell-s", type=float, default=1.5)
    parser.add_argument("--headersync-dwell-s", type=float, default=1.5)
    parser.add_argument("--attempts", type=int, default=6)
    parser.add_argument("--pulse-high", type=int, default=5)
    parser.add_argument("--multiplicity", type=int, default=1)
    parser.add_argument("--header-delay", type=int, default=300)
    parser.add_argument("--header-interval", type=int, default=1)
    parser.add_argument("--header-ch", type=int, default=1)
    parser.add_argument("--lvds-settle-s", type=float, default=1.0)
    parser.add_argument("--set-tdc", action="append", type=parse_tdc_override, default=[])
    parser.add_argument("--no-config", action="store_true")
    parser.add_argument("--no-restore-all", action="store_true")
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    tdc_overrides = tdc_override_map(args.set_tdc)
    config_steps: list[dict[str, Any]] = []
    rows: list[dict[str, Any]] = []
    try:
        if not args.no_config:
            config_steps.append(
                run_config(args.out_dir, "configure_all_tdc_mask_off_start", args.link, "0-7", 0, False)
            )
        for asic in args.asics:
            if not args.no_config:
                active_tdc_overrides = {asic: tdc_overrides[asic]} if asic in tdc_overrides else {}
                config_steps.append(
                    run_config(
                        args.out_dir,
                        f"configure_asic{asic}_tdc_full32_cmlflush",
                        args.link,
                        str(asic),
                        0xFFFFFFFF,
                        True,
                        active_tdc_overrides,
                    )
                )
            lvds = soft_reset_lvds(args.link, args.lvds_settle_s)
            print(f"# ASIC{asic} LVDS after reset: {lvds}")
            periodic = run_delay_window(
                args.link,
                asic,
                "periodic",
                args.periodic_dwell_s,
                args.attempts,
                args.periodic_interval,
                args.pulse_high,
                args.multiplicity,
                args.header_delay,
                args.header_interval,
                args.header_ch,
            )
            periodic["requested_hz_per_channel"] = 125_000_000.0 / args.periodic_interval
            periodic["lvds_after_reset"] = lvds
            rows.append(periodic)
            headersync = run_delay_window(
                args.link,
                asic,
                "headersync",
                args.headersync_dwell_s,
                args.attempts,
                args.periodic_interval,
                args.pulse_high,
                args.multiplicity,
                args.header_delay,
                args.header_interval,
                args.header_ch,
            )
            headersync["header_delay"] = args.header_delay
            headersync["header_interval"] = args.header_interval
            headersync["header_ch"] = args.header_ch
            headersync["lvds_after_reset"] = lvds
            rows.append(headersync)
            if not args.no_config:
                config_steps.append(
                    run_config(
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
        if not args.no_config and not args.no_restore_all:
            config_steps.append(
                run_config(args.out_dir, "configure_all_tdc_full32_restore", args.link, "0-7", 0xFFFFFFFF, True)
            )
            soft_reset_lvds(args.link, args.lvds_settle_s)

    bins_csv, summary_csv = write_csvs(args.out_dir, rows)
    artifact = {
        "kind": "real_mutrig_per_asic_type1_delay_scan",
        "args": {
            "link": args.link,
            "asics": args.asics,
            "periodic_interval": args.periodic_interval,
            "periodic_dwell_s": args.periodic_dwell_s,
            "headersync_dwell_s": args.headersync_dwell_s,
            "header_delay": args.header_delay,
            "header_interval": args.header_interval,
            "header_ch": args.header_ch,
            "tdc_overrides": tdc_overrides,
        },
        "left": LEFT,
        "right": RIGHT,
        "bin_width": BIN_WIDTH,
        "n_bins": N_BINS,
        "window_0_1000": [WINDOW_LO, WINDOW_HI],
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
    json_path = args.out_dir / "real_mutrig_per_asic_delay_scan.json"
    json_path.write_text(json.dumps(artifact, indent=2, sort_keys=True) + "\n")
    print(f"# wrote {json_path}")
    print(f"# wrote {bins_csv}")
    print(f"# wrote {summary_csv}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
