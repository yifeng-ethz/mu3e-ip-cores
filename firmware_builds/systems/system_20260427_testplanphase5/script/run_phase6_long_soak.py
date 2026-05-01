#!/usr/bin/env python3
"""Run the Phase-6 long soak until FEB/SWB/host blockers are cleared or localized.

The runner is intentionally conservative: a known failing FEB gate is recorded
as expected-fail evidence, not as end-to-end closure. SWB/DMA capture is only
attempted after the FEB full-channel gate passes without MTS/ring errors.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent
REPO_ROOT = BOARD_TEST_DIR.parent.parent.parent
REPORT_DIR = BOARD_TEST_DIR / "reports"

DEFAULT_SC_TOOL = BOARD_TEST_DIR / "bin" / "sc_tool"
DEFAULT_RC_TOOL = BOARD_TEST_DIR / "bin" / "rc_tool"
PYTHON = Path(sys.executable or "python3")

CONFIGURE_MUTRIG = SCRIPT_DIR / "configure_mutrig_from_xml.py"
INJECTOR_SANITY = SCRIPT_DIR / "run_phase5_injector_datapath_sanity.py"
CHECK_ENV = SCRIPT_DIR / "check_environment_monitors.py"
CHECK_SC = SCRIPT_DIR / "check_sc_bridges.py"
ANALYZE_DMA = SCRIPT_DIR / "analyze_phase6_dma_memory.py"
SWB_DMA_PROBE = REPO_ROOT / "tools" / "phase6_swb_dma_probe" / "phase6_swb_dma_probe.py"
DEFAULT_SMB3_XML = REPO_ROOT / "board_test_system" / "trash_bin" / "good_ribbon_0" / "config_smb3_tdc.txt"
DEFAULT_SMB5_XML = REPO_ROOT / "board_test_system" / "trash_bin" / "good_ribbon_0" / "config_smb5_tdc.txt"

FREQ_HZ = 125_000_000


def default_swb_dma_probe() -> Path:
    env_path = os.environ.get("PHASE6_SWB_DMA_PROBE")
    if env_path:
        return Path(env_path)
    return SWB_DMA_PROBE


def swb_mode_name(mode: int) -> str:
    names = {
        0: "stream-links",
        2: "stream-datagen",
        3: "time-datagen",
        4: "time-links",
    }
    if mode not in names:
        raise ValueError(f"unsupported SWB readout mode {mode}; expected one of {sorted(names)}")
    return names[mode]


@dataclass(frozen=True)
class CommandResult:
    name: str
    argv: list[str]
    rc: int
    log: str
    started: str
    finished: str
    timeout_s: float | None = None


@dataclass(frozen=True)
class Phase6Case:
    case_id: str
    description: str
    config_kind: str
    pulse_high_cycles: int
    lvds_lane_mask: int
    real_hits_per_lane: int
    duration_ms: int
    expected: str
    min_fraction: float = 0.80
    expected_failure_keywords: tuple[str, ...] = ("mts", "ring", "delay")


PHASE6_CASES: tuple[Phase6Case, ...] = (
    Phase6Case(
        case_id="P6B006",
        description="lower lane5 / ASIC5 one TDC-test channel, 100 kHz, pulse-high 4",
        config_kind="lower56_ch1",
        pulse_high_cycles=4,
        lvds_lane_mask=0x020,
        real_hits_per_lane=1,
        duration_ms=1000,
        expected="pass",
    ),
    Phase6Case(
        case_id="P6B007",
        description="lower lane6 / ASIC6 one TDC-test channel, 100 kHz, pulse-high 4",
        config_kind="lower56_ch1",
        pulse_high_cycles=4,
        lvds_lane_mask=0x040,
        real_hits_per_lane=1,
        duration_ms=1000,
        expected="pass",
    ),
    Phase6Case(
        case_id="P6B010",
        description="lower lanes5+6 one TDC-test channel per ASIC, 100 kHz, pulse-high 4",
        config_kind="lower56_ch1",
        pulse_high_cycles=4,
        lvds_lane_mask=0x060,
        real_hits_per_lane=1,
        duration_ms=1000,
        expected="pass",
    ),
    Phase6Case(
        case_id="P6B020",
        description="lower lanes5+6 full 32 TDC-test channels per ASIC, 100 kHz, pulse-high 4",
        config_kind="full32_tuned",
        pulse_high_cycles=4,
        lvds_lane_mask=0x060,
        real_hits_per_lane=32,
        duration_ms=1000,
        expected="fail",
    ),
    Phase6Case(
        case_id="P6E010",
        description="lower lanes5+6 full 32 TDC-test channels per ASIC, 100 kHz, pulse-high 3",
        config_kind="full32_tuned",
        pulse_high_cycles=3,
        lvds_lane_mask=0x060,
        real_hits_per_lane=32,
        duration_ms=1000,
        expected="underfilled",
    ),
)


def now_stamp() -> str:
    return dt.datetime.now().strftime("%Y%m%d_%H%M%S")


def iso_now() -> str:
    return dt.datetime.now().isoformat(timespec="seconds")


def fmt_mask(value: int) -> str:
    return f"0x{value:X}"


def parse_int(text: str) -> int:
    return int(text, 0)


def default_run_dir() -> Path:
    return REPORT_DIR / "phase6_long_runs" / now_stamp()


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def append_jsonl(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, sort_keys=True) + "\n")


class Runner:
    def __init__(self, args: argparse.Namespace) -> None:
        self.args = args
        self.run_dir = args.run_dir.resolve()
        self.log_dir = self.run_dir / "logs"
        self.case_dir = self.run_dir / "cases"
        self.summary_jsonl = self.run_dir / "summary.jsonl"
        self.command_index = 0
        self.last_config_kind: str | None = None
        self.run_dir.mkdir(parents=True, exist_ok=True)
        self.log_dir.mkdir(parents=True, exist_ok=True)
        self.case_dir.mkdir(parents=True, exist_ok=True)
        self.stop_file = self.run_dir / "STOP"

    def log_path(self, name: str) -> Path:
        self.command_index += 1
        safe = "".join(ch if ch.isalnum() or ch in ("-", "_", ".") else "_" for ch in name)
        return self.log_dir / f"{self.command_index:04d}_{safe}.log"

    def run_cmd(
        self,
        name: str,
        argv: list[str],
        *,
        cwd: Path | None = None,
        timeout_s: float | None = None,
        input_text: str | None = None,
        dry_ok: bool = True,
    ) -> CommandResult:
        started = iso_now()
        log = self.log_path(name)
        quoted = " ".join(argv)
        header = {
            "started": started,
            "name": name,
            "argv": argv,
            "cwd": str(cwd or REPO_ROOT),
            "timeout_s": timeout_s,
            "dry_run": self.args.dry_run,
        }
        log.write_text(json.dumps(header, sort_keys=True) + "\n\n", encoding="utf-8")

        if self.args.dry_run and dry_ok:
            with log.open("a", encoding="utf-8") as handle:
                handle.write(f"DRY-RUN: {quoted}\n")
            return CommandResult(name, argv, 0, str(log), started, iso_now(), timeout_s)

        try:
            completed = subprocess.run(
                argv,
                cwd=str(cwd or REPO_ROOT),
                input=input_text,
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                timeout=timeout_s,
                check=False,
            )
            rc = completed.returncode
            output = completed.stdout
        except subprocess.TimeoutExpired as exc:
            rc = 124
            output = (exc.stdout or "") if isinstance(exc.stdout, str) else ""
            output += f"\nTIMEOUT after {timeout_s} seconds\n"
        finished = iso_now()
        with log.open("a", encoding="utf-8") as handle:
            handle.write(output)
            handle.write(f"\nRETURN_CODE={rc}\nFINISHED={finished}\n")
        return CommandResult(name, argv, rc, str(log), started, finished, timeout_s)

    def rc_send(self, cmd: str, run_number: int | None = None) -> CommandResult:
        target_feb = self.args.feb
        if cmd == "address":
            target_feb = self.args.link if self.args.address_feb is None else self.args.address_feb
        argv = [
            str(self.args.rc_tool),
            "send",
            cmd,
            "--device",
            self.args.device,
            "--feb",
            str(target_feb),
            "--settle-us",
            str(self.args.rc_settle_us),
        ]
        if run_number is not None:
            argv.extend(["--run", str(run_number)])
        return self.run_cmd(f"rc_{cmd}", argv, timeout_s=20)

    def stop_reset(self) -> list[CommandResult]:
        return [self.rc_send("reset"), self.rc_send("address"), self.rc_send("stop-reset")]

    def preflight(self) -> bool:
        commands: list[CommandResult] = []
        commands.extend(self.stop_reset())
        if self.args.preflight_settle_ms > 0 and not self.args.dry_run:
            time.sleep(self.args.preflight_settle_ms / 1000.0)
        commands.append(
            self.run_cmd(
                "check_sc_bridges",
                [
                    str(PYTHON),
                    str(CHECK_SC),
                    "--link",
                    str(self.args.link),
                    "--sc-tool",
                    str(self.args.sc_tool),
                    "--skip-jtag",
                    "--json",
                ],
                timeout_s=60,
            )
        )
        env_json = self.run_dir / "preflight_environment.json"
        commands.append(
            self.run_cmd(
                "check_environment_monitors",
                [
                    str(PYTHON),
                    str(CHECK_ENV),
                    "--link",
                    str(self.args.link),
                    "--sc-tool",
                    str(self.args.sc_tool),
                    "--json-output",
                    str(env_json),
                ],
                timeout_s=120,
            )
        )
        ok = all(item.rc == 0 for item in commands)
        append_jsonl(
            self.summary_jsonl,
            {
                "kind": "preflight",
                "timestamp": iso_now(),
                "ok": ok,
                "commands": [item.__dict__ for item in commands],
            },
        )
        return ok

    def configure(self, kind: str, cycle: int) -> CommandResult:
        if self.last_config_kind == kind and not self.args.force_config_each_case:
            return CommandResult(
                name=f"configure_{kind}_skipped",
                argv=[],
                rc=0,
                log="",
                started=iso_now(),
                finished=iso_now(),
            )

        self.stop_reset()
        out_base = self.case_dir / f"cycle{cycle:05d}_{kind}_config"
        argv = [
            str(PYTHON),
            str(CONFIGURE_MUTRIG),
            "--link",
            str(self.args.link),
            "--sc-tool",
            str(self.args.sc_tool),
            "--allow-idle-after-config",
            "--smb3-xml",
            str(DEFAULT_SMB3_XML),
            "--smb5-xml",
            str(DEFAULT_SMB5_XML),
            "--set-channel",
            "cml_sc=0",
            "--set-channel",
            "recv_all=1",
            "--output",
            str(out_base.with_suffix(".md")),
            "--json-output",
            str(out_base.with_suffix(".json")),
        ]

        if kind == "full32_tuned":
            argv.extend(
                [
                    "--asics",
                    "0-7",
                    "--channel-enable-mask",
                    "0xffffffff",
                    "--tdctest-channel-mask",
                    "0xffffffff",
                    "--set-tdc",
                    "0:vnhitlogic=40",
                    "--set-tdc",
                    "2:vncnt=40",
                    "--set-tdc",
                    "2:vnvcodelay=30",
                    "--set-tdc",
                    "2:vnhitlogic=30",
                    "--set-tdc",
                    "3:vncnt=35",
                    "--set-tdc",
                    "3:vnvcodelay=12",
                    "--set-tdc",
                    "3:vnhitlogic=25",
                    "--set-tdc",
                    "7:vncnt=30",
                    "--set-tdc",
                    "7:vnvcodelay=14",
                    "--set-tdc",
                    "7:vnhitlogic=40",
                ]
            )
        elif kind == "lower56_ch1":
            argv.extend(
                [
                    "--asics",
                    "5,6",
                    "--channel-enable-mask",
                    "0x1",
                    "--tdctest-channel-mask",
                    "0x1",
                    "--set-header",
                    "5:ext_trig_offset=0",
                    "--set-header",
                    "6:ext_trig_offset=0",
                    "--set-header",
                    "5:sync_ch_rst=1",
                    "--set-header",
                    "6:sync_ch_rst=1",
                ]
            )
        else:
            raise ValueError(f"unknown config kind {kind}")

        result = self.run_cmd(f"configure_{kind}", argv, timeout_s=120)
        if result.rc == 0:
            self.last_config_kind = kind
        return result

    def expected_hits(self, case: Phase6Case) -> int:
        lanes = int(case.lvds_lane_mask & 0xFF).bit_count()
        pulses = (FREQ_HZ / self.args.pulse_interval) * (case.duration_ms / 1000.0)
        return int(round(pulses * lanes * case.real_hits_per_lane))

    def run_injector_case(self, case: Phase6Case, cycle: int) -> dict[str, Any]:
        config_result = self.configure(case.config_kind, cycle)
        case_base = self.case_dir / f"cycle{cycle:05d}_{case.case_id}"
        json_out = case_base.with_suffix(".json")
        md_out = case_base.with_suffix(".md")
        if config_result.rc != 0:
            result = CommandResult(
                name=f"run_{case.case_id}_skipped_config_failed",
                argv=[],
                rc=125,
                log="",
                started=iso_now(),
                finished=iso_now(),
                timeout_s=None,
            )
            record = {
                "kind": "phase6_case",
                "timestamp": iso_now(),
                "cycle": cycle,
                "case_id": case.case_id,
                "description": case.description,
                "expected": case.expected,
                "classification": "config_failed",
                "expected_hits": self.expected_hits(case),
                "config": config_result.__dict__,
                "command": result.__dict__,
                "json": str(json_out),
                "report": str(md_out),
                "parsed": {
                    "error": "configuration failed",
                    "config_rc": config_result.rc,
                    "config_log": config_result.log,
                },
            }
            append_jsonl(self.summary_jsonl, record)
            return record

        argv = [
            str(PYTHON),
            str(INJECTOR_SANITY),
            "--link",
            str(self.args.link),
            "--sc-tool",
            str(self.args.sc_tool),
            "--rc-tool",
            str(self.args.rc_tool),
            "--device",
            self.args.device,
            "--feb",
            str(self.args.feb),
            "--source",
            "real",
            "--lvds-lane-mask",
            fmt_mask(case.lvds_lane_mask),
            "--capture-lvds",
            "--read-lvds-dpa-unlocks",
            "--active-lanes-mask",
            "0x00",
            "--hist-profile",
            "delay-mts-both",
            "--inject-mode",
            "periodic",
            "--pulse-intervals",
            str(self.args.pulse_interval),
            "--pulse-high-cycles",
            str(case.pulse_high_cycles),
            "--duration-ms",
            str(case.duration_ms),
            "--pre-inject-ms",
            str(self.args.pre_inject_ms),
            "--post-sync-ms",
            str(self.args.post_sync_ms),
            "--real-hits-per-lane",
            str(case.real_hits_per_lane),
            "--mts-expected-latency",
            str(self.args.mts_expected_latency),
            "--mts-delay-ts-field",
            "t",
            "--mts-drop-delay-error",
            "off",
            "--ring-filter-inerr",
            "on",
            "--output",
            str(md_out),
            "--json-output",
            str(json_out),
        ]
        if self.args.dump_hist_bins:
            argv.extend(
                [
                    "--dump-hist-bins",
                    "--hist-bin-read-chunk-words",
                    str(self.args.hist_bin_read_chunk_words),
                    "--hist-bin-read-delay-ms",
                    str(self.args.hist_bin_read_delay_ms),
                ]
            )
        result = self.run_cmd(f"run_{case.case_id}", argv, timeout_s=max(60, case.duration_ms / 1000.0 + 60))
        parsed = self.parse_injector_json(json_out)
        classification = self.classify_case(case, result.rc, parsed)
        record = {
            "kind": "phase6_case",
            "timestamp": iso_now(),
            "cycle": cycle,
            "case_id": case.case_id,
            "description": case.description,
            "expected": case.expected,
            "classification": classification,
            "expected_hits": self.expected_hits(case),
            "config": config_result.__dict__,
            "command": result.__dict__,
            "json": str(json_out),
            "report": str(md_out),
            "parsed": parsed,
        }
        append_jsonl(self.summary_jsonl, record)
        return record

    def parse_injector_json(self, path: Path) -> dict[str, Any]:
        if self.args.dry_run:
            return {"dry_run": True}
        if not path.exists():
            return {"error": f"missing {path}"}
        try:
            payload = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            return {"error": f"json decode failed: {exc}"}
        cases = payload.get("cases", [])
        if not cases:
            return {"error": "no cases in injector JSON", "payload": payload}
        summary = cases[0].get("summary", {})
        return {
            "pass": bool(summary.get("pass", False)),
            "phase5_classification": summary.get("phase5_classification", "unknown"),
            "hist_total_delta": int(summary.get("hist_total_delta", 0) or 0),
            "hist_drop_delta": int(summary.get("hist_drop_delta", 0) or 0),
            "mts_total_delta": int(summary.get("mts_total_delta", 0) or 0),
            "mts_discard_delta": int(summary.get("mts_discard_delta", 0) or 0),
            "ring_push_delta": int(summary.get("ring_push_delta", 0) or 0),
            "ring_pop_delta": int(summary.get("ring_pop_delta", 0) or 0),
            "ring_inerr_delta": int(summary.get("ring_inerr_delta", 0) or 0),
            "ring_overwrite_delta": int(summary.get("ring_overwrite_delta", 0) or 0),
            "ring_cache_miss_delta": int(summary.get("ring_cache_miss_delta", 0) or 0),
            "frame_declared_delta": int(summary.get("frame_declared_delta", 0) or 0),
            "frame_actual_delta": int(summary.get("frame_actual_delta", 0) or 0),
            "frame_missing_delta": int(summary.get("frame_missing_delta", 0) or 0),
            "counter_rate_elapsed_s": summary.get("counter_rate_elapsed_s"),
            "counter_rates_hz": summary.get("counter_rates_hz", {}),
            "source_mux_real_delta": int(summary.get("source_mux_real_delta", 0) or 0),
            "lvds_error_delta_total": int(summary.get("lvds_error_delta_total", 0) or 0),
            "lvds_error_delta_lanes": summary.get("lvds_error_delta_lanes", []),
            "lvds_dpa_unlock_delta_total": int(summary.get("lvds_dpa_unlock_delta_total", 0) or 0),
            "lvds_dpa_unlock_delta_lanes": summary.get("lvds_dpa_unlock_delta_lanes", []),
            "lvds_fatal_lanes": summary.get("lvds_fatal_lanes", []),
            "lvds_snapshot_error": summary.get("lvds_snapshot_error"),
            "post_end_clean": bool(summary.get("post_end_clean", False)),
        }

    def classify_case(self, case: Phase6Case, rc: int, parsed: dict[str, Any]) -> str:
        if self.args.dry_run:
            return "dry_run"
        if "error" in parsed:
            return "unexpected_fail"
        passed = bool(parsed.get("pass", False)) and rc == 0
        expected_hits = self.expected_hits(case)
        hist_total = int(parsed.get("hist_total_delta", 0) or 0)
        underfilled = hist_total < int(round(expected_hits * case.min_fraction))
        phase5_class = str(parsed.get("phase5_classification", "")).lower()

        if case.expected == "pass":
            if passed and not underfilled:
                return "expected_pass"
            if passed and underfilled:
                return "underfilled"
            return "unexpected_fail"

        if case.expected == "underfilled":
            if passed and underfilled:
                return "underfilled"
            if passed and not underfilled:
                return "unexpected_pass"
            if any(keyword in phase5_class for keyword in case.expected_failure_keywords):
                return "expected_fail"
            return "unexpected_fail"

        if case.expected == "fail":
            if passed:
                return "unexpected_pass"
            if any(keyword in phase5_class for keyword in case.expected_failure_keywords):
                return "expected_fail"
            return "unexpected_fail"

        return "unexpected_fail"

    def feb_full_channel_gate_passed(self, records: list[dict[str, Any]]) -> bool:
        for record in records:
            if record.get("case_id") == "P6B020":
                return record.get("classification") == "unexpected_pass"
        return False

    def run_dma_capture(self, cycle: int) -> dict[str, Any]:
        dma_dir = self.case_dir / f"cycle{cycle:05d}_P6_DMA"
        dma_dir.mkdir(parents=True, exist_ok=True)
        generic_mask = self.args.swb_generic_mask if self.args.swb_generic_mask is not None else self.args.swb_link_mask
        scifi_mask = self.args.swb_scifi_mask if self.args.swb_scifi_mask is not None else self.args.swb_link_mask
        argv = [
            str(PYTHON),
            str(self.args.swb_dma_probe),
            "--out-dir",
            str(dma_dir),
            "--mode",
            swb_mode_name(self.args.swb_readout_mode),
            "--profile",
            self.args.swb_profile,
            "--generic-mask",
            fmt_mask(generic_mask),
            "--scifi-mask",
            fmt_mask(scifi_mask),
            "--hold-s",
            str(self.args.dma_hold_s),
            "--snapshot-period-s",
            str(self.args.dma_snapshot_period_s),
        ]
        if self.args.dma_dump_text:
            argv.append("--dump-text")
        result = self.run_cmd(
            "phase6_swb_dma_probe",
            argv,
            timeout_s=self.args.dma_timeout_s,
        )
        memory_file = dma_dir / ("memory_content.txt" if self.args.dma_dump_text else "dma_words.bin")
        analysis = self.analyze_memory_file(memory_file, dma_dir / "memory_decode")
        record = {
            "kind": "dma_capture",
            "timestamp": iso_now(),
            "cycle": cycle,
            "classification": "diagnostic_only",
            "command": result.__dict__,
            "memory_content": str(memory_file),
            "analysis": analysis,
        }
        append_jsonl(self.summary_jsonl, record)
        return record

    def analyze_memory_file(self, path: Path, output_base: Path) -> dict[str, Any]:
        if self.args.dry_run:
            return {"dry_run": True}
        if not path.exists():
            return {"error": "memory_content.txt missing"}
        argv = [
            str(PYTHON),
            str(ANALYZE_DMA),
            str(path),
            "--json-output",
            str(output_base.with_suffix(".json")),
            "--md-output",
            str(output_base.with_suffix(".md")),
        ]
        if self.args.dma_expect_ts_delta is not None:
            argv.extend(["--expect-ts-delta", str(self.args.dma_expect_ts_delta)])
        if self.args.dma_expect_hits_per_frame is not None:
            argv.extend(["--expect-hits-per-frame", str(self.args.dma_expect_hits_per_frame)])
        result = self.run_cmd("analyze_dma_memory", argv, timeout_s=120)
        try:
            payload = json.loads(output_base.with_suffix(".json").read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            payload = {"error": f"DMA decode JSON failed: {exc}"}
        payload["decode_command"] = result.__dict__
        return payload

    def write_manifest(self) -> None:
        write_json(
            self.run_dir / "manifest.json",
            {
                "created": iso_now(),
                "plan": str(REPO_ROOT / "firmware_builds" / "doc" / "TEST_PLAN_PHASE6.md"),
                "run_dir": str(self.run_dir),
                "args": {
                    "duration_hours": self.args.duration_hours,
                    "sleep_seconds": self.args.sleep_seconds,
                    "max_cycles": self.args.max_cycles,
                    "link": self.args.link,
                    "feb": self.args.feb,
                    "device": self.args.device,
                    "pulse_interval": self.args.pulse_interval,
                    "pre_inject_ms": self.args.pre_inject_ms,
                    "post_sync_ms": self.args.post_sync_ms,
                    "mts_expected_latency": self.args.mts_expected_latency,
                    "preflight_settle_ms": self.args.preflight_settle_ms,
                    "dump_hist_bins": self.args.dump_hist_bins,
                    "hist_bin_read_chunk_words": self.args.hist_bin_read_chunk_words,
                    "hist_bin_read_delay_ms": self.args.hist_bin_read_delay_ms,
                    "run_dma_when_feb_passes": self.args.run_dma_when_feb_passes,
                    "swb_link_mask": self.args.swb_link_mask,
                    "swb_profile": self.args.swb_profile,
                    "swb_generic_mask": self.args.swb_generic_mask,
                    "swb_scifi_mask": self.args.swb_scifi_mask,
                    "dma_expect_ts_delta": self.args.dma_expect_ts_delta,
                    "dma_expect_hits_per_frame": self.args.dma_expect_hits_per_frame,
                    "dry_run": self.args.dry_run,
                },
                "cases": [case.__dict__ for case in PHASE6_CASES],
                "stop_file": str(self.stop_file),
            },
        )
        readme = [
            "# Phase 6 Long-Run Directory",
            "",
            f"- Created: `{iso_now()}`",
            f"- Plan: `{REPO_ROOT / 'firmware_builds' / 'doc' / 'TEST_PLAN_PHASE6.md'}`",
            f"- Summary: `{self.summary_jsonl}`",
            f"- Stop file: `{self.stop_file}`",
            "",
            "Create the stop file to end the loop cleanly after the current case:",
            "",
            "```bash",
            f"touch {self.stop_file}",
            "```",
            "",
        ]
        (self.run_dir / "README.md").write_text("\n".join(readme), encoding="utf-8")

    def loop(self) -> int:
        self.write_manifest()
        if not self.preflight():
            print(f"preflight failed; see {self.summary_jsonl}", file=sys.stderr)
            return 2

        deadline = time.monotonic() + self.args.duration_hours * 3600.0
        cycle = 0
        exit_code = 0
        while time.monotonic() < deadline:
            if self.args.max_cycles is not None and cycle >= self.args.max_cycles:
                break
            if self.stop_file.exists():
                append_jsonl(
                    self.summary_jsonl,
                    {"kind": "stop", "timestamp": iso_now(), "cycle": cycle, "reason": "stop_file"},
                )
                break

            cycle_records: list[dict[str, Any]] = []
            for case in PHASE6_CASES:
                record = self.run_injector_case(case, cycle)
                cycle_records.append(record)
                if record.get("classification") in ("unexpected_fail", "unexpected_pass", "config_failed"):
                    exit_code = 1
                if self.stop_file.exists():
                    break

            if self.args.run_dma_when_feb_passes and self.feb_full_channel_gate_passed(cycle_records):
                self.run_dma_capture(cycle)

            append_jsonl(
                self.summary_jsonl,
                {
                    "kind": "cycle_complete",
                    "timestamp": iso_now(),
                    "cycle": cycle,
                    "records": [
                        {"case_id": item.get("case_id"), "classification": item.get("classification")}
                        for item in cycle_records
                    ],
                },
            )
            cycle += 1
            if self.args.sleep_seconds > 0:
                time.sleep(self.args.sleep_seconds)

        append_jsonl(
            self.summary_jsonl,
            {"kind": "complete", "timestamp": iso_now(), "cycles": cycle, "exit_code": exit_code},
        )
        return exit_code


def ensure_executable(path: Path, name: str) -> None:
    if not path.exists():
        raise FileNotFoundError(f"{name} not found: {path}")
    if not os.access(path, os.X_OK):
        raise PermissionError(f"{name} is not executable: {path}")


def ensure_file(path: Path, name: str) -> None:
    if not path.exists():
        raise FileNotFoundError(f"{name} not found: {path}")
    if not path.is_file():
        raise FileNotFoundError(f"{name} is not a file: {path}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, default=default_run_dir())
    parser.add_argument("--duration-hours", type=float, default=168.0)
    parser.add_argument("--sleep-seconds", type=float, default=60.0)
    parser.add_argument("--max-cycles", type=int, default=None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--feb", type=int, default=7)
    parser.add_argument(
        "--address-feb",
        type=int,
        default=None,
        help="FEB id used for the reset-link address command after reset. Defaults to --link.",
    )
    parser.add_argument("--device", default="/dev/mudaq0")
    parser.add_argument("--sc-tool", type=Path, default=DEFAULT_SC_TOOL)
    parser.add_argument("--rc-tool", type=Path, default=DEFAULT_RC_TOOL)
    parser.add_argument("--rc-settle-us", type=int, default=5000)
    parser.add_argument(
        "--preflight-settle-ms",
        type=int,
        default=500,
        help="Delay after reset/stop-reset before SC bridge preflight reads.",
    )
    parser.add_argument("--pulse-interval", type=int, default=1250)
    parser.add_argument(
        "--pre-inject-ms",
        type=int,
        default=50,
        help="Delay after setup before enabling injector pulses for each case.",
    )
    parser.add_argument(
        "--post-sync-ms",
        type=int,
        default=50,
        help="Delay after run-control sync before each injection window.",
    )
    parser.add_argument("--mts-expected-latency", type=int, default=2000)
    parser.add_argument("--force-config-each-case", action="store_true")
    parser.add_argument("--dump-hist-bins", action="store_true")
    parser.add_argument("--hist-bin-read-chunk-words", type=int, default=1)
    parser.add_argument("--hist-bin-read-delay-ms", type=int, default=1)
    parser.add_argument("--run-dma-when-feb-passes", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--swb-dma-probe", type=Path, default=default_swb_dma_probe())
    parser.add_argument("--swb-readout-mode", type=int, default=4)
    parser.add_argument(
        "--swb-profile",
        choices=("none", "pixel-us", "pixel-ds", "scifi", "all", "generic"),
        default="generic",
        help="Profile bit set passed to the repo-owned SWB DMA probe. Generic is the OPQ/MuSiP path default.",
    )
    parser.add_argument("--swb-link-mask", type=parse_int, default=0x4)
    parser.add_argument("--swb-generic-mask", type=parse_int, default=None)
    parser.add_argument("--swb-scifi-mask", type=parse_int, default=None)
    parser.add_argument("--dma-timeout-s", type=float, default=90.0)
    parser.add_argument("--dma-hold-s", type=float, default=10.0)
    parser.add_argument("--dma-snapshot-period-s", type=float, default=1.0)
    parser.add_argument("--dma-dump-text", action=argparse.BooleanOptionalAction, default=False)
    parser.add_argument(
        "--dma-expect-ts-delta",
        type=int,
        default=None,
        help="Expected timestamp delta between consecutive decoded DMA frames. Defaults to --pulse-interval.",
    )
    parser.add_argument(
        "--dma-expect-hits-per-frame",
        type=int,
        default=None,
        help="Expected decoded hit count per DMA frame, for example 255 for the Mu3e Demo OPQ limit case.",
    )
    args = parser.parse_args()
    if args.dma_expect_ts_delta is None:
        args.dma_expect_ts_delta = args.pulse_interval

    if not args.dry_run:
        ensure_executable(args.sc_tool, "sc_tool")
        ensure_executable(args.rc_tool, "rc_tool")
        ensure_executable(PYTHON, "python")
        ensure_file(CONFIGURE_MUTRIG, "configure_mutrig_from_xml.py")
        ensure_file(INJECTOR_SANITY, "run_phase5_injector_datapath_sanity.py")
        ensure_file(CHECK_ENV, "check_environment_monitors.py")
        ensure_file(CHECK_SC, "check_sc_bridges.py")
        ensure_file(ANALYZE_DMA, "analyze_phase6_dma_memory.py")
        ensure_file(SWB_DMA_PROBE, "phase6_swb_dma_probe.py")
        ensure_file(DEFAULT_SMB3_XML, "SMB3 MuTRiG config")
        ensure_file(DEFAULT_SMB5_XML, "SMB5 MuTRiG config")
        if args.run_dma_when_feb_passes:
            ensure_file(args.swb_dma_probe, "phase6_swb_dma_probe.py")

    if shutil.which("python3") is None:
        raise RuntimeError("python3 not found in PATH")

    runner = Runner(args)
    print(f"phase6_run_dir={runner.run_dir}")
    print(f"phase6_summary={runner.summary_jsonl}")
    return runner.loop()


if __name__ == "__main__":
    raise SystemExit(main())
