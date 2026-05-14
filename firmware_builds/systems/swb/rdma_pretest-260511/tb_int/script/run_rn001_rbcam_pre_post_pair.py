#!/usr/bin/env python3
"""Run RN.BASIC.001 twice for each rbCAM histogram tap.

The child runner owns the SWB ring lock, DMA setup, run-control sequence, and
evidence directory creation.  This wrapper only serializes the requested
pre-rbCAM and post-rbCAM captures so the two-run comparison is repeatable.
"""
from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any


SCRIPT = Path(__file__).resolve()
RUNNER = SCRIPT.with_name("run_swb_dma_packer_rn001_board.py")


def run_one(args: argparse.Namespace, source: str, index: int) -> dict[str, Any]:
    cmd = [
        sys.executable,
        str(RUNNER),
        "--hist-ingress-source",
        source,
        "--hist-preset",
        args.hist_preset,
        "--interval-seconds",
        str(args.interval_seconds),
        "--hist-interval-clocks",
        str(args.hist_interval_clocks),
        "--max-decode-bytes",
        str(args.max_decode_bytes),
        "--staging-mb",
        str(args.staging_mb),
        "--af-pct",
        str(args.af_pct),
    ]
    if args.hist_running_probe_period_s > 0.0:
        cmd.extend([
            "--hist-running-probe-period-s",
            str(args.hist_running_probe_period_s),
        ])
    for sample_s in args.hist_running_bin_sample_s:
        cmd.extend(["--hist-running-bin-sample-s", str(sample_s)])
    if args.sc_tool is not None:
        cmd.extend(["--sc-tool", str(args.sc_tool)])
    if args.dma_tool is not None:
        cmd.extend(["--dma-tool", str(args.dma_tool)])
    if args.output_root is not None:
        cmd.extend(["--output-root", str(args.output_root)])
    if args.link is not None:
        cmd.extend(["--link", str(args.link)])
    if args.preenable_dma_before_capture:
        cmd.append("--preenable-dma-before-capture")

    proc = subprocess.run(cmd, text=True, capture_output=True)
    summary = {
        "source": source,
        "index": index,
        "returncode": proc.returncode,
        "cmd": cmd,
        "stdout": proc.stdout,
        "stderr": proc.stderr,
    }
    print(proc.stdout, end="")
    if proc.stderr:
        print(proc.stderr, end="", file=sys.stderr)
    return summary


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--runs-per-source", type=int, default=2)
    ap.add_argument("--sources", choices=["both", "pre", "post"],
                    default="both")
    ap.add_argument("--hist-preset", choices=["rate", "delay"], default="rate")
    ap.add_argument("--interval-seconds", type=float, default=1.0)
    ap.add_argument("--hist-interval-clocks", type=lambda s: int(s, 0),
                    default=125000)
    ap.add_argument("--max-decode-bytes", type=int, default=4 * 1024 * 1024)
    ap.add_argument("--staging-mb", type=int, default=64)
    ap.add_argument("--af-pct", type=int, default=80)
    ap.add_argument("--hist-running-probe-period-s", type=float, default=0.1,
                    help="sample histogram CSR words during RUNNING")
    ap.add_argument("--hist-running-bin-sample-s", type=float, action="append",
                    default=None,
                    help="sample all 256 histogram bins during RUNNING; may be repeated")
    ap.add_argument("--sc-tool", type=Path, default=None)
    ap.add_argument("--dma-tool", type=Path, default=None)
    ap.add_argument("--output-root", type=Path, default=None)
    ap.add_argument("--link", type=int, default=None)
    ap.add_argument("--preenable-dma-before-capture", action="store_true")
    ap.add_argument("--summary-json", type=Path, default=None)
    args = ap.parse_args(argv)

    if args.runs_per_source < 1:
        raise SystemExit("--runs-per-source must be >= 1")
    if args.hist_running_bin_sample_s is None:
        args.hist_running_bin_sample_s = [0.25]

    sources = ["pre", "post"] if args.sources == "both" else [args.sources]
    runs: list[dict[str, Any]] = []
    rc = 0
    for source in sources:
        for index in range(args.runs_per_source):
            item = run_one(args, source, index)
            runs.append(item)
            if item["returncode"] != 0 and rc == 0:
                rc = int(item["returncode"])

    if args.summary_json is not None:
        args.summary_json.parent.mkdir(parents=True, exist_ok=True)
        args.summary_json.write_text(
            json.dumps({"runs": runs}, indent=2) + "\n",
            encoding="ascii",
        )
    return rc


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
