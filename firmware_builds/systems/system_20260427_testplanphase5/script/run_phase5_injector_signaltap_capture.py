#!/usr/bin/env python3
"""Arm Phase 5 SignalTap, run injector sanity, and keep both evidence streams."""

from __future__ import annotations

import argparse
import datetime as dt
import os
import subprocess
import sys
import time
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent


def stamp() -> str:
    return dt.datetime.now().strftime("%Y%m%d_%H%M%S")


def default_stp() -> Path:
    return SYSTEM_DIR / "signaltap" / "phase5_frame_hist_path_mux0_valid_runtime.stp"


def default_capture_tcl() -> Path:
    return SCRIPT_DIR / "capture_signaltap_vcd.tcl"


def default_vcd() -> Path:
    return SYSTEM_DIR / "captures" / f"phase5_frame_hist_mux0_valid_{stamp()}.vcd"


def default_log() -> Path:
    return SYSTEM_DIR / "reports" / f"phase5_injector_signaltap_capture_{stamp()}.log"


def default_report() -> Path:
    return SYSTEM_DIR / "reports" / f"phase5_injector_emulator_periodic_signaltap_{stamp()}.md"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Start a headless SignalTap VCD capture, wait for it to arm, then run "
            "run_phase5_injector_datapath_sanity.py. Extra arguments after '--' "
            "are passed to the injector runner."
        )
    )
    parser.add_argument("--stp", type=Path, default=default_stp())
    parser.add_argument("--out-vcd", type=Path, default=default_vcd())
    parser.add_argument("--log", type=Path, default=default_log())
    parser.add_argument("--capture-tcl", type=Path, default=default_capture_tcl())
    parser.add_argument("--quartus-stp", default="quartus_stp")
    parser.add_argument("--instance", default="phase5_frame_hist_path")
    parser.add_argument("--signal-set", default="phase5_frame_hist_path")
    parser.add_argument("--trigger-name", default="hist_valid_rising_edge")
    parser.add_argument("--data-log-name", default="phase5_frame_hist_mux0_valid")
    parser.add_argument("--capture-timeout-s", type=float, default=90.0)
    parser.add_argument("--arm-delay-s", type=float, default=2.0)
    parser.add_argument("--runner", type=Path, default=SCRIPT_DIR / "run_phase5_injector_datapath_sanity.py")
    parser.add_argument("--runner-timeout-s", type=float, default=180.0)
    parser.add_argument(
        "--no-default-runner-args",
        action="store_true",
        help="Only pass explicit trailing runner arguments.",
    )
    parser.add_argument(
        "--runner-no-sc-reset",
        action="store_true",
        help=(
            "Pass BOARD_TEST_SC_NO_RESET=1 to the runner. This is opt-in because "
            "the FEB SC secondary ring can stale after FPGA reprogramming."
        ),
    )
    parser.add_argument(
        "runner_args",
        nargs=argparse.REMAINDER,
        help="Arguments passed to the injector runner after an optional '--'.",
    )
    return parser.parse_args()


def check_file(path: Path, label: str) -> None:
    if not path.is_file():
        raise SystemExit(f"{label} not found: {path}")


def build_default_runner_args(report: Path) -> list[str]:
    return [
        "--source",
        "emulator",
        "--active-lanes-mask",
        "0xFF",
        "--inject-mode",
        "periodic",
        "--pulse-intervals",
        "12500",
        "--pulse-high-cycles",
        "5",
        "--duration-ms",
        "250",
        "--run-number-base",
        "45200",
        "--output",
        str(report),
        "--json-output",
        str(report.with_suffix(".json")),
    ]


def run() -> int:
    args = parse_args()
    stp = args.stp.resolve()
    out_vcd = args.out_vcd.resolve()
    log = args.log.resolve()
    capture_tcl = args.capture_tcl.resolve()
    runner = args.runner.resolve()

    check_file(stp, "SignalTap STP")
    check_file(capture_tcl, "capture Tcl")
    check_file(runner, "injector runner")

    out_vcd.parent.mkdir(parents=True, exist_ok=True)
    log.parent.mkdir(parents=True, exist_ok=True)
    report = default_report().resolve()

    extra_runner_args = list(args.runner_args)
    if extra_runner_args and extra_runner_args[0] == "--":
        extra_runner_args = extra_runner_args[1:]

    runner_args: list[str] = []
    if not args.no_default_runner_args:
        runner_args.extend(build_default_runner_args(report))
    runner_args.extend(extra_runner_args)

    capture_cmd = [
        args.quartus_stp,
        "-t",
        str(capture_tcl),
        str(stp),
        str(out_vcd),
        args.instance,
        args.signal_set,
        args.trigger_name,
        args.data_log_name,
        str(max(args.capture_timeout_s, 1.0)),
    ]
    runner_cmd = [sys.executable, str(runner), *runner_args]

    env = os.environ.copy()
    if args.runner_no_sc_reset:
        env["BOARD_TEST_SC_NO_RESET"] = "1"
    else:
        env.pop("BOARD_TEST_SC_NO_RESET", None)
    env.setdefault("BOARD_TEST_SC_PIPELINED_RETRY", "1")
    env.setdefault("BOARD_TEST_SC_REPLY_TIMEOUT_MS", "1000")

    lines: list[str] = [
        f"timestamp={dt.datetime.now().isoformat(timespec='seconds')}",
        f"stp={stp}",
        f"out_vcd={out_vcd}",
        f"capture_cmd={' '.join(capture_cmd)}",
        f"runner_cmd={' '.join(runner_cmd)}",
        "",
    ]
    log.write_text("\n".join(lines), encoding="utf-8")

    capture_proc = subprocess.Popen(
        capture_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=env,
    )

    capture_stdout = ""
    runner_stdout = ""
    runner_stderr = ""
    runner_rc = 127
    capture_rc = 127
    try:
        time.sleep(max(args.arm_delay_s, 0.0))
        try:
            runner = subprocess.run(
                runner_cmd,
                text=True,
                capture_output=True,
                timeout=max(args.runner_timeout_s, 1.0),
                env=env,
            )
            runner_stdout = runner.stdout
            runner_stderr = runner.stderr
            runner_rc = runner.returncode
        except subprocess.TimeoutExpired as exc:
            runner_stdout = exc.stdout or ""
            runner_stderr = exc.stderr or ""
            runner_stderr += f"\nRUNNER_TIMEOUT after {args.runner_timeout_s}s\n"
            runner_rc = 124

        try:
            capture_stdout, _ = capture_proc.communicate(timeout=max(args.capture_timeout_s + 30.0, 30.0))
        except subprocess.TimeoutExpired:
            capture_proc.kill()
            capture_stdout, _ = capture_proc.communicate()
            capture_stdout += f"\nCAPTURE_TIMEOUT after {args.capture_timeout_s}s\n"
            capture_rc = 124
        else:
            capture_rc = capture_proc.returncode
    finally:
        if capture_proc.poll() is None:
            capture_proc.kill()
            capture_proc.wait()

    with log.open("a", encoding="utf-8") as handle:
        handle.write("## runner stdout\n")
        handle.write(runner_stdout)
        handle.write("\n## runner stderr\n")
        handle.write(runner_stderr)
        handle.write("\n## quartus_stp stdout\n")
        handle.write(capture_stdout)
        handle.write("\n")
        handle.write(f"runner_rc={runner_rc}\n")
        handle.write(f"capture_rc={capture_rc}\n")

    print(f"log={log}")
    print(f"vcd={out_vcd}")
    print(f"runner_rc={runner_rc}")
    print(f"capture_rc={capture_rc}")
    return 0 if runner_rc == 0 and capture_rc == 0 else 1


if __name__ == "__main__":
    raise SystemExit(run())
