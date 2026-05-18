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
class ProbeResult:
    probe: Probe
    words: list[int]    # words read (length depends on mode/burst)
    uid: int | None = None
    version: int | None = None
    error: str = ""


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


def render_markdown(results: list[ProbeResult], header: dict[str, str],
                    mode: str) -> str:
    lines: list[str] = []
    lines.append(f"# FEB SciFi v3 — IP Inventory Probe ({mode} mode)")
    lines.append("")
    for k, v in header.items():
        lines.append(f"- **{k}**: {v}")
    lines.append("")
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
    ap.add_argument("--mode", choices=("uid", "version", "full"),
                    default="version",
                    help="Probe depth (default: version)")
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

    hard_fail = sum(1 for r in results
                    if r.error and not r.error.startswith("out-of-bridge")
                    and not r.probe.is_passthrough)
    warns = sum(1 for r in results if r.error.startswith("out-of-bridge"))
    print(f"RESULT {'PASS' if hard_fail == 0 else 'FAIL'} "
          f"failures={hard_fail} warnings={warns}")
    return 0 if hard_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
