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
    "sc_hub_v2": Path("slow-control_hub/sc_hub.svd"),
    "max10_prog_avmm": Path("feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm.svd"),
    "charge_injection_pulser": Path("charge_injection/charge_injection_pulser.svd"),
    "firefly_xcvr_ctrl": Path("firefly_xcvr_i2c_master/firefly_xcvr_ctrl.svd"),
    "onewire_master_controller": Path("onewire_temp_sense/onewire_master_controller.svd"),
    "altera_temp_sense_ctrl": Path("alt_temp_sense_controller/altera_temp_sense_ctrl.svd"),
    "mutrig_cfg_ctrl": Path("mutrig_controller/mutrig_cfg_ctrl.svd"),
    "runctl_mgmt_host": Path("run-control_mgmt/runctl_mgmt_host.svd"),
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


@dataclass
class SvdMetadata:
    path: str
    device_name: str | None
    device_version: dict[str, int | str] | None
    registers: dict[str, int]
    register_names: list[str]
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


def load_svd_metadata(svd_path: Path | None) -> dict[str, Any] | None:
    if svd_path is None or not svd_path.is_file():
        return None

    root = ET.parse(svd_path).getroot()
    registers: dict[str, int] = {}
    register_names: list[str] = []
    for reg in root.findall(".//register"):
        name = (reg.findtext("name") or "").strip()
        offset = _parse_int(reg.findtext("addressOffset"))
        if not name or offset is None:
            continue
        registers[name] = offset
        register_names.append(name)

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


def main_dump(qsys_path: Path, output: Path | None) -> None:
    manifest = collect_manifest(qsys_path)
    data = json.dumps(manifest, indent=2, sort_keys=True)
    if output is None:
        print(data)
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(data + "\n", encoding="utf-8")
