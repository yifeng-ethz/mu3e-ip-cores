#!/usr/bin/env python3

from __future__ import annotations

import argparse
from pathlib import Path


FILES = [
    "scifi_datapath_system_v3_hit_stack_subsystem_0.vhd",
    "scifi_datapath_system_v3_hit_stack_subsystem_1.vhd",
]


REPLACEMENTS = {
    "asi_ctrl_datapath_data        => run_control_splitter_0_out4_data,": "asi_ctrl_datapath_data        => run_control_signal_data,",
    "asi_ctrl_datapath_valid       => run_control_splitter_0_out4_valid,": "asi_ctrl_datapath_valid       => run_control_signal_valid,",
    "asi_ctrl_xcvr_data            => run_ctrl_cdc_d2x_out_data,": "asi_ctrl_xcvr_data            => run_control_signal_data,",
    "asi_ctrl_xcvr_valid           => run_ctrl_cdc_d2x_out_valid,": "asi_ctrl_xcvr_valid           => run_control_signal_valid,",
    "asi_hit_type1_channel       => data_splitter_0_out0_channel,": "asi_hit_type1_channel       => hit_type_1_channel,",
    "asi_hit_type1_startofpacket => data_splitter_0_out0_startofpacket,": "asi_hit_type1_startofpacket => hit_type_1_startofpacket,",
    "asi_hit_type1_endofpacket   => data_splitter_0_out0_endofpacket,": "asi_hit_type1_endofpacket   => hit_type_1_endofpacket,",
    "asi_hit_type1_empty         => data_splitter_0_out0_empty(0),": "asi_hit_type1_empty         => hit_type_1_empty(0),",
    "asi_hit_type1_data          => data_splitter_0_out0_data,": "asi_hit_type1_data          => hit_type_1_data,",
    "asi_hit_type1_valid         => data_splitter_0_out0_valid,": "asi_hit_type1_valid         => hit_type_1_valid,",
    "asi_hit_type1_error         => data_splitter_0_out0_error(0),": "asi_hit_type1_error         => hit_type_1_error(0),",
    "asi_ctrl_data               => run_control_splitter_0_out0_data,": "asi_ctrl_data               => run_control_signal_data,",
    "asi_ctrl_valid              => run_control_splitter_0_out0_valid,": "asi_ctrl_valid              => run_control_signal_valid,",
    "asi_hit_type1_channel       => data_splitter_0_out1_channel,": "asi_hit_type1_channel       => (others => '0'),",
    "asi_hit_type1_startofpacket => data_splitter_0_out1_startofpacket,": "asi_hit_type1_startofpacket => '0',",
    "asi_hit_type1_endofpacket   => data_splitter_0_out1_endofpacket,": "asi_hit_type1_endofpacket   => '0',",
    "asi_hit_type1_empty         => data_splitter_0_out1_empty(0),": "asi_hit_type1_empty         => '0',",
    "asi_hit_type1_data          => data_splitter_0_out1_data,": "asi_hit_type1_data          => (others => '0'),",
    "asi_hit_type1_valid         => data_splitter_0_out1_valid,": "asi_hit_type1_valid         => '0',",
    "asi_hit_type1_error         => data_splitter_0_out1_error(0),": "asi_hit_type1_error         => '0',",
    "asi_ctrl_data               => run_control_splitter_0_out1_data,": "asi_ctrl_data               => (others => '0'),",
    "asi_ctrl_valid              => run_control_splitter_0_out1_valid,": "asi_ctrl_valid              => '0',",
    "asi_hit_type1_channel       => data_splitter_0_out2_channel,": "asi_hit_type1_channel       => (others => '0'),",
    "asi_hit_type1_startofpacket => data_splitter_0_out2_startofpacket,": "asi_hit_type1_startofpacket => '0',",
    "asi_hit_type1_endofpacket   => data_splitter_0_out2_endofpacket,": "asi_hit_type1_endofpacket   => '0',",
    "asi_hit_type1_empty         => data_splitter_0_out2_empty(0),": "asi_hit_type1_empty         => '0',",
    "asi_hit_type1_data          => data_splitter_0_out2_data,": "asi_hit_type1_data          => (others => '0'),",
    "asi_hit_type1_valid         => data_splitter_0_out2_valid,": "asi_hit_type1_valid         => '0',",
    "asi_hit_type1_error         => data_splitter_0_out2_error(0),": "asi_hit_type1_error         => '0',",
    "asi_ctrl_data               => run_control_splitter_0_out2_data,": "asi_ctrl_data               => (others => '0'),",
    "asi_ctrl_valid              => run_control_splitter_0_out2_valid,": "asi_ctrl_valid              => '0',",
    "asi_hit_type1_channel       => data_splitter_0_out3_channel,": "asi_hit_type1_channel       => (others => '0'),",
    "asi_hit_type1_startofpacket => data_splitter_0_out3_startofpacket,": "asi_hit_type1_startofpacket => '0',",
    "asi_hit_type1_endofpacket   => data_splitter_0_out3_endofpacket,": "asi_hit_type1_endofpacket   => '0',",
    "asi_hit_type1_empty         => data_splitter_0_out3_empty(0),": "asi_hit_type1_empty         => '0',",
    "asi_hit_type1_data          => data_splitter_0_out3_data,": "asi_hit_type1_data          => (others => '0'),",
    "asi_hit_type1_valid         => data_splitter_0_out3_valid,": "asi_hit_type1_valid         => '0',",
    "asi_hit_type1_error         => data_splitter_0_out3_error(0),": "asi_hit_type1_error         => '0',",
    "asi_ctrl_data               => run_control_splitter_0_out3_data,": "asi_ctrl_data               => (others => '0'),",
    "asi_ctrl_valid              => run_control_splitter_0_out3_valid,": "asi_ctrl_valid              => '0',",
}


def patch_file(src: Path, dst: Path) -> None:
    text = src.read_text()
    original = text
    for old, new in REPLACEMENTS.items():
        text = text.replace(old, new)
    if text == original:
        raise RuntimeError(f"no replacements applied to {src}")
    dst.write_text(text)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--synth-dir", required=True, type=Path)
    parser.add_argument("--out-dir", required=True, type=Path)
    args = parser.parse_args()

    args.out_dir.mkdir(parents=True, exist_ok=True)
    submodules = args.synth_dir / "submodules"
    for name in FILES:
        patch_file(submodules / name, args.out_dir / name)


if __name__ == "__main__":
    main()
