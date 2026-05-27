#!/usr/bin/env python3
"""Generate a minimum-info SignalTap to disambiguate the held-in-reset triplet.

Lesson from first attempt (2026-05-19 11:32): pre-synthesis-valid probes get
optimized away when they are mm_interconnect-side wires. Quartus flattens the
Qsys interconnect and only slave-side ports / state registers / readdata regs
survive. All 34 probes from v1 landed at `held_in_reset_triplet|gnd|vcc`
post-fit (confirmed in map.rpt's "Connections to In-System Debugging Instance"
table).

This v2 selects probes from the `post_synthesis` observable list:
- mutrig_injector_0 internal state regs: `header_injector.RESETTING`,
  `random_injector.RESETTING` (= 1 while held in reset, = 0 when running)
- mutrig_injector_0 slave-port readdata: `avs_csr_readdata[0..7]`
- histogram_statistics_0 reset trace: `gts_reset_reg`, `stats_reset_pulse_d1`
- histogram_statistics_0 readdata reg: `csr_readdata_reg[0..7]`
- mu3e_lvds_controller_0 inner core readdata (sanity): `avs_csr_readdata[0..7]`
- rst_controller_001 final synchronizer output: `int_chain_out`

Sample clock: `monitor_clock_125_in_clk` (the only LVDS-independent clock at
data_path_subsystem boundary).

Trigger: rising edge of LVDS-core readdata[0] - LVDS CSR is known-working, so
this fires reliably during sc_tool polling, giving us a 1024-sample window in
which to observe whether mutrig_injector_0 and histogram_statistics_0 ever
update (i.e. whether they ever come out of reset).
"""

from __future__ import annotations

import argparse
import datetime as dt
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


QSYS = "feb_system:u_feb_system|feb_system_v4:u_qsys|"
DP_PREFIX = f"{QSYS}feb_system_v4_data_path_subsystem:data_path_subsystem|"

# Slave-instance prefixes - these survive Qsys flattening because they are
# inside the IP module proper (not the mm_interconnect wrapper).
INJ_PREFIX = f"{DP_PREFIX}mutrig_injector_multiheader:mutrig_injector_0|"
HIST_PREFIX = f"{DP_PREFIX}histogram_statistics_v2:histogram_statistics_0|"
LVDS_CORE_PREFIX = (
    f"{DP_PREFIX}feb_system_v4_data_path_subsystem_mu3e_lvds_controller_0:"
    f"mu3e_lvds_controller_0|mu3e_lvds_controller_phy_adapter:core|"
    f"mu3e_lvds_controller:u_core|"
)
RST_001_SYNC = (
    f"{DP_PREFIX}altera_reset_controller:rst_controller_001|"
    f"altera_reset_synchronizer:alt_rst_sync_uq1|"
)

DEFAULT_CLOCK = f"{DP_PREFIX}monitor_clock_125_in_clk"
DEFAULT_TRIGGER = f"{LVDS_CORE_PREFIX}avs_csr_readdata[0]"


@dataclass(frozen=True)
class Probe:
    group: str
    name: str


def add(group: str, probes: list[Probe], *names: str) -> None:
    probes.extend(Probe(group, name) for name in names)


def add_bus(group: str, probes: list[Probe], stem: str, high: int, low: int = 0) -> None:
    for bit in range(low, high + 1):
        probes.append(Probe(group, f"{stem}[{bit}]"))


def default_probes() -> list[Probe]:
    probes: list[Probe] = []

    # Group 00 - Reset state (the primary disambiguator). RESETTING == 1
    # confirms the injector is held in reset by rst_controller_001 (clocked
    # by outclock_clk). If outclock is dead, these never go to 0.
    add(
        "00 reset_state",
        probes,
        f"{INJ_PREFIX}header_injector.RESETTING",
        f"{INJ_PREFIX}random_injector.RESETTING",
        f"{HIST_PREFIX}gts_reset_reg~0",
        f"{HIST_PREFIX}stats_reset_pulse_d1",
        f"{RST_001_SYNC}altera_reset_synchronizer_int_chain_out",
    )

    # Group 01 - LVDS CSR readdata (sanity; known-working slave on bench).
    # Used as the trigger source: rising edge of bit[0] fires on each LVDS
    # CSR read, giving a 1024-sample window to observe the suspect IPs.
    add_bus(
        "01 lvds_core_readdata[7:0]",
        probes,
        f"{LVDS_CORE_PREFIX}avs_csr_readdata",
        7,
    )

    # Group 02 - Injector CSR readdata (suspect). Stuck at 0 across all
    # accesses on the previous build's bench probing.
    add_bus(
        "02 injector_readdata[7:0]",
        probes,
        f"{INJ_PREFIX}avs_csr_readdata",
        7,
    )

    # Group 03 - Histogram CSR readdata (suspect). Same symptom as injector.
    add_bus(
        "03 hist_readdata[7:0]",
        probes,
        f"{HIST_PREFIX}csr_readdata_reg",
        7,
    )

    return probes


def add_single(parent: ET.Element, attribute: str, value: str) -> None:
    ET.SubElement(parent, "single", {"attribute": attribute, "value": value})


def add_multi(parent: ET.Element, attribute: str, size: str, value: str) -> None:
    ET.SubElement(parent, "multi", {"attribute": attribute, "size": size, "value": value})


def infer_type(name: str) -> str:
    return "unknown"


def build_stp(sample_depth: int, trigger_signal: str, trigger_mode: str) -> ET.ElementTree:
    stamp = dt.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")
    signal_set_name = "held_in_reset_triplet"
    trigger_name = (
        "lvds_readdata0_rise"
        if trigger_mode == "rising_edge"
        else "lvds_readdata0_high"
    )
    probes = default_probes()
    signals = [probe.name for probe in probes]

    root = ET.Element("session", {"sof_file": ""})

    display_tree = ET.SubElement(root, "display_tree", {"gui_logging_enabled": "0"})
    ET.SubElement(
        display_tree,
        "display_branch",
        {
            "instance": signal_set_name,
            "signal_set": signal_set_name,
            "trigger": trigger_name,
        },
    )

    global_info = ET.SubElement(root, "global_info")
    add_single(global_info, "active instance", "0")
    add_single(global_info, "lock mode", "0")
    add_multi(global_info, "frame size", "2", "1680,981")
    add_single(global_info, "jtag widget visible", "1")
    add_multi(global_info, "jtag widget size", "2", "398,160")
    add_single(global_info, "instance widget visible", "1")
    add_single(global_info, "config widget visible", "1")
    add_single(global_info, "hierarchy widget visible", "1")
    add_single(global_info, "data log widget visible", "1")

    instance = ET.SubElement(
        root,
        "instance",
        {
            "enabled": "true",
            "entity_name": "sld_signaltap",
            "is_auto_node": "yes",
            "name": signal_set_name,
            "source_file": "sld_signaltap.vhd",
        },
    )
    ET.SubElement(
        instance,
        "node_ip_info",
        {"instance_id": "0", "mfg_id": "110", "node_id": "0", "version": "6"},
    )

    position_info = ET.SubElement(instance, "position_info")
    add_single(position_info, "active tab", "1")
    add_single(position_info, "setup vertical scroll position", "0")
    add_single(position_info, "setup horizontal scroll position", "0")

    signal_set = ET.SubElement(instance, "signal_set", {"name": signal_set_name})
    signal_set.append(ET.Comment(f"Generated {stamp} UTC"))
    signal_set.append(
        ET.Comment(
            "Probes validated against post_synthesis Node Finder observable list."
        )
    )
    ET.SubElement(
        signal_set,
        "clock",
        {"name": DEFAULT_CLOCK, "polarity": "posedge", "tap_mode": "classic"},
    )
    ET.SubElement(
        signal_set,
        "config",
        {
            "pipeline_level": "0",
            "ram_type": "AUTO",
            "reserved_data_nodes": "0",
            "reserved_storage_qualifier_nodes": "0",
            "reserved_trigger_nodes": "0",
            "sample_depth": str(sample_depth),
            "trigger_in_enable": "no",
            "trigger_out_enable": "no",
        },
    )
    ET.SubElement(signal_set, "top_entity")

    signal_vec = ET.SubElement(signal_set, "signal_vec")
    for vec_name in ("trigger_input_vec", "data_input_vec", "storage_qualifier_input_vec"):
        vec = ET.SubElement(signal_vec, vec_name)
        for name in signals:
            ET.SubElement(vec, "wire", {"name": name, "tap_mode": "classic"})

    presentation = ET.SubElement(signal_set, "presentation")
    unified = ET.SubElement(presentation, "unified_setup_data_view")
    data_view = ET.SubElement(presentation, "data_view")
    setup_view = ET.SubElement(presentation, "setup_view")

    last_group = None
    for index, probe in enumerate(probes):
        if probe.group != last_group:
            ET.SubElement(unified, "divider", {"name": probe.group})
            ET.SubElement(data_view, "divider", {"name": probe.group})
            ET.SubElement(setup_view, "divider", {"name": probe.group})
            last_group = probe.group

        common = {
            "duplicate_name_allowed": "false",
            "is_data_input": "true",
            "is_node_valid": "true",
            "is_storage_input": "true",
            "is_trigger_input": "true",
            "name": probe.name,
            "tap_mode": "classic",
            "type": infer_type(probe.name),
        }
        ET.SubElement(unified, "node", common)

        net = {
            **common,
            "data_index": str(index),
            "storage_index": str(index),
            "trigger_index": str(index),
        }
        ET.SubElement(data_view, "net", net)
        ET.SubElement(setup_view, "net", net)

    ET.SubElement(presentation, "trigger_in_editor")
    ET.SubElement(presentation, "trigger_out_editor")

    trigger = ET.SubElement(
        signal_set,
        "trigger",
        {
            "attribute_mem_mode": "false",
            "gap_record": "true",
            "name": trigger_name,
            "position": "pre",
            "power_up_trigger_mode": "false",
            "record_data_gap": "true",
            "segment_size": "1",
            "storage_mode": "off",
            "storage_qualifier_disabled": "no",
            "storage_qualifier_port_is_pin": "true",
            "storage_qualifier_port_name": "auto_stp_external_storage_qualifier",
            "storage_qualifier_port_tap_mode": "classic",
            "trigger_type": "circular",
        },
    )
    ET.SubElement(
        trigger, "power_up_trigger", {"position": "pre", "storage_qualifier_disabled": "no"}
    )
    events = ET.SubElement(trigger, "events", {"use_custom_flow_control": "no"})
    level = ET.SubElement(
        events, "level", {"enabled": "yes", "name": "condition1", "type": "basic"}
    )
    if trigger_mode == "rising_edge":
        level.text = f"'{trigger_signal}' == rising edge"
    elif trigger_mode == "high":
        level.text = f"'{trigger_signal}' == high"
    else:
        raise ValueError(f"unsupported trigger_mode: {trigger_mode}")
    ET.SubElement(level, "power_up", {"enabled": "yes"})
    ET.SubElement(level, "op_node")

    sq_events = ET.SubElement(trigger, "storage_qualifier_events")
    transitional = ET.SubElement(sq_events, "transitional")
    transitional.text = "1" * len(signals)
    pwr = ET.SubElement(transitional, "pwr_up_transitional")
    pwr.text = "1" * len(signals)
    for _ in range(3):
        sq_level = ET.SubElement(sq_events, "storage_qualifier_level", {"type": "basic"})
        ET.SubElement(sq_level, "power_up")
        ET.SubElement(sq_level, "op_node")

    ET.SubElement(root, "mnemonics")
    return ET.ElementTree(root)


def indent(elem: ET.Element, level: int = 0) -> None:
    pad = "\n" + "  " * level
    if len(elem):
        if not elem.text or not elem.text.strip():
            elem.text = pad + "  "
        for child in elem:
            indent(child, level + 1)
        if not elem[-1].tail or not elem[-1].tail.strip():
            elem[-1].tail = pad
    if level and (not elem.tail or not elem.tail.strip()):
        elem.tail = pad


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, help="Output .stp path")
    parser.add_argument("--sample-depth", type=int, default=1024, help="SignalTap sample depth")
    parser.add_argument(
        "--trigger-signal",
        default=DEFAULT_TRIGGER,
        help="SignalTap trigger signal name",
    )
    parser.add_argument(
        "--trigger-mode",
        choices=("rising_edge", "high"),
        default="rising_edge",
        help="Trigger expression kind",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    tree = build_stp(
        sample_depth=args.sample_depth,
        trigger_signal=args.trigger_signal,
        trigger_mode=args.trigger_mode,
    )
    indent(tree.getroot())

    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="utf-8", xml_declaration=False)
    output.write_text(output.read_text(encoding="utf-8") + "\n", encoding="utf-8")
    print(f"wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
