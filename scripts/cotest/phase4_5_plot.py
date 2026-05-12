#!/usr/bin/env python3
# ============================================================================
# phase4_5_plot.py -- Preset-driven plot renderer for Phase 4.5 sweep evidence.
# ============================================================================
#
#   Sibling to phase4_5_sweep.py. Pure plotter -- does NOT touch SWB / sc_tool.
#   Use to (re)generate plot_rate.png / plot_latency.png from existing
#   sweep_evidence/<row_id>/{counters.json, hist_bin.csv, verdict.json} after a
#   sweep run has completed.
#
#   CLI:
#       python3 scripts/cotest/phase4_5_plot.py --row <row_id> --mode rate
#       python3 scripts/cotest/phase4_5_plot.py --row <row_id> --mode latency
#       python3 scripts/cotest/phase4_5_plot.py --row <row_id> --mode both
#       python3 scripts/cotest/phase4_5_plot.py --all --mode both
#       python3 scripts/cotest/phase4_5_plot.py --list
#
#   Two preset modes:
#       rate     : 256-bin per-channel hit count histogram (one panel),
#                  x = channel_id, y = hits / bin [%]; Anthropic burnt-orange.
#       latency  : 2-panel hit-lifetime plot (pre-rbCAM + post-rbCAM),
#                  x = hit lifetime [8 ns cycles] in [-1000, 3096], y = %.
#
#   Imported by phase4_5_sweep.py:
#       from phase4_5_plot import render_rate_plot, render_latency_plot
#
#   ASCII only. matplotlib only (NOT DISLIN, NOT seaborn). Python 3.10+.
#
# ============================================================================
"""Preset-driven plot renderer for Phase 4.5 sweep evidence.

This module ships two preset plot modes:

1. ``render_rate_plot`` -- per-channel hit-count histogram, one panel.
   The natural readout of the ``histogram_statistics_v2`` ``hist_bin`` CSR
   window when ``KEY_LOC = channel_post``. Each of the 256 bins maps to a
   single channel id. Bar height is ``hits / bin [%]``.

2. ``render_latency_plot`` -- 2-panel pre/post-rbCAM hit lifetime histogram.
   This matches the legacy ``make_plot`` block that used to live inside
   ``phase4_5_sweep.py``. The 256 bins are split into pre-rbCAM (low half)
   and post-rbCAM (high half) and the x-axis is rescaled to the lifetime
   range ``[-1000, 3096]`` 8 ns cycles. Bar height is ``hits / bin [%]``.

Both functions accept structured arguments (a dict-of-bins for the rate plot
or pre-/post-counts for the latency plot, plus the row_id for the title).
They do not re-parse counters.json themselves; the CLI wrapper handles that.

The CLI is opt-in: when the sweep script imports this module, it never
touches argparse. Use ``--list`` to enumerate every row currently in
``sweep_evidence/`` and ``--all`` to re-render plots for every row.
"""
from __future__ import annotations

import argparse
import csv
import json
import os
import sys
from pathlib import Path
from typing import Any, Optional


# ============================================================================
# Top-of-file constants (Anthropic-friendly palette + matplotlib presets)
# ============================================================================

# Rate-mode (channel histogram) bar color: Anthropic burnt-orange.
RATE_BAR_COLOR    = "#cc785c"
# Latency-mode bar colors: blue (pre-rbCAM) and green (post-rbCAM).
LAT_PRE_COLOR     = "#4472C4"
LAT_POST_COLOR    = "#70AD47"

# Annotation colors and line styles.
ANNOTATION_COLOR  = "#1f1f1f"      # body-text dark
PERCENTILE_LINE   = {"color": ANNOTATION_COLOR, "linewidth": 0.8,
                     "linestyle": "--", "alpha": 0.7}

# Common style.
PLOT_DPI          = 300
RATE_FIGSIZE      = (12.0, 5.0)    # one panel, wider aspect
LATENCY_FIGSIZE   = (12.0, 8.0)    # two stacked panels

# Latency mode constants (match the legacy phase4_5_sweep.py settings).
LATENCY_X_LIM     = (-1000, 3096)
LATENCY_X_LABEL   = "hit lifetime [8 ns cycles]"
LATENCY_Y_LABEL   = "hits / bin [%]"
LATENCY_PRE_TITLE = (
    "pre-rbCAM checkpoint lifetime, bound [0.0, 2000.0] cycles"
)
LATENCY_POST_TITLE = (
    "post-rbCAM checkpoint lifetime, bound [2000.0, 2200.0] cycles"
)

# Rate mode constants.
RATE_X_LABEL      = "channel_id"
RATE_Y_LABEL      = "hits / bin [%]"
RATE_TITLE        = "per-channel hit count (histogram_statistics_v2, KEY_LOC=channel_post)"

# Histogram bin count -- matches sweep_evidence/<row_id>/hist_bin.csv.
HIST_NUM_BINS     = 256


def _ensure_matplotlib():
    """Late-import matplotlib so the rest of the module is import-safe in
    no-display environments. Returns ``(plt, np)``."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    import numpy as np
    return plt, np


# ============================================================================
# Path helpers (mirrors phase4_5_sweep.py)
# ============================================================================
SCRIPT_DIR = Path(__file__).resolve().parent


def _find_repo_root(start: Path) -> Path:
    for p in [start, *start.parents]:
        if (p / "firmware_builds").is_dir() and (p / "tools" / "run_script").is_dir():
            return p
    raise RuntimeError(
        f"Could not locate mu3e-ip-cores repo root from {start}"
    )


REPO_ROOT = _find_repo_root(SCRIPT_DIR)
DEFAULT_BUILD_DIR_REL = (
    "firmware_builds/systems/v3_pretest-260511-emulator-type0-260512"
)
_env_build = os.environ.get("PHASE4_5_BUILD_DIR", "").strip()
BUILD_DIR = (
    Path(_env_build).expanduser().resolve()
    if _env_build
    else REPO_ROOT / DEFAULT_BUILD_DIR_REL
)
EVIDENCE_ROOT = BUILD_DIR / "sweep_evidence"


# ============================================================================
# Percentile helper
# ============================================================================

def _percentile_indices(counts, percentiles=(5, 50, 95)):
    """Return (label, idx) tuples for the given percentile points.

    The index is computed against the cumulative sum of ``counts`` so that
    a quantile p maps to the smallest index whose cumulative count reaches
    ``total * p / 100``. If ``counts`` is empty or sums to zero, returns an
    empty list.
    """
    _, np = _ensure_matplotlib()
    counts = np.asarray(counts, dtype=np.int64)
    total = int(counts.sum())
    if total == 0 or len(counts) == 0:
        return []
    cum = np.cumsum(counts)
    out = []
    for p in percentiles:
        idx = int(np.searchsorted(cum, total * p / 100.0))
        idx = min(idx, len(counts) - 1)
        out.append((f"p{p:02d}", idx))
    return out


# ============================================================================
# Rate plot (per-channel hit count, one panel)
# ============================================================================

def render_rate_plot(
    hist_bins: list,
    row_id: str,
    out_path: Path,
    *,
    title_suffix: str = "",
) -> Path:
    """Render the per-channel hit-count histogram.

    Parameters
    ----------
    hist_bins
        Sequence of 256 integers: ``hist_bins[i]`` is the count for
        channel id ``i``.
    row_id
        Sweep row id; used in the figure title.
    out_path
        Target ``plot_rate.png`` path.
    title_suffix
        Optional sub-title to append after the row_id.
    """
    plt, np = _ensure_matplotlib()

    if len(hist_bins) != HIST_NUM_BINS:
        hist_bins = (list(hist_bins) + [0] * HIST_NUM_BINS)[:HIST_NUM_BINS]

    counts = np.asarray(hist_bins, dtype=np.int64)
    total = int(counts.sum())

    fig, ax = plt.subplots(1, 1, figsize=RATE_FIGSIZE,
                            constrained_layout=True)
    title = f"FEB/SWB ASIC0..7 -- {row_id} -- rate"
    if title_suffix:
        title = title + " -- " + title_suffix
    fig.suptitle(title, fontsize=10)
    ax.set_title(RATE_TITLE, fontsize=9)
    ax.set_xlabel(RATE_X_LABEL, fontsize=8)
    ax.set_ylabel(RATE_Y_LABEL, fontsize=8)
    ax.tick_params(labelsize=7)
    ax.set_xlim(-0.5, HIST_NUM_BINS - 0.5)
    centers = np.arange(HIST_NUM_BINS)

    if total == 0:
        ax.text(
            0.5,
            0.5,
            "no hits captured",
            ha="center",
            va="center",
            transform=ax.transAxes,
            fontsize=12,
            color="gray",
        )
    else:
        pct = counts.astype(np.float64) / total * 100.0
        ax.bar(centers, pct, width=0.9, color=RATE_BAR_COLOR,
               alpha=0.85, linewidth=0)
        # p05 / p50 / p95 annotations
        for label, idx in _percentile_indices(counts):
            x_p = float(centers[idx])
            ax.axvline(x_p, **PERCENTILE_LINE)
            ax.text(
                x_p,
                ax.get_ylim()[1] * 0.92,
                f"{label}={idx}",
                rotation=90,
                fontsize=6,
                ha="right",
                va="top",
                color=ANNOTATION_COLOR,
            )
        # Anthropic-style footer with counts.
        ax.text(
            0.99,
            0.97,
            f"total_hits = {total}\nnon_zero_bins = {int((counts > 0).sum())}",
            ha="right",
            va="top",
            transform=ax.transAxes,
            fontsize=7,
            color=ANNOTATION_COLOR,
        )

    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(str(out_path), dpi=PLOT_DPI, bbox_inches="tight")
    plt.close(fig)
    return out_path


# ============================================================================
# Latency plot (pre/post-rbCAM hit lifetime, two panels)
# ============================================================================

def render_latency_plot(
    hist_bins: list,
    row_id: str,
    out_path: Path,
    *,
    title_suffix: str = "",
    note: Optional[str] = None,
) -> Path:
    """Render the 2-panel pre/post-rbCAM hit lifetime histogram.

    Parameters
    ----------
    hist_bins
        Sequence of 256 integers; the low 128 are pre-rbCAM, the high 128
        are post-rbCAM in the legacy layout.
    row_id
        Sweep row id; used in the figure title.
    out_path
        Target ``plot_latency.png`` path.
    title_suffix
        Optional sub-title to append after the row_id.
    note
        If non-empty, annotate the figure with a footer note (used when
        the on-board CSRs do not expose hit timestamps directly).
    """
    plt, np = _ensure_matplotlib()

    if len(hist_bins) != HIST_NUM_BINS:
        hist_bins = (list(hist_bins) + [0] * HIST_NUM_BINS)[:HIST_NUM_BINS]

    arr = np.asarray(hist_bins, dtype=np.int64)
    pre_slice = slice(0, HIST_NUM_BINS // 2)
    post_slice = slice(HIST_NUM_BINS // 2, HIST_NUM_BINS)
    pre_counts = arr[pre_slice]
    post_counts = arr[post_slice]

    x_min, x_max = LATENCY_X_LIM
    bin_width_x = (x_max - x_min) / HIST_NUM_BINS
    pre_centers = x_min + (
        np.arange(pre_slice.start, pre_slice.stop) + 0.5
    ) * bin_width_x
    post_centers = x_min + (
        np.arange(post_slice.start, post_slice.stop) + 0.5
    ) * bin_width_x

    fig, axes = plt.subplots(2, 1, figsize=LATENCY_FIGSIZE,
                              constrained_layout=True)
    title = f"FEB/SWB ASIC0..7 -- {row_id} -- latency"
    if title_suffix:
        title = title + " -- " + title_suffix
    fig.suptitle(title, fontsize=10)

    for ax, centers, counts, panel_title, color in (
        (axes[0], pre_centers, pre_counts, LATENCY_PRE_TITLE, LAT_PRE_COLOR),
        (axes[1], post_centers, post_counts, LATENCY_POST_TITLE,
         LAT_POST_COLOR),
    ):
        ax.set_xlim(LATENCY_X_LIM)
        ax.set_xlabel(LATENCY_X_LABEL, fontsize=8)
        ax.set_ylabel(LATENCY_Y_LABEL, fontsize=8)
        ax.set_title(panel_title, fontsize=9)
        ax.tick_params(labelsize=7)
        total = int(counts.sum())
        if total == 0:
            ax.text(
                0.5,
                0.5,
                "no hits captured" if not note else note,
                ha="center",
                va="center",
                transform=ax.transAxes,
                fontsize=11,
                color="gray",
                wrap=True,
            )
            continue
        pct = counts.astype(np.float64) / total * 100.0
        ax.bar(centers, pct, width=bin_width_x * 0.9, color=color,
               alpha=0.85, linewidth=0)
        for label, idx in _percentile_indices(counts):
            x_p = float(centers[idx])
            ax.axvline(x_p, **PERCENTILE_LINE)
            ax.text(
                x_p,
                ax.get_ylim()[1] * 0.92,
                f"{label}={x_p:.0f}",
                rotation=90,
                fontsize=6,
                ha="right",
                va="top",
                color=ANNOTATION_COLOR,
            )

    out_path = Path(out_path)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(str(out_path), dpi=PLOT_DPI, bbox_inches="tight")
    plt.close(fig)
    return out_path


# ============================================================================
# CLI -- preset wrapper that re-parses hist_bin.csv from sweep_evidence/.
# ============================================================================

def _load_hist_bins(ev_dir: Path) -> list:
    """Return the 256-entry hist_bins list from sweep_evidence/<row>/hist_bin.csv.

    Falls back to a zero-filled list if the file is missing or malformed.
    """
    csv_path = ev_dir / "hist_bin.csv"
    if not csv_path.exists():
        return [0] * HIST_NUM_BINS
    bins = [0] * HIST_NUM_BINS
    try:
        with open(csv_path, encoding="ascii") as f:
            r = csv.reader(f)
            header = next(r, None)
            for row in r:
                if not row or len(row) < 2:
                    continue
                try:
                    idx = int(row[0])
                    val = int(row[1])
                except ValueError:
                    continue
                if 0 <= idx < HIST_NUM_BINS:
                    bins[idx] = val
    except OSError:
        return [0] * HIST_NUM_BINS
    return bins


def _load_row_meta(ev_dir: Path) -> dict:
    """Load row_id and axis_section info from counters.json (best effort)."""
    counters = ev_dir / "counters.json"
    if not counters.exists():
        return {"row_id": ev_dir.name, "axis_section": "unknown"}
    try:
        with open(counters, encoding="ascii") as f:
            data = json.load(f)
        row = data.get("row", {}) or {}
        return {
            "row_id": row.get("row_id", ev_dir.name),
            "axis_section": row.get("axis_section", "unknown"),
            "lane_mask": row.get("lane_mask", "-"),
            "channel_mask": row.get("channel_mask", "-"),
            "rate_88fp": row.get("rate_88fp", "-"),
            "hit_mode": row.get("hit_mode", "-"),
        }
    except (OSError, json.JSONDecodeError):
        return {"row_id": ev_dir.name, "axis_section": "unknown"}


def _enumerate_rows(root: Path) -> list[str]:
    if not root.exists():
        return []
    out = []
    for entry in sorted(root.iterdir()):
        if not entry.is_dir():
            continue
        if entry.name.startswith("_"):
            continue
        if ".bak." in entry.name:
            continue
        if (entry / "hist_bin.csv").exists():
            out.append(entry.name)
    return out


def _render_for_row(row_id: str, mode: str, evidence_root: Path) -> dict:
    ev_dir = evidence_root / row_id
    if not ev_dir.is_dir():
        return {"row_id": row_id, "ok": False,
                "error": f"evidence dir not found: {ev_dir}"}
    bins = _load_hist_bins(ev_dir)
    meta = _load_row_meta(ev_dir)
    axis = meta.get("axis_section", "")
    suffix_bits = []
    if meta.get("lane_mask", "-") != "-":
        suffix_bits.append(f"lane={meta['lane_mask']}")
    if meta.get("channel_mask", "-") != "-":
        suffix_bits.append(f"ch={meta['channel_mask']}")
    if meta.get("rate_88fp", "-") != "-":
        suffix_bits.append(f"rate={meta['rate_88fp']}")
    if meta.get("hit_mode", "-") != "-":
        suffix_bits.append(f"mode={meta['hit_mode']}")
    title_suffix = " ".join(suffix_bits)

    note_latency = (
        "no per-hit timestamps available on board; the histogram is keyed "
        "by channel_id (KEY_LOC=channel_post), see tb_int simulation for "
        "the full lifetime distribution"
    )

    out = {"row_id": row_id, "ok": True, "outputs": []}
    if mode in ("rate", "both"):
        rate_out = render_rate_plot(bins, row_id, ev_dir / "plot_rate.png",
                                     title_suffix=title_suffix)
        out["outputs"].append(str(rate_out))
    if mode in ("latency", "both"):
        # When the row is from a 4.5.2 rate-sweep section, label as rate-emphasis
        lat_suffix = title_suffix
        if axis == "4.5.2":
            lat_suffix = title_suffix + " (rate-sweep row)"
        lat_out = render_latency_plot(
            bins, row_id, ev_dir / "plot_latency.png",
            title_suffix=lat_suffix,
            note=note_latency,
        )
        out["outputs"].append(str(lat_out))
    return out


def main(argv: Optional[list] = None) -> int:
    ap = argparse.ArgumentParser(
        description="Phase 4.5 plot generator (preset-driven, post-sweep)"
    )
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--row", help="render plots for a single row_id")
    grp.add_argument("--all", action="store_true",
                      help="render plots for every row in sweep_evidence/")
    grp.add_argument("--list", action="store_true",
                      help="list every row_id currently in sweep_evidence/")
    ap.add_argument("--mode", default="both",
                     choices=("rate", "latency", "both"),
                     help="which preset to render (default: both)")
    ap.add_argument("--evidence-root", type=Path, default=EVIDENCE_ROOT,
                     help="override sweep_evidence root path")
    args = ap.parse_args(argv)

    root = args.evidence_root.resolve()

    if args.list:
        rows = _enumerate_rows(root)
        if not rows:
            print(f"(no rows under {root})", file=sys.stderr)
            return 0
        for r in rows:
            print(r)
        return 0

    if args.row:
        result = _render_for_row(args.row, args.mode, root)
        if not result["ok"]:
            print(f"FAIL {args.row}: {result.get('error')}", file=sys.stderr)
            return 1
        for path in result["outputs"]:
            print(f"  wrote {path}")
        return 0

    # --all
    rows = _enumerate_rows(root)
    if not rows:
        print(f"(no rows under {root})", file=sys.stderr)
        return 0
    fail = 0
    for r in rows:
        result = _render_for_row(r, args.mode, root)
        if not result["ok"]:
            print(f"FAIL {r}: {result.get('error')}", file=sys.stderr)
            fail += 1
            continue
        for path in result["outputs"]:
            print(f"  wrote {path}")
    print(f"\nDone: {len(rows) - fail} ok, {fail} fail "
          f"(mode={args.mode})")
    return 0 if fail == 0 else 2


if __name__ == "__main__":
    sys.exit(main())
