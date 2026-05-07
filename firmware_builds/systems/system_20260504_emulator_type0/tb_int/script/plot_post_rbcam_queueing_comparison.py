#!/usr/bin/env python3
"""Render post-rbCAM timestamp-age evidence for periodic tb_int runs.

The plotted delay is the rbCAM egress age, reconstructed from hit DEBUG
lineage and the monitor GTS:

    delay = (post_rbcam_monitor_gts - hit_ts8n) mod 8192

`hit_ts8n` is taken from the rbCAM ingress trace for the same DEBUG metadata
ID that appears as `root_hit_id` in `post_rbcam_records.csv`.  The post monitor
GTS is reconstructed from the rbCAM ingress `(time_ps, gts_8n)` anchor plus
the elapsed monitor time.  This intentionally ignores the source commit/export
time because the source can queue hits internally before presenting them to the
downstream path.
"""

from __future__ import annotations

import argparse
import csv
import math
import re
from collections import Counter
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402


CLOCK_PERIOD_PS = 8000
GTS_MODULUS = 8192
EXPECTED_WINDOW = (2000.0, 2200.0)
DEFAULT_XLIM = (1980, 2220)
DEFAULT_XTICKS = [1980, 2000, 2040, 2080, 2120, 2160, 2200, 2220]


CASE_SETS: dict[str, list[tuple[str, str, str]]] = {
    "ch0_emu_vs_virtual": [
        ("Emulator", "10 kHz", "prof_int_002_post_rbcam_periodic_asic0_ch0_emu_direct_010k_1ms_gap1ms_20260507"),
        ("Emulator", "100 kHz", "prof_int_002_post_rbcam_periodic_asic0_ch0_emu_direct_100k_1ms_gap1ms_20260507"),
        ("Emulator", "500 kHz", "prof_int_002_post_rbcam_periodic_asic0_ch0_emu_direct_500k_1ms_gap1ms_20260507"),
        ("Emulator", "1 MHz", "prof_int_002_post_rbcam_periodic_asic0_ch0_emu_direct_1000k_1ms_gap1ms_20260507"),
        ("Virtual MuTRiG", "10 kHz", "prof_int_002_post_rbcam_periodic_asic0_ch0_virtual_mutrig_010k_1ms_gap1ms_tccfix_20260507"),
        ("Virtual MuTRiG", "100 kHz", "prof_int_002_post_rbcam_periodic_asic0_ch0_virtual_mutrig_100k_1ms_gap1ms_tccfix_20260507"),
        ("Virtual MuTRiG", "500 kHz", "prof_int_002_post_rbcam_periodic_asic0_ch0_virtual_mutrig_500k_1ms_gap1ms_tccfix_20260507"),
        ("Virtual MuTRiG", "1 MHz", "prof_int_002_post_rbcam_periodic_asic0_ch0_virtual_mutrig_1000k_1ms_gap1ms_tccfix_20260507"),
    ],
    "asic0_full32_emu": [
        ("Emulator ASIC0 ch0..31", "10 kHz/ch", "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_010k_1ms_gap1ms_20260507"),
        ("Emulator ASIC0 ch0..31", "100 kHz/ch", "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_100k_1ms_gap1ms_20260507"),
        ("Emulator ASIC0 ch0..31", "500 kHz/ch", "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_500k_1ms_gap1ms_20260507"),
        ("Emulator ASIC0 ch0..31", "1 MHz/ch", "prof_int_002_post_rbcam_periodic_asic0_full32_emu_direct_1000k_1ms_gap1ms_20260507"),
    ],
}

TITLES = {
    "ch0_emu_vs_virtual": "tb_int post-rbCAM DEBUG timestamp age: ASIC0 ch0 periodic",
    "asic0_full32_emu": "tb_int post-rbCAM DEBUG timestamp age: ASIC0 ch0..31 periodic",
}

CASE_XLIMS = {
    "ch0_emu_vs_virtual": DEFAULT_XLIM,
    "asic0_full32_emu": (1980, 3400),
}


@dataclass(frozen=True)
class CaseData:
    source: str
    rate: str
    case_name: str
    records: int
    matched_records: int
    unmatched_records: int
    rbcam_age: list[int]
    ingress_age: list[int]
    counter_a: int
    counter_pre_fanout_raw: int
    counter_post: int
    uvm_error: int


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def parse_debug_id(value: str) -> int:
    text = value.strip().lower()
    if text.startswith("0x"):
        text = text[2:]
        # Some debug metadata includes X bits in simulation for don't-care
        # fields.  The decimal UVM export has those bits resolved to zero, so
        # normalize hex traces the same way before joining.
        text = "".join("0" if char in "xz" else char for char in text)
        return int(text, 16)
    return int(text)


def load_ingress_by_debug_id(case_dir: Path) -> dict[int, tuple[int, int, int, int]]:
    ingress: dict[int, tuple[int, int, int, int]] = {}
    for row in read_csv(case_dir / "rbcam_ingress_trace.csv"):
        if row.get("would_enter_deassembly") != "1":
            continue
        if row.get("metadata_valid") != "1":
            continue
        metadata_id = parse_debug_id(row["metadata_hex"])
        ingress[metadata_id] = (
            int(row["time_ps"]),
            int(row["gts_8n"]),
            int(row["hit_ts8n"]),
            int(row["age_mod8192"]),
        )
    return ingress


def load_counters(case_dir: Path) -> tuple[int, int, int]:
    counters = {"stage_a": 0, "pre_rbcam": 0, "post_rbcam": 0}
    path = case_dir / "counter_agreement.csv"
    if not path.is_file():
        return 0, 0, 0
    for row in read_csv(path):
        name = row.get("counter", "")
        if name in counters:
            counters[name] = int(row.get("scoreboard_count", "0"))
    return counters["stage_a"], counters["pre_rbcam"], counters["post_rbcam"]


def load_uvm_error(log_root: Path, case_name: str) -> int:
    summary = log_root / f"{case_name}.summary.txt"
    if not summary.is_file():
        return 0
    for line in summary.read_text(encoding="utf-8", errors="replace").splitlines():
        match = re.search(r"#\s*UVM_ERROR\s*:\s*(\d+)", line)
        if match:
            return int(match.group(1))
    return 0


def load_case(sim_root: Path, log_root: Path, source: str, rate: str, case_name: str) -> CaseData:
    case_dir = sim_root / case_name
    rows = [row for row in read_csv(case_dir / "post_rbcam_records.csv")
            if int(row.get("run_origin", "1")) != 0]
    ingress = load_ingress_by_debug_id(case_dir)
    rbcam_age: list[int] = []
    ingress_age: list[int] = []
    unmatched_records = 0
    for row in rows:
        metadata_id = parse_debug_id(row["root_hit_id"])
        anchor = ingress.get(metadata_id)
        if anchor is None:
            unmatched_records += 1
            continue
        ingress_time_ps, ingress_gts_8n, hit_ts8n, ingress_age_mod8192 = anchor
        elapsed_cycles = (int(row["abs_ts_post_rbcam"]) - ingress_time_ps) // CLOCK_PERIOD_PS
        post_monitor_gts = ingress_gts_8n + elapsed_cycles
        rbcam_age.append((post_monitor_gts - hit_ts8n) % GTS_MODULUS)
        ingress_age.append(ingress_age_mod8192)
    counter_a, counter_pre_fanout_raw, counter_post = load_counters(case_dir)
    return CaseData(
        source=source,
        rate=rate,
        case_name=case_name,
        records=len(rows),
        matched_records=len(rbcam_age),
        unmatched_records=unmatched_records,
        rbcam_age=rbcam_age,
        ingress_age=ingress_age,
        counter_a=counter_a,
        counter_pre_fanout_raw=counter_pre_fanout_raw,
        counter_post=counter_post,
        uvm_error=load_uvm_error(log_root, case_name),
    )


def make_xticks(xlim: tuple[int, int]) -> list[int]:
    if xlim == DEFAULT_XLIM:
        return DEFAULT_XTICKS
    lo, hi = xlim
    ticks = [2000, 2200]
    ticks.extend(range(2400, hi + 1, 200))
    if ticks[-1] != hi:
        ticks.append(hi)
    return sorted(set(tick for tick in ticks if lo <= tick <= hi))


def pct_hist(values: list[float], xlim: tuple[int, int]) -> tuple[list[int], list[float]]:
    if not values:
        return [], []
    counts = Counter(int(round(v)) for v in values)
    xs = list(range(xlim[0], xlim[1] + 1))
    ys = [100.0 * counts.get(x, 0) / len(values) for x in xs]
    return xs, ys


def stat_min(values: list[float]) -> float:
    return min(values) if values else math.nan


def stat_max(values: list[float]) -> float:
    return max(values) if values else math.nan


def stat_med(values: list[float]) -> float:
    if not values:
        return math.nan
    ordered = sorted(values)
    mid = len(ordered) // 2
    if len(ordered) & 1:
        return ordered[mid]
    return 0.5 * (ordered[mid - 1] + ordered[mid])


def peak(values: list[float]) -> tuple[int | None, float]:
    if not values:
        return None, 0.0
    counts = Counter(int(round(v)) for v in values)
    bin_center, count = max(counts.items(), key=lambda item: (item[1], -item[0]))
    return bin_center, 100.0 * count / len(values)


def in_expected_window(values: list[float]) -> int:
    lo, hi = EXPECTED_WINDOW
    return sum(1 for v in values if lo <= v < hi)


def render_case(ax: plt.Axes, case: CaseData, xlim: tuple[int, int], xticks: list[int]) -> None:
    xs, ys = pct_hist(case.rbcam_age, xlim)
    peak_bin, peak_pct = peak(case.rbcam_age)

    ax.bar(xs, ys, width=0.9, color="#1e78ff", alpha=0.30,
           edgecolor="#1e78ff", linewidth=0.35, label="post monitor GTS - hit_ts8n")
    ax.axvline(EXPECTED_WINDOW[0], color="#00d94a", linewidth=1.0)
    ax.axvline(EXPECTED_WINDOW[1], color="#00d94a", linewidth=1.0)
    if peak_bin is not None:
        ax.axvline(peak_bin, color="#111111", linewidth=0.9)

    ymax = max(ys + [0.0])
    ytop = max(12.0, math.ceil((ymax * 1.18) / 2.0) * 2.0)
    ax.set_xlim(*xlim)
    ax.set_ylim(0.0, ytop)
    ax.set_xticks(xticks)
    ax.set_yticks([0, 2, 4, 6, 8, 10, 12] if ytop <= 12 else list(range(0, int(ytop) + 1, 5)))
    ax.grid(True, color="#000000", alpha=0.22, linewidth=0.55)
    for spine in ax.spines.values():
        spine.set_color("#777777")
        spine.set_linewidth(0.55)
    ax.tick_params(axis="both", top=True, right=True, labelsize=6.5,
                   width=0.45, color="#666666", labelcolor="#555555")

    ax.set_title(f"{case.source} {case.rate}", fontsize=9.0,
                 fontfamily="monospace", pad=20.0)
    ax.text(0.5, 1.035,
            "delay = (post-rbCAM monitor GTS - hit DEBUG timestamp) mod 8192",
            transform=ax.transAxes, ha="center", va="bottom",
            fontsize=5.8, fontfamily="monospace")

    win_count = in_expected_window(case.rbcam_age)
    footer = (
        f"records={case.records}; matched={case.matched_records}; missing_debug={case.unmatched_records}; "
        f"UVM_ERROR={case.uvm_error}\n"
        f"raw counters A/PREfanout/POST="
        f"{case.counter_a}/{case.counter_pre_fanout_raw}/{case.counter_post}\n"
        f"egress age={stat_min(case.rbcam_age):.0f}..{stat_max(case.rbcam_age):.0f} cy "
        f"(p50 {stat_med(case.rbcam_age):.1f}; peak {peak_bin}, {peak_pct:.3f}%)\n"
        f"[{EXPECTED_WINDOW[0]:.0f},{EXPECTED_WINDOW[1]:.0f}) in={win_count}/{case.matched_records}"
    )
    ax.text(0.0, -0.305, footer, transform=ax.transAxes, ha="left", va="top",
            fontsize=5.1, fontfamily="monospace", linespacing=1.18)


def render(cases: list[CaseData], output: Path, title: str, xlim: tuple[int, int]) -> None:
    cols = min(4, max(1, len(cases)))
    rows = int(math.ceil(len(cases) / cols))
    fig_height = 7.9 if rows == 1 else 8.0 * rows
    fig, axes = plt.subplots(rows, cols, figsize=(6.0 * cols, fig_height), dpi=160, squeeze=False)
    xticks = make_xticks(xlim)
    fig.patch.set_facecolor("white")
    fig.suptitle(title, fontsize=13.0, fontfamily="monospace", fontweight="bold", y=0.982)
    fig.text(0.5, 0.952,
             "blue = (post monitor GTS - hit_ts8n from DEBUG-matched rbCAM ingress) mod 8192; green = [2000,2200) cycles; black = peak bin",
             ha="center", va="center", fontsize=8.2, fontfamily="monospace")

    for ax, case in zip(axes.flat, cases):
        render_case(ax, case, xlim, xticks)
    for ax in axes.flat[len(cases):]:
        ax.set_axis_off()

    handles, labels = axes.flat[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper right", bbox_to_anchor=(0.982, 0.982),
               fontsize=7.0, frameon=True)
    for ax in axes[rows - 1, :]:
        ax.set_xlabel("post-rbCAM egress age bin center [cycles]", fontsize=7.5, fontfamily="monospace")
    for ax in axes[:, 0]:
        ax.set_ylabel("hits / bin [%]", fontsize=7.5, fontfamily="monospace")
    fig.subplots_adjust(left=0.045, right=0.985, top=0.870 if rows == 1 else 0.900,
                        bottom=0.270 if rows == 1 else 0.180, wspace=0.18, hspace=0.78)
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output)
    plt.close(fig)


def write_summary(cases: list[CaseData], output: Path) -> None:
    fieldnames = [
        "source", "rate", "case", "records", "matched_records", "unmatched_records",
        "rbcam_age_min", "rbcam_age_p50", "rbcam_age_max",
        "rbcam_age_peak", "rbcam_age_peak_pct",
        "ingress_age_min", "ingress_age_p50", "ingress_age_max",
        "expected_window_left", "expected_window_right",
        "expected_window_count", "expected_window_pct",
        "counter_A", "counter_PRE_fanout_raw", "counter_POST", "uvm_error",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for case in cases:
            peak_bin, peak_pct = peak(case.rbcam_age)
            win_count = in_expected_window(case.rbcam_age)
            writer.writerow({
                "source": case.source,
                "rate": case.rate,
                "case": case.case_name,
                "records": case.records,
                "matched_records": case.matched_records,
                "unmatched_records": case.unmatched_records,
                "rbcam_age_min": round(stat_min(case.rbcam_age), 6),
                "rbcam_age_p50": round(stat_med(case.rbcam_age), 6),
                "rbcam_age_max": round(stat_max(case.rbcam_age), 6),
                "rbcam_age_peak": peak_bin,
                "rbcam_age_peak_pct": round(peak_pct, 6),
                "ingress_age_min": round(stat_min(case.ingress_age), 6),
                "ingress_age_p50": round(stat_med(case.ingress_age), 6),
                "ingress_age_max": round(stat_max(case.ingress_age), 6),
                "expected_window_left": EXPECTED_WINDOW[0],
                "expected_window_right": EXPECTED_WINDOW[1],
                "expected_window_count": win_count,
                "expected_window_pct": round(100.0 * win_count / case.matched_records, 6)
                if case.matched_records else 0.0,
                "counter_A": case.counter_a,
                "counter_PRE_fanout_raw": case.counter_pre_fanout_raw,
                "counter_POST": case.counter_post,
                "uvm_error": case.uvm_error,
            })


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sim-root", type=Path, required=True)
    parser.add_argument("--log-root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--case-set", choices=sorted(CASE_SETS), default="ch0_emu_vs_virtual")
    args = parser.parse_args()

    case_specs = CASE_SETS[args.case_set]
    cases = [load_case(args.sim_root, args.log_root, source, rate, case_name)
             for source, rate, case_name in case_specs]
    render(cases, args.output, TITLES[args.case_set], CASE_XLIMS[args.case_set])
    write_summary(cases, args.summary)
    print(args.output)
    print(args.summary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
