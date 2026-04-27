#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent
SYSTEM_DIR = BOARD_TEST_DIR
SYN_DIR = SYSTEM_DIR / "syn"
FIRMWARE_BUILDS_DIR = SYSTEM_DIR.parent.parent
REPO_ROOT = FIRMWARE_BUILDS_DIR.parent

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import (  # noqa: E402
    DEFAULT_JTAG_FALLBACK_PATTERN,
    DEFAULT_JTAG_MASTER_PATTERN,
    _default_sc_tool,
    _default_system_console,
)


@dataclass
class Probe:
    name: str
    addr: int
    count: int = 1
    expect: int | None = None
    note: str = ""
    allow_non_ok: bool = False


def default_jdi() -> Path:
    board_project = SYN_DIR / "board_projects" / "fe_scifi_feb_v3"
    pipe = board_project / "output_files_pipe" / "top_nostp_pipe.jdi"
    if pipe.is_file():
        return pipe
    return board_project / "output_files" / "top.jdi"


def default_project_dir() -> Path:
    return SYN_DIR / "board_projects" / "fe_scifi_feb_v3"


def default_output() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d")
    return BOARD_TEST_DIR / "reports" / f"phase1_bringup_{stamp}_pipe.md"


def run_cmd(cmd: list[str], cwd: Path | None = None, env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)


def read_jdi_hash(jdi: Path) -> str | None:
    try:
        text = jdi.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    match = re.search(r'md5_digest_80b="([0-9A-Fa-f]+)"', text)
    return match.group(1).upper() if match else None


def parse_live_design_hash(jtagconfig_output: str, cable_tag: str) -> str | None:
    in_target = False
    for raw_line in jtagconfig_output.splitlines():
        line = raw_line.strip()
        if re.match(r"^\d+\)", line):
            in_target = cable_tag in line
            continue
        if in_target:
            match = re.search(r"Design hash\s+([0-9A-Fa-f]+)", line)
            if match:
                return match.group(1).upper()
    return None


def parse_sc_result(output: str) -> dict[str, Any]:
    result: dict[str, Any] = {"payload": []}
    match = re.search(r"rsp\s*:\s*([A-Z0-9_]+)\s*\((\d+)\)", output)
    if match:
        result["rsp_name"] = match.group(1)
        result["rsp_code"] = int(match.group(2))
    match = re.search(r"ack\s*:\s*(\d+)", output)
    if match:
        result["ack"] = int(match.group(1))
    for payload_match in re.finditer(r"payload\[(\d+)\]\s*=\s*(0x[0-9A-Fa-f]+)", output):
        result["payload"].append(int(payload_match.group(2), 16))
    return result


def sc_read(
    sc_tool: Path,
    link: int,
    addr: int,
    count: int,
    enable_mask: int | None,
) -> tuple[subprocess.CompletedProcess[str], dict[str, Any]]:
    cmd = [str(sc_tool), str(link), "read", f"0x{addr:05X}", str(count), "--quiet"]
    if enable_mask is not None:
        cmd.extend(["--enable-mask", f"0x{enable_mask:08X}"])
    proc = run_cmd(cmd)
    return proc, parse_sc_result(proc.stdout + proc.stderr)


def fmt_word(value: int | None) -> str:
    return "n/a" if value is None else f"0x{value:08X}"


def fmt_addr(value: int) -> str:
    return f"0x{value:05X}"


def qsys_param_int(qsys_path: Path, instance: str, param_name: str, default: int) -> int:
    try:
        root = ET.parse(qsys_path).getroot()
        module = root.find(f"./module[@name='{instance}']")
        if module is None:
            return default
        param = module.find(f"./parameter[@name='{param_name}']")
        if param is None:
            return default
        value = param.attrib.get("value")
        return int(value, 0) if value else default
    except Exception:
        return default


def status_for(proc: subprocess.CompletedProcess[str], parsed: dict[str, Any], probe: Probe) -> tuple[str, str, str]:
    rsp_name = parsed.get("rsp_name", "NO_RSP")
    ack = parsed.get("ack")
    payload = parsed.get("payload", [])
    first = payload[0] if payload else None

    ok_rsp = rsp_name == "OK" and ack == 1 and proc.returncode == 0
    if probe.allow_non_ok:
        ok_rsp = ack == 1 and rsp_name in {"OK", "SLVERR", "DECERR"}

    status = "PASS" if ok_rsp else "FAIL"
    detail = ""
    if probe.expect is not None and first is not None:
        if first != probe.expect:
            status = "FAIL"
            detail = f"expected {fmt_word(probe.expect)}"
        else:
            detail = "expected match" + (f"; {probe.note}" if probe.note else "")
    elif probe.expect is not None:
        status = "FAIL"
        detail = f"expected {fmt_word(probe.expect)}, no payload"
    elif probe.note:
        detail = probe.note

    if proc.returncode != 0 and not probe.allow_non_ok:
        detail = (detail + "; " if detail else "") + f"sc_tool rc={proc.returncode}"

    return status, rsp_name, detail


def fenced(text: str) -> str:
    text = text.rstrip()
    return f"```\n{text}\n```" if text else "```text\n<no output>\n```"


def main() -> int:
    parser = argparse.ArgumentParser(description="Run FEB SciFi v3 TEST_PLAN Phase 1 and write a Markdown report.")
    parser.add_argument("--link", type=int, default=int(os.environ.get("BOARD_TEST_LINK", "2")))
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--system-console", type=Path, default=_default_system_console())
    parser.add_argument("--jdi", type=Path, default=default_jdi())
    parser.add_argument("--project-dir", type=Path, default=default_project_dir())
    parser.add_argument("--debug-qsys", type=Path, default=SYN_DIR / "debug_sc_system_v3.qsys")
    parser.add_argument("--feb-qsys", type=Path, default=SYN_DIR / "feb_system_v3_pipe.qsys")
    parser.add_argument("--sopcinfo", type=Path, default=SYN_DIR / "feb_system_v3_pipe.sopcinfo")
    parser.add_argument("--inventory-out", type=Path, default=BOARD_TEST_DIR / "generated" / "debug_sc_system_v3_inventory_pipe_live.json")
    parser.add_argument("--output", type=Path, default=default_output())
    parser.add_argument("--jtag-cable", default="USB-BlasterII [7-2]")
    parser.add_argument(
        "--jtag-master-pattern",
        default=os.environ.get("BOARD_TEST_JTAG_MASTER_PATTERN", DEFAULT_JTAG_MASTER_PATTERN),
        help="Primary System Console master-service glob for JTAG cross-checks.",
    )
    parser.add_argument(
        "--jtag-fallback-pattern",
        default=os.environ.get("BOARD_TEST_JTAG_FALLBACK_PATTERN", DEFAULT_JTAG_FALLBACK_PATTERN),
        help="Comma-separated fallback System Console master-service globs.",
    )
    parser.add_argument("--skip-image-check", action="store_true")
    parser.add_argument(
        "--enable-mask",
        type=lambda text: int(text, 0),
        default=None,
        help="FEB_ENABLE_REGISTER_W mask passed to sc_tool and subprocess checks",
    )
    args = parser.parse_args()

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.inventory_out.parent.mkdir(parents=True, exist_ok=True)

    timestamp = dt.datetime.now().isoformat(timespec="seconds")

    preflight_cmds = [
        ["jtagconfig", "-n"],
        ["ls", "-l", "/dev/mudaq0"],
    ]
    preflight = [(cmd, run_cmd(cmd)) for cmd in preflight_cmds]
    jtagconfig_text = preflight[0][1].stdout + preflight[0][1].stderr
    expected_hash = read_jdi_hash(args.jdi)
    live_hash = parse_live_design_hash(jtagconfig_text, args.jtag_cable)
    image_check_status = "SKIP" if args.skip_image_check else "PASS"
    image_check_detail = ""
    if not args.skip_image_check:
        if expected_hash is None:
            image_check_status = "FAIL"
            image_check_detail = f"could not read design hash from {args.jdi}"
        elif live_hash is None:
            image_check_status = "FAIL"
            image_check_detail = f"could not find live design hash for {args.jtag_cable}"
        elif live_hash != expected_hash:
            image_check_status = "FAIL"
            image_check_detail = f"live {live_hash} != JDI {expected_hash}"
        else:
            image_check_detail = f"live {live_hash} matches JDI {expected_hash}"

    if image_check_status == "FAIL":
        lines = [
            "# Phase 1 Bring-Up Report",
            "",
            f"- Timestamp: `{timestamp}`",
            f"- SC link: `{args.link}`",
            f"- JDI: `{args.jdi}`",
            f"- JTAG cable: `{args.jtag_cable}`",
            f"- JTAG master pattern: `{args.jtag_master_pattern}`",
            f"- JTAG fallback pattern: `{args.jtag_fallback_pattern}`",
            f"- Expected JDI hash: `{expected_hash or 'n/a'}`",
            f"- Live design hash: `{live_hash or 'n/a'}`",
            "- Result: `FAIL`",
            "",
            "## Pre-Flight",
            "",
        ]
        for cmd, proc in preflight:
            lines.append(f"### `{ ' '.join(cmd) }`")
            lines.append("")
            lines.append(f"- Return code: `{proc.returncode}`")
            lines.append(fenced(proc.stdout + proc.stderr))
            lines.append("")
        lines.extend([
            "## Image Check",
            "",
            f"- Status: `{image_check_status}`",
            f"- Detail: {image_check_detail}",
            "",
            "## Notes",
            "",
            "- Phase 1 was not run because the selected JDI does not match the live FEB image.",
            "- Reprogram the FEB with the matching SOF or pass the JDI for the live image, then rerun.",
            "",
        ])
        args.output.write_text("\n".join(lines), encoding="utf-8")
        print(f"Wrote {args.output}")
        print("RESULT FAIL failures=1")
        return 1

    tool_env = os.environ.copy()
    if args.enable_mask is not None:
        tool_env["BOARD_TEST_SC_ENABLE_MASK"] = f"0x{args.enable_mask:08X}"

    metadata_cmd = [
        str(SCRIPT_DIR / "check_ip_metadata.py"),
        "--link",
        str(args.link),
        "--sc-tool",
        str(args.sc_tool),
        "--system-console",
        str(args.system_console),
        "--jdi",
        str(args.jdi),
        "--project-dir",
        str(args.project_dir),
        "--inventory-out",
        str(args.inventory_out),
        "--jtag-master-pattern",
        args.jtag_master_pattern,
        "--jtag-fallback-pattern",
        args.jtag_fallback_pattern,
    ]
    metadata = run_cmd(metadata_cmd, cwd=BOARD_TEST_DIR, env=tool_env)

    bridge_cmd = [
        str(SCRIPT_DIR / "check_sc_bridges.py"),
        "--link",
        str(args.link),
        "--sc-tool",
        str(args.sc_tool),
        "--system-console",
        str(args.system_console),
        "--jdi",
        str(args.jdi),
        "--project-dir",
        str(args.project_dir),
        "--debug-qsys",
        str(args.debug_qsys),
        "--feb-qsys",
        str(args.feb_qsys),
        "--sopcinfo",
        str(args.sopcinfo),
        "--jtag-master-pattern",
        args.jtag_master_pattern,
        "--jtag-fallback-pattern",
        args.jtag_fallback_pattern,
    ]
    bridge = run_cmd(bridge_cmd, cwd=BOARD_TEST_DIR, env=tool_env)

    max10_ip_id = qsys_param_int(args.debug_qsys, "max10_prog_avmm_0", "IP_ID", 0x4D313050)
    probes = [
        Probe("scratch_pad_ram[0..15]", 0x00000, 16, note="read-only baseline"),
        Probe("onewire_master_controller_0.CAPABILITY", 0x04400, 1, note="SVD has CAPABILITY at offset 0, no UID register"),
        Probe("onewire_master_controller_0.out_of_range", 0x04408, 1, note="one word past 0x20-byte SVD aperture", allow_non_ok=True),
        Probe("max10_prog_avmm_0.ID", 0x04800, 1, expect=max10_ip_id, note="expected from Qsys IP_ID parameter"),
        Probe("max10_prog_avmm_0.VERSION", 0x04801, 1, expect=0x00020000),
        Probe("max10_prog_avmm_0.STATUS", 0x04803, 1, note="ready/busy/fault status"),
        Probe("charge_injection_pulser_0.read_probe", 0x04C00, 1, note="write-only SVD; OK/SLVERR/DECERR acceptable", allow_non_ok=True),
        Probe("firefly_xcvr_ctrl_0[0..13]", 0x05000, 14, note="read-only audit; no I2C start write issued"),
        Probe("on_die_temp_sense_ctrl.CSR", 0x05400, 1, note="temperature status"),
        Probe("legacy_firefly_bridge.word0", 0x05800, 1, note="bridge reachability", allow_non_ok=True),
        Probe("mutrig_cfg_ctrl_0.OPCODE_STATUS", 0x0FC04, 1, note="cfg CSR reachability"),
    ]

    probe_rows: list[tuple[Probe, subprocess.CompletedProcess[str], dict[str, Any], str, str, str]] = []
    for probe in probes:
        proc, parsed = sc_read(args.sc_tool, args.link, probe.addr, probe.count, args.enable_mask)
        status, rsp_name, detail = status_for(proc, parsed, probe)
        probe_rows.append((probe, proc, parsed, status, rsp_name, detail))

    failures = 0
    if metadata.returncode != 0:
        failures += 1
    if bridge.returncode != 0:
        failures += 1
    for _probe, _proc, _parsed, status, _rsp, _detail in probe_rows:
        if status != "PASS":
            failures += 1
    for _cmd, proc in preflight:
        if proc.returncode != 0:
            failures += 1
    if image_check_status == "FAIL":
        failures += 1

    lines: list[str] = []
    lines.append("# Phase 1 Bring-Up Report")
    lines.append("")
    lines.append(f"- Timestamp: `{timestamp}`")
    lines.append(f"- SC link: `{args.link}`")
    lines.append(f"- SC tool: `{args.sc_tool}`")
    lines.append(f"- System Console: `{args.system_console}`")
    lines.append(f"- JDI: `{args.jdi}`")
    lines.append(f"- Project dir: `{args.project_dir}`")
    lines.append(f"- Debug Qsys: `{args.debug_qsys}`")
    lines.append(f"- FEB Qsys/SOPC: `{args.feb_qsys}`, `{args.sopcinfo}`")
    lines.append(f"- JTAG cable: `{args.jtag_cable}`")
    lines.append(f"- JTAG master pattern: `{args.jtag_master_pattern}`")
    lines.append(f"- JTAG fallback pattern: `{args.jtag_fallback_pattern}`")
    lines.append(f"- SC enable mask: `{fmt_word(args.enable_mask)}`")
    lines.append(f"- Expected JDI hash: `{expected_hash or 'n/a'}`")
    lines.append(f"- Live design hash: `{live_hash or 'n/a'}`")
    lines.append(f"- Result: `{'PASS' if failures == 0 else 'FAIL'}`")
    lines.append("")
    lines.append("## Pre-Flight")
    lines.append("")
    for cmd, proc in preflight:
        lines.append(f"### `{ ' '.join(cmd) }`")
        lines.append("")
        lines.append(f"- Return code: `{proc.returncode}`")
        lines.append(fenced(proc.stdout + proc.stderr))
        lines.append("")

    lines.append("## Image Check")
    lines.append("")
    lines.append(f"- Status: `{image_check_status}`")
    lines.append(f"- Detail: {image_check_detail or 'not checked'}")
    lines.append("")

    lines.append("## Metadata Gate")
    lines.append("")
    lines.append(f"- Command: `{' '.join(metadata_cmd)}`")
    lines.append(f"- Return code: `{metadata.returncode}`")
    lines.append(fenced(metadata.stdout + metadata.stderr))
    lines.append("")

    lines.append("## Bridge Gate")
    lines.append("")
    lines.append(f"- Command: `{' '.join(bridge_cmd)}`")
    lines.append(f"- Return code: `{bridge.returncode}`")
    lines.append(fenced(bridge.stdout + bridge.stderr))
    lines.append("")

    lines.append("## Read-Only Slave Audit")
    lines.append("")
    lines.append("| Status | Probe | Word addr | Count | RSP | First payload | Detail |")
    lines.append("|---|---:|---:|---:|---:|---:|---|")
    for probe, proc, parsed, status, rsp_name, detail in probe_rows:
        payload = parsed.get("payload", [])
        first = payload[0] if payload else None
        if proc.returncode != 0 and probe.allow_non_ok:
            detail = (detail + "; " if detail else "") + f"sc_tool rc={proc.returncode} accepted for this probe"
        lines.append(
            f"| {status} | `{probe.name}` | `{fmt_addr(probe.addr)}` | {probe.count} | `{rsp_name}` | `{fmt_word(first)}` | {detail or ''} |"
        )
    lines.append("")

    lines.append("## Scratchpad Baseline")
    lines.append("")
    scratch = probe_rows[0][2].get("payload", [])
    if scratch:
        for idx, value in enumerate(scratch):
            lines.append(f"- `{fmt_addr(idx)}` = `{fmt_word(value)}`")
    else:
        lines.append("- No scratchpad payload captured.")
    lines.append("")

    lines.append("## Notes")
    lines.append("")
    lines.append("- This phase is read-only except for metadata page-select writes performed by the existing metadata/bridge gate scripts.")
    lines.append("- The bridge gate uses `debug_sc_system_v3.qsys` for the SC primary map and the pipe Qsys/SOPC pair for downstream datapath addresses.")
    lines.append("- Phase 2 remains destructive and was not run by this script.")
    lines.append("")

    args.output.write_text("\n".join(lines), encoding="utf-8")
    print(f"Wrote {args.output}")
    print(f"RESULT {'PASS' if failures == 0 else 'FAIL'} failures={failures}")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
