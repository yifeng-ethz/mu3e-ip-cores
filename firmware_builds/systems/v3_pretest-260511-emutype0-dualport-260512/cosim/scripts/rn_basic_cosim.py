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
import shutil
import subprocess
import sys
import time
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(REPO_ROOT / "scripts" / "cotest"))
from cosim_lifetime_analyzer import LifetimeAnalysisError, analyze_lifetime_dir  # noqa: E402

RUN_WINDOW_8NS = 125000
HIST_INTERVAL_CFG_CLOCKS = RUN_WINDOW_8NS
OPQ_INGRESS_CEILING = 250000
CHANNELS_PER_ASIC = 32
HIST_IP_RATE_BINS = 256
HIST_IP_DELAY_LEFT_CYCLES = -1000
HIST_IP_DELAY_RIGHT_CYCLES = 3096
HIST_IP_DELAY_BIN_WIDTH_CYCLES = 16
HIST_IP_KEY_LOC_PRE_RBCAM_GLOBAL_CHANNEL = (38 << 24) | (35 << 16) | (37 << 8) | 30
HIST_IP_KEY_LOC_POST_RBCAM_GLOBAL_CHANNEL = (38 << 24) | (35 << 16) | (24 << 8) | 17
HIST_IP_KEY_LOC_DEBUG_SAMPLE = (23 << 24) | (16 << 16) | (15 << 8) | 0
HIST_IP_CONTROL_RATE_PRESET = 0x00000101
HIST_IP_CONTROL_DELAY_PRESET = 0x00000091
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
        data["hist_interval_cfg_clocks"] = HIST_INTERVAL_CFG_CLOCKS
        data["hist_interval_ms"] = HIST_INTERVAL_CFG_CLOCKS * 8.0e-6
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
        return read_checkpoint_trace_fallback(report_dir, row)
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
    if not records:
        records = read_checkpoint_trace_fallback(report_dir, row)
    return records


def read_checkpoint_trace_fallback(report_dir: Path, row: RnBasicRow) -> list[dict[str, Any]]:
    """Rebuild the minimum per-hit ledger from preserved checkpoint traces.

    Older row reports may keep `feb_swb_pre_rbcam_trace.csv` and
    `feb_swb_post_rbcam_trace.csv` after pruning the richer debug trace.  The
    checkpoint traces are enough for rate and rbCAM delay histogram
    expectations.
    """
    stage_files = {
        "pre_rbcam_time_ps": report_dir / "feb_swb_pre_rbcam_trace.csv",
        "post_rbcam_time_ps": report_dir / "feb_swb_post_rbcam_trace.csv",
        "feb_egress_time_ps": report_dir / "feb_swb_feb_egress_trace.csv",
        "opq_ingress_time_ps": report_dir / "feb_swb_ingress_trace.csv",
        "opq_egress_time_ps": report_dir / "feb_swb_opq_trace.csv",
        "dma_time_ps": report_dir / "feb_swb_dma_trace.csv",
    }
    records_by_hit: dict[int, dict[str, Any]] = {}
    for stage_key, trace_path in stage_files.items():
        if not trace_path.is_file():
            continue
        with trace_path.open("r", encoding="ascii", newline="") as handle:
            for raw in csv.DictReader(handle):
                try:
                    hit_id = int(raw.get("hit_id", "-1"))
                    source_asic = int(raw.get("source_asic", "-1"))
                    channel = int(raw.get("channel", "-1"))
                    hit_ts_8ns = int(round(float(raw.get("hit_ts_8ns", "-1"))))
                    stage_abs_8ns = int(round(float(raw.get("abs_ts_8ns", "-1"))))
                except ValueError:
                    continue
                if hit_id < 0 or not row.selected(source_asic, channel):
                    continue
                record = records_by_hit.setdefault(
                    hit_id,
                    {
                        "hit_id": hit_id,
                        "payload_hit_id": int(raw.get("payload_hit_id", hit_id)),
                        "lane": source_asic,
                        "source_asic": source_asic,
                        "source_channel": channel,
                        "abs_ts_8ns": hit_ts_8ns,
                        "source_generation_time_ps": hit_ts_8ns * 8000,
                        "pre_rbcam_time_ps": -1,
                        "post_rbcam_time_ps": -1,
                        "feb_egress_time_ps": -1,
                        "opq_ingress_time_ps": -1,
                        "opq_egress_time_ps": -1,
                        "dma_time_ps": -1,
                        "expected_dma_hit": None,
                        "actual_dma_hit": None,
                        "debug_meta": None,
                    },
                )
                record[stage_key] = stage_abs_8ns * 8000
                record["hit_word"] = raw.get("hit_word", record.get("hit_word", ""))
    return [records_by_hit[key] for key in sorted(records_by_hit)]


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


def delay_cycles_at(records: list[dict[str, Any]], stage_key: str) -> list[float]:
    values: list[float] = []
    for record in records:
        src_ps = int(record.get("source_generation_time_ps", -1))
        stage_ps = int(record.get(stage_key, -1))
        if src_ps < 0 or stage_ps < 0:
            continue
        values.append(int(round((stage_ps - src_ps) / 8000.0)))
    return values


def delay_cycles_from_lifetime_trace(path: Path, column: str) -> list[float]:
    if not path.is_file():
        return []
    values: list[float] = []
    with path.open("r", encoding="ascii", newline="") as handle:
        for raw in csv.DictReader(handle):
            try:
                values.append(float(raw[column]))
            except (KeyError, ValueError):
                continue
    return values


def fixed_delay_hist(values: list[float]) -> dict[str, Any]:
    bin_count = (
        (HIST_IP_DELAY_RIGHT_CYCLES - HIST_IP_DELAY_LEFT_CYCLES)
        // HIST_IP_DELAY_BIN_WIDTH_CYCLES
    )
    bins = [0 for _ in range(bin_count)]
    underflow = 0
    overflow = 0
    for value in values:
        idx = int((value - HIST_IP_DELAY_LEFT_CYCLES) // HIST_IP_DELAY_BIN_WIDTH_CYCLES)
        if idx < 0:
            underflow += 1
        elif idx >= bin_count:
            overflow += 1
        else:
            bins[idx] += 1
    return {
        "left_bound_cycles": HIST_IP_DELAY_LEFT_CYCLES,
        "right_bound_cycles": HIST_IP_DELAY_RIGHT_CYCLES,
        "bin_width_cycles": HIST_IP_DELAY_BIN_WIDTH_CYCLES,
        "bin_count": bin_count,
        "underflow": underflow,
        "overflow": overflow,
        "hist_bins": bins,
        "hist_bin_sum": sum(bins),
        "count": len(values),
        "min_cycles": min(values, default=None),
        "max_cycles": max(values, default=None),
        "p50_cycles": percentile(values, 0.50),
    }


def build_hist_ip_expectation(row: RnBasicRow,
                              records: list[dict[str, Any]],
                              lifetime_trace_path: Path | None = None) -> dict[str, Any]:
    rate_bins = [0 for _ in range(HIST_IP_RATE_BINS)]
    for record in records:
        if int(record.get("post_rbcam_time_ps", -1)) < 0:
            continue
        source_asic = int(record.get("source_asic", -1))
        channel = int(record.get("source_channel", -1))
        global_channel = ((source_asic & 0x7) * CHANNELS_PER_ASIC) + channel
        if 0 <= channel < CHANNELS_PER_ASIC and 0 <= global_channel < HIST_IP_RATE_BINS:
            rate_bins[global_channel] += 1

    active_indices = [
        asic * CHANNELS_PER_ASIC + channel
        for asic in range(8)
        for channel in range(CHANNELS_PER_ASIC)
        if row.selected(asic, channel)
    ]
    active_index_set = set(active_indices)
    active_bins = [rate_bins[idx] for idx in active_indices]
    inactive_sum = sum(
        count for idx, count in enumerate(rate_bins)
        if idx not in active_index_set
    )
    pre_values: list[float] = []
    post_values: list[float] = []
    if lifetime_trace_path is not None:
        pre_values = delay_cycles_from_lifetime_trace(
            lifetime_trace_path,
            "pre_rbcam_lifetime_cycles",
        )
        post_values = delay_cycles_from_lifetime_trace(
            lifetime_trace_path,
            "post_rbcam_lifetime_cycles",
        )
    if not pre_values:
        pre_values = delay_cycles_at(records, "pre_rbcam_time_ps")
    if not post_values:
        post_values = delay_cycles_at(records, "post_rbcam_time_ps")
    active_channels = row.lane_popcount * row.channel_popcount
    observed_total = sum(active_bins)
    expected_per_channel = (
        observed_total / max(1, active_channels)
        if active_channels else 0.0
    )
    expected_theoretical_per_channel = (
        row.theoretical_hits / max(1, active_channels)
        if active_channels else 0.0
    )
    return {
        "row_id": row.row_id,
        "histogram_statistics_v2_csr": {
            "rate_pre_rbcam_preset": {
                "LEFT_BOUND": 0,
                "RIGHT_BOUND": 255,
                "BIN_WIDTH": 1,
                "KEY_LOC": f"0x{HIST_IP_KEY_LOC_PRE_RBCAM_GLOBAL_CHANNEL:08X}",
                "KEY_LOC_FIELD": "hit_type1_data[37:30] = {asic[2:0], channel[4:0]}",
                "CONTROL_APPLY": f"0x{HIST_IP_CONTROL_RATE_PRESET:08X}",
                "INTERVAL_CFG": HIST_INTERVAL_CFG_CLOCKS,
                "interval_ms": HIST_INTERVAL_CFG_CLOCKS * 8.0e-6,
            },
            "rate_post_rbcam_preset": {
                "LEFT_BOUND": 0,
                "RIGHT_BOUND": 255,
                "BIN_WIDTH": 1,
                "KEY_LOC": f"0x{HIST_IP_KEY_LOC_POST_RBCAM_GLOBAL_CHANNEL:08X}",
                "KEY_LOC_FIELD": "padded_hit_type2_data[24:17] = {asic[2:0], channel[4:0]}",
                "CONTROL_APPLY": f"0x{HIST_IP_CONTROL_RATE_PRESET:08X}",
                "INTERVAL_CFG": HIST_INTERVAL_CFG_CLOCKS,
                "interval_ms": HIST_INTERVAL_CFG_CLOCKS * 8.0e-6,
            },
            "delay_preset": {
                "LEFT_BOUND": HIST_IP_DELAY_LEFT_CYCLES,
                "RIGHT_BOUND": HIST_IP_DELAY_RIGHT_CYCLES,
                "BIN_WIDTH": HIST_IP_DELAY_BIN_WIDTH_CYCLES,
                "KEY_LOC": f"0x{HIST_IP_KEY_LOC_DEBUG_SAMPLE:08X}",
                "CONTROL_APPLY": f"0x{HIST_IP_CONTROL_DELAY_PRESET:08X}",
                "CONTROL_MODE": "-7 signed debug_1/debug_2",
                "INTERVAL_CFG": HIST_INTERVAL_CFG_CLOCKS,
                "interval_ms": HIST_INTERVAL_CFG_CLOCKS * 8.0e-6,
            },
        },
        "rate_256ch": {
            "hist_bins": rate_bins,
            "active_channels": active_channels,
            "expected_total_per_ms": observed_total,
            "expected_plan_total_per_ms": row.clipped_hits,
            "expected_per_active_channel_per_ms": expected_per_channel,
            "expected_theoretical_per_active_channel_per_ms": expected_theoretical_per_channel,
            "active_min": min(active_bins, default=0),
            "active_p50": percentile(active_bins, 0.50),
            "active_max": max(active_bins, default=0),
            "active_sum": sum(active_bins),
            "inactive_sum": inactive_sum,
        },
        "delay_cycles": {
            "pre_rbcam": fixed_delay_hist(pre_values),
            "post_rbcam": fixed_delay_hist(post_values),
        },
    }


SWB_K285 = 0xBC
SWB_K284 = 0x9C
SWB_K237 = 0xF7
PACKET_TYPE_IDLE = 0b000000
PACKET_TYPE_SCIFI = {0b111000, 0b111001}


def rdma_word_has_k(
    words: list[int],
    k_masks: list[int] | None,
    idx: int,
    marker: int,
) -> bool:
    if idx < 0 or idx >= len(words):
        return False
    if (words[idx] & 0xFF) != marker:
        return False
    if k_masks is None or idx >= len(k_masks):
        return True
    return bool(k_masks[idx] & 0x1)


def decode_rdma_wire_words(
    words: list[int],
    k_masks: list[int] | None = None,
) -> tuple[list[dict[str, Any]], list[int], list[int] | None]:
    frames: list[dict[str, Any]] = []
    trimmed: list[int] = []
    trimmed_k: list[int] = []
    idx = 0
    while idx < len(words):
        if not rdma_word_has_k(words, k_masks, idx, SWB_K285):
            idx += 1
            continue
        start = idx
        if idx + 5 >= len(words):
            frames.append({
                "start_word": start,
                "end_word": len(words) - 1,
                "timestamp": 0,
                "subheaders": 0,
                "subheader_declared": 0,
                "hits": 0,
                "hit_declared": 0,
                "bad": True,
                "issue": "truncated_header",
            })
            break

        packet_type = (words[idx] >> 26) & 0x3F
        if packet_type == PACKET_TYPE_IDLE:
            frames.append({
                "start_word": start,
                "end_word": start,
                "timestamp": 0,
                "subheaders": 0,
                "subheader_declared": 0,
                "hits": 0,
                "hit_declared": 0,
                "bad": True,
                "issue": "idle_sop",
            })
            idx = start + 1
            continue
        if packet_type not in PACKET_TYPE_SCIFI:
            frames.append({
                "start_word": start,
                "end_word": start,
                "timestamp": 0,
                "subheaders": 0,
                "subheader_declared": 0,
                "hits": 0,
                "hit_declared": 0,
                "bad": True,
                "issue": f"unsupported_packet_type_0x{packet_type:02x}",
            })
            idx = start + 1
            continue

        ts_high = words[idx + 1]
        ts_low_pkg = words[idx + 2]
        count_word = words[idx + 3]
        header_timestamp = (ts_high << 16) | ((ts_low_pkg >> 16) & 0xFFFF)
        header_base = (ts_high << 16) | (((ts_low_pkg >> 16) & 0xFFFF) & 0xF000)
        subheader_declared = (count_word >> 16) & 0x7FFF
        hit_declared = count_word & 0xFFFF
        subheaders = 0
        hits = 0
        bad = False
        first_subheader_ts: int | None = None
        last_subheader_ts = 0
        subheader_sequence_bad = False
        pos = idx + 5

        for subheader_idx in range(subheader_declared):
            if pos >= len(words) or not rdma_word_has_k(words, k_masks, pos, SWB_K237):
                bad = True
                break
            word = words[pos]
            subheader_ts = (word >> 24) & 0xFF
            if first_subheader_ts is None:
                first_subheader_ts = subheader_ts
            elif subheader_ts != ((first_subheader_ts + subheader_idx) & 0xFF):
                subheader_sequence_bad = True
            last_subheader_ts = subheader_ts
            subheaders += 1
            hit_count = (word >> 8) & 0xFFFF
            hits += hit_count
            pos += 1 + hit_count
            if pos > len(words):
                bad = True
                break
        timestamp = header_base | (((first_subheader_ts or 0) & 0xFF) << 4)

        if not bad and pos < len(words) and rdma_word_has_k(words, k_masks, pos, SWB_K284):
            end = pos
            dirty_trailer = bool(words[end] & 0xFFFF_FF00)
            frame_bad = (hits != hit_declared) or dirty_trailer or subheader_sequence_bad
            frame = {
                "start_word": start,
                "end_word": end,
                "timestamp": timestamp,
                "header_timestamp": header_timestamp,
                "first_subheader_ts": first_subheader_ts if first_subheader_ts is not None else 0,
                "last_subheader_ts": last_subheader_ts,
                "subheader_sequence_bad": subheader_sequence_bad,
                "subheaders": subheaders,
                "subheader_declared": subheader_declared,
                "hits": hits,
                "hit_declared": hit_declared,
                "bad": frame_bad,
                "issue": (
                    "dirty_trailer" if dirty_trailer
                    else "hit_count_mismatch" if hits != hit_declared
                    else "subheader_sequence_mismatch" if subheader_sequence_bad
                    else ""
                ),
            }
            frames.append(frame)
            if not frame_bad:
                trimmed.extend(words[start : end + 1])
                if k_masks is not None:
                    trimmed_k.extend(k_masks[start : end + 1])
            idx = end + 1
        else:
            frames.append({
                "start_word": start,
                "end_word": max(start, min(pos, len(words) - 1)),
                "timestamp": timestamp,
                "header_timestamp": header_timestamp,
                "first_subheader_ts": first_subheader_ts if first_subheader_ts is not None else 0,
                "last_subheader_ts": last_subheader_ts,
                "subheader_sequence_bad": subheader_sequence_bad,
                "subheaders": subheaders,
                "subheader_declared": subheader_declared,
                "hits": hits,
                "hit_declared": hit_declared,
                "bad": True,
                "issue": "missing_subheader_or_trailer",
            })
            idx = start + 1
    return frames, trimmed, (trimmed_k if k_masks is not None else None)


def rdma_frame_summary(
    words: list[int],
    raw: bytes,
    k_masks: list[int] | None = None,
) -> dict[str, Any]:
    frames, trimmed, trimmed_k = decode_rdma_wire_words(words, k_masks)
    good_frames = [
        frame
        for frame in frames
        if not frame["bad"]
        and frame["subheaders"] == 128
        and frame["subheader_declared"] == 128
    ]
    timestamps = [int(frame["timestamp"]) for frame in good_frames]
    header_timestamps = [int(frame.get("header_timestamp", 0)) for frame in good_frames]
    deltas = [timestamps[idx] - timestamps[idx - 1] for idx in range(1, len(timestamps))]
    header_deltas = [
        header_timestamps[idx] - header_timestamps[idx - 1]
        for idx in range(1, len(header_timestamps))
    ]
    def marker_count(marker: int) -> int:
        return sum(
            1
            for word_idx, word in enumerate(trimmed)
            if (word & 0xFF) == marker
            and (trimmed_k is None or (word_idx < len(trimmed_k) and (trimmed_k[word_idx] & 0x1)))
        )
    return {
        "first_k285_word_lsb": bool(raw) and raw[0] == 0xBC,
        "frames_decoded": len(good_frames),
        "bad_frame_count": len(frames) - len(good_frames),
        "idle_frame_start_count": sum(1 for frame in frames if frame.get("issue") == "idle_sop"),
        "dirty_trailer_count": sum(1 for frame in frames if frame.get("issue") == "dirty_trailer"),
        "bad_frame_issues": [
            str(frame.get("issue", "bad_frame"))
            for frame in frames
            if frame.get("bad")
        ][:16],
        "k285_word_lsb_count": marker_count(SWB_K285),
        "k284_word_lsb_count": marker_count(SWB_K284),
        "subheader_count_min": min((int(frame["subheaders"]) for frame in good_frames), default=0),
        "subheader_count_max": max((int(frame["subheaders"]) for frame in good_frames), default=0),
        "subheader_sequence_bad_count": sum(
            1 for frame in frames if bool(frame.get("subheader_sequence_bad", False))
        ),
        "first_subheader_ts_hex": [
            f"0x{int(frame.get('first_subheader_ts', 0)):02x}"
            for frame in good_frames[:16]
        ],
        "last_subheader_ts_hex": [
            f"0x{int(frame.get('last_subheader_ts', 0)):02x}"
            for frame in good_frames[:16]
        ],
        "wire_hit_count": sum(int(frame["hits"]) for frame in good_frames),
        "ts_first_hex": f"0x{timestamps[0]:012x}" if timestamps else "",
        "ts_deltas_hex": [f"0x{delta:012x}" for delta in deltas[:16]],
        "header_ts_deltas_hex": [f"0x{delta:012x}" for delta in header_deltas[:16]],
        "all_ts_delta_0x800": all(delta == 0x800 for delta in deltas),
        "trimmed_word_count_32": len(trimmed),
        "datak_sideband_words": len(trimmed_k or []),
    }


def read_dma_trace_words(trace_path: Path) -> tuple[list[int], list[int] | None, int, int]:
    words: list[int] = []
    k_masks: list[int] = []
    saw_datak = False
    dma_line_count = 0
    end_of_event_count = 0
    if not trace_path.is_file():
        return words, None, dma_line_count, end_of_event_count
    with trace_path.open("r", encoding="ascii", newline="") as handle:
        for row in csv.DictReader(handle):
            if str(row.get("wren", "0")).strip() != "1":
                continue
            data_hex = str(row.get("data", "")).strip()
            if not data_hex:
                continue
            dma_word = int(data_hex, 0)
            datak_text = str(row.get("datak", "")).strip()
            datak_word = int(datak_text, 0) if datak_text else 0
            saw_datak = saw_datak or bool(datak_text)
            for slot in range(8):
                word32 = (dma_word >> (slot * 32)) & 0xFFFF_FFFF
                words.append(word32)
                k_masks.append((datak_word >> (slot * 4)) & 0xF)
            dma_line_count += 1
            if nonzero_int(row.get("end_of_event")):
                end_of_event_count += 1
    return words, (k_masks if saw_datak else None), dma_line_count, end_of_event_count


def write_rdma_buffer(
    output_dir: Path,
    records: list[dict[str, Any]],
    work_dir: Path,
) -> dict[str, Any]:
    trace_candidates = [
        work_dir / "feb_swb_opq_dma_packer_trace.csv",
        work_dir / "feb_swb_dma_trace.csv",
    ]
    trace_path = next((path for path in trace_candidates if path.is_file()), trace_candidates[-1])
    words32, k_masks, dma_line_count, dma_eoe_count = read_dma_trace_words(trace_path)
    frames, trimmed_words, trimmed_k_masks = decode_rdma_wire_words(words32, k_masks)
    good_frames = [
        frame
        for frame in frames
        if not frame["bad"]
        and frame["subheaders"] == 128
        and frame["subheader_declared"] == 128
    ]
    source = f"{trace_path.name}:mu3e_wire_32" if good_frames else "legacy_actual_dma_hit"
    raw = bytearray()
    for word in (trimmed_words if good_frames else []):
        raw.extend(int(word).to_bytes(4, byteorder="little", signed=False))
    record_count = sum(int(frame["hits"]) for frame in good_frames)

    if good_frames and trace_path.is_file():
        dst_trace_path = output_dir / trace_path.name
        if trace_path.resolve() != dst_trace_path.resolve():
            shutil.copyfile(trace_path, dst_trace_path)
        if trimmed_k_masks is not None:
            (output_dir / "rdma_rxbuffer_datak.json").write_text(
                json.dumps(
                    {"word_datak": [f"0x{value:X}" for value in trimmed_k_masks]},
                    separators=(",", ":"),
                )
                + "\n",
                encoding="ascii",
            )

    words: list[int] = []
    if not raw:
        for record in records:
            value = record.get("actual_dma_hit")
            if isinstance(value, int):
                words.append(value)
        for word in words:
            raw.extend(int(word).to_bytes(8, byteorder="big", signed=False))
        record_count = len(words)

    path = output_dir / "rdma_rxbuffer.bin"
    path.write_bytes(bytes(raw))
    first = bytes(raw[:64]).hex()
    last = bytes(raw[-64:]).hex() if raw else ""
    summary = {
        "format": "mu3e_wire_32le" if good_frames else "legacy_dma_hit64be",
        "bytes_total": len(raw),
        "record_count": record_count,
        "buffer_source": source,
        "dma_line_count": dma_line_count,
        "dma_end_of_event_count": dma_eoe_count,
        "first_record_hex": first,
        "last_record_hex": last,
        "record_size_avg": (len(raw) / record_count) if record_count else 0.0,
        **rdma_frame_summary(
            trimmed_words if good_frames else [],
            bytes(raw),
            trimmed_k_masks if good_frames else None,
        ),
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
    "feb_swb_emulator_emit_trace.csv",
    "feb_swb_pre_rbcam_trace.csv",
    "feb_swb_post_rbcam_trace.csv",
    "feb_swb_feb_egress_trace.csv",
    "feb_swb_ingress_trace.csv",
    "feb_swb_opq_trace.csv",
    "feb_swb_opq_dma_packer_trace.csv",
    "feb_swb_lifetime_trace.csv",
    "feb_swb_lifetime_hist_stats.csv",
    "feb_swb_range_validation.csv",
    "frame_ts_progression.csv",
    "feb_swb_corun_summary.txt",
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
    frame_ts_path = work_dir / "frame_ts_progression.csv"
    if frame_ts_path.is_file():
        dst_frame_ts_path = output_dir / "frame_ts_progression.csv"
        if frame_ts_path.resolve() != dst_frame_ts_path.resolve():
            shutil.copyfile(frame_ts_path, dst_frame_ts_path)

    trace_summary = read_key_values(work_dir / "feb_swb_trace_debug_summary.txt")
    corun_summary = read_key_values(work_dir / "feb_swb_corun_summary.txt")
    records = read_filtered_hit_debug(work_dir, row)
    lifetime_error = ""
    lifetime_conditions = {
        "delay_pre": "FAIL",
        "delay_post": "FAIL",
        "delay_feb": "FAIL",
        "delay_ing": "FAIL",
        "delay_opq": "FAIL",
    }
    lifetime_bound_pass = False

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
        "lifetime_analysis": 0,
    }

    try:
        lifetime_summary = analyze_lifetime_dir(work_dir, output_dir, row.to_json(), validate_flat=True)
        bound_status = {
            item["checkpoint"]: item["status"]
            for item in lifetime_summary.get("bounds", [])
            if isinstance(item, dict)
        }
        lifetime_conditions = {
            "delay_pre": str(bound_status.get("pre_rbcam", "FAIL")),
            "delay_post": str(bound_status.get("post_rbcam", "FAIL")),
            "delay_feb": str(bound_status.get("feb_egress", "FAIL")),
            "delay_ing": str(bound_status.get("opq_ingress", "FAIL")),
            "delay_opq": str(bound_status.get("opq_egress", "FAIL")),
        }
        lifetime_bound_pass = all(value == "PASS" for value in lifetime_conditions.values())
    except LifetimeAnalysisError as exc:
        lifetime_error = str(exc)
        error_counters["lifetime_analysis"] = 1

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
            "interval_cfg_clocks": HIST_INTERVAL_CFG_CLOCKS,
            "interval_ms": HIST_INTERVAL_CFG_CLOCKS * 8.0e-6,
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
    write_json(output_dir / "hist_ip_expectation.json",
               build_hist_ip_expectation(
                   row,
                   records,
                   output_dir / "feb_swb_lifetime_trace.csv",
               ))
    hist_total = int(bank_a["hist_bin_sum"]) + int(bank_b["hist_bin_sum"])
    delay_pass = (
        abs(hist_total - csr_total) <= 8
        and delay_data["count"] > 0
        and float(delay_data["delay_stddev_ns"]) < 100.0
        and not lifetime_error
        and lifetime_bound_pass
    )

    rdma_summary = write_rdma_buffer(output_dir, records, work_dir)
    if rdma_summary.get("format") == "mu3e_wire_32le":
        rdma_pass = (
            abs(int(rdma_summary["record_count"]) - csr_total) <= 8
            and bool(rdma_summary.get("first_k285_word_lsb"))
            and int(rdma_summary.get("frames_decoded", 0)) >= 3
            and int(rdma_summary.get("bad_frame_count", 0)) == 0
            and bool(rdma_summary.get("all_ts_delta_0x800", False))
        )
    else:
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
            **lifetime_conditions,
            "rdma": "PASS" if rdma_pass else "FAIL",
        },
        "lifetime_analysis_error": lifetime_error,
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
        f"OPQ_ADAPTOR_VHDL_SOURCE={args.opq_adaptor_vhdl}",
        f"REPORT_DIR={report_dir}",
        f"RUN_LOG={report_dir / 'run_swb_corun.log'}",
        f"SOURCE_MODE={row.sim_source_mode()}",
        f"HIT_PERIOD_8NS={row.sim_hit_period_8ns()}",
        f"RUN_WINDOW_8NS={RUN_WINDOW_8NS}",
        "ASIC_COUNT=8",
        f"DRAIN_SWB_CYCLES={args.drain_swb_cycles}",
        f"FEB_SOURCE_N_SHD={args.feb_source_n_shd}",
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
        f"OPQ_ADAPTOR_VHDL_SOURCE={args.opq_adaptor_vhdl}",
        f"FEB_SOURCE_N_SHD={args.feb_source_n_shd}",
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
    parser.add_argument("--opq-adaptor-vhdl", type=Path)
    parser.add_argument("--report-root", type=Path)
    parser.add_argument("--work-root", type=Path)
    parser.add_argument("--parallel", type=int, default=30)
    parser.add_argument("--row")
    parser.add_argument("--slice", type=int, choices=(1, 2, 3, 4), dest="slice_id")
    parser.add_argument("--drain-swb-cycles", type=int, default=DEFAULT_DRAIN_SWB_CYCLES)
    parser.add_argument("--feb-source-n-shd", type=int, default=128)
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
    args.opq_adaptor_vhdl = (
        args.opq_adaptor_vhdl
        or (args.feb_corun_dir / "vhd" / "ingress_egress_adaptor_native_sv_scifi.vhd")
    ).resolve()
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
    if not args.collect_only and not args.dry_run and not args.opq_adaptor_vhdl.is_file():
        parser.error(f"missing OPQ adapter VHDL: {args.opq_adaptor_vhdl}")

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
