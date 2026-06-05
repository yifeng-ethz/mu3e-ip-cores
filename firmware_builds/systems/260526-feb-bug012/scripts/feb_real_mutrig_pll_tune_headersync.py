#!/usr/bin/env python3
"""Directed per-ASIC MuTRiG PLL/header-sync tuning sweep.

The lock metric is the real-MuTRiG Type1 header-sync delay histogram shape.
Unlocked candidates are broad/random. Locked candidates should have a compact
peak inside [0,1000] cycles after a fresh run sequence.
"""

from __future__ import annotations

import argparse
import csv
import json
import subprocess
import sys
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = Path(__file__).resolve().parents[4]
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

import feb_real_mutrig_per_asic_delay_scan as delay_scan  # noqa: E402
import feb_real_mutrig_type0_type1_scan as rate_scan  # noqa: E402


Candidate = tuple[str, int, int, int]


DEFAULT_CANDIDATES: dict[int, list[Candidate]] = {
    0: [
        ("zero", 0, 0, 0),
        ("default", 48, 20, 30),
        ("restore_hl40", 48, 20, 40),
        ("hl45", 48, 20, 45),
        ("hl50", 48, 20, 50),
        ("v18_hl40", 48, 18, 40),
        ("v22_hl40", 48, 22, 40),
        ("v24_hl40", 48, 24, 40),
        ("cnt45_v20_hl40", 45, 20, 40),
        ("cnt50_v20_hl40", 50, 20, 40),
    ],
    3: [
        ("zero", 0, 0, 0),
        ("default", 41, 10, 20),
        ("restore", 35, 12, 25),
        ("v08", 35, 8, 25),
        ("v10", 35, 10, 25),
        ("v14", 35, 14, 25),
        ("v16", 35, 16, 25),
        ("hl20", 35, 12, 20),
        ("hl30", 35, 12, 30),
        ("cnt33", 33, 12, 25),
        ("cnt37", 37, 12, 25),
    ],
    5: [
        ("zero", 0, 0, 0),
        ("default", 42, 20, 25),
        ("hl40", 42, 20, 40),
        ("hl50", 42, 20, 50),
        ("hl60_lane5_diag", 42, 20, 60),
        ("v16_hl60", 42, 16, 60),
        ("v18_hl60", 42, 18, 60),
        ("v22_hl60", 42, 22, 60),
        ("v24_hl60", 42, 24, 60),
        ("cnt40_v20_hl60", 40, 20, 60),
        ("cnt44_v20_hl60", 44, 20, 60),
    ],
}


def parse_candidates(raw: str) -> list[Candidate]:
    out: list[Candidate] = []
    for token in raw.split(","):
        token = token.strip()
        if not token:
            continue
        parts = token.split(":")
        if len(parts) != 4:
            raise argparse.ArgumentTypeError(
                "candidate must be label:cnt:vcodelay:hitlogic"
            )
        label, cnt, vcodelay, hitlogic = parts
        out.append((label, int(cnt, 0), int(vcodelay, 0), int(hitlogic, 0)))
    if not out:
        raise argparse.ArgumentTypeError("empty candidate list")
    return out


def candidate_list(asic: int, override: list[Candidate] | None) -> list[Candidate]:
    if override is not None:
        return override
    if asic not in DEFAULT_CANDIDATES:
        raise ValueError(f"no default candidate list for ASIC{asic}")
    return DEFAULT_CANDIDATES[asic]


def run_config(
    out_dir: Path,
    label: str,
    link: str,
    asics: str,
    tdctest_mask: int,
    cml_flush: bool,
    tdc_overrides: dict[int, dict[str, int]] | None = None,
) -> dict[str, Any]:
    log_path = out_dir / f"{label}.log"
    md_path = out_dir / f"{label}.md"
    json_path = out_dir / f"{label}.json"
    cmd = [
        sys.executable,
        str(delay_scan.CONFIG_RUNNER),
        "--link",
        str(link),
        "--sc-tool",
        str(delay_scan.SC_TOOL),
        "--bsp",
        str(delay_scan.BSP),
        "--smb3-xml",
        str(delay_scan.SMB3_XML),
        "--smb5-xml",
        str(delay_scan.SMB5_XML),
        "--asics",
        asics,
        "--channel-enable-mask",
        "0xffffffff",
        "--tdctest-channel-mask",
        f"0x{tdctest_mask:08x}",
        "--set-channel",
        "recv_all=1",
        "--set-channel",
        "cml_sc=0",
        "--allow-idle-after-config",
        "--output",
        str(md_path),
        "--json-output",
        str(json_path),
    ]
    for asic, fields in sorted((tdc_overrides or {}).items()):
        for name, value in sorted(fields.items()):
            cmd.extend(["--set-tdc", f"{asic}:{name}={value}"])
    if cml_flush:
        cmd.extend([
            "--cml-flush-after-config",
            "--cml-start-value",
            "0",
            "--cml-flush-value",
            "8",
            "--cml-final-value",
            "0",
        ])

    proc = subprocess.run(
        cmd,
        cwd=REPO_ROOT,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
    )
    log_path.write_text(proc.stdout)
    print(proc.stdout, end="")
    if proc.returncode != 0:
        raise RuntimeError(f"configuration {label} failed; see {log_path}")
    data = json.loads(json_path.read_text()) if json_path.exists() else {}
    return {
        "label": label,
        "log": str(log_path),
        "report": str(md_path),
        "json": str(json_path),
        "returncode": proc.returncode,
        "summary": data.get("summary"),
        "tdc_overrides": tdc_overrides or {},
    }


def score_summary(summary: dict[str, Any]) -> tuple[int, float, int, float]:
    total = int(summary.get("total", 0) or 0)
    width = summary.get("p05_p95_width_cycles")
    width_value = 9999.0 if width is None else float(width)
    in_frac = float(summary.get("window_fraction_0_1000", 0.0) or 0.0)
    peak_fraction = float(summary.get("peak_fraction", 0.0) or 0.0)
    locked = int(total >= 10_000 and width_value <= 160.0 and in_frac >= 0.98)
    # Sort descending: locked, tighter width, more total, peakier.
    return locked, -width_value, total, peak_fraction


def run_candidate(
    out_dir: Path,
    link: str,
    asic: int,
    candidate: Candidate,
    dwell_s: float,
    attempts: int,
    periodic_interval: int,
    pulse_high: int,
    multiplicity: int,
    header_delay: int,
    header_interval: int,
    header_ch: int,
    lvds_settle_s: float,
) -> dict[str, Any]:
    label, cnt, vcodelay, hitlogic = candidate
    safe_label = f"asic{asic}_{label}_cnt{cnt}_vco{vcodelay}_hl{hitlogic}"
    cfg = run_config(
        out_dir,
        f"configure_{safe_label}",
        link,
        str(asic),
        0xFFFFFFFF,
        True,
        {
            asic: {
                "vncnt": cnt,
                "vnvcodelay": vcodelay,
                "vnhitlogic": hitlogic,
            }
        },
    )
    lvds = delay_scan.soft_reset_lvds(link, lvds_settle_s)
    row = delay_scan.run_delay_window(
        link,
        asic,
        "headersync",
        dwell_s,
        attempts,
        periodic_interval,
        pulse_high,
        multiplicity,
        header_delay,
        header_interval,
        header_ch,
    )
    row["candidate"] = {
        "label": label,
        "vncnt": cnt,
        "vnvcodelay": vcodelay,
        "vnhitlogic": hitlogic,
    }
    row["config"] = cfg
    row["lvds_after_reset"] = lvds
    row["header_delay"] = header_delay
    row["header_interval"] = header_interval
    row["header_ch"] = header_ch
    locked, neg_width, total, peak_fraction = score_summary(row["summary"])
    row["score"] = {
        "locked": bool(locked),
        "sort_key": [locked, neg_width, total, peak_fraction],
    }
    summary = row["summary"]
    print(
        "# ASIC{asic} {label}: cnt={cnt} vco={vco} hl={hl} "
        "total={total} nz={nz}/256 peak={peak} p05p95={width} "
        "in0_1000={infrac:.3f}% locked={locked}".format(
            asic=asic,
            label=label,
            cnt=cnt,
            vco=vcodelay,
            hl=hitlogic,
            total=summary.get("total"),
            nz=summary.get("nonzero_bins"),
            peak=summary.get("peak_center_cycles"),
            width=summary.get("p05_p95_width_cycles"),
            infrac=100.0 * float(summary.get("window_fraction_0_1000", 0.0)),
            locked=int(bool(locked)),
        )
    )
    return row


def write_outputs(
    out_dir: Path,
    rows: list[dict[str, Any]],
    args_dict: dict[str, Any] | None = None,
    config_steps: list[dict[str, Any]] | None = None,
) -> None:
    artifact = {
        "kind": "real_mutrig_headersync_pll_tune",
        "args": args_dict or {},
        "config_steps": config_steps or [],
        "rows": rows,
    }
    (out_dir / "real_mutrig_headersync_pll_tune.json").write_text(
        json.dumps(artifact, indent=2, sort_keys=True) + "\n"
    )
    with (out_dir / "real_mutrig_headersync_pll_tune_summary.csv").open(
        "w", newline=""
    ) as f:
        writer = csv.writer(f, lineterminator="\n")
        writer.writerow([
            "asic",
            "label",
            "vncnt",
            "vnvcodelay",
            "vnhitlogic",
            "locked",
            "total",
            "nonzero_bins",
            "peak_center_cycles",
            "peak_fraction",
            "window_fraction_0_1000",
            "p05_p95_width_cycles",
        ])
        for row in rows:
            cand = row["candidate"]
            summary = row["summary"]
            writer.writerow([
                row["asic"],
                cand["label"],
                cand["vncnt"],
                cand["vnvcodelay"],
                cand["vnhitlogic"],
                int(row["score"]["locked"]),
                summary.get("total"),
                summary.get("nonzero_bins"),
                summary.get("peak_center_cycles"),
                summary.get("peak_fraction"),
                summary.get("window_fraction_0_1000"),
                summary.get("p05_p95_width_cycles"),
            ])


def parse_asics(text: str) -> list[int]:
    return delay_scan.parse_asics(text)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--link", default="2")
    parser.add_argument("--asics", type=parse_asics, default=parse_asics("0,3,5"))
    parser.add_argument("--candidate", action="append", type=parse_candidates, default=[])
    parser.add_argument("--dwell-s", type=float, default=0.7)
    parser.add_argument("--attempts", type=int, default=6)
    parser.add_argument("--periodic-interval", type=int, default=1250)
    parser.add_argument("--pulse-high", type=int, default=5)
    parser.add_argument("--multiplicity", type=int, default=1)
    parser.add_argument("--header-delay", type=int, default=300)
    parser.add_argument("--header-interval", type=int, default=1)
    parser.add_argument("--header-ch", type=int, default=1)
    parser.add_argument("--lvds-settle-s", type=float, default=1.0)
    parser.add_argument("--restore-all-default", action="store_true")
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    all_rows: list[dict[str, Any]] = []
    config_steps: list[dict[str, Any]] = []
    try:
        config_steps.append(
            run_config(args.out_dir, "configure_all_tdc_mask_off_start", args.link, "0-7", 0, False)
        )
        for idx, asic in enumerate(args.asics):
            overrides = args.candidate[idx] if idx < len(args.candidate) else None
            rows: list[dict[str, Any]] = []
            for candidate in candidate_list(asic, overrides):
                rows.append(
                    run_candidate(
                        args.out_dir,
                        args.link,
                        asic,
                        candidate,
                        args.dwell_s,
                        args.attempts,
                        args.periodic_interval,
                        args.pulse_high,
                        args.multiplicity,
                        args.header_delay,
                        args.header_interval,
                        args.header_ch,
                        args.lvds_settle_s,
                    )
                )
                write_outputs(args.out_dir, all_rows + rows)
            all_rows.extend(rows)
            config_steps.append(
                run_config(
                    args.out_dir,
                    f"configure_asic{asic}_tdc_mask_off_after_sweep",
                    args.link,
                    str(asic),
                    0,
                    False,
                )
            )
    finally:
        rate_scan.terminate_run(args.link)
        if args.restore_all_default:
            config_steps.append(
                run_config(
                    args.out_dir,
                    "configure_all_tdc_full32_default_restore",
                    args.link,
                    "0-7",
                    0xFFFFFFFF,
                    True,
                )
            )
            delay_scan.soft_reset_lvds(args.link, args.lvds_settle_s)

    write_outputs(
        args.out_dir,
        all_rows,
        {
            "link": args.link,
            "asics": args.asics,
            "dwell_s": args.dwell_s,
            "header_delay": args.header_delay,
            "header_interval": args.header_interval,
            "header_ch": args.header_ch,
        },
        config_steps,
    )

    for asic in args.asics:
        rows = [row for row in all_rows if row["asic"] == asic]
        if not rows:
            continue
        best = max(rows, key=lambda row: tuple(row["score"]["sort_key"]))
        cand = best["candidate"]
        summary = best["summary"]
        print(
            "# BEST ASIC{asic}: {label} cnt={cnt} vco={vco} hl={hl} "
            "locked={locked} total={total} peak={peak} p05p95={width}".format(
                asic=asic,
                label=cand["label"],
                cnt=cand["vncnt"],
                vco=cand["vnvcodelay"],
                hl=cand["vnhitlogic"],
                locked=int(best["score"]["locked"]),
                total=summary.get("total"),
                peak=summary.get("peak_center_cycles"),
                width=summary.get("p05_p95_width_cycles"),
            )
        )
    print(f"json={args.out_dir / 'real_mutrig_headersync_pll_tune.json'}")
    print(f"csv={args.out_dir / 'real_mutrig_headersync_pll_tune_summary.csv'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
