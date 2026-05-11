#!/usr/bin/env python3
"""Generate Phase-6 packet-path SignalTap files for FEB and SWB debug.

The generated taps are intended for cross-board captures that can be armed
before RUNNING.  Each capture triggers on the same packet-id field by default:
bits [23:8] of the 32-bit link word while valid and SOP are asserted.  That
matches the normal Mu3e link header FPGA/packet-id field used by the existing
tools.  The bit slice is configurable when a different packet tag is needed.

FEB target:
  * rbCAM Type-2 snoop for ASIC/lane 0 plus one lower-side lane
  * frame_assembly ingress/egress for both hit stacks
  * upload subsystem output for the upper stream
  * firefly XCVR upload inputs and both firefly TX groups

SWB target:
  * raw FEB RX physical links for the lower-side SciFi connections
  * SWB logical SciFi RX/debug stream names used after demerge
  * DMA write stream toward the SWB host side
"""

from __future__ import annotations

import argparse
import datetime as dt
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


QSYS = "feb_system:u_feb_system|feb_system_v3_pipe:u_qsys|"
DP_PREFIX = f"{QSYS}feb_system_v3_pipe_data_path_subsystem:data_path_subsystem|"
UP_PREFIX = f"{QSYS}feb_system_v3_pipe_upload_subsystem:upload_subsystem|"
TOP_PREFIX = "feb_system:u_feb_system|"
FIREFLY_PREFIX = f"{TOP_PREFIX}firefly_xcvr_subsystem:u_firefly_xcvr|"

HITSTACK0_PREFIX = (
    f"{DP_PREFIX}"
    "feb_system_v3_pipe_data_path_subsystem_hit_stack_subsystem_0:hit_stack_subsystem_0|"
)
FRAME0_PREFIX = f"{HITSTACK0_PREFIX}feb_frame_assembly:feb_frame_assembly_0|"
HITSTACK1_PREFIX = (
    f"{DP_PREFIX}"
    "feb_system_v3_pipe_data_path_subsystem_hit_stack_subsystem_1:hit_stack_subsystem_1|"
)
FRAME1_PREFIX = f"{HITSTACK1_PREFIX}feb_frame_assembly:feb_frame_assembly_0|"

FEB_DP_CLOCK = f"{DP_PREFIX}lvds_outclock_clk"
FEB_UPLOAD_CLOCK = f"{UP_PREFIX}control_clock_clk"
FEB_FIREFLY_CLOCK = f"{FIREFLY_PREFIX}i_clk_156"

SWB_BLOCK_PREFIX = "swb_block:e_swb_block|"
SWB_CLOCK = f"{SWB_BLOCK_PREFIX}i_clk"
SWB_SCIFI_LOGICAL_LINKS = (2, 3, 4, 5)


@dataclass(frozen=True)
class TapInstance:
    name: str
    signal_set: str
    clock: str
    signals: list[str]
    trigger_expr: str


def bits(prefix: str, width: int, *, lsb: int = 0) -> list[str]:
    return [f"{prefix}[{idx}]" for idx in range(lsb, lsb + width)]


def dedupe(signals: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for signal in signals:
        if signal not in seen:
            seen.add(signal)
            out.append(signal)
    return out


def ordered_unique(values: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            out.append(value)
    return out


def feb_lane_paths(global_lane: int) -> tuple[str, str, int]:
    if global_lane < 0 or global_lane > 7:
        raise ValueError(f"FEB lane {global_lane} is outside 0..7")
    if global_lane < 4:
        return HITSTACK0_PREFIX, FRAME0_PREFIX, global_lane
    return HITSTACK1_PREFIX, FRAME1_PREFIX, global_lane - 4


def st_stream(
    prefix: str,
    name: str,
    *,
    data_width: int = 36,
    data_lsb: int = 0,
    include_ready: bool = True,
    include_packet: bool = True,
    include_empty: bool = False,
    channel_width: int = 0,
    error_width: int = 0,
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
    if include_empty:
        signals.extend(bits(f"{prefix}{name}_empty", 1))
    signals.extend(bits(f"{prefix}{name}_data", data_width, lsb=data_lsb))
    if channel_width:
        signals.extend(bits(f"{prefix}{name}_channel", channel_width))
    if error_width:
        signals.extend(bits(f"{prefix}{name}_error", error_width))
    return signals


def packet_trigger(
    *,
    valid: str,
    data: str,
    packet_id: int | None,
    lsb: int,
    width: int,
    sop: str | None = None,
) -> str:
    terms = [f"'{valid}' == high"]
    if sop is not None:
        terms.append(f"'{sop}' == high")
    if packet_id is not None:
        mask = (1 << width) - 1
        value = packet_id & mask
        for bit in range(width):
            level = "high" if ((value >> bit) & 1) else "low"
            terms.append(f"'{data}[{lsb + bit}]' == {level}")
    return " && ".join(terms)


def add_single(parent: ET.Element, attribute: str, value: str) -> None:
    ET.SubElement(parent, "single", {"attribute": attribute, "value": value})


def add_multi(parent: ET.Element, attribute: str, size: str, value: str) -> None:
    ET.SubElement(parent, "multi", {"attribute": attribute, "size": size, "value": value})


def infer_type(name: str) -> str:
    return "unknown"


def add_signal_set(parent: ET.Element, tap: TapInstance, sample_depth: int, stamp: str) -> None:
    signal_set = ET.SubElement(parent, "signal_set", {"name": tap.signal_set})
    signal_set.append(ET.Comment(f"Generated {stamp} UTC"))
    ET.SubElement(signal_set, "clock", {"name": tap.clock, "polarity": "posedge", "tap_mode": "classic"})
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

    signals = dedupe(tap.signals)
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
            "name": f"{tap.signal_set}_packet_id",
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
    level.text = tap.trigger_expr
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


def build_stp(taps: list[TapInstance], sample_depth: int) -> ET.ElementTree:
    stamp = dt.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")
    root = ET.Element("session", {"sof_file": ""})

    display_tree = ET.SubElement(root, "display_tree", {"gui_logging_enabled": "0"})
    for idx, tap in enumerate(taps):
        ET.SubElement(
            display_tree,
            "display_branch",
            {
                "instance": f"auto_signaltap_{idx}",
                "signal_set": tap.signal_set,
                "trigger": f"{tap.signal_set}_packet_id",
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

    for idx, tap in enumerate(taps):
        instance = ET.SubElement(
            root,
            "instance",
            {
                "enabled": "true",
                "entity_name": "sld_signaltap",
                "is_auto_node": "yes",
                "name": f"auto_signaltap_{idx}",
                "source_file": "sld_signaltap.vhd",
            },
        )
        ET.SubElement(
            instance,
            "node_ip_info",
            {"instance_id": str(idx), "mfg_id": "110", "node_id": "0", "version": "6"},
        )
        position_info = ET.SubElement(instance, "position_info")
        add_single(position_info, "active tab", "1")
        add_single(position_info, "setup vertical scroll position", "0")
        add_single(position_info, "setup horizontal scroll position", "0")
        add_signal_set(instance, tap, sample_depth, stamp)

    ET.SubElement(root, "mnemonics")
    return ET.ElementTree(root)


def feb_taps(args: argparse.Namespace) -> list[TapInstance]:
    packet_id = args.packet_id
    lsb = args.packet_id_lsb
    width = args.packet_id_width

    frame_out = "aso_hit_type3"
    frame_lanes = (args.asic0_lane, args.other_lane)
    ring_lanes = (args.asic0_lane, args.other_lane)

    dp_signals: list[str] = []
    for lane in ring_lanes:
        hitstack_prefix, _, local_lane = feb_lane_paths(lane)
        dp_signals.extend(
            st_stream(
                hitstack_prefix,
                f"ring_buffer_cam_{local_lane}_hit_type2_snoop",
                include_empty=True,
                channel_width=4,
                error_width=1,
            )
        )
    for lane in frame_lanes:
        _, frame_prefix, local_lane = feb_lane_paths(lane)
        dp_signals.extend(
            st_stream(
                frame_prefix,
                f"asi_hit_type2_{local_lane}",
                channel_width=4,
                error_width=0,
            )
        )
    frame_prefixes = ordered_unique([feb_lane_paths(lane)[1] for lane in frame_lanes])
    dp_trigger_terms: list[str] = []
    for frame_prefix in frame_prefixes:
        dp_signals.extend(st_stream(frame_prefix, frame_out, channel_width=0, error_width=0))
        dp_signals.extend(
            [
                f"{frame_prefix}main_fifo_wr_valid",
                f"{frame_prefix}ingress_delay_valid",
            ]
        )
        dp_signals.extend(bits(f"{frame_prefix}ingress_delay_data", 16))
        dp_trigger_terms.append(
            packet_trigger(
                valid=f"{frame_prefix}{frame_out}_valid",
                sop=f"{frame_prefix}{frame_out}_startofpacket",
                data=f"{frame_prefix}{frame_out}_data",
                packet_id=packet_id,
                lsb=lsb,
                width=width,
            )
        )
    dp_trigger = " || ".join(f"({term})" for term in dp_trigger_terms)

    upload_signals: list[str] = []
    upload_signals.extend(
        st_stream(
            UP_PREFIX,
            "upload_data",
            channel_width=0,
            error_width=0,
        )
    )
    upload_signals.extend(
        st_stream(
            UP_PREFIX,
            "upload_data0_sc_rc",
            channel_width=2,
            error_width=0,
        )
    )
    upload_trigger = packet_trigger(
        valid=f"{UP_PREFIX}upload_data0_sc_rc_valid",
        sop=f"{UP_PREFIX}upload_data0_sc_rc_startofpacket",
        data=f"{UP_PREFIX}upload_data0_sc_rc_data",
        packet_id=packet_id,
        lsb=lsb,
        width=width,
    )

    firefly_signals: list[str] = [
        f"{FIREFLY_PREFIX}i_upload_data0_sc_rc_valid",
        f"{FIREFLY_PREFIX}i_upload_data1_valid",
    ]
    firefly_signals.extend(bits(f"{FIREFLY_PREFIX}i_upload_data0_sc_rc_data", 36))
    firefly_signals.extend(bits(f"{FIREFLY_PREFIX}i_upload_data1_data", 36))
    firefly_signals.extend(bits(f"{FIREFLY_PREFIX}firefly_reg_mapping:u_firefly_monitor|i_rx_locked", 4))
    firefly_signals.extend(bits(f"{FIREFLY_PREFIX}firefly_reg_mapping:u_firefly_monitor|i_rx_ready", 4))
    firefly_signals.extend(bits(f"{FIREFLY_PREFIX}ip_altera_xcvr_native_av:u_xcvr_native|rx_is_lockedtodata", 4))
    for group in ("o_firefly1_tx_data", "o_firefly2_tx_data"):
        firefly_signals.extend(bits(f"{FIREFLY_PREFIX}{group}", 4))
    firefly_signals.extend(bits(f"{FIREFLY_PREFIX}tx_words[0]", 36))
    firefly_signals.extend(bits(f"{FIREFLY_PREFIX}tx_words[4]", 36))
    firefly_trigger = " || ".join(
        f"({term})"
        for term in (
            packet_trigger(
                valid=f"{FIREFLY_PREFIX}i_upload_data0_sc_rc_valid",
                sop=None,
                data=f"{FIREFLY_PREFIX}i_upload_data0_sc_rc_data",
                packet_id=packet_id,
                lsb=lsb,
                width=width,
            ),
            packet_trigger(
                valid=f"{FIREFLY_PREFIX}i_upload_data1_valid",
                sop=None,
                data=f"{FIREFLY_PREFIX}i_upload_data1_data",
                packet_id=packet_id,
                lsb=lsb,
                width=width,
            ),
        )
    )

    return [
        TapInstance(
            name="phase6_feb_after_rbcam_frame",
            signal_set="phase6_feb_after_rbcam_frame",
            clock=FEB_DP_CLOCK,
            signals=dedupe(dp_signals),
            trigger_expr=dp_trigger,
        ),
        TapInstance(
            name="phase6_feb_upload_subsystem",
            signal_set="phase6_feb_upload_subsystem",
            clock=FEB_UPLOAD_CLOCK,
            signals=dedupe(upload_signals),
            trigger_expr=upload_trigger,
        ),
        TapInstance(
            name="phase6_feb_firefly_xcvr",
            signal_set="phase6_feb_firefly_xcvr",
            clock=FEB_FIREFLY_CLOCK,
            signals=dedupe(firefly_signals),
            trigger_expr=firefly_trigger,
        ),
    ]


def swb_record_link(prefix: str, link: int) -> list[str]:
    base = f"{prefix}i_feb_rx[{link}]"
    signals: list[str] = []
    signals.extend(bits(f"{base}.data", 32))
    signals.extend(bits(f"{base}.datak", 4))
    signals.extend(
        [
            f"{base}.sop",
            f"{base}.eop",
            f"{base}.err",
            f"{base}.dthdr",
            f"{base}.sbhdr",
            f"{base}.idle",
        ]
    )
    return signals


def swb_taps(args: argparse.Namespace) -> list[TapInstance]:
    packet_id = args.packet_id
    lsb = args.packet_id_lsb
    width = args.packet_id_width
    trigger_link = args.swb_trigger_link

    signals: list[str] = []
    for link in SWB_SCIFI_LOGICAL_LINKS:
        signals.extend(swb_record_link(SWB_BLOCK_PREFIX, link))

    for logical in range(4):
        signals.extend(
            [
                f"{SWB_BLOCK_PREFIX}rx_data_scifi[{logical}].data",
                f"{SWB_BLOCK_PREFIX}rx_data_scifi[{logical}].datak",
            ]
        )

    signals.extend(
        [
            f"{SWB_BLOCK_PREFIX}o_dma_wren",
            f"{SWB_BLOCK_PREFIX}o_endofevent",
        ]
    )
    signals.extend(bits(f"{SWB_BLOCK_PREFIX}o_dma_data", 64))

    trigger = packet_trigger(
        valid=f"{SWB_BLOCK_PREFIX}i_feb_rx[{trigger_link}].datak[0]",
        sop=f"{SWB_BLOCK_PREFIX}i_feb_rx[{trigger_link}].sop",
        data=f"{SWB_BLOCK_PREFIX}i_feb_rx[{trigger_link}].data",
        packet_id=packet_id,
        lsb=lsb,
        width=width,
    )

    return [
        TapInstance(
            name="phase6_swb_feb_rx_dma",
            signal_set="phase6_swb_feb_rx_dma",
            clock=SWB_CLOCK,
            signals=dedupe(signals),
            trigger_expr=trigger,
        )
    ]


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


def parse_int(value: str) -> int:
    return int(value, 0)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", choices=("feb", "swb"), required=True)
    parser.add_argument("--output", required=True, help="Output .stp path")
    parser.add_argument("--sample-depth", type=int, default=1024)
    parser.add_argument("--packet-id", type=parse_int, default=0x0001)
    parser.add_argument("--packet-id-lsb", type=int, default=8)
    parser.add_argument("--packet-id-width", type=int, default=16)
    parser.add_argument("--asic0-lane", type=int, default=0, help="Global FEB lane for ASIC0")
    parser.add_argument("--other-lane", type=int, default=6, help="Second global FEB lane to monitor; default is lower-side lane 6")
    parser.add_argument(
        "--swb-trigger-link",
        type=int,
        default=2,
        help="Logical SWB i_feb_rx link used for the packet-id trigger; SciFi lower side is 2..5",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if args.packet_id_width <= 0 or args.packet_id_width > 32:
        raise ValueError("--packet-id-width must be in 1..32")
    if args.packet_id_lsb < 0 or args.packet_id_lsb + args.packet_id_width > 32:
        raise ValueError("packet-id slice must fit in a 32-bit link word")
    feb_lane_paths(args.asic0_lane)
    feb_lane_paths(args.other_lane)

    taps = feb_taps(args) if args.target == "feb" else swb_taps(args)
    tree = build_stp(taps, args.sample_depth)
    indent(tree.getroot())

    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="utf-8", xml_declaration=False)
    output.write_text(output.read_text(encoding="utf-8") + "\n", encoding="utf-8")

    print(f"wrote {output}")
    for tap in taps:
        print(f"{tap.signal_set}: {len(dedupe(tap.signals))} signals, clock={tap.clock}")
        print(f"  trigger: {tap.trigger_expr}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
