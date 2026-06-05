#!/usr/bin/env python3
"""Render requested DISLIN-style Type1-delay and Type0/Type1-rate plots."""

from __future__ import annotations

import argparse
import json
import math
import sys
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
DISLIN_PYTHON = Path("/home/yifeng/packages/lib/dislin/python3")
if str(DISLIN_PYTHON) not in sys.path:
    sys.path.insert(0, str(DISLIN_PYTHON))

import dislin as dis  # noqa: E402


def nice_step(value: float) -> float:
    if value <= 0:
        return 1.0
    exponent = math.floor(math.log10(value))
    frac = value / (10 ** exponent)
    if frac <= 1:
        nice = 1
    elif frac <= 2:
        nice = 2
    elif frac <= 5:
        nice = 5
    else:
        nice = 10
    return nice * (10 ** exponent)


def nice_axis(max_value: float, target_ticks: int = 5) -> tuple[float, float]:
    if max_value <= 0:
        return 1.0, 0.2
    step = nice_step(max_value / target_ticks)
    top = math.ceil(max_value / step) * step
    return top, step


def init_page(output: Path, device: str, wide: bool = True) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    dis.metafl(device.upper())
    dis.setfil(str(output))
    if device.upper() == "PNG":
        if wide:
            dis.winsiz(1700, 1150)
        else:
            dis.winsiz(1035, 475)
    dis.setpag("DA4L")
    dis.scrmod("REVERS")
    dis.disini()
    dis.pagera()
    dis.complx()
    dis.hname(24)
    dis.labdis(12, "XY")
    dis.namdis(22, "XY")


def draw_page_text(text: str, x: int, y: int, height: int = 28, color: str = "fore") -> None:
    dis.height(height)
    dis.color(color)
    dis.messag(text, x, y)
    dis.color("fore")


def draw_center_text(text: str, y: int, height: int = 40) -> None:
    dis.height(height)
    width = dis.nlmess(text)
    dis.messag(text, max(0, (2970 - width) // 2), y)


def draw_delay_panel(row: dict[str, Any], idx: int) -> None:
    positions = [
        (265, 780),
        (1660, 780),
        (265, 1785),
        (1660, 1785),
    ]
    x0, y0 = positions[idx]
    ax_w, ax_h = 1000, 440
    centers = [float(v) for v in row["centers_cycles"]]
    counts = [float(v) for v in row["counts"]]
    total = sum(counts)
    y_pct = [0.0 if total <= 0 else 100.0 * value / total for value in counts]
    y_top = max(10.0, math.ceil((max(y_pct) if y_pct else 0.0) * 1.3))
    if y_top < 10.0:
        y_top = 10.0
    y_step = 2.0 if y_top <= 10.0 else nice_axis(y_top, 5)[1]

    summary = row["summary"]
    peak_center = summary.get("peak_center_cycles")
    requested = int(row["requested_hz"])
    measured = summary.get("measured_hz", 0.0)
    if measured >= 1_000_000:
        measured_text = f"meas {measured / 1_000_000:.2g} M/s"
    elif measured >= 1000:
        measured_text = f"meas {measured / 1000:.0f} k/s"
    else:
        measured_text = f"meas {measured:.0f} /s"

    rate_title = (
        f"~{requested // 1000}k/s" if requested < 1_000_000
        else f"~{requested // 1_000_000}M/s"
    )

    draw_page_text(f"ASIC0 (UP) delay - periodic {rate_title}", x0 + 295, y0 - ax_h - 78, 18)
    draw_page_text(
        f"{measured_text}   signed delay [cyc]   green = rbCAM (0,2000)",
        x0 + 210, y0 - ax_h - 38, 20,
    )

    dis.axspos(x0, y0)
    dis.axslen(ax_w, ax_h)
    dis.height(22)
    dis.hname(24)
    dis.labdis(10, "XY")
    dis.namdis(18, "XY")
    dis.name("signed hit latency bin center [cycles]", "X")
    dis.name("hits / bin [% of captured interval]", "Y")
    dis.labdig(-1, "X")
    dis.labdig(1, "Y")
    dis.ticks(1, "XY")
    dis.graf(-1000.0, 3096.0, -1000.0, 512.0, 0.0, y_top, 0.0, y_step)
    dis.grid(1, 1)

    dis.barwth(0.65)
    dis.color("blue")
    dis.bars(centers, [0.0] * len(centers), y_pct, len(centers))

    dis.linwid(3)
    dis.color("green")
    dis.curve([0.0, 0.0], [0.0, y_top], 2)
    dis.curve([2000.0, 2000.0], [0.0, y_top], 2)
    if peak_center is not None:
        dis.color("fore")
        dis.curve([float(peak_center), float(peak_center)], [0.0, y_top], 2)
    dis.linwid(1)
    dis.color("fore")

    total_i = int(summary["total"])
    peak_bin = summary.get("peak_bin")
    peak_frac = 100.0 * float(summary.get("peak_fraction", 0.0))
    in_count = int(summary.get("rbcam_window_count", 0))
    in_frac = 100.0 * float(summary.get("rbcam_window_fraction", 0.0))
    out_count = total_i - in_count
    out_frac = 0.0 if total_i <= 0 else max(0.0, 100.0 - in_frac)

    draw_page_text(
        f"total={total_i} hits, nonzero={summary['nonzero_bins']}/256, "
        f"peak bin={peak_bin} at {float(peak_center or 0):.1f} cycles, "
        f"peak fraction={peak_frac:.3f}%",
        x0,
        y0 + 125,
        18,
    )
    draw_page_text(
        f"black=peak {float(peak_center or 0):.1f} cycles; "
        f"green=rbCAM window edges 0 and 2000 cycles",
        x0,
        y0 + 158,
        18,
    )
    draw_page_text(
        f"rbCAM [0,2000]: in={in_count} ({in_frac:.6f}%), "
        f"out={out_count} ({out_frac:.6f}%)",
        x0,
        y0 + 191,
        18,
    )
    dis.endgrf()


def render_delay_contact(delay_json: Path, output: Path, device: str) -> None:
    data = json.loads(delay_json.read_text())
    rows = data["rows"]
    init_page(output, device, wide=True)
    draw_center_text(
        "FEB SciFi v4 - ASIC0 (UP bank) Type1 rbCAM ingress delay vs periodic rate (real MuTRiG)",
        92,
        30,
    )
    for idx, row in enumerate(rows[:4]):
        draw_delay_panel(row, idx)
    dis.disfin()


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
    x = [float(i) for i in range(len(counts))]
    expected = float(row["requested_hz"])
    y_limit = max(max(counts) if counts else 0.0, expected) * 1.12
    y_top, y_step = nice_axis(y_limit, 4)
    path_name = "Type0" if key == "type0_counts" else "Type1 combined"

    draw_page_text(
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
    dis.barwth(0.8)
    dis.color("blue")
    dis.bars(x, [0.0] * len(x), counts, len(x))
    dis.linwid(4)
    dis.color("red")
    dis.curve([0.0, 256.0], [expected, expected], 2)
    dis.linwid(1)
    dis.color("fore")
    dis.endgrf()


def render_rate_contact(rate_json: Path, output: Path, device: str) -> None:
    data = json.loads(rate_json.read_text())
    rows = data["rows"]
    init_page(output, device, wide=True)
    draw_center_text("Histogram readout counts, Type0/Type1 rate scan, 256 bins", 72, 30)
    idx = 0
    for row in rows:
        draw_rate_panel(row, "type0_counts", idx)
        idx += 1
        draw_rate_panel(row, "type1_counts", idx)
        idx += 1
    dis.disfin()


def render_single_rate(row: dict[str, Any], key: str, output: Path, device: str) -> None:
    counts = [float(v) for v in row[key]]
    x = [float(i) for i in range(len(counts))]
    expected = float(row["requested_hz"])
    y_limit = max(max(counts) if counts else 0.0, expected) * 1.12
    y_top, y_step = nice_axis(y_limit, 4)
    path_name = "Type0" if key == "type0_counts" else "Type1 combined"
    init_page(output, device, wide=False)
    draw_center_text(
        f"Histogram readout counts, {path_name}, {row['requested_hz']:.0f} Hz, 256 bins",
        80,
        34,
    )
    dis.axspos(420, 1510)
    dis.axslen(2160, 870)
    dis.height(30)
    dis.hname(36)
    dis.labdis(20, "XY")
    dis.namdis(30, "XY")
    dis.name("histogram channel [0,255]", "X")
    dis.name("count per frozen bank", "Y")
    dis.labdig(-1, "X")
    dis.labdig(-1, "Y")
    dis.ticks(4, "X")
    dis.ticks(2, "Y")
    dis.graf(0.0, 256.0, 0.0, 32.0, 0.0, y_top, 0.0, y_step)
    dis.grid(1, 1)
    dis.barwth(0.8)
    dis.color("blue")
    dis.bars(x, [0.0] * len(x), counts, len(x))
    dis.linwid(4)
    dis.color("red")
    dis.curve([0.0, 256.0], [expected, expected], 2)
    dis.linwid(1)
    dis.color("fore")
    dis.disfin()


def render_rate_singles(rate_json: Path, out_dir: Path) -> list[Path]:
    data = json.loads(rate_json.read_text())
    outputs: list[Path] = []
    for row in data["rows"]:
        hz = int(round(float(row["requested_hz"])))
        for key, suffix in (("type0_counts", "type0"), ("type1_counts", "type1")):
            png = out_dir / f"real_mutrig_{suffix}_rate_hist_{hz}hz_dislin.png"
            pdf = out_dir / f"real_mutrig_{suffix}_rate_hist_{hz}hz_dislin.pdf"
            render_single_rate(row, key, png, "PNG")
            render_single_rate(row, key, pdf, "PDF")
            outputs.extend([png, pdf])
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--delay-json", type=Path, default=SCRIPT_DIR / "real_mutrig_type1_delay_scan.json")
    parser.add_argument(
        "--rate-json",
        type=Path,
        default=SCRIPT_DIR.parent / "type0_type1_scan_20260604_151520" / "real_mutrig_type0_type1_scan.json",
    )
    parser.add_argument("--out-dir", type=Path, default=SCRIPT_DIR)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    products = [
        args.out_dir / "real_mutrig_type1_delay_asic0_up_4panel_dislin.png",
        args.out_dir / "real_mutrig_type1_delay_asic0_up_4panel_dislin.pdf",
        args.out_dir / "real_mutrig_type0_type1_rate_histograms_dislin.png",
        args.out_dir / "real_mutrig_type0_type1_rate_histograms_dislin.pdf",
    ]
    render_delay_contact(args.delay_json, products[0], "PNG")
    render_delay_contact(args.delay_json, products[1], "PDF")
    render_rate_contact(args.rate_json, products[2], "PNG")
    render_rate_contact(args.rate_json, products[3], "PDF")
    products.extend(render_rate_singles(args.rate_json, args.out_dir))

    for path in products:
        print(f"wrote {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
