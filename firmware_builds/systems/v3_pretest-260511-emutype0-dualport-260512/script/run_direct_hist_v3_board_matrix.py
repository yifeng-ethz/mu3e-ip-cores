#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


SC_HUB_UID_WORD = 0x0FE80
SC_HUB_UID = 0x53434842

RUNCTL_BASE_WORD = 0x0C000
RUNCTL_STATUS_WORD = RUNCTL_BASE_WORD + 0x03
RUNCTL_LAST_CMD_WORD = RUNCTL_BASE_WORD + 0x04
RUNCTL_RECV_TS_L_WORD = RUNCTL_BASE_WORD + 0x09
RUNCTL_RECV_TS_H_WORD = RUNCTL_BASE_WORD + 0x0A
RUNCTL_EXEC_TS_L_WORD = RUNCTL_BASE_WORD + 0x0B
RUNCTL_EXEC_TS_H_WORD = RUNCTL_BASE_WORD + 0x0C
LOCAL_CMD_WORD = 0x0C013

LVDS_LANE_GO_WORD = 0x08004
EMU_BASE_WORD = 0x08800
ARB_BASE_WORD = 0x088A0
ARB_STRIDE_WORD = 0x20
HIST_BIN_BASE_WORD = 0x0A800
HIST_CSR_BASE_WORD = 0x0A900

MTS_BASE_WORDS = [0x09000, 0x0A000]
MTS_CTRL_GO = 1 << 0
MTS_CTRL_DISCARD_HITERR = 1 << 4
MTS_CTRL_DELAY_TS_FIELD_USE_T = 1 << 29

RING_BASE_WORDS = {
    "hs0_rb0": 0x0AC00,
    "hs0_rb1": 0x0AC20,
    "hs0_rb2": 0x0AC40,
    "hs0_rb3": 0x0AC60,
    "hs1_rb0": 0x0AD00,
    "hs1_rb1": 0x0AD20,
    "hs1_rb2": 0x0AD40,
    "hs1_rb3": 0x0AD60,
}
FRAME_ASM_BASE_WORDS = {
    "hs0_frame": 0x0B400,
    "hs1_frame": 0x0B410,
}

LVDS_CLK_HZ = 125_000_000
HIST_NUM_BINS = 256
HIST_KEY_LOC_DIRECT = 0x261D_2311

SOURCE_TYPE0 = 0
SOURCE_TYPE1_UP = 1
SOURCE_TYPE1_DOWN = 2
SOURCE_MAP = {
    "type0": SOURCE_TYPE0,
    "type1_up": SOURCE_TYPE1_UP,
    "type1_down": SOURCE_TYPE1_DOWN,
}

ARB_MODE_EMU = 1
RING_CTRL_GO = 0x00000001
RING_CTRL_FILTER_INERR = 0x00000010

LOCAL_CMD_RUN_PREPARE = 0x10
LOCAL_CMD_SYNC = 0x11
LOCAL_CMD_RUNNING = 0x12
LOCAL_CMD_END_RUN = 0x13


def default_output_dir() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    return Path(__file__).resolve().parents[1] / "board" / "REPORT" / f"direct_hist_v3_board_{stamp}"


def have_swb_ring_lock() -> bool:
    if os.environ.get("SWB_RING_LOCK_HELD") == "1":
        return True
    try:
        return Path(os.readlink("/proc/self/fd/9")) == Path("/tmp/swb_ring.lock")
    except OSError:
        return False


def run_cmd(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
    proc = subprocess.run(cmd, text=True, capture_output=True)
    if check and proc.returncode != 0:
        raise RuntimeError(
            f"command failed rc={proc.returncode}: {' '.join(cmd)}\n"
            f"{proc.stdout}{proc.stderr}"
        )
    return proc


def parse_payload(text: str) -> list[int]:
    return [
        int(match.group(2), 16)
        for match in re.finditer(r"payload\[(\d+)\]\s*=\s*(0x[0-9A-Fa-f]+)", text)
    ]


def sc_read(sc_tool: Path, link: int, addr: int, count: int = 1, timeout_ms: int = 1000) -> list[int]:
    last = ""
    for attempt in range(6):
        proc = run_cmd(
            [
                str(sc_tool),
                str(link),
                "read",
                f"0x{addr:05X}",
                str(count),
                "--quiet",
                "--reply-timeout-ms",
                str(timeout_ms),
            ],
            check=False,
        )
        last = proc.stdout + proc.stderr
        words = parse_payload(last)
        if proc.returncode == 0 and len(words) == count:
            return words
        time.sleep(0.05 * (attempt + 1))
    raise RuntimeError(f"SC read failed at 0x{addr:05X} count={count}\n{last}")


def sc_write(sc_tool: Path, link: int, addr: int, words: list[int], timeout_ms: int = 1000) -> str:
    last = ""
    for attempt in range(6):
        proc = run_cmd(
            [
                str(sc_tool),
                str(link),
                "write",
                f"0x{addr:05X}",
                *[f"0x{word & 0xFFFFFFFF:08X}" for word in words],
                "--quiet",
                "--reply-timeout-ms",
                str(timeout_ms),
            ],
            check=False,
        )
        last = proc.stdout + proc.stderr
        if proc.returncode == 0 and not re.search(r"rsp\s*:\s*(SLVERR|DECERR)", last):
            return last
        time.sleep(0.05 * (attempt + 1))
    raise RuntimeError(f"SC write failed at 0x{addr:05X} words={words}\n{last}")


def sc_write_stable(sc_tool: Path, link: int, addr: int, words: list[int]) -> None:
    sc_write(sc_tool, link, addr, words)
    sc_write(sc_tool, link, addr, words)


def read_u64_pair(words: list[int], low_idx: int, high_idx: int) -> int:
    return (words[low_idx] & 0xFFFFFFFF) | ((words[high_idx] & 0xFFFFFFFF) << 32)


def read_u48(sc_tool: Path, link: int, low_addr: int, high_addr: int) -> int:
    lo = sc_read(sc_tool, link, low_addr)[0]
    hi = sc_read(sc_tool, link, high_addr)[0]
    return (lo & 0xFFFFFFFF) | ((hi & 0xFFFF) << 32)


def local_cmd(sc_tool: Path, link: int, cmd: int, payload24: int, delay_s: float) -> dict[str, Any]:
    word = ((payload24 & 0xFFFFFF) << 8) | (cmd & 0xFF)
    sc_write(sc_tool, link, LOCAL_CMD_WORD, [word])
    status = 0
    for _ in range(50):
        status = sc_read(sc_tool, link, RUNCTL_STATUS_WORD)[0]
        if (status & (1 << 30)) == 0:
            break
        time.sleep(0.02)
    last_cmd = sc_read(sc_tool, link, RUNCTL_LAST_CMD_WORD)[0]
    try:
        recv_ts = read_u48(sc_tool, link, RUNCTL_RECV_TS_L_WORD, RUNCTL_RECV_TS_H_WORD)
        exec_ts = read_u48(sc_tool, link, RUNCTL_EXEC_TS_L_WORD, RUNCTL_EXEC_TS_H_WORD)
    except RuntimeError:
        recv_ts = None
        exec_ts = None
    if delay_s > 0:
        time.sleep(delay_s)
    return {
        "cmd": f"0x{cmd:02X}",
        "word": f"0x{word:08X}",
        "runctl_status": f"0x{status:08X}",
        "runctl_last_cmd": f"0x{last_cmd:08X}",
        "recv_ts": recv_ts,
        "exec_ts": exec_ts,
    }


def ticks_to_s(ticks: int) -> float:
    return ticks * 8.0e-9


def stage_durations(trace: list[dict[str, Any]]) -> dict[str, Any]:
    by_cmd = {int(item["cmd"], 16): item for item in trace if item.get("cmd")}
    start_ts = by_cmd.get(LOCAL_CMD_RUNNING, {}).get("recv_ts")
    end_ts = by_cmd.get(LOCAL_CMD_END_RUN, {}).get("recv_ts")
    return {
        "running_s": ticks_to_s(end_ts - start_ts)
        if start_ts is not None and end_ts is not None and end_ts >= start_ts
        else None,
        "trace": trace,
    }


def rate_cfg_from_hz(rate_hz: int) -> int:
    return max(1, min(0xFFFF, round(rate_hz * 65536 / LVDS_CLK_HZ)))


def cluster_fix_word(low: int, high: int, *, right_side: bool = False) -> int:
    low &= 0x7F
    high &= 0x7F
    if right_side:
        return (1 << 30) | (high << 23) | (low << 16)
    return (1 << 14) | (high << 7) | low


def cluster_random_word(size: int, mirror_mode: int, mirror_offset: int, seed: int) -> int:
    return (
        (size & 0xFF)
        | ((mirror_mode & 0x3) << 8)
        | ((mirror_offset & 0xFF) << 11)
        | ((seed & 0xFF) << 19)
    )


def emulator_geometry(pattern: str) -> dict[str, int | str]:
    if pattern == "onech":
        return {
            "signal": 0x00000006,
            "cluster_fix": cluster_fix_word(0, 0),
            "cluster_random": cluster_random_word(1, 0, 0, 0x53),
            "description": "random geometry, one selected channel per launch",
            "nominal_hits_per_launch": 1,
        }
    if pattern == "allch":
        return {
            "signal": 0x00000006,
            "cluster_fix": cluster_fix_word(0, 127),
            "cluster_random": cluster_random_word(128, 2, 0, 0x00),
            "description": "random geometry, mirrored 128-channel clusters covering 0..255",
            "nominal_hits_per_launch": 256,
        }
    raise ValueError(f"unknown pattern {pattern}")


def configure_emulator(sc_tool: Path, link: int, rate_hz: int, pattern: str) -> dict[str, Any]:
    geom = emulator_geometry(pattern)
    rate_cfg = rate_cfg_from_hz(rate_hz)
    writes = {
        "CENTRAL": (EMU_BASE_WORD + 0x07, 0x00000001),
        "SIGNAL": (EMU_BASE_WORD + 0x08, int(geom["signal"])),
        "BACKGROUND": (EMU_BASE_WORD + 0x09, 0x00000000),
        "MUTRIG_FORMAT": (EMU_BASE_WORD + 0x0A, 0x00000023),
        "RATES": (EMU_BASE_WORD + 0x0B, rate_cfg),
        "CLUSTER_FIX": (EMU_BASE_WORD + 0x0C, int(geom["cluster_fix"])),
        "CLUSTER_RANDOM": (EMU_BASE_WORD + 0x0D, int(geom["cluster_random"])),
        "PRNG_SEED": (EMU_BASE_WORD + 0x0E, 0xDEADBEEF),
        "TIMEBASE_SEED": (EMU_BASE_WORD + 0x0F, 0x00010001),
        "LANE_ENABLE": (EMU_BASE_WORD + 0x12, 0x000000FF),
    }
    for _, (addr, value) in writes.items():
        sc_write_stable(sc_tool, link, addr, [value])
    return {
        "rate_hz_request": rate_hz,
        "rate_cfg": rate_cfg,
        "rate_hz_nominal_launch": rate_cfg * LVDS_CLK_HZ / 65536.0,
        "pattern": pattern,
        "geometry": geom,
        "writes": {
            name: {
                "addr": f"0x{addr:05X}",
                "written": f"0x{value:08X}",
                "readback": f"0x{sc_read(sc_tool, link, addr)[0]:08X}",
            }
            for name, (addr, value) in writes.items()
        },
    }


def configure_arbs_to_emu(sc_tool: Path, link: int) -> list[dict[str, Any]]:
    rows = []
    for lane in range(8):
        base = ARB_BASE_WORD + lane * ARB_STRIDE_WORD
        sc_write_stable(sc_tool, link, base + 0x02, [ARB_MODE_EMU | 0x3C])
        sc_write_stable(sc_tool, link, base + 0x02, [ARB_MODE_EMU])
        status = 0
        for _ in range(50):
            status = sc_read(sc_tool, link, base + 0x03)[0]
            if (status & 0x3) == ARB_MODE_EMU:
                break
            time.sleep(0.02)
        rows.append(
            {
                "lane": lane,
                "base": f"0x{base:05X}",
                "uid": f"0x{sc_read(sc_tool, link, base)[0]:08X}",
                "status": f"0x{status:08X}",
                "mode": status & 0x3,
            }
        )
    return rows


def configure_downstream(sc_tool: Path, link: int) -> dict[str, Any]:
    mts_ctrl = MTS_CTRL_GO | MTS_CTRL_DISCARD_HITERR | MTS_CTRL_DELAY_TS_FIELD_USE_T
    ring_ctrl = RING_CTRL_GO | RING_CTRL_FILTER_INERR
    for base in MTS_BASE_WORDS:
        sc_write_stable(sc_tool, link, base + 0x00, [mts_ctrl])
    for base in RING_BASE_WORDS.values():
        sc_write_stable(sc_tool, link, base + 0x02, [ring_ctrl])
    return {
        "mts_ctrl": f"0x{mts_ctrl:08X}",
        "ring_ctrl": f"0x{ring_ctrl:08X}",
        "mts_readback": [f"0x{sc_read(sc_tool, link, base)[0]:08X}" for base in MTS_BASE_WORDS],
        "ring_readback": {
            name: f"0x{sc_read(sc_tool, link, base + 0x02)[0]:08X}"
            for name, base in RING_BASE_WORDS.items()
        },
    }


def histogram_control_word(source_select: int, mode: str, filter_key: int | None) -> int:
    control = 0x00000001
    control |= (1 if mode == "delay" else 0) << 4
    control |= 1 << 8
    if filter_key is not None:
        control |= 1 << 12
    control |= (source_select & 0x3) << 16
    return control


def configure_histogram(
    sc_tool: Path,
    link: int,
    source: str,
    mode: str,
    interval_clocks: int,
    filter_key: int | None,
) -> dict[str, Any]:
    source_select = SOURCE_MAP[source]
    bin_width = 32 if (mode == "delay" or source != "type0") else 256
    left = 0
    key_value = ((filter_key or 0) & 0xFFFF) << 16
    control = histogram_control_word(source_select, mode, filter_key)

    # A zero write to the bin aperture clears measurement state. Bin readout
    # below is intentionally single-word only.
    sc_write_stable(sc_tool, link, HIST_BIN_BASE_WORD, [0])
    writes = {
        "KEY_LOC": (HIST_CSR_BASE_WORD + 0x06, HIST_KEY_LOC_DIRECT),
        "KEY_VALUE": (HIST_CSR_BASE_WORD + 0x07, key_value),
        "LEFT_BOUND": (HIST_CSR_BASE_WORD + 0x03, left),
        "BIN_WIDTH": (HIST_CSR_BASE_WORD + 0x05, bin_width),
        "INTERVAL_CFG": (HIST_CSR_BASE_WORD + 0x0A, interval_clocks & 0xFFFFFFFF),
        "CONTROL_APPLY": (HIST_CSR_BASE_WORD + 0x02, control),
    }
    for _, (addr, value) in writes.items():
        sc_write_stable(sc_tool, link, addr, [value])
    for _ in range(50):
        control_rb = sc_read(sc_tool, link, HIST_CSR_BASE_WORD + 0x02)[0]
        if (control_rb & 0x2) == 0:
            break
        time.sleep(0.02)
    return {
        "source": source,
        "source_select": source_select,
        "mode": mode,
        "filter_key": filter_key,
        "writes": {
            name: {
                "addr": f"0x{addr:05X}",
                "written": f"0x{value & 0xFFFFFFFF:08X}",
                "readback": f"0x{sc_read(sc_tool, link, addr)[0]:08X}",
            }
            for name, (addr, value) in writes.items()
        },
        "csr": read_hist_csr(sc_tool, link),
    }


def read_hist_csr(sc_tool: Path, link: int) -> dict[str, int]:
    words = sc_read(sc_tool, link, HIST_CSR_BASE_WORD, 19)
    return {
        "UID": words[0],
        "META": words[1],
        "CONTROL": words[2],
        "LEFT_BOUND": words[3],
        "RIGHT_BOUND": words[4],
        "BIN_WIDTH": words[5],
        "KEY_LOC": words[6],
        "KEY_VALUE": words[7],
        "UNDERFLOW_COUNT": words[8],
        "OVERFLOW_COUNT": words[9],
        "INTERVAL_CFG": words[10],
        "BANK_STATUS": words[11],
        "PORT_STATUS": words[12],
        "TOTAL_HITS": words[13],
        "DROPPED_HITS": words[14],
        "COAL_STATUS": words[15],
        "SCRATCH": words[16],
        "LAST_INTERVAL_TOTAL_HITS": words[17],
        "LAST_INTERVAL_DROPPED_HITS": words[18],
    }


def read_hist_bins_single(sc_tool: Path, link: int) -> list[int]:
    return [sc_read(sc_tool, link, HIST_BIN_BASE_WORD + idx)[0] for idx in range(HIST_NUM_BINS)]


def read_arb_snapshot(sc_tool: Path, link: int) -> list[dict[str, Any]]:
    rows = []
    for lane in range(8):
        base = ARB_BASE_WORD + lane * ARB_STRIDE_WORD
        words = sc_read(sc_tool, link, base, 30)
        rows.append(
            {
                "lane": lane,
                "uid": f"0x{words[0]:08X}",
                "status": f"0x{words[3]:08X}",
                "ingress_emu_hits": read_u64_pair(words, 0x0C, 0x0D),
                "drops_emu": read_u64_pair(words, 0x10, 0x11),
                "egress_emu_hits": read_u64_pair(words, 0x14, 0x15),
            }
        )
    return rows


def read_pipeline_snapshot(sc_tool: Path, link: int) -> dict[str, Any]:
    mts = []
    for idx, base in enumerate(MTS_BASE_WORDS):
        words = sc_read(sc_tool, link, base, 5)
        mts.append(
            {
                "idx": idx,
                "status_control": f"0x{words[0]:08X}",
                "discard_hits": words[1],
                "expected_latency": words[2],
                "total_hits": ((words[3] & 0xFFFF) << 32) | words[4],
            }
        )
    ring = {}
    for name, base in RING_BASE_WORDS.items():
        words = sc_read(sc_tool, link, base, 10)
        ring[name] = {
            "uid": f"0x{words[0]:08X}",
            "ctrl": f"0x{words[2]:08X}",
            "fill_level": words[4],
            "inerr_count": words[5],
            "push_count": words[6],
            "pop_count": words[7],
            "overwrite_count": words[8],
            "cache_miss_count": words[9],
        }
    frame = {}
    for name, base in FRAME_ASM_BASE_WORDS.items():
        words = sc_read(sc_tool, link, base, 8)
        frame[name] = {
            "feb_type": words[0],
            "feb_id": words[1],
            "declared_hits": ((words[2] & 0x3FFFF) << 32) | words[3],
            "actual_hits": ((words[4] & 0x3FFFF) << 32) | words[5],
            "missing_hits": ((words[6] & 0x3FFFF) << 32) | words[7],
        }
    return {"mts": mts, "ring": ring, "frame_assembly": frame}


def summarize_bins(bins: list[int]) -> dict[str, Any]:
    nonzero = [{"bin": idx, "count": value} for idx, value in enumerate(bins) if value != 0]
    return {
        "bin_sum": sum(bins),
        "nonzero_count": len(nonzero),
        "nonzero_min_bin": nonzero[0]["bin"] if nonzero else None,
        "nonzero_max_bin": nonzero[-1]["bin"] if nonzero else None,
        "nonzero_bins_first64": nonzero[:64],
    }


def case_list(selection: str) -> list[tuple[str, str, int, str]]:
    if selection == "smoke":
        return [
            ("type0", "rate", 100_000, "onech"),
            ("type1_up", "rate", 100_000, "onech"),
            ("type1_up", "delay", 100_000, "onech"),
        ]
    if selection == "matrix":
        rows: list[tuple[str, str, int, str]] = []
        for rate in (100_000, 500_000, 1_000_000):
            for pattern in ("onech", "allch"):
                rows.append(("type0", "rate", rate, pattern))
        for rate in (100_000, 500_000, 1_000_000):
            for pattern in ("onech", "allch"):
                for source in ("type1_up", "type1_down"):
                    rows.append((source, "rate", rate, pattern))
                    rows.append((source, "delay", rate, pattern))
        return rows
    raise ValueError(f"unknown case selection {selection}")


def run_case(
    sc_tool: Path,
    link: int,
    source: str,
    mode: str,
    rate_hz: int,
    pattern: str,
    run_seconds: float,
    interval_clocks: int,
    filter_key: int | None,
) -> dict[str, Any]:
    case_name = f"{source}_{mode}_{rate_hz // 1000}k_{pattern}"
    print(f"CASE_START {case_name}", flush=True)
    report: dict[str, Any] = {
        "case": case_name,
        "source": source,
        "mode": mode,
        "rate_hz": rate_hz,
        "pattern": pattern,
        "run_seconds_request": run_seconds,
        "interval_clocks": interval_clocks,
        "filter_key": filter_key,
    }

    sc_write_stable(sc_tool, link, LVDS_LANE_GO_WORD, [0x000001FF])
    report["arb_config"] = configure_arbs_to_emu(sc_tool, link)
    report["emulator_config"] = configure_emulator(sc_tool, link, rate_hz, pattern)
    report["downstream_config_before_prepare"] = configure_downstream(sc_tool, link)

    trace: list[dict[str, Any]] = []
    run_number = int(time.time()) & 0xFFFFFF
    trace.append(local_cmd(sc_tool, link, LOCAL_CMD_RUN_PREPARE, run_number, 0.05))

    report["histogram_config"] = configure_histogram(
        sc_tool, link, source, mode, interval_clocks, filter_key
    )

    trace.append(local_cmd(sc_tool, link, LOCAL_CMD_SYNC, 0, 0.05))
    report["downstream_config_after_sync"] = configure_downstream(sc_tool, link)
    report["before_running"] = {
        "hist_csr": read_hist_csr(sc_tool, link),
        "arb": read_arb_snapshot(sc_tool, link),
        "pipeline": read_pipeline_snapshot(sc_tool, link),
    }

    trace.append(local_cmd(sc_tool, link, LOCAL_CMD_RUNNING, 0, 0.0))
    samples = []
    deadline = time.time() + run_seconds
    sample_period_s = max(0.25, min(1.0, interval_clocks / LVDS_CLK_HZ))
    try:
        while time.time() < deadline:
            time.sleep(sample_period_s)
            samples.append({"t_host": time.time(), "hist_csr": read_hist_csr(sc_tool, link)})
        report["after_running"] = {
            "hist_csr": read_hist_csr(sc_tool, link),
            "hist_bins": read_hist_bins_single(sc_tool, link),
            "arb": read_arb_snapshot(sc_tool, link),
            "pipeline": read_pipeline_snapshot(sc_tool, link),
        }
    finally:
        trace.append(local_cmd(sc_tool, link, LOCAL_CMD_END_RUN, 0, 0.05))

    report["histogram_samples"] = samples
    report["timing"] = stage_durations(trace)
    report["after_end_run"] = {
        "hist_csr": read_hist_csr(sc_tool, link),
        "hist_bins": read_hist_bins_single(sc_tool, link),
        "arb": read_arb_snapshot(sc_tool, link),
        "pipeline": read_pipeline_snapshot(sc_tool, link),
    }
    bins = report["after_running"]["hist_bins"]
    hist = report["after_running"]["hist_csr"]
    report["bin_summary"] = summarize_bins(bins)
    report["verdict"] = {
        "has_hit": hist["LAST_INTERVAL_TOTAL_HITS"] > 0 or hist["TOTAL_HITS"] > 0 or sum(bins) > 0,
        "no_hist_drop": hist["DROPPED_HITS"] == 0 and hist["LAST_INTERVAL_DROPPED_HITS"] == 0,
        "no_hist_overflow": hist["OVERFLOW_COUNT"] == 0,
        "bank_samples": [sample["hist_csr"]["BANK_STATUS"] for sample in samples],
    }
    print(
        "CASE_DONE "
        f"{case_name} last_total={hist['LAST_INTERVAL_TOTAL_HITS']} "
        f"total={hist['TOTAL_HITS']} drops={hist['DROPPED_HITS']} "
        f"bin_sum={sum(bins)} overflow={hist['OVERFLOW_COUNT']}",
        flush=True,
    )
    return report


def write_reports(out_dir: Path, report: dict[str, Any]) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    json_path = out_dir / "direct_hist_v3_board_matrix.json"
    json_path.write_text(json.dumps(report, indent=2) + "\n", encoding="ascii")

    csv_path = out_dir / "direct_hist_v3_board_summary.csv"
    with csv_path.open("w", newline="", encoding="ascii") as fh:
        writer = csv.writer(fh)
        writer.writerow(
            [
                "case",
                "source",
                "mode",
                "rate_hz",
                "pattern",
                "running_s",
                "last_total",
                "last_dropped",
                "total_hits",
                "dropped_hits",
                "overflow",
                "bin_sum",
                "nonzero_min_bin",
                "nonzero_max_bin",
                "has_hit",
                "no_hist_drop",
                "no_hist_overflow",
            ]
        )
        for case in report["cases"]:
            hist = case["after_running"]["hist_csr"]
            bins = case["bin_summary"]
            verdict = case["verdict"]
            writer.writerow(
                [
                    case["case"],
                    case["source"],
                    case["mode"],
                    case["rate_hz"],
                    case["pattern"],
                    case["timing"]["running_s"],
                    hist["LAST_INTERVAL_TOTAL_HITS"],
                    hist["LAST_INTERVAL_DROPPED_HITS"],
                    hist["TOTAL_HITS"],
                    hist["DROPPED_HITS"],
                    hist["OVERFLOW_COUNT"],
                    bins["bin_sum"],
                    bins["nonzero_min_bin"],
                    bins["nonzero_max_bin"],
                    verdict["has_hit"],
                    verdict["no_hist_drop"],
                    verdict["no_hist_overflow"],
                ]
            )

    lines = [
        "# Direct Hist V3 Board Matrix",
        "",
        f"- Created: `{report['created']}`",
        f"- sc_tool: `{report['sc_tool']}`",
        f"- FEB link: `{report['link']}`",
        f"- RUNNING request: `{report['run_seconds']} s`",
        f"- Histogram interval: `{report['interval_clocks']} clocks`",
        "- Histogram bin readout: `single-word transactions only`",
        "",
        "| case | last_total | dropped | overflow | bin_sum | nonzero bins | verdict |",
        "|---|---:|---:|---:|---:|---:|---|",
    ]
    for case in report["cases"]:
        hist = case["after_running"]["hist_csr"]
        bins = case["bin_summary"]
        verdict = case["verdict"]
        verdict_text = (
            "PASS"
            if verdict["has_hit"] and verdict["no_hist_drop"] and verdict["no_hist_overflow"]
            else "FAIL"
        )
        lines.append(
            f"| `{case['case']}` | {hist['LAST_INTERVAL_TOTAL_HITS']} | "
            f"{hist['DROPPED_HITS']} | {hist['OVERFLOW_COUNT']} | {bins['bin_sum']} | "
            f"{bins['nonzero_count']} | `{verdict_text}` |"
        )
    lines += [
        "",
        "## Files",
        "",
        "- `direct_hist_v3_board_matrix.json`",
        "- `direct_hist_v3_board_summary.csv`",
    ]
    (out_dir / "DIRECT_HIST_V3_BOARD_MATRIX.md").write_text("\n".join(lines) + "\n", encoding="ascii")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sc-tool", type=Path, default=Path("tools/run_script/build/sc_tool"))
    ap.add_argument("--link", type=int, default=2)
    ap.add_argument("--case", choices=["smoke", "matrix"], default="smoke")
    ap.add_argument("--source", choices=sorted(SOURCE_MAP), default=None)
    ap.add_argument("--mode", choices=["rate", "delay"], default=None)
    ap.add_argument("--rate-hz", type=lambda s: int(s, 0), default=None)
    ap.add_argument("--pattern", choices=["onech", "allch"], default=None)
    ap.add_argument("--run-seconds", type=float, default=10.0)
    ap.add_argument("--interval-clocks", type=lambda s: int(s, 0), default=LVDS_CLK_HZ)
    ap.add_argument("--filter-key", type=lambda s: int(s, 0), default=None)
    ap.add_argument("--output-dir", type=Path, default=default_output_dir())
    args = ap.parse_args()

    if not have_swb_ring_lock():
        raise SystemExit("run under /home/yifeng/.local/bin/swb_ring_lock")

    uid = sc_read(args.sc_tool, args.link, SC_HUB_UID_WORD)[0]
    if uid != SC_HUB_UID:
        raise RuntimeError(f"SC hub UID mismatch: got 0x{uid:08X}, expected 0x{SC_HUB_UID:08X}")

    if any(value is not None for value in (args.source, args.mode, args.rate_hz, args.pattern)):
        if not all(value is not None for value in (args.source, args.mode, args.rate_hz, args.pattern)):
            raise SystemExit("--source, --mode, --rate-hz, and --pattern must be supplied together")
        cases = [(args.source, args.mode, args.rate_hz, args.pattern)]
    else:
        cases = case_list(args.case)

    report: dict[str, Any] = {
        "created": dt.datetime.now().isoformat(timespec="seconds"),
        "link": args.link,
        "sc_tool": str(args.sc_tool),
        "case_select": args.case,
        "run_seconds": args.run_seconds,
        "interval_clocks": args.interval_clocks,
        "cases": [],
    }

    for source, mode, rate_hz, pattern in cases:
        report["cases"].append(
            run_case(
                args.sc_tool,
                args.link,
                source,
                mode,
                rate_hz,
                pattern,
                args.run_seconds,
                args.interval_clocks,
                args.filter_key,
            )
        )
        write_reports(args.output_dir, report)

    write_reports(args.output_dir, report)
    print(args.output_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
