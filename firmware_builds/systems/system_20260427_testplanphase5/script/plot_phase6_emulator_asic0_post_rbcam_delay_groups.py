#!/usr/bin/env python3
"""Render ASIC post-rbCAM delay histogram groups."""

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
from matplotlib.patches import Rectangle  # noqa: E402


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
REPORT_DIR = SYSTEM_DIR / "reports"
DEFAULT_OUT_DIR = REPORT_DIR / "assets" / "phase6_emulator_asic0_post_rbcam_delay_20260502"

RATE_CASES = (
    ("10k", 10_000, 12_500),
    ("100k", 100_000, 1_250),
    ("500k", 500_000, 250),
    ("1M", 1_000_000, 125),
)
HEADER_MULTIPLICITIES = (2, 3, 4, 5)
RBCAM_LEFT = 2000.0
RBCAM_RIGHT = 3000.0
WINDOW_LABEL = "post-rbCAM"
FULL_XLIM = (-1000.0, 3096.0)
FULL_XTICKS = [-1000.0, -488.0, 24.0, 536.0, 1048.0, 1560.0, 2072.0, 2584.0, 3096.0]


@dataclass(frozen=True)
class Hist:
    name: str
    source: Path
    centers: list[float]
    counts: list[int]
    target_hz: int | None = None
    pulse_interval: int | None = None
    multiplicity: int | None = None
    sidecar: dict[str, object] | None = None

    @property
    def total(self) -> int:
        return sum(self.counts)

    @property
    def nonzero_bins(self) -> int:
        return sum(1 for value in self.counts if value > 0)

    @property
    def peak_center(self) -> float | None:
        if not self.counts or self.total <= 0:
            return None
        index = max(range(len(self.counts)), key=self.counts.__getitem__)
        return self.centers[index]

    @property
    def peak_fraction_pct(self) -> float:
        total = self.total
        return 100.0 * max(self.counts) / total if total > 0 and self.counts else 0.0

    @property
    def in_window(self) -> int:
        return sum(
            count
            for center, count in zip(self.centers, self.counts)
            if RBCAM_LEFT <= center < RBCAM_RIGHT
        )

    @property
    def low_out(self) -> int:
        return sum(count for center, count in zip(self.centers, self.counts) if center < RBCAM_LEFT)

    @property
    def high_out(self) -> int:
        return sum(count for center, count in zip(self.centers, self.counts) if center >= RBCAM_RIGHT)

    @property
    def out_window(self) -> int:
        return self.total - self.in_window

    def pct(self, value: int) -> float:
        return 100.0 * value / self.total if self.total else 0.0

    def quantile(self, fraction: float) -> float | None:
        if self.total <= 0:
            return None
        target = self.total * fraction
        acc = 0
        for center, count in zip(self.centers, self.counts):
            acc += count
            if acc >= target:
                return center
        return self.centers[-1] if self.centers else None

    def summary(self) -> dict[str, object]:
        q05 = self.quantile(0.05)
        q50 = self.quantile(0.50)
        q95 = self.quantile(0.95)
        width = q95 - q05 if q05 is not None and q95 is not None else None
        counters = sidecar_counters(self.sidecar, self.total)
        return {
            "name": self.name,
            "source": str(self.source),
            "target_hz": self.target_hz,
            "pulse_interval_cycles": self.pulse_interval,
            "multiplicity": self.multiplicity,
            "total_hits": self.total,
            "nonzero_bins": self.nonzero_bins,
            "peak_center_cycles": self.peak_center,
            "peak_fraction_pct": self.peak_fraction_pct,
            "q05_cycles": q05,
            "q50_cycles": q50,
            "q95_cycles": q95,
            "q05_q95_width_cycles": width,
            "rbcam_window": [RBCAM_LEFT, RBCAM_RIGHT],
            "rbcam_in_hits": self.in_window,
            "rbcam_in_pct": self.pct(self.in_window),
            "rbcam_out_hits": self.out_window,
            "rbcam_out_pct": self.pct(self.out_window),
            "rbcam_low_out_hits": self.low_out,
            "rbcam_low_out_pct": self.pct(self.low_out),
            "rbcam_high_out_hits": self.high_out,
            "rbcam_high_out_pct": self.pct(self.high_out),
            **counters,
        }

    @property
    def peak_bin_index(self) -> int | None:
        if not self.counts or self.total <= 0:
            return None
        return max(range(len(self.counts)), key=self.counts.__getitem__)


def delta32(after: dict[str, object], before: dict[str, object], key: str) -> int:
    return (int(after.get(key, 0)) - int(before.get(key, 0))) & 0xFFFFFFFF


def delta48(after: dict[str, object], before: dict[str, object], key: str) -> int:
    return (int(after.get(key, 0)) - int(before.get(key, 0))) & ((1 << 48) - 1)


def sidecar_counters(sidecar: dict[str, object] | None, total: int) -> dict[str, object]:
    if not sidecar:
        return {
            "counter_window_s": None,
            "hist_underflow": None,
            "hist_overflow": None,
            "hist_underflow_pct": None,
            "hist_overflow_pct": None,
            "hist_dropped_hits": None,
            "selector_hp_seen": None,
            "selector_rb_seen": None,
            "selector_hist_emit": None,
            "selector_hist_drop": None,
            "rbcam_inerr": None,
            "rbcam_push": None,
            "rbcam_pop": None,
            "rbcam_push_hz": None,
            "rbcam_pop_hz": None,
            "rbcam_overwrite": None,
            "rbcam_cache_miss": None,
            "mts0_hits": None,
            "mts1_hits": None,
            "mts0_hz": None,
            "mts1_hz": None,
        }

    hist_before = dict(sidecar.get("hist_before", {}))
    hist_after = dict(sidecar.get("hist_after", {}))
    selector_before = dict(sidecar.get("selector_before", {}))
    selector_after = dict(sidecar.get("selector_after", {}))
    rbcam_before = dict(sidecar.get("rbcam_before", {}))
    rbcam_after = dict(sidecar.get("rbcam_after", {}))
    mts_before = [dict(row) for row in sidecar.get("mts_before", [])]
    mts_after = [dict(row) for row in sidecar.get("mts_after", [])]
    window_s = float(dict(sidecar.get("dump", {})).get("elapsed_s", 0.0))

    hist_underflow = delta32(hist_after, hist_before, "underflow")
    hist_overflow = delta32(hist_after, hist_before, "overflow")
    rbcam_push = delta32(rbcam_after, rbcam_before, "push")
    rbcam_pop = delta32(rbcam_after, rbcam_before, "pop")
    mts_hits = [
        delta48(after, before, "total_hits")
        for before, after in zip(mts_before, mts_after)
    ]
    while len(mts_hits) < 2:
        mts_hits.append(0)

    def rate(value: int) -> float | None:
        return value / window_s if window_s > 0.0 else None

    return {
        "counter_window_s": window_s,
        "hist_underflow": hist_underflow,
        "hist_overflow": hist_overflow,
        "hist_underflow_pct": 100.0 * hist_underflow / total if total else 0.0,
        "hist_overflow_pct": 100.0 * hist_overflow / total if total else 0.0,
        "hist_dropped_hits": delta32(hist_after, hist_before, "dropped_hits"),
        "selector_hp_seen": delta32(selector_after, selector_before, "hp_seen"),
        "selector_rb_seen": delta32(selector_after, selector_before, "rb_seen"),
        "selector_hist_emit": delta32(selector_after, selector_before, "hist_emit"),
        "selector_hist_drop": delta32(selector_after, selector_before, "hist_drop"),
        "rbcam_inerr": delta32(rbcam_after, rbcam_before, "inerr"),
        "rbcam_push": rbcam_push,
        "rbcam_pop": rbcam_pop,
        "rbcam_push_hz": rate(rbcam_push),
        "rbcam_pop_hz": rate(rbcam_pop),
        "rbcam_overwrite": delta32(rbcam_after, rbcam_before, "overwrite"),
        "rbcam_cache_miss": delta32(rbcam_after, rbcam_before, "cache_miss"),
        "mts0_hits": mts_hits[0],
        "mts1_hits": mts_hits[1],
        "mts0_hz": rate(mts_hits[0]),
        "mts1_hz": rate(mts_hits[1]),
    }


def read_hist(path: Path, name: str, **kwargs: object) -> Hist:
    centers: list[float] = []
    counts: list[int] = []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        if not reader.fieldnames or "bin_center" not in reader.fieldnames or "count" not in reader.fieldnames:
            raise RuntimeError(f"{path} is not a histogram CSV with bin_center/count columns")
        for row in reader:
            centers.append(float(row["bin_center"]))
            counts.append(int(row["count"]))
    sidecar_path = path.with_suffix(".json")
    sidecar = None
    if sidecar_path.is_file():
        sidecar = json.loads(sidecar_path.read_text(encoding="utf-8"))
    return Hist(name=name, source=path, centers=centers, counts=counts, sidecar=sidecar, **kwargs)


def require_existing(path: Path) -> Path:
    if not path.is_file():
        raise FileNotFoundError(path)
    return path


def rate_csv_path(report_dir: Path, date: str, stem_prefix: str, label: str) -> Path:
    return report_dir / f"{stem_prefix}_rate_{label}_delay_hit_t_runtime_mux_{date}.csv"


def header_csv_path(report_dir: Path, date: str, stem_prefix: str, multiplicity: int) -> Path:
    return report_dir / (
        f"{stem_prefix}_header_mult{multiplicity}_"
        f"delay_hit_t_runtime_mux_{date}.csv"
    )


def load_rate_hists(report_dir: Path, date: str, stem_prefix: str) -> list[Hist]:
    hists: list[Hist] = []
    for label, target_hz, interval in RATE_CASES:
        hists.append(
            read_hist(
                require_existing(rate_csv_path(report_dir, date, stem_prefix, label)),
                name=f"{label} periodic",
                target_hz=target_hz,
                pulse_interval=interval,
            )
        )
    return hists


def load_header_hists(report_dir: Path, date: str, stem_prefix: str) -> list[Hist]:
    return [
        read_hist(
            require_existing(header_csv_path(report_dir, date, stem_prefix, multiplicity)),
            name=f"mult {multiplicity}",
            multiplicity=multiplicity,
        )
        for multiplicity in HEADER_MULTIPLICITIES
    ]


def normalized_counts(hist: Hist) -> list[float]:
    total = hist.total
    if total <= 0:
        return [0.0 for _ in hist.counts]
    return [100.0 * value / total for value in hist.counts]


def active_x_range(hists: list[Hist]) -> tuple[float, float]:
    active = [
        center
        for hist in hists
        for center, count in zip(hist.centers, hist.counts)
        if count > 0
    ]
    if not active:
        return -1000.0, 3096.0
    left = min(RBCAM_LEFT, min(active) - 96.0)
    right = max(RBCAM_RIGHT, max(active) + 96.0)
    return math.floor(left / 16.0) * 16.0, math.ceil(right / 16.0) * 16.0


def draw_panel(ax: plt.Axes, hist: Hist, color: str, xlim: tuple[float, float]) -> None:
    ax.step(hist.centers, normalized_counts(hist), where="mid", linewidth=1.5, color=color)
    ax.axvspan(RBCAM_LEFT, RBCAM_RIGHT, color="#ddeecf", alpha=0.35, linewidth=0)
    ax.axvline(RBCAM_LEFT, color="#2d6a4f", linewidth=1.0)
    ax.axvline(RBCAM_RIGHT, color="#2d6a4f", linewidth=1.0)
    if hist.peak_center is not None:
        ax.axvline(hist.peak_center, color="#111111", linewidth=1.1)
    ax.set_xlim(*xlim)
    ymax = max(normalized_counts(hist), default=0.0)
    ax.set_ylim(0.0, max(1.0, ymax * 1.22))
    ax.grid(True, alpha=0.22)
    summary = hist.summary()
    if hist.target_hz is not None:
        subtitle = f"{hist.name}; interval={hist.pulse_interval}; total={hist.total:,}"
    else:
        subtitle = f"{hist.name}; total={hist.total:,}"
    ax.set_title(
        f"{subtitle}\n"
        f"peak={summary['peak_center_cycles']} cyc, "
        f"in={summary['rbcam_in_pct']:.3f}%, out={summary['rbcam_out_pct']:.3f}%",
        fontsize=10,
    )


def render_group(hists: list[Hist], title: str, output: Path) -> None:
    xlim = active_x_range(hists)
    fig, axes = plt.subplots(2, 2, figsize=(14.0, 8.2), sharex=True, sharey=False)
    colors = ["#1f77b4", "#2ca02c", "#b58900", "#8c564b"]
    for ax, hist, color in zip(axes.flat, hists, colors):
        draw_panel(ax, hist, color, xlim)
    for ax in axes[-1, :]:
        ax.set_xlabel("Signed hit latency bin center [cycles]")
    for ax in axes[:, 0]:
        ax.set_ylabel("Hits per bin [%]")
    fig.suptitle(title, fontsize=15)
    fig.tight_layout(rect=(0.0, 0.0, 1.0, 0.96))
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output, dpi=170)
    plt.close(fig)


def rounded_y_top(hist: Hist) -> float:
    ymax = max(normalized_counts(hist), default=0.0)
    if ymax <= 10.0:
        return 10.0
    if ymax <= 20.0:
        return 20.0
    return math.ceil(ymax * 1.12 / 10.0) * 10.0


def add_reference_panel(
    fig: plt.Figure,
    panel: tuple[float, float, float, float],
    hist: Hist,
    title: str,
    subtitle: str,
    *,
    footer_fontsize: float,
    title_fontsize: float,
) -> None:
    left, bottom, width, height = panel
    fig.add_artist(
        Rectangle(
            (left, bottom),
            width,
            height,
            transform=fig.transFigure,
            fill=False,
            edgecolor="#9a9a9a",
            linewidth=0.9,
        )
    )
    fig.add_artist(
        Rectangle(
            (left + 0.003 * width, bottom + 0.004 * height),
            width - 0.006 * width,
            height - 0.008 * height,
            transform=fig.transFigure,
            fill=False,
            edgecolor="#d2d2d2",
            linewidth=0.45,
        )
    )

    ax = fig.add_axes(
        [
            left + 0.142 * width,
            bottom + 0.252 * height,
            0.700 * width,
            0.450 * height,
        ]
    )
    y = normalized_counts(hist)
    ax.bar(
        hist.centers,
        y,
        width=8.0,
        align="center",
        facecolor=(0.0, 0.42, 1.0, 0.08),
        edgecolor="#0066ff",
        linewidth=0.45,
    )
    ax.axvline(RBCAM_LEFT, color="#00e044", linewidth=0.8)
    ax.axvline(RBCAM_RIGHT, color="#00e044", linewidth=0.8)
    if hist.peak_center is not None:
        ax.axvline(hist.peak_center, color="#111111", linewidth=1.0)

    y_top = rounded_y_top(hist)
    ax.set_xlim(*FULL_XLIM)
    ax.set_ylim(0.0, y_top)
    ax.set_xticks(FULL_XTICKS)
    ax.set_yticks([value for value in range(0, int(y_top) + 1, 2 if y_top <= 10.0 else 5)])
    ax.grid(True, color="#000000", alpha=0.28, linewidth=0.55)
    ax.tick_params(
        axis="both",
        which="both",
        top=True,
        right=True,
        labelsize=7,
        width=0.45,
        color="#666666",
        labelcolor="#555555",
    )
    for spine in ax.spines.values():
        spine.set_linewidth(0.45)
        spine.set_color("#555555")
    ax.set_xlabel("signed hit latency bin center [cycles]", fontsize=8.5, family="monospace")
    ax.set_ylabel("hits / bin [% of captured interval]", fontsize=8.5, family="monospace")

    peak_center = hist.peak_center
    peak_bin = hist.peak_bin_index
    peak_text = "None" if peak_center is None else f"{peak_center:.1f}"
    in_pct = hist.pct(hist.in_window)
    out_pct = hist.pct(hist.out_window)
    fig.text(
        left + 0.5 * width,
        bottom + 0.835 * height,
        title,
        ha="center",
        va="center",
        fontsize=title_fontsize,
        family="monospace",
    )
    fig.text(
        left + 0.5 * width,
        bottom + 0.790 * height,
        subtitle,
        ha="center",
        va="center",
        fontsize=max(footer_fontsize - 0.3, 5.0),
        family="monospace",
    )
    footer_left = left + 0.140 * width
    footer_y = bottom + 0.125 * height
    footer_lines = [
        (
            f"total={hist.total} hits, nonzero={hist.nonzero_bins}/256, "
            f"peak bin={peak_bin} at {peak_text} cycles, "
            f"peak fraction={hist.peak_fraction_pct:.3f}%"
        ),
        (
            f"black=peak {peak_text} cycles; green={WINDOW_LABEL} window edges "
            f"{RBCAM_LEFT:.0f} and {RBCAM_RIGHT:.0f} cycles"
        ),
        (
            f"{WINDOW_LABEL} [{RBCAM_LEFT:.0f},{RBCAM_RIGHT:.0f}]: "
            f"in={hist.in_window} ({in_pct:.6f}%), "
            f"out={hist.out_window} ({out_pct:.6f}%)"
        ),
    ]
    for line_idx, line in enumerate(footer_lines):
        fig.text(
            footer_left,
            footer_y - line_idx * 0.048 * height,
            line,
            ha="left",
            va="center",
            fontsize=footer_fontsize,
            family="monospace",
        )


def render_reference_rate(hists: list[Hist], output: Path) -> None:
    fig = plt.figure(figsize=(16.0, 10.24), facecolor="white")
    panels = [
        (0.012, 0.515, 0.476, 0.464),
        (0.512, 0.515, 0.476, 0.464),
        (0.012, 0.025, 0.476, 0.464),
        (0.512, 0.025, 0.476, 0.464),
    ]
    for hist, panel in zip(hists, panels):
        label = (hist.name.split()[0] if hist.name else "").replace("periodic", "").strip()
        add_reference_panel(
            fig,
            panel,
            hist,
            f"Phase-6 Periodic Mode=2 Delay: ASIC 0 {label}",
            (
                f"mode=2 periodic; interval={hist.pulse_interval} cycles; "
                "pulse_high=5; delay_hit_t; ASIC0 filter"
            ),
            footer_fontsize=7.3,
            title_fontsize=7.5,
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output, dpi=160)
    plt.close(fig)


def render_reference_header(hists: list[Hist], output: Path) -> None:
    fig = plt.figure(figsize=(20.48, 3.33), facecolor="white")
    gap = 0.012
    width = (1.0 - gap * 5.0) / 4.0
    panels = [(gap + idx * (width + gap), 0.045, width, 0.910) for idx in range(4)]
    for hist, panel in zip(hists, panels):
        add_reference_panel(
            fig,
            panel,
            hist,
            "Phase-6 Header Delay multiplicity: ASIC 0",
            (
                "mask=0xffffffff; enabled=32/32; "
                f"multiplicity={hist.multiplicity}; pulse_high=5; delay_hit_t"
            ),
            footer_fontsize=5.0,
            title_fontsize=5.4,
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output, dpi=160)
    plt.close(fig)


def write_html(rate_plot: Path, header_plot: Path, summary: dict[str, object], output: Path, title: str) -> None:
    def table(rows: list[dict[str, object]]) -> str:
        def fmt_value(value: object, precision: int = 6) -> str:
            if value is None:
                return ""
            if isinstance(value, float):
                return f"{value:.{precision}f}"
            return str(value)

        body = [
            "<table>",
            "<tr><th>Case</th><th>Total</th><th>Nonzero</th><th>Peak cyc</th>"
            "<th>q05</th><th>q50</th><th>q95</th><th>Width</th>"
            "<th>In %</th><th>Out %</th><th>Low out %</th><th>High out %</th>"
            "<th>UF/OF %</th><th>Hist drops</th><th>Selector HP/RB/Emit/Drop</th>"
            "<th>MTS0/1 hits</th><th>MTS0/1 Hz</th><th>rbCAM InErr/Push/Pop</th>"
            "<th>rbCAM Push/Pop Hz</th><th>rbCAM OW/Miss</th></tr>",
        ]
        for row in rows:
            body.append(
                "<tr>"
                f"<td>{row['name']}</td>"
                f"<td>{int(row['total_hits'])}</td>"
                f"<td>{int(row['nonzero_bins'])}</td>"
                f"<td>{row['peak_center_cycles']}</td>"
                f"<td>{row['q05_cycles']}</td>"
                f"<td>{row['q50_cycles']}</td>"
                f"<td>{row['q95_cycles']}</td>"
                f"<td>{row['q05_q95_width_cycles']}</td>"
                f"<td>{float(row['rbcam_in_pct']):.6f}</td>"
                f"<td>{float(row['rbcam_out_pct']):.6f}</td>"
                f"<td>{float(row['rbcam_low_out_pct']):.6f}</td>"
                f"<td>{float(row['rbcam_high_out_pct']):.6f}</td>"
                f"<td>{fmt_value(row['hist_underflow_pct'])}/{fmt_value(row['hist_overflow_pct'])}</td>"
                f"<td>{fmt_value(row['hist_dropped_hits'], 0)}</td>"
                f"<td>{fmt_value(row['selector_hp_seen'], 0)}/{fmt_value(row['selector_rb_seen'], 0)}/"
                f"{fmt_value(row['selector_hist_emit'], 0)}/{fmt_value(row['selector_hist_drop'], 0)}</td>"
                f"<td>{fmt_value(row['mts0_hits'], 0)}/{fmt_value(row['mts1_hits'], 0)}</td>"
                f"<td>{fmt_value(row['mts0_hz'], 2)}/{fmt_value(row['mts1_hz'], 2)}</td>"
                f"<td>{fmt_value(row['rbcam_inerr'], 0)}/{fmt_value(row['rbcam_push'], 0)}/"
                f"{fmt_value(row['rbcam_pop'], 0)}</td>"
                f"<td>{fmt_value(row['rbcam_push_hz'], 2)}/{fmt_value(row['rbcam_pop_hz'], 2)}</td>"
                f"<td>{fmt_value(row['rbcam_overwrite'], 0)}/{fmt_value(row['rbcam_cache_miss'], 0)}</td>"
                "</tr>"
            )
        body.append("</table>")
        return "\n".join(body)

    html = [
        "<!doctype html>",
        "<meta charset=\"utf-8\">",
        f"<title>{title}</title>",
        "<style>",
        "body{font-family:Arial,sans-serif;margin:24px;max-width:1240px;color:#111}",
        "img{max-width:100%;border:1px solid #bbb;margin:6px 0 24px}",
        "table{border-collapse:collapse;margin:10px 0 28px;font-size:13px}",
        "th,td{border:1px solid #bbb;padding:5px 8px;text-align:right}",
        "th:first-child,td:first-child{text-align:left}",
        "code{background:#eee;padding:1px 4px}",
        "</style>",
        f"<h1>{title}</h1>",
        (
            "<p>Post-rbCAM groups use the histogram <code>delay-debug3</code> rbCAM "
            "egress-delay monitor; pre-rbCAM groups use <code>delay-hit-t</code>. "
            f"The green band marks the accepted delay window [{RBCAM_LEFT:.0f}, "
            f"{RBCAM_RIGHT:.0f}) cycles.</p>"
        ),
        "<h2>Periodic Mode 2 Rate Sweep</h2>",
        f"<img src=\"{rate_plot.name}\" alt=\"periodic rate delay group\">",
        table(summary["rate"]),
        "<h2>Header-Sync Multiplicity Sweep</h2>",
        f"<img src=\"{header_plot.name}\" alt=\"header-sync multiplicity delay group\">",
        table(summary["header_multiplicity"]),
    ]
    output.write_text("\n".join(html) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--date", default="20260502")
    parser.add_argument("--report-dir", type=Path, default=REPORT_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--stem-prefix", default="phase6_emulator_asic0_post_rbcam")
    parser.add_argument("--title-label", default="ASIC0 Emulator")
    parser.add_argument(
        "--hist-snoop-source",
        choices=("pre", "post"),
        default="post",
        help="Sets default delay window and labels for pre-rbCAM or post-rbCAM plots.",
    )
    parser.add_argument("--window-left", type=float, default=None)
    parser.add_argument("--window-right", type=float, default=None)
    parser.add_argument(
        "--reference-style",
        action="store_true",
        help="Render the screenshot-style 2x2 rate sheet and 1x4 multiplicity sheet.",
    )
    args = parser.parse_args()

    global RBCAM_LEFT, RBCAM_RIGHT, WINDOW_LABEL
    WINDOW_LABEL = "pre-rbCAM" if args.hist_snoop_source == "pre" else "post-rbCAM"
    if args.window_left is None:
        RBCAM_LEFT = 0.0 if args.hist_snoop_source == "pre" else 2000.0
    else:
        RBCAM_LEFT = args.window_left
    if args.window_right is None:
        RBCAM_RIGHT = 2000.0 if args.hist_snoop_source == "pre" else 3000.0
    else:
        RBCAM_RIGHT = args.window_right

    rate_hists = load_rate_hists(args.report_dir, args.date, args.stem_prefix)
    header_hists = load_header_hists(args.report_dir, args.date, args.stem_prefix)

    suffix = "_reference_style" if args.reference_style else ""
    rate_plot = args.out_dir / f"{args.stem_prefix}_rate_delay{suffix}_{args.date}.png"
    header_plot = args.out_dir / f"{args.stem_prefix}_header_multiplicity_delay{suffix}_{args.date}.png"
    summary_json = args.out_dir / f"{args.stem_prefix}_delay_summary{suffix}_{args.date}.json"
    summary_html = args.out_dir / f"{args.stem_prefix}_delay_groups{suffix}_{args.date}.html"

    if args.reference_style:
        render_reference_rate(rate_hists, rate_plot)
        render_reference_header(header_hists, header_plot)
    else:
        render_group(rate_hists, f"{args.title_label} {WINDOW_LABEL} Periodic Delay, Mode 2", rate_plot)
        render_group(header_hists, f"{args.title_label} {WINDOW_LABEL} Header-Sync Delay Multiplicity", header_plot)

    summary = {
        "rate": [hist.summary() for hist in rate_hists],
        "header_multiplicity": [hist.summary() for hist in header_hists],
    }
    args.out_dir.mkdir(parents=True, exist_ok=True)
    summary_json.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_html(rate_plot, header_plot, summary, summary_html, f"{args.title_label} {WINDOW_LABEL} Delay Histograms")

    for path in (rate_plot, header_plot, summary_json, summary_html):
        print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
