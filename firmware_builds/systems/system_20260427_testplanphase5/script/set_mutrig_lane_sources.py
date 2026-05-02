#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import _default_sc_tool  # noqa: E402


SOURCE_MUX_BASE_WORD = 0x08890
SOURCE_MUX_STRIDE_WORD = 0x10
SOURCE_MUX_UID = 0x4D4C534D
SOURCE_MUX_REG_UID = 0
SOURCE_MUX_REG_META = 1
SOURCE_MUX_REG_CONTROL = 2
SOURCE_MUX_REG_STATUS = 3
SOURCE_MUX_REG_REAL_BEATS = 4
SOURCE_MUX_REG_EMU_BEATS = 5
SOURCE_MUX_REG_SELECTED_BEATS = 6
SOURCE_MUX_REG_SWITCH_COUNT = 7
SOURCE_MUX_REG_LAST_SELECTED = 8
SOURCE_MUX_REG_FIFO_STATUS = 9
SOURCE_MUX_REG_REAL_DROPS = 10
SOURCE_MUX_REG_EMU_DROPS = 11
SOURCE_MUX_REG_REAL_SELECTED = 12
SOURCE_MUX_REG_EMU_SELECTED = 13

CONTROL_SELECT_EMULATOR = 0x1
CONTROL_CLEAR_COUNTERS = 0x2
CONTROL_MIXED_RR = 0x4

MODE_TO_CONTROL = {
    "real": 0,
    "emu": CONTROL_SELECT_EMULATOR,
    "emulator": CONTROL_SELECT_EMULATOR,
    "mix": CONTROL_MIXED_RR,
    "mixed": CONTROL_MIXED_RR,
    "mixed_rr": CONTROL_MIXED_RR,
}


def fmt_hex(value: int, width: int = 8) -> str:
    return f"0x{value & ((1 << (width * 4)) - 1):0{width}X}"


def run_cmd(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(
            f"command failed rc={proc.returncode}: {' '.join(cmd)}\n{proc.stdout}{proc.stderr}"
        )
    return proc.stdout + proc.stderr


def parse_payload(text: str) -> list[int]:
    return [int(match.group(2), 16) for match in re.finditer(r"payload\[(\d+)\]\s*=\s*(0x[0-9A-Fa-f]+)", text)]


def sc_enable_mask_args() -> list[str]:
    value = os.environ.get("BOARD_TEST_SC_ENABLE_MASK", "").strip()
    return ["--enable-mask", value] if value else []


def sc_read(sc_tool: Path, link: int, addr: int, count: int = 1) -> list[int]:
    argv = [str(sc_tool), str(link), "read", f"0x{addr:05X}", str(count), "--quiet"]
    argv.extend(sc_enable_mask_args())
    out = run_cmd(argv)
    words = parse_payload(out)
    if len(words) != count:
        raise RuntimeError(f"SC read 0x{addr:05X} count={count} returned {len(words)} words\n{out}")
    return words


def sc_write(sc_tool: Path, link: int, addr: int, words: list[int]) -> None:
    argv = [str(sc_tool), str(link), "write", f"0x{addr:05X}", *[fmt_hex(word) for word in words], "--quiet"]
    argv.extend(sc_enable_mask_args())
    out = run_cmd(argv)
    if re.search(r"rsp\s*:\s*(SLVERR|DECERR)", out):
        raise RuntimeError(f"SC write 0x{addr:05X} got bus error\n{out}")


def source_mux_base(lane: int) -> int:
    return SOURCE_MUX_BASE_WORD + lane * SOURCE_MUX_STRIDE_WORD


def mode_from_control(control: int) -> str:
    if control & CONTROL_MIXED_RR:
        return "mix"
    if control & CONTROL_SELECT_EMULATOR:
        return "emulator"
    return "real"


def parse_mode(text: str) -> str:
    key = text.strip().lower()
    if key == "status":
        return "status"
    if key not in MODE_TO_CONTROL:
        raise argparse.ArgumentTypeError("mode must be one of real, emulator, emu, mix, mixed, mixed_rr")
    return "emulator" if key == "emu" else ("mix" if key in {"mixed", "mixed_rr"} else key)


def parse_modes(text: str) -> list[str]:
    values = [parse_mode(item) for item in re.split(r"[,\\s]+", text.strip()) if item]
    if len(values) != 8:
        raise argparse.ArgumentTypeError("--modes must contain exactly 8 comma- or space-separated modes")
    if any(value == "status" for value in values):
        raise argparse.ArgumentTypeError("--modes entries must be real, emulator, or mix")
    return values


def parse_lane_mode(text: str) -> tuple[int, str]:
    if "=" not in text:
        raise argparse.ArgumentTypeError("--lane-mode expects LANE=MODE")
    lane_text, mode_text = text.split("=", 1)
    lane = int(lane_text, 0)
    if lane < 0 or lane > 7:
        raise argparse.ArgumentTypeError("lane must be in range 0..7")
    mode = parse_mode(mode_text)
    if mode == "status":
        raise argparse.ArgumentTypeError("lane mode must be real, emulator, or mix")
    return lane, mode


def decode_status(word: int) -> dict[str, int]:
    return {
        "raw": word,
        "select_emulator": word & 0x1,
        "real_valid": (word >> 1) & 0x1,
        "emu_valid": (word >> 2) & 0x1,
        "selected_valid": (word >> 3) & 0x1,
        "selected_channel": (word >> 4) & 0xF,
        "selected_error": (word >> 8) & 0x7,
        "real_channel": (word >> 11) & 0xF,
        "real_error": (word >> 15) & 0x7,
        "emu_channel": (word >> 18) & 0xF,
        "emu_error": (word >> 22) & 0x7,
        "both_valid": (word >> 25) & 0x1,
        "mixed_rr": (word >> 26) & 0x1,
        "real_fifo_full": (word >> 27) & 0x1,
        "emu_fifo_full": (word >> 28) & 0x1,
        "real_fifo_has_data": (word >> 29) & 0x1,
        "emu_fifo_has_data": (word >> 30) & 0x1,
        "rr_next_emulator": (word >> 31) & 0x1,
    }


def decode_last_selected(word: int) -> dict[str, int]:
    return {
        "raw": word,
        "data": word & 0x1FF,
        "channel": (word >> 9) & 0xF,
        "error": (word >> 13) & 0x7,
        "source_emulator": (word >> 16) & 0x1,
    }


def decode_fifo_status(word: int) -> dict[str, int]:
    return {
        "raw": word,
        "real_level": word & 0xFF,
        "emu_level": (word >> 8) & 0xFF,
        "real_full": (word >> 16) & 0x1,
        "emu_full": (word >> 17) & 0x1,
        "real_has_data": (word >> 18) & 0x1,
        "emu_has_data": (word >> 19) & 0x1,
        "rr_next_emulator": (word >> 20) & 0x1,
    }


def read_lane(sc_tool: Path, link: int, lane: int) -> dict[str, Any]:
    base = source_mux_base(lane)
    words = sc_read(sc_tool, link, base, SOURCE_MUX_REG_EMU_SELECTED + 1)
    control = words[SOURCE_MUX_REG_CONTROL]
    return {
        "lane": lane,
        "base": base,
        "uid": words[SOURCE_MUX_REG_UID],
        "meta": words[SOURCE_MUX_REG_META],
        "control": control,
        "mode": mode_from_control(control),
        "status": decode_status(words[SOURCE_MUX_REG_STATUS]),
        "real_beats": words[SOURCE_MUX_REG_REAL_BEATS],
        "emu_beats": words[SOURCE_MUX_REG_EMU_BEATS],
        "selected_beats": words[SOURCE_MUX_REG_SELECTED_BEATS],
        "switch_count": words[SOURCE_MUX_REG_SWITCH_COUNT],
        "last_selected": decode_last_selected(words[SOURCE_MUX_REG_LAST_SELECTED]),
        "fifo_status": decode_fifo_status(words[SOURCE_MUX_REG_FIFO_STATUS]),
        "real_drops": words[SOURCE_MUX_REG_REAL_DROPS],
        "emu_drops": words[SOURCE_MUX_REG_EMU_DROPS],
        "real_selected": words[SOURCE_MUX_REG_REAL_SELECTED],
        "emu_selected": words[SOURCE_MUX_REG_EMU_SELECTED],
    }


def read_all_lanes(sc_tool: Path, link: int) -> list[dict[str, Any]]:
    return [read_lane(sc_tool, link, lane) for lane in range(8)]


def write_lane_mode(sc_tool: Path, link: int, lane: int, mode: str, clear_counters: bool) -> None:
    control = MODE_TO_CONTROL[mode]
    if clear_counters:
        control |= CONTROL_CLEAR_COUNTERS
    sc_write(sc_tool, link, source_mux_base(lane) + SOURCE_MUX_REG_CONTROL, [control])


def target_modes(args: argparse.Namespace, current_rows: list[dict[str, Any]]) -> list[str] | None:
    modes: list[str] | None
    if args.modes is not None:
        modes = args.modes.copy()
    elif args.mode == "status":
        modes = [row["mode"] for row in current_rows] if args.lane_mode else None
    else:
        modes = [args.mode] * 8

    if args.lane_mode:
        if modes is None:
            modes = [row["mode"] for row in current_rows]
        for lane, mode in args.lane_mode:
            modes[lane] = mode

    return modes


def printable_row(row: dict[str, Any]) -> dict[str, Any]:
    fifo = row["fifo_status"]
    last = row["last_selected"]
    return {
        "lane": row["lane"],
        "base": fmt_hex(row["base"], 5),
        "uid": fmt_hex(row["uid"]),
        "mode": row["mode"],
        "control": fmt_hex(row["control"]),
        "real_beats": row["real_beats"],
        "emu_beats": row["emu_beats"],
        "selected_beats": row["selected_beats"],
        "real_selected": row["real_selected"],
        "emu_selected": row["emu_selected"],
        "real_drops": row["real_drops"],
        "emu_drops": row["emu_drops"],
        "fifo": f"{fifo['real_level']}/{fifo['emu_level']}",
        "last": f"{'emu' if last['source_emulator'] else 'real'}:{last['channel']}:{fmt_hex(last['data'], 3)}",
    }


def print_table(rows: list[dict[str, Any]]) -> None:
    print("| Lane | Base | UID | Mode | Ctrl | Real In | Emu In | Out | Real Out | Emu Out | Drop R/E | FIFO R/E | Last |")
    print("|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---|")
    for row in rows:
        item = printable_row(row)
        print(
            f"| {item['lane']} | `{item['base']}` | `{item['uid']}` | {item['mode']} | `{item['control']}` | "
            f"{item['real_beats']} | {item['emu_beats']} | {item['selected_beats']} | "
            f"{item['real_selected']} | {item['emu_selected']} | {item['real_drops']}/{item['emu_drops']} | "
            f"{item['fifo']} | `{item['last']}` |"
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Configure per-lane MuTRiG source selection: real, emulator, or mixed round-robin."
    )
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument(
        "--mode",
        type=parse_mode,
        choices=("status", "real", "emulator", "mix"),
        default="status",
        help="Apply one mode to all lanes. status only reads unless --lane-mode is used.",
    )
    parser.add_argument("--modes", type=parse_modes, help="Exactly 8 per-lane modes, for example real,mix,emulator,real,real,real,real,real.")
    parser.add_argument("--lane-mode", type=parse_lane_mode, action="append", default=[], help="Override one lane, for example --lane-mode 0=mix.")
    parser.add_argument("--clear-counters", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    before = read_all_lanes(args.sc_tool, args.link)
    modes = target_modes(args, before)

    if modes is not None:
        for lane, mode in enumerate(modes):
            write_lane_mode(args.sc_tool, args.link, lane, mode, args.clear_counters)

    rows = read_all_lanes(args.sc_tool, args.link)
    failures = []
    for row in rows:
        if row["uid"] != SOURCE_MUX_UID:
            failures.append(f"lane {row['lane']} UID mismatch: got {fmt_hex(row['uid'])}, expected {fmt_hex(SOURCE_MUX_UID)}")
        if modes is not None and row["mode"] != modes[row["lane"]]:
            failures.append(f"lane {row['lane']} mode mismatch: got {row['mode']}, expected {modes[row['lane']]}")

    payload = {
        "requested_modes": modes,
        "clear_counters": args.clear_counters,
        "rows": [printable_row(row) for row in rows],
        "failures": failures,
    }

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        if modes is not None:
            print("requested modes: " + ", ".join(f"{idx}:{mode}" for idx, mode in enumerate(modes)))
        print_table(rows)
        print(f"SUMMARY pass={len(rows) - len(failures)} fail={len(failures)}")
        for failure in failures:
            print(f"FAIL {failure}")

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
