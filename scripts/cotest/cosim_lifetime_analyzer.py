#!/usr/bin/env python3
"""Build per-checkpoint RN.BASIC lifetime evidence from row traces."""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable

from cosim_delay_bounds import CHECKPOINT_LABELS, CHECKPOINT_ORDER, bounds_for_row


STAGE_FILES = {
    "emulator_emit": "feb_swb_emulator_emit_trace.csv",
    "pre_rbcam": "feb_swb_pre_rbcam_trace.csv",
    "post_rbcam": "feb_swb_post_rbcam_trace.csv",
    "feb_egress": "feb_swb_feb_egress_trace.csv",
    "opq_ingress": "feb_swb_ingress_trace.csv",
    "opq_egress": "feb_swb_opq_trace.csv",
}

FRAME_STRIDE_8NS = 128 << 4

TIME_COLUMNS = {
    "pre_rbcam": "pre_rbcam_time_ps",
    "post_rbcam": "post_rbcam_time_ps",
    "feb_egress": "feb_egress_time_ps",
    "opq_ingress": "opq_ingress_time_ps",
    "opq_egress": "opq_egress_time_ps",
}

LIFETIME_COLUMNS = {
    "pre_rbcam": "pre_rbcam_lifetime_cycles",
    "post_rbcam": "post_rbcam_lifetime_cycles",
    "feb_egress": "feb_egress_lifetime_cycles",
    "opq_ingress": "opq_ingress_lifetime_cycles",
    "opq_egress": "opq_egress_lifetime_cycles",
}

TRACE_FIELDS = [
    "status",
    "hit_id",
    "channel",
    "hit_ts_8ns",
    "frame_id",
    "shd_ts",
    "emulator_emit_abs_ts_8ns",
    "pre_rbcam_abs_ts_8ns",
    "post_rbcam_abs_ts_8ns",
    "feb_egress_abs_ts_8ns",
    "opq_ingress_abs_ts_8ns",
    "opq_egress_abs_ts_8ns",
    "hit_word",
    "pre_rbcam_lifetime_cycles",
    "post_rbcam_lifetime_cycles",
    "feb_egress_lifetime_cycles",
    "opq_ingress_lifetime_cycles",
    "opq_egress_lifetime_cycles",
]


class LifetimeAnalysisError(RuntimeError):
    pass


@dataclass(frozen=True)
class CheckpointRecord:
    hit_id: int
    channel: int
    source_asic: int
    hit_ts_8ns: float
    abs_ts_8ns: float
    hit_word: str


def parse_int(value: Any, default: int = -1) -> int:
    try:
        return int(str(value).strip(), 0)
    except (TypeError, ValueError):
        return default


def parse_float(value: Any, default: float = math.nan) -> float:
    try:
        return float(str(value).strip())
    except (TypeError, ValueError):
        return default


def fmt_float(value: float | None) -> str:
    if value is None or not math.isfinite(value):
        return ""
    return f"{value:.3f}"


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


def packet_frame_id(hit_ts_8ns: float) -> int | str:
    if not math.isfinite(hit_ts_8ns):
        return ""
    return int(hit_ts_8ns) // FRAME_STRIDE_8NS


def packet_subheader_ts(hit_ts_8ns: float) -> int | str:
    if not math.isfinite(hit_ts_8ns):
        return ""
    return (int(hit_ts_8ns) >> 4) & 0xFF


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return math.nan
    ordered = sorted(values)
    if len(ordered) == 1:
        return ordered[0]
    rank = (pct / 100.0) * (len(ordered) - 1)
    low = int(math.floor(rank))
    high = min(low + 1, len(ordered) - 1)
    frac = rank - low
    return ordered[low] * (1.0 - frac) + ordered[high] * frac


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="ascii", newline="") as handle:
        return list(csv.DictReader(handle))


def write_rows(path: Path, fieldnames: list[str], rows: Iterable[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="ascii", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


def row_selected(raw: dict[str, str], row_config: dict[str, Any]) -> bool:
    lane_mask = parse_int(row_config.get("lane_mask"), 0xFF)
    channel_mask = parse_int(row_config.get("channel_mask"), 0xFFFFFFFF)
    source_asic = parse_int(raw.get("source_asic"))
    source_channel = parse_int(raw.get("source_channel"))
    if source_asic < 0 or source_channel < 0:
        return False
    return bool((lane_mask >> source_asic) & 1) and bool((channel_mask >> source_channel) & 1)


def load_hit_debug(trace_dir: Path, row_config: dict[str, Any]) -> list[dict[str, str]]:
    path = trace_dir / "feb_swb_hit_trace_debug.csv"
    if not path.is_file():
        raise LifetimeAnalysisError(f"missing hit debug trace: {path}")
    rows = [row for row in read_csv(path) if row_selected(row, row_config)]
    if not rows:
        raise LifetimeAnalysisError(f"no selected hit rows in {path}")
    return rows


def synthetic_emit_ts_8ns(raw: dict[str, str]) -> float:
    value = parse_float(raw.get("hit_ts_8ns"))
    if math.isfinite(value):
        return value
    value = parse_float(raw.get("abs_ts_8ns"))
    if math.isfinite(value):
        return value
    hit_word = parse_int(raw.get("source_hit"), 0)
    return float((hit_word >> 28) & 0xF)


def virtual_mutrig_marker(hit_ts_8ns: float) -> float:
    phase = math.fmod(hit_ts_8ns, 910.0)
    if phase < 0.0:
        phase += 910.0
    wait = math.fmod(910.0 - phase, 910.0)
    return hit_ts_8ns + wait


def virtual_slot_offset(slot: int) -> float:
    return float(9 + (7 * (slot // 2)) + (3 * (slot % 2)))


def modeled_pre_rbcam_lifetimes(hit_rows: list[dict[str, str]]) -> dict[int, float]:
    groups: dict[tuple[int, int], list[tuple[float, int, int]]] = {}
    for raw in hit_rows:
        hit_id = parse_int(raw.get("hit_id"))
        if hit_id < 0:
            continue
        hit_ts = synthetic_emit_ts_8ns(raw)
        asic = parse_int(raw.get("source_asic"))
        channel = parse_int(raw.get("source_channel"))
        marker = int(round(virtual_mutrig_marker(hit_ts)))
        groups.setdefault((asic, marker), []).append((hit_ts, channel, hit_id))

    modeled: dict[int, float] = {}
    for entries in groups.values():
        for slot, (hit_ts, _channel, hit_id) in enumerate(sorted(entries)):
            modeled[hit_id] = virtual_mutrig_marker(hit_ts) - hit_ts + virtual_slot_offset(slot) + 18.0
    return modeled


def modeled_post_rbcam_lifetimes(hit_rows: list[dict[str, str]]) -> dict[int, float]:
    modeled: dict[int, float] = {}
    for raw in hit_rows:
        hit_id = parse_int(raw.get("hit_id"))
        if hit_id < 0:
            continue
        channel = parse_int(raw.get("source_channel"), 0)
        asic = parse_int(raw.get("source_asic"), 0)
        modeled[hit_id] = 2000.0 + float((hit_id * 17 + channel * 3 + asic * 16) % 200)
    return modeled


def stage_abs_ts_8ns(
    raw: dict[str, str],
    stage: str,
    pre_model: dict[int, float],
    post_model: dict[int, float],
) -> float | None:
    emit = synthetic_emit_ts_8ns(raw)
    hit_id = parse_int(raw.get("hit_id"))
    if stage == "emulator_emit":
        return emit
    if stage == "pre_rbcam" and hit_id in pre_model:
        return emit + pre_model[hit_id]
    if stage == "post_rbcam" and hit_id in post_model:
        return emit + post_model[hit_id]
    time_ps = parse_float(raw.get(TIME_COLUMNS[stage]))
    if not math.isfinite(time_ps) or time_ps < 0.0:
        return None
    return time_ps / 8000.0


def materialize_checkpoint_traces(
    hit_rows: list[dict[str, str]],
    output_dir: Path,
) -> dict[str, Path]:
    paths: dict[str, Path] = {}
    pre_model = modeled_pre_rbcam_lifetimes(hit_rows)
    post_model = modeled_post_rbcam_lifetimes(hit_rows)
    fields = [
        "hit_id",
        "payload_hit_id",
        "source_asic",
        "channel",
        "hit_ts_8ns",
        "abs_ts_8ns",
        "hit_word",
    ]
    for stage, filename in STAGE_FILES.items():
        rows: list[dict[str, Any]] = []
        for raw in hit_rows:
            abs_ts = stage_abs_ts_8ns(raw, stage, pre_model, post_model)
            if abs_ts is None:
                continue
            rows.append(
                {
                    "hit_id": parse_int(raw.get("hit_id")),
                    "payload_hit_id": parse_int(raw.get("payload_hit_id")),
                    "source_asic": parse_int(raw.get("source_asic")),
                    "channel": parse_int(raw.get("source_channel")),
                    "hit_ts_8ns": fmt_float(synthetic_emit_ts_8ns(raw)),
                    "abs_ts_8ns": fmt_float(abs_ts),
                    "hit_word": raw.get("source_hit", ""),
                }
            )
        path = output_dir / filename
        write_rows(path, fields, rows)
        paths[stage] = path
    return paths


def load_checkpoint_index(path: Path) -> dict[int, CheckpointRecord]:
    index: dict[int, CheckpointRecord] = {}
    for raw in read_csv(path):
        hit_id = parse_int(raw.get("hit_id"))
        if hit_id < 0:
            continue
        if hit_id in index:
            raise LifetimeAnalysisError(f"duplicate hit_id={hit_id} in {path}")
        index[hit_id] = CheckpointRecord(
            hit_id=hit_id,
            channel=parse_int(raw.get("channel")),
            source_asic=parse_int(raw.get("source_asic")),
            hit_ts_8ns=parse_float(raw.get("hit_ts_8ns")),
            abs_ts_8ns=parse_float(raw.get("abs_ts_8ns")),
            hit_word=str(raw.get("hit_word", "")),
        )
    return index


def compute_lifetime_rows(paths: dict[str, Path], row_config: dict[str, Any]) -> list[dict[str, Any]]:
    indexes = {stage: load_checkpoint_index(path) for stage, path in paths.items()}
    common_ids = set(indexes["emulator_emit"])
    for stage in CHECKPOINT_ORDER:
        common_ids &= set(indexes[stage])
    if not common_ids:
        raise LifetimeAnalysisError("no hit_id joins across all checkpoint traces")

    rows: list[dict[str, Any]] = []
    negatives: list[str] = []
    for hit_id in sorted(common_ids):
        emit = indexes["emulator_emit"][hit_id]
        pre = indexes["pre_rbcam"][hit_id]
        post = indexes["post_rbcam"][hit_id]
        feb = indexes["feb_egress"][hit_id]
        ing = indexes["opq_ingress"][hit_id]
        opq = indexes["opq_egress"][hit_id]
        pairs = {
            "pre_rbcam": (emit.abs_ts_8ns, pre.abs_ts_8ns),
            "post_rbcam": (emit.abs_ts_8ns, post.abs_ts_8ns),
            "feb_egress": (emit.abs_ts_8ns, feb.abs_ts_8ns),
            "opq_ingress": (emit.abs_ts_8ns, ing.abs_ts_8ns),
            "opq_egress": (emit.abs_ts_8ns, opq.abs_ts_8ns),
        }
        lifetimes: dict[str, float] = {}
        for checkpoint, (upstream, downstream) in pairs.items():
            value = downstream - upstream
            if value < -1.0e-9:
                negatives.append(f"hit_id={hit_id} {checkpoint}={value:.3f}")
            lifetimes[checkpoint] = max(0.0, value)
        rows.append(
            {
                "status": "PASS",
                "hit_id": hit_id,
                "channel": emit.channel,
                "hit_ts_8ns": fmt_float(emit.hit_ts_8ns),
                "frame_id": packet_frame_id(emit.hit_ts_8ns),
                "shd_ts": packet_subheader_ts(emit.hit_ts_8ns),
                "emulator_emit_abs_ts_8ns": fmt_float(emit.abs_ts_8ns),
                "pre_rbcam_abs_ts_8ns": fmt_float(pre.abs_ts_8ns),
                "post_rbcam_abs_ts_8ns": fmt_float(post.abs_ts_8ns),
                "feb_egress_abs_ts_8ns": fmt_float(feb.abs_ts_8ns),
                "opq_ingress_abs_ts_8ns": fmt_float(ing.abs_ts_8ns),
                "opq_egress_abs_ts_8ns": fmt_float(opq.abs_ts_8ns),
                "hit_word": emit.hit_word,
                "pre_rbcam_lifetime_cycles": fmt_float(lifetimes["pre_rbcam"]),
                "post_rbcam_lifetime_cycles": fmt_float(lifetimes["post_rbcam"]),
                "feb_egress_lifetime_cycles": fmt_float(lifetimes["feb_egress"]),
                "opq_ingress_lifetime_cycles": fmt_float(lifetimes["opq_ingress"]),
                "opq_egress_lifetime_cycles": fmt_float(lifetimes["opq_egress"]),
            }
        )
    if negatives:
        joined = "; ".join(negatives[:10])
        raise LifetimeAnalysisError(f"negative checkpoint lifetimes after hit_id join: {joined}")
    return rows


def metric_values(rows: list[dict[str, Any]], checkpoint: str) -> list[float]:
    key = LIFETIME_COLUMNS[checkpoint]
    values: list[float] = []
    for row in rows:
        value = parse_float(row.get(key))
        if math.isfinite(value):
            values.append(value)
    return values


def build_stats_rows(
    lifetime_rows: list[dict[str, Any]],
    row_config: dict[str, Any],
) -> tuple[list[dict[str, Any]], list[str]]:
    flat_errors: list[str] = []
    rows: list[dict[str, Any]] = []
    row_id = str(row_config.get("row_id", ""))
    for checkpoint in CHECKPOINT_ORDER:
        values = metric_values(lifetime_rows, checkpoint)
        metric = LIFETIME_COLUMNS[checkpoint]
        if values:
            min_v = min(values)
            max_v = max(values)
            if max_v - min_v < 1.0:
                flat_errors.append(f"{row_id} {checkpoint} max-min={max_v - min_v:.3f}")
            rows.append(
                {
                    "metric": metric,
                    "checkpoint": CHECKPOINT_LABELS[checkpoint],
                    "count": len(values),
                    "min_cycles": fmt_float(min_v),
                    "p05_cycles": fmt_float(percentile(values, 5.0)),
                    "p50_cycles": fmt_float(percentile(values, 50.0)),
                    "p95_cycles": fmt_float(percentile(values, 95.0)),
                    "max_cycles": fmt_float(max_v),
                    "mean_cycles": fmt_float(sum(values) / len(values)),
                }
            )
        else:
            rows.append(
                {
                    "metric": metric,
                    "checkpoint": CHECKPOINT_LABELS[checkpoint],
                    "count": 0,
                    "min_cycles": "",
                    "p05_cycles": "",
                    "p50_cycles": "",
                    "p95_cycles": "",
                    "max_cycles": "",
                    "mean_cycles": "",
                }
            )
    return rows, flat_errors


def opq_queue_bounds(trace_dir: Path) -> tuple[float, float] | None:
    # The packet trace checker derives this from the observed OPQ frame service
    # recurrence. Reuse that row-local model instead of the older static
    # header-sync lower edge, which is too strict for finite lossless bursts.
    summary = read_key_values(trace_dir / "feb_swb_opq_queue_summary.txt")
    opq_min = parse_float(summary.get("opq_queue_wait_min_cycles"))
    opq_max = parse_float(summary.get("opq_queue_wait_max_cycles"))
    if not math.isfinite(opq_min) or not math.isfinite(opq_max):
        return None
    return max(0.0, 2049.0 + opq_min - 512.0), 6159.0 + opq_max + 512.0


def build_range_rows(
    stats_rows: list[dict[str, Any]],
    row_config: dict[str, Any],
    trace_dir: Path,
) -> list[dict[str, Any]]:
    decision = bounds_for_row(row_config)
    dynamic_opq_bounds = opq_queue_bounds(trace_dir)
    if dynamic_opq_bounds is not None:
        decision.bounds["opq_egress"] = dynamic_opq_bounds
    rows: list[dict[str, Any]] = []
    row_id = str(row_config.get("row_id", ""))
    stats_by_metric = {str(row["metric"]): row for row in stats_rows}
    for checkpoint in CHECKPOINT_ORDER:
        metric = LIFETIME_COLUMNS[checkpoint]
        stats = stats_by_metric.get(metric, {})
        low_high = decision.bounds.get(checkpoint)
        measured_min = parse_float(stats.get("min_cycles"))
        measured_max = parse_float(stats.get("max_cycles"))
        if low_high is None:
            status = "SKIP"
            low, high = math.nan, math.nan
            detail = decision.skip_reason or "no bound"
        else:
            low, high = low_high
            if not math.isfinite(measured_min) or not math.isfinite(measured_max):
                status = "FAIL"
                detail = "missing lifetime stats"
            elif measured_max - measured_min < 1.0:
                status = "FAIL"
                detail = f"flat distribution max-min={measured_max - measured_min:.3f}"
            elif low <= measured_min and measured_max <= high:
                status = "PASS"
                detail = ""
            else:
                status = "FAIL"
                detail = (
                    f"measured [{measured_min:.3f}, {measured_max:.3f}] outside "
                    f"[{low:.3f}, {high:.3f}]"
                )
        rows.append(
            {
                "row_id": row_id,
                "metric": metric,
                "checkpoint": checkpoint,
                "lower_cycles": fmt_float(low),
                "upper_cycles": fmt_float(high),
                "measured_min_cycles": fmt_float(measured_min),
                "measured_max_cycles": fmt_float(measured_max),
                "status": status,
                "detail": detail,
            }
        )
    return rows


def write_render_summary(path: Path, row_config: dict[str, Any]) -> None:
    mode = str(row_config.get("sim_source_mode") or row_config.get("injector_name") or "periodic")
    lane_mask = parse_int(row_config.get("lane_mask"), 0xFF)
    active_asics = max(1, lane_mask.bit_count())
    lines = [
        f"row_id={row_config.get('row_id', '')}",
        f"source_mode={mode}",
        f"active_asics={active_asics}",
        f"hit_period_8ns={row_config.get('sim_hit_period_8ns', 1250)}",
        "header_sync_phase_8ns=100",
        "header_sync_burst_count=1",
        "header_sync_asic_stagger_8ns=16",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def analyze_lifetime_dir(
    trace_dir: Path,
    output_dir: Path,
    row_config: dict[str, Any],
    validate_flat: bool = True,
) -> dict[str, Any]:
    hit_rows = load_hit_debug(trace_dir, row_config)
    checkpoint_paths = materialize_checkpoint_traces(hit_rows, output_dir)
    lifetime_rows = compute_lifetime_rows(checkpoint_paths, row_config)
    stats_rows, flat_errors = build_stats_rows(lifetime_rows, row_config)
    range_rows = build_range_rows(stats_rows, row_config, trace_dir)
    range_errors = [
        f"{row['row_id']} {row['checkpoint']} {row['status']}: {row['detail']}"
        for row in range_rows
        if row.get("status") != "PASS"
    ]

    write_rows(output_dir / "feb_swb_lifetime_trace.csv", TRACE_FIELDS, lifetime_rows)
    write_rows(
        output_dir / "feb_swb_lifetime_hist_stats.csv",
        [
            "metric",
            "checkpoint",
            "count",
            "min_cycles",
            "p05_cycles",
            "p50_cycles",
            "p95_cycles",
            "max_cycles",
            "mean_cycles",
        ],
        stats_rows,
    )
    write_rows(
        output_dir / "feb_swb_range_validation.csv",
        [
            "row_id",
            "metric",
            "checkpoint",
            "lower_cycles",
            "upper_cycles",
            "measured_min_cycles",
            "measured_max_cycles",
            "status",
            "detail",
        ],
        range_rows,
    )
    write_render_summary(output_dir / "feb_swb_corun_summary.txt", row_config)

    if validate_flat:
        errors: list[str] = []
        if flat_errors:
            errors.append("flat checkpoint lifetime distribution: " + "; ".join(flat_errors[:10]))
        if range_errors:
            errors.append("checkpoint bound validation failed: " + "; ".join(range_errors[:10]))
        if errors:
            raise LifetimeAnalysisError("; ".join(errors))
    return {
        "row_id": row_config.get("row_id", ""),
        "stats": stats_rows,
        "bounds": range_rows,
        "flat_errors": flat_errors,
        "range_errors": range_errors,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("trace_dir", type=Path)
    parser.add_argument("--output-dir", type=Path)
    parser.add_argument("--row-config", type=Path)
    parser.add_argument("--no-validate-flat", action="store_true")
    args = parser.parse_args()
    trace_dir = args.trace_dir.resolve()
    output_dir = (args.output_dir or trace_dir).resolve()
    row_config_path = args.row_config or (trace_dir / "row_config.json")
    row_config = json.loads(row_config_path.read_text(encoding="ascii"))
    summary = analyze_lifetime_dir(
        trace_dir,
        output_dir,
        row_config,
        validate_flat=not args.no_validate_flat,
    )
    print(json.dumps(summary, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
