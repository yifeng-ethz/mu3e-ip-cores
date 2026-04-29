#!/usr/bin/env python3
"""Show or capture a System-Console-style histogram matrix readout."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path
from tkinter import Canvas, Tk


STATUS_FILL = {
    "PASS": "#dff5e6",
    "PASS_PARTIAL": "#fff1cc",
    "FAIL": "#ffd9d9",
    "BLOCKED": "#e8e8e8",
}
STATUS_TEXT = {
    "PASS": "#146c2e",
    "PASS_PARTIAL": "#8a5a00",
    "FAIL": "#9b1c1c",
    "BLOCKED": "#4d4d4d",
}


def fmt_hex(value: int) -> str:
    return f"0x{value:02X}"


def scenario_names(payload: dict) -> list[str]:
    names = []
    for rec in payload.get("records", []):
        name = rec.get("scenario", "")
        if name and name not in names:
            names.append(name)
    return names


def rec_summary(rec: dict) -> dict:
    return rec.get("summary", {})


def draw_scenario(payload: dict, scenario: str, screenshot_path: Path | None = None) -> None:
    records = [rec for rec in payload.get("records", []) if rec.get("scenario") == scenario]
    root = Tk()
    root.title(f"System Console - Phase 5 Histogram Matrix - {scenario}")
    root.geometry("1740x1040+80+60")
    root.configure(bg="#f4f6f8")
    canvas = Canvas(root, width=1740, height=1040, bg="#f4f6f8", highlightthickness=0)
    canvas.pack(fill="both", expand=True)

    x0 = 24
    y = 22
    canvas.create_text(
        x0,
        y,
        anchor="nw",
        text="System Console - Phase 5 Histogram Statistics Reading",
        font=("DejaVu Sans", 22, "bold"),
        fill="#17202a",
    )
    y += 38
    counts = {status: sum(1 for rec in records if rec.get("status") == status) for status in STATUS_FILL}
    subtitle = (
        f"scenario={scenario}  timestamp={payload.get('timestamp', '-')}  "
        f"link={payload.get('args', {}).get('link', '-')}  enable-mask=0x00000004  "
        f"PASS={counts['PASS']} PARTIAL={counts['PASS_PARTIAL']} FAIL={counts['FAIL']} BLOCKED={counts['BLOCKED']}"
    )
    canvas.create_text(x0, y, anchor="nw", text=subtitle, font=("DejaVu Sans", 11), fill="#2f3b45")
    y += 24
    canvas.create_text(
        x0,
        y,
        anchor="nw",
        text=f"firmware={payload.get('firmware_note', '-')}",
        font=("DejaVu Sans Mono", 10),
        fill="#4a5560",
    )
    y += 34

    columns = [
        ("#", 44),
        ("source", 96),
        ("scope", 74),
        ("req", 68),
        ("emu", 68),
        ("real/LVDS", 86),
        ("hist", 106),
        ("drop", 70),
        ("mts", 106),
        ("discard", 82),
        ("crc", 62),
        ("inerr", 70),
        ("status", 120),
        ("classification / note", 600),
    ]
    row_h = 30
    header_h = 34
    table_w = sum(width for _, width in columns)
    canvas.create_rectangle(x0, y, x0 + table_w, y + header_h, fill="#26323f", outline="#26323f")
    x = x0
    for label, width in columns:
        canvas.create_text(x + 8, y + 9, anchor="nw", text=label, font=("DejaVu Sans", 10, "bold"), fill="#ffffff")
        x += width
        canvas.create_line(x, y, x, y + header_h, fill="#3b4652")
    y += header_h

    for row, rec in enumerate(records):
        summary = rec_summary(rec)
        status = rec.get("status", "FAIL")
        fill = STATUS_FILL.get(status, "#ffd9d9")
        base_fill = "#ffffff" if row % 2 == 0 else "#f9fbfc"
        canvas.create_rectangle(x0, y, x0 + table_w, y + row_h, fill=base_fill, outline="#d4dbe2")
        canvas.create_rectangle(x0 + table_w - columns[-1][1] - columns[-2][1], y, x0 + table_w, y + row_h, fill=fill, outline="#d4dbe2")
        classification = summary.get("phase5_classification", "")
        note = rec.get("block_reason") or rec.get("partial_reason") or rec.get("error") or classification
        values = [
            str(rec.get("matrix_index", "")),
            rec.get("source", ""),
            rec.get("scope", ""),
            fmt_hex(rec.get("requested_lanes_mask", 0)),
            fmt_hex(rec.get("effective_emulator_mask", 0)),
            fmt_hex(rec.get("effective_lvds_mask", 0)),
            str(summary.get("hist_total_delta", 0)),
            str(summary.get("hist_drop_delta", 0)),
            str(summary.get("mts_total_delta", 0)),
            str(summary.get("mts_discard_delta", 0)),
            str(summary.get("frame_crc_delta", 0)),
            str(summary.get("ring_inerr_delta", 0)),
            status,
            str(note)[:92],
        ]
        x = x0
        for (label, width), value in zip(columns, values):
            font = ("DejaVu Sans Mono", 9) if label not in {"source", "scope", "status"} else ("DejaVu Sans", 9, "bold")
            color = STATUS_TEXT.get(status, "#17202a") if label == "status" else "#17202a"
            canvas.create_text(x + 7, y + 7, anchor="nw", text=value, font=font, fill=color)
            x += width
        y += row_h

    y += 18
    note = (
        "Shown counters are read over the SWB System Console slow-control path from histogram_statistics_0 and adjacent "
        "stage CSRs. hist_bin SRAM readout is intentionally excluded here because this firmware/SC path currently returns RSP3 on that aperture."
    )
    canvas.create_text(x0, y, anchor="nw", text=note, font=("DejaVu Sans", 10), fill="#34495e", width=1600)
    canvas.update_idletasks()
    canvas.update()

    if screenshot_path is not None:
        screenshot_path.parent.mkdir(parents=True, exist_ok=True)
        time.sleep(0.3)
        window_id = root.winfo_id()
        proc = subprocess.run(
            ["import", "-window", str(window_id), str(screenshot_path)],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            raise RuntimeError(proc.stdout + proc.stderr)
        root.destroy()
    else:
        root.mainloop()


def main() -> int:
    parser = argparse.ArgumentParser(description="Display or capture Phase-5 histogram matrix readout screenshots.")
    parser.add_argument("json_path", type=Path)
    parser.add_argument("--scenario", default=None)
    parser.add_argument("--all-scenarios", action="store_true")
    parser.add_argument("--screenshot-dir", type=Path, default=None)
    args = parser.parse_args()

    payload = json.loads(args.json_path.read_text(encoding="utf-8"))
    names = scenario_names(payload)
    if args.all_scenarios:
        selected = names
    elif args.scenario:
        selected = [args.scenario]
    else:
        selected = [names[0]]

    for scenario in selected:
        if scenario not in names:
            raise SystemExit(f"scenario {scenario!r} not found in {args.json_path}")
        out = None
        if args.screenshot_dir is not None:
            out = args.screenshot_dir / f"{args.json_path.stem}_{scenario}.png"
        draw_scenario(payload, scenario, out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
