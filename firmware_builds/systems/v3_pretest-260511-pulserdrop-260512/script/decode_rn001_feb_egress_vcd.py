#!/usr/bin/env python3
"""Decode RN.BASIC.001 FEB egress SignalTap VCD exports."""

from __future__ import annotations

import argparse
import csv
import json
import re
from pathlib import Path
from typing import Any


INDEX_RE = re.compile(r"^(?P<base>.+)\[(?P<index>\d+)\]$")
K285 = 0xBC
K284 = 0x9C
K237 = 0xF7


def parse_vcd(path: Path) -> tuple[list[dict[str, Any]], dict[str, str]]:
    scopes: list[str] = []
    names_by_id: dict[str, str] = {}
    current: dict[str, str] = {}
    samples: list[dict[str, Any]] = []
    now: int | None = None

    def snapshot() -> None:
        if now is None:
            return
        samples.append({"time_ps": now, "values": dict(current)})

    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for raw in fh:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("$scope"):
                parts = line.split()
                if len(parts) >= 3:
                    scopes.append(parts[2])
                continue
            if line.startswith("$upscope"):
                if scopes:
                    scopes.pop()
                continue
            if line.startswith("$var"):
                parts = line.split()
                if len(parts) >= 6:
                    ident = parts[3]
                    ref = " ".join(parts[4:-1])
                    name = ".".join([*scopes, ref]) if scopes else ref
                    names_by_id[ident] = name
                    current.setdefault(ident, "x")
                continue
            if line.startswith("#"):
                snapshot()
                now = int(line[1:])
                continue
            if line.startswith("$"):
                continue
            if line[0] in "01xXzZ":
                current[line[1:].strip()] = line[0].lower()
                continue
            if line[0] in "bB":
                fields = line.split()
                if len(fields) == 2:
                    current[fields[1]] = fields[0][1:].lower()
    snapshot()
    return samples, names_by_id


def find_signal(names_by_id: dict[str, str], suffix: str) -> str:
    matches = [ident for ident, name in names_by_id.items() if name.endswith(suffix)]
    if len(matches) != 1:
        raise RuntimeError(f"expected one signal ending {suffix!r}, found {len(matches)}")
    return matches[0]


def find_bus(names_by_id: dict[str, str], suffix: str, width: int) -> dict[int, str]:
    bus: dict[int, str] = {}
    for ident, name in names_by_id.items():
        match = INDEX_RE.match(name)
        if not match:
            continue
        if match.group("base").endswith(suffix):
            bus[int(match.group("index"))] = ident
    missing = [idx for idx in range(width) if idx not in bus]
    if missing:
        raise RuntimeError(f"bus {suffix!r} missing indexes: {missing}")
    return bus


def bus_value(sample: dict[str, str], bus: dict[int, str], width: int) -> int | None:
    value = 0
    for idx in range(width):
        bit = sample.get(bus[idx], "x")
        if bit not in {"0", "1"}:
            return None
        if bit == "1":
            value |= 1 << idx
    return value


def decode_words(
    samples: list[dict[str, Any]],
    names_by_id: dict[str, str],
    clock_phase: str,
) -> list[dict[str, Any]]:
    clock_id = find_signal(names_by_id, "i_clk_156")
    valid_id = find_signal(names_by_id, "i_upload_data1_valid")
    data_bus = find_bus(names_by_id, "i_upload_data1_data", 36)
    words: list[dict[str, Any]] = []
    for sample in samples:
        values = sample["values"]
        if clock_phase in {"0", "1"} and values.get(clock_id, "x") != clock_phase:
            continue
        if values.get(valid_id, "0") != "1":
            continue
        raw = bus_value(values, data_bus, 36)
        if raw is None:
            continue
        data = raw & 0xFFFFFFFF
        datak = (raw >> 32) & 0xF
        words.append(
            {
                "time_ps": sample["time_ps"],
                "data": data,
                "datak": datak,
                "low_byte": data & 0xFF,
            }
        )
    return words


def decode_frames(words: list[dict[str, Any]]) -> list[dict[str, Any]]:
    frames: list[dict[str, Any]] = []
    active: list[dict[str, Any]] | None = None
    start_index = 0
    for index, word in enumerate(words):
        is_k = bool(word["datak"] & 0x1)
        if is_k and word["low_byte"] == K285:
            if active:
                frames.append(frame_summary(start_index, active, closed=False))
            active = [word]
            start_index = index
            continue
        if active is None:
            continue
        active.append(word)
        if is_k and word["low_byte"] == K284:
            frames.append(frame_summary(start_index, active, closed=True))
            active = None
    if active:
        frames.append(frame_summary(start_index, active, closed=False))
    return frames


def frame_summary(start_index: int, frame_words: list[dict[str, Any]], closed: bool) -> dict[str, Any]:
    debug0_sub_count = None
    debug0_hit_count = None
    if len(frame_words) > 3:
        word3 = frame_words[3]["data"]
        debug0_sub_count = (word3 >> 16) & 0x7FFF
        debug0_hit_count = word3 & 0xFFFF

    field_index = 0
    subheader_count = 0
    nonempty_subheader_count = 0
    hit_count = 0
    subheaders: list[dict[str, Any]] = []
    ts_high = None
    ts_low = None
    frame_id = None

    for word in frame_words[1:]:
        is_k = bool(word["datak"] & 0x1)
        low_byte = word["low_byte"]
        if is_k and low_byte == K284:
            break
        field_index += 1
        if field_index == 1:
            ts_high = word["data"]
            continue
        if field_index == 2:
            ts_low = (word["data"] >> 16) & 0xFFFF
            frame_id = word["data"] & 0xFFFF
            continue
        if field_index <= 4:
            continue
        if is_k and low_byte == K237:
            this_hit_count = (word["data"] >> 8) & 0xFFFF
            subheaders.append(
                {
                    "word_index_in_frame": len(subheaders),
                    "time_ps": word["time_ps"],
                    "data": f"0x{word['data']:08X}",
                    "shd_ts": (word["data"] >> 24) & 0xFF,
                    "hit_count": this_hit_count,
                }
            )
            subheader_count += 1
            if this_hit_count != 0:
                nonempty_subheader_count += 1
            hit_count += this_hit_count

    return {
        "start_word_index": start_index,
        "start_time_ps": frame_words[0]["time_ps"],
        "word_count": len(frame_words),
        "closed_by_k284": closed,
        "ts_high": ts_high,
        "ts_low": ts_low,
        "frame_id": frame_id,
        "debug0_sub_count": debug0_sub_count,
        "debug0_hit_count": debug0_hit_count,
        "subheader_count": subheader_count,
        "nonempty_subheader_count": nonempty_subheader_count,
        "hit_count": hit_count,
        "first_subheaders": subheaders[:8],
        "first_words": [f"0x{word['data']:08X}" for word in frame_words[:8]],
        "first_datak": [f"0x{word['datak']:X}" for word in frame_words[:8]],
    }


def write_words_csv(path: Path, words: list[dict[str, Any]]) -> None:
    with path.open("w", newline="", encoding="ascii") as fh:
        writer = csv.DictWriter(fh, fieldnames=["idx", "time_ps", "data", "datak", "low_byte"])
        writer.writeheader()
        for idx, word in enumerate(words):
            writer.writerow(
                {
                    "idx": idx,
                    "time_ps": word["time_ps"],
                    "data": f"0x{word['data']:08X}",
                    "datak": f"0x{word['datak']:X}",
                    "low_byte": f"0x{word['low_byte']:02X}",
                }
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vcd", type=Path)
    parser.add_argument(
        "--clock-phase",
        choices=["0", "1", "any"],
        default="1",
        help="sample only this exported i_clk_156 phase; use any to keep every VCD snapshot",
    )
    parser.add_argument("--json-out", type=Path)
    parser.add_argument("--words-csv-out", type=Path)
    args = parser.parse_args()

    samples, names_by_id = parse_vcd(args.vcd)
    words = decode_words(samples, names_by_id, args.clock_phase)
    frames = decode_frames(words)
    k285_count = sum(1 for word in words if (word["datak"] & 0x1) and word["low_byte"] == K285)
    k284_count = sum(1 for word in words if (word["datak"] & 0x1) and word["low_byte"] == K284)
    k237_count = sum(1 for word in words if (word["datak"] & 0x1) and word["low_byte"] == K237)
    closed_frames = [frame for frame in frames if frame["closed_by_k284"]]
    valid_sub_count_frames = [
        frame for frame in closed_frames if frame.get("subheader_count") == 128
    ]
    closed_subheader_counts = [frame["subheader_count"] for frame in closed_frames]
    closed_hit_counts = [frame["hit_count"] for frame in closed_frames]
    result = {
        "vcd": str(args.vcd),
        "clock_phase": args.clock_phase,
        "sample_count": len(samples),
        "valid_word_count": len(words),
        "k285_word_lsb_count": k285_count,
        "k284_word_lsb_count": k284_count,
        "k237_word_lsb_count": k237_count,
        "decoded_frame_count": len(frames),
        "closed_frame_count": len(closed_frames),
        "sub_count_128_closed_frame_count": len(valid_sub_count_frames),
        "all_closed_frames_sub_count_128": all(
            frame.get("subheader_count") == 128 for frame in closed_frames
        ),
        "closed_subheader_count_min": min(closed_subheader_counts) if closed_subheader_counts else None,
        "closed_subheader_count_max": max(closed_subheader_counts) if closed_subheader_counts else None,
        "closed_hit_count_min": min(closed_hit_counts) if closed_hit_counts else None,
        "closed_hit_count_max": max(closed_hit_counts) if closed_hit_counts else None,
        "frames": frames[:16],
    }

    if args.json_out is not None:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(result, indent=2) + "\n", encoding="ascii")
    if args.words_csv_out is not None:
        args.words_csv_out.parent.mkdir(parents=True, exist_ok=True)
        write_words_csv(args.words_csv_out, words)

    print(json.dumps(result, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
