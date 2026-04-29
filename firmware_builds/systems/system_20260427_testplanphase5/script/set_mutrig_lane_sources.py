#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from check_ip_metadata import _default_sc_tool
from run_phase4_emulator import (
    SOURCE_MUX_CONTROL_SELECT_EMULATOR,
    SOURCE_MUX_UID,
    fmt_hex,
    read_lane_source_muxes,
    select_lane_sources,
)


def parse_mask(text: str) -> int:
    value = int(text, 0)
    if value < 0 or value > 0xFF:
        raise argparse.ArgumentTypeError("mask must be in range 0x00..0xff")
    return value


def current_mask(rows: list[dict[str, Any]]) -> int:
    mask = 0
    for row in rows:
        if row["control"] & SOURCE_MUX_CONTROL_SELECT_EMULATOR:
            mask |= 1 << row["idx"]
    return mask


def requested_mask(args: argparse.Namespace, current_rows: list[dict[str, Any]]) -> int | None:
    if args.mode == "status":
        return current_mask(current_rows) if args.clear_counters else None
    if args.mode == "real":
        return 0x00
    if args.mode == "emulator":
        return 0xFF
    if args.mask is None:
        raise ValueError("--mode mixed requires --mask; bit=1 selects emulator, bit=0 selects real")
    return args.mask


def row_to_printable(row: dict[str, Any]) -> dict[str, Any]:
    source = "emulator" if (row["control"] & SOURCE_MUX_CONTROL_SELECT_EMULATOR) else "real"
    return {
        "lane": row["idx"],
        "base": fmt_hex(row["base"]),
        "uid": fmt_hex(row["uid"]),
        "source": source,
        "status": fmt_hex(row["status"]["raw"]),
        "real_beats": row["real_beats"],
        "emu_beats": row["emu_beats"],
        "selected_beats": row["selected_beats"],
        "switch_count": row["switch_count"],
        "last_selected": fmt_hex(row["last_selected"]["raw"]),
    }


def print_table(rows: list[dict[str, Any]]) -> None:
    print("| Lane | Base | UID | Source | Status | Real Beats | Emu Beats | Selected Beats | Switches | Last |")
    print("|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|")
    for row in rows:
        item = row_to_printable(row)
        print(
            f"| {item['lane']} | `{item['base']}` | `{item['uid']}` | `{item['source']}` | "
            f"`{item['status']}` | {item['real_beats']} | {item['emu_beats']} | "
            f"{item['selected_beats']} | {item['switch_count']} | `{item['last_selected']}` |"
        )


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Select real MuTRiG, emulator, or mixed per-lane sources through mutrig_lane_source_mux CSRs."
    )
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument(
        "--mode",
        choices=("status", "real", "emulator", "mixed"),
        default="status",
        help="status only reads; real selects all real LVDS; emulator selects all emulator; mixed uses --mask.",
    )
    parser.add_argument(
        "--mask",
        type=parse_mask,
        help="Mixed source mask. Bit N = 1 selects emulator for lane N; bit N = 0 selects real MuTRiG.",
    )
    parser.add_argument("--clear-counters", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    before = read_lane_source_muxes(args.sc_tool, args.link)
    mask = requested_mask(args, before)
    rows = before if mask is None else select_lane_sources(args.sc_tool, args.link, mask, args.clear_counters)

    failures = []
    for row in rows:
        if row["uid"] != SOURCE_MUX_UID:
            failures.append(
                f"lane {row['idx']} UID mismatch: got {fmt_hex(row['uid'])}, expected {fmt_hex(SOURCE_MUX_UID)}"
            )
        if mask is not None:
            expected = 1 if (mask & (1 << row["idx"])) else 0
            actual = 1 if (row["control"] & SOURCE_MUX_CONTROL_SELECT_EMULATOR) else 0
            if actual != expected:
                failures.append(f"lane {row['idx']} source mismatch: got {actual}, expected {expected}")

    payload = {
        "mode": args.mode,
        "requested_mask": None if mask is None else f"0x{mask:02X}",
        "clear_counters": args.clear_counters,
        "rows": [row_to_printable(row) for row in rows],
        "failures": failures,
    }

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    else:
        if mask is not None:
            print(f"requested source mask: 0x{mask:02X} (bit=1 emulator, bit=0 real)")
        print_table(rows)
        print(f"SUMMARY pass={len(rows) - len(failures)} fail={len(failures)}")
        for failure in failures:
            print(f"FAIL {failure}")

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
