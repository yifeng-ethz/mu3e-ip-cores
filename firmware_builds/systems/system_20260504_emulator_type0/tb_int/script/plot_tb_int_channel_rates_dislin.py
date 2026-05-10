#!/usr/bin/env python3
"""DISLIN-aesthetic channel-rate plot for tb_int exported CSV records.

Metric definitions
------------------
  global channel = lane * 32 + channel when lane/ASIC is present and channel is
                   a local 0..31 MuTRiG channel; otherwise channel is treated
                   as an already-global channel number.
  rate_hz        = record_count(global channel) / observation_window_seconds

The renderer always enumerates the full 8-ASIC channel map:
  ASIC 0..7, local channel 0..31, global channel 0..255.

By default the observation window is derived from the span of abs_ts_a in the
kept CSV rows.  Use --duration-s to force a known acquisition window.
"""

from __future__ import annotations

import argparse
import csv
import fnmatch
import math
import sys
import time
import warnings
from dataclasses import dataclass
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import Rectangle  # noqa: E402

N_ASICS = 8
CHANNELS_PER_ASIC = 32
N_GLOBAL_CHANNELS = N_ASICS * CHANNELS_PER_ASIC
CHANNEL_MIN = 0
CHANNEL_MAX = N_GLOBAL_CHANNELS - 1
PS_PER_SECOND = 1_000_000_000_000.0

RUN_ORIGIN_FIELD = "run_origin"
CHANNEL_FIELD_CANDIDATES = ("global_channel", "channel", "key.channel")
LANE_FIELD_CANDIDATES = ("lane", "asic", "asic_id")
TIME_FIELD_CANDIDATES = (
    "abs_ts_a",
    "abs_ts_pre_rbcam",
    "abs_ts_post_rbcam",
    "abs_ts_feb_egress",
    "last_seen_abs_ts",
    "timestamp_ps",
    "time_ps",
)
AUTO_RECORD_CSVS = ("closed_records.csv", "pre_rbcam_records.csv")


@dataclass(frozen=True)
class RateProfile:
    case_name: str
    source_csv: Path
    time_column: str | None
    duration_s: float
    counts: list[int]
    row_count: int
    used_rows: int
    skipped_rows: int
    invalid_channel_rows: int
    bad_time_rows: int
    stable_skipped_rows: int

    @property
    def total_count(self) -> int:
        return sum(self.counts)

    @property
    def active_channels(self) -> int:
        return sum(1 for count in self.counts if count > 0)

    def rate_hz(self, global_channel: int) -> float:
        if self.duration_s <= 0.0:
            return 0.0
        return self.counts[global_channel] / self.duration_s

    def rates_hz(self) -> list[float]:
        return [self.rate_hz(ch) for ch in range(N_GLOBAL_CHANNELS)]

    def max_rate_hz(self) -> float:
        return max(self.rates_hz(), default=0.0)


def parse_int(text: str) -> int:
    text = text.strip()
    if not text:
        raise ValueError("empty integer field")
    try:
        return int(text, 0)
    except ValueError:
        return int(text, 16)


def pick_int(row: dict[str, str], candidates: tuple[str, ...]) -> int | None:
    for name in candidates:
        if name in row and row[name].strip():
            return parse_int(row[name])
    return None


def row_is_stable(row: dict[str, str]) -> bool:
    if RUN_ORIGIN_FIELD not in row or not row[RUN_ORIGIN_FIELD].strip():
        return False
    try:
        return parse_int(row[RUN_ORIGIN_FIELD]) == 1
    except ValueError:
        return False


def resolve_global_channel(row: dict[str, str], channel_mode: str) -> int:
    raw_channel = pick_int(row, CHANNEL_FIELD_CANDIDATES)
    if raw_channel is None:
        raise ValueError("missing channel field")

    raw_lane = pick_int(row, LANE_FIELD_CANDIDATES)
    if channel_mode == "global":
        global_channel = raw_channel
    elif channel_mode == "lane-local":
        if raw_lane is None:
            raise ValueError("missing lane/ASIC field")
        if not (0 <= raw_lane < N_ASICS and 0 <= raw_channel < CHANNELS_PER_ASIC):
            raise ValueError(f"lane-local channel out of range: lane={raw_lane}, channel={raw_channel}")
        global_channel = raw_lane * CHANNELS_PER_ASIC + raw_channel
    else:
        if raw_lane is not None and 0 <= raw_lane < N_ASICS and 0 <= raw_channel < CHANNELS_PER_ASIC:
            global_channel = raw_lane * CHANNELS_PER_ASIC + raw_channel
        else:
            global_channel = raw_channel

    if not (CHANNEL_MIN <= global_channel <= CHANNEL_MAX):
        raise ValueError(f"global channel out of range: {global_channel}")
    return global_channel


def discover_cases(sim_root: Path, cases_spec: str) -> list[Path]:
    sim_root = sim_root.resolve()
    if not sim_root.is_dir():
        raise FileNotFoundError(f"--sim-root not found: {sim_root}")
    all_dirs = sorted(d for d in sim_root.iterdir() if d.is_dir())
    if cases_spec.lower() == "all":
        return all_dirs
    patterns = [p.strip() for p in cases_spec.split(",") if p.strip()]
    matched: list[Path] = []
    seen: set[str] = set()
    for pattern in patterns:
        for d in all_dirs:
            if fnmatch.fnmatch(d.name, pattern) and d.name not in seen:
                matched.append(d)
                seen.add(d.name)
    return matched


def candidate_record_paths(case_dir: Path, record_csv: str) -> list[Path]:
    if record_csv == "auto":
        return [case_dir / name for name in AUTO_RECORD_CSVS]
    return [case_dir / record_csv]


def choose_time_column(fieldnames: list[str], requested: str, duration_s: float | None) -> str | None:
    fields = set(fieldnames)
    if requested != "auto":
        if requested not in fields:
            raise ValueError(f"missing requested time column: {requested}")
        return requested
    for name in TIME_FIELD_CANDIDATES:
        if name in fields:
            return name
    if duration_s is not None:
        return None
    raise ValueError("no timestamp column found; pass --duration-s or --time-column")


def load_profile(
    case_dir: Path,
    record_csv: str,
    stable_only: bool,
    channel_mode: str,
    time_column: str,
    duration_s: float | None,
) -> RateProfile | None:
    for csv_path in candidate_record_paths(case_dir, record_csv):
        if not csv_path.is_file():
            continue
        try:
            profile = load_profile_from_csv(
                case_dir=case_dir,
                csv_path=csv_path,
                stable_only=stable_only,
                channel_mode=channel_mode,
                time_column=time_column,
                duration_s=duration_s,
            )
        except ValueError as exc:
            warnings.warn(f"[skip] {case_dir.name}: {csv_path.name}: {exc}")
            continue
        if profile is not None:
            return profile
    warnings.warn(f"[skip] {case_dir.name}: no loadable record CSV")
    return None


def load_profile_from_csv(
    case_dir: Path,
    csv_path: Path,
    stable_only: bool,
    channel_mode: str,
    time_column: str,
    duration_s: float | None,
) -> RateProfile | None:
    with csv_path.open(newline="", encoding="utf-8") as fh:
        reader = csv.DictReader(fh)
        if reader.fieldnames is None:
            raise ValueError("missing CSV header")
        fields = set(reader.fieldnames)
        if not any(name in fields for name in CHANNEL_FIELD_CANDIDATES):
            raise ValueError("missing channel column")
        if stable_only and RUN_ORIGIN_FIELD not in fields:
            raise ValueError(f"--stable-only requested but {RUN_ORIGIN_FIELD} is missing")
        selected_time_column = choose_time_column(reader.fieldnames, time_column, duration_s)

        counts = [0] * N_GLOBAL_CHANNELS
        timestamps: list[int] = []
        row_count = 0
        used_rows = 0
        invalid_channel_rows = 0
        bad_time_rows = 0
        stable_skipped_rows = 0

        for row in reader:
            row_count += 1
            if stable_only and not row_is_stable(row):
                stable_skipped_rows += 1
                continue

            try:
                global_channel = resolve_global_channel(row, channel_mode)
            except ValueError:
                invalid_channel_rows += 1
                continue

            if duration_s is None:
                assert selected_time_column is not None
                try:
                    timestamps.append(parse_int(row[selected_time_column]))
                except (KeyError, ValueError):
                    bad_time_rows += 1
                    continue

            counts[global_channel] += 1
            used_rows += 1

    if used_rows == 0:
        return None

    if duration_s is not None:
        if duration_s <= 0.0:
            raise ValueError("--duration-s must be > 0")
        window_s = duration_s
    else:
        if len(timestamps) < 2:
            raise ValueError("need at least two timestamped rows or --duration-s")
        window_ps = max(timestamps) - min(timestamps)
        if window_ps <= 0:
            raise ValueError("timestamp span is zero; pass --duration-s")
        window_s = window_ps / PS_PER_SECOND

    skipped_rows = row_count - used_rows
    return RateProfile(
        case_name=case_dir.name,
        source_csv=csv_path,
        time_column=selected_time_column,
        duration_s=window_s,
        counts=counts,
        row_count=row_count,
        used_rows=used_rows,
        skipped_rows=skipped_rows,
        invalid_channel_rows=invalid_channel_rows,
        bad_time_rows=bad_time_rows,
        stable_skipped_rows=stable_skipped_rows,
    )


def rounded_rate_top(max_rate_khz: float, expected_rate_khz: float | None) -> float:
    ymax = max_rate_khz
    if expected_rate_khz is not None:
        ymax = max(ymax, expected_rate_khz)
    if ymax <= 0.0:
        return 1.0
    padded = ymax * 1.15
    if padded <= 1.0:
        step = 0.2
    elif padded <= 10.0:
        step = 1.0
    elif padded <= 100.0:
        step = 10.0
    elif padded <= 250.0:
        step = 25.0
    elif padded <= 500.0:
        step = 50.0
    elif padded <= 1000.0:
        step = 100.0
    else:
        step = 250.0
    return math.ceil(padded / step) * step


def ytick_values(y_top: float) -> list[float]:
    if y_top <= 1.0:
        step = 0.2
    elif y_top <= 10.0:
        step = 1.0
    elif y_top <= 100.0:
        step = 10.0
    elif y_top <= 250.0:
        step = 25.0
    elif y_top <= 500.0:
        step = 50.0
    else:
        step = 100.0
    ticks: list[float] = []
    v = 0.0
    while v <= y_top + step * 0.5:
        ticks.append(round(v, 6))
        v += step
    return ticks


def render_panel(
    fig: plt.Figure,
    rect: tuple[float, float, float, float],
    profile: RateProfile,
    title: str,
    subtitle: str,
    footer_fontsize: float,
    title_fontsize: float,
    expected_rate_hz: float | None,
) -> None:
    left, bottom, width, height = rect

    for ew, ew2, ec, lw in [
        (0.0, 0.0, "#9a9a9a", 0.9),
        (0.003, 0.004, "#d2d2d2", 0.45),
    ]:
        fig.add_artist(Rectangle(
            (left + ew * width, bottom + ew2 * height),
            width - 2 * ew * width,
            height - 2 * ew2 * height,
            transform=fig.transFigure,
            fill=False,
            edgecolor=ec,
            linewidth=lw,
        ))

    ax = fig.add_axes([left + 0.075 * width, bottom + 0.255 * height, 0.865 * width, 0.470 * height])
    channels = list(range(N_GLOBAL_CHANNELS))
    rates_khz = [rate / 1000.0 for rate in profile.rates_hz()]
    expected_rate_khz = None if expected_rate_hz is None else expected_rate_hz / 1000.0
    y_top = rounded_rate_top(max(rates_khz, default=0.0), expected_rate_khz)

    for asic in range(N_ASICS):
        if asic % 2 == 1:
            start = asic * CHANNELS_PER_ASIC
            stop = start + CHANNELS_PER_ASIC - 1
            ax.axvspan(start, stop, color="#f2f2f2", zorder=0)
        if asic > 0:
            ax.axvline(asic * CHANNELS_PER_ASIC - 0.5, color="#777777", linewidth=0.45, alpha=0.65, zorder=1)
        ax.text(
            asic * CHANNELS_PER_ASIC + 15.5,
            0.985,
            f"ASIC{asic}",
            transform=ax.get_xaxis_transform(),
            ha="center",
            va="top",
            fontsize=6,
            family="monospace",
            color="#555555",
        )

    ax.vlines(channels, [0.0] * N_GLOBAL_CHANNELS, rates_khz,
              color="#0066ff", linewidth=0.75, alpha=0.78, zorder=3)
    active_x = [ch for ch, count in enumerate(profile.counts) if count > 0]
    active_y = [rates_khz[ch] for ch in active_x]
    ax.scatter(active_x, active_y, s=5.0, color="#003c9e", linewidths=0.0, zorder=4)

    if expected_rate_khz is not None:
        ax.axhline(expected_rate_khz, color="#00a63b", linewidth=0.9, zorder=2)

    ax.set_xlim(float(CHANNEL_MIN), float(CHANNEL_MAX))
    ax.set_ylim(0.0, y_top)
    ax.set_xticks([0, 32, 64, 96, 128, 160, 192, 224, 255])
    ax.set_yticks(ytick_values(y_top))
    ax.grid(True, color="#000000", alpha=0.22, linewidth=0.50)
    ax.tick_params(axis="both", which="both", top=True, right=True,
                   labelsize=6, width=0.45, color="#666666", labelcolor="#555555")
    for spine in ax.spines.values():
        spine.set_linewidth(0.45)
        spine.set_color("#555555")
    ax.set_xlabel("global channel [0..255] = ASIC * 32 + local channel", fontsize=7.5, family="monospace")
    ax.set_ylabel("record rate [kHz/channel]", fontsize=7.5, family="monospace")

    fig.text(left + 0.5 * width, bottom + 0.840 * height, title,
             ha="center", va="center", fontsize=title_fontsize, family="monospace")
    fig.text(left + 0.5 * width, bottom + 0.792 * height, subtitle,
             ha="center", va="center", fontsize=max(footer_fontsize - 0.3, 4.5), family="monospace")

    expected_text = "none" if expected_rate_hz is None else f"{expected_rate_hz / 1000.0:.3f} kHz"
    time_column = profile.time_column if profile.time_column is not None else "duration override"
    footer_lines = [
        (f"source={profile.source_csv.name}, rows={profile.row_count}, used={profile.used_rows}, "
         f"skipped={profile.skipped_rows}, active={profile.active_channels}/256"),
        (f"window={profile.duration_s:.9f} s from {time_column}; "
         f"total={profile.total_count}, max={profile.max_rate_hz() / 1000.0:.6f} kHz, expected={expected_text}"),
        (f"invalid_channel={profile.invalid_channel_rows}, bad_time={profile.bad_time_rows}, "
         f"stable_filtered={profile.stable_skipped_rows}; x-range exactly 0..255"),
    ]
    footer_y = bottom + 0.130 * height
    for i, line in enumerate(footer_lines):
        fig.text(left + 0.075 * width, footer_y - i * 0.052 * height, line,
                 ha="left", va="center", fontsize=footer_fontsize, family="monospace")


def render_page(
    page_profiles: list[RateProfile],
    output: Path,
    title_tag: str,
    expected_rate_hz: float | None,
    panel_height: float = 3.1,
) -> None:
    n_rows = len(page_profiles)
    if n_rows == 0:
        return

    fig_width = 16.8
    fig_height = max(4.0, n_rows * panel_height + 0.6)
    fig = plt.figure(figsize=(fig_width, fig_height), facecolor="white")
    tag_text = f" ({title_tag})" if title_tag else ""
    fig.text(0.5, 0.985, f"tb_int Channel-Rate Contact Sheet{tag_text}",
             ha="center", va="top", fontsize=11, family="monospace", weight="bold")

    row_gap = 0.014
    top_margin, bottom_margin = 0.045, 0.012
    row_height = (1.0 - top_margin - bottom_margin - row_gap * (n_rows + 1)) / n_rows
    footer_fontsize = max(4.7, min(6.4, row_height * fig_height * 2.35))
    title_fontsize = max(5.2, min(7.8, row_height * fig_height * 2.85))

    for row_idx, profile in enumerate(page_profiles):
        row_bottom = bottom_margin + row_gap + (n_rows - 1 - row_idx) * (row_height + row_gap)
        render_panel(
            fig=fig,
            rect=(0.022, row_bottom, 0.956, row_height),
            profile=profile,
            title="tb_int channel rate: 8 ASICs x 32 channels",
            subtitle=f"case={profile.case_name}",
            footer_fontsize=footer_fontsize,
            title_fontsize=title_fontsize,
            expected_rate_hz=expected_rate_hz,
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(output, dpi=160, bbox_inches="tight")
    plt.close(fig)
    print(f"  wrote {output}", file=sys.stderr)


def paginate(
    profiles: list[RateProfile],
    out_dir: Path,
    rows_per_page: int,
    title_tag: str,
    expected_rate_hz: float | None,
) -> list[Path]:
    outputs: list[Path] = []
    n_pages = max(1, math.ceil(len(profiles) / rows_per_page))
    pad = len(str(n_pages))
    for page_idx in range(n_pages):
        chunk = profiles[page_idx * rows_per_page: (page_idx + 1) * rows_per_page]
        if not chunk:
            continue
        stem = "channel_rate_dislin" if n_pages == 1 else f"channel_rate_dislin_p{page_idx + 1:0{pad}d}"
        out_path = out_dir / f"{stem}.png"
        render_page(chunk, out_path, title_tag, expected_rate_hz)
        outputs.append(out_path)
    return outputs


def write_summary_csv(profiles: list[RateProfile], out_dir: Path) -> Path:
    out_path = out_dir / "channel_rate_summary.csv"
    fieldnames = [
        "case",
        "source_csv",
        "time_column",
        "duration_s",
        "global_channel",
        "asic",
        "channel",
        "count",
        "rate_hz",
        "rate_khz",
    ]
    out_dir.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=fieldnames)
        writer.writeheader()
        for profile in profiles:
            rates = profile.rates_hz()
            for global_channel in range(N_GLOBAL_CHANNELS):
                writer.writerow({
                    "case": profile.case_name,
                    "source_csv": str(profile.source_csv),
                    "time_column": profile.time_column or "",
                    "duration_s": f"{profile.duration_s:.12f}",
                    "global_channel": global_channel,
                    "asic": global_channel // CHANNELS_PER_ASIC,
                    "channel": global_channel % CHANNELS_PER_ASIC,
                    "count": profile.counts[global_channel],
                    "rate_hz": f"{rates[global_channel]:.9f}",
                    "rate_khz": f"{rates[global_channel] / 1000.0:.9f}",
                })
    return out_path


def main() -> int:
    t0 = time.monotonic()
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--sim-root", type=Path, required=True, metavar="DIR")
    parser.add_argument("--cases", default="all", metavar="SPEC",
                        help="Comma-separated glob patterns, or 'all'.")
    parser.add_argument("--out-dir", type=Path, required=True, metavar="DIR")
    parser.add_argument("--rows-per-page", type=int, default=4, metavar="N")
    parser.add_argument("--title-tag", default="", metavar="TEXT")
    parser.add_argument("--stable-only", action="store_true", default=False,
                        help="Only include rows where run_origin == 1.")
    parser.add_argument("--record-csv", default="closed_records.csv", metavar="NAME",
                        help="Per-case CSV filename, or 'auto' to prefer closed_records.csv then pre_rbcam_records.csv.")
    parser.add_argument("--channel-mode", choices=("auto", "lane-local", "global"), default="auto",
                        help="How to interpret CSV channel fields.")
    parser.add_argument("--time-column", default="auto", metavar="NAME",
                        help="Timestamp column in ps; default auto-selects abs_ts_a when present.")
    parser.add_argument("--duration-s", type=float, default=None, metavar="SECONDS",
                        help="Override observation window instead of deriving it from timestamp span.")
    parser.add_argument("--expected-rate-hz", type=float, default=None, metavar="HZ",
                        help="Optional horizontal reference line.")
    args = parser.parse_args()

    try:
        case_dirs = discover_cases(args.sim_root, args.cases)
    except FileNotFoundError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2
    if not case_dirs:
        print(f"ERROR: no matching case directories under {args.sim_root}", file=sys.stderr)
        return 2

    profiles: list[RateProfile] = []
    skipped = 0
    for case_dir in case_dirs:
        profile = load_profile(
            case_dir=case_dir,
            record_csv=args.record_csv,
            stable_only=args.stable_only,
            channel_mode=args.channel_mode,
            time_column=args.time_column,
            duration_s=args.duration_s,
        )
        if profile is None:
            skipped += 1
        else:
            profiles.append(profile)

    if skipped:
        print(f"Skipped {skipped} case(s).", file=sys.stderr)
    if not profiles:
        print("ERROR: no loadable channel-rate data.", file=sys.stderr)
        return 3

    print(f"Rendering {len(profiles)} case(s), {args.rows_per_page} rows/page.", file=sys.stderr)
    png_paths = paginate(
        profiles,
        out_dir=args.out_dir,
        rows_per_page=args.rows_per_page,
        title_tag=args.title_tag,
        expected_rate_hz=args.expected_rate_hz,
    )
    csv_path = write_summary_csv(profiles, args.out_dir)
    print(f"  wrote {csv_path}", file=sys.stderr)

    elapsed = time.monotonic() - t0
    print(f"\nDone. {len(png_paths)} page(s), {len(profiles)} case(s), {elapsed:.1f}s elapsed.")
    for p in png_paths:
        print(f"  {p}")
    print(f"  {csv_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
