#!/usr/bin/env python3
"""Append a dedicated MTS-clock SignalTap instance to the FEB v4 STP.

The active bring-up STP already contains the `lvds_decoded` instance and a
large amount of GUI capture log payload.  This helper preserves that instance
byte-for-byte as much as practical and inserts a second instance named
`mts_debug`, clocked by the MTS datapath clock net.
"""
from __future__ import annotations

import argparse
import datetime as dt
import re
from pathlib import Path


DP = (
    "feb_system:u_feb_system|feb_system_v4:u_qsys|"
    "feb_system_v4_data_path_subsystem:data_path_subsystem|"
)
MTS0 = (
    DP
    + "feb_system_v4_data_path_subsystem_mts_preprocessor_0:mts_preprocessor_0|"
    + "mts_processor:mts_preprocessor_0|"
)
MTS1 = (
    DP
    + "feb_system_v4_data_path_subsystem_mts_preprocessor_1:mts_preprocessor_1|"
    + "mts_processor:mts_preprocessor_1|"
)
MTS_CLK = DP + "mu3e_lvds_controller_0_outclock_clk"


NET_ATTRS = (
    'duplicate_name_allowed="false" is_data_input="true" '
    'is_node_valid="true" is_storage_input="true" '
    'is_trigger_input="true"'
)
ACTIVE_TRIGGER = "rising edge"


def vec(base: str, hi: int, lo: int = 0) -> list[str]:
    return [f"{base}[{idx}]" for idx in range(hi, lo - 1, -1)]


def mts_probe_entries(prefix: str, label: str) -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = [
        ("divider", f"{label} guaranteed MTS-clock trigger"),
        ("sig", prefix + "stp_mts_freerun_toggle_q"),
        ("divider", f"{label} accepted Type0 input"),
        ("sig", prefix + "asi_hit_type0_valid"),
        ("sig", prefix + "asi_hit_type0_ready_i"),
        *[("sig", sig) for sig in vec(prefix + "asi_hit_type0_channel", 5)],
        ("sig", prefix + "hit_type0_low_channel_in_window"),
        ("sig", prefix + "hit_in_ok"),
        ("sig", prefix + "stp_asi_hit_type0_accept_q"),
        *[("sig", sig) for sig in vec(prefix + "stp_asi_hit_type0_channel_q", 5)],
        ("divider", f"{label} source ASIC sideband"),
        *[("sig", sig) for sig in vec(prefix + "stp_source_asic_stage0_q", 3)],
        *[("sig", sig) for sig in vec(prefix + "stp_source_asic_stage_last_q", 3)],
        ("divider", f"{label} Type1 output"),
        ("sig", prefix + "stp_aso_hit_type1_valid_q"),
        *[("sig", sig) for sig in vec(prefix + "stp_aso_hit_type1_asic_q", 3)],
        ("sig", prefix + "aso_hit_type1_valid"),
        *[("sig", sig) for sig in vec(prefix + "aso_hit_type1_data", 38, 35)],
    ]
    return entries


def top_level_entries() -> list[tuple[str, str]]:
    entries: list[tuple[str, str]] = [
        ("divider", "Qsys mux outputs before MTS"),
        ("sig", DP + "mux_mutrig2processor_out_valid"),
        *[("sig", sig) for sig in vec(DP + "mux_mutrig2processor_out_channel", 5)],
        ("sig", DP + "mux_mutrig2processor_0_out_valid"),
        *[("sig", sig) for sig in vec(DP + "mux_mutrig2processor_0_out_channel", 5)],
        ("divider", "Qsys Type1 taps toward histogram"),
        ("sig", DP + "mts_preprocessor_0_hit_type1_out_valid"),
        *[("sig", sig) for sig in vec(DP + "mts_preprocessor_0_hit_type1_out_data", 38, 35)],
        ("sig", DP + "mts_preprocessor_0_hit_type1_extended_0_valid"),
        *[("sig", sig) for sig in vec(DP + "mts_preprocessor_0_hit_type1_extended_0_data", 38, 35)],
        ("sig", DP + "hist_type1_up_tap_out1_valid"),
        *[("sig", sig) for sig in vec(DP + "hist_type1_up_tap_out1_data", 38, 35)],
        ("sig", DP + "mts_preprocessor_1_hit_type1_out_valid"),
        *[("sig", sig) for sig in vec(DP + "mts_preprocessor_1_hit_type1_out_data", 38, 35)],
        ("sig", DP + "mts_preprocessor_1_hit_type1_extended_1_valid"),
        *[("sig", sig) for sig in vec(DP + "mts_preprocessor_1_hit_type1_extended_1_data", 38, 35)],
        ("sig", DP + "hist_type1_down_tap_out1_valid"),
        *[("sig", sig) for sig in vec(DP + "hist_type1_down_tap_out1_data", 38, 35)],
    ]
    return entries


def signals_of(entries: list[tuple[str, str]]) -> list[str]:
    return [name for kind, name in entries if kind == "sig"]


def wire_vec(signals: list[str]) -> str:
    return "\n".join(
        f'          <wire name="{name}" tap_mode="classic"/>' for name in signals
    )


def level_attr(name: str, trigger_signal: str) -> str:
    level = ACTIVE_TRIGGER if name == trigger_signal else "dont_care"
    return f' level-0="{level}"'


def node_view(entries: list[tuple[str, str]], trigger_signal: str) -> str:
    rows: list[str] = []
    for kind, name in entries:
        if kind == "divider":
            rows.append(f'          <divider name="{name}"/>')
        else:
            rows.append(
                f'          <node {NET_ATTRS} name="{name}" tap_mode="classic" '
                f'type="unknown"{level_attr(name, trigger_signal)}/>'
            )
    return "\n".join(rows)


def index_view(entries: list[tuple[str, str]], trigger_signal: str) -> str:
    rows: list[str] = []
    idx = 0
    for kind, name in entries:
        if kind == "divider":
            rows.append(f'          <divider name="{name}"/>')
        else:
            rows.append(
                f'          <net data_index="{idx}" {NET_ATTRS} name="{name}" '
                f'storage_index="{idx}" tap_mode="classic" trigger_index="{idx}" '
                f'type="unknown"{level_attr(name, trigger_signal)}/>'
            )
            idx += 1
    return "\n".join(rows)


def instance_block(depth: int, instance_id: int) -> str:
    entries = (
        mts_probe_entries(MTS0, "MTS0/Type1-up")
        + mts_probe_entries(MTS1, "MTS1/Type1-down")
        + top_level_entries()
    )
    signals = signals_of(entries)
    wires = wire_vec(signals)
    sq_pattern = "1" * len(signals)
    trigger_signal = MTS0 + "stp_mts_freerun_toggle_q"
    timestamp = dt.datetime.utcnow().strftime("%Y/%m/%d %H:%M:%S")

    return f'''  <instance enabled="true" entity_name="sld_signaltap" is_auto_node="yes" is_expanded="true" name="mts_debug" source_file="sld_signaltap.vhd">
    <node_ip_info instance_id="{instance_id}" mfg_id="110" node_id="0" version="6"/>
    <signal_set is_expanded="true" name="mts_debug">
      <!--Generated {timestamp} UTC by add_mts_debug_instance.py.-->
      <!--Dedicated MTS-clock capture; trigger is the preserved MTS0 free-running toggle.-->
      <clock name="{MTS_CLK}" polarity="posedge" tap_mode="classic"/>
      <config pipeline_level="0" ram_type="AUTO" reserved_data_nodes="0" reserved_storage_qualifier_nodes="0" reserved_trigger_nodes="0" sample_depth="{depth}" trigger_in_enable="no" trigger_out_enable="no"/>
      <top_entity/>
      <signal_vec>
        <trigger_input_vec>
{wires}
        </trigger_input_vec>
        <data_input_vec>
{wires}
        </data_input_vec>
        <storage_qualifier_input_vec>
{wires}
        </storage_qualifier_input_vec>
      </signal_vec>
      <presentation>
        <unified_setup_data_view>
{node_view(entries, trigger_signal)}
        </unified_setup_data_view>
        <data_view>
{index_view(entries, trigger_signal)}
        </data_view>
        <setup_view>
{index_view(entries, trigger_signal)}
        </setup_view>
        <trigger_in_editor/>
        <trigger_out_editor/>
      </presentation>
      <trigger attribute_mem_mode="false" gap_record="true" is_expanded="true" name="mts_debug_trig" position="pre" power_up_trigger_mode="false" record_data_gap="true" segment_size="1" storage_mode="off" storage_qualifier_disabled="no" storage_qualifier_port_is_pin="true" storage_qualifier_port_name="auto_stp_external_storage_qualifier" storage_qualifier_port_tap_mode="classic" trigger_type="circular">
        <power_up_trigger position="pre" storage_qualifier_disabled="no"/>
        <events use_custom_flow_control="no">
          <level enabled="yes" name="condition1" type="basic">'{trigger_signal}' == {ACTIVE_TRIGGER}
            <power_up enabled="yes"/>
            <op_node/>
          </level>
        </events>
        <storage_qualifier_events>
          <transitional>{sq_pattern}<pwr_up_transitional>{sq_pattern}</pwr_up_transitional>
          </transitional>
          <storage_qualifier_level type="basic">
            <power_up/>
            <op_node/>
          </storage_qualifier_level>
        </storage_qualifier_events>
      </trigger>
    </signal_set>
    <position_info>
      <single attribute="active tab" value="1"/>
    </position_info>
  </instance>
'''


def remove_existing_mts_debug(text: str) -> str:
    text = re.sub(
        r'\n?  <display_branch instance="mts_debug"[^/]*/>\n?',
        "\n",
        text,
    )
    return re.sub(
        r'\n?  <instance[^>]*name="mts_debug"[\s\S]*?\n  </instance>\n?',
        "\n",
        text,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("stp", type=Path)
    parser.add_argument("--depth", type=int, default=4096)
    parser.add_argument("--instance-id", type=int, default=5)
    args = parser.parse_args()

    text = args.stp.read_text()
    text = remove_existing_mts_debug(text)

    display_branch = (
        '    <display_branch instance="mts_debug" signal_set="mts_debug" '
        'trigger="mts_debug_trig"/>\n'
    )
    if "</display_tree>" not in text:
        raise SystemExit("STP has no display_tree close tag")
    text = text.replace("  </display_tree>\n", display_branch + "  </display_tree>\n", 1)

    block = instance_block(args.depth, args.instance_id)
    marker = "  <mnemonics"
    idx = text.find(marker)
    if idx < 0:
        marker = "  <static_plugin_mnemonics"
        idx = text.find(marker)
    if idx < 0:
        raise SystemExit("STP has no mnemonics insertion point")
    text = text[:idx] + block + text[idx:]

    args.stp.write_text(text)
    print(f"updated {args.stp}")
    print(f"  mts_debug probes: {len(signals_of(mts_probe_entries(MTS0, 'x') + mts_probe_entries(MTS1, 'y') + top_level_entries()))}")
    print(f"  sample clock: {MTS_CLK}")
    print(f"  trigger: {MTS0}stp_mts_freerun_toggle_q == {ACTIVE_TRIGGER}")


if __name__ == "__main__":
    main()
