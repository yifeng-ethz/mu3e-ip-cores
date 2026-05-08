#!/usr/bin/env python3
"""Trace-level FEB/SWB corun checker.

The simulator scoreboard compares exact 64-bit DMA hits. This script leaves a
human-readable hit lineage table by decoding the FEB egress, OPQ ingress, OPQ
egress, and DMA traces emitted by feb_swb_corun_plain_tb.
"""

from __future__ import annotations

import argparse
import collections
import csv
from dataclasses import dataclass
from pathlib import Path


K285 = 0xBC
K284 = 0x9C
K237 = 0xF7
SCIFI_HEADER_ID = 0b111000
SOURCE_MUTRIG_EMU = 0x1
DMA_PADDING_WORD = (1 << 256) - 1
HIT_WORD_MASK = (1 << 64) - 1
DMA_TS_MASK = (1 << 39) - 1
FRAME_STRIDE_8NS = 128 << 4


@dataclass
class FrameState:
    lane: int
    header_id: int
    header_word: int
    sop_time_ps: int
    field_index: int = 0
    ts_high: int = 0
    ts_low: int = 0
    frame_id: int = 0
    debug0_word: int = 0
    debug1_word: int = 0
    current_shd: int = -1
    current_hit_count16: int = 0
    current_hit_seen: int = 0


@dataclass
class HitRecord:
    stage: str
    hit_idx: int
    lane: int
    frame_id: int
    header_id: int
    ts_high: int
    ts_low: int
    shd_ts: int
    hit_word: int
    dma_hit: int
    time_ps: int
    debug_meta: int = 0


@dataclass
class DmaHit:
    time_ps: int
    word_idx: int
    slot: int
    hit_word: int
    end_of_event: int


def parse_hex(value: str) -> int:
    return int(value.strip(), 0)


def frame_base_8ns(hit: HitRecord) -> int:
    return (hit.ts_high << 16) | hit.ts_low


def bucket_start_8ns(hit: HitRecord) -> int:
    return frame_base_8ns(hit) + (hit.shd_ts << 4)


def source_abs_ts_8ns(hit: HitRecord) -> int:
    return bucket_start_8ns(hit) + source_ts_low_nibble(hit.hit_word)


def source_asic(hit_word: int) -> int:
    return (hit_word >> 22) & 0xF


def source_channel(hit_word: int) -> int:
    return (hit_word >> 17) & 0x1F


def source_hit_id(hit_word: int) -> int:
    return hit_word & 0x1FF


def source_fine(hit_word: int) -> int:
    return (hit_word >> 9) & 0x1F


def source_rem(hit_word: int) -> int:
    return (hit_word >> 14) & 0x7


def source_ts_low_nibble(hit_word: int) -> int:
    return (hit_word >> 28) & 0xF


def dma_is_mutrig(hit_word: int) -> int:
    return (hit_word >> 63) & 0x1


def dma_asic(hit_word: int) -> int:
    return (hit_word >> 61) & 0x3


def dma_channel(hit_word: int) -> int:
    return (hit_word >> 56) & 0x1F


def dma_hit_id(hit_word: int) -> int:
    return (hit_word >> 47) & 0x1FF


def dma_rem(hit_word: int) -> int:
    return (hit_word >> 44) & 0x7


def dma_fine(hit_word: int) -> int:
    return (hit_word >> 39) & 0x1F


def dma_ts_8ns(hit_word: int) -> int:
    return hit_word & DMA_TS_MASK


def debug_level(meta: int) -> int:
    return (meta >> 62) & 0x3


def debug_lane(meta: int) -> int:
    return (meta >> 60) & 0x3


def debug_source(meta: int) -> int:
    return (meta >> 56) & 0xF


def debug_ps(meta: int) -> int:
    return (meta >> 48) & 0xFF


def debug_ts(meta: int) -> int:
    return (meta >> 32) & 0xFFFF


def debug_hit_id(meta: int) -> int:
    return meta & 0xFFFF_FFFF


def make_mutrig_dma_hit(ts_high: int, ts_low: int, shd_ts: int, hit_word: int) -> int:
    data_word = 0
    data_word |= 1 << 63
    data_word |= ((hit_word >> 17) & 0x1F) << 56
    data_word |= (hit_word & 0x1FF) << 47
    data_word |= ((hit_word >> 14) & 0x7) << 44
    data_word |= ((hit_word >> 9) & 0x1F) << 39
    data_word |= (ts_high & ((1 << 23) - 1)) << 16
    data_word |= ((ts_low >> 11) & 0x1F) << 11
    data_word |= (shd_ts & 0x7F) << 4
    data_word |= (hit_word >> 28) & 0xF
    return data_word


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="ascii", newline="") as handle:
        return list(csv.DictReader(handle))


def parse_stream_hits(path: Path, stage: str, has_lane: bool) -> tuple[list[HitRecord], list[str]]:
    hits: list[HitRecord] = []
    issues: list[str] = []
    states: dict[int, FrameState] = {}

    for row in read_csv(path):
        lane = int(row["lane"]) if has_lane else 0
        time_ps = int(row["time_ps"])
        datak = parse_hex(row["datak"])
        data = parse_hex(row["data"])
        low_byte = data & 0xFF
        sop = int(row.get("sop", "0"))
        eop = int(row.get("eop", "0"))
        debug_valid = int(row.get("debug_valid", "0"))
        debug_meta = parse_hex(row.get("debug_meta", "0x0"))

        if datak == 0x1 and low_byte == K285 and (sop or not has_lane):
            states[lane] = FrameState(
                lane=lane,
                header_id=(data >> 26) & 0x3F,
                header_word=data,
                sop_time_ps=time_ps,
            )
            continue

        state = states.get(lane)
        if state is None:
            issues.append(f"{stage}: data outside a frame at time {time_ps} lane {lane}")
            continue

        if datak == 0x1 and low_byte == K284 and (eop or not has_lane):
            states.pop(lane, None)
            continue

        if state.field_index == 0:
            state.ts_high = data
            state.field_index += 1
            continue
        if state.field_index == 1:
            state.ts_low = (data >> 16) & 0xFFFF
            state.frame_id = data & 0xFFFF
            state.field_index += 1
            continue
        if state.field_index == 2:
            state.debug0_word = data
            state.field_index += 1
            continue
        if state.field_index == 3:
            state.debug1_word = data
            state.field_index += 1
            continue

        if datak == 0x1 and low_byte == K237:
            high_count = (data >> 16) & 0xFF
            state.current_shd = (data >> 24) & 0xFF
            state.current_hit_count16 = (data >> 8) & 0xFFFF
            state.current_hit_seen = 0
            if high_count != 0:
                issues.append(
                    f"{stage}: subheader high hit-count byte nonzero "
                    f"frame={state.frame_id} shd={state.current_shd} value=0x{high_count:02x}"
                )
            continue

        if datak == 0x0 and state.current_shd >= 0:
            state.current_hit_seen += 1
            if state.current_hit_seen > state.current_hit_count16:
                issues.append(
                    f"{stage}: more hit words than subheader count "
                    f"frame={state.frame_id} shd={state.current_shd}"
                )
            dma_hit = make_mutrig_dma_hit(
                state.ts_high,
                state.ts_low,
                state.current_shd,
                data,
            )
            hits.append(
                HitRecord(
                    stage=stage,
                    hit_idx=len(hits),
                    lane=lane,
                    frame_id=state.frame_id,
                    header_id=state.header_id,
                    ts_high=state.ts_high,
                    ts_low=state.ts_low,
                    shd_ts=state.current_shd,
                    hit_word=data,
                    dma_hit=dma_hit,
                    time_ps=time_ps,
                    debug_meta=debug_meta if debug_valid else 0,
                )
            )
            continue

    for lane, state in states.items():
        issues.append(f"{stage}: unterminated frame lane={lane} frame={state.frame_id}")
    return hits, issues


def parse_dma_hits(path: Path) -> tuple[list[DmaHit], int]:
    hits: list[DmaHit] = []
    padding_words = 0
    payload_idx = 0

    for row in read_csv(path):
        time_ps = int(row["time_ps"])
        word = parse_hex(row["data"])
        if word == DMA_PADDING_WORD:
            padding_words += 1
            continue
        for slot in range(4):
            hit_word = (word >> (slot * 64)) & HIT_WORD_MASK
            if hit_word == 0:
                continue
            hits.append(
                DmaHit(
                    time_ps=time_ps,
                    word_idx=payload_idx,
                    slot=slot,
                    hit_word=hit_word,
                    end_of_event=int(row["end_of_event"]),
                )
            )
        payload_idx += 1
    return hits, padding_words


def pop_match(index: dict[int, list], key: int):
    entries = index.get(key)
    if not entries:
        return None
    return entries.pop(0)


def build_index(items, key_fn):
    index: dict[int, list] = collections.defaultdict(list)
    for item in items:
        index[key_fn(item)].append(item)
    return index


LIFETIME_METRICS = [
    ("feb_egress_lifetime_cycles", "FEB egress"),
    ("opq_ingress_lifetime_cycles", "OPQ ingress"),
    ("opq_egress_lifetime_cycles", "OPQ egress"),
]


def cycles_from_hit_ts(time_ps: int | None, hit_ts_8ns: int) -> str:
    if time_ps is None:
        return ""
    return f"{(time_ps / 8000.0) - hit_ts_8ns:.3f}"


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return 0.0
    if len(values) == 1:
        return values[0]
    values_sorted = sorted(values)
    rank = (pct / 100.0) * (len(values_sorted) - 1)
    low = int(rank)
    high = min(low + 1, len(values_sorted) - 1)
    frac = rank - low
    return values_sorted[low] * (1.0 - frac) + values_sorted[high] * frac


def metric_values(rows: list[dict[str, object]], metric: str) -> list[float]:
    values: list[float] = []
    for row in rows:
        if row.get("status") != "PASS":
            continue
        value = row.get(metric, "")
        if value == "":
            continue
        values.append(float(value))
    return values


def write_rows(path: Path, fieldnames: list[str], rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="ascii", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def write_lifetime_stats(path: Path, rows: list[dict[str, object]]) -> None:
    with path.open("w", encoding="ascii", newline="") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=[
                "metric",
                "checkpoint",
                "count",
                "min_cycles",
                "p50_cycles",
                "p95_cycles",
                "max_cycles",
                "mean_cycles",
            ],
        )
        writer.writeheader()
        for metric, label in LIFETIME_METRICS:
            values = metric_values(rows, metric)
            if values:
                writer.writerow(
                    {
                        "metric": metric,
                        "checkpoint": label,
                        "count": len(values),
                        "min_cycles": f"{min(values):.3f}",
                        "p50_cycles": f"{percentile(values, 50):.3f}",
                        "p95_cycles": f"{percentile(values, 95):.3f}",
                        "max_cycles": f"{max(values):.3f}",
                        "mean_cycles": f"{sum(values) / len(values):.3f}",
                    }
                )
            else:
                writer.writerow(
                    {
                        "metric": metric,
                        "checkpoint": label,
                        "count": 0,
                        "min_cycles": "",
                        "p50_cycles": "",
                        "p95_cycles": "",
                        "max_cycles": "",
                        "mean_cycles": "",
                    }
                )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trace-dir", required=True, type=Path)
    parser.add_argument("--expected-lane", default=0, type=int)
    parser.add_argument("--expected-asic", default=0, type=int)
    parser.add_argument("--expected-channel", default=-1, type=int)
    parser.add_argument("--expected-channel-count", default=32, type=int)
    parser.add_argument("--expected-hit-period-8ns", default=1250, type=int)
    args = parser.parse_args()

    trace_dir = args.trace_dir
    feb_hits, feb_issues = parse_stream_hits(
        trace_dir / "feb_swb_feb_egress_trace.csv",
        "feb_egress",
        has_lane=True,
    )
    opq_ingress_hits, ingress_issues = parse_stream_hits(
        trace_dir / "feb_swb_ingress_trace.csv",
        "opq_ingress",
        has_lane=True,
    )
    opq_egress_hits, opq_issues = parse_stream_hits(
        trace_dir / "feb_swb_opq_trace.csv",
        "opq_egress",
        has_lane=False,
    )
    dma_hits, padding_words = parse_dma_hits(trace_dir / "feb_swb_dma_trace.csv")

    opq_ingress_index = build_index(opq_ingress_hits, lambda item: item.dma_hit)
    opq_egress_index = build_index(opq_egress_hits, lambda item: item.dma_hit)
    dma_index = build_index(dma_hits, lambda item: item.hit_word)

    hit_rows: list[dict[str, object]] = []
    lifetime_rows: list[dict[str, object]] = []
    failures: list[str] = []

    for expected in feb_hits:
        checks: list[str] = []
        hit_id = source_hit_id(expected.hit_word)
        channel = source_channel(expected.hit_word)
        abs_ts_8ns = source_abs_ts_8ns(expected)
        base = frame_base_8ns(expected)
        bucket_start = bucket_start_8ns(expected)
        bucket_end = bucket_start + 15
        sample_idx = (
            abs_ts_8ns // args.expected_hit_period_8ns
            if args.expected_hit_period_8ns > 0
            else -1
        )
        expected_sched_hit_id = (sample_idx * args.expected_channel_count) + channel
        expected_ts = expected.dma_hit & DMA_TS_MASK
        opq_ingress = pop_match(opq_ingress_index, expected.dma_hit)
        opq_egress = pop_match(opq_egress_index, expected.dma_hit)
        dma = pop_match(dma_index, expected.dma_hit)
        status = "PASS"

        def require(condition: bool, label: str) -> None:
            nonlocal status
            if condition:
                checks.append(f"{label}=OK")
            else:
                checks.append(f"{label}=FAIL")
                status = "FAIL"

        require(expected.lane == args.expected_lane, "lane")
        require(expected.header_id == SCIFI_HEADER_ID, "feb_header")
        require(source_asic(expected.hit_word) == args.expected_asic, "source_asic")
        if args.expected_channel >= 0:
            require(channel == args.expected_channel, "source_channel")
        else:
            require(0 <= channel < args.expected_channel_count, "source_channel")
        require(source_fine(expected.hit_word) == 0, "source_fine")
        require(bucket_start <= abs_ts_8ns <= bucket_end, "source_bucket")
        require(expected.frame_id == abs_ts_8ns // FRAME_STRIDE_8NS, "source_frame")
        require((abs_ts_8ns & 0xF) == source_ts_low_nibble(expected.hit_word), "source_ts_nibble")
        require(abs_ts_8ns % args.expected_hit_period_8ns == 0, "source_period")
        require(hit_id == expected_sched_hit_id, "source_hit_id_schedule")
        require(debug_level(expected.debug_meta) == 2, "debug_level")
        require(debug_lane(expected.debug_meta) == expected.lane, "debug_lane")
        require(debug_source(expected.debug_meta) == SOURCE_MUTRIG_EMU, "debug_source")
        require(debug_hit_id(expected.debug_meta) == hit_id, "debug_hit_id")
        require(debug_ps(expected.debug_meta) == (abs_ts_8ns & 0xFF), "debug_ps")
        require(debug_ts(expected.debug_meta) == (abs_ts_8ns & 0xFFFF), "debug_ts")
        require(opq_ingress is not None, "opq_ingress_present")
        if opq_ingress is not None:
            require(opq_ingress.header_id == SCIFI_HEADER_ID, "opq_ingress_header")
            require(opq_ingress.frame_id == expected.frame_id, "opq_ingress_frame")
            require(bucket_start_8ns(opq_ingress) == bucket_start, "opq_ingress_bucket")
        require(opq_egress is not None, "opq_egress_present")
        if opq_egress is not None:
            require(opq_egress.header_id == SCIFI_HEADER_ID, "opq_egress_header")
            require(opq_egress.frame_id == expected.frame_id, "opq_egress_frame")
            require(bucket_start_8ns(opq_egress) == bucket_start, "opq_egress_bucket")
        require(dma is not None, "dma_present")
        if dma is not None:
            require(dma_is_mutrig(dma.hit_word) == 1, "dma_type")
            require(dma_asic(dma.hit_word) == args.expected_asic, "dma_asic")
            require(dma_channel(dma.hit_word) == channel, "dma_channel")
            require(dma_hit_id(dma.hit_word) == hit_id, "dma_hit_id")
            require(dma_rem(dma.hit_word) == source_rem(expected.hit_word), "dma_rem")
            require(dma_fine(dma.hit_word) == source_fine(expected.hit_word), "dma_fine")
            require(dma_ts_8ns(dma.hit_word) == expected_ts, "dma_ts")
            require(dma_ts_8ns(dma.hit_word) == abs_ts_8ns, "dma_abs_ts")

        if status != "PASS":
            failures.append(f"hit_id={hit_id} channel={channel} checks={';'.join(checks)}")

        hit_rows.append(
            {
                "status": status,
                "hit_id": hit_id,
                "lane": expected.lane,
                "source_asic": source_asic(expected.hit_word),
                "source_channel": channel,
                "abs_ts_8ns": abs_ts_8ns,
                "frame_id": expected.frame_id,
                "frame_base_8ns": base,
                "shd_ts": expected.shd_ts,
                "bucket_start_8ns": bucket_start,
                "bucket_end_8ns": bucket_end,
                "feb_egress_time_ps": expected.time_ps,
                "opq_ingress_time_ps": opq_ingress.time_ps if opq_ingress is not None else -1,
                "opq_egress_time_ps": opq_egress.time_ps if opq_egress is not None else -1,
                "dma_time_ps": dma.time_ps if dma is not None else -1,
                "dma_word_idx": dma.word_idx if dma is not None else -1,
                "dma_slot": dma.slot if dma is not None else -1,
                "source_hit": f"0x{expected.hit_word:08x}",
                "expected_dma_hit": f"0x{expected.dma_hit:016x}",
                "actual_dma_hit": f"0x{dma.hit_word:016x}" if dma is not None else "missing",
                "dma_ts_8ns": dma_ts_8ns(dma.hit_word) if dma is not None else -1,
                "debug_meta": f"0x{expected.debug_meta:016x}",
                "checks": ";".join(checks),
            }
        )
        lifetime_rows.append(
            {
                "status": status,
                "hit_id": hit_id,
                "channel": channel,
                "abs_ts_8ns": abs_ts_8ns,
                "frame_id": expected.frame_id,
                "shd_ts": expected.shd_ts,
                "feb_egress_time_ps": expected.time_ps,
                "opq_ingress_time_ps": opq_ingress.time_ps if opq_ingress is not None else "",
                "opq_egress_time_ps": opq_egress.time_ps if opq_egress is not None else "",
                "dma_time_ps": dma.time_ps if dma is not None else "",
                "feb_egress_lifetime_cycles": cycles_from_hit_ts(expected.time_ps, abs_ts_8ns),
                "opq_ingress_lifetime_cycles": cycles_from_hit_ts(
                    opq_ingress.time_ps if opq_ingress is not None else None,
                    abs_ts_8ns,
                ),
                "opq_egress_lifetime_cycles": cycles_from_hit_ts(
                    opq_egress.time_ps if opq_egress is not None else None,
                    abs_ts_8ns,
                ),
                "dma_lifetime_cycles": cycles_from_hit_ts(
                    dma.time_ps if dma is not None else None,
                    abs_ts_8ns,
                ),
            }
        )

    ghost_opq_ingress = sum(len(items) for items in opq_ingress_index.values())
    ghost_opq_egress = sum(len(items) for items in opq_egress_index.values())
    ghost_dma = sum(len(items) for items in dma_index.values())
    if ghost_opq_ingress:
        failures.append(f"ghost_opq_ingress_hits={ghost_opq_ingress}")
    if ghost_opq_egress:
        failures.append(f"ghost_opq_egress_hits={ghost_opq_egress}")
    if ghost_dma:
        failures.append(f"ghost_dma_hits={ghost_dma}")
    failures.extend(feb_issues)
    failures.extend(ingress_issues)
    failures.extend(opq_issues)

    hit_trace_path = trace_dir / "feb_swb_hit_trace_debug.csv"
    lifetime_trace_path = trace_dir / "feb_swb_lifetime_trace.csv"
    lifetime_stats_path = trace_dir / "feb_swb_lifetime_hist_stats.csv"
    summary_path = trace_dir / "feb_swb_trace_debug_summary.txt"
    write_rows(
        hit_trace_path,
        [
            "status",
            "hit_id",
            "lane",
            "source_asic",
            "source_channel",
            "abs_ts_8ns",
            "frame_id",
            "frame_base_8ns",
            "shd_ts",
            "bucket_start_8ns",
            "bucket_end_8ns",
            "feb_egress_time_ps",
            "opq_ingress_time_ps",
            "opq_egress_time_ps",
            "dma_time_ps",
            "dma_word_idx",
            "dma_slot",
            "source_hit",
            "expected_dma_hit",
            "actual_dma_hit",
            "dma_ts_8ns",
            "debug_meta",
            "checks",
        ],
        hit_rows,
    )
    write_rows(
        lifetime_trace_path,
        [
            "status",
            "hit_id",
            "channel",
            "abs_ts_8ns",
            "frame_id",
            "shd_ts",
            "feb_egress_time_ps",
            "opq_ingress_time_ps",
            "opq_egress_time_ps",
            "dma_time_ps",
            "feb_egress_lifetime_cycles",
            "opq_ingress_lifetime_cycles",
            "opq_egress_lifetime_cycles",
            "dma_lifetime_cycles",
        ],
        lifetime_rows,
    )
    write_lifetime_stats(lifetime_stats_path, lifetime_rows)

    pass_rows = sum(1 for row in hit_rows if row["status"] == "PASS")
    with summary_path.open("w", encoding="ascii") as handle:
        handle.write(f"expected_feb_hits={len(feb_hits)}\n")
        handle.write(f"opq_ingress_hits={len(opq_ingress_hits)}\n")
        handle.write(f"opq_egress_hits={len(opq_egress_hits)}\n")
        handle.write(f"dma_hits={len(dma_hits)}\n")
        handle.write(f"padding_words={padding_words}\n")
        handle.write(f"pass_hits={pass_rows}\n")
        handle.write(f"fail_hits={len(hit_rows) - pass_rows}\n")
        handle.write(f"ghost_opq_ingress_hits={ghost_opq_ingress}\n")
        handle.write(f"ghost_opq_egress_hits={ghost_opq_egress}\n")
        handle.write(f"ghost_dma_hits={ghost_dma}\n")
        handle.write(f"issue_count={len(failures)}\n")
        for failure in failures:
            handle.write(f"issue={failure}\n")

    if failures:
        print(
            "TRACE_DEBUG_FAIL "
            f"hits={len(hit_rows)} pass_hits={pass_rows} issues={len(failures)} "
            f"csv={hit_trace_path}"
        )
        for failure in failures[:16]:
            print(f"trace_debug: {failure}")
        return 1

    channel_text = (
        str(args.expected_channel)
        if args.expected_channel >= 0
        else f"0..{args.expected_channel_count - 1}"
    )
    print(
        "TRACE_DEBUG_PASS "
        f"hits={len(hit_rows)} channels={channel_text} "
        f"asic={args.expected_asic} csv={hit_trace_path}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
