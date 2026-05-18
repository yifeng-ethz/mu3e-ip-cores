#!/usr/bin/env python3
"""Generate an RX-only SignalTap profile from the mixed Link02 SC profile."""

from __future__ import annotations

import argparse
import copy
import re
import xml.etree.ElementTree as ET
from pathlib import Path


DEFAULT_INPUT = Path("/home/yifeng/packages/online_sc/online/switching_pc/a10_board/top_sc_link2_packets_example1_format.stp")
DEFAULT_OUTPUT = Path("/home/yifeng/packages/online_sc/online/switching_pc/a10_board/top_sc_link2_rx_only.stp")

RX_PATTERNS = (
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.init",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.waiting",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.rearm_wait",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.rearm_pop",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.capture_head",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.capture_body",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.write_word",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.drop_word",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.pop_word",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.wait_word",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|current_link[",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|ren[",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|pop_wait_cnt[",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|packet_active",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|captured_link.data[",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|state.capture_head",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|mem_wren_o",
    r"swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|link32_scfifo:\gen_buffer_sc:2:e_fifo|o_rdata.eop",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_",
)

DBG_LINK2_HEADER_PULSE = "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_header_pulse"
DBG_LINK2_WORD_VALID = "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_word_valid"
DBG_LINK2_PACKET_ACTIVE = "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_packet_active"

EXTRA_SCALAR_PROBES = (
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_sop",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_eop",
    "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_idle",
    DBG_LINK2_WORD_VALID,
    DBG_LINK2_HEADER_PULSE,
    DBG_LINK2_PACKET_ACTIVE,
)
EXTRA_BUS_PROBES = (
    ("swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|dbg_link2_data", 32),
)

TRIGGER_TERMS = (
    (DBG_LINK2_HEADER_PULSE, "high"),
)
TRIGGER_EXPR = " && ".join(f"'{name}' == {level}" for name, level in TRIGGER_TERMS)

EXACT_RENAMES = {
    r"swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|link32_scfifo:\gen_buffer_sc:2:e_fifo|o_rdata.eop":
        "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|captured_link.eop",
}

def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--sample-depth", type=int, default=1024)
    return parser


def is_rx_name(name: str) -> bool:
    return any(token in name for token in RX_PATTERNS)


def remap_rx_name(name: str) -> str:
    if name in EXACT_RENAMES:
        return EXACT_RENAMES[name]
    return name


def find_named_elem(root: ET.Element, tag: str, name: str) -> ET.Element | None:
    for elem in root.findall(f".//{tag}"):
        if elem.get("name", "") == name:
            return elem
    return None


def next_signal_index(root: ET.Element) -> int:
    max_idx = -1
    for elem in root.findall(".//net"):
        for attr in ("data_index", "storage_index", "trigger_index"):
            value = elem.get(attr)
            if value is None:
                continue
            try:
                max_idx = max(max_idx, int(value))
            except ValueError:
                continue
    return max_idx + 1


def clone_wire(vec: ET.Element, template_name: str, new_name: str) -> None:
    if any(wire.get("name", "") == new_name for wire in vec.findall("./wire")):
        return

    template = None
    for wire in vec.findall("./wire"):
        if wire.get("name", "") == template_name:
            template = wire
            break
    if template is None:
        raise RuntimeError(f"missing wire template {template_name}")

    new_wire = copy.deepcopy(template)
    new_wire.set("name", new_name)
    vec.append(new_wire)


def clone_net(root: ET.Element, template_name: str, new_name: str, new_index: int) -> None:
    if find_named_elem(root, "net", new_name) is not None:
        return

    template = find_named_elem(root, "net", template_name)
    if template is None:
        raise RuntimeError(f"missing net template {template_name}")

    new_net = copy.deepcopy(template)
    new_net.set("name", new_name)
    for attr in ("data_index", "storage_index", "trigger_index"):
        new_net.set(attr, str(new_index))
    new_net.set("level-0", "dont_care")

    parent = None
    for cand in root.iter():
        if template in list(cand):
            parent = cand
            break
    if parent is None:
        raise RuntimeError(f"failed to locate parent for template {template_name}")
    parent.append(new_net)


def append_scalar_probe(root: ET.Element, signal_set: ET.Element, template_name: str, new_name: str) -> None:
    signal_vec = signal_set.find("./signal_vec")
    if signal_vec is None:
        raise RuntimeError("missing signal_vec")

    for vec_name in ("trigger_input_vec", "data_input_vec", "storage_qualifier_input_vec"):
        vec = signal_vec.find(f"./{vec_name}")
        if vec is None:
            raise RuntimeError(f"missing {vec_name}")
        clone_wire(vec, template_name, new_name)

    clone_net(root, template_name, new_name, next_signal_index(root))


def append_bus_probes(
    root: ET.Element,
    signal_set: ET.Element,
    template_prefix: str,
    new_prefix: str,
    width: int,
) -> None:
    for bit in range(width):
        append_scalar_probe(
            root,
            signal_set,
            f"{template_prefix}[{bit}]",
            f"{new_prefix}[{bit}]",
        )


def append_dbg_link2_probes(root: ET.Element, signal_set: ET.Element) -> None:
    scalar_template = "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|mem_wren_o"
    data_template_prefix = "swb_block:e_swb_block|swb_sc_secondary:e_sc_secondary|captured_link.data"

    for name in EXTRA_SCALAR_PROBES:
        append_scalar_probe(root, signal_set, scalar_template, name)
    for prefix, width in EXTRA_BUS_PROBES:
        append_bus_probes(root, signal_set, data_template_prefix, prefix, width)


def unique_wires(vec: ET.Element) -> None:
    kept = []
    seen = set()
    for wire in vec.findall("./wire"):
        name = wire.get("name", "")
        if not name or name in seen:
            continue
        seen.add(name)
        kept.append(wire)
    vec[:] = kept


def prune_duplicate_named_elements(root: ET.Element) -> None:
    for tag in ("node", "net"):
        seen = set()
        for elem in list(root.findall(f".//{tag}")):
            name = elem.get("name", "")
            if not name:
                continue
            if name in seen:
                parent = None
                for cand in root.iter():
                    if elem in list(cand):
                        parent = cand
                        break
                if parent is not None:
                    parent.remove(elem)
                continue
            seen.add(name)


def set_trigger_levels(root: ET.Element, trigger_terms) -> None:
    level_map = {name: level for name, level in trigger_terms}
    for tag in ("node", "net"):
        for elem in root.findall(f".//{tag}"):
            name = elem.get("name", "")
            if not name:
                continue
            if name in level_map:
                elem.set("level-0", level_map[name])
            elif elem.get("level-0") in {"rising edge", "falling edge", "high", "low"}:
                elem.set("level-0", "dont_care")


def set_condition1(instance_body: ET.Element, trigger_expr: str) -> None:
    trigger = instance_body.find("./signal_set/trigger")
    if trigger is None:
        raise RuntimeError("missing trigger element")
    level = trigger.find("./events/level")
    if level is None or level.get("name") != "condition1":
        raise RuntimeError("missing condition1 trigger level")
    level.text = trigger_expr

def main() -> int:
    args = build_parser().parse_args()

    tree = ET.parse(args.input)
    root = tree.getroot()
    instance = root.find("./instance")
    if instance is None:
        raise SystemExit("input STP missing instance")
    signal_set = instance.find("./signal_set")
    if signal_set is None:
        raise SystemExit("input STP missing signal_set")

    selected_names: list[str] = []
    for vec_name in ("trigger_input_vec", "data_input_vec"):
        vec = signal_set.find(f"./signal_vec/{vec_name}")
        if vec is None:
            raise SystemExit(f"input STP missing {vec_name}")
        kept = []
        seen_names = set()
        for wire in vec.findall("./wire"):
            name = wire.get("name", "")
            if is_rx_name(name):
                new_name = remap_rx_name(name)
                if new_name in seen_names:
                    continue
                seen_names.add(new_name)
                new_wire = copy.deepcopy(wire)
                new_wire.set("name", new_name)
                kept.append(new_wire)
                selected_names.append(new_name)
        vec[:] = kept
        unique_wires(vec)

    selected_set = set(selected_names)

    config = signal_set.find("./config")
    if config is None:
        raise SystemExit("input STP missing config")
    config.set("sample_depth", str(args.sample_depth))

    trigger = signal_set.find("./trigger")
    if trigger is None:
        raise SystemExit("input STP missing trigger")
    trigger.set("position", "post")

    for tag in ("node", "net"):
        for elem in list(root.findall(f".//{tag}")):
            name = elem.get("name", "")
            if not name:
                continue
            if is_rx_name(name):
                elem.set("name", remap_rx_name(name))
                continue
            if name not in selected_set:
                parent = None
                for cand in root.iter():
                    if elem in list(cand):
                        parent = cand
                        break
                if parent is not None:
                    parent.remove(elem)

    prune_duplicate_named_elements(root)
    append_dbg_link2_probes(root, signal_set)
    prune_duplicate_named_elements(root)
    set_condition1(instance, TRIGGER_EXPR)
    set_trigger_levels(root, TRIGGER_TERMS)

    for vec_name in ("trigger_input_vec", "data_input_vec", "storage_qualifier_input_vec"):
        vec = signal_set.find(f"./signal_vec/{vec_name}")
        if vec is None:
            raise SystemExit(f"input STP missing {vec_name}")
        unique_wires(vec)

    args.output.write_text(
        ET.tostring(root, encoding="unicode"),
        encoding="utf-8",
    )

    print(f"Generated: {args.output}")
    print(f"Selected probes: {len(signal_set.findall('./signal_vec/data_input_vec/wire'))}")
    print(f"Trigger: {TRIGGER_EXPR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
