#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import _default_sc_tool, sc_read  # noqa: E402


BOARD_TEST_DIR = SCRIPT_DIR.parent
SYSTEM_DIR = BOARD_TEST_DIR
FIRMWARE_BUILDS_DIR = SYSTEM_DIR.parent.parent
REPO_ROOT = FIRMWARE_BUILDS_DIR.parent
RUNCTL_SVD = REPO_ROOT / "run-control_mgmt" / "runctl_mgmt_host.svd"


@dataclass(frozen=True)
class RcCommand:
    name: str
    code: int
    run_number: int | None = None


DEFAULT_SEQUENCE = [
    RcCommand("reset", 0x30),
    RcCommand("stop-reset", 0x31),
    RcCommand("run-prepare", 0x10, run_number=42),
    RcCommand("sync", 0x11),
    RcCommand("start-run", 0x12),
    RcCommand("end-run", 0x13),
]

FULL_SEQUENCE = [
    RcCommand("reset", 0x30),
    RcCommand("stop-reset", 0x31),
    RcCommand("run-prepare", 0x10, run_number=42),
    RcCommand("sync", 0x11),
    RcCommand("start-run", 0x12),
    RcCommand("end-run", 0x13),
    RcCommand("abort-run", 0x14),
    RcCommand("start-link-test", 0x20),
    RcCommand("stop-link-test", 0x21),
    RcCommand("start-sync-test", 0x24),
    RcCommand("test-sync", 0x26),
    RcCommand("stop-sync-test", 0x25),
    RcCommand("enable", 0x32),
    RcCommand("disable", 0x33),
    RcCommand("reset", 0x30),
    RcCommand("stop-reset", 0x31),
]


def load_register_map(svd_path: Path) -> dict[str, int]:
    root = ET.parse(svd_path).getroot()
    registers: dict[str, int] = {}
    for reg in root.findall(".//register"):
        name = (reg.findtext("name") or "").strip()
        address_offset = reg.findtext("addressOffset")
        if not name or address_offset is None:
            continue
        registers[name] = int(address_offset, 0)
    required = ("STATUS", "LAST_CMD", "RUN_NUMBER", "RX_CMD_COUNT", "RX_ERR_COUNT")
    missing = [name for name in required if name not in registers]
    if missing:
        raise RuntimeError(f"runctl SVD missing required registers: {', '.join(missing)}")
    return registers


def default_rc_tool() -> Path:
    local = BOARD_TEST_DIR / "bin" / "rc_tool"
    if local.is_file():
        return local
    return Path("/home/yifeng/packages/online_dpv2/online/install/bin/rc_tool")


def run_checked(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=True, capture_output=True, text=True)


def parse_rc_status(output: str) -> dict[str, int]:
    values: dict[str, int] = {}
    for line in output.splitlines():
        if "=" not in line:
            continue
        left, right = line.split("=", 1)
        key = left.strip().lower().replace(" ", "_")
        value_text = right.strip().split()[0]
        if value_text.startswith("0x"):
            try:
                values[key] = int(value_text, 16)
            except ValueError:
                continue
    match = re.search(r"last state byte\s*=\s*(0x[0-9A-Fa-f]+)", output)
    if match:
        values["last_state_byte"] = int(match.group(1), 16)
    return values


def read_runctl_snapshot(sc_tool: Path, link: int, base_word: int, registers: dict[str, int]) -> dict[str, int]:
    snapshot: dict[str, int] = {}
    for name in ("STATUS", "LAST_CMD", "RUN_NUMBER", "RX_CMD_COUNT", "RX_ERR_COUNT"):
        addr = base_word + registers[name] // 4
        snapshot[name] = sc_read(sc_tool, link, addr, 1)[0]
    return snapshot


def send_rc_command(rc_tool: Path, cmd: RcCommand, device: str, feb: int, settle_us: int) -> str:
    argv = [
        str(rc_tool),
        "send",
        cmd.name,
        "--device",
        device,
        "--feb",
        str(feb),
        "--settle-us",
        str(settle_us),
    ]
    if cmd.run_number is not None:
        argv.extend(["--run", str(cmd.run_number)])
    result = run_checked(argv)
    return result.stdout


def read_rc_status(rc_tool: Path, device: str) -> tuple[str, dict[str, int]]:
    result = run_checked([str(rc_tool), "status", "--device", device])
    return result.stdout, parse_rc_status(result.stdout)


def snapshot_to_hex(snapshot: dict[str, int]) -> dict[str, str]:
    return {key: f"0x{value:08X}" for key, value in snapshot.items()}


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Exercise reset-link commands via rc_tool and verify runctl_mgmt_host counters over the SC upload bridge."
    )
    parser.add_argument("--device", default="/dev/mudaq0")
    parser.add_argument("--feb", type=int, default=7, help="Destination FEB ID; 7 = broadcast.")
    parser.add_argument("--link", type=int, default=2, help="SC link index for the FEB under test.")
    parser.add_argument("--run-number", type=int, default=42, help="Run number used for run-prepare in the default sequence.")
    parser.add_argument("--settle-us", type=int, default=5000)
    parser.add_argument("--sleep-ms", type=int, default=20, help="Extra host-side delay after each command before SC readback.")
    parser.add_argument("--upload-base-word", type=lambda text: int(text, 0), default=0x0C000)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--rc-tool", type=Path, default=default_rc_tool())
    parser.add_argument(
        "--sequence",
        choices=("core", "full"),
        default="core",
        help="Command sequence to run. 'full' excludes address assignment by default.",
    )
    parser.add_argument(
        "--include-address",
        action="store_true",
        help="Also send the address-assignment opcode 0x40 at the end of a full sweep.",
    )
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    registers = load_register_map(RUNCTL_SVD)
    selected_sequence = FULL_SEQUENCE if args.sequence == "full" else DEFAULT_SEQUENCE
    if args.include_address:
        selected_sequence = [*selected_sequence, RcCommand("address", 0x40)]
    sequence = [
        RcCommand(item.name, item.code, args.run_number if item.name == "run-prepare" else item.run_number)
        for item in selected_sequence
    ]

    checks: list[dict[str, Any]] = []
    failures = 0

    for cmd in sequence:
        status_before_text, status_before = read_rc_status(args.rc_tool, args.device)
        sc_before = read_runctl_snapshot(args.sc_tool, args.link, args.upload_base_word, registers)
        send_output = send_rc_command(args.rc_tool, cmd, args.device, args.feb, args.settle_us)
        time.sleep(max(args.sleep_ms, 0) / 1000.0)
        status_after_text, status_after = read_rc_status(args.rc_tool, args.device)
        sc_after = read_runctl_snapshot(args.sc_tool, args.link, args.upload_base_word, registers)

        details: dict[str, Any] = {
            "command": cmd.name,
            "opcode": f"0x{cmd.code:02X}",
            "rc_status_before": status_before,
            "rc_status_after": status_after,
            "sc_before": snapshot_to_hex(sc_before),
            "sc_after": snapshot_to_hex(sc_after),
            "send_output": send_output.strip().splitlines(),
        }
        if cmd.run_number is not None:
            details["run_number"] = cmd.run_number

        problems: list[str] = []
        rx_delta = sc_after["RX_CMD_COUNT"] - sc_before["RX_CMD_COUNT"]
        if rx_delta != 1:
            problems.append(
                f"RX_CMD_COUNT delta = {rx_delta}, expected 1 "
                f"({sc_before['RX_CMD_COUNT']} -> {sc_after['RX_CMD_COUNT']})"
            )
        rx_err_delta = sc_after["RX_ERR_COUNT"] - sc_before["RX_ERR_COUNT"]
        if rx_err_delta != 0:
            problems.append(
                f"RX_ERR_COUNT delta = {rx_err_delta}, expected 0 "
                f"({sc_before['RX_ERR_COUNT']} -> {sc_after['RX_ERR_COUNT']})"
            )
        last_cmd_byte = sc_after["LAST_CMD"] & 0xFF
        if last_cmd_byte != cmd.code:
            problems.append(f"LAST_CMD byte = 0x{last_cmd_byte:02X}, expected 0x{cmd.code:02X}")
        if "last_state_byte" not in status_after:
            problems.append("rc_tool status output did not include last_state_byte")
        elif cmd.run_number is None and status_after["last_state_byte"] != cmd.code:
            problems.append(
                f"rc_tool last_state_byte = 0x{status_after['last_state_byte']:02X}, "
                f"expected 0x{cmd.code:02X}"
            )
        if cmd.run_number is not None and sc_after["RUN_NUMBER"] != cmd.run_number:
            problems.append(
                f"RUN_NUMBER = {sc_after['RUN_NUMBER']}, expected {cmd.run_number}"
            )

        checks.append(
            {
                "status": "FAIL" if problems else "PASS",
                "details": details,
                "problems": problems,
            }
        )
        if problems:
            failures += 1

    payload = {
        "device": args.device,
        "feb": args.feb,
        "link": args.link,
        "sequence": args.sequence,
        "include_address": args.include_address,
        "upload_base_word": f"0x{args.upload_base_word:05X}",
        "checks": checks,
    }

    if args.json:
        json.dump(payload, sys.stdout, indent=2, sort_keys=True)
        sys.stdout.write("\n")
    else:
        for item in checks:
            cmd_name = item["details"]["command"]
            print(f"{item['status']} {cmd_name}")
            print(f"  opcode: {item['details']['opcode']}")
            print(f"  rc before: {item['details']['rc_status_before']}")
            print(f"  rc after:  {item['details']['rc_status_after']}")
            print(f"  sc before: {item['details']['sc_before']}")
            print(f"  sc after:  {item['details']['sc_after']}")
            for line in item["details"]["send_output"]:
                print(f"  send: {line}")
            for problem in item["problems"]:
                print(f"  problem: {problem}")
        print(f"SUMMARY pass={len(checks) - failures} fail={failures}")

    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
