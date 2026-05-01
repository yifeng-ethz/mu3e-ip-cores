#!/usr/bin/env python3
"""Check Phase-6 mask-response raw histogram CSVs against intended masks."""

from __future__ import annotations

import argparse
import csv
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
REPORT_DIR = SYSTEM_DIR / "reports"


def load_counts(path: Path) -> dict[int, int]:
    counts: dict[int, int] = {}
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle):
            counts[int(row["bin_index"])] = int(float(row["count"]))
    return counts


def check_case(
    *,
    kind: str,
    case: str,
    mask: str,
    expected: set[int],
    csv_path: Path,
    on_threshold: int,
    good_threshold: int,
) -> dict[str, Any]:
    counts = load_counts(csv_path)
    observed_on = {bin_i for bin_i, count in counts.items() if count >= on_threshold}
    observed_good = {bin_i for bin_i, count in counts.items() if count >= good_threshold}
    unexpected_on = sorted(observed_on - expected)
    missing_on = sorted(expected - observed_on)
    weak_on = sorted(bin_i for bin_i in expected if counts.get(bin_i, 0) < good_threshold)
    off_counts = [counts.get(bin_i, 0) for bin_i in set(range(256)) - expected]
    on_counts = [counts.get(bin_i, 0) for bin_i in expected]
    return {
        "kind": kind,
        "case": case,
        "mask": mask,
        "expected_on": len(expected),
        "observed_nonzero": len(observed_on),
        "observed_ge_50k": len(observed_good),
        "unexpected_on": ",".join(str(value) for value in unexpected_on),
        "missing_on": ",".join(str(value) for value in missing_on),
        "weak_expected_lt_50k": ",".join(str(value) for value in weak_on),
        "max_off_count": max(off_counts) if off_counts else 0,
        "min_on_count": min(on_counts) if on_counts else 0,
        "max_on_count": max(on_counts) if on_counts else 0,
        "pass_exact_nonzero": int(not unexpected_on and not missing_on),
        "pass_50k_gate": int(not unexpected_on and not weak_on),
        "csv": str(csv_path),
    }


def load_asic_cases(path: Path, on_threshold: int, good_threshold: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            mask = int(row["lvds_mask"], 0)
            lanes = [lane for lane in range(8) if mask & (1 << lane)]
            expected = {
                global_ch
                for lane in lanes
                for global_ch in range(lane * 32, lane * 32 + 32)
            }
            rows.append(
                check_case(
                    kind=row["kind"],
                    case=row["case"],
                    mask=f"lvds_mask={row['lvds_mask']} lanes={lanes}",
                    expected=expected,
                    csv_path=Path(row["csv"]),
                    on_threshold=on_threshold,
                    good_threshold=good_threshold,
                )
            )
    return rows


def load_channel_cases(path: Path, on_threshold: int, good_threshold: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open(newline="", encoding="utf-8") as handle:
        for row in csv.DictReader(handle, delimiter="\t"):
            channel_mask = int(row["channel_mask"], 0)
            enabled = [channel for channel in range(32) if channel_mask & (1 << channel)]
            expected = {asic * 32 + channel for asic in range(8) for channel in enabled}
            rows.append(
                check_case(
                    kind=row["kind"],
                    case=row["case"],
                    mask=f"channel_mask={row['channel_mask']} enabled={enabled}",
                    expected=expected,
                    csv_path=Path(row["csv"]),
                    on_threshold=on_threshold,
                    good_threshold=good_threshold,
                )
            )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-dir", type=Path, default=REPORT_DIR)
    parser.add_argument("--on-threshold", type=int, default=1)
    parser.add_argument("--good-threshold", type=int, default=50_000)
    parser.add_argument("--output", type=Path, default=None)
    args = parser.parse_args()

    report_dir = args.report_dir
    output = args.output or report_dir / "phase6_mask_response_raw_mask_check_seed20260501.tsv"
    rows = []
    rows.extend(
        load_asic_cases(
            report_dir / "phase6_mask_response_asic_lvds_seed20260501.summary.tsv",
            args.on_threshold,
            args.good_threshold,
        )
    )
    rows.extend(
        load_channel_cases(
            report_dir / "phase6_mask_response_channel_seed20260501.summary.tsv",
            args.on_threshold,
            args.good_threshold,
        )
    )

    fields = [
        "kind",
        "case",
        "mask",
        "expected_on",
        "observed_nonzero",
        "observed_ge_50k",
        "unexpected_on",
        "missing_on",
        "weak_expected_lt_50k",
        "max_off_count",
        "min_on_count",
        "max_on_count",
        "pass_exact_nonzero",
        "pass_50k_gate",
        "csv",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, delimiter="\t", lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

    all_exact = all(row["pass_exact_nonzero"] for row in rows)
    all_good = all(row["pass_50k_gate"] for row in rows)
    print(f"wrote={output}")
    print(f"cases={len(rows)} all_exact_nonzero_match={int(all_exact)} all_50k_gate_match={int(all_good)}")
    return 0 if all_exact and all_good else 1


if __name__ == "__main__":
    raise SystemExit(main())
