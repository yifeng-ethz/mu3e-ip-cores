#!/usr/bin/env python3
"""Pre-rbCAM latency analyzer for tb_int CSV records.

Inputs:
- closed_records.csv produced by tb_int_latency_pkg::latency_reporter (default)
- pre_rbcam_records.csv (preferred when present)

Latencies are computed as:
  (abs_ts_pre_rbcam - abs_ts_a) / 8000.0
assuming 125 MHz timestamps in ps.

Outputs:
- prints count/min/p05/p50/p95/max per case
- optional per-case histogram CSV and/or PNG under --hist-dir
"""

from __future__ import annotations

import argparse
import csv
import fnmatch
import math
import sys
import warnings
from dataclasses import dataclass
from pathlib import Path

CLOCK_PERIOD_PS = 8000.0
REQUIRED_FIELDS = {"abs_ts_a", "abs_ts_pre_rbcam"}
RUN_ORIGIN_FIELD = "run_origin"


@dataclass(frozen=True)
class CaseSummary:
    name: str
    source_csv: str
    count: int
    min_latency: float
    p05_latency: float
    p50_latency: float
    p95_latency: float
    max_latency: float
    latencies: list[float]


def discover_cases(sim_root: Path, cases_spec: str) -> list[Path]:
    sim_root = sim_root.resolve()
    if not sim_root.is_dir():
        raise FileNotFoundError(f"--sim-root not found: {sim_root}")

    all_dirs = sorted(d for d in sim_root.iterdir() if d.is_dir())
    if cases_spec.lower() == "all":
        return all_dirs

    patterns = [spec.strip() for spec in cases_spec.split(",") if spec.strip()]
    matched: list[Path] = []
    seen: set[str] = set()
    for pattern in patterns:
        for d in all_dirs:
            if d.name not in seen and fnmatch.fnmatch(d.name, pattern):
                matched.append(d)
                seen.add(d.name)
    return matched


def pick_record_csv(case_dir: Path) -> Path | None:
    for name in ("pre_rbcam_records.csv", "closed_records.csv"):
        p = case_dir / name
        if p.is_file():
            return p
    return None


def load_latencies(path: Path, stable_only: bool) -> list[float]:
    with path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames is None:
            raise ValueError(f"{path}: missing header")
        fields = set(reader.fieldnames)
        if not REQUIRED_FIELDS.issubset(fields):
            raise ValueError(
                f"{path}: missing required columns {sorted(REQUIRED_FIELDS - fields)}"
            )
        rows: list[float] = []
        for row in reader:
            if stable_only:
                if RUN_ORIGIN_FIELD not in row or not row[RUN_ORIGIN_FIELD].strip():
                    continue
                try:
                    if int(row[RUN_ORIGIN_FIELD]) != 1:
                        continue
                except ValueError:
                    continue

            try:
                a = float(int(row["abs_ts_pre_rbcam"]) - int(row["abs_ts_a"])) / CLOCK_PERIOD_PS
            except (KeyError, ValueError):
                # Keep parsing resilient; malformed rows are skipped.
                continue
            rows.append(a)
    return rows


def percentile(values: list[float], percent: float) -> float:
    """Return percentile using linear interpolation between sorted points."""
    if not values:
        return float("nan")
    if percent <= 0:
        return values[0]
    if percent >= 100:
        return values[-1]
    index = (len(values) - 1) * (percent / 100.0)
    left_idx = int(math.floor(index))
    right_idx = int(math.ceil(index))
    if left_idx == right_idx:
        return values[left_idx]
    left_v = values[left_idx]
    right_v = values[right_idx]
    frac = index - left_idx
    return left_v + (right_v - left_v) * frac


def summarize_case(case_name: str, source_csv: Path, latencies: list[float]) -> CaseSummary | None:
    if not latencies:
        return None
    sorted_lat = sorted(latencies)
    return CaseSummary(
        name=case_name,
        source_csv=str(source_csv),
        count=len(sorted_lat),
        min_latency=sorted_lat[0],
        p05_latency=percentile(sorted_lat, 5.0),
        p50_latency=percentile(sorted_lat, 50.0),
        p95_latency=percentile(sorted_lat, 95.0),
        max_latency=sorted_lat[-1],
        latencies=sorted_lat,
    )


def _build_histogram(values: list[float], bin_width: float) -> tuple[list[float], list[float], list[float], list[int]]:
    min_v = min(values)
    max_v = max(values)
    if not values:
        return [], [], [], []

    if bin_width <= 0:
        raise ValueError("--hist-bin-width must be > 0")

    left = math.floor(min_v / bin_width) * bin_width
    right = math.floor(max_v / bin_width) * bin_width + bin_width
    if right <= left:
        right = left + bin_width

    n_bins = max(1, int(round((right - left) / bin_width)))
    counts = [0] * n_bins
    left_edges = [left + i * bin_width for i in range(n_bins)]
    right_edges = [left + (i + 1) * bin_width for i in range(n_bins)]
    centers = [l + 0.5 * bin_width for l in left_edges]

    for v in values:
        idx = int(math.floor((v - left) / bin_width))
        if idx < 0:
            idx = 0
        elif idx >= n_bins:
            idx = n_bins - 1
        counts[idx] += 1
    return left_edges, centers, right_edges, counts


def write_histogram_csv(path: Path, left_edges: list[float], centers: list[float], right_edges: list[float], counts: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh)
        writer.writerow(["bin_left_cycles", "bin_center_cycles", "bin_right_cycles", "count"])
        for l, c, r, cnt in zip(left_edges, centers, right_edges, counts):
            writer.writerow([f"{l:.6f}", f"{c:.6f}", f"{r:.6f}", str(cnt)])


def write_histogram_png(path: Path, left_edges: list[float], counts: list[int], title: str) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt  # noqa: E402

    if not counts:
        return

    width = left_edges[1] - left_edges[0] if len(left_edges) > 1 else 1.0
    centers = [l + 0.5 * width for l in left_edges]

    fig, ax = plt.subplots(figsize=(7.5, 2.8), dpi=140)
    ax.bar(centers, counts, width=width * 0.95, align="center", color="#1f77b4", edgecolor="#1f77b4", linewidth=0.3)
    ax.set_title(title, fontsize=10)
    ax.set_xlabel("pre-rbCAM latency [cycles]", fontsize=9)
    ax.set_ylabel("count", fontsize=9)
    ax.tick_params(labelsize=8)
    ax.grid(True, alpha=0.3)
    fig.tight_layout()
    path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(path, bbox_inches="tight")
    plt.close(fig)


def print_summary(summaries: list[CaseSummary], output_aggregate: bool) -> None:
    print("case,source_csv,count,min,p05,p50,p95,max")
    for s in summaries:
        print(
            f"{s.name},{s.source_csv},{s.count},"
            f"{s.min_latency:.6f},{s.p05_latency:.6f},{s.p50_latency:.6f},"
            f"{s.p95_latency:.6f},{s.max_latency:.6f}"
        )

    if output_aggregate and len(summaries) > 1:
        all_lat = sorted(v for s in summaries for v in s.latencies)
        if all_lat:
            agg = CaseSummary(
                name="all",
                source_csv="aggregate",
                count=len(all_lat),
                min_latency=all_lat[0],
                p05_latency=percentile(all_lat, 5.0),
                p50_latency=percentile(all_lat, 50.0),
                p95_latency=percentile(all_lat, 95.0),
                max_latency=all_lat[-1],
                latencies=all_lat,
            )
            print(
                f"aggregate,aggregate,{agg.count},"
                f"{agg.min_latency:.6f},{agg.p05_latency:.6f},{agg.p50_latency:.6f},"
                f"{agg.p95_latency:.6f},{agg.max_latency:.6f}"
            )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sim-root", type=Path, required=True, metavar="DIR",
                        help="Directory with per-case simulation outputs.")
    parser.add_argument("--cases", default="all", metavar="SPEC",
                        help="Comma-separated glob patterns, or 'all'.")
    parser.add_argument("--stable-only", action="store_true", default=False,
                        help="Keep only rows with run_origin == 1.")
    parser.add_argument("--hist-dir", type=Path, default=None, metavar="DIR",
                        help="Directory to write per-case histograms.")
    parser.add_argument("--hist-bin-width", type=float, default=1.0, metavar="W",
                        help="Histogram bin width in cycles (default: 1.0).")
    parser.add_argument("--hist-formats", default="csv,png", metavar="LIST",
                        help="Comma-separated list among: csv,png. Ignored unless --hist-dir set.")
    parser.add_argument("--aggregate", action="store_true", default=False,
                        help="Print an additional aggregate (all-case) summary row.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.hist_formats:
        requested_formats = {token.strip().lower() for token in args.hist_formats.split(",") if token.strip()}
    else:
        requested_formats = set()

    if args.hist_dir is not None and not requested_formats:
        requested_formats = {"csv", "png"}

    for token in requested_formats:
        if token not in {"csv", "png"}:
            print(f"ERROR: unsupported --hist-formats entry '{token}', expected csv and/or png.", file=sys.stderr)
            return 2

    try:
        case_dirs = discover_cases(args.sim_root, args.cases)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    if not case_dirs:
        print(f"ERROR: no case directories matching '{args.cases}' under {args.sim_root}", file=sys.stderr)
        return 2

    summaries: list[CaseSummary] = []
    skipped = 0

    for case_dir in case_dirs:
        src = pick_record_csv(case_dir)
        if src is None:
            warnings.warn(f"[skip] {case_dir.name}: no pre_rbcam_records.csv/closed_records.csv")
            skipped += 1
            continue

        try:
            latencies = load_latencies(src, stable_only=args.stable_only)
        except ValueError as exc:
            warnings.warn(f"[skip] {case_dir.name}: {exc}")
            skipped += 1
            continue

        summary = summarize_case(case_dir.name, src, latencies)
        if summary is None:
            warnings.warn(f"[skip] {case_dir.name}: no valid latency rows in {src}")
            skipped += 1
            continue

        summaries.append(summary)

        if args.hist_dir is not None:
            left_edges, centers, right_edges, counts = _build_histogram(summary.latencies, args.hist_bin_width)
            if "csv" in requested_formats:
                write_histogram_csv(
                    args.hist_dir / f"{case_dir.name}_pre_rbcam_hist.csv",
                    left_edges,
                    centers,
                    right_edges,
                    counts,
                )
            if "png" in requested_formats:
                write_histogram_png(
                    args.hist_dir / f"{case_dir.name}_pre_rbcam_hist.png",
                    left_edges,
                    counts,
                    f"pre-rbCAM latency histogram: {case_dir.name}",
                )

    if not summaries:
        print("ERROR: no loadable case data found.", file=sys.stderr)
        return 3

    print_summary(summaries, args.aggregate)
    if skipped:
        print(f"Skipped {skipped} case(s)", file=sys.stderr)
    print(f"Analyzed {len(summaries)} case(s).", file=sys.stderr)
    if args.hist_dir is not None:
        print(f"Wrote histogram files to {args.hist_dir.resolve()}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
