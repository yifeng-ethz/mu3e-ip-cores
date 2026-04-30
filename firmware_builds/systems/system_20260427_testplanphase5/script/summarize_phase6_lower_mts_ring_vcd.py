#!/usr/bin/env python3
"""Summarize the Phase-6 lower-MTS/ring SignalTap VCD export."""

from __future__ import annotations

import argparse
import re
from collections import Counter, defaultdict
from pathlib import Path


SignalSamples = list[tuple[int, dict[str, str]]]


def label_for_scope(scope: str) -> str | None:
    parts = scope.split("/")
    leaf = parts[-1] if parts else ""

    if leaf == "hit_stack_subsystem_1":
        return "hit_stack1"

    if leaf.startswith("mts_preprocessor_"):
        return leaf.replace("mts_preprocessor_", "mts")

    if leaf.startswith("mutrig_lane_source_mux_"):
        return leaf.replace("mutrig_lane_source_mux_", "mux")

    if leaf == "mutrig_frame_deassembly_0" and len(parts) >= 2:
        match = re.fullmatch(r"mutrig_datapath_subsystem_(\d+)", parts[-2])
        if match:
            return f"deasm{match.group(1)}"

    if leaf == "histogram_ingress_bridge_0":
        return "hist_ingress"

    if leaf == "histogram_statistics_0":
        return "hist_stats"

    return None


def keep_ref(label: str, ref: str) -> bool:
    if label == "hit_stack1":
        return (
            ref.startswith("hit_type_1_")
            or ref.startswith("frame_debug_")
            or ref.startswith("frame_ts_delta_")
            or ref.startswith("ring_buffer_cam_")
        )

    if label.startswith("mts"):
        return (
            ref.startswith("asi_ctrl_")
            or ref.startswith("asi_hit_type0_")
            or ref.startswith("aso_hit_type1_")
            or ref.startswith("aso_debug_")
            or ref == "hit_out_delay_error"
        )

    if label.startswith("mux"):
        return ref.startswith(("asi_real_", "asi_emu_", "aso_"))

    if label.startswith("deasm"):
        return ref.startswith(("asi_rx8b1k_", "aso_hit_type0_"))

    if label == "hist_ingress":
        return ref.startswith(("asi_pre_", "aso_hist_"))

    if label == "hist_stats":
        return ref in {"queue_hit_valid"} or ref.startswith(("asi_hist_fill_in_", "asi_ctrl_"))

    return False


def parse_vcd(path: Path) -> tuple[SignalSamples, Counter[str], dict[str, int]]:
    symbol_to_name: dict[str, str] = {}
    label_counts: Counter[str] = Counter()
    var_counts: dict[str, int] = {}
    state: dict[str, str] = {}
    samples: SignalSamples = []
    cur_time: int | None = None
    time_has_updates = False
    in_defs = True
    scopes: list[str] = []

    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for raw_line in fh:
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
                        scope = "/".join(scopes)
                        label = label_for_scope(scope)
                        if label is not None and keep_ref(label, ref):
                            canonical = f"{label}.{ref}"
                            symbol_to_name[symbol] = canonical
                            label_counts[label] += 1
                    continue

                if line == "$enddefinitions $end":
                    in_defs = False
                    var_counts = dict(label_counts)
                continue

            if line.startswith("#"):
                if cur_time is not None and time_has_updates:
                    samples.append((cur_time, dict(state)))
                    time_has_updates = False
                cur_time = int(line[1:])
                continue

            if line[0] in "01xXzZ" and len(line) >= 2:
                name = symbol_to_name.get(line[1:])
                if name is not None:
                    state[name] = line[0].lower()
                    time_has_updates = True

    if cur_time is not None and time_has_updates:
        samples.append((cur_time, dict(state)))

    return samples, label_counts, var_counts


def signal_exists(samples: SignalSamples, name: str) -> bool:
    return any(name in snap for _, snap in samples)


def ever_high(samples: SignalSamples, name: str) -> bool:
    return any(snap.get(name) == "1" for _, snap in samples)


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


def first_snapshot(samples: SignalSamples, name: str) -> tuple[int, dict[str, str]] | None:
    for ts, snap in samples:
        if snap.get(name) == "1":
            return ts, snap
    return None


def bus_word(snapshot: dict[str, str], prefix: str, base: str, width: int) -> int:
    word = 0
    for idx in range(width):
        if snapshot.get(f"{prefix}.{base}[{idx}]") == "1":
            word |= 1 << idx
    return word


def distinct_bus_words(
    samples: SignalSamples,
    prefix: str,
    base: str,
    width: int,
    valid: str | None = None,
    limit: int = 12,
) -> list[int]:
    words: list[int] = []
    seen: set[int] = set()
    for _, snap in samples:
        if valid is not None and snap.get(f"{prefix}.{valid}") != "1":
            continue
        word = bus_word(snap, prefix, base, width)
        if word in seen:
            continue
        words.append(word)
        seen.add(word)
        if len(words) >= limit:
            break
    return words


def hex_words(words: list[int], width_bits: int) -> str:
    if not words:
        return "-"
    digits = max(1, (width_bits + 3) // 4)
    return ", ".join(f"0x{word:0{digits}X}" for word in words)


def signal_summary(samples: SignalSamples, name: str) -> str:
    if not signal_exists(samples, name):
        return "missing"
    first = first_high(samples, name)
    first_text = "-" if first is None else str(first)
    return f"first={first_text} rises={count_rises(samples, name)} ever={int(ever_high(samples, name))}"


def stream_line(
    samples: SignalSamples,
    label: str,
    valid: str,
    data: str,
    data_width: int,
    channel: str | None = None,
    channel_width: int = 4,
    error: str | None = None,
    error_width: int = 3,
) -> str:
    parts = [f"`{label}.{valid}` {signal_summary(samples, f'{label}.{valid}')}"]
    parts.append(f"data={hex_words(distinct_bus_words(samples, label, data, data_width, valid), data_width)}")
    if channel is not None:
        parts.append(
            f"channel={hex_words(distinct_bus_words(samples, label, channel, channel_width, valid), channel_width)}"
        )
    if error is not None:
        scalar_error = f"{label}.{error}"
        if signal_exists(samples, scalar_error):
            parts.append(f"error_scalar={signal_summary(samples, scalar_error)}")
        else:
            parts.append(f"error={hex_words(distinct_bus_words(samples, label, error, error_width, valid), error_width)}")
    return "; ".join(parts)


def debug_bus_line(samples: SignalSamples, label: str, valid: str, data: str, width: int) -> str:
    return (
        f"`{label}.{valid}` {signal_summary(samples, f'{label}.{valid}')} "
        f"values={hex_words(distinct_bus_words(samples, label, data, width, valid), width)}"
    )


def first_context(samples: SignalSamples, label: str, trigger: str) -> str:
    hit = first_snapshot(samples, f"{label}.{trigger}")
    if hit is None:
        return "-"
    ts, snap = hit
    fields = [f"time={ts}"]
    for base, width, valid in (
        ("asi_hit_type0_data", 45, None),
        ("asi_hit_type0_channel", 6, None),
        ("asi_hit_type0_error", 3, None),
        ("aso_hit_type1_data", 39, None),
        ("aso_hit_type1_channel", 4, None),
        ("aso_debug_ts_data", 16, None),
        ("aso_debug_burst_data", 16, None),
        ("hit_type_1_data", 39, None),
        ("hit_type_1_channel", 4, None),
        ("hit_type_1_error", 1, None),
        ("frame_debug_ts_data", 16, None),
    ):
        if signal_exists(samples, f"{label}.{base}[0]"):
            fields.append(f"{base}=0x{bus_word(snap, label, base, width):0{max(1, (width + 3) // 4)}X}")
    return " ".join(fields)


def markdown_summary(path: Path, samples: SignalSamples, label_counts: Counter[str], lanes: list[int]) -> str:
    lines: list[str] = []
    lines.append("# Phase 6 Lower MTS/Ring SignalTap VCD Summary")
    lines.append("")
    lines.append(f"- VCD: `{path}`")
    lines.append(f"- Samples: `{len(samples)}`")
    if samples:
        lines.append(f"- Time window: `{samples[0][0]}` to `{samples[-1][0]}` ps")
    tracked = ", ".join(f"{label}={count}" for label, count in sorted(label_counts.items()))
    lines.append(f"- Tracked scalar probes: `{sum(label_counts.values())}` ({tracked})")
    lines.append("")

    order = [
        "mux5.aso_valid",
        "mux6.aso_valid",
        "deasm5.aso_hit_type0_valid",
        "deasm6.aso_hit_type0_valid",
        "mts1.asi_hit_type0_valid",
        "mts1.aso_hit_type1_valid",
        "mts1.aso_hit_type1_error",
        "mts1.hit_out_delay_error",
        "hit_stack1.hit_type_1_valid",
        "hit_stack1.hit_type_1_error[0]",
    ]
    lines.append("## First Observed Events")
    lines.append("")
    lines.append("| Signal | First high ps | Rising edges | Ever high |")
    lines.append("|---|---:|---:|---:|")
    for name in order:
        if signal_exists(samples, name):
            first = first_high(samples, name)
            lines.append(
                f"| `{name}` | {'-' if first is None else first} | {count_rises(samples, name)} | "
                f"{int(ever_high(samples, name))} |"
            )
        else:
            lines.append(f"| `{name}` | missing | missing | missing |")
    lines.append("")

    lines.append("## Active Lower Lane Streams")
    lines.append("")
    for lane in lanes:
        for label in (f"mux{lane}", f"deasm{lane}"):
            if label.startswith("mux"):
                lines.append(
                    f"- {stream_line(samples, label, 'aso_valid', 'aso_data', 9, 'aso_channel', 4, 'aso_error', 3)}"
                )
                lines.append(f"  - `{label}.asi_real_valid` {signal_summary(samples, f'{label}.asi_real_valid')}")
                lines.append(f"  - `{label}.asi_emu_valid` {signal_summary(samples, f'{label}.asi_emu_valid')}")
            else:
                lines.append(
                    "- "
                    + stream_line(
                        samples,
                        label,
                        "aso_hit_type0_valid",
                        "aso_hit_type0_data",
                        16,
                        "aso_hit_type0_channel",
                        4,
                        "aso_hit_type0_error",
                        3,
                    )
                )
                lines.append(f"  - `{label}.asi_rx8b1k_valid` {signal_summary(samples, f'{label}.asi_rx8b1k_valid')}")
    lines.append("")

    lines.append("## MTS 1")
    lines.append("")
    lines.append(
        "- "
        + stream_line(
            samples,
            "mts1",
            "asi_hit_type0_valid",
            "asi_hit_type0_data",
            45,
            "asi_hit_type0_channel",
            6,
            "asi_hit_type0_error",
            3,
        )
    )
    lines.append(
        "- "
        + stream_line(
            samples,
            "mts1",
            "aso_hit_type1_valid",
            "aso_hit_type1_data",
            39,
            "aso_hit_type1_channel",
            4,
            "aso_hit_type1_error",
            1,
        )
    )
    lines.append(f"- `mts1.hit_out_delay_error` {signal_summary(samples, 'mts1.hit_out_delay_error')}")
    lines.append(f"- {debug_bus_line(samples, 'mts1', 'aso_debug_ts_valid', 'aso_debug_ts_data', 16)}")
    lines.append(f"- {debug_bus_line(samples, 'mts1', 'aso_debug_burst_valid', 'aso_debug_burst_data', 16)}")
    lines.append(f"- First `aso_hit_type1_error` context: `{first_context(samples, 'mts1', 'aso_hit_type1_error')}`")
    lines.append("")

    lines.append("## Hit Stack 1 / Ring")
    lines.append("")
    lines.append(
        "- "
        + stream_line(
            samples,
            "hit_stack1",
            "hit_type_1_valid",
            "hit_type_1_data",
            39,
            "hit_type_1_channel",
            4,
            "hit_type_1_error",
            1,
        )
    )
    lines.append(f"- {debug_bus_line(samples, 'hit_stack1', 'frame_debug_ts_valid', 'frame_debug_ts_data', 16)}")
    lines.append(f"- {debug_bus_line(samples, 'hit_stack1', 'frame_debug_burst_valid', 'frame_debug_burst_data', 16)}")
    lines.append(f"- {debug_bus_line(samples, 'hit_stack1', 'frame_ts_delta_valid', 'frame_ts_delta_data', 16)}")
    for cam in range(4):
        lines.append(
            "- "
            + debug_bus_line(
                samples,
                "hit_stack1",
                f"ring_buffer_cam_{cam}_filllevel_valid",
                f"ring_buffer_cam_{cam}_filllevel_data",
                16,
            )
        )
    lines.append(f"- First ring input-error context: `{first_context(samples, 'hit_stack1', 'hit_type_1_error[0]')}`")
    lines.append("")

    lines.append("## Diagnostic Conclusion")
    lines.append("")
    if ever_high(samples, "mts1.aso_hit_type1_error"):
        lines.append(
            "- The lower MTS output error sideband is visible in this capture, so the run is not just a ring-local reject."
        )
    else:
        lines.append(
            "- The lower MTS output error sideband was not observed in the exported window; retarget or widen the trigger before using this VCD as causality evidence."
        )
    if ever_high(samples, "hit_stack1.hit_type_1_error[0]"):
        lines.append("- The downstream hit stack/ring input error is also visible in the same exported window.")
    else:
        lines.append("- The downstream hit stack/ring input error was not visible in the exported window.")
    lines.append(
        "- Interpret this together with the live counters; the capture log reported `PRE (0 triggers seen)`, so this VCD is supporting evidence, not a standalone pass/fail gate."
    )
    lines.append("")
    return "\n".join(lines)


def parse_lanes(text: str) -> list[int]:
    lanes: list[int] = []
    for item in text.split(","):
        item = item.strip()
        if not item:
            continue
        lane = int(item, 0)
        if lane < 0:
            raise argparse.ArgumentTypeError("lane index must be non-negative")
        lanes.append(lane)
    if not lanes:
        raise argparse.ArgumentTypeError("at least one lane is required")
    return lanes


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vcd", type=Path)
    parser.add_argument("--lanes", type=parse_lanes, default=parse_lanes("5,6"))
    parser.add_argument("--output", type=Path, help="Optional Markdown output path.")
    args = parser.parse_args()

    samples, label_counts, _ = parse_vcd(args.vcd.resolve())
    if not samples:
        raise SystemExit(f"no tracked samples found in {args.vcd}")

    text = markdown_summary(args.vcd, samples, label_counts, args.lanes)
    if args.output is not None:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")
    print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
