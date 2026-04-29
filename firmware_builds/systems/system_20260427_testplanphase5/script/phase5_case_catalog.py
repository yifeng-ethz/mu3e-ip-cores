#!/usr/bin/env python3
"""Parse Phase-5 Markdown bucket catalogs into executable case manifests."""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
REPO_ROOT = SYSTEM_DIR.parent.parent.parent
DEFAULT_DOC_DIR = REPO_ROOT / "firmware_builds" / "doc"

BUCKETS = {
    "BASIC": ("TEST_BASIC.md", "TPB5BAS"),
    "PROF": ("TEST_PROF.md", "TPB5PRO"),
    "EDGE": ("TEST_EDGE.md", "TPB5EDG"),
    "ERROR": ("TEST_ERROR.md", "TPB5ERR"),
}

EXPECTED_CASES_PER_BUCKET = 144
VALID_STATUSES = {"not-run", "ready", "running", "PASS", "FAIL", "BLOCKED", "WAIVED"}
NON_STIMULUS_COLUMNS = {"case_id", "trigger", "taps", "taps (deepened)", "evidence", "MATCH"}
GROUP_SOURCE_DEFAULTS = {
    ("PROF", "P1"): "EMU",
    ("PROF", "P2"): "EMU",
    ("PROF", "P3"): "EMU",
    ("PROF", "P5"): "EMU",
    ("PROF", "P6"): "EMU",
    ("PROF", "P7"): "EMU",
    ("PROF", "P9"): "MIXED",
    ("PROF", "P10"): "EMU",
    ("EDGE", "E1"): "EMU",
    ("EDGE", "E2"): "EMU",
    ("EDGE", "E3"): "EMU",
    ("EDGE", "E4"): "EMU",
    ("EDGE", "E5"): "EMU",
    ("EDGE", "E6"): "EMU",
    ("EDGE", "E7"): "EMU",
    ("EDGE", "E8"): "EMU",
    ("EDGE", "E9"): "EMU",
    ("ERROR", "X1"): "EMU",
    ("ERROR", "X2"): "EMU",
    ("ERROR", "X3"): "EMU",
    ("ERROR", "X4"): "EMU",
    ("ERROR", "X5"): "EMU",
    ("ERROR", "X6"): "EMU",
    ("ERROR", "X7"): "EMU",
    ("ERROR", "X8"): "EMU",
    ("ERROR", "X9"): "EMU",
    ("ERROR", "X10"): "EMU",
}


@dataclass(frozen=True)
class ScoreboardGroup:
    bucket: str
    group: str
    cases: int
    status: str
    passed: int
    failed: int
    blocked: int
    last_evidence: str
    notes: str
    line_no: int


@dataclass(frozen=True)
class CaseRow:
    bucket: str
    prefix: str
    group: str
    group_title: str
    row_expr: str
    columns: dict[str, str]
    line_no: int


@dataclass(frozen=True)
class CaseManifest:
    case_id: str
    bucket: str
    group: str
    group_title: str
    group_status: str
    row_expr: str
    row_line: int
    stimulus: str
    trigger: str
    taps: str
    evidence: str
    match: str
    tap_ids: list[str]
    source_class: str
    lanes: list[int]


def split_md_row(line: str) -> list[str]:
    stripped = line.strip()
    if not stripped.startswith("|") or not stripped.endswith("|"):
        return []
    return [cell.strip() for cell in stripped.strip("|").split("|")]


def is_separator(line: str) -> bool:
    cells = split_md_row(line)
    return bool(cells) and all(re.fullmatch(r":?-{3,}:?", cell.strip()) for cell in cells)


def parse_int_cell(text: str, path: Path, line_no: int, name: str) -> int:
    try:
        return int(text)
    except ValueError as exc:
        raise ValueError(f"{path}:{line_no}: invalid integer in {name}: {text!r}") from exc


def parse_scoreboard(path: Path, bucket: str) -> dict[str, ScoreboardGroup]:
    lines = path.read_text().splitlines()
    in_scoreboard = False
    groups: dict[str, ScoreboardGroup] = {}

    for idx, line in enumerate(lines):
        if line.startswith("## Execution scoreboard"):
            in_scoreboard = True
            continue
        if in_scoreboard and line.startswith("## "):
            break
        if not in_scoreboard:
            continue
        if not line.startswith("|"):
            continue
        if idx + 1 >= len(lines) or not is_separator(lines[idx + 1]):
            continue

        header = split_md_row(line)
        row_idx = idx + 2
        while row_idx < len(lines) and lines[row_idx].startswith("|"):
            row = split_md_row(lines[row_idx])
            if len(row) != len(header):
                raise ValueError(
                    f"{path}:{row_idx + 1}: scoreboard row has {len(row)} columns, expected {len(header)}"
                )
            item = dict(zip(header, row))
            group = item.get("Group", "")
            if group and group != "Group":
                status = item.get("Status", "")
                if status not in VALID_STATUSES:
                    raise ValueError(f"{path}:{row_idx + 1}: invalid status {status!r}")
                groups[group] = ScoreboardGroup(
                    bucket=bucket,
                    group=group,
                    cases=parse_int_cell(item.get("Cases", "0"), path, row_idx + 1, "Cases"),
                    status=status,
                    passed=parse_int_cell(item.get("PASS", "0"), path, row_idx + 1, "PASS"),
                    failed=parse_int_cell(item.get("FAIL", "0"), path, row_idx + 1, "FAIL"),
                    blocked=parse_int_cell(item.get("BLOCKED", "0"), path, row_idx + 1, "BLOCKED"),
                    last_evidence=item.get("Last evidence", ""),
                    notes=item.get("Notes", ""),
                    line_no=row_idx + 1,
                )
            row_idx += 1

    return groups


def parse_case_id_ranges(prefix: str, text: str) -> list[tuple[int, int]]:
    ranges: list[tuple[int, int]] = []
    for match in re.finditer(rf"\b{re.escape(prefix)}(\d{{3}})(?:\.\.(\d{{3}}))?\b", text):
        start = int(match.group(1))
        end = int(match.group(2) or match.group(1))
        ranges.append((start, end))
    return ranges


def expand_case_expr(prefix: str, text: str) -> list[str]:
    case_ids: list[str] = []
    for start, end in parse_case_id_ranges(prefix, text):
        if end < start:
            raise ValueError(f"descending case range {prefix}{start:03d}..{end:03d}")
        case_ids.extend(f"{prefix}{idx:03d}" for idx in range(start, end + 1))
    return case_ids


def parse_case_rows(path: Path, bucket: str, prefix: str) -> list[CaseRow]:
    lines = path.read_text().splitlines()
    rows: list[CaseRow] = []
    current_group = ""
    current_title = ""
    previous_case_columns: dict[str, str] = {}

    for idx, line in enumerate(lines):
        group_match = re.match(r"^### Group\s+([A-Za-z0-9]+)\s+(?:\u2014|-)\s+(.+)$", line)
        if group_match:
            current_group = group_match.group(1)
            current_title = group_match.group(2)
            previous_case_columns = {}
            continue

        if not line.startswith("|"):
            continue
        if idx + 1 >= len(lines) or not is_separator(lines[idx + 1]):
            continue

        header = split_md_row(line)
        row_idx = idx + 2
        while row_idx < len(lines) and lines[row_idx].startswith("|"):
            row = split_md_row(lines[row_idx])
            if len(row) != len(header):
                raise ValueError(
                    f"{path}:{row_idx + 1}: catalog row has {len(row)} columns, expected {len(header)}"
                )
            if row and parse_case_id_ranges(prefix, row[0]):
                if not current_group:
                    raise ValueError(f"{path}:{row_idx + 1}: case row found before a group heading")
                resolved = resolve_inherited_columns(dict(zip(header, row)), previous_case_columns)
                rows.append(
                    CaseRow(
                        bucket=bucket,
                        prefix=prefix,
                        group=current_group,
                        group_title=current_title,
                        row_expr=row[0],
                        columns=resolved,
                        line_no=row_idx + 1,
                    )
                )
                previous_case_columns.update(
                    {name: value for name, value in resolved.items() if name != header[0] and value}
                )
            row_idx += 1

    return rows


def pick_column(columns: dict[str, str], names: tuple[str, ...]) -> str:
    for name in names:
        if name in columns:
            return columns[name]
    return ""


def build_stimulus(columns: dict[str, str]) -> str:
    parts: list[str] = []
    for name, value in columns.items():
        if name in NON_STIMULUS_COLUMNS or not value:
            continue
        if name in {"stimulus", "scenario", "mix", "pressure pattern"}:
            parts.append(value)
        else:
            parts.append(f"{name}={value}")
    return "; ".join(parts)


def is_inherit_cell(text: str) -> bool:
    return text.strip().lower() in {"same", "(same)", "same as above"}


def resolve_inherited_columns(columns: dict[str, str], previous: dict[str, str]) -> dict[str, str]:
    resolved: dict[str, str] = {}
    for name, value in columns.items():
        if is_inherit_cell(value) and name in previous:
            resolved[name] = previous[name]
        else:
            resolved[name] = value
    return resolved


def parse_tap_ids(taps: str) -> list[str]:
    ids: set[str] = set()
    for match in re.finditer(r"\bT([0-8])\s*\.\.\s*T([0-8])\b", taps):
        start = int(match.group(1))
        end = int(match.group(2))
        step = 1 if start <= end else -1
        ids.update(f"T{idx}" for idx in range(start, end + step, step))
    ids.update(f"T{match.group(1)}" for match in re.finditer(r"\bT([0-8])\b", taps))
    if re.search(r"\bTS\b", taps):
        ids.add("TS")
    return sorted(ids, key=lambda item: (99 if item == "TS" else int(item[1:])))


def parse_braced_lanes(text: str) -> set[int]:
    found: set[int] = set()
    for match in re.finditer(r"\{([^{}]+)\}", text):
        found.update(parse_lane_list(match.group(1)))
    return found


def parse_lane_list(text: str) -> set[int]:
    found: set[int] = set()
    for token in text.split(","):
        token = token.strip()
        range_match = re.fullmatch(r"([0-7])\s*\.\.\s*([0-7])", token)
        if range_match:
            start = int(range_match.group(1))
            end = int(range_match.group(2))
            if start <= end:
                found.update(range(start, end + 1))
            continue
        if re.fullmatch(r"[0-7]", token):
            found.add(int(token))
    return found


def parse_lanes_from_contextual_braces(text: str) -> set[int]:
    found: set[int] = set()
    context_patterns = (
        r"\blane\s+pair\s*\{([^{}]+)\}",
        r"\blane\s+[A-Za-z]\s*(?:=|in|\u2208)?\s*\{([^{}]+)\}",
        r"\bASIC\s+subset\s*\{([^{}]+)\}",
    )
    for pattern in context_patterns:
        for match in re.finditer(pattern, text, flags=re.IGNORECASE):
            found.update(parse_lane_list(match.group(1)))

    grouped_context_patterns = (
        r"\bhot-pair\s+matrix\s+((?:\{[^{}]+\}\s*,?\s*)+)",
        r"\bsource\s+pairs?\s+((?:\{[^{}]+\}\s*,?\s*)+)",
    )
    for pattern in grouped_context_patterns:
        for match in re.finditer(pattern, text, flags=re.IGNORECASE):
            found.update(parse_braced_lanes(match.group(1)))
    return found


def parse_lanes_from_ranges(text: str) -> set[int]:
    found: set[int] = set()
    range_patterns = (
        r"\blanes?\s+([0-7])\.\.([0-7])\b",
        r"\bASIC\s+([0-7])\.\.([0-7])\b",
        r"\bASIC\s+subset\s+([0-7])\.\.([0-7])\b",
        r"\bk\s*=\s*([0-7])\.\.([0-7])\b",
    )
    for pattern in range_patterns:
        for match in re.finditer(pattern, text, flags=re.IGNORECASE):
            start = int(match.group(1))
            end = int(match.group(2))
            if start <= end:
                found.update(range(start, end + 1))
    return found


def parse_lanes(*texts: str) -> list[int]:
    found: set[int] = set()
    joined = " ".join(texts)
    for match in re.finditer(r"\blane\s+(\d)\b", joined, flags=re.IGNORECASE):
        found.add(int(match.group(1)))
    for match in re.finditer(r"\bASIC\s+([0-7])\b", joined, flags=re.IGNORECASE):
        found.add(int(match.group(1)))
    for match in re.finditer(r"\blanes_active\s*=\s*(0x[0-9a-fA-F]+|\d+)\b", joined, flags=re.IGNORECASE):
        mask = int(match.group(1), 0)
        found.update(idx for idx in range(8) if mask & (1 << idx))
    found.update(parse_lanes_from_ranges(joined))
    found.update(parse_lanes_from_contextual_braces(joined))
    return sorted(found)


def classify_source_text(text: str) -> str:
    upper = text.upper()
    has_emu = bool(re.search(r"\b(?:EMU|EMULATOR)\b", upper))
    has_real = bool(re.search(r"\bREAL(?:[-\s]+MUTRIG|\s+ASIC|\s+LVDS|\s+SOURCE|\s+LANE)\b", upper))
    if "MIX" in upper or (has_emu and has_real):
        return "MIXED"
    if has_real:
        return "REAL"
    if has_emu:
        return "EMU"
    return "UNSPECIFIED"


def classify_source(row: CaseRow, stimulus: str) -> str:
    explicit = classify_source_text(" ".join([stimulus, row.group_title]))
    if explicit != "UNSPECIFIED":
        return explicit
    return GROUP_SOURCE_DEFAULTS.get((row.bucket, row.group), "UNSPECIFIED")


def row_to_manifests(row: CaseRow, group_status: str) -> list[CaseManifest]:
    case_ids = expand_case_expr(row.prefix, row.row_expr)
    stimulus = build_stimulus(row.columns)
    trigger = pick_column(row.columns, ("trigger",))
    taps = pick_column(row.columns, ("taps", "taps (deepened)"))
    evidence = pick_column(row.columns, ("evidence",))
    match = pick_column(row.columns, ("MATCH",))
    text_for_lane_parse = " ".join([row.row_expr, stimulus, trigger, taps, evidence])
    return [
        CaseManifest(
            case_id=case_id,
            bucket=row.bucket,
            group=row.group,
            group_title=row.group_title,
            group_status=group_status,
            row_expr=row.row_expr,
            row_line=row.line_no,
            stimulus=stimulus,
            trigger=trigger,
            taps=taps,
            evidence=evidence,
            match=match,
            tap_ids=parse_tap_ids(taps),
            source_class=classify_source(row, stimulus),
            lanes=parse_lanes(text_for_lane_parse),
        )
        for case_id in case_ids
    ]


def load_catalog(doc_dir: Path) -> tuple[dict[str, ScoreboardGroup], dict[str, CaseManifest], list[str]]:
    scoreboards: dict[str, ScoreboardGroup] = {}
    cases: dict[str, CaseManifest] = {}
    errors: list[str] = []

    for bucket, (file_name, prefix) in BUCKETS.items():
        path = doc_dir / file_name
        if not path.is_file():
            errors.append(f"missing bucket file: {path}")
            continue

        try:
            bucket_scoreboard = parse_scoreboard(path, bucket)
            rows = parse_case_rows(path, bucket, prefix)
        except ValueError as exc:
            errors.append(str(exc))
            continue

        scoreboards.update({f"{bucket}:{group}": row for group, row in bucket_scoreboard.items()})
        groups_in_cases = {row.group for row in rows}
        groups_in_scoreboard = set(bucket_scoreboard)
        for group in sorted(groups_in_cases - groups_in_scoreboard):
            errors.append(f"{path}: group {group} has cases but no scoreboard row")
        for group in sorted(groups_in_scoreboard - groups_in_cases):
            errors.append(f"{path}: scoreboard group {group} has no catalog rows")

        for row in rows:
            group_status = bucket_scoreboard.get(row.group).status if row.group in bucket_scoreboard else "not-run"
            try:
                manifests = row_to_manifests(row, group_status)
            except ValueError as exc:
                errors.append(f"{path}:{row.line_no}: {exc}")
                continue
            for manifest in manifests:
                if manifest.case_id in cases:
                    errors.append(f"{path}:{row.line_no}: duplicate case id {manifest.case_id}")
                cases[manifest.case_id] = manifest

        expected = {f"{prefix}{idx:03d}" for idx in range(1, EXPECTED_CASES_PER_BUCKET + 1)}
        actual = {case_id for case_id in cases if case_id.startswith(prefix)}
        missing = sorted(expected - actual)
        extra = sorted(actual - expected)
        if missing:
            errors.append(f"{path}: missing {len(missing)} {prefix} cases: {', '.join(missing[:16])}")
        if extra:
            errors.append(f"{path}: extra {len(extra)} {prefix} cases: {', '.join(extra[:16])}")

        scoreboard_total = sum(item.cases for item in bucket_scoreboard.values())
        if scoreboard_total != EXPECTED_CASES_PER_BUCKET:
            errors.append(f"{path}: scoreboard totals {scoreboard_total}, expected {EXPECTED_CASES_PER_BUCKET}")
        for item in bucket_scoreboard.values():
            if item.passed + item.failed + item.blocked > item.cases:
                errors.append(f"{path}:{item.line_no}: PASS+FAIL+BLOCKED exceeds case count for {item.group}")

    return scoreboards, cases, errors


def manifest_to_dict(item: CaseManifest) -> dict[str, Any]:
    return {
        "case_id": item.case_id,
        "bucket": item.bucket,
        "group": item.group,
        "group_title": item.group_title,
        "group_status": item.group_status,
        "row_expr": item.row_expr,
        "row_line": item.row_line,
        "source_class": item.source_class,
        "lanes": item.lanes,
        "tap_ids": item.tap_ids,
        "stimulus": item.stimulus,
        "trigger": item.trigger,
        "taps": item.taps,
        "evidence": item.evidence,
        "match": item.match,
    }


def print_summary(cases: dict[str, CaseManifest], scoreboards: dict[str, ScoreboardGroup]) -> None:
    for bucket, (_, prefix) in BUCKETS.items():
        bucket_cases = [case for case in cases.values() if case.bucket == bucket]
        bucket_groups = [item for item in scoreboards.values() if item.bucket == bucket]
        not_run = sum(item.cases for item in bucket_groups if item.status == "not-run")
        ready = sum(item.cases for item in bucket_groups if item.status == "ready")
        running = sum(item.cases for item in bucket_groups if item.status == "running")
        passed = sum(item.passed for item in bucket_groups)
        failed = sum(item.failed for item in bucket_groups)
        blocked = sum(item.blocked for item in bucket_groups)
        print(
            f"{bucket}: cases={len(bucket_cases)} prefix={prefix} "
            f"not-run={not_run} ready={ready} running={running} "
            f"PASS={passed} FAIL={failed} BLOCKED={blocked}"
        )


def print_manifest(item: CaseManifest) -> None:
    print(f"CASE {item.case_id}")
    print(f"BUCKET {item.bucket}")
    print(f"GROUP {item.group} - {item.group_title}")
    print(f"STATUS {item.group_status}")
    print(f"ROW {item.row_expr} line={item.row_line}")
    print(f"SOURCE {item.source_class}")
    print(f"LANES {','.join(str(lane) for lane in item.lanes) if item.lanes else 'unspecified'}")
    print(f"TAPS {','.join(item.tap_ids) if item.tap_ids else item.taps}")
    print(f"TRIGGER {item.trigger}")
    print(f"STIMULUS {item.stimulus}")
    print(f"EXPECTED {item.evidence}")
    print(f"MATCH {item.match or 'pending'}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--doc-dir", type=Path, default=DEFAULT_DOC_DIR)
    parser.add_argument("--summary", action="store_true", help="Print per-bucket summary")
    parser.add_argument("--validate", action="store_true", help="Validate bucket counts and scoreboard consistency")
    parser.add_argument("--json", action="store_true", help="Print expanded case manifest JSON")
    parser.add_argument("--write-json", type=Path, help="Write expanded case manifest JSON to this file")
    parser.add_argument("--case", action="append", help="Print plaintext manifest for one case id")
    args = parser.parse_args()

    scoreboards, cases, errors = load_catalog(args.doc_dir)

    if args.summary or (not args.json and not args.write_json and not args.case):
        print_summary(cases, scoreboards)

    if args.case:
        for case_id in args.case:
            item = cases.get(case_id)
            if item is None:
                errors.append(f"unknown case id: {case_id}")
                continue
            print_manifest(item)

    payload = {
        "doc_dir": str(args.doc_dir.resolve()),
        "expected_cases_per_bucket": EXPECTED_CASES_PER_BUCKET,
        "cases": [manifest_to_dict(cases[case_id]) for case_id in sorted(cases)],
        "scoreboard": [
            {
                "bucket": item.bucket,
                "group": item.group,
                "cases": item.cases,
                "status": item.status,
                "PASS": item.passed,
                "FAIL": item.failed,
                "BLOCKED": item.blocked,
                "last_evidence": item.last_evidence,
                "notes": item.notes,
                "line_no": item.line_no,
            }
            for item in sorted(scoreboards.values(), key=lambda row: (row.bucket, row.group))
        ],
    }

    if args.json:
        print(json.dumps(payload, indent=2, sort_keys=True))
    if args.write_json:
        args.write_json.parent.mkdir(parents=True, exist_ok=True)
        args.write_json.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")

    if errors:
        for error in errors:
            print(f"ERROR {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
