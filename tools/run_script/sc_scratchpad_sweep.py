#!/usr/bin/env python3
"""
Scratchpad-only SC stress/sweep tool (link 2 by default).

Modes:
1) read-scan
2) same-address-write-then-read
3) full-scope-write-then-read

Compatibility aliases:
- scan   -> same-address-write-then-read
- burst  -> full-scope-write-then-read (burst profile)
- random -> full-scope-write-then-read (mixed-random profile)

Optional SignalTap verifier:
- For a selected transaction, run two captures:
  - first with TX trigger and strict TX packet match
  - second with RX trigger and strict RX packet match

Notes:
- All tests are constrained to scratchpad SRAM address space.
- Write bursts are emitted as per-word SC write transactions (test_slowcontrol supports single-word write).
"""

import argparse
import csv
import json
import random
import re
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

DEFAULT_ROOT = Path("/home/yifeng/packages/online_sc/online")
DEFAULT_PROJECT_DIR = DEFAULT_ROOT / "switching_pc/a10_board"
DEFAULT_QUARTUS_STP = Path("/data1/intelFPGA/18.1/quartus/bin/quartus_stp")
DEFAULT_TRIGGER_EDITOR = Path("/home/yifeng/.codex/skills/signaltap-creation-co-debug/scripts/set_runtime_trigger.py")


def pick_existing(paths: Sequence[Path]) -> Path:
    for path in paths:
        if path.exists():
            return path
    return paths[0]


def resolve_active_stp_file(project_dir: Path) -> Optional[Path]:
    qsf_path = project_dir / "top.qsf"
    if not qsf_path.exists():
        return None

    assignments: Dict[str, Path] = {}
    pattern = re.compile(r'^\s*set_global_assignment\s+-name\s+(USE_SIGNALTAP_FILE|SIGNALTAP_FILE)\s+"([^"]+)"')

    for line in qsf_path.read_text(encoding="utf-8", errors="replace").splitlines():
        match = pattern.match(line)
        if match is None:
            continue
        stp_path = Path(match.group(2))
        if not stp_path.is_absolute():
            stp_path = project_dir / stp_path
        assignments[match.group(1)] = stp_path

    for key in ("SIGNALTAP_FILE", "USE_SIGNALTAP_FILE"):
        if key in assignments:
            return assignments[key]
    return None


def parse_stp_metadata(stp_path: Path) -> Tuple[str, str, str]:
    root = ET.parse(stp_path).getroot()
    inst = root.find("./instance")
    if inst is None:
        raise SignalTapError(f"STP has no instance: {stp_path}")
    signal_set = inst.find("./signal_set")
    if signal_set is None:
        raise SignalTapError(f"STP has no signal_set: {stp_path}")
    trigger = signal_set.find("./trigger")
    if trigger is None:
        raise SignalTapError(f"STP has no trigger: {stp_path}")
    return (
        inst.get("name", ""),
        signal_set.get("name", ""),
        trigger.get("name", ""),
    )


ACTIVE_STP_FILE = resolve_active_stp_file(DEFAULT_PROJECT_DIR)
DEFAULT_STP_CANDIDATES: List[Path] = []
if ACTIVE_STP_FILE is not None:
    DEFAULT_STP_CANDIDATES.append(ACTIVE_STP_FILE)
DEFAULT_STP_CANDIDATES.extend(
    (
        DEFAULT_PROJECT_DIR / "top_sc_link2_packets_example1_format.stp",
        DEFAULT_PROJECT_DIR / "top_sc_link2_packets.stp",
    )
)


DEFAULT_TEST_BIN = pick_existing(
    (
        DEFAULT_ROOT / "build-codex/switching_pc/tools/test_slowcontrol",
        DEFAULT_ROOT / "build/switching_pc/tools/test_slowcontrol",
        DEFAULT_ROOT / "install/bin/test_slowcontrol",
    )
)
DEFAULT_STP_FILE = pick_existing(tuple(DEFAULT_STP_CANDIDATES))

SCRATCHPAD_BASE = 0x0000
SCRATCHPAD_WORDS = 256
MAX_SC_WORDS_PER_TX = 255

PACKET_RE = re.compile(
    r"SC secondary packet:\s*(?:\r?\n)\s*"
    r"header=0x(?P<header>[0-9A-Fa-f]+)\s+type=(?P<type>RD|WR)\s+resp=(?P<resp>[YN])\s+link=(?P<link>\d+)\s*(?:\r?\n)\s*"
    r"addr=0x(?P<addr>[0-9A-Fa-f]+)\s+len=(?P<len>\d+)"
    r"(?P<payload>(?:\s*(?:\r?\n)\s*payload\[\d+\]=0x[0-9A-Fa-f]+)*)",
    re.MULTILINE,
)
PAYLOAD_RE = re.compile(r"payload\[(\d+)\]=0x([0-9A-Fa-f]+)")
STATUS_RE = re.compile(r"SC Secondary status:\s*0x([0-9A-Fa-f]+)")

STP_TRIGGER_CANDIDATES = {
    "tx": (
        "swb_block:e_swb_block|swb_sc_main:e_sc_main|state.set_fpga_id1",
    ),
    "rx": (
        "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_header_pulse",
        "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_word_valid",
        "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.capture_head",
        "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|mem_wren_o",
        "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|link32_scfifo:\\gen_buffer_sc:2:e_fifo|o_rdata.sop",
    ),
}

RX_TRIGGER_DEBUG_HEADER_SIGNAL = "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_header_pulse"
RX_TRIGGER_DEBUG_VALID_SIGNAL = "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_word_valid"
RX_TRIGGER_HEAD_SIGNAL = "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.capture_head"
RX_TRIGGER_LINK_SIGNALS = (
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|current_link[2]",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|current_link[1]",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|current_link[0]",
)


@dataclass
class Packet:
    header: int
    pkt_type: str
    resp: str
    link: int
    addr: int
    length: int
    payload: List[int]


@dataclass
class CmdResult:
    ok: bool
    rc: int
    cmd: List[str]
    status: Optional[int]
    packets: List[Packet]
    stdout: str
    elapsed_ms: int
    error: Optional[str] = None


@dataclass
class SignalTapCaptureResult:
    ok: bool
    phase: str
    csv_path: str
    quartus_rc: int
    quartus_log: str
    strict_match: bool
    details: Dict


class ScError(RuntimeError):
    pass


class SignalTapError(RuntimeError):
    pass


MODE_READ_SCAN = "read-scan"
MODE_SAME_ADDR = "same-address-write-then-read"
MODE_FULL_SCOPE = "full-scope-write-then-read"


def canonical_mode(mode: str) -> str:
    aliases = {
        "scan": MODE_SAME_ADDR,
        "burst": MODE_FULL_SCOPE,
        "random": MODE_FULL_SCOPE,
        MODE_READ_SCAN: MODE_READ_SCAN,
        MODE_SAME_ADDR: MODE_SAME_ADDR,
        MODE_FULL_SCOPE: MODE_FULL_SCOPE,
    }
    return aliases.get(mode, mode)


def to_int_auto(s: str) -> Optional[int]:
    if s is None:
        return None
    v = s.strip().strip('"')
    if not v:
        return None
    low = v.lower()

    if low in {"x", "z", "u", "?", "n/a"}:
        return None
    if low in {"high", "h"}:
        return 1
    if low in {"low", "l"}:
        return 0

    if re.fullmatch(r"[01]+", v):
        return int(v, 2)
    if low.startswith("0x"):
        try:
            return int(low, 16)
        except ValueError:
            return None
    if re.fullmatch(r"[0-9]+", v):
        try:
            return int(v, 10)
        except ValueError:
            return None
    if re.fullmatch(r"[0-9a-f]+", low):
        try:
            return int(low, 16)
        except ValueError:
            return None
    if re.fullmatch(r"h[0-9a-f]+", low):
        try:
            return int(low[1:], 16)
        except ValueError:
            return None
    m = re.fullmatch(r"(\d+)'h([0-9a-fA-F]+)", v)
    if m:
        try:
            return int(m.group(2), 16)
        except ValueError:
            return None

    return None


def run_cmd(cmd: Sequence[str], cwd: Path, timeout_s: float) -> Tuple[int, str, int]:
    t0 = time.time()
    try:
        cp = subprocess.run(
            list(cmd),
            cwd=str(cwd),
            text=True,
            capture_output=True,
            timeout=timeout_s,
            check=False,
        )
        out = (cp.stdout or "") + (cp.stderr or "")
        rc = cp.returncode
    except subprocess.TimeoutExpired as ex:
        out = ((ex.stdout.decode("utf-8", errors="replace") if isinstance(ex.stdout, bytes) else (ex.stdout or "")) +
               (ex.stderr.decode("utf-8", errors="replace") if isinstance(ex.stderr, bytes) else (ex.stderr or "")) +
               "\n[TIMEOUT]")
        rc = 124
    dt_ms = int((time.time() - t0) * 1000.0)
    return rc, out, dt_ms


def parse_packets(text: str) -> List[Packet]:
    packets: List[Packet] = []
    for m in PACKET_RE.finditer(text):
        payload = [0] * int(m.group("len"))
        payload_block = m.group("payload") or ""
        for pm in PAYLOAD_RE.finditer(payload_block):
            idx = int(pm.group(1))
            val = int(pm.group(2), 16)
            if 0 <= idx < len(payload):
                payload[idx] = val

        packets.append(
            Packet(
                header=int(m.group("header"), 16),
                pkt_type=m.group("type"),
                resp=m.group("resp"),
                link=int(m.group("link")),
                addr=int(m.group("addr"), 16),
                length=int(m.group("len")),
                payload=payload,
            )
        )
    return packets


def parse_status(text: str) -> Optional[int]:
    m = STATUS_RE.search(text)
    if not m:
        return None
    return int(m.group(1), 16)


def status_looks_alive(status: Optional[int]) -> bool:
    if status is None:
        return False
    return (status & 0x1) == 0x1


def run_sc_command(args: argparse.Namespace, extra: Sequence[str], timeout_s: Optional[float] = None) -> CmdResult:
    cmd = [str(args.test_bin), str(args.link)] + list(extra) + ["--once"]
    rc, out, elapsed_ms = run_cmd(cmd, args.root, timeout_s or args.cmd_timeout)
    packets = parse_packets(out)
    status = parse_status(out)

    ok = rc == 0
    return CmdResult(
        ok=ok,
        rc=rc,
        cmd=cmd,
        status=status,
        packets=packets,
        stdout=out,
        elapsed_ms=elapsed_ms,
        error=None if ok else f"command rc={rc}",
    )


def find_packet(packets: Sequence[Packet], pkt_type: str, resp: str, link: int, addr: int, length: int) -> Optional[Packet]:
    for p in packets:
        if p.pkt_type == pkt_type and p.resp == resp and p.link == link and p.addr == addr and p.length == length:
            return p
    return None


def sc_read(args: argparse.Namespace, addr: int, length: int) -> List[int]:
    if length <= 0 or length > MAX_SC_WORDS_PER_TX:
        raise ScError(f"invalid read length {length}")

    last_err = None
    for _ in range(args.retries + 1):
        res = run_sc_command(args, ["--read", f"0x{addr:X}", str(length)])
        pkt = find_packet(res.packets, "RD", "Y", args.link, addr, length)
        if res.rc == 0 and pkt is not None and len(pkt.payload) == length:
            return pkt.payload
        last_err = f"read failed addr=0x{addr:X} len={length} rc={res.rc} status={res.status}"
    raise ScError(last_err or "read failed")


def sc_write_word(args: argparse.Namespace, addr: int, value: int) -> None:
    last_err = None
    for _ in range(args.retries + 1):
        res = run_sc_command(args, ["--write", f"0x{addr:X}", f"0x{value & 0xFFFFFFFF:X}"])
        pkt = find_packet(res.packets, "WR", "Y", args.link, addr, 0)
        if res.rc == 0 and pkt is not None:
            return
        last_err = f"write failed addr=0x{addr:X} value=0x{value:08X} rc={res.rc} status={res.status}"
    raise ScError(last_err or "write failed")


def sc_read_region(args: argparse.Namespace, addr: int, length: int) -> List[int]:
    out: List[int] = []
    cur = addr
    rem = length
    while rem > 0:
        n = min(MAX_SC_WORDS_PER_TX, rem)
        out.extend(sc_read(args, cur, n))
        cur += n
        rem -= n
    return out


def pick_trigger_signal(stp_path: Path, phase: str) -> str:
    candidates = STP_TRIGGER_CANDIDATES.get(phase)
    if not candidates:
        raise ValueError(f"unknown phase {phase}")

    stp_text = stp_path.read_text(encoding="utf-8", errors="replace")
    for signal_name in candidates:
        if re.search(rf'<(?:node|net)\b[^>]*\bname="{re.escape(signal_name)}"', stp_text):
            return signal_name

    raise SignalTapError(
        f"no trigger candidate from phase={phase} exists in {stp_path}"
    )


def rx_compound_trigger_terms(current_link_value: int) -> Tuple[Tuple[str, str], ...]:
    if current_link_value < 0 or current_link_value > 7:
        raise SignalTapError(f"stp rx current_link must be in range 0..7, got {current_link_value}")

    terms = [(RX_TRIGGER_HEAD_SIGNAL, "high")]
    for bit_pos, signal_name in zip((2, 1, 0), RX_TRIGGER_LINK_SIGNALS):
        bit_is_set = (current_link_value >> bit_pos) & 0x1
        terms.append((signal_name, "high" if bit_is_set else "low"))
    return tuple(terms)


def trigger_expr_for_phase(stp_path: Path, phase: str, rx_current_link: Optional[int] = None) -> str:
    if phase == "rx":
        stp_text = stp_path.read_text(encoding="utf-8", errors="replace")
        for signal_name in (RX_TRIGGER_DEBUG_HEADER_SIGNAL, RX_TRIGGER_DEBUG_VALID_SIGNAL):
            if re.search(rf'<(?:node|net)\b[^>]*\bname="{re.escape(signal_name)}"', stp_text):
                return f"'{signal_name}' == high"

        if rx_current_link is not None:
            trigger_terms = rx_compound_trigger_terms(rx_current_link)
            if all(
                re.search(rf'<(?:node|net)\b[^>]*\bname="{re.escape(signal_name)}"', stp_text)
                for signal_name, _ in trigger_terms
            ):
                return " && ".join(
                    f"'{signal_name}' == {condition}"
                    for signal_name, condition in trigger_terms
                )
    return f"'{pick_trigger_signal(stp_path, phase)}' == high"


def stp_supports_phase(stp_path: Path, phase: str) -> bool:
    try:
        pick_trigger_signal(stp_path, phase)
        return True
    except SignalTapError:
        return False


def find_condition1_level(root: ET.Element) -> Optional[ET.Element]:
    level = root.find("./instance/signal_set/trigger/events/level[@name='condition1']")
    if level is not None:
        return level
    level = root.find("./instance/signal_set/trigger/level[@name='condition1']")
    if level is not None:
        return level
    return root.find(".//level[@name='condition1']")


def patch_stp_trigger(stp_text: str, trigger_expr: str) -> str:
    try:
        root = ET.fromstring(stp_text)
    except ET.ParseError as ex:
        raise SignalTapError(f"failed to parse STP XML: {ex}") from ex

    level = find_condition1_level(root)
    if level is None:
        raise SignalTapError("cannot locate condition1 trigger expression in STP file")
    level.text = trigger_expr
    return ET.tostring(root, encoding="unicode")


def patch_trigger_level_attrs(stp_text: str, level_map: Dict[str, str]) -> str:
    tag_re = re.compile(r'<(?:node|net)\b[^>]*>')

    def repl(match) -> str:
        tag = match.group(0)
        name_match = re.search(r'\bname="([^"]*)"', tag)
        level_match = re.search(r'\blevel-0="([^"]*)"', tag)
        if name_match is None or level_match is None:
            return tag

        name = name_match.group(1)
        current = level_match.group(1)
        if name in level_map:
            return re.sub(r'\blevel-0="[^"]*"', f'level-0="{level_map[name]}"', tag, count=1)
        if current in {"rising edge", "falling edge", "high", "low"}:
            return re.sub(r'\blevel-0="[^"]*"', 'level-0="dont_care"', tag, count=1)
        return tag

    return tag_re.sub(repl, stp_text)


def current_trigger_expr(stp_path: Path) -> Optional[str]:
    try:
        root = ET.fromstring(stp_path.read_text(encoding="utf-8", errors="replace"))
    except ET.ParseError:
        return None
    level = find_condition1_level(root)
    if level is None or level.text is None:
        return None
    return level.text.strip()


def apply_runtime_trigger_edit(stp_path: Path, phase: str, rx_current_link: Optional[int] = None) -> None:
    desired_expr = trigger_expr_for_phase(stp_path, phase, rx_current_link=rx_current_link)
    if current_trigger_expr(stp_path) == desired_expr:
        return

    simple_match = re.fullmatch(r"'([^']+)'\s*==\s*(rising edge|falling edge|high|low)", desired_expr)
    if simple_match is not None:
        signal_name = simple_match.group(1)
        condition = simple_match.group(2)

        cmd = [
            "python3",
            str(DEFAULT_TRIGGER_EDITOR),
            "--stp",
            str(stp_path),
            "--instance",
            "0",
            "--signal",
            signal_name,
            "--condition",
            condition,
            "--no-backup",
        ]
        cp = subprocess.run(cmd, text=True, capture_output=True, check=False)
        if cp.returncode != 0:
            raise SignalTapError(
                "runtime trigger edit failed: "
                + ((cp.stdout or "") + (cp.stderr or "")).strip()
            )
        return

    compound_terms = re.findall(r"'([^']+)'\s*==\s*(high|low|rising edge|falling edge)", desired_expr)
    if not compound_terms:
        raise SignalTapError(f"unsupported trigger expression: {desired_expr}")

    stp_text = stp_path.read_text(encoding="utf-8", errors="replace")
    stp_text = patch_stp_trigger(stp_text, desired_expr)
    stp_text = patch_trigger_level_attrs(stp_text, dict(compound_terms))
    stp_path.write_text(stp_text, encoding="utf-8")


def build_quartus_tcl(path: Path) -> None:
    path.write_text(
        """if {$argc < 8} {
    puts "Usage: <stp> <csv> <instance> <signal_set> <trigger> <stim_script> <timeout> <hw_pattern>"
    exit 2
}
set stp_file [lindex $argv 0]
set csv_out [lindex $argv 1]
set inst_name [lindex $argv 2]
set sigset [lindex $argv 3]
set trig [lindex $argv 4]
set stim_script [lindex $argv 5]
set timeout_s [lindex $argv 6]
set hw_pattern [lindex $argv 7]

set hw_name ""
foreach hw [get_hardware_names] {
    if {$hw_pattern eq "" || [string match $hw_pattern $hw]} {
        set hw_name $hw
        break
    }
}
if {$hw_name eq ""} {
    set hw_name [lindex [get_hardware_names] 0]
}
if {$hw_name eq ""} {
    puts "ERR:NO_HARDWARE"
    exit 11
}
set dev_name [lindex [get_device_names -hardware_name $hw_name] 0]
if {$dev_name eq ""} {
    puts "ERR:NO_DEVICE"
    exit 12
}
puts "HW=$hw_name"
puts "DEV=$dev_name"

open_session -name $stp_file
catch {exec bash -lc "sleep 0.25; $stim_script" &} stim_out
puts "STIM=$stim_out"

set run_rc [catch {run -hardware_name $hw_name -device_name $dev_name -instance $inst_name -signal_set $sigset -trigger $trig -timeout $timeout_s} run_out]
puts "RUN_RC=$run_rc"
puts "RUN_OUT=$run_out"
if {$run_rc != 0} {
    catch {close_session}
    exit 21
}

set exp_rc [catch {export_data_log -instance $inst_name -signal_set $sigset -trigger $trig -filename $csv_out -format csv} exp_out]
puts "EXP_RC=$exp_rc"
puts "EXP_OUT=$exp_out"
catch {close_session}
if {$exp_rc != 0} {
    exit 22
}
puts "OK"
"""
    )


def parse_csv_rows(csv_path: Path) -> Tuple[List[str], List[List[str]]]:
    raw_rows: List[List[str]] = []
    with csv_path.open("r", newline="") as f:
        reader = csv.reader(f)
        raw_rows = [r for r in reader]

    if not raw_rows:
        raise SignalTapError(f"empty csv: {csv_path}")

    header_idx = None

    for i, row in enumerate(raw_rows):
        if row and row[0].strip().lower() == "data:":
            if i + 1 < len(raw_rows):
                header_idx = i + 1
                break

    if header_idx is None:
        for i, row in enumerate(raw_rows):
            if not row:
                continue
            first = row[0].strip().lower()
            joined = " ".join(row)
            if (
                first.startswith("time")
                or first in {"sample", "index"}
                or (
                    ("o_mem_data" in joined or "o_rdata" in joined or "TX Data" in joined or "RX Data" in joined)
                    and not joined.startswith("Groups:")
                )
            ):
                header_idx = i
                break

    if header_idx is None:
        header_idx = 0

    header = [c.strip() for c in raw_rows[header_idx]]
    rows: List[List[str]] = []
    for row in raw_rows[header_idx + 1 :]:
        if not row:
            continue
        if len(row) < len(header):
            continue
        if row[0].strip().startswith("#"):
            continue
        rows.append(row[: len(header)])

    if not rows:
        raise SignalTapError(f"csv has no data rows: {csv_path}")

    return header, rows


def find_col(header: Sequence[str], includes: Sequence[str]) -> Optional[int]:
    for i, name in enumerate(header):
        low = name.lower()
        if all(tok.lower() in low for tok in includes):
            return i
    return None


def bit_columns(header: Sequence[str], regex: re.Pattern) -> Dict[int, int]:
    out: Dict[int, int] = {}
    for i, name in enumerate(header):
        m = regex.search(name)
        if m:
            out[int(m.group(1))] = i
    return out


def reconstruct_from_bits(row: Sequence[str], colmap: Dict[int, int]) -> Optional[int]:
    if not colmap:
        return None
    value = 0
    for bit, col in colmap.items():
        b = to_int_auto(row[col])
        if b is None:
            return None
        value |= (int(b) & 1) << bit
    return value


def extract_stream(header: Sequence[str], rows: Sequence[Sequence[str]], phase: str) -> List[Dict]:
    assert phase in {"tx", "rx"}
    valid_col = None
    use_valid_only = False

    if phase == "tx":
        data_col = find_col(header, ["tx", "data", "31..0"])
        datak_col = find_col(header, ["tx", "datak", "3..0"])
        data_bits = bit_columns(header, re.compile(r"o_mem_data\[2\]\.data\[(\d+)\]$"))
        datak_bits = bit_columns(header, re.compile(r"o_mem_data\[2\]\.datak\[(\d+)\]$"))
        sop_col = None
        eop_col = None
        idle_col = None
    else:
        data_col = find_col(header, ["rx", "data", "31..0"])
        datak_col = find_col(header, ["rx", "datak", "3..0"])
        if data_col is None:
            data_col = find_col(header, ["dbg_link2_data"])
        if datak_col is None:
            datak_col = find_col(header, ["dbg_link2_datak"])
        if data_col is None:
            data_col = find_col(header, ["captured_link.data"])
        if datak_col is None:
            datak_col = find_col(header, ["captured_link.datak"])
        data_bits = bit_columns(header, re.compile(r"dbg_link2_data\[(\d+)\]$"))
        if not data_bits:
            data_bits = bit_columns(header, re.compile(r"o_rdata\.data\[(\d+)\]$"))
        datak_bits = bit_columns(header, re.compile(r"dbg_link2_datak\[(\d+)\]$"))
        if not datak_bits:
            datak_bits = bit_columns(header, re.compile(r"o_rdata\.datak\[(\d+)\]$"))
        captured_bits = bit_columns(header, re.compile(r"captured_link\.data\[(\d+)\]$"))
        if not data_bits and captured_bits:
            data_bits = captured_bits
            data_col = None
            datak_col = None
        sop_col = find_col(header, ["dbg_link2_sop"])
        if sop_col is None:
            sop_col = find_col(header, ["o_rdata.sop"])
        eop_col = find_col(header, ["dbg_link2_eop"])
        if eop_col is None:
            eop_col = find_col(header, ["o_rdata.eop"])
        if eop_col is None:
            eop_col = find_col(header, ["captured_link.eop"])
        idle_col = find_col(header, ["dbg_link2_idle"])
        if idle_col is None:
            idle_col = find_col(header, ["o_rdata.idle"])
        valid_col = find_col(header, ["dbg_link2_word_valid"])
        if valid_col is None:
            valid_col = find_col(header, ["mem_wren_o"])
        use_valid_only = valid_col is not None

    stream: List[Dict] = []
    for idx, row in enumerate(rows):
        if data_col is not None:
            data = to_int_auto(row[data_col])
        else:
            data = reconstruct_from_bits(row, data_bits)

        if datak_col is not None:
            datak = to_int_auto(row[datak_col])
        else:
            datak = reconstruct_from_bits(row, datak_bits)

        sop = to_int_auto(row[sop_col]) if sop_col is not None else None
        eop = to_int_auto(row[eop_col]) if eop_col is not None else None
        idle = to_int_auto(row[idle_col]) if idle_col is not None else None
        valid = to_int_auto(row[valid_col]) if valid_col is not None else None

        if use_valid_only and valid != 1:
            continue

        stream.append(
            {
                "idx": idx,
                "data": data,
                "datak": datak,
                "sop": sop,
                "eop": eop,
                "idle": idle,
                "valid": valid,
            }
        )

    return stream


def reduce_transitions(stream: Sequence[Dict]) -> List[Dict]:
    out: List[Dict] = []
    prev = None
    for s in stream:
        key = (s.get("data"), s.get("datak"), s.get("sop"), s.get("eop"), s.get("idle"))
        if key != prev:
            out.append(s)
            prev = key
    return out


def drop_tx_fillers(stream: Sequence[Dict]) -> List[Dict]:
    out: List[Dict] = []
    for s in stream:
        if s.get("datak") == 1 and s.get("data") == 0x000000BC:
            continue
        out.append(s)
    return out


def strict_packet_match(phase: str, stream: Sequence[Dict], expected_words: Sequence[int], require_strict: bool) -> Tuple[bool, Dict]:
    reduced = reduce_transitions(stream)
    if phase == "tx":
        reduced = drop_tx_fillers(reduced)
    expected_datak = [1] + [0] * max(0, len(expected_words) - 2) + ([1] if len(expected_words) > 1 else [])
    rx_datak_checked = phase != "rx" or any(s.get("datak") is not None for s in reduced)

    if len(expected_words) == 1:
        expected_datak = [1]

    match_at = None
    reason = "no exact subsequence"

    for i in range(0, max(0, len(reduced) - len(expected_words) + 1)):
        ok = True
        for j, ew in enumerate(expected_words):
            s = reduced[i + j]
            if s.get("data") != ew:
                ok = False
                break

            if require_strict:
                dk = s.get("datak")
                if rx_datak_checked and (dk is None or dk != expected_datak[j]):
                    ok = False
                    reason = f"datak mismatch at j={j}, got={dk}, exp={expected_datak[j]}"
                    break

                if phase == "rx":
                    if s.get("idle") is not None and s.get("idle") != 0:
                        ok = False
                        reason = f"idle asserted in rx packet at j={j}"
                        break
                    if j == 0 and s.get("sop") is not None and s.get("sop") != 1:
                        ok = False
                        reason = f"rx sop mismatch at first word, got={s.get('sop')}"
                        break
                    if j == len(expected_words) - 1 and s.get("eop") is not None and s.get("eop") != 1:
                        ok = False
                        reason = f"rx eop mismatch at last word, got={s.get('eop')}"
                        break
        if ok:
            match_at = i
            break

    details = {
        "reduced_len": len(reduced),
        "expected_words": [f"0x{w:08X}" for w in expected_words],
        "sample_head": [
            {
                "i": k,
                "data": None if reduced[k].get("data") is None else f"0x{int(reduced[k]['data']) & 0xFFFFFFFF:08X}",
                "datak": reduced[k].get("datak"),
                "sop": reduced[k].get("sop"),
                "eop": reduced[k].get("eop"),
                "idle": reduced[k].get("idle"),
            }
            for k in range(min(24, len(reduced)))
        ],
        "reason": reason,
        "match_at": match_at,
        "rx_datak_checked": rx_datak_checked,
    }

    return match_at is not None, details


def run_signaltap_capture(
    args: argparse.Namespace,
    phase: str,
    stim_cmd: str,
    expected_words: Sequence[int],
    tag: str,
) -> SignalTapCaptureResult:
    if not args.use_signaltap:
        return SignalTapCaptureResult(
            ok=True,
            phase=phase,
            csv_path="",
            quartus_rc=0,
            quartus_log="",
            strict_match=True,
            details={"skipped": True},
        )

    if not args.quartus_stp.exists():
        raise SignalTapError(f"quartus_stp not found: {args.quartus_stp}")

    stp_text = args.stp_file.read_text()

    with tempfile.TemporaryDirectory(prefix="sc_stp_") as td:
        tdir = Path(td)
        stp_tmp = tdir / f"capture_{phase}.stp"
        stp_tmp.write_text(stp_text)
        apply_runtime_trigger_edit(stp_tmp, phase, rx_current_link=args.stp_rx_current_link)

        stim_sh = tdir / f"stim_{phase}.sh"
        stim_sh.write_text(
            "#!/usr/bin/env bash\n"
            "set -euo pipefail\n"
            f"cd {args.root}\n"
            "unset LD_LIBRARY_PATH || true\n"
            "unset LD_PRELOAD || true\n"
            f"{stim_cmd}\n"
        )
        stim_sh.chmod(0o755)

        csv_out = Path(args.stp_out_dir) / f"stp_{tag}_{phase}.csv"
        csv_out.parent.mkdir(parents=True, exist_ok=True)
        tcl = tdir / "capture.tcl"
        build_quartus_tcl(tcl)

        q_cmd = [
            str(args.quartus_stp),
            "-t",
            str(tcl),
            str(stp_tmp),
            str(csv_out),
            args.stp_instance,
            args.stp_signal_set,
            args.stp_trigger,
            str(stim_sh),
            str(args.stp_timeout),
            args.stp_hw_pattern,
        ]

        q_rc, q_out, _ = run_cmd(q_cmd, args.root, args.stp_timeout + 30)
        if q_rc != 0:
            err = "quartus_stp failed"
            if "Can't find the instance" in q_out:
                err = "instance_not_found"
            elif "Signal" in q_out and "does not exist in Signal Tap File" in q_out:
                err = "trigger_signal_not_found"
            return SignalTapCaptureResult(
                ok=False,
                phase=phase,
                csv_path=str(csv_out),
                quartus_rc=q_rc,
                quartus_log=q_out[-4000:],
                strict_match=False,
                details={"error": err, "tag": tag},
            )

        if not csv_out.exists():
            return SignalTapCaptureResult(
                ok=False,
                phase=phase,
                csv_path=str(csv_out),
                quartus_rc=q_rc,
                quartus_log=q_out[-4000:],
                strict_match=False,
                details={"error": "csv not generated", "tag": tag},
            )

        try:
            header, rows = parse_csv_rows(csv_out)
            stream = extract_stream(header, rows, phase)
            matched, details = strict_packet_match(phase, stream, expected_words, args.stp_strict)
            return SignalTapCaptureResult(
                ok=matched,
                phase=phase,
                csv_path=str(csv_out),
                quartus_rc=q_rc,
                quartus_log=q_out[-2000:],
                strict_match=matched,
                details=details,
            )
        except Exception as ex:
            return SignalTapCaptureResult(
                ok=False,
                phase=phase,
                csv_path=str(csv_out),
                quartus_rc=q_rc,
                quartus_log=q_out[-2000:],
                strict_match=False,
                details={"error": f"csv/strict parse failed: {ex}"},
            )


def tx_read_words(link: int, addr: int, length: int) -> List[int]:
    return [0x1C000000 | ((link & 0xFF) << 8) | 0xBC, addr & 0xFFFF, length & 0xFFFF, 0x0000009C]


def rx_read_words(link: int, addr: int, payload: Sequence[int]) -> List[int]:
    return [
        0x1C000000 | ((link & 0xFF) << 8) | 0xBC,
        addr & 0xFFFF,
        0x00010000 | (len(payload) & 0xFFFF),
        *[int(x) & 0xFFFFFFFF for x in payload],
        0x0000009C,
    ]


def tx_write_words(link: int, addr: int, payload: Sequence[int]) -> List[int]:
    return [
        0x1D000000 | ((link & 0xFF) << 8) | 0xBC,
        addr & 0xFFFF,
        len(payload) & 0xFFFF,
        *[int(x) & 0xFFFFFFFF for x in payload],
        0x0000009C,
    ]


def rx_write_words(link: int, addr: int) -> List[int]:
    return [
        0x1D000000 | ((link & 0xFF) << 8) | 0xBC,
        addr & 0xFFFF,
        0x00010000,
        0x0000009C,
    ]


def stim_write_cmd(args: argparse.Namespace, addr: int, value: int) -> str:
    return f"{args.test_bin} {args.link} --write 0x{addr:X} 0x{value & 0xFFFFFFFF:X} --once --quiet"


def stim_read_cmd(args: argparse.Namespace, addr: int, length: int) -> str:
    return f"{args.test_bin} {args.link} --read 0x{addr:X} {length} --once --quiet"


def run_mode_read_scan(args: argparse.Namespace) -> Dict:
    summary = {
        "mode": MODE_READ_SCAN,
        "iterations": args.iterations,
        "link": args.link,
        "scratchpad_words": SCRATCHPAD_WORDS,
        "results": [],
        "totals": {"pass": 0, "fail": 0, "stp_pass": 0, "stp_fail": 0},
    }

    stp_checks_done = 0

    read_len = max(1, min(args.read_scan_len, MAX_SC_WORDS_PER_TX, SCRATCHPAD_WORDS))
    stride = max(1, args.read_scan_stride)

    for i in range(args.iterations):
        addr = (args.scan_start + i * stride) % SCRATCHPAD_WORDS
        if addr + read_len > SCRATCHPAD_WORDS:
            addr = SCRATCHPAD_WORDS - read_len

        rec = {
            "iter": i,
            "addr": addr,
            "len": read_len,
            "read_ok": False,
            "read_value": None,
            "stp": [],
            "ok": False,
            "error": None,
        }

        try:
            rb = sc_read(args, addr, read_len)
            rec["read_ok"] = True
            rec["read_value"] = rb if read_len > 1 else rb[0]

            if args.use_signaltap and stp_checks_done < args.stp_scan_count:
                tag = f"readscan_{i:04d}_a{addr:04X}_l{read_len:03d}"
                captures: List[SignalTapCaptureResult] = []
                if stp_supports_phase(args.stp_file, "tx"):
                    captures.append(
                        run_signaltap_capture(
                            args,
                            "tx",
                            stim_read_cmd(args, addr, read_len),
                            tx_read_words(args.link, addr, read_len),
                            tag + "_rd",
                        )
                    )
                if stp_supports_phase(args.stp_file, "rx"):
                    captures.append(
                        run_signaltap_capture(
                            args,
                            "rx",
                            stim_read_cmd(args, addr, read_len),
                            rx_read_words(args.link, addr, rb),
                            tag + "_rd",
                        )
                    )

                for c in captures:
                    rec["stp"].append(asdict(c))
                    if c.ok:
                        summary["totals"]["stp_pass"] += 1
                    else:
                        summary["totals"]["stp_fail"] += 1
                stp_checks_done += 1

            rec["ok"] = rec["read_ok"] and all(x.get("ok", True) for x in rec["stp"])
        except Exception as ex:
            rec["error"] = str(ex)
            rec["ok"] = False

        summary["results"].append(rec)
        if rec["ok"]:
            summary["totals"]["pass"] += 1
        else:
            summary["totals"]["fail"] += 1

        if args.verbose:
            print(f"[read-scan] iter={i} addr=0x{addr:04X} len={read_len} ok={rec['ok']}")

    return summary


def run_mode_same_address_write_then_read(args: argparse.Namespace) -> Dict:
    random.seed(args.seed)
    summary = {
        "mode": MODE_SAME_ADDR,
        "iterations": args.iterations,
        "link": args.link,
        "scratchpad_words": SCRATCHPAD_WORDS,
        "results": [],
        "totals": {"pass": 0, "fail": 0, "stp_pass": 0, "stp_fail": 0},
    }

    stp_checks_done = 0

    for i in range(args.iterations):
        addr = (args.scan_start + i) % SCRATCHPAD_WORDS
        value = random.getrandbits(32)
        rec = {
            "iter": i,
            "addr": addr,
            "write_value": value,
            "write_ok": False,
            "read_ok": False,
            "read_value": None,
            "stp": [],
            "ok": False,
            "error": None,
        }

        try:
            if args.use_signaltap and stp_checks_done < args.stp_scan_count:
                wr_res = run_sc_command(args, ["--write", f"0x{addr:X}", f"0x{value & 0xFFFFFFFF:X}"])
                rec["write_ok"] = (wr_res.rc == 0 and status_looks_alive(wr_res.status))

                rd_res = run_sc_command(args, ["--read", f"0x{addr:X}", "1"])
                rd_pkt = find_packet(rd_res.packets, "RD", "Y", args.link, addr, 1)
                if rd_pkt is not None and len(rd_pkt.payload) == 1:
                    rec["read_value"] = rd_pkt.payload[0]
                    rec["read_ok"] = (rd_pkt.payload[0] == value)
                else:
                    rec["read_value"] = None
                    rec["read_ok"] = (rd_res.rc == 0 and status_looks_alive(rd_res.status))

                tag = f"scan_{i:04d}_a{addr:04X}"
                captures: List[SignalTapCaptureResult] = []

                if stp_supports_phase(args.stp_file, "tx"):
                    captures.append(
                        run_signaltap_capture(
                            args,
                            "tx",
                            stim_write_cmd(args, addr, value),
                            tx_write_words(args.link, addr, [value]),
                            tag + "_wr",
                        )
                    )
                if stp_supports_phase(args.stp_file, "rx"):
                    captures.append(
                        run_signaltap_capture(
                            args,
                            "rx",
                            stim_write_cmd(args, addr, value),
                            rx_write_words(args.link, addr),
                            tag + "_wr",
                        )
                    )

                if stp_supports_phase(args.stp_file, "tx"):
                    captures.append(
                        run_signaltap_capture(
                            args,
                            "tx",
                            stim_read_cmd(args, addr, 1),
                            tx_read_words(args.link, addr, 1),
                            tag + "_rd",
                        )
                    )
                if stp_supports_phase(args.stp_file, "rx"):
                    captures.append(
                        run_signaltap_capture(
                            args,
                            "rx",
                            stim_read_cmd(args, addr, 1),
                            rx_read_words(args.link, addr, [value]),
                            tag + "_rd",
                        )
                    )

                for c in captures:
                    rec["stp"].append(asdict(c))
                    if c.ok:
                        summary["totals"]["stp_pass"] += 1
                    else:
                        summary["totals"]["stp_fail"] += 1

                stp_checks_done += 1
            else:
                sc_write_word(args, addr, value)
                rec["write_ok"] = True

                rb = sc_read(args, addr, 1)
                rec["read_value"] = rb[0]
                rec["read_ok"] = (rb[0] == value)

            rec["ok"] = rec["write_ok"] and rec["read_ok"] and all(x.get("ok", True) for x in rec["stp"])
        except Exception as ex:
            rec["error"] = str(ex)
            rec["ok"] = False

        summary["results"].append(rec)
        if rec["ok"]:
            summary["totals"]["pass"] += 1
        else:
            summary["totals"]["fail"] += 1

        if args.verbose:
            print(f"[same-address-write-then-read] iter={i} addr=0x{addr:04X} ok={rec['ok']}")

    return summary


def run_mode_burst(args: argparse.Namespace) -> Dict:
    random.seed(args.seed)
    mirror = sc_read_region(args, SCRATCHPAD_BASE, SCRATCHPAD_WORDS)

    summary = {
        "mode": MODE_FULL_SCOPE,
        "profile": "burst",
        "iterations": args.burst_iterations,
        "link": args.link,
        "results": [],
        "totals": {"pass": 0, "fail": 0},
    }

    for i in range(args.burst_iterations):
        length = random.randint(1, min(args.burst_max_len, SCRATCHPAD_WORDS))
        addr = random.randint(0, SCRATCHPAD_WORDS - length)
        data = [random.getrandbits(32) for _ in range(length)]

        rec = {
            "iter": i,
            "addr": addr,
            "len": length,
            "ok": False,
            "error": None,
        }
        try:
            for off, val in enumerate(data):
                sc_write_word(args, addr + off, val)
                mirror[addr + off] = val

            rb = sc_read(args, addr, length)
            if rb != mirror[addr : addr + length]:
                raise ScError(
                    f"burst mismatch at iter={i} addr=0x{addr:04X} len={length} "
                    f"exp={mirror[addr:addr+length]} got={rb}"
                )
            rec["ok"] = True
        except Exception as ex:
            rec["error"] = str(ex)
            rec["ok"] = False

        summary["results"].append(rec)
        if rec["ok"]:
            summary["totals"]["pass"] += 1
        else:
            summary["totals"]["fail"] += 1

        if args.verbose and (i % max(1, args.progress_every) == 0):
            print(f"[full-scope-write-then-read/burst] iter={i} addr=0x{addr:04X} len={length} ok={rec['ok']}")

    return summary


def run_mode_full_scope_write_then_read(args: argparse.Namespace) -> Dict:
    random.seed(args.seed)
    mirror = sc_read_region(args, SCRATCHPAD_BASE, SCRATCHPAD_WORDS)

    summary = {
        "mode": MODE_FULL_SCOPE,
        "profile": "mixed-random",
        "operations": args.random_ops,
        "link": args.link,
        "results": [],
        "totals": {"pass": 0, "fail": 0, "writes": 0, "reads": 0},
    }

    for op in range(args.random_ops):
        do_write = random.random() < args.random_write_prob
        rec = {
            "op": op,
            "kind": "write" if do_write else "read",
            "ok": False,
            "error": None,
        }

        try:
            if do_write:
                length = random.randint(1, min(args.random_max_write_len, SCRATCHPAD_WORDS))
                addr = random.randint(0, SCRATCHPAD_WORDS - length)
                data = [random.getrandbits(32) for _ in range(length)]

                for off, val in enumerate(data):
                    sc_write_word(args, addr + off, val)
                    mirror[addr + off] = val

                rec.update({"addr": addr, "len": length})
                summary["totals"]["writes"] += 1
                rec["ok"] = True
            else:
                length = random.randint(1, min(args.random_max_read_len, SCRATCHPAD_WORDS))
                addr = random.randint(0, SCRATCHPAD_WORDS - length)
                rb = sc_read(args, addr, length)
                exp = mirror[addr : addr + length]
                if rb != exp:
                    raise ScError(
                        f"random read mismatch op={op} addr=0x{addr:04X} len={length} exp={exp} got={rb}"
                    )
                rec.update({"addr": addr, "len": length})
                summary["totals"]["reads"] += 1
                rec["ok"] = True
        except Exception as ex:
            rec["error"] = str(ex)
            rec["ok"] = False

        summary["results"].append(rec)
        if rec["ok"]:
            summary["totals"]["pass"] += 1
        else:
            summary["totals"]["fail"] += 1

        if args.verbose and (op % max(1, args.progress_every) == 0):
            print(f"[full-scope-write-then-read/mixed-random] op={op} kind={rec['kind']} ok={rec['ok']}")

    return summary


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description="SC scratchpad sweep/stress with optional strict SignalTap verification")

    p.add_argument(
        "--mode",
        choices=[
            MODE_READ_SCAN,
            MODE_SAME_ADDR,
            MODE_FULL_SCOPE,
            "scan",
            "burst",
            "random",
        ],
        default=MODE_READ_SCAN,
    )

    p.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    p.add_argument("--test-bin", type=Path, default=DEFAULT_TEST_BIN)
    p.add_argument("--link", type=int, default=2)
    p.add_argument("--cmd-timeout", type=float, default=12.0)
    p.add_argument("--retries", type=int, default=1)
    p.add_argument("--seed", type=int, default=0xC0FFEE)
    p.add_argument("--verbose", action="store_true")
    p.add_argument("--progress-every", type=int, default=25)

    # read-scan + same-address-write-then-read
    p.add_argument("--iterations", type=int, default=8, help="scan mode iterations")
    p.add_argument("--scan-start", type=int, default=0)
    p.add_argument("--read-scan-len", type=int, default=1)
    p.add_argument("--read-scan-stride", type=int, default=1)

    # full-scope-write-then-read (burst profile)
    p.add_argument("--burst-iterations", type=int, default=200)
    p.add_argument("--burst-max-len", type=int, default=32)

    # full-scope-write-then-read (mixed-random profile)
    p.add_argument("--random-ops", type=int, default=1000)
    p.add_argument("--random-write-prob", type=float, default=0.6)
    p.add_argument("--random-max-write-len", type=int, default=16)
    p.add_argument("--random-max-read-len", type=int, default=64)
    p.add_argument("--full-scope-profile", choices=["mixed-random", "burst"], default="mixed-random")

    # SignalTap
    p.add_argument("--use-signaltap", action="store_true")
    p.add_argument("--quartus-stp", type=Path, default=DEFAULT_QUARTUS_STP)
    p.add_argument("--stp-file", type=Path, default=DEFAULT_STP_FILE)
    p.add_argument("--stp-instance", default=None)
    p.add_argument("--stp-signal-set", default=None)
    p.add_argument("--stp-trigger", default=None)
    p.add_argument("--stp-rx-current-link", type=int, default=2, help="current_link slot value to use for the RX compound trigger")
    p.add_argument("--stp-timeout", type=int, default=20)
    p.add_argument("--stp-hw-pattern", default="USB-Blaster*")
    p.add_argument("--stp-strict", action="store_true", default=True)
    p.add_argument("--stp-scan-count", type=int, default=1, help="scan mode: number of iterations to run TX+RX strict STP checks")
    p.add_argument("--stp-out-dir", default="/tmp/sc_stp_captures")

    p.add_argument("--out-json", type=Path, default=Path("/tmp/sc_scratchpad_modes_result.json"))

    return p


def validate_args(args: argparse.Namespace) -> None:
    if not args.root.exists():
        raise SystemExit(f"root does not exist: {args.root}")
    if not args.test_bin.exists():
        raise SystemExit(f"test binary does not exist: {args.test_bin}")
    args.mode = canonical_mode(args.mode)

    if not (1 <= args.read_scan_len <= MAX_SC_WORDS_PER_TX):
        raise SystemExit("read-scan-len must be in 1..255")
    if args.read_scan_stride <= 0:
        raise SystemExit("read-scan-stride must be > 0")

    if args.mode == MODE_FULL_SCOPE and args.full_scope_profile == "burst" and not (1 <= args.burst_max_len <= MAX_SC_WORDS_PER_TX):
        raise SystemExit("burst-max-len must be in 1..255")
    if args.mode == MODE_FULL_SCOPE and args.full_scope_profile == "mixed-random":
        if not (0.0 <= args.random_write_prob <= 1.0):
            raise SystemExit("random-write-prob must be in [0,1]")
        if not (1 <= args.random_max_write_len <= MAX_SC_WORDS_PER_TX):
            raise SystemExit("random-max-write-len must be in 1..255")
        if not (1 <= args.random_max_read_len <= MAX_SC_WORDS_PER_TX):
            raise SystemExit("random-max-read-len must be in 1..255")

    if args.use_signaltap:
        if not args.stp_file.exists():
            raise SystemExit(f"stp file does not exist: {args.stp_file}")
        stp_instance, stp_signal_set, stp_trigger = parse_stp_metadata(args.stp_file)
        if not args.stp_instance:
            args.stp_instance = stp_instance
        if not args.stp_signal_set:
            args.stp_signal_set = stp_signal_set
        if not args.stp_trigger:
            args.stp_trigger = stp_trigger
        if not any(stp_supports_phase(args.stp_file, phase) for phase in ("tx", "rx")):
            raise SystemExit(f"stp file has no triggerable TX/RX phase candidates: {args.stp_file}")


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    validate_args(args)

    t0 = time.strftime("%Y-%m-%d %H:%M:%S %Z")
    print(f"Start: {t0}")
    print(f"Mode: {args.mode}")
    print(f"Root: {args.root}")
    print(f"Test: {args.test_bin}")

    if args.use_signaltap:
        print("SignalTap: enabled (strict TX/RX packet checking)")
        print(f"  STP file: {args.stp_file}")
        print(f"  Instance: {args.stp_instance}")
        print(f"  SignalSet: {args.stp_signal_set}")
        print(f"  Trigger: {args.stp_trigger}")

    try:
        if args.mode == MODE_READ_SCAN:
            summary = run_mode_read_scan(args)
        elif args.mode == MODE_SAME_ADDR:
            summary = run_mode_same_address_write_then_read(args)
        elif args.mode == MODE_FULL_SCOPE:
            if args.full_scope_profile == "burst":
                summary = run_mode_burst(args)
            else:
                summary = run_mode_full_scope_write_then_read(args)
        else:
            raise RuntimeError(f"unknown mode {args.mode}")
    except Exception as ex:
        fail = {
            "mode": args.mode,
            "ok": False,
            "error": str(ex),
            "started": t0,
        }
        args.out_json.write_text(json.dumps(fail, indent=2))
        print(json.dumps(fail, indent=2))
        return 1

    summary["ok"] = (summary.get("totals", {}).get("fail", 0) == 0)
    summary["started"] = t0
    summary["finished"] = time.strftime("%Y-%m-%d %H:%M:%S %Z")

    args.out_json.write_text(json.dumps(summary, indent=2))
    print(f"Wrote: {args.out_json}")
    print(json.dumps(summary.get("totals", {}), indent=2))

    return 0 if summary["ok"] else 2


if __name__ == "__main__":
    sys.exit(main())
