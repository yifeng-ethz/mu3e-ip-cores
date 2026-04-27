#!/usr/bin/env python3
"""Generate a narrow SignalTap file for one FEB v3 hit-stack run-control path.

The FEB build is already at 96% ALM usage, so this generator keeps each pass
small and targeted. One compile instruments one hit-stack subsystem only. The
intent is to answer one question per compile:

Where does the 0x001/STOP_RESET-class command stop making forward progress
inside hit_stack_subsystem_{0,1}?
"""

from __future__ import annotations

import argparse
import datetime as dt
import xml.etree.ElementTree as ET
from pathlib import Path


QSYS_PREFIX = "feb_system:u_feb_system|feb_system_v3_pipe:u_qsys|"

DATA_PATH_PREFIX = (
    f"{QSYS_PREFIX}"
    "feb_system_v3_pipe_data_path_subsystem:data_path_subsystem|"
)

UPLOAD_PREFIX = (
    f"{QSYS_PREFIX}"
    "feb_system_v3_pipe_upload_subsystem:upload_subsystem|"
)

DEFAULT_CLOCK = f"{DATA_PATH_PREFIX}lvds_outclock_clk"

TOP_SPLITTER_PREFIX = (
    f"{DATA_PATH_PREFIX}"
    "feb_system_v3_pipe_data_path_subsystem_run_control_splitter:run_control_splitter|"
)

HITSTACK_PREFIX = {
    0: (
        f"{DATA_PATH_PREFIX}"
        "feb_system_v3_pipe_data_path_subsystem_hit_stack_subsystem_0:hit_stack_subsystem_0|"
    ),
    1: (
        f"{DATA_PATH_PREFIX}"
        "feb_system_v3_pipe_data_path_subsystem_hit_stack_subsystem_1:hit_stack_subsystem_1|"
    ),
}

HITSTACK_SPLITTER_PREFIX = {
    0: (
        f"{HITSTACK_PREFIX[0]}"
        "feb_system_v3_pipe_data_path_subsystem_hit_stack_subsystem_0_run_control_splitter_0:"
        "run_control_splitter_0|"
    ),
    1: (
        f"{HITSTACK_PREFIX[1]}"
        "feb_system_v3_pipe_data_path_subsystem_hit_stack_subsystem_1_run_control_splitter_0:"
        "run_control_splitter_0|"
    ),
}

HITSTACK_CDC_PREFIX = {
    0: f"{HITSTACK_PREFIX[0]}altera_avalon_dc_fifo:run_ctrl_cdc_d2x|",
    1: f"{HITSTACK_PREFIX[1]}altera_avalon_dc_fifo:run_ctrl_cdc_d2x|",
}

TOP_SPLITTER_OUTPUT = {
    0: 6,
    1: 14,
}


def default_signals(target: int) -> list[str]:
    signals = [
        f"{UPLOAD_PREFIX}runctl_mgmt_host_valid",
        f"{UPLOAD_PREFIX}runctl_mgmt_host_ready",
    ]
    signals.extend(f"{UPLOAD_PREFIX}runctl_mgmt_host_data[{idx}]" for idx in range(9))

    top_out = TOP_SPLITTER_OUTPUT[target]
    signals.extend(
        [
            f"{TOP_SPLITTER_PREFIX}out{top_out}_valid",
            f"{TOP_SPLITTER_PREFIX}out{top_out}_ready",
        ]
    )

    hitstack_prefix = HITSTACK_PREFIX[target]
    splitter_prefix = HITSTACK_SPLITTER_PREFIX[target]
    cdc_prefix = HITSTACK_CDC_PREFIX[target]
    signals.extend(f"{splitter_prefix}out{idx}_ready" for idx in range(6))
    signals.extend(
        [
            f"{splitter_prefix}out5_valid",
            f"{cdc_prefix}out_valid",
            f"{cdc_prefix}out_ready",
        ]
    )
    return signals


def add_single(parent: ET.Element, attribute: str, value: str) -> None:
    ET.SubElement(parent, "single", {"attribute": attribute, "value": value})


def add_multi(parent: ET.Element, attribute: str, size: str, value: str) -> None:
    ET.SubElement(parent, "multi", {"attribute": attribute, "size": size, "value": value})


def infer_type(name: str) -> str:
    if "[" in name and "]" in name:
        return "unknown"
    return "unknown"


def build_stp(target: int, sample_depth: int, trigger_signal: str, trigger_mode: str) -> ET.ElementTree:
    stamp = dt.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")
    signal_set_name = f"runctl_hitstack_stage_{target}"
    trigger_name = f"hitstack{target}_stage_{'rise' if trigger_mode == 'rising_edge' else 'high'}"
    signals = default_signals(target)

    root = ET.Element("session", {"sof_file": ""})

    display_tree = ET.SubElement(root, "display_tree", {"gui_logging_enabled": "0"})
    ET.SubElement(
        display_tree,
        "display_branch",
        {
            "instance": "auto_signaltap_0",
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
            "name": "auto_signaltap_0",
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

    for index, name in enumerate(signals):
        common = {
            "duplicate_name_allowed": "false",
            "is_data_input": "true",
            "is_node_valid": "true",
            "is_storage_input": "true",
            "is_trigger_input": "true",
            "name": name,
            "tap_mode": "classic",
            "type": infer_type(name),
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
    parser.add_argument("--target", type=int, choices=(0, 1), required=True, help="Hit-stack subsystem index")
    parser.add_argument("--sample-depth", type=int, default=512, help="SignalTap sample depth")
    parser.add_argument(
        "--trigger-mode",
        choices=("rising_edge", "high"),
        default="high",
        help="Trigger expression kind",
    )
    parser.add_argument(
        "--trigger-signal",
        default=None,
        help="Override trigger signal name",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    trigger_signal = args.trigger_signal
    if trigger_signal is None:
        top_out = TOP_SPLITTER_OUTPUT[args.target]
        trigger_signal = f"{TOP_SPLITTER_PREFIX}out{top_out}_valid"

    tree = build_stp(
        target=args.target,
        sample_depth=args.sample_depth,
        trigger_signal=trigger_signal,
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
