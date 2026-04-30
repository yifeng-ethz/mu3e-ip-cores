#!/usr/bin/env python3
"""Generate Phase-5 SignalTap for frame-deassembly to histogram counting.

This capture is intended to compare the selected real-MuTRiG and emulator
sources at the same downstream boundaries:

* per-lane source mux selected stream
* per-lane frame deassembly type-0 hit outputs
* MTS type-1 stream into the histogram ingress bridge
* optional ring-buffer CAM type-2 and FEB frame-assembly type-3 streams
* histogram ingress bridge selected hist stream
* histogram_statistics input and accepted/dropped counters

Use ``--hitstack 1`` for the lower real-MuTRiG path. The historical default is
hit-stack 0 so existing Phase-5 STP regeneration remains reproducible.
"""

from __future__ import annotations

import argparse
import datetime as dt
import xml.etree.ElementTree as ET
from pathlib import Path

from generate_runctl_mts_stage_stp import (
    DP_PREFIX,
    UP_PREFIX,
    DEFAULT_CLOCK,
    add_multi,
    add_presentation,
    add_signal_vectors,
    add_single,
    bits,
    ctrl_sink,
    indent,
    run_state_bits,
    stream,
)

DEFAULT_TRIGGER = (
    f"{DP_PREFIX}"
    "histogram_ingress_bridge:histogram_ingress_bridge_0|"
    "aso_hist_valid"
)

RESET_PREFIX = f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_rst_controller:rst_controller_001|"


def mux_prefix(lane: int) -> str:
    return f"{DP_PREFIX}mutrig_lane_source_mux:mutrig_lane_source_mux_{lane}|"


def deasm_prefix(lane: int) -> str:
    return (
        f"{DP_PREFIX}"
        f"feb_system_v3_pipe_data_path_subsystem_mutrig_datapath_subsystem_{lane}:mutrig_datapath_subsystem_{lane}|"
        "frame_rcv_ip:mutrig_frame_deassembly_0|"
    )


MTS_PREFIX = {
    0: f"{DP_PREFIX}mts_processor:mts_preprocessor_0|",
    1: f"{DP_PREFIX}mts_processor:mts_preprocessor_1|",
}
HIST_BRIDGE_PREFIX = f"{DP_PREFIX}histogram_ingress_bridge:histogram_ingress_bridge_0|"
HIST_STATS_PREFIX = f"{DP_PREFIX}histogram_statistics_v2:histogram_statistics_0|"


def hitstack_prefix(stack: int) -> str:
    return (
        f"{DP_PREFIX}"
        f"feb_system_v3_pipe_data_path_subsystem_hit_stack_subsystem_{stack}:hit_stack_subsystem_{stack}|"
    )


def scalar_group(prefix: str, names: list[str]) -> list[str]:
    return [f"{prefix}{name}" for name in names]


def type1_stream(prefix: str, name: str) -> list[str]:
    signals = [
        f"{prefix}{name}_valid",
        f"{prefix}{name}_ready",
        f"{prefix}{name}_startofpacket",
        f"{prefix}{name}_endofpacket",
        f"{prefix}{name}_empty",
        f"{prefix}{name}_error",
    ]
    signals.extend(bits(f"{prefix}{name}_data", 39))
    signals.extend(bits(f"{prefix}{name}_channel", 4))
    return signals


def histogram_stream(prefix: str, name: str, data_width: int, channel_width: int = 4) -> list[str]:
    signals = [
        f"{prefix}{name}_valid",
        f"{prefix}{name}_ready",
        f"{prefix}{name}_startofpacket",
        f"{prefix}{name}_endofpacket",
    ]
    signals.extend(bits(f"{prefix}{name}_data", data_width))
    signals.extend(bits(f"{prefix}{name}_channel", channel_width))
    return signals


def type2_stream(prefix: str, name: str) -> list[str]:
    signals = [
        f"{prefix}{name}_valid",
        f"{prefix}{name}_ready",
        f"{prefix}{name}_startofpacket",
        f"{prefix}{name}_endofpacket",
        f"{prefix}{name}_error",
    ]
    signals.extend(bits(f"{prefix}{name}_channel", 4))
    signals.extend(bits(f"{prefix}{name}_data", 36))
    return signals


def type3_stream(prefix: str, name: str) -> list[str]:
    signals = [
        f"{prefix}{name}_valid",
        f"{prefix}{name}_ready",
        f"{prefix}{name}_startofpacket",
        f"{prefix}{name}_endofpacket",
    ]
    signals.extend(bits(f"{prefix}{name}_data", 36))
    return signals


def mts_debug_streams(prefix: str) -> list[str]:
    signals = [
        f"{prefix}aso_debug_ts_valid",
        f"{prefix}aso_debug_burst_valid",
        f"{prefix}hit_out_delay_error",
    ]
    signals.extend(bits(f"{prefix}aso_debug_ts_data", 16))
    signals.extend(bits(f"{prefix}aso_debug_burst_data", 16))
    return signals


def hitstack_debug_ports(prefix: str, rings: int = 4) -> list[str]:
    signals: list[str] = [
        f"{prefix}hit_type_1_valid",
        f"{prefix}hit_type_1_ready",
        f"{prefix}hit_type_1_startofpacket",
        f"{prefix}hit_type_1_endofpacket",
        f"{prefix}hit_type_1_empty[0]",
        f"{prefix}hit_type_1_error[0]",
        f"{prefix}frame_debug_ts_valid",
        f"{prefix}frame_debug_burst_valid",
        f"{prefix}frame_debug_filllevel_valid",
        f"{prefix}frame_debug_loss8fill_valid",
        f"{prefix}frame_debug_delay8loss_valid",
        f"{prefix}frame_ts_delta_valid",
    ]
    signals.extend(bits(f"{prefix}hit_type_1_channel", 4))
    signals.extend(bits(f"{prefix}hit_type_1_data", 39))
    signals.extend(bits(f"{prefix}frame_debug_ts_data", 16))
    signals.extend(bits(f"{prefix}frame_debug_burst_data", 16))
    signals.extend(bits(f"{prefix}frame_debug_filllevel_data", 16))
    signals.extend(bits(f"{prefix}frame_debug_loss8fill_data", 16))
    signals.extend(bits(f"{prefix}frame_debug_delay8loss_data", 16))
    signals.extend(bits(f"{prefix}frame_ts_delta_data", 16))
    for ring in range(rings):
        signals.append(f"{prefix}ring_buffer_cam_{ring}_filllevel_valid")
        signals.extend(bits(f"{prefix}ring_buffer_cam_{ring}_filllevel_data", 16))
    return signals


def frame_boundary_ports(prefix: str, rings: int = 4) -> list[str]:
    signals: list[str] = []
    for ring in range(rings):
        ring_prefix = f"{prefix}ring_buffer_cam:ring_buffer_cam_{ring}|"
        signals.extend(type2_stream(ring_prefix, "aso_hit_type2"))
    signals.extend(type3_stream(prefix, "hit_type3"))
    return signals


def selected_hitstacks(hitstack: str) -> list[int]:
    if hitstack == "both":
        return [0, 1]
    return [int(hitstack)]


def default_signals(hitstack: str = "0", include_frame_boundaries: bool = False) -> list[str]:
    signals: list[str] = []

    signals.append(f"{RESET_PREFIX}reset_out")
    signals.append(f"{UP_PREFIX}runctl_mgmt_host_valid")
    signals.extend(bits(f"{UP_PREFIX}runctl_mgmt_host_data", 9))

    for lane in range(8):
        mp = mux_prefix(lane)
        dp = deasm_prefix(lane)
        signals.extend(
            scalar_group(
                mp,
                [
                    "select_emulator",
                    "asi_real_valid",
                    "asi_emu_valid",
                    "aso_valid",
                ],
            )
        )
        signals.extend(bits(f"{mp}aso_channel", 4))
        signals.extend(bits(f"{mp}aso_error", 3))
        signals.extend(bits(f"{mp}aso_data", 9))
        signals.extend(
            [
                f"{dp}receiver_go",
                f"{dp}enable",
                f"{dp}asi_rx8b1k_valid",
                f"{dp}aso_hit_type0_valid",
                f"{dp}aso_hit_type0_startofpacket",
                f"{dp}aso_hit_type0_endofpacket",
                f"{dp}aso_hit_type0_endofrun",
            ]
        )
        signals.extend(bits(f"{dp}aso_hit_type0_error", 3))
        signals.extend(bits(f"{dp}aso_hit_type0_channel", 4))
        signals.extend(bits(f"{dp}aso_hit_type0_data", 45 if lane == 0 else 16))

    for mts in (0, 1):
        mp = MTS_PREFIX[mts]
        signals.extend(ctrl_sink(mp))
        signals.extend(run_state_bits(mp))
        signals.extend(
            stream(
                mp,
                "asi_hit_type0",
                data_width=45,
                error_width=3,
                channel_width=6,
                include_ready=True,
                include_packet=True,
            )
        )
        signals.extend(type1_stream(mp, "aso_hit_type1"))
        signals.extend(mts_debug_streams(mp))

    for stack in selected_hitstacks(hitstack):
        hp = hitstack_prefix(stack)
        signals.extend(hitstack_debug_ports(hp))
        if include_frame_boundaries:
            signals.extend(frame_boundary_ports(hp))

    signals.extend(
        histogram_stream(HIST_BRIDGE_PREFIX, "asi_pre", data_width=39, channel_width=4)
    )
    signals.append(f"{HIST_BRIDGE_PREFIX}asi_pre_empty")
    signals.append(f"{HIST_BRIDGE_PREFIX}asi_pre_error")
    signals.extend(
        histogram_stream(HIST_BRIDGE_PREFIX, "aso_hist", data_width=39, channel_width=4)
    )
    signals.extend(
        scalar_group(
            HIST_BRIDGE_PREFIX,
            [
                "csr_select_post_req",
                "csr_select_post_live",
                "post_hit_region",
                "post_hist_word_accept",
            ],
        )
    )

    signals.extend(ctrl_sink(HIST_STATS_PREFIX))
    signals.extend(
        histogram_stream(HIST_STATS_PREFIX, "asi_hist_fill_in", data_width=39, channel_width=4)
    )
    signals.extend(
        scalar_group(
            HIST_STATS_PREFIX,
            [
                "queue_hit_valid",
            ],
        )
    )
    signals.extend(bits(f"{HIST_STATS_PREFIX}csr_total_hits", 16))
    signals.extend(bits(f"{HIST_STATS_PREFIX}csr_dropped_hits", 16))
    signals.extend(bits(f"{HIST_STATS_PREFIX}csr_underflow_count", 8))
    signals.extend(bits(f"{HIST_STATS_PREFIX}csr_overflow_count", 8))

    seen: set[str] = set()
    unique: list[str] = []
    for signal in signals:
        if signal not in seen:
            unique.append(signal)
            seen.add(signal)
    return unique


def build_stp(
    sample_depth: int,
    trigger_signal: str,
    trigger_mode: str,
    hitstack: str,
    include_frame_boundaries: bool,
) -> ET.ElementTree:
    stamp = dt.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")
    signal_set_name = "phase5_frame_hist_path"
    trigger_name = f"hist_valid_{trigger_mode}"
    signals = default_signals(hitstack, include_frame_boundaries=include_frame_boundaries)

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


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, help="Output .stp path")
    parser.add_argument("--sample-depth", type=int, default=1024, help="SignalTap sample depth")
    parser.add_argument("--trigger-signal", default=DEFAULT_TRIGGER, help="SignalTap trigger signal name")
    parser.add_argument(
        "--hitstack",
        choices=("0", "1", "both"),
        default="0",
        help="Hit-stack debug port set to include; use 1 for lower lanes 4..7.",
    )
    parser.add_argument(
        "--trigger-mode",
        choices=("rising_edge", "high"),
        default="rising_edge",
        help="Trigger expression kind",
    )
    parser.add_argument(
        "--include-frame-boundaries",
        action="store_true",
        help="Also probe RBCAM hit_type2 outputs and FEB frame-assembly hit_type3 output.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    tree = build_stp(
        args.sample_depth,
        args.trigger_signal,
        args.trigger_mode,
        args.hitstack,
        include_frame_boundaries=args.include_frame_boundaries,
    )
    indent(tree.getroot())

    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="utf-8", xml_declaration=False)
    output.write_text(output.read_text(encoding="utf-8") + "\n", encoding="utf-8")
    print(
        f"wrote {output} "
        f"({len(default_signals(args.hitstack, include_frame_boundaries=args.include_frame_boundaries))} probes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
