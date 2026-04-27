#!/usr/bin/env python3
"""Arm a SignalTap capture, issue one rc_tool command, and export the VCD."""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent


def default_rc_tool() -> Path:
    local = BOARD_TEST_DIR / "bin" / "rc_tool"
    if local.is_file():
        return local
    return Path("/home/yifeng/packages/online_dpv2/online/install/bin/rc_tool")


def default_capture_tcl() -> Path:
    return SCRIPT_DIR / "capture_signaltap_vcd.tcl"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stp", type=Path, required=True, help="SignalTap .stp file")
    parser.add_argument("--instance", default="auto_signaltap_0", help="SignalTap instance name")
    parser.add_argument("--signal-set", required=True, help="SignalTap signal-set name")
    parser.add_argument("--trigger-name", required=True, help="SignalTap trigger name")
    parser.add_argument(
        "--data-log-name",
        default="capture_[clock clicks]",
        help="SignalTap data-log name",
    )
    parser.add_argument(
        "--capture-tcl",
        type=Path,
        default=default_capture_tcl(),
        help="Headless quartus_stp capture Tcl",
    )
    parser.add_argument(
        "--quartus-stp",
        default="quartus_stp",
        help="quartus_stp executable",
    )
    parser.add_argument(
        "--out-vcd",
        type=Path,
        required=True,
        help="Output VCD path",
    )
    parser.add_argument(
        "--rc-tool",
        type=Path,
        default=default_rc_tool(),
        help="Path to rc_tool binary",
    )
    parser.add_argument("--command", default="reset", help="rc_tool command to send")
    parser.add_argument("--device", default="/dev/mudaq0", help="rc_tool device path")
    parser.add_argument("--feb", type=int, default=7, help="rc_tool FEB ID; 7=broadcast")
    parser.add_argument("--run", type=int, default=42, help="Run number for run-prepare")
    parser.add_argument("--settle-us", type=int, default=5000, help="rc_tool settle time")
    parser.add_argument("--arm-delay-s", type=float, default=2.0, help="Delay before rc_tool send")
    parser.add_argument("--capture-timeout-s", type=float, default=90.0, help="quartus_stp wait timeout")
    return parser.parse_args()


def run_checked(cmd: list[str], **kwargs) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=True, text=True, capture_output=True, **kwargs)


def build_rc_cmd(args: argparse.Namespace) -> list[str]:
    cmd = [
        str(args.rc_tool),
        "send",
        args.command,
        "--device",
        args.device,
        "--feb",
        str(args.feb),
        "--settle-us",
        str(args.settle_us),
    ]
    if args.command in {"run-prepare", "prepare", "run_prepare"}:
        cmd.extend(["--run", str(args.run)])
    return cmd


def main() -> int:
    args = parse_args()
    stp_file = args.stp.resolve()
    capture_tcl = args.capture_tcl.resolve()
    out_vcd = args.out_vcd.resolve()

    for path in (stp_file, capture_tcl, args.rc_tool):
        if not Path(path).is_file():
            raise SystemExit(f"required file not found: {path}")

    capture_cmd = [
        args.quartus_stp,
        "-t",
        str(capture_tcl),
        str(stp_file),
        str(out_vcd),
        args.instance,
        args.signal_set,
        args.trigger_name,
        args.data_log_name,
        str(max(args.capture_timeout_s, 1.0)),
    ]
    rc_cmd = build_rc_cmd(args)

    print(f"capture_cmd: {' '.join(capture_cmd)}")
    print(f"rc_cmd: {' '.join(rc_cmd)}")
    sys.stdout.flush()

    capture_proc = subprocess.Popen(
        capture_cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )

    try:
        time.sleep(max(args.arm_delay_s, 0.0))
        rc_result = run_checked(rc_cmd)
        print("rc_tool output:")
        print(rc_result.stdout.rstrip())
        sys.stdout.flush()

        try:
            capture_stdout, _ = capture_proc.communicate(timeout=max(args.capture_timeout_s + 30.0, 30.0))
        except subprocess.TimeoutExpired:
            capture_proc.kill()
            capture_stdout, _ = capture_proc.communicate()
            raise SystemExit(
                "quartus_stp capture timed out\n"
                f"partial output:\n{capture_stdout.rstrip()}"
            )

        print("quartus_stp output:")
        print(capture_stdout.rstrip())
        if capture_proc.returncode != 0:
            raise SystemExit(f"quartus_stp failed with exit code {capture_proc.returncode}")
        return 0
    finally:
        if capture_proc.poll() is None:
            capture_proc.kill()
            capture_proc.wait()


if __name__ == "__main__":
    raise SystemExit(main())
