#!/usr/bin/env python3
"""Generate a narrow Phase-5 SignalTap file for injector-to-emulator debug.

This tap is intentionally small. It answers the immediate board question:
does a CSR write to `mutrig_injector_0.MODE` produce a pulse, does the pulse
leave the fanout, and does emulator lane 0 accept it while RUNNING?

The tap list intentionally avoids pre-synthesis nodes that Quartus currently
optimizes to constants in the generated FEB image. In the 2026-04-28 compact
compile, `emulator_mutrig_0|event_count[*]` and the fanout-local
`merged_inject_pulse` passed Node Finder but were removed by map and became
GND in the SignalTap connection table. Keep board-debug probes on surviving
observable endpoints unless the RTL is changed to preserve those internals.

The default `micro` profile is the programming candidate. It removes wide CSR
and payload buses plus hit-generator internals because the 84-probe compact
profile built on 2026-04-28 but missed LVDS setup timing by about 0.9 ns. Keep
`compact` available as a richer pre-fit/debug list, but do not program it
unless timing is explicitly re-closed.
"""

from __future__ import annotations

import argparse
import datetime as dt
import xml.etree.ElementTree as ET
from pathlib import Path


QSYS_PREFIX = "feb_system:u_feb_system|feb_system_v3_pipe:u_qsys|"
DATA_PATH_PREFIX = f"{QSYS_PREFIX}feb_system_v3_pipe_data_path_subsystem:data_path_subsystem|"

DEFAULT_CLOCK = f"{DATA_PATH_PREFIX}lvds_outclock_clk"

RST_PREFIX = f"{DATA_PATH_PREFIX}feb_system_v3_pipe_data_path_subsystem_rst_controller:rst_controller_001|"
INJECTOR_PREFIX = f"{DATA_PATH_PREFIX}mutrig_injector_multiheader:mutrig_injector_0|"
FANOUT_PREFIX = f"{DATA_PATH_PREFIX}pulse_fanout8:emulator_inject_fanout|"
EMU0_PREFIX = f"{DATA_PATH_PREFIX}emulator_mutrig:emulator_mutrig_0|"
HITGEN0_PREFIX = f"{EMU0_PREFIX}hit_generator:u_hit_gen|"


def bits(prefix: str, width: int) -> list[str]:
    return [f"{prefix}[{idx}]" for idx in range(width)]


def micro_signals() -> list[str]:
    signals: list[str] = []

    signals.append(f"{RST_PREFIX}reset_out")

    signals.extend(
        [
            f"{INJECTOR_PREFIX}avs_csr_write",
            f"{INJECTOR_PREFIX}avs_csr_read",
            f"{INJECTOR_PREFIX}avs_csr_waitrequest",
        ]
    )
    signals.extend(bits(f"{INJECTOR_PREFIX}avs_csr_address", 4))
    signals.extend(bits(f"{INJECTOR_PREFIX}csr.mode", 4))
    signals.extend(
        [
            f"{INJECTOR_PREFIX}onclick_write_pulse",
            f"{INJECTOR_PREFIX}onclick_injector_pulse",
            f"{INJECTOR_PREFIX}periodic_injector_pulse",
            f"{INJECTOR_PREFIX}header_injector_pulse",
            f"{INJECTOR_PREFIX}random_injector_pulse",
            f"{INJECTOR_PREFIX}coe_inject_pulse",
        ]
    )

    signals.extend(
        [
            f"{FANOUT_PREFIX}coe_inject_pulse",
            f"{FANOUT_PREFIX}coe_out0_pulse",
            f"{FANOUT_PREFIX}coe_out0_masked_pulse",
        ]
    )

    signals.extend(
        [
            f"{EMU0_PREFIX}coe_inject_pulse",
            f"{EMU0_PREFIX}coe_inject_masked_pulse",
            f"{EMU0_PREFIX}csr_enable",
            f"{EMU0_PREFIX}inject_pulse_clk",
            f"{EMU0_PREFIX}inject_masked_pulse_clk",
            f"{EMU0_PREFIX}aso_tx8b1k_valid",
        ]
    )
    signals.extend(
        [
            f"{EMU0_PREFIX}ctrl_state_q[3]",
            f"{EMU0_PREFIX}ctrl_state_q[4]",
        ]
    )
    signals.extend(bits(f"{EMU0_PREFIX}inject_sync", 2))

    return unique(signals)


def compact_signals() -> list[str]:
    signals = micro_signals()
    signals.extend(bits(f"{INJECTOR_PREFIX}avs_csr_writedata", 32))
    signals.extend(bits(f"{EMU0_PREFIX}aso_tx8b1k_data", 9))
    signals.extend(
        [
            f"{HITGEN0_PREFIX}enable",
            f"{HITGEN0_PREFIX}inject_pulse",
            f"{HITGEN0_PREFIX}inject_masked_pulse",
            f"{HITGEN0_PREFIX}inject_burst_pending",
            f"{HITGEN0_PREFIX}fifo_full",
            f"{HITGEN0_PREFIX}fifo_empty",
        ]
    )
    signals.extend(bits(f"{HITGEN0_PREFIX}burst_remaining", 5))

    return unique(signals)


def unique(signals: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for signal in signals:
        if signal not in seen:
            result.append(signal)
            seen.add(signal)
    return result


def add_single(parent: ET.Element, attribute: str, value: str) -> None:
    ET.SubElement(parent, "single", {"attribute": attribute, "value": value})


def add_multi(parent: ET.Element, attribute: str, size: str, value: str) -> None:
    ET.SubElement(parent, "multi", {"attribute": attribute, "size": size, "value": value})


def infer_type(_name: str) -> str:
    return "unknown"


def build_stp(sample_depth: int, trigger_signal: str, trigger_mode: str, profile: str) -> ET.ElementTree:
    stamp = dt.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")
    signal_set_name = "phase5_injector_path_lvds"
    trigger_name = "injector_path_pulse"
    if profile == "micro":
        signals = micro_signals()
    elif profile == "compact":
        signals = compact_signals()
    else:
        raise ValueError(f"unsupported profile: {profile}")

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
    parser.add_argument("--sample-depth", type=int, default=1024, help="SignalTap sample depth")
    parser.add_argument("--trigger-mode", choices=("rising_edge", "high"), default="rising_edge")
    parser.add_argument(
        "--profile",
        choices=("micro", "compact"),
        default="micro",
        help="Probe profile: micro is timing-closure candidate; compact is richer but not timing-closed",
    )
    parser.add_argument(
        "--trigger-signal",
        default=f"{FANOUT_PREFIX}coe_out0_pulse",
        help="Trigger signal name",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    tree = build_stp(
        sample_depth=args.sample_depth,
        trigger_signal=args.trigger_signal,
        trigger_mode=args.trigger_mode,
        profile=args.profile,
    )
    indent(tree.getroot())

    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="utf-8", xml_declaration=False)
    output.write_text(output.read_text(encoding="utf-8") + "\n", encoding="utf-8")
    print(f"wrote {output}")
    print(f"profile={args.profile} probes={len(micro_signals() if args.profile == 'micro' else compact_signals())}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
