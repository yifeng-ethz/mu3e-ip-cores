#!/usr/bin/env python3

from __future__ import annotations

import json
import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
FIRMWARE_BUILDS_DIR = SYSTEM_DIR.parent.parent
REPO_ROOT = FIRMWARE_BUILDS_DIR.parent
SYN_DIR = SYSTEM_DIR / "syn"

EXPLICIT_SVD_MAP = {
    "altera_avalon_mm_bridge": Path("toolkits/infra/cmsis_svd/generic/mm_bridge_passthrough.svd"),
    "altera_avalon_mm_clock_crossing_bridge": Path("toolkits/infra/cmsis_svd/generic/mm_bridge_passthrough.svd"),
    "sc_hub_v2": Path("slow-control_hub/sc_hub.svd"),
    "max10_prog_avmm": Path("feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm.svd"),
    "firefly_xcvr_ctrl": Path("firefly_xcvr_i2c_master/firefly_xcvr_ctrl.svd"),
    "onewire_master_controller": Path("onewire_temp_sense/script/onewire_master_controller.svd"),
    "altera_temp_sense_ctrl": Path("alt_temp_sense_controller/altera_temp_sense_ctrl.svd"),
    "mutrig_cfg_ctrl": Path("mutrig_controller/mutrig_cfg_ctrl.svd"),
    "runctl_mgmt_host": Path("run-control_mgmt/runctl_mgmt_host.svd"),
    "mutrig_injector_multiheader": Path("charge_injection/script/mutrig_injector.svd"),
    "emulator_mutrig": Path("emulator_mutrig/emulator_mutrig.svd"),
    "dbg_mm2runctrl": Path("misc/dbg_issp_fab/dbg_mm2runctrl.svd"),
    "mutrig_lane_source_mux": Path("misc/mutrig_lane_source_mux/mutrig_lane_source_mux.svd"),
    "mutrig_reset_controller": Path("mutrig_reset_controller/mutrig_reset_controller.svd"),
    "mts_preprocessor": Path("mutrig_timestamp_processor/mts_processor.svd"),
}

INSTANCE_SVD_MAP = {
    "scratch_pad_ram": Path("toolkits/infra/cmsis_svd/generic/scratch_pad_ram.svd"),
    "mm_bridge": Path("toolkits/infra/cmsis_svd/generic/mm_bridge_passthrough.svd"),
    "legacy_firefly_bridge": Path("toolkits/infra/cmsis_svd/generic/mm_bridge_passthrough.svd"),
}


def _parse_int(text: str | None) -> int | None:
    if text is None or text == "":
        return None
    return int(text, 0)


def normalize_kind(kind: str) -> str:
    return re.sub(r"_v\d+$", "", kind)


def parse_version_string(text: str | None) -> dict[str, int | str] | None:
    if not text:
        return None
    fields = text.split(".")
    if len(fields) < 3:
        return None
    major = int(fields[0], 10)
    minor = int(fields[1], 10)
    patch = int(fields[2], 10)
    build = int(fields[3], 10) if len(fields) >= 4 else 0
    return {
        "raw": text,
        "major": major,
        "minor": minor,
        "patch": patch,
        "build": build,
    }


def pack_version(version: dict[str, int | str] | None) -> int | None:
    if not version:
        return None
    return (
        (int(version["major"]) & 0xFF) << 24
        | (int(version["minor"]) & 0xFF) << 16
        | (int(version["patch"]) & 0xF) << 12
        | (int(version["build"]) & 0xFFF)
    )


def _safe_relpath(path: Path) -> str:
    return str(path.resolve().relative_to(REPO_ROOT.resolve()))


def _node_text(node: ET.Element | None, name: str, default: str | None = None) -> str | None:
    if node is None:
        return default
    text = node.findtext(name)
    if text is None:
        return default
    return text.strip()


def _parse_dim_index(text: str | None, dim: int) -> list[str]:
    if not text:
        return [str(idx) for idx in range(dim)]
    text = text.strip()
    if "," in text:
        parts = [part.strip() for part in text.split(",") if part.strip()]
        return parts[:dim]
    match = re.fullmatch(r"(\d+)\s*-\s*(\d+)", text)
    if match:
        start = int(match.group(1))
        stop = int(match.group(2))
        step = 1 if stop >= start else -1
        values = [str(value) for value in range(start, stop + step, step)]
        return values[:dim]
    return [text if dim == 1 else f"{text}{idx}" for idx in range(dim)]


def _parse_fields(reg: ET.Element) -> list[dict[str, Any]]:
    fields: list[dict[str, Any]] = []
    for field in reg.findall("./fields/field"):
        fields.append(
            {
                "name": _node_text(field, "name", ""),
                "description": _node_text(field, "description", ""),
                "bit_offset": _parse_int(_node_text(field, "bitOffset")),
                "bit_width": _parse_int(_node_text(field, "bitWidth")),
                "access": _node_text(field, "access"),
                "reset_value": _parse_int(_node_text(field, "resetValue")),
            }
        )
    return fields


def _expand_registers(root: ET.Element) -> tuple[dict[str, int], list[str], list[dict[str, Any]]]:
    registers: dict[str, int] = {}
    register_names: list[str] = []
    register_details: list[dict[str, Any]] = []
    for reg in root.findall(".//register"):
        name_template = (_node_text(reg, "name", "") or "").strip()
        offset = _parse_int(_node_text(reg, "addressOffset"))
        if not name_template or offset is None:
            continue
        dim = _parse_int(_node_text(reg, "dim")) or 1
        dim_increment = _parse_int(_node_text(reg, "dimIncrement")) or 0
        dim_indexes = _parse_dim_index(_node_text(reg, "dimIndex"), dim)
        fields = _parse_fields(reg)
        for dim_i in range(dim):
            suffix = dim_indexes[dim_i] if dim_i < len(dim_indexes) else str(dim_i)
            if "%s" in name_template:
                name = name_template.replace("%s", suffix)
            elif dim > 1:
                name = f"{name_template}{suffix}"
            else:
                name = name_template
            expanded_offset = offset + dim_i * dim_increment
            registers[name] = expanded_offset
            register_names.append(name)
            register_details.append(
                {
                    "name": name,
                    "description": _node_text(reg, "description", ""),
                    "address_offset": expanded_offset,
                    "access": _node_text(reg, "access"),
                    "reset_value": _parse_int(_node_text(reg, "resetValue")),
                    "reset_mask": _parse_int(_node_text(reg, "resetMask")),
                    "fields": fields,
                }
            )
    return registers, register_names, register_details


@dataclass
class SvdMetadata:
    path: str
    device_name: str | None
    device_version: dict[str, int | str] | None
    registers: dict[str, int]
    register_names: list[str]
    register_details: list[dict[str, Any]]
    uid_offset: int | None
    version_mode: str | None
    version_offset: int | None
    version_page: int | None
    git_mode: str | None
    git_offset: int | None
    git_page: int | None
    date_mode: str | None
    date_offset: int | None
    date_page: int | None

    def to_dict(self) -> dict[str, Any]:
        return {
            "path": self.path,
            "device_name": self.device_name,
            "device_version": self.device_version,
            "packed_device_version": pack_version(self.device_version),
            "registers": self.registers,
            "register_names": self.register_names,
            "register_details": self.register_details,
            "uid_offset": self.uid_offset,
            "version_mode": self.version_mode,
            "version_offset": self.version_offset,
            "version_page": self.version_page,
            "git_mode": self.git_mode,
            "git_offset": self.git_offset,
            "git_page": self.git_page,
            "date_mode": self.date_mode,
            "date_offset": self.date_offset,
            "date_page": self.date_page,
        }


def resolve_svd_path(kind: str, instance: str) -> Path | None:
    if instance in INSTANCE_SVD_MAP:
        return REPO_ROOT / INSTANCE_SVD_MAP[instance]

    base_kind = normalize_kind(kind)
    if base_kind in EXPLICIT_SVD_MAP:
        return REPO_ROOT / EXPLICIT_SVD_MAP[base_kind]

    candidates = sorted(REPO_ROOT.rglob(f"{base_kind}.svd"))
    if len(candidates) == 1:
        return candidates[0]
    return None


def resolve_leaf_svd_path(slave_name: str, kind: str = "", instance: str = "") -> Path | None:
    if re.search(r"mutrig_datapath_subsystem_\d+\.csr$", slave_name):
        return REPO_ROOT / "mutrig_frame_deassembly/mutrig_frame_deassembly.svd"
    leaf_rules: list[tuple[str, Path]] = [
        ("backpressure_fifo", Path("toolkits/infra/cmsis_svd/generic/backpressure_fifo_window.svd")),
        ("hist_bin", Path("toolkits/infra/cmsis_svd/generic/histogram_bin_window.svd")),
        ("histogram_statistics", Path("histogram_statistics/histogram_statistics.svd")),
        ("histogram_ingress_bridge", Path("histogram_statistics/histogram_ingress_bridge.svd")),
        ("ring_buffer_cam", Path("ring-buffer_cam/script/ring_buffer_cam.svd")),
        ("feb_frame_assembly", Path("feb_frame_assembly/feb_frame_assembly.svd")),
        ("mutrig_frame_deassembly", Path("mutrig_frame_deassembly/mutrig_frame_deassembly.svd")),
        ("lvds_rx_controller_pro", Path("mu3e_lvds_controller/lvds_rx_controller_pro.svd")),
        ("mts_preprocessor", Path("mutrig_timestamp_processor/mts_processor.svd")),
        ("emulator_mutrig", Path("emulator_mutrig/emulator_mutrig.svd")),
        ("dbg_mm2runctrl", Path("misc/dbg_issp_fab/dbg_mm2runctrl.svd")),
        ("mutrig_lane_source_mux", Path("misc/mutrig_lane_source_mux/mutrig_lane_source_mux.svd")),
        ("mutrig_injector", Path("charge_injection/script/mutrig_injector.svd")),
        ("mutrig_reset_controller", Path("mutrig_reset_controller/mutrig_reset_controller.svd")),
        ("runctl_mgmt_host", Path("run-control_mgmt/runctl_mgmt_host.svd")),
    ]
    for needle, relpath in leaf_rules:
        if needle in slave_name:
            return REPO_ROOT / relpath
    return resolve_svd_path(kind, instance)


def load_svd_metadata(svd_path: Path | None) -> dict[str, Any] | None:
    if svd_path is None or not svd_path.is_file():
        return None

    root = ET.parse(svd_path).getroot()
    registers, register_names, register_details = _expand_registers(root)

    uid_offset = registers.get("UID")
    if uid_offset is None:
        uid_offset = registers.get("ID")

    version_mode = None
    version_offset = None
    version_page = None
    git_mode = None
    git_offset = None
    git_page = None
    date_mode = None
    date_offset = None
    date_page = None

    if "VERSION" in registers:
        version_mode = "direct"
        version_offset = registers["VERSION"]
    elif "META" in registers:
        version_mode = "meta"
        version_offset = registers["META"]
        version_page = 0

    if "GIT" in registers:
        git_mode = "direct"
        git_offset = registers["GIT"]
    elif "META" in registers:
        git_mode = "meta"
        git_offset = registers["META"]
        git_page = 2

    if "DATE" in registers:
        date_mode = "direct"
        date_offset = registers["DATE"]
    elif "META" in registers:
        date_mode = "meta"
        date_offset = registers["META"]
        date_page = 1

    meta = SvdMetadata(
        path=_safe_relpath(svd_path),
        device_name=root.findtext("name"),
        device_version=parse_version_string(root.findtext("version")),
        registers=registers,
        register_names=register_names,
        register_details=register_details,
        uid_offset=uid_offset,
        version_mode=version_mode,
        version_offset=version_offset,
        version_page=version_page,
        git_mode=git_mode,
        git_offset=git_offset,
        git_page=git_page,
        date_mode=date_mode,
        date_offset=date_offset,
        date_page=date_page,
    )
    return meta.to_dict()


def parse_qsys(qsys_path: Path) -> tuple[dict[str, Any], list[dict[str, Any]]]:
    root = ET.parse(qsys_path).getroot()

    modules: dict[str, Any] = {}
    for module in root.findall("./module"):
        params: dict[str, str] = {}
        for param in module.findall("./parameter"):
            name = param.attrib.get("name")
            value = param.attrib.get("value")
            if name:
                params[name] = value or ""

        name = module.attrib.get("name")
        if not name:
            continue
        modules[name] = {
            "name": name,
            "kind": module.attrib.get("kind", ""),
            "module_version": module.attrib.get("version", ""),
            "parameters": params,
        }

    connections: list[dict[str, Any]] = []
    for conn in root.findall("./connection[@kind='avalon']"):
        params = {param.attrib.get("name"): param.attrib.get("value", "") for param in conn.findall("./parameter")}
        connections.append(
            {
                "start": conn.attrib.get("start", ""),
                "end": conn.attrib.get("end", ""),
                "baseAddress": _parse_int(params.get("baseAddress")),
                "parameters": params,
            }
        )

    return modules, connections


def _qsys_expected_version(module: dict[str, Any]) -> dict[str, int] | None:
    params = module.get("parameters", module.get("qsys_parameters", {}))
    if not {"VERSION_MAJOR", "VERSION_MINOR", "VERSION_PATCH"} <= params.keys():
        version = parse_version_string(module.get("module_version"))
        if not version:
            return None
        return {
            "major": int(version["major"]),
            "minor": int(version["minor"]),
            "patch": int(version["patch"]),
            "build": int(version["build"]),
        }
    return {
        "major": int(params["VERSION_MAJOR"], 0),
        "minor": int(params["VERSION_MINOR"], 0),
        "patch": int(params["VERSION_PATCH"], 0),
        "build": int(params.get("BUILD", "0"), 0),
    }


def collect_manifest(qsys_path: Path, masters: dict[str, str] | None = None) -> dict[str, Any]:
    if masters is None:
        masters = {
            "sc": "sc_hub_cmd_pipe.m0",
            "jtag": "jtag_master.master",
        }

    modules, connections = parse_qsys(qsys_path)
    entries: dict[str, dict[str, Any]] = {}

    for transport, master_name in masters.items():
        for conn in connections:
            if conn["start"] != master_name or conn["baseAddress"] is None:
                continue
            end = conn["end"]
            if "." in end:
                instance, interface = end.split(".", 1)
            else:
                instance, interface = end, ""

            module = modules.get(instance, {"name": instance, "kind": "", "module_version": "", "parameters": {}})
            entry = entries.setdefault(
                instance,
                {
                    "instance": instance,
                    "kind": module["kind"],
                    "module_version": module["module_version"],
                    "qsys_parameters": module["parameters"],
                    "interfaces": {},
                    "transports": {},
                },
            )
            entry["interfaces"][transport] = interface
            transport_info = {
                "master": master_name,
                "base_byte": conn["baseAddress"],
            }
            if transport == "sc":
                transport_info["base_word"] = conn["baseAddress"] // 4
            entry["transports"][transport] = transport_info

    for instance, entry in entries.items():
        svd_path = resolve_svd_path(entry["kind"], instance)
        entry["svd"] = load_svd_metadata(svd_path)
        entry["qsys_expected_version"] = _qsys_expected_version(entry)
        entry["qsys_expected_packed_version"] = pack_version(entry["qsys_expected_version"])
        params = entry["qsys_parameters"]
        entry["qsys_expected_git"] = _parse_int(params.get("VERSION_GIT"))
        entry["qsys_expected_date"] = _parse_int(params.get("VERSION_DATE"))
        entry["has_live_version_check"] = bool(entry["svd"] and entry["svd"]["version_mode"])
        entry["has_live_git_check"] = bool(entry["svd"] and entry["svd"]["git_mode"])
        entry["svd_qsys_version_match"] = None
        if entry["svd"] and entry["svd"]["packed_device_version"] is not None and entry["qsys_expected_packed_version"] is not None:
            entry["svd_qsys_version_match"] = entry["svd"]["packed_device_version"] == entry["qsys_expected_packed_version"]

        if entry["kind"] == "sc_hub_v2" and "sc" not in entry["transports"]:
            entry["interfaces"]["sc"] = "internal_csr"
            entry["transports"]["sc"] = {
                "master": "sc_hub.internal",
                "base_byte": 0x3FA00,
                "base_word": 0x0FE80,
            }

    return {
        "repo_root": str(REPO_ROOT),
        "qsys_path": _safe_relpath(qsys_path),
        "masters": masters,
        "instances": sorted(entries.values(), key=lambda item: item["instance"]),
    }


BRIDGE_KINDS = {
    "altera_avalon_mm_bridge",
    "altera_avalon_mm_clock_crossing_bridge",
}


def _endpoint_parts(endpoint: str) -> tuple[str, str]:
    if "." not in endpoint:
        return endpoint, ""
    return endpoint.split(".", 1)


def _bridge_master_for_slave(modules: dict[str, Any], endpoint: str) -> str | None:
    instance, interface = _endpoint_parts(endpoint)
    module = modules.get(instance)
    if not module:
        return None
    if module.get("kind") in BRIDGE_KINDS and interface == "s0":
        return f"{instance}.m0"
    return None


def _connection_base(conn: dict[str, Any]) -> int:
    base = conn.get("baseAddress")
    return 0 if base is None else int(base)


def _absolute_register_details(svd: dict[str, Any] | None, base_byte: int) -> list[dict[str, Any]]:
    if not svd:
        return []
    details: list[dict[str, Any]] = []
    for reg in svd.get("register_details", []):
        item = dict(reg)
        offset = int(item.get("address_offset", 0))
        absolute_byte = base_byte + offset
        item["absolute_byte_addr"] = absolute_byte
        item["sc_tool_word_addr"] = absolute_byte // 4
        item["word_aligned"] = (absolute_byte % 4) == 0
        details.append(item)
    return details


def _entry_for_endpoint(
    *,
    source_qsys: Path,
    modules: dict[str, Any],
    endpoint: str,
    base_byte: int,
    relative_base_byte: int,
    segment: str,
) -> dict[str, Any]:
    instance, interface = _endpoint_parts(endpoint)
    module = modules.get(instance, {"name": instance, "kind": "", "module_version": "", "parameters": {}})
    svd_path = resolve_leaf_svd_path(endpoint, module.get("kind", ""), instance)
    svd = load_svd_metadata(svd_path)
    return {
        "segment": segment,
        "source_qsys": _safe_relpath(source_qsys),
        "slave": endpoint,
        "instance": instance,
        "interface": interface,
        "kind": module.get("kind", ""),
        "module_version": module.get("module_version", ""),
        "qsys_parameters": module.get("parameters", {}),
        "relative_base_byte": relative_base_byte,
        "base_byte": base_byte,
        "base_word": base_byte // 4,
        "word_aligned": (base_byte % 4) == 0,
        "svd": svd,
        "registers": _absolute_register_details(svd, base_byte),
    }


def _traverse_avalon_from(
    *,
    qsys_path: Path,
    modules: dict[str, Any],
    connections: list[dict[str, Any]],
    root_slave_endpoint: str,
    root_base_byte: int,
    segment: str,
) -> list[dict[str, Any]]:
    by_start: dict[str, list[dict[str, Any]]] = {}
    for conn in connections:
        by_start.setdefault(conn["start"], []).append(conn)

    entries: list[dict[str, Any]] = []
    visited: set[tuple[str, int]] = set()

    def walk(slave_endpoint: str, accumulated_base: int) -> None:
        master_endpoint = _bridge_master_for_slave(modules, slave_endpoint)
        if master_endpoint is None:
            return
        key = (master_endpoint, accumulated_base)
        if key in visited:
            return
        visited.add(key)
        for conn in by_start.get(master_endpoint, []):
            relative = accumulated_base + _connection_base(conn)
            end = conn["end"]
            next_master = _bridge_master_for_slave(modules, end)
            if next_master is not None:
                walk(end, relative)
            else:
                entries.append(
                    _entry_for_endpoint(
                        source_qsys=qsys_path,
                        modules=modules,
                        endpoint=end,
                        base_byte=root_base_byte + relative,
                        relative_base_byte=relative,
                        segment=segment,
                    )
                )

    walk(root_slave_endpoint, 0)
    return entries


def _sc_base_for(debug_qsys: Path, endpoint: str) -> int | None:
    _modules, connections = parse_qsys(debug_qsys)
    for conn in connections:
        if conn["start"] == "sc_hub_cmd_pipe.m0" and conn["end"] == endpoint:
            return conn["baseAddress"]
    return None


def collect_full_address_map(
    *,
    debug_qsys: Path,
    datapath_qsys: Path,
    upload_qsys: Path,
) -> dict[str, Any]:
    debug_modules, debug_connections = parse_qsys(debug_qsys)

    entries: list[dict[str, Any]] = []
    for conn in debug_connections:
        if conn["start"] != "sc_hub_cmd_pipe.m0" or conn["baseAddress"] is None:
            continue
        entries.append(
            _entry_for_endpoint(
                source_qsys=debug_qsys,
                modules=debug_modules,
                endpoint=conn["end"],
                base_byte=int(conn["baseAddress"]),
                relative_base_byte=int(conn["baseAddress"]),
                segment="control",
            )
        )

    mm_bridge_base = _sc_base_for(debug_qsys, "mm_bridge.s0")
    if mm_bridge_base is not None:
        datapath_modules, datapath_connections = parse_qsys(datapath_qsys)
        entries.extend(
            _traverse_avalon_from(
                qsys_path=datapath_qsys,
                modules=datapath_modules,
                connections=datapath_connections,
                root_slave_endpoint="mm_clock_crossing_bridge.s0",
                root_base_byte=mm_bridge_base,
                segment="datapath",
            )
        )

    upload_bridge_base = _sc_base_for(debug_qsys, "upload_mm_bridge.s0")
    if upload_bridge_base is not None:
        upload_modules, upload_connections = parse_qsys(upload_qsys)
        entries.extend(
            _traverse_avalon_from(
                qsys_path=upload_qsys,
                modules=upload_modules,
                connections=upload_connections,
                root_slave_endpoint="csr_bridge.s0",
                root_base_byte=upload_bridge_base,
                segment="upload",
            )
        )

    entries = sorted(entries, key=lambda item: (item["base_byte"], item["segment"], item["slave"]))
    missing_svd = [entry["slave"] for entry in entries if not entry["svd"]]
    return {
        "repo_root": str(REPO_ROOT),
        "debug_qsys": _safe_relpath(debug_qsys),
        "datapath_qsys": _safe_relpath(datapath_qsys),
        "upload_qsys": _safe_relpath(upload_qsys),
        "entries": entries,
        "entry_count": len(entries),
        "missing_svd": missing_svd,
    }


def main_dump(qsys_path: Path, output: Path | None) -> None:
    manifest = collect_manifest(qsys_path)
    data = json.dumps(manifest, indent=2, sort_keys=True)
    if output is None:
        print(data)
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(data + "\n", encoding="utf-8")


def main_dump_full_address_map(debug_qsys: Path, datapath_qsys: Path, upload_qsys: Path, output: Path | None) -> None:
    manifest = collect_full_address_map(debug_qsys=debug_qsys, datapath_qsys=datapath_qsys, upload_qsys=upload_qsys)
    data = json.dumps(manifest, indent=2, sort_keys=True)
    if output is None:
        print(data)
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(data + "\n", encoding="utf-8")
