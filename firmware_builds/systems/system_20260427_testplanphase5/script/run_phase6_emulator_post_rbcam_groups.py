#!/usr/bin/env python3
"""Collect ASIC0 post-rbCAM delay histograms for Phase-6 plots."""

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


SCRIPT_DIR = Path(__file__).resolve().parent
SYSTEM_DIR = SCRIPT_DIR.parent
REPORT_DIR = SYSTEM_DIR / "reports"
BOARD_PROJECT_DIR = SYSTEM_DIR / "syn" / "board_projects" / "fe_scifi_feb_v3"
POST_RBCAM_DELAY_LEFT = 2000.0
POST_RBCAM_DELAY_RIGHT = 3000.0

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import _default_sc_tool  # noqa: E402
from check_run_control import default_rc_tool  # noqa: E402


EMU_BASE_WORD = 0x08800
EMU_STRIDE_WORD = 0x10
SOURCE_MUX_BASE_WORD = 0x08890
SOURCE_MUX_STRIDE_WORD = 0x10
SOURCE_MUX_MODE_WORDS = {
    "real": 0x0,
    "emulator": 0x1,
    "rr": 0x2,
}
SOURCE_MUX_CONTROL_CLEAR_COUNTERS = 0x100
HIST_CSR_BASE_WORD = 0x0A900
HIST_SNOOP_SELECTOR_BASE_WORD = 0x0AB00
HIST_INGRESS_BRIDGE_UID = 0x48495342
HIST_SNOOP_SELECTOR_UIDS = {0x48534E50, 0x48535E50}
HIST_SELECTOR_UIDS = HIST_SNOOP_SELECTOR_UIDS | {HIST_INGRESS_BRIDGE_UID}
HIST_SNOOP_SELECTOR_CONTROL_HP = 0x00000000
HIST_SNOOP_SELECTOR_CONTROL_RBCAM_FILTER = 0x00000003
HIST_SNOOP_SELECTOR_CONTROL_CLEAR = 0x00000100
DATA_JTAG_UID_ADDR = 0x00020400
DATA_JTAG_UID = 0x48495354
HIST_CSR_JTAG_BASE = 0x00020400
HIST_SNOOP_SELECTOR_JTAG_BASE = 0x00020C00
SOURCE_MUX_JTAG_BASE = 0x00002240
SOURCE_MUX_JTAG_STRIDE = 0x40
RBCAM_JTAG_BASE_STACK0 = 0x00021000
RBCAM_JTAG_BASE_STACK1 = 0x00023000
RBCAM_JTAG_STRIDE = 0x80
MTS_JTAG_BASES = (0x00004000, 0x00008000)
RBCAM_BASE_WORD_STACK0 = 0x0AC00
RBCAM_BASE_WORD_STACK1 = 0x0AD00
RBCAM_STRIDE_WORD = 0x20
RBCAM_UID = 0x5242434D
MTS_BASE_WORDS = (0x09000, 0x0A000)
INJECTOR_BASE_WORD = 0x0AC80

RATE_CASES = (
    ("10k", 10_000, 12_500),
    ("100k", 100_000, 1_250),
    ("500k", 500_000, 250),
    ("1M", 1_000_000, 125),
)
HEADER_MULTIPLICITIES = (2, 3, 4, 5)
EMU_CSR_CENTRAL = 0x07
EMU_CSR_SIGNAL = 0x08
EMU_CSR_BACKGROUND = 0x09
EMU_CSR_MUTRIG_FORMAT = 0x0A
EMU_CSR_RATES = 0x0B
EMU_CSR_CLUSTER_FIX = 0x0C
EMU_CSR_CLUSTER_RANDOM = 0x0D
EMU_CSR_PRNG_SEED = 0x0E
EMU_CSR_TIMEBASE_SEED = 0x0F
EMU_SIGNAL_EXTERNAL_FIXED = 0x00000001
EMU_SIGNAL_INTERNAL_PERIODIC = 0x00000002
EMU_FORMAT_TYPE0_LONG_NO_IDLE = 0x00000020
EMU_DEFAULT_HIT_RATE = 0x00000800
EMU_INTERNAL_CLOCK_HZ = 125_000_000.0


def internal_rate_increment(target_hz: float) -> int:
    increment = int(round((target_hz / EMU_INTERNAL_CLOCK_HZ) * 65536.0))
    return max(1, min(0xFFFF, increment))


def default_system_console() -> Path:
    env_value = os.environ.get("BOARD_TEST_SYSCON", "")
    if env_value:
        return Path(env_value)
    return Path("/data1/intelFPGA/18.1/quartus/sopc_builder/bin/system-console")


def default_jdi() -> Path:
    return BOARD_PROJECT_DIR / "output_files_pipe" / "top_nostp_pipe.jdi"


def run_cmd(cmd: list[str], *, timeout: float | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)


def checked_cmd(cmd: list[str], *, timeout: float | None = None) -> str:
    proc = run_cmd(cmd, timeout=timeout)
    if proc.returncode != 0:
        raise RuntimeError(
            f"command failed rc={proc.returncode}: {' '.join(cmd)}\n{proc.stdout}{proc.stderr}"
        )
    return proc.stdout + proc.stderr


def system_console_cmd(args: argparse.Namespace, script: Path, script_args: list[str]) -> list[str]:
    return [
        "env",
        "-u",
        "DISPLAY",
        "_JAVA_OPTIONS=-Djava.awt.headless=true",
        str(args.system_console),
        "-cli",
        "-disable_readline",
        "-disable_timeout",
        f"--project_dir={args.project_dir}",
        f"--jdi={args.jdi}",
        f"--script={script}",
        "--",
        *script_args,
    ]


def parse_payload(text: str) -> list[int]:
    return [int(match.group(2), 16) for match in re.finditer(r"payload\[(\d+)\]\s*=\s*(0x[0-9A-Fa-f]+)", text)]


def sc_enable_mask_args() -> list[str]:
    value = os.environ.get("BOARD_TEST_SC_ENABLE_MASK", "").strip()
    return ["--enable-mask", value] if value else []


def sc_read(sc_tool: Path, device: str, link: int, addr: int, count: int = 1) -> list[int]:
    argv = [
        str(sc_tool),
        str(link),
        "read",
        f"0x{addr:05X}",
        str(count),
        "--device",
        device,
        "--quiet",
    ]
    argv.extend(sc_enable_mask_args())
    out = checked_cmd(argv)
    words = parse_payload(out)
    if len(words) != count:
        raise RuntimeError(f"SC read 0x{addr:05X} count={count} returned {len(words)} words\n{out}")
    return words


def sc_write(sc_tool: Path, device: str, link: int, addr: int, words: list[int]) -> None:
    argv = [
        str(sc_tool),
        str(link),
        "write",
        f"0x{addr:05X}",
        *[f"0x{word & 0xFFFFFFFF:08X}" for word in words],
        "--device",
        device,
        "--quiet",
    ]
    argv.extend(sc_enable_mask_args())
    out = checked_cmd(argv)
    if re.search(r"rsp\s*:\s*(SLVERR|DECERR)", out):
        raise RuntimeError(f"SC write 0x{addr:05X} got bus error\n{out}")


def rc_send(rc_tool: Path, device: str, feb: int, name: str, run_number: int | None = None, settle_us: int = 5000) -> str:
    argv = [str(rc_tool), "send", name, "--device", device, "--feb", str(feb), "--settle-us", str(settle_us)]
    if run_number is not None:
        argv.extend(["--run", str(run_number)])
    return checked_cmd(argv)


def emu_base(lane: int) -> int:
    return EMU_BASE_WORD + lane * EMU_STRIDE_WORD


def source_mux_base(lane: int) -> int:
    return SOURCE_MUX_BASE_WORD + lane * SOURCE_MUX_STRIDE_WORD


def configure_sources(sc_tool: Path, device: str, link: int, source_mode: str) -> None:
    mode_word = SOURCE_MUX_MODE_WORDS[source_mode]
    for lane in range(8):
        sc_write(
            sc_tool,
            device,
            link,
            source_mux_base(lane) + 2,
            [mode_word | SOURCE_MUX_CONTROL_CLEAR_COUNTERS],
        )
        sc_write(sc_tool, device, link, source_mux_base(lane) + 2, [mode_word])


def emulator_cluster_fix_word(header_channel: int, multiplicity: int) -> int:
    low = max(0, min(127, header_channel))
    width = max(1, multiplicity)
    high = max(low, min(127, low + width - 1))
    return low | (high << 7) | (1 << 14)


def configure_emulators(
    sc_tool: Path,
    device: str,
    link: int,
    active_lane: int,
    *,
    multiplicity: int,
    header_channel: int,
    emu_hit_rate: int = EMU_DEFAULT_HIT_RATE,
    emu_signal: int = EMU_SIGNAL_EXTERNAL_FIXED,
    cluster_width: int = 1,
) -> None:
    cluster_fix = emulator_cluster_fix_word(header_channel, cluster_width)
    for lane in range(8):
        base = emu_base(lane)
        enabled = 1 if lane == active_lane else 0
        sc_write(sc_tool, device, link, base + EMU_CSR_CENTRAL, [0x00000000])
        if enabled:
            sc_write(sc_tool, device, link, base + EMU_CSR_SIGNAL, [emu_signal])
            sc_write(sc_tool, device, link, base + EMU_CSR_BACKGROUND, [0x00000000])
            sc_write(sc_tool, device, link, base + EMU_CSR_MUTRIG_FORMAT, [EMU_FORMAT_TYPE0_LONG_NO_IDLE])
            sc_write(sc_tool, device, link, base + EMU_CSR_RATES, [emu_hit_rate & 0x0000FFFF])
            sc_write(sc_tool, device, link, base + EMU_CSR_CLUSTER_FIX, [cluster_fix])
            sc_write(sc_tool, device, link, base + EMU_CSR_CLUSTER_RANDOM, [0x00000000])
            sc_write(sc_tool, device, link, base + EMU_CSR_PRNG_SEED, [0xDEADBEEF ^ lane])
            sc_write(sc_tool, device, link, base + EMU_CSR_TIMEBASE_SEED, [0x00010001])
        sc_write(sc_tool, device, link, base + EMU_CSR_CENTRAL, [enabled])


def configure_injector(
    sc_tool: Path,
    device: str,
    link: int,
    *,
    mode: int,
    pulse_interval: int,
    multiplicity: int,
    header_delay: int,
    pulse_high: int,
    header_channel: int,
) -> None:
    writes = [
        (2, 0),
        (3, header_delay),
        (4, 1),
        (5, multiplicity),
        (6, header_channel),
        (7, pulse_interval),
        (8, pulse_high),
        (2, mode),
    ]
    for offset, value in writes:
        sc_write(sc_tool, device, link, INJECTOR_BASE_WORD + offset, [value])


def stop_injector(sc_tool: Path, device: str, link: int) -> None:
    sc_write(sc_tool, device, link, INJECTOR_BASE_WORD + 2, [0])


def selector_control_for_source(source: str) -> int:
    if source == "pre":
        return HIST_SNOOP_SELECTOR_CONTROL_HP
    if source == "post":
        return HIST_SNOOP_SELECTOR_CONTROL_RBCAM_FILTER
    raise ValueError(f"unsupported histogram snoop source {source!r}")


def selector_label_for_source(source: str) -> str:
    if source == "pre":
        return "hit-processor ingress"
    if source == "post":
        return "filtered rbCAM egress"
    raise ValueError(f"unsupported histogram snoop source {source!r}")


def histogram_profile_for_source(source: str, override: str | None = None) -> str:
    if override:
        return override
    if source == "pre":
        return "delay-hit-t-pre"
    if source == "post":
        return "delay-debug3"
    raise ValueError(f"unsupported histogram snoop source {source!r}")


def delay_window_for_source(source: str) -> tuple[float, float]:
    if source == "pre":
        return (0.0, 2000.0)
    if source == "post":
        return (POST_RBCAM_DELAY_LEFT, POST_RBCAM_DELAY_RIGHT)
    raise ValueError(f"unsupported histogram snoop source {source!r}")


def configure_selector(sc_tool: Path, device: str, link: int, source: str) -> dict[str, int]:
    control = selector_control_for_source(source)
    sc_write(
        sc_tool,
        device,
        link,
        HIST_SNOOP_SELECTOR_BASE_WORD + 2,
        [control | HIST_SNOOP_SELECTOR_CONTROL_CLEAR],
    )
    words = sc_read(sc_tool, device, link, HIST_SNOOP_SELECTOR_BASE_WORD, 8)
    uid = words[0]
    status = words[3]
    if uid == HIST_INGRESS_BRIDGE_UID:
        if source == "pre":
            mode_ok = (status & 0x7) == 0
        else:
            mode_ok = (status & 0x7) == 0x3
    else:
        if source == "pre":
            mode_ok = (status & 0x1) == 0
        else:
            mode_ok = (status & 0x3) == 0x3
    if (uid not in HIST_SELECTOR_UIDS) or not mode_ok:
        raise RuntimeError(
            f"histogram snoop selector not in {selector_label_for_source(source)} mode: "
            f"uid=0x{uid:08X} status=0x{status:08X}"
        )
    return decode_selector_words(words)


def decode_selector_words(words: list[int]) -> dict[str, int]:
    if words[0] == HIST_INGRESS_BRIDGE_UID:
        return {
            "uid": words[0],
            "meta": words[1],
            "control": words[2],
            "status": words[3],
            "hp_seen": 0,
            "rb_seen": 0,
            "hist_emit": 0,
            "hist_drop": 0,
        }
    return {
        "uid": words[0],
        "meta": words[1],
        "control": words[2],
        "status": words[3],
        "hp_seen": words[4],
        "rb_seen": words[5],
        "hist_emit": words[6],
        "hist_drop": words[7],
    }


def decode_source_mux_words(words: list[int]) -> dict[str, int]:
    mode = words[2] & 0x3
    return {
        "present": 1,
        "uid": words[0],
        "meta": words[1],
        "control": words[2],
        "mode": mode,
        "status": words[3],
        "real_in": words[4],
        "emu_in": words[5],
        "selected": words[6],
        "switch_count": words[7],
        "last_selected": words[8],
        "fifo_status": words[9],
        "real_drop": words[10],
        "emu_drop": words[11],
        "real_out": words[12],
        "emu_out": words[13],
    }


def empty_source_mux_snapshot() -> dict[str, int]:
    return {
        "present": 0,
        "uid": 0,
        "meta": 0,
        "control": 0,
        "mode": 0,
        "status": 0,
        "real_in": 0,
        "emu_in": 0,
        "selected": 0,
        "switch_count": 0,
        "last_selected": 0,
        "fifo_status": 0,
        "real_drop": 0,
        "emu_drop": 0,
        "real_out": 0,
        "emu_out": 0,
    }


def source_mux_snapshot(sc_tool: Path, device: str, link: int, lane: int) -> dict[str, int]:
    return decode_source_mux_words(sc_read(sc_tool, device, link, source_mux_base(lane), 16))


def rbcam_base(lane: int) -> int:
    if lane < 4:
        return RBCAM_BASE_WORD_STACK0 + lane * RBCAM_STRIDE_WORD
    return RBCAM_BASE_WORD_STACK1 + (lane - 4) * RBCAM_STRIDE_WORD


def decode_rbcam_words(words: list[int]) -> dict[str, int]:
    return {
        "uid": words[0],
        "meta": words[1],
        "control": words[2],
        "expected_latency": words[3],
        "fill_level": words[4],
        "inerr": words[5],
        "push": words[6],
        "pop": words[7],
        "overwrite": words[8],
        "cache_miss": words[9],
    }


def u48(high_word: int, low_word: int, high_bits: int = 16) -> int:
    return ((high_word & ((1 << high_bits) - 1)) << 32) | (low_word & 0xFFFFFFFF)


def decode_mts_words(idx: int, base: int, words: list[int]) -> dict[str, int]:
    return {
        "idx": idx,
        "base": base,
        "status_control": words[0],
        "discard_hits": words[1],
        "expected_latency": words[2],
        "total_hits": u48(words[3], words[4], high_bits=16),
    }


def mts_snapshot(sc_tool: Path, device: str, link: int) -> list[dict[str, int]]:
    rows: list[dict[str, int]] = []
    for idx, base in enumerate(MTS_BASE_WORDS):
        words = sc_read(sc_tool, device, link, base, 5)
        rows.append(decode_mts_words(idx, base, words))
    return rows


def rbcam_snapshot(sc_tool: Path, device: str, link: int, lane: int) -> dict[str, int]:
    base = rbcam_base(lane)
    words = sc_read(sc_tool, device, link, base, 10)
    decoded = decode_rbcam_words(words)
    decoded["base"] = base
    decoded["uid_ok"] = 1 if decoded["uid"] == RBCAM_UID else 0
    return decoded


def hist_snapshot(sc_tool: Path, device: str, link: int) -> dict[str, int]:
    regs = sc_read(sc_tool, device, link, HIST_CSR_BASE_WORD + 8, 11)
    return decode_hist_regs(regs)


def decode_hist_regs(regs: list[int]) -> dict[str, int]:
    return {
        "underflow": regs[0],
        "overflow": regs[1],
        "interval_cfg": regs[2],
        "bank_status": regs[3],
        "port_status": regs[4],
        "total_hits": regs[5],
        "dropped_hits": regs[6],
        "coal_status": regs[7],
        "profile": regs[8],
        "last_interval_total_hits": regs[9],
        "last_interval_dropped_hits": regs[10],
    }


def histogram_csv_summary(path: Path, window_left: float, window_right: float) -> dict[str, Any]:
    total = 0
    nonzero = 0
    peak_count = 0
    peak_center: float | None = None
    in_window = 0
    low_out = 0
    high_out = 0
    with path.open(newline="", encoding="utf-8") as handle:
        reader = csv.DictReader(handle)
        for row in reader:
            center = float(row["bin_center"])
            count = int(row["count"])
            total += count
            if count:
                nonzero += 1
            if count > peak_count:
                peak_count = count
                peak_center = center
            if window_left <= center < window_right:
                in_window += count
            elif center < window_left:
                low_out += count
            else:
                high_out += count
    out_window = total - in_window
    return {
        "total": total,
        "nonzero": nonzero,
        "peak_center": peak_center,
        "peak_count": peak_count,
        "peak_pct": (100.0 * peak_count / total) if total else 0.0,
        "window_left": window_left,
        "window_right": window_right,
        "in_window": in_window,
        "in_pct": (100.0 * in_window / total) if total else 0.0,
        "out_window": out_window,
        "out_pct": (100.0 * out_window / total) if total else 0.0,
        "low_out": low_out,
        "high_out": high_out,
    }


def dump_histogram(args: argparse.Namespace, csv_path: Path, log_path: Path) -> dict[str, Any]:
    cmd = system_console_cmd(args, SCRIPT_DIR / "phase6_histogram_bin_dump_keep_ingress.tcl", [
        "--profile",
        histogram_profile_for_source(args.hist_snoop_source, args.hist_profile_override),
        "--out",
        str(csv_path),
        "--lane-filter",
        str(args.active_lane),
        "--read-chunk-words",
        str(args.hist_bin_read_chunk_words),
        "--read-delay-ms",
        str(args.hist_bin_read_delay_ms),
    ])
    start = time.monotonic()
    try:
        proc = run_cmd(cmd, timeout=args.jtag_timeout_s)
        timed_out = False
    except subprocess.TimeoutExpired as exc:
        elapsed = time.monotonic() - start
        stdout = exc.stdout or ""
        stderr = exc.stderr or ""
        if isinstance(stdout, bytes):
            stdout = stdout.decode(errors="replace")
        if isinstance(stderr, bytes):
            stderr = stderr.decode(errors="replace")
        log_path.write_text(
            json.dumps(
                {
                    "argv": cmd,
                    "returncode": 124,
                    "elapsed_s": elapsed,
                    "timed_out": True,
                    "timeout_s": args.jtag_timeout_s,
                },
                indent=2,
            )
            + "\n\n"
            + stdout
            + stderr,
            encoding="utf-8",
        )
        raise RuntimeError(f"histogram dump timed out after {args.jtag_timeout_s}s; see {log_path}") from exc
    elapsed = time.monotonic() - start
    log_path.write_text(
        json.dumps(
            {
                "argv": cmd,
                "returncode": proc.returncode,
                "elapsed_s": elapsed,
                "timed_out": timed_out,
            },
            indent=2,
        )
        + "\n\n"
        + proc.stdout
        + proc.stderr,
        encoding="utf-8",
    )
    if proc.returncode != 0:
        raise RuntimeError(f"histogram dump failed rc={proc.returncode}; see {log_path}")
    if not csv_path.is_file():
        raise RuntimeError(f"histogram dump did not create {csv_path}")
    return {"elapsed_s": elapsed, "log": str(log_path)}


def jtag_case_cmd(args: argparse.Namespace, op: str, case: dict[str, Any], run_number: int) -> list[str]:
    emu_signal = EMU_SIGNAL_EXTERNAL_FIXED
    emu_cluster_width = 1
    emu_hit_rate = EMU_DEFAULT_HIT_RATE
    if args.emulator_trigger_mode == "internal-periodic":
        emu_signal = EMU_SIGNAL_INTERNAL_PERIODIC
        emu_cluster_width = int(case.get("multiplicity", 1))
        if case.get("target_hz") is not None:
            emu_hit_rate = internal_rate_increment(float(case["target_hz"]))
        else:
            target_hz = EMU_INTERNAL_CLOCK_HZ / float(args.header_pulse_interval)
            emu_hit_rate = internal_rate_increment(target_hz)
    script_args = [
        "--op",
        op,
        "--run-number",
        str(run_number),
        "--case-mode",
        str(case.get("mode", 1)),
        "--pulse-interval",
        str(case.get("pulse_interval", args.header_pulse_interval)),
        "--multiplicity",
        str(case.get("multiplicity", 1)),
        "--header-delay",
        str(args.header_delay),
        "--pulse-high",
        str(args.pulse_high),
        "--header-channel",
        str(args.header_channel),
        "--active-lane",
        str(args.active_lane),
        "--source-mode",
        args.source_mode,
        "--hist-snoop-source",
        args.hist_snoop_source,
        "--lvds-lane-go-mask",
        str(args.lvds_lane_go_mask),
        "--emu-hit-rate",
        str(emu_hit_rate),
        "--emu-signal",
        str(emu_signal),
        "--emu-cluster-width",
        str(emu_cluster_width),
        "--post-stop-reset-ms",
        str(args.post_stop_reset_ms),
        "--runctl-delay-ms",
        str(args.jtag_runctl_delay_ms),
    ]
    if args.skip_emulator_config:
        script_args.append("--skip-emulator-config")
    if args.skip_source_mux:
        script_args.append("--skip-source-mux")
    if args.skip_runctl_reset:
        script_args.append("--skip-runctl-reset")
    return system_console_cmd(args, SCRIPT_DIR / "phase6_emulator_post_rbcam_jtag_case.tcl", script_args)


def run_jtag_case(args: argparse.Namespace, op: str, case: dict[str, Any], run_number: int, log_path: Path) -> str:
    cmd = jtag_case_cmd(args, op, case, run_number)
    proc = run_cmd(cmd, timeout=args.jtag_timeout_s)
    log_path.write_text(
        json.dumps({"argv": cmd, "returncode": proc.returncode}, indent=2)
        + "\n\n"
        + proc.stdout
        + proc.stderr,
        encoding="utf-8",
    )
    if proc.returncode != 0 or "PHASE6_JTAG_CASE_RESULT status=OK" not in (proc.stdout + proc.stderr):
        raise RuntimeError(f"JTAG {op} failed rc={proc.returncode}; see {log_path}")
    return proc.stdout + proc.stderr


def jtag_snapshot(args: argparse.Namespace, label: str, log_path: Path) -> dict[str, Any]:
    script_args = ["--active-lane", str(args.active_lane)]
    if args.skip_source_mux:
        script_args.append("--skip-source-mux")
    cmd = system_console_cmd(
        args,
        SCRIPT_DIR / "phase6_post_rbcam_snapshot.tcl",
        script_args,
    )
    proc = run_cmd(cmd, timeout=args.jtag_timeout_s)
    text = proc.stdout + proc.stderr
    log_path.write_text(
        json.dumps({"argv": cmd, "returncode": proc.returncode, "label": label}, indent=2)
        + "\n\n"
        + text,
        encoding="utf-8",
    )
    if proc.returncode != 0:
        raise RuntimeError(f"JTAG snapshot failed rc={proc.returncode}; see {log_path}")
    match = re.search(r"PHASE6_POST_RBCAM_SNAPSHOT_JSON\s+(\{.*\})", text)
    if not match:
        raise RuntimeError(f"JTAG snapshot did not emit JSON; see {log_path}")
    raw = json.loads(match.group(1))
    rbcam = decode_rbcam_words(raw["rbcam"])
    if args.active_lane < 4:
        rbcam_base = RBCAM_JTAG_BASE_STACK0 + args.active_lane * RBCAM_JTAG_STRIDE
    else:
        rbcam_base = RBCAM_JTAG_BASE_STACK1 + (args.active_lane - 4) * RBCAM_JTAG_STRIDE
    rbcam["base"] = rbcam_base
    rbcam["uid_ok"] = 1 if rbcam["uid"] == RBCAM_UID else 0
    return {
        "source_mux": empty_source_mux_snapshot() if args.skip_source_mux else decode_source_mux_words(raw["source_mux"]),
        "rbcam": rbcam,
        "selector": decode_selector_words(raw["selector"]),
        "hist": decode_hist_regs(raw["hist"]),
        "mts": [
            decode_mts_words(0, MTS_BASE_WORDS[0], raw["mts0"]),
            decode_mts_words(1, MTS_BASE_WORDS[1], raw["mts1"]),
        ],
    }


def run_to_running(args: argparse.Namespace, run_number: int, case: dict[str, Any]) -> None:
    if not args.skip_runctl_reset:
        rc_send(args.rc_tool, args.device, args.feb, "reset", settle_us=args.rc_settle_us)
        rc_send(args.rc_tool, args.device, args.address_feb, "address", settle_us=args.rc_settle_us)
        rc_send(args.rc_tool, args.device, args.feb, "stop-reset", settle_us=args.rc_settle_us)
        time.sleep(args.post_stop_reset_ms / 1000.0)
    if not args.skip_source_mux:
        configure_sources(args.sc_tool, args.device, args.link, args.source_mode)
    if not args.skip_emulator_config:
        configure_emulators(
            args.sc_tool,
            args.device,
            args.link,
            args.active_lane,
            multiplicity=case.get("multiplicity", 1),
            header_channel=args.header_channel,
            emu_hit_rate=(
                internal_rate_increment(float(case["target_hz"]))
                if args.emulator_trigger_mode == "internal-periodic" and case.get("target_hz") is not None
                else internal_rate_increment(EMU_INTERNAL_CLOCK_HZ / float(args.header_pulse_interval))
                if args.emulator_trigger_mode == "internal-periodic"
                else EMU_DEFAULT_HIT_RATE
            ),
            emu_signal=(
                EMU_SIGNAL_INTERNAL_PERIODIC
                if args.emulator_trigger_mode == "internal-periodic"
                else EMU_SIGNAL_EXTERNAL_FIXED
            ),
            cluster_width=(
                int(case.get("multiplicity", 1))
                if args.emulator_trigger_mode == "internal-periodic"
                else 1
            ),
        )
    configure_selector(args.sc_tool, args.device, args.link, args.hist_snoop_source)
    configure_injector(
        args.sc_tool,
        args.device,
        args.link,
        mode=case["mode"],
        pulse_interval=case.get("pulse_interval", args.header_pulse_interval),
        multiplicity=case.get("multiplicity", 1),
        header_delay=args.header_delay,
        pulse_high=args.pulse_high,
        header_channel=args.header_channel,
    )
    rc_send(args.rc_tool, args.device, args.feb, "run-prepare", run_number, settle_us=args.rc_settle_us)
    rc_send(args.rc_tool, args.device, args.feb, "sync", settle_us=args.rc_settle_us)
    rc_send(args.rc_tool, args.device, args.feb, "start-run", settle_us=args.rc_settle_us)


def run_case(args: argparse.Namespace, case: dict[str, Any], run_number: int) -> dict[str, Any]:
    csv_path = REPORT_DIR / f"{case['stem']}.csv"
    log_path = REPORT_DIR / f"{case['stem']}.jtag.log"
    json_path = REPORT_DIR / f"{case['stem']}.json"

    if args.control_transport == "jtag":
        run_jtag_case(args, "setup", case, run_number, REPORT_DIR / f"{case['stem']}.setup_jtag.log")
    else:
        run_to_running(args, run_number, case)
    time.sleep(args.pre_dump_ms / 1000.0)
    if args.control_transport == "jtag":
        before = jtag_snapshot(args, "before", REPORT_DIR / f"{case['stem']}.before_snapshot_jtag.log")
        source_mux_before = before["source_mux"]
        rbcam_before = before["rbcam"]
        selector_before = before["selector"]
        hist_before = before["hist"]
        mts_before = before["mts"]
    else:
        source_mux_before = (
            empty_source_mux_snapshot()
            if args.skip_source_mux
            else source_mux_snapshot(args.sc_tool, args.device, args.link, args.active_lane)
        )
        rbcam_before = rbcam_snapshot(args.sc_tool, args.device, args.link, args.active_lane)
        selector_before = decode_selector_words(sc_read(args.sc_tool, args.device, args.link, HIST_SNOOP_SELECTOR_BASE_WORD, 8))
        hist_before = hist_snapshot(args.sc_tool, args.device, args.link)
        mts_before = mts_snapshot(args.sc_tool, args.device, args.link)
    dump = dump_histogram(args, csv_path, log_path)
    if args.control_transport == "jtag":
        after = jtag_snapshot(args, "after", REPORT_DIR / f"{case['stem']}.after_snapshot_jtag.log")
        mts_after = after["mts"]
        hist_after = after["hist"]
        selector_after = after["selector"]
        rbcam_after = after["rbcam"]
        source_mux_after = after["source_mux"]
        run_jtag_case(args, "teardown", case, run_number, REPORT_DIR / f"{case['stem']}.teardown_jtag.log")
    else:
        mts_after = mts_snapshot(args.sc_tool, args.device, args.link)
        hist_after = hist_snapshot(args.sc_tool, args.device, args.link)
        selector_after = decode_selector_words(sc_read(args.sc_tool, args.device, args.link, HIST_SNOOP_SELECTOR_BASE_WORD, 8))
        rbcam_after = rbcam_snapshot(args.sc_tool, args.device, args.link, args.active_lane)
        source_mux_after = (
            empty_source_mux_snapshot()
            if args.skip_source_mux
            else source_mux_snapshot(args.sc_tool, args.device, args.link, args.active_lane)
        )
        stop_injector(args.sc_tool, args.device, args.link)
        rc_send(args.rc_tool, args.device, args.feb, "end-run", settle_us=args.rc_settle_us)

    summary = {
        "case": case,
        "run_number": run_number,
        "csv": str(csv_path),
        "dump": dump,
        "histogram": histogram_csv_summary(csv_path, *delay_window_for_source(args.hist_snoop_source)),
        "hist_before": hist_before,
        "hist_after": hist_after,
        "mts_before": mts_before,
        "mts_after": mts_after,
        "selector_before": selector_before,
        "selector_after": selector_after,
        "rbcam_before": rbcam_before,
        "rbcam_after": rbcam_after,
        "source_mux_before": source_mux_before,
        "source_mux_after": source_mux_after,
    }
    json_path.write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return summary


def build_cases(date: str, source_prefix: str) -> list[dict[str, Any]]:
    cases: list[dict[str, Any]] = []
    for label, target_hz, interval in RATE_CASES:
        cases.append(
            {
                "group": "rate",
                "label": label,
                "target_hz": target_hz,
                "pulse_interval": interval,
                "mode": 2,
                "stem": f"{source_prefix}_rate_{label}_delay_hit_t_runtime_mux_{date}",
            }
        )
    for multiplicity in HEADER_MULTIPLICITIES:
        cases.append(
            {
                "group": "header_multiplicity",
                "label": f"mult{multiplicity}",
                "multiplicity": multiplicity,
                "mode": 1,
                "stem": f"{source_prefix}_header_mult{multiplicity}_delay_hit_t_runtime_mux_{date}",
            }
        )
    return cases


def write_report(path: Path, rows: list[dict[str, Any]], args: argparse.Namespace) -> None:
    def rate_text(delta: int, seconds: float) -> str:
        if seconds <= 0.0:
            return "n/a"
        return f"{delta / seconds:.2f}"

    snoop_title = "Pre-rbCAM" if args.hist_snoop_source == "pre" else "Post-rbCAM"
    lines = [
        f"# Phase 6 ASIC0 {args.source_label} {snoop_title} Histogram Collection",
        "",
        f"- Timestamp: `{dt.datetime.now().isoformat(timespec='seconds')}`",
        f"- Result: `{'PASS' if all(row['histogram']['total'] > 0 for row in rows) else 'FAIL'}`",
        f"- Active lane: `{args.active_lane}`",
        f"- Source mux: `{'skipped / absent in this image' if args.skip_source_mux else 'all lanes forced to ' + args.source_mode}`",
        f"- Emulator trigger mode: `{args.emulator_trigger_mode}`",
        f"- Emulator CSR setup: `{'skipped' if args.skip_emulator_config else 'enabled for active lane'}`",
        f"- Histogram selector: `{selector_label_for_source(args.hist_snoop_source)} at 0x{HIST_SNOOP_SELECTOR_BASE_WORD:05X}`",
        f"- Histogram profile: `{histogram_profile_for_source(args.hist_snoop_source, args.hist_profile_override)}`",
        f"- Delay window: `[{delay_window_for_source(args.hist_snoop_source)[0]:.0f}, {delay_window_for_source(args.hist_snoop_source)[1]:.0f})` cycles",
        f"- Header delay: `{args.header_delay}` cycles",
        f"- Pulse high: `{args.pulse_high}` cycles",
        "",
        "| Group | Case | Run | Hits | Nonzero | Peak [cyc] | In % | Low Out % | High Out % | Hist UF/OF | Hist UF/OF % | Hist Drops | Selector HP/RB/Emit/Drop | MTS0/1 Hits | MTS0/1 Hz | rbCAM InErr/Push/Pop | rbCAM Push/Pop Hz | rbCAM Overwrite/Miss | Source R/E In | Source R/E Out | Source R/E Drop | Window s | CSV |",
        "|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ]
    for row in rows:
        hist = row["histogram"]
        window_s = float(row.get("dump", {}).get("elapsed_s", 0.0))
        hist_drops = (row["hist_after"]["dropped_hits"] - row["hist_before"]["dropped_hits"]) & 0xFFFFFFFF
        hist_uf = (row["hist_after"]["underflow"] - row["hist_before"]["underflow"]) & 0xFFFFFFFF
        hist_of = (row["hist_after"]["overflow"] - row["hist_before"]["overflow"]) & 0xFFFFFFFF
        hist_total = int(hist["total"])
        hist_uf_pct = 100.0 * hist_uf / hist_total if hist_total else 0.0
        hist_of_pct = 100.0 * hist_of / hist_total if hist_total else 0.0
        selector_hp = (row["selector_after"]["hp_seen"] - row["selector_before"]["hp_seen"]) & 0xFFFFFFFF
        selector_rb = (row["selector_after"]["rb_seen"] - row["selector_before"]["rb_seen"]) & 0xFFFFFFFF
        selector_emit = (row["selector_after"]["hist_emit"] - row["selector_before"]["hist_emit"]) & 0xFFFFFFFF
        selector_drops = (row["selector_after"]["hist_drop"] - row["selector_before"]["hist_drop"]) & 0xFFFFFFFF
        mts_deltas = [
            (after["total_hits"] - before["total_hits"]) & ((1 << 48) - 1)
            for before, after in zip(row["mts_before"], row["mts_after"])
        ]
        rbcam_before = row["rbcam_before"]
        rbcam_after = row["rbcam_after"]
        rbcam_inerr = (rbcam_after["inerr"] - rbcam_before["inerr"]) & 0xFFFFFFFF
        rbcam_push = (rbcam_after["push"] - rbcam_before["push"]) & 0xFFFFFFFF
        rbcam_pop = (rbcam_after["pop"] - rbcam_before["pop"]) & 0xFFFFFFFF
        rbcam_overwrite = (rbcam_after["overwrite"] - rbcam_before["overwrite"]) & 0xFFFFFFFF
        rbcam_miss = (rbcam_after["cache_miss"] - rbcam_before["cache_miss"]) & 0xFFFFFFFF
        source_before = row["source_mux_before"]
        source_after = row["source_mux_after"]
        source_real_in = (source_after["real_in"] - source_before["real_in"]) & ((1 << 64) - 1)
        source_emu_in = (source_after["emu_in"] - source_before["emu_in"]) & ((1 << 64) - 1)
        source_real_out = (source_after["real_out"] - source_before["real_out"]) & ((1 << 64) - 1)
        source_emu_out = (source_after["emu_out"] - source_before["emu_out"]) & ((1 << 64) - 1)
        source_real_drop = (source_after["real_drop"] - source_before["real_drop"]) & ((1 << 64) - 1)
        source_emu_drop = (source_after["emu_drop"] - source_before["emu_drop"]) & ((1 << 64) - 1)
        lines.append(
            f"| `{row['case']['group']}` | `{row['case']['label']}` | {row['run_number']} | "
            f"{hist['total']} | {hist['nonzero']} | {hist['peak_center']} | "
            f"{hist['in_pct']:.6f} | {100.0 * hist['low_out'] / hist['total'] if hist['total'] else 0.0:.6f} | "
            f"{100.0 * hist['high_out'] / hist['total'] if hist['total'] else 0.0:.6f} | "
            f"{hist_uf}/{hist_of} | {hist_uf_pct:.6f}/{hist_of_pct:.6f} | {hist_drops} | "
            f"{selector_hp}/{selector_rb}/{selector_emit}/{selector_drops} | "
            f"{mts_deltas[0]}/{mts_deltas[1]} | {rate_text(mts_deltas[0], window_s)}/{rate_text(mts_deltas[1], window_s)} | "
            f"{rbcam_inerr}/{rbcam_push}/{rbcam_pop} | "
            f"{rate_text(rbcam_push, window_s)}/{rate_text(rbcam_pop, window_s)} | "
            f"{rbcam_overwrite}/{rbcam_miss} | "
            f"{source_real_in}/{source_emu_in} | {source_real_out}/{source_emu_out} | "
            f"{source_real_drop}/{source_emu_drop} | {window_s:.3f} | `{Path(row['csv']).name}` |"
        )
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--link", type=int, default=int(os.environ.get("BOARD_TEST_LINK", "2")))
    parser.add_argument("--device", default=os.environ.get("BOARD_TEST_DEVICE", "/dev/mudaq0"))
    parser.add_argument("--feb", type=int, default=7)
    parser.add_argument("--address-feb", type=int, default=int(os.environ.get("BOARD_TEST_ADDRESS_FEB", "2")))
    parser.add_argument("--run-number-base", type=int, default=66000)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--rc-tool", type=Path, default=default_rc_tool())
    parser.add_argument(
        "--control-transport",
        choices=("swb", "jtag"),
        default=os.environ.get("BOARD_TEST_CONTROL_TRANSPORT", "swb"),
        help="Use SWB sc_tool/rc_tool or FEB-local JTAG for run-control and counter snapshots.",
    )
    parser.add_argument("--system-console", type=Path, default=default_system_console())
    parser.add_argument("--project-dir", type=Path, default=BOARD_PROJECT_DIR)
    parser.add_argument("--jdi", type=Path, default=default_jdi())
    parser.add_argument("--date", default=dt.datetime.now().strftime("%Y%m%d"))
    parser.add_argument("--active-lane", type=int, default=0)
    parser.add_argument("--lvds-lane-go-mask", type=lambda value: int(value, 0), default=0x000001FF)
    parser.add_argument("--source-mode", choices=tuple(SOURCE_MUX_MODE_WORDS), default="emulator")
    parser.add_argument(
        "--skip-source-mux",
        action="store_true",
        help="Do not touch or sample the legacy byte-source mux; use when the real MuTRiG path is wired directly.",
    )
    parser.add_argument(
        "--hist-snoop-source",
        choices=("pre", "post"),
        default="post",
        help="Select hit-processor ingress or filtered rbCAM egress at the nonblocking histogram snoop selector.",
    )
    parser.add_argument(
        "--hist-profile-override",
        choices=(
            "delay-hit-t-pre",
            "delay-hit-t-post",
            "delay-debug1",
            "delay-debug2",
            "delay-debug3",
        ),
        default=None,
        help="Override the histogram binning profile for the selected snoop source.",
    )
    parser.add_argument(
        "--emulator-trigger-mode",
        choices=("external-injector", "internal-periodic"),
        default="external-injector",
        help="Use the external injector pulse path or the emulator's internal periodic signal trigger.",
    )
    parser.add_argument("--source-label", default="")
    parser.add_argument("--stem-prefix", default="")
    parser.add_argument(
        "--skip-emulator-config",
        action="store_true",
        help="Do not touch emulator CSRs; use this for real-MuTRiG runs.",
    )
    parser.add_argument(
        "--skip-runctl-reset",
        action="store_true",
        help="Do not issue FEB reset/stop-reset in each JTAG setup; use after loading MuTRiG config while IDLE.",
    )
    parser.add_argument("--header-delay", type=int, default=500)
    parser.add_argument("--header-channel", type=int, default=0)
    parser.add_argument("--header-pulse-interval", type=int, default=12500)
    parser.add_argument("--pulse-high", type=int, default=5)
    parser.add_argument("--pre-dump-ms", type=int, default=100)
    parser.add_argument("--post-stop-reset-ms", type=int, default=50)
    parser.add_argument("--rc-settle-us", type=int, default=5000)
    parser.add_argument("--jtag-runctl-delay-ms", type=int, default=50)
    parser.add_argument("--jtag-timeout-s", type=float, default=240.0)
    parser.add_argument("--hist-bin-read-chunk-words", type=int, default=1)
    parser.add_argument("--hist-bin-read-delay-ms", type=int, default=1)
    parser.add_argument("--only-group", choices=("all", "rate", "header_multiplicity"), default="all")
    args = parser.parse_args()

    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    if not args.source_label:
        args.source_label = {"real": "Real MuTRiG", "emulator": "Emulator", "rr": "RR Mix"}[args.source_mode]
    if not args.stem_prefix:
        source_slug = re.sub(r"[^a-z0-9]+", "_", args.source_label.lower()).strip("_") or args.source_mode
        snoop_slug = "pre_rbcam" if args.hist_snoop_source == "pre" else "post_rbcam"
        args.stem_prefix = f"phase6_{source_slug}_asic{args.active_lane}_{snoop_slug}"
    cases = build_cases(args.date, args.stem_prefix)
    if args.only_group != "all":
        cases = [case for case in cases if case["group"] == args.only_group]

    rows = []
    try:
        for idx, case in enumerate(cases):
            print(f"CASE_BEGIN {case['group']} {case['label']} run={args.run_number_base + idx}")
            rows.append(run_case(args, case, args.run_number_base + idx))
            print(f"CASE_DONE {case['group']} {case['label']} hits={rows[-1]['histogram']['total']}")
    finally:
        try:
            if args.control_transport == "jtag":
                cleanup_case = {
                    "mode": 0,
                    "pulse_interval": args.header_pulse_interval,
                    "multiplicity": 1,
                    "stem": f"{args.stem_prefix}_cleanup_{args.date}",
                }
                run_jtag_case(
                    args,
                    "teardown",
                    cleanup_case,
                    args.run_number_base + len(rows),
                    REPORT_DIR / f"{args.stem_prefix}_cleanup_{args.date}.teardown_jtag.log",
                )
            else:
                stop_injector(args.sc_tool, args.device, args.link)
                rc_send(args.rc_tool, args.device, args.feb, "end-run", settle_us=args.rc_settle_us)
        except Exception:
            pass

    report_path = REPORT_DIR / f"{args.stem_prefix}_groups_runtime_mux_{args.date}.md"
    write_report(report_path, rows, args)
    print(report_path)
    return 0 if all(row["histogram"]["total"] > 0 for row in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
