#!/usr/bin/env python3
"""Live FEB/SWB histogram sideband capture using the SC word map.

The loaded FEB image exposes a custom slow-control word map that is different
from the Platform Designer/JTAG byte map. This script intentionally uses only
the SC map for live run setup, CSR counters, rbCAM counters, and histogram-bin
readback.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import json
import os
import random
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
REPO_ROOT = SYSTEM_DIR.parents[2]

SC_HIST_BIN = 0x0A800
SC_HIST_CSR = 0x0A900
SC_RBCAM_STACK0 = 0x0AC00
SC_RBCAM_STACK1 = 0x0AD00
SC_RBCAM_STRIDE = 0x20
SC_INJECTOR = 0x0AC80
SC_EMU_BASE = 0x08800
SC_EMU_STRIDE = 0x40
SC_DBG_RUNCTRL = 0x08A00
SC_TYPE0_ARB_BASE = 0x08C00
SC_TYPE0_ARB_STRIDE = 0x20
SC_UPLOAD_RUNCTL = 0x0C000
SC_MTS_BASES = (0x09000, 0x0A000)
SC_LVDS_BASE = 0x08000
SC_BACKPRESSURE_BASE = 0x08218
SC_DATAPATH_LANE_STRIDE = 0x400
SC_FRAME_DEASM_BASE = 0x08AA0
SC_FRAME_DEASM_STRIDE = 0x4

HIST_UID = 0x48495354
RBCAM_UID = 0x5242434D
EMU_UID = 0x454D5554
TYPE0_ARB_UID = 0x41485430
DBG_RUNCTRL_UID = 0x4D325243

HIST_KEY_LOC_TYPE1_DELAY = 0x26231D11  # filter=38:35, update=29:17
HIST_KEY_LOC_TYPE1_RATE = 0x2623261E   # filter=38:35, update=38:30 (ASIC:channel)
HIST_CONTROL_APPLY = 0x00000001
HIST_CONTROL_KEY_UNSIGNED = 0x00000100
HIST_IN_PORT = {
    "upper": 1,
    "lower": 2,
}
HIST_SOURCE_LANE_MASK = {
    # Generated feb_system_v3 wiring:
    # lanes 0..3 -> mts_preprocessor_0 BANK=UP -> hit_type1_extended_0
    # lanes 4..7 -> mts_preprocessor_1 BANK=DW -> hit_type1_extended_1
    "upper": 0x0F,
    "lower": 0xF0,
}
HIST_CLOCK_HZ = 125_000_000
DEFAULT_HIST_INTERVAL_CLOCKS = HIST_CLOCK_HZ // 1000
EMU_RATE_BASE = 65_536
EMU_CHANNELS_PER_LANE = 32
OPQ_INGRESS_CEILING_HPS = 250_000_000.0

EMU_REG_CENTRAL = 0x07
EMU_REG_SIGNAL = 0x08
EMU_REG_BACKGROUND = 0x09
EMU_REG_FORMAT = 0x0A
EMU_REG_RATES = 0x0B
EMU_REG_CLUSTER_FIX = 0x0C
EMU_REG_PRNG_SEED = 0x0E
EMU_REG_TIMEBASE_SEED = 0x0F
EMU_REG_LANE_ENABLE = 0x12
EMU_REG_BANK_STATUS = 0x14
EMU_REG_LANE_STATUS_BASE = 0x18
EMU_FORMAT_TYPE0_SHORT_IDLE = 0x00000033
EMU_CLUSTER_FIX_ALL_CHANNELS = 0x00004F80

TYPE0_ARB_MODE = {
    "real": 0,
    "emu": 1,
    "mix": 2,
}
TYPE0_ARB_REG_META = 0x01
TYPE0_ARB_REG_CONTROL = 0x02
TYPE0_ARB_REG_STATUS = 0x03
TYPE0_ARB_REG_WATCHDOG = 0x04
TYPE0_ARB_REG_INGRESS_REAL = 0x0A
TYPE0_ARB_REG_INGRESS_EMU = 0x0C
TYPE0_ARB_REG_DROPS_REAL = 0x0E
TYPE0_ARB_REG_DROPS_EMU = 0x10
TYPE0_ARB_REG_EGRESS_REAL = 0x12
TYPE0_ARB_REG_EGRESS_EMU = 0x14
TYPE0_ARB_REG_INGRESS_REAL_FRAMES = 0x16
TYPE0_ARB_REG_INGRESS_EMU_FRAMES = 0x18
TYPE0_ARB_REG_EGRESS_REAL_FRAMES = 0x1A
TYPE0_ARB_REG_EGRESS_EMU_FRAMES = 0x1C
TYPE0_ARB_CONTROL_CLEAR_ALL = (1 << 2) | (1 << 3) | (1 << 4) | (1 << 5)

DBG_RC_STATUS = 0x01
DBG_RC_CONTROL = 0x02
DBG_RC_SCRIPT = 0x05
DBG_RC_GAP_CYCLES = 0x06
DBG_RC_SENT_COUNT = 0x07
DBG_RC_LAST_SENT = 0x08
DBG_RC_SCRIPT_SELF_RUN = 0x01
DBG_RC_SCRIPT_END_RUN = 0x02
RUNCTL_UID = 0x52434D48
RUNCTL_REG_STATUS = 0x03
RUNCTL_REG_LAST_CMD = 0x04
RUNCTL_REG_RUN_NUMBER = 0x06
RUNCTL_REG_RECV_TS_L = 0x09
RUNCTL_REG_RECV_TS_H = 0x0A
RUNCTL_REG_EXEC_TS_L = 0x0B
RUNCTL_REG_EXEC_TS_H = 0x0C
RUNCTL_REG_GTS_L = 0x0D
RUNCTL_REG_GTS_H = 0x0E
RUNCTL_REG_RX_CMD_COUNT = 0x0F
RUNCTL_REG_RX_ERR_COUNT = 0x10
RUNCTL_REG_LOG_STATUS = 0x11
RUNCTL_REG_LOCAL_CMD = 0x13
RUNCTL_REG_ACK_SYMBOLS = 0x14
RC_CMD_RUN_PREPARE = 0x10
RC_CMD_RUN_SYNC = 0x11
RC_CMD_START_RUN = 0x12
RC_CMD_END_RUN = 0x13
RC_CMD_ABORT_RUN = 0x14
RC_CMD_STOP_RESET = 0x31
RC_CMD_ENABLE = 0x32

MTS_CTRL_DEFAULT = (1 << 0) | (1 << 4) | (1 << 29)
RBCAM_CTRL_DEFAULT = 0x00000011
FRAME_DEASM_CTRL_ENABLE = 0x00000001


def default_output_dir() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    return SYSTEM_DIR / "reports" / f"hw_hist_sideband_live_{stamp}"


def default_sc_tool() -> Path:
    local = REPO_ROOT / "tools" / "run_script" / "build" / "sc_tool"
    return local if local.is_file() else Path("/home/yifeng/packages/online_dpv2/online/install/bin/sc_tool")


def default_rc_tool() -> Path:
    local = REPO_ROOT / "tools" / "run_script" / "build" / "rc_tool"
    if local.is_file():
        return local
    installed = Path("/home/yifeng/packages/online_dpv2/online/install/bin/rc_tool")
    if installed.is_file():
        return installed
    return SYSTEM_DIR.parents[0] / "system_20260427_testplanphase5" / "bin" / "rc_tool"


def run_checked(cmd: list[str], *, timeout: float | None = None) -> str:
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if proc.returncode != 0:
        raise RuntimeError(
            f"command failed rc={proc.returncode}: {' '.join(cmd)}\n"
            f"{proc.stdout}{proc.stderr}"
        )
    return proc.stdout + proc.stderr


def parse_int_arg(text: str) -> int:
    return int(text, 0)


def normalize_hist_mode(mode: str) -> str:
    aliases = {
        "mode0": "rate",
        "rate": "rate",
        "delay": "latency",
        "latency": "latency",
    }
    key = mode.strip().lower()
    if key not in aliases:
        raise RuntimeError(f"unsupported mode '{mode}'")
    return aliases[key]


def q16_from_rate_hz(rate_hz: float) -> int:
    q16 = int(round(rate_hz * EMU_RATE_BASE / HIST_CLOCK_HZ))
    if not 0 <= q16 <= 0xFFFF:
        raise RuntimeError(f"requested rate {rate_hz} Hz maps to out-of-range rate_88fp {q16}")
    return q16


def active_lane_count(lane_mask: int) -> int:
    return (lane_mask & 0xFF).bit_count()


def encode_cluster_fix_single_channel(channel: int) -> int:
    if not 0 <= channel < EMU_CHANNELS_PER_LANE:
        raise RuntimeError(f"debug channel must be 0..{EMU_CHANNELS_PER_LANE - 1}, got {channel}")
    return (1 << 14) | ((channel & 0x7F) << 7) | (channel & 0x7F)


def selected_channel_map(args: argparse.Namespace) -> dict[int, int]:
    return {int(k): int(v) for k, v in getattr(args, "selected_channels", {}).items()}


def rate_model(args: argparse.Namespace) -> dict[str, Any]:
    lanes = active_lane_count(args.lane_mask)
    one_channel = bool(getattr(args, "one_channel_per_asic", False))
    channels_per_lane = 1 if one_channel else EMU_CHANNELS_PER_LANE
    active_channels = lanes * channels_per_lane
    per_channel_hps = args.q16_rate * HIST_CLOCK_HZ / EMU_RATE_BASE
    aggregate_hps = per_channel_hps * active_channels
    interval_s = args.hist_interval_clocks / HIST_CLOCK_HZ
    model = {
        "lane_mask": f"0x{args.lane_mask & 0xFF:02X}",
        "active_lanes": lanes,
        "channels_per_lane": channels_per_lane,
        "active_channels": active_channels,
        "rate_88fp": args.q16_rate,
        "rate_88fp_hex": f"0x{args.q16_rate & 0xFFFF:04X}",
        "per_channel_hps": per_channel_hps,
        "aggregate_hps": aggregate_hps,
        "opq_clipped_hps": min(aggregate_hps, OPQ_INGRESS_CEILING_HPS),
        "hist_interval_clocks": args.hist_interval_clocks,
        "hist_interval_ms": interval_s * 1000.0,
        "expected_hist_interval_hits": aggregate_hps * interval_s,
    }
    if one_channel:
        model["one_channel_per_asic"] = True
        model["selected_channels"] = {str(k): v for k, v in selected_channel_map(args).items()}
    return model


def source_rate_model(args: argparse.Namespace, source: str) -> dict[str, Any]:
    if source not in HIST_SOURCE_LANE_MASK:
        raise RuntimeError(f"unsupported source '{source}'")
    source_mask = args.lane_mask & HIST_SOURCE_LANE_MASK[source]
    model = rate_model(argparse.Namespace(
        q16_rate=args.q16_rate,
        lane_mask=source_mask,
        hist_interval_clocks=args.hist_interval_clocks,
        one_channel_per_asic=getattr(args, "one_channel_per_asic", False),
        selected_channels={
            lane: channel
            for lane, channel in selected_channel_map(args).items()
            if (source_mask >> lane) & 0x1
        },
    ))
    model.update({
        "source": source,
        "source_lane_mask": f"0x{HIST_SOURCE_LANE_MASK[source] & 0xFF:02X}",
        "global_lane_mask": f"0x{args.lane_mask & 0xFF:02X}",
    })
    return model


def compare_expected_count(name: str, observed: int, expected: float, args: argparse.Namespace) -> dict[str, Any]:
    tolerance = max(float(args.expected_tolerance_count), abs(expected) * args.expected_tolerance_pct / 100.0)
    delta = float(observed) - expected
    delta_pct = (delta / expected * 100.0) if expected else (0.0 if observed == 0 else float("inf"))
    return {
        "name": name,
        "observed": observed,
        "expected": expected,
        "expected_rounded": int(round(expected)),
        "delta": delta,
        "delta_pct": delta_pct,
        "tolerance": tolerance,
        "tolerance_pct": args.expected_tolerance_pct,
        "tolerance_count_floor": args.expected_tolerance_count,
        "status": "PASS" if abs(delta) <= tolerance else "FAIL",
    }


def parse_payload(text: str) -> list[int]:
    values = [int(m.group(1), 16) for m in re.finditer(r"payload\[\d+\]\s*=\s*(0x[0-9A-Fa-f]+)", text)]
    if not values:
        raise RuntimeError(f"SC command returned no payload:\n{text}")
    if "rsp                 : OK" not in text and "rsp = OK" not in text:
        raise RuntimeError(f"SC command did not return OK:\n{text}")
    return values


class ScBus:
    def __init__(self, sc_tool: Path, lock_tool: Path | None, link: int, device: str, *, no_reset: bool) -> None:
        self.sc_tool = sc_tool
        self.lock_tool = lock_tool
        self.link = link
        self.device = device
        self.no_reset = no_reset

    def _cmd(self, op: str, addr: int, args: list[str]) -> list[str]:
        base = [
            str(self.sc_tool),
            str(self.link),
            op,
            f"0x{addr:05X}",
            *args,
            "--device",
            self.device,
            "--quiet",
        ]
        if self.no_reset:
            base.append("--no-reset")
        if self.lock_tool and self.lock_tool.is_file():
            return [str(self.lock_tool), *base]
        return base

    def read(self, addr: int, count: int = 1) -> list[int]:
        last_error: Exception | None = None
        for attempt in range(6):
            try:
                return parse_payload(run_checked(self._cmd("read", addr, [str(count)])))
            except Exception as exc:
                last_error = exc
                time.sleep(0.05 * (attempt + 1))
        raise RuntimeError(f"SC read failed after retries at 0x{addr:05X} count={count}: {last_error}") from last_error

    def write(self, addr: int, words: list[int], *, repeat: bool = True) -> None:
        args = [f"0x{word & 0xFFFFFFFF:08X}" for word in words]
        last_error: Exception | None = None
        for attempt in range(6):
            try:
                # Repeating the same SC write avoids the stale-first-write behavior seen
                # on this SWB/FEB slow-control path after address changes.
                run_checked(self._cmd("write", addr, args))
                if repeat:
                    run_checked(self._cmd("write", addr, args))
                return
            except Exception as exc:
                last_error = exc
                time.sleep(0.05 * (attempt + 1))
        raise RuntimeError(f"SC write failed after retries at 0x{addr:05X}: {last_error}") from last_error


def fmt_hex(value: int) -> str:
    return f"0x{value & 0xFFFFFFFF:08X}"


def rc_send(args: argparse.Namespace, name: str, run_number: int | None = None) -> str:
    cmd = [
        str(args.rc_tool),
        "send",
        name,
        "--device",
        args.device,
        "--feb",
        str(args.feb),
        "--settle-us",
        str(args.rc_settle_us),
    ]
    if run_number is not None:
        cmd.extend(["--run", str(run_number)])
    return run_checked(cmd)


def read_dbg_runctrl(bus: ScBus) -> dict[str, Any]:
    status = bus.read(SC_DBG_RUNCTRL + DBG_RC_STATUS, 1)[0]
    return {
        "uid": fmt_hex(bus.read(SC_DBG_RUNCTRL, 1)[0]),
        "status": fmt_hex(status),
        "local_enable": status & 0x1,
        "pending": (status >> 1) & 0x1,
        "script_busy": (status >> 2) & 0x1,
        "sticky_overrun": (status >> 3) & 0x1,
        "sticky_bad_cmd": (status >> 4) & 0x1,
        "last_from_host": (status >> 5) & 0x1,
        "gap_cycles": (status >> 16) & 0xFFFF,
        "sent_count": bus.read(SC_DBG_RUNCTRL + DBG_RC_SENT_COUNT, 1)[0],
        "last_sent": fmt_hex(bus.read(SC_DBG_RUNCTRL + DBG_RC_LAST_SENT, 1)[0]),
    }


def decode_runctl_status(word: int) -> dict[str, Any]:
    return {
        "raw": fmt_hex(word),
        "recv_idle": word & 0x1,
        "host_idle": (word >> 1) & 0x1,
        "dp_hard_reset": (word >> 4) & 0x1,
        "ct_hard_reset": (word >> 5) & 0x1,
        "recv_state": (word >> 8) & 0xFF,
        "host_state": (word >> 16) & 0xFF,
        "local_cmd_busy": (word >> 30) & 0x1,
        "log_empty": (word >> 31) & 0x1,
    }


def read_runctl_mgmt_host(bus: ScBus) -> dict[str, Any]:
    uid = bus.read(SC_UPLOAD_RUNCTL, 1)[0]
    status = bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_STATUS, 1)[0]
    last_cmd = bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_LAST_CMD, 1)[0]
    recv_l = bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_RECV_TS_L, 1)[0]
    recv_h = bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_RECV_TS_H, 1)[0]
    exec_l = bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_EXEC_TS_L, 1)[0]
    exec_h = bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_EXEC_TS_H, 1)[0]
    gts_l = bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_GTS_L, 1)[0]
    gts_h = bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_GTS_H, 1)[0]
    return {
        "base": f"0x{SC_UPLOAD_RUNCTL:05X}",
        "uid": fmt_hex(uid),
        "uid_ok": uid == RUNCTL_UID,
        "control": fmt_hex(bus.read(SC_UPLOAD_RUNCTL + 2, 1)[0]),
        "status": decode_runctl_status(status),
        "last_cmd": fmt_hex(last_cmd),
        "last_cmd_byte": last_cmd & 0xFF,
        "last_cmd_fpga_address": (last_cmd >> 16) & 0xFFFF,
        "scratch": fmt_hex(bus.read(SC_UPLOAD_RUNCTL + 5, 1)[0]),
        "run_number": bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_RUN_NUMBER, 1)[0],
        "reset_mask": fmt_hex(bus.read(SC_UPLOAD_RUNCTL + 7, 1)[0]),
        "fpga_address": fmt_hex(bus.read(SC_UPLOAD_RUNCTL + 8, 1)[0]),
        "recv_ts": ((recv_h & 0xFFFF) << 32) | recv_l,
        "exec_ts": ((exec_h & 0xFFFF) << 32) | exec_l,
        "gts": ((gts_h & 0xFFFF) << 32) | gts_l,
        "rx_cmd_count": bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_RX_CMD_COUNT, 1)[0],
        "rx_err_count": bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_RX_ERR_COUNT, 1)[0],
        "log_status": fmt_hex(bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_LOG_STATUS, 1)[0]),
        "local_cmd_shadow": fmt_hex(bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_LOCAL_CMD, 1)[0]),
        "ack_symbols": fmt_hex(bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_ACK_SYMBOLS, 1)[0]),
    }


def read_runctl_cmd_status(bus: ScBus) -> dict[str, Any]:
    status = bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_STATUS, 1)[0]
    last_cmd = bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_LAST_CMD, 1)[0]
    return {
        "status": decode_runctl_status(status),
        "last_cmd": fmt_hex(last_cmd),
        "last_cmd_byte": last_cmd & 0xFF,
        "rx_cmd_count": bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_RX_CMD_COUNT, 1)[0],
        "rx_err_count": bus.read(SC_UPLOAD_RUNCTL + RUNCTL_REG_RX_ERR_COUNT, 1)[0],
    }


def dbg_runctrl_init(bus: ScBus, gap_cycles: int) -> dict[str, Any]:
    expect_uid(bus, SC_DBG_RUNCTRL, DBG_RUNCTRL_UID, "dbg_mm2runctrl")
    if gap_cycles < 0 or gap_cycles > 0xFFFF:
        raise RuntimeError(f"dbg_mm2runctrl gap must fit in 16 bits, got {gap_cycles}")
    bus.write(SC_DBG_RUNCTRL + DBG_RC_CONTROL, [0x00000007], repeat=False)
    bus.write(SC_DBG_RUNCTRL + DBG_RC_GAP_CYCLES, [(gap_cycles & 0xFFFF) << 16])
    bus.write(SC_DBG_RUNCTRL + DBG_RC_CONTROL, [0x00000001], repeat=False)
    return read_dbg_runctrl(bus)


def dbg_runctrl_script(bus: ScBus, script: int) -> dict[str, Any]:
    before = read_dbg_runctrl(bus)
    bus.write(SC_DBG_RUNCTRL + DBG_RC_SCRIPT, [script], repeat=False)
    last = before
    for _ in range(200):
        time.sleep(0.005)
        last = read_dbg_runctrl(bus)
        if last["pending"] == 0 and last["script_busy"] == 0:
            break
    else:
        raise RuntimeError(f"dbg_mm2runctrl script {script} did not drain: {last}")
    if last["sticky_overrun"] or last["sticky_bad_cmd"]:
        raise RuntimeError(f"dbg_mm2runctrl script {script} set sticky error: before={before}, after={last}")
    return {"before": before, "after": last, "script": script}


def upload_runctrl_init(bus: ScBus) -> dict[str, Any]:
    expect_uid(bus, SC_UPLOAD_RUNCTL, RUNCTL_UID, "runctl_mgmt_host")
    return read_runctl_mgmt_host(bus)


def upload_local_cmd(bus: ScBus, cmd: int, payload24: int = 0) -> dict[str, Any]:
    before = read_runctl_mgmt_host(bus)
    word = ((payload24 & 0xFFFFFF) << 8) | (cmd & 0xFF)
    last: dict[str, Any] = before
    target_byte = cmd & 0xFF
    target_count = before["rx_cmd_count"] + 1
    attempts: list[dict[str, Any]] = []
    max_rx_err_delta = 0

    for attempt in range(4):
        bus.write(SC_UPLOAD_RUNCTL + RUNCTL_REG_LOCAL_CMD, [word], repeat=False)
        for _ in range(200):
            time.sleep(0.005)
            last = read_runctl_cmd_status(bus)
            max_rx_err_delta = max(max_rx_err_delta, last["rx_err_count"] - before["rx_err_count"])
            if last["rx_cmd_count"] >= target_count:
                attempts.append({
                    "attempt": attempt,
                    "observed_rx_cmd_count": last["rx_cmd_count"],
                    "observed_last_cmd": fmt_hex(last["last_cmd_byte"]),
                    "matched": last["last_cmd_byte"] == target_byte,
                    "rx_err_delta": max_rx_err_delta,
                })
                if last["last_cmd_byte"] == target_byte:
                    after = read_runctl_mgmt_host(bus)
                    return {
                        "before": before,
                        "after": after,
                        "cmd": fmt_hex(cmd),
                        "word": fmt_hex(word),
                        "write_attempts": attempts,
                        "rx_err_delta": after["rx_err_count"] - before["rx_err_count"],
                        "rx_err_note": (
                            "rx_err_count is the external synclink receive-error counter; "
                            "local_cmd success is judged by rx_cmd_count and last_cmd"
                        ),
                    }
                # The SC path can commit the previous LOCAL_CMD word after an
                # address change. Re-issue only after that wrong command is
                # visible, so duplicates are not sent on the normal path.
                target_count = last["rx_cmd_count"] + 1
                break
        else:
            attempts.append({
                "attempt": attempt,
                "timeout_after_rx_cmd_count": last["rx_cmd_count"],
                "last_cmd": fmt_hex(last["last_cmd_byte"]),
                "rx_err_delta": max_rx_err_delta,
            })
            target_count = max(target_count, last["rx_cmd_count"] + 1)

    raise RuntimeError(
        f"runctl_mgmt_host local command 0x{cmd:02X} did not complete: "
        f"before={before}, after={last}, attempts={attempts}"
    )


def upload_runctrl_sequence(bus: ScBus, commands: list[tuple[int, int]]) -> dict[str, Any]:
    rows = []
    for cmd, payload24 in commands:
        rows.append(upload_local_cmd(bus, cmd, payload24))
    return {"commands": rows, "final": read_runctl_mgmt_host(bus)}


def upload_runctrl_sequence_with_dwell(
    bus: ScBus,
    commands: list[tuple[int, int]],
    dwell_ms: int,
) -> dict[str, Any]:
    rows = []
    dwell_s = max(0, dwell_ms) / 1000.0
    for cmd, payload24 in commands:
        row = upload_local_cmd(bus, cmd, payload24)
        if dwell_s:
            time.sleep(dwell_s)
        row["post_command_dwell_ms"] = dwell_ms
        rows.append(row)
    return {"commands": rows, "final": read_runctl_mgmt_host(bus), "phase_dwell_ms": dwell_ms}


def prepare_run_control(args: argparse.Namespace, bus: ScBus) -> dict[str, Any]:
    if args.runctrl_source == "sc-dbg":
        return {"source": "sc-dbg", "init": dbg_runctrl_init(bus, args.dbg_runctrl_gap_cycles)}
    if args.runctrl_source == "upload-local":
        return {"source": "upload-local", "init": upload_runctrl_init(bus)}
    if not args.swb_reset_preamble:
        return {
            "source": "swb-reset-link",
            "reset_preamble": "skipped",
            "runctl_mgmt_host": read_runctl_mgmt_host(bus),
        }
    return {
        "source": "swb-reset-link",
        "runctl_mgmt_host_before": read_runctl_mgmt_host(bus),
        "reset": rc_send(args, "reset"),
        "stop_reset": rc_send(args, "stop-reset"),
        "runctl_mgmt_host_after": read_runctl_mgmt_host(bus),
    }


def start_run_control(args: argparse.Namespace, bus: ScBus, run_number: int) -> dict[str, Any]:
    if args.runctrl_source == "sc-dbg":
        return {
            "source": "sc-dbg",
            "start": dbg_runctrl_script(bus, DBG_RC_SCRIPT_SELF_RUN),
            "run_number": run_number,
        }
    if args.runctrl_source == "upload-local":
        return {
            "source": "upload-local",
            "run_number": run_number,
            "start": upload_runctrl_sequence_with_dwell(bus, [
                (RC_CMD_STOP_RESET, 0),
                (RC_CMD_ENABLE, 0),
                (RC_CMD_RUN_PREPARE, run_number),
                (RC_CMD_RUN_SYNC, 0),
                (RC_CMD_START_RUN, 0),
            ], args.runctrl_phase_dwell_ms),
        }
    before = read_runctl_mgmt_host(bus)
    run_prepare = rc_send(args, "run-prepare", run_number)
    after_prepare = read_runctl_mgmt_host(bus)
    sync = rc_send(args, "sync")
    after_sync = read_runctl_mgmt_host(bus)
    start_run = rc_send(args, "start-run")
    after_start = read_runctl_mgmt_host(bus)
    return {
        "source": "swb-reset-link",
        "run_prepare": run_prepare,
        "sync": sync,
        "start_run": start_run,
        "runctl_mgmt_host_before": before,
        "runctl_mgmt_host_after_prepare": after_prepare,
        "runctl_mgmt_host_after_sync": after_sync,
        "runctl_mgmt_host_after_start": after_start,
    }


def stop_run_control(args: argparse.Namespace, bus: ScBus) -> dict[str, Any]:
    if args.runctrl_source == "sc-dbg":
        return {"source": "sc-dbg", "end": dbg_runctrl_script(bus, DBG_RC_SCRIPT_END_RUN)}
    if args.runctrl_source == "upload-local":
        return {"source": "upload-local", "end": upload_local_cmd(bus, RC_CMD_END_RUN)}
    before = read_runctl_mgmt_host(bus)
    end_run = rc_send(args, "end-run")
    after = read_runctl_mgmt_host(bus)
    return {
        "source": "swb-reset-link",
        "end_run": end_run,
        "runctl_mgmt_host_before": before,
        "runctl_mgmt_host_after": after,
    }


def expect_uid(bus: ScBus, addr: int, expected: int, name: str) -> int:
    observed = bus.read(addr, 1)[0]
    if observed != expected:
        raise RuntimeError(f"{name} UID mismatch at SC word 0x{addr:05X}: got {fmt_hex(observed)}, expected {fmt_hex(expected)}")
    return observed


def configure_emulators(
    bus: ScBus,
    q16_rate: int,
    lane_mask: int,
    hist_interval_clocks: int,
    *,
    one_channel_per_asic: bool,
    selected_channels: dict[int, int],
) -> dict[str, Any]:
    rows: list[dict[str, Any]] = []
    for lane in range(8):
        base = SC_EMU_BASE + lane * SC_EMU_STRIDE
        enabled = bool((lane_mask >> lane) & 0x1)
        uid = expect_uid(bus, base, EMU_UID, f"emulator_mutrig_{lane}")
        selected_channel = selected_channels.get(lane)
        cluster_fix = (
            encode_cluster_fix_single_channel(selected_channel)
            if one_channel_per_asic and selected_channel is not None
            else EMU_CLUSTER_FIX_ALL_CHANNELS
        )
        bus.write(base + EMU_REG_CENTRAL, [0x00000000])
        bus.write(base + EMU_REG_BACKGROUND, [0x00000000])
        bus.write(base + EMU_REG_SIGNAL, [0x00000002])
        bus.write(base + EMU_REG_FORMAT, [EMU_FORMAT_TYPE0_SHORT_IDLE])
        bus.write(base + EMU_REG_RATES, [q16_rate & 0xFFFF])
        bus.write(base + EMU_REG_CLUSTER_FIX, [cluster_fix])
        bus.write(base + EMU_REG_PRNG_SEED, [0xDEADBEEF ^ lane ^ ((selected_channel or 0) << 8)])
        bus.write(base + EMU_REG_TIMEBASE_SEED, [0x00010001])
        bus.write(base + EMU_REG_LANE_ENABLE, [((lane & 0xF) << 8) | (0x00000001 if enabled else 0x00000000)])
        if enabled:
            bus.write(base + EMU_REG_CENTRAL, [0x00000001])
        rows.append({
            "lane": lane,
            "base": f"0x{base:05X}",
            "uid": fmt_hex(uid),
            "enabled": enabled,
            "selected_channel": selected_channel,
            "one_channel_per_asic": one_channel_per_asic,
            "central": fmt_hex(bus.read(base + EMU_REG_CENTRAL, 1)[0]),
            "signal": fmt_hex(bus.read(base + EMU_REG_SIGNAL, 1)[0]),
            "format": fmt_hex(bus.read(base + EMU_REG_FORMAT, 1)[0]),
            "rates": fmt_hex(bus.read(base + EMU_REG_RATES, 1)[0]),
            "cluster_fix": fmt_hex(bus.read(base + EMU_REG_CLUSTER_FIX, 1)[0]),
            "lane_enable": fmt_hex(bus.read(base + EMU_REG_LANE_ENABLE, 1)[0]),
        })

    return {
        "emulators": rows,
        "lane_mask": f"0x{lane_mask & 0xFF:02X}",
        "active_lanes": [row["lane"] for row in rows if row["enabled"]],
        "one_channel_per_asic": one_channel_per_asic,
        "selected_channels": {str(k): v for k, v in selected_channels.items()},
        "q16_rate": q16_rate,
        "rate_model": rate_model(argparse.Namespace(
            q16_rate=q16_rate,
            lane_mask=lane_mask,
            hist_interval_clocks=hist_interval_clocks,
            one_channel_per_asic=one_channel_per_asic,
            selected_channels=selected_channels,
        )),
    }


def decode_type0_arb_status(word: int) -> dict[str, Any]:
    return {
        "raw": fmt_hex(word),
        "mode": word & 0x3,
        "mode_pending": (word >> 2) & 0x3,
        "merged_open": (word >> 4) & 0x1,
        "real_source_open": (word >> 5) & 0x1,
        "emu_source_open": (word >> 6) & 0x1,
        "real_full": (word >> 7) & 0x1,
        "real_empty": (word >> 8) & 0x1,
        "emu_full": (word >> 9) & 0x1,
        "emu_empty": (word >> 10) & 0x1,
        "last_grant": (word >> 11) & 0x1,
        "partial_packet_drop_sticky": (word >> 12) & 0x1,
        "mode_reserved_seen": (word >> 13) & 0x1,
        "protocol_violation_sticky": (word >> 14) & 0x1,
        "drop_mid_packet_sticky": (word >> 15) & 0x1,
        "watchdog_synthesized_real": (word >> 16) & 0x1,
        "watchdog_synthesized_emu": (word >> 17) & 0x1,
        "run_state": (word >> 18) & 0x7,
    }


def read_type0_arb_counter64(bus: ScBus, base: int, low_reg: int) -> int:
    low = bus.read(base + low_reg, 1)[0]
    high = bus.read(base + low_reg + 1, 1)[0]
    return (high << 32) | low


def configure_type0_arbs(bus: ScBus, mode_name: str, watchdog_cycles: int) -> dict[str, Any]:
    if mode_name not in TYPE0_ARB_MODE:
        raise RuntimeError(f"unsupported Type-0 arb mode '{mode_name}'")
    mode = TYPE0_ARB_MODE[mode_name]
    rows: list[dict[str, Any]] = []
    for lane in range(8):
        base = SC_TYPE0_ARB_BASE + lane * SC_TYPE0_ARB_STRIDE
        uid = expect_uid(bus, base, TYPE0_ARB_UID, f"arb_hit_type0_{lane}")
        bus.write(base + TYPE0_ARB_REG_WATCHDOG, [watchdog_cycles & 0xFFFF])
        bus.write(base + TYPE0_ARB_REG_CONTROL, [mode | TYPE0_ARB_CONTROL_CLEAR_ALL])
        rows.append({
            "lane": lane,
            "base": f"0x{base:05X}",
            "uid": fmt_hex(uid),
            "mode_requested": mode_name,
            "control": fmt_hex(bus.read(base + TYPE0_ARB_REG_CONTROL, 1)[0]),
            "status": decode_type0_arb_status(bus.read(base + TYPE0_ARB_REG_STATUS, 1)[0]),
            "watchdog_cycles": bus.read(base + TYPE0_ARB_REG_WATCHDOG, 1)[0] & 0xFFFF,
        })
    return {
        "mode_requested": mode_name,
        "watchdog_cycles": watchdog_cycles,
        "arbiters": rows,
    }


def decode_frame_deassembly(raw: list[int]) -> dict[str, Any]:
    debug = raw[3] if len(raw) > 3 else 0
    return {
        "raw": [fmt_hex(v) for v in raw],
        "control_status": fmt_hex(raw[0]),
        "control": raw[0] & 0xFF,
        "parser_state": (raw[0] >> 12) & 0xF,
        "ctrl_ready": (raw[0] >> 16) & 0x1,
        "ctrl_valid_sample": (raw[0] >> 17) & 0x1,
        "parser_enable": (raw[0] >> 18) & 0x1,
        "receiver_go": (raw[0] >> 19) & 0x1,
        "run_state": (raw[0] >> 20) & 0xF,
        "frame_flags": (raw[0] >> 24) & 0xFF,
        "crc_error_count": raw[1],
        "head_tail_delta": raw[2],
        "frame_count_delta": raw[2],
        "frame_count_delta_note": "legacy key; this CSR word is the frame parser head-tail/open-frame delta, not a total frame counter",
        "debug_raw_valid_sat": (debug >> 24) & 0xFF,
        "debug_header_sat": (debug >> 16) & 0xFF,
        "debug_trailer_sat": (debug >> 8) & 0xFF,
        "debug_hit_sat": debug & 0xFF,
    }


def read_frame_deassembly_rows(bus: ScBus) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for lane in range(8):
        base = SC_FRAME_DEASM_BASE + lane * SC_FRAME_DEASM_STRIDE
        raw = [bus.read(base + idx, 1)[0] for idx in range(4)]
        row = decode_frame_deassembly(raw)
        row.update({"lane": lane, "base": f"0x{base:05X}"})
        rows.append(row)
    return rows


def frame_deassembly_is_exported(rows: list[dict[str, Any]]) -> bool:
    return any(any(value != "0x00000000" for value in row["raw"]) for row in rows)


def configure_frame_deassembly(bus: ScBus) -> dict[str, Any]:
    initial = read_frame_deassembly_rows(bus)
    if not frame_deassembly_is_exported(initial):
        return {
            "exported": False,
            "reason": "not present in loaded AUTO_AVMM_PORT_ADDRESS_MAP",
            "probe": initial,
        }

    rows: list[dict[str, Any]] = []
    for lane in range(8):
        base = SC_FRAME_DEASM_BASE + lane * SC_FRAME_DEASM_STRIDE
        bus.write(base, [FRAME_DEASM_CTRL_ENABLE])
        raw = [bus.read(base + idx, 1)[0] for idx in range(4)]
        row = decode_frame_deassembly(raw)
        row.update({"lane": lane, "base": f"0x{base:05X}"})
        rows.append(row)
    return {"exported": True, "rows": rows}


def configure_downstream(bus: ScBus) -> dict[str, Any]:
    mts_rows = []
    for base in SC_MTS_BASES:
        bus.write(base, [MTS_CTRL_DEFAULT])
        mts_rows.append({"base": f"0x{base:05X}", "control": fmt_hex(bus.read(base, 1)[0])})

    frame_deassembly = configure_frame_deassembly(bus)

    rb_rows = []
    for base0 in (SC_RBCAM_STACK0, SC_RBCAM_STACK1):
        for lane in range(4):
            base = base0 + lane * SC_RBCAM_STRIDE
            bus.write(base + 2, [RBCAM_CTRL_DEFAULT])
            rb_rows.append({"base": f"0x{base:05X}", "control": fmt_hex(bus.read(base + 2, 1)[0])})
    return {
        "mts": mts_rows,
        "rbcam": rb_rows,
        "frame_deassembly": frame_deassembly,
    }


def apply_hist_config(
    bus: ScBus,
    *,
    delay_mode: bool,
    in_port: int,
    left: int,
    bin_width: int,
    interval_clocks: int,
) -> dict[str, Any]:
    expect_uid(bus, SC_HIST_CSR, HIST_UID, "histogram_statistics")
    control = (
        HIST_CONTROL_APPLY
        | HIST_CONTROL_KEY_UNSIGNED
        | ((in_port & 0x3) << 2)
        | ((1 if delay_mode else 0) << 4)
    )
    key_loc = HIST_KEY_LOC_TYPE1_DELAY if delay_mode else HIST_KEY_LOC_TYPE1_RATE
    right_unclamped = left + 256 * bin_width
    right = min(right_unclamped, 0xFFFFFFFF)
    bus.write(SC_HIST_CSR + 3, [left & 0xFFFFFFFF])
    bus.write(SC_HIST_CSR + 4, [right & 0xFFFFFFFF])
    bus.write(SC_HIST_CSR + 5, [bin_width & 0xFFFFFFFF])
    bus.write(SC_HIST_CSR + 6, [key_loc])
    bus.write(SC_HIST_CSR + 7, [0])
    bus.write(SC_HIST_CSR + 10, [interval_clocks])
    bus.write(SC_HIST_CSR + 2, [control])
    for _ in range(100):
        if (bus.read(SC_HIST_CSR + 2, 1)[0] & 0x2) == 0:
            break
        time.sleep(0.01)
    else:
        raise RuntimeError("histogram apply_pending did not clear")
    bus.write(SC_HIST_BIN, [0])
    return {
        "mode": "latency" if delay_mode else "rate",
        "in_port": in_port,
        "control": fmt_hex(control),
        "left": left,
        "right": right,
        "right_unclamped": right_unclamped,
        "bin_width": bin_width,
        "key_loc": fmt_hex(key_loc),
        "interval_clocks": interval_clocks,
    }


def decode_hist(raw: list[int]) -> dict[str, Any]:
    coal = raw[15] if len(raw) > 15 else 0
    return {
        "raw": [fmt_hex(v) for v in raw],
        "underflow_count": raw[8],
        "overflow_count": raw[9],
        "bank_status": fmt_hex(raw[11]),
        "port_status": fmt_hex(raw[12]),
        "total_hits": raw[13],
        "dropped_hits": raw[14],
        "coal_status": fmt_hex(coal),
        "coal_occupancy": coal & 0xFF,
        "coal_occupancy_max": (coal >> 8) & 0xFF,
        "coal_queue_overflow_count": (coal >> 16) & 0xFFFF,
        "last_interval_total_hits": raw[17] if len(raw) > 17 else 0,
        "last_interval_dropped_hits": raw[18] if len(raw) > 18 else 0,
    }


def read_hist_counts(bus: ScBus) -> dict[str, Any]:
    return decode_hist([bus.read(SC_HIST_CSR + idx, 1)[0] for idx in range(19)])


def decode_mts(raw: list[int]) -> dict[str, Any]:
    return {
        "raw": [fmt_hex(v) for v in raw],
        "control_status": fmt_hex(raw[0]),
        "running": raw[0] & 0x1,
        "force_stop": (raw[0] >> 1) & 0x1,
        "soft_reset": (raw[0] >> 2) & 0x1,
        "bypass_lapse": (raw[0] >> 3) & 0x1,
        "discard_hiterr": (raw[0] >> 4) & 0x1,
        "drop_delay_error": (raw[0] >> 5) & 0x1,
        "delay_ts_field_use_t": (raw[0] >> 29) & 0x1,
        "derive_tot": (raw[0] >> 18) & 0x1,
        "discard_hit_count": raw[1],
        "expected_latency": raw[2],
        "total_hit_count": ((raw[3] & 0xFFFF) << 32) | raw[4],
    }


def read_mts_counts(bus: ScBus) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for index, base in enumerate(SC_MTS_BASES):
        raw = [bus.read(base + idx, 1)[0] for idx in range(5)]
        row = decode_mts(raw)
        row.update({"index": index, "base": f"0x{base:05X}"})
        rows.append(row)
    return rows


def decode_rbcam(raw: list[int]) -> dict[str, Any]:
    return {
        "raw": [fmt_hex(v) for v in raw],
        "uid": fmt_hex(raw[0]),
        "control": fmt_hex(raw[2]),
        "latency": raw[3],
        "fill_level": raw[4],
        "inerr_count": raw[5],
        "push_count": raw[6],
        "pop_count": raw[7],
        "overwrite_count": raw[8],
        "cache_miss_count": raw[9],
    }


def read_rbcam_counts(bus: ScBus) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for stack, base0 in (("lower", SC_RBCAM_STACK0), ("upper", SC_RBCAM_STACK1)):
        for lane in range(4):
            base = base0 + lane * SC_RBCAM_STRIDE
            raw = [bus.read(base + idx, 1)[0] for idx in range(10)]
            row = decode_rbcam(raw)
            row.update({"stack": stack, "lane": lane, "base": f"0x{base:05X}"})
            rows.append(row)
    return rows


def read_emulator_visible_cfg(bus: ScBus) -> list[dict[str, Any]]:
    rows = []
    for lane in range(8):
        base = SC_EMU_BASE + lane * SC_EMU_STRIDE
        frame_count = bus.read(base + EMU_REG_LANE_STATUS_BASE, 2)
        hit_count = bus.read(base + EMU_REG_LANE_STATUS_BASE + 2, 2)
        rows.append({
            "lane": lane,
            "base": f"0x{base:05X}",
            "central": fmt_hex(bus.read(base + EMU_REG_CENTRAL, 1)[0]),
            "signal": fmt_hex(bus.read(base + EMU_REG_SIGNAL, 1)[0]),
            "format": fmt_hex(bus.read(base + EMU_REG_FORMAT, 1)[0]),
            "rates": fmt_hex(bus.read(base + EMU_REG_RATES, 1)[0]),
            "cluster_fix": fmt_hex(bus.read(base + EMU_REG_CLUSTER_FIX, 1)[0]),
            "lane_enable": fmt_hex(bus.read(base + EMU_REG_LANE_ENABLE, 1)[0]),
            "bank_status": fmt_hex(bus.read(base + EMU_REG_BANK_STATUS, 1)[0]),
            "frame_count": (frame_count[1] << 32) | frame_count[0],
            "hit_count": (hit_count[1] << 32) | hit_count[0],
        })
    return rows


def read_type0_arb_counts(bus: ScBus) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for lane in range(8):
        base = SC_TYPE0_ARB_BASE + lane * SC_TYPE0_ARB_STRIDE
        status = bus.read(base + TYPE0_ARB_REG_STATUS, 1)[0]
        rows.append({
            "lane": lane,
            "base": f"0x{base:05X}",
            "uid": fmt_hex(bus.read(base, 1)[0]),
            "control": fmt_hex(bus.read(base + TYPE0_ARB_REG_CONTROL, 1)[0]),
            "status": decode_type0_arb_status(status),
            "watchdog_cycles": bus.read(base + TYPE0_ARB_REG_WATCHDOG, 1)[0] & 0xFFFF,
            "ingress_real_hits": read_type0_arb_counter64(bus, base, TYPE0_ARB_REG_INGRESS_REAL),
            "ingress_emu_hits": read_type0_arb_counter64(bus, base, TYPE0_ARB_REG_INGRESS_EMU),
            "drops_real": read_type0_arb_counter64(bus, base, TYPE0_ARB_REG_DROPS_REAL),
            "drops_emu": read_type0_arb_counter64(bus, base, TYPE0_ARB_REG_DROPS_EMU),
            "egress_real_hits": read_type0_arb_counter64(bus, base, TYPE0_ARB_REG_EGRESS_REAL),
            "egress_emu_hits": read_type0_arb_counter64(bus, base, TYPE0_ARB_REG_EGRESS_EMU),
            "ingress_real_frames": read_type0_arb_counter64(bus, base, TYPE0_ARB_REG_INGRESS_REAL_FRAMES),
            "ingress_emu_frames": read_type0_arb_counter64(bus, base, TYPE0_ARB_REG_INGRESS_EMU_FRAMES),
            "egress_real_frames": read_type0_arb_counter64(bus, base, TYPE0_ARB_REG_EGRESS_REAL_FRAMES),
            "egress_emu_frames": read_type0_arb_counter64(bus, base, TYPE0_ARB_REG_EGRESS_EMU_FRAMES),
        })
    return rows


def read_backpressure_counts(bus: ScBus) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for lane in range(8):
        base = SC_BACKPRESSURE_BASE + lane * SC_DATAPATH_LANE_STRIDE
        raw = [bus.read(base + idx, 1)[0] for idx in range(4)]
        rows.append({
            "lane": lane,
            "base": f"0x{base:05X}",
            "raw": [fmt_hex(v) for v in raw],
            "fill_level": raw[0],
            "almost_full_threshold": raw[2] & 0xFFFFFF,
            "almost_empty_threshold": raw[3] & 0xFFFFFF,
        })
    return rows


def read_frame_deassembly_counts(bus: ScBus) -> dict[str, Any]:
    rows = read_frame_deassembly_rows(bus)
    if not frame_deassembly_is_exported(rows):
        return {
            "exported": False,
            "reason": "not present in loaded AUTO_AVMM_PORT_ADDRESS_MAP",
            "probe": rows,
        }
    return {"exported": True, "rows": rows}


def read_hist_bins(bus: ScBus, path: Path, left: int, bin_width: int) -> dict[str, Any]:
    nonzero: list[dict[str, Any]] = []
    total = 0
    max_count = 0
    max_bin = 0
    counts = bus.read(SC_HIST_BIN, 256)
    if len(counts) != 256:
        raise RuntimeError(f"histogram burst read returned {len(counts)} bins, expected 256")
    with path.open("w", newline="", encoding="utf-8") as fd:
        writer = csv.writer(fd)
        writer.writerow(["bin_index", "bin_center", "count"])
        for idx, count in enumerate(counts):
            center = left + idx * bin_width + bin_width / 2.0
            writer.writerow([idx, f"{center:.3f}", count])
            total += count
            if count:
                nonzero.append({"bin": idx, "center": center, "count": count})
            if count > max_count:
                max_count = count
                max_bin = idx
    return {
        "csv": str(path),
        "total_bin_counts": total,
        "nonzero_bins": len(nonzero),
        "max_bin": max_bin,
        "max_count": max_count,
        "first_nonzero_bins": nonzero[:16],
    }


def configure_case(args: argparse.Namespace, bus: ScBus, source: str, mode: str) -> dict[str, Any]:
    canonical_mode = normalize_hist_mode(mode)
    is_delay = canonical_mode == "latency"
    in_port = HIST_IN_PORT[source]
    left = 0
    bin_width = args.delay_bin_width if is_delay else args.mode0_bin_width

    bus.write(SC_LVDS_BASE + 4, [0x000001FF])
    type0_arb = configure_type0_arbs(bus, args.type0_arb_mode, args.type0_arb_watchdog_cycles)
    downstream = configure_downstream(bus)
    stimulus = configure_emulators(
        bus,
        args.q16_rate,
        args.lane_mask,
        args.hist_interval_clocks,
        one_channel_per_asic=args.one_channel_per_asic,
        selected_channels=selected_channel_map(args),
    )
    time.sleep(args.post_config_ms / 1000.0)
    config = apply_hist_config(
        bus,
        delay_mode=is_delay,
        in_port=in_port,
        left=left,
        bin_width=bin_width,
        interval_clocks=args.hist_interval_clocks,
    )
    return {
        "config": config,
        "downstream": downstream,
        "type0_arb": type0_arb,
        "stimulus": stimulus,
        "source_rate_model": source_rate_model(args, source),
        "aggregate_rate_model": rate_model(args),
        "left": left,
        "bin_width": bin_width,
    }


def run_hist_readback(args: argparse.Namespace, bus: ScBus, out_dir: Path, source: str, mode: str, run_number: int) -> dict[str, Any]:
    preamble = prepare_run_control(args, bus)
    time.sleep(args.post_stop_reset_ms / 1000.0)
    canonical_mode = normalize_hist_mode(mode)
    case_cfg = configure_case(args, bus, source, canonical_mode)
    start = start_run_control(args, bus, run_number)
    start_ts = time.monotonic()
    time.sleep(args.hist_probe_delay_ms / 1000.0)
    probe_start_ts = time.monotonic()
    runctl_probe = read_runctl_mgmt_host(bus)
    bins = read_hist_bins(bus, out_dir / f"{source}_{canonical_mode}_hist_readback_bins.csv", case_cfg["left"], case_cfg["bin_width"])
    runctl_after_bins = read_runctl_mgmt_host(bus)
    stop = stop_run_control(args, bus)
    stop_ts = time.monotonic()
    time.sleep(args.post_end_ms / 1000.0)
    model = source_rate_model(args, source)
    expected = compare_expected_count(
        "hist_bin_total_interval",
        bins["total_bin_counts"],
        float(model["expected_hist_interval_hits"]),
        args,
    )
    return {
        "run_number": run_number,
        "preamble": preamble,
        "case_config": {k: v for k, v in case_cfg.items() if k not in {"left", "bin_width"}},
        "run_control_start": start,
        "probe_delay_ms": args.hist_probe_delay_ms,
        "read_started_ms_after_start": (probe_start_ts - start_ts) * 1000.0,
        "runctl_mgmt_host_probe": runctl_probe,
        "bins": bins,
        "expected": {
            "rate_model": model,
            "checks": [expected],
            "status": expected["status"],
        },
        "runctl_mgmt_host_after_bins": runctl_after_bins,
        "run_control_stop": stop,
        "run_elapsed_ms": (stop_ts - start_ts) * 1000.0,
    }


def run_csr_counter_readback(args: argparse.Namespace, bus: ScBus, source: str, mode: str, run_number: int) -> dict[str, Any]:
    preamble = prepare_run_control(args, bus)
    time.sleep(args.post_stop_reset_ms / 1000.0)
    canonical_mode = normalize_hist_mode(mode)
    case_cfg = configure_case(args, bus, source, canonical_mode)
    start = start_run_control(args, bus, run_number)
    start_ts = time.monotonic()
    time.sleep(args.csr_probe_delay_ms / 1000.0)
    probe_ts = time.monotonic()
    runctl = read_runctl_mgmt_host(bus)
    hist = read_hist_counts(bus)
    mts = read_mts_counts(bus)
    rbcam = read_rbcam_counts(bus)
    emu = read_emulator_visible_cfg(bus)
    type0_arb = read_type0_arb_counts(bus)
    backpressure = read_backpressure_counts(bus)
    frame_deassembly = read_frame_deassembly_counts(bus)
    stop = stop_run_control(args, bus)
    stop_ts = time.monotonic()
    time.sleep(args.post_end_ms / 1000.0)
    model = source_rate_model(args, source)
    probe_elapsed_ms = (probe_ts - start_ts) * 1000.0
    expected_elapsed_hits = float(model["aggregate_hps"]) * probe_elapsed_ms / 1000.0
    checks = [
        compare_expected_count(
            "hist_last_interval_total_hits",
            hist["last_interval_total_hits"],
            float(model["expected_hist_interval_hits"]),
            args,
        ),
        compare_expected_count(
            "hist_total_hits_elapsed",
            hist["total_hits"],
            expected_elapsed_hits,
            args,
        ),
    ]
    if hist["last_interval_total_hits"] == 0:
        # Before the first interval edge, TOTAL_HITS is the useful live counter.
        primary_status = checks[1]["status"]
    else:
        primary_status = checks[0]["status"]
    return {
        "run_number": run_number,
        "preamble": preamble,
        "case_config": {k: v for k, v in case_cfg.items() if k not in {"left", "bin_width"}},
        "run_control_start": start,
        "probe_delay_ms": args.csr_probe_delay_ms,
        "probe_elapsed_ms": probe_elapsed_ms,
        "runctl_mgmt_host": runctl,
        "hist": hist,
        "mts": mts,
        "rbcam": rbcam,
        "emulator": emu,
        "type0_arb": type0_arb,
        "backpressure": backpressure,
        "frame_deassembly": frame_deassembly,
        "expected": {
            "rate_model": model,
            "expected_elapsed_hits": expected_elapsed_hits,
            "checks": checks,
            "primary_check": "hist_total_hits_elapsed" if hist["last_interval_total_hits"] == 0 else "hist_last_interval_total_hits",
            "status": primary_status,
        },
        "run_control_stop": stop,
        "run_elapsed_ms": (stop_ts - start_ts) * 1000.0,
    }


def run_capture(args: argparse.Namespace, bus: ScBus, out_dir: Path, source: str, mode: str, run_number: int) -> dict[str, Any]:
    hist_run_number = run_number * 2
    csr_run_number = run_number * 2 + 1
    canonical_mode = normalize_hist_mode(mode)

    result = {
        "source": source,
        "mode": canonical_mode,
        "hist_readback_run": run_hist_readback(args, bus, out_dir, source, canonical_mode, hist_run_number),
        "csr_counter_run": run_csr_counter_readback(args, bus, source, canonical_mode, csr_run_number),
    }
    result["status"] = (
        "PASS"
        if result["hist_readback_run"]["expected"]["status"] == "PASS"
        and result["csr_counter_run"]["expected"]["status"] == "PASS"
        else "FAIL"
    )
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--device", default="/dev/mudaq0")
    parser.add_argument("--feb", type=int, default=7)
    parser.add_argument("--active-lane", type=int, default=0, help="Deprecated single-lane selector used only when --lane-mask is omitted")
    parser.add_argument("--lane-mask", type=parse_int_arg, help="8-bit emulator instance mask; use 0xFF for 32 channels x 8 ASICs")
    parser.add_argument("--one-channel-per-asic", action="store_true", help="Debug stimulus mode: enable only one local channel per active emulator/ASIC")
    parser.add_argument("--debug-channel", type=parse_int_arg, help="Force the one-channel debug stimulus to this local channel on every active ASIC; default is random per run")
    parser.add_argument("--debug-channel-seed", type=parse_int_arg, help="Deterministic seed for random per-ASIC debug-channel selection")
    parser.add_argument("--q16-rate", type=parse_int_arg, default=52)
    parser.add_argument("--target-rate-hz", type=float, help="Per-active-channel requested hit rate; converted to rate_88fp by round(rate_hz * 65536 / 125e6)")
    parser.add_argument("--wait-ms", type=int, default=1, help="Deprecated alias kept for old callers; use --hist-probe-delay-ms/--csr-probe-delay-ms")
    parser.add_argument("--hist-probe-delay-ms", type=int, default=2)
    parser.add_argument("--csr-probe-delay-ms", type=int, default=2)
    parser.add_argument("--hist-interval-clocks", type=int, default=DEFAULT_HIST_INTERVAL_CLOCKS, help="Histogram ping-pong interval in 125 MHz clocks; default is 1 ms so a 1 ms live probe sees the first frozen bank")
    parser.add_argument("--post-stop-reset-ms", type=int, default=50)
    parser.add_argument("--post-config-ms", type=int, default=50)
    parser.add_argument("--post-start-ms", type=int, default=100)
    parser.add_argument("--post-end-ms", type=int, default=100)
    parser.add_argument("--rc-settle-us", type=int, default=5000)
    parser.add_argument("--run-number-base", type=int, default=514900)
    parser.add_argument("--mode0-bin-width", type=int, default=1)
    parser.add_argument("--delay-bin-width", type=int, default=64)
    parser.add_argument("--sources", default="upper,lower", help="Comma-separated histogram extended sources: upper,lower")
    parser.add_argument("--modes", default="rate,latency", help="Comma-separated histogram modes: rate,latency (aliases: mode0,delay)")
    parser.add_argument("--type0-arb-mode", choices=tuple(TYPE0_ARB_MODE), default="emu", help="Per-lane post-deassembly arb_hit_type0 selection used for the live capture")
    parser.add_argument("--type0-arb-watchdog-cycles", type=parse_int_arg, default=500)
    parser.add_argument("--expected-tolerance-pct", type=float, default=5.0)
    parser.add_argument("--expected-tolerance-count", type=int, default=8)
    parser.add_argument("--no-fail-on-expected-mismatch", action="store_true", help="Write mismatch evidence but return success")
    parser.add_argument("--output-dir", type=Path, default=default_output_dir())
    parser.add_argument("--sc-tool", type=Path, default=default_sc_tool())
    parser.add_argument("--rc-tool", type=Path, default=default_rc_tool())
    parser.add_argument("--lock-tool", type=Path, default=Path("/home/yifeng/.local/bin/swb_ring_lock"))
    parser.add_argument("--runctrl-source", choices=("sc-dbg", "swb-reset-link", "upload-local"), default="swb-reset-link")
    parser.add_argument("--dbg-runctrl-gap-cycles", type=parse_int_arg, default=0xFFFF, help="Inter-command gap for dbg_mm2runctrl scripts; written to the IP's 16-bit gap_cycles field")
    parser.add_argument("--runctrl-phase-dwell-ms", type=int, default=2, help="Dwell after each upload-local run-control command before issuing the next phase")
    parser.add_argument("--swb-reset-preamble", action="store_true", help="Send reset/stop-reset before each SWB reset-link run; disabled by default because it can reset the FEB datapath SC window")
    parser.set_defaults(sc_reset_each_op=True)
    parser.add_argument("--sc-reset-each-op", dest="sc_reset_each_op", action="store_true", help="Reset the SC secondary ring before every sc_tool operation; default for reliable live readback")
    parser.add_argument("--no-sc-reset-each-op", dest="sc_reset_each_op", action="store_false", help="Reuse the SC secondary ring between operations; faster but can miss replies when the ring contains stale traffic")
    args = parser.parse_args()

    if not 0 <= args.active_lane <= 7:
        raise SystemExit("--active-lane must be 0..7")
    if args.lane_mask is None:
        args.lane_mask = 1 << args.active_lane
    args.lane_mask &= 0xFF
    if args.lane_mask == 0:
        raise SystemExit("--lane-mask must enable at least one emulator lane")
    if args.target_rate_hz is not None:
        args.q16_rate = q16_from_rate_hz(args.target_rate_hz)
    if not 0 <= args.q16_rate <= 0xFFFF:
        raise SystemExit("--q16-rate must be 0..65535")
    if args.hist_interval_clocks <= 0:
        raise SystemExit("--hist-interval-clocks must be positive")
    if args.debug_channel is not None and not 0 <= args.debug_channel < EMU_CHANNELS_PER_LANE:
        raise SystemExit(f"--debug-channel must be 0..{EMU_CHANNELS_PER_LANE - 1}")

    if args.one_channel_per_asic:
        enabled_lanes = [lane for lane in range(8) if (args.lane_mask >> lane) & 0x1]
        if args.debug_channel is not None:
            args.selected_channels = {lane: args.debug_channel for lane in enabled_lanes}
        else:
            rng = random.Random(args.debug_channel_seed) if args.debug_channel_seed is not None else random.SystemRandom()
            args.selected_channels = {lane: rng.randrange(EMU_CHANNELS_PER_LANE) for lane in enabled_lanes}
    else:
        args.selected_channels = {}

    out_dir = args.output_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    bus = ScBus(args.sc_tool, args.lock_tool, args.link, args.device, no_reset=not args.sc_reset_each_op)

    manifest: dict[str, Any] = {
        "created_at": dt.datetime.now().isoformat(timespec="seconds"),
        "output_dir": str(out_dir),
        "run_protocol": {
            "hist_readback": "configure, start a fresh run, wait hist_probe_delay_ms, read all 256 bins while run remains active, then stop",
            "csr_counter_readback": "start a separate fresh run after hist readback and sample counters after csr_probe_delay_ms",
            "addressing": "SC hub packet-word addresses; not Platform Designer/JTAG byte addresses",
            "hist_interval": "default histogram interval is 125000 clocks (1 ms at 125 MHz); bin reads return the frozen previous ping-pong bank",
            "hist_bin_read": "all 256 bins are requested in one SC read so the histogram slave can latch one frozen read bank for the dump",
            "hist_extended_sources": "CONTROL.in_port selects histogram_statistics_v2 hit_type1_extended_0/1 directly; the histogram ingress bridge is not present in this image",
            "type0_arbitration": "emulator traffic is injected after MuTRiG frame deassembly as hit_type0 atoms; arb_hit_type0 selects real/emu/mix before the MTS bank mux",
            "sc_transaction_reset": "default is to reset the SC secondary ring on each sc_tool operation; use --no-sc-reset-each-op only for controlled experiments",
        },
        "sc_word_map": {
            "hist_bin": f"0x{SC_HIST_BIN:05X}",
            "hist_csr": f"0x{SC_HIST_CSR:05X}",
            "rbcam_stack0": f"0x{SC_RBCAM_STACK0:05X}",
            "rbcam_stack1": f"0x{SC_RBCAM_STACK1:05X}",
            "emulator_bases": [f"0x{SC_EMU_BASE + lane * SC_EMU_STRIDE:05X}" for lane in range(8)],
            "type0_arb_bases": [f"0x{SC_TYPE0_ARB_BASE + lane * SC_TYPE0_ARB_STRIDE:05X}" for lane in range(8)],
            "dbg_runctrl": f"0x{SC_DBG_RUNCTRL:05X}",
            "upload_runctl_mgmt_host": f"0x{SC_UPLOAD_RUNCTL:05X}",
            "mts_bases": [f"0x{base:05X}" for base in SC_MTS_BASES],
            "backpressure_bases": [f"0x{SC_BACKPRESSURE_BASE + lane * SC_DATAPATH_LANE_STRIDE:05X}" for lane in range(8)],
            "frame_deassembly_bases": [f"0x{SC_FRAME_DEASM_BASE + lane * SC_FRAME_DEASM_STRIDE:05X}" for lane in range(8)],
        },
        "tools": {
            "sc_tool": str(args.sc_tool),
            "rc_tool": str(args.rc_tool),
            "lock_tool": str(args.lock_tool),
        },
        "stimulus": rate_model(args),
        "expected_tolerance": {
            "pct": args.expected_tolerance_pct,
            "count_floor": args.expected_tolerance_count,
        },
        "captures": [],
    }
    exit_code = 0

    try:
        expect_uid(bus, SC_HIST_CSR, HIST_UID, "histogram_statistics")
        expect_uid(bus, SC_RBCAM_STACK0, RBCAM_UID, "ring_buffer_cam_stack0_lane0")
        expect_uid(bus, SC_RBCAM_STACK1, RBCAM_UID, "ring_buffer_cam_stack1_lane0")

        sources = [item.strip() for item in args.sources.split(",") if item.strip()]
        modes = [normalize_hist_mode(item) for item in args.modes.split(",") if item.strip()]
        for source in sources:
            if source not in HIST_IN_PORT:
                raise RuntimeError(f"unsupported source '{source}'")

        case_index = 0
        for source in sources:
            for mode in modes:
                capture = run_capture(args, bus, out_dir, source, mode, args.run_number_base + case_index)
                manifest["captures"].append(capture)
                if capture["status"] != "PASS":
                    exit_code = 2
                case_index += 1
        manifest["status"] = "PASS" if exit_code == 0 else "FAIL"
    finally:
        manifest_path = out_dir / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(manifest_path)

    if exit_code and args.no_fail_on_expected_mismatch:
        return 0
    return exit_code


if __name__ == "__main__":
    os.environ.setdefault("LC_ALL", "C")
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
