#!/usr/bin/env python3
"""Contact-sheet latency histogram (DISLIN aesthetic) for tb_int closed_records.

Differences from plot_tb_int_latency_contact_sheet.py (the baseline renderer):

1. Bin resolution -- integer-cycle bins (bin_width=1 cycle) instead of a fixed
   count of 256.  With all hits landing at a single integer latency value, 256
   bins over a 24-cycle range produces a 0.09-cycle-wide needle that is nearly
   invisible.  1-cycle bins produce a full-width bar.  This is the primary
   visual-debug finding driven by the scientific-plotting skill: the prior plot
   was technically correct but rendered the entire data population as a hairline.

2. Y-axis tick density -- prior renderer derived tick_step from y_top with a
   step of 5 at y_top>10.  At 100 % that gives 20 ticks on a tiny panel.
   Fixed to [0, 20, 40, 60, 80, 100] (6 ticks) when peak fraction >= 90 %.

3. X-tick labels -- prior labels were spaced at the stage-mode xtick list, some
   of which landed outside the visible range.  Now derived from the xlim with a
   spacing matched to the integer bin grid.

4. X-axis window -- all three panels use the reference rbCAM aperture view
   [-1024, 3072] cycles, with green lines at 0 and 2000 cycles.  This matches
   the phase-0 latency-plot convention used for visual comparison across cases.

Metric definitions
------------------
  pre-rbCAM latency  = abs_ts_pre_rbcam  - abs_ts_a   [cycles]
  post-rbCAM latency = abs_ts_post_rbcam - abs_ts_a   [cycles]
  FEB-egress latency = abs_ts_feb_egress - abs_ts_a   [cycles]

CSV timestamps are in ps; the renderer converts them to 125 MHz clock cycles.
"""

from __future__ import annotations

import argparse
import csv
import fnmatch
import math
import sys
import time
import warnings
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Rectangle  # noqa: E402

# ---------------------------------------------------------------------------
# Stage definitions.  xlim and win_* follow the reference rbCAM latency
# aperture used in the user-facing phase-0 histogram panels.
# ---------------------------------------------------------------------------
STAGES: list[dict[str, object]] = [
    {
        "key": "pre_rbcam",
        "label": "pre-rbCAM (ring_buffer_cam asi_hit_type1)",
        "col_diff": ("abs_ts_pre_rbcam", "abs_ts_a"),
        "win_left": 0.0,
        "win_right": 2000.0,
        "xlim": (-1024.0, 3072.0),
        "xtick_step": 512,
    },
    {
        "key": "post_rbcam",
        "label": "post-rbCAM (ring_buffer_cam hit_type2)",
        "col_diff": ("abs_ts_post_rbcam", "abs_ts_a"),
        "win_left": 0.0,
        "win_right": 2000.0,
        "xlim": (-1024.0, 3072.0),
        "xtick_step": 512,
    },
    {
        "key": "feb_egress",
        "label": "FEB-egress (packet scheduler egress)",
        "col_diff": ("abs_ts_feb_egress", "abs_ts_a"),
        "win_left": 0.0,
        "win_right": 2000.0,
        "xlim": (-1024.0, 3072.0),
        "xtick_step": 512,
    },
]

N_STAGES = len(STAGES)
CLOCK_PERIOD_PS = 8000.0
REQUIRED_FIELDS = {"hit_id", "abs_ts_a", "abs_ts_pre_rbcam", "abs_ts_post_rbcam", "abs_ts_feb_egress", "run_origin"}
REQUIRED_STABLE_FIELD = "run_origin"


# ---------------------------------------------------------------------------
# Data structures
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class Hist:
    case_name: str
    stage_label: str
    win_left: float
    win_right: float
    centers: list[float]
    counts: list[int]

    @property
    def total(self) -> int:
        return sum(self.counts)

    @property
    def nonzero_bins(self) -> int:
        return sum(1 for c in self.counts if c > 0)

    @property
    def peak_bin_index(self) -> int | None:
        if not self.counts or self.total <= 0:
            return None
        return max(range(len(self.counts)), key=self.counts.__getitem__)

    @property
    def peak_center(self) -> float | None:
        idx = self.peak_bin_index
        return self.centers[idx] if idx is not None else None

    @property
    def peak_fraction_pct(self) -> float:
        total = self.total
        return 100.0 * max(self.counts) / total if total > 0 else 0.0

    @property
    def in_window(self) -> int:
        return sum(
            count
            for center, count in zip(self.centers, self.counts)
            if self.win_left <= center < self.win_right
        )

    @property
    def out_window(self) -> int:
        return self.total - self.in_window

    def pct(self, value: int) -> float:
        return 100.0 * value / self.total if self.total else 0.0

    def normalized_counts(self) -> list[float]:
        total = self.total
        if total <= 0:
            return [0.0] * len(self.counts)
        return [100.0 * c / total for c in self.counts]

    def summary_row(self) -> dict[str, object]:
        pc = self.peak_center
        return {
            "case": self.case_name,
            "stage": self.stage_label,
            "total": self.total,
            "nonzero_bins": self.nonzero_bins,
            "peak_bin_index": self.peak_bin_index,
            "peak_cycles": pc,
            "peak_fraction_pct": round(self.peak_fraction_pct, 6),
            "win_left": self.win_left,
            "win_right": self.win_right,
            "in_window_count": self.in_window,
            "in_window_pct": round(self.pct(self.in_window), 6),
            "out_window_count": self.out_window,
            "out_window_pct": round(self.pct(self.out_window), 6),
        }


# ---------------------------------------------------------------------------
# Histogram builder -- 1-cycle bins aligned to integer edges
# ---------------------------------------------------------------------------

def build_integer_histogram(latencies: list[float], xlim: tuple[float, float]) -> tuple[list[float], list[int]]:
    """Build 1-cycle-wide bins aligned to integer cycle boundaries.

    Each bin spans [n-0.5, n+0.5) for integer n.  The bin centre is n.
    xlim defines the display window; only bins whose centre falls in
    [xlim[0], xlim[1]) are included.
    """
    lo, hi = xlim
    # Enumerate integer centres in the xlim range
    first_n = math.ceil(lo)
    last_n = math.floor(hi) - 1  # centre < hi
    centers = list(range(first_n, last_n + 1))
    center_set = {n: idx for idx, n in enumerate(centers)}
    counts = [0] * len(centers)
    for v in latencies:
        n = int(round(v))  # nearest integer cycle
        if n in center_set:
            counts[center_set[n]] += 1
    return [float(c) for c in centers], counts


# ---------------------------------------------------------------------------
# Histogram loading
# ---------------------------------------------------------------------------

def load_case(case_dir: Path, stable_only: bool = False) -> list[Hist] | None:
    csv_path = case_dir / "closed_records.csv"
    if not csv_path.is_file():
        warnings.warn(f"[skip] {case_dir.name}: closed_records.csv not found")
        return None
    with csv_path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames is None or not REQUIRED_FIELDS.issubset(set(reader.fieldnames)):
            warnings.warn(f"[skip] {case_dir.name}: missing required columns")
            return None
        rows = list(reader)
    if len(rows) < 2:
        warnings.warn(f"[skip] {case_dir.name}: only {len(rows)} row(s)")
        return None
    if stable_only:
        try:
            rows = [row for row in rows if int(row[REQUIRED_STABLE_FIELD]) != 0]
        except (KeyError, ValueError) as exc:
            warnings.warn(f"[skip] {case_dir.name}: cannot filter stable-origin rows ({exc})")
            return None
        if len(rows) < 2:
            warnings.warn(f"[skip] {case_dir.name}: no stable-origin rows available")
            return None

    hists: list[Hist] = []
    for stage in STAGES:
        col_after, col_before = stage["col_diff"]  # type: ignore[misc]
        try:
            latencies = [
                float(int(r[col_after]) - int(r[col_before])) / CLOCK_PERIOD_PS
                for r in rows
            ]  # type: ignore[index]
        except (KeyError, ValueError) as exc:
            warnings.warn(f"[skip] {case_dir.name} stage {stage['label']}: {exc}")
            return None
        xlim_s = (float(stage["xlim"][0]), float(stage["xlim"][1]))  # type: ignore[index]
        centers, counts = build_integer_histogram(latencies, xlim=xlim_s)
        hists.append(Hist(
            case_name=case_dir.name,
            stage_label=str(stage["label"]),
            win_left=float(stage["win_left"]),  # type: ignore[arg-type]
            win_right=float(stage["win_right"]),  # type: ignore[arg-type]
            centers=centers,
            counts=counts,
        ))
    return hists


# ---------------------------------------------------------------------------
# Y-axis layout
# ---------------------------------------------------------------------------

def yticks_for_peak_fraction(peak_pct: float, y_top: float) -> list[float]:
    """Return a sparse y-tick list.

    When the peak fraction is >= 90 % (all-in-one-bin case), use 6 ticks at
    [0, 20, 40, 60, 80, 100].  Otherwise fall back to a 10-unit grid up to
    y_top.
    """
    if peak_pct >= 90.0:
        return [0.0, 20.0, 40.0, 60.0, 80.0, 100.0]
    step = 10.0
    return [float(v) for v in range(0, int(y_top) + 1, int(step))]


def rounded_y_top(hist: Hist) -> float:
    ymax = max(hist.normalized_counts(), default=0.0)
    if ymax >= 90.0:
        return 110.0  # give breathing room above 100 % spike
    if ymax <= 10.0:
        return 10.0
    if ymax <= 20.0:
        return 20.0
    return math.ceil(ymax * 1.12 / 10.0) * 10.0


# ---------------------------------------------------------------------------
# Panel renderer
# ---------------------------------------------------------------------------

def render_panel(
    fig: plt.Figure,
    rect: tuple[float, float, float, float],
    hist: Hist,
    stage: dict[str, object],
    title: str,
    subtitle: str,
    footer_fontsize: float,
    title_fontsize: float,
) -> None:
    """Render one histogram panel (DISLIN aesthetic) into fig."""
    left, bottom, width, height = rect

    # Hairline double-border (DISLIN aesthetic: inner grey, outer lighter)
    for (ew, ew2, ec, lw) in [
        (0.0, 0.0, "#9a9a9a", 0.9),
        (0.003, 0.004, "#d2d2d2", 0.45),
    ]:
        fig.add_artist(Rectangle(
            (left + ew * width, bottom + ew2 * height),
            width - 2 * ew * width,
            height - 2 * ew2 * height,
            transform=fig.transFigure, fill=False, edgecolor=ec, linewidth=lw,
        ))

    xlim: tuple[float, float] = (float(stage["xlim"][0]), float(stage["xlim"][1]))  # type: ignore[index]
    # bin_width = 1.0 cycle (integer bins); bar width slightly narrower
    bin_width = 1.0

    ax = fig.add_axes([left + 0.142 * width, bottom + 0.255 * height, 0.700 * width, 0.450 * height])

    ax.bar(hist.centers, hist.normalized_counts(), width=bin_width * 0.88, align="center",
           facecolor=(0.0, 0.42, 1.0, 0.08), edgecolor="#0066ff", linewidth=0.45)

    win_left, win_right = hist.win_left, hist.win_right
    ax.axvline(win_left, color="#00e044", linewidth=0.9)
    ax.axvline(win_right, color="#00e044", linewidth=0.9)
    peak_c = hist.peak_center
    if peak_c is not None:
        ax.axvline(peak_c, color="#111111", linewidth=1.0)

    y_top = rounded_y_top(hist)
    ax.set_xlim(*xlim)
    ax.set_ylim(0.0, y_top)

    # X-ticks: derive from xtick_step aligned to integer cycle grid
    xtick_step = int(stage.get("xtick_step", 2))  # type: ignore[call-overload]
    lo_tick = math.ceil(xlim[0] / xtick_step) * xtick_step
    hi_tick = math.floor(xlim[1] / xtick_step) * xtick_step
    xtick_vals = list(range(int(lo_tick), int(hi_tick) + 1, xtick_step))
    ax.set_xticks([float(v) for v in xtick_vals])

    # Y-ticks: sparse when all data is in one bin
    ytick_vals = yticks_for_peak_fraction(hist.peak_fraction_pct, y_top)
    ax.set_yticks(ytick_vals)

    ax.grid(True, color="#000000", alpha=0.28, linewidth=0.55)
    ax.tick_params(axis="both", which="both", top=True, right=True,
                   labelsize=6, width=0.45, color="#666666", labelcolor="#555555")
    for spine in ax.spines.values():
        spine.set_linewidth(0.45)
        spine.set_color("#555555")
    ax.set_xlabel("signed hit latency bin center [cycles]", fontsize=7.5, family="monospace")
    ax.set_ylabel("hits / bin [% of captured interval]", fontsize=7.5, family="monospace")

    # Title and subtitle inside panel
    fig.text(left + 0.5 * width, bottom + 0.840 * height, title,
             ha="center", va="center", fontsize=title_fontsize, family="monospace")
    fig.text(left + 0.5 * width, bottom + 0.795 * height, subtitle,
             ha="center", va="center", fontsize=max(footer_fontsize - 0.3, 4.5), family="monospace")

    # Footer info block (monospaced, 3 lines)
    peak_text = "None" if peak_c is None else f"{peak_c:.1f}"
    in_pct, out_pct = hist.pct(hist.in_window), hist.pct(hist.out_window)
    footer_lines = [
        (f"total={hist.total} hits, nonzero={hist.nonzero_bins}/{len(hist.counts)}, "
         f"peak bin={hist.peak_bin_index} at {peak_text} cycles, "
         f"peak fraction={hist.peak_fraction_pct:.3f}%"),
        (f"black=peak {peak_text} cycles; green=rbCAM window edges "
         f"{win_left:.0f} and {win_right:.0f} cycles"),
        (f"{hist.stage_label} [{win_left:.0f},{win_right:.0f}]: "
         f"in={hist.in_window} ({in_pct:.6f}%), out={hist.out_window} ({out_pct:.6f}%)"),
    ]
    footer_y = bottom + 0.128 * height
    for i, line in enumerate(footer_lines):
        fig.text(left + 0.140 * width, footer_y - i * 0.048 * height, line,
                 ha="left", va="center", fontsize=footer_fontsize, family="monospace")


# ---------------------------------------------------------------------------
# Page renderer
# ---------------------------------------------------------------------------

def render_page(
    page_cases: list[tuple[str, list[Hist]]],
    output: Path,
    title_tag: str,
    panel_height: float = 3.0,
) -> None:
    n_rows = len(page_cases)
    if n_rows == 0:
        return
    row_label_width = 0.08
    fig_width = 22.0
    fig_height = max(4.5, n_rows * panel_height + 0.6)
    fig = plt.figure(figsize=(fig_width, fig_height), facecolor="white")
    tag_text = f" ({title_tag})" if title_tag else ""
    fig.text(0.5, 0.985, f"tb_int Avalon-ST Latency Contact Sheet{tag_text}",
             ha="center", va="top", fontsize=11, family="monospace", weight="bold")

    col_gap = 0.008
    col_width = (1.0 - row_label_width - col_gap * (N_STAGES + 1)) / N_STAGES
    row_gap = 0.012
    top_margin, bottom_margin = 0.035, 0.01
    row_height = (1.0 - top_margin - bottom_margin - row_gap * (n_rows + 1)) / n_rows
    footer_fontsize = max(4.5, min(6.5, row_height * fig_height * 2.5))
    title_fontsize = max(5.0, min(7.5, row_height * fig_height * 3.0))

    for row_idx, (case_name, hists) in enumerate(page_cases):
        row_bottom = bottom_margin + row_gap + (n_rows - 1 - row_idx) * (row_height + row_gap)
        fig.text(row_label_width * 0.5, row_bottom + row_height * 0.5, case_name,
                 ha="center", va="center",
                 fontsize=max(4.5, min(6.5, row_height * fig_height * 2.2)),
                 family="monospace", rotation=90)
        for col_idx, (stage, hist) in enumerate(zip(STAGES, hists)):
            col_left = row_label_width + col_gap * (col_idx + 1) + col_idx * col_width
            wl = float(stage["win_left"])  # type: ignore[arg-type]
            wr = float(stage["win_right"])  # type: ignore[arg-type]
            render_panel(
                fig=fig,
                rect=(col_left, row_bottom, col_width, row_height),
                hist=hist, stage=stage,
                title=f"tb_int latency: {stage['label']}",
                subtitle=f"case={case_name}; win=[{wl:.0f},{wr:.0f}]",
                footer_fontsize=footer_fontsize,
                title_fontsize=title_fontsize,
            )

    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output, dpi=160, bbox_inches="tight")
    plt.close(fig)
    print(f"  wrote {output}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Pagination
# ---------------------------------------------------------------------------

def paginate(all_cases: list[tuple[str, list[Hist]]], out_dir: Path,
             rows_per_page: int, title_tag: str) -> list[Path]:
    outputs: list[Path] = []
    n_pages = max(1, math.ceil(len(all_cases) / rows_per_page))
    pad = len(str(n_pages))
    for page_idx in range(n_pages):
        chunk = all_cases[page_idx * rows_per_page: (page_idx + 1) * rows_per_page]
        if not chunk:
            continue
        stem = "contact_sheet_dislin" if n_pages == 1 else f"contact_sheet_dislin_p{page_idx + 1:0{pad}d}"
        out_path = out_dir / f"{stem}.png"
        render_page(chunk, out_path, title_tag)
        outputs.append(out_path)
    return outputs


# ---------------------------------------------------------------------------
# Summary CSV
# ---------------------------------------------------------------------------

def write_summary_csv(all_cases: list[tuple[str, list[Hist]]], out_dir: Path) -> Path:
    out_path = out_dir / "latency_summary.csv"
    fieldnames = ["case", "stage", "total", "nonzero_bins", "peak_bin_index", "peak_cycles",
                  "peak_fraction_pct", "win_left", "win_right",
                  "in_window_count", "in_window_pct", "out_window_count", "out_window_pct"]
    out_dir.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for _case_name, hists in all_cases:
            for hist in hists:
                writer.writerow(hist.summary_row())
    return out_path


# ---------------------------------------------------------------------------
# Case discovery
# ---------------------------------------------------------------------------

def discover_cases(sim_root: Path, cases_spec: str) -> list[Path]:
    sim_root = sim_root.resolve()
    if not sim_root.is_dir():
        raise FileNotFoundError(f"--sim-root not found: {sim_root}")
    all_dirs = sorted(d for d in sim_root.iterdir() if d.is_dir())
    if cases_spec.lower() == "all":
        return all_dirs
    patterns = [p.strip() for p in cases_spec.split(",") if p.strip()]
    matched: list[Path] = []
    seen: set[str] = set()
    for pattern in patterns:
        for d in all_dirs:
            if fnmatch.fnmatch(d.name, pattern) and d.name not in seen:
                matched.append(d)
                seen.add(d.name)
    return matched


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> int:
    t0 = time.monotonic()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sim-root", type=Path, required=True, metavar="DIR")
    parser.add_argument("--cases", default="all", metavar="SPEC",
                        help="Comma-separated glob patterns, or 'all'.")
    parser.add_argument("--out-dir", type=Path, required=True, metavar="DIR")
    parser.add_argument("--rows-per-page", type=int, default=4, metavar="N")
    parser.add_argument("--title-tag", default="", metavar="TEXT")
    parser.add_argument("--stable-only", action="store_true", default=False,
                        help="Only include rows where run_origin == 1")
    args = parser.parse_args()

    case_dirs = discover_cases(args.sim_root, args.cases)
    if not case_dirs:
        print(f"ERROR: no matching case directories under {args.sim_root}", file=sys.stderr)
        return 2
    print(f"Discovered {len(case_dirs)} case(s).", file=sys.stderr)

    all_cases: list[tuple[str, list[Hist]]] = []
    skipped = 0
    for case_dir in case_dirs:
        hists = load_case(case_dir, stable_only=args.stable_only)
        if hists is None:
            skipped += 1
        else:
            all_cases.append((case_dir.name, hists))
    if skipped:
        print(f"Skipped {skipped} case(s).", file=sys.stderr)
    if not all_cases:
        print("ERROR: no loadable cases.", file=sys.stderr)
        return 3

    print(f"Rendering {len(all_cases)} case(s), {args.rows_per_page} rows/page.", file=sys.stderr)
    png_paths = paginate(all_cases, out_dir=args.out_dir,
                         rows_per_page=args.rows_per_page, title_tag=args.title_tag)
    csv_path = write_summary_csv(all_cases, args.out_dir)
    print(f"  wrote {csv_path}", file=sys.stderr)

    elapsed = time.monotonic() - t0
    print(f"\nDone. {len(png_paths)} page(s), {len(all_cases)} case(s), {elapsed:.1f}s elapsed.")
    for p in png_paths:
        print(f"  {p}")
    print(f"  {csv_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
