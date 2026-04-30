#!/usr/bin/env python3
"""Decode a Phase-6 SWB DMA ``memory_content.txt`` dump.

The parser is intentionally format-tolerant. The active SWB diagnostic writes a
flat 32-bit buffer, while captures may include MIDAS wrapper words around FEB
frames. This script scans for FEB/SWB frame headers, trailers, subheaders, hit
words, timestamp deltas, and frame-counter gaps without depending on pandas or
the online build tree.
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from dataclasses import dataclass
from pathlib import Path
from typing import Any


PADDING_WORDS = {0x00000000, 0xAFFEAFFE, 0xFFFFFFFF}
TRAILER_WORDS = {0x0000009C, 0xFC00009C, 0xFC00019C}


@dataclass(frozen=True)
class MemoryWord:
    index: int
    word: int


def hex32(value: int) -> str:
    return f"0x{value & 0xFFFFFFFF:08X}"


def hist(values: list[int], *, limit: int = 64) -> dict[str, int]:
    counts = Counter(values)
    items = sorted(counts.items(), key=lambda item: (-item[1], item[0]))
    return {str(key): count for key, count in items[:limit]}


def parse_memory_words(path: Path) -> list[MemoryWord]:
    words: list[MemoryWord] = []
    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for lineno, line in enumerate(handle, start=1):
            parts = line.strip().split()
            if not parts:
                continue
            try:
                if len(parts) >= 2:
                    index = int(parts[0], 0)
                    word = int(parts[1], 16)
                else:
                    index = len(words)
                    word = int(parts[0], 16)
            except ValueError:
                continue
            words.append(MemoryWord(index=index, word=word & 0xFFFFFFFF))
    return words


def is_padding(word: int) -> bool:
    return word in PADDING_WORDS


def is_frame_header(word: int) -> bool:
    return (word & 0xFF) == 0xBC and ((word >> 24) & 0xFF) == 0xE8


def is_frame_trailer(word: int) -> bool:
    if word in TRAILER_WORDS:
        return True
    return (word & 0xFF) == 0x9C and ((word >> 24) & 0xFF) in (0x00, 0xFC)


def is_old_type2_subheader(word: int) -> bool:
    return not is_frame_trailer(word) and ((word >> 21) & 0x7F) == 0x7F


def is_swb_subheader(word: int) -> bool:
    return not is_frame_trailer(word) and ((word >> 26) & 0x3F) == 0x3F and (word & 0xFFFF) == 0


def decode_subheader(word: int) -> dict[str, Any] | None:
    if is_old_type2_subheader(word):
        return {
            "format": "feb_type2",
            "id": ((word >> 28) << 5) | ((word >> 16) & 0x1F),
            "hit_count_field": (word >> 8) & 0xFF,
            "timestamp_bucket": (word >> 24) & 0xFF,
        }
    if is_swb_subheader(word):
        return {
            "format": "swb_link32",
            "id": (word >> 16) & 0x7F,
            "hit_count_field": None,
            "timestamp_bucket": None,
        }
    return None


def decode_timestamp(frame_words: list[MemoryWord]) -> int | None:
    if len(frame_words) < 3:
        return None
    return ((frame_words[1].word & 0xFFFFFFFF) << 5) | ((frame_words[2].word >> 27) & 0x1F)


def decode_frame(frame_words: list[MemoryWord]) -> dict[str, Any]:
    errors: list[str] = []
    if not frame_words:
        return {"errors": ["empty_frame"]}

    header = frame_words[0].word
    trailer = frame_words[-1].word
    if not is_frame_header(header):
        errors.append("missing_header")
    if not is_frame_trailer(trailer):
        errors.append("missing_trailer")
    if len(frame_words) < 4:
        errors.append("too_short")

    timestamp = decode_timestamp(frame_words)
    frame_counter = frame_words[2].word & 0xFFFF if len(frame_words) >= 3 else None
    body = frame_words[3:-1] if is_frame_trailer(trailer) else frame_words[3:]

    subheaders: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    hit_words: list[int] = []
    hits_before_first_subheader = 0
    duplicate_hit_words = 0
    previous_hit_word: int | None = None

    for item in body:
        subheader = decode_subheader(item.word)
        if subheader is not None:
            if current is not None:
                subheaders.append(current)
            current = {
                "index": item.index,
                "word": hex32(item.word),
                "format": subheader["format"],
                "id": subheader["id"],
                "hit_count_field": subheader["hit_count_field"],
                "timestamp_bucket": subheader["timestamp_bucket"],
                "hit_count": 0,
            }
            continue

        if is_padding(item.word):
            continue
        if is_frame_header(item.word) or is_frame_trailer(item.word):
            errors.append(f"unexpected_control_word_at_{item.index}")
            continue

        if previous_hit_word == item.word:
            duplicate_hit_words += 1
        previous_hit_word = item.word
        hit_words.append(item.word)
        if current is None:
            hits_before_first_subheader += 1
        else:
            current["hit_count"] += 1

    if current is not None:
        subheaders.append(current)

    declared_mismatches = [
        {
            "index": item["index"],
            "id": item["id"],
            "declared": item["hit_count_field"],
            "observed": item["hit_count"],
        }
        for item in subheaders
        if item["hit_count_field"] is not None and item["hit_count_field"] != item["hit_count"]
    ]
    if declared_mismatches:
        errors.append("subheader_declared_hit_count_mismatch")
    if hit_words and not subheaders:
        errors.append("hits_without_subheaders")
    if hits_before_first_subheader:
        errors.append("hits_before_first_subheader")

    subheader_id_jumps: list[dict[str, int]] = []
    subheader_formats = {item["format"] for item in subheaders}
    modulo = 128 if "swb_link32" in subheader_formats else 256
    for prev, cur in zip(subheaders, subheaders[1:]):
        expected = (int(prev["id"]) + 1) % modulo
        if int(cur["id"]) != expected:
            subheader_id_jumps.append(
                {
                    "prev_index": int(prev["index"]),
                    "prev_id": int(prev["id"]),
                    "cur_index": int(cur["index"]),
                    "cur_id": int(cur["id"]),
                    "expected_id": expected,
                }
            )
    if subheader_id_jumps:
        errors.append("subheader_id_jump")

    return {
        "start_index": frame_words[0].index,
        "end_index": frame_words[-1].index,
        "length_words": len(frame_words),
        "header": hex32(header),
        "trailer": hex32(trailer),
        "feb_id_guess": (header >> 8) & 0xFFFF,
        "timestamp": timestamp,
        "frame_counter": frame_counter,
        "subheader_count": len(subheaders),
        "hit_count": len(hit_words),
        "hits_before_first_subheader": hits_before_first_subheader,
        "duplicate_adjacent_hit_words": duplicate_hit_words,
        "subheader_hit_counts": [int(item["hit_count"]) for item in subheaders],
        "subheader_ids": [int(item["id"]) for item in subheaders[:256]],
        "subheader_formats": sorted(subheader_formats),
        "subheader_id_jumps": subheader_id_jumps[:32],
        "declared_hit_count_mismatches": declared_mismatches[:32],
        "hit_word_top_nibble_hist": hist([(word >> 28) & 0xF for word in hit_words], limit=16),
        "errors": errors,
    }


def scan_frames(words: list[MemoryWord]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    frames: list[dict[str, Any]] = []
    orphan_trailers = 0
    headers = 0
    i = 0
    while i < len(words):
        word = words[i].word
        if is_frame_trailer(word):
            orphan_trailers += 1
            i += 1
            continue
        if not is_frame_header(word):
            i += 1
            continue

        headers += 1
        start = i
        i += 1
        while i < len(words):
            if is_frame_trailer(words[i].word):
                i += 1
                frames.append(decode_frame(words[start:i]))
                break
            if is_frame_header(words[i].word):
                frames.append(decode_frame(words[start:i]))
                break
            i += 1
        else:
            frames.append(decode_frame(words[start:]))

    return frames, {"header_candidates": headers, "orphan_trailers": orphan_trailers}


def delta_values(values: list[int]) -> list[int]:
    return [cur - prev for prev, cur in zip(values, values[1:])]


def counter_deltas(values: list[int], bits: int) -> list[int]:
    modulo = 1 << bits
    return [(cur - prev) % modulo for prev, cur in zip(values, values[1:])]


def classify_summary(summary: dict[str, Any]) -> str:
    checks = summary["checks"]
    if not checks["has_frames"]:
        return "no_frames"
    if checks["malformed_frames"] != 0:
        return "malformed"
    if checks["timestamp_delta_mismatches"] != 0:
        return "timestamp_delta_mismatch"
    if checks["frame_counter_gap_count"] != 0:
        return "frame_counter_gap"
    if checks["hit_count_mismatches"] != 0:
        return "hit_count_mismatch"
    return "pass"


def analyze_memory_file(
    path: Path,
    *,
    expect_ts_delta: int | None = None,
    expect_hits_per_frame: int | None = None,
    max_frame_reports: int = 16,
) -> dict[str, Any]:
    try:
        words = parse_memory_words(path)
    except OSError as exc:
        return {"error": str(exc)}

    frames, scan = scan_frames(words)
    nonzero_words = sum(1 for item in words if item.word != 0)
    nonpadding_words = sum(1 for item in words if not is_padding(item.word))
    trailer_candidates = sum(1 for item in words if is_frame_trailer(item.word))

    timestamps = [int(frame["timestamp"]) for frame in frames if frame["timestamp"] is not None and not frame["errors"]]
    timestamp_deltas = delta_values(timestamps)
    frame_counters = [
        int(frame["frame_counter"]) for frame in frames if frame["frame_counter"] is not None and not frame["errors"]
    ]
    frame_counter_deltas = counter_deltas(frame_counters, 16)
    hit_counts = [int(frame["hit_count"]) for frame in frames if not frame["errors"]]
    subheader_counts = [int(frame["subheader_count"]) for frame in frames if not frame["errors"]]
    subheader_hit_counts = [
        int(count) for frame in frames if not frame["errors"] for count in frame["subheader_hit_counts"]
    ]

    timestamp_delta_mismatches = 0
    if expect_ts_delta is not None:
        timestamp_delta_mismatches = sum(1 for delta in timestamp_deltas if delta != expect_ts_delta)
    hit_count_mismatches = 0
    if expect_hits_per_frame is not None:
        hit_count_mismatches = sum(1 for count in hit_counts if count != expect_hits_per_frame)
    frame_counter_gap_count = sum(1 for delta in frame_counter_deltas if delta != 1)

    malformed = [frame for frame in frames if frame["errors"]]
    first_bad_frames = [
        {
            key: frame[key]
            for key in (
                "start_index",
                "end_index",
                "length_words",
                "header",
                "trailer",
                "timestamp",
                "frame_counter",
                "subheader_count",
                "hit_count",
                "errors",
                "subheader_id_jumps",
                "declared_hit_count_mismatches",
            )
        }
        for frame in malformed[:max_frame_reports]
    ]
    frame_reports = [
        {
            key: frame[key]
            for key in (
                "start_index",
                "end_index",
                "length_words",
                "header",
                "trailer",
                "timestamp",
                "frame_counter",
                "subheader_count",
                "hit_count",
                "subheader_hit_counts",
                "subheader_ids",
                "subheader_formats",
                "hit_word_top_nibble_hist",
                "errors",
            )
        }
        for frame in frames[:max_frame_reports]
    ]

    summary: dict[str, Any] = {
        "format_decode": "phase6_swb_dma_frame_scan_v1",
        "file": str(path),
        "total_words": len(words),
        "nonzero_words": nonzero_words,
        "nonpadding_words": nonpadding_words,
        "first_words": [hex32(item.word) for item in words[:32]],
        "header_candidates": scan["header_candidates"],
        "trailer_candidates": trailer_candidates,
        "orphan_trailers": scan["orphan_trailers"],
        "frames": len(frames),
        "malformed_frames": len(malformed),
        "first_bad_frames": first_bad_frames,
        "frame_reports": frame_reports,
        "timestamp_delta_hist": hist(timestamp_deltas),
        "timestamp_first": timestamps[0] if timestamps else None,
        "timestamp_last": timestamps[-1] if timestamps else None,
        "frame_counter_delta_hist": hist(frame_counter_deltas),
        "frame_counter_first": frame_counters[0] if frame_counters else None,
        "frame_counter_last": frame_counters[-1] if frame_counters else None,
        "hit_count_hist": hist(hit_counts),
        "subheader_count_hist": hist(subheader_counts),
        "subheader_hit_count_hist": hist(subheader_hit_counts),
        "expectations": {
            "expect_ts_delta": expect_ts_delta,
            "expect_hits_per_frame": expect_hits_per_frame,
        },
        "checks": {
            "has_frames": len(frames) > 0,
            "malformed_frames": len(malformed),
            "timestamp_delta_mismatches": timestamp_delta_mismatches,
            "frame_counter_gap_count": frame_counter_gap_count,
            "hit_count_mismatches": hit_count_mismatches,
        },
    }
    summary["classification"] = classify_summary(summary)
    return summary


def render_markdown(summary: dict[str, Any]) -> str:
    lines = [
        "# Phase 6 DMA Memory Decode",
        "",
        f"- File: `{summary.get('file')}`",
        f"- Classification: `{summary.get('classification')}`",
        f"- Words: total `{summary.get('total_words')}`, nonzero `{summary.get('nonzero_words')}`, nonpadding `{summary.get('nonpadding_words')}`",
        f"- Frames: `{summary.get('frames')}`, malformed `{summary.get('malformed_frames')}`, headers `{summary.get('header_candidates')}`, trailers `{summary.get('trailer_candidates')}`",
        f"- Timestamp delta histogram: `{summary.get('timestamp_delta_hist')}`",
        f"- Frame-counter delta histogram: `{summary.get('frame_counter_delta_hist')}`",
        f"- Hit-count histogram: `{summary.get('hit_count_hist')}`",
        f"- Subheader-count histogram: `{summary.get('subheader_count_hist')}`",
        f"- Subheader hit-count histogram: `{summary.get('subheader_hit_count_hist')}`",
        "",
        "## First Frames",
        "",
    ]
    for frame in summary.get("frame_reports", []):
        lines.append(
            f"- `{frame['start_index']}..{frame['end_index']}` "
            f"ts `{frame['timestamp']}` fc `{frame['frame_counter']}` "
            f"subheaders `{frame['subheader_count']}` hits `{frame['hit_count']}` "
            f"errors `{frame['errors']}`"
        )
    if summary.get("first_bad_frames"):
        lines.extend(["", "## First Bad Frames", ""])
        for frame in summary["first_bad_frames"]:
            lines.append(f"- `{frame['start_index']}..{frame['end_index']}` errors `{frame['errors']}`")
    lines.append("")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("memory_file", type=Path)
    parser.add_argument("--json-output", type=Path)
    parser.add_argument("--md-output", type=Path)
    parser.add_argument("--expect-ts-delta", type=int)
    parser.add_argument("--expect-hits-per-frame", type=int)
    parser.add_argument("--max-frame-reports", type=int, default=16)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    summary = analyze_memory_file(
        args.memory_file,
        expect_ts_delta=args.expect_ts_delta,
        expect_hits_per_frame=args.expect_hits_per_frame,
        max_frame_reports=args.max_frame_reports,
    )
    text = json.dumps(summary, indent=2, sort_keys=True) + "\n"
    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(text, encoding="utf-8")
    else:
        print(text, end="")
    if args.md_output:
        args.md_output.parent.mkdir(parents=True, exist_ok=True)
        args.md_output.write_text(render_markdown(summary), encoding="utf-8")
    return 0 if summary.get("classification") == "pass" else 1


if __name__ == "__main__":
    raise SystemExit(main())
