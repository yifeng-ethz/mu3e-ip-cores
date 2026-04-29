#!/usr/bin/env python3
"""Exercise the active mutrig_injector datapath against emulator or real sources."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import time
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import _default_sc_tool  # noqa: E402
from check_run_control import default_rc_tool  # noqa: E402
from probe_phase4_stage_counters import (  # noqa: E402
    MTS_BASE_WORDS,
    MTS_CTRL_DELAY_TS_FIELD_USE_T,
    MTS_CTRL_DISCARD_HITERR,
    MTS_CTRL_DROP_DELAY_ERROR,
    MTS_CTRL_GO,
    RING_BASE_WORDS,
    RING_CTRL_FILTER_INERR,
    RING_CTRL_GO,
    read_stage_snapshot,
    summarize_cycle,
)
from run_phase4_emulator import (  # noqa: E402
    EMU_BASE_WORD,
    EMU_STRIDE_WORD,
    HIST_CSR_BASE_WORD,
    HIST_KEY_LOC_CHANNEL_POST,
    LVDS_CSR_BASE_WORD,
    SOURCE_MUX_BASE_WORD,
    SOURCE_MUX_CONTROL_CLEAR_COUNTERS,
    SOURCE_MUX_CONTROL_SELECT_EMULATOR,
    SOURCE_MUX_REG_CONTROL,
    SOURCE_MUX_STRIDE_WORD,
    clear_histogram,
    configure_lvds_lanes,
    fmt_hex,
    rc_send,
    sc_read,
    sc_write,
    select_histogram_ingress_post,
    select_lane_sources,
)


INJECTOR_BASE_WORD = 0x0AC80
HIST_INTERVAL_CLOCKS_1S = 125_000_000
HIST_KEY_LOC_GLOBAL_CHANNEL_POST = (38 << 24) | (35 << 16) | (38 << 8) | 30
INJECT_MODE = {
    "off": 0,
    "header": 1,
    "periodic": 2,
    "async-periodic": 3,
    "onclick": 4,
    "prbs": 5,
}
EMU_HIT_MODE = {
    "poisson": 0,
    "burst": 1,
    "poisson-iid": 2,
    "periodic": 3,
}
HIST_PROFILE = {
    "rate": {
        "description": "post-hit channel/rate histogram",
        "left_bound": 0,
        "right_bound": 0xFF,
        "bin_width": 1,
        "control": 0x00000101,
        "key_loc": None,
    },
    "delay-debug1": {
        "description": "MTS debug_1 signed ts_delta delay histogram",
        "left_bound": 0,
        "right_bound": 0x0FFF,
        "bin_width": 16,
        "control": 0x000000F1,
        "key_loc": None,
    },
    "delay-mts-both": {
        "description": "combined signed MTS ts_delta delay histogram on debug_1/debug_2",
        "left_bound": 0,
        "right_bound": 0x0FFF,
        "bin_width": 16,
        "control": 0x00000091,
        "key_loc": None,
    },
}


def default_output() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    return BOARD_TEST_DIR / "reports" / f"phase5_injector_datapath_sanity_{stamp}.md"


def parse_mask(text: str) -> int:
    value = int(text, 0)
    if value < 0 or value > 0xFF:
        raise argparse.ArgumentTypeError("mask must be in range 0x00..0xff")
    return value


def parse_lane_mask(text: str) -> int:
    value = int(text, 0)
    if value < 0 or value > 0x1FF:
        raise argparse.ArgumentTypeError("lane mask must be in range 0x000..0x1ff")
    return value


def parse_u32(text: str) -> int:
    value = int(text, 0)
    if value < 0 or value > 0xFFFFFFFF:
        raise argparse.ArgumentTypeError("value must be in range 0..0xffffffff")
    return value


def parse_intervals(text: str) -> list[int]:
    intervals: list[int] = []
    for item in text.split(","):
        item = item.strip()
        if not item:
            continue
        value = int(item, 0)
        if value <= 0:
            raise argparse.ArgumentTypeError("pulse intervals must be positive")
        intervals.append(value)
    if not intervals:
        raise argparse.ArgumentTypeError("at least one pulse interval is required")
    return intervals


def source_mask(args: argparse.Namespace) -> int:
    if args.source == "emulator":
        return 0xFF
    if args.source == "real":
        # Park non-requested lanes on disabled emulator sources so a scoped
        # real-lane run cannot accidentally count every live MuTRiG lane.
        return (~args.lvds_lane_mask) & 0xFF
    if args.emulator_source_mask is None:
        raise ValueError("--source mixed requires --emulator-source-mask")
    return args.emulator_source_mask


def popcount(value: int) -> int:
    return int(value & 0xFFFFFFFF).bit_count()


def expected_periodic_rate_hits(args: argparse.Namespace, pulse_interval: int) -> int:
    """Expected aggregate 1 s histogram count for rate-profile periodic mode."""
    if args.hist_profile != "rate" or args.inject_mode != "periodic" or pulse_interval <= 0:
        return 0

    source_select = source_mask(args) & 0xFF
    if args.source == "emulator":
        emulator_lanes = popcount(args.active_lanes_mask & 0xFF)
        real_lanes = 0
    elif args.source == "real":
        emulator_lanes = 0
        real_lanes = popcount(args.lvds_lane_mask & 0xFF)
    else:
        emulator_lanes = popcount(args.active_lanes_mask & source_select)
        real_lanes = popcount((args.lvds_lane_mask & 0xFF) & (~source_select & 0xFF))

    # The emulator can fan one injector pulse into a configured cluster.  The
    # real MuTRiG TDC-test configuration used by this runner is one channel per
    # enabled ASIC unless a separate ASIC configuration flow changes it.
    hits_per_pulse = (emulator_lanes * max(1, args.cluster_size)) + real_lanes
    return int(round((HIST_INTERVAL_CLOCKS_1S / pulse_interval) * hits_per_pulse))


def add_rate_acceptance(args: argparse.Namespace, summary: dict[str, Any], pulse_interval: int) -> None:
    expected = expected_periodic_rate_hits(args, pulse_interval)
    summary["rate_expected_hits"] = expected
    summary["rate_tolerance_pct"] = args.rate_tolerance_pct
    summary["rate_tolerance_hits"] = 0
    summary["rate_error_hits"] = 0
    summary["rate_error_pct"] = None
    summary["rate_last_interval_available"] = summary.get("hist_rate_counter_source") == "last_interval"
    summary["rate_within_tolerance"] = True
    if expected <= 0:
        return

    observed = summary.get("hist_total_delta", 0)
    tolerance_hits = max(1, int(round(expected * (args.rate_tolerance_pct / 100.0))))
    error_hits = observed - expected
    summary["rate_tolerance_hits"] = tolerance_hits
    summary["rate_error_hits"] = error_hits
    summary["rate_error_pct"] = (100.0 * error_hits / expected) if expected else None
    summary["rate_within_tolerance"] = abs(error_hits) <= tolerance_hits


def emu_base(idx: int) -> int:
    return EMU_BASE_WORD + idx * EMU_STRIDE_WORD


def configure_emulators_for_injector(args: argparse.Namespace) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    hit_mode = EMU_HIT_MODE[args.emulator_hit_mode]
    for idx in range(8):
        base = emu_base(idx)
        enabled = 1 if (args.active_lanes_mask & (1 << idx)) else 0
        control = enabled | ((hit_mode & 0x3) << 1) | ((1 if args.short_mode else 0) << 3)
        rate_word = (args.emulator_noise_rate << 16) | args.emulator_background_rate
        cluster_word = (
            (args.cluster_size & 0x1F)
            | ((args.cluster_center & 0x1F) << 8)
            | ((1 if args.cluster_cross_asic else 0) << 13)
            | ((args.cluster_center_global & 0xFF) << 14)
            | ((idx & 0xF) << 22)
            | ((args.cluster_lane_count & 0xF) << 26)
        )

        sc_write(args.sc_tool, args.link, base + 0, [0x00000000])
        sc_write(args.sc_tool, args.link, base + 1, [rate_word])
        sc_write(args.sc_tool, args.link, base + 2, [cluster_word])
        sc_write(args.sc_tool, args.link, base + 3, [args.emulator_seed ^ idx])
        sc_write(args.sc_tool, args.link, base + 4, [0x00000008 | (idx << 4)])
        sc_write(args.sc_tool, args.link, base + 6, [args.inject_channel_mask])
        sc_write(args.sc_tool, args.link, base + 0, [control])
        readback = sc_read(args.sc_tool, args.link, base, 7)
        rows.append(
            {
                "lane": idx,
                "base": base,
                "enabled": enabled,
                "control": readback[0],
                "rate": readback[1],
                "cluster": readback[2],
                "seed": readback[3],
                "tx_mode": readback[4],
                "status": readback[5],
                "inject_channel_mask": readback[6],
            }
        )
    return rows


def configure_injector(args: argparse.Namespace, pulse_interval: int) -> dict[str, int]:
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 0, [0])
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 1, [args.header_delay])
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 2, [args.header_interval])
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 3, [args.injection_multiplicity])
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 4, [args.header_channel])
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 5, [pulse_interval])
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 6, [args.pulse_high_cycles])
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 7, [args.prbs_rate])
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 8, [args.prbs_pattern])
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 9, [args.prbs_seed])
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 10, [args.prbs_ctrl])
    words = sc_read(args.sc_tool, args.link, INJECTOR_BASE_WORD, 11)
    keys = [
        "mode",
        "header_delay",
        "header_interval",
        "injection_multiplicity",
        "header_channel",
        "pulse_interval",
        "pulse_high_cycles",
        "prbs_rate",
        "prbs_pattern",
        "prbs_seed",
        "prbs_ctrl",
    ]
    return dict(zip(keys, words))


def configure_histogram_for_args(args: argparse.Namespace) -> dict[str, Any]:
    """Apply the requested histogram profile and return the readback contract.

    `rate` programs the Phase-5 closure preset: one 1 s accumulation interval
    with update key data[38:30], i.e. ASIC[38:35] concatenated with
    channel[34:30].  That gives one bin per global MuTRiG channel across the
    8 x 32-channel FEB.

    `delay-debug1` uses histogram_statistics mode -1, which is wired in this
    firmware to mts_preprocessor_0.ts_delta via the debug_1 stream.
    `delay-mts-both` selects mode -7 in the 26.1.4 histogram image, sampling
    debug_1 and debug_2 together so upper and lower MTS preprocessors share one
    delay PDF.
    """
    profile = HIST_PROFILE[args.hist_profile]
    filter_enable = bool(getattr(args, "hist_filter_enable", False))
    filter_key_loc_override = getattr(args, "hist_filter_key_loc", None)
    filter_key_value = int(getattr(args, "hist_filter_key_value", 0) or 0) & 0xFFFF
    if args.hist_profile == "rate":
        key_loc = HIST_KEY_LOC_GLOBAL_CHANNEL_POST
        key_value = 0x00000000
        control_word = profile["control"] & 0xFFFFFFFF
        if filter_enable:
            if filter_key_loc_override is not None:
                key_loc = filter_key_loc_override
            key_value = filter_key_value
            control_word |= 0x00001000
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 3, [profile["left_bound"] & 0xFFFFFFFF])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 4, [profile["right_bound"] & 0xFFFFFFFF])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 5, [profile["bin_width"] & 0xFFFFFFFF])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 6, [key_loc])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 7, [key_value])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 10, [HIST_INTERVAL_CLOCKS_1S])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 2, [control_word])
        for _ in range(20):
            control = sc_read(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 2)[0]
            if (control & 0x2) == 0:
                break
            time.sleep(0.01)
        else:
            raise RuntimeError(f"histogram profile {args.hist_profile} apply did not clear apply_pending")
    else:
        key_loc = HIST_KEY_LOC_CHANNEL_POST
        key_value = 0x00000000
        control_word = profile["control"] & 0xFFFFFFFF
        if filter_enable:
            if filter_key_loc_override is not None:
                key_loc = filter_key_loc_override
            key_value = filter_key_value
            control_word |= 0x00001000
        sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 0, [0])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 3, [profile["left_bound"] & 0xFFFFFFFF])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 4, [profile["right_bound"] & 0xFFFFFFFF])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 5, [profile["bin_width"] & 0xFFFFFFFF])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 6, [key_loc])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 7, [key_value])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 10, [HIST_INTERVAL_CLOCKS_1S])
        sc_write(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 2, [control_word])
        for _ in range(20):
            control = sc_read(args.sc_tool, args.link, HIST_CSR_BASE_WORD + 2)[0]
            if (control & 0x2) == 0:
                break
            time.sleep(0.01)
        else:
            raise RuntimeError(f"histogram profile {args.hist_profile} apply did not clear apply_pending")

    words = {idx: sc_read(args.sc_tool, args.link, HIST_CSR_BASE_WORD + idx)[0] for idx in (0, 1, 2, 3, 4, 5, 6, 7, 10)}
    return {
        "profile": args.hist_profile,
        "description": profile["description"],
        "uid": words[0],
        "meta": words[1],
        "control": words[2],
        "left_bound": words[3],
        "right_bound": words[4],
        "bin_width": words[5],
        "key_loc": words[6],
        "key_value": words[7],
        "interval_cfg": words[10],
        "filter_enable_requested": filter_enable,
        "filter_key_loc_requested": filter_key_loc_override,
        "filter_key_value_requested": filter_key_value,
    }


def apply_debug_overrides(args: argparse.Namespace) -> dict[str, Any]:
    overrides: dict[str, Any] = {
        "mts_expected_latency": args.mts_expected_latency,
        "mts_delay_ts_field": args.mts_delay_ts_field,
        "mts_drop_delay_error": args.mts_drop_delay_error,
        "ring_filter_inerr": args.ring_filter_inerr,
    }

    if (
        args.mts_delay_ts_field != "keep"
        or args.mts_drop_delay_error != "keep"
    ):
        ctrl = MTS_CTRL_GO | MTS_CTRL_DISCARD_HITERR
        if args.mts_delay_ts_field in ("keep", "t"):
            ctrl |= MTS_CTRL_DELAY_TS_FIELD_USE_T
        if args.mts_drop_delay_error == "on":
            ctrl |= MTS_CTRL_DROP_DELAY_ERROR
        for base in MTS_BASE_WORDS:
            sc_write(args.sc_tool, args.link, base + 0, [ctrl])
        overrides["mts_ctrl_written"] = ctrl

    if args.mts_expected_latency is not None:
        for base in MTS_BASE_WORDS:
            sc_write(args.sc_tool, args.link, base + 2, [args.mts_expected_latency])

    if args.ring_filter_inerr != "keep":
        ctrl = RING_CTRL_GO
        if args.ring_filter_inerr == "on":
            ctrl |= RING_CTRL_FILTER_INERR
        for base in RING_BASE_WORDS.values():
            sc_write(args.sc_tool, args.link, base + 2, [ctrl])
        overrides["ring_ctrl_written"] = ctrl

    return overrides


def clear_source_mux_counter_window(args: argparse.Namespace, selected_source_mask: int) -> None:
    """Clear source-mux counters close to the measured injection window."""
    for idx in range(8):
        control = SOURCE_MUX_CONTROL_CLEAR_COUNTERS
        if selected_source_mask & (1 << idx):
            control |= SOURCE_MUX_CONTROL_SELECT_EMULATOR
        sc_write(
            args.sc_tool,
            args.link,
            SOURCE_MUX_BASE_WORD + idx * SOURCE_MUX_STRIDE_WORD + SOURCE_MUX_REG_CONTROL,
            [control],
        )


def run_injector_window(args: argparse.Namespace, pulse_interval: int) -> dict[str, Any]:
    mode_value = INJECT_MODE[args.inject_mode]
    actions: list[dict[str, Any]] = []

    if args.inject_mode == "off":
        time.sleep(args.duration_ms / 1000.0)
        actions.append({"action": "sleep_off", "duration_ms": args.duration_ms})
        return {
            "actions": actions,
            "injector_during": read_injector_regs(args.sc_tool, args.link),
            "sample": read_stage_snapshot(args.sc_tool, args.link),
        }

    if args.inject_mode == "onclick":
        for index in range(args.onclick_count):
            sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 0, [mode_value])
            actions.append({"action": "onclick", "index": index})
            if args.onclick_spacing_ms > 0 and index + 1 < args.onclick_count:
                time.sleep(args.onclick_spacing_ms / 1000.0)
        settle_ms = max(args.duration_ms, args.onclick_spacing_ms)
        if settle_ms > 0:
            time.sleep(settle_ms / 1000.0)
        injector_during = read_injector_regs(args.sc_tool, args.link)
        sample = read_stage_snapshot(args.sc_tool, args.link)
        sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 0, [0])
        actions.append({"action": "force_off_after_onclick", "mode": 0})
        return {"actions": actions, "injector_during": injector_during, "sample": sample}

    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 0, [mode_value])
    actions.append({"action": "set_mode", "mode": mode_value})
    time.sleep(args.duration_ms / 1000.0)
    injector_during = read_injector_regs(args.sc_tool, args.link)
    sample = read_stage_snapshot(args.sc_tool, args.link)
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 0, [0])
    actions.append({"action": "force_off", "mode": 0})
    return {"actions": actions, "injector_during": injector_during, "sample": sample}


def read_injector_regs(sc_tool: Path, link: int) -> dict[str, int]:
    words = sc_read(sc_tool, link, INJECTOR_BASE_WORD, 11)
    keys = [
        "mode",
        "header_delay",
        "header_interval",
        "injection_multiplicity",
        "header_channel",
        "pulse_interval",
        "pulse_high_cycles",
        "prbs_rate",
        "prbs_pattern",
        "prbs_seed",
        "prbs_ctrl",
    ]
    return dict(zip(keys, words))


def classify(args: argparse.Namespace, summary: dict[str, Any]) -> str:
    diagnostic_bypass = (
        args.ring_filter_inerr == "off"
        or args.mts_drop_delay_error == "on"
    )
    rate_profile = args.hist_profile == "rate" and summary.get("rate_expected_hits", 0) > 0
    if rate_profile and not summary.get("rate_last_interval_available", False):
        return "rate_last_interval_unavailable"
    if (
        summary["hist_total_delta"] > 0
        and summary["hist_drop_delta"] == 0
        and summary["frame_crc_delta"] == 0
        and summary["mts_discard_delta"] == 0
        and summary["ring_inerr_delta"] == 0
        and summary["post_end_clean"]
    ):
        if rate_profile and not summary.get("rate_within_tolerance", False):
            return "rate_out_of_tolerance"
        if diagnostic_bypass:
            return "diagnostic_bypass_clean_not_closure"
        return "PASS"
    if summary["hist_total_delta"] > 0 and summary["hist_drop_delta"] > 0:
        return "histogram_drop_or_saturation"
    if summary["hist_total_delta"] > 0 and summary["frame_crc_delta"] > 0:
        return "frame_crc_errors_with_histogram_hits"
    if summary["hist_total_delta"] > 0 and summary["mts_discard_delta"] > 0:
        return "mts_discard_with_histogram_hits"
    if summary["hist_total_delta"] > 0 and summary["ring_inerr_delta"] > 0:
        return "ring_input_errors_with_histogram_hits"
    if args.source == "real":
        if summary["source_mux_real_delta"] == 0:
            return "no_real_lane_activity"
        return "real_source_not_reaching_histogram"
    if args.source == "mixed" and summary["source_mux_selected_delta"] == 0:
        return "mixed_source_no_selected_activity"
    return summary["classification"]


def run_case(args: argparse.Namespace, index: int, pulse_interval: int) -> dict[str, Any]:
    run_number = args.run_number_base + index
    rc_log: list[str] = []
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 0, [0])

    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "reset", settle_us=args.rc_settle_us))
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "stop-reset", settle_us=args.rc_settle_us))
    if args.post_stop_reset_ms > 0:
        time.sleep(args.post_stop_reset_ms / 1000.0)

    if args.skip_lvds_config:
        lane_go = sc_read(args.sc_tool, args.link, LVDS_CSR_BASE_WORD + 4)[0]
    else:
        lane_go = configure_lvds_lanes(args.sc_tool, args.link, args.lvds_lane_mask)
    selected_source_mask = source_mask(args)
    source_rows = select_lane_sources(args.sc_tool, args.link, selected_source_mask, clear_counters=True)
    histogram_config = configure_histogram_for_args(args)
    clear_histogram(args.sc_tool, args.link)
    ingress_status = select_histogram_ingress_post(args.sc_tool, args.link)
    emu_config = configure_emulators_for_injector(args)
    injector_config = configure_injector(args, pulse_interval)
    debug_overrides = apply_debug_overrides(args)

    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "run-prepare", run_number, settle_us=args.rc_settle_us))
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "sync", settle_us=args.rc_settle_us))
    if args.post_sync_ms > 0:
        time.sleep(args.post_sync_ms / 1000.0)
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "start-run", settle_us=args.rc_settle_us))
    if args.pre_inject_ms > 0:
        time.sleep(args.pre_inject_ms / 1000.0)

    clear_source_mux_counter_window(args, selected_source_mask)
    before = read_stage_snapshot(args.sc_tool, args.link)
    inject_window = run_injector_window(args, pulse_interval)
    sample = inject_window["sample"]
    sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 0, [0])
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "end-run", settle_us=args.rc_settle_us))
    if args.post_end_ms > 0:
        time.sleep(args.post_end_ms / 1000.0)
    after = read_stage_snapshot(args.sc_tool, args.link)
    injector_after = read_injector_regs(args.sc_tool, args.link)

    summary = summarize_cycle(before, sample, after)
    summary["hist_live_total_delta"] = summary.get("hist_total_delta", 0)
    summary["hist_live_drop_delta"] = summary.get("hist_drop_delta", 0)
    summary["hist_last_interval_total"] = sample["histogram"].get("LAST_INTERVAL_TOTAL_HITS", 0)
    summary["hist_last_interval_dropped"] = sample["histogram"].get("LAST_INTERVAL_DROPPED_HITS", 0)
    summary["hist_rate_counter_source"] = "live_delta"
    if args.hist_profile == "rate":
        if summary["hist_last_interval_total"] or summary["hist_last_interval_dropped"]:
            summary["hist_total_delta"] = summary["hist_last_interval_total"]
            summary["hist_drop_delta"] = summary["hist_last_interval_dropped"]
            summary["hist_rate_counter_source"] = "last_interval"
        else:
            summary["hist_rate_counter_source"] = "live_delta_no_last_interval"
    add_rate_acceptance(args, summary, pulse_interval)
    summary["phase5_classification"] = classify(args, summary)
    summary["pass"] = summary["phase5_classification"] == "PASS"

    return {
        "index": index,
        "run_number": run_number,
        "pulse_interval": pulse_interval,
        "source": args.source,
        "selected_source_mask": selected_source_mask,
        "active_lanes_mask": args.active_lanes_mask,
        "inject_mode": args.inject_mode,
        "duration_ms": args.duration_ms,
        "lane_go": lane_go,
        "source_rows_after_select": source_rows,
        "ingress_status_after_select": ingress_status,
        "histogram_config": histogram_config,
        "emulator_config": emu_config,
        "injector_config": injector_config,
        "debug_overrides": debug_overrides,
        "injector_actions": {"actions": inject_window["actions"]},
        "injector_during": inject_window["injector_during"],
        "injector_after": injector_after,
        "rc_log": rc_log,
        "before": before,
        "sample": sample,
        "after": after,
        "summary": summary,
    }


def write_report(path: Path, timestamp: str, args: argparse.Namespace, cases: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    failures = [case for case in cases if not case.get("summary", {}).get("pass", False)]
    lines = [
        "# Phase 5 Injector Datapath Sanity Report",
        "",
        f"- Timestamp: `{timestamp}`",
        f"- SC link: `{args.link}`",
        f"- Device: `{args.device}`",
        f"- FEB target: `{args.feb}`",
        f"- Source: `{args.source}`",
        f"- Source emulator mask: `{fmt_hex(source_mask(args))}`",
        f"- LVDS lane-go mask: `{fmt_hex(args.lvds_lane_mask)}`",
        f"- LVDS configured by runner: `{'no' if args.skip_lvds_config else 'yes'}`",
        f"- Active emulator lanes: `{fmt_hex(args.active_lanes_mask)}`",
        f"- Inject mode: `{args.inject_mode}`",
        f"- Histogram profile: `{args.hist_profile}`",
        f"- Rate tolerance: `{args.rate_tolerance_pct:.3f}%`",
        f"- Histogram filter enable: `{getattr(args, 'hist_filter_enable', False)}`",
        f"- Histogram filter key loc override: `{getattr(args, 'hist_filter_key_loc', None)}`",
        f"- Histogram filter key value: `{fmt_hex(getattr(args, 'hist_filter_key_value', 0) or 0)}`",
        f"- MTS expected latency override: `{args.mts_expected_latency if args.mts_expected_latency is not None else 'keep'}`",
        f"- MTS delay-ts field override: `{args.mts_delay_ts_field}`",
        f"- MTS drop-delay-error override: `{args.mts_drop_delay_error}`",
        f"- Ring filter-inerr override: `{args.ring_filter_inerr}`",
        f"- Result: `{'PASS' if not failures else 'FAIL'}`",
        "",
        "## Case Summary",
        "",
        "| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | Emu Beats | Class |",
        "|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for case in cases:
        summary = case.get("summary", {})
        lines.append(
            f"| {case.get('index', '?')} | {case.get('run_number', '?')} | `{case.get('source', args.source)}` | `{case.get('inject_mode', args.inject_mode)}` | "
            f"{case.get('pulse_interval', '?')} | {summary.get('hist_total_delta', 0)} | {summary.get('hist_drop_delta', 0)} | "
            f"{summary.get('mts_total_delta', 0)} | {summary.get('ring_inerr_delta', 0)} | "
            f"{summary.get('source_mux_real_delta', 0)} | {summary.get('source_mux_emu_delta', 0)} | "
            f"`{summary.get('phase5_classification', 'exception')}` |"
        )

    lines.extend(
        [
            "",
            "## Configuration Notes",
            "",
            "- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.",
            "- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.",
            "- Scoped real-source runs select disabled emulator sources on non-requested lanes; otherwise an aligned idle/live MuTRiG lane can continue into MTS/histogram even when the LVDS lane-go mask requests a single lane.",
            "- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.",
            "",
            "## Per-Case Details",
            "",
        ]
    )

    for case in cases:
        summary = case.get("summary", {})
        lines.extend(
            [
                f"### Case {case.get('index', '?')}",
                "",
                f"- Run number: `{case.get('run_number', '?')}`",
                f"- Pulse interval: `{case.get('pulse_interval', '?')}`",
                f"- Pulse high cycles: `{case.get('injector_config', {}).get('pulse_high_cycles', '?')}`",
                f"- Injector mode during run: `{case.get('injector_during', {}).get('mode', '?')}`",
                f"- Injector mode after run: `{case.get('injector_after', {}).get('mode', '?')}`",
                f"- Lane-go readback: `{fmt_hex(case.get('lane_go', 0))}`",
            f"- Histogram ingress status: `{fmt_hex(case.get('ingress_status_after_select', {}).get('raw', 0))}`",
            f"- Histogram profile/readback: `{case.get('histogram_config', {})}`",
                f"- Debug overrides: `{case.get('debug_overrides', {})}`",
                f"- Source mux selected beat delta: `{summary.get('source_mux_selected_delta', 0)}`",
                f"- Emulator frame delta: `{summary.get('emu_frame_delta', 0)}`",
                f"- Frame CRC delta: `{summary.get('frame_crc_delta', 0)}`",
                f"- Frame actual-hit delta: `{summary.get('frame_actual_delta', 0)}`",
                f"- Histogram rate counter source: `{summary.get('hist_rate_counter_source', 'live_delta')}`",
                f"- Histogram live delta: `{summary.get('hist_live_total_delta', 0)}` / dropped `{summary.get('hist_live_drop_delta', 0)}`",
                f"- Histogram last interval: `{summary.get('hist_last_interval_total', 0)}` / dropped `{summary.get('hist_last_interval_dropped', 0)}`",
                f"- Rate expected/tolerance/error: `{summary.get('rate_expected_hits', 0)}` / `±{summary.get('rate_tolerance_hits', 0)}` / `{summary.get('rate_error_hits', 0)}` hits",
                f"- Post-end clean: `{'yes' if summary.get('post_end_clean', False) else 'no'}`",
                "",
            ]
        )
        if "error" in case:
            lines.extend([f"- Error: `{case['error']}`", ""])
            continue
        lines.extend(
            [
                "| Lane | Source Ctrl | Emu Enabled | Emu Ctrl | Emu Cluster | Emu Status |",
                "|---:|---:|---:|---:|---:|---:|",
            ]
        )
        source_by_lane = {row["idx"]: row for row in case["source_rows_after_select"]}
        emu_by_lane = {row["lane"]: row for row in case["emulator_config"]}
        for lane in range(8):
            source_row = source_by_lane[lane]
            emu_row = emu_by_lane[lane]
            lines.append(
                f"| {lane} | `{fmt_hex(source_row['control'])}` | {emu_row['enabled']} | "
                f"`{fmt_hex(emu_row['control'])}` | `{fmt_hex(emu_row['cluster'])}` | "
                f"`{fmt_hex(emu_row['status'])}` |"
            )
        lines.append("")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_json(path: Path, timestamp: str, args: argparse.Namespace, cases: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "timestamp": timestamp,
        "args": {
            "link": args.link,
            "device": args.device,
            "feb": args.feb,
            "source": args.source,
            "selected_source_mask": source_mask(args),
            "active_lanes_mask": args.active_lanes_mask,
            "lvds_lane_mask": args.lvds_lane_mask,
            "skip_lvds_config": args.skip_lvds_config,
            "inject_mode": args.inject_mode,
            "duration_ms": args.duration_ms,
            "pulse_intervals": args.pulse_intervals,
            "hist_profile": args.hist_profile,
            "rate_tolerance_pct": args.rate_tolerance_pct,
            "hist_filter_enable": getattr(args, "hist_filter_enable", False),
            "hist_filter_key_loc": getattr(args, "hist_filter_key_loc", None),
            "hist_filter_key_value": getattr(args, "hist_filter_key_value", 0),
            "cluster_size": args.cluster_size,
            "cluster_center": args.cluster_center,
            "inject_channel_mask": args.inject_channel_mask,
            "mts_expected_latency": args.mts_expected_latency,
            "mts_delay_ts_field": args.mts_delay_ts_field,
            "mts_drop_delay_error": args.mts_drop_delay_error,
            "ring_filter_inerr": args.ring_filter_inerr,
        },
        "cases": cases,
    }
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Run injector-driven datapath sanity checks through emulator, real, or mixed MuTRiG lane sources."
    )
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--rc-tool", type=Path, default=default_rc_tool())
    parser.add_argument("--device", default="/dev/mudaq0")
    parser.add_argument("--feb", type=int, default=7)
    parser.add_argument("--run-number-base", type=int, default=45000)
    parser.add_argument("--rc-settle-us", type=int, default=5000)
    parser.add_argument("--post-stop-reset-ms", type=int, default=50)
    parser.add_argument("--post-sync-ms", type=int, default=0)
    parser.add_argument("--pre-inject-ms", type=int, default=5)
    parser.add_argument("--post-end-ms", type=int, default=80)
    parser.add_argument("--duration-ms", type=int, default=250)
    parser.add_argument("--source", choices=("emulator", "real", "mixed"), default="emulator")
    parser.add_argument("--emulator-source-mask", type=parse_mask)
    parser.add_argument("--lvds-lane-mask", type=parse_lane_mask, default=0x1FF)
    parser.add_argument("--skip-lvds-config", action="store_true")
    parser.add_argument("--active-lanes-mask", type=parse_mask, default=0xFF)
    parser.add_argument("--inject-mode", choices=tuple(INJECT_MODE), default="periodic")
    parser.add_argument("--hist-profile", choices=tuple(HIST_PROFILE), default="rate")
    parser.add_argument("--rate-tolerance-pct", type=float, default=1.0)
    parser.add_argument("--hist-filter-enable", action="store_true")
    parser.add_argument("--hist-filter-key-loc", type=parse_u32, default=None)
    parser.add_argument("--hist-filter-key-value", type=parse_u32, default=0)
    parser.add_argument("--pulse-intervals", type=parse_intervals, default=[5000])
    parser.add_argument("--pulse-high-cycles", type=parse_u32, default=8)
    parser.add_argument("--onclick-count", type=int, default=16)
    parser.add_argument("--onclick-spacing-ms", type=int, default=2)
    parser.add_argument("--header-delay", type=parse_u32, default=100)
    parser.add_argument("--header-interval", type=parse_u32, default=1)
    parser.add_argument("--injection-multiplicity", type=parse_u32, default=1)
    parser.add_argument("--header-channel", type=parse_u32, default=0)
    parser.add_argument("--prbs-rate", type=parse_u32, default=999)
    parser.add_argument("--prbs-pattern", type=parse_u32, default=1)
    parser.add_argument("--prbs-seed", type=parse_u32, default=0xACE1)
    parser.add_argument("--prbs-ctrl", type=parse_u32, default=0x4)
    parser.add_argument("--emulator-background-rate", type=parse_u32, default=0)
    parser.add_argument("--emulator-noise-rate", type=parse_u32, default=0)
    parser.add_argument("--emulator-hit-mode", choices=tuple(EMU_HIT_MODE), default="poisson")
    parser.add_argument("--emulator-seed", type=parse_u32, default=0xDEADBEEF)
    parser.add_argument("--cluster-size", type=parse_u32, default=1)
    parser.add_argument("--cluster-center", type=parse_u32, default=16)
    parser.add_argument("--cluster-cross-asic", action="store_true")
    parser.add_argument("--cluster-center-global", type=parse_u32, default=16)
    parser.add_argument("--cluster-lane-count", type=parse_u32, default=8)
    parser.add_argument("--inject-channel-mask", type=parse_u32, default=0xFFFFFFFF)
    parser.add_argument("--short-mode", action="store_true")
    parser.add_argument("--mts-expected-latency", type=parse_u32, default=None)
    parser.add_argument("--mts-delay-ts-field", choices=("keep", "t", "e"), default="keep")
    parser.add_argument("--mts-drop-delay-error", choices=("keep", "on", "off"), default="keep")
    parser.add_argument("--ring-filter-inerr", choices=("keep", "on", "off"), default="keep")
    parser.add_argument("--continue-on-error", action="store_true")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--json-output", type=Path, default=None)
    args = parser.parse_args()

    timestamp = dt.datetime.now().isoformat(timespec="seconds")
    output = args.output or default_output()
    json_output = args.json_output or output.with_suffix(".json")

    cases: list[dict[str, Any]] = []
    try:
        for index, pulse_interval in enumerate(args.pulse_intervals):
            try:
                case = run_case(args, index, pulse_interval)
            except Exception as exc:  # noqa: BLE001
                case = {
                    "index": index,
                    "run_number": args.run_number_base + index,
                    "pulse_interval": pulse_interval,
                    "source": args.source,
                    "selected_source_mask": source_mask(args),
                    "active_lanes_mask": args.active_lanes_mask,
                    "inject_mode": args.inject_mode,
                    "duration_ms": args.duration_ms,
                    "error": str(exc),
                    "summary": {
                        "pass": False,
                        "phase5_classification": "exception",
                        "hist_total_delta": 0,
                        "hist_drop_delta": 0,
                        "mts_total_delta": 0,
                        "ring_inerr_delta": 0,
                        "source_mux_real_delta": 0,
                        "source_mux_emu_delta": 0,
                        "source_mux_selected_delta": 0,
                        "emu_frame_delta": 0,
                        "frame_crc_delta": 0,
                        "frame_actual_delta": 0,
                        "post_end_clean": False,
                    },
                }
                cases.append(case)
                print(f"case={index} interval={pulse_interval} class=exception error={exc}", file=sys.stderr)
                if not args.continue_on_error:
                    break
                continue
            cases.append(case)
            summary = case["summary"]
            print(
                "case={case} interval={interval} class={klass} "
                "hist={hist} drops={drops} mts={mts} real={real} emu={emu}".format(
                    case=index,
                    interval=pulse_interval,
                    klass=summary["phase5_classification"],
                    hist=summary["hist_total_delta"],
                    drops=summary["hist_drop_delta"],
                    mts=summary["mts_total_delta"],
                    real=summary["source_mux_real_delta"],
                    emu=summary["source_mux_emu_delta"],
                )
            )
    finally:
        try:
            sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 0, [0])
        except Exception as exc:  # noqa: BLE001
            print(f"WARN failed to force injector off in cleanup: {exc}", file=sys.stderr)

    write_report(output, timestamp, args, cases)
    write_json(json_output, timestamp, args, cases)
    failures = [case for case in cases if not case["summary"]["pass"]]
    print(f"report={output}")
    print(f"json={json_output}")
    print(f"SUMMARY pass={len(cases) - len(failures)} fail={len(failures)}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
