#!/usr/bin/env python3
"""On-board FEB SciFi v3 IP inventory probe.

Reads UID and META-mux VERSION from each user-IP CSR on the FEB via
sc_tool (over the SWB secondary ring) and emits a markdown report.

Address table is derived from the build's own sopcinfo
(generated/qsys/feb_system_v3.sopcinfo). Default IPs covered:

- control path: scratch_pad_ram, onewire_master_controller,
  max10_prog_avmm, firefly_xcvr_ctrl, on_die_temp_sense_ctrl,
  mutrig_cfg_ctrl, sc_hub internal CSR
- data path (via control_path|mm_bridge at sc-byte 0x20000):
  emulator_mutrig, dbg_mm2runctrl, mts_preprocessor_0,
  mts_preprocessor_1, histogram_statistics_v2 (csr + hist_bin),
  mutrig_injector_multiheader, mutrig_reset_controller,
  arb_hit_type0_supercore_0_csr_pipe_0..7

Usage:

  ./probe_feb_ip_inventory.py [--link 2] [--program] [--settle 20] \
      [--output reports/feb_inventory_<stamp>.md]

  --program       quartus_pgm the matching .sof first, then settle.
  --settle SEC    sleep N seconds after program before probing (default 20).
  --link N        SC ring link (default 2 = FEB SciFi on this teferi setup).

sc_tool always goes through ~/.local/bin/swb_ring_lock so the ring is
serialized against rc_tool/rw concurrent users on the same SWB.
"""

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent

DEFAULT_SOPCINFO = SYSTEM_DIR / "generated" / "qsys" / "feb_system_v3.sopcinfo"
DEFAULT_SOF = SYSTEM_DIR / "syn" / "board_projects" / "fe_scifi_feb_v3" / "output_files" / "top.sof"
DEFAULT_OUTPUT = SYSTEM_DIR / "tb_int" / "reports" / "feb_inventory_{stamp}.md"
DEFAULT_SC_TOOL = Path("/home/yifeng/packages/online_dpv2/online/install/bin/sc_tool")
DEFAULT_SWB_LOCK = Path.home() / ".local" / "bin" / "swb_ring_lock"
DEFAULT_JTAG_CABLE = "USB-BlasterII [7-2]"

CTRL_BRIDGE_TO_DATA_BYTE = 0x00020000  # control_path -> data_path master gateway
# control_path_subsystem_mm_bridge addressSpan is 0x10000 (64 KiB), so only
# data-path internal offsets < 0x10000 are reachable from sc_hub. Internal
# offsets >= 0x10000 alias back into the lower window and produce wrong
# readbacks (mutrig_injector at internal 0x22000 reads as emulator at 0x2000).
CTRL_BRIDGE_TO_DATA_SPAN = 0x10000


@dataclass
class Probe:
    label: str
    kind: str
    instance: str
    base_byte: int
    data_path_local_offset: int | None = None  # internal addr on data-path master, for range check
    note: str = ""

    @property
    def base_word(self) -> int:
        return self.base_byte // 4

    @property
    def reachable(self) -> bool:
        # If on the data-path master, the control_path mm_bridge addressSpan
        # truncates anything >= 0x10000 internal. Flag as out-of-bridge.
        if self.data_path_local_offset is None:
            return True
        return self.data_path_local_offset < CTRL_BRIDGE_TO_DATA_SPAN


@dataclass
class ProbeResult:
    probe: Probe
    uid: int | None
    version: int | None
    error: str = ""


def parse_sopcinfo(sopcinfo: Path) -> list[Probe]:
    root = ET.parse(sopcinfo).getroot()
    modules = {m.get("name"): m for m in root.findall(".//module") if m.get("name")}

    def get_param(c, name):
        for p in c.findall("parameter"):
            if p.get("name") == name:
                v = p.get("value")
                if v is None:
                    v = p.findtext("value")
                return v
        return None

    def parse_int(v):
        if v is None:
            return None
        try:
            return int(v, 0)
        except ValueError:
            return None

    SC_MASTER = "control_path_subsystem_sc_hub_cmd_pipe.m0"
    DATA_MASTER = "data_path_subsystem_master_datapath.master"

    # 1) direct SC-hub slaves (control path)
    direct: list[Probe] = []
    for c in root.findall(".//connection"):
        if c.get("start") != SC_MASTER:
            continue
        end = c.get("end", "")
        base = parse_int(get_param(c, "baseAddress"))
        if base is None:
            continue
        em = end.split(".")[0]
        kind = modules.get(em, {}).get("kind", "?") if modules.get(em) is not None else "?"
        # We probe via CSR interface; only keep the .csr / .csr_avmm / .firefly etc. ports
        port = end.split(".", 1)[1] if "." in end else ""
        if em.endswith("mm_bridge") or em.endswith("scratch_pad_ram") or em.endswith("upload_mm_bridge") or em.endswith("legacy_firefly_bridge"):
            continue
        direct.append(Probe(
            label=f"{em}.{port}",
            kind=kind,
            instance=em,
            base_byte=base,
        ))

    # 2) data-path slaves via control_path mm_bridge gateway at 0x20000
    data: list[Probe] = []
    for c in root.findall(".//connection"):
        if c.get("start") != DATA_MASTER:
            continue
        end = c.get("end", "")
        local_base = parse_int(get_param(c, "baseAddress"))
        if local_base is None:
            continue
        em = end.split(".")[0]
        port = end.split(".", 1)[1] if "." in end else ""
        kind = modules.get(em, {}).get("kind", "?") if modules.get(em) is not None else "?"
        # skip pass-through bridges and FIFOs
        if kind in ("altera_avalon_mm_bridge", "altera_avalon_sc_fifo"):
            continue
        # only keep CSR / hist_bin user-IP slaves; skip multiple ports per IP except the first
        if port and port not in ("csr", "csr_avmm", "hist_bin", "firefly", "ctrl", "reconfig_mgmt"):
            continue
        data.append(Probe(
            label=f"{em}.{port}",
            kind=kind,
            instance=em,
            base_byte=CTRL_BRIDGE_TO_DATA_BYTE + local_base,
            data_path_local_offset=local_base,
        ))

    # 3) sc_hub internal CSR (constant location: sc-word 0xFE80)
    sc_hub_internal = Probe(
        label="sc_hub_internal_csr",
        kind="sc_hub_v2",
        instance="control_path_subsystem_sc_hub",
        base_byte=0xFE80 * 4,
        note="hub internal CSR; word 0xFE80",
    )

    return sorted(direct + [sc_hub_internal] + data, key=lambda x: x.base_byte)


def sc_tool_cmd(sc_tool: Path, swb_lock: Path, link: int, op: str, addr_word: int,
                value_or_len: int) -> list[str]:
    base = [str(swb_lock), "--", str(sc_tool), str(link), op,
            f"0x{addr_word:05X}", f"0x{value_or_len:X}" if op == "write" else str(value_or_len),
            "--quiet"]
    return base


_PAYLOAD_RE = re.compile(r"^\s*payload\[0\]\s*=\s*(0x[0-9a-fA-F]+)")
_RSP_NOT_OK_RE = re.compile(r"^\s*rsp\s*:\s*(?!OK)(\S+)", re.MULTILINE)


def parse_sc_read_word(stdout: str) -> int | None:
    # sc_tool prints `info: packet payload:\n  payload[0] = 0xXXXXXXXX` for a
    # single-word read. The header word `0x1C0002BC` printed earlier in the
    # transcript is the wire frame, not the slave data.
    for line in stdout.splitlines():
        m = _PAYLOAD_RE.match(line)
        if m:
            return int(m.group(1), 16)
    return None


def sc_read_word(sc_tool: Path, swb_lock: Path, link: int, addr_word: int) -> tuple[int | None, str]:
    cmd = sc_tool_cmd(sc_tool, swb_lock, link, "read", addr_word, 1)
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    out = proc.stdout + proc.stderr
    if proc.returncode != 0:
        return None, f"rc={proc.returncode}: {out.strip()[-200:]}"
    val = parse_sc_read_word(out)
    if val is None:
        return None, f"unparsed: {out.strip()[-200:]}"
    return val, ""


def sc_write_word(sc_tool: Path, swb_lock: Path, link: int, addr_word: int, value: int) -> str:
    cmd = sc_tool_cmd(sc_tool, swb_lock, link, "write", addr_word, value)
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
    if proc.returncode != 0:
        return f"rc={proc.returncode}: {(proc.stdout + proc.stderr).strip()[-200:]}"
    return ""


def probe_ip(p: Probe, sc_tool: Path, swb_lock: Path, link: int) -> ProbeResult:
    if not p.reachable:
        return ProbeResult(
            probe=p, uid=None, version=None,
            error=(f"out-of-bridge: data-path internal 0x{p.data_path_local_offset:05x}"
                   f" >= ctrl mm_bridge addressSpan 0x{CTRL_BRIDGE_TO_DATA_SPAN:05x}"),
        )
    # UID at offset 0x00 (= word base + 0)
    uid, err = sc_read_word(sc_tool, swb_lock, link, p.base_word + 0)
    if err:
        return ProbeResult(probe=p, uid=None, version=None, error=f"uid: {err}")
    # META selector page 0 = VERSION. Write 0 to META (offset 0x04 = word +1),
    # then read META back.
    werr = sc_write_word(sc_tool, swb_lock, link, p.base_word + 1, 0)
    if werr:
        return ProbeResult(probe=p, uid=uid, version=None, error=f"meta_sel: {werr}")
    ver, err = sc_read_word(sc_tool, swb_lock, link, p.base_word + 1)
    if err:
        return ProbeResult(probe=p, uid=uid, version=None, error=f"version: {err}")
    return ProbeResult(probe=p, uid=uid, version=ver)


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
        if 0x20 <= c < 0x7F:
            ascii_repr += chr(c)
        else:
            ascii_repr += "."
    return f"0x{v:08X} ({ascii_repr})"


def fmt_version(v: int | None) -> str:
    if v is None:
        return "—"
    # Mu3e META[VERSION] encoding: [31:24]=MAJOR, [23:16]=MINOR,
    # [15:12]=PATCH, [11:0]=BUILD
    major = (v >> 24) & 0xFF
    minor = (v >> 16) & 0xFF
    patch = (v >> 12) & 0xF
    build = v & 0xFFF
    return f"0x{v:08X} = {major}.{minor}.{patch}.{build:03d}"


def render_markdown(results: list[ProbeResult], header_info: dict[str, str]) -> str:
    lines: list[str] = []
    lines.append("# FEB SciFi v3 — IP Inventory Probe")
    lines.append("")
    for k, v in header_info.items():
        lines.append(f"- **{k}**: {v}")
    lines.append("")
    lines.append("## Per-IP CSR readback")
    lines.append("")
    lines.append("| sc-word | sc-byte | kind | instance | UID | VERSION (META[0]) | status |")
    lines.append("|---|---|---|---|---|---|---|")
    ok = 0
    fail = 0
    warn = 0
    for r in results:
        p = r.probe
        if r.error.startswith("out-of-bridge"):
            status = "OUT-OF-BRIDGE"
            warn += 1
        elif r.error:
            status = f"ERR ({r.error[:60]})"
            fail += 1
        else:
            status = "OK"
            ok += 1
        uid_str = fmt_uid(r.uid)
        lines.append(
            f"| 0x{p.base_word:05X} | 0x{p.base_byte:06X} | {p.kind} | {p.instance} "
            f"| {uid_str} | {fmt_version(r.version)} | {status} |"
        )
    lines.append("")
    lines.append(f"**Summary**: {ok} OK / {fail} fail / {warn} out-of-bridge / {ok + fail + warn} probed")
    if warn:
        lines.append("")
        lines.append(
            f"> **Note**: control_path_subsystem_mm_bridge addressSpan is "
            f"0x{CTRL_BRIDGE_TO_DATA_SPAN:05x} (64 KiB). Data-path slaves at "
            f"internal offsets >= 0x{CTRL_BRIDGE_TO_DATA_SPAN:05x} are not "
            f"reachable from sc_hub (the bridge truncates the upper address "
            f"bits, aliasing them into the lower window). Reach those via the "
            f"JTAG master / system_console path, or widen the bridge in the qsys.")
    return "\n".join(lines) + "\n"


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--sopcinfo", type=Path, default=DEFAULT_SOPCINFO)
    ap.add_argument("--sof", type=Path, default=DEFAULT_SOF)
    ap.add_argument("--sc-tool", type=Path, default=DEFAULT_SC_TOOL)
    ap.add_argument("--swb-lock", type=Path, default=DEFAULT_SWB_LOCK)
    ap.add_argument("--quartus-pgm", type=Path,
                    default=Path("/data1/intelFPGA/18.1/quartus/bin/quartus_pgm"))
    ap.add_argument("--jtag-cable", default=DEFAULT_JTAG_CABLE)
    ap.add_argument("--link", type=int, default=2,
                    help="SWB SC ring link number for FEB SciFi (default 2)")
    ap.add_argument("--program", action="store_true", help="quartus_pgm the SOF before probing")
    ap.add_argument("--settle", type=int, default=20,
                    help="Seconds to sleep after program before probing (default 20)")
    ap.add_argument("--output", type=Path,
                    default=Path(str(DEFAULT_OUTPUT).format(
                        stamp=dt.datetime.now().strftime("%Y%m%d_%H%M%S"))))
    args = ap.parse_args(argv)

    if not args.sopcinfo.is_file():
        print(f"sopcinfo not found: {args.sopcinfo}", file=sys.stderr)
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

    probes = parse_sopcinfo(args.sopcinfo)
    print(f"[probe] {len(probes)} IP CSR endpoints from {args.sopcinfo.name}")
    results: list[ProbeResult] = []
    for p in probes:
        r = probe_ip(p, args.sc_tool, args.swb_lock, args.link)
        results.append(r)
        marker = "OK" if not r.error else "ERR"
        print(f"  [{marker:3}] 0x{p.base_word:05X}  {p.kind:32}  {p.instance}")
        if r.error:
            print(f"        {r.error}")

    header = {
        "Timestamp": dt.datetime.now().isoformat(timespec="seconds"),
        "SOF": str(args.sof),
        "sopcinfo": str(args.sopcinfo),
        "JTAG cable": args.jtag_cable,
        "SC link": str(args.link),
        "sc_tool": str(args.sc_tool),
        "swb_ring_lock": str(args.swb_lock),
    }
    md = render_markdown(results, header)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(md, encoding="utf-8")
    print(f"\nWrote {args.output}")

    hard_fail = sum(1 for r in results if r.error and not r.error.startswith("out-of-bridge"))
    warns = sum(1 for r in results if r.error.startswith("out-of-bridge"))
    print(f"RESULT {'PASS' if hard_fail == 0 else 'FAIL'} failures={hard_fail} warnings={warns}")
    return 0 if hard_fail == 0 else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
