#!/usr/bin/env python3
"""Exercise the active mutrig_injector datapath against emulator or real sources."""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import (  # noqa: E402
    _default_jdi,
    _default_project_dir,
    _default_sc_tool,
    _default_system_console,
)
from check_run_control import default_rc_tool  # noqa: E402
from probe_phase4_stage_counters import (  # noqa: E402
    MTS_BASE_WORDS,
    MTS_CTRL_BYPASS_LAPSE,
    MTS_CTRL_DELAY_TS_FIELD_USE_T,
    MTS_CTRL_DISCARD_HITERR,
    MTS_CTRL_DROP_DELAY_ERROR,
    MTS_CTRL_GO,
    MTS_REG_OVERFLOW_LOOKBACK,
    RING_BASE_WORDS,
    RING_CTRL_FILTER_INERR,
    RING_CTRL_GO,
    add_counter_rate_summary,
    counter_delta,
    read_stage_snapshot,
    summarize_cycle,
    timed_stage_snapshot,
)
from phase5_real_mutrig_link_debug import read_lvds_snapshot  # noqa: E402
from run_phase4_emulator import (  # noqa: E402
    EMU_BASE_WORD,
    EMU_STRIDE_WORD,
    HIST_BIN_BASE_WORD,
    HIST_CSR_BASE_WORD,
    HIST_INGRESS_BASE_WORD,
    HIST_KEY_LOC_CHANNEL_POST,
    LVDS_CSR_BASE_WORD,
    SOURCE_MUX_BASE_WORD,
    SOURCE_MUX_CONTROL_CLEAR_COUNTERS,
    SOURCE_MUX_CONTROL_SELECT_EMULATOR,
    SOURCE_MUX_REG_CONTROL,
    SOURCE_MUX_STRIDE_WORD,
    clear_histogram,
    configure_lvds_lanes,
    decode_histogram_ingress_status,
    fmt_hex,
    rc_send,
    sc_read,
    sc_write,
    select_lane_sources,
)


INJECTOR_BASE_WORD = 0x0AC80
INJECTOR_UID = 0x4D494E4A
HIST_INGRESS_BASE_WORDS = (HIST_INGRESS_BASE_WORD, HIST_INGRESS_BASE_WORD + 4)
HIST_INGRESS_UID = 0x48495342
HIST_INTERVAL_CLOCKS_1S = 125_000_000
HIST_KEY_LOC_GLOBAL_CHANNEL_POST = (38 << 24) | (35 << 16) | (38 << 8) | 30
TOOLKIT_PRESET_SOURCE = "toolkits/fe_scifi/board_bring_up/fe_scifi_board_bring_up_project.tcl"
INJECT_MODE = {
    "off": 0,
    "header": 1,
    "periodic": 2,
    "async-periodic": 3,
    "onclick": 4,
    "prbs": 5,
}


def detect_injector_layout(args: argparse.Namespace) -> dict[str, Any]:
    """Detect old direct CSR layout vs. common UID/META header layout."""
    word0 = sc_read(args.sc_tool, args.link, INJECTOR_BASE_WORD, 1)[0]
    if word0 == INJECTOR_UID:
        meta = {}
        for page, name in ((0, "version"), (1, "date"), (2, "git"), (3, "instance_id")):
            sc_write(args.sc_tool, args.link, INJECTOR_BASE_WORD + 1, [page])
            meta[name] = sc_read(args.sc_tool, args.link, INJECTOR_BASE_WORD + 1, 1)[0]
        return {
            "name": "meta_header",
            "control_offset": 2,
            "uid": word0,
            "meta": meta,
        }
    return {
        "name": "legacy_direct",
        "control_offset": 0,
        "uid": None,
        "meta": {},
        "word0": word0,
    }


def injector_control_base(args: argparse.Namespace) -> int:
    layout = getattr(args, "injector_layout", None)
    offset = 0 if layout is None else int(layout.get("control_offset", 0))
    return INJECTOR_BASE_WORD + offset


def write_injector_mode(args: argparse.Namespace, mode: int) -> None:
    sc_write(args.sc_tool, args.link, injector_control_base(args) + 0, [mode])


def read_injector_regs_for_args(args: argparse.Namespace) -> dict[str, int]:
    return read_injector_regs(args.sc_tool, args.link, int(getattr(args, "injector_layout", {}).get("control_offset", 0)))


EMU_HIT_MODE = {
    "poisson": 0,
    "burst": 1,
    "poisson-iid": 2,
    "periodic": 3,
}
HIST_PROFILE = {
    "rate": {
        "description": "pre-RBCAM hit_type1 global channel/rate histogram",
        "toolkit_preset_id": "rate",
        "left_bound": 0,
        "right_bound": 0xFF,
        "bin_width": 1,
        "control": 0x00000101,
        "key_loc": HIST_KEY_LOC_GLOBAL_CHANNEL_POST,
    },
    "delay-debug1": {
        "description": "MTS debug_1 signed debug_ts latency histogram",
        "toolkit_preset_id": None,
        "left_bound": -1000,
        "right_bound": 3096,
        "bin_width": 16,
        "control": 0x000000F1,
        "key_loc": HIST_KEY_LOC_CHANNEL_POST,
    },
    "delay-mts-both": {
        "description": "combined signed MTS debug_ts latency histogram on debug_1/debug_2",
        "toolkit_preset_id": "delay_mts_both",
        "left_bound": -1000,
        "right_bound": 3096,
        "bin_width": 16,
        "control": 0x00000091,
        "key_loc": HIST_KEY_LOC_CHANNEL_POST,
    },
}


def select_histogram_ingress_source(sc_tool: Path, link: int, *, select_post: bool) -> dict[str, Any]:
    """Select all histogram ingress bridge sources and wait for idle switches.

    Rate plots use the pre-RBCAM MTS hit_type1 stream because the toolkit rate
    preset extracts data[38:30] = {ASIC,channel}. The post-hit-stack stream is
    packetized hit_type3; using the rate preset there collapses valid hits into
    meaningless bins.
    """
    target = 1 if select_post else 0
    bridge_rows: list[dict[str, Any]] = []
    primary_status: dict[str, Any] | None = None
    for base in HIST_INGRESS_BASE_WORDS:
        try:
            uid = sc_read(sc_tool, link, base + 0)[0]
        except Exception as exc:  # noqa: BLE001
            bridge_rows.append({"base": base, "present": False, "error": str(exc)})
            continue
        if uid != HIST_INGRESS_UID:
            bridge_rows.append(
                {
                    "base": base,
                    "present": False,
                    "uid": uid,
                    "error": f"unexpected UID 0x{uid:08X}",
                }
            )
            continue

        sc_write(sc_tool, link, base + 2, [target])
        last_status = 0
        decoded: dict[str, Any] = {}
        for _ in range(50):
            last_status = sc_read(sc_tool, link, base + 3)[0]
            decoded = decode_histogram_ingress_status(last_status)
            if (
                decoded["live_select_post"] == target
                and decoded["requested_select_post"] == target
                and decoded["switch_pending"] == 0
            ):
                break
            time.sleep(0.01)
        else:
            raise RuntimeError(
                "histogram ingress bridge did not switch to requested stream: "
                f"base=0x{base:05X} target={'post' if select_post else 'pre'} "
                f"status=0x{last_status:08X} decoded={decoded}"
            )

        decoded["base"] = base
        decoded["uid"] = uid
        decoded["present"] = True
        decoded["selected_source"] = "post" if select_post else "pre"
        bridge_rows.append(decoded)
        if primary_status is None:
            primary_status = dict(decoded)

    if primary_status is None:
        raise RuntimeError(f"no histogram ingress bridge responded at {HIST_INGRESS_BASE_WORDS}")
    primary_status["bridges"] = bridge_rows
    primary_status["bridge_count"] = sum(1 for row in bridge_rows if row.get("present"))
    primary_status["selected_source"] = "post" if select_post else "pre"
    return primary_status


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


def read_lvds_snapshot_for_args(args: argparse.Namespace) -> dict[str, Any] | None:
    if not getattr(args, "capture_lvds", False):
        return None
    try:
        return read_lvds_snapshot(args.sc_tool, args.link, read_dpa_unlocks=args.read_lvds_dpa_unlocks)
    except Exception as exc:  # noqa: BLE001
        if getattr(args, "require_lvds_snapshot", False):
            raise
        return {"error": str(exc)}


def optional_counter_delta(old: int | None, new: int | None) -> int | None:
    if old is None or new is None:
        return None
    if old == new:
        return 0
    if old == 0xFFFFFFFF or new == 0xFFFFFFFF:
        return None
    return counter_delta(old, new)


def summarize_lvds_window(before: dict[str, Any] | None, after: dict[str, Any] | None) -> dict[str, Any]:
    if before is None or after is None:
        return {"captured": False}
    if "error" in before or "error" in after:
        return {
            "captured": False,
            "before_error": before.get("error") if isinstance(before, dict) else None,
            "after_error": after.get("error") if isinstance(after, dict) else None,
        }

    before_lanes = {int(lane["lane"]): lane for lane in before.get("lanes", [])}
    lane_rows = []
    error_delta_total = 0
    dpa_delta_total = 0
    error_delta_lanes: list[int] = []
    dpa_delta_lanes: list[int] = []
    fatal_lanes: list[int] = []

    for lane in after.get("lanes", []):
        lane_idx = int(lane["lane"])
        old = before_lanes.get(lane_idx, {})
        err_delta = optional_counter_delta(old.get("error_counter"), lane.get("error_counter"))
        dpa_delta = optional_counter_delta(old.get("dpa_unlocks"), lane.get("dpa_unlocks"))
        if lane.get("error_counter") == 0xFFFFFFFF:
            fatal_lanes.append(lane_idx)
        if err_delta is not None and err_delta > 0:
            error_delta_total += err_delta
            error_delta_lanes.append(lane_idx)
        if dpa_delta is not None and dpa_delta > 0:
            dpa_delta_total += dpa_delta
            dpa_delta_lanes.append(lane_idx)
        lane_rows.append(
            {
                "lane": lane_idx,
                "mode_adaptive": lane.get("mode_adaptive"),
                "lane_go": lane.get("lane_go"),
                "dpa_hold": lane.get("dpa_hold"),
                "error_counter_before": old.get("error_counter"),
                "error_counter_after": lane.get("error_counter"),
                "error_delta": err_delta,
                "dpa_unlocks_before": old.get("dpa_unlocks"),
                "dpa_unlocks_after": lane.get("dpa_unlocks"),
                "dpa_unlock_delta": dpa_delta,
            }
        )

    return {
        "captured": True,
        "base": after.get("base"),
        "n_lane": after.get("n_lane"),
        "sync_pattern": after.get("sync_pattern"),
        "mode_mask_before": before.get("mode_mask"),
        "mode_mask_after": after.get("mode_mask"),
        "dpa_hold_before": before.get("dpa_hold"),
        "dpa_hold_after": after.get("dpa_hold"),
        "lane_go_before": before.get("lane_go"),
        "lane_go_after": after.get("lane_go"),
        "error_delta_total": error_delta_total,
        "error_delta_lanes": error_delta_lanes,
        "dpa_unlock_delta_total": dpa_delta_total,
        "dpa_unlock_delta_lanes": dpa_delta_lanes,
        "fatal_lanes": fatal_lanes,
        "lanes": lane_rows,
    }


def read_histogram_bins(
    sc_tool: Path,
    link: int,
    *,
    chunk_words: int = 1,
    read_delay_s: float = 0.0,
) -> list[int]:
    """Read histogram bins over the slow-control path.

    Keep the default conservative.  A 16-word read from the bin window has
    been observed to desynchronize the SC secondary ring while real MuTRiG
    traffic is active; use bulk reads only as an explicitly unsafe debug mode.
    """
    bins: list[int] = []
    for offset in range(0, 256, chunk_words):
        bins.extend(sc_read(sc_tool, link, HIST_BIN_BASE_WORD + offset, min(chunk_words, 256 - offset)))
        if read_delay_s > 0 and offset + chunk_words < 256:
            time.sleep(read_delay_s)
    return bins


def summarize_histogram_bins(bins: list[int], histogram_config: dict[str, Any]) -> dict[str, Any]:
    left = int(histogram_config.get("left_bound", 0) or 0)
    width = int(histogram_config.get("bin_width", 1) or 1)
    nonzero = []
    total = 0
    for idx, count in enumerate(bins):
        count_i = int(count or 0)
        total += count_i
        if count_i:
            nonzero.append(
                {
                    "bin": idx,
                    "center": left + idx * width + width / 2.0,
                    "count": count_i,
                }
            )
    top_bins = sorted(nonzero, key=lambda item: item["count"], reverse=True)[:16]
    return {
        "captured": True,
        "total": total,
        "nonzero_bins": len(nonzero),
        "top_bins": top_bins,
        "bins": bins,
    }


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

    # The emulator can fan one injector pulse into a configured cluster.  Real
    # MuTRiG TDC-test multiplicity depends on the XML channel mask loaded before
    # the run; full Phase-5 TDC-injection closure uses 32 channels per ASIC.
    real_hits_per_lane = max(1, int(getattr(args, "real_hits_per_lane", 1)))
    hits_per_pulse = (emulator_lanes * max(1, args.cluster_size)) + (real_lanes * real_hits_per_lane)
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


def add_mts_discard_acceptance(args: argparse.Namespace, summary: dict[str, Any]) -> None:
    """Classify low MTS discard as a fine-counter caveat instead of a hard fail."""
    mts_total = int(summary.get("mts_total_delta", 0) or 0)
    mts_discard = int(summary.get("mts_discard_delta", 0) or 0)
    tolerance_pct = float(getattr(args, "mts_discard_tolerance_pct", 0.0))
    tolerance_hits = 0
    discard_pct = None
    if mts_total > 0:
        tolerance_hits = int(round(mts_total * (tolerance_pct / 100.0)))
        discard_pct = 100.0 * mts_discard / mts_total

    summary["mts_discard_tolerance_pct"] = tolerance_pct
    summary["mts_discard_tolerance_hits"] = tolerance_hits
    summary["mts_discard_pct"] = discard_pct
    summary["mts_discard_within_tolerance"] = mts_discard <= tolerance_hits


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
    base = injector_control_base(args)
    sc_write(args.sc_tool, args.link, base + 0, [0])
    sc_write(args.sc_tool, args.link, base + 1, [args.header_delay])
    sc_write(args.sc_tool, args.link, base + 2, [args.header_interval])
    sc_write(args.sc_tool, args.link, base + 3, [args.injection_multiplicity])
    sc_write(args.sc_tool, args.link, base + 4, [args.header_channel])
    sc_write(args.sc_tool, args.link, base + 5, [pulse_interval])
    sc_write(args.sc_tool, args.link, base + 6, [args.pulse_high_cycles])
    sc_write(args.sc_tool, args.link, base + 7, [args.prbs_rate])
    sc_write(args.sc_tool, args.link, base + 8, [args.prbs_pattern])
    sc_write(args.sc_tool, args.link, base + 9, [args.prbs_seed])
    sc_write(args.sc_tool, args.link, base + 10, [args.prbs_ctrl])
    words = sc_read(args.sc_tool, args.link, base, 11)
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
    firmware to mts_preprocessor_0.debug_ts via the debug_1 stream.
    `delay-mts-both` selects mode -7 in the 26.1.4 histogram image, sampling
    debug_1 and debug_2 together so upper and lower MTS preprocessors share one
    delay PDF.
    """
    profile = HIST_PROFILE[args.hist_profile]
    filter_enable = bool(getattr(args, "hist_filter_enable", False))
    filter_key_loc_override = getattr(args, "hist_filter_key_loc", None)
    filter_key_value = int(getattr(args, "hist_filter_key_value", 0) or 0) & 0xFFFF
    if args.hist_profile == "rate":
        key_loc = int(profile["key_loc"])
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
        key_loc = int(profile["key_loc"])
        key_value = 0x00000000
        control_word = profile["control"] & 0xFFFFFFFF
        if filter_enable:
            if filter_key_loc_override is not None:
                key_loc = filter_key_loc_override
            key_value = filter_key_value
            control_word |= 0x00001000
        write_injector_mode(args, 0)
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
        "toolkit_preset_source": TOOLKIT_PRESET_SOURCE,
        "toolkit_preset_id": profile.get("toolkit_preset_id"),
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
        "mts_overflow_lookback": args.mts_overflow_lookback,
        "mts_bypass_lapse": args.mts_bypass_lapse,
        "mts_delay_ts_field": args.mts_delay_ts_field,
        "mts_drop_delay_error": args.mts_drop_delay_error,
        "ring_filter_inerr": args.ring_filter_inerr,
    }

    if (
        args.mts_delay_ts_field != "keep"
        or args.mts_bypass_lapse != "keep"
        or args.mts_drop_delay_error != "keep"
    ):
        ctrl = MTS_CTRL_GO | MTS_CTRL_DISCARD_HITERR
        if args.mts_bypass_lapse == "on":
            ctrl |= MTS_CTRL_BYPASS_LAPSE
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

    if args.mts_overflow_lookback is not None:
        for base in MTS_BASE_WORDS:
            sc_write(args.sc_tool, args.link, base + MTS_REG_OVERFLOW_LOOKBACK, [args.mts_overflow_lookback])

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
        jtag_hist_dump = run_jtag_hist_dump(args)
        remaining_s = max(0.0, (args.duration_ms / 1000.0) - float(jtag_hist_dump.get("elapsed_s", 0.0) or 0.0))
        if remaining_s > 0:
            time.sleep(remaining_s)
        actions.append({"action": "sleep_off", "duration_ms": args.duration_ms})
        sample, sample_timing = timed_stage_snapshot(args.sc_tool, args.link)
        return {
            "actions": actions,
            "injector_during": read_injector_regs_for_args(args),
            "sample": sample,
            "sample_timing": sample_timing,
            "jtag_hist_dump": jtag_hist_dump,
        }

    if args.inject_mode == "onclick":
        for index in range(args.onclick_count):
            write_injector_mode(args, mode_value)
            actions.append({"action": "onclick", "index": index})
            if args.onclick_spacing_ms > 0 and index + 1 < args.onclick_count:
                time.sleep(args.onclick_spacing_ms / 1000.0)
        settle_ms = max(args.duration_ms, args.onclick_spacing_ms)
        if settle_ms > 0:
            time.sleep(settle_ms / 1000.0)
        injector_during = read_injector_regs_for_args(args)
        sample, sample_timing = timed_stage_snapshot(args.sc_tool, args.link)
        write_injector_mode(args, 0)
        actions.append({"action": "force_off_after_onclick", "mode": 0})
        return {"actions": actions, "injector_during": injector_during, "sample": sample, "sample_timing": sample_timing}

    write_injector_mode(args, mode_value)
    actions.append({"action": "set_mode", "mode": mode_value})
    jtag_hist_dump = run_jtag_hist_dump(args)
    remaining_s = max(0.0, (args.duration_ms / 1000.0) - float(jtag_hist_dump.get("elapsed_s", 0.0) or 0.0))
    if remaining_s > 0:
        time.sleep(remaining_s)
    injector_during = read_injector_regs_for_args(args)
    sample, sample_timing = timed_stage_snapshot(args.sc_tool, args.link)
    write_injector_mode(args, 0)
    actions.append({"action": "force_off", "mode": 0})
    return {
        "actions": actions,
        "injector_during": injector_during,
        "sample": sample,
        "sample_timing": sample_timing,
        "jtag_hist_dump": jtag_hist_dump,
    }


def subprocess_text(output: str | bytes | None) -> str:
    if output is None:
        return ""
    if isinstance(output, bytes):
        return output.decode("utf-8", errors="replace")
    return output


def run_jtag_hist_dump(args: argparse.Namespace) -> dict[str, Any]:
    if args.jtag_hist_csv is None:
        return {"enabled": False}

    profile = args.jtag_hist_profile
    if profile is None:
        profile = "rate" if args.hist_profile == "rate" else "delay"

    csv_path = args.jtag_hist_csv.resolve()
    log_path = (args.jtag_hist_log or csv_path.with_suffix(".log")).resolve()
    csv_path.parent.mkdir(parents=True, exist_ok=True)
    log_path.parent.mkdir(parents=True, exist_ok=True)

    argv = [
        str(args.system_console),
        "-cli",
        "-disable_readline",
        "-disable_timeout",
        f"--project_dir={args.jtag_project_dir}",
        f"--jdi={args.jtag_jdi}",
        f"--script={args.jtag_hist_script}",
        "--",
        "--profile",
        profile,
        "--out",
        str(csv_path),
    ]
    if args.jtag_hist_wait_ms is not None:
        argv.extend(["--wait-ms", str(args.jtag_hist_wait_ms)])
    if args.jtag_hist_lane_filter is not None:
        argv.extend(["--lane-filter", str(args.jtag_hist_lane_filter)])

    env = os.environ.copy()
    if args.jtag_hist_display:
        env["DISPLAY"] = args.jtag_hist_display
    else:
        env.pop("DISPLAY", None)

    started = dt.datetime.now().isoformat(timespec="seconds")
    start_s = time.monotonic()
    try:
        proc = subprocess.run(
            argv,
            cwd=Path.cwd(),
            env=env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=args.jtag_hist_timeout_s,
            check=False,
        )
        output = subprocess_text(proc.stdout)
        rc = proc.returncode
        timed_out = False
    except subprocess.TimeoutExpired as exc:
        output = subprocess_text(exc.stdout)
        rc = 124
        timed_out = True
    elapsed_s = time.monotonic() - start_s

    log_path.write_text(
        json.dumps(
            {
                "argv": argv,
                "elapsed_s": elapsed_s,
                "returncode": rc,
                "started": started,
                "timed_out": timed_out,
                "timeout_s": args.jtag_hist_timeout_s,
            },
            sort_keys=True,
        )
        + "\n\n"
        + output,
        encoding="utf-8",
    )

    line_count = 0
    if csv_path.exists():
        with csv_path.open(encoding="utf-8") as handle:
            line_count = sum(1 for _ in handle)
    return {
        "enabled": True,
        "profile": profile,
        "csv": str(csv_path),
        "log": str(log_path),
        "returncode": rc,
        "timed_out": timed_out,
        "elapsed_s": elapsed_s,
        "csv_exists": csv_path.exists(),
        "csv_line_count": line_count,
    }


def read_injector_regs(sc_tool: Path, link: int, control_offset: int = 0) -> dict[str, int]:
    base = INJECTOR_BASE_WORD + control_offset
    words = sc_read(sc_tool, link, base, 11)
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
    mts_discard_ok = bool(summary.get("mts_discard_within_tolerance", False))
    if (
        summary["hist_total_delta"] > 0
        and summary["hist_drop_delta"] == 0
        and summary["frame_crc_delta"] == 0
        and mts_discard_ok
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

    address_feb = args.link if args.address_feb is None else args.address_feb
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "reset", settle_us=args.rc_settle_us))
    rc_log.append(rc_send(args.rc_tool, args.device, address_feb, "address", settle_us=args.rc_settle_us))
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "stop-reset", settle_us=args.rc_settle_us))
    if args.post_stop_reset_ms > 0:
        time.sleep(args.post_stop_reset_ms / 1000.0)
    write_injector_mode(args, 0)

    if args.skip_lvds_config:
        lane_go = sc_read(args.sc_tool, args.link, LVDS_CSR_BASE_WORD + 4)[0]
    else:
        lane_go = configure_lvds_lanes(args.sc_tool, args.link, args.lvds_lane_mask)
    selected_source_mask = source_mask(args)
    source_rows = select_lane_sources(args.sc_tool, args.link, selected_source_mask, clear_counters=True)
    histogram_config = configure_histogram_for_args(args)
    clear_histogram(args.sc_tool, args.link)
    ingress_status = select_histogram_ingress_source(
        args.sc_tool,
        args.link,
        select_post=(args.hist_ingress_source == "post"),
    )
    emu_config = configure_emulators_for_injector(args)
    injector_config = configure_injector(args, pulse_interval)
    debug_overrides = apply_debug_overrides(args)

    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "run-prepare", run_number, settle_us=args.rc_settle_us))
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "sync", settle_us=args.rc_settle_us))
    if args.post_sync_ms > 0:
        time.sleep(args.post_sync_ms / 1000.0)
    start_run_started_s = time.monotonic()
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "start-run", settle_us=args.rc_settle_us))
    start_run_finished_s = time.monotonic()
    if args.pre_inject_ms > 0:
        time.sleep(args.pre_inject_ms / 1000.0)

    clear_source_mux_counter_window(args, selected_source_mask)
    before, before_timing = timed_stage_snapshot(args.sc_tool, args.link)
    lvds_before = read_lvds_snapshot_for_args(args)
    inject_window = run_injector_window(args, pulse_interval)
    sample = inject_window["sample"]
    sample_timing = inject_window["sample_timing"]
    write_injector_mode(args, 0)
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "end-run", settle_us=args.rc_settle_us))
    if args.post_end_ms > 0:
        time.sleep(args.post_end_ms / 1000.0)
    after, after_timing = timed_stage_snapshot(args.sc_tool, args.link)
    lvds_after = read_lvds_snapshot_for_args(args)
    injector_after = read_injector_regs_for_args(args)
    hist_bins = None
    hist_bin_summary: dict[str, Any] = {"captured": False}
    if args.dump_hist_bins:
        try:
            hist_bins = read_histogram_bins(
                args.sc_tool,
                args.link,
                chunk_words=args.hist_bin_read_chunk_words,
                read_delay_s=args.hist_bin_read_delay_ms / 1000.0,
            )
            hist_bin_summary = summarize_histogram_bins(hist_bins, histogram_config)
        except Exception as exc:  # noqa: BLE001
            hist_bin_summary = {
                "captured": False,
                "error": str(exc),
                "chunk_words": args.hist_bin_read_chunk_words,
                "read_delay_ms": args.hist_bin_read_delay_ms,
            }

    summary = summarize_cycle(before, sample, after)
    counter_elapsed_s = sample_timing["read_midpoint_s"] - before_timing["read_midpoint_s"]
    add_counter_rate_summary(summary, counter_elapsed_s)
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
    add_mts_discard_acceptance(args, summary)
    lvds_summary = summarize_lvds_window(lvds_before, lvds_after)
    if (
        hist_bin_summary.get("captured")
        and int(hist_bin_summary.get("total", 0) or 0) == 0
        and int(summary.get("hist_last_interval_total", 0) or 0) > 0
    ):
        hist_bin_summary["artifact_grade"] = False
        hist_bin_summary["warning"] = (
            "zero histogram bins with nonzero LAST_INTERVAL_TOTAL_HITS; "
            "slow SC bin read likely crossed the ping-pong bank, use the burst "
            "System Console/toolkit dump for plotted artifacts"
        )
    elif hist_bin_summary.get("captured"):
        hist_bin_summary["artifact_grade"] = True
    if lvds_summary.get("captured"):
        summary["lvds_error_delta_total"] = lvds_summary.get("error_delta_total", 0)
        summary["lvds_error_delta_lanes"] = lvds_summary.get("error_delta_lanes", [])
        summary["lvds_dpa_unlock_delta_total"] = lvds_summary.get("dpa_unlock_delta_total", 0)
        summary["lvds_dpa_unlock_delta_lanes"] = lvds_summary.get("dpa_unlock_delta_lanes", [])
        summary["lvds_fatal_lanes"] = lvds_summary.get("fatal_lanes", [])
    else:
        summary["lvds_snapshot_error"] = lvds_summary
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
        "injector_layout": getattr(args, "injector_layout", {}),
        "duration_ms": args.duration_ms,
        "lane_go": lane_go,
        "source_rows_after_select": source_rows,
        "ingress_status_after_select": ingress_status,
        "histogram_config": histogram_config,
        "emulator_config": emu_config,
        "injector_config": injector_config,
        "debug_overrides": debug_overrides,
        "lvds_before": lvds_before,
        "lvds_after": lvds_after,
        "lvds_summary": lvds_summary,
        "hist_bins": hist_bins,
        "hist_bin_summary": hist_bin_summary,
        "injector_actions": {"actions": inject_window["actions"]},
        "jtag_hist_dump": inject_window.get("jtag_hist_dump", {"enabled": False}),
        "injector_during": inject_window["injector_during"],
        "injector_after": injector_after,
        "timing": {
            "before": before_timing,
            "sample": sample_timing,
            "after": after_timing,
            "start_run_started_s": start_run_started_s,
            "start_run_finished_s": start_run_finished_s,
            "counter_rate_elapsed_s": counter_elapsed_s,
            "run_start_to_sample_s": sample_timing["read_midpoint_s"] - start_run_started_s,
        },
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
        f"- LVDS SVD snapshot: `{'yes' if args.capture_lvds else 'no'}`",
        f"- LVDS per-lane DPA unlock reads: `{'yes' if args.read_lvds_dpa_unlocks else 'no'}`",
        f"- Histogram bin dump: `{'yes' if args.dump_hist_bins else 'no'}`",
        f"- JTAG histogram artifact dump: `{'yes' if args.jtag_hist_csv is not None else 'no'}`",
        f"- Histogram bin read chunk/delay: `{args.hist_bin_read_chunk_words}` words / `{args.hist_bin_read_delay_ms}` ms",
        f"- Active emulator lanes: `{fmt_hex(args.active_lanes_mask)}`",
        f"- Inject mode: `{args.inject_mode}`",
        f"- Injector layout: `{getattr(args, 'injector_layout', {}).get('name', 'unknown')}`",
        f"- Injector base/control offset: `{fmt_hex(INJECTOR_BASE_WORD)}` / `{getattr(args, 'injector_layout', {}).get('control_offset', 'unknown')}` words",
        f"- Histogram profile: `{args.hist_profile}`",
        f"- Histogram ingress source: `{args.hist_ingress_source}`",
        f"- Rate tolerance: `{args.rate_tolerance_pct:.3f}%`",
        f"- Real hits per lane for rate expectation: `{getattr(args, 'real_hits_per_lane', 1)}`",
        f"- Histogram filter enable: `{getattr(args, 'hist_filter_enable', False)}`",
        f"- Histogram filter key loc override: `{getattr(args, 'hist_filter_key_loc', None)}`",
        f"- Histogram filter key value: `{fmt_hex(getattr(args, 'hist_filter_key_value', 0) or 0)}`",
        f"- MTS expected latency override: `{args.mts_expected_latency if args.mts_expected_latency is not None else 'keep'}`",
        f"- MTS overflow lookback override: `{args.mts_overflow_lookback if args.mts_overflow_lookback is not None else 'keep'}`",
        f"- MTS bypass-lapse override: `{args.mts_bypass_lapse}`",
        f"- MTS delay-ts field override: `{args.mts_delay_ts_field}`",
        f"- MTS drop-delay-error override: `{args.mts_drop_delay_error}`",
        f"- MTS discard tolerance: `{args.mts_discard_tolerance_pct:.3f}%`",
        f"- Ring filter-inerr override: `{args.ring_filter_inerr}`",
        f"- Result: `{'PASS' if not failures else 'FAIL'}`",
        "",
        "## Case Summary",
        "",
        "| Case | Run | Source | Mode | Interval | Hist Hits | Hist Drops | MTS Hits | Ring InErr | Real Beats | LVDS Err Δ | DPA Unlock Δ | Class |",
        "|---:|---:|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for case in cases:
        summary = case.get("summary", {})
        lines.append(
            f"| {case.get('index', '?')} | {case.get('run_number', '?')} | `{case.get('source', args.source)}` | `{case.get('inject_mode', args.inject_mode)}` | "
            f"{case.get('pulse_interval', '?')} | {summary.get('hist_total_delta', 0)} | {summary.get('hist_drop_delta', 0)} | "
            f"{summary.get('mts_total_delta', 0)} | {summary.get('ring_inerr_delta', 0)} | "
            f"{summary.get('source_mux_real_delta', 0)} | "
            f"{summary.get('lvds_error_delta_total', 'n/a')} | {summary.get('lvds_dpa_unlock_delta_total', 'n/a')} | "
            f"`{summary.get('phase5_classification', 'exception')}` |"
        )

    lines.extend(
        [
            "",
            "## Configuration Notes",
            "",
            "- The active `mutrig_injector_0` exposes one `coe_inject_pulse` output. The emulator `inject_channel_mask` CSR is still written for visibility, but that mask only affects the separate masked-trigger conduit and is not driven by this injector instance.",
            "- Channel sanity in this report is therefore represented by emulator cluster center/size; ASIC sanity is represented by `active_lanes_mask` and the per-lane source mux selection.",
            "- For `inject-mode=off` with `emulator-hit-mode=periodic`, channel population comes from the emulator's internal channel scan. Choose a rate word that does not phase-lock to the 32-channel scan; rate word `5` only lights a subset, while the current `r53` control lights all 256 bins but is still not uniform enough for rate closure.",
            "- Scoped real-source runs select disabled emulator sources on non-requested lanes; otherwise an aligned idle/live MuTRiG lane can continue into MTS/histogram even when the LVDS lane-go mask requests a single lane.",
            "- The runner writes injector mode `0` before setup and immediately after the injection window because the current injector RTL accepts run-control but does not gate the pulse arbiter by RUNNING.",
            "- The runner autodetects the injector CSR layout. Current programmed images without UID/META use MODE at base+0; packaged images with UID/META use MODE at base+2.",
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
                f"- JTAG histogram artifact: `{case.get('jtag_hist_dump', {'enabled': False})}`",
                f"- Rate expected/tolerance/error: `{summary.get('rate_expected_hits', 0)}` / `±{summary.get('rate_tolerance_hits', 0)}` / `{summary.get('rate_error_hits', 0)}` hits",
                f"- MTS discard/tolerance: `{summary.get('mts_discard_delta', 0)}` / `±{summary.get('mts_discard_tolerance_hits', 0)}` hits (`{summary.get('mts_discard_pct', 0.0) if summary.get('mts_discard_pct') is not None else 'n/a'}` %)",
                f"- Post-end clean: `{'yes' if summary.get('post_end_clean', False) else 'no'}`",
                f"- LVDS error delta lanes: `{summary.get('lvds_error_delta_lanes', 'n/a')}`",
                f"- LVDS DPA unlock delta lanes: `{summary.get('lvds_dpa_unlock_delta_lanes', 'n/a')}`",
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
        lvds_summary = case.get("lvds_summary", {})
        if lvds_summary.get("captured"):
            lines.extend(
                [
                    "| Lane | Go | Mode | Hold | Err Before | Err After | Err Δ | DPA Before | DPA After | DPA Δ |",
                    "|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|",
                ]
            )
            for lane in lvds_summary.get("lanes", [])[:8]:
                mode = "adaptive" if lane.get("mode_adaptive") else "bit_slip"
                err_before = lane.get("error_counter_before")
                err_after = lane.get("error_counter_after")
                dpa_before = lane.get("dpa_unlocks_before")
                dpa_after = lane.get("dpa_unlocks_after")
                lines.append(
                    f"| {lane.get('lane')} | {lane.get('lane_go')} | `{mode}` | {lane.get('dpa_hold')} | "
                    f"`{fmt_hex(err_before) if err_before is not None else 'n/a'}` | "
                    f"`{fmt_hex(err_after) if err_after is not None else 'n/a'}` | "
                    f"{lane.get('error_delta', 'n/a')} | "
                    f"{dpa_before if dpa_before is not None else 'n/a'} | "
                    f"{dpa_after if dpa_after is not None else 'n/a'} | "
                    f"{lane.get('dpa_unlock_delta', 'n/a')} |"
                )
            lines.append("")
        elif lvds_summary:
            lines.extend([f"- LVDS snapshot error: `{lvds_summary}`", ""])
        hist_bin_summary = case.get("hist_bin_summary", {})
        if hist_bin_summary.get("error"):
            lines.extend([f"- Histogram bin dump error: `{hist_bin_summary.get('error')}`", ""])
        if hist_bin_summary.get("warning"):
            lines.extend([f"- Histogram bin dump warning: `{hist_bin_summary.get('warning')}`", ""])
        if hist_bin_summary.get("captured"):
            lines.extend(
                [
                    "| Hist Bin | Center | Count |",
                    "|---:|---:|---:|",
                ]
            )
            for row in hist_bin_summary.get("top_bins", []):
                lines.append(f"| {row['bin']} | {row['center']:.3f} | {row['count']} |")
            lines.append(
                f"\nHistogram bin dump total: `{hist_bin_summary.get('total', 0)}`, "
                f"nonzero bins: `{hist_bin_summary.get('nonzero_bins', 0)}`.\n"
            )

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
            "capture_lvds": args.capture_lvds,
            "read_lvds_dpa_unlocks": args.read_lvds_dpa_unlocks,
            "dump_hist_bins": args.dump_hist_bins,
            "hist_bin_read_chunk_words": args.hist_bin_read_chunk_words,
            "hist_bin_read_delay_ms": args.hist_bin_read_delay_ms,
            "jtag_hist_csv": str(args.jtag_hist_csv) if args.jtag_hist_csv else None,
            "jtag_hist_profile": args.jtag_hist_profile,
            "jtag_hist_wait_ms": args.jtag_hist_wait_ms,
            "jtag_hist_lane_filter": args.jtag_hist_lane_filter,
            "inject_mode": args.inject_mode,
            "duration_ms": args.duration_ms,
            "pulse_intervals": args.pulse_intervals,
            "pulse_high_cycles": args.pulse_high_cycles,
            "header_delay": args.header_delay,
            "header_interval": args.header_interval,
            "injection_multiplicity": args.injection_multiplicity,
            "header_channel": args.header_channel,
            "hist_profile": args.hist_profile,
            "hist_ingress_source": args.hist_ingress_source,
            "rate_tolerance_pct": args.rate_tolerance_pct,
            "real_hits_per_lane": getattr(args, "real_hits_per_lane", 1),
            "hist_filter_enable": getattr(args, "hist_filter_enable", False),
            "hist_filter_key_loc": getattr(args, "hist_filter_key_loc", None),
            "hist_filter_key_value": getattr(args, "hist_filter_key_value", 0),
            "cluster_size": args.cluster_size,
            "cluster_center": args.cluster_center,
            "inject_channel_mask": args.inject_channel_mask,
            "mts_expected_latency": args.mts_expected_latency,
            "mts_overflow_lookback": args.mts_overflow_lookback,
            "mts_bypass_lapse": args.mts_bypass_lapse,
            "mts_delay_ts_field": args.mts_delay_ts_field,
            "mts_drop_delay_error": args.mts_drop_delay_error,
            "mts_discard_tolerance_pct": args.mts_discard_tolerance_pct,
            "ring_filter_inerr": args.ring_filter_inerr,
            "injector_layout": getattr(args, "injector_layout", {}),
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
    parser.add_argument(
        "--address-feb",
        type=int,
        default=None,
        help="FEB id used for the reset-link address command after reset. Defaults to --link.",
    )
    parser.add_argument("--run-number-base", type=int, default=45000)
    parser.add_argument("--rc-settle-us", type=int, default=5000)
    parser.add_argument("--post-stop-reset-ms", type=int, default=50)
    parser.add_argument("--post-sync-ms", type=int, default=0)
    parser.add_argument("--pre-inject-ms", type=int, default=5)
    parser.add_argument("--post-end-ms", type=int, default=80)
    parser.add_argument("--duration-ms", type=int, default=1000)
    parser.add_argument("--source", choices=("emulator", "real", "mixed"), default="emulator")
    parser.add_argument("--emulator-source-mask", type=parse_mask)
    parser.add_argument("--lvds-lane-mask", type=parse_lane_mask, default=0x1FF)
    parser.add_argument("--skip-lvds-config", action="store_true")
    parser.add_argument("--capture-lvds", action=argparse.BooleanOptionalAction, default=None)
    parser.add_argument("--read-lvds-dpa-unlocks", action="store_true")
    parser.add_argument("--require-lvds-snapshot", action="store_true")
    parser.add_argument("--dump-hist-bins", action="store_true")
    parser.add_argument(
        "--jtag-hist-csv",
        type=Path,
        default=None,
        help="Optional artifact-grade System Console/JTAG histogram CSV captured while injector pulses are active.",
    )
    parser.add_argument("--jtag-hist-log", type=Path, default=None)
    parser.add_argument("--jtag-hist-script", type=Path, default=SCRIPT_DIR / "phase5_histogram_bin_dump.tcl")
    parser.add_argument("--jtag-hist-profile", choices=("rate", "delay", "header"), default=None)
    parser.add_argument("--jtag-hist-wait-ms", type=int, default=None)
    parser.add_argument("--jtag-hist-lane-filter", type=int, default=None)
    parser.add_argument("--jtag-hist-timeout-s", type=float, default=60.0)
    parser.add_argument("--jtag-hist-display", default=os.environ.get("DISPLAY"))
    parser.add_argument("--system-console", type=Path, default=_default_system_console())
    parser.add_argument("--jtag-jdi", type=Path, default=_default_jdi())
    parser.add_argument("--jtag-project-dir", type=Path, default=_default_project_dir())
    parser.add_argument(
        "--hist-bin-read-chunk-words",
        type=int,
        default=1,
        help="SC words per histogram-bin read. Default is conservative; values above 1 require --unsafe-bulk-hist-bin-read.",
    )
    parser.add_argument("--hist-bin-read-delay-ms", type=int, default=1)
    parser.add_argument("--unsafe-bulk-hist-bin-read", action="store_true")
    parser.add_argument(
        "--active-lanes-mask",
        type=parse_mask,
        default=None,
        help=(
            "Emulator lanes to enable. Defaults to 0x00 for --source real so "
            "non-requested lanes parked on emulator sources stay quiet, and "
            "0xff for emulator/mixed runs."
        ),
    )
    parser.add_argument("--inject-mode", choices=tuple(INJECT_MODE), default="periodic")
    parser.add_argument("--hist-profile", choices=tuple(HIST_PROFILE), default="rate")
    parser.add_argument(
        "--hist-ingress-source",
        choices=("pre", "post"),
        default="pre",
        help="Source for histogram_ingress_bridge_0. Rate artifacts require pre so data[38:30] is hit_type1 {ASIC,channel}.",
    )
    parser.add_argument("--rate-tolerance-pct", type=float, default=1.0)
    parser.add_argument(
        "--real-hits-per-lane",
        type=parse_u32,
        default=1,
        help="Expected real MuTRiG TDC-test hits per enabled lane per injector pulse; use 32 for full-channel ASIC XML.",
    )
    parser.add_argument("--hist-filter-enable", action="store_true")
    parser.add_argument("--hist-filter-key-loc", type=parse_u32, default=None)
    parser.add_argument("--hist-filter-key-value", type=parse_u32, default=0)
    parser.add_argument("--pulse-intervals", type=parse_intervals, default=[5000])
    parser.add_argument("--pulse-high-cycles", type=parse_u32, default=5)
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
    parser.add_argument("--mts-overflow-lookback", type=parse_u32, default=None)
    parser.add_argument("--mts-bypass-lapse", choices=("keep", "on", "off"), default="keep")
    parser.add_argument("--mts-delay-ts-field", choices=("keep", "t", "e"), default="keep")
    parser.add_argument("--mts-drop-delay-error", choices=("keep", "on", "off"), default="keep")
    parser.add_argument(
        "--mts-discard-tolerance-pct",
        type=float,
        default=1.0,
        help=(
            "Accept low MTS discards as a MuTRiG fine-counter caveat. "
            "rbCAM ingress closure is checked with the delay histogram 0..2000-cycle window."
        ),
    )
    parser.add_argument("--ring-filter-inerr", choices=("keep", "on", "off"), default="keep")
    parser.add_argument("--continue-on-error", action="store_true")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--json-output", type=Path, default=None)
    args = parser.parse_args()
    if args.active_lanes_mask is None:
        args.active_lanes_mask = 0x00 if args.source == "real" else 0xFF
    if args.capture_lvds is None:
        args.capture_lvds = args.source in ("real", "mixed")
    if args.hist_bin_read_chunk_words <= 0 or args.hist_bin_read_chunk_words > 16:
        parser.error("--hist-bin-read-chunk-words must be in range 1..16")
    if args.hist_bin_read_delay_ms < 0:
        parser.error("--hist-bin-read-delay-ms must be non-negative")
    if args.mts_discard_tolerance_pct < 0.0:
        parser.error("--mts-discard-tolerance-pct must be non-negative")
    if args.hist_bin_read_chunk_words > 1 and not args.unsafe_bulk_hist_bin_read:
        parser.error("histogram bin bulk reads require --unsafe-bulk-hist-bin-read")
    if args.jtag_hist_csv is not None:
        if args.jtag_hist_timeout_s <= 0:
            parser.error("--jtag-hist-timeout-s must be positive")
        if args.jtag_hist_wait_ms is not None and args.jtag_hist_wait_ms < 0:
            parser.error("--jtag-hist-wait-ms must be non-negative")
        if args.jtag_hist_lane_filter is not None and not (0 <= args.jtag_hist_lane_filter <= 7):
            parser.error("--jtag-hist-lane-filter must be 0..7")
        for attr in ("system_console", "jtag_jdi", "jtag_project_dir", "jtag_hist_script"):
            path = getattr(args, attr)
            if not Path(path).exists():
                parser.error(f"--{attr.replace('_', '-')} path does not exist: {path}")

    timestamp = dt.datetime.now().isoformat(timespec="seconds")
    output = args.output or default_output()
    json_output = args.json_output or output.with_suffix(".json")
    args.injector_layout = detect_injector_layout(args)

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
            write_injector_mode(args, 0)
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
