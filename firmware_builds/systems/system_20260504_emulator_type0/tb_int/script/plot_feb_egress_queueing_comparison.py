#!/usr/bin/env python3
"""Render FEB-egress DEBUG timestamp-age evidence for tb_int runs.

The plotted age follows the post-rbCAM queueing plot style:

    age = (FEB egress monitor GTS - hit_ts8n from DEBUG-matched rbCAM ingress) mod 8192

`hit_ts8n` and the ingress monitor `(time_ps, gts_8n)` anchor come from
`rbcam_ingress_trace.csv`.  The FEB-egress monitor GTS is reconstructed by
advancing that ingress GTS by the elapsed 125 MHz monitor cycles at
`abs_ts_feb_egress` in `closed_records.csv`.
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
EXPECTED_WINDOW = (2000.0, 7096.0)
DEFAULT_XLIM = (2000, 7600)


CASE_SETS: dict[str, list[tuple[str, str, str]]] = {
    "asic0_full32_emu_20260508": [
        ("Emulator ASIC0 ch0..31", "10 kHz/ch",
         "prof_int_002_feb_egress_periodic_asic0_full32_emu_direct_010k_1ms_gap1ms_20260508"),
        ("Emulator ASIC0 ch0..31", "100 kHz/ch",
         "prof_int_002_feb_egress_periodic_asic0_full32_emu_direct_100k_1ms_gap1ms_20260508"),
        ("Emulator ASIC0 ch0..31", "500 kHz/ch",
         "prof_int_002_feb_egress_periodic_asic0_full32_emu_direct_500k_1ms_gap1ms_20260508"),
        ("Emulator ASIC0 ch0..31", "1 MHz/ch",
         "prof_int_002_feb_egress_periodic_asic0_full32_emu_direct_1000k_1ms_gap1ms_20260508"),
    ],
}

TITLES = {
    "asic0_full32_emu_20260508": "tb_int FEB-egress DEBUG timestamp age: ASIC0 ch0..31 periodic",
}


@dataclass(frozen=True)
class CaseData:
    source: str
    rate: str
    case_name: str
    records: int
    matched_records: int
    unmatched_records: int
    feb_age: list[int]
    post_age: list[int]
    post_to_feb_cycles: list[int]
    counter_a: int
    counter_pre: int
    counter_post: int
    counter_feb: int
    uvm_error: int
    uvm_fatal: int


def read_csv(path: Path) -> list[dict[str, str]]:
    if not path.is_file() or path.stat().st_size == 0:
        return []
    with path.open(newline="", encoding="utf-8") as fh:
        return list(csv.DictReader(fh))


def parse_debug_id(value: str) -> int:
    text = value.strip().lower()
    if text.startswith("0x"):
        text = text[2:]
        text = "".join("0" if char in "xz" else char for char in text)
        return int(text, 16)
    return int(text)


def load_ingress_by_debug_id(case_dir: Path) -> dict[int, tuple[int, int, int]]:
    ingress: dict[int, tuple[int, int, int]] = {}
    for row in read_csv(case_dir / "rbcam_ingress_trace.csv"):
        if row.get("would_enter_deassembly") != "1":
            continue
        if row.get("metadata_valid") != "1":
            continue
        ingress[parse_debug_id(row["metadata_hex"])] = (
            int(row["time_ps"]),
            int(row["gts_8n"]),
            int(row["hit_ts8n"]),
        )
    return ingress


def load_counters(case_dir: Path) -> tuple[int, int, int, int]:
    counters = {"stage_a": 0, "pre_rbcam": 0, "post_rbcam": 0, "feb_egress": 0}
    for row in read_csv(case_dir / "counter_agreement.csv"):
        name = row.get("counter", "")
        if name in counters:
            counters[name] = int(row.get("scoreboard_count", "0"))
    return counters["stage_a"], counters["pre_rbcam"], counters["post_rbcam"], counters["feb_egress"]


def load_uvm_counts(case_dir: Path, log_root: Path | None, case_name: str) -> tuple[int, int]:
    candidates: list[Path] = []
    if log_root is not None:
        candidates.append(log_root / f"{case_name}.summary.txt")
    candidates.append(case_dir / "transcript")
    text = ""
    for path in candidates:
        if path.is_file():
            text = path.read_text(encoding="utf-8", errors="replace")
            break
    if not text:
        return 0, 0
    error = 0
    fatal = 0
    for line in text.splitlines():
        match_error = re.search(r"#?\s*UVM_ERROR\s*:\s*(\d+)", line)
        match_fatal = re.search(r"#?\s*UVM_FATAL\s*:\s*(\d+)", line)
        if match_error:
            error = int(match_error.group(1))
        if match_fatal:
            fatal = int(match_fatal.group(1))
    return error, fatal


def load_case(sim_root: Path, log_root: Path | None, source: str, rate: str, case_name: str) -> CaseData:
    case_dir = sim_root / case_name
    rows = [
        row for row in read_csv(case_dir / "closed_records.csv")
        if row.get("abs_ts_feb_egress", "") not in ("", "0")
        and int(row.get("run_origin", "1")) != 0
    ]
    ingress = load_ingress_by_debug_id(case_dir)
    feb_age: list[int] = []
    post_age: list[int] = []
    post_to_feb_cycles: list[int] = []
    unmatched_records = 0
    for row in rows:
        metadata_id = parse_debug_id(row["root_hit_id"])
        anchor = ingress.get(metadata_id)
        if anchor is None:
            unmatched_records += 1
            continue
        ingress_time_ps, ingress_gts_8n, hit_ts8n = anchor
        post_elapsed = (int(row["abs_ts_post_rbcam"]) - ingress_time_ps) // CLOCK_PERIOD_PS
        feb_elapsed = (int(row["abs_ts_feb_egress"]) - ingress_time_ps) // CLOCK_PERIOD_PS
        post_age.append((ingress_gts_8n + post_elapsed - hit_ts8n) % GTS_MODULUS)
        feb_age.append((ingress_gts_8n + feb_elapsed - hit_ts8n) % GTS_MODULUS)
        post_to_feb_cycles.append(
            (int(row["abs_ts_feb_egress"]) - int(row["abs_ts_post_rbcam"])) // CLOCK_PERIOD_PS
        )
    counter_a, counter_pre, counter_post, counter_feb = load_counters(case_dir)
    uvm_error, uvm_fatal = load_uvm_counts(case_dir, log_root, case_name)
    return CaseData(
        source=source,
        rate=rate,
        case_name=case_name,
        records=len(rows),
        matched_records=len(feb_age),
        unmatched_records=unmatched_records,
        feb_age=feb_age,
        post_age=post_age,
        post_to_feb_cycles=post_to_feb_cycles,
        counter_a=counter_a,
        counter_pre=counter_pre,
        counter_post=counter_post,
        counter_feb=counter_feb,
        uvm_error=uvm_error,
        uvm_fatal=uvm_fatal,
    )


def make_xticks(xlim: tuple[int, int]) -> list[int]:
    lo, hi = xlim
    ticks = [lo, 2000, 3000, 4048, 5000, 6000, 7096, hi]
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


def percentile(values: list[float], pct: float) -> float:
    if not values:
        return math.nan
    ordered = sorted(values)
    rank = (len(ordered) - 1) * pct / 100.0
    lo = int(math.floor(rank))
    hi = int(math.ceil(rank))
    if lo == hi:
        return ordered[lo]
    return ordered[lo] + (ordered[hi] - ordered[lo]) * (rank - lo)


def in_expected_window(values: list[float]) -> int:
    lo, hi = EXPECTED_WINDOW
    return sum(1 for value in values if lo <= value < hi)


def render_case(ax: plt.Axes, case: CaseData, xlim: tuple[int, int], xticks: list[int]) -> None:
    xs, ys = pct_hist(case.feb_age, xlim)
    peak_bin, peak_pct = peak(case.feb_age)

    ax.bar(xs, ys, width=0.9, color="#1e78ff", alpha=0.30,
           edgecolor="#1e78ff", linewidth=0.35, label="FEB monitor GTS - hit_ts8n")
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
            "delay = (FEB egress monitor GTS - hit DEBUG timestamp) mod 8192",
            transform=ax.transAxes, ha="center", va="bottom",
            fontsize=5.8, fontfamily="monospace")

    win_count = in_expected_window(case.feb_age)
    footer = (
        f"records={case.records}; matched={case.matched_records}; missing_debug={case.unmatched_records}; "
        f"UVM_ERROR={case.uvm_error}; UVM_FATAL={case.uvm_fatal}\n"
        f"raw counters A/PRE/POST/FEB="
        f"{case.counter_a}/{case.counter_pre}/{case.counter_post}/{case.counter_feb}\n"
        f"FEB age={stat_min(case.feb_age):.0f}..{stat_max(case.feb_age):.0f} cy "
        f"(p50 {stat_med(case.feb_age):.1f}; peak {peak_bin}, {peak_pct:.3f}%)\n"
        f"POST->FEB p05/p50/p95="
        f"{percentile(case.post_to_feb_cycles, 5):.1f}/"
        f"{percentile(case.post_to_feb_cycles, 50):.1f}/"
        f"{percentile(case.post_to_feb_cycles, 95):.1f} cy\n"
        f"[{EXPECTED_WINDOW[0]:.0f},{EXPECTED_WINDOW[1]:.0f}) in={win_count}/{case.matched_records}"
    )
    ax.text(0.0, -0.345, footer, transform=ax.transAxes, ha="left", va="top",
            fontsize=5.1, fontfamily="monospace", linespacing=1.18)


def render(cases: list[CaseData], output: Path, title: str, xlim: tuple[int, int]) -> None:
    cols = min(4, max(1, len(cases)))
    rows = int(math.ceil(len(cases) / cols))
    fig_height = 8.2 if rows == 1 else 8.2 * rows
    fig, axes = plt.subplots(rows, cols, figsize=(6.0 * cols, fig_height), dpi=160, squeeze=False)
    xticks = make_xticks(xlim)
    fig.patch.set_facecolor("white")
    fig.suptitle(title, fontsize=13.0, fontfamily="monospace", fontweight="bold", y=0.982)
    fig.text(0.5, 0.952,
             "blue = (FEB monitor GTS - hit_ts8n from DEBUG-matched rbCAM ingress) mod 8192; "
             f"green = [{EXPECTED_WINDOW[0]:.0f},{EXPECTED_WINDOW[1]:.0f}) cycles; black = peak bin",
             ha="center", va="center", fontsize=8.2, fontfamily="monospace")

    for ax, case in zip(axes.flat, cases):
        render_case(ax, case, xlim, xticks)
    for ax in axes.flat[len(cases):]:
        ax.set_axis_off()

    handles, labels = axes.flat[0].get_legend_handles_labels()
    fig.legend(handles, labels, loc="upper right", bbox_to_anchor=(0.982, 0.982),
               fontsize=7.0, frameon=True)
    for ax in axes[rows - 1, :]:
        ax.set_xlabel("FEB egress age bin center [cycles]", fontsize=7.5, fontfamily="monospace")
    for ax in axes[:, 0]:
        ax.set_ylabel("hits / bin [%]", fontsize=7.5, fontfamily="monospace")
    fig.subplots_adjust(left=0.045, right=0.985, top=0.870 if rows == 1 else 0.900,
                        bottom=0.295 if rows == 1 else 0.190, wspace=0.18, hspace=0.82)
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output)
    plt.close(fig)


def write_summary(cases: list[CaseData], output: Path) -> None:
    fieldnames = [
        "source", "rate", "case", "records", "matched_records", "unmatched_records",
        "feb_age_min", "feb_age_p05", "feb_age_p50", "feb_age_p95", "feb_age_max",
        "feb_age_peak", "feb_age_peak_pct",
        "post_age_min", "post_age_p50", "post_age_max",
        "post_to_feb_p05", "post_to_feb_p50", "post_to_feb_p95",
        "expected_window_left", "expected_window_right",
        "expected_window_count", "expected_window_pct",
        "counter_A", "counter_PRE", "counter_POST", "counter_FEB",
        "uvm_error", "uvm_fatal",
    ]
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for case in cases:
            peak_bin, peak_pct = peak(case.feb_age)
            win_count = in_expected_window(case.feb_age)
            writer.writerow({
                "source": case.source,
                "rate": case.rate,
                "case": case.case_name,
                "records": case.records,
                "matched_records": case.matched_records,
                "unmatched_records": case.unmatched_records,
                "feb_age_min": round(stat_min(case.feb_age), 6),
                "feb_age_p05": round(percentile(case.feb_age, 5), 6),
                "feb_age_p50": round(percentile(case.feb_age, 50), 6),
                "feb_age_p95": round(percentile(case.feb_age, 95), 6),
                "feb_age_max": round(stat_max(case.feb_age), 6),
                "feb_age_peak": peak_bin,
                "feb_age_peak_pct": round(peak_pct, 6),
                "post_age_min": round(stat_min(case.post_age), 6),
                "post_age_p50": round(percentile(case.post_age, 50), 6),
                "post_age_max": round(stat_max(case.post_age), 6),
                "post_to_feb_p05": round(percentile(case.post_to_feb_cycles, 5), 6),
                "post_to_feb_p50": round(percentile(case.post_to_feb_cycles, 50), 6),
                "post_to_feb_p95": round(percentile(case.post_to_feb_cycles, 95), 6),
                "expected_window_left": EXPECTED_WINDOW[0],
                "expected_window_right": EXPECTED_WINDOW[1],
                "expected_window_count": win_count,
                "expected_window_pct": round(100.0 * win_count / case.matched_records, 6)
                if case.matched_records else 0.0,
                "counter_A": case.counter_a,
                "counter_PRE": case.counter_pre,
                "counter_POST": case.counter_post,
                "counter_FEB": case.counter_feb,
                "uvm_error": case.uvm_error,
                "uvm_fatal": case.uvm_fatal,
            })


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sim-root", type=Path, required=True)
    parser.add_argument("--log-root", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--summary", type=Path, required=True)
    parser.add_argument("--case-set", choices=sorted(CASE_SETS), default="asic0_full32_emu_20260508")
    parser.add_argument("--xlim", nargs=2, type=int, metavar=("LO", "HI"), default=DEFAULT_XLIM)
    parser.add_argument("--strict", action="store_true",
                        help="fail if any case has UVM errors, missing DEBUG matches, or FEB ages outside the expected window")
    args = parser.parse_args()

    case_specs = CASE_SETS[args.case_set]
    cases = [load_case(args.sim_root, args.log_root, source, rate, case_name)
             for source, rate, case_name in case_specs]
    render(cases, args.output, TITLES[args.case_set], tuple(args.xlim))
    write_summary(cases, args.summary)
    print(args.output)
    print(args.summary)
    failures: list[str] = []
    for case in cases:
        if case.matched_records == 0:
            failures.append(f"{case.case_name}: no DEBUG-matched FEB-egress rows")
            continue
        if case.unmatched_records:
            failures.append(f"{case.case_name}: {case.unmatched_records} FEB rows missing DEBUG ingress match")
        if args.strict and (case.uvm_error or case.uvm_fatal):
            failures.append(f"{case.case_name}: UVM_ERROR={case.uvm_error} UVM_FATAL={case.uvm_fatal}")
        if args.strict and in_expected_window(case.feb_age) != case.matched_records:
            failures.append(
                f"{case.case_name}: {in_expected_window(case.feb_age)}/{case.matched_records} rows in "
                f"[{EXPECTED_WINDOW[0]:.0f},{EXPECTED_WINDOW[1]:.0f})"
            )
    if failures:
        for failure in failures:
            print(f"ERROR: {failure}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
