#!/usr/bin/env python3
"""Generate and optionally load a MuTRiG ASIC configuration via FEB JTAG."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[3]
SYSTEM_CONSOLE = Path("/data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console")
DEFAULT_CONFIG = REPO_ROOT / "board_test_system/trash_bin/good_ribbon_0/config_smb3_tdc.txt"

PARAMS = {
    "Header": [
        ("gen_idle", 1, 0),
        ("sync_ch_rst", 1, 0),
        ("ext_trig_mode", 1, 0),
        ("ext_trig_endtime_sign", 1, 0),
        ("ext_trig_offset", 4, 1),
        ("ext_trig_endtime", 4, 1),
        ("ms_limits", 5, 1),
        ("ms_switch_sel", 1, 0),
        ("ms_debug", 1, 0),
        ("tx_mode", 3, 1),
        ("pll_setcoarse", 1, 0),
        ("pll_envomonitor", 1, 0),
        ("disable_coarse", 1, 0),
        ("pll_lol_dbg", 1, 0),
        ("en_ch_evt_cnt", 1, 0),
        ("dmon_sel", 5, 0),
        ("dmon_sel_enable", 1, 0),
        ("dmon_sw", 1, 0),
    ],
    "Channel": [
        ("energy_c_en", 1, 0),
        ("energy_r_en", 1, 0),
        ("sswitch", 1, 0),
        ("cm_sensing_high_r", 1, 0),
        ("amon_en_n", 1, 0),
        ("edge", 1, 0),
        ("edge_cml", 1, 0),
        ("cml_sc", 1, 0),
        ("tdctest_n", 1, 0),
        ("amonctrl", 3, 0),
        ("comp_spi", 2, 0),
        ("tthresh_offset_1", 1, 0),
        ("sipm", 6, 0),
        ("tthresh_offset_2", 1, 0),
        ("tthresh_sc", 2, 0),
        ("tthresh", 6, 0),
        ("ampcom_sc", 2, 0),
        ("ampcom", 6, 0),
        ("tthresh_offset_0", 1, 0),
        ("inputbias", 6, 0),
        ("ethresh", 8, 0),
        ("ebias", 3, 0),
        ("pole_sc", 1, 0),
        ("pole", 6, 0),
        ("cml", 4, 0),
        ("delay", 1, 0),
        ("pole_en_n", 1, 0),
        ("mask", 1, 0),
        ("recv_all", 1, 0),
    ],
    "TDC": [
        ("vnd2c_scale", 1, 0),
        ("vnd2c_offset", 2, 0),
        ("vnd2c", 6, 0),
        ("vncntbuffer_scale", 1, 0),
        ("vncntbuffer_offset", 2, 0),
        ("vncntbuffer", 6, 0),
        ("vncnt_scale", 1, 0),
        ("vncnt_offset", 2, 0),
        ("vncnt", 6, 0),
        ("vnpcp_scale", 1, 0),
        ("vnpcp_offset", 2, 0),
        ("vnpcp", 6, 0),
        ("vnvcodelay_scale", 1, 0),
        ("vnvcodelay_offset", 2, 0),
        ("vnvcodelay", 6, 0),
        ("vnvcobuffer_scale", 1, 0),
        ("vnvcobuffer_offset", 2, 0),
        ("vnvcobuffer", 6, 0),
        ("vnhitlogic_scale", 1, 0),
        ("vnhitlogic_offset", 2, 0),
        ("vnhitlogic", 6, 0),
        ("vnpfc_scale", 1, 0),
        ("vnpfc_offset", 2, 0),
        ("vnpfc", 6, 0),
        ("latchbias", 12, 1),
    ],
    "Footer": [
        ("coin_xbar_lower_rx_ena", 1, 0),
        ("coin_xbar_lower_tx_ena", 1, 0),
        ("coin_xbar_lower_tx_vdac", 8, 0),
        ("coin_xbar_lower_tx_idac", 6, 0),
        ("coin_mat_xbl", 3, 0),
        ("coin_mat_0", 6, 0),
        ("coin_mat_1", 6, 0),
        ("coin_mat_2", 6, 0),
        ("coin_mat_3", 6, 0),
        ("coin_mat_4", 6, 0),
        ("coin_mat_5", 6, 0),
        ("coin_mat_6", 6, 0),
        ("coin_mat_7", 6, 0),
        ("coin_mat_8", 6, 0),
        ("coin_mat_9", 6, 0),
        ("coin_mat_10", 6, 0),
        ("coin_mat_11", 6, 0),
        ("coin_mat_12", 6, 0),
        ("coin_mat_13", 6, 0),
        ("coin_mat_14", 6, 0),
        ("coin_mat_15", 6, 0),
        ("coin_mat_16", 6, 0),
        ("coin_mat_17", 6, 0),
        ("coin_mat_18", 6, 0),
        ("coin_mat_19", 6, 0),
        ("coin_mat_20", 6, 0),
        ("coin_mat_21", 6, 0),
        ("coin_mat_22", 6, 0),
        ("coin_mat_23", 6, 0),
        ("coin_mat_24", 6, 0),
        ("coin_mat_25", 6, 0),
        ("coin_mat_26", 6, 0),
        ("coin_mat_27", 6, 0),
        ("coin_mat_28", 6, 0),
        ("coin_mat_29", 6, 0),
        ("coin_mat_30", 6, 0),
        ("coin_mat_31", 6, 0),
        ("coin_mat_xbu", 3, 0),
        ("coin_xbar_upper_rx_ena", 1, 0),
        ("coin_xbar_upper_tx_ena", 1, 0),
        ("coin_xbar_upper_tx_vdac", 8, 0),
        ("coin_xbar_upper_tx_idac", 6, 0),
        ("coin_wnd", 1, 0),
        ("amon_en", 1, 0),
        ("amon_dac", 8, 0),
        ("dmon_1_en", 1, 0),
        ("dmon_1_dac", 8, 0),
        ("dmon_2_en", 1, 0),
        ("dmon_2_dac", 8, 0),
        ("lvds_tx_vcm", 8, 0),
        ("lvds_tx_bias", 6, 0),
    ],
}


def parse_int(text: str) -> int:
    return int(str(text).strip(), 0)


def parse_override(item: str) -> tuple[str, int]:
    if "=" not in item:
        raise argparse.ArgumentTypeError(f"override must be name=value: {item}")
    name, value = item.split("=", 1)
    return name.strip(), parse_int(value)


def load_mutrig(path: Path, index: int) -> ET.Element:
    tree = ET.parse(path)
    for mutrig in tree.findall("./SMB/mutrig"):
        value = mutrig.findtext("index")
        if value is not None and int(value.strip(), 0) == index:
            return mutrig
    raise SystemExit(f"MuTRiG index {index} not found in {path}")


def text_value(node: ET.Element, name: str) -> int:
    child = node.find(name)
    if child is None or child.text is None:
        raise KeyError(f"missing XML field {name}")
    return parse_int(child.text)


def clamp_field(name: str, value: int, width: int) -> int:
    limit = (1 << width) - 1
    if value < 0 or value > limit:
        raise ValueError(f"{name}={value} does not fit in {width} bits")
    return value


def apply_overrides(mutrig: ET.Element, overrides: list[tuple[str, int]]) -> None:
    params = mutrig.find("parameters")
    if params is None:
        raise ValueError("missing parameters node")
    for name, value in overrides:
        matches = params.findall(f".//{name}")
        if not matches:
            raise ValueError(f"override field {name} not found")
        for match in matches:
            match.text = str(value)


def apply_channel_masks(mutrig: ET.Element, channel_enable_mask: int | None, tdctest_channel_mask: int | None) -> None:
    channel = mutrig.find("./parameters/Channel")
    if channel is None:
        raise ValueError("missing Channel node")
    for ch in range(32):
        ch_node = channel.find(f"ch{ch}")
        if ch_node is None:
            raise ValueError(f"missing ch{ch}")
        if channel_enable_mask is not None:
            mask_node = ch_node.find("mask")
            if mask_node is None:
                raise ValueError(f"missing ch{ch}.mask")
            mask_node.text = "0" if ((channel_enable_mask >> ch) & 1) else "1"
        if tdctest_channel_mask is not None:
            tdctest_node = ch_node.find("tdctest_n")
            if tdctest_node is None:
                raise ValueError(f"missing ch{ch}.tdctest_n")
            tdctest_node.text = "0" if ((tdctest_channel_mask >> ch) & 1) else "1"


def append_field(bits: list[str], name: str, width: int, reverse: int, value: int) -> None:
    value = clamp_field(name, value, width)
    field = f"{value:0{width}b}"
    if reverse:
        field = field[::-1]
    bits.append(field)


def bitstream_from_mutrig(mutrig: ET.Element) -> str:
    params = mutrig.find("parameters")
    if params is None:
        raise ValueError("missing parameters node")
    bits: list[str] = []

    for name, width, reverse in PARAMS["Header"]:
        append_field(bits, name, width, reverse, text_value(params.find("Header"), name))  # type: ignore[arg-type]

    channel = params.find("Channel")
    if channel is None:
        raise ValueError("missing Channel node")
    for ch in range(32):
        ch_node = channel.find(f"ch{ch}")
        if ch_node is None:
            raise ValueError(f"missing ch{ch}")
        for name, width, reverse in PARAMS["Channel"]:
            append_field(bits, f"ch{ch}.{name}", width, reverse, text_value(ch_node, name))

    for group in ("TDC", "Footer"):
        node = params.find(group)
        if node is None:
            raise ValueError(f"missing {group} node")
        for name, width, reverse in PARAMS[group]:
            append_field(bits, f"{group}.{name}", width, reverse, text_value(node, name))

    return "".join(bits)


def parse_reverse_bit_stream(bitstream: str) -> list[int]:
    words: list[int] = []
    for match in re.finditer(r"\d{1,32}", bitstream):
        reversed_word = match.group(0)[::-1]
        value = 0
        for byte_bits in re.findall(r"\d{1,8}", reversed_word):
            byte_value = int(byte_bits.ljust(8, "0"), 2)
            value = (value << 8) | byte_value
        words.append(value)
    return words


def write_words(path: Path, words: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(f"0x{word:08X}" for word in words) + "\n")


def run_loader(args: argparse.Namespace, words_file: Path) -> subprocess.CompletedProcess[str]:
    cmd = [
        str(args.system_console),
        "-cli",
        "-disable_readline",
        f"--script={SCRIPT_DIR / 'mutrig_config_jtag_load.tcl'}",
        "--",
        "--words-file",
        str(words_file),
        "--asic-id",
        str(args.asic),
        "--scratchpad-base",
        f"0x{args.scratchpad_base:08X}",
        "--controller-offset",
        f"0x{args.controller_offset:08X}",
        "--csr-base",
        f"0x{args.csr_base:08X}",
        "--command-len",
        str(args.command_len),
        "--poll-ms",
        str(args.poll_ms),
        "--timeout-ms",
        str(args.timeout_ms),
        "--master-pattern",
        args.master_pattern,
        "--fallback-pattern",
        args.fallback_pattern,
        "--service-tag",
        args.service_tag,
    ]
    if args.readback:
        cmd.append("--readback")
    env = os.environ.copy()
    env.pop("DISPLAY", None)
    env["_JAVA_OPTIONS"] = "-Djava.awt.headless=true"
    env["BOARD_TEST_SCRIPT_DIR"] = str(SCRIPT_DIR)
    return subprocess.run(cmd, check=False, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    parser.add_argument("--xml-index", type=int, default=0, help="MuTRiG index inside the SMB XML")
    parser.add_argument("--asic", type=int, default=0, help="Physical ASIC select line, 0..7")
    parser.add_argument("--tdc-override", action="append", type=parse_override, default=[])
    parser.add_argument("--channel-enable-mask", type=lambda s: int(s, 0), default=None)
    parser.add_argument("--tdctest-channel-mask", type=lambda s: int(s, 0), default=None)
    parser.add_argument("--words-out", type=Path, default=None)
    parser.add_argument("--json-out", type=Path, default=None)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--readback", action="store_true")
    parser.add_argument("--system-console", type=Path, default=SYSTEM_CONSOLE)
    parser.add_argument("--scratchpad-base", type=lambda s: int(s, 0), default=0x00000000)
    parser.add_argument("--controller-offset", type=lambda s: int(s, 0), default=0x00000000)
    parser.add_argument("--csr-base", type=lambda s: int(s, 0), default=0x0003F010)
    parser.add_argument("--command-len", type=int, default=84)
    parser.add_argument("--poll-ms", type=int, default=10)
    parser.add_argument("--timeout-ms", type=int, default=15000)
    parser.add_argument("--master-pattern", default="*5AG*#7-2*/phy_0/master")
    parser.add_argument("--fallback-pattern", default="*#7-2*/phy_0/master,*phy_0/master")
    parser.add_argument("--service-tag", default="phase6_mutrig_cfg")
    args = parser.parse_args()

    if not (0 <= args.asic <= 7):
        raise SystemExit("--asic must be in 0..7")

    mutrig = load_mutrig(args.config, args.xml_index)
    apply_overrides(mutrig, args.tdc_override)
    apply_channel_masks(mutrig, args.channel_enable_mask, args.tdctest_channel_mask)

    bitstream = bitstream_from_mutrig(mutrig)
    words = parse_reverse_bit_stream(bitstream)
    if len(words) != args.command_len:
        raise SystemExit(f"generated {len(words)} words, command length is {args.command_len}")

    timestamp = time.strftime("%Y%m%d_%H%M%S")
    words_out = args.words_out or (
        REPO_ROOT
        / "firmware_builds/systems/system_20260427_testplanphase5/reports"
        / f"phase6_mutrig_asic{args.asic}_config_words_{timestamp}.txt"
    )
    write_words(words_out, words)

    summary = {
        "status": "generated",
        "config": str(args.config),
        "xml_index": args.xml_index,
        "asic": args.asic,
        "tdc_overrides": [f"{name}={value}" for name, value in args.tdc_override],
        "channel_enable_mask": None if args.channel_enable_mask is None else f"0x{args.channel_enable_mask:08X}",
        "tdctest_channel_mask": None if args.tdctest_channel_mask is None else f"0x{args.tdctest_channel_mask:08X}",
        "bit_count": len(bitstream),
        "word_count": len(words),
        "words_out": str(words_out),
        "first_words": [f"0x{word:08X}" for word in words[:4]],
        "last_words": [f"0x{word:08X}" for word in words[-4:]],
    }

    if not args.dry_run:
        result = run_loader(args, words_out)
        summary["loader_returncode"] = result.returncode
        summary["loader_output"] = result.stdout
        if result.returncode != 0 or "MUTRIG_CFG_JTAG_RESULT status=OK" not in result.stdout:
            print(result.stdout, end="")
            if args.json_out:
                args.json_out.parent.mkdir(parents=True, exist_ok=True)
                args.json_out.write_text(json.dumps(summary, indent=2) + "\n")
            return 2
        summary["status"] = "loaded"
        print(result.stdout, end="")

    if args.json_out:
        args.json_out.parent.mkdir(parents=True, exist_ok=True)
        args.json_out.write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps({k: v for k, v in summary.items() if k != "loader_output"}, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
