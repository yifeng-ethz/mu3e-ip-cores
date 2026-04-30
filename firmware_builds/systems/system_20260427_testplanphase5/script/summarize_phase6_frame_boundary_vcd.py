#!/usr/bin/env python3
"""Summarize Phase-6 RBCAM/FEB-frame SignalTap VCD exports."""

from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path
from typing import Any


SignalSamples = list[tuple[int, dict[str, str]]]


def label_for_scope(scope: str) -> str | None:
    parts = scope.split("/")
    leaf = (parts[-1] if parts else "").split(":")[-1]
    parent = (parts[-2] if len(parts) >= 2 else "").split(":")[-1]

    hit_stack = re.fullmatch(r"hit_stack_subsystem_(\d+)", leaf)
    if hit_stack:
        return f"hs{hit_stack.group(1)}"

    rbcam = re.fullmatch(r"ring_buffer_cam_(\d+)", leaf)
    stack_parent = re.fullmatch(r"hit_stack_subsystem_(\d+)", parent)
    if rbcam and stack_parent:
        return f"hs{stack_parent.group(1)}.rbcam{rbcam.group(1)}"

    return None


def keep_ref(label: str, ref: str) -> bool:
    if ".rbcam" in label:
        return ref.startswith("aso_hit_type2_")
    if re.fullmatch(r"hs\d+", label):
        return ref.startswith(("hit_type3_", "ring_buffer_cam_"))
    return False


def parse_vcd(path: Path) -> tuple[SignalSamples, Counter[str]]:
    symbol_to_name: dict[str, str] = {}
    label_counts: Counter[str] = Counter()
    state: dict[str, str] = {}
    samples: SignalSamples = []
    cur_time: int | None = None
    time_has_updates = False
    in_defs = True
    scopes: list[str] = []

    def push_sample() -> None:
        nonlocal time_has_updates
        if cur_time is not None and time_has_updates:
            samples.append((cur_time, dict(state)))
            time_has_updates = False

    with path.open("r", encoding="utf-8", errors="replace") as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue

            if in_defs:
                if line.startswith("$scope "):
                    parts = line.split()
                    if len(parts) >= 4:
                        scopes.append(parts[2])
                    continue
                if line == "$upscope $end":
                    if scopes:
                        scopes.pop()
                    continue
                if line.startswith("$var "):
                    parts = line.split()
                    if len(parts) >= 6 and "$end" in parts:
                        end_idx = parts.index("$end")
                        symbol = parts[3]
                        ref = " ".join(parts[4:end_idx]).strip()
                        if ref.startswith("\\"):
                            ref = ref[1:].strip()
                        label = label_for_scope("/".join(scopes))
                        if label is not None and keep_ref(label, ref):
                            symbol_to_name[symbol] = f"{label}.{ref}"
                            label_counts[label] += 1
                    continue
                if line == "$enddefinitions $end":
                    in_defs = False
                continue

            if line.startswith("#"):
                push_sample()
                cur_time = int(line[1:])
                continue

            if line[0] in "01xXzZ" and len(line) >= 2:
                name = symbol_to_name.get(line[1:])
                if name is not None:
                    state[name] = line[0].lower()
                    time_has_updates = True
                continue

            if line[0] in "bB":
                bits, _, symbol = line[1:].partition(" ")
                name = symbol_to_name.get(symbol.strip())
                if name is not None:
                    for idx, bit in enumerate(reversed(bits.lower())):
                        state[f"{name}[{idx}]"] = bit
                    time_has_updates = True

    push_sample()
    return samples, label_counts


def signal_exists(samples: SignalSamples, name: str) -> bool:
    return any(name in snap for _, snap in samples)


def first_high(samples: SignalSamples, name: str) -> int | None:
    for ts, snap in samples:
        if snap.get(name) == "1":
            return ts
    return None


def count_rises(samples: SignalSamples, name: str) -> int:
    prev = "0"
    rises = 0
    for _, snap in samples:
        cur = snap.get(name, prev)
        if prev != "1" and cur == "1":
            rises += 1
        prev = cur
    return rises


def bus_word(snapshot: dict[str, str], prefix: str, base: str, width: int) -> int:
    word = 0
    for idx in range(width):
        if snapshot.get(f"{prefix}.{base}[{idx}]") == "1":
            word |= 1 << idx
    return word


def stream_events(samples: SignalSamples, label: str, stem: str) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    last_key: tuple[int, int, int, int] | None = None
    for ts, snap in samples:
        if snap.get(f"{label}.{stem}_valid") != "1":
            continue
        ready_name = f"{label}.{stem}_ready"
        if signal_exists(samples, ready_name) and snap.get(ready_name) != "1":
            continue
        data = bus_word(snap, label, f"{stem}_data", 36)
        sop = 1 if snap.get(f"{label}.{stem}_startofpacket") == "1" else 0
        eop = 1 if snap.get(f"{label}.{stem}_endofpacket") == "1" else 0
        err_name = f"{label}.{stem}_error"
        err = 1 if signal_exists(samples, err_name) and snap.get(err_name) == "1" else 0
        channel = 0
        if signal_exists(samples, f"{label}.{stem}_channel[0]"):
            channel = bus_word(snap, label, f"{stem}_channel", 4)
        key = (data, sop, eop, err)
        if key == last_key:
            continue
        last_key = key
        events.append(
            {
                "time_ps": ts,
                "data": data,
                "sop": sop,
                "eop": eop,
                "error": err,
                "channel": channel,
                "kind": classify_word(data),
            }
        )
    return events


def classify_word(data: int) -> str:
    top = (data >> 32) & 0xF
    low = data & 0xFF
    if top == 1 and low == 0xBC:
        return "frame_header"
    if top == 1 and low == 0x9C:
        return "frame_trailer"
    if top == 1 and low == 0xF7:
        return "subheader"
    if top == 0:
        return "hit"
    return "other"


def summarize_type2(events: list[dict[str, Any]]) -> dict[str, Any]:
    subheaders: list[dict[str, Any]] = []
    current: dict[str, Any] | None = None
    errors = 0
    hits_before_subheader = 0
    for event in events:
        if event["error"]:
            errors += 1
        if event["kind"] == "subheader":
            if current is not None:
                subheaders.append(current)
            word = int(event["data"])
            current = {
                "time_ps": event["time_ps"],
                "channel": event["channel"],
                "ts_bucket": (word >> 24) & 0xFF,
                "declared_hits": (word >> 8) & 0xFF,
                "observed_hits": 0,
            }
        elif event["kind"] == "hit":
            if current is None:
                hits_before_subheader += 1
            else:
                current["observed_hits"] += 1
    if current is not None:
        subheaders.append(current)

    mismatches = [
        item
        for item in subheaders
        if int(item["declared_hits"]) != int(item["observed_hits"])
    ]
    return {
        "events": len(events),
        "errors": errors,
        "subheaders": len(subheaders),
        "hits": sum(1 for item in events if item["kind"] == "hit"),
        "hits_before_subheader": hits_before_subheader,
        "declared_hit_hist": hist([int(item["declared_hits"]) for item in subheaders]),
        "observed_hit_hist": hist([int(item["observed_hits"]) for item in subheaders]),
        "ts_bucket_delta_hist": hist(delta([int(item["ts_bucket"]) for item in subheaders], 256)),
        "mismatches": mismatches[:16],
        "first_subheaders": subheaders[:8],
    }


def summarize_type3(events: list[dict[str, Any]]) -> dict[str, Any]:
    frames: list[list[dict[str, Any]]] = []
    current: list[dict[str, Any]] = []
    for event in events:
        if event["sop"] or event["kind"] == "frame_header":
            if current:
                frames.append(current)
            current = [event]
        elif current:
            current.append(event)
            if event["eop"] or event["kind"] == "frame_trailer":
                frames.append(current)
                current = []
    if current:
        frames.append(current)

    reports: list[dict[str, Any]] = []
    for frame in frames[:16]:
        words = [int(event["data"]) for event in frame]
        kinds = [event["kind"] for event in frame]
        body = frame[5:-1] if len(frame) >= 6 and kinds[-1] == "frame_trailer" else frame[5:]
        subheaders = [event for event in body if event["kind"] == "subheader"]
        hits = [event for event in body if event["kind"] == "hit"]
        header_debug = words[3] if len(words) > 3 else 0
        reports.append(
            {
                "start_time_ps": frame[0]["time_ps"],
                "length_words": len(frame),
                "first_word": hex36(words[0]) if words else "-",
                "last_word": hex36(words[-1]) if words else "-",
                "has_header": bool(words and classify_word(words[0]) == "frame_header"),
                "has_trailer": bool(words and classify_word(words[-1]) == "frame_trailer"),
                "debug_subheaders": (header_debug >> 16) & 0x7FFF,
                "debug_hits": header_debug & 0xFFFF,
                "decoded_subheaders": len(subheaders),
                "decoded_hits": len(hits),
                "subheader_hit_hist": hist([(int(event["data"]) >> 8) & 0xFF for event in subheaders]),
            }
        )

    return {
        "events": len(events),
        "frames": len(frames),
        "frame_length_hist": hist([len(frame) for frame in frames]),
        "reports": reports,
    }


def delta(values: list[int], modulo: int) -> list[int]:
    return [(cur - prev) % modulo for prev, cur in zip(values, values[1:])]


def hist(values: list[int]) -> dict[str, int]:
    counts = Counter(values)
    return {str(key): val for key, val in sorted(counts.items(), key=lambda item: (-item[1], item[0]))[:32]}


def hex36(value: int) -> str:
    return f"0x{value & ((1 << 36) - 1):09X}"


def analyze(path: Path, hitstack: int) -> dict[str, Any]:
    samples, label_counts = parse_vcd(path)
    labels = [f"hs{hitstack}.rbcam{idx}" for idx in range(4)]
    type2 = {label: summarize_type2(stream_events(samples, label, "aso_hit_type2")) for label in labels}
    type3_label = f"hs{hitstack}"
    type3 = summarize_type3(stream_events(samples, type3_label, "hit_type3"))
    interesting = [
        *(f"{label}.aso_hit_type2_valid" for label in labels),
        f"{type3_label}.hit_type3_valid",
        f"{type3_label}.hit_type3_startofpacket",
        f"{type3_label}.hit_type3_endofpacket",
    ]
    return {
        "file": str(path),
        "hitstack": hitstack,
        "samples": len(samples),
        "time_window_ps": [samples[0][0], samples[-1][0]] if samples else None,
        "tracked_probes": dict(label_counts),
        "first_events": {
            name: {"first_high_ps": first_high(samples, name), "rising_edges": count_rises(samples, name)}
            for name in interesting
            if signal_exists(samples, name)
        },
        "type2": type2,
        "type3": type3,
    }


def render_markdown(summary: dict[str, Any]) -> str:
    lines = [
        "# Phase 6 Frame-Boundary SignalTap VCD Summary",
        "",
        f"- VCD: `{summary['file']}`",
        f"- Hit stack: `{summary['hitstack']}`",
        f"- Samples: `{summary['samples']}`",
        f"- Time window ps: `{summary['time_window_ps']}`",
        f"- Tracked probes: `{summary['tracked_probes']}`",
        "",
        "## First Events",
        "",
        "| Signal | First high ps | Rising edges |",
        "|---|---:|---:|",
    ]
    for name, info in sorted(summary["first_events"].items()):
        lines.append(f"| `{name}` | {info['first_high_ps']} | {info['rising_edges']} |")
    lines.extend(["", "## RBCAM Type2", ""])
    for label, item in sorted(summary["type2"].items()):
        lines.append(
            f"- `{label}` events `{item['events']}`, subheaders `{item['subheaders']}`, hits `{item['hits']}`, "
            f"errors `{item['errors']}`, declared-hit hist `{item['declared_hit_hist']}`, "
            f"observed-hit hist `{item['observed_hit_hist']}`, ts-delta hist `{item['ts_bucket_delta_hist']}`"
        )
        if item["mismatches"]:
            lines.append(f"  - mismatches `{item['mismatches']}`")
    lines.extend(["", "## FEB Type3 Frames", ""])
    t3 = summary["type3"]
    lines.append(f"- Events: `{t3['events']}`")
    lines.append(f"- Frames: `{t3['frames']}`")
    lines.append(f"- Frame length histogram: `{t3['frame_length_hist']}`")
    for frame in t3["reports"][:8]:
        lines.append(
            f"- frame @{frame['start_time_ps']} ps len `{frame['length_words']}` "
            f"first `{frame['first_word']}` last `{frame['last_word']}` "
            f"header/trailer `{frame['has_header']}/{frame['has_trailer']}` "
            f"debug sh/hit `{frame['debug_subheaders']}/{frame['debug_hits']}` "
            f"decoded sh/hit `{frame['decoded_subheaders']}/{frame['decoded_hits']}`"
        )
    lines.append("")
    return "\n".join(lines)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vcd", type=Path)
    parser.add_argument("--hitstack", type=int, default=1)
    parser.add_argument("--json-output", type=Path)
    parser.add_argument("--md-output", type=Path)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    summary = analyze(args.vcd.resolve(), args.hitstack)
    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    if args.md_output:
        args.md_output.parent.mkdir(parents=True, exist_ok=True)
        args.md_output.write_text(render_markdown(summary), encoding="utf-8")
    if not args.json_output and not args.md_output:
        print(render_markdown(summary))
    return 0 if summary["samples"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
