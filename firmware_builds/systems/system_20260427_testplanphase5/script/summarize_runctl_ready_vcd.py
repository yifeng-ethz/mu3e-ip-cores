#!/usr/bin/env python3
"""Summarize the FE SciFi v3 run-control ready fanout capture VCD."""

from __future__ import annotations

import argparse
from pathlib import Path


QSYS = "feb_system:u_feb_system|feb_system_v3_pipe:u_qsys|"
DP_PREFIX = f"{QSYS}feb_system_v3_pipe_data_path_subsystem:data_path_subsystem|"
UP_PREFIX = f"{QSYS}feb_system_v3_pipe_upload_subsystem:upload_subsystem|"

SPLITTER_PREFIX = f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_run_control_splitter:run_control_splitter|"
EMULATOR_SPLITTER_PREFIX = f"{DP_PREFIX}feb_system_v3_pipe_data_path_subsystem_emulator_ctrl_splitter:emulator_ctrl_splitter|"

OUT_INDEX_TO_SINK = {
    0: "histogram_statistics_0.ctrl",
    1: "mts_preprocessor_0.run_ctrl",
    2: "mutrig_datapath_subsystem_0.run_ctrl",
    3: "mutrig_datapath_subsystem_1.run_ctrl",
    4: "mutrig_datapath_subsystem_2.run_ctrl",
    5: "mutrig_datapath_subsystem_3.run_ctrl",
    6: "hit_stack_subsystem_0.run_control_signal",
    7: "mutrig_reset_controller_0.runcontrol",
    8: "mutrig_datapath_subsystem_4.run_ctrl",
    9: "mutrig_datapath_subsystem_5.run_ctrl",
    10: "mutrig_datapath_subsystem_6.run_ctrl",
    11: "mutrig_datapath_subsystem_7.run_ctrl",
    12: "mts_preprocessor_1.run_ctrl",
    13: "mutrig_injector_0.runctl",
    14: "hit_stack_subsystem_1.run_control_signal",
    15: "emulator_ctrl_splitter.in",
}

EMULATOR_OUT_INDEX_TO_SINK = {
    idx: f"emulator_mutrig_{idx}.ctrl" for idx in range(8)
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("vcd", help="Input VCD file")
    return parser.parse_args()


def wanted_names() -> list[str]:
    names = [
        f"{UP_PREFIX}runctl_mgmt_host_valid",
        f"{UP_PREFIX}runctl_mgmt_host_ready",
        "runctl_mgmt_host_valid",
        "runctl_mgmt_host_ready",
    ]
    names.extend(f"{UP_PREFIX}runctl_mgmt_host_data[{idx}]" for idx in range(9))
    names.extend(f"runctl_mgmt_host_data[{idx}]" for idx in range(9))
    names.extend(f"{SPLITTER_PREFIX}out{idx}_ready" for idx in range(16))
    names.extend(f"out{idx}_ready" for idx in range(16))
    names.extend(f"{EMULATOR_SPLITTER_PREFIX}out{idx}_ready" for idx in range(8))
    names.extend(f"emulator_out{idx}_ready" for idx in range(8))
    return names


def canonical_name(name: str) -> str:
    if "|" in name:
        leaf = name.rsplit("|", 1)[-1]
        if "emulator_ctrl_splitter" in name and leaf.startswith("out"):
            return f"emulator_{leaf}"
        return leaf
    return name


def parse_vcd(path: Path) -> tuple[dict[str, str], list[tuple[int, dict[str, str]]]]:
    wanted = set(wanted_names())
    symbol_to_name: dict[str, str] = {}
    state: dict[str, str] = {}
    samples: list[tuple[int, dict[str, str]]] = []
    cur_time: int | None = None
    time_has_updates = False
    in_defs = True

    with path.open("r", encoding="utf-8", errors="replace") as fh:
        for raw_line in fh:
            line = raw_line.strip()
            if not line:
                continue
            if in_defs:
                if line.startswith("$var "):
                    parts = line.split()
                    if len(parts) >= 5:
                        symbol = parts[3]
                        name = parts[4]
                        if name in wanted:
                            symbol_to_name[symbol] = name
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
                value = line[0].lower()
                symbol = line[1:]
                name = symbol_to_name.get(symbol)
                if name is None:
                    continue
                state[canonical_name(name)] = value
                time_has_updates = True

    if cur_time is not None and time_has_updates:
        samples.append((cur_time, dict(state)))

    return symbol_to_name, samples


def build_data_word(snapshot: dict[str, str]) -> int:
    word = 0
    for bit in range(9):
        key = f"runctl_mgmt_host_data[{bit}]"
        if snapshot.get(key) == "1":
            word |= 1 << bit
    return word


def main() -> int:
    args = parse_args()
    vcd_path = Path(args.vcd).resolve()
    _, samples = parse_vcd(vcd_path)
    if not samples:
        raise SystemExit(f"no tracked samples found in {vcd_path}")

    first_assert = None
    for ts, snapshot in samples:
        if snapshot.get("runctl_mgmt_host_valid") == "1":
            first_assert = (ts, snapshot)
            break

    if first_assert is None:
        raise SystemExit("runctl_mgmt_host_valid never asserted in capture")

    ts, snapshot = first_assert
    ready = snapshot.get("runctl_mgmt_host_ready", "?")
    data_word = build_data_word(snapshot)
    blocked = []
    for idx, sink in OUT_INDEX_TO_SINK.items():
        key = f"out{idx}_ready"
        if snapshot.get(key) != "1":
            blocked.append((idx, sink, snapshot.get(key, "?")))

    print(f"time={ts}")
    print(f"host_valid=1 host_ready={ready} host_data=0x{data_word:03X}")
    if blocked:
        print("blocked_sinks:")
        for idx, sink, val in blocked:
            print(f"  out{idx}={val} {sink}")
    else:
        print("blocked_sinks: none")
    if any(idx == 15 for idx, _, _ in blocked):
        nested_blocked = []
        for idx, sink in EMULATOR_OUT_INDEX_TO_SINK.items():
            key = f"emulator_out{idx}_ready"
            if snapshot.get(key) != "1":
                nested_blocked.append((idx, sink, snapshot.get(key, "?")))
        if nested_blocked:
            print("blocked_emulator_sinks:")
            for idx, sink, val in nested_blocked:
                print(f"  emulator_out{idx}={val} {sink}")
        else:
            print("blocked_emulator_sinks: none")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
