#!/usr/bin/env python3
"""Generate SignalTap files for staged pipe SC debug.

The full view proves whether SWB slow-control words reach the Firefly receive
path, cross the 156->125 CDC bridge, and enter sc_hub. Smaller modes keep the
first hardware pass timing-clean while isolating hub/Merlin or ingress issues.
"""

from __future__ import annotations

import argparse
import datetime as dt
import xml.etree.ElementTree as ET
from pathlib import Path


TOP = "feb_system:u_feb_system|"
XCVR = f"{TOP}firefly_xcvr_subsystem:u_firefly_xcvr|"
XCVR_NATIVE = f"{XCVR}ip_altera_xcvr_native_av:u_xcvr_native|"
XCVR_MON = f"{XCVR}firefly_reg_mapping:u_firefly_monitor|"
CDC = f"{TOP}sc_downlink_cdc_bridge:u_sc_downlink_cdc|"
QSYS = f"{TOP}feb_system_v3_pipe:u_qsys|"
CP = f"{QSYS}feb_system_v3_pipe_control_path_subsystem:control_path_subsystem|"
HUB = f"{CP}sc_hub_top:sc_hub|"
PKTRX = f"{HUB}sc_hub_pkt_rx:pkt_rx_inst|"
MM2 = f"{CP}feb_system_v3_pipe_control_path_subsystem_mm_interconnect_2:mm_interconnect_2|"


def bits(prefix: str, name: str, width: int) -> list[str]:
    return [f"{prefix}{name}[{idx}]" for idx in range(width)]


def matrix_bits(prefix: str, name: str, outer: int, inner: int) -> list[str]:
    return [f"{prefix}{name}[{lane}][{bit}]" for lane in range(outer) for bit in range(inner)]


def signals_156() -> list[str]:
    sigs: list[str] = []
    sigs += bits(XCVR_MON, "i_rx_locked", 4)
    sigs += bits(XCVR_MON, "i_rx_ready", 4)
    sigs += bits(XCVR_NATIVE, "rx_is_lockedtodata", 4)
    sigs += matrix_bits(XCVR_MON, "i_rx_syncstatus", 4, 4)
    sigs += matrix_bits(XCVR_MON, "i_rx_errDetect", 4, 4)
    sigs += matrix_bits(XCVR_MON, "i_rx_disperr", 4, 4)
    sigs += bits(CDC, "i_in_data", 32)
    sigs += bits(CDC, "i_in_datak", 4)
    sigs += [
        f"{CDC}fifo_wrreq",
        f"{CDC}fifo_reset_n",
    ]
    return sigs


def signals_156_lite() -> list[str]:
    sigs: list[str] = []
    sigs += bits(XCVR_MON, "i_rx_locked", 4)
    sigs += bits(XCVR_MON, "i_rx_ready", 4)
    sigs += bits(XCVR_NATIVE, "rx_is_lockedtodata", 4)
    sigs += bits(CDC, "i_in_datak", 4)
    sigs += [
        f"{CDC}fifo_wrreq",
        f"{CDC}fifo_reset_n",
    ]
    return sigs


def signals_125() -> list[str]:
    sigs: list[str] = []
    sigs += [
        f"{CDC}i_out_ready",
        f"{CDC}fifo_rdreq",
        f"{CDC}out_valid",
    ]
    sigs += bits(CDC, "out_data", 32)
    sigs += bits(CDC, "out_datak", 4)
    sigs += bits(HUB, "i_download_data", 32)
    sigs += bits(HUB, "i_download_datak", 4)
    sigs += [
        f"{HUB}o_download_ready",
        f"{PKTRX}o_download_ready",
        f"{PKTRX}pkt_has_download_words_reg",
        f"{MM2}sc_hub_hub_read",
        f"{MM2}sc_hub_hub_write",
        f"{MM2}sc_hub_hub_readdatavalid",
        f"{MM2}sc_hub_hub_waitrequest",
        f"{MM2}sc_hub_hub_writeresponsevalid",
        f"{MM2}sc_hub_hub_response[0]",
        f"{MM2}sc_hub_hub_response[1]",
    ]
    return sigs


def mode_instances(mode: str, sample_depth: int) -> list[dict[str, object]]:
    if mode == "full":
        return [
            {
                "instance_name": "pipe_sc_156",
                "instance_id": 0,
                "signal_set_name": "pipe_sc_156",
                "trigger_name": "sc_156_fifo_wrreq",
                "clock_name": f"{CDC}i_in_clk",
                "sample_depth": sample_depth,
                "signal_names": signals_156(),
                "trigger_signal": f"{CDC}fifo_wrreq",
            },
            {
                "instance_name": "pipe_sc_125",
                "instance_id": 1,
                "signal_set_name": "pipe_sc_125",
                "trigger_name": "sc_125_hub_kchar",
                "clock_name": f"{CDC}i_out_clk",
                "sample_depth": sample_depth,
                "signal_names": signals_125(),
                "trigger_signal": f"{HUB}i_download_datak[0]",
            },
        ]
    if mode == "hub125":
        return [
            {
                "instance_name": "pipe_sc_125",
                "instance_id": 0,
                "signal_set_name": "pipe_sc_125",
                "trigger_name": "sc_125_hub_kchar",
                "clock_name": f"{CDC}i_out_clk",
                "sample_depth": sample_depth,
                "signal_names": signals_125(),
                "trigger_signal": f"{HUB}i_download_datak[0]",
            },
        ]
    if mode == "ingress156-lite":
        return [
            {
                "instance_name": "pipe_sc_156_lite",
                "instance_id": 0,
                "signal_set_name": "pipe_sc_156_lite",
                "trigger_name": "sc_156_fifo_wrreq",
                "clock_name": f"{CDC}i_in_clk",
                "sample_depth": sample_depth,
                "signal_names": signals_156_lite(),
                "trigger_signal": f"{CDC}fifo_wrreq",
            },
        ]
    raise ValueError(f"unsupported mode: {mode}")


def add_single(parent: ET.Element, attribute: str, value: str) -> None:
    ET.SubElement(parent, "single", {"attribute": attribute, "value": value})


def add_multi(parent: ET.Element, attribute: str, size: str, value: str) -> None:
    ET.SubElement(parent, "multi", {"attribute": attribute, "size": size, "value": value})


def add_instance(
    root: ET.Element,
    *,
    instance_name: str,
    instance_id: int,
    signal_set_name: str,
    trigger_name: str,
    clock_name: str,
    sample_depth: int,
    signal_names: list[str],
    trigger_signal: str,
) -> None:
    instance = ET.SubElement(
        root,
        "instance",
        {
            "enabled": "true",
            "entity_name": "sld_signaltap",
            "is_auto_node": "yes",
            "name": instance_name,
            "source_file": "sld_signaltap.vhd",
        },
    )
    ET.SubElement(
        instance,
        "node_ip_info",
        {"instance_id": str(instance_id), "mfg_id": "110", "node_id": "0", "version": "6"},
    )

    position_info = ET.SubElement(instance, "position_info")
    add_single(position_info, "active tab", "1")
    add_single(position_info, "setup vertical scroll position", "0")
    add_single(position_info, "setup horizontal scroll position", "0")

    signal_set = ET.SubElement(instance, "signal_set", {"name": signal_set_name})
    signal_set.append(ET.Comment(f"Generated {dt.datetime.utcnow().strftime('%Y/%m/%d %H:%M:%S')} UTC"))
    ET.SubElement(signal_set, "clock", {"name": clock_name, "polarity": "posedge", "tap_mode": "classic"})
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
        for name in signal_names:
            ET.SubElement(vec, "wire", {"name": name, "tap_mode": "classic"})

    presentation = ET.SubElement(signal_set, "presentation")
    unified = ET.SubElement(presentation, "unified_setup_data_view")
    data_view = ET.SubElement(presentation, "data_view")
    setup_view = ET.SubElement(presentation, "setup_view")

    for index, name in enumerate(signal_names):
        common = {
            "duplicate_name_allowed": "false",
            "is_data_input": "true",
            "is_node_valid": "true",
            "is_storage_input": "true",
            "is_trigger_input": "true",
            "name": name,
            "tap_mode": "classic",
            "type": "unknown",
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
    level.text = f"'{trigger_signal}' == high"
    ET.SubElement(level, "power_up", {"enabled": "yes"})
    ET.SubElement(level, "op_node")

    sq_events = ET.SubElement(trigger, "storage_qualifier_events")
    transitional = ET.SubElement(sq_events, "transitional")
    transitional.text = "1" * len(signal_names)
    pwr = ET.SubElement(transitional, "pwr_up_transitional")
    pwr.text = "1" * len(signal_names)
    for _ in range(3):
        sq_level = ET.SubElement(sq_events, "storage_qualifier_level", {"type": "basic"})
        ET.SubElement(sq_level, "power_up")
        ET.SubElement(sq_level, "op_node")


def build_stp(sample_depth: int, mode: str) -> ET.ElementTree:
    root = ET.Element("session", {"sof_file": ""})
    display_tree = ET.SubElement(root, "display_tree", {"gui_logging_enabled": "0"})
    instances = mode_instances(mode, sample_depth)
    for instance in instances:
        ET.SubElement(
            display_tree,
            "display_branch",
            {
                "instance": str(instance["instance_name"]),
                "signal_set": str(instance["signal_set_name"]),
                "trigger": str(instance["trigger_name"]),
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

    for instance in instances:
        add_instance(root, **instance)
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


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True)
    parser.add_argument("--sample-depth", type=int, default=512)
    parser.add_argument(
        "--mode",
        choices=("full", "hub125", "ingress156-lite"),
        default="full",
        help="debug scope to generate",
    )
    args = parser.parse_args()

    tree = build_stp(args.sample_depth, args.mode)
    indent(tree.getroot())

    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="utf-8", xml_declaration=False)
    output.write_text(output.read_text(encoding="utf-8") + "\n", encoding="utf-8")
    print(f"wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
