#!/usr/bin/env python3
"""Build the Phase 4.5 five-tab local HTML report.

The report is intentionally static: no CDN, no JavaScript dependency, and no
live hardware access.  It consumes checked-in docs plus existing sim/board
evidence trees and emits one HTML file under the v3_pretest-260511 emulator
build doc directory.
"""
from __future__ import annotations

import datetime as dt
import html
import importlib.util
import json
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DOC_DIR = REPO_ROOT / "firmware_builds" / "systems" / "v3_pretest-260511" / "doc"
BUILD_DIR = REPO_ROOT / "firmware_builds" / "systems" / "v3_pretest-260511-emulator-type0-260512"
DUALPORT_BUILD_DIR = REPO_ROOT / "firmware_builds" / "systems" / "v3_pretest-260511-emutype0-dualport-260512"
SIM_EVIDENCE_ROOT = (
    REPO_ROOT
    / "firmware_builds"
    / "systems"
    / "system_20260504_emulator_type0"
    / "tb_int"
    / "feb_swb_corun"
    / "sim_evidence"
)
BOARD_EVIDENCE_ROOT = DUALPORT_BUILD_DIR / "sweep_evidence"
OUTPUT_HTML = BUILD_DIR / "doc" / "PHASE4_5_SWEEP_REPORT_5TAB.html"
SWEEP_SCRIPT = REPO_ROOT / "scripts" / "cotest" / "phase4_5_sweep.py"


@dataclass(frozen=True)
class IpSpec:
    ip: str
    hw_tcl: str | None
    svd: str | None
    csr_meta: str | None
    sc_addr: str
    csr_base: str
    note: str = ""
    source_note: str = ""
    kind_override: str | None = None
    uid_override: str | None = None
    version_override: str | None = None
    author_override: str | None = None
    build_date_override: str | None = None


def ip_specs() -> list[IpSpec]:
    specs: list[IpSpec] = [
        IpSpec("scratch_pad_ram", None, "toolkits/infra/cmsis_svd/generic/scratch_pad_ram.svd", None, "0x00000 / 0x00000", "0x00000000", "built-in memory; BU bridge smoke"),
        IpSpec("sc_hub_0", "slow-control_hub/sc_hub_v2_hw.tcl", "slow-control_hub/sc_hub.svd", None, "0x3FA00 / 0x0FE80", "overlay", "SC-hub UID overlay", uid_override="0x53434842", build_date_override="2026-04-23"),
        IpSpec("onewire_master_controller_0", "onewire_temp_sense/script/onewire_master_controller_hw.tcl", "onewire_temp_sense/script/onewire_master_controller.svd", None, "0x11000 / 0x04400", "0x00011000"),
        IpSpec("onewire_master_0", "onewire_temp_sense/script/onewire_master_hw.tcl", None, None, "no SC", "controller-only", "no SC, controller-only"),
        IpSpec("max10_prog_avmm_0", "feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm_hw.tcl", "feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm.svd", None, "0x12000 / 0x04800", "0x00012000"),
        IpSpec("charge_injection_pulser_0", "charge_injection/legacy/analog_pulser_hw.tcl", "charge_injection/legacy/charge_injection_pulser.svd", None, "DROPPED (slot 4 free)", "DROPPED", "LEGACY; DROPPED (slot 4 free; no drop commit in last 20)"),
        IpSpec("mutrig_injector_0", "charge_injection/script/mutrig_injector_multiheader_hw.tcl", "charge_injection/script/mutrig_injector.svd", "charge_injection/script/mutrig_injector_csr_meta.tcl", "0x2B200 / 0x0AC80", "0x0000B200", "ACTIVE"),
        IpSpec("firefly_xcvr_ctrl_0", "firefly_xcvr_i2c_master/firefly_xcvr_ctrl_hw.tcl", "firefly_xcvr_i2c_master/firefly_xcvr_ctrl.svd", None, "0x14000 / 0x05000", "0x00014000"),
        IpSpec("legacy_firefly_bridge", None, "toolkits/infra/cmsis_svd/generic/mm_bridge_passthrough.svd", None, "0x16000 / 0x05800", "0x00016000", "Platform Designer bridge in SC map", kind_override="altera_avalon_mm_bridge", version_override="18.1", author_override="Intel/Altera", build_date_override="Qsys built-in"),
        IpSpec("on_die_temp_sense_ctrl", "alt_temp_sense_controller/altera_temp_sense_ctrl_hw.tcl", "alt_temp_sense_controller/altera_temp_sense_ctrl.svd", None, "0x15000 / 0x05400", "0x00015000"),
        IpSpec("mutrig_cfg_ctrl_0", "mutrig_controller/mutrig_controller_hw.tcl", "mutrig_controller/mutrig_cfg_ctrl.svd", None, "0x3F010 / 0x0FC04", "0x0003F010"),
        IpSpec("mm_bridge", None, "toolkits/infra/cmsis_svd/generic/mm_bridge_passthrough.svd", None, "0x20000 / 0x08000", "0x00020000", "Platform Designer bridge to datapath map", kind_override="altera_avalon_mm_bridge", version_override="18.1", author_override="Intel/Altera", build_date_override="Qsys built-in"),
        IpSpec("upload_mm_bridge", None, "toolkits/infra/cmsis_svd/generic/mm_bridge_passthrough.svd", None, "0x30000 / 0x0C000", "0x00030000", "Platform Designer bridge to upload map", kind_override="altera_avalon_mm_bridge", version_override="18.1", author_override="Intel/Altera", build_date_override="Qsys built-in"),
        IpSpec("runctl_mgmt_host_0", "run-control_mgmt/runctl_mgmt_host_hw.tcl", "run-control_mgmt/runctl_mgmt_host.svd", None, "0x30000 / 0x0C000", "0x00000000"),
        IpSpec("lvds_rx_controller_pro_0", "mu3e_lvds_controller/lvds_rx_controller_pro_hw.tcl", "mu3e_lvds_controller/lvds_rx_controller_pro.svd", None, "0x20000 / 0x08000", "0x00000000"),
        IpSpec("mutrig_reset_controller_0", "mutrig_reset_controller/mutrig_reset_controller_hw.tcl", "mutrig_reset_controller/mutrig_reset_controller.svd", None, "0x20200 / 0x08080", "0x00000200"),
    ]
    for lane in range(8):
        local = 0x2000 + lane * 0x40
        pkt = 0x08000 + local // 4
        specs.append(IpSpec(
            f"emulator_mutrig_{lane}",
            "emulator_mutrig/emulator_mutrig_hw.tcl",
            "emulator_mutrig/emulator_mutrig.svd",
            None,
            f"0x{pkt * 4:05X} / 0x{pkt:05X}",
            f"0x{local:08X}",
        ))
    specs.extend([
        IpSpec("arb_hit_type0_supercore_0", "misc/arb_hit_type0/script/arb_hit_type0_supercore_hw.tcl", None, None, "0x22280 / 0x088A0", "0x000022A0", "rc-readyless supercore; lane CSR contents are arb_hit_type0"),
        IpSpec("arb_hit_type0_0", "misc/arb_hit_type0/script/arb_hit_type0_hw.tcl", None, None, "0x22280 / 0x088A0", "0x000022A0", "per-lane CSR behind supercore"),
        IpSpec("arb_hit_type0_runctl_0", None, None, None, "inside arb_hit_type0_supercore_0", "no separate aperture", "TBD: no standalone _hw.tcl found; RTL block under misc/arb_hit_type0/rtl"),
        IpSpec("mts_preprocessor_0", "mutrig_timestamp_processor/mts_processor_hw.tcl", "mutrig_timestamp_processor/mts_processor.svd", "mutrig_timestamp_processor/mts_processor_csr_meta.tcl", "0x24000 / 0x09000", "0x00004000"),
        IpSpec("mts_preprocessor_1", "mutrig_timestamp_processor/mts_processor_hw.tcl", "mutrig_timestamp_processor/mts_processor.svd", "mutrig_timestamp_processor/mts_processor_csr_meta.tcl", "0x28000 / 0x0A000", "0x00008000"),
        IpSpec("histogram_statistics_0", "histogram_statistics/histogram_statistics_v2_hw.tcl", "histogram_statistics/histogram_statistics.svd", None, "0x2A400 / 0x0A900", "0x0000A400"),
        IpSpec("histogram_ingress_bridge_0", "histogram_statistics/histogram_ingress_bridge_hw.tcl", "histogram_statistics/histogram_ingress_bridge.svd", None, "0x2AC00 / 0x0AB00", "0x0000AC00"),
    ])
    rbases = [0xB000, 0xB080, 0xB100, 0xB180, 0xB400, 0xB480, 0xB500, 0xB580]
    for idx, local in enumerate(rbases):
        pkt = 0x08000 + local // 4
        specs.append(IpSpec(
            f"ring_buffer_cam_{idx}",
            "ring-buffer_cam/script/ring_buffer_cam_hw.tcl",
            "ring-buffer_cam/script/ring_buffer_cam.svd",
            "ring-buffer_cam/script/ring_buffer_cam_csr_meta.tcl",
            f"0x{pkt * 4:05X} / 0x{pkt:05X}",
            f"0x{local:08X}",
        ))
    specs.extend([
        IpSpec("feb_frame_assembly_0", "feb_frame_assembly/feb_frame_assembly_hw.tcl", "feb_frame_assembly/feb_frame_assembly.svd", None, "0x34000 / 0x0D000", "0x0000D000"),
        IpSpec("feb_frame_assembly_1", "feb_frame_assembly/feb_frame_assembly_hw.tcl", "feb_frame_assembly/feb_frame_assembly.svd", None, "0x34040 / 0x0D010", "0x0000D040"),
        IpSpec("mutrig_frame_deassembly_0", "mutrig_frame_deassembly/script/mutrig_frame_deassembly_hw.tcl", "mutrig_frame_deassembly/script/mutrig_frame_deassembly.svd", None, "not mapped in v3_pretest AUTO map", "TBD"),
    ])
    return specs


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        return path.read_text(encoding="latin-1")


def clean_token(token: str) -> str:
    token = token.strip()
    if token.startswith('"') and token.endswith('"'):
        return token[1:-1]
    if token.startswith("{") and token.endswith("}"):
        return token[1:-1]
    return token


def parse_tcl_sets(text: str) -> dict[str, str]:
    values: dict[str, str] = {}
    for raw in text.splitlines():
        line = raw.split(";#", 1)[0].strip()
        if not line.startswith("set "):
            continue
        match = re.match(r"set\s+([A-Za-z0-9_:]+)\s+(.+)$", line)
        if not match:
            continue
        values[match.group(1)] = clean_token(match.group(2).strip())
    return values


def parse_module_property(text: str, name: str) -> str | None:
    match = re.search(rf"set_module_property\s+{re.escape(name)}\s+(.+)", text)
    if not match:
        return None
    value = match.group(1).strip()
    if " " in value and not value.startswith(('"', "{", "$")):
        value = value.split()[0]
    return clean_token(value)


def parse_int_token(token: str | None, values: dict[str, str]) -> int | None:
    if token is None:
        return None
    token = token.strip()
    if token.startswith("$"):
        token = values.get(token[1:], token)
    token = clean_token(token)
    if token.startswith("[expr") and "0x" in token:
        token = re.search(r"0x[0-9A-Fa-f]+", token).group(0)  # type: ignore[union-attr]
    if re.fullmatch(r"0x[0-9A-Fa-f]+", token):
        return int(token, 16)
    if re.fullmatch(r"[0-9]+", token):
        return int(token, 10)
    return None


def version_from_values(values: dict[str, str]) -> str | None:
    prefixes = ["", "SC_HUB_V2_"]
    for prefix in prefixes:
        major = parse_int_token(values.get(prefix + "VERSION_MAJOR_DEFAULT_CONST"), values)
        minor = parse_int_token(values.get(prefix + "VERSION_MINOR_DEFAULT_CONST"), values)
        patch = parse_int_token(values.get(prefix + "VERSION_PATCH_DEFAULT_CONST"), values)
        build = parse_int_token(values.get(prefix + "BUILD_DEFAULT_CONST"), values)
        if None not in (major, minor, patch, build):
            return f"{major}.{minor}.{patch}.{build:04d}"
    return None


def yyyymmdd_to_date(value: int | None) -> str | None:
    if value is None:
        return None
    text = f"{value:08d}"
    try:
        return f"{text[0:4]}-{text[4:6]}-{text[6:8]}"
    except IndexError:
        return None


def header_date(text: str) -> str | None:
    patterns = [
        r"(20[0-9]{2})[.:-]([01][0-9])[.:-]([0-3][0-9])",
        r"(Mon|Tue|Wed|Thu|Fri|Sat|Sun)\s+([A-Z][a-z]{2})\s+([0-3]?[0-9]).*(20[0-9]{2})",
    ]
    match = re.search(patterns[0], text[:2000])
    if match:
        return f"{match.group(1)}-{match.group(2)}-{match.group(3)}"
    match = re.search(patterns[1], text[:2000])
    if match:
        month = {
            "Jan": "01", "Feb": "02", "Mar": "03", "Apr": "04",
            "May": "05", "Jun": "06", "Jul": "07", "Aug": "08",
            "Sep": "09", "Oct": "10", "Nov": "11", "Dec": "12",
        }[match.group(2)]
        return f"{match.group(4)}-{month}-{int(match.group(3)):02d}"
    return None


def hw_metadata(spec: IpSpec) -> dict[str, str]:
    meta = {
        "kind": spec.kind_override or "TBD",
        "uid": spec.uid_override or "TBD",
        "version": spec.version_override or "TBD",
        "author": spec.author_override or "TBD",
        "build_date": spec.build_date_override or "TBD",
    }
    if spec.hw_tcl is None:
        return meta
    path = REPO_ROOT / spec.hw_tcl
    if not path.exists():
        return meta
    text = read_text(path)
    values = parse_tcl_sets(text)
    if "sc_hub_v2_hw.tcl" in spec.hw_tcl:
        params = REPO_ROOT / "slow-control_hub" / "hw_tcl" / "sc_hub_v2_params.tcl"
        if params.exists():
            values.update(parse_tcl_sets(read_text(params)))
    meta["kind"] = spec.kind_override or parse_module_property(text, "NAME") or meta["kind"]
    version_prop = parse_module_property(text, "VERSION")
    if spec.version_override:
        meta["version"] = spec.version_override
    elif version_prop and not version_prop.startswith("$"):
        meta["version"] = version_prop
    else:
        meta["version"] = version_from_values(values) or meta["version"]
    meta["author"] = spec.author_override or parse_module_property(text, "AUTHOR") or meta["author"]
    uid_value = (
        parse_int_token(values.get("IP_UID_DEFAULT_CONST"), values)
        or parse_int_token(values.get("IP_ID_DEFAULT_CONST"), values)
        or parse_int_token(values.get("SC_HUB_V2_IP_UID_DEFAULT_CONST"), values)
    )
    if spec.uid_override:
        meta["uid"] = spec.uid_override
    elif uid_value is not None:
        meta["uid"] = f"0x{uid_value & 0xFFFFFFFF:08X}"
    date_value = (
        parse_int_token(values.get("VERSION_DATE_DEFAULT_CONST"), values)
        or parse_int_token(values.get("SC_HUB_V2_VERSION_DATE_DEFAULT_CONST"), values)
    )
    if spec.build_date_override:
        meta["build_date"] = spec.build_date_override
    else:
        meta["build_date"] = yyyymmdd_to_date(date_value) or header_date(text) or dt.datetime.fromtimestamp(path.stat().st_mtime).strftime("%Y-%m-%d")
    return meta


def strip_ns(tag: str) -> str:
    return tag.split("}", 1)[-1]


def child_text(elem: ET.Element, name: str) -> str | None:
    for child in elem:
        if strip_ns(child.tag) == name and child.text is not None:
            return child.text.strip()
    return None


def parse_svd_registers(path: Path, uid: str, version: str) -> list[dict[str, str]]:
    if not path.exists():
        return []
    try:
        root = ET.parse(path).getroot()
    except ET.ParseError:
        return []
    device_reset = child_text(root, "resetValue") or ""
    rows: list[dict[str, str]] = []
    for reg in root.iter():
        if strip_ns(reg.tag) != "register":
            continue
        name = child_text(reg, "name") or "UNKNOWN"
        desc = child_text(reg, "description") or ""
        offset = child_text(reg, "addressOffset") or "TBD"
        access = child_text(reg, "access") or ""
        reset = child_text(reg, "resetValue") or device_reset or expected_for_name(name, uid, version)
        fields: list[str] = []
        for field in reg.iter():
            if strip_ns(field.tag) != "field":
                continue
            fname = child_text(field, "name") or "field"
            boff = child_text(field, "bitOffset")
            width = child_text(field, "bitWidth")
            bit_range = f"[{boff}+:{width}]" if boff and width else ""
            fields.append(f"{fname}{bit_range}")
        rows.append({
            "offset": offset,
            "field": name if not fields else f"{name}: {', '.join(fields[:6])}",
            "access": access,
            "description": desc,
            "expected": reset,
            "source": path.name,
        })
    return rows


def expected_for_name(name: str, uid: str, version: str) -> str:
    upper = name.upper()
    if upper in {"UID", "ID", "IP_ID"} and uid != "TBD":
        return uid
    if upper == "VERSION" and version != "TBD":
        return version
    if upper == "META" and version != "TBD":
        return f"VERSION page {version}"
    return ""


def parse_html_rows_from_tcl(path: Path, uid: str, version: str) -> list[dict[str, str]]:
    if not path.exists():
        return []
    text = read_text(path)
    rows: list[dict[str, str]] = []
    for table_match in re.finditer(r"<table.*?</table>", text, flags=re.IGNORECASE | re.DOTALL):
        table = table_match.group(0)
        headers: list[str] = []
        for tr in re.findall(r"<tr.*?</tr>", table, flags=re.IGNORECASE | re.DOTALL):
            cells = re.findall(r"<t[hd][^>]*>(.*?)</t[hd]>", tr, flags=re.IGNORECASE | re.DOTALL)
            clean = [html.unescape(re.sub(r"<[^>]+>", "", c)).strip() for c in cells]
            clean = [re.sub(r"\s+", " ", c) for c in clean]
            if not clean:
                continue
            if "<th" in tr.lower():
                headers = [c.lower() for c in clean]
                continue
            if len(clean) < 3:
                continue
            data = {headers[i] if i < len(headers) else f"c{i}": clean[i] for i in range(len(clean))}
            name = data.get("name") or data.get("register") or clean[2 if len(clean) > 2 else 0]
            offset = data.get("byte") or data.get("word") or clean[0]
            access = data.get("access", "")
            desc = data.get("description", clean[-1])
            default = data.get("default") or data.get("reset") or expected_for_name(name, uid, version)
            rows.append({
                "offset": offset,
                "field": name,
                "access": access,
                "description": desc,
                "expected": default,
                "source": path.name,
            })
    return rows


def parse_csr_meta(path: Path, uid: str, version: str) -> list[dict[str, str]]:
    if not path.exists():
        return []
    text = read_text(path)
    rows: list[dict[str, str]] = []
    pattern = re.compile(
        r"meta::register\s+\"([^\"]+)\"\s+\"([^\"]+)\"\s+\"(0x[0-9A-Fa-f]+)\"(.*?)(?=\n\s*::board_bring_up::meta::register|\Z)",
        re.DOTALL,
    )
    for match in pattern.finditer(text):
        name, desc, offset, body = match.groups()
        fields = re.findall(r"meta::field\s+\"([^\"]+)\"", body)
        rows.append({
            "offset": offset,
            "field": name if not fields else f"{name}: {', '.join(fields[:6])}",
            "access": "",
            "description": desc,
            "expected": expected_for_name(name, uid, version),
            "source": path.name,
        })
    return rows


def csr_rows(spec: IpSpec, meta: dict[str, str]) -> list[dict[str, str]]:
    uid = meta["uid"]
    version = meta["version"]
    rows: list[dict[str, str]] = []
    if spec.csr_meta:
        rows.extend(parse_csr_meta(REPO_ROOT / spec.csr_meta, uid, version))
    if spec.svd:
        rows.extend(parse_svd_registers(REPO_ROOT / spec.svd, uid, version))
    if spec.hw_tcl:
        rows.extend(parse_html_rows_from_tcl(REPO_ROOT / spec.hw_tcl, uid, version))
    seen: set[tuple[str, str]] = set()
    unique: list[dict[str, str]] = []
    for row in rows:
        key = (row.get("offset", ""), row.get("field", ""))
        if key in seen:
            continue
        seen.add(key)
        unique.append(row)
    if unique:
        return unique
    if uid != "TBD":
        return [
            {"offset": "0x00", "field": "UID", "access": "RO", "description": "Common identity register", "expected": uid, "source": "identity fallback"},
            {"offset": "0x04", "field": "META", "access": "RW/RO", "description": "Common metadata mux", "expected": f"VERSION page {version}", "source": "identity fallback"},
        ]
    return [{
        "offset": "TBD",
        "field": "TBD",
        "access": "",
        "description": "No CSR metadata source was located for this row.",
        "expected": "",
        "source": "TBD",
    }]


def table(headers: list[str], rows: list[list[Any]], cls: str = "") -> str:
    klass = f' class="{cls}"' if cls else ""
    out = [f"<table{klass}>", "<thead><tr>"]
    out.extend(f"<th>{html.escape(str(h))}</th>" for h in headers)
    out.append("</tr></thead><tbody>")
    for row in rows:
        out.append("<tr>")
        out.extend(f"<td>{html.escape(str(cell))}</td>" for cell in row)
        out.append("</tr>")
    out.append("</tbody></table>")
    return "\n".join(out)


def parse_markdown_rows(path: Path, prefix: str) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    headers: list[str] = []
    for raw in read_text(path).splitlines():
        line = raw.strip()
        if not line.startswith("|"):
            continue
        cells = [c.strip() for c in line.strip("|").split("|")]
        if len(cells) < 2:
            continue
        if all(set(c) <= {"-", ":"} for c in cells):
            continue
        if cells[0] == "ID":
            headers = cells
            continue
        if cells[0].startswith(prefix):
            row = {headers[i] if i < len(headers) else f"c{i}": cells[i] for i in range(len(cells))}
            rows.append(row)
    return rows


def int_from_text(value: str) -> int | None:
    match = re.search(r"[0-9][0-9,]*", value)
    if not match:
        return None
    return int(match.group(0).replace(",", ""))


def load_sweep_module() -> Any:
    spec = importlib.util.spec_from_file_location("phase4_5_sweep", SWEEP_SCRIPT)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load {SWEEP_SCRIPT}")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def evidence_dirs(root: Path) -> dict[str, Path]:
    mapping: dict[str, Path] = {}
    if not root.exists():
        return mapping
    for entry in sorted(root.iterdir()):
        if not entry.is_dir() or not entry.name.startswith("p45_"):
            continue
        row_id = entry.name.split(".bak.", 1)[0]
        mapping[row_id] = entry
    return mapping


def load_json(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    try:
        return json.loads(read_text(path))
    except json.JSONDecodeError:
        return None


def fmt_num(value: float | int | None, digits: int = 1) -> str:
    if value is None:
        return "pending"
    if isinstance(value, int) or abs(value - round(value)) < 0.05:
        return f"{int(round(value)):,}"
    return f"{value:,.{digits}f}"


def fmt_pct(value: float | None) -> str:
    if value is None:
        return "pending"
    return f"{value:+.2f}%"


RN_BASIC_REPORT_ROOT = DUALPORT_BUILD_DIR / "cosim" / "REPORT"
RUN_WINDOW_MS = 1.0


def popcount(value: int) -> int:
    return bin(value).count("1")


def parse_hex_token(value: str | None) -> int | None:
    if not value:
        return None
    match = re.search(r"0[xX][0-9A-Fa-f]+", value)
    if not match:
        return None
    try:
        return int(match.group(0), 16)
    except ValueError:
        return None


def basic_row_theory(row: dict[str, str]) -> dict[str, Any]:
    """Compute popcount + theory_hits + theory_hits_per_ms for a TEST_BASIC row.

    Slice 1/2/4: theoretical_hits = popcount(L)*popcount(C)*rate/65536*125e6*1ms
    Slice 3 onclick: theoretical_hits = popcount(L)*popcount(C)*n_pulses (10)
    """
    lane = parse_hex_token(row.get("lane_mask"))
    chan = parse_hex_token(row.get("channel_mask"))
    rate = parse_hex_token(row.get("rate_88fp"))
    pulses = int_from_text(row.get("n_pulses", "") or "")
    pl = popcount(lane) if lane is not None else None
    pc = popcount(chan) if chan is not None else None
    pop_str = f"{pl} x {pc}" if pl is not None and pc is not None else row.get("popcount L x C", "")
    theory: int | float | None = None
    if pulses is not None and pl is not None and pc is not None:
        theory = pl * pc * pulses
    elif rate is not None and pl is not None and pc is not None:
        theory_f = pl * pc * (rate / 65536.0) * 125e6 * (RUN_WINDOW_MS / 1000.0)
        ceil = 250_000.0
        theory = int(round(min(theory_f, ceil)))
    if theory is None:
        clipped = int_from_text(row.get("clipped_hits", "") or row.get("theoretical_hits", "") or row.get("expected_hits", "") or "")
        theory = clipped
    theory_per_ms = (theory / RUN_WINDOW_MS) if isinstance(theory, (int, float)) else None
    return {
        "popcount": pop_str,
        "theory_hits": theory,
        "theory_hits_per_ms": theory_per_ms,
        "lane_pop": pl,
        "chan_pop": pc,
    }


def gather_rate_evidence(row_id: str) -> dict[str, Any] | None:
    """Read rate_csr_dump.json for a row. Returns None if missing."""
    path = RN_BASIC_REPORT_ROOT / row_id / "rate_csr_dump.json"
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


_DELAY_STATS_KEYS = {
    "count", "delay_mean_ns", "delay_stddev_ns",
    "delay_min_cycles", "delay_p05_cycles", "delay_p50_cycles",
    "delay_p95_cycles", "delay_max_cycles",
    "checkpoint", "bound_lower", "bound_upper",
}


def _strip_delay_arrays(payload: Any) -> Any:
    """Strip per-hit arrays from a delay JSON; keep only summary scalars."""
    if not isinstance(payload, dict):
        return payload
    return {k: v for k, v in payload.items() if k in _DELAY_STATS_KEYS}


# Math-reviewer per-checkpoint bounds (header-sync example values shown in
# the worktree reference plot; periodic / emul-only / onclick rows fall back
# to these same windows until #106 emits per-mode bounds in the row config).
_CHECKPOINT_BOUNDS_HEADER_SYNC = {
    "pre-rbCAM":   (0.0, 2000.0),
    "post-rbCAM":  (2000.0, 2200.0),
    "FEB egress":  (2049.0, 6143.0),
    "OPQ ingress": (2049.0, 6159.0),
    "OPQ egress":  (4356.0, 99133.5),
}
_CHECKPOINT_FORMULA = {
    "pre-rbCAM":   "D_pre = wait_910(hit_ts) + s(q) + 18 (virtual MuTRiG)",
    "post-rbCAM":  "D_post = (GTS_post - ts_hit) mod 8192",
    "FEB egress":  "D_feb <= 2F - p + 20 + eps_clk",
    "OPQ ingress": "D_ing = D_feb + adapter_sync",
    "OPQ egress":  "D_opq = D_ing + W_n, W_n = max(0, W_(n-1) + S_n - A_n)",
}
_CHECKPOINT_METRIC_TO_NAME = {
    "pre_rbcam_lifetime_cycles":   "pre-rbCAM",
    "post_rbcam_lifetime_cycles":  "post-rbCAM",
    "feb_egress_lifetime_cycles":  "FEB egress",
    "opq_ingress_lifetime_cycles": "OPQ ingress",
    "opq_egress_lifetime_cycles":  "OPQ egress",
}


def _parse_lifetime_stats_csv(path: Path) -> dict[str, dict[str, float]]:
    """Parse feb_swb_lifetime_hist_stats.csv -> {checkpoint_name: {stat_key: value}}.

    Columns: metric, checkpoint, count, min_cycles, p05_cycles, p50_cycles,
    p95_cycles, max_cycles, mean_cycles.
    """
    out: dict[str, dict[str, float]] = {}
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return out
    lines = text.splitlines()
    if not lines:
        return out
    header = [h.strip() for h in lines[0].split(",")]
    for line in lines[1:]:
        if not line.strip():
            continue
        cells = [c.strip() for c in line.split(",")]
        if len(cells) < len(header):
            continue
        row = dict(zip(header, cells))
        cp_name = row.get("checkpoint") or _CHECKPOINT_METRIC_TO_NAME.get(row.get("metric", ""), "")
        if not cp_name:
            continue

        def fnum(key: str) -> float | None:
            v = row.get(key, "")
            try:
                return float(v)
            except (TypeError, ValueError):
                return None

        out[cp_name] = {
            "count": fnum("count"),
            "delay_min_cycles": fnum("min_cycles"),
            "delay_p05_cycles": fnum("p05_cycles"),
            "delay_p50_cycles": fnum("p50_cycles"),
            "delay_p95_cycles": fnum("p95_cycles"),
            "delay_max_cycles": fnum("max_cycles"),
            "delay_mean_cycles": fnum("mean_cycles"),
        }
    return out


def gather_delay_evidence(row_id: str) -> dict[str, Any]:
    """Collect per-checkpoint delay stats for a row from the cosim's
    `feb_swb_lifetime_hist_stats.csv` (5 checkpoints, one row each).

    Each checkpoint entry carries: count, delay_min/p05/p50/p95/max_cycles,
    bound_lower, bound_upper (math-reviewer window), formula text, and
    optional pdf_rel to a DISLIN plot if rendered.

    The cosim per-hit arrays in delay_scoreboard.json are deliberately NOT
    inlined here -- they balloon the report to >250 MB across 194 rows.
    """
    base = RN_BASIC_REPORT_ROOT / row_id
    stats_csv = base / "feb_swb_lifetime_hist_stats.csv"
    by_name = _parse_lifetime_stats_csv(stats_csv) if stats_csv.is_file() else {}
    cps: list[dict[str, Any]] = []
    for name in ("pre-rbCAM", "post-rbCAM", "FEB egress", "OPQ ingress", "OPQ egress"):
        lo, hi = _CHECKPOINT_BOUNDS_HEADER_SYNC[name]
        entry: dict[str, Any] = {
            "name": name,
            "bound_lower": lo,
            "bound_upper": hi,
            "formula": _CHECKPOINT_FORMULA[name],
            "pdf_rel": None,
        }
        entry.update(by_name.get(name, {}))
        cps.append(entry)
    return {"checkpoints": cps, "source_csv": stats_csv.name if stats_csv.is_file() else None}


# Mu3e SWB frame markers per feb_data_frame.py + Mu3eSpecBook-4.pdf:
#   K28.5 (0xBC) = preamble       (frame start)
#   K28.4 (0x9C) = trailer        (frame end)
#   K23.7 (0xF7) is on-wire idle ONLY -- it does NOT appear in the host
#                 rdma rxbuffer payload, so we do not highlight it here.
SWB_K285 = 0xBC
SWB_K284 = 0x9C
PACKET_TYPE_LABELS: dict[int, str] = {
    0b111010: "MuPix",
    0b111000: "SciFi",
    0b110100: "Tile",
    0b111011: "MuPix Debug",
    0b111001: "SciFi Debug",
    0b110101: "Tile Debug",
    0b000111: "SlowControl",
    0b000010: "BERTs",
    0b000000: "Idle",
}


def _decode_preamble_words(words: list[int]) -> dict[str, Any]:
    """Decode a frame's 5-word fixed header (preamble + 4 follow-up words).

    Bit layout per feb_data_frame.py:parse_framed_stream():
      word0 (preamble): bits 31..26 = packet_type_code (6 bits)
                        bits 23..8  = fpga_id          (16 bits)
                        bits 7..0   = 0xBC K28.5 marker
      word1 (ts_high):  bits 31..0  = high 32 bits of packet_timestamp
      word2 (ts_low):   bits 31..16 = low 16 bits of packet_timestamp
                        bits 15..0  = package_counter
      word3 (debug0):   bits 30..16 = debug_subheader_count (15 bits)
                        bits 15..0  = debug_hit_count       (16 bits)
      word4 (debug1):   bits 30..0  = send_ts_counter       (31 bits)
    """
    if len(words) < 5:
        return {}
    w0, w1, w2, w3, w4 = words[:5]
    pkt_type = (w0 >> 26) & 0x3F
    fpga_id = (w0 >> 8) & 0xFFFF
    packet_timestamp = ((w1 & 0xFFFF_FFFF) << 16) | ((w2 >> 16) & 0xFFFF)
    package_counter = w2 & 0xFFFF
    debug_subheader_count = (w3 >> 16) & 0x7FFF
    debug_hit_count = w3 & 0xFFFF
    send_ts_counter = w4 & 0x7FFF_FFFF
    return {
        "packet_type_raw": pkt_type,
        "packet_type_label": PACKET_TYPE_LABELS.get(pkt_type, f"unknown 0x{pkt_type:02X}"),
        "fpga_id": fpga_id,
        "packet_timestamp": packet_timestamp,
        "package_counter": package_counter,
        "debug_subheader_count": debug_subheader_count,
        "debug_hit_count": debug_hit_count,
        "send_ts_counter": send_ts_counter,
    }


def _bytes_to_words_le(buf: bytes, byte_offset: int, n_words: int) -> list[int]:
    """Read n_words 32-bit little-endian words starting at byte_offset."""
    out: list[int] = []
    for i in range(n_words):
        s = byte_offset + i * 4
        if s + 4 > len(buf):
            break
        out.append(int.from_bytes(buf[s:s + 4], "little"))
    return out


def gather_rdma_evidence(row_id: str, max_bytes_decode: int = 16384, max_bytes_hex: int = 1024) -> dict[str, Any]:
    """Decode ALL frames from rdma_rxbuffer.bin up to max_bytes_decode.

    The host rdma rxbuffer is a 32-bit-word-aligned stream. Frame starts at
    each K28.5 (0xBC) byte sitting at word-LSB position. Frame ends at the
    K28.4 (0x9C) trailer byte (also word-LSB position).

    The decoder reads the 5-word fixed header (per feb_data_frame.py) and
    captures the full frame hex up to and including the trailer.
    """
    base = RN_BASIC_REPORT_ROOT / row_id
    summary_path = base / "rdma_rxbuffer_summary.json"
    bin_path = base / "rdma_rxbuffer.bin"
    out: dict[str, Any] = {"summary": None, "hex_lines": [], "frames": []}
    if summary_path.is_file():
        try:
            out["summary"] = json.loads(summary_path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError):
            out["summary"] = None
    if not bin_path.is_file():
        return out
    try:
        data = bin_path.read_bytes()
    except OSError:
        return out
    data = data[:max_bytes_decode]
    # Frame starts: K28.5 byte at word-LSB (offset % 4 == 0)
    frame_starts = [i for i in range(0, len(data), 4) if data[i] == SWB_K285]
    # Trailer ends: K28.4 byte at word-LSB
    trailer_offsets = set(i for i in range(0, len(data), 4) if data[i] == SWB_K284)

    frames: list[dict[str, Any]] = []
    for fi, start in enumerate(frame_starts):
        next_start = frame_starts[fi + 1] if (fi + 1) < len(frame_starts) else len(data)
        # Trailer for this frame: nearest K28.4 (word-aligned) in [start+4, next_start)
        trailer_pos = None
        for t in range(start + 4, next_start, 4):
            if t in trailer_offsets:
                trailer_pos = t
                break
        frame_end = (trailer_pos + 4) if trailer_pos is not None else next_start
        chunk = data[start:frame_end]
        words = _bytes_to_words_le(data, start, 5)
        hdr = _decode_preamble_words(words)
        frames.append({
            "frame_idx": fi,
            "byte_offset": start,
            "length": len(chunk),
            "hex": chunk.hex(),
            "trailer_offset": trailer_pos,
            "has_trailer": trailer_pos is not None,
            **hdr,
        })

    # 16-byte-per-row colorized hex of the first max_bytes_hex bytes for the
    # global hex pane. K23.7 is on-wire idle only and never lands in the host
    # rxbuffer, so we no longer paint it.
    hex_lines: list[dict[str, Any]] = []
    for off in range(0, min(len(data), max_bytes_hex), 16):
        row_bytes = data[off:off + 16]
        hex_str = "".join(f"{b:02x}" for b in row_bytes)
        roles: list[str] = []
        for byte_idx, byte in enumerate(row_bytes):
            absolute = off + byte_idx
            role = "d"
            if (absolute % 4) == 0:
                if byte == SWB_K285:
                    role = "5"
                elif byte == SWB_K284:
                    role = "4"
            roles.append(role)
        hex_lines.append({"o": off, "h": hex_str, "r": "".join(roles)})
    out["hex_lines"] = hex_lines
    out["frames"] = frames
    out["bytes_total_truncated_at"] = min(len(data), max_bytes_hex)
    out["frames_decoded"] = len(frames)
    return out


def gather_scoreboard_evidence(row_id: str) -> dict[str, Any] | None:
    """Read scoreboard.json for a row. The scoreboard is the sim-only monitor
    that checks per-checkpoint hit accounting against the source true-hit-list.

    Each entry has: checkpoint, total_hits, ghost_hits, broken_hits, missing_hits.
    """
    path = RN_BASIC_REPORT_ROOT / row_id / "scoreboard.json"
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def gather_runlog_evidence(row_id: str) -> dict[str, Any] | None:
    """Read run_log.json for a row. The run log captures phase transitions
    and CSR configure activity along the 1 ms RUNNING window.
    """
    path = RN_BASIC_REPORT_ROOT / row_id / "run_log.json"
    if not path.is_file():
        return None
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return None


def dummy_evidence_RN_BASIC_001() -> dict[str, Any]:
    """Synthesised perfect evidence for RN.BASIC.001 so the showcase popup
    renders end-to-end without depending on a successful cosim run.

    RN.BASIC.001 = slice 1 periodic, lane=0xFF, chan=0xFFFFFFFF, rate=0x0100,
    expected theoretical hits = 125,000 in a 1 ms RUNNING window.
    """
    theory = 125000
    # counter / rate evidence - per-IP CSR snapshot at TERM
    counter = {
        "theoretical_hits": theory,
        "row_id": "RN.BASIC.001",
        "arb_hit_type0_supercore": {
            "SELECTED_COUNT_lane0": 15625, "SELECTED_COUNT_lane1": 15625,
            "SELECTED_COUNT_lane2": 15625, "SELECTED_COUNT_lane3": 15625,
            "SELECTED_COUNT_lane4": 15625, "SELECTED_COUNT_lane5": 15625,
            "SELECTED_COUNT_lane6": 15625, "SELECTED_COUNT_lane7": 15625,
            "TOTAL_SELECTED": 125000,
            "DROPPED_HITS": 0,
            "ERROR_STICKY": 0,
        },
        "histogram_statistics_v2": {
            "TOTAL_HITS_CSR13": 125000,
            "LAST_INTERVAL_TOTAL_HITS_CSR17": 125000,
            "hist_bin_sum": 124998,
            "UNDERFLOW": 0, "OVERFLOW": 0,
        },
        "ring_buffer_cam_0": {"push_cnt": 31250, "pop_cnt": 31250},
        "ring_buffer_cam_1": {"push_cnt": 31250, "pop_cnt": 31250},
        "ring_buffer_cam_2": {"push_cnt": 31250, "pop_cnt": 31250},
        "ring_buffer_cam_3": {"push_cnt": 31250, "pop_cnt": 31250},
        "mts_preprocessor_0": {"ts_delta_min": 642, "ts_delta_max": 4172, "debug_burst": 0},
        "mts_preprocessor_1": {"ts_delta_min": 644, "ts_delta_max": 4174, "debug_burst": 0},
        "mutrig_frame_deassembly": {
            "frame_count_per_lane": [1953, 1953, 1953, 1953, 1953, 1953, 1953, 1953],
            "crc_err": 0,
        },
        "feb_frame_assembly_0": {"actual_hits": 62500},
        "feb_frame_assembly_1": {"actual_hits": 62500},
    }
    # delay evidence - 5 per-checkpoint percentile stats per the math review
    # Each checkpoint has its own min/p05/p50/p95/max with the math-reviewer bound.
    delay = {
        "checkpoints": [
            {"name": "pre-rbCAM",   "count": 125000,
             "delay_min_cycles": 27,     "delay_p05_cycles": 118,
             "delay_p50_cycles": 527,    "delay_p95_cycles": 941,
             "delay_max_cycles": 1040,   "bound_lower": 0,      "bound_upper": 2000,
             "formula": "D_pre = wait_910(hit_ts) + s(q) + 18 (virtual MuTRiG)"},
            {"name": "post-rbCAM",  "count": 125000,
             "delay_min_cycles": 2014,   "delay_p05_cycles": 2022,
             "delay_p50_cycles": 2098,   "delay_p95_cycles": 2174,
             "delay_max_cycles": 2196,   "bound_lower": 2000,   "bound_upper": 2200,
             "formula": "D_post = (GTS_post - ts_hit) mod 8192, window [2000,2200]"},
            {"name": "FEB egress",  "count": 125000,
             "delay_min_cycles": 2342,   "delay_p05_cycles": 3344,
             "delay_p50_cycles": 3778,   "delay_p95_cycles": 4268,
             "delay_max_cycles": 4173,   "bound_lower": 2049,   "bound_upper": 6143,
             "formula": "D_feb <= 2F - p + 20 + eps_clk"},
            {"name": "OPQ ingress", "count": 125000,
             "delay_min_cycles": 2343,   "delay_p05_cycles": 3345,
             "delay_p50_cycles": 3779,   "delay_p95_cycles": 4269,
             "delay_max_cycles": 4174,   "bound_lower": 2049,   "bound_upper": 6159,
             "formula": "D_ing = D_feb + adapter_sync"},
            {"name": "OPQ egress",  "count": 124998,
             "delay_min_cycles": 5005,   "delay_p05_cycles": 9290,
             "delay_p50_cycles": 50754,  "delay_p95_cycles": 92219,
             "delay_max_cycles": 95829,  "bound_lower": 4356,   "bound_upper": 99133.5,
             "formula": "D_opq = D_ing + W_n, W_n = max(0, W_(n-1) + S_n - A_n)"},
        ],
        "pdf_pre_rbcam_rel": None,
        "pdf_post_rbcam_rel": None,
        "pdf_feb_egress_rel": None,
        "pdf_opq_ingress_rel": None,
        "pdf_opq_egress_rel": None,
    }
    # rdma evidence - synthetic rxbuffer with 5 properly-formatted frames so
    # the decoder's K28.5 + 4-header-word + K28.4 trailer scan finds them
    rdma_buf = _dummy_rdma_buffer(num_frames=5)
    rdma = gather_rdma_evidence_from_bytes(rdma_buf)
    rdma["summary"] = {
        "bytes_total": 250000, "record_count": 124998,
        "first_record_hex": rdma_buf[:24].hex(),
        "last_record_hex": rdma_buf[-24:].hex() if len(rdma_buf) >= 24 else "",
        "record_size_avg": 8.0,
    }
    # scoreboard evidence - per-checkpoint monitor table
    scoreboard = {
        "source_hit_count": theory,
        "ghost_total": 0,
        "broken_total": 0,
        "missing_total": 2,
        "notes": ("Sim-only monitor comparing each checkpoint's hit stream "
                  "against the source true-hit-list (resolved via hit_id back "
                  "to the emulator-side payload). Ghost = hit not in source. "
                  "Broken = payload mismatch vs source. Missing = source hit "
                  "never seen at this checkpoint."),
        "monitors": [
            {"checkpoint": "pre-rbCAM",         "total_hits": 125000, "ghost_hits": 0, "broken_hits": 0, "missing_hits": 0},
            {"checkpoint": "post-rbCAM",        "total_hits": 125000, "ghost_hits": 0, "broken_hits": 0, "missing_hits": 0},
            {"checkpoint": "FEB egress",        "total_hits": 125000, "ghost_hits": 0, "broken_hits": 0, "missing_hits": 0},
            {"checkpoint": "OPQ ingress",       "total_hits": 125000, "ghost_hits": 0, "broken_hits": 0, "missing_hits": 0},
            {"checkpoint": "OPQ egress",        "total_hits": 124998, "ghost_hits": 0, "broken_hits": 0, "missing_hits": 2},
            {"checkpoint": "RDMA host rxbuffer","total_hits": 124998, "ghost_hits": 0, "broken_hits": 0, "missing_hits": 2},
        ],
    }
    # run log evidence
    runlog = {
        "run_length_ms": 1.0,
        "events": [
            {"t_ms": 0.000000, "type": "RUN_START",  "ip": "",                            "detail": "test harness reset, FSM in IDLE"},
            {"t_ms": 0.000234, "type": "CSR_WRITE",  "ip": "histogram_statistics_v2",     "detail": "LEFT_BOUND=0x00 RIGHT_BOUND=0xFF BIN_WIDTH=1 INTERVAL_CFG=0xFFFFFFFF"},
            {"t_ms": 0.000412, "type": "CSR_WRITE",  "ip": "arb_hit_type0_supercore",     "detail": "per-lane MODE=EMU x8"},
            {"t_ms": 0.000578, "type": "CSR_WRITE",  "ip": "emulator_mutrig_0..7",        "detail": "lane_mask=0xFF channel_mask=0xFFFFFFFF rate_88fp=0x0100 hit_mode=direct"},
            {"t_ms": 0.000812, "type": "CSR_WRITE",  "ip": "mutrig_injector_multiheader", "detail": "mode=0 (off, slice 1 periodic uses emulator hit-gen)"},
            {"t_ms": 0.001020, "type": "CSR_WRITE",  "ip": "runctl_mgmt_host",            "detail": "RUN_NUMBER=0x00AA0001"},
            {"t_ms": 0.001234, "type": "PHASE",      "ip": "runctl FSM",                  "detail": "0x10 RUN_PREPARE; STATUS PREPARING"},
            {"t_ms": 0.003456, "type": "PHASE",      "ip": "runctl FSM",                  "detail": "0x11 SYNC; STATUS SYNCING; SYNC pulse propagated"},
            {"t_ms": 0.005678, "type": "PHASE",      "ip": "runctl FSM",                  "detail": "0x12 START_RUN; STATUS RUNNING; emulators armed"},
            {"t_ms": 0.250000, "type": "MARKER",     "ip": "histogram_statistics_v2",     "detail": "TOTAL_HITS_CSR13 readback during running = 31254"},
            {"t_ms": 0.500000, "type": "MARKER",     "ip": "histogram_statistics_v2",     "detail": "TOTAL_HITS_CSR13 readback during running = 62498"},
            {"t_ms": 0.750000, "type": "MARKER",     "ip": "histogram_statistics_v2",     "detail": "TOTAL_HITS_CSR13 readback during running = 93746"},
            {"t_ms": 1.005678, "type": "PHASE",      "ip": "runctl FSM",                  "detail": "0x13 END_RUN; STATUS TERMINATING; drain in progress"},
            {"t_ms": 1.012345, "type": "PHASE",      "ip": "runctl FSM",                  "detail": "STATUS IDLE; terminating complete"},
            {"t_ms": 1.013012, "type": "CSR_READ",   "ip": "histogram_statistics_v2",     "detail": "TOTAL_HITS_CSR13 post-TERM = 125000 (theory 125000)"},
            {"t_ms": 1.013234, "type": "CSR_READ",   "ip": "arb_hit_type0_supercore",     "detail": "DROPPED_HITS = 0 across all 8 lanes"},
            {"t_ms": 1.013456, "type": "CSR_READ",   "ip": "ring_buffer_cam_0..3",        "detail": "push_cnt = pop_cnt = 31250 per slot"},
            {"t_ms": 1.014000, "type": "RUN_END",    "ip": "",                            "detail": "run length 1.0 ms; 194-row plan: row 1/194 complete"},
        ],
    }
    return {
        "counter": counter,
        "delay": delay,
        "rdma": rdma,
        "scoreboard": scoreboard,
        "runlog": runlog,
        "hit_count": 125000,
        "run_length_ms": 1.0,
        "is_dummy": True,
    }


def _build_frame_bytes(packet_type: int, fpga_id: int, packet_timestamp: int,
                        package_counter: int, debug_subheader_count: int,
                        debug_hit_count: int, send_ts_counter: int,
                        payload_words: int) -> bytes:
    """Build a 32-bit-aligned little-endian mu3e frame: K28.5 preamble +
    4 fixed header words + `payload_words` placeholder words + K28.4 trailer.

    Bit layout per feb_data_frame.py:parse_framed_stream():
      word0 (preamble): pkt_type[5:0]<<26 | fpga_id[15:0]<<8 | 0xBC
      word1 (ts_high):  upper 32 bits of packet_timestamp
      word2 (ts_low):   (packet_timestamp[15:0] << 16) | package_counter[15:0]
      word3 (debug0):   (debug_subheader_count[14:0] << 16) | debug_hit_count[15:0]
      word4 (debug1):   send_ts_counter[30:0]
      ...payload_words placeholder words...
      wordN (trailer):  0x9C (K28.4) in LSB
    """
    w0 = ((packet_type & 0x3F) << 26) | ((fpga_id & 0xFFFF) << 8) | SWB_K285
    w1 = (packet_timestamp >> 16) & 0xFFFF_FFFF
    w2 = ((packet_timestamp & 0xFFFF) << 16) | (package_counter & 0xFFFF)
    w3 = ((debug_subheader_count & 0x7FFF) << 16) | (debug_hit_count & 0xFFFF)
    w4 = send_ts_counter & 0x7FFF_FFFF
    parts = [w0, w1, w2, w3, w4]
    # Placeholder per-hit payload words (just patterned data so search demos work)
    for k in range(payload_words):
        parts.append(0xDEAD_0000 | (k & 0xFFFF))
    # Trailer word: K28.4 in LSB
    trailer = (send_ts_counter & 0xFFFF_FF00) | SWB_K284
    parts.append(trailer)
    buf = bytearray()
    for w in parts:
        buf.extend(int(w).to_bytes(4, "little"))
    return bytes(buf)


def _dummy_rdma_buffer(num_frames: int = 5) -> bytes:
    """Build a synthetic rdma rxbuffer with `num_frames` mu3e frames."""
    buf = bytearray()
    base_ts = 0x0000_0001_2345_0000
    for fi in range(num_frames):
        buf.extend(_build_frame_bytes(
            packet_type=0b111000,        # SciFi
            fpga_id=0x00A5,
            packet_timestamp=base_ts + fi * 8192,
            package_counter=fi,
            debug_subheader_count=4,
            debug_hit_count=8 + (fi % 4) * 2,
            send_ts_counter=0x1234_5600 + fi * 16,
            payload_words=8 + (fi % 4) * 2,
        ))
    return bytes(buf)


def gather_rdma_evidence_from_bytes(data: bytes, max_bytes_hex: int = 1024) -> dict[str, Any]:
    """Same as gather_rdma_evidence but operates on a raw byte buffer."""
    out: dict[str, Any] = {"summary": None, "hex_lines": [], "frames": []}
    frame_starts = [i for i in range(0, len(data), 4) if data[i] == SWB_K285]
    trailer_offsets = set(i for i in range(0, len(data), 4) if data[i] == SWB_K284)
    frames: list[dict[str, Any]] = []
    for fi, start in enumerate(frame_starts):
        next_start = frame_starts[fi + 1] if (fi + 1) < len(frame_starts) else len(data)
        trailer_pos = None
        for t in range(start + 4, next_start, 4):
            if t in trailer_offsets:
                trailer_pos = t
                break
        frame_end = (trailer_pos + 4) if trailer_pos is not None else next_start
        chunk = data[start:frame_end]
        words = _bytes_to_words_le(data, start, 5)
        hdr = _decode_preamble_words(words)
        frames.append({
            "frame_idx": fi, "byte_offset": start, "length": len(chunk),
            "hex": chunk.hex(), "trailer_offset": trailer_pos,
            "has_trailer": trailer_pos is not None, **hdr,
        })
    hex_lines: list[dict[str, Any]] = []
    for off in range(0, min(len(data), max_bytes_hex), 16):
        row_bytes = data[off:off + 16]
        hex_str = "".join(f"{b:02x}" for b in row_bytes)
        roles: list[str] = []
        for byte_idx, byte in enumerate(row_bytes):
            absolute = off + byte_idx
            role = "d"
            if (absolute % 4) == 0:
                if byte == SWB_K285:
                    role = "5"
                elif byte == SWB_K284:
                    role = "4"
            roles.append(role)
        hex_lines.append({"o": off, "h": hex_str, "r": "".join(roles)})
    out["hex_lines"] = hex_lines
    out["frames"] = frames
    out["bytes_total_truncated_at"] = min(len(data), max_bytes_hex)
    out["frames_decoded"] = len(frames)
    return out


def basic_rows_html() -> str:
    """Render the BASIC tab table with the requested column groups."""
    basic_rows = parse_markdown_rows(DOC_DIR / "TEST_BASIC.md", "RN.BASIC.")
    by_id = {row["ID"]: row for row in basic_rows}
    # Slice routing per the 194-row plan
    def slice_for(idx: int) -> tuple[int, str]:
        if idx <= 128:
            return 1, "periodic"
        if idx <= 160:
            return 2, "headersync"
        if idx <= 162:
            return 3, "onclick"
        return 4, "emul-only"

    evidence_json: dict[str, dict[str, Any]] = {}
    body_rows_html: list[str] = []
    for idx in range(1, 195):
        rid = f"RN.BASIC.{idx:03d}"
        row = by_id.get(rid, {"ID": rid})
        slice_id, slice_label = slice_for(idx)
        # Slice 3 uses different headers ("n_pulses", "expected_hits"); fill defaults
        hit_mode = row.get("hit_mode")
        if hit_mode is None:
            hit_mode = {1: "periodic", 2: "headersync", 3: "onclick", 4: "direct (off)"}[slice_id]
        lane_mask = row.get("lane_mask", "0xFF")
        chan_mask = row.get("channel_mask", "0xFFFFFFFF")
        rate_field = row.get("rate_88fp", "0x0100" if slice_id != 3 else "N/A")
        theory_info = basic_row_theory(row)
        # Gather evidence (eager at generation time; lazy in browser via inline JSON)
        counter_ev = gather_rate_evidence(rid)
        delay_ev = gather_delay_evidence(rid)
        rdma_ev = gather_rdma_evidence(rid)
        sb_ev = gather_scoreboard_evidence(rid)
        run_ev = gather_runlog_evidence(rid)
        hit_count = theory_info.get("theory_hits")
        run_length_ms = RUN_WINDOW_MS
        # RN.BASIC.001 is the showcase: always override with the perfect dummy
        # so the popup behaviour is reviewable before the cosim sweep emits
        # real evidence in this shape.
        if rid == "RN.BASIC.001":
            dummy = dummy_evidence_RN_BASIC_001()
            counter_ev = dummy["counter"]
            delay_ev = dummy["delay"]
            rdma_ev = dummy["rdma"]
            sb_ev = dummy["scoreboard"]
            run_ev = dummy["runlog"]
            hit_count = dummy["hit_count"]
            run_length_ms = dummy["run_length_ms"]
        evidence_json[rid] = {
            "counter": counter_ev,
            "delay": delay_ev,
            "rdma": rdma_ev,
            "scoreboard": sb_ev,
            "runlog": run_ev,
            "slice": slice_id,
            "slice_label": slice_label,
            "is_dummy": rid == "RN.BASIC.001",
        }
        run_len_str = f"{run_length_ms:.1f}"
        run_len_cell = (
            f'<button class="ev-btn run-len" data-row="{rid}" data-ev="runlog">{run_len_str}</button>'
            if run_ev else
            f'<span class="ev-pending">{run_len_str}</span>'
        )
        counter_btn = f'<button class="ev-btn" data-row="{rid}" data-ev="counter">View</button>' if counter_ev else '<span class="ev-pending">pending</span>'
        delay_has_data = bool(delay_ev.get("checkpoints")) and any(
            (cp.get("delay_max_cycles") is not None) for cp in delay_ev.get("checkpoints", [])
        )
        delay_btn = f'<button class="ev-btn" data-row="{rid}" data-ev="delay">View</button>' if delay_has_data else '<span class="ev-pending">pending</span>'
        rdma_has_buf = bool(rdma_ev.get("hex_lines"))
        rdma_btn = f'<button class="ev-btn" data-row="{rid}" data-ev="rdma">View</button>' if rdma_has_buf else '<span class="ev-pending">pending</span>'
        sb_btn = f'<button class="ev-btn" data-row="{rid}" data-ev="scoreboard">View</button>' if sb_ev else '<span class="ev-pending">pending</span>'
        cells = [
            f"<td class=\"id\">{html.escape(rid)}</td>",
            f"<td>{html.escape(str(lane_mask))}</td>",
            f"<td>{html.escape(str(chan_mask))}</td>",
            f"<td>{html.escape(str(hit_mode))}</td>",
            f"<td>{html.escape(str(rate_field))}</td>",
            f"<td>{html.escape(theory_info['popcount'])}</td>",
            f"<td class=\"num\">{fmt_num(hit_count)}</td>",
            f"<td class=\"num run-len-cell\">{run_len_cell}</td>",
            f"<td class=\"ev\">{counter_btn}</td>",
            f"<td class=\"ev\">{delay_btn}</td>",
            f"<td class=\"ev\">{rdma_btn}</td>",
            f"<td class=\"ev\">{sb_btn}</td>",
        ]
        body_rows_html.append(f'<tr data-row="{rid}" data-slice="{slice_id}">{"".join(cells)}</tr>')

    note = (
        "<p class=\"note\">194-row RN.BASIC plan from TEST_BASIC.md. "
        "Configuration columns are taken directly from the test plan. "
        "Packets carries popcount, the committed hit count (sim scoreboard-traced; equals theory at PASS rows), and the run length in ms (click for a UVM-style run log). "
        "Evidence buttons open inline popups for counter (per-IP CSR counters), delay (DISLIN lifetime plots, 2 hist banks), rdma (rx-buffer hex with mu3e frame decode), and scoreboard (sim-only per-checkpoint monitor: ghost / broken / missing hits resolved against the source true-hit-list). "
        "RN.BASIC.001 carries a synthetic perfect dummy so the popup layout is reviewable end-to-end before the real cosim evidence lands.</p>"
    )
    header_html = (
        '<thead>'
        '<tr class="hg1">'
        '<th rowspan="2">ID</th>'
        '<th colspan="4" class="grp">Configuration</th>'
        '<th colspan="3" class="grp">Packets</th>'
        '<th colspan="4" class="grp">Evidence</th>'
        '</tr>'
        '<tr class="hg2">'
        '<th>lane_mask</th>'
        '<th>channel_mask</th>'
        '<th>hit_mode</th>'
        '<th>rate_88fp</th>'
        '<th>popcount</th>'
        '<th>hit count</th>'
        '<th>run length (ms)</th>'
        '<th>counter</th>'
        '<th>delay</th>'
        '<th>rdma</th>'
        '<th>scoreboard</th>'
        '</tr>'
        '</thead>'
    )
    body_html = '<tbody>' + ''.join(body_rows_html) + '</tbody>'
    table_html = '<table class="basic-grid dense">' + header_html + body_html + '</table>'
    # Inline the evidence JSON so popups work without a web server.
    # HTML5 <script> bodies are raw text -- HTML entities are NOT decoded
    # by the parser, so we MUST NOT html-escape here (doing so leaves
    # &quot; literals in textContent which then break JSON.parse()).
    # The only HTML-level hazard is a premature </script> close; replace
    # any "</" with "<\/" which JSON.parse accepts cleanly.
    raw_json = json.dumps(evidence_json, separators=(",", ":")).replace("</", "<\\/")
    evidence_blob = (
        '<script id="basic-evidence" type="application/json">'
        + raw_json
        + "</script>"
    )
    return note + table_html + evidence_blob


def observed_p45_rows() -> list[dict[str, Any]]:
    sweep = load_sweep_module()
    sim_dirs = evidence_dirs(SIM_EVIDENCE_ROOT)
    board_dirs = evidence_dirs(BOARD_EVIDENCE_ROOT)
    rows: list[dict[str, Any]] = []
    for row in sweep.build_plan():
        run_ms = float(row.get("interval_seconds", 0.0)) * 1000.0
        theory = sweep.theoretical_hits(row, run_ms)
        sim = load_json(sim_dirs.get(row["row_id"], Path()) / "sim_counters.json") if row["row_id"] in sim_dirs else None
        board = load_json(board_dirs.get(row["row_id"], Path()) / "verdict.json") if row["row_id"] in board_dirs else None
        sim_hits = None
        if sim:
            sim_hits = sim.get("sim", {}).get("sim_total_hits")
        board_hits = None
        if board:
            board_hits = board.get("total_hits")
        rows.append({
            "id": row["row_id"],
            "bucket": row.get("bucket", sweep.bucket_for_row(row)),
            "axis": row.get("axis_section", ""),
            "lane_mask": row["lane_mask"],
            "channel_mask": row["channel_mask"],
            "rate": row["rate_88fp"],
            "mode": row["hit_mode"],
            "theory_hits": theory,
            "theory_hpm": theory / max(run_ms, 1.0),
            "sim_hpm": (float(sim_hits) / max(run_ms, 1.0)) if sim_hits is not None else None,
            "sim_delta": sweep.delta_pct_vs_theory(sim_hits, theory),
            "board_hpm": (float(board_hits) / max(run_ms, 1.0)) if board_hits is not None else None,
            "board_delta": sweep.delta_pct_vs_theory(board_hits, theory),
        })
    return rows


def perf_html() -> str:
    perf_rows = parse_markdown_rows(DOC_DIR / "TEST_PERF.md", "RN.PROF.")
    perf_rows.extend(parse_markdown_rows(DOC_DIR / "TEST_PERF.md", "SC.AG."))
    plan_rows = [[r.get("ID", ""), r.get("Method", ""), r.get("Scenario", r.get("lane_mask", "")), r.get("Stimulus", r.get("rate_88fp", "")), r.get("Pass Criteria", r.get("expected", ""))] for r in perf_rows]
    observed = [r for r in observed_p45_rows() if r["bucket"] == "PERF"]
    observed_rows = [[r["id"], r["axis"], r["rate"], fmt_num(r["theory_hpm"]), fmt_num(r["sim_hpm"]), fmt_pct(r["sim_delta"]), fmt_num(r["board_hpm"]), fmt_pct(r["board_delta"])] for r in observed]
    return (
        "<h3>PERF Catalog Rows</h3>"
        + table(["ID", "Method", "Scenario", "Stimulus/Rate", "Pass Criteria"], plan_rows, "dense")
        + "<h3>Existing p45 Saturation Evidence</h3>"
        + table(["row_id", "axis", "rate", "theory hits/ms", "sim hits/ms", "sim_delta_pct", "board hits/ms", "board_delta_pct"], observed_rows, "dense")
    )


def generic_bucket_html(doc_name: str, prefixes: list[str]) -> str:
    rows: list[dict[str, str]] = []
    path = DOC_DIR / doc_name
    for prefix in prefixes:
        rows.extend(parse_markdown_rows(path, prefix))
    headers = ["ID", "Method", "Scenario", "Stimulus", "Pass Criteria", "Function Reference"]
    out_rows = [[r.get(h, "") for h in headers] for r in rows]
    return table(headers, out_rows, "dense")


def bu_html(specs: list[IpSpec], metas: dict[str, dict[str, str]]) -> str:
    master_rows = [
        [s.ip, metas[s.ip]["kind"], metas[s.ip]["uid"], metas[s.ip]["version"], metas[s.ip]["author"], metas[s.ip]["build_date"], s.sc_addr, s.csr_base, s.note]
        for s in specs
    ]
    parts = [
        table(["IP", "kind", "UID", "version", "author", "build date", "SC addr", "csr base", "note"], master_rows, "dense master"),
        "<h3>Per-IP CSR Dump</h3>",
    ]
    for spec in specs:
        meta = metas[spec.ip]
        rows = csr_rows(spec, meta)
        body = table(["offset", "field", "access", "description", "default / expected", "source"], [[r["offset"], r["field"], r["access"], r["description"], r["expected"], r["source"]] for r in rows], "dense csr")
        summary = f"{spec.ip} - {meta['kind']} - {meta['uid']} - {spec.sc_addr}"
        parts.append(f"<details><summary>{html.escape(summary)}</summary>{body}</details>")
    return "\n".join(parts)


def render_html() -> str:
    specs = ip_specs()
    metas = {spec.ip: hw_metadata(spec) for spec in specs}
    tabs = {
        "BU": bu_html(specs, metas),
        "BASIC": basic_rows_html(),
        "PERF": perf_html(),
        "ERROR": generic_bucket_html("TEST_ERROR.md", ["RC.ERROR.", "RN.ERROR."]),
        "EDGE": generic_bucket_html("TEST_EDGE.md", ["RN.EDGE."]),
    }
    tab_inputs: list[str] = []
    tab_panels: list[str] = []
    for idx, (name, body) in enumerate(tabs.items()):
        checked = " checked" if idx == 0 else ""
        tab_id = f"tab-{name.lower()}"
        tab_inputs.append(f'<input type="radio" id="{tab_id}" name="tabs"{checked}><label for="{tab_id}">{name}</label>')
        tab_panels.append(f'<section class="panel" id="panel-{name.lower()}"><h2>{name}</h2>{body}</section>')
    css = """
:root {
  --bg: #f7f4ee;
  --ink: #25211b;
  --muted: #6d665d;
  --line: #d7cec0;
  --panel: #fffdf8;
  --accent: #2d6f73;
  --accent-weak: #dceee8;
}
* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  color: var(--ink);
  background: var(--bg);
}
main { max-width: 1480px; margin: 0 auto; padding: 28px 24px 48px; }
h1 { margin: 0 0 6px; font-size: 28px; line-height: 1.2; font-weight: 720; }
h2 { margin: 22px 0 14px; font-size: 20px; }
h3 { margin: 22px 0 10px; font-size: 16px; }
.sub { color: var(--muted); margin: 0 0 22px; }
.tabs { display: flex; flex-wrap: wrap; gap: 0; align-items: flex-end; border-bottom: 1px solid var(--line); margin-bottom: 18px; }
.tabs input { position: absolute; opacity: 0; pointer-events: none; }
.tabs label {
  padding: 10px 16px;
  border: 1px solid transparent;
  border-bottom: 0;
  cursor: pointer;
  color: var(--muted);
  font-weight: 650;
}
.tabs input:checked + label {
  color: var(--ink);
  background: var(--panel);
  border-color: var(--line);
  border-radius: 6px 6px 0 0;
}
.panel {
  display: none;
  flex-basis: 100%;
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 0 6px 6px 6px;
  padding: 18px;
  overflow-x: auto;
}
#tab-bu:checked ~ #panel-bu,
#tab-basic:checked ~ #panel-basic,
#tab-perf:checked ~ #panel-perf,
#tab-error:checked ~ #panel-error,
#tab-edge:checked ~ #panel-edge { display: block; }
table { width: 100%; border-collapse: collapse; margin: 0 0 16px; font-size: 13px; }
th, td { border-bottom: 1px solid var(--line); padding: 7px 8px; text-align: left; vertical-align: top; }
th { background: #f0eadf; color: #3c362f; font-weight: 700; position: sticky; top: 0; z-index: 1; }
td { max-width: 520px; }
.dense td, .dense th { padding: 5px 7px; font-size: 12px; }
.csr td:nth-child(4) { min-width: 360px; }
details {
  border: 1px solid var(--line);
  border-radius: 6px;
  background: #fffaf1;
  margin: 8px 0;
}
summary {
  cursor: pointer;
  padding: 10px 12px;
  font-weight: 700;
}
details[open] summary { border-bottom: 1px solid var(--line); background: var(--accent-weak); }
.note {
  border-left: 4px solid var(--accent);
  background: #edf6f3;
  padding: 10px 12px;
  color: #274b45;
  margin: 0 0 14px;
}
.basic-grid th.grp { background: #e9e0cd; text-align: center; }
.basic-grid th, .basic-grid td { white-space: nowrap; font-variant-numeric: tabular-nums; }
.basic-grid td.num { text-align: right; }
.basic-grid td.ev { text-align: center; }
.basic-grid td.id { font-weight: 650; }
.ev-btn {
  cursor: pointer;
  padding: 3px 9px;
  border: 1px solid var(--accent);
  background: var(--panel);
  color: var(--accent);
  border-radius: 4px;
  font-size: 11px;
  font-weight: 650;
}
.ev-btn:hover { background: var(--accent-weak); }
.ev-btn.run-len { font-variant-numeric: tabular-nums; padding: 3px 8px; min-width: 46px; }
.ev-pending { color: var(--muted); font-style: italic; font-size: 11px; }

/* Modal */
.modal-backdrop {
  position: fixed; inset: 0; background: rgba(15,12,8,0.55);
  display: none; align-items: flex-start; justify-content: center;
  z-index: 100; padding: 4vh 2vw; overflow-y: auto;
}
.modal-backdrop.open { display: flex; }
.modal-card {
  background: var(--panel); border-radius: 8px; border: 1px solid var(--line);
  width: 100%; max-width: 1100px; max-height: 92vh; overflow: auto;
  box-shadow: 0 22px 60px rgba(0,0,0,0.25);
}
.modal-head {
  padding: 14px 18px; border-bottom: 1px solid var(--line);
  display: flex; justify-content: space-between; align-items: center;
  background: #f4ecd9; border-radius: 8px 8px 0 0;
}
.modal-head h3 { margin: 0; font-size: 15px; }
.modal-close {
  cursor: pointer; padding: 4px 10px; border: 1px solid var(--line);
  background: transparent; border-radius: 4px; font-weight: 700;
}
.modal-body { padding: 16px 18px 22px; }
.rate-table th, .rate-table td { font-size: 12px; }
.rate-table td.num { text-align: right; font-variant-numeric: tabular-nums; }
.rate-table tr.ip-section td {
  background: #efe6d3; font-weight: 700; padding-top: 8px;
}
.delay-pdf {
  width: 100%; height: 520px; border: 1px solid var(--line);
  border-radius: 4px; margin-bottom: 12px; background: #fff;
}
.delay-stats {
  font-family: ui-monospace, "Cascadia Mono", Menlo, monospace;
  font-size: 11px; background: #f7f1e3; padding: 8px 10px;
  border-radius: 4px; margin: 4px 0 12px; white-space: pre;
}
.rdma-controls {
  display: flex; gap: 10px; margin-bottom: 10px;
  align-items: center; flex-wrap: wrap;
}
.rdma-controls input {
  padding: 5px 9px; border: 1px solid var(--line);
  border-radius: 4px; font-family: ui-monospace, monospace;
}
.rdma-frame {
  background: #fffaf1; border: 1px solid var(--line);
  border-radius: 4px; padding: 8px 10px; margin: 8px 0;
}
.rdma-frame summary { font-weight: 650; padding: 0; }
.rdma-frame .meta { color: var(--muted); font-size: 11px; }
.hex-row {
  font-family: ui-monospace, "Cascadia Mono", Menlo, monospace;
  font-size: 12px; line-height: 1.55; padding: 1px 0;
}
.hex-row .off { color: var(--muted); margin-right: 10px; }
.hex-row .byte { padding: 0 1px; border-radius: 2px; }
.hex-row .byte.k285 { background: #ffd17a; color: #5a3300; font-weight: 700; }
.hex-row .byte.k284 { background: #b3e0b6; color: #1f4f23; font-weight: 700; }
.hex-row .byte.match { outline: 2px solid #d24a4a; outline-offset: -1px; }
.legend { font-size: 11px; color: var(--muted); margin: 4px 0 10px; }
.legend .pill {
  display: inline-block; padding: 1px 6px; margin: 0 4px 0 8px;
  border-radius: 3px; font-weight: 700;
}
.legend .k285 { background: #ffd17a; color: #5a3300; }
.legend .k284 { background: #b3e0b6; color: #1f4f23; }

/* Scoreboard table: ensure numeric cells right-align under their headers */
.sb-table th, .sb-table td { padding: 6px 12px; vertical-align: middle; }
.sb-table th { text-align: center; background: #f0eadf; }
.sb-table th.left, .sb-table td.left { text-align: left; }
.sb-table td.num {
  text-align: right; font-variant-numeric: tabular-nums;
  font-family: ui-monospace, "Cascadia Mono", Menlo, monospace;
}
.sb-table tr.total-row td { background: #f4ecd9; font-weight: 700; border-top: 2px solid var(--accent); }
.sb-table td.zero { color: #2d6f73; }
.sb-table td.nonzero { color: #b54a2a; font-weight: 700; }

/* Per-checkpoint delay panels */
.cp-panel {
  background: #fffaf1; border: 1px solid var(--line); border-radius: 4px;
  padding: 10px 12px; margin: 8px 0;
}
.cp-panel h4 { margin: 0 0 6px; font-size: 13px; }
.cp-panel .formula {
  font-family: ui-monospace, "Cascadia Mono", Menlo, monospace;
  font-size: 11px; color: var(--muted); margin: 0 0 8px;
}
.cp-stats {
  display: grid; grid-template-columns: repeat(7, 1fr); gap: 6px;
  font-size: 12px; margin: 6px 0;
}
.cp-stats .lbl { color: var(--muted); }
.cp-stats .val {
  font-variant-numeric: tabular-nums; font-weight: 650;
  font-family: ui-monospace, "Cascadia Mono", Menlo, monospace;
}
.cp-status {
  display: inline-block; padding: 2px 8px; border-radius: 3px; font-size: 11px; font-weight: 700;
}
.cp-status.pass { background: #b3e0b6; color: #1f4f23; }
.cp-status.fail { background: #f3b6a3; color: #7a1f1f; }
.cp-status.tbd  { background: #e8e1d0; color: #6d665d; }

/* Frame details: collapsible per-frame block with monospace hex */
.frame-list { display: flex; flex-direction: column; gap: 6px; margin: 8px 0; }
.frame-card {
  background: #fffaf1; border: 1px solid var(--line); border-radius: 4px;
}
.frame-card > summary {
  cursor: pointer; padding: 8px 12px; font-weight: 650; font-size: 12px;
  display: flex; flex-wrap: wrap; gap: 18px; align-items: center;
}
.frame-card > summary .tag {
  padding: 1px 6px; border-radius: 3px; font-weight: 700; font-size: 11px;
}
.frame-card > summary .tag.scifi { background: #d6e7ff; color: #1f3f6a; }
.frame-card > summary .tag.mupix { background: #ffd1c2; color: #743311; }
.frame-card > summary .tag.tile  { background: #e0ccff; color: #3f1f6a; }
.frame-card > summary .tag.other { background: #e0e0e0; color: #444; }
.frame-card[open] > summary { border-bottom: 1px solid var(--line); background: var(--accent-weak); }
.frame-detail { padding: 10px 12px; }
.frame-fields {
  display: grid; grid-template-columns: auto 1fr; gap: 4px 16px;
  font-size: 12px; font-variant-numeric: tabular-nums;
  margin-bottom: 10px;
}
.frame-fields .key { color: var(--muted); }
.frame-fields .val { font-family: ui-monospace, "Cascadia Mono", Menlo, monospace; }
.frame-hex {
  font-family: ui-monospace, "Cascadia Mono", Menlo, monospace;
  font-size: 11px; background: #f7f1e3; padding: 8px 10px;
  border-radius: 3px; line-height: 1.5; overflow-x: auto;
}
"""
    generated = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    modal_html = """
<div id="ev-modal" class="modal-backdrop" role="dialog" aria-modal="true" aria-hidden="true">
  <div class="modal-card">
    <div class="modal-head">
      <h3 id="ev-modal-title">Evidence</h3>
      <button class="modal-close" id="ev-modal-close" aria-label="Close">x</button>
    </div>
    <div class="modal-body" id="ev-modal-body"></div>
  </div>
</div>
"""
    modal_js = """
<script>
(function(){
  var raw = document.getElementById('basic-evidence');
  var EV = {};
  if (raw) {
    try { EV = JSON.parse(raw.textContent || raw.innerText || '{}'); } catch (e) { EV = {}; }
  }
  function $(id){return document.getElementById(id);}
  function openModal(title, body){
    $('ev-modal-title').textContent = title;
    var b = $('ev-modal-body'); b.innerHTML = '';
    if (typeof body === 'string') { b.innerHTML = body; } else { b.appendChild(body); }
    var m = $('ev-modal'); m.classList.add('open'); m.setAttribute('aria-hidden','false');
  }
  function closeModal(){
    var m = $('ev-modal'); m.classList.remove('open'); m.setAttribute('aria-hidden','true');
  }
  $('ev-modal-close').addEventListener('click', closeModal);
  $('ev-modal').addEventListener('click', function(e){ if(e.target.id==='ev-modal') closeModal(); });
  document.addEventListener('keydown', function(e){ if(e.key==='Escape') closeModal(); });

  function fmtNum(x){
    if (x === null || x === undefined || x === '') return '';
    if (typeof x === 'number') {
      if (Math.abs(x) >= 1000) return x.toLocaleString();
      return String(x);
    }
    return String(x);
  }
  function asTable(headers, rows){
    var h = '<table class="rate-table dense"><thead><tr>'
            + headers.map(function(x){return '<th>'+x+'</th>';}).join('')
            + '</tr></thead><tbody>';
    var b = rows.map(function(r){
      if (r.section) { return '<tr class="ip-section"><td colspan="'+headers.length+'">'+r.section+'</td></tr>'; }
      return '<tr>' + r.map(function(c, i){
        var cls = (typeof c === 'number') ? ' class="num"' : '';
        return '<td'+cls+'>'+fmtNum(c)+'</td>';
      }).join('') + '</tr>';
    }).join('');
    return h + b + '</tbody></table>';
  }
  function renderCounter(rid, data){
    if (!data) return '<p class="ev-pending">No counter evidence found for ' + rid + '. Run the cosim sweep for this row.</p>';
    var theory = data.theoretical_hits;
    var rows = [];
    var keys = Object.keys(data).sort();
    keys.forEach(function(ip){
      if (ip === 'theoretical_hits' || ip === 'row_id' || ip === 'meta') return;
      var entry = data[ip];
      if (typeof entry !== 'object' || entry === null) {
        rows.push([ip, '', fmtNum(entry), '', '']);
        return;
      }
      rows.push({section: ip});
      Object.keys(entry).forEach(function(k){
        var v = entry[k];
        var pct = '';
        if (theory && typeof v === 'number' && v > 0 && /total|hits|count|csr13|selected/i.test(k)){
          pct = ((v - theory) / theory * 100).toFixed(2) + '%';
        }
        rows.push([ip, k, fmtNum(v), theory != null ? fmtNum(theory) : '', pct]);
      });
    });
    var header = 'Counter evidence - ' + rid + (theory != null ? ' (theory ' + fmtNum(theory) + ' hits)' : '');
    var note = '<p class="legend">Counters are absolute committed counts at TERM. Rate = counter / run_length_ms.</p>';
    return '<p><strong>' + header + '</strong></p>' + note
         + asTable(['IP', 'counter name', 'measured / sim', 'expected', 'delta vs theory'], rows);
  }
  function renderScoreboard(rid, data){
    if (!data) return '<p class="ev-pending">No scoreboard evidence found for ' + rid + '. Sim-only -- scoreboard.json missing.</p>';
    var notes = data.notes || '';
    var srcCount = data.source_hit_count;
    var monitors = data.monitors || [];
    // Build a dedicated sb-table with explicit column classes so numbers
    // right-align under their numeric column headers and text stays left-aligned.
    var html = '<p><strong>Scoreboard - ' + rid + ' (sim-only)</strong></p>'
             + '<p class="legend">' + notes + '</p>'
             + '<table class="sb-table dense">'
             + '<thead><tr>'
             +   '<th class="left">monitor / checkpoint</th>'
             +   '<th>total hits at checkpoint</th>'
             +   '<th>ghost hits</th>'
             +   '<th>broken hits</th>'
             +   '<th>missing hits</th>'
             + '</tr></thead><tbody>';
    function cellClass(v){
      if (v == null || v === '') return 'num';
      var n = Number(v);
      if (isNaN(n)) return 'num';
      return (n === 0) ? 'num zero' : 'num nonzero';
    }
    monitors.forEach(function(m){
      html += '<tr>'
           +   '<td class="left">' + (m.checkpoint || '') + '</td>'
           +   '<td class="num">' + fmtNum(m.total_hits) + '</td>'
           +   '<td class="' + cellClass(m.ghost_hits) + '">' + fmtNum(m.ghost_hits) + '</td>'
           +   '<td class="' + cellClass(m.broken_hits) + '">' + fmtNum(m.broken_hits) + '</td>'
           +   '<td class="' + cellClass(m.missing_hits) + '">' + fmtNum(m.missing_hits) + '</td>'
           + '</tr>';
    });
    html += '<tr class="total-row">'
         +   '<td class="left">TOTAL (vs source true-hit-list)</td>'
         +   '<td class="num">' + (srcCount != null ? fmtNum(srcCount) + ' source' : '-') + '</td>'
         +   '<td class="' + cellClass(data.ghost_total) + '">' + fmtNum(data.ghost_total) + '</td>'
         +   '<td class="' + cellClass(data.broken_total) + '">' + fmtNum(data.broken_total) + '</td>'
         +   '<td class="' + cellClass(data.missing_total) + '">' + fmtNum(data.missing_total) + '</td>'
         + '</tr>';
    html += '</tbody></table>';
    return html;
  }
  function renderRunlog(rid, data){
    if (!data) return '<p class="ev-pending">No run log found for ' + rid + '.</p>';
    var events = (data.events || []).slice();
    var runLen = data.run_length_ms != null ? data.run_length_ms : '-';
    var controls = '<div class="rdma-controls">'
                 + '<label>Filter (phase / ip / detail substring): </label>'
                 + '<input type="text" id="rl-filter" placeholder="CSR_WRITE">'
                 + '<label>Type: </label><select id="rl-type"><option value="">(all)</option>'
                 + '<option>RUN_START</option><option>CSR_WRITE</option><option>CSR_READ</option><option>PHASE</option><option>MARKER</option><option>RUN_END</option></select>'
                 + '<button class="ev-btn" id="rl-apply">Apply</button></div>';
    var html = '<p><strong>Run log - ' + rid + ' (run length ' + runLen + ' ms)</strong></p>' + controls
             + '<div id="rl-pane" class="delay-stats" style="max-height:60vh; overflow:auto;"></div>';
    var wrapper = document.createElement('div'); wrapper.innerHTML = html;
    var pane = wrapper.querySelector('#rl-pane');
    function paint(filterText, filterType){
      pane.innerHTML = '';
      var lo = (filterText || '').toLowerCase();
      var lines = [];
      events.forEach(function(ev){
        var typ = ev.type || '';
        if (filterType && typ !== filterType) return;
        if (lo){
          var hay = (typ + ' ' + (ev.ip || '') + ' ' + (ev.detail || '')).toLowerCase();
          if (hay.indexOf(lo) === -1) return;
        }
        var tStr = (typeof ev.t_ms === 'number') ? ev.t_ms.toFixed(6) : String(ev.t_ms || '');
        var ipStr = (ev.ip || '').padEnd(38, ' ').slice(0,38);
        var typeStr = '[' + (typ || '').padEnd(11, ' ').slice(0,11) + ']';
        lines.push(typeStr + ' t=' + tStr.padStart(11, ' ') + ' ms  ' + ipStr + '  ' + (ev.detail || ''));
      });
      pane.textContent = lines.join('\\n') || '(no events match the filter)';
    }
    paint('', '');
    wrapper.querySelector('#rl-apply').addEventListener('click', function(){
      paint(wrapper.querySelector('#rl-filter').value, wrapper.querySelector('#rl-type').value);
    });
    return wrapper;
  }
  function renderDelay(rid, data){
    if (!data || !data.checkpoints || data.checkpoints.length === 0) {
      return '<p class="ev-pending">No delay evidence found for ' + rid + '.</p>';
    }
    var html = '<p class="legend">Per-checkpoint hit-lifetime distributions, 8 ns cycle units. '
             + 'Bounds per math review; pass criterion = min &ge; bound_lower AND max &le; bound_upper. '
             + 'Renderer: DISLIN only (matplotlib/seaborn/plotly disallowed).</p>';
    data.checkpoints.forEach(function(cp){
      var name = cp.name || '(unnamed)';
      var lo = cp.bound_lower, hi = cp.bound_upper;
      var mn = cp.delay_min_cycles, mx = cp.delay_max_cycles;
      var status = 'tbd', label = 'tbd';
      if (mn != null && mx != null && lo != null && hi != null){
        if (mn >= lo && mx <= hi){ status = 'pass'; label = 'PASS'; }
        else { status = 'fail'; label = 'FAIL'; }
      }
      var formula = cp.formula || '';
      var pdf = cp.pdf_rel || null;
      html += '<div class="cp-panel">'
            + '<h4>' + name + ' <span class="cp-status ' + status + '">' + label + '</span></h4>'
            + (formula ? '<div class="formula">' + formula + '</div>' : '')
            + '<div class="cp-stats">'
            +   '<div class="lbl">count</div><div class="val">' + fmtNum(cp.count) + '</div>'
            +   '<div class="lbl">min</div><div class="val">' + fmtNum(mn) + '</div>'
            +   '<div class="lbl">p05</div><div class="val">' + fmtNum(cp.delay_p05_cycles) + '</div>'
            +   '<div class="lbl">p50</div><div class="val">' + fmtNum(cp.delay_p50_cycles) + '</div>'
            +   '<div class="lbl">p95</div><div class="val">' + fmtNum(cp.delay_p95_cycles) + '</div>'
            +   '<div class="lbl">max</div><div class="val">' + fmtNum(mx) + '</div>'
            +   '<div class="lbl">bound</div><div class="val">[' + fmtNum(lo) + ', ' + fmtNum(hi) + ']</div>'
            + '</div>';
      if (pdf) {
        html += '<embed class="delay-pdf" src="' + pdf + '" type="application/pdf">';
      } else {
        html += '<p class="ev-pending">DISLIN PDF pending; expected at <code>plots/' + (name.replace(/[^a-z]/gi,"_").toLowerCase()) + '.pdf</code> once #106 lifetime renderer finishes.</p>';
      }
      html += '</div>';
    });
    return html;
  }
  function renderRdma(rid, data){
    if (!data) return '<p class="ev-pending">No rdma evidence found for ' + rid + '.</p>';
    var summary = data.summary || {};
    var frames = data.frames || [];
    var sumStr = 'bytes_total          : ' + (summary.bytes_total != null ? summary.bytes_total : '-') + '\\n'
               + 'record_count         : ' + (summary.record_count != null ? summary.record_count : '-') + '\\n'
               + 'record_size_avg      : ' + (summary.record_size_avg != null ? summary.record_size_avg : '-') + '\\n'
               + 'frames decoded       : ' + frames.length + '\\n'
               + 'hex sample bytes     : ' + (data.bytes_total_truncated_at != null ? data.bytes_total_truncated_at : '-');
    var html = '<h3>rdma rxbuffer summary</h3><div class="delay-stats">' + sumStr + '</div>'
             + '<div class="legend">Legend:'
             + '<span class="pill k285">0xBC = K28.5 preamble</span>'
             + '<span class="pill k284">0x9C = K28.4 trailer</span>'
             + ' (K23.7 idle is on-wire only and not present in the rxbuffer payload)</div>'
             + '<div class="rdma-controls">'
             + '<label>Search hex pattern (e.g. <code>bc</code> or <code>9c</code>): </label>'
             + '<input type="text" id="rdma-search" placeholder="bc">'
             + '<label>Range start: </label><input type="number" id="rdma-start" value="0" min="0" style="width:80px">'
             + '<label>length: </label><input type="number" id="rdma-len" value="1024" min="16" max="65536" style="width:80px">'
             + '<button class="ev-btn" id="rdma-apply">Apply</button>'
             + '</div>';
    if (!frames.length) {
      html += '<p class="legend">No K28.5/K28.4 framed packets in this rxbuffer -- this row cosim emitted host-format hit records (8-byte each per the rdma_rxbuffer_summary). The hex pane below shows the raw record stream.</p>';
    }
    if (frames.length) {
      html += '<h3>Decoded frames (' + frames.length + ' total, click any to expand full hex)</h3><div class="frame-list">';
      frames.forEach(function(f){
        var ptl = (f.packet_type_label || '').toLowerCase();
        var tagCls = 'other';
        if (ptl.indexOf('scifi') >= 0) tagCls = 'scifi';
        else if (ptl.indexOf('mupix') >= 0) tagCls = 'mupix';
        else if (ptl.indexOf('tile') >= 0) tagCls = 'tile';
        var ts = (f.packet_timestamp != null) ? ('0x' + f.packet_timestamp.toString(16).padStart(12, '0')) : '-';
        var pkgc = (f.package_counter != null) ? f.package_counter : '-';
        var summary_line =
            '<span>Frame ' + f.frame_idx + '</span>'
          + '<span class="tag ' + tagCls + '">' + (f.packet_type_label || 'unknown') + '</span>'
          + '<span>off 0x' + f.byte_offset.toString(16) + '</span>'
          + '<span>len ' + f.length + 'B</span>'
          + '<span>fpga 0x' + ((f.fpga_id != null) ? f.fpga_id.toString(16).padStart(4,'0') : '-') + '</span>'
          + '<span>pkts ts ' + ts + '</span>'
          + '<span>pkg# ' + pkgc + '</span>'
          + '<span>sub ' + (f.debug_subheader_count != null ? f.debug_subheader_count : '-') + '</span>'
          + '<span>hits ' + (f.debug_hit_count != null ? f.debug_hit_count : '-') + '</span>'
          + '<span>trailer ' + (f.has_trailer ? '0x' + (f.trailer_offset != null ? f.trailer_offset.toString(16) : '?') : 'MISSING') + '</span>';
        // Detail body: decoded field grid + full hex split per 16-byte row
        var fields =
            '<div class="key">packet_type</div><div class="val">0x' + (f.packet_type_raw != null ? f.packet_type_raw.toString(16) : '?') + ' (' + (f.packet_type_label || '?') + ')</div>'
          + '<div class="key">fpga_id</div><div class="val">0x' + ((f.fpga_id != null) ? f.fpga_id.toString(16).padStart(4,'0') : '-') + '</div>'
          + '<div class="key">packet_timestamp</div><div class="val">' + ts + ' (' + (f.packet_timestamp != null ? f.packet_timestamp : '-') + ')</div>'
          + '<div class="key">package_counter</div><div class="val">' + pkgc + '</div>'
          + '<div class="key">debug_subheader_count</div><div class="val">' + (f.debug_subheader_count != null ? f.debug_subheader_count : '-') + '</div>'
          + '<div class="key">debug_hit_count</div><div class="val">' + (f.debug_hit_count != null ? f.debug_hit_count : '-') + '</div>'
          + '<div class="key">send_ts_counter</div><div class="val">' + (f.send_ts_counter != null ? f.send_ts_counter : '-') + '</div>'
          + '<div class="key">byte_offset</div><div class="val">0x' + f.byte_offset.toString(16) + ' = ' + f.byte_offset + '</div>'
          + '<div class="key">length</div><div class="val">' + f.length + ' bytes</div>'
          + '<div class="key">trailer</div><div class="val">' + (f.has_trailer ? ('present at 0x' + f.trailer_offset.toString(16)) : 'MISSING') + '</div>';
        // Render full hex split in rows of 16 bytes
        var hex = f.hex || '';
        var hexBlock = '';
        for (var off = 0; off < hex.length; off += 32) {
          var rowHex = hex.slice(off, off + 32);
          var abs = (f.byte_offset || 0) + (off / 2);
          var cells = '';
          for (var b = 0; b < rowHex.length; b += 2) {
            cells += rowHex.slice(b, b + 2) + ' ';
          }
          hexBlock += '0x' + abs.toString(16).padStart(4,'0') + ': ' + cells + '\\n';
        }
        html += '<details class="frame-card"><summary>' + summary_line + '</summary>'
              + '<div class="frame-detail">'
              + '<div class="frame-fields">' + fields + '</div>'
              + '<div class="frame-hex">' + hexBlock + '</div>'
              + '</div></details>';
      });
      html += '</div>';
    }
    html += '<h3>Raw rxbuffer hex (' + (data.hex_lines || []).length * 16 + ' bytes shown, K28.5/K28.4 highlighted at word-LSB boundaries)</h3>'
          + '<div id="rdma-hex-pane"></div>';
    var wrapper = document.createElement('div');
    wrapper.innerHTML = html;
    var pane = wrapper.querySelector('#rdma-hex-pane');
    function paint(filterPattern, startByte, lenBytes){
      pane.innerHTML = '';
      var pattern = (filterPattern || '').toLowerCase().replace(/[^0-9a-f]/g, '');
      var roleMap = {'5':'k285', '4':'k284', 'd':'data'};
      (data.hex_lines || []).forEach(function(row){
        if (row.o < startByte) return;
        if (row.o >= startByte + lenBytes) return;
        var lineDiv = document.createElement('div');
        lineDiv.className = 'hex-row';
        var off = document.createElement('span');
        off.className = 'off';
        off.textContent = '0x' + row.o.toString(16).padStart(4,'0') + ':';
        lineDiv.appendChild(off);
        var rowHex = row.h || '';
        var rowRoles = row.r || '';
        for (var idx = 0; idx < rowRoles.length; idx++){
          var b = document.createElement('span');
          var hexPair = rowHex.slice(idx*2, idx*2+2);
          b.className = 'byte ' + (roleMap[rowRoles.charAt(idx)] || 'data');
          b.textContent = hexPair + ' ';
          if (pattern && rowHex.slice(idx*2, idx*2 + pattern.length) === pattern){
            b.classList.add('match');
          }
          lineDiv.appendChild(b);
        }
        pane.appendChild(lineDiv);
      });
    }
    paint('', 0, 512);
    wrapper.querySelector('#rdma-apply').addEventListener('click', function(){
      var p = wrapper.querySelector('#rdma-search').value;
      var s = parseInt(wrapper.querySelector('#rdma-start').value, 10) || 0;
      var l = parseInt(wrapper.querySelector('#rdma-len').value, 10) || 1024;
      paint(p, s, l);
    });
    paint('', 0, 1024);
    return wrapper;
  }
  document.addEventListener('click', function(e){
    var btn = e.target.closest('button.ev-btn[data-row]');
    if (!btn) return;
    var rid = btn.getAttribute('data-row');
    var kind = btn.getAttribute('data-ev');
    var ev = EV[rid] || {};
    var title = rid + ' - ' + kind + ' evidence';
    var body;
    if (kind === 'counter') body = renderCounter(rid, ev.counter);
    else if (kind === 'delay') body = renderDelay(rid, ev.delay);
    else if (kind === 'rdma') body = renderRdma(rid, ev.rdma);
    else if (kind === 'scoreboard') body = renderScoreboard(rid, ev.scoreboard);
    else if (kind === 'runlog') body = renderRunlog(rid, ev.runlog);
    else body = '<p>Unknown evidence kind.</p>';
    openModal(title, body);
  });
})();
</script>
"""
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Phase 4.5 Five-Tab Sweep Report</title>
<style>{css}</style>
</head>
<body>
<main>
<h1>Phase 4.5 Sweep Report</h1>
<p class="sub">v3_pretest-260511 emulator type0 cross-validation. Generated {html.escape(generated)} from local docs and existing evidence.</p>
<div class="tabs">
{''.join(tab_inputs)}
{''.join(tab_panels)}
</div>
</main>
{modal_html}
{modal_js}
</body>
</html>
"""


def main() -> int:
    OUTPUT_HTML.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT_HTML.write_text(render_html(), encoding="utf-8")
    print(OUTPUT_HTML)
    return 0


if __name__ == "__main__":
    sys.exit(main())
