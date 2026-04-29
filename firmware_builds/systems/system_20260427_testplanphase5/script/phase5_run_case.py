#!/usr/bin/env python3
"""Plan or execute one Phase-5 board-test case from the Markdown scoreboard."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Any

from phase5_case_catalog import CaseManifest, DEFAULT_DOC_DIR, load_catalog, manifest_to_dict, parse_lane_list


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
SIGNALTAP_DIR = SYSTEM_DIR / "signaltap"
CAPTURES_DIR = SYSTEM_DIR / "captures"
REPORTS_DIR = SYSTEM_DIR / "reports"


@dataclass(frozen=True)
class TapDefinition:
    tap_id: str
    signal_set: str
    stp_name: str
    local: bool
    note: str


@dataclass(frozen=True)
class PlanStep:
    name: str
    status: str
    command: list[str]
    note: str


TAP_DEFS = {
    "T0": TapDefinition(
        "T0",
        "phase5_t0_emulator_egress",
        "phase5_t0_emulator_egress.stp",
        True,
        "emulator or real-MuTRiG byte stream before frame deassembly",
    ),
    "T1": TapDefinition(
        "T1",
        "phase5_t1_frame_deassembly",
        "phase5_t1_frame_deassembly.stp",
        True,
        "mutrig_frame_deassembly hit_type0 output",
    ),
    "T2": TapDefinition(
        "T2",
        "phase5_t2_backpressure_fifo",
        "phase5_t2_backpressure_fifo.stp",
        True,
        "backpressure_fifo output and fill level",
    ),
    "T3": TapDefinition(
        "T3",
        "phase5_t3_lane_mux",
        "phase5_t3_lane_mux.stp",
        True,
        "mux_mutrig2processor output",
    ),
    "T4": TapDefinition(
        "T4",
        "phase5_t4_mts_processor",
        "phase5_t4_mts_processor.stp",
        True,
        "mts_processor hit_type1 output",
    ),
    "T5": TapDefinition(
        "T5",
        "phase5_t5_hist_ingress_bridge",
        "phase5_t5_hist_ingress_bridge.stp",
        True,
        "histogram_ingress_bridge pre/post observation surface",
    ),
    "T6": TapDefinition(
        "T6",
        "phase5_t6_ring_buffer_cam_M_K",
        "phase5_t6_ring_buffer_cam_M_K.stp",
        True,
        "ring_buffer_cam partition capture; expand M/K from the row taps field",
    ),
    "T7": TapDefinition(
        "T7",
        "phase5_t7_feb_frame_assembly_M",
        "phase5_t7_feb_frame_assembly_M.stp",
        True,
        "feb_frame_assembly hit_type3 output; expand M from the row taps field",
    ),
    "T8": TapDefinition(
        "T8",
        "phase5_t8_lvds_tx",
        "phase5_t8_lvds_tx.stp",
        True,
        "FEB LVDS TX byte stream",
    ),
    "TS": TapDefinition(
        "TS",
        "phase5_ts_swb_ingress",
        "phase5_ts_swb_ingress.stp",
        False,
        "SWB-side capture lives in the online_sc Quartus project",
    ),
}


def stamp() -> str:
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def source_select(manifest: CaseManifest) -> tuple[str, int | None, str]:
    if manifest.source_class == "EMU":
        return "emulator", 0xFF, "select all emulator lanes; stimulus config limits active lanes"
    if manifest.source_class == "REAL":
        return "real", 0x00, "select all real MuTRiG lanes"
    if manifest.source_class == "MIXED":
        mask = explicit_emu_mask(manifest.stimulus)
        if mask is not None:
            return "mixed", mask, "select the EMU lanes named by the mixed-source stimulus"
        return "mixed", None, "mixed source rows need an explicit per-case mask before live execution"
    return "status", None, "source class is not explicit in the row; inspect stimulus before live execution"


def explicit_emu_mask(text: str) -> int | None:
    found: set[int] = set()
    for match in re.finditer(r"\bEMU\s+lanes?\s+([0-7])\.\.([0-7])\b", text, flags=re.IGNORECASE):
        start = int(match.group(1))
        end = int(match.group(2))
        if start <= end:
            found.update(range(start, end + 1))
    for match in re.finditer(r"\bEMU\s+lanes?\s*\{([^{}]+)\}", text, flags=re.IGNORECASE):
        found.update(parse_lane_list(match.group(1)))
    for match in re.finditer(r"\bEMU\s+lane\s+([0-7])\b", text, flags=re.IGNORECASE):
        found.add(int(match.group(1)))
    if not found:
        return None
    mask = 0
    for lane in found:
        mask |= 1 << lane
    return mask


def source_step(manifest: CaseManifest, link: int) -> PlanStep:
    mode, mask, note = source_select(manifest)
    command = [str(SCRIPT_DIR / "set_mutrig_lane_sources.py"), "--link", str(link), "--mode", mode]
    if mode == "mixed" and mask is not None:
        command.extend(["--mask", f"0x{mask:02X}"])
    if mode in {"real", "emulator", "mixed"}:
        command.append("--clear-counters")
    status = "READY" if mode in {"real", "emulator"} else "MANUAL"
    return PlanStep("source-select", status, command, note)


def tap_steps(manifest: CaseManifest, signaltap_dir: Path, captures_dir: Path) -> list[PlanStep]:
    steps: list[PlanStep] = []
    for tap_id in manifest.tap_ids:
        tap = TAP_DEFS.get(tap_id)
        if tap is None:
            steps.append(PlanStep(f"tap-{tap_id}", "UNKNOWN", [], "tap ID is not in the Phase-5 tap map"))
            continue
        if not tap.local:
            steps.append(
                PlanStep(
                    f"tap-{tap_id}",
                    "EXTERNAL",
                    [],
                    f"{tap.note}; use signal-set {tap.signal_set}",
                )
            )
            continue
        stp_path = signaltap_dir / tap.stp_name
        out_vcd = captures_dir / f"{manifest.case_id.lower()}_{tap.signal_set}.vcd"
        command = [
            str(SCRIPT_DIR / "run_signaltap_capture.py"),
            "--stp",
            str(stp_path),
            "--signal-set",
            tap.signal_set,
            "--trigger-name",
            "<trigger-name-from-stp>",
            "--out-vcd",
            str(out_vcd),
        ]
        status = "READY" if stp_path.is_file() else "MISSING"
        steps.append(PlanStep(f"tap-{tap_id}", status, command, tap.note))
    return steps


def build_steps(
    manifest: CaseManifest,
    *,
    doc_dir: Path,
    signaltap_dir: Path,
    captures_dir: Path,
    link: int,
) -> list[PlanStep]:
    steps = [
        PlanStep(
            "catalog-validate",
            "READY",
            [str(SCRIPT_DIR / "phase5_case_catalog.py"), "--doc-dir", str(doc_dir), "--validate", "--summary"],
            "validate the scoreboard before using it as the execution source",
        ),
        PlanStep(
            "bridge-preflight",
            "READY",
            [str(SCRIPT_DIR / "check_sc_bridges.py"), "--link", str(link)],
            "SC bridge, source-mux, histogram, and run-control reachability gate",
        ),
        source_step(manifest, link),
    ]
    steps.extend(tap_steps(manifest, signaltap_dir, captures_dir))
    return steps


def step_to_dict(step: PlanStep) -> dict[str, Any]:
    return {
        "name": step.name,
        "status": step.status,
        "command": step.command,
        "note": step.note,
    }


def command_text(command: list[str]) -> str:
    if not command:
        return ""
    return " ".join(command)


def render_markdown(manifest: CaseManifest, steps: list[PlanStep]) -> str:
    lines = [
        f"# Phase 5 Case Plan: {manifest.case_id}",
        "",
        f"- bucket: `{manifest.bucket}`",
        f"- group: `{manifest.group}` - {manifest.group_title}",
        f"- scoreboard status: `{manifest.group_status}`",
        f"- source class: `{manifest.source_class}`",
        f"- lanes: `{','.join(str(lane) for lane in manifest.lanes) if manifest.lanes else 'manual'}`",
        f"- taps: `{','.join(manifest.tap_ids) if manifest.tap_ids else 'manual'}`",
        f"- row: `{manifest.row_expr}` at line {manifest.row_line}",
        "",
        "## Stimulus",
        "",
        manifest.stimulus or "manual",
        "",
        "## Trigger",
        "",
        manifest.trigger or "manual",
        "",
        "## Expected Evidence",
        "",
        manifest.evidence or "manual",
        "",
        "## Execution Steps",
        "",
        "| Step | Status | Command | Note |",
        "|---|---|---|---|",
    ]
    for step in steps:
        command = command_text(step.command)
        command_cell = f"`{command}`" if command else "manual"
        lines.append(f"| {step.name} | {step.status} | {command_cell} | {step.note} |")
    lines.extend(
        [
            "",
            "## Live-Run Gate",
            "",
            "- Do not run live until every required local tap is `READY`, or the case is intentionally run as a counter-only/debug capture.",
            "- `TS` is external to this repo and must be captured or counter-checked in the SWB `online_sc` tree.",
            "- Keep this report as the detailed evidence pointer when the bucket scoreboard row is moved out of `not-run`.",
            "",
        ]
    )
    return "\n".join(lines)


def run_source_select(step: PlanStep) -> int:
    if step.status != "READY":
        print(f"source-select is not executable without manual input: {step.note}", file=sys.stderr)
        return 2
    print(command_text(step.command))
    result = subprocess.run(step.command, text=True)
    return result.returncode


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("case_id", nargs="+", help="Phase-5 case ID, for example TPB5BAS001")
    parser.add_argument("--doc-dir", type=Path, default=DEFAULT_DOC_DIR)
    parser.add_argument("--signaltap-dir", type=Path, default=SIGNALTAP_DIR)
    parser.add_argument("--captures-dir", type=Path, default=CAPTURES_DIR)
    parser.add_argument("--reports-dir", type=Path, default=REPORTS_DIR)
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of Markdown")
    parser.add_argument("--write-report", type=Path, help="Write Markdown plan to this file")
    parser.add_argument("--require-stp", action="store_true", help="Return non-zero if any local tap file is missing")
    parser.add_argument(
        "--execute-source-select",
        action="store_true",
        help="Execute only the source mux command for a single case; SignalTap and stimulus remain manual",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    scoreboards, cases, errors = load_catalog(args.doc_dir)
    del scoreboards
    if errors:
        for error in errors:
            print(f"ERROR {error}", file=sys.stderr)
        return 1

    reports: list[dict[str, Any]] = []
    markdown_reports: list[str] = []
    exit_code = 0
    for case_id in args.case_id:
        manifest = cases.get(case_id)
        if manifest is None:
            print(f"ERROR unknown case id: {case_id}", file=sys.stderr)
            exit_code = 1
            continue
        steps = build_steps(
            manifest,
            doc_dir=args.doc_dir,
            signaltap_dir=args.signaltap_dir,
            captures_dir=args.captures_dir,
            link=args.link,
        )
        if args.require_stp and any(step.status == "MISSING" for step in steps):
            exit_code = 1
        if args.execute_source_select:
            if len(args.case_id) != 1:
                print("ERROR --execute-source-select accepts exactly one case", file=sys.stderr)
                return 2
            source = next(step for step in steps if step.name == "source-select")
            exit_code = run_source_select(source)

        reports.append({"case": manifest_to_dict(manifest), "steps": [step_to_dict(step) for step in steps]})
        markdown_reports.append(render_markdown(manifest, steps))

    if args.json:
        print(json.dumps({"generated_at": stamp(), "reports": reports}, indent=2, sort_keys=True))
    else:
        output = "\n---\n".join(markdown_reports)
        if output:
            print(output)
        if args.write_report:
            args.write_report.parent.mkdir(parents=True, exist_ok=True)
            args.write_report.write_text(output + ("\n" if output else ""), encoding="utf-8")
            print(f"WROTE {args.write_report}")

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
