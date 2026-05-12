#!/usr/bin/env python3
# ============================================================================
# phase4_5_longsoak.py -- directed Phase 4.5 dual-port histogram soak.
# ============================================================================
"""Run the directed 100k-hit single-channel ping-pong histogram soak.

Default ping-pong period 1 ms (125,000 cycles @ 125 MHz); 10x faster
sampling than the prior 10 ms; override via --interval-ms 10.0 if a
longer interval is needed for slow-rate runs.

This helper intentionally reuses phase4_5_sweep.py for all SC access,
address constants, retry policy, and run-control opcode handling. Run it
under swb_ring_lock, for example:

  PHASE4_5_BUILD_DIR=/abs/path/to/build \
    /home/yifeng/.local/bin/swb_ring_lock \
    python3 scripts/cotest/phase4_5_longsoak.py

  # Use 10 ms ping-pong period (prior default) for slow-rate runs:
  python3 scripts/cotest/phase4_5_longsoak.py --interval-ms 10.0
"""
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import sys
import time
import traceback
from pathlib import Path
from typing import Any

import phase4_5_sweep as sweep


# Fix 2: default ping-pong period changed from 10 ms (1,250,000 cycles) to
# 1 ms (125,000 cycles) per user directive. Override via --interval-ms.
# 125 MHz clock: 1 ms = 125,000 cycles, 10 ms = 1,250,000 cycles.
INTERVAL_1MS_CYCLES  = 125_000      # 1 ms @ 125 MHz (new default)
INTERVAL_10MS_CYCLES = 1_250_000    # 10 ms @ 125 MHz (legacy; use --interval-ms 10.0)
DEFAULT_INTERVAL_MS  = 1.0
DEFAULT_TARGET_HITS = 100_000
DEFAULT_RUN_SECONDS = 0.100
DEFAULT_CAL_SECONDS = 0.050
DEFAULT_INITIAL_RATE = 0x0040
DEFAULT_TOLERANCE = 4_000
CHANNEL0_BANK_BINS = tuple(list(range(0, 4)) + list(range(32, 36)))


def _timestamp() -> str:
    return dt.datetime.now().strftime("%Y%m%d_%H%M%S")


def _ensure_output_dir(base: Path) -> Path:
    out = base / "sweep_evidence" / "_longsoak" / f"longsoak_{_timestamp()}"
    out.mkdir(parents=True, exist_ok=False)
    return out


def _json_dump(path: Path, obj: Any) -> None:
    with open(path, "w", encoding="ascii") as f:
        json.dump(obj, f, indent=2, sort_keys=True)
        f.write("\n")


def _row(row_id: str, rate_88fp: int, interval_seconds: float) -> dict[str, Any]:
    return {
        "row_id": row_id,
        "lane_mask": "0xFF",
        "channel_mask": "0x00000001",
        "rate_88fp": f"0x{rate_88fp:04X}",
        "hit_mode": "00",
        "interval_seconds": interval_seconds,
        "axis_section": "4.5.longsoak",
        "expected_behavior": "all lanes, channel 0 only, directed 10 ms ping-pong soak",
        "sanity_negative": False,
    }


def _configure_common(sc_tool: Path, link: int, rate_88fp: int,
                      interval_clocks: int, log_fh: Any) -> dict[str, Any]:
    uid = sweep.sc_read(sc_tool, link, sweep.SC_HUB_UID_WORD, 1, log_fh=log_fh)[0]
    if uid != sweep.SC_HUB_UID_EXPECT:
        raise RuntimeError(
            f"SC hub UID mismatch at 0x{sweep.SC_HUB_UID_WORD:05X}: "
            f"got 0x{uid:08X}, expected 0x{sweep.SC_HUB_UID_EXPECT:08X}"
        )
    sweep.enable_lvds_lanes(sc_tool, link, log_fh=log_fh)
    arb_cfg = sweep.configure_arb_lane_mask(sc_tool, link, 0xFF, log_fh=log_fh)
    emu_cfg = sweep.configure_emulator(
        sc_tool, link, channel_mask=0x00000001,
        rate_88fp=rate_88fp, hit_mode=0, log_fh=log_fh,
    )
    hist_cfg = sweep.configure_histogram(
        sc_tool, link, interval_clocks=interval_clocks,
        hist_left=0, hist_right=255, hist_bin_width=1, log_fh=log_fh,
    )
    ingress_status = sweep.select_histogram_source(
        sc_tool, link, source="pre", bank_count=2, log_fh=log_fh,
    )
    ds_cfg = sweep.configure_downstream(sc_tool, link, log_fh=log_fh)
    return {
        "sc_hub_uid": f"0x{uid:08X}",
        "arb_cfg": arb_cfg,
        "emulator_cfg": emu_cfg,
        "histogram_cfg": hist_cfg,
        "ingress_source": "pre",
        "ingress_status": ingress_status,
        "downstream_cfg": ds_cfg,
    }


def _run_fixed_window(sc_tool: Path, link: int, row: dict[str, Any],
                      log_fh: Any) -> dict[str, Any]:
    return sweep.run_stage_recipe(sc_tool, link, row, 0, log_fh=log_fh)


def _calibrate_rate(sc_tool: Path, link: int, requested_rate: int,
                    cal_seconds: float, run_seconds: float,
                    target_hits: int, log_fh: Any) -> dict[str, Any]:
    cfg = _configure_common(
        sc_tool, link, requested_rate, sweep.INTERVAL_CFG_NEVER_FIRE, log_fh,
    )
    row = _row("longsoak_calibration", requested_rate, cal_seconds)
    pre = sweep.full_snapshot(sc_tool, link, log_fh=log_fh)
    stage = _run_fixed_window(sc_tool, link, row, log_fh)
    post = sweep.full_snapshot(sc_tool, link, log_fh=log_fh)
    observed = int(post.get("histogram", {}).get("TOTAL_HITS", 0) or 0)
    if observed <= 0:
        chosen = requested_rate
        reason = "calibration_observed_zero"
    else:
        scale = (float(target_hits) * cal_seconds) / (float(observed) * run_seconds)
        chosen = max(1, min(0xFFFF, int(round(requested_rate * scale))))
        reason = "scaled_from_calibration"
    return {
        "requested_rate_88fp": f"0x{requested_rate:04X}",
        "chosen_rate_88fp": f"0x{chosen:04X}",
        "cal_seconds": cal_seconds,
        "target_run_seconds": run_seconds,
        "target_hits": target_hits,
        "observed_hits": observed,
        "reason": reason,
        "common_config": cfg,
        "snap_pre": pre,
        "snap_post": post,
        "stage": stage,
    }


def _wait_for_bank_toggle(sc_tool: Path, link: int, previous_status: int,
                          deadline: float, log_fh: Any) -> tuple[bool, int, float]:
    status = previous_status
    while time.time() < deadline:
        status = sweep.sc_read(
            sc_tool, link,
            sweep.HIST_CSR_BASE_WORD + sweep.HIST_BANK_STATUS_W,
            1, log_fh=log_fh,
        )[0]
        if (status & 0x1) != (previous_status & 0x1):
            return True, status, time.time()
        time.sleep(0.001)
    return False, status, time.time()


def _read_interval_status(sc_tool: Path, link: int,
                          log_fh: Any) -> dict[str, Any]:
    words = sweep.sc_read(
        sc_tool, link,
        sweep.HIST_CSR_BASE_WORD + sweep.HIST_BANK_STATUS_W,
        sweep.HIST_LAST_INTERVAL_DROPPED_HITS_W - sweep.HIST_BANK_STATUS_W + 1,
        log_fh=log_fh,
    )
    total_idx = sweep.HIST_TOTAL_HITS_W - sweep.HIST_BANK_STATUS_W
    dropped_idx = sweep.HIST_DROPPED_HITS_W - sweep.HIST_BANK_STATUS_W
    last_total_idx = sweep.HIST_LAST_INTERVAL_TOTAL_HITS_W - sweep.HIST_BANK_STATUS_W
    last_dropped_idx = sweep.HIST_LAST_INTERVAL_DROPPED_HITS_W - sweep.HIST_BANK_STATUS_W
    return {
        "bank_status": int(words[0]),
        "total_hits": int(words[total_idx]),
        "dropped_hits": int(words[dropped_idx]),
        "last_interval_total_hits": int(words[last_total_idx]),
        "last_interval_dropped_hits": int(words[last_dropped_idx]),
    }


def _write_interval_poll(path: Path, interval_records: list[dict[str, Any]]) -> None:
    with open(path, "w", encoding="ascii", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "interval_index", "target_elapsed_s", "wall_elapsed_s",
            "bank_status", "toggle_seen", "total_hits",
            "dropped_hits", "last_interval_total_hits",
            "last_interval_dropped_hits",
        ])
        for rec in interval_records:
            writer.writerow([
                rec["interval_index"],
                f"{rec['target_elapsed_s']:.9f}",
                f"{rec['wall_elapsed_s']:.9f}",
                rec["bank_status"],
                int(rec["toggle_seen"]),
                rec["total_hits"],
                rec["dropped_hits"],
                rec["last_interval_total_hits"],
                rec["last_interval_dropped_hits"],
            ])


def _write_interval_bins(path: Path, interval_records: list[dict[str, Any]]) -> None:
    with open(path, "w", encoding="ascii", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "interval_index", "wall_elapsed_s", "bank_status", "toggle_seen",
            "channel", "count",
        ])
        for rec in interval_records:
            for channel, count in enumerate(rec["bins"]):
                writer.writerow([
                    rec["interval_index"],
                    f"{rec['wall_elapsed_s']:.9f}",
                    rec["bank_status"],
                    int(rec["toggle_seen"]),
                    channel,
                    count,
                ])


def _write_final_bins(path: Path, bins: list[int]) -> None:
    with open(path, "w", encoding="ascii", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["channel", "count"])
        for channel, count in enumerate(bins):
            writer.writerow([channel, count])


def _run_soak(sc_tool: Path, link: int, rate_88fp: int,
              run_seconds: float, intervals: int, interval_clocks: int,
              log_fh: Any) -> dict[str, Any]:
    cfg = _configure_common(
        sc_tool, link, rate_88fp, interval_clocks, log_fh,
    )
    snap_pre = sweep.full_snapshot(sc_tool, link, log_fh=log_fh)

    run_number = 0xAA4500
    try:
        sweep.sc_write_stable(
            sc_tool, link, sweep.RUNCTL_RUN_NUMBER_ADDR,
            [run_number], log_fh=log_fh,
        )
    except RuntimeError as exc:
        sweep._log(log_fh, f"NOTE: CSR_RUN_NUMBER side-load failed: {exc}")

    traces: list[dict[str, Any]] = []
    traces.append(sweep.drive_local_cmd(
        sc_tool, link, sweep.CMD_RUN_PREPARE, run_number & 0xFFFFFF,
        log_fh=log_fh,
    ))
    time.sleep(sweep.GRACE_STAGE_PREPARE_S)
    traces.append(sweep.drive_local_cmd(
        sc_tool, link, sweep.CMD_RUN_SYNC, 0, log_fh=log_fh,
    ))
    time.sleep(sweep.GRACE_STAGE_SYNC_S)

    start_status = sweep.sc_read(
        sc_tool, link,
        sweep.HIST_CSR_BASE_WORD + sweep.HIST_BANK_STATUS_W,
        1, log_fh=log_fh,
    )[0]
    traces.append(sweep.drive_local_cmd(
        sc_tool, link, sweep.CMD_START_RUN, 0, log_fh=log_fh,
    ))
    t_start = time.time()

    interval_records: list[dict[str, Any]] = []
    status = start_status
    for idx in range(intervals):
        target_ts = t_start + (idx + 1) * (run_seconds / float(intervals))
        deadline = max(target_ts + 0.050, time.time() + 0.050)
        toggle_seen, status, wall_ts = _wait_for_bank_toggle(
            sc_tool, link, status, deadline, log_fh,
        )
        interval_status = _read_interval_status(sc_tool, link, log_fh)
        status = interval_status["bank_status"]
        bins = sweep.read_hist_bins(sc_tool, link, log_fh=log_fh)
        interval_records.append({
            "interval_index": idx,
            "wall_ts": wall_ts,
            "target_elapsed_s": target_ts - t_start,
            "wall_elapsed_s": wall_ts - t_start,
            "bank_status": f"0x{status:08X}",
            "toggle_seen": toggle_seen,
            "total_hits": interval_status["total_hits"],
            "dropped_hits": interval_status["dropped_hits"],
            "last_interval_total_hits": interval_status["last_interval_total_hits"],
            "last_interval_dropped_hits": interval_status["last_interval_dropped_hits"],
            "sum": int(sum(bins)),
            "bin0": int(bins[0]) if bins else 0,
            "bin32": int(bins[32]) if len(bins) > 32 else 0,
            "nonzero_bins": [idx for idx, value in enumerate(bins) if value],
            "bins": bins,
        })

    traces.append(sweep.drive_local_cmd(
        sc_tool, link, sweep.CMD_END_RUN, 0, log_fh=log_fh,
    ))
    time.sleep(sweep.GRACE_STAGE_TERMINATE_S)
    idle_ok, idle_ts, idle_label = sweep.wait_for_idle(sc_tool, link, log_fh=log_fh)
    snap_post = sweep.full_snapshot(sc_tool, link, log_fh=log_fh)
    final_bins = sweep.read_hist_bins(sc_tool, link, log_fh=log_fh)

    return {
        "rate_88fp": f"0x{rate_88fp:04X}",
        "run_seconds": run_seconds,
        "interval_clocks": interval_clocks,
        "intervals_requested": intervals,
        "common_config": cfg,
        "snap_pre": snap_pre,
        "snap_post": snap_post,
        "cmd_traces": traces,
        "idle_observed": idle_ok,
        "idle_observed_ts": idle_ts,
        "idle_completion": idle_label,
        "interval_records": interval_records,
        "final_bins": final_bins,
        "final_bin_sum": int(sum(final_bins)),
        "final_bin0": int(final_bins[0]) if final_bins else 0,
        "final_nonzero_bins": [
            idx for idx, value in enumerate(final_bins) if value
        ],
    }


def _make_markdown(path: Path, verdict: dict[str, Any]) -> None:
    lines = [
        "# Phase 4.5 dual-port long soak",
        "",
        f"- Verdict: {'PASS' if verdict['pass'] else 'FAIL'}",
        f"- Target hits: {verdict['target_hits']}",
        f"- Observed cumulative hits: {verdict['observed_cumulative_hits']}",
        f"- Tolerance: +/-{verdict['tolerance_hits']}",
        f"- Rate: {verdict['rate_88fp']}",
        f"- Interval clocks: {verdict['interval_clocks']}",
        f"- Intervals captured: {verdict['intervals_captured']}",
        f"- Toggle misses: {verdict['toggle_misses']}",
        f"- Nonzero channels: {verdict['nonzero_channels']}",
        f"- Final frozen-bank bin sum: {verdict['final_bin_sum']}",
        f"- Timed readout mode: {verdict['timed_readout_mode']}",
        "",
        "## Per-Interval Summary",
        "",
        "| interval | toggle | bank_status | elapsed_s | hist_sum | bin0 | bin32 | nonzero_bins |",
        "|---:|---:|---|---:|---:|---:|---:|---|",
    ]
    for rec in verdict["interval_summary"]:
        lines.append(
            f"| {rec['interval_index']} | {int(rec['toggle_seen'])} | "
            f"{rec['bank_status']} | {rec['wall_elapsed_s']:.6f} | "
            f"{rec['sum']} | {rec['bin0']} | {rec['bin32']} | "
            f"{rec['nonzero_bins']} |"
        )
    lines.append("")
    path.write_text("\n".join(lines), encoding="ascii")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sc-tool", type=Path, default=sweep.DEFAULT_SC_TOOL)
    parser.add_argument("--link", type=int, default=sweep.DEFAULT_LINK)
    parser.add_argument("--target-hits", type=int, default=DEFAULT_TARGET_HITS)
    parser.add_argument("--tolerance-hits", type=int, default=DEFAULT_TOLERANCE)
    parser.add_argument("--run-seconds", type=float, default=DEFAULT_RUN_SECONDS)
    parser.add_argument("--cal-seconds", type=float, default=DEFAULT_CAL_SECONDS)
    parser.add_argument("--initial-rate-88fp", type=lambda s: int(s, 0),
                        default=DEFAULT_INITIAL_RATE)
    parser.add_argument("--rate-88fp", type=lambda s: int(s, 0), default=None,
                        help="Skip calibration and use this 8.8 rate")
    parser.add_argument("--no-calibrate", action="store_true")
    parser.add_argument("--build-dir", type=Path, default=sweep.BUILD_DIR)
    parser.add_argument(
        "--interval-ms", type=float, default=DEFAULT_INTERVAL_MS,
        help=(
            "Ping-pong interval in ms (default 1.0 ms = 125,000 cycles @ 125 MHz). "
            "Use --interval-ms 10.0 for 10 ms (legacy 1,250,000-cycle period)."
        ),
    )
    args = parser.parse_args()

    out_dir = _ensure_output_dir(args.build_dir.resolve())
    log_path = out_dir / "tool_calls.log"
    interval_clocks = int(args.interval_ms * 125_000)
    try:
        with open(log_path, "w", encoding="ascii") as log_fh:
            if args.no_calibrate or args.rate_88fp is not None:
                calibration = {
                    "requested_rate_88fp": f"0x{args.initial_rate_88fp:04X}",
                    "chosen_rate_88fp": f"0x{(args.rate_88fp or args.initial_rate_88fp):04X}",
                    "reason": "explicit_rate" if args.rate_88fp is not None else "calibration_disabled",
                }
                chosen_rate = args.rate_88fp or args.initial_rate_88fp
            else:
                calibration = _calibrate_rate(
                    args.sc_tool, args.link, args.initial_rate_88fp,
                    args.cal_seconds, args.run_seconds, args.target_hits,
                    log_fh,
                )
                chosen_rate = int(calibration["chosen_rate_88fp"], 16)

            soak = _run_soak(
                args.sc_tool, args.link, chosen_rate, args.run_seconds,
                intervals=10, interval_clocks=interval_clocks, log_fh=log_fh,
            )
    except Exception as exc:
        failure = {
            "pass": False,
            "error": str(exc),
            "traceback": traceback.format_exc(),
            "output_dir": str(out_dir),
        }
        _json_dump(out_dir / "verdict.json", failure)
        print(f"FAIL: {exc}", file=sys.stderr)
        print(f"evidence: {out_dir}", file=sys.stderr)
        return 1

    interval_records = soak["interval_records"]
    final_bins = soak["final_bins"]
    _write_interval_poll(out_dir / "interval_poll.csv", interval_records)
    _write_interval_bins(out_dir / "interval_bins.csv", interval_records)
    _write_final_bins(out_dir / "final_hist_bins.csv", final_bins)

    observed_cumulative = sum(int(r["sum"]) for r in interval_records)
    nonzero_channels = sorted({
        ch
        for rec in interval_records
        for ch in rec["nonzero_bins"]
    })
    toggle_misses = sum(1 for r in interval_records if not r["toggle_seen"])
    diff = abs(observed_cumulative - args.target_hits)
    only_channel0_by_bank = all(ch in CHANNEL0_BANK_BINS for ch in nonzero_channels)
    passed = (
        diff <= args.tolerance_hits
        and toggle_misses == 0
        and len(interval_records) == 10
        and only_channel0_by_bank
        and soak["idle_observed"]
    )
    verdict = {
        "pass": passed,
        "target_hits": args.target_hits,
        "observed_cumulative_hits": observed_cumulative,
        "difference_hits": observed_cumulative - args.target_hits,
        "tolerance_hits": args.tolerance_hits,
        "rate_88fp": f"0x{chosen_rate:04X}",
        "interval_clocks": soak["interval_clocks"],
        "run_seconds": args.run_seconds,
        "intervals_captured": len(interval_records),
        "toggle_misses": toggle_misses,
        "nonzero_channels": nonzero_channels,
        "allowed_channel0_bank_bins": list(CHANNEL0_BANK_BINS),
        "final_bin_sum": soak["final_bin_sum"],
        "final_bin0": soak["final_bin0"],
        "final_nonzero_bins": soak["final_nonzero_bins"],
        "timed_readout_mode": (
            "full_256_bin_snapshot_during_run_post_end_snapshot_records_clear"
        ),
        "timed_readout_note": (
            "Histogram RAM burst reads remain disabled. The helper takes "
            "single-word 256-bin snapshots while RUNNING because END_RUN "
            "clears the frozen bank on this image."
        ),
        "idle_completion": soak["idle_completion"],
        "calibration": calibration,
        "interval_summary": [
            {
                "interval_index": r["interval_index"],
                "toggle_seen": r["toggle_seen"],
                "bank_status": r["bank_status"],
                "target_elapsed_s": r["target_elapsed_s"],
                "wall_elapsed_s": r["wall_elapsed_s"],
                "total_hits": r["total_hits"],
                "dropped_hits": r["dropped_hits"],
                "last_interval_total_hits": r["last_interval_total_hits"],
                "last_interval_dropped_hits": (
                    r["last_interval_dropped_hits"]
                ),
                "sum": r["sum"],
                "bin0": r["bin0"],
                "bin32": r["bin32"],
                "nonzero_bins": r["nonzero_bins"],
            }
            for r in interval_records
        ],
    }
    counters = {
        "calibration": calibration,
        "soak": {
            key: value
            for key, value in soak.items()
            if key != "interval_records"
        },
    }
    _json_dump(out_dir / "verdict.json", verdict)
    _json_dump(out_dir / "counters.json", counters)
    _make_markdown(out_dir / "summary.md", verdict)
    print(("PASS" if passed else "FAIL") + f": evidence {out_dir}")
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
