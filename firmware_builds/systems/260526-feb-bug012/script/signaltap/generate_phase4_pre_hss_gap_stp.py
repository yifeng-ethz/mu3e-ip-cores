#!/usr/bin/env python3
"""Generate a SignalTap file for the Phase 4 FEB histogram/rbCAM boundary.

The tapped payload fields use stable instance-port names with bit-expanded
buses. Whole-vector module-port taps pass Node Finder but can be dropped by
Analysis & Synthesis, leaving the post-map SignalTap node tied to GND. The
logical view spans arbiter egress, mux-to-MTS, MTS type1 output, the histogram
ingress selector, the rbCAM hit-stack input, and the post-rbCAM histogram tap.
"""

from __future__ import annotations

import argparse
import datetime as dt
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


QSYS = "feb_system:u_feb_system|feb_system_v3:u_qsys|"
DP_PREFIX = f"{QSYS}feb_system_v3_data_path_subsystem:data_path_subsystem|"
DEFAULT_CLOCK = f"{DP_PREFIX}lvds_outclock_clk"
DEFAULT_TRIGGER = (
    f"{DP_PREFIX}"
    "histogram_ingress_bridge:histogram_ingress_bridge_0|"
    "aso_hist_valid"
)


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
    dp = DP_PREFIX
    arb0 = (
        f"{dp}"
        "feb_system_v3_data_path_subsystem_arb_hit_type0_supercore_0:"
        "arb_hit_type0_supercore_0|selected_out_0_"
    )
    type0_mux = f"{dp}hit_type0_readyless_mux4:mux_mutrig2processor|aso_out_"
    mts_type1 = f"{dp}mts_processor:mts_preprocessor_0|aso_hit_type1_"
    hist_bridge = f"{dp}histogram_ingress_bridge:histogram_ingress_bridge_0|"
    hist_pre = f"{hist_bridge}aso_pre_"
    hist_post = f"{dp}altera_avalon_dc_fifo:hist_post_cdc_0|out_"
    hist_out = f"{hist_bridge}aso_hist_"

    probes: list[Probe] = []

    add(
        "01 arb_selected_out0",
        probes,
        f"{arb0}valid",
        f"{arb0}startofpacket",
        f"{arb0}endofpacket",
        f"{arb0}endofrun",
    )
    add_bus("01 arb_selected_out0 data[44:0]", probes, f"{arb0}data", 44)
    add_bus("01 arb_selected_out0 channel[3:0]", probes, f"{arb0}channel", 3)
    add_bus("01 arb_selected_out0 error[2:0]", probes, f"{arb0}error", 2)

    add(
        "02 mux_to_mts",
        probes,
        f"{type0_mux}valid",
        f"{type0_mux}startofpacket",
        f"{type0_mux}endofpacket",
        f"{type0_mux}endofrun",
    )
    add_bus("02 mux_to_mts data[44:0]", probes, f"{type0_mux}data", 44)
    add_bus("02 mux_to_mts channel[5:0]", probes, f"{type0_mux}channel", 5)
    add_bus("02 mux_to_mts error[2:0]", probes, f"{type0_mux}error", 2)

    add(
        "03 mts_type1_to_hist_pre",
        probes,
        f"{mts_type1}valid",
        f"{mts_type1}ready",
        f"{mts_type1}startofpacket",
        f"{mts_type1}endofpacket",
        f"{mts_type1}error",
        f"{mts_type1}empty",
    )
    add_bus("03 mts_type1_to_hist_pre data[38:0]", probes, f"{mts_type1}data", 38)
    add_bus("03 mts_type1_to_hist_pre channel[3:0]", probes, f"{mts_type1}channel", 3)

    add(
        "04 hist_pre_to_rbcam",
        probes,
        f"{hist_pre}valid",
        f"{hist_pre}ready",
        f"{hist_pre}startofpacket",
        f"{hist_pre}endofpacket",
        f"{hist_pre}error",
        f"{hist_pre}empty",
    )
    add_bus("04 hist_pre_to_rbcam data[38:0]", probes, f"{hist_pre}data", 38)
    add_bus("04 hist_pre_to_rbcam channel[3:0]", probes, f"{hist_pre}channel", 3)

    add(
        "05 post_rbcam_to_hist",
        probes,
        f"{hist_post}valid",
        f"{hist_post}ready",
        f"{hist_post}startofpacket",
        f"{hist_post}endofpacket",
    )
    add_bus("05 post_rbcam_to_hist data[35:0]", probes, f"{hist_post}data", 35)

    add(
        "06 hist_selector_out",
        probes,
        f"{hist_out}valid",
        f"{hist_out}ready",
        f"{hist_out}startofpacket",
        f"{hist_out}endofpacket",
    )
    add_bus("06 hist_selector_out data[38:0]", probes, f"{hist_out}data", 38)
    add_bus("06 hist_selector_out channel[3:0]", probes, f"{hist_out}channel", 3)

    return probes


def add_single(parent: ET.Element, attribute: str, value: str) -> None:
    ET.SubElement(parent, "single", {"attribute": attribute, "value": value})


def add_multi(parent: ET.Element, attribute: str, size: str, value: str) -> None:
    ET.SubElement(parent, "multi", {"attribute": attribute, "size": size, "value": value})


def infer_type(name: str) -> str:
    if "[" in name and "]" in name:
        return "unknown"
    return "unknown"


def build_stp(sample_depth: int, trigger_signal: str, trigger_mode: str) -> ET.ElementTree:
    stamp = dt.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")
    signal_set_name = "phase4_pre_hss_gap"
    trigger_name = "decoded_mux_valid_rise" if trigger_mode == "rising_edge" else "decoded_mux_valid_high"
    probes = default_probes()
    signals = [probe.name for probe in probes]

    root = ET.Element("session", {"sof_file": ""})

    display_tree = ET.SubElement(root, "display_tree", {"gui_logging_enabled": "0"})
    ET.SubElement(
        display_tree,
        "display_branch",
        {
            "instance": "phase4_pre_hss_gap_lvds",
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
            "name": "phase4_pre_hss_gap_lvds",
            "source_file": "sld_signaltap.vhd",
        },
    )
    ET.SubElement(instance, "node_ip_info", {"instance_id": "0", "mfg_id": "110", "node_id": "0", "version": "6"})

    position_info = ET.SubElement(instance, "position_info")
    add_single(position_info, "active tab", "1")
    add_single(position_info, "setup vertical scroll position", "0")
    add_single(position_info, "setup horizontal scroll position", "0")

    signal_set = ET.SubElement(instance, "signal_set", {"name": signal_set_name})
    signal_set.append(ET.Comment(f"Generated {stamp} UTC"))
    signal_set.append(ET.Comment("Validate node names before compile; import with quartus_stp to refresh CRC metadata."))
    ET.SubElement(signal_set, "clock", {"name": DEFAULT_CLOCK, "polarity": "posedge", "tap_mode": "classic"})
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
    ET.SubElement(trigger, "power_up_trigger", {"position": "pre", "storage_qualifier_disabled": "no"})
    events = ET.SubElement(trigger, "events", {"use_custom_flow_control": "no"})
    level = ET.SubElement(events, "level", {"enabled": "yes", "name": "condition1", "type": "basic"})
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
    parser.add_argument("--trigger-signal", default=DEFAULT_TRIGGER, help="SignalTap trigger signal name")
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
