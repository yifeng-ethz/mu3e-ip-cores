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


def basic_rows_html() -> str:
    basic_rows = parse_markdown_rows(DOC_DIR / "TEST_BASIC.md", "RN.BASIC.")
    by_id = {row["ID"]: row for row in basic_rows}
    rows: list[list[Any]] = []
    for idx in range(1, 129):
        rid = f"RN.BASIC.{idx:03d}"
        row = by_id.get(rid, {"ID": rid})
        theory = int_from_text(row.get("clipped_hits", row.get("theoretical_hits", "")))
        rows.append([
            rid,
            row.get("lane_mask", "0xFF"),
            row.get("channel_mask", "0xFFFFFFFF"),
            row.get("hit_mode", "direct (0)"),
            row.get("rate_88fp", "0x0100"),
            row.get("popcount L x C", ""),
            fmt_num(theory),
            fmt_num(theory),
            "pending",
            "pending",
            "pending",
            "pending",
        ])
    note = (
        "<p class=\"note\">The BASIC tab is the 128-row RN.BASIC plan from TEST_BASIC.md. "
        "Existing evidence directories are named p45_* from the prior 32-row sweep, so RN.BASIC evidence columns remain pending until that row-id stream is emitted.</p>"
    )
    return note + table(
        ["ID", "lane_mask", "channel_mask", "hit_mode", "rate_88fp", "popcount", "theory hits", "theory hits/ms", "sim hits/ms", "sim_delta_pct", "board hits/ms", "board_delta_pct"],
        rows,
        "dense",
    )


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
"""
    generated = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
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
