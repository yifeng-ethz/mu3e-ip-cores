#!/usr/bin/env python3
"""Read FEB environmental monitor CSRs and apply basic sanity checks."""

from __future__ import annotations

import argparse
import json
import math
import re
import struct
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
SYN_DIR = SCRIPT_DIR.parent / "syn"
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import _default_sc_tool  # noqa: E402


@dataclass(frozen=True)
class ReadBlock:
    name: str
    base_word: int
    count: int


READ_BLOCKS = [
    ReadBlock("onewire_master_controller_0", 0x04400, 11),
    ReadBlock("max10_prog_avmm_0", 0x04800, 4),
    ReadBlock("firefly_xcvr_ctrl_0", 0x05000, 14),
    ReadBlock("on_die_temp_sense_ctrl", 0x05400, 1),
    ReadBlock("legacy_firefly_bridge", 0x05800, 1),
]

ONEWIRE_BASE = 0x04400
ONEWIRE_UID = 0x4F574D43


@dataclass(frozen=True)
class OnewireMap:
    kind: str
    cap_idx: int
    status_idx: int
    temp_start_idx: int
    cap_addr: int
    status_addr: int


def detect_onewire_map(words: list[int]) -> OnewireMap:
    if words and words[0] == ONEWIRE_UID:
        return OnewireMap("common_header", 3, 4, 5, ONEWIRE_BASE + 3, ONEWIRE_BASE + 4)
    return OnewireMap("legacy", 0, 1, 2, ONEWIRE_BASE + 0, ONEWIRE_BASE + 1)


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


def _run_sc_command_with_fallback(cmd: list[str], expect_payload: int | None) -> tuple[subprocess.CompletedProcess[str], dict[str, Any]]:
    quiet_cmd = [*cmd, "--quiet"]
    quiet_proc = subprocess.run(quiet_cmd, capture_output=True, text=True)
    quiet_parsed = parse_sc_result(quiet_proc.stdout + quiet_proc.stderr)
    quiet_ok = quiet_proc.returncode == 0 and quiet_parsed.get("rsp_name") == "OK"
    if expect_payload is not None:
        quiet_ok = quiet_ok and len(quiet_parsed.get("payload", [])) == expect_payload
    if quiet_ok:
        quiet_parsed["sc_transport"] = "quiet"
        return quiet_proc, quiet_parsed

    verbose_proc = subprocess.run(cmd, capture_output=True, text=True)
    verbose_parsed = parse_sc_result(verbose_proc.stdout + verbose_proc.stderr)
    verbose_parsed["sc_transport"] = "verbose_fallback"
    verbose_parsed["quiet_returncode"] = quiet_proc.returncode
    verbose_parsed["quiet_rsp_name"] = quiet_parsed.get("rsp_name")
    verbose_parsed["quiet_payload_words"] = len(quiet_parsed.get("payload", []))
    return verbose_proc, verbose_parsed


def sc_read(sc_tool: Path, link: int, addr: int, count: int, enable_mask: int | None) -> tuple[subprocess.CompletedProcess[str], dict[str, Any]]:
    cmd = [str(sc_tool), str(link), "read", f"0x{addr:05X}", str(count)]
    if enable_mask is not None:
        cmd.extend(["--enable-mask", f"0x{enable_mask:08X}"])
    return _run_sc_command_with_fallback(cmd, count)


def sc_write(sc_tool: Path, link: int, addr: int, words: list[int], enable_mask: int | None) -> tuple[subprocess.CompletedProcess[str], dict[str, Any]]:
    cmd = [str(sc_tool), str(link), "write", f"0x{addr:05X}"]
    cmd.extend(f"0x{word & 0xFFFFFFFF:08X}" for word in words)
    if enable_mask is not None:
        cmd.extend(["--enable-mask", f"0x{enable_mask:08X}"])
    return _run_sc_command_with_fallback(cmd, None)


def signed8(value: int) -> int:
    value &= 0xFF
    return value - 256 if value & 0x80 else value


def float32_bits(value: int) -> float:
    return struct.unpack(">f", value.to_bytes(4, "big"))[0]


def status(ok: bool, warn: bool = False) -> str:
    if not ok:
        return "FAIL"
    return "WARN" if warn else "PASS"


def check_range(value: float, low: float, high: float) -> tuple[bool, bool]:
    if not math.isfinite(value):
        return False, False
    if value < low or value > high:
        return True, True
    return True, False


def add_check(checks: list[dict[str, Any]], name: str, value: Any, result: str, detail: str) -> None:
    checks.append({"name": name, "value": value, "status": result, "detail": detail})


def add_onewire_line_status_checks(checks: list[dict[str, Any]], line_statuses: list[dict[str, Any]]) -> None:
    for item in line_statuses:
        line = item["line"]
        parsed = item.get("parsed", {})
        payload = parsed.get("payload", [])
        ok = item.get("returncode") == 0 and parsed.get("rsp_name") == "OK" and len(payload) == 1
        if not ok:
            add_check(checks, f"onewire.line{line}.status_read", parsed.get("rsp_name", f"returncode={item.get('returncode')}"), "FAIL", "per-line 1-Wire status readback failed")
            continue
        word = payload[0]
        selected = word & 0xFFFF
        processor_go = bool(word & (1 << 16))
        crc_err = bool(word & (1 << 24))
        init_err = bool(word & (1 << 25))
        sample_valid = bool(word & (1 << 26))
        add_check(checks, f"onewire.line{line}.selected", selected, status(selected == line), "STATUS.sel_line should echo the requested DQ line")
        add_check(checks, f"onewire.line{line}.processor_go", int(processor_go), status(processor_go), "processor_go must remain asserted to run the background temperature loop")
        add_check(checks, f"onewire.line{line}.crc_err", int(crc_err), status(not crc_err, crc_err), "CRC error should stay clear for a healthy 1-Wire sensor read")
        add_check(checks, f"onewire.line{line}.init_err", int(init_err), status(not init_err, init_err), "initialization error should stay clear for a detected/powered 1-Wire sensor")
        add_check(
            checks,
            f"onewire.line{line}.sample_valid",
            int(sample_valid),
            "PASS" if sample_valid else "WARN",
            "sample_valid can clear immediately after selecting a line; aggregate sensor temperatures are the hard health gate",
        )


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


def analyze(blocks: dict[str, list[int]], read_status: dict[str, str], max10_expected_id: int, firefly2_present: bool) -> list[dict[str, Any]]:
    checks: list[dict[str, Any]] = []

    ow = blocks.get("onewire_master_controller_0", [])
    if ow and read_status.get("onewire_master_controller_0") == "OK":
        ow_map = detect_onewire_map(ow)
        if ow_map.kind == "common_header":
            add_check(checks, "onewire.uid", f"0x{ow[0]:08X}", status(ow[0] == ONEWIRE_UID), "common CSR header UID should identify the upgraded OneWire controller")
        map_ok = len(ow) > max(ow_map.cap_idx, ow_map.status_idx)
        if not map_ok:
            add_check(checks, "onewire.map", {"kind": ow_map.kind, "words": len(ow)}, "FAIL", "1-Wire block did not return enough words for its detected CSR map")
            return checks
        capability = ow[ow_map.cap_idx]
        n_dq = capability & 0xFFFF
        status_word = ow[ow_map.status_idx]
        crc_err = bool(status_word & (1 << 24))
        init_err = bool(status_word & (1 << 25))
        sample_valid = bool(status_word & (1 << 26))
        add_check(checks, "onewire.capability.n_dq_lines", n_dq, status(n_dq > 0), "expected at least one synthesized 1-Wire DQ line")
        add_check(checks, "onewire.status.crc_err", int(crc_err), status(not crc_err, crc_err), "sticky CRC error flag should normally be clear")
        add_check(checks, "onewire.status.init_err", int(init_err), status(not init_err, init_err), "sticky init error flag should normally be clear")
        add_check(checks, "onewire.status.sample_valid", int(sample_valid), status(sample_valid), "selected 1-Wire line should have captured at least one full scratchpad")
        valid_temps = []
        for idx, raw in enumerate(ow[ow_map.temp_start_idx : ow_map.temp_start_idx + min(6, max(0, len(ow) - ow_map.temp_start_idx))]):
            temp_c = float32_bits(raw)
            ok, warn = check_range(temp_c, -40.0, 125.0)
            warn = warn or (ok and not (5.0 <= temp_c <= 85.0))
            default_one_c = raw == 0x3F800000
            if ok and not warn:
                valid_temps.append(temp_c)
            add_check(
                checks,
                f"onewire.sensor{idx}.temp_c",
                round(temp_c, 3) if math.isfinite(temp_c) else str(temp_c),
                "FAIL" if default_one_c else status(ok, warn),
                "expected finite board temperature in [-40, 125] C, normally within [5, 85] C on a populated bench board; 1.0 C is treated as the old default/stale-loop signature",
            )
        add_check(checks, "onewire.sensor.valid_count", len(valid_temps), status(len(valid_temps) > 0), "at least one 1-Wire temperature should decode as a non-default-looking board temperature")
    else:
        add_check(checks, "onewire.read", read_status.get("onewire_master_controller_0", "NO_READ"), "FAIL", "1-Wire monitor block did not return all expected words")

    max10 = blocks.get("max10_prog_avmm_0", [])
    if len(max10) >= 4 and read_status.get("max10_prog_avmm_0") == "OK":
        add_check(checks, "max10.id", f"0x{max10[0]:08X}", status(max10[0] == max10_expected_id), f"expected 0x{max10_expected_id:08X}")
        add_check(checks, "max10.version", f"0x{max10[1]:08X}", status(max10[1] == 0x00020000, max10[1] != 0x00020000), "expected legacy interface version 0x00020000")
        busy = bool(max10[3] & 0x2)
        fault = bool(max10[3] & 0x4)
        add_check(checks, "max10.status.busy", int(busy), status(not busy, busy), "programmer should be idle during environmental audit")
        add_check(checks, "max10.status.fault", int(fault), status(not fault), "programmer fault bit must be clear")
    else:
        add_check(checks, "max10.read", read_status.get("max10_prog_avmm_0", "NO_READ"), "FAIL", "MAX10 programmer status block did not return expected words")

    ff = blocks.get("firefly_xcvr_ctrl_0", [])
    if len(ff) == 14 and read_status.get("firefly_xcvr_ctrl_0") == "OK":
        for label, word_idx in (("ff1", 0),):
            temp_c = signed8(ff[word_idx])
            ok = temp_c not in (0, -1) and -20 <= temp_c <= 100
            warn = ok and not (10 <= temp_c <= 80)
            add_check(checks, f"firefly.{label}.temp_c", temp_c, status(ok, warn), "expected non-sentinel optical module temperature")
        for label, word_idx in (("ff1.vcc_raw", 1),):
            raw = ff[word_idx] & 0xFFFF
            ok = raw not in (0x0000, 0xFFFF)
            warn = ok and not (25000 <= raw <= 38000)
            add_check(checks, f"firefly.{label}", raw, status(ok, warn), "expected low-16 VCC monitor code to be non-sentinel and near a 3.3 V module rail")
        ff1_power_words = {
            "ff1.rx_power1_raw": ff[2] & 0xFFFF,
            "ff1.rx_power2_raw": ff[3] & 0xFFFF,
            "ff1.rx_power3_raw": ff[4] & 0xFFFF,
            "ff1.rx_power4_raw": ff[5] & 0xFFFF,
        }
        nonzero_power = 0
        for name, raw in ff1_power_words.items():
            ok = raw != 0xFFFF
            warn = raw == 0
            if raw not in (0, 0xFFFF):
                nonzero_power += 1
            add_check(checks, f"firefly.{name}", raw, status(ok, warn), "expected optical-power monitor code to avoid 0xFFFF; zero means unplugged/dark channel or stale poll")
        ff2_temp = signed8(ff[7])
        ff2_vcc = ff[8] & 0xFFFF
        ff2_power_words = [ff[idx] & 0xFFFF for idx in (9, 10, 11, 12)]
        if firefly2_present:
            ok = ff2_temp not in (0, -1) and -20 <= ff2_temp <= 100
            warn = ok and not (10 <= ff2_temp <= 80)
            add_check(checks, "firefly.ff2.temp_c", ff2_temp, status(ok, warn), "expected non-sentinel optical module temperature")
            ok = ff2_vcc not in (0x0000, 0xFFFF)
            warn = ok and not (25000 <= ff2_vcc <= 38000)
            add_check(checks, "firefly.ff2.vcc_raw", ff2_vcc, status(ok, warn), "expected low-16 VCC monitor code to be non-sentinel and near a 3.3 V module rail")
            for idx, raw in enumerate(ff2_power_words, start=1):
                ok = raw != 0xFFFF
                warn = raw == 0
                if raw not in (0, 0xFFFF):
                    nonzero_power += 1
                add_check(checks, f"firefly.ff2.rx_power{idx}_raw", raw, status(ok, warn), "expected optical-power monitor code to avoid 0xFFFF; zero means unplugged/dark channel or stale poll")
        else:
            absent = ff2_temp in (0, -1) and ff2_vcc == 0xFFFF and all(raw == 0xFFFF for raw in ff2_power_words)
            add_check(
                checks,
                "firefly.ff2.expected_absent",
                {"temp_c": ff2_temp, "vcc_raw": ff2_vcc, "rx_power_raw": ff2_power_words},
                "PASS" if absent else "WARN",
                "Firefly 2 is expected to be dangling on this Phase-5 setup; non-sentinel values should be explained",
            )
        add_check(checks, "firefly.rx_power.nonzero_count", nonzero_power, status(nonzero_power > 0, nonzero_power == 0), "at least one optical power channel should be nonzero on a cabled board")
    else:
        add_check(checks, "firefly.read", read_status.get("firefly_xcvr_ctrl_0", "NO_READ"), "FAIL", "Firefly monitor block did not return all expected words")

    od = blocks.get("on_die_temp_sense_ctrl", [])
    if len(od) == 1 and read_status.get("on_die_temp_sense_ctrl") == "OK":
        temp_c = signed8(od[0])
        ok = temp_c not in (0, -1) and -20 <= temp_c <= 110
        warn = ok and not (10 <= temp_c <= 90)
        add_check(checks, "on_die.temp_c", temp_c, status(ok, warn), "expected non-sentinel Arria-V die temperature")
    else:
        add_check(checks, "on_die.read", read_status.get("on_die_temp_sense_ctrl", "NO_READ"), "FAIL", "on-die temperature block did not return expected word")

    legacy = read_status.get("legacy_firefly_bridge", "NO_READ")
    add_check(
        checks,
        "legacy_firefly_bridge.reachability",
        legacy,
        "PASS" if legacy == "OK" else "WARN",
        "legacy bridge read is informational; primary Firefly monitor is firefly_xcvr_ctrl_0",
    )

    return checks


def main() -> int:
    parser = argparse.ArgumentParser(description="Check FEB environmental monitor readbacks for sane values.")
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--enable-mask", type=lambda text: int(text, 0), default=None)
    parser.add_argument("--debug-qsys", type=Path, default=SYN_DIR / "debug_sc_system_v3.qsys")
    parser.add_argument("--max10-expected-id", type=lambda text: int(text, 0), default=None)
    parser.add_argument("--firefly2-present", action="store_true", help="Require Firefly 2 monitor values to be live instead of accepting the dangling-module sentinel pattern.")
    parser.add_argument("--no-start-onewire", action="store_true", help="Do not enable the 1-Wire monitor loop before sampling temperatures.")
    parser.add_argument("--onewire-settle-seconds", type=float, default=15.0, help="Delay after enabling 1-Wire monitor lines before reading temperature CSRs.")
    parser.add_argument("--json-output", type=Path, default=None)
    args = parser.parse_args()
    max10_expected_id = args.max10_expected_id
    if max10_expected_id is None:
        max10_expected_id = qsys_param_int(args.debug_qsys, "max10_prog_avmm_0", "IP_ID", 0x4D313050)

    pre_actions: list[dict[str, Any]] = []
    onewire_status_addr = ONEWIRE_BASE + 1
    if not args.no_start_onewire:
        first_proc, first_parsed = sc_read(args.sc_tool, args.link, ONEWIRE_BASE, 1, args.enable_mask)
        first_ok = first_proc.returncode == 0 and first_parsed.get("rsp_name") == "OK" and len(first_parsed.get("payload", [])) == 1
        first_word = first_parsed.get("payload", [0])[0] if first_ok else 0
        if first_word == ONEWIRE_UID:
            ow_map = detect_onewire_map([first_word])
            cap_proc, cap_parsed = sc_read(args.sc_tool, args.link, ow_map.cap_addr, 1, args.enable_mask)
            cap_ok = cap_proc.returncode == 0 and cap_parsed.get("rsp_name") == "OK" and len(cap_parsed.get("payload", [])) == 1
            n_dq = (cap_parsed.get("payload", [0])[0] & 0xFFFF) if cap_ok else 0
            onewire_status_addr = ow_map.status_addr
            pre_actions.append(
                {
                    "name": "onewire_detect_common_header",
                    "addr": f"0x{ONEWIRE_BASE:05X}",
                    "value": f"UID=0x{first_word:08X}, cap_addr=0x{ow_map.cap_addr:05X}, status_addr=0x{ow_map.status_addr:05X}",
                    "returncode": cap_proc.returncode,
                    "parsed": cap_parsed,
                    "status": "PASS" if cap_ok else "FAIL",
                }
            )
        else:
            n_dq = (first_word & 0xFFFF) if first_ok else 0
        for line in range(min(n_dq, 6)):
            write_value = (1 << 16) | line
            proc, parsed = sc_write(args.sc_tool, args.link, onewire_status_addr, [write_value], args.enable_mask)
            pre_actions.append(
                {
                    "name": f"onewire_start_line{line}",
                    "addr": f"0x{onewire_status_addr:05X}",
                    "value": f"0x{write_value:08X}",
                    "returncode": proc.returncode,
                    "parsed": parsed,
                    "status": "PASS" if proc.returncode == 0 and parsed.get("rsp_name") == "OK" else "FAIL",
                }
            )
        if n_dq:
            time.sleep(max(args.onewire_settle_seconds, 0.0))

    onewire_line_statuses: list[dict[str, Any]] = []
    if not args.no_start_onewire and pre_actions:
        started_lines = [action for action in pre_actions if action["name"].startswith("onewire_start_line")]
        for line in range(len(started_lines)):
            write_value = (1 << 16) | line
            write_proc, write_parsed = sc_write(args.sc_tool, args.link, onewire_status_addr, [write_value], args.enable_mask)
            read_proc, read_parsed = sc_read(args.sc_tool, args.link, onewire_status_addr, 1, args.enable_mask)
            onewire_line_statuses.append(
                {
                    "line": line,
                    "status_addr": f"0x{onewire_status_addr:05X}",
                    "select_returncode": write_proc.returncode,
                    "select_parsed": write_parsed,
                    "returncode": read_proc.returncode,
                    "parsed": read_parsed,
                }
            )

    blocks: dict[str, list[int]] = {}
    read_status: dict[str, str] = {}
    raw_reads: dict[str, dict[str, Any]] = {}
    for block in READ_BLOCKS:
        proc, parsed = sc_read(args.sc_tool, args.link, block.base_word, block.count, args.enable_mask)
        ok = proc.returncode == 0 and parsed.get("rsp_name") == "OK" and len(parsed.get("payload", [])) == block.count
        read_status[block.name] = "OK" if ok else parsed.get("rsp_name", f"returncode={proc.returncode}")
        blocks[block.name] = parsed.get("payload", [])
        raw_reads[block.name] = {
            "addr": f"0x{block.base_word:05X}",
            "count": block.count,
            "returncode": proc.returncode,
            "parsed": parsed,
        }

    checks = analyze(blocks, read_status, max10_expected_id, args.firefly2_present)
    add_onewire_line_status_checks(checks, onewire_line_statuses)
    for action in reversed(pre_actions):
        add_check(
            checks,
            action["name"],
            action["value"],
            action["status"],
            "detected OneWire CSR map or wrote STATUS.sel_line with processor_go=1 to enable the 1-Wire background monitor loop",
        )
    result = {
        "read_status": read_status,
        "pre_actions": pre_actions,
        "onewire_line_statuses": onewire_line_statuses,
        "checks": checks,
        "raw_reads": raw_reads,
        "summary": {
            "PASS": sum(1 for check in checks if check["status"] == "PASS"),
            "WARN": sum(1 for check in checks if check["status"] == "WARN"),
            "FAIL": sum(1 for check in checks if check["status"] == "FAIL"),
        },
    }
    if args.json_output:
        args.json_output.parent.mkdir(parents=True, exist_ok=True)
        args.json_output.write_text(json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    else:
        print(json.dumps(result, indent=2, sort_keys=True))
    return 1 if result["summary"]["FAIL"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
