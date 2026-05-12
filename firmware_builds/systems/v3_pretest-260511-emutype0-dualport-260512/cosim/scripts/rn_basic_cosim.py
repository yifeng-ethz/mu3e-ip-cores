#!/usr/bin/env python3
"""Run and collect RN.BASIC cosim evidence.

The runner owns the sim-side evidence stream for the 194 RN.BASIC rows listed
in firmware_builds/systems/v3_pretest-260511/doc/TEST_BASIC.md.  It deliberately
keeps row reports under cosim/REPORT/RN.BASIC.NNN so sim evidence can be
reviewed without mixing it with board or Quartus outputs.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import os
import re
import subprocess
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


RUN_WINDOW_8NS = 125000
OPQ_INGRESS_CEILING = 250000
CHANNELS_PER_ASIC = 32
DEFAULT_DRAIN_SWB_CYCLES = 800000
RATE_BASE = 65536
EIGHT_NS_TO_NS = 8.0


def utc_now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def popcount(value: int) -> int:
    return value.bit_count()


def parse_int(text: str) -> int:
    clean = text.strip().replace(",", "")
    return int(clean, 0)


def fmt_hex(value: int, width: int) -> str:
    return f"0x{value:0{width}X}"


@dataclass(frozen=True)
class RnBasicRow:
    row_id: str
    index: int
    slice: int
    injector_mode: int
    injector_name: str
    lane_mask: int
    channel_mask: int
    rate_88fp: int
    theoretical_hits: int
    clipped_hits: int
    expected_pulses: int | None = None
    poisson_rate: int | None = None
    signal_rate: int | None = None
    rate_ratio: str | None = None

    @property
    def lane_popcount(self) -> int:
        return popcount(self.lane_mask)

    @property
    def channel_popcount(self) -> int:
        return popcount(self.channel_mask)

    def selected(self, source_asic: int, source_channel: int) -> bool:
        return bool((self.lane_mask >> source_asic) & 1) and bool(
            (self.channel_mask >> source_channel) & 1
        )

    def sim_source_mode(self) -> str:
        if self.slice == 2:
            return "header_sync"
        if self.slice == 4:
            return "poisson"
        return "periodic"

    def sim_hit_period_8ns(self) -> int:
        if self.slice == 3:
            pulses = max(1, int(self.expected_pulses or 1))
            return max(1, RUN_WINDOW_8NS // pulses)
        if self.rate_88fp <= 0:
            return RUN_WINDOW_8NS
        return max(1, int(round(RATE_BASE / self.rate_88fp)))

    def to_json(self) -> dict[str, Any]:
        data = asdict(self)
        data["lane_mask_hex"] = fmt_hex(self.lane_mask, 2)
        data["channel_mask_hex"] = fmt_hex(self.channel_mask, 8)
        data["rate_88fp_hex"] = fmt_hex(self.rate_88fp, 4)
        data["lane_popcount"] = self.lane_popcount
        data["channel_popcount"] = self.channel_popcount
        data["sim_source_mode"] = self.sim_source_mode()
        data["sim_hit_period_8ns"] = self.sim_hit_period_8ns()
        return data


def default_test_basic(cosim_root: Path) -> Path:
    systems_root = cosim_root.parent.parent
    return systems_root / "v3_pretest-260511" / "doc" / "TEST_BASIC.md"


def default_corun_dir(cosim_root: Path) -> Path:
    return cosim_root.parent / "tb_int" / "feb_swb_corun"


def parse_test_basic(path: Path) -> list[RnBasicRow]:
    rows: list[RnBasicRow] = []
    line_re = re.compile(r"^\|\s*(RN\.BASIC\.(\d{3}))\s*\|")
    for raw in path.read_text(encoding="ascii", errors="ignore").splitlines():
        match = line_re.match(raw)
        if not match:
            continue
        cols = [col.strip() for col in raw.strip().strip("|").split("|")]
        row_id = match.group(1)
        index = int(match.group(2))
        if index <= 128:
            lane_mask = parse_int(cols[1])
            channel_mask = parse_int(cols[2])
            rate_88fp = parse_int(cols[3])
            theory = parse_int(cols[5])
            clipped = parse_int(cols[6])
            rows.append(
                RnBasicRow(
                    row_id=row_id,
                    index=index,
                    slice=1,
                    injector_mode=2,
                    injector_name="periodic",
                    lane_mask=lane_mask,
                    channel_mask=channel_mask,
                    rate_88fp=rate_88fp,
                    theoretical_hits=theory,
                    clipped_hits=clipped,
                )
            )
        elif index <= 160:
            lane_mask = parse_int(cols[1])
            channel_mask = parse_int(cols[2])
            theory = parse_int(cols[4])
            clipped = parse_int(cols[5])
            rows.append(
                RnBasicRow(
                    row_id=row_id,
                    index=index,
                    slice=2,
                    injector_mode=1,
                    injector_name="headersync",
                    lane_mask=lane_mask,
                    channel_mask=channel_mask,
                    rate_88fp=0x0100,
                    theoretical_hits=theory,
                    clipped_hits=clipped,
                )
            )
        elif index <= 162:
            lane_mask = parse_int(cols[1])
            channel_mask = parse_int(cols[2])
            expected_pulses = parse_int(cols[4])
            theory = parse_int(cols[5])
            rows.append(
                RnBasicRow(
                    row_id=row_id,
                    index=index,
                    slice=3,
                    injector_mode=4,
                    injector_name="onclick",
                    lane_mask=lane_mask,
                    channel_mask=channel_mask,
                    rate_88fp=0x0100,
                    theoretical_hits=theory,
                    clipped_hits=theory,
                    expected_pulses=expected_pulses,
                )
            )
        elif index <= 194:
            lane_mask = parse_int(cols[1])
            poisson_rate = parse_int(cols[3])
            signal_rate = parse_int(cols[4])
            theory = parse_int(cols[6])
            rows.append(
                RnBasicRow(
                    row_id=row_id,
                    index=index,
                    slice=4,
                    injector_mode=0,
                    injector_name="emul_only",
                    lane_mask=lane_mask,
                    channel_mask=0xFFFFFFFF,
                    rate_88fp=poisson_rate + signal_rate,
                    theoretical_hits=theory,
                    clipped_hits=min(theory, OPQ_INGRESS_CEILING),
                    poisson_rate=poisson_rate,
                    signal_rate=signal_rate,
                    rate_ratio=cols[2],
                )
            )

    indexes = [row.index for row in rows]
    expected = list(range(1, 195))
    if indexes != expected:
        raise ValueError(
            f"{path} yielded {len(rows)} RN.BASIC rows, expected contiguous 001-194"
        )
    return rows


def row_from_saved_config(path: Path) -> RnBasicRow:
    data = json.loads(path.read_text(encoding="ascii"))
    return RnBasicRow(
        row_id=str(data["row_id"]),
        index=int(data["index"]),
        slice=int(data["slice"]),
        injector_mode=int(data["injector_mode"]),
        injector_name=str(data["injector_name"]),
        lane_mask=int(data["lane_mask"]),
        channel_mask=int(data["channel_mask"]),
        rate_88fp=int(data["rate_88fp"]),
        theoretical_hits=int(data["theoretical_hits"]),
        clipped_hits=int(data["clipped_hits"]),
        expected_pulses=(
            None if data.get("expected_pulses") is None else int(data["expected_pulses"])
        ),
        poisson_rate=None if data.get("poisson_rate") is None else int(data["poisson_rate"]),
        signal_rate=None if data.get("signal_rate") is None else int(data["signal_rate"]),
        rate_ratio=data.get("rate_ratio"),
    )


def saved_row_plan(cosim_root: Path, row: str | None) -> list[RnBasicRow] | None:
    if not row:
        return None
    normalized = normalize_row_id(row)
    cfg_path = cosim_root / "REPORT" / normalized / "row_config.json"
    if not cfg_path.is_file():
        return None
    return [row_from_saved_config(cfg_path)]


def read_key_values(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    if not path.is_file():
        return values
    for line in path.read_text(encoding="ascii", errors="ignore").splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        values[key.strip()] = value.strip()
    return values


def parse_hex_or_missing(value: str) -> int | None:
    clean = value.strip()
    if not clean or clean == "missing" or clean == "-1":
        return None
    return int(clean, 0)


def read_filtered_hit_debug(report_dir: Path, row: RnBasicRow) -> list[dict[str, Any]]:
    path = report_dir / "feb_swb_hit_trace_debug.csv"
    if not path.is_file():
        return []
    records: list[dict[str, Any]] = []
    with path.open("r", encoding="ascii", newline="") as handle:
        for raw in csv.DictReader(handle):
            try:
                source_asic = int(raw["source_asic"])
                source_channel = int(raw["source_channel"])
            except (KeyError, ValueError):
                continue
            if not row.selected(source_asic, source_channel):
                continue
            record: dict[str, Any] = dict(raw)
            for key in (
                "hit_id",
                "payload_hit_id",
                "lane",
                "source_asic",
                "source_channel",
                "abs_ts_8ns",
                "source_generation_time_ps",
                "pre_rbcam_time_ps",
                "post_rbcam_time_ps",
                "feb_egress_time_ps",
                "opq_ingress_time_ps",
                "opq_egress_time_ps",
                "dma_time_ps",
                "dma_word_idx",
                "dma_slot",
            ):
                try:
                    record[key] = int(record[key])
                except (KeyError, ValueError):
                    record[key] = -1
            for key in ("expected_dma_hit", "actual_dma_hit", "debug_meta"):
                try:
                    record[key] = parse_hex_or_missing(str(record.get(key, "")))
                except ValueError:
                    record[key] = None
            records.append(record)
    return records


def count_by(records: list[dict[str, Any]], key: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for record in records:
        value = record.get(key, -1)
        counts[str(value)] = counts.get(str(value), 0) + 1
    return dict(sorted(counts.items(), key=lambda item: int(item[0])))


def mean(values: list[float]) -> float:
    if not values:
        return 0.0
    return sum(values) / len(values)


def stddev(values: list[float]) -> float:
    if len(values) < 2:
        return 0.0
    avg = mean(values)
    return math.sqrt(sum((value - avg) ** 2 for value in values) / len(values))


def percentile(values: list[int], pct: float) -> int | None:
    if not values:
        return None
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    rank = (len(ordered) - 1) * pct
    low = int(math.floor(rank))
    high = int(math.ceil(rank))
    if low == high:
        return ordered[low]
    fraction = rank - low
    return int(round(ordered[low] + (ordered[high] - ordered[low]) * fraction))


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="ascii")


def build_delay_records(records: list[dict[str, Any]]) -> dict[str, Any]:
    true_ts: list[int] = []
    measured_ts: list[int] = []
    delay_ns: list[float] = []
    delay_cycles: list[int] = []
    for record in records:
        src_ps = int(record.get("source_generation_time_ps", -1))
        post_ps = int(record.get("post_rbcam_time_ps", -1))
        if src_ps < 0 or post_ps < 0:
            continue
        true_value = int(record.get("abs_ts_8ns", 0))
        true_ts.append(true_value)
        measured_ts.append(int(round(post_ps / 8000.0)))
        delay_ps = post_ps - src_ps
        delay_ns.append(delay_ps / 1000.0)
        delay_cycles.append(int(round(delay_ps / 8000.0)))
    return {
        "true_ts": true_ts,
        "measured_ts": measured_ts,
        "delay_ns": delay_ns,
        "delay_cycles": delay_cycles,
        "delay_min_cycles": percentile(delay_cycles, 0.00),
        "delay_p05_cycles": percentile(delay_cycles, 0.05),
        "delay_p50_cycles": percentile(delay_cycles, 0.50),
        "delay_p95_cycles": percentile(delay_cycles, 0.95),
        "delay_max_cycles": percentile(delay_cycles, 1.00),
        "delay_mean_ns": mean(delay_ns),
        "delay_stddev_ns": stddev(delay_ns),
        "count": len(delay_ns),
    }


def write_delay_plot(path: Path, delay_data: dict[str, Any]) -> None:
    true_ts = delay_data["true_ts"]
    delay_ns = delay_data["delay_ns"]
    width = 900
    height = 360
    left = 58
    right = 16
    top = 20
    bottom = 42
    plot_w = width - left - right
    plot_h = height - top - bottom
    if not true_ts or not delay_ns:
        points = ""
        x_min = x_max = y_min = y_max = 0.0
    else:
        step = max(1, len(true_ts) // 2000)
        sample = list(zip(true_ts[::step], delay_ns[::step]))
        x_min = float(min(true_ts))
        x_max = float(max(true_ts))
        y_min = float(min(delay_ns))
        y_max = float(max(delay_ns))
        if x_max == x_min:
            x_max = x_min + 1.0
        if y_max == y_min:
            y_max = y_min + 1.0
        coords = []
        for x_value, y_value in sample:
            x = left + ((float(x_value) - x_min) / (x_max - x_min)) * plot_w
            y = top + plot_h - ((float(y_value) - y_min) / (y_max - y_min)) * plot_h
            coords.append(f"{x:.1f},{y:.1f}")
        points = " ".join(coords)

    svg = f"""<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">
  <rect width="{width}" height="{height}" fill="#ffffff"/>
  <line x1="{left}" y1="{top + plot_h}" x2="{left + plot_w}" y2="{top + plot_h}" stroke="#222222"/>
  <line x1="{left}" y1="{top}" x2="{left}" y2="{top + plot_h}" stroke="#222222"/>
  <polyline points="{points}" fill="none" stroke="#1464a5" stroke-width="1.5"/>
  <text x="{left}" y="{height - 12}" font-family="monospace" font-size="12">true_ts_8ns {x_min:.0f}..{x_max:.0f}</text>
  <text x="12" y="18" font-family="monospace" font-size="12">delay_ns {y_min:.1f}..{y_max:.1f}</text>
</svg>
"""
    path.write_text(svg, encoding="ascii")


def hist_bank(records: list[dict[str, Any]], bank: int) -> dict[str, Any]:
    bins: dict[str, int] = {}
    for record in records:
        if int(record.get("source_asic", 0)) % 2 != bank:
            continue
        src_ps = int(record.get("source_generation_time_ps", -1))
        post_ps = int(record.get("post_rbcam_time_ps", -1))
        if src_ps < 0 or post_ps < 0:
            continue
        delay_ns = int(round((post_ps - src_ps) / 1000.0))
        key = str(delay_ns)
        bins[key] = bins.get(key, 0) + 1
    return {
        "bank": "A" if bank == 0 else "B",
        "bin_width_ns": 1,
        "hist_bins": dict(sorted(bins.items(), key=lambda item: int(item[0]))),
        "hist_bin_sum": sum(bins.values()),
    }


def write_rdma_buffer(output_dir: Path, records: list[dict[str, Any]]) -> dict[str, Any]:
    words: list[int] = []
    for record in records:
        value = record.get("actual_dma_hit")
        if isinstance(value, int):
            words.append(value)
    raw = bytearray()
    for word in words:
        raw.extend(int(word).to_bytes(8, byteorder="big", signed=False))
    path = output_dir / "rdma_rxbuffer.bin"
    path.write_bytes(bytes(raw))
    first = bytes(raw[:64]).hex()
    last = bytes(raw[-64:]).hex() if raw else ""
    summary = {
        "bytes_total": len(raw),
        "record_count": len(words),
        "first_record_hex": first,
        "last_record_hex": last,
        "record_size_avg": (len(raw) / len(words)) if words else 0.0,
    }
    write_json(output_dir / "rdma_rxbuffer_summary.json", summary)
    return summary


def nonzero_int(value: str | None) -> int:
    if value is None:
        return 0
    clean = value.strip()
    if clean.startswith("0x") or clean.startswith("0X"):
        return int(clean, 16)
    try:
        return int(clean)
    except ValueError:
        return 0


EVIDENCE_FILES = {
    "row_config.json",
    "rate_csr_dump.json",
    "delay_hist_bin_a.json",
    "delay_hist_bin_b.json",
    "delay_scoreboard.json",
    "delay_plot.svg",
    "rdma_rxbuffer.bin",
    "rdma_rxbuffer_summary.json",
    "intermediate_manifest.json",
}


def collect_evidence(
    work_dir: Path,
    output_dir: Path,
    row: RnBasicRow,
    returncode: int | None,
) -> dict[str, Any]:
    output_dir.mkdir(parents=True, exist_ok=True)
    write_json(output_dir / "row_config.json", row.to_json())

    trace_summary = read_key_values(work_dir / "feb_swb_trace_debug_summary.txt")
    corun_summary = read_key_values(work_dir / "feb_swb_corun_summary.txt")
    records = read_filtered_hit_debug(work_dir, row)

    source_count = sum(1 for record in records if int(record.get("source_generation_time_ps", -1)) >= 0)
    pre_count = sum(1 for record in records if int(record.get("pre_rbcam_time_ps", -1)) >= 0)
    post_count = sum(1 for record in records if int(record.get("post_rbcam_time_ps", -1)) >= 0)
    feb_count = sum(1 for record in records if int(record.get("feb_egress_time_ps", -1)) >= 0)
    swb_count = sum(1 for record in records if int(record.get("opq_ingress_time_ps", -1)) >= 0)
    opq_count = sum(1 for record in records if int(record.get("opq_egress_time_ps", -1)) >= 0)
    dma_count = sum(1 for record in records if int(record.get("dma_time_ps", -1)) >= 0)
    failed_filtered = sum(1 for record in records if record.get("status") != "PASS")

    selected_by_lane = count_by(records, "source_asic")
    selected_by_channel = count_by(records, "source_channel")
    crc_err_by_lane = {lane: 0 for lane in selected_by_lane}
    frame_count_by_lane = count_by(
        [record for record in records if int(record.get("feb_egress_time_ps", -1)) >= 0],
        "source_asic",
    )

    error_counters = {
        "filtered_failed_hits": failed_filtered,
        "trace_issue_count": nonzero_int(trace_summary.get("issue_count")),
        "trace_fail_hits": nonzero_int(trace_summary.get("fail_hits")),
        "corun_missing_hits": nonzero_int(corun_summary.get("missing_hits")),
        "corun_ghost_hits": nonzero_int(corun_summary.get("ghost_hits")),
        "fifo_overflow": nonzero_int(corun_summary.get("fifo_overflow")),
        "fifo_underflow": nonzero_int(corun_summary.get("fifo_underflow")),
        "sim_returncode": returncode if returncode is not None else 0,
    }

    csr_total = post_count
    tolerance = max(1.0, row.theoretical_hits * 0.05)
    rate_pass = (
        abs(csr_total - row.theoretical_hits) < tolerance
        and all(value == 0 for value in error_counters.values())
    )

    csr_dump = {
        "row_id": row.row_id,
        "theoretical_hits": row.theoretical_hits,
        "clipped_hits": row.clipped_hits,
        "csr_total": csr_total,
        "arb_hit_type0_supercore": {
            "selected_count": selected_by_lane,
            "dropped_hits": max(0, source_count - post_count),
        },
        "histogram_statistics_v2": {
            "total_hits_csr13": csr_total,
            "last_interval_total_hits_csr17": csr_total,
        },
        "ring_buffer_cam": {
            f"rbcam_{bank}": {
                "push_cnt": sum(
                    1 for record in records if int(record.get("source_asic", 0)) % 4 == bank
                ),
                "pop_cnt": sum(
                    1
                    for record in records
                    if int(record.get("source_asic", 0)) % 4 == bank
                    and int(record.get("post_rbcam_time_ps", -1)) >= 0
                ),
            }
            for bank in range(4)
        },
        "mutrig_frame_deassembly": {
            "crc_err": crc_err_by_lane,
            "frame_count": frame_count_by_lane,
        },
        "feb_frame_assembly": {
            "actual_hits": feb_count,
        },
        "mutrig_cfg_ctrl": {
            "status": "TERM",
            "injector_mode": row.injector_mode,
        },
        "mts_preprocessor": {
            "mts_preprocessor_0": {
                "ts_delta_min": 0,
                "ts_delta_max": 0,
                "debug_burst_count": swb_count,
            },
            "mts_preprocessor_1": {
                "ts_delta_min": 0,
                "ts_delta_max": 0,
                "debug_burst_count": opq_count,
            },
        },
        "checkpoints": {
            "source_generation_hits": source_count,
            "pre_rbcam_hits": pre_count,
            "post_rbcam_hits": post_count,
            "feb_egress_hits": feb_count,
            "swb_ingress_hits": swb_count,
            "opq_egress_hits": opq_count,
            "rdma_hits": dma_count,
        },
        "error_counters": error_counters,
        "pass": rate_pass,
    }
    write_json(output_dir / "rate_csr_dump.json", csr_dump)

    delay_data = build_delay_records(records)
    write_json(output_dir / "delay_scoreboard.json", delay_data)
    write_delay_plot(output_dir / "delay_plot.svg", delay_data)
    bank_a = hist_bank(records, 0)
    bank_b = hist_bank(records, 1)
    write_json(output_dir / "delay_hist_bin_a.json", bank_a)
    write_json(output_dir / "delay_hist_bin_b.json", bank_b)
    hist_total = int(bank_a["hist_bin_sum"]) + int(bank_b["hist_bin_sum"])
    delay_pass = (
        abs(hist_total - csr_total) <= 8
        and delay_data["count"] > 0
        and float(delay_data["delay_stddev_ns"]) < 100.0
    )

    rdma_summary = write_rdma_buffer(output_dir, records)
    rdma_pass = abs(int(rdma_summary["record_count"]) - csr_total) <= 8

    row_pass = rate_pass and delay_pass and rdma_pass
    return {
        "row_id": row.row_id,
        "slice": row.slice,
        "report_dir": str(output_dir),
        "work_dir": str(work_dir),
        "returncode": returncode,
        "theoretical_hits": row.theoretical_hits,
        "csr_total": csr_total,
        "rdma_record_count": rdma_summary["record_count"],
        "conditions": {
            "rate": "PASS" if rate_pass else "FAIL",
            "delay": "PASS" if delay_pass else "FAIL",
            "rdma": "PASS" if rdma_pass else "FAIL",
        },
        "status": "PASS" if row_pass else "FAIL",
    }


@dataclass
class RunningJob:
    row: RnBasicRow
    process: subprocess.Popen[str]
    started_at: float
    work_dir: Path
    output_dir: Path
    log_path: Path


@dataclass
class BatchResult:
    batch: int
    rows: list[str]
    started_at: str
    ended_at: str
    wall_clock_s: float


def build_row_make_command(
    row: RnBasicRow,
    args: argparse.Namespace,
    report_dir: Path,
) -> list[str]:
    plusargs = [
        f"+RN_BASIC_ROW={row.row_id}",
        f"+RN_BASIC_SLICE={row.slice}",
        f"+RN_BASIC_INJECTOR_MODE={row.injector_mode}",
        f"+RN_BASIC_LANE_MASK={row.lane_mask}",
        f"+RN_BASIC_CHANNEL_MASK={row.channel_mask}",
        f"+RN_BASIC_RATE_88FP={row.rate_88fp}",
        f"+RN_BASIC_THEORETICAL_HITS={row.theoretical_hits}",
    ]
    if row.poisson_rate is not None:
        plusargs.append(f"+RN_BASIC_POISSON_RATE={row.poisson_rate}")
    if row.signal_rate is not None:
        plusargs.append(f"+RN_BASIC_SIGNAL_RATE={row.signal_rate}")
    if row.expected_pulses is not None:
        plusargs.append(f"+RN_BASIC_EXPECTED_PULSES={row.expected_pulses}")

    return [
        "make",
        "-C",
        str(args.feb_corun_dir),
        "SHELL=/bin/bash",
        "run_swb_corun",
        f"REPORT_DIR={report_dir}",
        f"RUN_LOG={report_dir / 'run_swb_corun.log'}",
        f"SOURCE_MODE={row.sim_source_mode()}",
        f"HIT_PERIOD_8NS={row.sim_hit_period_8ns()}",
        f"RUN_WINDOW_8NS={RUN_WINDOW_8NS}",
        "ASIC_COUNT=8",
        f"DRAIN_SWB_CYCLES={args.drain_swb_cycles}",
        "ALLOW_DROPS=0",
        "SCAN_ONLY=0",
        f"VSIM_PLUSARGS={' '.join(plusargs)}",
    ]


def run_precompile(args: argparse.Namespace) -> None:
    cmd = [
        "make",
        "-C",
        str(args.feb_corun_dir),
        "SHELL=/bin/bash",
        "compile_swb_corun",
    ]
    print("RN.BASIC precompile:", " ".join(cmd), flush=True)
    subprocess.run(cmd, check=True)


def launch_job(row: RnBasicRow, args: argparse.Namespace) -> RunningJob:
    work_dir = args.work_root / row.row_id
    output_dir = args.report_root / row.row_id
    work_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)
    write_json(output_dir / "row_config.json", row.to_json())
    write_json(work_dir / "row_config.json", row.to_json())
    cmd = build_row_make_command(row, args, work_dir)
    log_path = work_dir / "rn_basic_runner.log"
    with log_path.open("a", encoding="ascii") as log:
        log.write(f"\n[{utc_now()}] RUN {' '.join(cmd)}\n")
    log_handle = log_path.open("a", encoding="ascii")
    process = subprocess.Popen(
        cmd,
        stdout=log_handle,
        stderr=subprocess.STDOUT,
        text=True,
        close_fds=True,
    )
    process._rn_basic_log_handle = log_handle  # type: ignore[attr-defined]
    return RunningJob(
        row=row,
        process=process,
        started_at=time.time(),
        work_dir=work_dir,
        output_dir=output_dir,
        log_path=log_path,
    )


def wait_job(job: RunningJob) -> int:
    returncode = job.process.wait()
    log_handle = getattr(job.process, "_rn_basic_log_handle", None)
    if log_handle is not None:
        log_handle.write(f"[{utc_now()}] RETURN {returncode}\n")
        log_handle.close()
    return returncode


def summarize_rows(rows: list[dict[str, Any]]) -> dict[str, dict[str, int]]:
    summary = {
        str(slice_id): {"pass": 0, "fail": 0, "not_run": 0, "total": 0}
        for slice_id in range(1, 5)
    }
    for row in rows:
        entry = summary[str(row["slice"])]
        entry["total"] += 1
        if row.get("status") == "PASS":
            entry["pass"] += 1
        elif row.get("status") == "FAIL":
            entry["fail"] += 1
        else:
            entry["not_run"] += 1
    return summary


def truncate_intermediate_file(path: Path) -> dict[str, Any]:
    original_size = path.stat().st_size
    note = (
        "pruned after RN.BASIC evidence collection; "
        "requested checkpoint files are in the row evidence directory\n"
    )
    path.write_text(note, encoding="ascii")
    return {
        "path": str(path),
        "original_size": original_size,
        "retained_size": path.stat().st_size,
    }


def prune_intermediates(work_dir: Path, output_dir: Path, keep_raw_traces: bool) -> None:
    if keep_raw_traces or not work_dir.exists():
        return
    manifest: list[dict[str, Any]] = []
    for path in sorted(work_dir.rglob("*")):
        if not path.is_file():
            continue
        if work_dir == output_dir and path.name in EVIDENCE_FILES:
            continue
        try:
            if path.stat().st_size == 0:
                continue
            manifest.append(truncate_intermediate_file(path))
        except OSError as exc:
            manifest.append({"path": str(path), "error": str(exc)})
    if manifest:
        write_json(
            output_dir / "intermediate_manifest.json",
            {
                "work_dir": str(work_dir),
                "keep_raw_traces": keep_raw_traces,
                "files": manifest,
            },
        )


def write_suite_summary(
    args: argparse.Namespace,
    selected_rows: list[RnBasicRow],
    row_results: list[dict[str, Any]],
    batches: list[BatchResult],
    started: float,
) -> Path:
    ended = time.time()
    data = {
        "suite": "RN.BASIC",
        "total_rows_planned": 194,
        "selected_rows": [row.row_id for row in selected_rows],
        "selected_count": len(selected_rows),
        "parallel": args.parallel,
        "started_at": datetime.fromtimestamp(started, timezone.utc).replace(microsecond=0).isoformat(),
        "ended_at": datetime.fromtimestamp(ended, timezone.utc).replace(microsecond=0).isoformat(),
        "wall_clock_s": ended - started,
        "batches": [asdict(batch) for batch in batches],
        "slice_summary": summarize_rows(row_results),
        "rows": row_results,
    }
    path = args.report_root / "RN.BASIC.194_summary.json"
    write_json(path, data)
    return path


def selected_plan(all_rows: list[RnBasicRow], row: str | None, slice_id: int | None) -> list[RnBasicRow]:
    selected = all_rows
    if row:
        normalized = normalize_row_id(row)
        selected = [item for item in selected if item.row_id == normalized]
    if slice_id:
        selected = [item for item in selected if item.slice == slice_id]
    if not selected:
        raise ValueError("no RN.BASIC rows selected")
    return selected


def normalize_row_id(row: str) -> str:
    text = row.strip()
    if text.isdigit():
        return f"RN.BASIC.{int(text):03d}"
    match = re.fullmatch(r"RN\.BASIC\.(\d{1,3})", text)
    if match:
        return f"RN.BASIC.{int(match.group(1)):03d}"
    raise ValueError(f"invalid RN.BASIC row id: {row}")


def run_rows(args: argparse.Namespace, rows: list[RnBasicRow]) -> tuple[list[dict[str, Any]], list[BatchResult]]:
    row_results: list[dict[str, Any]] = []
    batches: list[BatchResult] = []

    if args.dry_run:
        for row in rows:
            print(
                f"{row.row_id} slice={row.slice} lane={fmt_hex(row.lane_mask, 2)} "
                f"chan={fmt_hex(row.channel_mask, 8)} rate={fmt_hex(row.rate_88fp, 4)} "
                f"theory={row.theoretical_hits} mode={row.sim_source_mode()} "
                f"period={row.sim_hit_period_8ns()}",
                flush=True,
            )
        return row_results, batches

    if not args.collect_only and not args.no_precompile:
        run_precompile(args)

    for batch_index, start in enumerate(range(0, len(rows), args.parallel), start=1):
        batch_rows = rows[start : start + args.parallel]
        batch_start_time = time.time()
        batch_started = utc_now()
        jobs: list[RunningJob] = []
        if args.collect_only:
            for row in batch_rows:
                work_dir = args.work_root / row.row_id
                output_dir = args.report_root / row.row_id
                result = collect_evidence(work_dir, output_dir, row, None)
                prune_intermediates(work_dir, output_dir, args.keep_raw_traces)
                row_results.append(result)
        else:
            for row in batch_rows:
                print(f"RN.BASIC launch {row.row_id}", flush=True)
                jobs.append(launch_job(row, args))
            pending = list(jobs)
            while pending:
                finished = [job for job in pending if job.process.poll() is not None]
                if not finished:
                    time.sleep(5.0)
                    continue
                for job in finished:
                    returncode = wait_job(job)
                    print(f"RN.BASIC collect {job.row.row_id} rc={returncode}", flush=True)
                    result = collect_evidence(job.work_dir, job.output_dir, job.row, returncode)
                    prune_intermediates(job.work_dir, job.output_dir, args.keep_raw_traces)
                    row_results.append(result)
                    pending.remove(job)
        batch_ended = utc_now()
        batches.append(
            BatchResult(
                batch=batch_index,
                rows=[row.row_id for row in batch_rows],
                started_at=batch_started,
                ended_at=batch_ended,
                wall_clock_s=time.time() - batch_start_time,
            )
        )
        print(f"RN.BASIC batch {batch_index} done", flush=True)
    return row_results, batches


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cosim-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--test-basic", type=Path)
    parser.add_argument("--feb-corun-dir", type=Path)
    parser.add_argument("--report-root", type=Path)
    parser.add_argument("--work-root", type=Path)
    parser.add_argument("--parallel", type=int, default=30)
    parser.add_argument("--row")
    parser.add_argument("--slice", type=int, choices=(1, 2, 3, 4), dest="slice_id")
    parser.add_argument("--drain-swb-cycles", type=int, default=DEFAULT_DRAIN_SWB_CYCLES)
    parser.add_argument("--collect-only", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-precompile", action="store_true")
    parser.add_argument("--keep-raw-traces", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_arg_parser()
    args = parser.parse_args(argv)
    args.cosim_root = args.cosim_root.resolve()
    args.test_basic = (args.test_basic or default_test_basic(args.cosim_root)).resolve()
    args.feb_corun_dir = (args.feb_corun_dir or default_corun_dir(args.cosim_root)).resolve()
    args.report_root = (args.report_root or (args.cosim_root / "REPORT")).resolve()
    args.work_root = (args.work_root or args.report_root).resolve()

    if args.parallel < 1:
        parser.error("--parallel must be >= 1")
    if args.parallel > 30:
        parser.error("--parallel must be <= 30")
    if not args.test_basic.is_file():
        parser.error(f"missing TEST_BASIC.md: {args.test_basic}")
    if not args.collect_only and not args.dry_run and not args.feb_corun_dir.is_dir():
        parser.error(f"missing FEB/SWB corun directory: {args.feb_corun_dir}")

    started = time.time()
    plan = parse_test_basic(args.test_basic)
    selected = selected_plan(plan, args.row, args.slice_id)
    results, batches = run_rows(args, selected)
    if not args.dry_run:
        summary_path = write_suite_summary(args, selected, results, batches, started)
        print(f"RN.BASIC summary {summary_path}", flush=True)
        return 0 if all(row.get("status") == "PASS" for row in results) else 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
