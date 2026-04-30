#!/usr/bin/env python3
"""Serialized Phase-5 real-MuTRiG LVDS/configuration boundary debug."""

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
REPO_ROOT = BOARD_TEST_DIR.parent.parent.parent

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import _default_sc_tool  # noqa: E402
from check_run_control import default_rc_tool  # noqa: E402
from configure_mutrig_from_xml import (  # noqa: E402
    CMD_MUTRIG_ASIC_CFG,
    MUTRIG_CFG_BASE_WORD,
    MUTRIG_CFG_OPCODE_STATUS,
    MUTRIG_CFG_OFFSET,
    MUTRIG_CFG_WORDS,
    SCRATCH_BASE_WORD,
    apply_channel_overrides,
    extract_param_info,
    load_mutrigs,
    pack_words,
    parse_asic_list,
    parse_channel_mask,
    poll_idle,
    write_cfg_words,
)
from probe_phase4_stage_counters import FRAME_RCV_BASE_WORDS, counter_delta  # noqa: E402
from run_phase4_emulator import (  # noqa: E402
    LVDS_CSR_BASE_WORD,
    SOURCE_MUX_BASE_WORD,
    SOURCE_MUX_REG_CONTROL,
    SOURCE_MUX_REG_EMU_BEATS,
    SOURCE_MUX_REG_LAST_SELECTED,
    SOURCE_MUX_REG_REAL_BEATS,
    SOURCE_MUX_REG_SELECTED_BEATS,
    SOURCE_MUX_REG_STATUS,
    SOURCE_MUX_REG_SWITCH_COUNT,
    SOURCE_MUX_REG_UID,
    SOURCE_MUX_STRIDE_WORD,
    rc_send,
    sc_read,
    sc_write,
    select_lane_sources,
)


LVDS_N_LANE = 9
LVDS_LANE_MASK = (1 << LVDS_N_LANE) - 1
LVDS_REG_WORDS = 16
LVDS_REG_MODE_MASK = 1
LVDS_REG_SOFT_RESET_REQ = 2
LVDS_REG_DPA_HOLD = 3
LVDS_REG_LANE_GO = 4
LVDS_REG_ERROR_BASE = 5
LVDS_REG_LANE_SELECTION = 14
LVDS_REG_DPA_UNLOCKS = 15
K28_5_IDLE = 0x1BC
K28_0_HEADER = 0x11C
K28_4_TRAILER = 0x19C


def sc_read_word(sc_tool: Path, link: int, addr: int) -> int:
    return sc_read(sc_tool, link, addr, 1)[0]


def default_output() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    return BOARD_TEST_DIR / "reports" / f"phase5_real_mutrig_link_debug_{stamp}.md"


def parse_mask(text: str) -> int:
    value = int(text, 0)
    if value < 0 or value > LVDS_LANE_MASK:
        raise argparse.ArgumentTypeError(f"mask must be in range 0x0..0x{LVDS_LANE_MASK:X}")
    return value


def fmt_hex(value: int, width: int = 8) -> str:
    return f"0x{value & ((1 << (width * 4)) - 1):0{width}X}"


def decode_source_status(raw: int) -> dict[str, int]:
    return {
        "select_emulator": raw & 0x1,
        "real_valid": (raw >> 1) & 0x1,
        "emu_valid": (raw >> 2) & 0x1,
        "selected_valid": (raw >> 3) & 0x1,
        "selected_channel": (raw >> 4) & 0xF,
        "selected_error": (raw >> 8) & 0x7,
        "real_channel": (raw >> 11) & 0xF,
        "real_error": (raw >> 15) & 0x7,
        "emu_channel": (raw >> 18) & 0xF,
        "emu_error": (raw >> 22) & 0x7,
        "both_valid": (raw >> 25) & 0x1,
    }


def decode_last_selected(raw: int) -> dict[str, int]:
    return {
        "data": raw & 0x1FF,
        "channel": (raw >> 9) & 0xF,
        "error": (raw >> 13) & 0x7,
        "source_emulator": (raw >> 16) & 0x1,
    }


def lvds_lane_state(error_count: int, mux_status: dict[str, int] | None) -> str:
    if error_count == 0xFFFFFFFF:
        return "fatal_training"
    if mux_status and mux_status["real_valid"]:
        error = mux_status["real_error"]
        data = mux_status.get("real_data", 0)
        if error & 0x4:
            return "loss_sync_pattern"
        if error & 0x2:
            return "parity_error"
        if error & 0x1:
            return "decode_error"
        if data == K28_5_IDLE:
            return "aligned_idle"
        if data == K28_0_HEADER:
            return "header_seen_sample"
        if data == K28_4_TRAILER:
            return "trailer_seen_sample"
        return "valid_symbol"
    if error_count:
        return "symbol_errors_no_live_sample"
    return "quiet_or_clean"


def read_lvds_snapshot(sc_tool: Path, link: int, *, read_dpa_unlocks: bool = False) -> dict[str, Any]:
    words = [sc_read_word(sc_tool, link, LVDS_CSR_BASE_WORD + offset) for offset in range(LVDS_REG_WORDS)]
    dpa_unlocks: dict[str, int] = {}
    if read_dpa_unlocks:
        original_lane_selection = words[LVDS_REG_LANE_SELECTION] & 0xF
        for lane in range(LVDS_N_LANE):
            sc_write(sc_tool, link, LVDS_CSR_BASE_WORD + LVDS_REG_LANE_SELECTION, [lane])
            dpa_unlocks[str(lane)] = sc_read_word(sc_tool, link, LVDS_CSR_BASE_WORD + LVDS_REG_DPA_UNLOCKS)
        if original_lane_selection < LVDS_N_LANE:
            sc_write(sc_tool, link, LVDS_CSR_BASE_WORD + LVDS_REG_LANE_SELECTION, [original_lane_selection])

    lanes = []
    for lane in range(LVDS_N_LANE):
        lanes.append(
            {
                "lane": lane,
                "mode_adaptive": (words[LVDS_REG_MODE_MASK] >> lane) & 0x1,
                "soft_reset_req": (words[LVDS_REG_SOFT_RESET_REQ] >> lane) & 0x1,
                "dpa_hold": (words[LVDS_REG_DPA_HOLD] >> lane) & 0x1,
                "lane_go": (words[LVDS_REG_LANE_GO] >> lane) & 0x1,
                "error_counter": words[LVDS_REG_ERROR_BASE + lane],
                "dpa_unlocks": dpa_unlocks.get(str(lane)),
            }
        )
    return {
        "base": LVDS_CSR_BASE_WORD,
        "raw_words": words,
        "capability": words[0],
        "n_lane": words[0] & 0xFF,
        "sync_pattern": (words[0] >> 16) & 0x3FF,
        "mode_mask": words[LVDS_REG_MODE_MASK],
        "soft_reset_req": words[LVDS_REG_SOFT_RESET_REQ],
        "dpa_hold": words[LVDS_REG_DPA_HOLD],
        "lane_go": words[LVDS_REG_LANE_GO],
        "lane_selection": words[LVDS_REG_LANE_SELECTION],
        "selected_dpa_unlocks": words[LVDS_REG_DPA_UNLOCKS],
        "lanes": lanes,
    }


def read_source_mux_snapshot(sc_tool: Path, link: int) -> list[dict[str, Any]]:
    rows = []
    for idx in range(8):
        base = SOURCE_MUX_BASE_WORD + idx * SOURCE_MUX_STRIDE_WORD
        words = {
            "uid": sc_read_word(sc_tool, link, base + SOURCE_MUX_REG_UID),
            "control": sc_read_word(sc_tool, link, base + SOURCE_MUX_REG_CONTROL),
            "status": sc_read_word(sc_tool, link, base + SOURCE_MUX_REG_STATUS),
            "real_beats": sc_read_word(sc_tool, link, base + SOURCE_MUX_REG_REAL_BEATS),
            "emu_beats": sc_read_word(sc_tool, link, base + SOURCE_MUX_REG_EMU_BEATS),
            "selected_beats": sc_read_word(sc_tool, link, base + SOURCE_MUX_REG_SELECTED_BEATS),
            "switch_count": sc_read_word(sc_tool, link, base + SOURCE_MUX_REG_SWITCH_COUNT),
            "last_selected": sc_read_word(sc_tool, link, base + SOURCE_MUX_REG_LAST_SELECTED),
        }
        status = decode_source_status(words["status"])
        last_selected = decode_last_selected(words["last_selected"])
        status["real_data"] = last_selected["data"] if last_selected["source_emulator"] == 0 else 0
        rows.append(
            {
                "idx": idx,
                "base": base,
                "uid": words["uid"],
                "control": words["control"],
                "status": status,
                "real_beats": words["real_beats"],
                "emu_beats": words["emu_beats"],
                "selected_beats": words["selected_beats"],
                "switch_count": words["switch_count"],
                "last_selected": last_selected,
            }
        )
    return rows


def annotate_lvds_with_mux(lvds: dict[str, Any], source_mux: list[dict[str, Any]]) -> None:
    mux_by_lane = {row["idx"]: row for row in source_mux}
    for lane in lvds["lanes"]:
        mux_row = mux_by_lane.get(lane["lane"])
        lane["source_mux_status"] = mux_row["status"] if mux_row else None
        lane["link_state"] = lvds_lane_state(lane["error_counter"], lane["source_mux_status"])


def read_boundary_snapshot(sc_tool: Path, link: int, *, read_dpa_unlocks: bool = False) -> dict[str, Any]:
    lvds = read_lvds_snapshot(sc_tool, link, read_dpa_unlocks=read_dpa_unlocks)
    source_mux = read_source_mux_snapshot(sc_tool, link)
    annotate_lvds_with_mux(lvds, source_mux)
    return {
        "lvds": lvds,
        "source_mux": source_mux,
        "frame_rcv": read_frame_rcv_snapshot_slow(sc_tool, link),
    }


def read_frame_rcv_snapshot_slow(sc_tool: Path, link: int) -> list[dict[str, int]]:
    rows = []
    for idx, base in enumerate(FRAME_RCV_BASE_WORDS):
        rows.append(
            {
                "lane": idx,
                "status_control": sc_read_word(sc_tool, link, base),
                "crc_err": sc_read_word(sc_tool, link, base + 1),
                "open_frame_count": sc_read_word(sc_tool, link, base + 2),
            }
        )
    return rows


def reset_lvds(args: argparse.Namespace) -> list[dict[str, int]]:
    actions: list[dict[str, int]] = []
    mask = args.lane_mask
    sc_write(args.sc_tool, args.link, LVDS_CSR_BASE_WORD + LVDS_REG_LANE_GO, [0])
    actions.append({"word": LVDS_REG_LANE_GO, "value": 0})
    sc_write(args.sc_tool, args.link, LVDS_CSR_BASE_WORD + LVDS_REG_DPA_HOLD, [0])
    actions.append({"word": LVDS_REG_DPA_HOLD, "value": 0})
    sc_write(args.sc_tool, args.link, LVDS_CSR_BASE_WORD + LVDS_REG_MODE_MASK, [args.mode_mask])
    actions.append({"word": LVDS_REG_MODE_MASK, "value": args.mode_mask})
    sc_write(args.sc_tool, args.link, LVDS_CSR_BASE_WORD + LVDS_REG_SOFT_RESET_REQ, [mask])
    actions.append({"word": LVDS_REG_SOFT_RESET_REQ, "value": mask})
    time.sleep(args.lvds_reset_ms / 1000.0)
    sc_write(args.sc_tool, args.link, LVDS_CSR_BASE_WORD + LVDS_REG_LANE_GO, [mask])
    actions.append({"word": LVDS_REG_LANE_GO, "value": mask})
    return actions


def prepare_run_control_for_spi(args: argparse.Namespace) -> list[str]:
    """Leave RUN_SYNC/RUNNING before issuing MuTRiG SPI configuration loads."""
    if args.skip_pre_config_stop_reset or not args.configure_asics:
        return []
    log = [
        rc_send(args.rc_tool, args.device, args.feb, "reset", settle_us=args.rc_settle_us),
        rc_send(args.rc_tool, args.device, args.feb, "stop-reset", settle_us=args.rc_settle_us),
    ]
    if args.post_stop_reset_ms > 0:
        time.sleep(args.post_stop_reset_ms / 1000.0)
    return log


def configure_asic(args: argparse.Namespace, asic: int, words: list[int]) -> dict[str, Any]:
    write_cfg_words(args.sc_tool, args.link, words)
    sc_write(args.sc_tool, args.link, MUTRIG_CFG_BASE_WORD + MUTRIG_CFG_OFFSET, [args.scratch_offset])
    opcode = ((CMD_MUTRIG_ASIC_CFG & 0xFFF) << 20) | ((asic & 0xF) << 16) | MUTRIG_CFG_WORDS
    sc_write(args.sc_tool, args.link, MUTRIG_CFG_BASE_WORD + MUTRIG_CFG_OPCODE_STATUS, [opcode])
    final_status, samples = poll_idle(args.sc_tool, args.link, args.timeout_s)
    time.sleep(args.post_config_ms / 1000.0)
    return {
        "asic": asic,
        "scratch_base_word": SCRATCH_BASE_WORD,
        "scratch_offset": args.scratch_offset,
        "opcode": opcode,
        "word_count": len(words),
        "first_words": words[:4],
        "last_words": words[-4:],
        "final_status": final_status,
        "poll_samples": samples[:32],
        "poll_sample_count": len(samples),
        "pass": final_status == 0,
    }


def run_config_sequence(args: argparse.Namespace) -> list[dict[str, Any]]:
    if args.configure_asics is None:
        return []
    param_info = extract_param_info(args.bsp)
    smb3 = load_mutrigs(args.smb3_xml)
    smb5 = load_mutrigs(args.smb5_xml)
    rows = []
    for asic in args.configure_asics:
        local = asic % 4
        mutrigs = smb3 if asic < 4 else smb5
        if local not in mutrigs:
            raise RuntimeError(f"XML for ASIC {asic} missing local mutrig index {local}")
        mutrig = apply_channel_overrides(
            mutrigs[local],
            channel_enable_mask=args.channel_enable_mask,
            tdctest_channel_mask=args.tdctest_channel_mask,
        )
        words = pack_words(mutrig, param_info)
        rows.append(configure_asic(args, asic, words))
    return rows


def window_delta(before: dict[str, Any], after: dict[str, Any]) -> dict[str, Any]:
    source_rows = []
    before_mux = {row["idx"]: row for row in before["source_mux"]}
    for row in after["source_mux"]:
        old = before_mux[row["idx"]]
        source_rows.append(
            {
                "lane": row["idx"],
                "real_delta": counter_delta(old["real_beats"], row["real_beats"]),
                "emu_delta": counter_delta(old["emu_beats"], row["emu_beats"]),
                "selected_delta": counter_delta(old["selected_beats"], row["selected_beats"]),
                "real_error": row["status"]["real_error"],
                "last_data": row["last_selected"]["data"],
                "link_state": after["lvds"]["lanes"][row["idx"]]["link_state"],
            }
        )

    frame_rows = []
    for old, row in zip(before["frame_rcv"], after["frame_rcv"]):
        frame_rows.append(
            {
                "lane": row["lane"],
                "frame_delta": counter_delta(old["open_frame_count"], row["open_frame_count"]),
                "crc_delta": counter_delta(old["crc_err"], row["crc_err"]),
                "status_control": row["status_control"],
            }
        )
    return {"source_mux": source_rows, "frame_rcv": frame_rows}


def classify(snapshot: dict[str, Any], delta: dict[str, Any]) -> str:
    frame_lanes = [row for row in delta["frame_rcv"] if row["frame_delta"] > 0]
    if frame_lanes:
        return "frames_seen"
    states = {lane["link_state"] for lane in snapshot["lvds"]["lanes"][:8]}
    if "aligned_idle" in states:
        return "aligned_idle_no_frames"
    if states == {"loss_sync_pattern"} or states == {"fatal_training"}:
        return "all_lanes_untrained"
    return "mixed_untrained_no_frames"


def write_report(path: Path, timestamp: str, args: argparse.Namespace, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    final = payload["snapshots"][-1]["snapshot"]
    delta = payload["window_delta"]
    result = payload["classification"]
    lines = [
        "# Phase 5 Real MuTRiG Link Debug Report",
        "",
        f"- Timestamp: `{timestamp}`",
        f"- SC link: `{args.link}`",
        f"- LVDS reset requested: `{'yes' if args.lvds_reset else 'no'}`",
        f"- Pre-config run-control reset/stop-reset: `{'no' if args.skip_pre_config_stop_reset else 'yes'}`",
        f"- Configured ASICs: `{args.configure_asics if args.configure_asics is not None else 'none'}`",
        f"- Channel enable override: `{f'0x{args.channel_enable_mask:08X}' if args.channel_enable_mask is not None else 'none'}`",
        f"- TDC-test channel override: `{f'0x{args.tdctest_channel_mask:08X}' if args.tdctest_channel_mask is not None else 'none'}`",
        f"- Window: `{args.window_ms}` ms",
        f"- Classification: `{result}`",
        "",
        "## Final LVDS Snapshot",
        "",
        "| Lane | Mode | Go | Hold | ResetReq | Error Counter | DPA Unlocks | Real Err | Last Data | State |",
        "|---:|---|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    mux_by_lane = {row["idx"]: row for row in final["source_mux"]}
    for lane in final["lvds"]["lanes"]:
        if lane["lane"] >= 8:
            continue
        mux = mux_by_lane[lane["lane"]]
        mode = "adaptive" if lane["mode_adaptive"] else "bit_slip"
        dpa = lane["dpa_unlocks"]
        lines.append(
            f"| {lane['lane']} | `{mode}` | {lane['lane_go']} | {lane['dpa_hold']} | {lane['soft_reset_req']} | "
            f"`{fmt_hex(lane['error_counter'])}` | `{dpa if dpa is not None else 'n/a'}` | "
            f"`{mux['status']['real_error']}` | `{fmt_hex(mux['last_selected']['data'], 3)}` | `{lane['link_state']}` |"
        )

    lines.extend(
        [
            "",
            "## Window Delta",
            "",
            "| Lane | Real Beats | Selected Beats | Frame Delta | CRC Delta | Last Data | Link State |",
            "|---:|---:|---:|---:|---:|---:|---|",
        ]
    )
    frame_by_lane = {row["lane"]: row for row in delta["frame_rcv"]}
    for row in delta["source_mux"]:
        if row["lane"] >= 8:
            continue
        frame = frame_by_lane[row["lane"]]
        lines.append(
            f"| {row['lane']} | {row['real_delta']} | {row['selected_delta']} | "
            f"{frame['frame_delta']} | {frame['crc_delta']} | `{fmt_hex(row['last_data'], 3)}` | `{row['link_state']}` |"
        )

    if payload["config_rows"]:
        if payload.get("pre_config_run_control"):
            lines.extend(
                [
                    "",
                    "## Pre-Config Run-Control",
                    "",
                ]
            )
            for entry in payload["pre_config_run_control"]:
                lines.append(f"```text\n{entry.strip()}\n```")
            lines.append("")
        lines.extend(
            [
                "",
                "## Configuration Commands",
                "",
                "| ASIC | Opcode | Words | Status | Polls | Result |",
                "|---:|---:|---:|---:|---:|---|",
            ]
        )
        for row in payload["config_rows"]:
            lines.append(
                f"| {row['asic']} | `{fmt_hex(row['opcode'])}` | {row['word_count']} | "
                f"`{fmt_hex(row['final_status'])}` | {row['poll_sample_count']} | `{'PASS' if row['pass'] else 'FAIL'}` |"
            )

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Debug real MuTRiG LVDS/source-mux/frame-deassembly boundary.")
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--rc-tool", type=Path, default=default_rc_tool())
    parser.add_argument("--device", default="/dev/mudaq0")
    parser.add_argument("--feb", type=int, default=7)
    parser.add_argument("--rc-settle-us", type=int, default=5000)
    parser.add_argument("--post-stop-reset-ms", type=int, default=50)
    parser.add_argument("--skip-pre-config-stop-reset", action="store_true")
    parser.add_argument("--lvds-reset", action="store_true")
    parser.add_argument("--lvds-reset-ms", type=int, default=20)
    parser.add_argument("--mode-mask", type=parse_mask, default=LVDS_LANE_MASK)
    parser.add_argument("--lane-mask", type=parse_mask, default=LVDS_LANE_MASK)
    parser.add_argument("--read-dpa-unlocks", action="store_true")
    parser.add_argument("--select-real", action="store_true", default=True)
    parser.add_argument("--window-ms", type=int, default=1000)
    parser.add_argument("--configure-asics", type=parse_asic_list, default=None)
    parser.add_argument(
        "--channel-enable-mask",
        type=parse_channel_mask,
        default=None,
        help="Optional 32-bit channel mask override; selected channels get XML mask=0, others mask=1.",
    )
    parser.add_argument(
        "--tdctest-channel-mask",
        type=parse_channel_mask,
        default=None,
        help="Optional 32-bit TDC-test override; selected channels get tdctest_n=0, others tdctest_n=1.",
    )
    parser.add_argument("--timeout-s", type=float, default=5.0)
    parser.add_argument("--post-config-ms", type=int, default=100)
    parser.add_argument("--scratch-offset", type=int, default=0)
    parser.add_argument(
        "--bsp",
        type=Path,
        default=REPO_ROOT / "toolkits" / "fe_scifi" / "system_console" / "lib" / "mutrig_controller_bsp.tcl",
    )
    parser.add_argument(
        "--smb3-xml",
        type=Path,
        default=REPO_ROOT / "board_test_system" / "trash_bin" / "good_ribbon_0" / "config_smb3_tdc.txt",
    )
    parser.add_argument(
        "--smb5-xml",
        type=Path,
        default=REPO_ROOT / "board_test_system" / "trash_bin" / "good_ribbon_0" / "config_smb5_tdc.txt",
    )
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--json-output", type=Path, default=None)
    args = parser.parse_args()

    timestamp = dt.datetime.now().isoformat(timespec="seconds")
    output = args.output or default_output()
    json_output = args.json_output or output.with_suffix(".json")

    snapshots: list[dict[str, Any]] = []
    snapshots.append({"label": "initial", "snapshot": read_boundary_snapshot(args.sc_tool, args.link, read_dpa_unlocks=args.read_dpa_unlocks)})

    reset_actions: list[dict[str, int]] = []
    if args.lvds_reset:
        reset_actions = reset_lvds(args)
        snapshots.append({"label": "after_lvds_reset", "snapshot": read_boundary_snapshot(args.sc_tool, args.link, read_dpa_unlocks=args.read_dpa_unlocks)})

    pre_config_run_control = prepare_run_control_for_spi(args)
    config_rows = run_config_sequence(args)
    if config_rows:
        snapshots.append({"label": "after_config", "snapshot": read_boundary_snapshot(args.sc_tool, args.link, read_dpa_unlocks=args.read_dpa_unlocks)})

    if args.select_real:
        select_lane_sources(args.sc_tool, args.link, 0x00, clear_counters=True)

    before_window = read_boundary_snapshot(args.sc_tool, args.link, read_dpa_unlocks=args.read_dpa_unlocks)
    time.sleep(args.window_ms / 1000.0)
    after_window = read_boundary_snapshot(args.sc_tool, args.link, read_dpa_unlocks=args.read_dpa_unlocks)
    delta = window_delta(before_window, after_window)
    snapshots.append({"label": "after_window", "snapshot": after_window})

    payload = {
        "timestamp": timestamp,
        "args": {
            "link": args.link,
            "device": args.device,
            "feb": args.feb,
            "skip_pre_config_stop_reset": args.skip_pre_config_stop_reset,
            "lvds_reset": args.lvds_reset,
            "mode_mask": args.mode_mask,
            "lane_mask": args.lane_mask,
            "configure_asics": args.configure_asics,
            "channel_enable_mask": args.channel_enable_mask,
            "tdctest_channel_mask": args.tdctest_channel_mask,
            "window_ms": args.window_ms,
            "scratch_offset": args.scratch_offset,
        },
        "reset_actions": reset_actions,
        "pre_config_run_control": pre_config_run_control,
        "config_rows": config_rows,
        "snapshots": snapshots,
        "window_delta": delta,
        "classification": classify(after_window, delta),
    }

    write_report(output, timestamp, args, payload)
    json_output.parent.mkdir(parents=True, exist_ok=True)
    json_output.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"classification={payload['classification']}")
    print(f"report={output}")
    print(f"json={json_output}")
    return 0 if payload["classification"] == "frames_seen" else 1


if __name__ == "__main__":
    raise SystemExit(main())
