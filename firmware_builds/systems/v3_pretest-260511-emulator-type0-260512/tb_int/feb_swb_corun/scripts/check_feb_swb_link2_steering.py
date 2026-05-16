#!/usr/bin/env python3
"""Check the FEB->SWB link-2 steering contract from a corun report."""

from __future__ import annotations

import argparse
import re
from pathlib import Path


LANE_SUMMARY_RE = re.compile(r"OPQ_NATIVE_LANE_SUMMARY\s+lane=(?P<lane>\d+)\s+(?P<body>.*)")
KV_RE = re.compile(r"(?P<key>[A-Za-z0-9_]+)=(?P<value>[^\s]+)")


def parse_kv_body(body: str) -> dict[str, int]:
    out: dict[str, int] = {}
    for match in KV_RE.finditer(body):
        value = match.group("value")
        try:
            out[match.group("key")] = int(value, 0)
        except ValueError:
            pass
    return out


def read_summary(path: Path) -> dict[str, int]:
    values: dict[str, int] = {}
    if not path.exists():
        return values
    for line in path.read_text().splitlines():
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key == "issue":
            continue
        try:
            values[key] = int(value, 0)
        except ValueError:
            pass
    return values


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-log", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--lane", type=int, default=2)
    args = parser.parse_args()

    run_log = args.run_log.read_text(errors="replace")
    lane_metrics: dict[str, int] | None = None
    for line in run_log.splitlines():
        match = LANE_SUMMARY_RE.search(line)
        if not match or int(match.group("lane")) != args.lane:
            continue
        lane_metrics = parse_kv_body(match.group("body"))

    if lane_metrics is None:
        raise SystemExit(f"missing OPQ_NATIVE_LANE_SUMMARY for lane {args.lane}")

    summary = read_summary(args.summary)
    expected_hits = summary.get("expected_feb_hits", summary.get("expected_hits", 0))
    opq_ingress_hits = summary.get("opq_ingress_hits", 0)
    ingress_tunnel_pass = summary.get("tunnel_feb_egress_to_opq_ingress_pass", 0)

    required_lane_keys = ("wr_hdr", "wr_shd", "wr_hit", "rd_hdr", "rd_shd", "rd_hit")
    missing = [key for key in required_lane_keys if lane_metrics.get(key, 0) <= 0]
    drops = sum(lane_metrics.get(key, 0) for key in ("drop_hdr", "drop_shd", "drop_hit"))
    drops += sum(
        lane_metrics.get(key, 0)
        for key in (
            "mask_drop_shd",
            "mask_drop_hit",
            "credit_lane_drop_shd",
            "credit_lane_drop_hit",
            "credit_ticket_drop_shd",
            "credit_ticket_drop_hit",
            "credit_other_drop_shd",
            "credit_other_drop_hit",
            "handle_drop_shd",
            "handle_drop_hit",
        )
    )

    failures: list[str] = []
    if missing:
        failures.append(f"lane{args.lane}_missing_metrics={','.join(missing)}")
    if drops != 0:
        failures.append(f"lane{args.lane}_opq_drops={drops}")
    if expected_hits <= 0:
        failures.append("expected_hits_zero")
    if opq_ingress_hits < expected_hits:
        failures.append(f"opq_ingress_hits={opq_ingress_hits} expected={expected_hits}")
    if ingress_tunnel_pass < expected_hits:
        failures.append(
            f"feb_egress_to_opq_ingress_pass={ingress_tunnel_pass} expected={expected_hits}"
        )

    if failures:
        raise SystemExit("FEB_SWB_LINK2_STEERING_FAIL " + " ".join(failures))

    print(
        "FEB_SWB_LINK2_STEERING_PASS "
        f"lane={args.lane} expected_hits={expected_hits} "
        f"opq_ingress_hits={opq_ingress_hits} "
        f"wr_hit={lane_metrics.get('wr_hit', 0)} rd_hit={lane_metrics.get('rd_hit', 0)}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
