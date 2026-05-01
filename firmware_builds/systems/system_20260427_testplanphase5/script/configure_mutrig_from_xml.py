#!/usr/bin/env python3
"""Configure MuTRiG3 ASICs from the FE SciFi XML config files over sc_tool."""

from __future__ import annotations

import argparse
import copy
import datetime as dt
import json
import re
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent
REPO_ROOT = BOARD_TEST_DIR.parent.parent.parent

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import _default_sc_tool  # noqa: E402
from probe_phase4_stage_counters import read_frame_rcv_snapshot  # noqa: E402
from run_phase4_emulator import sc_read, sc_write  # noqa: E402


SCRATCH_BASE_WORD = 0x00000
MUTRIG_CFG_BASE_WORD = 0x0FC04
MUTRIG_CFG_OPCODE_STATUS = 0
MUTRIG_CFG_OFFSET = 1
CMD_MUTRIG_ASIC_CFG = 0x011
MUTRIG_CFG_WORDS = 84
FIELD_ORDER = ("Header", "Channel", "TDC", "Footer")


def default_output() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    return BOARD_TEST_DIR / "reports" / f"phase5_mutrig_config_{stamp}.md"


def parse_asic_list(text: str) -> list[int]:
    values: list[int] = []
    for item in text.split(","):
        item = item.strip()
        if not item:
            continue
        if "-" in item:
            start_text, stop_text = item.split("-", 1)
            start = int(start_text, 0)
            stop = int(stop_text, 0)
            if stop < start:
                raise argparse.ArgumentTypeError("ASIC ranges must be increasing")
            values.extend(range(start, stop + 1))
        else:
            values.append(int(item, 0))
    if not values:
        raise argparse.ArgumentTypeError("ASIC list is empty")
    bad = [value for value in values if value < 0 or value > 7]
    if bad:
        raise argparse.ArgumentTypeError(f"ASIC IDs out of range 0..7: {bad}")
    return sorted(dict.fromkeys(values))


def parse_channel_mask(text: str) -> int:
    value = int(text, 0)
    if value < 0 or value > 0xFFFFFFFF:
        raise argparse.ArgumentTypeError("channel mask must be in range 0x00000000..0xffffffff")
    return value


def parse_asic_field_override(text: str) -> tuple[int, str, int]:
    try:
        asic_text, assignment = text.split(":", 1)
        name, value_text = assignment.split("=", 1)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("override must use ASIC:tdc_field=value syntax") from exc
    asic = int(asic_text, 0)
    if asic < 0 or asic > 7:
        raise argparse.ArgumentTypeError("override ASIC must be in range 0..7")
    if not re.fullmatch(r"[A-Za-z0-9_]+", name):
        raise argparse.ArgumentTypeError(f"invalid TDC field name {name!r}")
    value = int(value_text, 0)
    if value < 0:
        raise argparse.ArgumentTypeError("TDC override value must be non-negative")
    return asic, name, value


def parse_field_override(text: str) -> tuple[str, int]:
    try:
        name, value_text = text.split("=", 1)
    except ValueError as exc:
        raise argparse.ArgumentTypeError("override must use field=value syntax") from exc
    if not re.fullmatch(r"[A-Za-z0-9_]+", name):
        raise argparse.ArgumentTypeError(f"invalid field name {name!r}")
    value = int(value_text, 0)
    if value < 0:
        raise argparse.ArgumentTypeError("override value must be non-negative")
    return name, value


def group_field_overrides(items: list[tuple[str, int]]) -> dict[str, int]:
    return {name: value for name, value in items}


def group_tdc_overrides(items: list[tuple[int, str, int]]) -> dict[int, dict[str, int]]:
    grouped: dict[int, dict[str, int]] = {}
    for asic, name, value in items:
        grouped.setdefault(asic, {})[name] = value
    return grouped


def group_asic_field_overrides(items: list[tuple[int, str, int]]) -> dict[int, dict[str, int]]:
    return group_tdc_overrides(items)


def extract_param_info(bsp_path: Path) -> dict[str, list[tuple[str, int, int]]]:
    text = bsp_path.read_text(encoding="utf-8")
    spans = {
        "Header": ("set mutrig_header_param", "set mutrig_ch_param"),
        "Channel": ("set mutrig_ch_param", "set mutrig_tdc_param"),
        "TDC": ("set mutrig_tdc_param", "set mutrig_footer_param"),
        "Footer": ("set mutrig_footer_param", "switch $fieldName"),
    }
    result: dict[str, list[tuple[str, int, int]]] = {}
    for field, (start_marker, stop_marker) in spans.items():
        start = text.index(start_marker)
        stop = text.index(stop_marker, start + len(start_marker))
        block = text[start:stop]
        entries = [
            (name.strip(), int(width), int(order))
            for name, width, order in re.findall(r'\{"([^"]+)"\s+(\d+)\s+(\d+)\}', block)
        ]
        if not entries:
            raise RuntimeError(f"failed to extract {field} parameter list from {bsp_path}")
        result[field] = entries
    return result


def child_int(parent: ET.Element, name: str) -> int:
    node = parent.find(name)
    if node is None or node.text is None:
        raise KeyError(name)
    text = node.text.strip()
    if text == "":
        raise KeyError(name)
    return int(text, 0)


def param_value(mutrig: ET.Element, field: str, param: str, channel: int | None = None) -> int:
    params = mutrig.find("parameters")
    if params is None:
        raise RuntimeError("mutrig entry has no parameters node")
    if field == "Channel":
        if channel is None:
            raise RuntimeError("channel parameter requested without channel index")
        parent = params.find(f"Channel/ch{channel}")
    else:
        parent = params.find(field)
    if parent is None:
        raise RuntimeError(f"missing XML node for {field}{'' if channel is None else f'/ch{channel}'}")
    return child_int(parent, param)


def set_child_int(parent: ET.Element, name: str, value: int) -> None:
    node = parent.find(name)
    if node is None:
        raise RuntimeError(f"missing XML node {name}")
    node.text = str(value)


def apply_channel_overrides(
    mutrig: ET.Element,
    *,
    channel_enable_mask: int | None = None,
    tdctest_channel_mask: int | None = None,
) -> ET.Element:
    if channel_enable_mask is None and tdctest_channel_mask is None:
        return mutrig

    patched = copy.deepcopy(mutrig)
    params = patched.find("parameters")
    channel_root = params.find("Channel") if params is not None else None
    if channel_root is None:
        raise RuntimeError("mutrig entry has no parameters/Channel node")

    for channel in range(32):
        node = channel_root.find(f"ch{channel}")
        if node is None:
            raise RuntimeError(f"missing Channel/ch{channel} node")
        if channel_enable_mask is not None:
            # MuTRiG XML uses mask=1 as disabled; keep selected channels unmasked.
            set_child_int(node, "mask", 0 if (channel_enable_mask & (1 << channel)) else 1)
        if tdctest_channel_mask is not None:
            # tdctest_n is active-low: 0 enables the channel's test-pulse path.
            set_child_int(node, "tdctest_n", 0 if (tdctest_channel_mask & (1 << channel)) else 1)
    return patched


def apply_tdc_overrides(mutrig: ET.Element, overrides: dict[str, int]) -> ET.Element:
    if not overrides:
        return mutrig

    patched = copy.deepcopy(mutrig)
    params = patched.find("parameters")
    tdc_root = params.find("TDC") if params is not None else None
    if tdc_root is None:
        raise RuntimeError("mutrig entry has no parameters/TDC node")

    for name, value in overrides.items():
        set_child_int(tdc_root, name, value)
    return patched


def apply_header_overrides(mutrig: ET.Element, overrides: dict[str, int]) -> ET.Element:
    if not overrides:
        return mutrig

    patched = copy.deepcopy(mutrig)
    params = patched.find("parameters")
    header_root = params.find("Header") if params is not None else None
    if header_root is None:
        raise RuntimeError("mutrig entry has no parameters/Header node")

    for name, value in overrides.items():
        set_child_int(header_root, name, value)
    return patched


def apply_channel_field_overrides(mutrig: ET.Element, overrides: dict[str, int]) -> ET.Element:
    if not overrides:
        return mutrig

    patched = copy.deepcopy(mutrig)
    params = patched.find("parameters")
    channel_root = params.find("Channel") if params is not None else None
    if channel_root is None:
        raise RuntimeError("mutrig entry has no parameters/Channel node")

    for channel in range(32):
        node = channel_root.find(f"ch{channel}")
        if node is None:
            raise RuntimeError(f"missing Channel/ch{channel} node")
        for name, value in overrides.items():
            set_child_int(node, name, value)
    return patched


def append_param_bits(bits: list[str], value: int, width: int, reverse: int, label: str) -> None:
    if value < 0 or value >= (1 << width):
        raise ValueError(f"{label}={value} does not fit in {width} bits")
    chunk = f"{value:0{width}b}"
    if reverse:
        chunk = chunk[::-1]
    bits.append(chunk)


def pack_words(mutrig: ET.Element, param_info: dict[str, list[tuple[str, int, int]]]) -> list[int]:
    bits: list[str] = []
    for field in FIELD_ORDER:
        entries = param_info[field]
        if field == "Channel":
            for channel in range(32):
                for name, width, reverse in entries:
                    value = param_value(mutrig, field, name, channel)
                    append_param_bits(bits, value, width, reverse, f"{field}.ch{channel}.{name}")
        else:
            for name, width, reverse in entries:
                value = param_value(mutrig, field, name)
                append_param_bits(bits, value, width, reverse, f"{field}.{name}")

    bit_stream = "".join(bits)
    if len(bit_stream) != 2662:
        raise RuntimeError(f"unexpected MuTRiG3 bitstream length {len(bit_stream)}, expected 2662")
    pad = (-len(bit_stream)) % 32
    bit_stream += "0" * pad
    words = []
    for idx in range(0, len(bit_stream), 32):
        word_bits = bit_stream[idx : idx + 32]
        words.append(int(word_bits[::-1], 2))
    if len(words) != MUTRIG_CFG_WORDS:
        raise RuntimeError(f"packed {len(words)} words, expected {MUTRIG_CFG_WORDS}")
    return words


def load_mutrigs(xml_path: Path) -> dict[int, ET.Element]:
    root = ET.parse(xml_path).getroot()
    result: dict[int, ET.Element] = {}
    for mutrig in root.findall(".//mutrig"):
        index_node = mutrig.find("index")
        if index_node is None or index_node.text is None:
            continue
        index = int(index_node.text.strip(), 0)
        result[index] = mutrig
    if not result:
        raise RuntimeError(f"no mutrig entries found in {xml_path}")
    return result


def write_cfg_words(sc_tool: Path, link: int, words: list[int]) -> None:
    for offset in range(0, len(words), 16):
        sc_write(sc_tool, link, SCRATCH_BASE_WORD + offset, words[offset : offset + 16])


def poll_idle(sc_tool: Path, link: int, timeout_s: float) -> tuple[int, list[int]]:
    deadline = time.monotonic() + timeout_s
    samples: list[int] = []
    last = 0
    while time.monotonic() < deadline:
        last = sc_read(sc_tool, link, MUTRIG_CFG_BASE_WORD + MUTRIG_CFG_OPCODE_STATUS, 1)[0]
        samples.append(last)
        if last == 0:
            return last, samples
        time.sleep(0.02)
    return last, samples


def configure_one(args: argparse.Namespace, asic: int, mutrig: ET.Element, words: list[int]) -> dict[str, Any]:
    local_index = int((mutrig.findtext("index") or "0").strip(), 0)
    before = read_frame_rcv_snapshot(args.sc_tool, args.link)
    idle_before = sc_read(args.sc_tool, args.link, MUTRIG_CFG_BASE_WORD + MUTRIG_CFG_OPCODE_STATUS, 1)[0]
    if idle_before != 0 and not args.force:
        raise RuntimeError(f"mutrig_cfg_ctrl not idle before ASIC {asic}: 0x{idle_before:08X}")

    if not args.dry_run:
        write_cfg_words(args.sc_tool, args.link, words)
        sc_write(args.sc_tool, args.link, MUTRIG_CFG_BASE_WORD + MUTRIG_CFG_OFFSET, [0])
        opcode = ((CMD_MUTRIG_ASIC_CFG & 0xFFF) << 20) | ((asic & 0xF) << 16) | MUTRIG_CFG_WORDS
        sc_write(args.sc_tool, args.link, MUTRIG_CFG_BASE_WORD + MUTRIG_CFG_OPCODE_STATUS, [opcode])
        final_status, samples = poll_idle(args.sc_tool, args.link, args.timeout_s)
    else:
        opcode = ((CMD_MUTRIG_ASIC_CFG & 0xFFF) << 20) | ((asic & 0xF) << 16) | MUTRIG_CFG_WORDS
        final_status, samples = idle_before, [idle_before]

    time.sleep(args.post_config_ms / 1000.0)
    after = read_frame_rcv_snapshot(args.sc_tool, args.link)
    frame_delta = (after[asic]["open_frame_count"] - before[asic]["open_frame_count"]) & 0xFFFFFFFF
    crc_delta = (after[asic]["crc_err"] - before[asic]["crc_err"]) & 0xFFFFFFFF
    return {
        "asic": asic,
        "xml_local_index": local_index,
        "opcode": opcode,
        "word_count": len(words),
        "first_words": words[:4],
        "last_words": words[-4:],
        "idle_before": idle_before,
        "final_status": final_status,
        "poll_samples": samples[:16],
        "poll_sample_count": len(samples),
        "frame_before": before[asic],
        "frame_after": after[asic],
        "frame_delta": frame_delta,
        "crc_delta": crc_delta,
        "pass": final_status == 0 and (args.dry_run or args.allow_idle_after_config or frame_delta > 0),
    }


def write_report(path: Path, timestamp: str, args: argparse.Namespace, rows: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Phase 5 MuTRiG XML Configuration Report",
        "",
        f"- Timestamp: `{timestamp}`",
        f"- SC link: `{args.link}`",
        f"- SMB3 XML: `{args.smb3_xml}`",
        f"- SMB5 XML: `{args.smb5_xml}`",
        f"- Dry run: `{'yes' if args.dry_run else 'no'}`",
        f"- Channel enable override: `{f'0x{args.channel_enable_mask:08X}' if args.channel_enable_mask is not None else 'none'}`",
        f"- TDC-test channel override: `{f'0x{args.tdctest_channel_mask:08X}' if args.tdctest_channel_mask is not None else 'none'}`",
        f"- Channel field overrides: `{args.set_channel if args.set_channel else 'none'}`",
        f"- Header field overrides: `{args.set_header if args.set_header else 'none'}`",
        f"- TDC field overrides: `{args.set_tdc if args.set_tdc else 'none'}`",
        f"- CML flush after config: `{'yes' if args.cml_flush_after_config else 'no'}`",
        f"- CML start/flush/final values: `{args.cml_start_value}` / `{args.cml_flush_value}` / `{args.cml_final_value}`",
        f"- Force `cml_sc=0` during CML flush/final: `{'yes' if args.cml_flush_set_cml_sc_zero else 'no'}`",
        f"- Require frame delta after config: `{'no' if args.allow_idle_after_config else 'yes'}`",
        f"- Result: `{'PASS' if all(row['pass'] for row in rows) else 'FAIL'}`",
        "",
        "| Phase | ASIC | XML Local | Opcode | Words | Final Status | Frame Delta | CRC Delta | Result |",
        "|---|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in rows:
        lines.append(
            f"| `{row.get('phase', 'main')}` | {row['asic']} | {row['xml_local_index']} | `0x{row['opcode']:08X}` | {row['word_count']} | "
            f"`0x{row['final_status']:08X}` | {row['frame_delta']} | {row['crc_delta']} | "
            f"`{'PASS' if row['pass'] else 'FAIL'}` |"
        )
    lines.extend(["", "## Packed Word Preview", ""])
    for row in rows:
        first_words = ", ".join(f"0x{word:08X}" for word in row["first_words"])
        last_words = ", ".join(f"0x{word:08X}" for word in row["last_words"])
        lines.append(f"- {row.get('phase', 'main')} ASIC {row['asic']}: first `{first_words}`, last `{last_words}`")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Configure MuTRiG3 ASICs from XML files through sc_tool.")
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument(
        "--bsp",
        type=Path,
        default=REPO_ROOT / "toolkits" / "fe_scifi" / "system_console" / "lib" / "mutrig_controller_bsp.tcl",
    )
    parser.add_argument(
        "--smb3-xml",
        type=Path,
        default=REPO_ROOT / "board_test_system" / "trash_bin" / "good_ribbon_0" / "config_smb3_tdc.txt",
    )
    parser.add_argument(
        "--smb5-xml",
        type=Path,
        default=REPO_ROOT / "board_test_system" / "trash_bin" / "good_ribbon_0" / "config_smb5_tdc.txt",
    )
    parser.add_argument("--asics", type=parse_asic_list, default=parse_asic_list("0-7"))
    parser.add_argument(
        "--channel-enable-mask",
        type=parse_channel_mask,
        default=None,
        help="Optional 32-bit channel mask override; selected channels get XML mask=0, others mask=1.",
    )
    parser.add_argument(
        "--tdctest-channel-mask",
        type=parse_channel_mask,
        default=None,
        help="Optional 32-bit TDC-test override; selected channels get tdctest_n=0, others tdctest_n=1.",
    )
    parser.add_argument("--timeout-s", type=float, default=5.0)
    parser.add_argument("--post-config-ms", type=int, default=100)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument(
        "--set-tdc",
        action="append",
        type=parse_asic_field_override,
        default=[],
        metavar="ASIC:FIELD=VALUE",
        help="Override one TDC XML field for one global ASIC before packing, e.g. 2:vnvcodelay=34.",
    )
    parser.add_argument(
        "--set-header",
        action="append",
        type=parse_asic_field_override,
        default=[],
        metavar="ASIC:FIELD=VALUE",
        help="Override one Header XML field for one global ASIC before packing, e.g. 6:ext_trig_offset=1.",
    )
    parser.add_argument(
        "--set-channel",
        action="append",
        type=parse_field_override,
        default=[],
        metavar="FIELD=VALUE",
        help="Override one channel XML field on all 32 channels of each selected ASIC before packing, e.g. recv_all=0.",
    )
    parser.add_argument(
        "--allow-idle-after-config",
        action="store_true",
        help="Treat final_status=0 as PASS even if the post-config frame counter does not advance.",
    )
    parser.add_argument(
        "--cml-flush-after-config",
        action="store_true",
        help=(
            "After the normal XML/SPI load, force the selected ASICs through "
            "channel CML start/flush/final phases: cml=--cml-start-value, "
            "cml=--cml-flush-value, then cml=--cml-final-value. Use this for "
            "the TDC-injection CML 0-8-0 charge-flush sequence."
        ),
    )
    parser.add_argument(
        "--cml-start-value",
        type=int,
        default=0,
        help="Channel cml value used for the explicit first phase of the CML charge flush.",
    )
    parser.add_argument(
        "--cml-flush-value",
        type=int,
        default=8,
        help="Channel cml value used for the high-CML flush phase.",
    )
    parser.add_argument(
        "--cml-final-value",
        type=int,
        default=0,
        help="Channel cml value restored after the high-CML flush phase.",
    )
    parser.add_argument(
        "--cml-flush-set-cml-sc-zero",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Also force channel cml_sc=0 during the flush and final CML phases.",
    )
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--json-output", type=Path, default=None)
    args = parser.parse_args()
    if args.cml_start_value < 0 or args.cml_flush_value < 0 or args.cml_final_value < 0:
        parser.error("--cml-start-value, --cml-flush-value, and --cml-final-value must be non-negative")

    timestamp = dt.datetime.now().isoformat(timespec="seconds")
    output = args.output or default_output()
    json_output = args.json_output or output.with_suffix(".json")

    param_info = extract_param_info(args.bsp)
    smb3 = load_mutrigs(args.smb3_xml)
    smb5 = load_mutrigs(args.smb5_xml)
    tdc_overrides = group_tdc_overrides(args.set_tdc)
    header_overrides = group_asic_field_overrides(args.set_header)
    channel_field_overrides = group_field_overrides(args.set_channel)

    phase_overrides: list[tuple[str, dict[str, int]]] = [("main", {})]
    if args.cml_flush_after_config:
        start_override = {"cml": args.cml_start_value}
        flush_override = {"cml": args.cml_flush_value}
        final_override = {"cml": args.cml_final_value}
        if args.cml_flush_set_cml_sc_zero:
            start_override["cml_sc"] = 0
            flush_override["cml_sc"] = 0
            final_override["cml_sc"] = 0
        phase_overrides = [
            (f"cml_start_{args.cml_start_value}", start_override),
            (f"cml_flush_{args.cml_flush_value}", flush_override),
            (f"cml_final_{args.cml_final_value}", final_override),
        ]

    rows: list[dict[str, Any]] = []
    for phase, phase_channel_overrides in phase_overrides:
        effective_channel_overrides = {**channel_field_overrides, **phase_channel_overrides}
        for asic in args.asics:
            local = asic % 4
            mutrigs = smb3 if asic < 4 else smb5
            if local not in mutrigs:
                raise RuntimeError(f"XML for ASIC {asic} missing local mutrig index {local}")
            mutrig = apply_channel_overrides(
                mutrigs[local],
                channel_enable_mask=args.channel_enable_mask,
                tdctest_channel_mask=args.tdctest_channel_mask,
            )
            mutrig = apply_channel_field_overrides(mutrig, effective_channel_overrides)
            mutrig = apply_header_overrides(mutrig, header_overrides.get(asic, {}))
            mutrig = apply_tdc_overrides(mutrig, tdc_overrides.get(asic, {}))
            words = pack_words(mutrig, param_info)
            row = configure_one(args, asic, mutrig, words)
            row["phase"] = phase
            row["channel_enable_mask"] = args.channel_enable_mask
            row["tdctest_channel_mask"] = args.tdctest_channel_mask
            row["channel_field_overrides"] = effective_channel_overrides
            row["header_overrides"] = header_overrides.get(asic, {})
            row["tdc_overrides"] = tdc_overrides.get(asic, {})
            rows.append(row)
            print(
                "phase={phase} asic={asic} opcode=0x{opcode:08X} status=0x{status:08X} frame_delta={frame_delta} crc_delta={crc_delta} pass={passed}".format(
                    phase=phase,
                    asic=asic,
                    opcode=row["opcode"],
                    status=row["final_status"],
                    frame_delta=row["frame_delta"],
                    crc_delta=row["crc_delta"],
                    passed=int(row["pass"]),
                )
            )

    write_report(output, timestamp, args, rows)
    json_output.parent.mkdir(parents=True, exist_ok=True)
    json_output.write_text(
        json.dumps(
            {
                "timestamp": timestamp,
                "args": {
                    "link": args.link,
                    "bsp": str(args.bsp),
                    "smb3_xml": str(args.smb3_xml),
                    "smb5_xml": str(args.smb5_xml),
                    "asics": args.asics,
                    "dry_run": args.dry_run,
                    "channel_enable_mask": args.channel_enable_mask,
                    "tdctest_channel_mask": args.tdctest_channel_mask,
                    "set_channel": [f"{name}={value}" for name, value in args.set_channel],
                    "set_header": [f"{asic}:{name}={value}" for asic, name, value in args.set_header],
                    "set_tdc": [f"{asic}:{name}={value}" for asic, name, value in args.set_tdc],
                    "allow_idle_after_config": args.allow_idle_after_config,
                    "cml_flush_after_config": args.cml_flush_after_config,
                    "cml_start_value": args.cml_start_value,
                    "cml_flush_value": args.cml_flush_value,
                    "cml_final_value": args.cml_final_value,
                    "cml_flush_set_cml_sc_zero": args.cml_flush_set_cml_sc_zero,
                },
                "rows": rows,
            },
            indent=2,
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"report={output}")
    print(f"json={json_output}")
    failures = [row for row in rows if not row["pass"]]
    print(f"SUMMARY pass={len(rows) - len(failures)} fail={len(failures)}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
