#!/usr/bin/env python3
"""Generate a SignalTap file for the Phase 4 pre-HSS zero-hit gap.

The byte-stream fix produces post-selected histogram word-counter activity, but
the pre-HSS histogram tap, MTS-visible totals, rbCAM, and HSS counters remain
zero. This tap spans the hardware boundary from emulator byte stream through
decoded-lane, mutrig frame-deassembly/type0, MTS type1, and the histogram
ingress bridge pre path.
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
    "feb_system_v3_data_path_subsystem_decoded_lane_mux_0:decoded_lane_mux_0|"
    "out_valid"
)


@dataclass(frozen=True)
class Probe:
    group: str
    name: str


def add(group: str, probes: list[Probe], *names: str) -> None:
    probes.extend(Probe(group, name) for name in names)


def default_probes() -> list[Probe]:
    dp = DP_PREFIX
    emu0_qsys = f"{dp}emulator_mutrig_qsys_inst:emulator_mutrig_0|"
    emu0_core = f"{emu0_qsys}emulator_mutrig:u_emulator_mutrig|"
    emu0_frontend_run_ctl = f"{emu0_core}frontend_run_ctl:u_frontend_run_ctl|"
    adapter_032 = (
        f"{dp}"
        "feb_system_v3_data_path_subsystem_avalon_st_adapter_032:avalon_st_adapter_032|"
    )
    decoded_mux = (
        f"{dp}"
        "feb_system_v3_data_path_subsystem_decoded_lane_mux_0:decoded_lane_mux_0|"
    )
    decoded_fifo = f"{dp}altera_avalon_sc_fifo:decoded_lane_fifo_0|"
    mutrig_dp = (
        f"{dp}"
        "feb_system_v3_data_path_subsystem_mutrig_datapath_subsystem_0:"
        "mutrig_datapath_subsystem_0|"
    )
    type0_mux = (
        f"{dp}"
        "feb_system_v3_data_path_subsystem_mux_mutrig2processor:mux_mutrig2processor|"
    )
    mts = f"{dp}mts_processor:mts_preprocessor_0|"
    hist_bridge = f"{dp}histogram_ingress_bridge:histogram_ingress_bridge_0|"
    post_cdc = f"{dp}altera_avalon_dc_fifo:hist_post_cdc_0|"

    probes: list[Probe] = [
        Probe("00 clock_reset", f"{dp}feb_system_v3_data_path_subsystem_rst_controller:rst_controller_001|reset_out"),
        Probe("01 run_state", f"{emu0_qsys}asi_ctrl_valid"),
        Probe("01 run_state", f"{emu0_qsys}asi_ctrl_ready"),
        Probe("01 run_state", f"{emu0_qsys}asi_ctrl_data"),
        Probe("01 run_state", f"{emu0_frontend_run_ctl}run_generating"),
        Probe("01 run_state", f"{emu0_frontend_run_ctl}run_draining"),
        Probe("01 run_state", f"{emu0_frontend_run_ctl}frame_rst"),
        Probe("01 run_state", f"{emu0_frontend_run_ctl}emu_rst"),
    ]

    add(
        "02 emulator_tx8b1k",
        probes,
        f"{emu0_qsys}aso_tx8b1k_valid",
        f"{dp}emulator_mutrig_0_tx8b1k_data",
        f"{dp}emulator_mutrig_0_tx8b1k_channel",
        f"{dp}emulator_mutrig_0_tx8b1k_error",
    )
    add(
        "03 byte_adapter_to_mux",
        probes,
        f"{adapter_032}in_0_valid",
        f"{adapter_032}out_0_valid",
        f"{adapter_032}out_0_ready",
        f"{dp}avalon_st_adapter_032_out_0_data",
        f"{dp}avalon_st_adapter_032_out_0_channel",
        f"{dp}avalon_st_adapter_032_out_0_error",
    )
    add(
        "04 decoded_mux_out",
        probes,
        f"{decoded_mux}in1_valid",
        f"{decoded_mux}in1_ready",
        f"{decoded_mux}out_valid",
        f"{decoded_mux}out_ready",
        f"{dp}decoded_lane_mux_0_out_data",
        f"{dp}decoded_lane_mux_0_out_channel",
        f"{dp}decoded_lane_mux_0_out_error",
    )
    add(
        "05 decoded_fifo_out",
        probes,
        f"{decoded_fifo}in_valid",
        f"{decoded_fifo}in_ready",
        f"{decoded_fifo}out_valid",
        f"{decoded_fifo}out_ready",
        f"{dp}decoded_lane_fifo_0_out_data",
        f"{dp}decoded_lane_fifo_0_out_channel",
        f"{dp}decoded_lane_fifo_0_out_error",
    )

    add(
        "06 mutrig_datapath_header",
        probes,
        f"{mutrig_dp}headerinfo_valid",
        f"{dp}mutrig_datapath_subsystem_0_headerinfo_channel",
        f"{dp}mutrig_datapath_subsystem_0_headerinfo_data",
    )
    add(
        "07 mutrig_datapath_type0",
        probes,
        f"{mutrig_dp}hit_type0_out_valid",
        f"{mutrig_dp}hit_type0_out_ready",
        f"{mutrig_dp}hit_type0_out_startofpacket",
        f"{mutrig_dp}hit_type0_out_endofpacket",
        f"{dp}mutrig_datapath_subsystem_0_hit_type0_out_data",
        f"{dp}mutrig_datapath_subsystem_0_hit_type0_out_channel",
        f"{dp}mutrig_datapath_subsystem_0_hit_type0_out_error",
    )
    add(
        "08 mts_input_type0",
        probes,
        f"{type0_mux}out_valid",
        f"{type0_mux}out_ready",
        f"{type0_mux}out_startofpacket",
        f"{type0_mux}out_endofpacket",
        f"{mts}asi_hit_type0_valid",
        f"{mts}asi_hit_type0_ready",
        f"{dp}mux_mutrig2processor_out_data",
        f"{dp}mux_mutrig2processor_out_channel",
        f"{dp}mux_mutrig2processor_out_error",
    )
    add(
        "09 mts_output_type1",
        probes,
        f"{mts}aso_hit_type1_valid",
        f"{mts}aso_hit_type1_ready",
        f"{mts}aso_hit_type1_startofpacket",
        f"{mts}aso_hit_type1_endofpacket",
        f"{dp}mts_preprocessor_0_hit_type1_out_data",
        f"{dp}mts_preprocessor_0_hit_type1_out_channel",
    )
    add(
        "10 hist_pre_out",
        probes,
        f"{hist_bridge}asi_pre_valid",
        f"{hist_bridge}asi_pre_ready",
        f"{hist_bridge}aso_pre_valid",
        f"{hist_bridge}aso_pre_ready",
        f"{hist_bridge}aso_pre_startofpacket",
        f"{hist_bridge}aso_pre_endofpacket",
        f"{dp}histogram_ingress_bridge_0_pre_out_data",
        f"{dp}histogram_ingress_bridge_0_pre_out_channel",
    )
    add(
        "11 hist_fill_out",
        probes,
        f"{hist_bridge}aso_hist_valid",
        f"{hist_bridge}aso_hist_ready",
        f"{hist_bridge}aso_hist_startofpacket",
        f"{hist_bridge}aso_hist_endofpacket",
        f"{dp}histogram_ingress_bridge_0_hist_out_data",
        f"{dp}histogram_ingress_bridge_0_hist_out_channel",
    )
    add(
        "12 post_path_compare",
        probes,
        f"{post_cdc}out_valid",
        f"{post_cdc}out_ready",
        f"{post_cdc}out_startofpacket",
        f"{post_cdc}out_endofpacket",
        f"{dp}hist_post_cdc_0_out_data",
    )

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
