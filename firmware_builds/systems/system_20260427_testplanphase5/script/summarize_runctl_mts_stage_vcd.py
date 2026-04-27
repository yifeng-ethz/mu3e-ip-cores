#!/usr/bin/env python3
"""Summarize the Phase 4 run-control-to-MTS SignalTap VCD."""

from __future__ import annotations

import argparse
from pathlib import Path


QSYS = "feb_system:u_feb_system|feb_system_v3_pipe:u_qsys|"
DP_PREFIX = f"{QSYS}feb_system_v3_pipe_data_path_subsystem:data_path_subsystem|"
UP_PREFIX = f"{QSYS}feb_system_v3_pipe_upload_subsystem:upload_subsystem|"
SPLITTER_PREFIX = f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_run_control_splitter:run_control_splitter|"
RESET_PREFIX = f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_rst_controller:rst_controller_001|"
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

ADAPTER_PREFIX = {
    "mts0_adapter": f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_avalon_st_adapter_017:avalon_st_adapter_019|",
    "deasm0_adapter": f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_avalon_st_adapter_017:avalon_st_adapter_026|",
    "mts1_adapter": f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_avalon_st_adapter_017:avalon_st_adapter_022|",
    "emu_adapter": f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_avalon_st_adapter_017:avalon_st_adapter_025|",
}

MTS_PREFIX = {
    "mts0": f"{DP_PREFIX}mts_processor:mts_preprocessor_0|",
    "mts1": f"{DP_PREFIX}mts_processor:mts_preprocessor_1|",
}

DEASM0_PREFIX = (
    f"{DP_PREFIX}"
    "feb_system_v3_pipe_data_path_subsystem_mutrig_datapath_subsystem_0:mutrig_datapath_subsystem_0|"
    "frame_rcv_ip:mutrig_frame_deassembly_0|"
)
EMU0_PREFIX = f"{DP_PREFIX}emulator_mutrig:emulator_mutrig_0|"


def add_bus(
    mapping: dict[str, str],
    path_prefix: str,
    canonical_prefix: str,
    path_name: str,
    width: int,
    canonical_name: str = "data",
) -> None:
    for idx in range(width):
        mapping[f"{path_prefix}{path_name}[{idx}]"] = f"{canonical_prefix}.{canonical_name}[{idx}]"


def add_stream(mapping: dict[str, str], path_prefix: str, canonical_prefix: str, name: str, ready: bool = False) -> None:
    mapping[f"{path_prefix}{name}_valid"] = f"{canonical_prefix}.valid"
    add_bus(mapping, path_prefix, canonical_prefix, f"{name}_data", 9)
    if ready:
        mapping[f"{path_prefix}{name}_ready"] = f"{canonical_prefix}.ready"


def add_ctrl_sink(mapping: dict[str, str], path_prefix: str, canonical_prefix: str) -> None:
    mapping[f"{path_prefix}asi_ctrl_valid"] = f"{canonical_prefix}.ctrl_valid"
    add_bus(mapping, path_prefix, canonical_prefix, "asi_ctrl_data", 9)
    mapping[f"{path_prefix}asi_ctrl_ready"] = f"{canonical_prefix}.ctrl_ready"
    for state in ("RUN_PREPARE", "SYNC", "RUNNING", "TERMINATING"):
        mapping[f"{path_prefix}run_state_cmd.{state}"] = f"{canonical_prefix}.run_state_{state.lower()}"


def add_deasm_gate(mapping: dict[str, str], path_prefix: str, canonical_prefix: str) -> None:
    for name in (
        "receiver_go",
        "enable",
        "i_byteisk",
        "n_frame_info_ready",
        "aso_hit_type0_startofpacket",
        "aso_hit_type0_endofpacket",
    ):
        mapping[f"{path_prefix}{name}"] = f"{canonical_prefix}.{name}"
    add_bus(mapping, path_prefix, canonical_prefix, "i_data", 8, "i_data")
    add_bus(mapping, path_prefix, canonical_prefix, "asi_rx8b1k_data", 9, "rx8b1k_data")
    add_bus(mapping, path_prefix, canonical_prefix, "p_frame_flags", 6, "p_frame_flags")
    add_bus(mapping, path_prefix, canonical_prefix, "p_frame_len", 10, "p_frame_len")
    for state in (
        "FS_IDLE",
        "FS_FRAME_COUNTER",
        "FS_EVENT_COUNTER",
        "FS_UNPACK",
        "FS_UNPACK_EXTRA",
        "FS_CRC_CALC",
        "FS_CRC_CHECK",
        "FS_ERROR",
    ):
        mapping[f"{path_prefix}p_state.{state}"] = f"{canonical_prefix}.state_{state.lower()}"


def add_vcd_bus(
    mapping: dict[str, str],
    scope_prefix: str,
    canonical_prefix: str,
    path_name: str,
    width: int,
    canonical_name: str = "data",
) -> None:
    for idx in range(width):
        mapping[f"{scope_prefix}{path_name}[{idx}]"] = f"{canonical_prefix}.{canonical_name}[{idx}]"


def add_vcd_stream(
    mapping: dict[str, str],
    scope_prefix: str,
    canonical_prefix: str,
    name: str,
    ready: bool = False,
) -> None:
    mapping[f"{scope_prefix}{name}_valid"] = f"{canonical_prefix}.valid"
    add_vcd_bus(mapping, scope_prefix, canonical_prefix, f"{name}_data", 9)
    if ready:
        mapping[f"{scope_prefix}{name}_ready"] = f"{canonical_prefix}.ready"


def add_vcd_ctrl_sink(mapping: dict[str, str], scope_prefix: str, canonical_prefix: str) -> None:
    mapping[f"{scope_prefix}asi_ctrl_valid"] = f"{canonical_prefix}.ctrl_valid"
    add_vcd_bus(mapping, scope_prefix, canonical_prefix, "asi_ctrl_data", 9)
    mapping[f"{scope_prefix}asi_ctrl_ready"] = f"{canonical_prefix}.ctrl_ready"
    for state in ("RUN_PREPARE", "SYNC", "RUNNING", "TERMINATING"):
        mapping[f"{scope_prefix}run_state_cmd.{state}"] = f"{canonical_prefix}.run_state_{state.lower()}"


def add_vcd_deasm_gate(mapping: dict[str, str], scope_prefix: str, canonical_prefix: str) -> None:
    for name in (
        "receiver_go",
        "enable",
        "i_byteisk",
        "n_frame_info_ready",
        "aso_hit_type0_startofpacket",
        "aso_hit_type0_endofpacket",
    ):
        mapping[f"{scope_prefix}{name}"] = f"{canonical_prefix}.{name}"
    add_vcd_bus(mapping, scope_prefix, canonical_prefix, "i_data", 8, "i_data")
    add_vcd_bus(mapping, scope_prefix, canonical_prefix, "asi_rx8b1k_data", 9, "rx8b1k_data")
    add_vcd_bus(mapping, scope_prefix, canonical_prefix, "p_frame_flags", 6, "p_frame_flags")
    add_vcd_bus(mapping, scope_prefix, canonical_prefix, "p_frame_len", 10, "p_frame_len")
    for state in (
        "FS_IDLE",
        "FS_FRAME_COUNTER",
        "FS_EVENT_COUNTER",
        "FS_UNPACK",
        "FS_UNPACK_EXTRA",
        "FS_CRC_CALC",
        "FS_CRC_CHECK",
        "FS_ERROR",
    ):
        mapping[f"{scope_prefix}p_state.{state}"] = f"{canonical_prefix}.state_{state.lower()}"


def wanted_mapping() -> dict[str, str]:
    mapping: dict[str, str] = {
        f"{RESET_PREFIX}reset_out": "dp_reset",
        f"{UP_PREFIX}runctl_mgmt_host_valid": "up_host.valid",
        f"{DP_PREFIX}runctl_mgmt_host_valid": "dp_host.valid",
    }
    add_bus(mapping, UP_PREFIX, "up_host", "runctl_mgmt_host_data", 9)
    add_bus(mapping, DP_PREFIX, "dp_host", "runctl_mgmt_host_data", 9)

    for out_idx, label in ((1, "split_mts0"), (2, "split_deasm0"), (12, "split_mts1"), (15, "split_emu")):
        add_stream(mapping, SPLITTER_PREFIX, label, f"out{out_idx}")

    for label, prefix in ADAPTER_PREFIX.items():
        add_stream(mapping, prefix, label, "out_0", ready=True)

    for label, prefix in MTS_PREFIX.items():
        add_ctrl_sink(mapping, prefix, label)
        mapping[f"{prefix}processor_state.RUNNING"] = f"{label}.processor_running"
        mapping[f"{prefix}aso_hit_type1_valid"] = f"{label}.hit_type1_valid"
        mapping[f"{prefix}aso_hit_type1_ready"] = f"{label}.hit_type1_ready"

    add_ctrl_sink(mapping, DEASM0_PREFIX, "deasm0")
    mapping[f"{DEASM0_PREFIX}asi_rx8b1k_valid"] = "deasm0.rx8b1k_valid"
    mapping[f"{DEASM0_PREFIX}aso_hit_type0_valid"] = "deasm0.hit_type0_valid"
    add_deasm_gate(mapping, DEASM0_PREFIX, "deasm0")

    add_ctrl_sink(mapping, EMU0_PREFIX, "emu0")
    mapping[f"{EMU0_PREFIX}ctrl_state_q[3]"] = "emu0.ctrl_running"
    mapping[f"{EMU0_PREFIX}ctrl_state_q[4]"] = "emu0.ctrl_terminating"
    mapping[f"{EMU0_PREFIX}aso_tx8b1k_valid"] = "emu0.tx8b1k_valid"

    add_stream(mapping, MUX0_PREFIX, "mux0_asi_emu", "asi_emu")
    add_stream(mapping, MUX0_PREFIX, "mux0_aso", "aso")
    add_stream(mapping, ADAPTER034_PREFIX, "adapter034_in", "in_0")
    add_stream(mapping, ADAPTER034_PREFIX, "adapter034_out", "out_0", ready=True)
    add_stream(mapping, FIFO0_PREFIX, "fifo0_in", "in", ready=True)
    add_stream(mapping, FIFO0_PREFIX, "fifo0_out", "out", ready=True)
    add_stream(mapping, ADAPTER009_PREFIX, "adapter009_in", "in_0", ready=True)
    add_stream(mapping, ADAPTER009_PREFIX, "adapter009_out", "out_0")

    # Quartus' VCD exporter shortens hierarchy to instance module scopes. Keep
    # aliases for the exported form so the same summarizer works on both STP
    # node lists and VCD logs.
    vcd_dp = "u_feb_system/u_qsys/data_path_subsystem/"
    vcd_up = "u_feb_system/u_qsys/upload_subsystem/"
    mapping[f"{vcd_dp}rst_controller_001/reset_out"] = "dp_reset"
    mapping[f"{vcd_up}runctl_mgmt_host_valid"] = "up_host.valid"
    mapping[f"{vcd_dp}runctl_mgmt_host_valid"] = "dp_host.valid"
    add_vcd_bus(mapping, vcd_up, "up_host", "runctl_mgmt_host_data", 9)
    add_vcd_bus(mapping, vcd_dp, "dp_host", "runctl_mgmt_host_data", 9)

    for out_idx, label in ((1, "split_mts0"), (2, "split_deasm0"), (12, "split_mts1"), (15, "split_emu")):
        add_vcd_stream(mapping, f"{vcd_dp}run_control_splitter/", label, f"out{out_idx}")

    for scope, label in (
        ("avalon_st_adapter_019", "mts0_adapter"),
        ("avalon_st_adapter_026", "deasm0_adapter"),
        ("avalon_st_adapter_022", "mts1_adapter"),
        ("avalon_st_adapter_025", "emu_adapter"),
    ):
        add_vcd_stream(mapping, f"{vcd_dp}{scope}/", label, "out_0", ready=True)

    for scope, label in (("mts_preprocessor_0", "mts0"), ("mts_preprocessor_1", "mts1")):
        add_vcd_ctrl_sink(mapping, f"{vcd_dp}{scope}/", label)
        mapping[f"{vcd_dp}{scope}/processor_state.RUNNING"] = f"{label}.processor_running"
        mapping[f"{vcd_dp}{scope}/aso_hit_type1_valid"] = f"{label}.hit_type1_valid"
        mapping[f"{vcd_dp}{scope}/aso_hit_type1_ready"] = f"{label}.hit_type1_ready"

    vcd_deasm0 = f"{vcd_dp}mutrig_datapath_subsystem_0/mutrig_frame_deassembly_0/"
    add_vcd_ctrl_sink(mapping, vcd_deasm0, "deasm0")
    mapping[f"{vcd_deasm0}asi_rx8b1k_valid"] = "deasm0.rx8b1k_valid"
    mapping[f"{vcd_deasm0}aso_hit_type0_valid"] = "deasm0.hit_type0_valid"
    add_vcd_deasm_gate(mapping, vcd_deasm0, "deasm0")

    vcd_emu0 = f"{vcd_dp}emulator_mutrig_0/"
    add_vcd_ctrl_sink(mapping, vcd_emu0, "emu0")
    mapping[f"{vcd_emu0}ctrl_state_q[3]"] = "emu0.ctrl_running"
    mapping[f"{vcd_emu0}ctrl_state_q[4]"] = "emu0.ctrl_terminating"
    mapping[f"{vcd_emu0}aso_tx8b1k_valid"] = "emu0.tx8b1k_valid"
    add_vcd_stream(mapping, f"{vcd_dp}mutrig_lane_source_mux_0/", "mux0_asi_emu", "asi_emu")
    add_vcd_stream(mapping, f"{vcd_dp}mutrig_lane_source_mux_0/", "mux0_aso", "aso")
    add_vcd_stream(mapping, f"{vcd_dp}avalon_st_adapter_034/", "adapter034_in", "in_0")
    add_vcd_stream(mapping, f"{vcd_dp}avalon_st_adapter_034/", "adapter034_out", "out_0", ready=True)
    add_vcd_stream(mapping, f"{vcd_dp}decoded_lane_fifo_0/", "fifo0_in", "in", ready=True)
    add_vcd_stream(mapping, f"{vcd_dp}decoded_lane_fifo_0/", "fifo0_out", "out", ready=True)
    add_vcd_stream(mapping, f"{vcd_dp}avalon_st_adapter_009/", "adapter009_in", "in_0", ready=True)
    add_vcd_stream(mapping, f"{vcd_dp}avalon_st_adapter_009/", "adapter009_out", "out_0")
    return mapping


def parse_vcd(path: Path, wanted: dict[str, str]) -> list[tuple[int, dict[str, str]]]:
    symbol_to_name: dict[str, str] = {}
    state: dict[str, str] = {}
    samples: list[tuple[int, dict[str, str]]] = []
    cur_time: int | None = None
    time_has_updates = False
    in_defs = True
    scopes: list[str] = []

    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line:
                continue
            if in_defs:
                if line.startswith("$scope "):
                    parts = line.split()
                    if len(parts) >= 4:
                        scopes.append(parts[2])
                    continue
                if line == "$upscope $end":
                    if scopes:
                        scopes.pop()
                    continue
                if line.startswith("$var "):
                    parts = line.split()
                    if len(parts) >= 6 and "$end" in parts:
                        end_idx = parts.index("$end")
                        symbol = parts[3]
                        ref = " ".join(parts[4:end_idx]).strip()
                        if ref.startswith("\\"):
                            ref = ref[1:].strip()
                        full_ref = "/".join([*scopes, ref])
                        if full_ref in wanted:
                            symbol_to_name[symbol] = wanted[full_ref]
                        elif ref in wanted:
                            symbol_to_name[symbol] = wanted[ref]
                elif line == "$enddefinitions $end":
                    in_defs = False
                continue

            if line.startswith("#"):
                if cur_time is not None and time_has_updates:
                    samples.append((cur_time, dict(state)))
                    time_has_updates = False
                cur_time = int(line[1:])
                continue

            if line[0] in "01xXzZ" and len(line) >= 2:
                name = symbol_to_name.get(line[1:])
                if name is not None:
                    state[name] = line[0].lower()
                    time_has_updates = True

    if cur_time is not None and time_has_updates:
        samples.append((cur_time, dict(state)))
    return samples


def stream_word(snapshot: dict[str, str], prefix: str, data_name: str = "data") -> int:
    word = 0
    for idx in range(9):
        if snapshot.get(f"{prefix}.{data_name}[{idx}]") == "1":
            word |= 1 << idx
    return word


def bus_word(snapshot: dict[str, str], prefix: str, bus_name: str, width: int) -> int:
    word = 0
    for idx in range(width):
        if snapshot.get(f"{prefix}.{bus_name}[{idx}]") == "1":
            word |= 1 << idx
    return word


def distinct_words(samples: list[tuple[int, dict[str, str]]], prefix: str, valid_name: str = "valid") -> list[int]:
    words: list[int] = []
    seen: set[int] = set()
    for _, snap in samples:
        if snap.get(f"{prefix}.{valid_name}") != "1":
            continue
        word = stream_word(snap, prefix)
        if word not in seen:
            words.append(word)
            seen.add(word)
    return words


def distinct_bus_words(
    samples: list[tuple[int, dict[str, str]]],
    prefix: str,
    bus_name: str,
    width: int,
    valid_name: str | None = None,
) -> list[int]:
    words: list[int] = []
    seen: set[int] = set()
    for _, snap in samples:
        if valid_name is not None and snap.get(f"{prefix}.{valid_name}") != "1":
            continue
        word = bus_word(snap, prefix, bus_name, width)
        if word not in seen:
            words.append(word)
            seen.add(word)
    return words


def words_text(words: list[int], width: int = 3) -> str:
    return ",".join(f"0x{word:0{width}X}" for word in words) if words else "-"


def ever_high(samples: list[tuple[int, dict[str, str]]], name: str) -> bool:
    return any(snap.get(name) == "1" for _, snap in samples)


def first_high(samples: list[tuple[int, dict[str, str]]], name: str) -> int | None:
    for ts, snap in samples:
        if snap.get(name) == "1":
            return ts
    return None


def count_rises(samples: list[tuple[int, dict[str, str]]], name: str) -> int:
    prev = "0"
    rises = 0
    for _, snap in samples:
        cur = snap.get(name, prev)
        if prev != "1" and cur == "1":
            rises += 1
        prev = cur
    return rises


def summarize_stage(samples: list[tuple[int, dict[str, str]]], label: str, valid_name: str = "valid") -> str:
    signal = f"{label}.{valid_name}"
    first = first_high(samples, signal)
    words = distinct_words(samples, label, valid_name)
    ready = f" ready_ever={int(ever_high(samples, f'{label}.ready'))}" if any(f"{label}.ready" in snap for _, snap in samples) else ""
    return (
        f"{label}: first={first if first is not None else '-'} "
        f"rises={count_rises(samples, signal)} words={words_text(words)}{ready}"
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vcd", type=Path)
    args = parser.parse_args()

    samples = parse_vcd(args.vcd.resolve(), wanted_mapping())
    if not samples:
        raise SystemExit(f"no tracked samples found in {args.vcd}")

    print(f"samples={len(samples)} first_time={samples[0][0]} last_time={samples[-1][0]}")
    print(f"dp_reset_ever_high={int(ever_high(samples, 'dp_reset'))}")
    for label in (
        "up_host",
        "dp_host",
        "split_mts0",
        "mts0_adapter",
        "mts0",
        "split_mts1",
        "mts1_adapter",
        "mts1",
        "split_deasm0",
        "deasm0_adapter",
        "deasm0",
        "split_emu",
        "emu_adapter",
        "emu0",
        "mux0_asi_emu",
        "mux0_aso",
        "adapter034_in",
        "adapter034_out",
        "fifo0_in",
        "fifo0_out",
        "adapter009_in",
        "adapter009_out",
    ):
        valid_name = "ctrl_valid" if label in {"mts0", "mts1", "deasm0", "emu0"} else "valid"
        print(summarize_stage(samples, label, valid_name))

    for label in ("mts0", "mts1", "deasm0"):
        flags = {
            "prepare": ever_high(samples, f"{label}.run_state_run_prepare"),
            "sync": ever_high(samples, f"{label}.run_state_sync"),
            "running": ever_high(samples, f"{label}.run_state_running"),
            "terminating": ever_high(samples, f"{label}.run_state_terminating"),
        }
        print(f"{label}.run_state_flags={flags}")

    print(f"mts0.processor_running={int(ever_high(samples, 'mts0.processor_running'))}")
    print(f"mts1.processor_running={int(ever_high(samples, 'mts1.processor_running'))}")
    print(f"mts0.hit_type1_valid={int(ever_high(samples, 'mts0.hit_type1_valid'))}")
    print(f"mts1.hit_type1_valid={int(ever_high(samples, 'mts1.hit_type1_valid'))}")
    print(f"deasm0.receiver_go={int(ever_high(samples, 'deasm0.receiver_go'))}")
    print(f"deasm0.enable={int(ever_high(samples, 'deasm0.enable'))}")
    print(f"deasm0.i_byteisk={int(ever_high(samples, 'deasm0.i_byteisk'))}")
    print(f"deasm0.n_frame_info_ready={int(ever_high(samples, 'deasm0.n_frame_info_ready'))}")
    print(f"deasm0.rx8b1k_valid={int(ever_high(samples, 'deasm0.rx8b1k_valid'))}")
    print(
        "deasm0.rx8b1k_words="
        f"{words_text(distinct_bus_words(samples, 'deasm0', 'rx8b1k_data', 9, 'rx8b1k_valid'))}"
    )
    print(
        "deasm0.i_data_words="
        f"{words_text(distinct_bus_words(samples, 'deasm0', 'i_data', 8, 'rx8b1k_valid'), width=2)}"
    )
    print(
        "deasm0.p_frame_flags="
        f"{words_text(distinct_bus_words(samples, 'deasm0', 'p_frame_flags', 6), width=2)}"
    )
    print(
        "deasm0.p_frame_len="
        f"{words_text(distinct_bus_words(samples, 'deasm0', 'p_frame_len', 10))}"
    )
    deasm_states = {
        "idle": ever_high(samples, "deasm0.state_fs_idle"),
        "frame_counter": ever_high(samples, "deasm0.state_fs_frame_counter"),
        "event_counter": ever_high(samples, "deasm0.state_fs_event_counter"),
        "unpack": ever_high(samples, "deasm0.state_fs_unpack"),
        "unpack_extra": ever_high(samples, "deasm0.state_fs_unpack_extra"),
        "crc_calc": ever_high(samples, "deasm0.state_fs_crc_calc"),
        "crc_check": ever_high(samples, "deasm0.state_fs_crc_check"),
        "error": ever_high(samples, "deasm0.state_fs_error"),
    }
    print(f"deasm0.parser_states={deasm_states}")
    print(f"deasm0.hit_type0_valid={int(ever_high(samples, 'deasm0.hit_type0_valid'))}")
    print(f"emu0.ctrl_running={int(ever_high(samples, 'emu0.ctrl_running'))}")
    print(f"emu0.tx8b1k_valid={int(ever_high(samples, 'emu0.tx8b1k_valid'))}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
