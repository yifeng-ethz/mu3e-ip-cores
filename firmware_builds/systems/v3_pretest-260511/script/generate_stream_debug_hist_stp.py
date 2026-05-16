#!/usr/bin/env python3
"""Generate the stream-debug histogram-path SignalTap file for feb_system_v3.

This tap follows the bridge-free post-deassembly Type-0 path and the FE
delivery boundary:

    frame parser hit_type0 + emulator hit_type0 -> arb_hit_type0
        -> readyless bank mux -> MTS type1/extended
        -> rbCAM -> feb_frame_assembly -> upload

The probe list deliberately excludes the retired histogram ingress bridge and
the removed decoded-lane source mux. The histogram IP owns extended-port
selection internally through its CONTROL/port CSR state.

This is the synthesis/STP view. It also excludes DEBUG_LEVEL=2 metadata
sidecars; those are simulator-only scoreboard evidence and are forced off in
normal FEB firmware builds.
"""

from __future__ import annotations

import argparse
import datetime as dt
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


QSYS = "feb_system:u_feb_system|feb_system_v3:u_qsys|"
DP_PREFIX = f"{QSYS}feb_system_v3_data_path_subsystem:data_path_subsystem|"
HIST_PREFIX = f"{DP_PREFIX}histogram_statistics_v2:histogram_statistics_0|"
FIREFLY_PREFIX = "feb_system:u_feb_system|firefly_xcvr_subsystem:u_firefly_xcvr|"
DEFAULT_CLOCK = f"{DP_PREFIX}lvds_outclock_clk"
DEFAULT_TRIGGER = f"{DP_PREFIX}dbg_mm2runctrl:dbg_mm2runctrl_0|aso_ctrl_valid"


@dataclass(frozen=True)
class Probe:
    group: str
    name: str


def add(group: str, probes: list[Probe], *names: str) -> None:
    probes.extend(Probe(group, name) for name in names)


def add_bits(group: str, probes: list[Probe], base: str, width: int) -> None:
    probes.extend(Probe(group, f"{base}[{idx}]") for idx in range(width))


def add_bit_range(group: str, probes: list[Probe], base: str, start: int, stop: int) -> None:
    probes.extend(Probe(group, f"{base}[{idx}]") for idx in range(start, stop))


def add_avst_stream36(
    group: str,
    probes: list[Probe],
    base: str,
    *,
    include_ready: bool = True,
    include_packet_flags: bool = True,
) -> None:
    add(group, probes, f"{base}_valid")
    if include_ready:
        add(group, probes, f"{base}_ready")
    if include_packet_flags:
        add(group, probes, f"{base}_startofpacket", f"{base}_endofpacket")
    add_bit_range(group, probes, f"{base}_data", 0, 32)
    add_bit_range(f"{group} datak", probes, f"{base}_data", 32, 36)


def default_probes() -> list[Probe]:
    qsys = QSYS
    dp = DP_PREFIX
    firefly = FIREFLY_PREFIX
    parser0 = (
        f"{dp}"
        "feb_system_v3_data_path_subsystem_mutrig_datapath_subsystem_0:"
        "mutrig_datapath_subsystem_0|"
    )
    parser4 = (
        f"{dp}"
        "feb_system_v3_data_path_subsystem_mutrig_datapath_subsystem_4:"
        "mutrig_datapath_subsystem_4|"
    )
    frcv0 = f"{parser0}frame_rcv_ip:mutrig_frame_deassembly_0|"
    frcv4 = f"{parser4}frame_rcv_ip:mutrig_frame_deassembly_0|"
    emus = [f"{dp}emulator_mutrig_qsys_lane:emulator_mutrig_{idx}|" for idx in range(8)]
    arbs = [f"{dp}arb_hit_type0:arb_hit_type0_{idx}|" for idx in range(8)]
    run_splitter = f"{dp}feb_system_v3_data_path_subsystem_run_control_splitter:run_control_splitter|"
    type0_splitter = (
        f"{dp}"
        "feb_system_v3_data_path_subsystem_run_control_type0_arb_splitter:"
        "run_control_type0_arb_splitter|"
    )
    mux0 = f"{dp}hit_type0_readyless_mux4:mux_mutrig2processor|"
    mux1 = f"{dp}hit_type0_readyless_mux4:mux_mutrig2processor_0|"
    mts0 = f"{dp}mts_processor:mts_preprocessor_0|"
    mts1 = f"{dp}mts_processor:mts_preprocessor_1|"
    hist = HIST_PREFIX
    hit_stacks = [
        (
            "hs0",
            f"{dp}"
            "feb_system_v3_data_path_subsystem_hit_stack_subsystem_0:"
            "hit_stack_subsystem_0|",
        ),
        (
            "hs1",
            f"{dp}"
            "feb_system_v3_data_path_subsystem_hit_stack_subsystem_1:"
            "hit_stack_subsystem_1|",
        ),
    ]

    probes: list[Probe] = []

    add(
        "00 run_control_debug_source",
        probes,
        f"{dp}dbg_mm2runctrl:dbg_mm2runctrl_0|aso_ctrl_valid",
        f"{dp}dbg_mm2runctrl:dbg_mm2runctrl_0|aso_ctrl_ready",
        f"{dp}run_control_mux_out_data",
        f"{dp}run_control_mux_out_valid",
        f"{dp}run_control_mux_out_ready",
        f"{dp}run_control_channel_dropper_out_data",
        f"{dp}run_control_channel_dropper_out_valid",
        f"{dp}run_control_splitter_out0_data",
        f"{dp}run_control_splitter_out1_data",
        f"{dp}run_control_splitter_out2_data",
        f"{dp}run_control_splitter_out12_data",
        f"{dp}run_control_splitter_out14_data",
        f"{dp}run_control_splitter_out14_valid",
        f"{run_splitter}out15_valid",
        f"{dp}run_control_splitter_out15_data",
        f"{dp}run_control_splitter_out15_valid",
        f"{type0_splitter}out0_valid",
        f"{type0_splitter}out1_valid",
        f"{type0_splitter}out5_valid",
        f"{type0_splitter}out1_data",
        f"{frcv0}receiver_go",
    )
    add_bits("00 run_control_debug_source", probes, f"{dp}dbg_mm2runctrl:dbg_mm2runctrl_0|aso_ctrl_data", 9)

    for idx in range(8):
        add(
            "00b generated_run_control_fanout",
            probes,
            f"{dp}emulator_ctrl_splitter_out{idx}_valid",
            f"{dp}emulator_ctrl_splitter_out{idx}_ready",
            f"{dp}emulator_ctrl_splitter_out{idx}_data",
            f"{dp}run_control_type0_arb_splitter_out{idx + 1}_valid",
            f"{dp}run_control_type0_arb_splitter_out{idx + 1}_data",
        )

    add(
        "00c emulator_inject_fanout",
        probes,
        f"{dp}mutrig_injector_0_inject_pulse",
    )
    for idx in range(8):
        add(
            "00c emulator_inject_fanout",
            probes,
            f"{dp}emulator_inject_fanout_out{idx}_pulse",
            f"{dp}emulator_inject_fanout_out{idx}_masked_pulse",
        )

    add(
        "01 post_deassembly_type0",
        probes,
        f"{parser0}decoded_din_valid",
        f"{frcv0}aso_headerinfo_valid",
        f"{frcv0}aso_hit_type0_valid",
        f"{frcv0}aso_hit_type0_endofpacket",
        f"{frcv0}p_new_word",
        f"{frcv0}n_new_word",
        f"{parser0}hit_type0_out_valid",
        f"{parser0}hit_type0_out_startofpacket",
        f"{parser0}hit_type0_out_endofpacket",
        f"{parser0}hit_type0_out_channel",
        f"{parser0}hit_type0_out_data",
        f"{frcv4}receiver_go",
        f"{frcv4}aso_hit_type0_valid",
        f"{parser4}hit_type0_out_valid",
        f"{parser4}hit_type0_out_startofpacket",
        f"{parser4}hit_type0_out_endofpacket",
        f"{parser4}hit_type0_out_channel",
        f"{parser4}hit_type0_out_data",
    )
    add_bits("01 post_deassembly_type0", probes, f"{parser0}decoded_din_data", 9)

    for idx, emu in enumerate(emus):
        add(
            "02 emulator_type0_each",
            probes,
            f"{dp}emulator_mutrig_{idx}_hit_type0_valid",
            f"{dp}emulator_mutrig_{idx}_hit_type0_startofpacket",
            f"{dp}emulator_mutrig_{idx}_hit_type0_endofpacket",
            f"{dp}emulator_mutrig_{idx}_hit_type0_endofrun",
            f"{dp}emulator_mutrig_{idx}_hit_type0_channel",
            f"{dp}emulator_mutrig_{idx}_hit_type0_error",
            f"{dp}emulator_mutrig_{idx}_hit_type0_data",
            f"{emu}aso_tx8b1k_valid",
        )

    for arb in arbs:
        add(
            "03 type0_arb_output_all",
            probes,
            f"{arb}arbiter_egress_valid",
            f"{arb}arbiter_egress_startofpacket",
            f"{arb}arbiter_egress_endofpacket",
            f"{arb}arbiter_egress_endofrun",
            f"{arb}arbiter_egress_channel",
            f"{arb}arbiter_egress_error",
            f"{arb}arbiter_egress_data",
            f"{arb}arbiter_egress_source_emu",
            f"{arb}arbiter_egress_synthesized",
            f"{arb}arbiter_egress_real_frame_pulse",
            f"{arb}arbiter_egress_emu_frame_pulse",
        )

    add(
        "04 mux_mts_type0_boundary",
        probes,
        f"{mux0}aso_out_valid",
        f"{mux0}aso_out_channel",
        f"{mux0}aso_out_data",
        f"{mux0}aso_out_startofpacket",
        f"{mux0}aso_out_endofpacket",
        f"{mux1}aso_out_valid",
        f"{mux1}aso_out_channel",
        f"{mux1}aso_out_data",
        f"{mux1}aso_out_startofpacket",
        f"{mux1}aso_out_endofpacket",
        f"{mts0}asi_hit_type0_accept",
        f"{mts1}asi_hit_type0_accept",
    )

    add(
        "04b mts_type1_to_hitstack",
        probes,
        f"{dp}mts_preprocessor_0_hit_type1_out_valid",
        f"{dp}mts_preprocessor_0_hit_type1_out_ready",
        f"{dp}mts_preprocessor_0_hit_type1_out_startofpacket",
        f"{dp}mts_preprocessor_0_hit_type1_out_endofpacket",
        f"{dp}mts_preprocessor_0_hit_type1_out_empty",
        f"{dp}mts_preprocessor_0_hit_type1_out_channel",
        f"{dp}mts_preprocessor_0_hit_type1_out_error",
        f"{dp}mts_preprocessor_0_hit_type1_out_data",
        f"{dp}mts_preprocessor_1_hit_type1_out_valid",
        f"{dp}mts_preprocessor_1_hit_type1_out_ready",
        f"{dp}mts_preprocessor_1_hit_type1_out_startofpacket",
        f"{dp}mts_preprocessor_1_hit_type1_out_endofpacket",
        f"{dp}mts_preprocessor_1_hit_type1_out_empty",
        f"{dp}mts_preprocessor_1_hit_type1_out_channel",
        f"{dp}mts_preprocessor_1_hit_type1_out_error",
        f"{dp}mts_preprocessor_1_hit_type1_out_data",
    )

    for _stack_name, stack in hit_stacks:
        for cam_idx in range(4):
            pre = f"{stack}data_splitter_0_out{cam_idx}"
            add(
                "05 prerbcam_hit_type1_each",
                probes,
                f"{pre}_valid",
                f"{pre}_ready",
                f"{pre}_startofpacket",
                f"{pre}_endofpacket",
                f"{pre}_empty[0]",
                f"{pre}_channel",
                f"{pre}_error[0]",
                f"{pre}_data",
            )

            post = f"{stack}ring_buffer_cam_{cam_idx}_hit_type2"
            add(
                "06 postrbcam_hit_type2_each",
                probes,
                f"{post}_valid",
                f"{post}_ready",
                f"{post}_startofpacket",
                f"{post}_endofpacket",
                f"{post}_channel",
                f"{post}_error",
                f"{post}_data",
            )

    add_avst_stream36("07a frame_assembly_upper_bank", probes, f"{dp}hit_type3_upper")
    add_avst_stream36("07b frame_assembly_lower_bank", probes, f"{dp}hit_type3_lower")
    add_avst_stream36("07c qsys_upper_export", probes, f"{qsys}data_path_subsystem_hit_type3_upper")
    add_avst_stream36("07d qsys_upload_data1_lower_bank", probes, f"{qsys}upload_data1")
    add_avst_stream36("07e qsys_upload_data0_upper_sc_rc_bank", probes, f"{qsys}upload_data0_sc_rc")
    add_avst_stream36(
        "07f firefly_upload_data1_lower_bank",
        probes,
        f"{firefly}i_upload_data1",
        include_ready=False,
        include_packet_flags=False,
    )
    add_avst_stream36(
        "07g firefly_upload_data0_upper_sc_rc_bank",
        probes,
        f"{firefly}i_upload_data0_sc_rc",
        include_ready=False,
        include_packet_flags=False,
    )

    add(
        "08 mts_to_histogram_ingress",
        probes,
        f"{mts0}aso_hit_type1_extended_0_valid",
        f"{mts1}aso_hit_type1_extended_1_valid",
        f"{hist}asi_hit_type1_extended_0_valid",
        f"{hist}asi_hit_type1_extended_1_valid",
        f"{hist}port_valid[0]",
        f"{hist}port_ready[0]",
        f"{hist}ingress_stage_valid[0]",
        f"{hist}ingress_stage_write_req[0]",
        f"{hist}ingress_stage_valid[1]",
        f"{hist}ingress_stage_write_req[1]",
    )
    add_bits("08 mts_to_histogram_ingress", probes, f"{hist}cfg_in_port", 2)
    add_bit_range("08 mts_to_histogram_ingress", probes, f"{hist}asi_hit_type1_extended_0_data", 17, 39)
    add_bit_range("08 mts_to_histogram_ingress", probes, f"{hist}asi_hit_type1_extended_1_data", 17, 39)

    add(
        "09 histogram_fill_pipeline",
        probes,
        f"{hist}fifo_write[0]",
        f"{hist}fifo_write[1]",
        f"{hist}key_pipe_valid",
        f"{hist}divider_in_valid",
        f"{hist}queue_hit_valid",
    )
    add_bits("09 histogram_fill_pipeline", probes, f"{hist}key_pipe", 32)
    add_bit_range("09 histogram_fill_pipeline", probes, f"{hist}queue_hit_bin", 0, 8)

    add_bits("10 histogram_csr_counters", probes, f"{hist}csr_total_hits", 32)
    add_bit_range("10 histogram_csr_counters", probes, f"{hist}csr_dropped_hits", 0, 16)
    add_bit_range("10 histogram_csr_counters", probes, f"{hist}csr_bank_status", 0, 8)
    add_bit_range("10 histogram_csr_counters", probes, f"{hist}csr_port_status", 0, 24)
    add_bit_range("10 histogram_csr_counters", probes, f"{hist}csr_coal_status", 0, 16)

    return probes


def add_single(parent: ET.Element, attribute: str, value: str) -> None:
    ET.SubElement(parent, "single", {"attribute": attribute, "value": value})


def add_multi(parent: ET.Element, attribute: str, size: str, value: str) -> None:
    ET.SubElement(parent, "multi", {"attribute": attribute, "size": size, "value": value})


def build_stp(sample_depth: int, trigger_signal: str, trigger_mode: str) -> ET.ElementTree:
    stamp = dt.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")
    signal_set_name = "stream_debug_hist_path"
    trigger_name = "run_control_dbg_valid_rise" if trigger_mode == "rising_edge" else "run_control_dbg_valid_high"
    probes = default_probes()
    signals = [probe.name for probe in probes]

    root = ET.Element("session", {"sof_file": ""})
    display_tree = ET.SubElement(root, "display_tree", {"gui_logging_enabled": "0"})
    ET.SubElement(
        display_tree,
        "display_branch",
        {
            "instance": "stream_debug_hist_path_lvds",
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
            "name": "stream_debug_hist_path_lvds",
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
    signal_set.append(
        ET.Comment(
            "Bridge-free FEB histogram path with run-control debug-source probes through mux/dropper/splitter."
        )
    )
    signal_set.append(
        ET.Comment(
            "Frame buses are probed bitwise. For 36-bit streams, data[31:0]=word and data[35:32]=datak; "
            "offline decode classifies K28.5 headers, K23.7 subheaders, hits, and K28.4 trailers."
        )
    )
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
            "type": "unknown",
        }
        ET.SubElement(unified, "node", common)
        net = {**common, "data_index": str(index), "storage_index": str(index), "trigger_index": str(index)}
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
    parser.add_argument("--sample-depth", type=int, default=2048, help="SignalTap sample depth")
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
    tree = build_stp(args.sample_depth, args.trigger_signal, args.trigger_mode)
    indent(tree.getroot())

    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="utf-8", xml_declaration=False)
    output.write_text(output.read_text(encoding="utf-8") + "\n", encoding="utf-8")
    print(f"wrote {output}")
    print(f"probes={len(default_probes())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
