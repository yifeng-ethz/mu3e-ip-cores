#!/usr/bin/env python3
"""Generate SignalTap for the FEB v3 pipe run-control-to-lane0 boundary.

The Phase 4 hardware failure has emulators advancing but no deassembly,
ring-CAM, or histogram traffic.  The system TB proves the generated Qsys
emulator/mux/FIFO/deassembly chain can work, so this tap checks the same
boundary in hardware:

* upload run-control host output
* top-level datapath splitter branches for MTS0, lane0, and emulator0
* lane0 emulator, source mux, adapter/FIFO, deassembly input, and type0 output
* deassembly run-control decode, enable, byte stream, and parser state
"""

from __future__ import annotations

import argparse
import datetime as dt
import xml.etree.ElementTree as ET
from pathlib import Path


QSYS = "feb_system:u_feb_system|feb_system_v3_pipe:u_qsys|"
DP_PREFIX = f"{QSYS}feb_system_v3_pipe_data_path_subsystem:data_path_subsystem|"
UP_PREFIX = f"{QSYS}feb_system_v3_pipe_upload_subsystem:upload_subsystem|"

DEFAULT_CLOCK = f"{DP_PREFIX}lvds_outclock_clk"
DEFAULT_TRIGGER = f"{UP_PREFIX}runctl_mgmt_host_valid"

SPLITTER_PREFIX = f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_run_control_splitter:run_control_splitter|"
RESET_PREFIX = f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_rst_controller:rst_controller_001|"

ADAPTER_PREFIX = {
    19: f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_avalon_st_adapter_017:avalon_st_adapter_019|",
    22: f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_avalon_st_adapter_017:avalon_st_adapter_022|",
    25: f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_avalon_st_adapter_017:avalon_st_adapter_025|",
    26: f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_avalon_st_adapter_017:avalon_st_adapter_026|",
}

MTS_PREFIX = {
    0: f"{DP_PREFIX}mts_processor:mts_preprocessor_0|",
    1: f"{DP_PREFIX}mts_processor:mts_preprocessor_1|",
}

DEASM0_PREFIX = (
    f"{DP_PREFIX}"
    "feb_system_v3_pipe_data_path_subsystem_mutrig_datapath_subsystem_0:mutrig_datapath_subsystem_0|"
    "frame_rcv_ip:mutrig_frame_deassembly_0|"
)

EMU0_PREFIX = f"{DP_PREFIX}emulator_mutrig:emulator_mutrig_0|"
MUX0_PREFIX = f"{DP_PREFIX}mutrig_lane_source_mux:mutrig_lane_source_mux_0|"
ADAPTER034_PREFIX = (
    f"{DP_PREFIX}"
    "feb_system_v3_pipe_data_path_subsystem_avalon_st_adapter_034:avalon_st_adapter_034|"
)
FIFO0_PREFIX = f"{DP_PREFIX}altera_avalon_sc_fifo:decoded_lane_fifo_0|"
ADAPTER009_PREFIX = (
    f"{DP_PREFIX}"
    "feb_system_v3_pipe_data_path_subsystem_avalon_st_adapter_009:avalon_st_adapter_009|"
)


def bits(prefix: str, width: int) -> list[str]:
    return [f"{prefix}[{idx}]" for idx in range(width)]


def branch(prefix: str, name: str, include_ready: bool = False) -> list[str]:
    signals = [f"{prefix}{name}_valid"]
    signals.extend(bits(f"{prefix}{name}_data", 9))
    if include_ready:
        signals.append(f"{prefix}{name}_ready")
    return signals


def stream(
    prefix: str,
    name: str,
    *,
    data_width: int,
    error_width: int,
    channel_width: int,
    include_ready: bool = False,
    include_packet: bool = False,
) -> list[str]:
    signals = [f"{prefix}{name}_valid"]
    if include_ready:
        signals.append(f"{prefix}{name}_ready")
    if include_packet:
        signals.extend(
            [
                f"{prefix}{name}_startofpacket",
                f"{prefix}{name}_endofpacket",
            ]
        )
    signals.extend(bits(f"{prefix}{name}_data", data_width))
    signals.extend(bits(f"{prefix}{name}_error", error_width))
    signals.extend(bits(f"{prefix}{name}_channel", channel_width))
    return signals


def top_stream(
    name: str,
    *,
    data_width: int,
    error_width: int,
    channel_width: int,
    include_ready: bool = False,
    include_packet: bool = False,
) -> list[str]:
    return stream(
        DP_PREFIX,
        name,
        data_width=data_width,
        error_width=error_width,
        channel_width=channel_width,
        include_ready=include_ready,
        include_packet=include_packet,
    )


def ctrl_sink(prefix: str) -> list[str]:
    signals = [f"{prefix}asi_ctrl_valid"]
    signals.extend(bits(f"{prefix}asi_ctrl_data", 9))
    signals.append(f"{prefix}asi_ctrl_ready")
    return signals


def run_state_bits(prefix: str) -> list[str]:
    return [
        f"{prefix}run_state_cmd.RUN_PREPARE",
        f"{prefix}run_state_cmd.SYNC",
        f"{prefix}run_state_cmd.RUNNING",
        f"{prefix}run_state_cmd.TERMINATING",
    ]


def mts_processor_state_bits(prefix: str) -> list[str]:
    return [
        f"{prefix}processor_state.RUNNING",
    ]


def deassembly_state_bits(prefix: str) -> list[str]:
    return [
        f"{prefix}p_state.FS_IDLE",
        f"{prefix}p_state.FS_FRAME_COUNTER",
        f"{prefix}p_state.FS_EVENT_COUNTER",
        f"{prefix}p_state.FS_UNPACK",
        f"{prefix}p_state.FS_UNPACK_EXTRA",
        f"{prefix}p_state.FS_CRC_CALC",
        f"{prefix}p_state.FS_CRC_CHECK",
        f"{prefix}p_state.FS_ERROR",
    ]


def deassembly_gate_bits(prefix: str) -> list[str]:
    signals = [
        f"{prefix}receiver_go",
        f"{prefix}enable",
        f"{prefix}i_byteisk",
        f"{prefix}n_frame_info_ready",
        f"{prefix}aso_hit_type0_valid",
        f"{prefix}aso_hit_type0_startofpacket",
        f"{prefix}aso_hit_type0_endofpacket",
    ]
    signals.extend(bits(f"{prefix}i_data", 8))
    signals.extend(bits(f"{prefix}p_frame_flags", 6))
    signals.extend(bits(f"{prefix}p_frame_len", 10))
    signals.extend(bits(f"{prefix}aso_hit_type0_error", 3))
    signals.extend(bits(f"{prefix}aso_hit_type0_channel", 4))
    signals.extend(deassembly_state_bits(prefix))
    return signals


def default_signals() -> list[str]:
    signals: list[str] = []

    signals.append(f"{RESET_PREFIX}reset_out")

    signals.append(f"{UP_PREFIX}runctl_mgmt_host_valid")
    signals.extend(bits(f"{UP_PREFIX}runctl_mgmt_host_data", 9))

    signals.append(f"{DP_PREFIX}runctl_mgmt_host_valid")
    signals.extend(bits(f"{DP_PREFIX}runctl_mgmt_host_data", 9))

    for out_idx in (1, 2, 12):
        signals.extend(branch(SPLITTER_PREFIX, f"out{out_idx}", include_ready=False))

    for adapter_idx in (19, 26, 22):
        signals.extend(branch(ADAPTER_PREFIX[adapter_idx], "out_0", include_ready=True))

    signals.extend(ctrl_sink(MTS_PREFIX[0]))
    signals.extend(run_state_bits(MTS_PREFIX[0]))
    signals.extend(mts_processor_state_bits(MTS_PREFIX[0]))
    signals.extend(
        [
            f"{MTS_PREFIX[0]}aso_hit_type1_valid",
            f"{MTS_PREFIX[0]}aso_hit_type1_ready",
        ]
    )

    signals.extend(ctrl_sink(DEASM0_PREFIX))
    signals.extend(run_state_bits(DEASM0_PREFIX))
    signals.extend(deassembly_gate_bits(DEASM0_PREFIX))
    signals.extend(
        stream(
            DEASM0_PREFIX,
            "asi_rx8b1k",
            data_width=9,
            error_width=3,
            channel_width=4,
        )
    )

    signals.extend(ctrl_sink(EMU0_PREFIX))
    signals.extend(
        [
            f"{EMU0_PREFIX}ctrl_state_q[3]",
            f"{EMU0_PREFIX}ctrl_state_q[4]",
        ]
    )

    signals.extend(
        stream(
            EMU0_PREFIX,
            "aso_tx8b1k",
            data_width=9,
            error_width=3,
            channel_width=4,
        )
    )
    signals.extend(
        stream(
            MUX0_PREFIX,
            "asi_emu",
            data_width=9,
            error_width=3,
            channel_width=4,
        )
    )
    signals.extend(
        stream(
            MUX0_PREFIX,
            "aso",
            data_width=9,
            error_width=3,
            channel_width=4,
        )
    )
    signals.extend(
        stream(
            ADAPTER034_PREFIX,
            "in_0",
            data_width=9,
            error_width=3,
            channel_width=4,
        )
    )
    signals.extend(
        stream(
            ADAPTER034_PREFIX,
            "out_0",
            data_width=9,
            error_width=3,
            channel_width=5,
            include_ready=True,
        )
    )
    signals.extend(
        stream(
            FIFO0_PREFIX,
            "in",
            data_width=9,
            error_width=3,
            channel_width=5,
            include_ready=True,
        )
    )
    signals.extend(
        stream(
            FIFO0_PREFIX,
            "out",
            data_width=9,
            error_width=3,
            channel_width=5,
            include_ready=True,
        )
    )
    signals.extend(
        stream(
            ADAPTER009_PREFIX,
            "in_0",
            data_width=9,
            error_width=3,
            channel_width=5,
            include_ready=True,
        )
    )
    signals.extend(
        stream(
            ADAPTER009_PREFIX,
            "out_0",
            data_width=9,
            error_width=3,
            channel_width=4,
        )
    )

    seen: set[str] = set()
    unique: list[str] = []
    for signal in signals:
        if signal not in seen:
            unique.append(signal)
            seen.add(signal)
    return unique


def add_single(parent: ET.Element, attribute: str, value: str) -> None:
    ET.SubElement(parent, "single", {"attribute": attribute, "value": value})


def add_multi(parent: ET.Element, attribute: str, size: str, value: str) -> None:
    ET.SubElement(parent, "multi", {"attribute": attribute, "size": size, "value": value})


def infer_type(_name: str) -> str:
    return "unknown"


def add_signal_vectors(signal_set: ET.Element, signals: list[str]) -> None:
    signal_vec = ET.SubElement(signal_set, "signal_vec")
    for vec_name in ("trigger_input_vec", "data_input_vec", "storage_qualifier_input_vec"):
        vec = ET.SubElement(signal_vec, vec_name)
        for name in signals:
            ET.SubElement(vec, "wire", {"name": name, "tap_mode": "classic"})


def add_presentation(signal_set: ET.Element, signals: list[str]) -> None:
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


def build_stp(sample_depth: int, trigger_signal: str, trigger_mode: str) -> ET.ElementTree:
    stamp = dt.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")
    signal_set_name = "runctl_mts_stage"
    trigger_name_by_mode = {
        "rising_edge": "runctl_host_valid_rise",
        "high": "runctl_host_valid_high",
        "low": "runctl_host_valid_low",
    }
    trigger_name = trigger_name_by_mode[trigger_mode]
    signals = default_signals()

    root = ET.Element("session", {"sof_file": ""})
    display_tree = ET.SubElement(root, "display_tree", {"gui_logging_enabled": "0"})
    ET.SubElement(
        display_tree,
        "display_branch",
        {
            "instance": "runctl_mts_stage",
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
            "name": "runctl_mts_stage",
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

    add_signal_vectors(signal_set, signals)
    add_presentation(signal_set, signals)

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
    elif trigger_mode == "low":
        level.text = f"'{trigger_signal}' == low"
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
        choices=("rising_edge", "high", "low"),
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
    print(f"wrote {output} ({len(default_signals())} probes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
