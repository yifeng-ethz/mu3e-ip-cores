#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import xml.etree.ElementTree as ET
from functools import lru_cache
from pathlib import Path
from typing import Any

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import (
    DEFAULT_JTAG_FALLBACK_PATTERN,
    DEFAULT_JTAG_MASTER_PATTERN,
    _default_jdi,
    _default_project_dir,
    _default_sc_tool,
    _default_system_console,
    jtag_rw,
    run_checked,
    split_jtag_patterns,
    sc_read,
    sc_write,
)
from svd_inventory_lib import REPO_ROOT, SYN_DIR, load_svd_metadata, resolve_svd_path


DEFAULT_DATA_QSYS = SYN_DIR / "scifi_datapath_system_v3_pipe.qsys"
DEFAULT_DEBUG_QSYS = SYN_DIR / "debug_sc_system_v3.qsys"
DEFAULT_FEB_SOPCINFO = SYN_DIR / "feb_system_v3_pipe.sopcinfo"
DEFAULT_SYSTEM_DESC = DEFAULT_FEB_SOPCINFO if DEFAULT_FEB_SOPCINFO.is_file() else DEFAULT_DATA_QSYS
DEFAULT_INVENTORY_JTAG_MASTER_PATTERN = os.environ.get(
    "BOARD_TEST_JTAG_MASTER_PATTERN",
    "*#7-2*/phy_1/master",
)
DEFAULT_INVENTORY_JTAG_FALLBACK_PATTERN = os.environ.get(
    "BOARD_TEST_JTAG_FALLBACK_PATTERN",
    ",".join(
        [
            "*phy_1/master",
            DEFAULT_JTAG_MASTER_PATTERN,
            DEFAULT_JTAG_FALLBACK_PATTERN,
        ]
    ),
)

SC_HUB_MASTER = "sc_hub_cmd_pipe.m0"
SC_DATAPATH_BRIDGE = "mm_bridge.s0"
DATA_SC_ROOT = "mm_clock_crossing_bridge.m0"
DATA_JTAG_ROOT = "master_datapath.master"
SOPCINFO_SC_HUB_MASTER = "control_path_subsystem_sc_hub_cmd_pipe.m0"
SOPCINFO_JTAG_ROOT = "data_path_subsystem_master_datapath.master"

BRIDGE_KINDS = {
    "altera_avalon_mm_bridge",
    "altera_avalon_mm_clock_crossing_bridge",
}

HEADER_REGS = {"UID", "ID", "META", "VERSION", "DATE", "GIT", "INSTANCE_ID"}
STATUS_WORDS = (
    "STATUS",
    "COUNT",
    "COUNTER",
    "TOTAL",
    "DROPPED",
    "DROP",
    "ERROR",
    "ERR",
    "FIFO",
    "LAST",
    "SELECTED",
    "BEAT",
    "RATE",
    "UNDERFLOW",
    "OVERFLOW",
)
CONFIG_WORDS = (
    "CONTROL",
    "CONFIG",
    "CFG",
    "MODE",
    "MASK",
    "SELECT",
    "DELAY",
    "WINDOW",
    "LEFT",
    "RIGHT",
    "BIN",
    "KEY",
    "INTERVAL",
    "LOCAL_CMD",
    "CMD",
)


def parse_int(text: str | None) -> int | None:
    if text is None or text == "":
        return None
    return int(text, 0)


def fmt_hex(value: int | None, width: int = 8) -> str:
    if value is None:
        return "n/a"
    return f"0x{value:0{width}X}"


def split_endpoint(endpoint: str) -> tuple[str, str]:
    if "." not in endpoint:
        return endpoint, ""
    return endpoint.split(".", 1)


def parameter_value(param: ET.Element) -> str:
    return param.attrib.get("value") or param.findtext("value") or ""


def parse_qsys(qsys_path: Path) -> tuple[dict[str, dict[str, Any]], dict[str, list[dict[str, Any]]]]:
    root = ET.parse(qsys_path).getroot()
    modules: dict[str, dict[str, Any]] = {}
    by_start: dict[str, list[dict[str, Any]]] = {}

    for module in root.findall("./module"):
        name = module.attrib.get("name")
        if not name:
            continue
        parameters: dict[str, str] = {}
        for param in module.findall("./parameter"):
            key = param.attrib.get("name")
            if key:
                parameters[key] = parameter_value(param)
        modules[name] = {
            "name": name,
            "kind": module.attrib.get("kind", ""),
            "module_version": module.attrib.get("version", ""),
            "parameters": parameters,
        }

    for conn in root.findall("./connection[@kind='avalon']"):
        start = conn.attrib.get("start", "")
        end = conn.attrib.get("end", "")
        if not start or not end:
            continue
        params = {param.attrib.get("name"): param.attrib.get("value", "") for param in conn.findall("./parameter")}
        base = parse_int(params.get("baseAddress"))
        if base is None:
            continue
        row = {
            "start": start,
            "end": end,
            "base_byte": base,
            "parameters": params,
        }
        by_start.setdefault(start, []).append(row)

    for rows in by_start.values():
        rows.sort(key=lambda item: (item["base_byte"], item["end"]))
    return modules, by_start


def parse_sopcinfo(
    sopcinfo_path: Path,
) -> tuple[dict[str, dict[str, Any]], dict[str, list[dict[str, Any]]]]:
    root = ET.parse(sopcinfo_path).getroot()
    modules: dict[str, dict[str, Any]] = {}
    master_maps: dict[str, list[dict[str, Any]]] = {}

    for module in root.findall("./module"):
        name = module.attrib.get("name")
        if not name:
            continue
        parameters: dict[str, str] = {}
        for param in module.findall("./parameter"):
            key = param.attrib.get("name")
            if key:
                parameters[key] = parameter_value(param)
        modules[name] = {
            "name": name,
            "kind": module.attrib.get("kind", ""),
            "module_version": module.attrib.get("version", ""),
            "parameters": parameters,
        }

        for iface in module.findall("./interface"):
            iface_name = iface.attrib.get("name", "")
            if iface.attrib.get("kind") != "avalon_master" or not iface_name:
                continue
            master = f"{name}.{iface_name}"
            rows: list[dict[str, Any]] = []
            for block in iface.findall("./memoryBlock"):
                endpoint = (block.findtext("name") or "").strip()
                instance = (block.findtext("moduleName") or "").strip()
                slave = (block.findtext("slaveName") or "").strip()
                base = parse_int(block.findtext("baseAddress"))
                span = parse_int(block.findtext("span"))
                if not endpoint or not instance or base is None:
                    continue
                rows.append(
                    {
                        "endpoint": endpoint,
                        "instance": instance,
                        "interface": slave,
                        "base_byte": base,
                        "span_byte": span,
                        "is_bridge": (block.findtext("isBridge") or "").strip().lower() == "true",
                        "route": [f"{master}->{endpoint}@{fmt_hex(base)}"],
                        "cycle": False,
                    }
                )
            rows.sort(key=lambda item: (item["base_byte"], item["endpoint"]))
            master_maps[master] = rows
    return modules, master_maps


def resolve_master(master_maps: dict[str, list[dict[str, Any]]], requested: str) -> str:
    if requested in master_maps:
        return requested
    matches = [name for name in master_maps if name.endswith(requested)]
    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise RuntimeError(f"{requested} is not an Avalon master in the SOPCInfo")
    raise RuntimeError(f"{requested} is ambiguous in the SOPCInfo: {', '.join(matches)}")


def sopcinfo_leaves_for_master(
    master_maps: dict[str, list[dict[str, Any]]],
    requested_master: str,
) -> tuple[str, list[dict[str, Any]]]:
    resolved = resolve_master(master_maps, requested_master)
    return resolved, [row for row in master_maps[resolved] if not row.get("is_bridge")]


def is_bridge(modules: dict[str, dict[str, Any]], instance: str, iface: str, by_start: dict[str, list[dict[str, Any]]]) -> bool:
    module = modules.get(instance, {})
    if module.get("kind") in BRIDGE_KINDS and f"{instance}.m0" in by_start:
        return True
    return iface.startswith("s") and f"{instance}.m0" in by_start and instance.startswith("mm_")


def walk_avalon(
    modules: dict[str, dict[str, Any]],
    by_start: dict[str, list[dict[str, Any]]],
    root_master: str,
) -> list[dict[str, Any]]:
    leaves: list[dict[str, Any]] = []

    def visit(master: str, base_byte: int, route: list[str], seen: set[str]) -> None:
        if master in seen:
            leaves.append(
                {
                    "endpoint": master,
                    "base_byte": base_byte,
                    "route": route + [f"{master}:cycle"],
                    "cycle": True,
                }
            )
            return
        next_seen = set(seen)
        next_seen.add(master)

        for conn in by_start.get(master, []):
            end = conn["end"]
            instance, iface = split_endpoint(end)
            total_base = base_byte + int(conn["base_byte"])
            edge = f"{master}->{end}@{fmt_hex(total_base)}"
            if is_bridge(modules, instance, iface, by_start):
                visit(f"{instance}.m0", total_base, route + [edge], next_seen)
                continue
            leaves.append(
                {
                    "endpoint": end,
                    "instance": instance,
                    "interface": iface,
                    "base_byte": total_base,
                    "route": route + [edge],
                    "cycle": False,
                }
            )

    visit(root_master, 0, [], set())
    return leaves


def find_sc_hub_bridge_base(debug_qsys: Path, master: str, bridge: str) -> int:
    _, by_start = parse_qsys(debug_qsys)
    for conn in by_start.get(master, []):
        if conn["end"] == bridge:
            return int(conn["base_byte"])
    raise RuntimeError(f"{bridge} is not reachable from {master} in {debug_qsys}")


@lru_cache(maxsize=None)
def svd_for_endpoint(instance: str, interface: str, kind: str) -> Path | None:
    if interface == "hist_bin":
        path = REPO_ROOT / "toolkits" / "infra" / "cmsis_svd" / "generic" / "histogram_bin_window.svd"
        return path if path.is_file() else None
    if "backpressure_fifo" in instance:
        path = REPO_ROOT / "toolkits" / "infra" / "cmsis_svd" / "generic" / "backpressure_fifo_window.svd"
        return path if path.is_file() else None
    if interface in {"s0", "s1"}:
        path = REPO_ROOT / "toolkits" / "infra" / "cmsis_svd" / "generic" / "mm_bridge_passthrough.svd"
        return path if path.is_file() else None
    return resolve_svd_path(kind, instance)


@lru_cache(maxsize=None)
def load_svd_register_detail(svd_path: Path | None) -> dict[str, Any] | None:
    meta = load_svd_metadata(svd_path)
    if meta is None or svd_path is None:
        return None

    root = ET.parse(svd_path).getroot()
    address_block_size = None
    block_size_text = root.findtext(".//addressBlock/size")
    if block_size_text:
        address_block_size = int(block_size_text, 0)

    registers = []
    for reg in root.findall(".//register"):
        name = (reg.findtext("name") or "").strip()
        offset = parse_int(reg.findtext("addressOffset"))
        if not name or offset is None:
            continue
        registers.append(
            {
                "name": name,
                "offset_byte": offset,
                "offset_word": offset // 4,
                "access": reg.findtext("access"),
                "reset": parse_int(reg.findtext("resetValue")),
                "group": classify_register(name),
            }
        )

    span = address_block_size
    if span is None and registers:
        span = max(reg["offset_byte"] for reg in registers) + 4

    grouped: dict[str, list[dict[str, Any]]] = {
        "header": [],
        "configure": [],
        "status_counter": [],
        "port_mapped": [],
    }
    for reg in registers:
        grouped.setdefault(reg["group"], []).append(reg)

    result = dict(meta)
    result["address_block_size"] = span
    result["register_detail"] = registers
    result["register_groups"] = grouped
    return result


def classify_register(name: str) -> str:
    upper = name.upper()
    if upper in HEADER_REGS:
        return "header"
    if any(word in upper for word in STATUS_WORDS):
        return "status_counter"
    if any(word in upper for word in CONFIG_WORDS):
        return "configure"
    return "port_mapped"


def classify_aperture(interface: str, svd: dict[str, Any] | None) -> str:
    if interface in {"s0", "s1", "hist_bin"}:
        return "port_mapped"
    if svd and (svd.get("uid_offset") is not None or svd.get("version_mode") is not None):
        return "csr_with_header"
    if svd:
        return "csr_legacy_or_port"
    return "port_mapped"


def pack_qsys_version(module: dict[str, Any]) -> int | None:
    params = module.get("parameters", {})
    keys = {"VERSION_MAJOR", "VERSION_MINOR", "VERSION_PATCH"}
    if keys <= params.keys():
        major = int(params["VERSION_MAJOR"], 0)
        minor = int(params["VERSION_MINOR"], 0)
        patch = int(params["VERSION_PATCH"], 0)
        build = int(params.get("BUILD", "0"), 0)
        return ((major & 0xFF) << 24) | ((minor & 0xFF) << 16) | ((patch & 0xF) << 12) | (build & 0xFFF)

    version = module.get("module_version") or ""
    parts = version.split(".")
    if len(parts) < 3:
        return None
    major = int(parts[0], 10)
    minor = int(parts[1], 10)
    patch = int(parts[2], 10)
    build = int(parts[3], 10) if len(parts) >= 4 else 0
    return ((major & 0xFF) << 24) | ((minor & 0xFF) << 16) | ((patch & 0xF) << 12) | (build & 0xFFF)


def merge_reachable_maps(
    modules: dict[str, dict[str, Any]],
    jtag_leaves: list[dict[str, Any]],
    sc_leaves: list[dict[str, Any]],
    sc_root_base_byte: int,
    jtag_root: str,
    sc_hub_master: str,
    sc_local_root: str | None = None,
    sc_bases_are_global: bool = False,
) -> list[dict[str, Any]]:
    entries: dict[str, dict[str, Any]] = {}

    def entry_for(leaf: dict[str, Any]) -> dict[str, Any]:
        endpoint = leaf["endpoint"]
        instance = leaf.get("instance") or split_endpoint(endpoint)[0]
        interface = leaf.get("interface") or split_endpoint(endpoint)[1]
        module = modules.get(instance, {"kind": "", "module_version": "", "parameters": {}})
        item = entries.setdefault(
            endpoint,
            {
                "endpoint": endpoint,
                "instance": instance,
                "interface": interface,
                "kind": module.get("kind", ""),
                "module_version": module.get("module_version", ""),
                "qsys_parameters": module.get("parameters", {}),
                "qsys_expected_version": pack_qsys_version(module),
                "qsys_expected_git": parse_int(module.get("parameters", {}).get("VERSION_GIT")),
                "qsys_expected_date": parse_int(module.get("parameters", {}).get("VERSION_DATE")),
                "transports": {},
            },
        )
        if leaf.get("span_byte") is not None:
            item.setdefault("span_byte", leaf.get("span_byte"))
        return item

    for leaf in jtag_leaves:
        item = entry_for(leaf)
        item["transports"]["jtag_master"] = {
            "root": jtag_root,
            "base_byte": leaf["base_byte"],
            "base_word": leaf["base_byte"] // 4,
            "span_byte": leaf.get("span_byte"),
            "route": leaf["route"],
        }

    for leaf in sc_leaves:
        item = entry_for(leaf)
        sc_byte = leaf["base_byte"] if sc_bases_are_global else sc_root_base_byte + leaf["base_byte"]
        item["transports"]["sc_hub"] = {
            "root": sc_hub_master,
            "local_root": sc_local_root,
            "sc_bridge_base_byte": sc_root_base_byte,
            "local_base_byte": leaf["base_byte"],
            "base_byte": sc_byte,
            "base_word": sc_byte // 4,
            "span_byte": leaf.get("span_byte"),
            "route": leaf["route"],
        }

    result = []
    for item in entries.values():
        svd_path = svd_for_endpoint(item["instance"], item["interface"], item["kind"])
        svd = load_svd_register_detail(svd_path)
        item["svd"] = svd
        item["aperture"] = {
            "kind": classify_aperture(item["interface"], svd),
            "span_byte": svd.get("address_block_size") if svd else item.get("span_byte"),
            "header": svd.get("register_groups", {}).get("header", []) if svd else [],
            "configure": svd.get("register_groups", {}).get("configure", []) if svd else [],
            "status_counter": svd.get("register_groups", {}).get("status_counter", []) if svd else [],
            "port_mapped": svd.get("register_groups", {}).get("port_mapped", []) if svd else [],
        }
        result.append(item)

    result.sort(
        key=lambda item: (
            item["transports"].get("jtag_master", {}).get("base_byte", 1 << 60),
            item["endpoint"],
        )
    )
    return result


def read_meta_sc(entry: dict[str, Any], sc_tool: Path, link: int, which: str) -> int | None:
    svd = entry.get("svd")
    transport = entry.get("transports", {}).get("sc_hub")
    if not svd or not transport:
        return None
    if which == "uid":
        offset = svd.get("uid_offset")
        if offset is None:
            return None
        return sc_read(sc_tool, link, int(transport["base_word"]) + int(offset) // 4, 1)[0]

    mode = svd.get(f"{which}_mode")
    offset = svd.get(f"{which}_offset")
    if mode is None or offset is None:
        return None
    addr = int(transport["base_word"]) + int(offset) // 4
    if mode == "direct":
        return sc_read(sc_tool, link, addr, 1)[0]
    if mode == "meta":
        page = int(svd[f"{which}_page"])
        sc_write(sc_tool, link, addr, [page])
        value = sc_read(sc_tool, link, addr, 1)[0]
        if page != 0:
            sc_write(sc_tool, link, addr, [0])
        return value
    return None


def read_meta_jtag(
    entry: dict[str, Any],
    system_console: Path,
    jdi: Path,
    project_dir: Path,
    which: str,
    master_pattern: str,
    fallback_pattern: str,
) -> int | None:
    svd = entry.get("svd")
    transport = entry.get("transports", {}).get("jtag_master")
    if not svd or not transport:
        return None

    def uid_reset_value() -> int | None:
        for reg in svd.get("register_detail", []):
            if reg.get("name") == "UID" and reg.get("reset") is not None:
                return int(reg["reset"])
        return None

    uid_offset = svd.get("uid_offset")
    uid_expected = uid_reset_value()
    probe_kwargs: dict[str, int] = {}
    if uid_offset is not None and uid_expected is not None:
        probe_kwargs = {
            "uid_addr": int(transport["base_byte"]) + int(uid_offset),
            "uid_expected": uid_expected,
        }

    if which == "uid":
        offset = svd.get("uid_offset")
        if offset is None:
            return None
        return jtag_rw(
            system_console,
            jdi,
            project_dir,
            "read",
            int(transport["base_byte"]) + int(offset),
            master_pattern=master_pattern,
            fallback_pattern=fallback_pattern,
            **probe_kwargs,
        )[0]

    mode = svd.get(f"{which}_mode")
    offset = svd.get(f"{which}_offset")
    if mode is None or offset is None:
        return None
    addr = int(transport["base_byte"]) + int(offset)
    if mode == "direct":
        return jtag_rw(
            system_console,
            jdi,
            project_dir,
            "read",
            addr,
            master_pattern=master_pattern,
            fallback_pattern=fallback_pattern,
            **probe_kwargs,
        )[0]
    if mode == "meta":
        page = int(svd[f"{which}_page"])
        jtag_rw(
            system_console,
            jdi,
            project_dir,
            "write",
            addr,
            data=[page],
            master_pattern=master_pattern,
            fallback_pattern=fallback_pattern,
            **probe_kwargs,
        )
        value = jtag_rw(
            system_console,
            jdi,
            project_dir,
            "read",
            addr,
            master_pattern=master_pattern,
            fallback_pattern=fallback_pattern,
            **probe_kwargs,
        )[0]
        if page != 0:
            jtag_rw(
                system_console,
                jdi,
                project_dir,
                "write",
                addr,
                data=[0],
                master_pattern=master_pattern,
                fallback_pattern=fallback_pattern,
                **probe_kwargs,
            )
        return value
    return None


def uid_probe_for_jtag(entries: list[dict[str, Any]]) -> tuple[int | None, int | None]:
    for entry in entries:
        svd = entry.get("svd")
        transport = entry.get("transports", {}).get("jtag_master")
        if not svd or not transport:
            continue
        uid_offset = svd.get("uid_offset")
        if uid_offset is None:
            continue
        for reg in svd.get("register_detail", []):
            if reg.get("name") == "UID" and reg.get("reset") is not None:
                return int(transport["base_byte"]) + int(uid_offset), int(reg["reset"])
    return None, None


def jtag_meta_read_specs(entries: list[dict[str, Any]]) -> tuple[list[str], dict[str, tuple[dict[str, Any], str]]]:
    specs: list[str] = []
    labels: dict[str, tuple[dict[str, Any], str]] = {}
    for entry_index, entry in enumerate(entries):
        svd = entry.get("svd")
        transport = entry.get("transports", {}).get("jtag_master")
        if not svd or not transport:
            continue
        base = int(transport["base_byte"])
        for field in ("uid", "version", "date", "git"):
            label = f"e{entry_index}_{field}"
            if field == "uid":
                offset = svd.get("uid_offset")
                if offset is None:
                    continue
                specs.append(f"{label}:direct:0x{base + int(offset):08X}")
            else:
                mode = svd.get(f"{field}_mode")
                offset = svd.get(f"{field}_offset")
                if mode is None or offset is None:
                    continue
                addr = base + int(offset)
                if mode == "direct":
                    specs.append(f"{label}:direct:0x{addr:08X}")
                elif mode == "meta":
                    page = int(svd[f"{field}_page"])
                    specs.append(f"{label}:meta:0x{addr:08X}:0x{page:08X}")
                else:
                    continue
            labels[label] = (entry, field)
    return specs, labels


def parse_jtag_meta_output(output: str) -> tuple[dict[str, int], dict[str, str]]:
    words: dict[str, int] = {}
    result_line: dict[str, str] = {}
    for line in output.splitlines():
        line = line.strip()
        if line.startswith("JTAG_META_WORD "):
            label = None
            value = None
            for token in line.split()[1:]:
                if "=" not in token:
                    continue
                key, text = token.split("=", 1)
                if key == "label":
                    label = text
                elif key == "value":
                    value = int(text, 16)
            if label is None or value is None:
                raise RuntimeError(f"failed to parse JTAG meta word line: {line}")
            words[label] = value
        elif line.startswith("JTAG_META_RESULT "):
            for token in line.split()[1:]:
                if "=" not in token:
                    continue
                key, value = token.split("=", 1)
                result_line[key] = value
    if result_line.get("status") != "OK":
        raise RuntimeError(f"JTAG metadata helper failed:\n{output}")
    return words, result_line


def read_live_jtag_batch(
    entries: list[dict[str, Any]],
    system_console: Path,
    jdi: Path,
    project_dir: Path,
    master_pattern: str,
    fallback_pattern: str,
) -> None:
    entries_with_jtag = [entry for entry in entries if "jtag_master" in entry.get("transports", {})]
    specs, labels = jtag_meta_read_specs(entries_with_jtag)
    if not specs:
        return

    script = SCRIPT_DIR / "jtag_meta_batch.tcl"
    env = os.environ.copy()
    if "BOARD_TEST_DISPLAY" in env:
        env["DISPLAY"] = env["BOARD_TEST_DISPLAY"]
    else:
        env.pop("DISPLAY", None)
    env.setdefault("BOARD_TEST_SCRIPT_DIR", str(SCRIPT_DIR))

    uid_addr, uid_expected = uid_probe_for_jtag(entries_with_jtag)
    base_cmd = [
        str(system_console),
        "-cli",
        "-disable_readline",
        "-disable_timeout",
        f"--project_dir={project_dir}",
        f"--jdi={jdi}",
        f"--script={script}",
        "--reads",
        ",".join(specs),
        "--service-tag",
        "board_test_inventory",
    ]
    if uid_addr is not None and uid_expected is not None:
        base_cmd.extend(["--uid-addr", f"0x{uid_addr:08X}", "--uid-expected", f"0x{uid_expected:08X}"])

    errors: list[str] = []
    for pattern in split_jtag_patterns(master_pattern, fallback_pattern):
        cmd = list(base_cmd)
        cmd.extend(["--master-pattern", pattern, "--fallback-pattern", ""])
        try:
            output = run_checked(cmd, env=env).stdout
            words, _ = parse_jtag_meta_output(output)
            for label, value in words.items():
                entry, field = labels[label]
                entry.setdefault("live", {}).setdefault("jtag_master", {})[field] = value
            return
        except subprocess.CalledProcessError as exc:
            errors.append((exc.stdout or "") + (exc.stderr or ""))
        except Exception as exc:
            errors.append(str(exc))

    raise RuntimeError(
        "JTAG metadata helper failed for all master patterns: "
        + ", ".join(split_jtag_patterns(master_pattern, fallback_pattern))
        + "\n"
        + "\n---\n".join(errors)
    )


def attach_live_metadata(entries: list[dict[str, Any]], args: argparse.Namespace) -> None:
    for entry in entries:
        live: dict[str, Any] = {"sc_hub": {}, "jtag_master": {}, "errors": []}
        entry["live"] = live
        if not args.skip_sc and "sc_hub" in entry.get("transports", {}):
            try:
                for field in ("uid", "version", "date", "git"):
                    live["sc_hub"][field] = read_meta_sc(entry, args.sc_tool, args.link, field)
            except Exception as exc:
                live["errors"].append(f"sc_hub: {exc}")

    if args.skip_jtag:
        return

    try:
        read_live_jtag_batch(
            entries,
            args.system_console,
            args.jdi,
            args.project_dir,
            args.jtag_master_pattern,
            args.jtag_fallback_pattern,
        )
    except Exception as exc:
        for entry in entries:
            if "jtag_master" in entry.get("transports", {}):
                entry["live"]["errors"].append(f"jtag_master: {exc}")


def match_instances(entries: list[dict[str, Any]], pattern: str) -> list[dict[str, Any]]:
    if not pattern:
        return entries
    regex = re.compile(pattern)
    return [
        entry
        for entry in entries
        if regex.search(entry["endpoint"]) or regex.search(entry["instance"]) or regex.search(entry["kind"])
    ]


def compact_reg_list(registers: list[dict[str, Any]], limit: int) -> str:
    if not registers:
        return "-"
    pieces = [f"{reg['name']}@+{reg['offset_word']}" for reg in registers[:limit]]
    if len(registers) > limit:
        pieces.append(f"+{len(registers) - limit} more")
    return ", ".join(pieces)


def compact_meta(entry: dict[str, Any]) -> str:
    pieces = []
    if entry.get("qsys_expected_version") is not None:
        pieces.append(f"ver={fmt_hex(entry['qsys_expected_version'])}")
    if entry.get("qsys_expected_date") is not None:
        pieces.append(f"date={fmt_hex(entry['qsys_expected_date'])}")
    if entry.get("qsys_expected_git") is not None:
        pieces.append(f"git={fmt_hex(entry['qsys_expected_git'])}")
    return ", ".join(pieces) if pieces else "-"


def compact_live(entry: dict[str, Any]) -> str:
    live = entry.get("live")
    if not live:
        return "-"
    pieces = []
    for transport in ("sc_hub", "jtag_master"):
        values = live.get(transport, {})
        sub = []
        for field in ("uid", "version", "date", "git"):
            if values.get(field) is not None:
                sub.append(f"{field}={fmt_hex(values[field])}")
        if sub:
            pieces.append(f"{transport}: " + ",".join(sub))
    if live.get("errors"):
        pieces.append("errors=" + ";".join(live["errors"]))
    return "<br>".join(pieces) if pieces else "-"


def print_table(entries: list[dict[str, Any]]) -> None:
    print(
        "| Endpoint | Kind | JTAG byte | SC word | Meta | Live | Aperture | Header | Configure | Status/counter | Port-mapped | SVD |"
    )
    print("|---|---|---:|---:|---|---|---|---|---|---|---|---|")
    for entry in entries:
        jtag = entry["transports"].get("jtag_master", {})
        sc = entry["transports"].get("sc_hub", {})
        aperture = entry["aperture"]
        svd = entry.get("svd") or {}
        print(
            f"| `{entry['endpoint']}` | `{entry['kind']}` | "
            f"`{fmt_hex(jtag.get('base_byte'))}` | `{fmt_hex(sc.get('base_word'), 5)}` | "
            f"{compact_meta(entry)} | {compact_live(entry)} | "
            f"{aperture['kind']} span=`{fmt_hex(aperture.get('span_byte'))}` | "
            f"{compact_reg_list(aperture['header'], 4)} | "
            f"{compact_reg_list(aperture['configure'], 5)} | "
            f"{compact_reg_list(aperture['status_counter'], 5)} | "
            f"{compact_reg_list(aperture['port_mapped'], 5)} | "
            f"`{svd.get('path', 'n/a')}` |"
        )


def system_desc_kind(path: Path) -> str:
    root = ET.parse(path).getroot()
    if root.tag == "EnsembleReport":
        return "sopcinfo"
    return "qsys"


def build_inventory(args: argparse.Namespace) -> dict[str, Any]:
    system_desc = (args.system_desc or args.data_qsys or DEFAULT_SYSTEM_DESC).resolve()
    desc_kind = system_desc_kind(system_desc)

    if desc_kind == "sopcinfo":
        modules, master_maps = parse_sopcinfo(system_desc)
        jtag_root = args.jtag_root or SOPCINFO_JTAG_ROOT
        sc_hub_master = args.sc_hub_master or SOPCINFO_SC_HUB_MASTER
        jtag_root, jtag_leaves = sopcinfo_leaves_for_master(master_maps, jtag_root)
        sc_hub_master, sc_leaves = sopcinfo_leaves_for_master(master_maps, sc_hub_master)
        sc_bridge_base_byte = 0
        sc_root = None
        entries = merge_reachable_maps(
            modules,
            jtag_leaves,
            sc_leaves,
            sc_bridge_base_byte,
            jtag_root,
            sc_hub_master,
            sc_root,
            sc_bases_are_global=True,
        )
    else:
        modules, by_start = parse_qsys(system_desc)
        jtag_root = args.jtag_root or DATA_JTAG_ROOT
        sc_root = args.sc_root or DATA_SC_ROOT
        sc_hub_master = args.sc_hub_master or SC_HUB_MASTER
        sc_datapath_bridge = args.sc_datapath_bridge or SC_DATAPATH_BRIDGE
        jtag_leaves = walk_avalon(modules, by_start, jtag_root)
        sc_leaves = walk_avalon(modules, by_start, sc_root)
        sc_bridge_base_byte = find_sc_hub_bridge_base(args.debug_qsys.resolve(), sc_hub_master, sc_datapath_bridge)
        entries = merge_reachable_maps(
            modules,
            jtag_leaves,
            sc_leaves,
            sc_bridge_base_byte,
            jtag_root,
            sc_hub_master,
            sc_root,
        )

    entries = match_instances(entries, args.filter)
    if args.probe_live:
        attach_live_metadata(entries, args)
    return {
        "system_desc": str(system_desc),
        "system_desc_kind": desc_kind,
        "data_qsys": str(system_desc) if desc_kind == "qsys" else None,
        "debug_qsys": str(args.debug_qsys.resolve()),
        "roots": {
            "jtag_master": jtag_root,
            "sc_local_root": sc_root,
            "sc_hub_master": sc_hub_master,
            "sc_datapath_bridge": args.sc_datapath_bridge,
            "sc_datapath_bridge_base_byte": sc_bridge_base_byte,
            "sc_datapath_bridge_base_word": sc_bridge_base_byte // 4,
        },
        "instances": entries,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Derive the current FEB SciFi datapath IP inventory, standard VERSION/META "
            "layout, aperture grouping, and both JTAG-master and SC-hub base addresses."
        )
    )
    parser.add_argument(
        "--system-desc",
        type=Path,
        default=None,
        help=f"Qsys or generated SOPCInfo source. Default: {DEFAULT_SYSTEM_DESC}",
    )
    parser.add_argument("--data-qsys", type=Path, default=None, help="Legacy alias for --system-desc with a Qsys file.")
    parser.add_argument("--debug-qsys", type=Path, default=DEFAULT_DEBUG_QSYS)
    parser.add_argument("--jtag-root", default=None)
    parser.add_argument("--sc-root", default=None)
    parser.add_argument("--sc-hub-master", default=None)
    parser.add_argument("--sc-datapath-bridge", default=None)
    parser.add_argument("--filter", default="", help="Regex over endpoint, instance, or kind.")
    parser.add_argument("--json", action="store_true", help="Emit JSON instead of Markdown table.")
    parser.add_argument("--output", type=Path, default=None)
    parser.add_argument("--probe-live", action="store_true", help="Read UID/VERSION/DATE/GIT through live SC/JTAG.")
    parser.add_argument("--link", type=int, default=int(os.environ.get("BOARD_TEST_LINK", "2")))
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--system-console", type=Path, default=_default_system_console())
    parser.add_argument("--jdi", type=Path, default=_default_jdi())
    parser.add_argument("--project-dir", type=Path, default=_default_project_dir())
    parser.add_argument("--skip-sc", action="store_true")
    parser.add_argument("--skip-jtag", action="store_true")
    parser.add_argument(
        "--jtag-master-pattern",
        default=DEFAULT_INVENTORY_JTAG_MASTER_PATTERN,
    )
    parser.add_argument(
        "--jtag-fallback-pattern",
        default=DEFAULT_INVENTORY_JTAG_FALLBACK_PATTERN,
    )
    args = parser.parse_args()

    inventory = build_inventory(args)
    if args.json:
        rendered = json.dumps(inventory, indent=2, sort_keys=True) + "\n"
    else:
        from io import StringIO
        import contextlib

        buf = StringIO()
        with contextlib.redirect_stdout(buf):
            print_table(inventory["instances"])
        rendered = buf.getvalue()

    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        try:
            print(rendered, end="")
        except BrokenPipeError:
            return 0
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
