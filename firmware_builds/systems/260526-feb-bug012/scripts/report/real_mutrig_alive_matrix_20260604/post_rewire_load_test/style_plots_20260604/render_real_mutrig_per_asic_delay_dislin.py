#!/usr/bin/env python3
"""Render real-MuTRiG rate and per-ASIC delay sheets with filled bins."""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import render_requested_style_plots_dislin as base  # noqa: E402

dis = base.dis

DELAY_X_MIN = -1024.0
DELAY_X_MAX = 3096.0
DELAY_X_STEP = 512.0
OFFSET_COLORS = ("blue", "red", "green")


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


def step_curve_xy(centers: list[float], values: list[float], bin_width: float) -> tuple[list[float], list[float]]:
    if not centers:
        return [], []
    xs: list[float] = []
    ys: list[float] = []
    half = bin_width / 2.0
    for center, value in zip(centers, values):
        xs.extend([center - half, center + half])
        ys.extend([value, value])
    return xs, ys


def draw_filled_histogram(
    centers: list[float],
    values: list[float],
    bin_width: float,
    color: str = "blue",
) -> None:
    xs, ys = step_curve_xy(centers, values, bin_width)
    if not xs:
        return
    zeros = [0.0] * len(xs)
    dis.color(color)
    dis.shdpat(16)
    dis.shdcrv(xs, ys, len(xs), xs, zeros, len(xs))
    dis.linwid(1)
    dis.curve(xs, ys, len(xs))
    dis.color("fore")


def delay_axis(values: list[float]) -> tuple[float, float]:
    peak = max(values) if values else 0.0
    if peak <= 0.0:
        return 1.0, 0.2
    y_top, y_step = base.nice_axis(peak * 1.22, 4)
    return max(y_top, 0.5), y_step


def draw_rate_panel(row: dict[str, Any], key: str, idx: int) -> None:
    positions = [
        (310, 540),
        (1650, 540),
        (310, 1210),
        (1650, 1210),
        (310, 1880),
        (1650, 1880),
    ]
    x0, y0 = positions[idx]
    ax_w, ax_h = 1040, 360
    counts = [float(v) for v in row[key]]
    centers = [float(i) + 0.5 for i in range(len(counts))]
    expected = float(row["requested_hz"])
    y_limit = max(max(counts) if counts else 0.0, expected) * 1.12
    y_top, y_step = base.nice_axis(y_limit, 4)
    path_name = "Type0" if key == "type0_counts" else "Type1 combined"

    base.draw_page_text(
        f"{path_name}, requested {row['requested_hz']:.0f} Hz, interval {row['interval']}",
        x0 + 170,
        y0 - ax_h - 38,
        22,
    )
    dis.axspos(x0, y0)
    dis.axslen(ax_w, ax_h)
    dis.height(20)
    dis.hname(24)
    dis.labdis(10, "XY")
    dis.namdis(18, "XY")
    dis.name("histogram channel [0,255]", "X")
    dis.name("count per frozen bank", "Y")
    dis.labdig(-1, "X")
    dis.labdig(-1, "Y")
    dis.ticks(4, "X")
    dis.ticks(2, "Y")
    dis.graf(0.0, 256.0, 0.0, 32.0, 0.0, y_top, 0.0, y_step)
    dis.grid(1, 1)
    draw_filled_histogram(centers, counts, 1.0)
    dis.linwid(4)
    dis.color("red")
    dis.curve([0.0, 256.0], [expected, expected], 2)
    dis.linwid(1)
    dis.color("fore")
    dis.endgrf()


def render_rate_contact(rate_json: Path, output: Path, device: str) -> None:
    data = json.loads(rate_json.read_text())
    rows = data["rows"]
    base.init_page(output, device, wide=True)
    base.draw_center_text("Histogram readout counts, Type0/Type1 rate scan, 256 bins", 72, 30)
    idx = 0
    for row in rows[:3]:
        draw_rate_panel(row, "type0_counts", idx)
        idx += 1
        draw_rate_panel(row, "type1_counts", idx)
        idx += 1
    dis.disfin()


def panel_position(idx: int) -> tuple[int, int]:
    col = idx % 4
    row = idx // 4
    return 155 + col * 710, 710 + row * 930


def draw_delay_panel(row: dict[str, Any], idx: int, mode: str) -> None:
    x0, y0 = panel_position(idx)
    ax_w, ax_h = 560, 300
    counts = [float(v) for v in row["counts"]]
    total = sum(counts)
    y_pct = [0.0 if total <= 0 else 100.0 * value / total for value in counts]
    left = int(row.get("left", 0))
    bin_width = int(row.get("bin_width", 4))
    centers = [float(left + i * bin_width + bin_width // 2) for i in range(len(counts))]
    y_top, y_step = delay_axis(y_pct)
    summary = row["summary"]
    asic = int(row["asic"])
    peak = summary.get("peak_center_cycles")
    title_mode = "periodic 100k/ch" if mode == "periodic" else "header-sync 1/frame"

    base.draw_page_text(f"ASIC{asic} {title_mode}", x0 + 72, y0 - ax_h - 48, 18)
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
    dis.graf(DELAY_X_MIN, DELAY_X_MAX, DELAY_X_MIN, DELAY_X_STEP, 0.0, y_top, 0.0, y_step)
    dis.grid(1, 1)
    draw_filled_histogram(centers, y_pct, float(bin_width))

    dis.linwid(3)
    dis.color("green")
    dis.curve([0.0, 0.0], [0.0, y_top], 2)
    dis.curve([1000.0, 1000.0], [0.0, y_top], 2)
    if mode == "headersync":
        expected = float(row.get("expected_center_cycles", 910 - int(row.get("header_delay", 300))))
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
    in_frac = 100.0 * float(summary.get("window_fraction_0_1000", 0.0))
    base.draw_page_text(
        f"total={summary.get('total', 0)} peak={peak_text} nz={summary.get('nonzero_bins', 0)}/256",
        x0,
        y0 + 96,
        16,
    )
    base.draw_page_text(
        f"p05-p95={width_text} cyc  in[0,1000]={in_frac:.3f}%",
        x0,
        y0 + 124,
        16,
    )
    dis.endgrf()


def delay_pct(row: dict[str, Any]) -> tuple[list[float], list[float]]:
    counts = [float(v) for v in row["counts"]]
    total = sum(counts)
    left = int(row.get("left", 0))
    bin_width = int(row.get("bin_width", 4))
    centers = [float(left + i * bin_width + bin_width // 2) for i in range(len(counts))]
    y_pct = [0.0 if total <= 0 else 100.0 * value / total for value in counts]
    return centers, y_pct


def rows_by_asic_and_delay(data: dict[str, Any]) -> dict[int, list[dict[str, Any]]]:
    grouped: dict[int, list[dict[str, Any]]] = {}
    for row in data["rows"]:
        if row.get("mode") != "headersync":
            continue
        item = dict(row)
        item["left"] = data.get("left", 0)
        item["bin_width"] = data.get("bin_width", 4)
        item["expected_center_cycles"] = 910 - int(
            item.get("header_delay", data.get("args", {}).get("header_delay", 300))
        )
        grouped.setdefault(int(item["asic"]), []).append(item)
    for rows in grouped.values():
        rows.sort(key=lambda item: int(item.get("header_delay", 0)))
    return grouped


def draw_delay_offset_panel(rows: list[dict[str, Any]], idx: int) -> None:
    x0, y0 = panel_position(idx)
    ax_w, ax_h = 560, 300
    asic = int(rows[0]["asic"]) if rows else idx
    curves = [delay_pct(row) for row in rows]
    all_y = [value for _, y_pct in curves for value in y_pct]
    y_top, y_step = delay_axis(all_y)

    base.draw_page_text(f"ASIC{asic} header-sync offsets", x0 + 45, y0 - ax_h - 56, 18)
    for lidx, row in enumerate(rows[:3]):
        color = OFFSET_COLORS[lidx % len(OFFSET_COLORS)]
        hd = int(row.get("header_delay", 0))
        expected = int(row.get("expected_center_cycles", 910 - hd))
        base.draw_page_text(f"hd={hd} exp={expected}", x0 + 8 + lidx * 178, y0 - ax_h - 27, 15, color)

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
    dis.graf(DELAY_X_MIN, DELAY_X_MAX, DELAY_X_MIN, DELAY_X_STEP, 0.0, y_top, 0.0, y_step)
    dis.grid(1, 1)

    dis.linwid(2)
    for lidx, (row, (centers, y_pct)) in enumerate(zip(rows[:3], curves[:3])):
        color = OFFSET_COLORS[lidx % len(OFFSET_COLORS)]
        xs, ys = step_curve_xy(centers, y_pct, float(row.get("bin_width", 4)))
        dis.color(color)
        if xs:
            dis.curve(xs, ys, len(xs))
        expected = float(row.get("expected_center_cycles", 910 - int(row.get("header_delay", 0))))
        dis.curve([expected, expected], [0.0, y_top], 2)

    dis.linwid(3)
    dis.color("green")
    dis.curve([0.0, 0.0], [0.0, y_top], 2)
    dis.curve([1000.0, 1000.0], [0.0, y_top], 2)
    dis.linwid(1)
    dis.color("fore")

    summaries = []
    for row in rows[:3]:
        s = row["summary"]
        peak = s.get("peak_center_cycles")
        width = s.get("p05_p95_width_cycles")
        peak_text = "None" if peak is None else f"{float(peak):.0f}"
        width_text = "None" if width is None else f"{float(width):.0f}"
        summaries.append(f"hd{row.get('header_delay')}:pk{peak_text}/w{width_text}")
    base.draw_page_text("  ".join(summaries), x0, y0 + 96, 14)
    dis.endgrf()


def delay_rows(data: dict[str, Any], mode: str) -> list[dict[str, Any]]:
    rows = []
    for row in data["rows"]:
        if row.get("mode") != mode:
            continue
        row = dict(row)
        row["left"] = data.get("left", 0)
        row["bin_width"] = data.get("bin_width", 4)
        row["expected_center_cycles"] = 910 - int(row.get("header_delay", data.get("args", {}).get("header_delay", 300)))
        rows.append(row)
    return sorted(rows, key=lambda item: int(item["asic"]))


def render_delay_contact(delay_json: Path, output: Path, device: str, mode: str) -> None:
    data = json.loads(delay_json.read_text())
    rows = delay_rows(data, mode)
    base.init_page(output, device, wide=True)
    if mode == "periodic":
        base.draw_center_text(
            "FEB SciFi v4 - per-ASIC Type1 delay, periodic 100 kHz per channel (real MuTRiG)",
            72,
            28,
        )
        base.draw_center_text("blue = filled measured bins, black = peak, green = expected plateau [0,1000]", 122, 18)
    else:
        base.draw_center_text(
            "FEB SciFi v4 - per-ASIC Type1 delay, header-sync 1 pulse per frame (real MuTRiG)",
            72,
            28,
        )
        base.draw_center_text(
            "blue = filled measured bins, red = 910-header_delay, black = peak, green = [0,1000]",
            122,
            18,
        )
    for idx, row in enumerate(rows[:8]):
        draw_delay_panel(row, idx, mode)
    dis.disfin()


def render_delay_offsets(offset_delay_json: Path, output: Path, device: str) -> None:
    data = json.loads(offset_delay_json.read_text())
    grouped = rows_by_asic_and_delay(data)
    base.init_page(output, device, wide=True)
    base.draw_center_text(
        "FEB SciFi v4 - per-ASIC Type1 header-sync delay, three offsets (real MuTRiG)",
        72,
        28,
    )
    base.draw_center_text(
        "colored curves/lines = header_delay offsets, green = [0,1000], x range [-1024,3096]",
        122,
        18,
    )
    for idx, asic in enumerate(range(8)):
        rows = grouped.get(asic, [])
        if rows:
            draw_delay_offset_panel(rows, idx)
    dis.disfin()


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--rate-json", type=Path)
    parser.add_argument("--delay-json", type=Path)
    parser.add_argument("--offset-delay-json", type=Path)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    outputs: list[Path] = []
    if args.rate_json:
        for device, suffix in (("PNG", "png"), ("PDF", "pdf")):
            out = args.out_dir / f"real_mutrig_type0_type1_rate_histograms_filled_dislin.{suffix}"
            render_rate_contact(args.rate_json, out, device)
            outputs.append(out)
    if args.delay_json:
        for mode in ("periodic", "headersync"):
            for device, suffix in (("PNG", "png"), ("PDF", "pdf")):
                out = args.out_dir / f"real_mutrig_per_asic_{mode}_delay_filled_dislin.{suffix}"
                render_delay_contact(args.delay_json, out, device, mode)
                outputs.append(out)
    if args.offset_delay_json:
        for device, suffix in (("PNG", "png"), ("PDF", "pdf")):
            out = args.out_dir / f"real_mutrig_per_asic_headersync_offsets_overlay_dislin.{suffix}"
            render_delay_offsets(args.offset_delay_json, out, device)
            outputs.append(out)
    for output in outputs:
        print(f"wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
