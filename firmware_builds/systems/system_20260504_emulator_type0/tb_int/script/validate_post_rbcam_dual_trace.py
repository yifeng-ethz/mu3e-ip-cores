#!/usr/bin/env python3
"""Validate dual-UVM post-rbCAM no-loss evidence for PROF-INT-002 runs."""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path


CASE_SETS = {
    "asic0_full32_emu": [
        "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_010k_1ms_gap1ms_20260507",
        "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_100k_1ms_gap1ms_20260507",
        "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_500k_1ms_gap1ms_20260507",
        "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_1000k_1ms_gap1ms_20260507",
    ],
}

RECONCILE_RE = re.compile(
    r"reconcile\[check\].*?"
    r"A=(?P<A>\d+)\s+stable_A=(?P<stable_A>\d+)\s+PRE=(?P<PRE>\d+)\s+"
    r"pre_fanout_dupe=(?P<pre_fanout_dupe>\d+)\s+POST=(?P<POST>\d+)\s+FEB=(?P<FEB>\d+).*?"
    r"residuals fifo A->PRE matched/missing/ghost="
    r"(?P<fifo_a_pre_matched>\d+)/(?P<fifo_a_pre_missing>\d+)/(?P<fifo_a_pre_ghost>\d+)\s+"
    r"PRE->POST=(?P<fifo_pre_post_matched>\d+)/(?P<fifo_pre_post_missing>\d+)/(?P<fifo_pre_post_ghost>\d+)\s+"
    r"POST->FEB=(?P<fifo_post_feb_matched>\d+)/(?P<fifo_post_feb_missing>\d+)/(?P<fifo_post_feb_ghost>\d+).*?"
    r"debug_obs A/SRC/PRE/POST/FEB="
    r"(?P<debug_A>\d+)/(?P<debug_SRC>\d+)/(?P<debug_PRE>\d+)/(?P<debug_POST>\d+)/(?P<debug_FEB>\d+)\s+"
    r"debug_residuals SRC->PRE="
    r"(?P<debug_src_pre_matched>\d+)/(?P<debug_src_pre_missing>\d+)/(?P<debug_src_pre_ghost>\d+)\s+"
    r"PRE->POST=(?P<debug_pre_post_matched>\d+)/(?P<debug_pre_post_missing>\d+)/(?P<debug_pre_post_ghost>\d+)\s+"
    r"POST->FEB=(?P<debug_post_feb_matched>\d+)/(?P<debug_post_feb_missing>\d+)/(?P<debug_post_feb_ghost>\d+)\s+"
    r"debug_duplicate_ids=(?P<debug_duplicate_ids>\d+)"
)


def read_text(path: Path) -> str:
    return path.read_text(encoding="utf-8", errors="replace") if path.is_file() else ""


def extract_count(text: str, name: str) -> int:
    matches = re.findall(rf"#\s*{re.escape(name)}\s*:\s*(\d+)", text)
    return int(matches[-1]) if matches else -1


def read_counter_agreement(case_dir: Path) -> dict[str, tuple[int, int, int, int]]:
    path = case_dir / "counter_agreement.csv"
    counters: dict[str, tuple[int, int, int, int]] = {}
    if not path.is_file():
        return counters
    with path.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            counters[row["counter"]] = (
                int(row["scoreboard_count"]),
                int(row["counter_count"]),
                int(row["available"]),
                int(row["agree"]),
            )
    return counters


def validate_case(sim_root: Path, log_root: Path, case_name: str) -> dict[str, object]:
    case_dir = sim_root / case_name
    text = read_text(case_dir / "transcript")
    if not text:
        text = read_text(log_root / f"{case_name}.summary.txt")

    matches = list(RECONCILE_RE.finditer(text))
    values = {key: -1 for key in RECONCILE_RE.groupindex}
    if matches:
        values.update({key: int(value) for key, value in matches[-1].groupdict().items()})

    counters = read_counter_agreement(case_dir)
    required_counters = ("stage_a", "pre_rbcam", "post_rbcam")
    counter_ok = all(counters.get(name, (0, 0, 0, 0))[2:] == (1, 1) for name in required_counters)

    uvm_error = extract_count(text, "UVM_ERROR")
    uvm_fatal = extract_count(text, "UVM_FATAL")
    test_passed = "*** TEST PASSED ***" in text

    no_loss = (
        values["fifo_a_pre_missing"] == 0
        and values["fifo_a_pre_ghost"] == 0
        and values["fifo_pre_post_missing"] == 0
        and values["fifo_pre_post_ghost"] == 0
        and values["debug_src_pre_missing"] == 0
        and values["debug_src_pre_ghost"] == 0
        and values["debug_pre_post_missing"] == 0
        and values["debug_pre_post_ghost"] == 0
        and values["debug_duplicate_ids"] == 0
    )
    pass_case = bool(matches) and no_loss and counter_ok and uvm_error == 0 and uvm_fatal == 0 and test_passed

    row: dict[str, object] = {
        "case": case_name,
        "pass": int(pass_case),
        "test_passed": int(test_passed),
        "uvm_error": uvm_error,
        "uvm_fatal": uvm_fatal,
        "counter_stage_a_agree": counters.get("stage_a", (0, 0, 0, 0))[3],
        "counter_pre_rbcam_agree": counters.get("pre_rbcam", (0, 0, 0, 0))[3],
        "counter_post_rbcam_agree": counters.get("post_rbcam", (0, 0, 0, 0))[3],
        "counter_ok": int(counter_ok),
    }
    row.update(values)
    return row


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sim-root", type=Path, required=True)
    parser.add_argument("--log-root", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--case-set", choices=sorted(CASE_SETS), default="asic0_full32_emu")
    parser.add_argument("--cases", nargs="*")
    args = parser.parse_args()

    cases = args.cases if args.cases else CASE_SETS[args.case_set]
    rows = [validate_case(args.sim_root, args.log_root, case) for case in cases]
    args.summary.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = list(rows[0].keys()) if rows else ["case", "pass"]
    with args.summary.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)

    for row in rows:
        print(
            f"{row['case']}: pass={row['pass']} "
            f"A/PRE/POST={row['A']}/{row['PRE']}/{row['POST']} "
            f"fifo_missing={row['fifo_a_pre_missing']}/{row['fifo_pre_post_missing']} "
            f"debug_missing={row['debug_src_pre_missing']}/{row['debug_pre_post_missing']} "
            f"uvm={row['uvm_error']}/{row['uvm_fatal']}"
        )
    print(args.summary)
    return 0 if all(int(row["pass"]) for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
