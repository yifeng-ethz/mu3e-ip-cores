#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
from pathlib import Path


DEFAULT_RTL_LATENCY = Path(
    "quartus_system/board_test/phase4/inputs/"
    "rtl_ts_soak_exact5k_stable/emulator_dispatch_latency_hist.csv"
)
DEFAULT_RTL_LOG = Path(
    "quartus_system/board_test/phase4/inputs/"
    "rtl_ts_soak_exact5k_stable/run.log"
)
DEFAULT_BOARD_REPORT = Path(
    "quartus_system/board_test/phase4/inputs/board/"
    "phase4_emulator_20260425_hist_fifo_depth_full_sweep_flushaware.md"
)
DEFAULT_STAGE_REPORT = Path(
    "quartus_system/board_test/phase4/inputs/board/"
    "phase4_stage_probe_20260425_hist_fifo_depth_rate0800_flushaware.md"
)


RATE_ROW_RE = re.compile(
    r"^\| `(?P<label>[^`]+)` \| `0x(?P<rate>[0-9a-fA-F]+)` \| "
    r"(?P<total>[0-9]+) \| (?P<per_s>[0-9]+) \| (?P<drop>[0-9]+) \| "
    r"(?P<ratio>[^|]+) \| (?P<result>[^|]+) \|$"
)
PRIMARY_RE = {
    "total_delta": re.compile(r"Histogram TOTAL_HITS delta: `(?P<v>[0-9]+)`"),
    "dropped_delta": re.compile(r"Histogram DROPPED_HITS delta: `(?P<v>[0-9]+)`"),
    "duration_s": re.compile(r"Sample spacing: `(?P<v>[0-9.]+) s`"),
    "result": re.compile(r"Result: `(?P<v>PASS|FAIL)`"),
}


def parse_hist(path: Path) -> dict[str, int | None]:
    hist: dict[int, int] = {}
    with path.open() as f:
      reader = csv.DictReader(f)
      for row in reader:
          key = int(row["latency_cycles"])
          count = int(row["count"])
          if count:
              hist[key] = count
    total = sum(hist.values())
    if total == 0:
        return {"total": 0, "min": None, "p50": None, "p90": None, "p99": None, "max": None}

    def pct(p: float) -> int:
        target = total * p / 100.0
        acc = 0
        for key in sorted(hist):
            acc += hist[key]
            if acc >= target:
                return key
        return max(hist)

    return {
        "total": total,
        "min": min(hist),
        "p50": pct(50),
        "p90": pct(90),
        "p99": pct(99),
        "max": max(hist),
    }


def parse_board_report(path: Path) -> tuple[dict[str, object], list[dict[str, object]]]:
    text = path.read_text(encoding="utf-8")
    primary: dict[str, object] = {}
    for key, rx in PRIMARY_RE.items():
        match = rx.search(text)
        if match:
            value = match.group("v")
            primary[key] = float(value) if "." in value else value
    rows: list[dict[str, object]] = []
    for line in text.splitlines():
        match = RATE_ROW_RE.match(line.strip())
        if not match:
            continue
        duration_s = 0.1
        rows.append(
            {
                "source": "board",
                "label": match.group("label"),
                "rate_word": int(match.group("rate"), 16),
                "total_delta": int(match.group("total")),
                "dropped_delta": int(match.group("drop")),
                "duration_s": duration_s,
                "hits_per_s": float(match.group("per_s")),
                "result": match.group("result").strip(),
            }
        )
    return primary, rows


def read_tlm_rate(path: Path) -> list[dict[str, object]]:
    if not path.exists():
        return []
    rows: list[dict[str, object]] = []
    with path.open() as f:
        reader = csv.DictReader(f)
        for row in reader:
            rate_word = int(row["rate_word"], 16)
            rows.append(
                {
                    "source": "tlm_hdl",
                    "label": f"r{rate_word:04x}",
                    "rate_word": rate_word,
                    "total_delta": int(row["accepted"]),
                    "dropped_delta": int(row["dropped"]),
                    "duration_s": float(row["duration_s"]),
                    "hits_per_s": float(row["accepted_per_s"]),
                    "result": "SIM",
                    "generated": int(row["generated"]),
                    "backlog_end": int(row["backlog_end"]),
                }
            )
    return rows


def write_rate_csv(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = [
        "source",
        "label",
        "rate_word",
        "total_delta",
        "dropped_delta",
        "duration_s",
        "hits_per_s",
        "result",
        "generated",
        "backlog_end",
    ]
    with path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        for row in rows:
            out = {field: row.get(field, "") for field in fields}
            writer.writerow(out)


def parse_stage_summary(path: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    if not path.exists():
        return rows
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.startswith("| ") or "`PASS`" not in line:
            continue
        cells = [cell.strip().strip("`") for cell in line.strip("|").split("|")]
        if len(cells) < 16 or not cells[0].isdigit():
            continue
        rows.append(
            {
                "iteration": int(cells[0]),
                "classification": cells[1],
                "emu_frames": int(cells[2]),
                "mts_hits": int(cells[3]),
                "ring_push": int(cells[6]),
                "ring_pop": int(cells[7]),
                "frame_actual": int(cells[8]),
                "hist_total": int(cells[9]),
                "hist_drop": int(cells[10]),
                "flush": cells[12],
            }
        )
    return rows


def read_csv_rows(path: Path) -> list[dict[str, object]]:
    if not path.exists():
        return []
    with path.open(newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--repo-root", type=Path, default=Path.cwd())
    ap.add_argument("--artifact-dir", type=Path, default=Path("quartus_system/board_test/phase4/artifacts"))
    ap.add_argument("--rtl-latency", type=Path, default=DEFAULT_RTL_LATENCY)
    ap.add_argument("--rtl-log", type=Path, default=DEFAULT_RTL_LOG)
    ap.add_argument("--board-report", type=Path, default=DEFAULT_BOARD_REPORT)
    ap.add_argument("--stage-report", type=Path, default=DEFAULT_STAGE_REPORT)
    args = ap.parse_args()

    root = args.repo_root.resolve()
    out_dir = (root / args.artifact_dir).resolve() if not args.artifact_dir.is_absolute() else args.artifact_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    rtl_latency = root / args.rtl_latency if not args.rtl_latency.is_absolute() else args.rtl_latency
    board_report = root / args.board_report if not args.board_report.is_absolute() else args.board_report
    stage_report = root / args.stage_report if not args.stage_report.is_absolute() else args.stage_report
    rtl_log = root / args.rtl_log if not args.rtl_log.is_absolute() else args.rtl_log

    rtl_latency_out = out_dir / "phase4_rtl_latency_hist.csv"
    shutil.copyfile(rtl_latency, rtl_latency_out)

    primary, board_rows = parse_board_report(board_report)
    tlm_rows = read_tlm_rate(out_dir / "phase4_tlm_rate_sweep.csv")
    write_rate_csv(out_dir / "phase4_rate_sweep.csv", [*board_rows, *tlm_rows])
    write_rate_csv(out_dir / "phase4_board_rate_sweep.csv", board_rows)

    summary = {
        "inputs": {
            "rtl_latency_csv": str(rtl_latency),
            "rtl_log": str(rtl_log),
            "board_report": str(board_report),
            "stage_report": str(stage_report),
        },
        "rtl_latency": parse_hist(rtl_latency_out),
        "tlm_latency": parse_hist(out_dir / "phase4_tlm_latency_hist.csv")
        if (out_dir / "phase4_tlm_latency_hist.csv").exists()
        else None,
        "board_primary": primary,
        "board_rate_rows": board_rows,
        "stage_rows": parse_stage_summary(stage_report),
        "physical_rate_limits": read_csv_rows(out_dir / "phase4_physical_rate_limits.csv"),
        "queue_depth_1ppm_at_200mhit": [
            row
            for row in read_csv_rows(out_dir / "phase4_queue_depth_regions.csv")
            if row.get("rate_mhit") == "200.000" and row.get("threshold") == "1e-06"
        ],
    }
    (out_dir / "phase4_summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {out_dir / 'phase4_summary.json'}")
    print(f"Wrote {out_dir / 'phase4_rate_sweep.csv'}")
    print(f"Wrote {rtl_latency_out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
