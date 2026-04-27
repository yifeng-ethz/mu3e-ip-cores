#!/usr/bin/env python3
import argparse
import csv
import json
import math
import pathlib
import re
from collections import defaultdict


TS_SUMMARY_RE = re.compile(
    r"TB_TS_TRACE_SUMMARY enabled=(?P<enabled>\d+) "
    r"gen_mod=(?P<gen_mod>\d+) "
    r"type0_under=(?P<type0_under>\d+) "
    r"type0_mismatch=(?P<type0_mismatch>\d+) "
    r"mts_in_under=(?P<mts_in_under>\d+) "
    r"mts_in_mismatch=(?P<mts_in_mismatch>\d+) "
    r"mts_out_under=(?P<mts_out_under>\d+) "
    r"mts_out_channel=(?P<mts_out_channel>\d+) "
    r"mts_out_tcc=(?P<mts_out_tcc>\d+) "
    r"mts_out_delta=(?P<mts_out_delta>\d+) "
    r"mts_out_error=(?P<mts_out_error>\d+)"
)

DROP_RE = re.compile(r"TB_MEAS_DROP payload_clean=(?P<clean>\d+) payload_error=(?P<error>\d+)")
CFG_RE = re.compile(
    r"TB_MEAS_CFG lane=(?P<lane>\d+) hit_rate=0x(?P<hit_rate>[0-9a-fA-F]+) "
    r"noise_rate=0x(?P<noise_rate>[0-9a-fA-F]+) hit_mode=(?P<hit_mode>\d+) "
    r"burst_size=(?P<burst_size>\d+) burst_center=(?P<burst_center>\d+)"
)


def percentile_from_hist(hist, pct):
    total = sum(hist.values())
    if total == 0:
        return None
    target = total * pct / 100.0
    accum = 0
    for key in sorted(hist):
        accum += hist[key]
        if accum >= target:
            return key
    return max(hist)


def parse_latency_csv(path):
    hist = {}
    with path.open() as f:
        reader = csv.DictReader(f)
        for row in reader:
            key = int(row["latency_cycles"])
            count = int(row["count"])
            if count:
                hist[key] = count
    total = sum(hist.values())
    if not hist:
        return {
            "total": 0,
            "min": None,
            "max": None,
            "p50": None,
            "p90": None,
            "p99": None,
        }
    return {
        "total": total,
        "min": min(hist),
        "max": max(hist),
        "p50": percentile_from_hist(hist, 50),
        "p90": percentile_from_hist(hist, 90),
        "p99": percentile_from_hist(hist, 99),
    }


def parse_rate_csv(path):
    total = 0
    asic_totals = defaultdict(int)
    chan_totals = defaultdict(int)
    nonzero_bins = 0
    with path.open() as f:
        reader = csv.DictReader(f)
        for row in reader:
            count = int(row["count"])
            if count:
                nonzero_bins += 1
            total += count
            asic_totals[int(row["asic"])] += count
            chan_totals[int(row["channel"])] += count

    return {
        "total": total,
        "nonzero_bins": nonzero_bins,
        "asic_totals": dict(sorted(asic_totals.items())),
        "channel_totals": dict(sorted(chan_totals.items())),
    }


def parse_log(path):
    result = {
        "ts_summary": None,
        "drop_summary": None,
        "lane_cfg": {},
    }
    for line in path.read_text().splitlines():
        if "TB_TS_TRACE_SUMMARY" in line:
            m = TS_SUMMARY_RE.search(line)
            if m:
                result["ts_summary"] = {k: int(v) for k, v in m.groupdict().items()}
        elif "TB_MEAS_DROP" in line:
            m = DROP_RE.search(line)
            if m:
                result["drop_summary"] = {k: int(v) for k, v in m.groupdict().items()}
        elif "TB_MEAS_CFG" in line:
            m = CFG_RE.search(line)
            if m:
                gd = m.groupdict()
                lane = int(gd.pop("lane"))
                result["lane_cfg"][lane] = {
                    "hit_rate": int(gd["hit_rate"], 16),
                    "noise_rate": int(gd["noise_rate"], 16),
                    "hit_mode": int(gd["hit_mode"]),
                    "burst_size": int(gd["burst_size"]),
                    "burst_center": int(gd["burst_center"]),
                }
    return result


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report-dir", required=True)
    ap.add_argument("--json-out")
    args = ap.parse_args()

    report_dir = pathlib.Path(args.report_dir)
    log_path = report_dir / "run.log"
    if not log_path.exists():
        candidates = list(report_dir.glob("*.log"))
        if candidates:
            log_path = candidates[0]

    summary = {
        "report_dir": str(report_dir),
        "log": parse_log(log_path) if log_path.exists() else None,
        "rate_hist": parse_rate_csv(report_dir / "pre_rbcam_rate_hist.csv"),
        "latency_hist": parse_latency_csv(report_dir / "emulator_dispatch_latency_hist.csv"),
    }

    if args.json_out:
        pathlib.Path(args.json_out).write_text(json.dumps(summary, indent=2, sort_keys=True))
    else:
        print(json.dumps(summary, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
