#!/usr/bin/env python3
"""Trace-level FEB/SWB corun checker.

The simulator scoreboard compares exact 64-bit DMA hits. This script leaves a
human-readable hit lineage table by decoding the virtual MuTRiG generation,
pre-rbCAM, post-rbCAM, FEB egress, OPQ ingress, OPQ egress, and DMA traces
emitted by feb_swb_corun_plain_tb.
"""

from __future__ import annotations

import argparse
import collections
import csv
import re
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
REFERENCE_RBCAM_CASE = (
    "feb_egress_queueing_20260508/"
    "prof_int_002_feb_egress_periodic_asic0_full32_emu_direct_100k_"
    "1ms_gap1ms_20260508"
)
REFERENCE_PRE_RBCAM_CASE = REFERENCE_RBCAM_CASE
REFERENCE_POST_RBCAM_CASE = REFERENCE_RBCAM_CASE


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
class FrameRecord:
    stage: str
    lane: int
    frame_seq: int
    frame_id: int
    header_id: int
    ts_high: int
    ts_low: int
    sop_time_ps: int
    eop_time_ps: int
    word_count: int
    subheader_count: int
    nonempty_subheader_count: int
    hit_count: int


@dataclass
class CheckpointRecord:
    stage: str
    time_ps: int
    lane: int
    hit_id: int
    channel: int
    abs_ts_8ns: int
    hit_word: int
    dma_hit: int
    debug_meta: int


@dataclass
class DmaHit:
    time_ps: int
    word_idx: int
    slot: int
    hit_word: int
    end_of_event: int


@dataclass
class OpqNativeLog:
    summary: dict[str, int]
    lanes: list[dict[str, int]]
    issues: list[str]


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


def parse_debug_id(value: str) -> int:
    text = value.strip().lower()
    if text.startswith("0x"):
        text = text[2:]
        text = "".join("0" if char in "xz" else char for char in text)
        return int(text, 16)
    return int(text)


def load_pre_rbcam_reference(tb_int_root: Path) -> tuple[list[float], list[str]]:
    path = tb_int_root / "sim" / REFERENCE_PRE_RBCAM_CASE / "pre_rbcam_records.csv"
    values: list[float] = []
    issues: list[str] = []
    if not path.is_file():
        return values, [f"pre_rbcam_reference: missing {path}"]
    for row in read_csv(path):
        if row.get("run_origin", "1").strip() and int(row.get("run_origin", "1")) == 0:
            continue
        try:
            values.append(
                (int(row["abs_ts_pre_rbcam"]) - int(row["abs_ts_a"])) / 8000.0
            )
        except (KeyError, ValueError) as exc:
            issues.append(f"pre_rbcam_reference: malformed row in {path}: {exc}")
    return values, issues


def load_post_rbcam_reference(tb_int_root: Path) -> tuple[list[float], list[str]]:
    case_dir = tb_int_root / "sim" / REFERENCE_POST_RBCAM_CASE
    ingress_path = case_dir / "rbcam_ingress_trace.csv"
    post_path = case_dir / "post_rbcam_records.csv"
    values: list[float] = []
    issues: list[str] = []
    ingress: dict[int, tuple[int, int, int]] = {}
    if not ingress_path.is_file() or not post_path.is_file():
        return values, [f"post_rbcam_reference: missing {case_dir} trace CSVs"]

    for row in read_csv(ingress_path):
        if row.get("would_enter_deassembly") != "1":
            continue
        if row.get("metadata_valid") != "1":
            continue
        try:
            ingress[parse_debug_id(row["metadata_hex"])] = (
                int(row["time_ps"]),
                int(row["gts_8n"]),
                int(row["hit_ts8n"]),
            )
        except (KeyError, ValueError) as exc:
            issues.append(f"post_rbcam_reference: malformed ingress row: {exc}")

    for row in read_csv(post_path):
        if row.get("run_origin", "1").strip() and int(row.get("run_origin", "1")) == 0:
            continue
        try:
            metadata_id = parse_debug_id(row["root_hit_id"])
            anchor = ingress.get(metadata_id)
            if anchor is None:
                issues.append(f"post_rbcam_reference: missing DEBUG id {metadata_id}")
                continue
            ingress_time_ps, ingress_gts_8n, hit_ts8n = anchor
            elapsed_cycles = (int(row["abs_ts_post_rbcam"]) - ingress_time_ps) // 8000
            values.append(float((ingress_gts_8n + elapsed_cycles - hit_ts8n) % 8192))
        except (KeyError, ValueError) as exc:
            issues.append(f"post_rbcam_reference: malformed post row: {exc}")
    return values, issues


def validate_rbcam_reference(tb_int_root: Path) -> tuple[list[dict[str, object]], list[str]]:
    case_dir = tb_int_root / "sim" / REFERENCE_RBCAM_CASE
    rows: list[dict[str, object]] = []
    issues: list[str] = []

    def add(check: str, status: str, detail: str) -> None:
        rows.append(
            {
                "source_case": REFERENCE_RBCAM_CASE,
                "check": check,
                "status": status,
                "detail": detail,
            }
        )
        if status != "PASS":
            issues.append(f"rbcam_reference_{check}: {detail}")

    if not case_dir.is_dir():
        add("case_dir", "FAIL", f"missing {case_dir}")
        return rows, issues
    add("case_dir", "PASS", str(case_dir))

    drops_path = case_dir / "drops.csv"
    if not drops_path.is_file():
        add("drops_empty", "FAIL", f"missing {drops_path}")
    else:
        drop_rows = read_csv(drops_path)
        if drop_rows:
            last_seen = collections.Counter(
                row.get("last_seen_stage", "unknown") for row in drop_rows
            )
            detail = (
                f"{len(drop_rows)} drop rows; "
                + ";".join(f"{key}={value}" for key, value in sorted(last_seen.items()))
            )
            add("drops_empty", "FAIL", detail)
        else:
            add("drops_empty", "PASS", "no residual drop rows")

    counter_path = case_dir / "counter_agreement.csv"
    if not counter_path.is_file():
        add("counter_agreement", "FAIL", f"missing {counter_path}")
    else:
        counter_rows = read_csv(counter_path)
        bad_counters: list[str] = []
        for row in counter_rows:
            try:
                available = int(row.get("available", "0"))
                agree = int(row.get("agree", "0"))
            except ValueError:
                bad_counters.append(f"{row.get('counter', 'unknown')}: malformed")
                continue
            if available != 1 or agree != 1:
                bad_counters.append(
                    f"{row.get('counter', 'unknown')}: available={available} agree={agree}"
                )
        if bad_counters:
            add("counter_agreement", "FAIL", ";".join(bad_counters))
        else:
            add("counter_agreement", "PASS", f"{len(counter_rows)} counters agree")

    transcript_path = case_dir / "transcript"
    if not transcript_path.is_file():
        add("transcript", "FAIL", f"missing {transcript_path}")
    else:
        transcript = transcript_path.read_text(encoding="ascii", errors="ignore")
        if re.search(r"UVM_ERROR\s*:\s*0\b", transcript):
            add("transcript_uvm_error", "PASS", "UVM_ERROR=0")
        else:
            add("transcript_uvm_error", "FAIL", "missing clean UVM_ERROR=0 line")

        residual_lines = [
            line.strip()
            for line in transcript.splitlines()
            if ("residuals" in line or "stable_missing" in line) and "=" in line
        ]
        residual_bad: list[str] = []
        for line in residual_lines:
            spans: list[tuple[str, bool]] = []
            for start_token, end_tokens, expect_all_zero in (
                ("residuals fifo ", (" stable_missing ", " debug_obs "), False),
                ("debug_residuals ", (" debug_duplicate_ids=",), False),
                ("stable_missing ", (" debug_obs ", " debug_residuals "), True),
            ):
                if start_token not in line:
                    continue
                span = line.split(start_token, 1)[1]
                for end_token in end_tokens:
                    if end_token in span:
                        span = span.split(end_token, 1)[0]
                spans.append((span, expect_all_zero))
            for span, expect_all_zero in spans:
                for label, matched, missing, ghost in re.findall(
                    r"([A-Za-z0-9_>/\-]+)=([0-9]+)/([0-9]+)/([0-9]+)",
                    span,
                ):
                    if expect_all_zero:
                        if int(matched) != 0 or int(missing) != 0 or int(ghost) != 0:
                            residual_bad.append(f"{label}: values={matched}/{missing}/{ghost}")
                    elif int(missing) != 0 or int(ghost) != 0:
                        residual_bad.append(
                            f"{label}: matched={matched} missing={missing} ghost={ghost}"
                        )
        if residual_bad:
            add("transcript_residuals", "FAIL", ";".join(residual_bad))
        elif residual_lines:
            add("transcript_residuals", "PASS", "all reported missing/ghost residuals zero")
        else:
            add("transcript_residuals", "FAIL", "no residual summary lines found")

    return rows, issues


def write_rbcam_reference_trace(
    path: Path,
    pre_values: list[float],
    post_values: list[float],
) -> None:
    rows: list[dict[str, object]] = []
    for idx, value in enumerate(pre_values):
        rows.append(
            {
                "metric": "pre_rbcam_lifetime_cycles",
                "checkpoint": "pre-rbCAM full-FEB reference",
                "sample_index": idx,
                "lifetime_cycles": f"{value:.3f}",
                "source_case": REFERENCE_PRE_RBCAM_CASE,
            }
        )
    for idx, value in enumerate(post_values):
        rows.append(
            {
                "metric": "post_rbcam_lifetime_cycles",
                "checkpoint": "post-rbCAM DEBUG age reference",
                "sample_index": idx,
                "lifetime_cycles": f"{value:.3f}",
                "source_case": REFERENCE_POST_RBCAM_CASE,
            }
        )
    write_rows(
        path,
        ["metric", "checkpoint", "sample_index", "lifetime_cycles", "source_case"],
        rows,
    )


def write_reference_stats(
    path: Path,
    pre_values: list[float],
    post_values: list[float],
) -> None:
    rows: list[dict[str, object]] = []
    for metric, label, values in (
        ("pre_rbcam_lifetime_cycles", "pre-rbCAM full-FEB reference", pre_values),
        ("post_rbcam_lifetime_cycles", "post-rbCAM DEBUG age reference", post_values),
    ):
        if values:
            rows.append(
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
            rows.append(
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
    write_rows(
        path,
        [
            "metric",
            "checkpoint",
            "count",
            "min_cycles",
            "p50_cycles",
            "p95_cycles",
            "max_cycles",
            "mean_cycles",
        ],
        rows,
    )


def write_reference_health(path: Path, rows: list[dict[str, object]]) -> None:
    write_rows(path, ["source_case", "check", "status", "detail"], rows)


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


def parse_stream_frames(path: Path, stage: str, has_lane: bool) -> tuple[list[FrameRecord], list[str]]:
    frames: list[FrameRecord] = []
    issues: list[str] = []
    states: dict[int, FrameState] = {}
    seq_by_lane: dict[int, int] = collections.defaultdict(int)

    for row in read_csv(path):
        lane = int(row["lane"]) if has_lane else 0
        time_ps = int(row["time_ps"])
        datak = parse_hex(row["datak"])
        data = parse_hex(row["data"])
        low_byte = data & 0xFF
        sop = int(row.get("sop", "0"))
        eop = int(row.get("eop", "0"))

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
            continue

        if datak == 0x1 and low_byte == K284 and (eop or not has_lane):
            frames.append(
                FrameRecord(
                    stage=stage,
                    lane=lane,
                    frame_seq=seq_by_lane[lane],
                    frame_id=state.frame_id,
                    header_id=state.header_id,
                    ts_high=state.ts_high,
                    ts_low=state.ts_low,
                    sop_time_ps=state.sop_time_ps,
                    eop_time_ps=time_ps,
                    word_count=state.field_index,
                    subheader_count=state.current_hit_count16 >> 16,
                    nonempty_subheader_count=state.current_hit_count16 & 0xFFFF,
                    hit_count=state.current_hit_seen,
                )
            )
            seq_by_lane[lane] += 1
            states.pop(lane, None)
            continue

        state.field_index += 1
        if state.field_index == 1:
            state.ts_high = data
            continue
        if state.field_index == 2:
            state.ts_low = (data >> 16) & 0xFFFF
            state.frame_id = data & 0xFFFF
            continue
        if state.field_index <= 4:
            continue

        if datak == 0x1 and low_byte == K237:
            hit_count = (data >> 8) & 0xFFFF
            state.current_shd = (data >> 24) & 0xFF
            state.current_hit_count16 = state.current_hit_count16 + (1 << 16)
            if hit_count != 0:
                state.current_hit_count16 += 1
            state.current_hit_seen += hit_count

    for lane, state in states.items():
        issues.append(f"{stage}: unterminated frame lane={lane} frame={state.frame_id}")
    return frames, issues


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


def parse_checkpoint_hits(path: Path, stage: str) -> tuple[list[CheckpointRecord], list[str]]:
    hits: list[CheckpointRecord] = []
    issues: list[str] = []

    if not path.exists():
        return hits, [f"{stage}: missing checkpoint trace {path}"]

    for row in read_csv(path):
        hit_word = parse_hex(row["hit_word"])
        dma_hit = parse_hex(row["expected_dma_hit"])
        hits.append(
            CheckpointRecord(
                stage=stage,
                time_ps=int(row["time_ps"]),
                lane=int(row["lane"]),
                hit_id=int(row["hit_id"]),
                channel=int(row["channel"]),
                abs_ts_8ns=int(row["abs_ts_8ns"]),
                hit_word=hit_word,
                dma_hit=dma_hit,
                debug_meta=parse_hex(row.get("debug_meta", "0x0")),
            )
        )

    return hits, issues


def parse_opq_native_log(path: Path | None) -> OpqNativeLog:
    if path is None:
        return OpqNativeLog({}, [], ["opq_native_log: no log path supplied"])
    if not path.exists():
        return OpqNativeLog({}, [], [f"opq_native_log: missing {path}"])

    summary: dict[str, int] = {}
    lanes: list[dict[str, int]] = []
    for line in path.read_text(encoding="ascii", errors="ignore").splitlines():
        if "OPQ_NATIVE_SUMMARY" not in line and "OPQ_NATIVE_LANE_SUMMARY" not in line:
            continue
        fields: dict[str, int] = {}
        for token in line.strip().split():
            if "=" not in token:
                continue
            key, value = token.split("=", 1)
            try:
                fields[key] = int(value, 0)
            except ValueError:
                continue
        if "OPQ_NATIVE_LANE_SUMMARY" in line:
            lanes.append(fields)
        else:
            summary = fields

    issues: list[str] = []
    if not summary:
        issues.append(f"opq_native_log: no OPQ_NATIVE_SUMMARY in {path}")
    if not lanes:
        issues.append(f"opq_native_log: no OPQ_NATIVE_LANE_SUMMARY in {path}")
    return OpqNativeLog(summary, lanes, issues)


def opq_drop_counters(opq_log: OpqNativeLog) -> dict[str, int]:
    counters: dict[str, int] = {}
    for key, value in opq_log.summary.items():
        if "drop" in key:
            counters[f"summary.{key}"] = value
    for lane_info in opq_log.lanes:
        lane = lane_info.get("lane", len(counters))
        for key, value in lane_info.items():
            if "drop" in key:
                counters[f"lane{lane}.{key}"] = value
    return counters


def write_opq_native_summary(path: Path, opq_log: OpqNativeLog) -> None:
    rows: list[dict[str, object]] = []
    for key, value in sorted(opq_log.summary.items()):
        rows.append({"scope": "summary", "lane": "", "counter": key, "value": value})
    for lane_info in opq_log.lanes:
        lane = lane_info.get("lane", "")
        for key, value in sorted(lane_info.items()):
            if key == "lane":
                continue
            rows.append({"scope": "lane", "lane": lane, "counter": key, "value": value})
    write_rows(path, ["scope", "lane", "counter", "value"], rows)


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
    ("pre_rbcam_lifetime_cycles", "pre-rbCAM"),
    ("post_rbcam_lifetime_cycles", "post-rbCAM"),
    ("feb_egress_lifetime_cycles", "FEB egress"),
    ("opq_ingress_lifetime_cycles", "OPQ ingress"),
    ("opq_egress_lifetime_cycles", "OPQ egress"),
    ("dma_lifetime_cycles", "DMA"),
]


def cycles_from_source_time(time_ps: int | None, source_time_ps: int | None) -> str:
    if time_ps is None or source_time_ps is None:
        return ""
    return f"{(time_ps - source_time_ps) / 8000.0:.3f}"


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
        value = row.get(metric, "")
        if value == "":
            continue
        values.append(float(value))
    return values


def format_float(value: float | None) -> str:
    if value is None:
        return ""
    return f"{value:.3f}"


def frame_id_list(values: set[int]) -> str:
    return ";".join(str(value) for value in sorted(values))


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


def build_opq_queue_model(
    ingress_frames: list[FrameRecord],
    opq_frames: list[FrameRecord],
    lifetime_rows: list[dict[str, object]],
    expected_lane: int,
    expected_channel_count: int,
) -> tuple[list[dict[str, object]], dict[str, float | int | str]]:
    ingress_by_frame = {
        frame.frame_id: frame
        for frame in ingress_frames
        if frame.lane == expected_lane
    }
    opq_by_frame = {frame.frame_id: frame for frame in opq_frames}
    source_samples_by_frame: dict[int, set[int]] = collections.defaultdict(set)
    delivered_samples_by_frame: dict[int, set[int]] = collections.defaultdict(set)
    source_hits_by_frame: dict[int, int] = collections.defaultdict(int)
    delivered_hits_by_frame: dict[int, int] = collections.defaultdict(int)

    for row in lifetime_rows:
        frame_id = int(row["frame_id"])
        hit_id = int(row["hit_id"])
        sample_id = hit_id // expected_channel_count
        source_samples_by_frame[frame_id].add(sample_id)
        source_hits_by_frame[frame_id] += 1
        if row.get("opq_egress_time_ps", "") != "":
            delivered_samples_by_frame[frame_id].add(sample_id)
            delivered_hits_by_frame[frame_id] += 1

    model_rows: list[dict[str, object]] = []
    paired_frame_ids = sorted(set(ingress_by_frame) & set(opq_by_frame))
    queue_model_wait_cycles: float | None = None
    previous_ingress_sop_ps: int | None = None
    previous_opq_sop_ps: int | None = None
    ingress_iats: list[float] = []
    service_iats: list[float] = []
    wait_values: list[float] = []
    residual_values: list[float] = []
    loss_wait_values: list[float] = []
    clean_wait_values: list[float] = []
    nonempty_clean_wait_values: list[float] = []
    first_loss_frame_seq = -1
    first_loss_frame_id = -1
    first_loss_wait_cycles = 0.0
    pre_loss_clean_wait_values: list[float] = []

    for frame_seq, frame_id in enumerate(paired_frame_ids):
        ingress = ingress_by_frame[frame_id]
        opq = opq_by_frame[frame_id]
        ingress_iat_cycles = (
            (ingress.sop_time_ps - previous_ingress_sop_ps) / 8000.0
            if previous_ingress_sop_ps is not None
            else None
        )
        service_iat_cycles = (
            (opq.sop_time_ps - previous_opq_sop_ps) / 8000.0
            if previous_opq_sop_ps is not None
            else None
        )
        frame_wait_cycles = (opq.sop_time_ps - ingress.sop_time_ps) / 8000.0
        if queue_model_wait_cycles is None:
            queue_model_wait_cycles = frame_wait_cycles
        elif ingress_iat_cycles is not None and service_iat_cycles is not None:
            queue_model_wait_cycles += service_iat_cycles - ingress_iat_cycles
        residual_cycles = frame_wait_cycles - queue_model_wait_cycles

        if ingress_iat_cycles is not None:
            ingress_iats.append(ingress_iat_cycles)
        if service_iat_cycles is not None:
            service_iats.append(service_iat_cycles)
        wait_values.append(frame_wait_cycles)
        residual_values.append(abs(residual_cycles))

        source_samples = source_samples_by_frame.get(frame_id, set())
        delivered_samples = delivered_samples_by_frame.get(frame_id, set())
        missing_samples = source_samples - delivered_samples
        missing_hits = source_hits_by_frame[frame_id] - delivered_hits_by_frame[frame_id]
        if missing_hits:
            if first_loss_frame_seq < 0:
                first_loss_frame_seq = frame_seq
                first_loss_frame_id = frame_id
                first_loss_wait_cycles = frame_wait_cycles
            loss_wait_values.append(frame_wait_cycles)
        else:
            clean_wait_values.append(frame_wait_cycles)
            if source_hits_by_frame[frame_id] > 0:
                nonempty_clean_wait_values.append(frame_wait_cycles)
            if first_loss_frame_seq < 0:
                pre_loss_clean_wait_values.append(frame_wait_cycles)

        model_rows.append(
            {
                "frame_seq": frame_seq,
                "frame_id": frame_id,
                "ingress_sop_time_ps": ingress.sop_time_ps,
                "opq_sop_time_ps": opq.sop_time_ps,
                "ingress_iat_cycles": format_float(ingress_iat_cycles),
                "opq_service_iat_cycles": format_float(service_iat_cycles),
                "opq_frame_wait_cycles": format_float(frame_wait_cycles),
                "queue_model_wait_cycles": format_float(queue_model_wait_cycles),
                "queue_model_residual_cycles": format_float(residual_cycles),
                "input_hits": source_hits_by_frame[frame_id],
                "output_hits": delivered_hits_by_frame[frame_id],
                "missing_hits": missing_hits,
                "input_samples": frame_id_list(source_samples),
                "output_samples": frame_id_list(delivered_samples),
                "missing_samples": frame_id_list(missing_samples),
            }
        )
        previous_ingress_sop_ps = ingress.sop_time_ps
        previous_opq_sop_ps = opq.sop_time_ps

    mean_ingress_iat = sum(ingress_iats) / len(ingress_iats) if ingress_iats else 0.0
    mean_service_iat = sum(service_iats) / len(service_iats) if service_iats else 0.0
    rho = mean_service_iat / mean_ingress_iat if mean_ingress_iat > 0.0 else 0.0
    stats: dict[str, float | int | str] = {
        "opq_input_frame_count": len(ingress_by_frame),
        "opq_output_frame_count": len(opq_by_frame),
        "opq_paired_frame_count": len(paired_frame_ids),
        "opq_input_frame_iat_min_cycles": min(ingress_iats) if ingress_iats else 0.0,
        "opq_input_frame_iat_p50_cycles": percentile(ingress_iats, 50) if ingress_iats else 0.0,
        "opq_input_frame_iat_p95_cycles": percentile(ingress_iats, 95) if ingress_iats else 0.0,
        "opq_input_frame_iat_max_cycles": max(ingress_iats) if ingress_iats else 0.0,
        "opq_input_frame_iat_mean_cycles": mean_ingress_iat,
        "opq_service_iat_min_cycles": min(service_iats) if service_iats else 0.0,
        "opq_service_iat_p50_cycles": percentile(service_iats, 50) if service_iats else 0.0,
        "opq_service_iat_p95_cycles": percentile(service_iats, 95) if service_iats else 0.0,
        "opq_service_iat_max_cycles": max(service_iats) if service_iats else 0.0,
        "opq_service_iat_mean_cycles": mean_service_iat,
        "opq_utilization_mean": rho,
        "opq_frame_rho_mean": rho,
        "opq_queue_wait_min_cycles": min(wait_values) if wait_values else 0.0,
        "opq_queue_wait_max_cycles": max(wait_values) if wait_values else 0.0,
        "opq_queue_model_residual_max_abs_cycles": max(residual_values)
        if residual_values
        else 0.0,
        "opq_clean_wait_max_cycles": max(clean_wait_values) if clean_wait_values else 0.0,
        "opq_nonempty_clean_wait_max_cycles": max(nonempty_clean_wait_values)
        if nonempty_clean_wait_values
        else 0.0,
        "opq_loss_wait_min_cycles": min(loss_wait_values) if loss_wait_values else 0.0,
        "opq_first_loss_frame_seq": first_loss_frame_seq,
        "opq_first_loss_frame_id": first_loss_frame_id,
        "opq_first_loss_wait_cycles": first_loss_wait_cycles,
        "opq_pre_loss_clean_wait_max_cycles": max(pre_loss_clean_wait_values)
        if pre_loss_clean_wait_values
        else 0.0,
        "opq_queue_regime": "OVERLOADED" if rho > 1.0 else "STABLE",
    }
    return model_rows, stats


def write_opq_queue_summary(path: Path, stats: dict[str, float | int | str]) -> None:
    with path.open("w", encoding="ascii") as handle:
        for key in sorted(stats):
            value = stats[key]
            if isinstance(value, float):
                handle.write(f"{key}={value:.3f}\n")
            else:
                handle.write(f"{key}={value}\n")


def write_range_validation(
    path: Path,
    lifetime_rows: list[dict[str, object]],
    opq_stats: dict[str, float | int | str],
) -> list[dict[str, object]]:
    opq_min = float(opq_stats.get("opq_queue_wait_min_cycles", 0.0))
    opq_max = float(opq_stats.get("opq_queue_wait_max_cycles", 0.0))
    specs = [
        (
            "pre_rbcam",
            "pre_rbcam_lifetime_cycles",
            0.0,
            0.0,
            "synthetic pass-through marker in feb_swb_corun; not real rbCAM latency",
        ),
        (
            "post_rbcam",
            "post_rbcam_lifetime_cycles",
            0.0,
            0.0,
            "synthetic pass-through marker in feb_swb_corun; not real rbCAM latency",
        ),
        (
            "feb_egress",
            "feb_egress_lifetime_cycles",
            2049.0,
            6143.0,
            "profile-specific FEB store-and-forward lifetime from carried hit GTS",
        ),
        (
            "opq_ingress",
            "opq_ingress_lifetime_cycles",
            2049.0,
            6159.0,
            "FEB store-and-forward plus parallel CDC/direct SWB ingress adapter range",
        ),
        (
            "opq_egress",
            "opq_egress_lifetime_cycles",
            max(0.0, 2049.0 + opq_min - 512.0),
            6159.0 + opq_max + 512.0,
            "lossless finite-burst OPQ queue-model envelope from measured frame service recurrence",
        ),
        (
            "dma",
            "dma_lifetime_cycles",
            max(0.0, 2049.0 + opq_min - 512.0),
            6159.0 + opq_max + 1024.0,
            "lossless OPQ queue-model envelope plus DMA packing allowance",
        ),
    ]
    rows: list[dict[str, object]] = []
    for checkpoint, metric, low, high, note in specs:
        values = metric_values(lifetime_rows, metric)
        observed_min = min(values) if values else None
        observed_max = max(values) if values else None
        status = "PASS"
        if not values:
            status = "MISSING"
        elif observed_min is None or observed_max is None:
            status = "MISSING"
        elif observed_min < low or observed_max > high:
            status = "FAIL"
        rows.append(
            {
                "checkpoint": checkpoint,
                "metric": metric,
                "count": len(values),
                "range_low_cycles": format_float(low),
                "range_high_cycles": format_float(high),
                "observed_min_cycles": format_float(observed_min),
                "observed_max_cycles": format_float(observed_max),
                "status": status,
                "note": note,
            }
        )
    write_rows(
        path,
        [
            "checkpoint",
            "metric",
            "count",
            "range_low_cycles",
            "range_high_cycles",
            "observed_min_cycles",
            "observed_max_cycles",
            "status",
            "note",
        ],
        rows,
    )
    return rows


def time_value(row: dict[str, object], key: str) -> int | None:
    value = row.get(key, "")
    if value == "" or value is None:
        return None
    return int(value)


def write_tunnel_scoreboard(
    path: Path,
    lifetime_rows: list[dict[str, object]],
    opq_stats: dict[str, float | int | str],
) -> tuple[list[dict[str, object]], dict[str, int]]:
    opq_max = float(opq_stats.get("opq_queue_wait_max_cycles", 0.0))
    specs = [
        ("source_to_pre_rbcam", "source_generation_time_ps", "pre_rbcam_time_ps", 0.0, 0.0),
        ("pre_to_post_rbcam", "pre_rbcam_time_ps", "post_rbcam_time_ps", 0.0, 0.0),
        ("post_rbcam_to_feb_egress", "post_rbcam_time_ps", "feb_egress_time_ps", 2049.0, 6143.0),
        ("feb_egress_to_opq_ingress", "feb_egress_time_ps", "opq_ingress_time_ps", 0.0, 16.0),
        ("opq_ingress_to_opq_egress", "opq_ingress_time_ps", "opq_egress_time_ps", 0.0, opq_max + 512.0),
        ("opq_egress_to_dma", "opq_egress_time_ps", "dma_time_ps", 0.0, 512.0),
    ]
    rows: list[dict[str, object]] = []
    summary: dict[str, int] = collections.defaultdict(int)
    for hit in lifetime_rows:
        for tunnel, a_key, b_key, low, high in specs:
            a_time = time_value(hit, a_key)
            b_time = time_value(hit, b_key)
            if a_time is None or b_time is None:
                latency = None
                status = "MISSING"
            else:
                latency = (b_time - a_time) / 8000.0
                status = "PASS" if low <= latency <= high else "FAIL"
            rows.append(
                {
                    "tunnel": tunnel,
                    "hit_id": hit["hit_id"],
                    "channel": hit["channel"],
                    "frame_id": hit["frame_id"],
                    "latency_cycles": format_float(latency),
                    "range_low_cycles": format_float(low),
                    "range_high_cycles": format_float(high),
                    "status": status,
                }
            )
            summary[f"{tunnel}_{status.lower()}"] += 1
            if status != "PASS":
                summary["fail_or_missing"] += 1
    write_rows(
        path,
        [
            "tunnel",
            "hit_id",
            "channel",
            "frame_id",
            "latency_cycles",
            "range_low_cycles",
            "range_high_cycles",
            "status",
        ],
        rows,
    )
    return rows, dict(summary)


def write_factual_scoreboard(path: Path, hit_rows: list[dict[str, object]]) -> dict[str, int]:
    rows: list[dict[str, object]] = []
    summary: dict[str, int] = collections.defaultdict(int)
    for row in hit_rows:
        expected = str(row["expected_dma_hit"])
        actual = str(row["actual_dma_hit"])
        checks = str(row["checks"])
        factual_status = "PASS" if actual == expected else "FAIL"
        debug_status = "PASS"
        if any(token.startswith("debug_") and token.endswith("=FAIL") for token in checks.split(";")):
            debug_status = "FAIL"
        rows.append(
            {
                "hit_id": row["hit_id"],
                "channel": row["source_channel"],
                "abs_ts_8ns": row["abs_ts_8ns"],
                "frame_id": row["frame_id"],
                "expected_dma_hit": expected,
                "actual_dma_hit": actual,
                "factual_status": factual_status,
                "debug_status": debug_status,
            }
        )
        summary[f"factual_{factual_status.lower()}"] += 1
        summary[f"debug_{debug_status.lower()}"] += 1
    write_rows(
        path,
        [
            "hit_id",
            "channel",
            "abs_ts_8ns",
            "frame_id",
            "expected_dma_hit",
            "actual_dma_hit",
            "factual_status",
            "debug_status",
        ],
        rows,
    )
    return dict(summary)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--trace-dir", required=True, type=Path)
    parser.add_argument("--expected-lane", default=0, type=int)
    parser.add_argument("--expected-asic", default=0, type=int)
    parser.add_argument("--expected-channel", default=-1, type=int)
    parser.add_argument("--expected-channel-count", default=32, type=int)
    parser.add_argument("--expected-hit-period-8ns", default=1250, type=int)
    parser.add_argument("--opq-log", type=Path)
    parser.add_argument("--assume-opq-lossless", action="store_true")
    args = parser.parse_args()

    trace_dir = args.trace_dir
    source_hits, source_issues = parse_checkpoint_hits(
        trace_dir / "feb_swb_source_trace.csv",
        "source_generation",
    )
    pre_rbcam_hits, pre_rbcam_issues = parse_checkpoint_hits(
        trace_dir / "feb_swb_pre_rbcam_trace.csv",
        "pre_rbcam",
    )
    post_rbcam_hits, post_rbcam_issues = parse_checkpoint_hits(
        trace_dir / "feb_swb_post_rbcam_trace.csv",
        "post_rbcam",
    )
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
    ingress_frames, ingress_frame_issues = parse_stream_frames(
        trace_dir / "feb_swb_ingress_trace.csv",
        "opq_ingress",
        has_lane=True,
    )
    opq_frames, opq_frame_issues = parse_stream_frames(
        trace_dir / "feb_swb_opq_trace.csv",
        "opq_egress",
        has_lane=False,
    )
    dma_hits, padding_words = parse_dma_hits(trace_dir / "feb_swb_dma_trace.csv")
    opq_log = parse_opq_native_log(args.opq_log)
    tb_int_root = Path(__file__).resolve().parents[2]
    pre_rbcam_reference, pre_rbcam_reference_issues = load_pre_rbcam_reference(
        tb_int_root
    )
    post_rbcam_reference, post_rbcam_reference_issues = load_post_rbcam_reference(
        tb_int_root
    )
    rbcam_reference_health, rbcam_reference_health_issues = validate_rbcam_reference(
        tb_int_root
    )

    source_index = build_index(source_hits, lambda item: item.dma_hit)
    pre_rbcam_index = build_index(pre_rbcam_hits, lambda item: item.dma_hit)
    post_rbcam_index = build_index(post_rbcam_hits, lambda item: item.dma_hit)
    opq_ingress_index = build_index(opq_ingress_hits, lambda item: item.dma_hit)
    opq_egress_index = build_index(opq_egress_hits, lambda item: item.dma_hit)
    dma_index = build_index(dma_hits, lambda item: item.hit_word)

    hit_rows: list[dict[str, object]] = []
    lifetime_rows: list[dict[str, object]] = []
    failures: list[str] = []

    for expected in feb_hits:
        checks: list[str] = []
        payload_hit_id = source_hit_id(expected.hit_word)
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
        expected_full_hit_id = (sample_idx * args.expected_channel_count) + channel
        expected_payload_hit_id = expected_full_hit_id & 0x1FF
        expected_ts = expected.dma_hit & DMA_TS_MASK
        source_generation = pop_match(source_index, expected.dma_hit)
        pre_rbcam = pop_match(pre_rbcam_index, expected.dma_hit)
        post_rbcam = pop_match(post_rbcam_index, expected.dma_hit)
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
        require((abs_ts_8ns & 0x7) == source_rem(expected.hit_word), "source_ts_rem")
        require(
            args.expected_hit_period_8ns > 0
            and abs_ts_8ns % args.expected_hit_period_8ns == 0,
            "source_period",
        )
        require(payload_hit_id == expected_payload_hit_id, "source_hit_id_schedule")
        require(debug_level(expected.debug_meta) == 2, "debug_level")
        require(debug_lane(expected.debug_meta) == expected.lane, "debug_lane")
        require(debug_source(expected.debug_meta) == SOURCE_MUTRIG_EMU, "debug_source")
        require(debug_hit_id(expected.debug_meta) == expected_full_hit_id, "debug_hit_id")
        require(debug_ps(expected.debug_meta) == (abs_ts_8ns & 0xFF), "debug_ps")
        require(debug_ts(expected.debug_meta) == (abs_ts_8ns & 0xFFFF), "debug_ts")
        require(
            debug_ts(expected.debug_meta) == (expected_ts & 0xFFFF),
            "debug_ts_matches_dma",
        )
        require(source_generation is not None, "source_generation_present")
        if source_generation is not None:
            require(source_generation.lane == expected.lane, "source_generation_lane")
            require(source_generation.hit_id == expected_full_hit_id, "source_generation_hit_id")
            require(source_generation.channel == channel, "source_generation_channel")
            require(source_generation.abs_ts_8ns == abs_ts_8ns, "source_generation_ts")
            require(source_generation.hit_word == expected.hit_word, "source_generation_hit_word")
            require(source_generation.dma_hit == expected.dma_hit, "source_generation_dma_hit")
        require(pre_rbcam is not None, "pre_rbcam_present")
        if pre_rbcam is not None:
            require(pre_rbcam.lane == expected.lane, "pre_rbcam_lane")
            require(pre_rbcam.hit_id == expected_full_hit_id, "pre_rbcam_hit_id")
            require(pre_rbcam.channel == channel, "pre_rbcam_channel")
            require(pre_rbcam.abs_ts_8ns == abs_ts_8ns, "pre_rbcam_ts")
            require(pre_rbcam.hit_word == expected.hit_word, "pre_rbcam_hit_word")
            require(pre_rbcam.dma_hit == expected.dma_hit, "pre_rbcam_dma_hit")
            if source_generation is not None:
                require(pre_rbcam.time_ps >= source_generation.time_ps, "pre_rbcam_after_source")
        require(post_rbcam is not None, "post_rbcam_present")
        if post_rbcam is not None:
            require(post_rbcam.lane == expected.lane, "post_rbcam_lane")
            require(post_rbcam.hit_id == expected_full_hit_id, "post_rbcam_hit_id")
            require(post_rbcam.channel == channel, "post_rbcam_channel")
            require(post_rbcam.abs_ts_8ns == abs_ts_8ns, "post_rbcam_ts")
            require(post_rbcam.hit_word == expected.hit_word, "post_rbcam_hit_word")
            require(post_rbcam.dma_hit == expected.dma_hit, "post_rbcam_dma_hit")
            if pre_rbcam is not None:
                require(post_rbcam.time_ps >= pre_rbcam.time_ps, "post_rbcam_after_pre")
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
            require(dma_hit_id(dma.hit_word) == payload_hit_id, "dma_hit_id")
            require(dma_rem(dma.hit_word) == source_rem(expected.hit_word), "dma_rem")
            require(dma_fine(dma.hit_word) == source_fine(expected.hit_word), "dma_fine")
            require(dma_ts_8ns(dma.hit_word) == expected_ts, "dma_ts")
            require(dma_ts_8ns(dma.hit_word) == abs_ts_8ns, "dma_abs_ts")

        if status != "PASS":
            failures.append(
                f"hit_id={expected_full_hit_id} channel={channel} checks={';'.join(checks)}"
            )

        lifetime_origin_time_ps = abs_ts_8ns * 8000
        hit_rows.append(
            {
                "status": status,
                "hit_id": expected_full_hit_id,
                "payload_hit_id": payload_hit_id,
                "lane": expected.lane,
                "source_asic": source_asic(expected.hit_word),
                "source_channel": channel,
                "abs_ts_8ns": abs_ts_8ns,
                "frame_id": expected.frame_id,
                "frame_base_8ns": base,
                "shd_ts": expected.shd_ts,
                "bucket_start_8ns": bucket_start,
                "bucket_end_8ns": bucket_end,
                "source_generation_time_ps": source_generation.time_ps
                if source_generation is not None
                else -1,
                "pre_rbcam_time_ps": pre_rbcam.time_ps if pre_rbcam is not None else -1,
                "post_rbcam_time_ps": post_rbcam.time_ps if post_rbcam is not None else -1,
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
                "debug_ps_tag": debug_ps(expected.debug_meta),
                "debug_ts_tag": debug_ts(expected.debug_meta),
                "debug_hit_id": debug_hit_id(expected.debug_meta),
                "lifetime_origin_time_ps": lifetime_origin_time_ps,
                "checks": ";".join(checks),
            }
        )
        lifetime_rows.append(
            {
                "status": status,
                "hit_id": expected_full_hit_id,
                "channel": channel,
                "abs_ts_8ns": abs_ts_8ns,
                "frame_id": expected.frame_id,
                "shd_ts": expected.shd_ts,
                "source_generation_time_ps": source_generation.time_ps
                if source_generation is not None
                else "",
                "pre_rbcam_time_ps": pre_rbcam.time_ps if pre_rbcam is not None else "",
                "post_rbcam_time_ps": post_rbcam.time_ps if post_rbcam is not None else "",
                "feb_egress_time_ps": expected.time_ps,
                "opq_ingress_time_ps": opq_ingress.time_ps if opq_ingress is not None else "",
                "opq_egress_time_ps": opq_egress.time_ps if opq_egress is not None else "",
                "dma_time_ps": dma.time_ps if dma is not None else "",
                "pre_rbcam_lifetime_cycles": cycles_from_source_time(
                    pre_rbcam.time_ps if pre_rbcam is not None else None,
                    lifetime_origin_time_ps,
                ),
                "post_rbcam_lifetime_cycles": cycles_from_source_time(
                    post_rbcam.time_ps if post_rbcam is not None else None,
                    lifetime_origin_time_ps,
                ),
                "feb_egress_lifetime_cycles": cycles_from_source_time(
                    expected.time_ps,
                    lifetime_origin_time_ps,
                ),
                "opq_ingress_lifetime_cycles": cycles_from_source_time(
                    opq_ingress.time_ps if opq_ingress is not None else None,
                    lifetime_origin_time_ps,
                ),
                "opq_egress_lifetime_cycles": cycles_from_source_time(
                    opq_egress.time_ps if opq_egress is not None else None,
                    lifetime_origin_time_ps,
                ),
                "dma_lifetime_cycles": cycles_from_source_time(
                    dma.time_ps if dma is not None else None,
                    lifetime_origin_time_ps,
                ),
                "lifetime_origin_time_ps": lifetime_origin_time_ps,
                "lifetime_origin_abs_ts_8ns": abs_ts_8ns,
                "debug_ps_tag": debug_ps(expected.debug_meta),
                "debug_ts_tag": debug_ts(expected.debug_meta),
                "debug_hit_id": debug_hit_id(expected.debug_meta),
            }
        )

    ghost_source = sum(len(items) for items in source_index.values())
    ghost_pre_rbcam = sum(len(items) for items in pre_rbcam_index.values())
    ghost_post_rbcam = sum(len(items) for items in post_rbcam_index.values())
    ghost_opq_ingress = sum(len(items) for items in opq_ingress_index.values())
    ghost_opq_egress = sum(len(items) for items in opq_egress_index.values())
    ghost_dma = sum(len(items) for items in dma_index.values())
    if ghost_source:
        failures.append(f"ghost_source_generation_hits={ghost_source}")
    if ghost_pre_rbcam:
        failures.append(f"ghost_pre_rbcam_hits={ghost_pre_rbcam}")
    if ghost_post_rbcam:
        failures.append(f"ghost_post_rbcam_hits={ghost_post_rbcam}")
    if ghost_opq_ingress:
        failures.append(f"ghost_opq_ingress_hits={ghost_opq_ingress}")
    if ghost_opq_egress:
        failures.append(f"ghost_opq_egress_hits={ghost_opq_egress}")
    if ghost_dma:
        failures.append(f"ghost_dma_hits={ghost_dma}")
    failures.extend(feb_issues)
    failures.extend(source_issues)
    failures.extend(pre_rbcam_issues)
    failures.extend(post_rbcam_issues)
    failures.extend(ingress_issues)
    failures.extend(opq_issues)
    failures.extend(ingress_frame_issues)
    failures.extend(opq_frame_issues)
    failures.extend(pre_rbcam_reference_issues)
    failures.extend(post_rbcam_reference_issues)
    failures.extend(rbcam_reference_health_issues)
    if args.assume_opq_lossless:
        failures.extend(opq_log.issues)
        nonzero_drop_counters = {
            key: value
            for key, value in opq_drop_counters(opq_log).items()
            if value != 0
        }
        for key, value in sorted(nonzero_drop_counters.items()):
            failures.append(f"opq_lossless_drop_counter {key}={value}")

    hit_trace_path = trace_dir / "feb_swb_hit_trace_debug.csv"
    lifetime_trace_path = trace_dir / "feb_swb_lifetime_trace.csv"
    lifetime_stats_path = trace_dir / "feb_swb_lifetime_hist_stats.csv"
    opq_queue_model_path = trace_dir / "feb_swb_opq_queue_model.csv"
    opq_queue_summary_path = trace_dir / "feb_swb_opq_queue_summary.txt"
    range_validation_path = trace_dir / "feb_swb_range_validation.csv"
    tunnel_scoreboard_path = trace_dir / "feb_swb_tunnel_scoreboard.csv"
    factual_scoreboard_path = trace_dir / "feb_swb_factual_scoreboard.csv"
    opq_native_summary_path = trace_dir / "feb_swb_opq_native_summary.csv"
    rbcam_reference_trace_path = trace_dir / "feb_swb_rbcam_reference_trace.csv"
    rbcam_reference_stats_path = trace_dir / "feb_swb_rbcam_reference_stats.csv"
    rbcam_reference_health_path = trace_dir / "feb_swb_rbcam_reference_health.csv"
    summary_path = trace_dir / "feb_swb_trace_debug_summary.txt"
    write_rows(
        hit_trace_path,
        [
            "status",
            "hit_id",
            "payload_hit_id",
            "lane",
            "source_asic",
            "source_channel",
            "abs_ts_8ns",
            "frame_id",
            "frame_base_8ns",
            "shd_ts",
            "bucket_start_8ns",
            "bucket_end_8ns",
            "source_generation_time_ps",
            "pre_rbcam_time_ps",
            "post_rbcam_time_ps",
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
            "debug_ps_tag",
            "debug_ts_tag",
            "debug_hit_id",
            "lifetime_origin_time_ps",
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
            "source_generation_time_ps",
            "pre_rbcam_time_ps",
            "post_rbcam_time_ps",
            "feb_egress_time_ps",
            "opq_ingress_time_ps",
            "opq_egress_time_ps",
            "dma_time_ps",
            "pre_rbcam_lifetime_cycles",
            "post_rbcam_lifetime_cycles",
            "feb_egress_lifetime_cycles",
            "opq_ingress_lifetime_cycles",
            "opq_egress_lifetime_cycles",
            "dma_lifetime_cycles",
            "lifetime_origin_time_ps",
            "lifetime_origin_abs_ts_8ns",
            "debug_ps_tag",
            "debug_ts_tag",
            "debug_hit_id",
        ],
        lifetime_rows,
    )
    write_lifetime_stats(lifetime_stats_path, lifetime_rows)
    write_rbcam_reference_trace(
        rbcam_reference_trace_path,
        pre_rbcam_reference,
        post_rbcam_reference,
    )
    write_reference_stats(
        rbcam_reference_stats_path,
        pre_rbcam_reference,
        post_rbcam_reference,
    )
    write_reference_health(rbcam_reference_health_path, rbcam_reference_health)
    opq_queue_rows, opq_queue_stats = build_opq_queue_model(
        ingress_frames,
        opq_frames,
        lifetime_rows,
        args.expected_lane,
        args.expected_channel_count,
    )
    write_rows(
        opq_queue_model_path,
        [
            "frame_seq",
            "frame_id",
            "ingress_sop_time_ps",
            "opq_sop_time_ps",
            "ingress_iat_cycles",
            "opq_service_iat_cycles",
            "opq_frame_wait_cycles",
            "queue_model_wait_cycles",
            "queue_model_residual_cycles",
            "input_hits",
            "output_hits",
            "missing_hits",
            "input_samples",
            "output_samples",
            "missing_samples",
        ],
        opq_queue_rows,
    )
    write_opq_queue_summary(opq_queue_summary_path, opq_queue_stats)
    range_rows = write_range_validation(
        range_validation_path,
        lifetime_rows,
        opq_queue_stats,
    )
    tunnel_rows, tunnel_summary = write_tunnel_scoreboard(
        tunnel_scoreboard_path,
        lifetime_rows,
        opq_queue_stats,
    )
    factual_summary = write_factual_scoreboard(factual_scoreboard_path, hit_rows)
    write_opq_native_summary(opq_native_summary_path, opq_log)

    pass_rows = sum(1 for row in hit_rows if row["status"] == "PASS")
    opq_drop_counter_total = sum(opq_drop_counters(opq_log).values())
    with summary_path.open("w", encoding="ascii") as handle:
        handle.write(f"source_generation_hits={len(source_hits)}\n")
        handle.write(f"pre_rbcam_hits={len(pre_rbcam_hits)}\n")
        handle.write(f"post_rbcam_hits={len(post_rbcam_hits)}\n")
        handle.write(f"pre_rbcam_reference_hits={len(pre_rbcam_reference)}\n")
        handle.write(f"post_rbcam_reference_hits={len(post_rbcam_reference)}\n")
        handle.write(
            f"rbcam_reference_issue_count={len(pre_rbcam_reference_issues) + len(post_rbcam_reference_issues)}\n"
        )
        handle.write(f"rbcam_reference_health_issue_count={len(rbcam_reference_health_issues)}\n")
        handle.write(f"expected_feb_hits={len(feb_hits)}\n")
        handle.write(f"opq_ingress_hits={len(opq_ingress_hits)}\n")
        handle.write(f"opq_egress_hits={len(opq_egress_hits)}\n")
        handle.write(f"opq_ingress_frames={len(ingress_frames)}\n")
        handle.write(f"opq_egress_frames={len(opq_frames)}\n")
        handle.write(f"dma_hits={len(dma_hits)}\n")
        handle.write(f"padding_words={padding_words}\n")
        handle.write(f"assume_opq_lossless={1 if args.assume_opq_lossless else 0}\n")
        handle.write(f"opq_drop_counter_total={opq_drop_counter_total}\n")
        handle.write(f"pass_hits={pass_rows}\n")
        handle.write(f"fail_hits={len(hit_rows) - pass_rows}\n")
        handle.write(f"ghost_source_generation_hits={ghost_source}\n")
        handle.write(f"ghost_pre_rbcam_hits={ghost_pre_rbcam}\n")
        handle.write(f"ghost_post_rbcam_hits={ghost_post_rbcam}\n")
        handle.write(f"ghost_opq_ingress_hits={ghost_opq_ingress}\n")
        handle.write(f"ghost_opq_egress_hits={ghost_opq_egress}\n")
        handle.write(f"ghost_dma_hits={ghost_dma}\n")
        for key in sorted(opq_queue_stats):
            value = opq_queue_stats[key]
            if isinstance(value, float):
                handle.write(f"{key}={value:.3f}\n")
            else:
                handle.write(f"{key}={value}\n")
        handle.write(
            "range_validation_failures="
            f"{sum(1 for row in range_rows if row['status'] != 'PASS')}\n"
        )
        handle.write(
            "tunnel_scoreboard_failures="
            f"{sum(1 for row in tunnel_rows if row['status'] != 'PASS')}\n"
        )
        for key in sorted(tunnel_summary):
            handle.write(f"tunnel_{key}={tunnel_summary[key]}\n")
        for key in sorted(factual_summary):
            handle.write(f"{key}={factual_summary[key]}\n")
        handle.write(f"issue_count={len(failures)}\n")
        for failure in failures:
            handle.write(f"issue={failure}\n")
        for issue in pre_rbcam_reference_issues[:32]:
            handle.write(f"reference_issue={issue}\n")
        for issue in post_rbcam_reference_issues[:32]:
            handle.write(f"reference_issue={issue}\n")

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
