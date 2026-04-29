#!/usr/bin/env python3
"""Run the Phase-5 histogram statistics evidence matrix.

This is a thin orchestrator around run_phase5_injector_datapath_sanity.py.  It
keeps one hardware transaction active at a time, records unavailable real-lane
scope as BLOCKED, and emits a JSON/Markdown artifact suitable for screenshot
rendering and scoreboard updates.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import sys
import time
from pathlib import Path
from types import SimpleNamespace
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import _default_sc_tool  # noqa: E402
from check_run_control import default_rc_tool  # noqa: E402
from run_phase4_emulator import fmt_hex, rc_send, sc_read  # noqa: E402
from run_phase5_injector_datapath_sanity import run_case  # noqa: E402


SCENARIOS: dict[str, dict[str, Any]] = {
    "rate_100k": {
        "title": "Rate 100 kHz periodic",
        "inject_mode": "periodic",
        "pulse_interval": 1250,
        "hist_profile": "rate",
        "injection_multiplicity": 1,
        "cluster_size": 1,
    },
    "rate_10k": {
        "title": "Rate 10 kHz periodic",
        "inject_mode": "periodic",
        "pulse_interval": 12500,
        "hist_profile": "rate",
        "injection_multiplicity": 1,
        "cluster_size": 1,
    },
    "delay_100k": {
        "title": "Delay 100 kHz periodic, all channels",
        "inject_mode": "periodic",
        "pulse_interval": 1250,
        "hist_profile": "delay-mts-both",
        "injection_multiplicity": 1,
        "cluster_size": 32,
    },
    "header_1": {
        "title": "Delay header mode, 1 injection per header",
        "inject_mode": "header",
        "pulse_interval": 12500,
        "hist_profile": "delay-mts-both",
        "injection_multiplicity": 1,
        "cluster_size": 1,
    },
    "header_2": {
        "title": "Delay header mode, 2 injections per header",
        "inject_mode": "header",
        "pulse_interval": 12500,
        "hist_profile": "delay-mts-both",
        "injection_multiplicity": 2,
        "cluster_size": 1,
    },
    "header_5": {
        "title": "Delay header mode, 5 injections per header",
        "inject_mode": "header",
        "pulse_interval": 12500,
        "hist_profile": "delay-mts-both",
        "injection_multiplicity": 5,
        "cluster_size": 1,
    },
}


def default_output() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    return BOARD_TEST_DIR / "reports" / f"phase5_histogram_matrix_{stamp}.md"


def parse_csv(text: str, allowed: set[str]) -> list[str]:
    values = [item.strip() for item in text.split(",") if item.strip()]
    bad = [item for item in values if item not in allowed]
    if bad:
        raise argparse.ArgumentTypeError(f"unsupported value(s): {', '.join(bad)}")
    return values


def parse_mask(text: str) -> int:
    value = int(text, 0)
    if value < 0 or value > 0xFF:
        raise argparse.ArgumentTypeError("mask must be in range 0x00..0xff")
    return value


def scope_items(scope_text: str) -> list[tuple[str, int]]:
    if scope_text == "all":
        names = ["all", *[f"lane{idx}" for idx in range(8)]]
    else:
        names = [item.strip() for item in scope_text.split(",") if item.strip()]
    items: list[tuple[str, int]] = []
    for name in names:
        if name == "all":
            items.append((name, 0xFF))
        elif name.startswith("lane") and name[4:].isdigit() and 0 <= int(name[4:]) <= 7:
            lane = int(name[4:])
            items.append((name, 1 << lane))
        else:
            raise argparse.ArgumentTypeError(f"unsupported scope {name!r}")
    return items


def source_plan(source: str, requested_mask: int, real_lane_mask: int, mixed_emulator_mask: int) -> tuple[int, int, int, str | None]:
    """Return selected emulator mask, active emulator mask, LVDS lane mask, block reason."""
    if source == "emulator":
        return 0xFF, requested_mask, 0x1FF, None

    if source == "real":
        available = requested_mask & real_lane_mask
        if available == 0:
            return 0x00, 0x00, 0x000, "requested real lane is not currently configured/locked"
        if requested_mask != available:
            return 0x00, 0x00, available, "partial_real_available_only"
        return 0x00, 0x00, available, None

    emu_active = requested_mask & mixed_emulator_mask
    real_active = requested_mask & real_lane_mask & (~mixed_emulator_mask & 0xFF)
    if emu_active == 0 and real_active == 0:
        return mixed_emulator_mask, 0x00, 0x000, "mixed source has neither emulator nor available real lanes for this scope"
    return mixed_emulator_mask, emu_active, real_active, None


def lane_from_scope(scope: str) -> int | None:
    if scope.startswith("lane") and scope[4:].isdigit():
        lane = int(scope[4:])
        if 0 <= lane <= 7:
            return lane
    return None


def header_channel_for_scope(args: argparse.Namespace, scenario: dict[str, Any], scope: str) -> int:
    lane = lane_from_scope(scope)
    if scenario["inject_mode"] == "header" and lane is not None:
        return lane
    return args.header_channel


def make_case_args(
    args: argparse.Namespace,
    scenario: dict[str, Any],
    source: str,
    scope: str,
    selected_emu_mask: int,
    active_emu_mask: int,
    lvds_mask: int,
    run_number: int,
) -> SimpleNamespace:
    return SimpleNamespace(
        link=args.link,
        sc_tool=args.sc_tool,
        rc_tool=args.rc_tool,
        device=args.device,
        feb=args.feb,
        run_number_base=run_number,
        rc_settle_us=args.rc_settle_us,
        post_stop_reset_ms=args.post_stop_reset_ms,
        post_sync_ms=args.post_sync_ms,
        pre_inject_ms=args.pre_inject_ms,
        post_end_ms=args.post_end_ms,
        duration_ms=args.duration_ms,
        source=source,
        emulator_source_mask=selected_emu_mask if source == "mixed" else None,
        lvds_lane_mask=lvds_mask,
        skip_lvds_config=False,
        active_lanes_mask=active_emu_mask,
        inject_mode=scenario["inject_mode"],
        hist_profile=scenario["hist_profile"],
        rate_tolerance_pct=args.rate_tolerance_pct,
        pulse_intervals=[scenario["pulse_interval"]],
        pulse_high_cycles=args.pulse_high_cycles,
        onclick_count=16,
        onclick_spacing_ms=2,
        header_delay=args.header_delay,
        header_interval=args.header_interval,
        injection_multiplicity=scenario["injection_multiplicity"],
        header_channel=header_channel_for_scope(args, scenario, scope),
        prbs_rate=999,
        prbs_pattern=1,
        prbs_seed=0xACE1,
        prbs_ctrl=0x4,
        emulator_background_rate=0,
        emulator_noise_rate=0,
        emulator_hit_mode="poisson",
        emulator_seed=args.emulator_seed,
        cluster_size=scenario["cluster_size"],
        cluster_center=args.cluster_center,
        cluster_cross_asic=False,
        cluster_center_global=args.cluster_center,
        cluster_lane_count=8,
        inject_channel_mask=0xFFFFFFFF,
        short_mode=False,
        mts_expected_latency=None,
        mts_delay_ts_field="keep",
        mts_drop_delay_error="keep",
        ring_filter_inerr="keep",
        continue_on_error=True,
    )


def blocked_record(index: int, run_number: int, source: str, scope: str, scenario_name: str, requested_mask: int, reason: str) -> dict[str, Any]:
    return {
        "matrix_index": index,
        "run_number": run_number,
        "source": source,
        "scope": scope,
        "scenario": scenario_name,
        "requested_lanes_mask": requested_mask,
        "effective_lanes_mask": 0,
        "status": "BLOCKED",
        "block_reason": reason,
        "summary": {
            "pass": False,
            "phase5_classification": "BLOCKED",
            "hist_total_delta": 0,
            "hist_drop_delta": 0,
            "mts_total_delta": 0,
            "mts_discard_delta": 0,
            "ring_inerr_delta": 0,
            "frame_crc_delta": 0,
            "frame_actual_delta": 0,
            "emu_frame_delta": 0,
            "post_end_clean": False,
        },
    }


def prime_sc_path(args: argparse.Namespace) -> list[str]:
    logs = []
    logs.append(rc_send(args.rc_tool, args.device, args.feb, "reset", settle_us=args.rc_settle_us))
    logs.append(rc_send(args.rc_tool, args.device, 2, "address", settle_us=args.rc_settle_us))
    logs.append(rc_send(args.rc_tool, args.device, args.feb, "stop-reset", settle_us=args.rc_settle_us))
    time.sleep(args.post_stop_reset_ms / 1000.0)
    uid = sc_read(args.sc_tool, args.link, 0x0A900)[0]
    if uid != 0x48495354:
        raise RuntimeError(f"histogram UID mismatch after SC prime: got 0x{uid:08X}")
    return logs


def write_report(path: Path, timestamp: str, args: argparse.Namespace, records: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    pass_count = sum(1 for rec in records if rec.get("status") == "PASS")
    fail_count = sum(1 for rec in records if rec.get("status") == "FAIL")
    blocked_count = sum(1 for rec in records if rec.get("status") == "BLOCKED")
    partial_count = sum(1 for rec in records if rec.get("status") == "PASS_PARTIAL")
    lines = [
        "# Phase 5 Histogram Statistics Matrix",
        "",
        f"- Timestamp: `{timestamp}`",
        f"- Firmware vehicle: `{args.firmware_note}`",
        f"- SC link: `{args.link}`",
        f"- FEB target: `{args.feb}`",
        f"- Sources: `{','.join(args.sources)}`",
        f"- Real-lane availability mask: `{fmt_hex(args.real_lane_mask)}`",
        f"- Mixed emulator-source mask: `{fmt_hex(args.mixed_emulator_mask)}`",
        f"- Duration per run: `{args.duration_ms} ms`",
        f"- Result: `{pass_count} PASS / {partial_count} PASS_PARTIAL / {fail_count} FAIL / {blocked_count} BLOCKED`",
        "",
        "## Summary",
        "",
        "| # | Scenario | Source | Scope | Requested | Mux emu select | Effective emu | Effective real/LVDS | Hist profile | Hits | Rate Exp | Rate Err | Drops | MTS | Discard | CRC | Ring InErr | Status |",
        "|---:|---|---|---|---:|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for rec in records:
        summary = rec.get("summary", {})
        lines.append(
            f"| {rec['matrix_index']} | `{rec['scenario']}` | `{rec['source']}` | `{rec['scope']}` | "
            f"`{fmt_hex(rec.get('requested_lanes_mask', 0))}` | `{fmt_hex(rec.get('selected_source_mask', 0))}` | "
            f"`{fmt_hex(rec.get('effective_emulator_mask', 0))}` | "
            f"`{fmt_hex(rec.get('effective_lvds_mask', 0))}` | `{rec.get('hist_profile', '-')}` | "
            f"{summary.get('hist_total_delta', 0)} | {summary.get('rate_expected_hits', 0)} | "
            f"{summary.get('rate_error_hits', 0)} | {summary.get('hist_drop_delta', 0)} | "
            f"{summary.get('mts_total_delta', 0)} | {summary.get('mts_discard_delta', 0)} | "
            f"{summary.get('frame_crc_delta', 0)} | {summary.get('ring_inerr_delta', 0)} | `{rec.get('status', 'UNKNOWN')}` |"
        )

    lines.extend(["", "## Notes", ""])
    lines.append("- `PASS_PARTIAL` means the requested `all` real-MuTRiG scope was reduced to the currently configured real lanes, mask `0x09` by default. It is evidence, but not full eight-MuTRiG closure.")
    lines.append("- Rate scenarios use the Phase-5 histogram preset: `INTERVAL_CFG = 125000000` (1 s at 125 MHz) and update key `data[38:30] = {ASIC[3:0], channel[4:0]}` for 256-channel global-rate bins. Rate-mode PASS requires the v26.1.6 `LAST_INTERVAL_TOTAL_HITS` CSR and aggregate hits within +/-1% of the pulse-interval expectation.")
    lines.append("- Delay scenarios use histogram profile `delay-mts-both`, i.e. `histogram_statistics_0.CONTROL.mode = -7`, which samples `mts_preprocessor_0.ts_delta` on debug_1 and `mts_preprocessor_1.ts_delta` on debug_2 into one delay PDF. Current mode -7 does not carry a lane tag through the histogram CSR filter; eight-lane overlays require eight isolated lane-source runs unless the RTL is extended with lane-tagged debug filtering.")
    lines.append("- Final closure must use raw histogram-bin readout and DISLIN plots; this matrix remains quick CSR triage and does not replace the histogram plot evidence.")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_json(path: Path, timestamp: str, args: argparse.Namespace, records: list[dict[str, Any]], prime_logs: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "timestamp": timestamp,
        "firmware_note": args.firmware_note,
        "args": {
            "link": args.link,
            "feb": args.feb,
            "duration_ms": args.duration_ms,
            "sources": args.sources,
            "scopes": args.scope,
            "scenarios": args.scenarios,
            "real_lane_mask": args.real_lane_mask,
            "mixed_emulator_mask": args.mixed_emulator_mask,
        },
        "prime_logs": prime_logs,
        "records": records,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Phase-5 histogram statistics source/scope/scenario matrix.")
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--rc-tool", type=Path, default=default_rc_tool())
    parser.add_argument("--device", default="/dev/mudaq0")
    parser.add_argument("--feb", type=int, default=7)
    parser.add_argument("--run-number-base", type=int, default=48000)
    parser.add_argument("--rc-settle-us", type=int, default=50000)
    parser.add_argument("--post-stop-reset-ms", type=int, default=50)
    parser.add_argument("--post-sync-ms", type=int, default=0)
    parser.add_argument("--pre-inject-ms", type=int, default=5)
    parser.add_argument("--post-end-ms", type=int, default=80)
    parser.add_argument("--duration-ms", type=int, default=1100)
    parser.add_argument("--sources", type=lambda s: parse_csv(s, {"emulator", "real", "mixed"}), default=["emulator", "real", "mixed"])
    parser.add_argument("--scope", default="all", help="all, or comma list like lane0,lane3")
    parser.add_argument("--scenarios", type=lambda s: parse_csv(s, set(SCENARIOS)), default=list(SCENARIOS))
    parser.add_argument("--real-lane-mask", type=parse_mask, default=0x09)
    parser.add_argument("--mixed-emulator-mask", type=parse_mask, default=0xF6)
    parser.add_argument("--pulse-high-cycles", type=int, default=8)
    parser.add_argument("--header-delay", type=int, default=100)
    parser.add_argument("--header-interval", type=int, default=1)
    parser.add_argument("--header-channel", type=int, default=0)
    parser.add_argument("--cluster-center", type=int, default=16)
    parser.add_argument("--emulator-seed", type=int, default=0xDEADBEEF)
    parser.add_argument("--rate-tolerance-pct", type=float, default=1.0)
    parser.add_argument("--max-runs", type=int, default=0, help="limit executed non-blocked runs; 0 means no limit")
    parser.add_argument("--no-prime", action="store_true")
    parser.add_argument("--firmware-note", default="top_stp_pipe_phase5_injector.sof checksum 0x13F0D32A")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--json-output", type=Path, default=None)
    args = parser.parse_args()

    os.environ.setdefault("BOARD_TEST_SC_ENABLE_MASK", "0x00000004")
    os.environ.setdefault("BOARD_TEST_SC_REPLY_TIMEOUT_MS", "1000")

    timestamp = dt.datetime.now().isoformat(timespec="seconds")
    output = args.output or default_output()
    json_output = args.json_output or output.with_suffix(".json")
    scopes = scope_items(args.scope)
    prime_logs = [] if args.no_prime else prime_sc_path(args)

    records: list[dict[str, Any]] = []
    run_count = 0
    matrix_index = 0
    for scenario_name in args.scenarios:
        scenario = SCENARIOS[scenario_name]
        for source in args.sources:
            for scope_name, requested_mask in scopes:
                selected_emu_mask, active_emu_mask, lvds_mask, block_reason = source_plan(
                    source,
                    requested_mask,
                    args.real_lane_mask,
                    args.mixed_emulator_mask,
                )
                run_number = args.run_number_base + matrix_index
                if block_reason and block_reason != "partial_real_available_only":
                    records.append(blocked_record(matrix_index, run_number, source, scope_name, scenario_name, requested_mask, block_reason))
                    matrix_index += 1
                    continue
                if args.max_runs and run_count >= args.max_runs:
                    records.append(blocked_record(matrix_index, run_number, source, scope_name, scenario_name, requested_mask, "not run due to --max-runs limit"))
                    matrix_index += 1
                    continue

                case_args = make_case_args(args, scenario, source, scope_name, selected_emu_mask, active_emu_mask, lvds_mask, run_number)
                try:
                    case = run_case(case_args, 0, scenario["pulse_interval"])
                    summary = case["summary"]
                    status = "PASS" if summary.get("pass") else "FAIL"
                    if status == "PASS" and block_reason == "partial_real_available_only":
                        status = "PASS_PARTIAL"
                except Exception as exc:  # noqa: BLE001
                    retry_error = None
                    if not args.no_prime:
                        try:
                            prime_logs.extend(prime_sc_path(args))
                            case = run_case(case_args, 0, scenario["pulse_interval"])
                            case["retry_after_prime"] = True
                            summary = case["summary"]
                            status = "PASS" if summary.get("pass") else "FAIL"
                            if status == "PASS" and block_reason == "partial_real_available_only":
                                status = "PASS_PARTIAL"
                        except Exception as retry_exc:  # noqa: BLE001
                            retry_error = retry_exc
                    if retry_error is not None or args.no_prime:
                        case = {
                            "error": str(retry_error if retry_error is not None else exc),
                            "first_error": str(exc),
                            "summary": {
                                "pass": False,
                                "phase5_classification": "exception",
                                "hist_total_delta": 0,
                                "hist_drop_delta": 0,
                                "mts_total_delta": 0,
                                "mts_discard_delta": 0,
                                "ring_inerr_delta": 0,
                                "frame_crc_delta": 0,
                                "frame_actual_delta": 0,
                                "emu_frame_delta": 0,
                                "post_end_clean": False,
                            },
                        }
                        status = "FAIL"

                case.update(
                    {
                        "matrix_index": matrix_index,
                        "source": source,
                        "scenario": scenario_name,
                        "scenario_title": scenario["title"],
                        "scope": scope_name,
                        "requested_lanes_mask": requested_mask,
                        "effective_emulator_mask": active_emu_mask,
                        "effective_lvds_mask": lvds_mask,
                        "hist_profile": scenario["hist_profile"],
                        "status": status,
                        "partial_reason": block_reason,
                    }
                )
                records.append(case)
                run_count += 1
                summary = case["summary"]
                print(
                    f"matrix={matrix_index} scenario={scenario_name} source={source} scope={scope_name} "
                    f"status={status} hist={summary.get('hist_total_delta', 0)} drops={summary.get('hist_drop_delta', 0)} "
                    f"mts={summary.get('mts_total_delta', 0)}"
                )
                matrix_index += 1

    write_report(output, timestamp, args, records)
    write_json(json_output, timestamp, args, records, prime_logs)
    failures = [rec for rec in records if rec.get("status") == "FAIL"]
    print(f"report={output}")
    print(f"json={json_output}")
    print(
        "SUMMARY pass={pass_count} partial={partial_count} fail={fail_count} blocked={blocked_count}".format(
            pass_count=sum(1 for rec in records if rec.get("status") == "PASS"),
            partial_count=sum(1 for rec in records if rec.get("status") == "PASS_PARTIAL"),
            fail_count=len(failures),
            blocked_count=sum(1 for rec in records if rec.get("status") == "BLOCKED"),
        )
    )
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
