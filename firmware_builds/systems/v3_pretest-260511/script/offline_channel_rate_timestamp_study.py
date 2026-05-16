#!/usr/bin/env python3
"""Offline Mu3e 256-channel rate and timestamp-consecutiveness study.

The study builds legal FEB Mu3e data frames, decodes the hit timestamp back out
of the header/subheader/hit fields, and checks that one selected channel per
ASIC preserves the exact injected inter-event interval.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import math
import random
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt


CLOCK_HZ = 125_000_000
ASIC_COUNT = 8
CHANNELS_PER_ASIC = 32
CHANNEL_COUNT = ASIC_COUNT * CHANNELS_PER_ASIC
FRAME_SUBHEADERS = 128
SUBHEADER_TICKS = 16
FRAME_PERIOD_TICKS = FRAME_SUBHEADERS * SUBHEADER_TICKS
RUNNING_TICKS = CLOCK_HZ // 1000
SOP_WORD = 0xA50000BC
K28_5 = 0xBC
K23_7 = 0xF7
K28_4 = 0x9C
DEFAULT_RATES_HZ = (10_000, 100_000, 500_000, 1_000_000)


@dataclass(frozen=True)
class FrameWord:
    rate_hz: int
    frame_index: int
    word_index: int
    kind: str
    data: int
    datak: int
    sop: int
    eop: int


@dataclass(frozen=True)
class DecodedHit:
    rate_hz: int
    frame_index: int
    subheader_index: int
    hit_index_in_subheader: int
    packet_count: int
    ts48: int
    ts_ticks: int
    asic: int
    local_channel: int
    global_channel: int
    raw_hit_word: int


@dataclass(frozen=True)
class FrameCheck:
    rate_hz: int
    frame_index: int
    packet_count: int
    expected_packet_count: int
    frame_start_ts: int
    expected_frame_start_ts: int
    page_base: int
    expected_page_base: int
    declared_hits: int
    seen_hits: int
    accepted_words: int
    expected_words: int
    status: str
    issues: tuple[str, ...]


def parse_rate(text: str) -> int:
    cleaned = text.strip().lower().replace("_", "")
    scale = 1
    if cleaned.endswith("khz"):
        cleaned = cleaned[:-3]
        scale = 1_000
    elif cleaned.endswith("mhz"):
        cleaned = cleaned[:-3]
        scale = 1_000_000
    elif cleaned.endswith("hz"):
        cleaned = cleaned[:-2]
    value = float(cleaned)
    rate = int(round(value * scale))
    if rate <= 0:
        raise argparse.ArgumentTypeError("rate must be positive")
    if CLOCK_HZ % rate != 0:
        raise argparse.ArgumentTypeError(f"{text} does not map to an integer 125 MHz period")
    return rate


def parse_selected_channels(text: str) -> dict[int, int]:
    selected: dict[int, int] = {}
    if not text:
        return selected
    for item in text.split(","):
        if ":" not in item:
            raise argparse.ArgumentTypeError("selected channels must use ASIC:channel entries")
        asic_text, channel_text = item.split(":", 1)
        asic = int(asic_text, 0)
        channel = int(channel_text, 0)
        if not 0 <= asic < ASIC_COUNT:
            raise argparse.ArgumentTypeError(f"ASIC must be 0..{ASIC_COUNT - 1}, got {asic}")
        if not 0 <= channel < CHANNELS_PER_ASIC:
            raise argparse.ArgumentTypeError(
                f"channel must be 0..{CHANNELS_PER_ASIC - 1}, got {channel}"
            )
        selected[asic] = channel
    if len(selected) != ASIC_COUNT:
        raise argparse.ArgumentTypeError(f"need exactly {ASIC_COUNT} ASIC entries")
    return selected


def default_output_dir() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    return Path("firmware_builds/systems/v3_pretest-260511/reports") / (
        f"offline_channel_rate_timestamp_{stamp}"
    )


def choose_channels(seed: int) -> dict[int, int]:
    rng = random.Random(seed)
    return {asic: rng.randrange(CHANNELS_PER_ASIC) for asic in range(ASIC_COUNT)}


def global_channel(asic: int, local_channel: int) -> int:
    return asic * CHANNELS_PER_ASIC + local_channel


def build_periodic_events(rate_hz: int, selected: dict[int, int], running_ticks: int) -> list[dict[str, int]]:
    period_ticks = CLOCK_HZ // rate_hz
    events: list[dict[str, int]] = []
    for tick in range(0, running_ticks, period_ticks):
        for asic, local_channel in sorted(selected.items()):
            events.append(
                {
                    "tick": tick,
                    "asic": asic,
                    "local_channel": local_channel,
                    "global_channel": global_channel(asic, local_channel),
                }
            )
    events.sort(key=lambda item: (item["tick"], item["asic"], item["local_channel"]))
    return events


def encode_hit_word(event: dict[str, int]) -> int:
    return (
        ((event["tick"] & 0xF) << 28)
        | ((event["asic"] & 0x3F) << 22)
        | ((event["local_channel"] & 0x3F) << 16)
        | 0x40
    )


def encode_frames(rate_hz: int, selected: dict[int, int], running_ticks: int) -> list[FrameWord]:
    events = build_periodic_events(rate_hz, selected, running_ticks)
    frame_count = math.ceil(running_ticks / FRAME_PERIOD_TICKS)
    events_by_frame: list[list[dict[str, int]]] = [[] for _ in range(frame_count)]
    for event in events:
        frame_index = event["tick"] // FRAME_PERIOD_TICKS
        events_by_frame[frame_index].append(event)

    words: list[FrameWord] = []
    for frame_index in range(frame_count):
        frame_start_ts = frame_index * FRAME_PERIOD_TICKS
        frame_events = events_by_frame[frame_index]
        packet_count = frame_index & 0xFFFF
        header_hi = (frame_start_ts >> 16) & 0xFFFFFFFF
        header_lo = ((frame_start_ts & 0xF000) << 16) | packet_count
        declared_hits = len(frame_events)
        count_word = (FRAME_SUBHEADERS << 16) | declared_hits
        header_words = [
            ("sop", SOP_WORD, 0x1, 1, 0),
            ("header_ts_hi", header_hi, 0x0, 0, 0),
            ("header_ts_lo", header_lo, 0x0, 0, 0),
            ("declared_counts", count_word, 0x0, 0, 0),
            ("debug_time", frame_start_ts & 0xFFFFFFFF, 0x0, 0, 0),
        ]
        word_index = 0
        for kind, data, datak, sop, eop in header_words:
            words.append(FrameWord(rate_hz, frame_index, word_index, kind, data, datak, sop, eop))
            word_index += 1

        events_by_subheader: list[list[dict[str, int]]] = [[] for _ in range(FRAME_SUBHEADERS)]
        for event in frame_events:
            subheader_index = (event["tick"] - frame_start_ts) // SUBHEADER_TICKS
            events_by_subheader[subheader_index].append(event)

        for subheader_index, subheader_events in enumerate(events_by_subheader):
            sub_ts = ((frame_start_ts >> 4) + subheader_index) & 0xFF
            subheader_events.sort(key=lambda item: (item["tick"], item["asic"], item["local_channel"]))
            if len(subheader_events) > 0xFF:
                raise RuntimeError("subheader hit declaration overflow")
            sub_word = (sub_ts << 24) | (len(subheader_events) << 8) | K23_7
            words.append(
                FrameWord(rate_hz, frame_index, word_index, "subheader", sub_word, 0x1, 0, 0)
            )
            word_index += 1
            for event in subheader_events:
                words.append(
                    FrameWord(
                        rate_hz,
                        frame_index,
                        word_index,
                        "hit",
                        encode_hit_word(event),
                        0x0,
                        0,
                        0,
                    )
                )
                word_index += 1

        words.append(FrameWord(rate_hz, frame_index, word_index, "trailer", K28_4, 0x1, 0, 1))
    return words


def reconstruct_hit_ts(header_hi: int, header_lo: int, sub_ts: int, hit_word: int) -> int:
    return (
        ((header_hi & 0xFFFFFFFF) << 16)
        | (((header_lo >> 28) & 0xF) << 12)
        | ((sub_ts & 0xFF) << 4)
        | ((hit_word >> 28) & 0xF)
    ) & 0xFFFFFFFFFFFF


def reconstruct_frame_start_ts(header_hi: int, header_lo: int, first_sub_ts: int) -> int:
    return (
        ((header_hi & 0xFFFFFFFF) << 16)
        | (((header_lo >> 28) & 0xF) << 12)
        | ((first_sub_ts & 0xFF) << 4)
    ) & 0xFFFFFFFFFFFF


def decode_frames(rate_hz: int, words: list[FrameWord]) -> tuple[list[DecodedHit], list[FrameCheck]]:
    hits: list[DecodedHit] = []
    checks: list[FrameCheck] = []
    index = 0
    last_packet_count: int | None = None
    last_page_base: int | None = None
    last_frame_start_ts: int | None = None
    frame_index = 0

    while index < len(words):
        issues: list[str] = []
        frame_word_start = index
        preamble = words[index]
        if not (preamble.sop and preamble.datak & 0x1 and (preamble.data & 0xFF) == K28_5):
            issues.append(f"missing K28.5 SOP at word {index}")
        index += 1
        header_hi = words[index].data
        index += 1
        header_lo = words[index].data
        packet_count = header_lo & 0xFFFF
        index += 1
        count_word = words[index].data
        declared_subheaders = (count_word >> 16) & 0x7FFF
        declared_hits = count_word & 0xFFFF
        index += 1
        index += 1  # debug word

        expected_packet_count = packet_count if last_packet_count is None else (last_packet_count + 1) & 0xFFFF
        seen_hits = 0
        first_sub_ts: int | None = None
        for subheader_index in range(declared_subheaders):
            subheader = words[index]
            if not (subheader.datak & 0x1 and (subheader.data & 0xFF) == K23_7):
                issues.append(
                    f"missing K23.7 subheader frame={frame_index} subheader={subheader_index}"
                )
            sub_ts = (subheader.data >> 24) & 0xFF
            declared_sub_hits = (subheader.data >> 8) & 0xFF
            if first_sub_ts is None:
                first_sub_ts = sub_ts
            expected_sub_ts = ((first_sub_ts & 0x80) + subheader_index) & 0xFF
            if sub_ts != expected_sub_ts:
                issues.append(
                    f"subheader nonconsecutive got=0x{sub_ts:02X} expected=0x{expected_sub_ts:02X}"
                )
            index += 1
            for hit_index_in_subheader in range(declared_sub_hits):
                hit_word = words[index]
                if hit_word.datak != 0:
                    issues.append(
                        f"hit datak nonzero frame={frame_index} subheader={subheader_index}"
                    )
                ts48 = reconstruct_hit_ts(header_hi, header_lo, sub_ts, hit_word.data)
                asic = (hit_word.data >> 22) & 0x3F
                local_channel = (hit_word.data >> 16) & 0x3F
                hits.append(
                    DecodedHit(
                        rate_hz=rate_hz,
                        frame_index=frame_index,
                        subheader_index=subheader_index,
                        hit_index_in_subheader=hit_index_in_subheader,
                        packet_count=packet_count,
                        ts48=ts48,
                        ts_ticks=ts48,
                        asic=asic,
                        local_channel=local_channel,
                        global_channel=global_channel(asic, local_channel),
                        raw_hit_word=hit_word.data,
                    )
                )
                seen_hits += 1
                index += 1

        trailer = words[index]
        if not (trailer.eop and trailer.datak & 0x1 and (trailer.data & 0xFF) == K28_4):
            issues.append(f"missing K28.4 trailer at frame={frame_index}")
        index += 1

        accepted_words = index - frame_word_start
        expected_words = 5 + declared_subheaders + declared_hits + 1
        page_base = 0 if first_sub_ts is None else (first_sub_ts & 0x80)
        expected_page_base = page_base if last_page_base is None else (last_page_base + FRAME_SUBHEADERS) & 0xFF
        frame_start_ts = reconstruct_frame_start_ts(header_hi, header_lo, first_sub_ts or 0)
        expected_frame_start_ts = (
            frame_start_ts
            if last_frame_start_ts is None
            else (last_frame_start_ts + FRAME_PERIOD_TICKS) & 0xFFFFFFFFFFFF
        )

        if declared_subheaders != FRAME_SUBHEADERS:
            issues.append(f"declared_subheaders={declared_subheaders} expected={FRAME_SUBHEADERS}")
        if seen_hits != declared_hits:
            issues.append(f"seen_hits={seen_hits} declared_hits={declared_hits}")
        if accepted_words != expected_words:
            issues.append(f"accepted_words={accepted_words} expected_words={expected_words}")
        if packet_count != expected_packet_count:
            issues.append(
                f"packet_count=0x{packet_count:04X} expected=0x{expected_packet_count:04X}"
            )
        if page_base != expected_page_base:
            issues.append(f"page_base=0x{page_base:02X} expected=0x{expected_page_base:02X}")
        if frame_start_ts != expected_frame_start_ts:
            issues.append(
                f"frame_start_ts=0x{frame_start_ts:012X} expected=0x{expected_frame_start_ts:012X}"
            )

        checks.append(
            FrameCheck(
                rate_hz=rate_hz,
                frame_index=frame_index,
                packet_count=packet_count,
                expected_packet_count=expected_packet_count,
                frame_start_ts=frame_start_ts,
                expected_frame_start_ts=expected_frame_start_ts,
                page_base=page_base,
                expected_page_base=expected_page_base,
                declared_hits=declared_hits,
                seen_hits=seen_hits,
                accepted_words=accepted_words,
                expected_words=expected_words,
                status="PASS" if not issues else "FAIL",
                issues=tuple(issues),
            )
        )
        last_packet_count = packet_count
        last_page_base = page_base
        last_frame_start_ts = frame_start_ts
        frame_index += 1

    return hits, checks


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, Any]]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def analyze_interevents(
    rate_hz: int,
    hits: list[DecodedHit],
    selected: dict[int, int],
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    expected_interval = CLOCK_HZ // rate_hz
    rows: list[dict[str, Any]] = []
    active_global_channels = {
        global_channel(asic, local_channel) for asic, local_channel in selected.items()
    }
    counts = {channel: 0 for channel in range(CHANNEL_COUNT)}
    by_channel: dict[int, list[int]] = {channel: [] for channel in active_global_channels}
    for hit in hits:
        counts[hit.global_channel] += 1
        if hit.global_channel in by_channel:
            by_channel[hit.global_channel].append(hit.ts_ticks)

    mismatches = 0
    long_gaps = 0
    for asic, local_channel in sorted(selected.items()):
        channel = global_channel(asic, local_channel)
        timestamps = sorted(by_channel[channel])
        for event_index, (prev_ts, this_ts) in enumerate(zip(timestamps, timestamps[1:]), start=1):
            delta = this_ts - prev_ts
            status = "PASS" if delta == expected_interval else "FAIL"
            if status != "PASS":
                mismatches += 1
            if delta > expected_interval:
                long_gaps += 1
            rows.append(
                {
                    "rate_hz": rate_hz,
                    "asic": asic,
                    "local_channel": local_channel,
                    "global_channel": channel,
                    "event_index": event_index,
                    "prev_ts48": f"0x{prev_ts:012X}",
                    "ts48": f"0x{this_ts:012X}",
                    "delta_ticks": delta,
                    "expected_delta_ticks": expected_interval,
                    "delta_ns": delta * 8,
                    "status": status,
                }
            )

    inactive_hits = sum(count for channel, count in counts.items() if channel not in active_global_channels)
    expected_hits_per_active_channel = math.ceil(RUNNING_TICKS / expected_interval)
    active_count_mismatches = {
        str(channel): counts[channel]
        for channel in active_global_channels
        if counts[channel] != expected_hits_per_active_channel
    }
    summary = {
        "rate_hz": rate_hz,
        "expected_interval_ticks": expected_interval,
        "expected_interval_ns": expected_interval * 8,
        "expected_hits_per_active_channel": expected_hits_per_active_channel,
        "active_channels": sorted(active_global_channels),
        "decoded_hits": len(hits),
        "inactive_channel_hits": inactive_hits,
        "delta_rows": len(rows),
        "delta_mismatches": mismatches,
        "long_gap_count": long_gaps,
        "active_count_mismatches": active_count_mismatches,
        "status": "PASS"
        if inactive_hits == 0 and mismatches == 0 and not active_count_mismatches
        else "FAIL",
    }
    return rows, summary


def rate_label(rate_hz: int) -> str:
    if rate_hz >= 1_000_000 and rate_hz % 1_000_000 == 0:
        return f"{rate_hz // 1_000_000} MHz"
    if rate_hz >= 1_000 and rate_hz % 1_000 == 0:
        return f"{rate_hz // 1_000} kHz"
    return f"{rate_hz} Hz"


def plot_channel_counts(path: Path, count_rows: list[dict[str, Any]], selected: dict[int, int], rates: list[int]) -> None:
    active_channels = {global_channel(asic, ch) for asic, ch in selected.items()}
    fig, axes = plt.subplots(2, 2, figsize=(10.5, 6.8), sharex=True)
    axes_list = list(axes.flat)
    for axis, rate_hz in zip(axes_list, rates):
        rows = [row for row in count_rows if row["rate_hz"] == rate_hz]
        channels = [row["global_channel"] for row in rows]
        counts = [row["count"] for row in rows]
        colors = ["#b8bec9" if channel not in active_channels else "#1f77b4" for channel in channels]
        axis.bar(channels, counts, color=colors, linewidth=0, width=0.85)
        expected = next(row["expected_count"] for row in rows if row["global_channel"] in active_channels)
        axis.axhline(expected, color="#d62728", linestyle="--", linewidth=1.2, label="expected")
        axis.set_title(rate_label(rate_hz))
        axis.set_ylabel("hits in 1 ms")
        axis.set_xlim(-2, CHANNEL_COUNT + 1)
        axis.grid(True, axis="y", alpha=0.25)
        axis.legend(loc="upper right", fontsize=8, frameon=False)
    for axis in axes_list[-2:]:
        axis.set_xlabel("global channel = ASIC * 32 + channel")
    fig.suptitle("Offline 256-channel occupancy, one random channel per ASIC", fontsize=12)
    fig.tight_layout(rect=(0, 0, 1, 0.96))
    fig.savefig(path, dpi=160)
    plt.close(fig)


def plot_interevents(path: Path, delta_rows: list[dict[str, Any]], rates: list[int]) -> None:
    fig, axes = plt.subplots(2, 2, figsize=(10.5, 6.8), sharex=True)
    axes_list = list(axes.flat)
    for axis, rate_hz in zip(axes_list, rates):
        rows = [row for row in delta_rows if row["rate_hz"] == rate_hz]
        expected = CLOCK_HZ // rate_hz
        pass_rows = [row for row in rows if row["status"] == "PASS"]
        fail_rows = [row for row in rows if row["status"] != "PASS"]
        axis.scatter(
            [row["global_channel"] for row in pass_rows],
            [row["delta_ticks"] for row in pass_rows],
            s=12,
            alpha=0.18,
            color="#2ca02c",
            edgecolors="none",
            label="decoded delta",
        )
        if fail_rows:
            axis.scatter(
                [row["global_channel"] for row in fail_rows],
                [row["delta_ticks"] for row in fail_rows],
                s=28,
                alpha=0.9,
                color="#d62728",
                edgecolors="none",
                label="mismatch",
            )
        axis.axhline(expected, color="#111111", linestyle="--", linewidth=1.1, label="injected interval")
        y_values = [row["delta_ticks"] for row in rows] + [expected]
        y_min = min(y_values)
        y_max = max(y_values)
        pad = max(1, int(expected * 0.08), (y_max - y_min) // 4)
        axis.set_ylim(max(0, y_min - pad), y_max + pad)
        axis.set_title(f"{rate_label(rate_hz)} ({expected} ticks)")
        axis.set_ylabel("inter-event ticks")
        axis.set_xlim(-2, CHANNEL_COUNT + 1)
        axis.grid(True, axis="y", alpha=0.25)
        axis.legend(loc="upper right", fontsize=8, frameon=False)
    for axis in axes_list[-2:]:
        axis.set_xlabel("global channel = ASIC * 32 + channel")
    fig.suptitle("Decoded 48-bit timestamp inter-event intervals", fontsize=12)
    fig.tight_layout(rect=(0, 0, 1, 0.96))
    fig.savefig(path, dpi=160)
    plt.close(fig)


def write_readme(out_dir: Path, summary: dict[str, Any]) -> None:
    lines = [
        "# Offline Channel Rate Timestamp Study",
        "",
        f"Created: {summary['created_at']}",
        "",
        "This report generates legal Mu3e data frames for one selected local",
        "channel per ASIC, decodes hit timestamps as",
        "`{header_ts_hi, header_ts_lo[31:28], subheader_ts[7:0], hit_ts[3:0]}`,",
        "and checks per-channel inter-event time.",
        "",
        f"Status: **{summary['status']}**",
        "",
        "## Selected Channels",
        "",
    ]
    for asic, channel in summary["selected_channels"].items():
        lines.append(f"- ASIC {asic}: local channel {channel}, global channel {int(asic) * 32 + int(channel)}")
    lines.extend(
        [
            "",
            "## Rates",
            "",
            "| Rate | Interval ticks | Interval ns | Frames | Hits | Long gaps | Status |",
            "| --- | ---: | ---: | ---: | ---: | ---: | --- |",
        ]
    )
    for rate in summary["rates"]:
        lines.append(
            f"| {rate_label(rate['rate_hz'])} | {rate['expected_interval_ticks']} | "
            f"{rate['expected_interval_ns']} | {rate['frame_count']} | {rate['decoded_hits']} | "
            f"{rate['long_gap_count']} | {rate['status']} |"
        )
    lines.extend(
        [
            "",
            "## Artifacts",
            "",
            "- `offline_frame_words.csv`: raw generated 32-bit data, datak, SOP/EOP words.",
            "- `offline_decoded_hits.csv`: decoded hits with reconstructed 48-bit timestamps.",
            "- `offline_interevent.csv`: per-channel inter-event intervals and pass/fail status.",
            "- `offline_channel_counts.csv`: 256-channel hit counts for each rate.",
            "- `channel_counts.png`: 256-channel occupancy plot.",
            "- `interevent_delta_ticks.png`: decoded timestamp interval plot.",
        ]
    )
    (out_dir / "README.md").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rates", nargs="+", type=parse_rate, default=list(DEFAULT_RATES_HZ))
    parser.add_argument("--seed", type=int, default=20260516)
    parser.add_argument("--selected-channels", type=parse_selected_channels)
    parser.add_argument("--running-ticks", type=int, default=RUNNING_TICKS)
    parser.add_argument("--output-dir", type=Path, default=default_output_dir())
    args = parser.parse_args()

    rates = list(dict.fromkeys(args.rates))
    if args.running_ticks <= 0:
        raise SystemExit("--running-ticks must be positive")
    selected = args.selected_channels if args.selected_channels is not None else choose_channels(args.seed)

    out_dir = args.output_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    all_word_rows: list[dict[str, Any]] = []
    all_hit_rows: list[dict[str, Any]] = []
    all_frame_rows: list[dict[str, Any]] = []
    all_delta_rows: list[dict[str, Any]] = []
    all_count_rows: list[dict[str, Any]] = []
    rate_summaries: list[dict[str, Any]] = []

    for rate_hz in rates:
        words = encode_frames(rate_hz, selected, args.running_ticks)
        decoded_hits, frame_checks = decode_frames(rate_hz, words)
        delta_rows, delta_summary = analyze_interevents(rate_hz, decoded_hits, selected)
        all_delta_rows.extend(delta_rows)
        all_word_rows.extend(
            {
                **asdict(word),
                "data_hex": f"0x{word.data:08X}",
                "datak_hex": f"0x{word.datak:X}",
            }
            for word in words
        )
        all_hit_rows.extend(
            {
                **asdict(hit),
                "ts48_hex": f"0x{hit.ts48:012X}",
                "raw_hit_word_hex": f"0x{hit.raw_hit_word:08X}",
            }
            for hit in decoded_hits
        )
        all_frame_rows.extend({**asdict(check), "issues": "; ".join(check.issues)} for check in frame_checks)

        active_channels = {
            global_channel(asic, local_channel) for asic, local_channel in selected.items()
        }
        counts = {channel: 0 for channel in range(CHANNEL_COUNT)}
        for hit in decoded_hits:
            counts[hit.global_channel] += 1
        expected_count = delta_summary["expected_hits_per_active_channel"]
        for channel in range(CHANNEL_COUNT):
            all_count_rows.append(
                {
                    "rate_hz": rate_hz,
                    "global_channel": channel,
                    "asic": channel // CHANNELS_PER_ASIC,
                    "local_channel": channel % CHANNELS_PER_ASIC,
                    "active_selected": int(channel in active_channels),
                    "count": counts[channel],
                    "expected_count": expected_count if channel in active_channels else 0,
                    "status": "PASS"
                    if ((channel in active_channels and counts[channel] == expected_count) or (channel not in active_channels and counts[channel] == 0))
                    else "FAIL",
                }
            )

        frame_failures = sum(1 for check in frame_checks if check.status != "PASS")
        rate_summary = {
            **delta_summary,
            "frame_count": len(frame_checks),
            "frame_failures": frame_failures,
            "encoded_words": len(words),
            "status": "PASS"
            if delta_summary["status"] == "PASS" and frame_failures == 0
            else "FAIL",
        }
        rate_summaries.append(rate_summary)

    summary = {
        "created_at": dt.datetime.now().isoformat(timespec="seconds"),
        "clock_hz": CLOCK_HZ,
        "running_ticks": args.running_ticks,
        "running_ms": args.running_ticks / CLOCK_HZ * 1000.0,
        "frame_period_ticks": FRAME_PERIOD_TICKS,
        "frame_period_ns": FRAME_PERIOD_TICKS * 8,
        "seed": args.seed,
        "selected_channels": {str(k): v for k, v in sorted(selected.items())},
        "rates": rate_summaries,
        "status": "PASS" if all(rate["status"] == "PASS" for rate in rate_summaries) else "FAIL",
    }

    write_csv(
        out_dir / "offline_frame_words.csv",
        [
            "rate_hz",
            "frame_index",
            "word_index",
            "kind",
            "data",
            "data_hex",
            "datak",
            "datak_hex",
            "sop",
            "eop",
        ],
        all_word_rows,
    )
    write_csv(
        out_dir / "offline_decoded_hits.csv",
        [
            "rate_hz",
            "frame_index",
            "subheader_index",
            "hit_index_in_subheader",
            "packet_count",
            "ts48",
            "ts48_hex",
            "ts_ticks",
            "asic",
            "local_channel",
            "global_channel",
            "raw_hit_word",
            "raw_hit_word_hex",
        ],
        all_hit_rows,
    )
    write_csv(
        out_dir / "offline_frame_checks.csv",
        [
            "rate_hz",
            "frame_index",
            "packet_count",
            "expected_packet_count",
            "frame_start_ts",
            "expected_frame_start_ts",
            "page_base",
            "expected_page_base",
            "declared_hits",
            "seen_hits",
            "accepted_words",
            "expected_words",
            "status",
            "issues",
        ],
        all_frame_rows,
    )
    write_csv(
        out_dir / "offline_interevent.csv",
        [
            "rate_hz",
            "asic",
            "local_channel",
            "global_channel",
            "event_index",
            "prev_ts48",
            "ts48",
            "delta_ticks",
            "expected_delta_ticks",
            "delta_ns",
            "status",
        ],
        all_delta_rows,
    )
    write_csv(
        out_dir / "offline_channel_counts.csv",
        [
            "rate_hz",
            "global_channel",
            "asic",
            "local_channel",
            "active_selected",
            "count",
            "expected_count",
            "status",
        ],
        all_count_rows,
    )
    (out_dir / "offline_rate_summary.json").write_text(
        json.dumps(summary, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    plot_channel_counts(out_dir / "channel_counts.png", all_count_rows, selected, rates)
    plot_interevents(out_dir / "interevent_delta_ticks.png", all_delta_rows, rates)
    write_readme(out_dir, summary)

    print(f"OFFLINE_CHANNEL_RATE_STUDY {summary['status']} output_dir={out_dir}")
    for rate in rate_summaries:
        print(
            "  "
            f"{rate_label(rate['rate_hz'])}: interval={rate['expected_interval_ticks']} ticks "
            f"frames={rate['frame_count']} hits={rate['decoded_hits']} "
            f"long_gaps={rate['long_gap_count']} frame_failures={rate['frame_failures']} "
            f"status={rate['status']}"
        )
    return 0 if summary["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
