#!/usr/bin/env python3
"""Generate strict DV_COV.md and DV_REPORT.md from doc-case inventories and UCDB/log evidence."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import tempfile
from collections import OrderedDict
from pathlib import Path


BUCKET_FILES = OrderedDict(
    [
        ("BASIC", "DV_BASIC.md"),
        ("EDGE", "DV_EDGE.md"),
        ("PROF", "DV_PROF.md"),
        ("ERROR", "DV_ERROR.md"),
    ]
)

METRIC_ROWS = OrderedDict(
    [
        ("Statements", "stmt"),
        ("Branches", "branch"),
        ("Conditions", "cond"),
        ("Expressions", "expr"),
        ("FSM States", "fsm_state"),
        ("FSM Transitions", "fsm_trans"),
        ("Toggles", "toggle"),
    ]
)
ENGINE_MARKER = "DOC_CASE_ENGINE_V2"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ip-root", required=True, type=Path)
    parser.add_argument("--dut-name", required=True)
    parser.add_argument("--report-title", required=True)
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--rtl-variant", default="after")
    parser.add_argument("--vcover", default="/data1/intelFPGA_pro/23.1/questa_fse/bin/vcover")
    parser.add_argument("--raw-json-name", default="DV_REPORT.json")
    parser.add_argument("--strict-implementation", action="store_true")
    return parser.parse_args()


def short_case_id(case_id: str) -> str:
    match = re.match(r"^([BEPX]\d{3})", case_id)
    return match.group(1) if match else case_id


def build_description(scenario: str, primary_checks: str, contract_anchor: str) -> str:
    parts: list[str] = []
    if scenario:
        parts.append(scenario.rstrip("."))
    if primary_checks:
        parts.append(primary_checks.rstrip("."))
    if contract_anchor:
        parts.append(f"anchor: {contract_anchor.rstrip('.')}")
    return "; ".join(parts)


def parse_doc_cases(doc_path: Path) -> list[dict[str, str]]:
    cases: list[dict[str, str]] = []
    for line in doc_path.read_text().splitlines():
        cols = [col.strip() for col in line.strip().split("|")[1:-1]]
        if cols and re.match(r"^[BEPX]\d{3}[A-Za-z0-9_]*$", cols[0]):
            method = cols[1].upper() if len(cols) > 1 else "D"
            scenario = cols[2] if len(cols) > 2 else ""
            primary_checks = cols[3] if len(cols) > 3 else ""
            contract_anchor = cols[4] if len(cols) > 4 else ""
            cases.append(
                {
                    "case_id": cols[0],
                    "short_id": short_case_id(cols[0]),
                    "method": method,
                    "scenario": scenario,
                    "primary_checks": primary_checks,
                    "contract_anchor": contract_anchor,
                    "description": build_description(scenario, primary_checks, contract_anchor),
                }
            )
            continue
        bullet_match = re.match(r"^-\s*`([BEPX]\d{3})\s*\|\s*([^`]+)`", line)
        if bullet_match:
            case_id = bullet_match.group(2).strip()
            cases.append(
                {
                    "case_id": case_id,
                    "short_id": short_case_id(case_id),
                    "method": "D",
                    "scenario": "",
                    "primary_checks": "",
                    "contract_anchor": "",
                    "description": case_id,
                }
            )
    return cases


def is_random_case(case_info: dict[str, object]) -> bool:
    method = str(case_info.get("method", "D")).upper()
    scenario = str(case_info.get("scenario", "")).lower()
    return method == "R" or (method in {"K", "F"} and "random" in scenario)


def case_type_for(case_info: dict[str, object]) -> str:
    return "r" if is_random_case(case_info) else "d"


def executed_random_txn_for(case_info: dict[str, object]) -> int:
    if not is_random_case(case_info):
        return 0
    return int(case_info.get("observed_txn", 0))


def pending_cov_string() -> str:
    return "stmt=pending, branch=pending, cond=pending, expr=pending, fsm_state=pending, fsm_trans=pending, toggle=pending"


def na_cov_string() -> str:
    return "stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a"


def format_cov(metrics: dict[str, tuple[int | float, int]]) -> str:
    parts: list[str] = []
    for _, key in METRIC_ROWS.items():
        hits, bins = metrics.get(key, (0, 0))
        if bins == 0:
            parts.append(f"{key}=n/a")
        else:
            parts.append(f"{key}={(float(hits) * 100.0 / bins):.2f}")
    return ", ".join(parts)


def diff_cov(curr: dict[str, tuple[int, int]], prev: dict[str, tuple[int, int]]) -> dict[str, tuple[int, int]]:
    delta: dict[str, tuple[int, int]] = {}
    for key in METRIC_ROWS.values():
        curr_hits, curr_bins = curr.get(key, (0, 0))
        prev_hits, prev_bins = prev.get(key, (0, 0))
        bins = curr_bins or prev_bins
        if bins == 0:
            delta[key] = (0, 0)
            continue
        delta[key] = (max(curr_hits - prev_hits, 0), bins)
    return delta


def scale_cov(metrics: dict[str, tuple[int, int]], divisor: int) -> dict[str, tuple[float, int]]:
    scaled: dict[str, tuple[float, int]] = {}
    for key in METRIC_ROWS.values():
        hits, bins = metrics.get(key, (0, 0))
        if bins == 0:
            scaled[key] = (0.0, 0)
        else:
            scaled[key] = (hits / divisor, bins)
    return scaled


def format_cov_per_txn(metrics: dict[str, tuple[int, int]], divisor: int) -> str:
    if divisor <= 0:
        return na_cov_string()
    return format_cov(scale_cov(metrics, divisor))


def metrics_to_raw(metrics: dict[str, tuple[int | float, int]] | None) -> dict[str, dict[str, int | float | None]] | None:
    if not metrics:
        return None
    payload: dict[str, dict[str, int | float | None]] = {}
    for key in METRIC_ROWS.values():
        hits, bins = metrics.get(key, (0, 0))
        payload[key] = {
            "hits": hits,
            "bins": bins,
            "pct": None if bins == 0 else round(float(hits) * 100.0 / bins, 2),
        }
    return payload


def parse_cov_summary(text: str) -> dict[str, tuple[int, int]]:
    active_instance = None
    totals = {key: [0, 0] for key in METRIC_ROWS.values()}
    instance_match = re.compile(r"^=== Instance:\s+(.+)$")
    metric_match = re.compile(
        r"^\s+(Branches|Conditions|Expressions|FSM States|FSM Transitions|Statements|Toggles)\s+(\d+)\s+(\d+)\s+\d+"
    )

    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        m_inst = instance_match.match(line)
        if m_inst:
            active_instance = m_inst.group(1).strip()
            continue
        if not active_instance or not active_instance.startswith("/tb_top/dut"):
            continue
        m_metric = metric_match.match(line)
        if not m_metric:
            continue
        label = m_metric.group(1)
        bins = int(m_metric.group(2))
        hits = int(m_metric.group(3))
        key = METRIC_ROWS[label]
        totals[key][0] += hits
        totals[key][1] += bins
    return {key: (value[0], value[1]) for key, value in totals.items()}


def run_vcover_summary(vcover: str, ucdb: Path) -> dict[str, tuple[int, int]]:
    result = subprocess.run(
        [vcover, "report", "-code", "bcesft", str(ucdb)],
        check=True,
        capture_output=True,
        text=True,
    )
    return parse_cov_summary(result.stdout)


def merge_cov(vcover: str, ucdbs: list[Path], temp_root: Path) -> dict[str, tuple[int, int]]:
    if not ucdbs:
        return {}
    temp_root.mkdir(parents=True, exist_ok=True)
    if len(ucdbs) == 1:
        return run_vcover_summary(vcover, ucdbs[0])
    merged = temp_root / "merged.ucdb"
    if merged.exists():
        merged.unlink()
    subprocess.run(
        [vcover, "merge", str(merged), *[str(p) for p in ucdbs]],
        check=True,
        capture_output=True,
        text=True,
    )
    return run_vcover_summary(vcover, merged)


def merge_cov_incremental(
    vcover: str,
    prev_merged_ucdb: Path | None,
    next_ucdb: Path,
    temp_root: Path,
) -> tuple[Path, dict[str, tuple[int, int]]]:
    if prev_merged_ucdb is None:
        return next_ucdb, run_vcover_summary(vcover, next_ucdb)

    temp_root.mkdir(parents=True, exist_ok=True)
    merged = temp_root / "merged.ucdb"
    if merged.exists():
        merged.unlink()
    subprocess.run(
        [vcover, "merge", str(merged), str(prev_merged_ucdb), str(next_ucdb)],
        check=True,
        capture_output=True,
        text=True,
    )
    return merged, run_vcover_summary(vcover, merged)


def log_passed(log_path: Path) -> bool:
    if not log_path.exists():
        return False
    return "*** TEST PASSED ***" in log_path.read_text(errors="ignore")


def log_contains_engine_marker(log_path: Path) -> bool:
    if not log_path.exists():
        return False
    return ENGINE_MARKER in log_path.read_text(errors="ignore")


def parse_log_summary(log_path: Path) -> dict[str, int]:
    if not log_path.exists():
        return {"headers": 0, "hits": 0, "real_eops": 0, "synth_eops": 0}

    summary_re = re.compile(r"headers=(\d+)\s+hits=(\d+)\s+real_eops=(\d+)\s+synth_eops=(\d+)")
    for line in reversed(log_path.read_text().splitlines()):
        match = summary_re.search(line)
        if match:
            return {
                "headers": int(match.group(1)),
                "hits": int(match.group(2)),
                "real_eops": int(match.group(3)),
                "synth_eops": int(match.group(4)),
            }
    return {"headers": 0, "hits": 0, "real_eops": 0, "synth_eops": 0}


def parse_cross_summary(log_path: Path) -> dict[str, object] | None:
    if not log_path.exists():
        return None
    summary_re = re.compile(
        r"FRCV_CROSS_SUMMARY hit_bins=(\d+) total_bins=(\d+) pct=([0-9.]+) txns=(\d+) "
        r"back_to_back=(\d+) queued_overlap=(\d+) counter_checks_passed=(\d+) "
        r"counter_checks_failed=(\d+) unexpected_outputs=(\d+)"
    )
    curve_re = re.compile(r"^\s*#?\s*FRCV_CROSS_CURVE\s*(.*)$")
    summary: dict[str, object] | None = None
    curve = ""
    for line in log_path.read_text(errors="ignore").splitlines():
        match = summary_re.search(line)
        if match:
            summary = {
                "hit_bins": int(match.group(1)),
                "total_bins": int(match.group(2)),
                "pct": float(match.group(3)),
                "txns": int(match.group(4)),
                "back_to_back": int(match.group(5)),
                "queued_overlap": int(match.group(6)),
                "counter_checks_passed": int(match.group(7)),
                "counter_checks_failed": int(match.group(8)),
                "unexpected_outputs": int(match.group(9)),
            }
            continue
        curve_match = curve_re.search(line)
        if curve_match:
            curve = curve_match.group(1).strip()
    if summary is None:
        return None
    summary["curve"] = curve
    return summary


def parse_case_banner(log_path: Path) -> dict[str, object]:
    payload: dict[str, object] = {}
    if not log_path.exists():
        return payload
    case_re = re.compile(
        r"DOC_CASE_ENGINE_V2 case=(\S+) build=(\S+)(?:\s+effort=(\S+))?\s+global_case_idx=(\d+)\s+bucket_case_idx=(\d+)"
    )
    for line in log_path.read_text(errors="ignore").splitlines():
        match = case_re.search(line)
        if not match:
            continue
        payload.update(
            {
                "case_id": match.group(1),
                "build_tag": match.group(2),
                "effort": match.group(3) or "practical",
                "global_case_idx": int(match.group(4)),
                "bucket_case_idx": int(match.group(5)),
            }
        )
    return payload


def parse_signoff_banner(log_path: Path) -> dict[str, object]:
    payload: dict[str, object] = {}
    if not log_path.exists():
        return payload
    list_re = re.compile(
        r"DOC_CASE_LIST_ENGINE_V1 mode=(\S+) build=(\S+)(?:\s+effort=(\S+))?\s+seq=(\S+) case_count=(\d+)(?:\s+iter_cap=(\d+)\s+payload_cap=(\d+))?"
    )
    cross_re = re.compile(r"FRCV_CROSS_ENGINE_V1 plan=(\S+) build=(\S+)(?:\s+effort=(\S+))?")
    for line in log_path.read_text(errors="ignore").splitlines():
        list_match = list_re.search(line)
        if list_match:
            payload.update(
                {
                    "mode": list_match.group(1),
                    "build_tag": list_match.group(2),
                    "effort": list_match.group(3) or "practical",
                    "sequence_name": list_match.group(4),
                    "case_count": int(list_match.group(5)),
                    "iter_cap": int(list_match.group(6)) if list_match.group(6) else None,
                    "payload_cap": int(list_match.group(7)) if list_match.group(7) else None,
                }
            )
            continue
        cross_match = cross_re.search(line)
        if cross_match:
            payload.update(
                {
                    "mode": "cross",
                    "build_tag": cross_match.group(2),
                    "effort": cross_match.group(3) or "practical",
                    "sequence_name": cross_match.group(1),
                }
            )
    return payload


def normalize_build_tag(run_id: str, banner_build_tag: object) -> str:
    if isinstance(banner_build_tag, str) and re.match(r"^CFG_[A-Z]$", banner_build_tag):
        return banner_build_tag
    suffix_match = re.search(r"(cfg_[a-z])$", run_id)
    if suffix_match:
        return suffix_match.group(1).upper()
    return "UNKNOWN"


def collect_signoff_runs(
    uvm_root: Path,
    rtl_variant: str,
    seed: int,
    vcover: str,
) -> list[dict[str, object]]:
    latest_runs: OrderedDict[tuple[object, ...], dict[str, object]] = OrderedDict()
    suffix = f"_{rtl_variant}_s{seed}.log"
    for log_path in sorted((uvm_root / "logs").glob(f"*{suffix}")):
        run_id = log_path.name[: -len(suffix)]
        if not (
            run_id.startswith("bucket_frame_")
            or run_id.startswith("all_buckets_frame_")
            or run_id.startswith("cross_")
        ):
            continue
        if "smoke" in run_id:
            continue
        ucdb_path = uvm_root / f"cov_{rtl_variant}" / f"{run_id}_s{seed}.ucdb"
        if not log_passed(log_path) or not ucdb_path.exists():
            continue
        banner = parse_signoff_banner(log_path)
        cross_summary = parse_cross_summary(log_path)
        kind = "cross"
        bucket = None
        build_tag = normalize_build_tag(run_id, banner.get("build_tag"))
        if run_id.startswith("bucket_frame_"):
            kind = "bucket_frame"
            bucket_match = re.match(r"^bucket_frame_([a-z]+)(?:_(cfg_[a-z]))?$", run_id)
            bucket = bucket_match.group(1).upper() if bucket_match else None
        elif run_id.startswith("all_buckets_frame_"):
            kind = "all_buckets_frame"
        elif run_id.startswith("cross_"):
            kind = "cross"
        if kind == "bucket_frame" and bucket not in BUCKET_FILES:
            continue
        if kind == "all_buckets_frame" and build_tag == "UNKNOWN":
            continue
        if kind == "cross" and not banner.get("sequence_name"):
            continue
        key: tuple[object, ...]
        if kind == "bucket_frame":
            key = (kind, bucket, build_tag)
        elif kind == "all_buckets_frame":
            key = (kind, build_tag)
        else:
            key = (kind, banner.get("sequence_name", ""), build_tag)
        current = {
            "run_id": run_id,
            "kind": kind,
            "bucket": bucket,
            "build_tag": build_tag,
            "sequence_name": banner.get("sequence_name", ""),
            "case_count": int(banner.get("case_count", 0)),
            "effort": banner.get("effort", ""),
            "iter_cap": banner.get("iter_cap"),
            "payload_cap": banner.get("payload_cap"),
            "code_coverage": run_vcover_summary(vcover, ucdb_path),
            "cross_summary": cross_summary,
            "mtime": log_path.stat().st_mtime,
        }
        previous = latest_runs.get(key)
        if previous is None or float(current["mtime"]) >= float(previous.get("mtime", 0.0)):
            latest_runs[key] = current
    runs = list(latest_runs.values())
    runs.sort(key=lambda run: (str(run["kind"]), str(run["bucket"]), str(run["build_tag"]), str(run["sequence_name"])))
    return runs


def build_case_index(
    ip_root: Path, seed: int, rtl_variant: str
) -> tuple[dict[str, list[str]], dict[str, dict[str, object]], list[str]]:
    tb_root = ip_root / "tb"
    uvm_root = tb_root / "uvm"
    case_lists: dict[str, list[str]] = {}
    case_info: dict[str, dict[str, object]] = {}
    failed_cases: list[str] = []

    for bucket, filename in BUCKET_FILES.items():
        case_records = parse_doc_cases(tb_root / filename)
        case_lists[bucket] = [record["case_id"] for record in case_records]
        for record in case_records:
            case_id = record["case_id"]
            ucdb = uvm_root / "cov_after" / f"{case_id}_s{seed}.ucdb"
            log = uvm_root / "logs" / f"{case_id}_{rtl_variant}_s{seed}.log"
            case_banner = parse_case_banner(log)
            implemented = log_contains_engine_marker(log)
            artifact_passed = implemented and ucdb.exists() and log_passed(log)
            passed = artifact_passed
            log_summary = parse_log_summary(log)
            if implemented and log.exists() and not artifact_passed:
                failed_cases.append(case_id)
            case_info[case_id] = {
                "bucket": bucket,
                "short_id": record["short_id"],
                "method": record["method"],
                "scenario": record["scenario"],
                "primary_checks": record["primary_checks"],
                "contract_anchor": record["contract_anchor"],
                "description": record["description"],
                "implemented": implemented,
                "artifact_passed": artifact_passed,
                "implementation_mode": "doc_case_engine_v2" if implemented else "missing_engine_evidence",
                "build_tag": str(case_banner.get("build_tag", "UNKNOWN")),
                "isolated_effort": str(case_banner.get("effort", "unknown")),
                "ucdb": ucdb,
                "log": log,
                "passed": passed,
                "log_summary": log_summary,
                "observed_txn": log_summary["headers"],
            }

    return case_lists, case_info, sorted(set(failed_cases))


def incr_per_txn_string(case_info: dict[str, object], increment_cov: dict[str, tuple[int, int]]) -> str:
    random_txn = executed_random_txn_for(case_info)
    if random_txn > 0:
        return format_cov_per_txn(increment_cov, random_txn)
    return format_cov(increment_cov)


def build_ordered_trace(
    vcover: str,
    ordered_cases: list[str],
    case_info: dict[str, dict[str, object]],
    temp_root: Path,
) -> dict[str, object]:
    rows: list[dict[str, object]] = []
    row_by_case: dict[str, dict[str, object]] = {}
    prev_summary: dict[str, tuple[int, int]] = {}
    prev_merged_ucdb: Path | None = None
    step = 0

    for case_id in ordered_cases:
        if not case_info[case_id]["passed"]:
            continue
        step += 1
        prev_merged_ucdb, merged_summary = merge_cov_incremental(
            vcover,
            prev_merged_ucdb,
            case_info[case_id]["ucdb"],
            temp_root / f"step_{step:03d}",
        )
        increment_summary = diff_cov(merged_summary, prev_summary)
        row = {
            "step": step,
            "case_id": case_id,
            "merged": merged_summary,
            "increment": increment_summary,
        }
        rows.append(row)
        row_by_case[case_id] = row
        prev_summary = merged_summary

    return {
        "rows": rows,
        "row_by_case": row_by_case,
        "final": prev_summary if rows else {},
    }


def write_ordered_trace(
    lines: list[str],
    heading: str,
    trace_rows: list[dict[str, object]],
    bucket_lookup: dict[str, str] | None = None,
) -> None:
    if heading:
        lines.append(heading)
        lines.append("")
    if not trace_rows:
        lines.append("- none yet")
        lines.append("")
        return

    if bucket_lookup is None:
        lines.append("| step | case_id | merged_total_after_case |")
        lines.append("|---:|---|---|")
        for row in trace_rows:
            lines.append(f"| {row['step']} | {row['case_id']} | {format_cov(row['merged'])} |")
    else:
        lines.append("| step | bucket | case_id | merged_total_after_case |")
        lines.append("|---:|---|---|---|")
        for row in trace_rows:
            case_id = str(row["case_id"])
            lines.append(f"| {row['step']} | {bucket_lookup[case_id]} | {case_id} | {format_cov(row['merged'])} |")
    lines.append("")


def write_bucket_table(
    lines: list[str],
    bucket: str,
    cases: list[str],
    case_info: dict[str, dict[str, object]],
    display_trace: dict[str, object],
    bucket_local_trace: dict[str, object],
) -> None:
    lines.append(f"## {bucket} Bucket")
    lines.append("")
    lines.append("| case_id | type (d/r) | coverage_by_this_case | executed random txn | coverage_incr_per_txn |")
    lines.append("|---|---|---|---|---|")
    row_by_case = display_trace["row_by_case"]
    for case_id in cases:
        info = case_info[case_id]
        if case_info[case_id]["passed"]:
            increment_cov = row_by_case[case_id]["increment"]
            lines.append(
                f"| {case_id} | {case_type_for(info)} | {format_cov(increment_cov)} | {executed_random_txn_for(info)} | {incr_per_txn_string(info, increment_cov)} |"
            )
        else:
            lines.append(f"| {case_id} | {case_type_for(info)} | {pending_cov_string()} | 0 | {pending_cov_string()} |")
    lines.append("")
    write_ordered_trace(lines, "### Bucket-Local Ordered Isolated Merge Trace", bucket_local_trace["rows"])


def write_report_bucket_table(
    lines: list[str],
    bucket: str,
    cases: list[str],
    case_info: dict[str, dict[str, object]],
    bucket_local_trace: dict[str, object],
) -> None:
    lines.append(f"## {bucket} Bucket")
    lines.append("")
    lines.append(
        "| case_id | method | isolated_case_coverage | observed_txn | isolated_cov_per_txn | bucket_gain_by_case | bucket_merged_total_after_case | bucket_gain_per_txn | description |"
    )
    lines.append("|---|---|---|---:|---|---|---|---|---|")
    row_by_case = bucket_local_trace["row_by_case"]
    for case_id in cases:
        info = case_info[case_id]
        if info["passed"]:
            standalone = info["standalone"]
            observed_txn = int(info.get("observed_txn", 0))
            increment_cov = row_by_case[case_id]["increment"]
            merged_cov = row_by_case[case_id]["merged"]
            lines.append(
                f"| {info['short_id']} | {info['method']} | {format_cov(standalone)} | {observed_txn} | {format_cov_per_txn(standalone, observed_txn)} | {format_cov(increment_cov)} | {format_cov(merged_cov)} | {format_cov_per_txn(increment_cov, observed_txn)} | {info['description']} |"
            )
        else:
            lines.append(
                f"| {info['short_id']} | {info['method']} | {pending_cov_string()} | 0 | {na_cov_string()} | {pending_cov_string()} | {pending_cov_string()} | {na_cov_string()} | {info['description']} |"
            )
    lines.append("")


def write_random_case_summary(
    lines: list[str],
    case_lists: dict[str, list[str]],
    case_info: dict[str, dict[str, object]],
    bucket_traces: dict[str, dict[str, object]],
) -> None:
    random_cases = [
        case_id
        for bucket_cases in case_lists.values()
        for case_id in bucket_cases
        if is_random_case(case_info[case_id])
    ]

    lines.append("## Random / Multi-Txn View")
    lines.append("")
    if not random_cases:
        lines.append("- No doc cases are currently tagged as random in the DV plan.")
        lines.append("")
        return

    lines.append(
        "| case_id | bucket | method | observed_txn | isolated_case_coverage | isolated_cov_per_txn | bucket_gain_by_case | bucket_gain_per_txn | txn_growth_curve | description |"
    )
    lines.append("|---|---|---|---:|---|---|---|---|---|---|")
    for case_id in random_cases:
        info = case_info[case_id]
        bucket = str(info["bucket"])
        if not info["passed"]:
            lines.append(
                f"| {info['short_id']} | {bucket} | {info['method']} | 0 | {pending_cov_string()} | {na_cov_string()} | {pending_cov_string()} | {na_cov_string()} | pending | {info['description']} |"
            )
            continue
        observed_txn = int(info.get("observed_txn", 0))
        increment_cov = bucket_traces[bucket]["row_by_case"][case_id]["increment"]
        growth_note = "n/a: only final per-case UCDB is available" if observed_txn > 0 else "n/a: no observed txn count in log"
        lines.append(
            f"| {info['short_id']} | {bucket} | {info['method']} | {observed_txn} | {format_cov(info['standalone'])} | {format_cov_per_txn(info['standalone'], observed_txn)} | {format_cov(increment_cov)} | {format_cov_per_txn(increment_cov, observed_txn)} | {growth_note} | {info['description']} |"
        )
    lines.append("")


def build_raw_payload(
    args: argparse.Namespace,
    case_lists: dict[str, list[str]],
    case_info: dict[str, dict[str, object]],
    failed_cases: list[str],
    bucket_evidence: dict[str, list[str]],
    bucket_traces: dict[str, dict[str, object]],
    bucket_totals: dict[str, dict[str, tuple[int, int]]],
    all_trace: dict[str, object],
    all_total: dict[str, tuple[int, int]],
    planned_total: int,
    evidenced_total: int,
    signoff_runs: list[dict[str, object]],
) -> dict[str, object]:
    bucket_summary: list[dict[str, object]] = []
    buckets_payload: dict[str, object] = {}
    unimplemented_cases = [case_id for case_id, info in case_info.items() if not bool(info["implemented"])]
    stale_artifacts = [
        case_id
        for case_id, info in case_info.items()
        if not bool(info["implemented"]) and (info["log"].exists() or info["ucdb"].exists())
    ]

    for bucket, cases in case_lists.items():
        evidenced = len(bucket_evidence[bucket])
        merged_all_after_bucket = (
            all_trace["row_by_case"][bucket_evidence[bucket][-1]]["merged"] if evidenced else None
        )
        bucket_summary.append(
            {
                "bucket": bucket,
                "planned_cases": len(cases),
                "evidenced_cases": evidenced,
                "merged_bucket_total": metrics_to_raw(bucket_totals[bucket]) if evidenced else None,
                "merged_all_buckets_total_after_bucket": metrics_to_raw(merged_all_after_bucket),
                "functional_coverage": {
                    "pct": round(100.0 * evidenced / len(cases), 2),
                    "evidenced": evidenced,
                    "planned": len(cases),
                },
            }
        )

        bucket_cases_payload: list[dict[str, object]] = []
        row_by_case = bucket_traces[bucket]["row_by_case"]
        for case_id in cases:
            info = case_info[case_id]
            row = row_by_case.get(case_id)
            observed_txn = int(info.get("observed_txn", 0))
            bucket_cases_payload.append(
                {
                    "full_case_id": case_id,
                    "case_id": info["short_id"],
                    "bucket": bucket,
                    "method": info["method"],
                    "scenario": info["scenario"],
                    "primary_checks": info["primary_checks"],
                    "contract_anchor": info["contract_anchor"],
                    "description": info["description"],
                    "implemented": bool(info["implemented"]),
                    "artifact_passed": bool(info["artifact_passed"]),
                    "implementation_mode": info["implementation_mode"],
                    "build_tag": info["build_tag"],
                    "isolated_effort": info["isolated_effort"],
                    "passed": bool(info["passed"]),
                    "evidence_valid": bool(info["passed"]),
                    "is_random_case": is_random_case(info),
                    "observed_txn": observed_txn,
                    "log_summary": info["log_summary"],
                    "standalone_coverage": metrics_to_raw(info["standalone"]) if info["passed"] else None,
                    "isolated_cov_per_txn": metrics_to_raw(scale_cov(info["standalone"], observed_txn))
                    if info["passed"] and observed_txn > 0
                    else None,
                    "bucket_gain_by_case": metrics_to_raw(row["increment"]) if row else None,
                    "bucket_merged_total_after_case": metrics_to_raw(row["merged"]) if row else None,
                    "bucket_gain_per_txn": metrics_to_raw(scale_cov(row["increment"], observed_txn))
                    if row and observed_txn > 0
                    else None,
                }
            )

        buckets_payload[bucket] = {
            "planned_cases": len(cases),
            "evidenced_cases": evidenced,
            "merged_bucket_total": metrics_to_raw(bucket_totals[bucket]) if evidenced else None,
            "cases": bucket_cases_payload,
            "merge_trace": [
                {
                    "step": int(row["step"]),
                    "full_case_id": str(row["case_id"]),
                    "case_id": case_info[str(row["case_id"])]["short_id"],
                    "merged_total_after_case": metrics_to_raw(row["merged"]),
                }
                for row in bucket_traces[bucket]["rows"]
            ],
        }

    random_cases_payload: list[dict[str, object]] = []
    for bucket in case_lists:
        for case_id in case_lists[bucket]:
            info = case_info[case_id]
            if not is_random_case(info):
                continue
            row = bucket_traces[bucket]["row_by_case"].get(case_id)
            observed_txn = int(info.get("observed_txn", 0))
            random_cases_payload.append(
                {
                    "full_case_id": case_id,
                    "case_id": info["short_id"],
                    "bucket": bucket,
                    "method": info["method"],
                    "description": info["description"],
                    "implemented": bool(info["implemented"]),
                    "artifact_passed": bool(info["artifact_passed"]),
                    "implementation_mode": info["implementation_mode"],
                    "build_tag": info["build_tag"],
                    "isolated_effort": info["isolated_effort"],
                    "passed": bool(info["passed"]),
                    "evidence_valid": bool(info["passed"]),
                    "observed_txn": observed_txn,
                    "standalone_coverage": metrics_to_raw(info["standalone"]) if info["passed"] else None,
                    "isolated_cov_per_txn": metrics_to_raw(scale_cov(info["standalone"], observed_txn))
                    if info["passed"] and observed_txn > 0
                    else None,
                    "bucket_gain_by_case": metrics_to_raw(row["increment"]) if row else None,
                    "bucket_gain_per_txn": metrics_to_raw(scale_cov(row["increment"], observed_txn))
                    if row and observed_txn > 0
                    else None,
                    "txn_growth_curve": (
                        "n/a: only final per-case UCDB is available"
                        if info["passed"] and observed_txn > 0
                        else "n/a: no observed txn count in log"
                    ),
                }
            )

    return {
        "report_title": args.report_title,
        "dut_name": args.dut_name,
        "date": "2026-04-16",
        "rtl_variant": args.rtl_variant,
        "seed": args.seed,
        "failed_cases": failed_cases,
        "implementation_summary": {
            "unimplemented_cases": unimplemented_cases,
            "unimplemented_count": len(unimplemented_cases),
            "stale_artifacts_without_engine_marker": stale_artifacts,
            "stale_artifact_without_engine_marker_count": len(stale_artifacts),
        },
        "bucket_summary": bucket_summary,
        "buckets": buckets_payload,
        "random_cases": random_cases_payload,
        "totals": {
            "planned_cases": planned_total,
            "evidenced_cases": evidenced_total,
            "excluded_cases": planned_total - evidenced_total,
            "merged_total_code_coverage": metrics_to_raw(all_total) if evidenced_total else None,
            "functional_coverage": {
                "pct": round(100.0 * evidenced_total / planned_total, 2) if planned_total else 0.0,
                "evidenced": evidenced_total,
                "planned": planned_total,
            },
        },
        "all_buckets_trace": [
            {
                "step": int(row["step"]),
                "bucket": case_info[str(row["case_id"])]["bucket"],
                "full_case_id": str(row["case_id"]),
                "case_id": case_info[str(row["case_id"])]["short_id"],
                "merged_total_after_case": metrics_to_raw(row["merged"]),
            }
            for row in all_trace["rows"]
        ],
        "signoff_runs": [
            {
                "run_id": run["run_id"],
                "kind": run["kind"],
                "bucket": run["bucket"],
                "build_tag": run["build_tag"],
                "sequence_name": run["sequence_name"],
                "case_count": run["case_count"],
                "effort": run.get("effort", ""),
                "iter_cap": run.get("iter_cap"),
                "payload_cap": run.get("payload_cap"),
                "code_coverage": metrics_to_raw(run["code_coverage"]),
                "cross_summary": run["cross_summary"],
            }
            for run in signoff_runs
        ],
    }


def known_failed_lines(failed_cases: list[str]) -> list[str]:
    if not failed_cases:
        return []
    return [
        "Known attempted-but-not-counted cases:",
        *[
            f"- `{case_id}` has a non-passing log and is excluded from the totals until the case/doc contract is resolved"
            for case_id in failed_cases
        ],
        "",
    ]


def implementation_gate_lines(case_info: dict[str, dict[str, object]]) -> list[str]:
    unimplemented_cases = [case_id for case_id, info in case_info.items() if not bool(info["implemented"])]
    stale_logs = [case_id for case_id, info in case_info.items() if not bool(info["implemented"]) and info["log"].exists()]
    if not unimplemented_cases:
        return []
    sample = ", ".join(f"`{case_id}`" for case_id in unimplemented_cases[:8])
    lines = [
        "Implementation gating:",
        f"- `{len(unimplemented_cases)}` documented cases do not yet have fresh `DOC_CASE_ENGINE_V2` log evidence and are excluded from coverage totals",
        f"- sample missing cases: {sample}" if sample else "- no sample cases available",
    ]
    if stale_logs:
        lines.append(
            f"- `{len(stale_logs)}` stale log/UCDB pairs without the current engine marker are ignored by this report"
        )
    lines.append("- doc-case functional coverage is case-hit based today; richer protocol/cross covergroups are still pending")
    lines.append("")
    return lines


def main() -> None:
    args = parse_args()
    ip_root = args.ip_root.resolve()
    tb_root = ip_root / "tb"

    case_lists, case_info, failed_cases = build_case_index(ip_root, args.seed, args.rtl_variant)
    unimplemented_cases = [case_id for case_id, info in case_info.items() if not bool(info["implemented"])]

    if args.strict_implementation and unimplemented_cases:
        raise SystemExit(
            f"{len(unimplemented_cases)} documented cases lack fresh {ENGINE_MARKER} evidence; "
            "stale artifacts are not allowed"
        )

    with tempfile.TemporaryDirectory(prefix="dv_case_report_") as tempdir:
        temp_root = Path(tempdir)
        bucket_evidence: dict[str, list[str]] = {}
        bucket_traces: dict[str, dict[str, object]] = {}
        bucket_totals: dict[str, dict[str, tuple[int, int]]] = {}

        for case_id, info in case_info.items():
            if info["passed"]:
                info["standalone"] = run_vcover_summary(args.vcover, info["ucdb"])
            else:
                info["standalone"] = {}

        for bucket, cases in case_lists.items():
            bucket_evidence[bucket] = [case_id for case_id in cases if case_info[case_id]["passed"]]
            bucket_traces[bucket] = build_ordered_trace(args.vcover, cases, case_info, temp_root / bucket.lower())
            bucket_totals[bucket] = bucket_traces[bucket]["final"]

        all_case_order = [case_id for bucket_cases in case_lists.values() for case_id in bucket_cases]
        all_trace = build_ordered_trace(args.vcover, all_case_order, case_info, temp_root / "all")
        all_total = all_trace["final"]

    planned_total = sum(len(cases) for cases in case_lists.values())
    evidenced_total = sum(len(case_ids) for case_ids in bucket_evidence.values())
    bucket_lookup = {case_id: str(info["bucket"]) for case_id, info in case_info.items()}
    signoff_runs = collect_signoff_runs(tb_root / "uvm", args.rtl_variant, args.seed, args.vcover)
    isolated_extensive_cases = sum(
        1 for info in case_info.values() if info.get("isolated_effort") == "extensive" and info.get("passed")
    )
    isolated_extensive_random_cases = sum(
        1
        for info in case_info.values()
        if info.get("isolated_effort") == "extensive" and info.get("passed") and is_random_case(info)
    )
    raw_payload = build_raw_payload(
        args,
        case_lists,
        case_info,
        failed_cases,
        bucket_evidence,
        bucket_traces,
        bucket_totals,
        all_trace,
        all_total,
        planned_total,
        evidenced_total,
        signoff_runs,
    )

    report_summary_rows: list[str] = []
    cov_summary_rows: list[str] = []
    for bucket, cases in case_lists.items():
        evidenced = len(bucket_evidence[bucket])
        cov_total = format_cov(bucket_totals[bucket]) if evidenced else pending_cov_string()
        all_bucket_total = (
            format_cov(all_trace["row_by_case"][bucket_evidence[bucket][-1]]["merged"])
            if evidenced
            else pending_cov_string()
        )
        func_total = f"{(100.0 * evidenced / len(cases)):.2f}% ({evidenced}/{len(cases)})"
        exec_mode = "isolated ordered-merge" if evidenced else "none yet"
        report_summary_rows.append(
            f"| {bucket} | {len(cases)} | {evidenced} | {cov_total} | {all_bucket_total} | {func_total} |"
        )
        cov_summary_rows.append(
            f"| {bucket} | {len(cases)} | {evidenced} | {exec_mode} | {cov_total} | {func_total} |"
        )

    signoff_bucket_rows: list[str] = []
    signoff_all_rows: list[str] = []
    signoff_cross_rows: list[str] = []
    for run in signoff_runs:
        cross = run.get("cross_summary")
        cross_pct = f"{cross['pct']:.2f}%" if cross else "n/a"
        txn_count = str(cross["txns"]) if cross else "0"
        overlap = str(cross["queued_overlap"]) if cross else "0"
        if run["kind"] == "bucket_frame":
            signoff_bucket_rows.append(
                f"| {run['bucket']} | {run['build_tag']} | {run.get('effort', '')} | {int(run['case_count'])} | {format_cov(run['code_coverage'])} | {cross_pct} | {txn_count} | {overlap} |"
            )
        elif run["kind"] == "all_buckets_frame":
            signoff_all_rows.append(
                f"| {run['build_tag']} | {run.get('effort', '')} | {int(run['case_count'])} | {format_cov(run['code_coverage'])} | {cross_pct} | {txn_count} | {overlap} |"
            )
        elif run["kind"] == "cross":
            curve = cross.get("curve", "") if cross else ""
            signoff_cross_rows.append(
                f"| {run['sequence_name']} | {run['build_tag']} | {run.get('effort', '')} | {format_cov(run['code_coverage'])} | {cross_pct} | {txn_count} | {overlap} | {curve if curve else 'n/a'} |"
            )
    bucket_frame_status = (
        f"{len(signoff_bucket_rows)} bucket-frame baselines captured"
        if signoff_bucket_rows
        else "pending refresh"
    )
    all_buckets_status = (
        f"{len(signoff_all_rows)} all-buckets-frame baselines captured"
        if signoff_all_rows
        else "pending refresh"
    )
    cross_status = (
        f"{len(signoff_cross_rows)} curated cross runs captured"
        if signoff_cross_rows
        else "pending refresh"
    )

    report_lines = [
        f"# DV Report: {args.report_title}",
        "",
        f"**DUT:** `{args.dut_name}`  ",
        "**Date:** 2026-04-16  ",
        f"**Execution baseline used in this report:** `{args.rtl_variant}` RTL, seed `{args.seed}`, with isolated refresh evidence plus continuous-frame signoff runs when present",
        "",
        "## Scope",
        "",
        "This report is generated from the bucket docs plus the case-keyed isolated UVM evidence under `tb/uvm/logs/` and `tb/uvm/cov_after/`.",
        f"Machine-readable raw data for this markdown is emitted to `tb/{args.raw_json_name}` in JSON format.",
        f"Isolated extensive refresh evidence currently covers `{isolated_extensive_cases}` cases, including `{isolated_extensive_random_cases}` random/seed-tagged cases.",
        "",
        "Methodology used here:",
        "- `isolated_case_coverage` is the standalone code coverage from that case's own isolated UCDB run",
        "- `bucket_gain_by_case` is the bucket-local incremental code-coverage gain added when that isolated UCDB is merged into the documented bucket order",
        "- `bucket_merged_total_after_case` is the cumulative bucket-local merged coverage after that case is added",
        "- `merged_all_buckets_total_after_bucket` shows the cumulative all-buckets merged total after the last passing case in each bucket",
        "- `observed_txn` is derived from the passing log scoreboard summary (`headers=...`) and is the current frame-count proxy for per-txn reporting",
        "- `isolated_cov_per_txn` and `bucket_gain_per_txn` are average-per-observed-txn views; true intra-case marginal gain curves need checkpoint UCDBs across txn growth and are not available in the current evidence",
        f"- only fresh testcase logs/UCDBs that carry the `{ENGINE_MARKER}` marker are counted as valid evidence",
        "- cases without a passing isolated log/UCDB pair remain `pending` and do not contribute to bucket totals",
        "- continuous-frame baselines are tracked per compatible build tag because mixed generic configurations cannot legally share one DUT image",
        "- continuous-frame signoff runs use reduced per-case iteration and payload caps so the full 520-case refresh stays rerunnable; isolated runs remain the per-case coverage reference",
        "",
        *known_failed_lines(failed_cases),
        *implementation_gate_lines(case_info),
        "## Execution Profiles",
        "",
        "- `isolated_refresh`: the practical full-520 rerunnable baseline; every documented case runs as a fresh testcase and feeds the per-case tables below.",
        "- `bucket_frame`: no-restart runs for each bucket inside each compatible build domain, using capped practical budgets to expose sequential-state and carry-over effects.",
        "- `all_buckets_frame`: no-restart runs across all buckets inside each compatible build domain, using capped practical budgets as the long-run ordered baseline.",
        "- `isolated_extensive_stress`: a targeted isolated rerun of the long/random PROF cases so their final UCDBs reflect the full documented stress budget rather than the practical cap.",
        "- `cross`: curated sequential and near-back-to-back mixes that drive GOOD-ERROR-GOOD and interleaved patterns while the scoreboard performs delayed backdoor counter checks.",
        "",
        "## Bucket Summary",
        "",
        "| bucket | planned_cases | evidenced_cases | merged_bucket_total | merged_all_buckets_total_after_bucket | current_functional_coverage_total |",
        "|---|---:|---:|---|---|---|",
        *report_summary_rows,
        "",
        "CROSS signoff baselines are summarized separately below because they are continuous-frame sequences, not isolated bucket rows.",
        "",
        "## Continuous-Frame Baselines",
        "",
        "| bucket | build | effort | case_count | code_coverage_total | functional_cross_total | txn_count | queued_overlap |",
        "|---|---|---|---:|---|---|---:|---:|",
        *(signoff_bucket_rows if signoff_bucket_rows else ["| pending | pending | pending | 0 | n/a | n/a | 0 | 0 |"]),
        "",
        "| build | effort | case_count | code_coverage_total | functional_cross_total | txn_count | queued_overlap |",
        "|---|---|---:|---|---|---:|---:|",
        *(signoff_all_rows if signoff_all_rows else ["| pending | pending | 0 | n/a | n/a | 0 | 0 |"]),
        "",
        "## Cross Signoff Summary",
        "",
        "| sequence | build | effort | code_coverage_total | functional_cross_total | txn_count | queued_overlap | txn_growth_curve |",
        "|---|---|---|---|---|---:|---:|---|",
        *(signoff_cross_rows if signoff_cross_rows else ["| pending | pending | pending | n/a | n/a | 0 | 0 | n/a |"]),
        "",
    ]

    for bucket, cases in case_lists.items():
        write_report_bucket_table(report_lines, bucket, cases, case_info, bucket_traces[bucket])

    write_random_case_summary(report_lines, case_lists, case_info, bucket_traces)
    report_lines.extend(
        [
            "## CROSS Bucket",
            "",
            "| sequence | build | effort | code_coverage_total | functional_cross_total | txn_count | queued_overlap | txn_growth_curve |",
            "|---|---|---|---|---|---:|---:|---|",
            *(signoff_cross_rows if signoff_cross_rows else ["| pending | pending | pending | n/a | n/a | 0 | 0 | n/a |"]),
            "",
        ]
    )
    report_lines.extend(
        [
            "## Current Totals",
            "",
            f"- Merged total code coverage across all passing doc-case evidence: `{format_cov(all_total) if evidenced_total else pending_cov_string()}`",
            f"- Total final functional coverage from visible testcase rows: `{(100.0 * evidenced_total / planned_total):.2f}% ({evidenced_total}/{planned_total} planned cases evidenced)`",
            f"- Cases excluded from totals because they do not yet have passing evidence: `{planned_total - evidenced_total}`",
            "- True per-random-case txn-growth deltas are not yet available because the current run flow stores one final UCDB per case rather than checkpoint UCDBs at intermediate txn counts.",
            f"- `bucket_frame` status: {bucket_frame_status}",
            f"- `all_buckets_frame` status: {all_buckets_status}",
            f"- `cross` status: {cross_status}",
            "",
        ]
    )

    cov_lines = [
        f"# DV Coverage Tracking — {args.report_title}",
        "",
        f"**DUT:** `{args.dut_name}`  ",
        "**Date:** 2026-04-16  ",
        f"**Execution baseline tracked here:** `{args.rtl_variant}` RTL, seed `{args.seed}`, isolated refresh plus continuous-frame signoff runs when present",
        "",
        "Execution-mode status:",
        "- `isolated`: tracked in this file as ordered incremental gains from passing case-keyed UCDBs merged in bucket order, then documented case order",
        f"- `bucket_frame`: {bucket_frame_status}",
        f"- `all_buckets_frame`: {all_buckets_status}",
        f"- `cross`: {cross_status}",
        "",
        *known_failed_lines(failed_cases),
        *implementation_gate_lines(case_info),
        "## Bucket Summary",
        "",
        "| bucket | planned_cases | evidenced_cases | execution_mode_baseline | current_code_coverage_total | current_functional_coverage_total |",
        "|---|---:|---:|---|---|---|",
        *cov_summary_rows,
        "| CROSS | n/a | 0 | none yet | n/a | 0.00% (protocol CROSS covergroups still pending) |",
        "",
        "## Continuous-Frame Baselines",
        "",
        "| bucket | build | effort | case_count | code_coverage_total | functional_cross_total | txn_count | queued_overlap |",
        "|---|---|---|---:|---|---|---:|---:|",
        *(signoff_bucket_rows if signoff_bucket_rows else ["| pending | pending | pending | 0 | n/a | n/a | 0 | 0 |"]),
        "",
        "| build | effort | case_count | code_coverage_total | functional_cross_total | txn_count | queued_overlap |",
        "|---|---|---:|---|---|---:|---:|",
        *(signoff_all_rows if signoff_all_rows else ["| pending | pending | 0 | n/a | n/a | 0 | 0 |"]),
        "",
    ]

    for bucket, cases in case_lists.items():
        write_bucket_table(cov_lines, bucket, cases, case_info, all_trace, bucket_traces[bucket])

    write_ordered_trace(cov_lines, "## All-Buckets Ordered Isolated Merge Trace", all_trace["rows"], bucket_lookup)
    cov_lines.extend(
        [
            "## All-Buckets Totals",
            "",
            f"- merged isolated total code coverage: `{format_cov(all_total) if evidenced_total else pending_cov_string()}`",
            f"- total final functional coverage: `{(100.0 * evidenced_total / planned_total):.2f}% ({evidenced_total}/{planned_total} planned cases evidenced)`",
            f"- `bucket_frame` status: {bucket_frame_status}",
            f"- `all_buckets_frame` status: {all_buckets_status}",
            f"- `cross` status: {cross_status}",
            "",
        ]
    )

    (tb_root / args.raw_json_name).write_text(json.dumps(raw_payload, indent=2) + "\n")
    (tb_root / "DV_REPORT.md").write_text("\n".join(report_lines) + "\n")
    (tb_root / "DV_COV.md").write_text("\n".join(cov_lines) + "\n")


if __name__ == "__main__":
    main()
