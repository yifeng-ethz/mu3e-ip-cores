#!/usr/bin/env python3
"""Render board on-chip histogram latency captures in the tb_int plot style."""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402


STAGE_META = {
    "pre_rbcam": {
        "title": "Board pre-rbCAM DEBUG timestamp age: ASIC0 ch0..31 periodic",
        "subtitle": "blue = histogram debug_1 mts_preprocessor_0.debug_ts; green = [-1000,3096) cycles; black = peak bin",
        "xlabel": "pre-rbCAM debug age bin center [cycles]",
        "ylabel": "hits / bin [%]",
        "expected": (-1000.0, 3096.0),
        "xlim": (-1000, 3400),
        "bar_label": "pre-rbCAM debug_1",
        "delay_label": "delay = mts_preprocessor_0.debug_ts histogram sample",
    },
    "feb_egress": {
        "title": "Board FEB-egress DEBUG timestamp age: ASIC0 ch0..31 periodic",
        "subtitle": "blue = on-chip post histogram delay-hit-t profile; green = [2000,7096) cycles; black = peak bin",
        "xlabel": "FEB egress age bin center [cycles]",
        "ylabel": "hits / bin [%]",
        "expected": (2000.0, 7096.0),
        "xlim": (2000, 7600),
        "bar_label": "FEB histogram delay-hit-t",
        "delay_label": "delay = (FEB/post monitor GTS - hit DEBUG timestamp) mod 8192 proxy",
    },
}


@dataclass(frozen=True)
class Capture:
    rate: str
    q16_rate: int
    csv_path: Path
    log_path: Path | None
    source_status: str
    bin_width: float
    centers: list[float]
    counts: list[int]

    @property
    def total(self) -> int:
        return sum(self.counts)


def read_bins(path: Path) -> tuple[list[float], list[int]]:
    centers: list[float] = []
    counts: list[int] = []
    with path.open(newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            centers.append(float(row["bin_center"]))
            counts.append(int(row["count"]))
    return centers, counts


def weighted_values(capture: Capture) -> list[tuple[float, int]]:
    return [(center, count) for center, count in zip(capture.centers, capture.counts) if count > 0]


def stat_min(capture: Capture) -> float:
    values = weighted_values(capture)
    return values[0][0] if values else math.nan


def stat_max(capture: Capture) -> float:
    values = weighted_values(capture)
    return values[-1][0] if values else math.nan


def percentile(capture: Capture, pct: float) -> float:
    total = capture.total
    if total <= 0:
        return math.nan
    target = max(1, math.ceil(total * pct / 100.0))
    acc = 0
    for center, count in zip(capture.centers, capture.counts):
        acc += count
        if acc >= target:
            return center
    return capture.centers[-1]


def peak(capture: Capture) -> tuple[float | None, float, int]:
    if capture.total <= 0:
        return None, 0.0, 0
    best_center = None
    best_count = -1
    for center, count in zip(capture.centers, capture.counts):
        if count > best_count:
            best_center = center
            best_count = count
    return best_center, 100.0 * best_count / capture.total, best_count


def expected_count(capture: Capture, window: tuple[float, float]) -> int:
    lo, hi = window
    return sum(count for center, count in zip(capture.centers, capture.counts) if lo <= center < hi)


def load_captures(manifest_path: Path, stage: str) -> list[Capture]:
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    captures: list[Capture] = []
    for rate_row in manifest.get("rates", []):
        for item in rate_row.get("captures", []):
            if item.get("stage") != stage:
                continue
            csv_path = Path(item["csv"])
            centers, counts = read_bins(csv_path)
            if len(centers) >= 2:
                bin_width = centers[1] - centers[0]
            else:
                bin_width = float(item.get("bin_width", 1))
            captures.append(
                Capture(
                    rate=rate_row["label"],
                    q16_rate=int(rate_row["q16_rate"]),
                    csv_path=csv_path,
                    log_path=Path(item["log"]) if item.get("log") else None,
                    source_status=json.dumps(item.get("source_select", {}), sort_keys=True),
                    bin_width=bin_width,
                    centers=centers,
                    counts=counts,
                )
            )
    return captures


def make_xticks(xlim: tuple[int, int], expected: tuple[float, float]) -> list[int]:
    lo, hi = xlim
    ticks = [lo, int(expected[0]), int(expected[1]), hi]
    step = 200 if hi - lo <= 5000 else 1000
    start = int(math.ceil(lo / step) * step)
    for tick in range(start, hi + 1, step):
        ticks.append(tick)
    return sorted(set(tick for tick in ticks if lo <= tick <= hi))


def render_case(ax: plt.Axes, capture: Capture, meta: dict[str, object], xlim: tuple[int, int]) -> None:
    total = capture.total
    ys = [100.0 * count / total if total else 0.0 for count in capture.counts]
    expected = meta["expected"]  # type: ignore[assignment]
    peak_bin, peak_pct, peak_count = peak(capture)
    ax.bar(
        capture.centers,
        ys,
        width=max(0.8, capture.bin_width * 0.9),
        color="#1e78ff",
        alpha=0.30,
        edgecolor="#1e78ff",
        linewidth=0.35,
        label=str(meta["bar_label"]),
    )
    ax.axvline(expected[0], color="#00d94a", linewidth=1.0)  # type: ignore[index]
    ax.axvline(expected[1], color="#00d94a", linewidth=1.0)  # type: ignore[index]
    if peak_bin is not None:
        ax.axvline(peak_bin, color="#111111", linewidth=0.9)
    ymax = max(ys + [0.0])
    ytop = max(12.0, math.ceil((ymax * 1.18) / 2.0) * 2.0)
    ax.set_xlim(*xlim)
    ax.set_ylim(0.0, ytop)
    ax.set_xticks(make_xticks(xlim, expected))  # type: ignore[arg-type]
    ax.set_yticks([0, 2, 4, 6, 8, 10, 12] if ytop <= 12 else list(range(0, int(ytop) + 1, 5)))
    ax.grid(True, color="#000000", alpha=0.22, linewidth=0.55)
    for spine in ax.spines.values():
        spine.set_color("#777777")
        spine.set_linewidth(0.55)
    ax.tick_params(axis="both", top=True, right=True, labelsize=6.5, width=0.45, color="#666666", labelcolor="#555555")
    ax.set_title(f"Emulator ASIC0 ch0..31 {capture.rate}", fontsize=9.0, fontfamily="monospace", pad=20.0)
    ax.text(0.5, 1.035, str(meta["delay_label"]), transform=ax.transAxes, ha="center", va="bottom", fontsize=5.8, fontfamily="monospace")
    win_count = expected_count(capture, expected)  # type: ignore[arg-type]
    footer = (
        f"records={total}; q16_rate={capture.q16_rate}; nonzero_bins={sum(1 for c in capture.counts if c)}\n"
        f"age={stat_min(capture):.0f}..{stat_max(capture):.0f} cy "
        f"(p50 {percentile(capture, 50):.1f}; peak {peak_bin}, {peak_pct:.3f}%, n={peak_count})\n"
        f"[{expected[0]:.0f},{expected[1]:.0f}) in={win_count}/{total}"
    )
    ax.text(0.0, -0.315, footer, transform=ax.transAxes, ha="left", va="top", fontsize=5.1, fontfamily="monospace", linespacing=1.18)


def render(captures: list[Capture], stage: str, output: Path, xlim: tuple[int, int] | None) -> None:
    meta = STAGE_META[stage]
    if xlim is None:
        xlim = meta["xlim"]  # type: ignore[assignment]
    cols = min(4, max(1, len(captures)))
    rows = int(math.ceil(len(captures) / cols))
    fig_height = 8.2 if rows == 1 else 8.2 * rows
    fig, axes = plt.subplots(rows, cols, figsize=(6.0 * cols, fig_height), dpi=160, squeeze=False)
    fig.patch.set_facecolor("white")
    fig.suptitle(str(meta["title"]), fontsize=13.0, fontfamily="monospace", fontweight="bold", y=0.982)
    fig.text(0.5, 0.952, str(meta["subtitle"]), ha="center", va="center", fontsize=8.2, fontfamily="monospace")
    for ax, capture in zip(axes.flat, captures):
        render_case(ax, capture, meta, xlim)
    for ax in axes.flat[len(captures):]:
        ax.set_axis_off()
    handles, labels = axes.flat[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper right", bbox_to_anchor=(0.982, 0.982), fontsize=7.0, frameon=True)
    for ax in axes[rows - 1, :]:
        ax.set_xlabel(str(meta["xlabel"]), fontsize=7.5, fontfamily="monospace")
    for ax in axes[:, 0]:
        ax.set_ylabel(str(meta["ylabel"]), fontsize=7.5, fontfamily="monospace")
    fig.subplots_adjust(left=0.045, right=0.985, top=0.870 if rows == 1 else 0.900, bottom=0.295 if rows == 1 else 0.190, wspace=0.18, hspace=0.82)
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output)
    plt.close(fig)


def write_summary(captures: list[Capture], stage: str, output: Path) -> None:
    meta = STAGE_META[stage]
    expected = meta["expected"]  # type: ignore[assignment]
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as fh:
        fieldnames = [
            "stage",
            "rate",
            "q16_rate",
            "total",
            "nonzero_bins",
            "age_min",
            "age_p05",
            "age_p50",
            "age_p95",
            "age_max",
            "peak_bin",
            "peak_pct",
            "expected_left",
            "expected_right",
            "expected_count",
            "expected_pct",
            "csv",
            "log",
        ]
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for capture in captures:
            peak_bin, peak_pct, _ = peak(capture)
            win = expected_count(capture, expected)  # type: ignore[arg-type]
            writer.writerow(
                {
                    "stage": stage,
                    "rate": capture.rate,
                    "q16_rate": capture.q16_rate,
                    "total": capture.total,
                    "nonzero_bins": sum(1 for count in capture.counts if count),
                    "age_min": stat_min(capture),
                    "age_p05": percentile(capture, 5),
                    "age_p50": percentile(capture, 50),
                    "age_p95": percentile(capture, 95),
                    "age_max": stat_max(capture),
                    "peak_bin": peak_bin,
                    "peak_pct": peak_pct,
                    "expected_left": expected[0],
                    "expected_right": expected[1],
                    "expected_count": win,
                    "expected_pct": 100.0 * win / capture.total if capture.total else 0.0,
                    "csv": capture.csv_path,
                    "log": capture.log_path or "",
                }
            )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--stage", choices=sorted(STAGE_META), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--xlim", nargs=2, type=int, metavar=("LO", "HI"))
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()
    captures = load_captures(args.manifest, args.stage)
    if not captures:
        raise SystemExit(f"no captures for stage {args.stage} in {args.manifest}")
    xlim = tuple(args.xlim) if args.xlim else None
    render(captures, args.stage, args.output, xlim)
    write_summary(captures, args.stage, args.summary)
    print(args.output)
    print(args.summary)
    if args.strict:
        meta = STAGE_META[args.stage]
        expected = meta["expected"]  # type: ignore[assignment]
        failures = [
            f"{capture.rate}: expected-window count {expected_count(capture, expected)}/{capture.total}"
            for capture in captures
            if capture.total == 0 or expected_count(capture, expected) != capture.total
        ]
        if failures:
            for failure in failures:
                print(f"ERROR: {failure}")
            return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
