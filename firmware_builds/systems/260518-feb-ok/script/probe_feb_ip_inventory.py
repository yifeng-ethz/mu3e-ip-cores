#!/usr/bin/env python3
"""On-board FEB SciFi v3 IP inventory probe.

Reads from each Avalon-MM slave on the FEB via sc_tool (over the SWB
secondary ring) and emits a markdown report. The slave list is derived
from the build's own sopcinfo (generated/qsys/feb_system_v4.sopcinfo).

Modes:

    --mode uid       one word per IP at offset 0x00 (CSR UID)
    --mode version   uid + META-VERSION dance (default; same shape as
                     the original 13-row inventory report)
    --mode full      burst-read every word of the IP's addressSpan,
                     burst length capped by --burst (default 256)
    --mode report    per-IP markdown section with one row per word:
                     [offset | SVD register | expected (resetValue)
                       | read single | read burst | diff status]
                     Spans capped at min(span_words, 256). SVD is
                     auto-mapped from sopcinfo `kind` using the
                     KIND_TO_SVD table below.

Coverage:

    --include-bridges  list pass-through bridges and FIFOs alongside
                       the user IPs (info-only; not probed)

Bursting:

    --burst N        max burst length for --mode full (1..256). The
                     SC-hub mm_bridge has MAX_BURST_SIZE=256.

Usage:

    ./probe_feb_ip_inventory.py [--link 2] [--mode {uid,version,full}] \\
        [--burst 256] [--include-bridges] [--program] [--settle 20] \\
        [--output reports/feb_inventory_<stamp>.md]

sc_tool always goes through ~/.local/bin/swb_ring_lock so the ring is
serialized against rc_tool/rw concurrent users on the same SWB.
"""

from __future__ import annotations

import argparse
import datetime as dt
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
# mu3e-ip-cores worktree root (3 levels up from script/: <root>/firmware_builds/systems/<dated>/script/)
REPO_ROOT  = SYSTEM_DIR.resolve().parents[2]

# sopcinfo `kind` -> SVD path (relative to REPO_ROOT). Used by --mode report.
KIND_TO_SVD = {
    "altera_avalon_onchip_memory2":  "toolkits/infra/cmsis_svd/generic/scratch_pad_ram.svd",
    "altera_avalon_mm_bridge":       "toolkits/infra/cmsis_svd/generic/mm_bridge_passthrough.svd",
    "max10_prog_avmm":               "feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm.svd",
    "altera_temp_sense_ctrl":        "alt_temp_sense_controller/altera_temp_sense_ctrl.svd",
    "onewire_master_controller":     "onewire_temp_sense/script/onewire_master_controller.svd",
    "firefly_xcvr_ctrl":             "firefly_xcvr_i2c_master/firefly_xcvr_ctrl.svd",
    "mutrig_cfg_ctrl":               "mutrig_controller/mutrig_cfg_ctrl.svd",
    "lvds_rx_controller_pro":        "mu3e_lvds_controller/lvds_rx_controller_pro.svd",
    "emulator_mutrig":               "emulator_mutrig/emulator_mutrig.svd",
    "mts_preprocessor":              "mutrig_timestamp_processor/mts_processor.svd",
    "histogram_statistics_v2":       "histogram_statistics/histogram_statistics.svd",
    "mutrig_injector_multiheader":   "charge_injection/script/mutrig_injector.svd",
    "sc_hub_v2":                     "slow-control_hub/sc_hub.svd",
    "arb_hit_type0":                 "misc/arb_hit_type0/script/arb_hit_type0.svd",
    "ring_buffer_cam":               "ring-buffer_cam/script/ring_buffer_cam.svd",
    "feb_frame_assembly":            "feb_frame_assembly/feb_frame_assembly.svd",
    "mutrig_reset_controller":       "mutrig_reset_controller/mutrig_reset_controller.svd",
}

DEFAULT_SOPCINFO = SYSTEM_DIR / "generated" / "qsys" / "feb_system_v4.sopcinfo"
DEFAULT_SOF = SYSTEM_DIR / "syn" / "board_projects" / "fe_scifi_feb_v3" / "output_files" / "top.sof"
DEFAULT_OUTPUT = SYSTEM_DIR / "tb_int" / "reports" / "feb_inventory_{stamp}.md"
DEFAULT_SC_TOOL = Path("/home/yifeng/packages/online_dpv2/online/install/bin/sc_tool")
DEFAULT_SWB_LOCK = Path.home() / ".local" / "bin" / "swb_ring_lock"
DEFAULT_JTAG_CABLE = "USB-BlasterII [7-2]"

# control_path_subsystem_mm_bridge addressSpan after Phase B widening
# (ADDRESS_WIDTH=15 -> 32K words -> 0x20000 bytes = 128 KiB). Anything
# above this in the data-path internal address space cannot be reached
# from sc_hub via the ctrl2data bridge.
CTRL_BRIDGE_TO_DATA_BYTE = 0x00020000
CTRL_BRIDGE_TO_DATA_SPAN = 0x00020000

SC_MASTER = "control_path_subsystem_sc_hub_cmd_pipe.m0"
DATA_MASTER = "data_path_subsystem_master_datapath.master"

# Passthrough kinds that have no CSR aperture of their own; either info-
# only or probed only if --include-bridges is set.
PASSTHROUGH_KINDS = {
    "altera_avalon_mm_bridge",
    "altera_avalon_mm_clock_crossing_bridge",
    "altera_avalon_sc_fifo",
}


@dataclass
class Probe:
    label: str          # e.g. histogram_statistics_0.hist_bin
    kind: str           # IP kind (sopcinfo `kind` attr)
    instance: str       # module instance name
    port: str           # slave port name (s0 / csr / hist_bin / ...)
    base_byte: int      # absolute sc-byte address as seen by sc_hub
    span_byte: int      # addressSpan in bytes
    via_data_master: bool = False    # True if reached via control->data bridge
    local_offset: int = 0            # internal offset on data master (only meaningful if via_data_master)
    is_passthrough: bool = False     # True for bridges / FIFOs

    @property
    def base_word(self) -> int:
        return self.base_byte // 4

    @property
    def span_word(self) -> int:
        return max(1, self.span_byte // 4)

    @property
    def reachable(self) -> bool:
        if not self.via_data_master:
            return True
        return self.local_offset < CTRL_BRIDGE_TO_DATA_SPAN


@dataclass
class SvdRegister:
    name: str
    address_offset: int      # byte offset within peripheral
    reset_value: int | None  # None if not declared
    access: str              # read-only / read-write / write-only / etc.
    description: str = ""


@dataclass
class SvdPeripheral:
    name: str
    version: str
    registers: list["SvdRegister"]    # sorted by address_offset
    source_path: Path | None = None
    error: str = ""


@dataclass
class ProbeResult:
    probe: Probe
    words: list[int]              # single-read words (length depends on mode)
    burst_words: list[int] | None = None  # burst-read words (--mode report)
    uid: int | None = None
    version: int | None = None
    error: str = ""
    svd: "SvdPeripheral | None" = None


def _param(c: ET.Element, name: str) -> str | None:
    for p in c.findall("parameter"):
        if p.get("name") == name:
            v = p.get("value")
            if v is None:
                v = p.findtext("value")
            return v
    return None


def _parse_int(v: str | None) -> int | None:
    if v is None:
        return None
    try:
        return int(v, 0)
    except (ValueError, TypeError):
        return None


def _slave_span_bytes(root: ET.Element, instance: str, port: str) -> int:
    """Pull addressSpan from the slave-side <interface> element on the
    module. addressSpan in sopcinfo is in WORDS or BYTES depending on
    the interface's `addressUnits` parameter. Falls back to 0x40 (16
    words = 64 bytes) when not declared."""
    mod = root.find(f".//module[@name='{instance}']")
    if mod is None:
        return 0x40
    for itf in mod.findall(".//interface"):
        if itf.get("name") != port:
            continue
        span = _parse_int(_param(itf, "addressSpan"))
        units = (_param(itf, "addressUnits") or "WORDS").upper()
        if span is None or span <= 0:
            return 0x40
        if units == "WORDS":
            return span * 4
        return span
    return 0x40


def parse_sopcinfo(sopcinfo: Path, include_bridges: bool) -> list[Probe]:
    root = ET.parse(sopcinfo).getroot()
    modules = {m.get("name"): m for m in root.findall(".//module") if m.get("name")}
    probes: list[Probe] = []

    # 1) direct SC-hub slaves (control path)
    for c in root.findall(".//connection"):
        if c.get("start") != SC_MASTER or c.get("kind") != "avalon":
            continue
        end = c.get("end", "")
        base = _parse_int(_param(c, "baseAddress"))
        if base is None:
            continue
        inst = end.split(".")[0]
        port = end.split(".", 1)[1] if "." in end else ""
        kind = modules[inst].get("kind") if inst in modules else "?"
        is_pt = kind in PASSTHROUGH_KINDS
        if is_pt and not include_bridges:
            continue
        span = _slave_span_bytes(root, inst, port)
        probes.append(Probe(
            label=f"{inst}.{port}",
            kind=kind,
            instance=inst,
            port=port,
            base_byte=base,
            span_byte=span,
            is_passthrough=is_pt,
        ))

    # 2) data-path slaves via control_path mm_bridge gateway
    for c in root.findall(".//connection"):
        if c.get("start") != DATA_MASTER or c.get("kind") != "avalon":
            continue
        end = c.get("end", "")
        local = _parse_int(_param(c, "baseAddress"))
        if local is None:
            continue
        inst = end.split(".")[0]
        port = end.split(".", 1)[1] if "." in end else ""
        kind = modules[inst].get("kind") if inst in modules else "?"
        is_pt = kind in PASSTHROUGH_KINDS
        # arb_hit_type0_supercore_0_csr_pipe_N bridges expose the lane CSR
        # at a real backplane address; they're passthroughs but always
        # worth probing because the lane behind them has the UID/META.
        is_arb_pipe = inst.startswith("data_path_subsystem_arb_hit_type0_supercore_0_csr_pipe_")
        if is_pt and not include_bridges and not is_arb_pipe:
            continue
        # The backpressure_fifo CSR ports are altera_avalon_sc_fifo;
        # treat as info-only unless --include-bridges.
        span = _slave_span_bytes(root, inst, port)
        probes.append(Probe(
            label=f"{inst}.{port}",
            kind=kind,
            instance=inst,
            port=port,
            base_byte=CTRL_BRIDGE_TO_DATA_BYTE + local,
            span_byte=span,
            via_data_master=True,
            local_offset=local,
            is_passthrough=is_pt and not is_arb_pipe,
        ))

    # 3) sc_hub internal CSR (constant location: sc-word 0xFE80)
    probes.append(Probe(
        label="sc_hub_internal_csr",
        kind="sc_hub_v2",
        instance="control_path_subsystem_sc_hub",
        port="internal_csr",
        base_byte=0xFE80 * 4,
        span_byte=0x40,
    ))

    return sorted(probes, key=lambda x: x.base_byte)


_PAYLOAD_RE = re.compile(r"^\s*payload\[(\d+)\]\s*=\s*(0x[0-9a-fA-F]+)")


def parse_sc_read_payload(stdout: str, expected_len: int) -> list[int]:
    """Pull payload[i] = 0xXXXXXXXX lines from sc_tool stdout, return in
    index order. The wire header word (e.g. 0x1C0002BC) is printed
    earlier and is NOT a payload line, so the regex anchored to
    `payload[` correctly ignores it."""
    pairs: list[tuple[int, int]] = []
    for line in stdout.splitlines():
        m = _PAYLOAD_RE.match(line)
        if m:
            pairs.append((int(m.group(1)), int(m.group(2), 16)))
    pairs.sort()
    words = [v for _, v in pairs]
    return words[:expected_len]


def sc_read(sc_tool: Path, swb_lock: Path, link: int, addr_word: int,
            length: int) -> tuple[list[int], str]:
    cmd = [str(swb_lock), "--", str(sc_tool), str(link), "read",
           f"0x{addr_word:05X}", str(length), "--quiet"]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    out = proc.stdout + proc.stderr
    if proc.returncode != 0:
        return [], f"rc={proc.returncode}: {out.strip()[-200:]}"
    words = parse_sc_read_payload(out, length)
    if len(words) < length:
        return words, f"short read: got {len(words)} of {length} words"
    return words, ""


def sc_write_word(sc_tool: Path, swb_lock: Path, link: int, addr_word: int,
                  value: int) -> str:
    cmd = [str(swb_lock), "--", str(sc_tool), str(link), "write",
           f"0x{addr_word:05X}", f"0x{value:X}", "--quiet"]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    if proc.returncode != 0:
        return f"rc={proc.returncode}: {(proc.stdout + proc.stderr).strip()[-200:]}"
    return ""


def probe_one(p: Probe, sc_tool: Path, swb_lock: Path, link: int,
              mode: str, burst: int) -> ProbeResult:
    if mode == "report":
        return probe_report(p, sc_tool, swb_lock, link, burst)
    if not p.reachable:
        return ProbeResult(
            probe=p, words=[],
            error=(f"out-of-bridge: data-path internal 0x{p.local_offset:05x}"
                   f" >= ctrl mm_bridge span 0x{CTRL_BRIDGE_TO_DATA_SPAN:05x}"),
        )
    if mode == "uid":
        words, err = sc_read(sc_tool, swb_lock, link, p.base_word + 0, 1)
        if err:
            return ProbeResult(probe=p, words=[], error=f"uid: {err}")
        return ProbeResult(probe=p, words=words, uid=words[0])
    if mode == "version":
        uid_words, err = sc_read(sc_tool, swb_lock, link, p.base_word + 0, 1)
        if err:
            return ProbeResult(probe=p, words=[], error=f"uid: {err}")
        uid = uid_words[0]
        werr = sc_write_word(sc_tool, swb_lock, link, p.base_word + 1, 0)
        if werr:
            return ProbeResult(probe=p, words=uid_words, uid=uid,
                               error=f"meta_sel: {werr}")
        ver_words, err = sc_read(sc_tool, swb_lock, link, p.base_word + 1, 1)
        if err:
            return ProbeResult(probe=p, words=uid_words, uid=uid,
                               error=f"version: {err}")
        return ProbeResult(probe=p, words=uid_words + ver_words,
                           uid=uid, version=ver_words[0])
    if mode == "full":
        # Cap burst at the IP's own span_word AND at the user-supplied
        # burst limit. Read the whole IP in chunks of `burst` words.
        total = p.span_word
        chunk = max(1, min(burst, 256))
        all_words: list[int] = []
        offset = 0
        while offset < total:
            this_len = min(chunk, total - offset)
            words, err = sc_read(sc_tool, swb_lock, link,
                                 p.base_word + offset, this_len)
            if err:
                return ProbeResult(
                    probe=p, words=all_words,
                    error=f"full@+0x{offset*4:03x}: {err}",
                )
            all_words.extend(words)
            offset += this_len
        uid = all_words[0] if len(all_words) >= 1 else None
        ver = all_words[1] if len(all_words) >= 2 else None
        return ProbeResult(probe=p, words=all_words, uid=uid, version=ver)
    return ProbeResult(probe=p, words=[], error=f"unknown mode: {mode}")


# Slave-port names that carry the IP's CSR aperture (and therefore get the
# SVD overlay). All other ports — RAM (.s0, .s1, .hist_bin), bridge .s0,
# FIFO .csr, etc. — are NOT covered by the IP's CSR SVD and must NOT be
# scored against it.
CSR_PORT_NAMES = {
    "csr", "csr_avmm", "avmm_csr", "firefly",
    "internal_csr", "ctrl", "reconfig_mgmt",
}


def load_svd_for_kind(kind: str, port: str = "") -> SvdPeripheral | None:
    """Locate the SVD file for an IP kind via KIND_TO_SVD and parse its
    first <peripheral>'s register table. Returns None when no SVD is
    mapped (passthroughs, unknown IPs), when the port is not a CSR port
    (memory apertures, bridge passthroughs), or with .error set when the
    file exists but cannot be parsed.

    Port-name discrimination is needed because some IPs expose BOTH a
    CSR aperture AND a memory aperture (e.g. histogram_statistics_v2
    has .csr and .hist_bin); the SVD documents only the CSR aperture
    and must not be overlaid on the memory aperture."""
    if port and port not in CSR_PORT_NAMES:
        return None
    rel = KIND_TO_SVD.get(kind)
    if rel is None:
        return None
    path = REPO_ROOT / rel
    if not path.is_file():
        return SvdPeripheral(name=kind, version="", registers=[],
                             source_path=path,
                             error=f"SVD path not found: {path}")
    try:
        root = ET.parse(path).getroot()
    except Exception as e:
        return SvdPeripheral(name=kind, version="", registers=[],
                             source_path=path, error=f"XML parse error: {e}")
    dev_name = root.findtext("name") or ""
    dev_ver = root.findtext("version") or ""
    regs: list[SvdRegister] = []
    # CMSIS-SVD: device -> peripherals -> peripheral -> registers -> register.
    # Take the first peripheral (our IPs only declare one).
    for periph in root.findall(".//peripheral"):
        for reg in periph.findall(".//register"):
            name = reg.findtext("name") or ""
            off_s = reg.findtext("addressOffset") or "0"
            rv_s = reg.findtext("resetValue")
            access = reg.findtext("access") or ""
            desc = (reg.findtext("description") or "").strip().replace("\n", " ")
            try:
                off = int(off_s, 0)
            except ValueError:
                continue
            rv: int | None
            try:
                rv = int(rv_s, 0) if rv_s else None
            except ValueError:
                rv = None
            regs.append(SvdRegister(name=name, address_offset=off,
                                    reset_value=rv, access=access,
                                    description=desc[:160]))
        if regs:
            break
    regs.sort(key=lambda r: r.address_offset)
    return SvdPeripheral(name=dev_name, version=dev_ver,
                         registers=regs, source_path=path)


def probe_report(p: Probe, sc_tool: Path, swb_lock: Path, link: int,
                 burst: int) -> ProbeResult:
    """Read the IP's full CSR aperture (capped at min(span_words, 256))
    via SINGLE reads AND via one or more BURST reads, plus look up the
    SVD register layout. Returns both vectors for diffing."""
    if not p.reachable:
        return ProbeResult(
            probe=p, words=[],
            error=(f"out-of-bridge: data-path internal 0x{p.local_offset:05x}"
                   f" >= ctrl mm_bridge span 0x{CTRL_BRIDGE_TO_DATA_SPAN:05x}"),
        )
    svd = load_svd_for_kind(p.kind, p.port)
    # cap span at 256 words per the user spec for --mode report
    total = min(p.span_word, 256)
    if total == 0:
        return ProbeResult(probe=p, words=[], svd=svd,
                           error="zero-span aperture")
    # Single-word loop
    singles: list[int] = []
    for off in range(total):
        words, err = sc_read(sc_tool, swb_lock, link, p.base_word + off, 1)
        if err:
            return ProbeResult(probe=p, words=singles, svd=svd,
                               error=f"single@+0x{off*4:03x}: {err}")
        singles.append(words[0])
    # Burst loop, chunked by `burst` words at most
    chunk = max(1, min(burst, 256))
    bursts: list[int] = []
    off = 0
    while off < total:
        n = min(chunk, total - off)
        words, err = sc_read(sc_tool, swb_lock, link, p.base_word + off, n)
        if err:
            return ProbeResult(probe=p, words=singles, burst_words=bursts,
                               svd=svd, error=f"burst@+0x{off*4:03x}: {err}")
        bursts.extend(words)
        off += n
    uid = singles[0] if singles else None
    ver = singles[1] if len(singles) >= 2 else None
    return ProbeResult(probe=p, words=singles, burst_words=bursts,
                       svd=svd, uid=uid, version=ver)


def program_feb(quartus_pgm: Path, cable: str, sof: Path) -> tuple[bool, str]:
    cmd = [str(quartus_pgm), "-c", cable, "-m", "JTAG", "-o", f"p;{sof}"]
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return proc.returncode == 0, (proc.stdout + proc.stderr)


def fmt_uid(v: int | None) -> str:
    if v is None:
        return "—"
    ascii_repr = ""
    for shift in (24, 16, 8, 0):
        c = (v >> shift) & 0xFF
        ascii_repr += chr(c) if 0x20 <= c < 0x7F else "."
    return f"0x{v:08X} ({ascii_repr})"


def fmt_version(v: int | None) -> str:
    if v is None:
        return "—"
    major = (v >> 24) & 0xFF
    minor = (v >> 16) & 0xFF
    patch = (v >> 12) & 0xF
    build = v & 0xFFF
    return f"0x{v:08X} = {major}.{minor}.{patch}.{build:03d}"


def render_summary_table(results: list[ProbeResult], mode: str) -> list[str]:
    lines: list[str] = []
    lines.append("| sc-word | sc-byte | span | kind | instance.port | UID | VERSION (META[0]) | status |")
    lines.append("|---|---|---|---|---|---|---|---|")
    ok = fail = warn = pass_ = 0
    for r in results:
        p = r.probe
        if p.is_passthrough:
            status = "PASSTHROUGH"
            pass_ += 1
        elif r.error.startswith("out-of-bridge"):
            status = "OUT-OF-BRIDGE"
            warn += 1
        elif r.error:
            status = f"ERR ({r.error[:60]})"
            fail += 1
        else:
            status = "OK"
            ok += 1
        uid_s = fmt_uid(r.uid) if mode != "uid" or r.uid is None else fmt_uid(r.uid)
        ver_s = fmt_version(r.version) if mode in ("version", "full") else "—"
        lines.append(
            f"| 0x{p.base_word:05X} | 0x{p.base_byte:06X} | 0x{p.span_byte:04X} "
            f"| {p.kind} | {p.instance}.{p.port} "
            f"| {uid_s} | {ver_s} | {status} |"
        )
    lines.append("")
    lines.append(f"**Summary**: {ok} OK / {fail} fail / {warn} out-of-bridge / "
                 f"{pass_} passthrough / {ok + fail + warn + pass_} listed")
    return lines


def render_full_word_dump(results: list[ProbeResult]) -> list[str]:
    lines: list[str] = []
    for r in results:
        if r.probe.is_passthrough or not r.words:
            continue
        p = r.probe
        lines.append(f"### `{p.instance}.{p.port}`  (sc-byte 0x{p.base_byte:06X}, span 0x{p.span_byte:04X})")
        lines.append("")
        lines.append("```text")
        # 4 words per line: offset, w0, w1, w2, w3
        for i in range(0, len(r.words), 4):
            chunk = r.words[i:i+4]
            words_s = " ".join(f"0x{w:08X}" for w in chunk)
            lines.append(f"  +0x{i*4:04X}  {words_s}")
        if r.error:
            lines.append(f"  ... (truncated: {r.error})")
        lines.append("```")
        lines.append("")
    return lines


def _word_to_register(svd: SvdPeripheral | None, byte_off: int) -> SvdRegister | None:
    """Return the SvdRegister whose addressOffset covers the given
    byte offset within an IP. Our SVDs declare registers at 4-byte
    word boundaries, so a register at addressOffset N covers exactly
    one word [N, N+4). Returns None if no register exact-matches."""
    if svd is None:
        return None
    for r in svd.registers:
        if r.address_offset == byte_off:
            return r
    return None


def render_report_section(r: ProbeResult,
                           uvm_lookup: dict[tuple[str,int], int] | None = None
                           ) -> list[str]:
    """One per-IP section for --mode report.

    Each word in the IP's aperture (capped at min(span_words, 256)) is
    one row with 5 columns: offset | register | SVD (resetValue + brief
    description) | UVM (expected from UVM evidence if provided) | board
    (live single + burst readback) | diff."""
    p = r.probe
    lines: list[str] = []
    title = f"### `{p.instance}.{p.port}`  (kind=`{p.kind}`)"
    lines.append(title)
    lines.append("")
    lines.append(f"- **sc-byte base**: `0x{p.base_byte:06X}`  "
                 f"(sc-word `0x{p.base_word:05X}`)")
    lines.append(f"- **addressSpan**: `0x{p.span_byte:04X}` bytes "
                 f"(`{p.span_word}` words)")
    span_w = min(p.span_word, 256)
    lines.append(f"- **probed**: first `{span_w}` words "
                 f"(min(span_words, 256))")
    if r.svd is not None:
        if r.svd.error:
            lines.append(f"- **SVD**: ERROR — `{r.svd.error}`")
        else:
            lines.append(f"- **SVD**: `{r.svd.source_path.name}` "
                         f"v{r.svd.version}  "
                         f"({len(r.svd.registers)} registers declared)")
    else:
        lines.append("- **SVD**: (not mapped for this kind)")
    if r.error:
        lines.append(f"- **probe error**: `{r.error}`")
    lines.append("")
    if not r.words:
        lines.append("> No readback data — probe failed before any word was read.")
        lines.append("")
        return lines
    lines.append("| offset | register | SVD (reset + description) | UVM (expected) | board (single / burst) | diff |")
    lines.append("|---|---|---|---|---|---|")
    nw = min(len(r.words),
             len(r.burst_words) if r.burst_words is not None else len(r.words))
    n_match = n_drift = n_no_svd = 0
    for i in range(nw):
        byte_off = i * 4
        reg = _word_to_register(r.svd, byte_off)
        reg_name = reg.name if reg else "—"
        if reg and reg.reset_value is not None:
            desc = f" — {reg.description}" if reg.description else ""
            svd_cell = f"`0x{reg.reset_value:08X}`{desc}"
            expected_svd: int | None = reg.reset_value
        elif reg:
            # named register but no resetValue declared
            desc = f" — {reg.description}" if reg.description else ""
            svd_cell = f"_(no reset declared)_{desc}"
            expected_svd = None
        else:
            svd_cell = "—"
            expected_svd = None
        # UVM expected (from external evidence dict)
        uvm_val = (uvm_lookup or {}).get((p.kind, byte_off))
        uvm_cell = f"`0x{uvm_val:08X}`" if uvm_val is not None else "—"
        single = r.words[i]
        burst = r.burst_words[i] if r.burst_words is not None else single
        board_cell = f"`0x{single:08X}` / `0x{burst:08X}`"
        # Decide diff status
        if single != burst:
            diff = "BURST≠SINGLE"
        elif expected_svd is None:
            diff = "no-svd-reset"
            n_no_svd += 1
        elif single == expected_svd:
            diff = "match"
            n_match += 1
        else:
            diff = "drift"
            n_drift += 1
        lines.append(
            f"| `+0x{byte_off:03X}` | `{reg_name}` | {svd_cell} "
            f"| {uvm_cell} | {board_cell} | {diff} |"
        )
    lines.append("")
    lines.append(
        f"**Per-IP summary**: {n_match} match / {n_drift} drift / "
        f"{n_no_svd} no-svd-reset (of {nw} words)"
    )
    if r.burst_words is not None and len(r.burst_words) != len(r.words):
        lines.append(f"")
        lines.append(
            f"> NOTE: burst returned {len(r.burst_words)} words vs "
            f"single returned {len(r.words)} words (truncated)."
        )
    lines.append("")
    return lines


def render_markdown(results: list[ProbeResult], header: dict[str, str],
                    mode: str) -> str:
    lines: list[str] = []
    lines.append(f"# FEB SciFi v3 — IP Inventory Probe ({mode} mode)")
    lines.append("")
    for k, v in header.items():
        lines.append(f"- **{k}**: {v}")
    lines.append("")
    if mode == "report":
        lines.append("## Per-IP CSR summary (rollup)")
        lines.append("")
        lines.extend(render_summary_table(results, mode))
        lines.append("")
        lines.append("## Per-IP CSR word-by-word report")
        lines.append("")
        lines.append(
            "Each section is one Avalon-MM slave seen by `sc_hub_cmd_pipe.m0` "
            "(direct on the control path or via the v4 ctrl2data bridge for "
            "data-path slaves). Each row is one 32-bit word. `expected` is the "
            "register's `resetValue` from its SVD; **drift** means the live "
            "readback differs from the reset value (counters, status, anything "
            "the FSM has written). `BURST≠SINGLE` means the single-word and "
            "burst-aperture readbacks disagreed at the same offset — that "
            "indicates a bridge / response-pipeline issue, NOT live drift."
        )
        lines.append("")
        for r in results:
            if r.probe.is_passthrough:
                continue
            lines.extend(render_report_section(r))
    else:
        lines.append("## Per-IP CSR readback")
        lines.append("")
        lines.extend(render_summary_table(results, mode))
        if mode == "full":
            lines.append("")
            lines.append("## Per-IP word dump (--mode full)")
            lines.append("")
            lines.extend(render_full_word_dump(results))
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    ap.add_argument("--sopcinfo", type=Path, default=DEFAULT_SOPCINFO)
    ap.add_argument("--sof", type=Path, default=DEFAULT_SOF)
    ap.add_argument("--sc-tool", type=Path, default=DEFAULT_SC_TOOL)
    ap.add_argument("--swb-lock", type=Path, default=DEFAULT_SWB_LOCK)
    ap.add_argument("--quartus-pgm", type=Path,
                    default=Path("/data1/intelFPGA/18.1/quartus/bin/quartus_pgm"))
    ap.add_argument("--jtag-cable", default=DEFAULT_JTAG_CABLE)
    ap.add_argument("--link", type=int, default=2,
                    help="SWB SC ring link for FEB SciFi (default 2)")
    ap.add_argument("--mode", choices=("uid", "version", "full", "report"),
                    default="version",
                    help="Probe depth (default: version). report = per-IP "
                         "per-word SVD-vs-readback comparison.")
    ap.add_argument("--burst", type=int, default=256,
                    help="Max burst length for --mode full (1..256). "
                         "The mm_bridge MAX_BURST_SIZE is 256.")
    ap.add_argument("--include-bridges", action="store_true",
                    help="List pass-through bridges/FIFOs as info rows (not probed)")
    ap.add_argument("--program", action="store_true",
                    help="quartus_pgm the SOF before probing")
    ap.add_argument("--settle", type=int, default=20,
                    help="Seconds to sleep after program before probing")
    ap.add_argument("--output", type=Path,
                    default=Path(str(DEFAULT_OUTPUT).format(
                        stamp=dt.datetime.now().strftime("%Y%m%d_%H%M%S"))))
    ap.add_argument("--reports-dir", type=Path, default=SYSTEM_DIR / "doc" / "reports",
                    help="Root for per-IP reports (default: doc/reports). "
                         "In --mode report this is the parent of the dated "
                         "subdir <YYYYMMDD>/ that holds one file per IP plus "
                         "SYSTEM_OVERVIEW.md.")
    ap.add_argument("--uvm-evidence", type=Path, default=None,
                    help="JSON file with UVM-expected values per IP. Format: "
                         "{\"<kind>\": {\"0\": \"0xDEADBEEF\", ...}, ...}. "
                         "Populates the UVM column of --mode report.")
    args = ap.parse_args(argv)

    if not args.sopcinfo.is_file():
        print(f"sopcinfo not found: {args.sopcinfo}", file=sys.stderr)
        return 2
    if not 1 <= args.burst <= 256:
        print(f"--burst must be in 1..256 (got {args.burst})", file=sys.stderr)
        return 2

    if args.program:
        if not args.sof.is_file():
            print(f"SOF not found: {args.sof}", file=sys.stderr)
            return 2
        ok, log = program_feb(args.quartus_pgm, args.jtag_cable, args.sof)
        print(f"[program] {'OK' if ok else 'FAIL'} (last 6 lines):")
        for line in log.splitlines()[-6:]:
            print(f"  {line}")
        if not ok:
            return 2
        print(f"[settle] sleeping {args.settle}s for FEB LVDS/firefly to lock ...")
        time.sleep(args.settle)

    probes = parse_sopcinfo(args.sopcinfo, args.include_bridges)
    print(f"[probe] mode={args.mode} burst={args.burst} "
          f"endpoints={len(probes)} from {args.sopcinfo.name}")
    results: list[ProbeResult] = []
    for p in probes:
        if p.is_passthrough:
            r = ProbeResult(probe=p, words=[])
        else:
            r = probe_one(p, args.sc_tool, args.swb_lock, args.link,
                          args.mode, args.burst)
        results.append(r)
        if p.is_passthrough:
            marker = "INFO"
        elif r.error:
            marker = "ERR"
        else:
            marker = "OK"
        n = len(r.words)
        print(f"  [{marker:4}] 0x{p.base_word:05X}  {p.kind:32}  "
              f"{p.instance}.{p.port}  (words={n})")
        if r.error:
            print(f"         {r.error}")

    header = {
        "Timestamp": dt.datetime.now().isoformat(timespec="seconds"),
        "Mode": args.mode,
        "Burst": str(args.burst),
        "SOF": str(args.sof),
        "sopcinfo": str(args.sopcinfo),
        "JTAG cable": args.jtag_cable,
        "SC link": str(args.link),
        "sc_tool": str(args.sc_tool),
        "swb_ring_lock": str(args.swb_lock),
    }
    md = render_markdown(results, header, args.mode)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(md, encoding="utf-8")
    print(f"\nWrote {args.output}")

    # In --mode report: also emit per-IP files and a SYSTEM_OVERVIEW.md
    # index under reports-dir/<YYYYMMDD>/.
    if args.mode == "report":
        # Load optional UVM-evidence dict
        import json
        uvm_lookup: dict[tuple[str,int], int] = {}
        if args.uvm_evidence and args.uvm_evidence.is_file():
            try:
                raw = json.loads(args.uvm_evidence.read_text())
                for kind, regmap in raw.items():
                    for off_s, val_s in regmap.items():
                        try:
                            off = int(off_s, 0)
                            val = int(val_s, 0)
                            uvm_lookup[(kind, off)] = val
                        except (ValueError, TypeError):
                            continue
                print(f"[uvm] loaded {len(uvm_lookup)} expected values "
                      f"from {args.uvm_evidence}")
            except Exception as e:
                print(f"[uvm] failed to parse {args.uvm_evidence}: {e}")
        stamp_date = dt.datetime.now().strftime("%Y%m%d")
        dated_dir = args.reports_dir / stamp_date
        dated_dir.mkdir(parents=True, exist_ok=True)
        index_rows: list[tuple[str, str, str, int, int, int, int]] = []
        for r in results:
            if r.probe.is_passthrough:
                continue
            ip_file = f"{r.probe.instance}_{r.probe.port}_readback.md".replace(".", "_").replace(
                "_readback_md", "_readback.md")
            ip_path = dated_dir / ip_file
            body: list[str] = []
            body.append(f"# {r.probe.instance}.{r.probe.port} CSR readback")
            body.append("")
            body.append(f"- **Timestamp**: {header['Timestamp']}")
            body.append(f"- **Kind**: `{r.probe.kind}`")
            body.append(f"- **sc-byte base**: `0x{r.probe.base_byte:06X}`")
            body.append(f"- **addressSpan**: `0x{r.probe.span_byte:04X}` bytes")
            body.append(f"- **probe mode**: {args.mode} (burst {args.burst})")
            if r.svd is not None and not r.svd.error:
                body.append(f"- **SVD**: `{r.svd.source_path.name}` v{r.svd.version}")
            body.append("")
            body.extend(render_report_section(r, uvm_lookup))
            ip_path.write_text("\n".join(body) + "\n", encoding="utf-8")
            # Per-IP summary for the index
            nw = min(len(r.words),
                     len(r.burst_words) if r.burst_words is not None else len(r.words))
            n_match = n_drift = n_no_svd = 0
            for i in range(nw):
                byte_off = i * 4
                reg = _word_to_register(r.svd, byte_off)
                exp = reg.reset_value if (reg and reg.reset_value is not None) else None
                s = r.words[i]
                b = r.burst_words[i] if r.burst_words is not None else s
                if s != b:
                    pass  # counted as BURST!=SINGLE; not in this rollup
                elif exp is None:
                    n_no_svd += 1
                elif s == exp:
                    n_match += 1
                else:
                    n_drift += 1
            index_rows.append((r.probe.instance, r.probe.port,
                               r.probe.kind, nw, n_match, n_drift, n_no_svd))
        # SYSTEM_OVERVIEW.md
        overview_lines: list[str] = []
        overview_lines.append(f"# FEB v4 CSR readback — {stamp_date} system overview")
        overview_lines.append("")
        overview_lines.append("Generated by `script/probe_feb_ip_inventory.py --mode report`.")
        overview_lines.append("One linked file per Avalon-MM slave under "
                              f"`{dated_dir.relative_to(SYSTEM_DIR)}/`. Each file "
                              "tabulates every word in the slave's CSR aperture "
                              "with three value columns: **SVD** (declared "
                              "resetValue + description), **UVM** (expected from "
                              "UVM evidence dict when provided), **board** (live "
                              "single read / burst read).")
        overview_lines.append("")
        overview_lines.append("| IP | kind | words | match | drift | no-svd-reset | report |")
        overview_lines.append("|---|---|---|---|---|---|---|")
        for inst, port, kind, nw, nm, nd, nn in index_rows:
            ip_file = f"{inst}_{port}_readback.md".replace(".", "_").replace(
                "_readback_md", "_readback.md")
            overview_lines.append(
                f"| `{inst}.{port}` | {kind} | {nw} | {nm} | {nd} | {nn} | "
                f"[readback]({ip_file}) |"
            )
        ovr_path = dated_dir / "SYSTEM_OVERVIEW.md"
        ovr_path.write_text("\n".join(overview_lines) + "\n", encoding="utf-8")
        print(f"\n[report] wrote {len(index_rows)} per-IP files under {dated_dir}/")
        print(f"[report] index: {ovr_path}")

    hard_fail = sum(1 for r in results
                    if r.error and not r.error.startswith("out-of-bridge")
                    and not r.probe.is_passthrough)
    warns = sum(1 for r in results if r.error.startswith("out-of-bridge"))
    print(f"RESULT {'PASS' if hard_fail == 0 else 'FAIL'} "
          f"failures={hard_fail} warnings={warns}")
    return 0 if hard_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
