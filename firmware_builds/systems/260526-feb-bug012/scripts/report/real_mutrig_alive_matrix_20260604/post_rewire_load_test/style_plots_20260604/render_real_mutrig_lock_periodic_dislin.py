#!/usr/bin/env python3
"""Render the main real-MuTRiG rate, periodic-delay, and header-sync plots."""

from __future__ import annotations

import argparse
import csv
import json
import math
import re
import sys
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import render_requested_style_plots_dislin as base  # noqa: E402

dis = base.dis


def rate_label(hz: float) -> str:
    if hz >= 1_000_000:
        return f"~{hz / 1_000_000:.2g}M/s"
    if hz >= 1000:
        return f"~{hz / 1000:.0f}k/s"
    return f"~{hz:.0f}/s"


def measured_label(hz: float) -> str:
    if hz >= 1_000_000:
        return f"meas {hz / 1_000_000:.2g} M/s"
    if hz >= 1000:
        return f"meas {hz / 1000:.0f} k/s"
    return f"meas {hz:.0f} /s"


def draw_periodic_delay_panel(row: dict[str, Any], idx: int) -> None:
    positions = [
        (265, 780),
        (1660, 780),
        (265, 1785),
        (1660, 1785),
    ]
    x0, y0 = positions[idx]
    ax_w, ax_h = 1000, 440
    centers = [float(v) for v in row["centers_cycles"]]
    counts = [float(v) for v in row["type1_combined_counts"]]
    total = sum(counts)
    y_pct = [0.0 if total <= 0 else 100.0 * value / total for value in counts]
    y_top = max(10.0, math.ceil((max(y_pct) if y_pct else 0.0) * 1.3))
    y_step = 2.0 if y_top <= 10.0 else base.nice_axis(y_top, 5)[1]
    summary = row["summary"]
    requested = float(row["requested_hz"])

    base.draw_page_text(
        f"Type1 delay - periodic {rate_label(requested)}",
        x0 + 315,
        y0 - ax_h - 78,
        18,
    )
    base.draw_page_text(
        f"{measured_label(float(summary.get('measured_hz', 0.0)))}   "
        "delay [cyc]   green = expected plateau [0,1000]",
        x0 + 160,
        y0 - ax_h - 38,
        20,
    )

    dis.axspos(x0, y0)
    dis.axslen(ax_w, ax_h)
    dis.height(22)
    dis.hname(24)
    dis.labdis(10, "XY")
    dis.namdis(18, "XY")
    dis.name("periodic hit latency bin center [cycles]", "X")
    dis.name("hits / bin [% of captured interval]", "Y")
    dis.labdig(-1, "X")
    dis.labdig(1, "Y")
    dis.ticks(1, "XY")
    dis.graf(0.0, 1024.0, 0.0, 128.0, 0.0, y_top, 0.0, y_step)
    dis.grid(1, 1)

    dis.barwth(0.65)
    dis.color("blue")
    dis.bars(centers, [0.0] * len(centers), y_pct, len(centers))

    dis.linwid(3)
    dis.color("green")
    dis.curve([0.0, 0.0], [0.0, y_top], 2)
    dis.curve([1000.0, 1000.0], [0.0, y_top], 2)
    peak = summary.get("peak_center_cycles")
    if peak is not None:
        dis.color("fore")
        dis.curve([float(peak), float(peak)], [0.0, y_top], 2)
    dis.linwid(1)
    dis.color("fore")

    total_i = int(summary.get("total", 0))
    peak_frac = 100.0 * float(summary.get("peak_fraction", 0.0))
    plateau_frac = 100.0 * float(summary.get("plateau_window_fraction", 0.0))
    base.draw_page_text(
        f"total={total_i} hits, nonzero={summary.get('nonzero_bins', 0)}/256, "
        f"span=[{summary.get('first_nonzero_center')},{summary.get('last_nonzero_center')}] cycles",
        x0,
        y0 + 125,
        18,
    )
    base.draw_page_text(
        f"black=peak {float(peak or 0):.1f} cycles, "
        f"peak fraction={peak_frac:.3f}%",
        x0,
        y0 + 158,
        18,
    )
    base.draw_page_text(
        f"plateau [0,1000]: in={int(summary.get('plateau_window_count', 0))} "
        f"({plateau_frac:.6f}%)",
        x0,
        y0 + 191,
        18,
    )
    dis.endgrf()


def render_periodic_delay_contact(delay_json: Path, output: Path, device: str) -> None:
    data = json.loads(delay_json.read_text())
    rows = data["rows"]
    left = int(data.get("left", 0))
    bw = int(data.get("bin_width", 4))
    n_bins = int(data.get("n_bins", 256))
    centers = [left + idx * bw + bw // 2 for idx in range(n_bins)]
    for row in rows:
        row["centers_cycles"] = centers

    base.init_page(output, device, wide=True)
    base.draw_center_text(
        "FEB SciFi v4 - Type1 periodic rbCAM delay plateau [0,1000] (real MuTRiG)",
        92,
        30,
    )
    for idx, row in enumerate(rows[:4]):
        draw_periodic_delay_panel(row, idx)
    dis.disfin()


def draw_headersync_delay_panel(row: dict[str, Any], idx: int) -> None:
    positions = [
        (265, 780),
        (1660, 780),
        (265, 1785),
        (1660, 1785),
    ]
    x0, y0 = positions[idx]
    ax_w, ax_h = 1000, 440
    centers = [float(v) for v in row["centers_cycles"]]
    counts = [float(v) for v in row["type1_combined_counts"]]
    total = sum(counts)
    y_pct = [0.0 if total <= 0 else 100.0 * value / total for value in counts]
    y_top = max(10.0, math.ceil((max(y_pct) if y_pct else 0.0) * 1.25))
    y_step = 2.0 if y_top <= 10.0 else base.nice_axis(y_top, 5)[1]
    summary = row["summary"]
    header_delay = int(row["header_delay"])
    expected = float(row.get("expected_center_cycles", 910 - header_delay))
    peak = summary.get("peak_center_cycles")

    base.draw_page_text(
        f"Type1 header-sync delay - hd={header_delay}",
        x0 + 280,
        y0 - ax_h - 78,
        18,
    )
    base.draw_page_text(
        "ASIC1 TDC-test only   blue=measured, red=910-hd, black=peak, green=[0,1000]",
        x0 + 75,
        y0 - ax_h - 38,
        18,
    )

    dis.axspos(x0, y0)
    dis.axslen(ax_w, ax_h)
    dis.height(22)
    dis.hname(24)
    dis.labdis(10, "XY")
    dis.namdis(18, "XY")
    dis.name("header-sync hit latency bin center [cycles]", "X")
    dis.name("hits / bin [% of captured interval]", "Y")
    dis.labdig(-1, "X")
    dis.labdig(1, "Y")
    dis.ticks(1, "XY")
    dis.graf(0.0, 1024.0, 0.0, 128.0, 0.0, y_top, 0.0, y_step)
    dis.grid(1, 1)

    dis.barwth(0.65)
    dis.color("blue")
    dis.bars(centers, [0.0] * len(centers), y_pct, len(centers))

    dis.linwid(3)
    dis.color("green")
    dis.curve([0.0, 0.0], [0.0, y_top], 2)
    dis.curve([1000.0, 1000.0], [0.0, y_top], 2)
    dis.color("red")
    dis.curve([expected, expected], [0.0, y_top], 2)
    if peak is not None:
        dis.color("fore")
        dis.curve([float(peak), float(peak)], [0.0, y_top], 2)
    dis.linwid(1)
    dis.color("fore")

    total_i = int(summary.get("total", 0))
    peak_frac = 100.0 * float(summary.get("peak_fraction", 0.0))
    in_frac = 100.0 * float(summary.get("in_0_1000_fraction", 0.0))
    width = summary.get("p05_p95_width_cycles")
    width_text = "None" if width is None else f"{float(width):.0f}"
    base.draw_page_text(
        f"total={total_i} hits, nonzero={summary.get('nonzero_bins', 0)}/256, "
        f"span=[{summary.get('first_nonzero_center')},{summary.get('last_nonzero_center')}] cycles",
        x0,
        y0 + 125,
        18,
    )
    base.draw_page_text(
        f"peak={float(peak or 0):.1f} cycles, expected={expected:.1f}, "
        f"peak fraction={peak_frac:.3f}%",
        x0,
        y0 + 158,
        18,
    )
    base.draw_page_text(
        f"p05-p95={width_text} cycles; in [0,1000]={in_frac:.6f}%",
        x0,
        y0 + 191,
        18,
    )
    dis.endgrf()


def render_headersync_delay_contact(delay_json: Path, output: Path, device: str) -> None:
    data = json.loads(delay_json.read_text())
    rows = data["rows"]
    base.init_page(output, device, wide=True)
    isolated = data.get("isolated_asic", "unknown")
    header_ch = data.get("header_ch", "unknown")
    base.draw_center_text(
        f"FEB SciFi v4 - ASIC{isolated} header-sync Type1 delay vs header_delay (HEADER_CH={header_ch})",
        92,
        30,
    )
    for idx, row in enumerate(rows[:4]):
        draw_headersync_delay_panel(row, idx)
    dis.disfin()


def parse_hsync_csv(path: Path) -> tuple[list[float], list[float]]:
    centers: list[float] = []
    counts: list[float] = []
    with path.open() as f:
        reader = csv.reader(f)
        for row in reader:
            if len(row) < 3:
                continue
            centers.append(float(row[1]))
            counts.append(float(row[2]))
    return centers, counts


def percentile_center(centers: list[float], counts: list[float], pct: float) -> float | None:
    total = sum(counts)
    if total <= 0:
        return None
    threshold = total * pct
    acc = 0.0
    for center, count in zip(centers, counts):
        acc += count
        if acc >= threshold:
            return center
    return centers[-1] if centers else None


def hsync_summary(asic: int, header_delay: int, centers: list[float], counts: list[float]) -> dict[str, Any]:
    total = sum(counts)
    nonzero = [idx for idx, count in enumerate(counts) if count > 0]
    peak_bin = max(range(len(counts)), key=lambda idx: counts[idx]) if total else None
    p05 = percentile_center(centers, counts, 0.05)
    p95 = percentile_center(centers, counts, 0.95)
    peak_center = None if peak_bin is None else centers[peak_bin]
    expected = 910 - header_delay
    return {
        "asic": asic,
        "header_delay": header_delay,
        "expected_center_cycles": expected,
        "total": int(total),
        "nonzero_bins": len(nonzero),
        "first_nonzero_center": None if not nonzero else centers[nonzero[0]],
        "last_nonzero_center": None if not nonzero else centers[nonzero[-1]],
        "peak_bin": peak_bin,
        "peak_center_cycles": peak_center,
        "peak_count": 0 if peak_bin is None else int(counts[peak_bin]),
        "peak_fraction": 0.0 if total <= 0 or peak_bin is None else counts[peak_bin] / total,
        "p05_center_cycles": p05,
        "p95_center_cycles": p95,
        "p05_p95_width_cycles": None if p05 is None or p95 is None else p95 - p05,
        "inside_0_1000": bool(peak_center is not None and 0 <= peak_center <= 1000),
    }


def load_hsync_rows(hsync_dir: Path, header_delay: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    pattern = re.compile(r"asic(\d+)_hd(\d+)\.csv$")
    by_asic: dict[int, Path] = {}
    for path in hsync_dir.glob("asic*_hd*.csv"):
        match = pattern.match(path.name)
        if not match:
            continue
        asic = int(match.group(1))
        hd = int(match.group(2))
        if hd == header_delay:
            by_asic[asic] = path
    for asic in range(8):
        path = by_asic.get(asic)
        if path is None:
            rows.append({
                "asic": asic,
                "header_delay": header_delay,
                "expected_center_cycles": 910 - header_delay,
                "centers_cycles": [float(idx * 4 + 2) for idx in range(256)],
                "counts": [0.0] * 256,
                "summary": hsync_summary(asic, header_delay, [float(idx * 4 + 2) for idx in range(256)], [0.0] * 256),
                "csv": None,
            })
            continue
        centers, counts = parse_hsync_csv(path)
        rows.append({
            "asic": asic,
            "header_delay": header_delay,
            "expected_center_cycles": 910 - header_delay,
            "centers_cycles": centers,
            "counts": counts,
            "summary": hsync_summary(asic, header_delay, centers, counts),
            "csv": str(path),
        })
    return rows


def write_hsync_summary_files(rows: list[dict[str, Any]], out_dir: Path) -> tuple[Path, Path]:
    json_path = out_dir / "real_mutrig_header_sync_pll_lock_summary.json"
    csv_path = out_dir / "real_mutrig_header_sync_pll_lock_summary.csv"
    json_path.write_text(json.dumps({"kind": "real_mutrig_header_sync_pll_lock", "rows": rows}, indent=2, sort_keys=True) + "\n")
    with csv_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "asic", "header_delay", "expected_center_cycles", "total",
            "nonzero_bins", "peak_center_cycles", "peak_fraction",
            "p05_center_cycles", "p95_center_cycles", "p05_p95_width_cycles",
            "inside_0_1000",
        ])
        for row in rows:
            summary = row["summary"]
            writer.writerow([
                summary["asic"],
                summary["header_delay"],
                summary["expected_center_cycles"],
                summary["total"],
                summary["nonzero_bins"],
                summary["peak_center_cycles"],
                summary["peak_fraction"],
                summary["p05_center_cycles"],
                summary["p95_center_cycles"],
                summary["p05_p95_width_cycles"],
                summary["inside_0_1000"],
            ])
    return json_path, csv_path


def draw_hsync_panel(row: dict[str, Any], idx: int) -> None:
    col = idx % 4
    row_idx = idx // 4
    x0 = 155 + col * 710
    y0 = 710 + row_idx * 930
    ax_w, ax_h = 560, 300
    centers = [float(v) for v in row["centers_cycles"]]
    counts = [float(v) for v in row["counts"]]
    total = sum(counts)
    y_pct = [0.0 if total <= 0 else 100.0 * value / total for value in counts]
    y_top = max(10.0, math.ceil((max(y_pct) if y_pct else 0.0) * 1.25))
    y_step = 2.0 if y_top <= 10.0 else base.nice_axis(y_top, 4)[1]
    summary = row["summary"]
    asic = int(row["asic"])
    hd = int(row["header_delay"])
    expected = float(row["expected_center_cycles"])
    peak = summary.get("peak_center_cycles")

    base.draw_page_text(f"ASIC{asic} header-sync hd={hd}", x0 + 80, y0 - ax_h - 48, 18)
    dis.axspos(x0, y0)
    dis.axslen(ax_w, ax_h)
    dis.height(18)
    dis.hname(20)
    dis.labdis(8, "XY")
    dis.namdis(16, "XY")
    dis.name("latency [cycles]", "X")
    dis.name("% / bin", "Y")
    dis.labdig(-1, "X")
    dis.labdig(1, "Y")
    dis.ticks(1, "XY")
    dis.graf(0.0, 1024.0, 0.0, 256.0, 0.0, y_top, 0.0, y_step)
    dis.grid(1, 1)

    dis.barwth(0.65)
    dis.color("blue")
    dis.bars(centers, [0.0] * len(centers), y_pct, len(centers))

    dis.linwid(3)
    dis.color("green")
    dis.curve([0.0, 0.0], [0.0, y_top], 2)
    dis.curve([1000.0, 1000.0], [0.0, y_top], 2)
    dis.color("red")
    dis.curve([expected, expected], [0.0, y_top], 2)
    if peak is not None:
        dis.color("fore")
        dis.curve([float(peak), float(peak)], [0.0, y_top], 2)
    dis.linwid(1)
    dis.color("fore")

    peak_text = "None" if peak is None else f"{float(peak):.0f}"
    width = summary.get("p05_p95_width_cycles")
    width_text = "None" if width is None else f"{float(width):.0f}"
    base.draw_page_text(
        f"total={summary.get('total', 0)} peak={peak_text} exp={expected:.0f}",
        x0,
        y0 + 96,
        16,
    )
    base.draw_page_text(
        f"nz={summary.get('nonzero_bins', 0)}/256 p05-p95={width_text} cyc",
        x0,
        y0 + 124,
        16,
    )
    dis.endgrf()


def render_hsync_contact(rows: list[dict[str, Any]], output: Path, device: str) -> None:
    base.init_page(output, device, wide=True)
    base.draw_center_text(
        "FEB SciFi v4 - per-ASIC header-sync PLL-lock check [0,1000] (real MuTRiG)",
        72,
        30,
    )
    base.draw_center_text("blue = measured, red = 910-header_delay, black = peak, green = [0,1000]", 122, 18)
    for idx, row in enumerate(rows[:8]):
        draw_hsync_panel(row, idx)
    dis.disfin()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rate-json", type=Path)
    parser.add_argument("--periodic-delay-json", type=Path)
    parser.add_argument("--headersync-delay-json", type=Path)
    parser.add_argument("--hsync-dir", type=Path)
    parser.add_argument("--hsync-header-delay", type=int, default=300)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    products: list[Path] = []

    if args.rate_json:
        png = args.out_dir / "real_mutrig_type0_type1_rate_histograms_dislin.png"
        pdf = args.out_dir / "real_mutrig_type0_type1_rate_histograms_dislin.pdf"
        base.render_rate_contact(args.rate_json, png, "PNG")
        base.render_rate_contact(args.rate_json, pdf, "PDF")
        products.extend([png, pdf])

    if args.periodic_delay_json:
        png = args.out_dir / "real_mutrig_type1_periodic_delay_plateau_dislin.png"
        pdf = args.out_dir / "real_mutrig_type1_periodic_delay_plateau_dislin.pdf"
        render_periodic_delay_contact(args.periodic_delay_json, png, "PNG")
        render_periodic_delay_contact(args.periodic_delay_json, pdf, "PDF")
        products.extend([png, pdf])

    if args.headersync_delay_json:
        png = args.out_dir / "real_mutrig_header_sync_delay_asic1_hch1_dislin.png"
        pdf = args.out_dir / "real_mutrig_header_sync_delay_asic1_hch1_dislin.pdf"
        render_headersync_delay_contact(args.headersync_delay_json, png, "PNG")
        render_headersync_delay_contact(args.headersync_delay_json, pdf, "PDF")
        products.extend([png, pdf])

    if args.hsync_dir:
        rows = load_hsync_rows(args.hsync_dir, args.hsync_header_delay)
        json_path, csv_path = write_hsync_summary_files(rows, args.out_dir)
        png = args.out_dir / f"real_mutrig_header_sync_pll_lock_asic8_hd{args.hsync_header_delay:04d}_dislin.png"
        pdf = args.out_dir / f"real_mutrig_header_sync_pll_lock_asic8_hd{args.hsync_header_delay:04d}_dislin.pdf"
        render_hsync_contact(rows, png, "PNG")
        render_hsync_contact(rows, pdf, "PDF")
        products.extend([json_path, csv_path, png, pdf])

    for path in products:
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
