#!/usr/bin/env python3
"""Generate a SignalTap file for the FEB V3 direct histogram path.

The tap intentionally avoids the removed histogram_ingress_bridge. It observes
the direct Type0 lane taps, Type1 up/down taps, timestamp sidebands, and
histogram CSR/bin readback boundary.
"""

from __future__ import annotations

import argparse
import datetime as dt
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from pathlib import Path


QSYS = "feb_system:u_feb_system|feb_system_v3:u_qsys|"
FEB_WRAPPER = "feb_system:u_feb_system|"
FIREFLY = f"{FEB_WRAPPER}firefly_xcvr_subsystem:u_firefly_xcvr|"
DP_PREFIX = f"{QSYS}feb_system_v3_data_path_subsystem:data_path_subsystem|"
CP_PREFIX = f"{QSYS}feb_system_v3_control_path_subsystem:control_path_subsystem|"
UPLOAD_PREFIX = f"{QSYS}feb_system_v3_upload_subsystem:upload_subsystem|"
HIST = f"{DP_PREFIX}histogram_statistics_v2:histogram_statistics_0|"
DEFAULT_CLOCK = f"{DP_PREFIX}lvds_outclock_clk"
DEFAULT_TRIGGER = f"{HIST}asi_type0_lane0_valid"
MCLK125_CLOCK = "lvds_firefly_clk"
CCLK156_CLOCK = "transceiver_pll_clock[0]"


@dataclass(frozen=True)
class Probe:
    domain: str
    group: str
    name: str


@dataclass(frozen=True)
class DomainConfig:
    key: str
    instance: str
    signal_set: str
    clock: str
    default_trigger: str
    trigger_prefix: str


DOMAIN_CONFIGS = (
    DomainConfig(
        key="lvds",
        instance="direct_hist_v3_lvds",
        signal_set="direct_hist_v3_lvds",
        clock=DEFAULT_CLOCK,
        default_trigger=DEFAULT_TRIGGER,
        trigger_prefix="type0_lane0_hist_valid",
    ),
    DomainConfig(
        key="mclk125",
        instance="direct_hist_v3_mclk125",
        signal_set="direct_hist_v3_mclk125",
        clock=MCLK125_CLOCK,
        default_trigger=f"{CP_PREFIX}data_sc_merger_out_valid",
        trigger_prefix="sc_merger_out_valid",
    ),
    DomainConfig(
        key="cclk156",
        instance="direct_hist_v3_cclk156",
        signal_set="direct_hist_v3_cclk156",
        clock=CCLK156_CLOCK,
        default_trigger=f"{QSYS}upload_data0_sc_rc_valid",
        trigger_prefix="sc_upload_rc_valid",
    ),
)


def add(probes: list[Probe], domain: str, group: str, *names: str) -> None:
    probes.extend(Probe(domain, group, name) for name in names)


def add_bits(probes: list[Probe], domain: str, group: str, stem: str, width: int) -> None:
    probes.extend(Probe(domain, group, f"{stem}[{idx}]") for idx in range(width))


def add_bit_range(
    probes: list[Probe], domain: str, group: str, stem: str, first: int, last: int
) -> None:
    step = 1 if last >= first else -1
    for idx in range(first, last + step, step):
        probes.append(Probe(domain, group, f"{stem}[{idx}]"))


def type0_tap(lane: int) -> str:
    return f"{DP_PREFIX}hit_type0_tap2:hist_type0_lane{lane}_tap|"


def type1_tap(bank: str) -> str:
    return f"{DP_PREFIX}avst_snoop_splitter:hist_type1_{bank}_tap|"


def default_probes() -> list[Probe]:
    probes: list[Probe] = []

    add(
        probes,
        "lvds",
        "00 reset_and_hist_control",
        f"{HIST}i_rst",
        f"{HIST}cfg_source_select[0]",
        f"{HIST}cfg_source_select[1]",
        f"{HIST}csr_source_select[0]",
        f"{HIST}csr_source_select[1]",
        f"{HIST}csr_mode[0]",
        f"{HIST}csr_mode[1]",
        f"{HIST}csr_mode[2]",
        f"{HIST}csr_mode[3]",
        f"{HIST}measure_clear_pulse",
        f"{HIST}bank_pending[0]",
        f"{HIST}bank_pending[1]",
    )
    add_bits(probes, "lvds", "00 reset_and_hist_control", f"{HIST}csr_bin_width", 16)

    for lane in range(8):
        group = f"01 type0_lane{lane}_direct"
        tap = type0_tap(lane)
        add(
            probes,
            "lvds",
            group,
            f"{tap}asi_in_valid",
            f"{tap}aso_hist_valid",
            f"{tap}aso_hist_startofpacket",
            f"{tap}aso_hist_endofpacket",
            f"{HIST}asi_type0_lane{lane}_valid",
            f"{HIST}asi_type0_lane{lane}_ready",
        )
        add_bits(probes, "lvds", group, f"{tap}aso_hist_channel", 4)
        add_bits(probes, "lvds", group, f"{HIST}asi_type0_lane{lane}_channel", 4)

    add_bits(
        probes, "lvds", "01 type0_lane0_data_sample", f"{HIST}asi_type0_lane0_data", 45
    )

    for bank in ("up", "down"):
        group = f"02 type1_{bank}_direct"
        tap = type1_tap(bank)
        add(
            probes,
            "lvds",
            group,
            f"{tap}asi_valid",
            f"{tap}asi_ready",
            f"{tap}aso_out1_valid",
            f"{tap}aso_out1_ready",
            f"{tap}aso_out1_startofpacket",
            f"{tap}aso_out1_endofpacket",
            f"{HIST}asi_type1_{bank}_valid",
            f"{HIST}asi_type1_{bank}_ready",
        )
        add_bits(probes, "lvds", group, f"{tap}aso_out1_channel", 4)
        add_bits(probes, "lvds", group, f"{HIST}asi_type1_{bank}_channel", 4)
        add_bits(probes, "lvds", f"02 type1_{bank}_data_sample", f"{tap}aso_out1_data", 39)

    add_bit_range(
        probes,
        "lvds",
        "03 type1_up_timestamp_sideband",
        f"{HIST}asi_type1_up_ts",
        0,
        15,
    )
    add_bit_range(
        probes,
        "lvds",
        "03 type1_up_timestamp_sideband",
        f"{HIST}asi_type1_up_ts",
        32,
        47,
    )
    add_bit_range(
        probes,
        "lvds",
        "03 type1_down_timestamp_sideband",
        f"{HIST}asi_type1_down_ts",
        0,
        15,
    )
    add_bit_range(
        probes,
        "lvds",
        "03 type1_down_timestamp_sideband",
        f"{HIST}asi_type1_down_ts",
        32,
        47,
    )

    add(
        probes,
        "lvds",
        "04 hist_csr_boundary",
        f"{HIST}avs_csr_read",
        f"{HIST}avs_csr_write",
        f"{HIST}avs_csr_waitrequest",
    )
    add_bits(probes, "lvds", "04 hist_csr_boundary", f"{HIST}avs_csr_address", 5)
    add_bits(probes, "lvds", "04 hist_csr_boundary", f"{HIST}avs_csr_writedata", 32)
    add_bits(probes, "lvds", "04 hist_csr_boundary", f"{HIST}avs_csr_readdata", 32)

    add(
        probes,
        "lvds",
        "05 hist_update_and_coalescing",
        f"{HIST}queue_hit_valid",
        f"{HIST}coalescing_queue:queue_inst|i_hit_valid",
        f"{HIST}coalescing_queue:queue_inst|drain_valid_q",
        f"{HIST}coalescing_queue:queue_inst|drain_fire_c",
        f"{HIST}drop_pulse[0]",
        f"{HIST}drop_pulse[1]",
        f"{HIST}drop_pulse[2]",
        f"{HIST}drop_pulse[3]",
        f"{HIST}drop_pulse[4]",
        f"{HIST}drop_pulse[5]",
        f"{HIST}drop_pulse[6]",
        f"{HIST}drop_pulse[7]",
    )
    add_bits(probes, "lvds", "05 hist_update_and_coalescing", f"{HIST}queue_hit_bin", 8)
    add_bits(probes, "lvds", "05 hist_update_and_coalescing", f"{HIST}coalescing_queue:queue_inst|i_hit_bin", 8)
    add_bits(probes, "lvds", "05 hist_update_and_coalescing", f"{HIST}coalescing_queue:queue_inst|drain_bin_q", 8)
    add_bits(probes, "lvds", "05 hist_update_and_coalescing", f"{HIST}coalescing_queue:queue_inst|drain_count_q", 4)
    add_bits(probes, "lvds", "05 hist_update_and_coalescing", f"{HIST}csr_total_hits", 20)
    add_bits(probes, "lvds", "05 hist_update_and_coalescing", f"{HIST}csr_dropped_hits", 20)

    add(
        probes,
        "mclk125",
        "06b sc_download_wrapper_125",
        f"{FEB_WRAPPER}download_sc_data_125",
        f"{FEB_WRAPPER}download_sc_datak_125",
        f"{QSYS}download_sc_ready",
        f"{QSYS}download_sc_data",
        f"{QSYS}download_sc_datak",
    )

    add_bits(
        probes,
        "cclk156",
        "07 sc_upload_firefly_in",
        f"{FIREFLY}i_upload_data0_sc_rc_data",
        36,
    )
    add(
        probes,
        "cclk156",
        "07 sc_upload_qsys",
        f"{QSYS}upload_data0_sc_rc_valid",
        f"{QSYS}upload_data0_sc_rc_ready",
        f"{QSYS}upload_data0_sc_rc_startofpacket",
        f"{QSYS}upload_data0_sc_rc_endofpacket",
    )
    add_bits(probes, "cclk156", "07 sc_upload_qsys", f"{QSYS}upload_data0_sc_rc_data", 36)
    add_bits(probes, "cclk156", "07 sc_upload_qsys", f"{QSYS}upload_data0_sc_rc_channel", 2)

    add(
        probes,
        "mclk125",
        "08 sc_qsys_control_upload",
        f"{CP_PREFIX}data_sc_merger_out_valid",
        f"{CP_PREFIX}data_sc_merger_out_ready",
        f"{CP_PREFIX}data_sc_merger_out_startofpacket",
        f"{CP_PREFIX}data_sc_merger_out_endofpacket",
        f"{UPLOAD_PREFIX}ext_hard_reset_reset",
    )
    add_bits(probes, "mclk125", "08 sc_qsys_control_upload", f"{CP_PREFIX}data_sc_merger_out_data", 36)

    add(
        probes,
        "cclk156",
        "09a runctl_upload_transport",
        f"{UPLOAD_PREFIX}runctl_mgmt_host_valid",
    )
    add_bits(probes, "cclk156", "09a runctl_upload_transport", f"{UPLOAD_PREFIX}runctl_mgmt_host_data", 9)

    add(
        probes,
        "lvds",
        "09b runctl_rstlink_datapath",
        f"{DP_PREFIX}runctl_mgmt_host_valid",
        f"{DP_PREFIX}runctl_mgmt_host_ready",
    )
    add_bits(probes, "lvds", "09b runctl_rstlink_datapath", f"{DP_PREFIX}runctl_mgmt_host_data", 9)
    add_bits(probes, "lvds", "09b runctl_rstlink_datapath", f"{DP_PREFIX}rstlink_data", 9)
    add_bits(probes, "lvds", "09b runctl_rstlink_datapath", f"{DP_PREFIX}rstlink_channel", 4)
    add_bits(probes, "lvds", "09b runctl_rstlink_datapath", f"{DP_PREFIX}rstlink_error", 3)

    return probes


def add_single(parent: ET.Element, attribute: str, value: str) -> None:
    ET.SubElement(parent, "single", {"attribute": attribute, "value": value})


def add_multi(parent: ET.Element, attribute: str, size: str, value: str) -> None:
    ET.SubElement(parent, "multi", {"attribute": attribute, "size": size, "value": value})


def infer_type(_name: str) -> str:
    return "unknown"


def add_instance(
    root: ET.Element,
    config: DomainConfig,
    domain_probes: list[Probe],
    sample_depth: int,
    trigger_signal: str,
    trigger_mode: str,
    instance_id: int,
) -> None:
    stamp = dt.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")
    trigger_suffix = "rise" if trigger_mode == "rising_edge" else "high"
    trigger_name = f"{config.trigger_prefix}_{trigger_suffix}"
    signals = [probe.name for probe in domain_probes]

    instance = ET.SubElement(
        root,
        "instance",
        {
            "enabled": "true",
            "entity_name": "sld_signaltap",
            "is_auto_node": "yes",
            "name": config.instance,
            "source_file": "sld_signaltap.vhd",
        },
    )
    ET.SubElement(
        instance,
        "node_ip_info",
        {"instance_id": str(instance_id), "mfg_id": "110", "node_id": str(instance_id), "version": "6"},
    )

    position_info = ET.SubElement(instance, "position_info")
    add_single(position_info, "active tab", "1")
    add_single(position_info, "setup vertical scroll position", "0")
    add_single(position_info, "setup horizontal scroll position", "0")

    signal_set = ET.SubElement(instance, "signal_set", {"name": config.signal_set})
    signal_set.append(ET.Comment(f"Generated {stamp} UTC"))
    signal_set.append(ET.Comment(f"Clock domain: {config.key}. Import with quartus_stp to refresh trigger CRC metadata before compile."))
    ET.SubElement(signal_set, "clock", {"name": config.clock, "polarity": "posedge", "tap_mode": "classic"})
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
    for index, probe in enumerate(domain_probes):
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



def build_stp(
    sample_depth: int,
    trigger_signal: str,
    trigger_mode: str,
    domains: set[str] | None = None,
) -> ET.ElementTree:
    probes = default_probes()

    root = ET.Element("session", {"sof_file": ""})
    display_tree = ET.SubElement(root, "display_tree", {"gui_logging_enabled": "0"})

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

    selected_configs = [config for config in DOMAIN_CONFIGS if domains is None or config.key in domains]
    for instance_id, config in enumerate(selected_configs):
        domain_probes = [probe for probe in probes if probe.domain == config.key]
        if not domain_probes:
            continue
        domain_trigger = trigger_signal if config.key == "lvds" else config.default_trigger
        trigger_suffix = "rise" if trigger_mode == "rising_edge" else "high"
        trigger_name = f"{config.trigger_prefix}_{trigger_suffix}"
        ET.SubElement(
            display_tree,
            "display_branch",
            {
                "instance": config.instance,
                "signal_set": config.signal_set,
                "trigger": trigger_name,
            },
        )
        add_instance(
            root,
            config,
            domain_probes,
            sample_depth,
            domain_trigger,
            trigger_mode,
            instance_id,
        )

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
    parser.add_argument(
        "--domains",
        default="all",
        help="Comma-separated domains to emit: lvds,mclk125,cclk156, or all",
    )
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
    valid_domains = {config.key for config in DOMAIN_CONFIGS}
    if args.domains == "all":
        domains = None
    else:
        domains = {domain.strip() for domain in args.domains.split(",") if domain.strip()}
        unknown = domains - valid_domains
        if unknown:
            raise SystemExit(f"unknown --domains value(s): {', '.join(sorted(unknown))}")
        if not domains:
            raise SystemExit("--domains selected no domains")

    tree = build_stp(args.sample_depth, args.trigger_signal, args.trigger_mode, domains)
    indent(tree.getroot())

    output = Path(args.output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    tree.write(output, encoding="utf-8", xml_declaration=False)
    output.write_text(output.read_text(encoding="utf-8") + "\n", encoding="utf-8")
    print(f"wrote {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
