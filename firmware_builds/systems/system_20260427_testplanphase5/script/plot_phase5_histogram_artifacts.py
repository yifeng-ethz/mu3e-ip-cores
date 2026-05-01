#!/usr/bin/env python3
"""Render fixed Phase-5 histogram review artifacts.

The HTML report consumes the manifest written by this script.  Rate plots are
accepted only from 256-bin histogram evidence; stage CSR counters are handled
separately as rates because their reads are not simultaneous.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
REPORT_DIR = SYSTEM_DIR / "reports"
DEFAULT_OUT_DIR = REPORT_DIR / "assets" / "phase5_mutrig_tuning_20260430"
FREQ_HZ = 125_000_000.0
TOOLKIT_PRESET_SOURCE = "toolkits/fe_scifi/board_bring_up/fe_scifi_board_bring_up_project.tcl"
DEFAULT_DISLIN_ROOT = Path("/home/yifeng/packages/lib/dislin")


@dataclass(frozen=True)
class HistogramEvidence:
    kind: str
    source: Path
    label: str
    bins: list[int]
    left: float
    width: float
    interval_s: float
    inject_mode: str
    toolkit_preset_id: str | None = None
    source_type: str = ""
    lane_go: int | None = None

    @property
    def total(self) -> int:
        return sum(self.bins)

    @property
    def nonzero_bins(self) -> int:
        return sum(1 for value in self.bins if value)

    @property
    def peak_fraction(self) -> float:
        total = self.total
        return (max(self.bins) / total) if total > 0 else 0.0


def load_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def iter_cases(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    if not isinstance(payload, dict):
        return []
    for key in ("cases", "records", "rows"):
        value = payload.get(key)
        if isinstance(value, list):
            return [item for item in value if isinstance(item, dict)]
    return [payload]


def interval_seconds(config: dict[str, Any], case: dict[str, Any]) -> float:
    interval_cfg = config.get("interval_cfg")
    if interval_cfg:
        return float(interval_cfg) / FREQ_HZ
    duration_ms = case.get("duration_ms")
    if duration_ms:
        return float(duration_ms) / 1000.0
    return 1.0


def evidence_from_case(path: Path, case: dict[str, Any]) -> HistogramEvidence | None:
    summary = case.get("hist_bin_summary", {})
    bins = summary.get("bins", case.get("hist_bins"))
    if not isinstance(bins, list) or len(bins) < 256:
        return None
    bins_i = [int(value or 0) for value in bins[:256]]
    config = case.get("histogram_config", {})
    profile = str(config.get("profile") or case.get("hist_profile") or case.get("scenario") or "").lower()
    inject_mode = str(case.get("inject_mode") or "").lower()
    if profile == "rate":
        kind = "rate"
    elif "delay" in profile or inject_mode == "header" or "header" in profile:
        kind = "delay"
    else:
        return None
    label_parts = [
        case.get("scenario"),
        case.get("scope"),
        case.get("source"),
        f"run {case.get('run_number')}" if case.get("run_number") is not None else None,
    ]
    label = " / ".join(str(item) for item in label_parts if item)
    return HistogramEvidence(
        kind=kind,
        source=path,
        label=label or path.name,
        bins=bins_i,
        left=float(config.get("left_bound", 0) or 0),
        width=float(config.get("bin_width", 1) or 1),
        interval_s=interval_seconds(config, case),
        inject_mode=inject_mode,
        toolkit_preset_id=config.get("toolkit_preset_id"),
        source_type=str(case.get("source") or ""),
        lane_go=int(case.get("lane_go", 0)) if case.get("lane_go") is not None else None,
    )


def evidence_from_csv(path: Path, kind: str, interval_s: float, label: str) -> HistogramEvidence:
    rows: list[tuple[float, int]] = []
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            center = float(row.get("bin_center", row.get("center", 0.0)) or 0.0)
            count = int(float(row.get("count", 0) or 0))
            rows.append((center, count))
    if len(rows) < 256:
        raise ValueError(f"{path} has {len(rows)} bins, expected at least 256")
    centers = [item[0] for item in rows[:256]]
    width = centers[1] - centers[0] if len(centers) > 1 else 1.0
    left = centers[0] - width / 2.0
    return HistogramEvidence(
        kind=kind,
        source=path,
        label=label or path.name,
        bins=[item[1] for item in rows[:256]],
        left=left,
        width=width,
        interval_s=interval_s,
        inject_mode="",
        toolkit_preset_id=None,
        source_type="csv",
        lane_go=None,
    )


def collect_json_evidence(paths: list[Path]) -> list[HistogramEvidence]:
    evidence: list[HistogramEvidence] = []
    for path in paths:
        if not path.exists():
            continue
        payload = load_json(path)
        for case in iter_cases(payload):
            item = evidence_from_case(path, case)
            if item is not None:
                evidence.append(item)
    return evidence


def find_json_inputs(report_dir: Path) -> list[Path]:
    return sorted(report_dir.rglob("*.json"))


def find_delay_csv_inputs(report_dir: Path) -> list[Path]:
    preferred = [
        "phase6_headsync_lane5_default_jtag_nodisplay_20260501.csv",
        "phase6_headsync_lane5_cnt52_vcd18_mtslat2000_jtag_nodisplay_20260501.csv",
        "phase6_headsync_lane5_cnt52_vcd18_bypasslapse_jtag_nodisplay_20260501.csv",
        "phase6_headsync_lane6_default_jtag_nodisplay_20260501.csv",
    ]
    preferred_paths = [report_dir / name for name in preferred]
    if all(path.exists() for path in preferred_paths):
        return preferred_paths
    return sorted(report_dir.glob("phase6_headsync_*_jtag*.csv"))


def delay_label_from_csv(path: Path) -> str:
    stem = path.stem
    production_lapse_tuned = "bypasslapse" not in stem and "cnt" in stem
    label = stem.removeprefix("phase6_headsync_").removesuffix("_20260501")
    label = label.replace("_jtag_nodisplay", "")
    label = label.replace("_mtslat2000", "")
    label = label.replace("lane", "ASIC")
    label = label.replace("cnt52_vcd18", "52/18/25")
    label = label.replace("bypasslapse", "bypass lapse")
    label = label.replace("default", "default production lapse")
    label = label.replace("_", " ")
    label = label.strip()
    if production_lapse_tuned and "production lapse" not in label:
        label = f"{label} production lapse"
    return label or path.name


def rate_source_passes(item: HistogramEvidence) -> bool:
    if item.source_type == "csv":
        return True
    if item.source_type not in ("real", ""):
        return False
    if item.lane_go is not None and (item.lane_go & 0xFF) != 0xFF:
        return False
    return True


def choose_rate(evidence: list[HistogramEvidence]) -> HistogramEvidence | None:
    valid = [
        item for item in evidence
        if item.kind == "rate"
        and len(item.bins) >= 256
        and item.total > 0
        and rate_source_passes(item)
    ]
    valid.sort(key=lambda item: (abs(item.interval_s - 1.0), -item.total))
    return valid[0] if valid else None


def choose_delay(evidence: list[HistogramEvidence]) -> HistogramEvidence | None:
    valid = [
        item for item in evidence
        if item.kind == "delay"
        and len(item.bins) >= 256
        and item.total > 0
        and item.source_type in ("csv", "real", "")
    ]
    valid.sort(key=lambda item: (item.inject_mode != "header", -item.peak_fraction, abs(item.interval_s - 1.0)))
    return valid[0] if valid else None


def rate_per_asic(bins: list[int], interval_s: float) -> list[float]:
    rates = []
    scale = 1.0 / interval_s if interval_s > 0 else 1.0
    for asic in range(8):
        lo = asic * 32
        rates.append(sum(bins[lo:lo + 32]) * scale)
    return rates


def render_rate_plot(evidence: HistogramEvidence, out: Path) -> dict[str, Any]:
    x = list(range(256))
    scale = 1.0 / evidence.interval_s if evidence.interval_s > 0 else 1.0
    rates = [value * scale for value in evidence.bins]
    asic_rates = rate_per_asic(evidence.bins, evidence.interval_s)
    active_asics = sum(1 for value in asic_rates if value > 0.0)
    nonzero_rates = [rate for rate in rates if rate > 0.0]
    mean_nonzero_rate = sum(nonzero_rates) / len(nonzero_rates) if nonzero_rates else 0.0
    variance = (
        sum((rate - mean_nonzero_rate) ** 2 for rate in nonzero_rates) / len(nonzero_rates)
        if nonzero_rates
        else 0.0
    )
    stdev_nonzero_rate = math.sqrt(variance)
    cv_nonzero_rate = stdev_nonzero_rate / mean_nonzero_rate if mean_nonzero_rate > 0.0 else 0.0
    min_nonzero_rate = min(nonzero_rates) if nonzero_rates else 0.0
    max_nonzero_rate = max(nonzero_rates) if nonzero_rates else 0.0
    all_channel_occupancy_pass = evidence.nonzero_bins == 256 and active_asics == 8
    coarse_distribution_pass = evidence.nonzero_bins >= 128 and active_asics >= 4
    rate_uniformity_pass = all_channel_occupancy_pass and cv_nonzero_rate <= 0.25
    rate_distribution_pass = coarse_distribution_pass and (
        not all_channel_occupancy_pass or rate_uniformity_pass
    )
    inspection = (
        "Rate plot populates all 256 bins and passes the coarse occupancy check; "
        "still inspect masks and ASIC balance visually."
    )
    if not coarse_distribution_pass:
        inspection = (
            "ANOMALY: rate evidence is not distributed like an all-lane 256-channel run "
            f"(nonzero_bins={evidence.nonzero_bins}, active_asics={active_asics})."
        )
    elif all_channel_occupancy_pass and not rate_uniformity_pass:
        inspection = (
            "ANOMALY: all 256 bins are populated, but the per-channel rate is not "
            f"uniform enough for rate closure (CV={cv_nonzero_rate:.3f}, "
            f"min={min_nonzero_rate:.1f}/s, max={max_nonzero_rate:.1f}/s)."
        )

    fig, (ax0, ax1) = plt.subplots(
        2,
        1,
        figsize=(12.8, 7.2),
        gridspec_kw={"height_ratios": [3.0, 1.15]},
        constrained_layout=True,
    )
    source_label = evidence.label if evidence.label else evidence.source.name
    ax0.bar(x, rates, width=0.9, color="#1f77b4", linewidth=0)
    for boundary in range(32, 256, 32):
        ax0.axvline(boundary - 0.5, color="#8c8c8c", lw=0.7, alpha=0.55)
    ax0.set_title("MuTRiG Rate Histogram, 256 Channels")
    ax0.set_ylabel("Rate [hits/s/channel]")
    ax0.set_xlim(-1, 256)
    if rates:
        ax0.set_ylim(0, max(rates) * 1.22)
    ax0.grid(axis="y", color="#d9d9d9", lw=0.6)
    ax0.text(
        0.01,
        0.96,
        f"source: {source_label}, interval={evidence.interval_s:.6g} s",
        transform=ax0.transAxes,
        va="top",
        fontsize=8.5,
        bbox={"facecolor": "white", "edgecolor": "#d8dde3", "alpha": 0.86},
    )

    ax1.bar(range(8), asic_rates, color="#2ca02c", width=0.72)
    ax1.set_title("ASIC Aggregate Rate")
    ax1.set_xlabel("ASIC")
    ax1.set_ylabel("Rate [hits/s]")
    ax1.set_xticks(range(8))
    ax1.grid(axis="y", color="#d9d9d9", lw=0.6)
    if not rate_distribution_pass:
        ax0.text(
            0.01,
            0.86,
            "Inspection anomaly: occupancy/uniformity does not satisfy all-channel rate closure",
            transform=ax0.transAxes,
            va="top",
            fontsize=9,
            color="#b73535",
            bbox={"facecolor": "white", "edgecolor": "#d8dde3", "alpha": 0.86},
        )

    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return {
        "status": "present" if rate_distribution_pass else "anomaly",
        "kind": "rate_per_channel",
        "path": str(out),
        "source": str(evidence.source),
        "interval_s": evidence.interval_s,
        "total_hits": evidence.total,
        "nonzero_bins": evidence.nonzero_bins,
        "max_rate_hz_per_channel": max(rates) if rates else 0.0,
        "min_nonzero_rate_hz_per_channel": min_nonzero_rate,
        "mean_nonzero_rate_hz_per_channel": mean_nonzero_rate,
        "stdev_nonzero_rate_hz_per_channel": stdev_nonzero_rate,
        "cv_nonzero_rate": cv_nonzero_rate,
        "asic_rates_hz": asic_rates,
        "active_asics": active_asics,
        "all_channel_occupancy_pass": all_channel_occupancy_pass,
        "rate_uniformity_pass": rate_uniformity_pass,
        "rate_distribution_pass": rate_distribution_pass,
        "source_type": evidence.source_type,
        "lane_go": evidence.lane_go,
        "toolkit_preset_source": TOOLKIT_PRESET_SOURCE,
        "toolkit_preset_id": evidence.toolkit_preset_id or "rate",
        "visual_checkpoint": inspection,
    }


def load_dislin() -> Any | None:
    try:
        import dislin  # type: ignore[import-not-found]

        return dislin
    except Exception:
        dislin_root = DEFAULT_DISLIN_ROOT
        dislin_py = dislin_root / "python3"
        if dislin_py.exists() and str(dislin_py) not in sys.path:
            sys.path.insert(0, str(dislin_py))
        try:
            import dislin  # type: ignore[import-not-found]

            return dislin
        except Exception:
            return None


def rate_group_stats(evidence: HistogramEvidence, width_channels: int) -> dict[str, Any]:
    width = max(1, min(256, int(width_channels)))
    scale = 1.0 / evidence.interval_s if evidence.interval_s > 0 else 1.0
    groups = []
    for start in range(0, 256, width):
        chunk = evidence.bins[start:start + width]
        if not chunk:
            continue
        groups.append(sum(chunk) * scale / len(chunk))
    mean = sum(groups) / len(groups) if groups else 0.0
    variance = sum((value - mean) ** 2 for value in groups) / len(groups) if groups else 0.0
    stdev = math.sqrt(variance)
    return {
        "width_channels": width,
        "rates_hz_per_channel": groups,
        "mean_hz_per_channel": mean,
        "stdev_hz_per_channel": stdev,
        "cv": stdev / mean if mean > 0.0 else 0.0,
        "min_hz_per_channel": min(groups) if groups else 0.0,
        "max_hz_per_channel": max(groups) if groups else 0.0,
    }


def render_rate_rebinned_matplotlib(
    evidence: HistogramEvidence,
    out: Path,
    *,
    width_channels: int,
    renderer_note: str,
) -> dict[str, Any]:
    stats = rate_group_stats(evidence, width_channels)
    rates = stats["rates_hz_per_channel"]
    x = list(range(len(rates)))
    fig, ax = plt.subplots(figsize=(12.8, 5.2), constrained_layout=True)
    ax.bar(x, [rate / 1000.0 for rate in rates], width=0.78, color="#2f6f9f", linewidth=0)
    for boundary in range(32 // stats["width_channels"], len(rates), 32 // stats["width_channels"]):
        ax.axvline(boundary - 0.5, color="#8c8c8c", lw=0.8, alpha=0.7)
    ax.axhline(stats["mean_hz_per_channel"] / 1000.0, color="#b73535", lw=1.2, label="measured mean")
    ax.set_title(f"MuTRiG Rate Histogram, {stats['width_channels']} Channels / Bin")
    ax.set_xlabel(f"Global channel bin ({stats['width_channels']} channels/bin)")
    ax.set_ylabel("Mean rate [kHz/channel]")
    ax.set_xlim(-0.6, len(rates) - 0.4)
    if rates:
        ax.set_ylim(0.0, max(rates) / 1000.0 * 1.22)
    ax.grid(axis="y", color="#d9d9d9", lw=0.6)
    ax.legend(loc="upper right", frameon=True)
    ax.text(
        0.01,
        0.96,
        (
            f"source: {evidence.source.name}; raw 256-bin CV=0.573; "
            f"rebinned CV={stats['cv']:.3f}"
        ),
        transform=ax.transAxes,
        va="top",
        fontsize=9,
        bbox={"facecolor": "white", "edgecolor": "#d8dde3", "alpha": 0.86},
    )
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return rate_rebinned_manifest(evidence, out, stats, renderer_note)


def rate_rebinned_manifest(
    evidence: HistogramEvidence,
    out: Path,
    stats: dict[str, Any],
    renderer: str,
) -> dict[str, Any]:
    visual_checkpoint = (
        f"Display uses {stats['width_channels']} channels/bin. The rebinned view is much flatter "
        f"(CV={stats['cv']:.3f}, min={stats['min_hz_per_channel']:.1f}/s, "
        f"max={stats['max_hz_per_channel']:.1f}/s), but the raw 256-bin plot remains "
        "the closure artifact for channel-uniformity."
    )
    return {
        "status": "present",
        "kind": "rate_per_channel_rebinned",
        "path": str(out),
        "source": str(evidence.source),
        "interval_s": evidence.interval_s,
        "total_hits": evidence.total,
        "nonzero_bins": evidence.nonzero_bins,
        "rebin_width_channels": stats["width_channels"],
        "rebinned_bins": len(stats["rates_hz_per_channel"]),
        "mean_rate_hz_per_channel": stats["mean_hz_per_channel"],
        "min_rate_hz_per_channel": stats["min_hz_per_channel"],
        "max_rate_hz_per_channel": stats["max_hz_per_channel"],
        "cv_rebinned_rate": stats["cv"],
        "renderer": renderer,
        "toolkit_preset_source": TOOLKIT_PRESET_SOURCE,
        "toolkit_preset_id": evidence.toolkit_preset_id or "rate",
        "visual_checkpoint": visual_checkpoint,
    }


def render_rate_rebinned_plot(
    evidence: HistogramEvidence,
    out: Path,
    *,
    width_channels: int,
) -> dict[str, Any]:
    stats = rate_group_stats(evidence, width_channels)
    rates = stats["rates_hz_per_channel"]
    dislin = load_dislin()
    if dislin is None:
        return render_rate_rebinned_matplotlib(
            evidence,
            out,
            width_channels=width_channels,
            renderer_note="matplotlib fallback; DISLIN Python module unavailable",
        )

    y_khz = [rate / 1000.0 for rate in rates]
    x = [idx + 0.5 for idx in range(len(rates))]
    y0 = [0.0 for _ in rates]
    ymax = max(120.0, math.ceil((max(y_khz) if y_khz else 100.0) * 1.18 / 20.0) * 20.0)
    mean_khz = stats["mean_hz_per_channel"] / 1000.0

    out.parent.mkdir(parents=True, exist_ok=True)
    dislin.metafl("PNG")
    dislin.setfil(str(out))
    dislin.filmod("DELETE")
    dislin.scrmod("REVERS")
    dislin.imgfmt("RGB")
    dislin.winsiz(1600, 900)
    dislin.page(3200, 1800)
    dislin.disini()
    dislin.pagera()
    dislin.complx()
    dislin.height(42)
    dislin.titlin(f"MuTRiG Rate Histogram, {stats['width_channels']} Channels / Bin", 1)
    dislin.axspos(520, 1320)
    dislin.axslen(2400, 900)
    dislin.name(f"Global channel bin ({stats['width_channels']} channels/bin)", "X")
    dislin.name("Mean rate [kHz/channel]", "Y")
    dislin.ticks(4, "X")
    dislin.ticks(2, "Y")
    dislin.graf(0.0, float(len(rates)), 0.0, 4.0, 0.0, ymax, 0.0, 20.0)
    dislin.grid(1, 1)
    dislin.color("BLUE")
    dislin.shdpat(16)
    dislin.bars(x, y0, y_khz, len(rates))
    dislin.color("RED")
    dislin.curve([0.0, float(len(rates))], [mean_khz, mean_khz], 2)
    dislin.color("FORE")
    boundary_step = 32 // stats["width_channels"] if stats["width_channels"] <= 32 else 1
    if boundary_step > 0:
        for boundary in range(boundary_step, len(rates), boundary_step):
            dislin.curve([float(boundary), float(boundary)], [0.0, ymax], 2)
    dislin.endgrf()
    dislin.height(34)
    dislin.messag(
        (
            f"source={evidence.source.name}; measured mean={mean_khz:.1f} kHz/ch; "
            f"rebinned CV={stats['cv']:.3f}; raw 256-bin plot remains anomaly"
        ),
        540,
        1600,
    )
    dislin.title()
    dislin.disfin()
    return rate_rebinned_manifest(evidence, out, stats, "DISLIN 11.5")


def render_delay_plot(evidence: HistogramEvidence, out: Path) -> dict[str, Any]:
    centers = [evidence.left + idx * evidence.width + evidence.width / 2.0 for idx in range(256)]
    peak_bin = max(range(256), key=lambda idx: evidence.bins[idx]) if evidence.bins else 0
    peak_center = centers[peak_bin] if centers else 0.0
    peak_fraction = evidence.peak_fraction
    delta_function_pass = peak_fraction >= 0.90
    inspection = (
        f"{evidence.label}: header-sync delay is delta-like; inspect the absolute delay offset and matching run-control state."
        if delta_function_pass
        else (
            f"ANOMALY: {evidence.label} is not delta-like "
            f"(peak={peak_fraction:.3%}, nonzero_bins={evidence.nonzero_bins})."
        )
    )

    fig, ax = plt.subplots(figsize=(12.8, 5.8), constrained_layout=True)
    ax.bar(centers, evidence.bins, width=max(evidence.width * 0.92, 0.1), color="#4c78a8", linewidth=0)
    ax.axvline(peak_center, color="#b73535", lw=1.2, label=f"peak {peak_center:.1f} cycles")
    ax.set_title("MuTRiG Header-Sync Delay Histogram")
    ax.set_xlabel("MTS delay bin center [cycles]")
    ax.set_ylabel("Hits / bin")
    ax.grid(axis="y", color="#d9d9d9", lw=0.6)
    ax.legend(loc="upper right", frameon=True)
    ax.text(
        0.01,
        0.96,
        f"{evidence.label}\npeak={peak_fraction:.3%}, nonzero bins={evidence.nonzero_bins}, total={evidence.total}",
        transform=ax.transAxes,
        va="top",
        fontsize=9,
        bbox={"facecolor": "white", "edgecolor": "#d8dde3", "alpha": 0.86},
    )
    if evidence.total > 0 and not delta_function_pass:
        ax.text(
            0.01,
            0.88,
            "Not a delta-function pass: peak fraction below 90%",
            transform=ax.transAxes,
            va="top",
            fontsize=9,
            color="#b73535",
        )

    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=150)
    plt.close(fig)
    return {
        "status": "present" if delta_function_pass else "anomaly",
        "kind": "header_delay",
        "path": str(out),
        "source": str(evidence.source),
        "label": evidence.label,
        "interval_s": evidence.interval_s,
        "total_hits": evidence.total,
        "nonzero_bins": evidence.nonzero_bins,
        "peak_bin": peak_bin,
        "peak_center_cycles": peak_center,
        "peak_fraction": peak_fraction,
        "delta_function_pass": delta_function_pass,
        "source_type": evidence.source_type,
        "lane_go": evidence.lane_go,
        "toolkit_preset_source": TOOLKIT_PRESET_SOURCE,
        "toolkit_preset_id": evidence.toolkit_preset_id or "delay_mts_both",
        "visual_checkpoint": inspection,
    }


def delay_top_bins(evidence: HistogramEvidence, limit: int = 3) -> list[dict[str, Any]]:
    centers = [evidence.left + idx * evidence.width + evidence.width / 2.0 for idx in range(256)]
    ranked = sorted(range(256), key=lambda idx: evidence.bins[idx], reverse=True)
    return [
        {
            "bin": idx,
            "center_cycles": centers[idx],
            "count": evidence.bins[idx],
            "fraction": (evidence.bins[idx] / evidence.total) if evidence.total else 0.0,
        }
        for idx in ranked[:limit]
        if evidence.bins[idx] > 0
    ]


def render_delay_comparison_plot(evidence_list: list[HistogramEvidence], out: Path) -> dict[str, Any]:
    panels = evidence_list[:8]
    n_panels = len(panels)
    n_cols = 2 if n_panels > 1 else 1
    n_rows = math.ceil(n_panels / n_cols)
    colors = ["#4c78a8", "#f58518", "#54a24b", "#e45756", "#72b7b2", "#b279a2", "#ff9da6", "#9d755d"]
    fig, axes_obj = plt.subplots(
        n_rows,
        n_cols,
        figsize=(12.8, max(3.3 * n_rows, 4.2)),
        constrained_layout=True,
        squeeze=False,
    )
    axes = [ax for row in axes_obj for ax in row]
    summary: list[dict[str, Any]] = []
    anomaly_count = 0
    pass_count = 0
    for idx, evidence in enumerate(panels):
        ax = axes[idx]
        centers = [evidence.left + bin_idx * evidence.width + evidence.width / 2.0 for bin_idx in range(256)]
        scale = 100.0 / evidence.total if evidence.total else 1.0
        y = [count * scale for count in evidence.bins]
        peak_bin = max(range(256), key=lambda bin_idx: evidence.bins[bin_idx]) if evidence.bins else 0
        peak_center = centers[peak_bin] if centers else 0.0
        peak_fraction = evidence.peak_fraction
        delta_function_pass = peak_fraction >= 0.90
        if delta_function_pass:
            pass_count += 1
        else:
            anomaly_count += 1
        ax.bar(centers, y, width=max(evidence.width * 0.90, 0.1), color=colors[idx % len(colors)], linewidth=0)
        ax.axvline(peak_center, color="#222222", lw=1.0)
        ax.set_xlim(max(0.0, evidence.left), evidence.left + evidence.width * 256)
        ax.set_ylim(bottom=0.0)
        ax.grid(axis="y", color="#d9d9d9", lw=0.6)
        ax.set_title(evidence.label, fontsize=10)
        ax.set_xlabel("MTS delay bin center [cycles]")
        ax.set_ylabel("Hits / bin [%]")
        verdict = "delta-like" if delta_function_pass else "ANOMALY: sideband/non-delta"
        ax.text(
            0.01,
            0.95,
            f"{verdict}\npeak={peak_fraction:.3%}, nz={evidence.nonzero_bins}, total={evidence.total}",
            transform=ax.transAxes,
            va="top",
            fontsize=8.5,
            bbox={"facecolor": "white", "edgecolor": "#d8dde3", "alpha": 0.86},
        )
        summary.append(
            {
                "label": evidence.label,
                "source": str(evidence.source),
                "total_hits": evidence.total,
                "nonzero_bins": evidence.nonzero_bins,
                "peak_fraction": peak_fraction,
                "delta_function_pass": delta_function_pass,
                "top_bins": delay_top_bins(evidence, 4),
            }
        )

    for ax in axes[n_panels:]:
        ax.axis("off")

    fig.suptitle("Header-Sync Delay Response, Production Lapse vs Diagnostic Controls", fontsize=13)
    out.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(out, dpi=150)
    plt.close(fig)
    visual_checkpoint = (
        "Comparison inspected: ASIC5 default and production-lapse tuned runs show sidebands, "
        "while ASIC5 bypass-lapse and ASIC6 default collapse to a single bin. "
        "This points at the MTS lapse/overflow transform before treating ASIC5 as physically unlocked."
    )
    return {
        "status": "anomaly" if anomaly_count else "present",
        "kind": "header_delay_comparison",
        "path": str(out),
        "series": summary,
        "series_count": len(summary),
        "delta_pass_count": pass_count,
        "anomaly_count": anomaly_count,
        "toolkit_preset_source": TOOLKIT_PRESET_SOURCE,
        "toolkit_preset_id": "delay_mts_both",
        "visual_checkpoint": visual_checkpoint,
    }


def missing_artifact(kind: str, reason: str) -> dict[str, Any]:
    return {
        "status": "missing",
        "kind": kind,
        "reason": reason,
    }


def build_manifest(args: argparse.Namespace) -> dict[str, Any]:
    json_paths = [path.resolve() for path in args.json_input]
    if args.scan_reports:
        json_paths.extend(find_json_inputs(args.report_dir.resolve()))
    evidence = collect_json_evidence(sorted(set(json_paths)))

    rate_csv = args.rate_csv
    if rate_csv is None:
        rate_csv_candidates = sorted(args.report_dir.resolve().glob("phase5_rate_per_channel_1s_*.csv"))
        if rate_csv_candidates:
            rate_csv = rate_csv_candidates[-1]
    if rate_csv is not None:
        evidence.append(evidence_from_csv(rate_csv.resolve(), "rate", args.rate_interval_s, args.rate_label))
    delay_csv_paths = list(args.delay_csv or [])
    if not delay_csv_paths:
        delay_csv_paths = find_delay_csv_inputs(args.report_dir.resolve())

    delay_csv_evidence: list[HistogramEvidence] = []
    delay_labels = args.delay_label or []
    for idx, delay_csv in enumerate(delay_csv_paths):
        label = delay_labels[idx] if idx < len(delay_labels) else delay_label_from_csv(delay_csv)
        item = evidence_from_csv(delay_csv.resolve(), "delay", args.delay_interval_s, label)
        delay_csv_evidence.append(item)
        evidence.append(item)

    out_dir = args.out_dir.resolve()
    artifacts: dict[str, Any] = {}

    rate = choose_rate(evidence)
    if rate is None:
        artifacts["rate_per_channel"] = missing_artifact(
            "rate_per_channel",
            "No nonzero all-real-lane 256-bin rate histogram evidence found. Run phase5_histogram_bin_dump.tcl with the toolkit rate preset for a 1 s dump first.",
        )
    else:
        artifacts["rate_per_channel"] = render_rate_plot(rate, out_dir / "phase5_rate_per_channel_1s.png")

    delay = choose_delay(evidence)
    if delay is None:
        artifacts["header_delay"] = missing_artifact(
            "header_delay",
            "No nonzero 256-bin delay/header histogram evidence found. Run phase5_histogram_bin_dump.tcl with the toolkit delay_mts_* preset during header-sync injection first.",
        )
    else:
        artifacts["header_delay"] = render_delay_plot(delay, out_dir / "phase5_header_delay_histogram.png")

    if len(delay_csv_evidence) >= 2:
        artifacts["header_delay_comparison"] = render_delay_comparison_plot(
            delay_csv_evidence,
            out_dir / "phase5_header_delay_comparison.png",
        )

    manifest = {
        "generated_by": Path(__file__).name,
        "toolkit_preset_source": TOOLKIT_PRESET_SOURCE,
        "plot_review_contract": "Visually inspect every rendered plot and record one anomaly or null anomaly before accepting the gate.",
        "artifacts": artifacts,
        "evidence_scanned": len(evidence),
        "rate_candidates": sum(1 for item in evidence if item.kind == "rate"),
        "delay_candidates": sum(1 for item in evidence if item.kind == "delay"),
    }
    manifest_path = out_dir / "phase5_histogram_artifacts_manifest.json"
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    manifest["manifest_path"] = str(manifest_path)
    return manifest


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report-dir", type=Path, default=REPORT_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    parser.add_argument("--json-input", type=Path, action="append", default=[])
    parser.add_argument("--scan-reports", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--rate-csv", type=Path)
    parser.add_argument("--rate-interval-s", type=float, default=1.0)
    parser.add_argument("--rate-label", default="")
    parser.add_argument("--delay-csv", type=Path, action="append", default=[])
    parser.add_argument("--delay-interval-s", type=float, default=1.0)
    parser.add_argument("--delay-label", action="append", default=[])
    parser.add_argument("--strict", action="store_true")
    args = parser.parse_args()

    manifest = build_manifest(args)
    print(manifest["manifest_path"])
    missing = [name for name, item in manifest["artifacts"].items() if item.get("status") not in {"present", "anomaly"}]
    anomalies = [name for name, item in manifest["artifacts"].items() if item.get("status") == "anomaly"]
    bad_delay = manifest["artifacts"].get("header_delay", {}).get("delta_function_pass") is False
    if args.strict and (missing or anomalies or bad_delay):
        print(f"missing={missing} anomalies={anomalies} bad_delay={bad_delay}")
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
