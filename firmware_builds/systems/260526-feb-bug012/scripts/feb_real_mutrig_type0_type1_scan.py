#!/usr/bin/env python3
"""Scan Type0/Type1 histograms with the physical MuTRiG as the hit source.

This is the real-MuTRiG counterpart to feb_type0_type1_rate_scan.py:
emulator engines are disabled, merger sources are set to REAL, all frame
receivers are enabled, and the mutrig_injector periodic mode drives the
physical TDC-test injection line. The MuTRiG config bitstream must already
have the desired TDC-test channel mask loaded.
"""

from __future__ import annotations

import argparse
import csv
import json
import statistics
import sys
import time
from pathlib import Path

import feb_hist_read as fh


MERGER_BASE = 0x08840
MERGER_STRIDE = 8
MERGER_SOURCE_SEL = 3
MERGER_REAL = 0

INJ = 0x06C80
I_MODE = 2
I_HDELAY = 3
I_HINTERVAL = 4
I_MULT = 5
I_HCH = 6
I_PINT = 7
I_PHIGH = 8

FRAME_RCV = [
    0x04428, 0x04628, 0x04A28, 0x04E28,
    0x05228, 0x05628, 0x05A28, 0x05E28,
]

CTRL_TYPE0 = (0 << 16) | (0 << 2) | (1 << 8) | 1
CTRL_TYPE1_UP = (1 << 16) | (1 << 2) | (1 << 8) | 1
CTRL_TYPE1_DOWN = (2 << 16) | (2 << 2) | (1 << 8) | 1

N_BINS = 256
N_ASICS = 8
N_CH = 32
DEFAULT_INTERVALS = (50000, 12500, 5000)


def wr_verify(link: str, addr: int, value: int, mask: int = 0xFFFFFFFF,
              tries: int = 6, label: str = "") -> bool:
    want = value & mask
    last = None
    for _ in range(tries):
        fh.wr(link, addr, value)
        time.sleep(0.03)
        last = fh.rd(link, addr)
        if last is not None and (last & mask) == want:
            return True
    print(
        f"# WARNING: verify failed {label} addr={addr:#x} "
        f"write={value:#x} read={last!r}",
        file=sys.stderr,
    )
    return False


def set_real_path(link: str) -> None:
    wr_verify(link, fh.EMU + fh.E_CENTRAL, 0, 0x1, label="EMU.CENTRAL")
    wr_verify(link, fh.EMU + fh.E_BACKGROUND, 0, 0x1, label="EMU.BACKGROUND")
    wr_verify(link, fh.EMU + fh.E_SIGNAL, 0, 0x7, label="EMU.SIGNAL")
    wr_verify(link, INJ + I_MODE, 0, 0xF, label="INJ.MODE")
    for lane in range(N_ASICS):
        addr = MERGER_BASE + lane * MERGER_STRIDE + MERGER_SOURCE_SEL
        wr_verify(link, addr, MERGER_REAL, 0x1, label=f"merger{lane}.source_sel")
    for base in FRAME_RCV:
        wr_verify(link, base, 1, 0x1, label=f"frame_rcv@{base:#x}.control")


def start_run(link: str, attempts: int) -> bool:
    for attempt in range(1, attempts + 1):
        for opcode, delay_s in (
            (0x13, 0.15),
            (0x110, 0.25),
            (0x11, 0.20),
            (0x12, 0.30),
        ):
            fh.wr(link, fh.RUNCTL + fh.R_LOCAL_CMD, opcode)
            time.sleep(delay_s)
        status = fh.rd(link, fh.RUNCTL + fh.R_STATUS)
        last_cmd = fh.rd(link, fh.RUNCTL + fh.R_LOCAL_CMD)
        status_ok = status is not None and ((status & 0x3) == 0x3 or (status & 0x2) == 0x2)
        cmd_ok = last_cmd is not None and (last_cmd & 0xFF) == 0x12
        if status_ok and cmd_ok:
            return True
        print(
            f"# WARNING: RUNCTL start attempt {attempt} did not settle: "
            f"STATUS={status if status is None else f'{status:#010x}'} "
            f"LAST_CMD={last_cmd if last_cmd is None else f'{last_cmd:#010x}'}",
            file=sys.stderr,
        )
    return False


def terminate_run(link: str) -> None:
    fh.wr(link, INJ + I_MODE, 0)
    time.sleep(0.05)
    fh.wr(link, fh.RUNCTL + fh.R_LOCAL_CMD, 0x13)
    time.sleep(0.20)


def configure_periodic_injector(
    link: str,
    interval: int,
    pulse_high: int,
    multiplicity: int,
    header_delay: int,
    header_ch: int,
) -> None:
    wr_verify(link, INJ + I_MODE, 0, 0xF, label="INJ.MODE")
    wr_verify(link, INJ + I_HCH, header_ch, 0xFF, label="INJ.HEADER_CH")
    wr_verify(link, INJ + I_HDELAY, header_delay, label="INJ.HEADER_DELAY")
    wr_verify(link, INJ + I_HINTERVAL, 1, label="INJ.HEADER_INTERVAL")
    wr_verify(link, INJ + I_MULT, multiplicity, label="INJ.MULT")
    wr_verify(link, INJ + I_PINT, interval, label="INJ.PULSE_INTERVAL")
    wr_verify(link, INJ + I_PHIGH, pulse_high, 0xFF, label="INJ.PULSE_HIGH")


def enable_periodic_injector(link: str) -> None:
    wr_verify(link, INJ + I_MODE, 2, 0xF, label="INJ.MODE")


def frame_snapshot(link: str) -> list[dict[str, int | None]]:
    rows = []
    for asic, base in enumerate(FRAME_RCV):
        word0 = fh.rd(link, base)
        crc = fh.rd(link, base + 1)
        frame_cnt = fh.rd(link, base + 2)
        rows.append({
            "asic": asic,
            "word0": word0,
            "status": None if word0 is None else ((word0 >> 24) & 0xFF),
            "control": None if word0 is None else (word0 & 0xFF),
            "crc": crc,
            "frame_cnt": frame_cnt,
        })
    return rows


def arm_histogram(link: str, ctrl: int) -> None:
    wr_verify(link, fh.HIST_CSR + fh.H_LEFT, 0, label="HIST.LEFT")
    wr_verify(link, fh.HIST_CSR + fh.H_RIGHT, N_BINS, label="HIST.RIGHT")
    wr_verify(link, fh.HIST_CSR + fh.H_BINW, 1, label="HIST.BINW")
    fh.wr(link, fh.HIST_CSR + fh.H_CONTROL, ctrl)
    time.sleep(0.15)


def summarize_counts(counts: dict[int, int]) -> dict[str, float | int | list[int]]:
    values = [counts.get(k, 0) for k in range(N_BINS)]
    nz_bins = [k for k, value in enumerate(values) if value > 0]
    nz_values = [values[k] for k in nz_bins]
    if not nz_values:
        return {
            "occupied_bins": 0,
            "bin_sum": 0,
            "min": 0,
            "mean": 0.0,
            "max": 0,
            "std": 0.0,
            "zero_bins": list(range(N_BINS)),
        }
    return {
        "occupied_bins": len(nz_bins),
        "bin_sum": int(sum(values)),
        "min": int(min(nz_values)),
        "mean": float(statistics.mean(nz_values)),
        "max": int(max(nz_values)),
        "std": float(statistics.pstdev(nz_values)),
        "zero_bins": [k for k, value in enumerate(values) if value == 0],
    }


def merge_type1(up: dict[int, int], down: dict[int, int]) -> dict[int, int]:
    combined = {k: up.get(k, 0) for k in range(N_BINS)}
    down_nz = [k for k in range(N_BINS) if down.get(k, 0) > 0]
    down_is_absolute = bool(down_nz) and min(down_nz) >= 128
    for k in range(N_BINS):
        value = down.get(k, 0)
        if not value:
            continue
        dst = k if down_is_absolute else (k + 128 if k < 128 else k)
        combined[dst] = combined.get(dst, 0) + value
    return combined


def run_hist_window(
    link: str,
    ctrl: int,
    interval: int,
    dwell_s: float,
    attempts: int,
    pulse_high: int,
    multiplicity: int,
    header_delay: int,
    header_ch: int,
) -> tuple[dict[int, int], dict[str, int], list[dict], list[dict]]:
    set_real_path(link)
    configure_periodic_injector(
        link, interval, pulse_high, multiplicity, header_delay, header_ch)
    if not start_run(link, attempts):
        terminate_run(link)
        raise RuntimeError(f"could not enter RUNNING for interval={interval}")
    before = frame_snapshot(link)
    arm_histogram(link, ctrl)
    enable_periodic_injector(link)
    time.sleep(dwell_s)
    counts = fh.read_frozen_bins(link, method="burst")
    stats = {
        "total": fh.rd(link, fh.HIST_CSR + fh.H_TOTAL) or 0,
        "last_interval": fh.rd(link, fh.HIST_CSR + fh.H_LASTINT) or 0,
    }
    after = frame_snapshot(link)
    terminate_run(link)
    return counts, stats, before, after


def parse_intervals(raw: str | None) -> list[int]:
    if not raw:
        return list(DEFAULT_INTERVALS)
    out = []
    for token in raw.split(","):
        token = token.strip()
        if token:
            out.append(int(token, 0))
    return out


def write_channel_csv(rows: list[dict], csv_path: Path) -> None:
    with csv_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(["interval", "requested_hz", "path", "asic", "channel", "bin", "count"])
        for row in rows:
            for path in ("type0_counts", "type1_counts"):
                for bin_idx, count in enumerate(row[path]):
                    writer.writerow([
                        row["interval"],
                        row["requested_hz"],
                        path.replace("_counts", ""),
                        bin_idx >> 5,
                        bin_idx & 31,
                        bin_idx,
                        count,
                    ])


def plot_channel_heatmap(rows: list[dict], key: str, title: str, png_path: Path) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    intervals = [row["interval"] for row in rows]
    matrix = [row[key] for row in rows]
    fig, ax = plt.subplots(figsize=(11.0, 4.6))
    image = ax.imshow(matrix, aspect="auto", interpolation="nearest", cmap="viridis")
    ax.set_title(title)
    ax.set_xlabel("histogram bin = ASIC*32 + channel")
    ax.set_ylabel("pulse_interval")
    ax.set_xticks([0, 32, 64, 96, 128, 160, 192, 224, 255])
    ax.set_yticks(range(len(intervals)))
    ax.set_yticklabels([str(interval) for interval in intervals])
    for boundary in range(32, N_BINS, 32):
        ax.axvline(boundary - 0.5, color="white", linewidth=0.55, alpha=0.8)
    cbar = fig.colorbar(image, ax=ax)
    cbar.set_label("frozen-bin count [hits/interval]")
    fig.tight_layout()
    fig.savefig(png_path, dpi=130)
    plt.close(fig)


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--link", default="2")
    ap.add_argument("--intervals", default=None,
                    help="comma-separated pulse intervals; default: "
                         + ",".join(str(v) for v in DEFAULT_INTERVALS))
    ap.add_argument("--dwell-s", type=float, default=3.0)
    ap.add_argument("--attempts", type=int, default=8)
    ap.add_argument("--pulse-high", type=int, default=5)
    ap.add_argument("--multiplicity", type=int, default=1)
    ap.add_argument("--header-delay", type=int, default=300)
    ap.add_argument("--header-ch", type=int, default=0)
    ap.add_argument("--out-dir", default=None)
    args = ap.parse_args()

    out_dir = Path(args.out_dir or (
        Path(__file__).resolve().parent / "report" / "real_mutrig_scan_20260604"))
    out_dir.mkdir(parents=True, exist_ok=True)

    link = args.link
    intervals = parse_intervals(args.intervals)
    print(f"# feb_real_mutrig_type0_type1_scan link={link} intervals={intervals} dwell_s={args.dwell_s}")
    print(f"# UIDs: EMU={fh.rd(link, fh.EMU)!r} HIST={fh.rd(link, fh.HIST_CSR)!r} "
          f"RUNCTL={fh.rd(link, fh.RUNCTL)!r} INJ={fh.rd(link, INJ)!r}")

    rows = []
    for interval in intervals:
        requested_hz = 125_000_000.0 / interval if interval else 0.0
        type0, type0_stats, type0_before, type0_after = run_hist_window(
            link, CTRL_TYPE0, interval, args.dwell_s, args.attempts,
            args.pulse_high, args.multiplicity, args.header_delay, args.header_ch)
        type1_up, type1_up_stats, type1_up_before, type1_up_after = run_hist_window(
            link, CTRL_TYPE1_UP, interval, args.dwell_s, args.attempts,
            args.pulse_high, args.multiplicity, args.header_delay, args.header_ch)
        type1_down, type1_down_stats, type1_down_before, type1_down_after = run_hist_window(
            link, CTRL_TYPE1_DOWN, interval, args.dwell_s, args.attempts,
            args.pulse_high, args.multiplicity, args.header_delay, args.header_ch)

        combined = merge_type1(type1_up, type1_down)
        row = {
            "interval": interval,
            "requested_hz": requested_hz,
            "type0_stats": type0_stats,
            "type1_up_stats": type1_up_stats,
            "type1_down_stats": type1_down_stats,
            "type0": summarize_counts(type0),
            "type1_up": summarize_counts(type1_up),
            "type1_down": summarize_counts(type1_down),
            "type1_combined": summarize_counts(combined),
            "type0_counts": [type0.get(k, 0) for k in range(N_BINS)],
            "type1_counts": [combined.get(k, 0) for k in range(N_BINS)],
            "frame_snapshots": {
                "type0_before": type0_before,
                "type0_after": type0_after,
                "type1_up_before": type1_up_before,
                "type1_up_after": type1_up_after,
                "type1_down_before": type1_down_before,
                "type1_down_after": type1_down_after,
            },
        }
        rows.append(row)
        print(
            f"# interval={interval} requested={requested_hz:9.1f} Hz "
            f"Type0 occ={row['type0']['occupied_bins']:3d}/256 "
            f"sum={row['type0']['bin_sum']:8d} "
            f"Type1 occ={row['type1_combined']['occupied_bins']:3d}/256 "
            f"sum={row['type1_combined']['bin_sum']:8d} "
            f"UP={row['type1_up']['occupied_bins']:3d} "
            f"DN={row['type1_down']['occupied_bins']:3d}"
        )

    json_path = out_dir / "real_mutrig_type0_type1_scan.json"
    summary_csv_path = out_dir / "real_mutrig_type0_type1_scan_summary.csv"
    channel_csv_path = out_dir / "real_mutrig_type0_type1_scan_channels.csv"
    type0_heatmap_path = out_dir / "real_mutrig_type0_channel_heatmap.png"
    type1_heatmap_path = out_dir / "real_mutrig_type1_channel_heatmap.png"

    with json_path.open("w") as f:
        json.dump({"rows": rows, "dwell_s": args.dwell_s}, f, indent=2)

    with summary_csv_path.open("w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow([
            "interval", "requested_hz",
            "type0_occupied_bins", "type0_bin_sum", "type0_total", "type0_last_interval",
            "type1_occupied_bins", "type1_bin_sum",
            "type1_up_occupied_bins", "type1_up_total", "type1_up_last_interval",
            "type1_down_occupied_bins", "type1_down_total", "type1_down_last_interval",
        ])
        for row in rows:
            writer.writerow([
                row["interval"],
                row["requested_hz"],
                row["type0"]["occupied_bins"],
                row["type0"]["bin_sum"],
                row["type0_stats"]["total"],
                row["type0_stats"]["last_interval"],
                row["type1_combined"]["occupied_bins"],
                row["type1_combined"]["bin_sum"],
                row["type1_up"]["occupied_bins"],
                row["type1_up_stats"]["total"],
                row["type1_up_stats"]["last_interval"],
                row["type1_down"]["occupied_bins"],
                row["type1_down_stats"]["total"],
                row["type1_down_stats"]["last_interval"],
            ])

    write_channel_csv(rows, channel_csv_path)
    plot_channel_heatmap(rows, "type0_counts", "Real MuTRiG Type0 per-channel counts",
                         type0_heatmap_path)
    plot_channel_heatmap(rows, "type1_counts", "Real MuTRiG Type1 per-channel counts",
                         type1_heatmap_path)

    print(f"# wrote {json_path}")
    print(f"# wrote {summary_csv_path}")
    print(f"# wrote {channel_csv_path}")
    print(f"# wrote {type0_heatmap_path}")
    print(f"# wrote {type1_heatmap_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
