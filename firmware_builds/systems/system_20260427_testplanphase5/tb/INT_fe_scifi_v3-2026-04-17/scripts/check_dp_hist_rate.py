#!/usr/bin/env python3
import argparse
import csv
import math
import pathlib
import re
import sys


DROP_RE = re.compile(r"TB_MEAS_DROP payload_clean=(?P<clean>\d+) payload_error=(?P<error>\d+)")
RATE_STATUS_RE = re.compile(
    r"TB_MEAS_RATE_STATUS ctrl=0x(?P<ctrl>[0-9a-fA-F]+) "
    r"total=0x(?P<total>[0-9a-fA-F]+) "
    r"dropped=0x(?P<dropped>[0-9a-fA-F]+) "
    r"under=0x(?P<under>[0-9a-fA-F]+) "
    r"over=0x(?P<over>[0-9a-fA-F]+)"
)


def parse_log(path: pathlib.Path):
    result = {
        "drop_clean": None,
        "drop_error": None,
        "hist_total": None,
        "hist_dropped": None,
        "hist_under": None,
        "hist_over": None,
    }
    for line in path.read_text().splitlines():
        m = DROP_RE.search(line)
        if m:
            result["drop_clean"] = int(m.group("clean"))
            result["drop_error"] = int(m.group("error"))
        m = RATE_STATUS_RE.search(line)
        if m:
            result["hist_total"] = int(m.group("total"), 16)
            result["hist_dropped"] = int(m.group("dropped"), 16)
            result["hist_under"] = int(m.group("under"), 16)
            result["hist_over"] = int(m.group("over"), 16)
    return result


def parse_rate_csv(path: pathlib.Path):
    counts = {}
    with path.open() as f:
        reader = csv.DictReader(f)
        for row in reader:
            asic = int(row["asic"])
            channel = int(row["channel"])
            counts[(asic, channel)] = int(row["count"])
    return counts


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report-dir", required=True)
    ap.add_argument("--expected-rate-hz", type=float, required=True)
    ap.add_argument("--duration-s", type=float, required=True)
    ap.add_argument("--expected-channel", type=int, default=16)
    ap.add_argument("--expected-asics", type=int, default=8)
    ap.add_argument("--rtol", type=float, default=0.05)
    ap.add_argument("--atol", type=int, default=8)
    args = ap.parse_args()

    report_dir = pathlib.Path(args.report_dir)
    csv_path = report_dir / "pre_rbcam_rate_hist.csv"
    log_path = report_dir / "run.log"

    counts = parse_rate_csv(csv_path)
    log = parse_log(log_path)

    expected_count = args.expected_rate_hz * args.duration_s
    tol = max(args.atol, math.ceil(expected_count * args.rtol))
    expected_bins = {(asic, args.expected_channel) for asic in range(args.expected_asics)}

    nonzero_bins = {key: value for key, value in counts.items() if value != 0}
    unexpected_bins = {key: value for key, value in nonzero_bins.items() if key not in expected_bins}
    failures = []

    if log["drop_error"] not in (None, 0):
        failures.append(f"payload_error={log['drop_error']}")
    if log["hist_dropped"] not in (None, 0):
        failures.append(f"hist_dropped={log['hist_dropped']}")
    if log["hist_under"] not in (None, 0):
        failures.append(f"hist_under={log['hist_under']}")
    if log["hist_over"] not in (None, 0):
        failures.append(f"hist_over={log['hist_over']}")
    if unexpected_bins:
        failures.append(f"unexpected_nonzero_bins={unexpected_bins}")

    actual_total = 0
    for asic in range(args.expected_asics):
        key = (asic, args.expected_channel)
        actual = counts.get(key, 0)
        actual_total += actual
        if abs(actual - expected_count) > tol:
            failures.append(
                f"asic{asic}_ch{args.expected_channel}={actual} outside expected {expected_count:.1f} +/- {tol}"
            )

    expected_total = expected_count * args.expected_asics
    if log["hist_total"] is not None and abs(log["hist_total"] - expected_total) > tol * args.expected_asics:
        failures.append(
            f"hist_total={log['hist_total']} outside expected {expected_total:.1f} +/- {tol * args.expected_asics}"
        )
    if abs(actual_total - expected_total) > tol * args.expected_asics:
        failures.append(
            f"csv_total={actual_total} outside expected {expected_total:.1f} +/- {tol * args.expected_asics}"
        )

    print(
        f"RATE_CHECK rate={args.expected_rate_hz:.0f}Hz duration={args.duration_s:.6f}s "
        f"expected_per_channel={expected_count:.1f} tol={tol} actual_total={actual_total}"
    )
    for asic in range(args.expected_asics):
        print(f"  asic={asic} channel={args.expected_channel} count={counts.get((asic, args.expected_channel), 0)}")

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1

    print("PASS: histogram counts match expected periodic injector rate")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
