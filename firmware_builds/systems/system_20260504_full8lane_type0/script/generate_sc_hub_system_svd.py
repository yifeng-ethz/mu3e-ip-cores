#!/usr/bin/env python3
"""Generate the SC-hub-relative CMSIS-SVD for the full8lane type0 system."""

from __future__ import annotations

import argparse
import copy
import re
import sys
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path

XSI_NS = "http://www.w3.org/2001/XMLSchema-instance"
ET.register_namespace("xs", XSI_NS)


@dataclass(frozen=True)
class ModuleInfo:
    name: str
    kind: str
    version: str
    params: dict[str, str]
    source_qsys: str


@dataclass(frozen=True)
class SlaveEntry:
    slave: str
    base: int
    size: int
    origin: str


REPO_ROOT = Path(__file__).resolve().parents[4]
SYSTEM_DIR = Path(__file__).resolve().parents[1]
SYN_DIR = SYSTEM_DIR / "syn"

TOP_QSYS = SYN_DIR / "full8lane_type0_system.qsys"
CONTROL_QSYS = SYN_DIR / "full8lane_control_path_subsystem.qsys"
DATAPATH_QSYS = SYN_DIR / "full8lane_type0_datapath.qsys"
ARB_QSYS = SYN_DIR / "arb_hit_type0_supercore.qsys"
BUILD_TCL = SYN_DIR / "build_full8lane_system.tcl"
DEFAULT_OUTPUT = SYSTEM_DIR / "svd" / "full8lane_type0_system_sc_hub.svd"

SOURCE_SVDS = {
    "scratch_pad_ram.s1": "toolkits/infra/cmsis_svd/generic/scratch_pad_ram.svd",
    "onewire_master_controller_0.csr": "onewire_temp_sense/script/onewire_master_controller.svd",
    "max10_prog_avmm_0.csr_avmm": "feb_max10_comm/legacy/max10_prog_avmm/max10_prog_avmm.svd",
    "charge_injection_pulser_0.csr_avmm": "charge_injection/legacy/charge_injection_pulser.svd",
    "firefly_xcvr_ctrl_0.firefly": "firefly_xcvr_i2c_master/firefly_xcvr_ctrl.svd",
    "mutrig_cfg_ctrl_0.avmm_csr": "mutrig_controller/mutrig_cfg_ctrl.svd",
}

SOURCE_RULES = [
    (re.compile(r"^data_path_subsystem_backpressure_fifo_\d+\.csr$"),
     "toolkits/infra/cmsis_svd/generic/backpressure_fifo_window.svd"),
    (re.compile(r"^data_path_subsystem_mutrig_frame_deassembly_\d+\.csr$"),
     "mutrig_frame_deassembly/script/mutrig_frame_deassembly.svd"),
    (re.compile(r"^data_path_subsystem_emulator_mutrig_\d+\.csr$"),
     "emulator_mutrig/emulator_mutrig.svd"),
    (re.compile(r"^data_path_subsystem_histogram_statistics_0\.hist_bin$"),
     "toolkits/infra/cmsis_svd/generic/histogram_bin_window.svd"),
    (re.compile(r"^data_path_subsystem_histogram_statistics_0\.csr$"),
     "histogram_statistics/histogram_statistics.svd"),
    (re.compile(r"^data_path_subsystem_histogram_ingress_bridge_0\.csr$"),
     "histogram_statistics/histogram_ingress_bridge.svd"),
    (re.compile(r"^data_path_subsystem_mutrig_injector_0\.csr$"),
     "charge_injection/script/mutrig_injector.svd"),
    (re.compile(r"^upload_subsystem_runctl_mgmt_host_0\.csr$"),
     "run-control_mgmt/runctl_mgmt_host.svd"),
]

RAW_WINDOWS = {
    "on_die_temp_sense_ctrl.csr": (0x20, "Intel temperature-sensor control/status window; no local Mu3e SVD source was present."),
    "legacy_firefly_bridge.s0": (0x400, "Avalon bridge aperture for the legacy Firefly path; the bridge has no decoded local CSR fields."),
    "data_path_subsystem_mutrig_reset_controller_0.reconfig_mgmt": (0x100, "LVDS/MuTRiG reset-controller reconfiguration-management window; no local SVD source was present."),
    "data_path_subsystem_dbg_mm2runctrl_0.csr": (0x40, "Debug MM-to-run-control adapter CSR window; no local SVD source was present."),
}


def parse_int(value: str | None) -> int:
    if value is None:
        raise ValueError("missing integer value")
    text = value.strip().replace("_", "")
    sv_match = re.fullmatch(r"(\d+)?'([hHdDbB])([0-9a-fA-FxXzZ]+)", text)
    if sv_match:
        radix = sv_match.group(2).lower()
        digits = sv_match.group(3).lower().replace("x", "0").replace("z", "0")
        return int(digits, {"h": 16, "d": 10, "b": 2}[radix])
    return int(text, 0)


def h(value: int, width: int = 8) -> str:
    return f"0x{value:0{width}X}"


def sanitize_name(value: str) -> str:
    out = re.sub(r"[^0-9A-Za-z_]", "_", value).upper()
    out = re.sub(r"_+", "_", out).strip("_")
    if not out:
        out = "PERIPHERAL"
    if out[0].isdigit():
        out = "P_" + out
    return out


def rel(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def text(parent: ET.Element, tag: str, value: str | int) -> ET.Element:
    elem = ET.SubElement(parent, tag)
    elem.text = str(value)
    return elem


def set_child(parent: ET.Element, tag: str, value: str | int) -> ET.Element:
    elem = parent.find(tag)
    if elem is None:
        elem = ET.SubElement(parent, tag)
    elem.text = str(value)
    return elem


def parse_qsys(path: Path) -> ET.Element:
    return ET.parse(path).getroot()


def qsys_modules(path: Path) -> dict[str, ModuleInfo]:
    root = parse_qsys(path)
    out: dict[str, ModuleInfo] = {}
    for module in root.findall("module"):
        name = module.get("name", "")
        if not name:
            continue
        params: dict[str, str] = {}
        for param in module.findall("parameter"):
            pname = param.get("name")
            if not pname:
                continue
            params[pname] = param.get("value") if param.get("value") is not None else (param.text or "").strip()
        out[name] = ModuleInfo(
            name=name,
            kind=module.get("kind", ""),
            version=module.get("version", ""),
            params=params,
            source_qsys=path.name,
        )
    return out


def all_module_info() -> dict[str, ModuleInfo]:
    out: dict[str, ModuleInfo] = {}
    for path in (CONTROL_QSYS, DATAPATH_QSYS, TOP_QSYS):
        out.update(qsys_modules(path))
    arb = qsys_modules(ARB_QSYS)
    for name, info in arb.items():
        if name.startswith("lane_"):
            out[f"arb_hit_type0_supercore_0_{name}"] = info
    generated_runctl, intended_runctl = runctl_versions()
    if generated_runctl or intended_runctl:
        out["runctl_mgmt_host_0"] = ModuleInfo(
            name="upload_subsystem_runctl_mgmt_host_0",
            kind="runctl_mgmt_host",
            version=generated_runctl or intended_runctl,
            params={"BUILD_TCL_VERSION": intended_runctl} if intended_runctl else {},
            source_qsys="full8lane_type0_system generated HTML/build_full8lane_system.tcl",
        )
    return out


def module_name_from_slave(slave: str) -> str:
    name = slave.split(".", 1)[0]
    if name.startswith("data_path_subsystem_"):
        name = name.removeprefix("data_path_subsystem_")
    if name.startswith("upload_subsystem_"):
        name = name.removeprefix("upload_subsystem_")
    if name.startswith("arb_hit_type0_supercore_0_lane_"):
        return name
    return name


def module_info_for_slave(slave: str, modules: dict[str, ModuleInfo]) -> ModuleInfo | None:
    if "arb_hit_type0_supercore_0_lane_" in slave:
        lane = re.search(r"lane_(\d+)", slave)
        if lane:
            return modules.get(f"arb_hit_type0_supercore_0_lane_{lane.group(1)}")
    return modules.get(module_name_from_slave(slave))


def version_summary(info: ModuleInfo | None) -> str:
    if info is None:
        return "Compiled Qsys module version was not found in the source .qsys files."
    parts = [f"Compiled Qsys module {info.name} kind={info.kind} version={info.version} from {info.source_qsys}."]
    ordered = [
        "VERSION_MAJOR", "VERSION_MINOR", "VERSION_PATCH", "BUILD",
        "VERSION_DATE", "VERSION_GIT", "IP_UID", "INSTANCE_ID",
        "N_LANE", "N_ENGINE", "ROUTING_TOPOLOGY", "SCORE_WINDOW_W",
        "SCORE_ACCEPT", "SCORE_REJECT", "BUILD_TCL_VERSION",
    ]
    present = [f"{key}={info.params[key]}" for key in ordered if key in info.params]
    if present:
        parts.append("Version/identity parameters: " + ", ".join(present) + ".")
    return " ".join(parts)


def find_base(root: ET.Element, start: str, end: str) -> int:
    for connection in root.findall("connection"):
        if connection.get("kind") != "avalon":
            continue
        if connection.get("start") == start and connection.get("end") == end:
            for param in connection.findall("parameter"):
                if param.get("name") == "baseAddress":
                    return parse_int(param.get("value"))
    raise RuntimeError(f"missing Avalon base for {start} -> {end}")


def control_slaves(root: ET.Element) -> list[tuple[str, int]]:
    out: list[tuple[str, int]] = []
    for connection in root.findall("connection"):
        if connection.get("kind") != "avalon" or connection.get("start") != "sc_hub_cmd_pipe.m0":
            continue
        end = connection.get("end", "")
        base = None
        for param in connection.findall("parameter"):
            if param.get("name") == "baseAddress":
                base = parse_int(param.get("value"))
                break
        if base is not None:
            out.append((end, base))
    return sorted(out, key=lambda item: item[1])


def qsys_address_map(root: ET.Element, param_name: str) -> list[tuple[str, int, int]]:
    for param in root.findall(".//parameter"):
        if param.get("name") != param_name:
            continue
        payload = (param.text or "").strip()
        address_map = ET.fromstring(payload)
        out = []
        for slave in address_map.findall("slave"):
            out.append((
                slave.get("name", ""),
                parse_int(slave.get("start")),
                parse_int(slave.get("end")),
            ))
        return out
    raise RuntimeError(f"missing {param_name} in {TOP_QSYS}")


def source_svd_for_slave(slave: str) -> Path | None:
    if slave in SOURCE_SVDS:
        return REPO_ROOT / SOURCE_SVDS[slave]
    for pattern, source in SOURCE_RULES:
        if pattern.match(slave):
            return REPO_ROOT / source
    return None


def source_svd_version(path: Path) -> str:
    try:
        return ET.parse(path).getroot().findtext("version") or "unknown"
    except Exception:
        return "unreadable"


def first_address_block_size(peripheral: ET.Element) -> int | None:
    size = peripheral.findtext("addressBlock/size")
    if not size:
        return None
    return parse_int(size)


def default_size_for_direct(slave: str, svd_path: Path | None) -> int:
    if slave in RAW_WINDOWS:
        return RAW_WINDOWS[slave][0]
    if svd_path is None:
        return 0x40
    peripheral = ET.parse(svd_path).getroot().find("peripherals/peripheral")
    if peripheral is not None:
        size = first_address_block_size(peripheral)
        if size is not None:
            return size
    return 0x40


def group_for_slave(slave: str, origin: str) -> str:
    if origin == "control":
        if "firefly" in slave:
            return "CONTROL_FIREFLY"
        if "onewire" in slave or "temp" in slave:
            return "CONTROL_BOARD_MONITOR"
        if "max10" in slave or "charge_injection" in slave or "mutrig_cfg" in slave:
            return "CONTROL_MU3E_FRONTEND"
        return "CONTROL_PATH"
    if origin == "upload":
        return "UPLOAD_RUN_CONTROL"
    if "lvds" in slave:
        return "DATAPATH_LVDS"
    if "histogram" in slave:
        return "DATAPATH_HISTOGRAM"
    if "emulator" in slave:
        return "DATAPATH_EMULATOR"
    if "arb_hit_type0" in slave:
        return "DATAPATH_ARB_TYPE0"
    if "hit_stack" in slave or "feb_frame" in slave:
        return "DATAPATH_HIT_STACK"
    if "mutrig" in slave or "backpressure_fifo" in slave or "mts_preprocessor" in slave:
        return "DATAPATH_MUTRIG"
    return "DATAPATH_MISC"


def description_prefix(entry: SlaveEntry, info: ModuleInfo | None, source: Path | None) -> str:
    origin_text = {
        "control": "Direct control-path slave reached from sc_hub_cmd_pipe.m0.",
        "datapath": "Datapath-local slave expanded below the SC-hub mm_bridge.s0 aperture.",
        "upload": "Upload-subsystem slave expanded below the SC-hub upload_mm_bridge.s0 aperture.",
    }[entry.origin]
    source_text = "No source SVD file was present; this peripheral is generated as an explicitly raw window."
    if source is not None:
        source_text = f"Source SVD {rel(source)} version {source_svd_version(source)}."
    return (
        f"{origin_text} Qsys slave {entry.slave} is SC-hub-relative at "
        f"{h(entry.base)} with compiled aperture size {h(entry.size)}. "
        f"{version_summary(info)} {source_text}"
    )


def field(name: str, bit_offset: int, bit_width: int, access: str, description: str) -> ET.Element:
    elem = ET.Element("field")
    text(elem, "name", name)
    text(elem, "description", description)
    text(elem, "bitOffset", bit_offset)
    text(elem, "bitWidth", bit_width)
    text(elem, "access", access)
    return elem


def register(
    name: str,
    offset: int,
    access: str,
    description: str,
    fields: list[ET.Element] | None = None,
    reset: int | None = None,
) -> ET.Element:
    elem = ET.Element("register")
    text(elem, "name", name)
    text(elem, "description", description)
    text(elem, "addressOffset", h(offset, 2))
    text(elem, "access", access)
    if reset is not None:
        text(elem, "resetValue", h(reset))
    if fields:
        fields_elem = ET.SubElement(elem, "fields")
        for item in fields:
            fields_elem.append(item)
    return elem


def peripheral_shell(name: str, base: int, size: int, group: str, description: str) -> ET.Element:
    peripheral = ET.Element("peripheral")
    text(peripheral, "name", sanitize_name(name))
    text(peripheral, "description", description)
    text(peripheral, "groupName", group)
    text(peripheral, "baseAddress", h(base))
    block = ET.SubElement(peripheral, "addressBlock")
    text(block, "offset", "0x0")
    text(block, "size", h(size))
    text(block, "usage", "registers")
    ET.SubElement(peripheral, "registers")
    return peripheral


def copy_source_peripheral(entry: SlaveEntry, source: Path, group: str, info: ModuleInfo | None) -> ET.Element:
    root = ET.parse(source).getroot()
    source_peripheral = root.find("peripherals/peripheral")
    if source_peripheral is None:
        raise RuntimeError(f"{source} has no peripheral")
    peripheral = copy.deepcopy(source_peripheral)
    set_child(peripheral, "name", sanitize_name(entry.slave))
    set_child(peripheral, "groupName", group)
    set_child(peripheral, "baseAddress", h(entry.base))
    original_desc = source_peripheral.findtext("description") or ""
    set_child(peripheral, "description", f"{description_prefix(entry, info, source)} {original_desc}")
    block = peripheral.find("addressBlock")
    if block is None:
        block = ET.SubElement(peripheral, "addressBlock")
        text(block, "offset", "0x0")
        text(block, "usage", "registers")
    set_child(block, "offset", "0x0")
    set_child(block, "size", h(entry.size))
    set_child(block, "usage", "registers")
    if peripheral.find("registers") is None:
        ET.SubElement(peripheral, "registers")
    return peripheral


def raw_window(entry: SlaveEntry, group: str, info: ModuleInfo | None, note: str) -> ET.Element:
    desc = f"{description_prefix(entry, info, None)} {note}"
    peripheral = peripheral_shell(entry.slave, entry.base, entry.size, group, desc)
    regs = peripheral.find("registers")
    assert regs is not None
    word_count = max(1, min(entry.size // 4, 64))
    for idx in range(word_count):
        regs.append(register(
            f"RAW_WORD_{idx:02d}",
            idx * 4,
            "read-write",
            f"Undecoded raw 32-bit word {idx} in {entry.slave}. The compiled Qsys map exposes this word, but no semantic source SVD was present.",
            [field("value", 0, 32, "read-write", f"Raw 32-bit value for word {idx}.")],
        ))
    return peripheral


def lvds_peripheral(entry: SlaveEntry, group: str, info: ModuleInfo | None) -> ET.Element:
    legacy_svd = REPO_ROOT / "mu3e_lvds_controller/lvds_rx_controller_pro.svd"
    desc = (
        "Datapath-local slave expanded below the SC-hub mm_bridge.s0 aperture. "
        f"Qsys slave {entry.slave} is SC-hub-relative at {h(entry.base)} with "
        f"compiled aperture size {h(entry.size)}. {version_summary(info)} "
        "The Qsys module version is the normalized LVDS IP release; Qsys shows "
        "BUILD=1286 and VERSION_DATE=539362566 because the Tcl build supplied "
        "hex literals BUILD=0x506 and VERSION_DATE=0x20260506. "
        f"Standalone source SVD {rel(legacy_svd)} version {source_svd_version(legacy_svd)} "
        "is generated from the same current SV RTL map. This system SVD emits the "
        "LVDS peripheral directly from mu3e_lvds_controller/rtl/mu3e_lvds_controller.sv "
        "so the SC-hub-specific Qsys version and address notes stay local to the grouped map."
    )
    peripheral = peripheral_shell(entry.slave, entry.base, entry.size, group, desc)
    regs = peripheral.find("registers")
    assert regs is not None
    regs.extend([
        register("UID", 0x00, "read-only", "Software-visible LVDS controller UID. Default ASCII \"LVDS\" (0x4C564453).",
                 [field("value", 0, 32, "read-only", "Compile-time or integration-time LVDS UID word.")], 0x4C564453),
        register("META", 0x04, "read-write", "Read-multiplexed metadata word. Write page[1:0] before reading back: 0=VERSION, 1=VERSION_DATE, 2=VERSION_GIT, 3=INSTANCE_ID.",
                 [field("page", 0, 2, "read-write", "Selects the metadata read page."),
                  field("reserved", 2, 30, "read-only", "Reserved, read as zero.")]),
        register("CAPABILITY", 0x08, "read-only", "Packed capability word for the compiled lane/engine/routing profile.",
                 [field("counter_count", 0, 8, "read-only", "Number of per-lane counters exposed through the selected-lane counter window."),
                  field("n_lane", 8, 8, "read-only", "Number of active LVDS lanes after RTL parameter clamping."),
                  field("n_engine", 16, 8, "read-only", "Number of shared decode engines after RTL parameter clamping."),
                  field("score_window_w", 24, 4, "read-only", "Score-window width used by the engine steering score saturators."),
                  field("routing_topology", 28, 4, "read-only", "Compiled routing topology selector.")]),
        register("SYNC_PATTERN", 0x0C, "read-write", "Training/control symbol accepted as the lane synchronization pattern. Writes are accepted only for RTL-recognized K28.5/K28.0/K23.7 encodings.",
                 [field("pattern", 0, 10, "read-write", "10-bit synchronization symbol."),
                  field("reserved", 10, 22, "read-only", "Reserved, read as zero.")]),
        register("LANE_GO", 0x10, "read-write", "Per-lane enable mask, clipped by the compiled active-lane mask.",
                 [field("lane_mask", 0, 32, "read-write", "One bit per physical LVDS lane.")]),
        register("DPA_HOLD", 0x14, "read-write", "Per-lane DPA hold request mask, clipped by the compiled active-lane mask.",
                 [field("lane_mask", 0, 32, "read-write", "One bit per physical LVDS lane.")]),
        register("SOFT_RESET", 0x18, "read-write", "Per-lane soft-reset request latch. Writing 1 requests a lane soft reset; RTL clears the bit after the hold interval completes.",
                 [field("lane_mask", 0, 32, "read-write", "One bit per physical LVDS lane.")]),
        register("MODE_MASK", 0x1C, "read-write", "Global two-bit lane mode in the current RTL. The full word is stored, but lane_mode() currently consumes bits [1:0].",
                 [field("mode", 0, 2, "read-write", "0=bitslipping, 1=adapting, 2=autoing."),
                  field("reserved_storage", 2, 30, "read-write", "Stored by RTL for future per-lane mode expansion; currently not decoded by lane_mode().")]),
        register("SCORE_ACCEPT", 0x20, "read-write", "Engine steering accept threshold, clamped by the RTL score window.",
                 [field("threshold", 0, 16, "read-write", "Accept threshold."),
                  field("reserved", 16, 16, "read-only", "Reserved, read as zero.")]),
        register("SCORE_REJECT", 0x24, "read-write", "Engine steering reject threshold, clamped not to exceed SCORE_ACCEPT.",
                 [field("threshold", 0, 16, "read-write", "Reject threshold."),
                  field("reserved", 16, 16, "read-only", "Reserved, read as zero.")]),
        register("STEER_STATUS", 0x28, "read-only", "Snapshot status from the data-clock steering queue. This read may wait while the control clock requests the data-clock snapshot.",
                 [field("steer_queue_count", 0, 6, "read-only", "Current queued engine-steering decisions."),
                  field("reserved", 6, 10, "read-only", "Reserved, read as zero."),
                  field("steer_overflow_count_low", 16, 16, "read-only", "Low 16 bits of the saturating steering-queue overflow counter.")]),
        register("LANE_SELECT", 0x40, "read-write", "Selected lane for the counter snapshot window. Writes above the last active lane clamp to the last active lane.",
                 [field("lane", 0, 6, "read-write", "Zero-based lane index for counter snapshot reads."),
                  field("reserved", 6, 26, "read-only", "Reserved, read as zero.")]),
    ])
    counter_names = [
        ("CODE_VIOLATIONS", "Illegal or unexpected 8b/10b symbol events observed on the selected lane."),
        ("DISP_VIOLATIONS", "Disparity violation events observed on the selected lane."),
        ("COMMA_LOSSES", "Selected-lane comma/sync-pattern loss events."),
        ("BITSLIP_EVENTS", "Selected-lane bitslip control events."),
        ("DPA_UNLOCKS", "Selected-lane DPA unlock events."),
        ("REALIGNS", "Selected-lane realignment events."),
        ("SCORE_CHANGES", "Selected-lane engine-score change events."),
        ("ENGINE_STEER", "Selected-lane engine steering decisions."),
        ("SOFT_RESETS", "Selected-lane soft-reset completions."),
        ("UPTIME", "Selected-lane uptime counter in data-clock cycles."),
    ]
    for idx, (name, description) in enumerate(counter_names):
        regs.append(register(
            name,
            0x44 + idx * 4,
            "read-only",
            description + " The lane is selected by LANE_SELECT and the value is returned through the RTL snapshot path.",
            [field("value", 0, 32, "read-only", "Selected-lane saturating counter value.")],
        ))
    return peripheral


def arb_peripheral(entry: SlaveEntry, group: str, info: ModuleInfo | None) -> ET.Element:
    desc = (
        f"{description_prefix(entry, info, None)} This peripheral is generated from "
        "misc/arb_hit_type0/rtl/arb_hit_type0_csr.sv and the per-lane Qsys child "
        "instances in arb_hit_type0_supercore.qsys; no standalone source SVD was present."
    )
    peripheral = peripheral_shell(entry.slave, entry.base, entry.size, group, desc)
    regs = peripheral.find("registers")
    assert regs is not None
    regs.extend([
        register("UID", 0x00, "read-only", "Software-visible hit-type0 arbiter UID. Default ASCII \"AHT0\" (0x41485430).",
                 [field("value", 0, 32, "read-only", "Compile-time or integration-time UID word.")], 0x41485430),
        register("META", 0x04, "read-write", "Read-multiplexed metadata word. Write page[1:0] before reading back: 0=VERSION, 1=VERSION_DATE, 2=VERSION_GIT, 3=INSTANCE_ID.",
                 [field("page", 0, 2, "read-write", "Selects the metadata read page."),
                  field("reserved", 2, 30, "read-only", "Reserved, read as zero.")]),
        register("CONTROL", 0x08, "read-write", "Mode request and write-one clear controls.",
                 [field("mode", 0, 2, "read-write", "0=real source, 1=emulator source, 2=mixed round-robin; 3 is reserved and sanitizes to real mode."),
                  field("clear_counters", 2, 1, "read-write", "Write 1 to clear hit/frame/drop counters and high-word snapshots."),
                  field("clear_sticky", 3, 1, "read-write", "Write 1 to clear sticky status bits."),
                  field("clear_error_counters", 4, 1, "read-write", "Write 1 to clear protocol and drop-mid-packet error counters."),
                  field("clear_syndromes", 5, 1, "read-write", "Write 1 to clear captured syndrome words."),
                  field("reserved", 6, 26, "read-only", "Reserved, read as zero.")]),
        register("STATUS", 0x0C, "read-only", "Live source, FIFO, mode, sticky-error, watchdog, and run-state summary.",
                 [field("mode", 0, 2, "read-only", "Committed source selection mode."),
                  field("mode_pending", 2, 2, "read-only", "Requested source selection mode waiting for commit."),
                  field("merged_open", 4, 1, "read-only", "Merged egress packet is currently open."),
                  field("real_source_open", 5, 1, "read-only", "Real-source packet is open on egress."),
                  field("emu_source_open", 6, 1, "read-only", "Emulator-source packet is open on egress."),
                  field("real_full", 7, 1, "read-only", "Real-source FIFO full."),
                  field("real_empty", 8, 1, "read-only", "Real-source FIFO empty."),
                  field("emu_full", 9, 1, "read-only", "Emulator-source FIFO full."),
                  field("emu_empty", 10, 1, "read-only", "Emulator-source FIFO empty."),
                  field("last_grant", 11, 1, "read-only", "Last round-robin grant source."),
                  field("partial_packet_drop_sticky", 12, 1, "read-only", "Sticky flag for a drop while an ingress packet was open."),
                  field("mode_reserved_seen", 13, 1, "read-only", "Sticky flag that software requested reserved mode 3."),
                  field("protocol_violation_sticky", 14, 1, "read-only", "Sticky protocol violation flag."),
                  field("drop_mid_packet_sticky", 15, 1, "read-only", "Sticky mid-packet drop flag."),
                  field("watchdog_synthesized_real", 16, 1, "read-only", "Real-source watchdog synthesized a frame boundary."),
                  field("watchdog_synthesized_emu", 17, 1, "read-only", "Emulator-source watchdog synthesized a frame boundary."),
                  field("run_state", 18, 3, "read-only", "Run-control state sampled by the arbiter."),
                  field("reserved", 21, 11, "read-only", "Reserved, read as zero.")]),
        register("WATCHDOG_CYCLES", 0x10, "read-write", "Frame-boundary watchdog threshold in clock cycles.",
                 [field("cycles", 0, 16, "read-write", "Watchdog threshold."),
                  field("reserved", 16, 16, "read-only", "Reserved, read as zero.")]),
        register("WATCHDOG_STATUS", 0x14, "read-only", "Current source idle counters used by the watchdog.",
                 [field("real_idle_cycles", 0, 16, "read-only", "Real-source idle-cycle count."),
                  field("emu_idle_cycles", 16, 16, "read-only", "Emulator-source idle-cycle count.")]),
        register("ERROR_COUNT_PROTOCOL", 0x18, "read-only", "Saturating protocol-event counter.",
                 [field("value", 0, 32, "read-only", "Protocol error count.")]),
        register("ERROR_COUNT_DROP_MID_PACKET", 0x1C, "read-only", "Saturating mid-packet-drop event counter.",
                 [field("value", 0, 32, "read-only", "Drop-mid-packet error count.")]),
        register("SYNDROME_PROTOCOL", 0x20, "read-only", "First captured protocol-event syndrome until cleared.",
                 [field("source_channel", 0, 4, "read-only", "Channel on the selected source."),
                  field("source_emu", 4, 1, "read-only", "1 when the syndrome came from the emulator source."),
                  field("prior_real_open", 5, 1, "read-only", "Real-source open state before the event."),
                  field("prior_emu_open", 6, 1, "read-only", "Emulator-source open state before the event."),
                  field("beat_sop", 7, 1, "read-only", "Start-of-packet sideband on the selected beat."),
                  field("beat_eop", 8, 1, "read-only", "End-of-packet sideband on the selected beat."),
                  field("beat_error", 9, 3, "read-only", "Avalon-ST error sideband on the selected beat."),
                  field("run_state", 12, 3, "read-only", "Run-control state at capture."),
                  field("reserved", 15, 17, "read-only", "Reserved, read as zero.")]),
        register("SYNDROME_DROP_MID_PACKET", 0x24, "read-only", "First captured mid-packet-drop syndrome until cleared.",
                 [field("source_channel", 0, 4, "read-only", "Ingress source channel."),
                  field("source_emu", 4, 1, "read-only", "1 when the syndrome came from the emulator source."),
                  field("fifo_depth", 5, 5, "read-only", "Source FIFO depth at capture."),
                  field("source_open", 10, 1, "read-only", "Source egress-open state at capture."),
                  field("beat_error", 11, 3, "read-only", "Avalon-ST error sideband at capture."),
                  field("run_state", 14, 3, "read-only", "Run-control state at capture."),
                  field("reserved", 17, 15, "read-only", "Reserved, read as zero.")]),
    ])
    counters = [
        ("INGRESS_REAL_HITS", 0x28, "Accepted real-source hit beats."),
        ("INGRESS_EMU_HITS", 0x30, "Accepted emulator-source hit beats."),
        ("DROPS_REAL", 0x38, "Dropped real-source beats."),
        ("DROPS_EMU", 0x40, "Dropped emulator-source beats."),
        ("EGRESS_REAL_HITS", 0x48, "Granted real-source egress hit beats, excluding synthesized frames."),
        ("EGRESS_EMU_HITS", 0x50, "Granted emulator-source egress hit beats, excluding synthesized frames."),
        ("INGRESS_REAL_FRAMES", 0x58, "Accepted real-source frame boundaries."),
        ("INGRESS_EMU_FRAMES", 0x60, "Accepted emulator-source frame boundaries."),
        ("EGRESS_REAL_FRAMES", 0x68, "Real-source egress frame boundaries."),
        ("EGRESS_EMU_FRAMES", 0x70, "Emulator-source egress frame boundaries."),
    ]
    for name, offset, description in counters:
        regs.append(register(
            name + "_LO",
            offset,
            "read-only",
            description + " Reading the low word snapshots the matching high word into the following HI_SNAPSHOT register.",
            [field("low", 0, 32, "read-only", "Low 32 bits of the saturating 64-bit counter.")],
        ))
        regs.append(register(
            name + "_HI_SNAPSHOT",
            offset + 4,
            "read-only",
            "High 32-bit snapshot captured by the preceding low-word counter read.",
            [field("high", 0, 32, "read-only", "Snapshot high 32 bits of the saturating 64-bit counter.")],
        ))
    return peripheral


def build_entries() -> tuple[list[SlaveEntry], int, int]:
    control_root = parse_qsys(CONTROL_QSYS)
    top_root = parse_qsys(TOP_QSYS)
    mm_bridge_base = find_base(control_root, "sc_hub_cmd_pipe.m0", "mm_bridge.s0")
    upload_bridge_base = find_base(control_root, "sc_hub_cmd_pipe.m0", "upload_mm_bridge.s0")
    entries: list[SlaveEntry] = []

    for slave, base in control_slaves(control_root):
        if slave in {"mm_bridge.s0", "upload_mm_bridge.s0"}:
            continue
        source = source_svd_for_slave(slave)
        size = default_size_for_direct(slave, source)
        entries.append(SlaveEntry(slave=slave, base=base, size=size, origin="control"))

    for slave, start, end in qsys_address_map(top_root, "AUTO_AVMM_PORT_ADDRESS_MAP"):
        entries.append(SlaveEntry(slave=slave, base=mm_bridge_base + start, size=end - start, origin="datapath"))

    for slave, start, end in qsys_address_map(top_root, "AUTO_UPLOAD_AVMM_PORT_ADDRESS_MAP"):
        entries.append(SlaveEntry(slave=slave, base=upload_bridge_base + start, size=end - start, origin="upload"))

    entries.sort(key=lambda entry: (entry.base, entry.slave))
    return entries, mm_bridge_base, upload_bridge_base


def raw_note_for_slave(slave: str) -> str:
    if slave in RAW_WINDOWS:
        return RAW_WINDOWS[slave][1]
    if "mts_preprocessor" in slave:
        return "MTS preprocessor CSR window; no local SVD source was present in this worktree."
    if "ring_buffer_cam" in slave:
        return "Hit-stack ring-buffer CAM CSR window; no local system-matching SVD source was present in this worktree."
    if "feb_frame_assembly" in slave:
        return "FEB frame assembly CSR window; no local SVD source was present in this worktree."
    return "No local SVD source was present in this worktree for this compiled slave."


def entry_to_peripheral(entry: SlaveEntry, modules: dict[str, ModuleInfo]) -> ET.Element:
    info = module_info_for_slave(entry.slave, modules)
    group = group_for_slave(entry.slave, entry.origin)

    if "lvds_rx_controller_pro_0.csr" in entry.slave:
        return lvds_peripheral(entry, group, info)
    if "arb_hit_type0_supercore_0_lane_" in entry.slave:
        return arb_peripheral(entry, group, info)

    source = source_svd_for_slave(entry.slave)
    if source is not None:
        return copy_source_peripheral(entry, source, group, info)

    return raw_window(entry, group, info, raw_note_for_slave(entry.slave))


def runctl_versions() -> tuple[str, str]:
    generated = ""
    intended = ""
    if BUILD_TCL.exists():
        match = re.search(r"set\s+runctl_mgmt_host_readyless_version\s+(\S+)", BUILD_TCL.read_text())
        if match:
            intended = match.group(1)
    html = SYN_DIR / "full8lane_type0_system" / "full8lane_type0_system.html"
    if html.exists():
        data = html.read_text(errors="ignore")
        match = re.search(r"upload_subsystem_runctl_mgmt_host_0</b>\s*</a>\s*runctl_mgmt_host\s+([0-9.]+)", data)
        if match:
            generated = match.group(1)
    return generated, intended


def generated_runctl_note() -> str:
    generated, intended = runctl_versions()
    notes: list[str] = []
    if intended:
        notes.append(f"build Tcl runctl_mgmt_host_readyless_version={intended}")
    if generated:
        notes.append(f"generated HTML runctl_mgmt_host={generated}")
    return "; ".join(notes)


def build_device(entries: list[SlaveEntry], mm_bridge_base: int, upload_bridge_base: int) -> ET.Element:
    device = ET.Element(
        "device",
        {
            "schemaVersion": "1.3",
            f"{{{XSI_NS}}}noNamespaceSchemaLocation": "CMSIS-SVD.xsd",
        },
    )
    text(device, "vendor", "Mu3e")
    text(device, "vendorID", "MU3E")
    text(device, "name", "MU3E_FULL8LANE_TYPE0_SYSTEM_SC_HUB")
    text(device, "series", "MU3E_FULL8LANE_TYPE0")
    text(device, "version", "2026.05.06")
    runctl_note = generated_runctl_note()
    runctl_sentence = f" Run-control note: {runctl_note}." if runctl_note else ""
    text(
        device,
        "description",
        "Grouped CMSIS-SVD for the current full8lane type0 Qsys system. "
        "Every peripheral baseAddress is an offset in the SC-hub command address space, "
        "i.e. downstream of sc_hub.hub/sc_hub_cmd_pipe.m0. The datapath-local AUTO_AVMM map "
        f"is expanded below mm_bridge.s0 at {h(mm_bridge_base)}, and the upload AUTO_UPLOAD_AVMM "
        f"map is expanded below upload_mm_bridge.s0 at {h(upload_bridge_base)}. "
        "The JTAG-side sc_hub.csr aperture is intentionally not listed because it is upstream "
        "of the SC-hub command address space. The direct LVDS debug/JTAG master aperture from "
        "build_full8lane_system.tcl is not used for these baseAddress values; the SC-hub LVDS "
        "CSR base is the datapath-local 0x9000 plus the mm_bridge.s0 base."
        + runctl_sentence,
    )
    text(device, "addressUnitBits", 8)
    text(device, "width", 32)
    text(device, "size", 32)
    text(device, "access", "read-write")
    text(device, "resetValue", "0x00000000")
    text(device, "resetMask", "0xFFFFFFFF")

    modules = all_module_info()
    peripherals = ET.SubElement(device, "peripherals")
    for entry in entries:
        peripherals.append(entry_to_peripheral(entry, modules))
    return device


def write_svd(output: Path) -> tuple[int, int]:
    entries, mm_bridge_base, upload_bridge_base = build_entries()
    output.parent.mkdir(parents=True, exist_ok=True)
    device = build_device(entries, mm_bridge_base, upload_bridge_base)
    tree = ET.ElementTree(device)
    ET.indent(tree, space="  ")
    tree.write(output, encoding="UTF-8", xml_declaration=True, short_empty_elements=False)
    return len(entries), sum(len(p.findall("registers/register")) for p in device.findall("peripherals/peripheral"))


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("-o", "--output", type=Path, default=DEFAULT_OUTPUT, help="Output SVD path.")
    args = parser.parse_args(argv)

    count, registers = write_svd(args.output)
    print(f"wrote {args.output} ({count} peripherals, {registers} registers)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
