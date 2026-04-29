#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import os
import re
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Callable


SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent
SYSTEM_DIR = BOARD_TEST_DIR
FIRMWARE_BUILDS_DIR = SYSTEM_DIR.parent.parent
REPO_ROOT = FIRMWARE_BUILDS_DIR.parent

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import _default_sc_tool  # noqa: E402
from check_run_control import default_rc_tool  # noqa: E402


EMU_BASE_WORD = 0x08800
EMU_STRIDE_WORD = 0x10
SOURCE_MUX_BASE_WORD = 0x08890
SOURCE_MUX_STRIDE_WORD = 0x10
SOURCE_MUX_UID = 0x4D4C534D
SOURCE_MUX_REG_UID = 0
SOURCE_MUX_REG_CONTROL = 2
SOURCE_MUX_REG_STATUS = 3
SOURCE_MUX_REG_REAL_BEATS = 4
SOURCE_MUX_REG_EMU_BEATS = 5
SOURCE_MUX_REG_SELECTED_BEATS = 6
SOURCE_MUX_REG_SWITCH_COUNT = 7
SOURCE_MUX_REG_LAST_SELECTED = 8
SOURCE_MUX_CONTROL_SELECT_EMULATOR = 0x1
SOURCE_MUX_CONTROL_CLEAR_COUNTERS = 0x2
LVDS_CSR_BASE_WORD = 0x08000
LVDS_LANE_GO_MASK = 0x000001FF
HIST_BIN_BASE_WORD = 0x0A800
HIST_CSR_BASE_WORD = 0x0A900
HIST_INGRESS_BASE_WORD = 0x0AB00
DEFAULT_SWEEP_RATES = "0x0100,0x0200,0x0400,0x0800,0x1000,0x2000,0x4000,0x8000"
HIST_KEY_LOC_CHANNEL_POST = (38 << 24) | (35 << 16) | (21 << 8) | 17


def default_output() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d")
    return BOARD_TEST_DIR / "reports" / f"phase4_emulator_{stamp}_pipe.md"


def run_cmd(cmd: list[str]) -> subprocess.CompletedProcess[str]:
    timeout_s = float(os.environ.get("BOARD_TEST_CMD_TIMEOUT_S", "10"))
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout_s)
    except subprocess.TimeoutExpired as exc:
        stdout = exc.stdout if isinstance(exc.stdout, str) else (exc.stdout or b"").decode(errors="replace")
        stderr = exc.stderr if isinstance(exc.stderr, str) else (exc.stderr or b"").decode(errors="replace")
        stderr += f"\ncommand timed out after {timeout_s:.1f}s\n"
        return subprocess.CompletedProcess(cmd, 124, stdout, stderr)


def checked_cmd(cmd: list[str], attempts: int = 3, retry_delay_s: float = 0.05) -> str:
    last_text = ""
    for attempt in range(attempts):
        proc = run_cmd(cmd)
        last_text = proc.stdout + proc.stderr
        if proc.returncode == 0:
            return last_text
        if (
            attempt + 1 < attempts
            and proc.returncode == 2
            and "SC secondary did not report ready after reset" in last_text
        ):
            time.sleep(retry_delay_s)
            continue
        break

    if proc.returncode != 0:
        raise RuntimeError(
            f"command failed rc={proc.returncode}: {' '.join(cmd)}\n{proc.stdout}{proc.stderr}"
        )
    return last_text


def sc_cmd_with_enable_mask(cmd: list[str], *, quiet: bool) -> list[str]:
    argv = [*cmd]
    if quiet:
        argv.append("--quiet")
    if os.environ.get("BOARD_TEST_SC_NO_RESET", "").strip().lower() in {"1", "true", "yes", "on"}:
        argv.append("--no-reset")
    reply_timeout_ms = os.environ.get("BOARD_TEST_SC_REPLY_TIMEOUT_MS", "").strip()
    if reply_timeout_ms:
        argv.extend(["--reply-timeout-ms", reply_timeout_ms])
    argv.extend(sc_enable_mask_args())
    return argv


def sc_attempt(cmd: list[str], attempts: int = 3, retry_delay_s: float = 0.05) -> tuple[subprocess.CompletedProcess[str], str]:
    last_proc: subprocess.CompletedProcess[str] | None = None
    last_text = ""
    pipelined_retry = os.environ.get("BOARD_TEST_SC_PIPELINED_RETRY", "").strip().lower() in {"1", "true", "yes", "on"}
    for attempt in range(attempts):
        proc = run_cmd(cmd)
        text = proc.stdout + proc.stderr
        last_proc = proc
        last_text = text
        if proc.returncode == 0:
            return proc, text
        retry_secondary_reset = proc.returncode == 2 and "SC secondary did not report ready after reset" in text
        if attempt + 1 < attempts and (retry_secondary_reset or pipelined_retry):
            time.sleep(retry_delay_s)
            continue
        break
    assert last_proc is not None
    return last_proc, last_text


def parse_payload(text: str) -> list[int]:
    return [int(match.group(2), 16) for match in re.finditer(r"payload\[(\d+)\]\s*=\s*(0x[0-9A-Fa-f]+)", text)]


def sc_rsp_has_bus_error(text: str) -> bool:
    return bool(re.search(r"rsp\s*:\s*(SLVERR|DECERR)", text))


def sc_verbose_first() -> bool:
    return os.environ.get("BOARD_TEST_SC_VERBOSE_FIRST", "").strip().lower() in {"1", "true", "yes", "on"}


def sc_transaction(cmd: list[str], expect_payload: int | None = None) -> str:
    attempts = (False, True) if sc_verbose_first() else (True, False)
    results: list[tuple[str, subprocess.CompletedProcess[str], str]] = []
    for quiet in attempts:
        label = "quiet" if quiet else "verbose"
        argv = sc_cmd_with_enable_mask(cmd, quiet=quiet)
        proc, text = sc_attempt(argv)
        results.append((label, proc, text))
        words = parse_payload(text)
        ok = proc.returncode == 0 and not sc_rsp_has_bus_error(text)
        if expect_payload is not None:
            ok = ok and len(words) == expect_payload
        if ok:
            return text

    details = []
    for label, proc, text in results:
        argv = sc_cmd_with_enable_mask(cmd, quiet=(label == "quiet"))
        details.append(f"{label} rc={proc.returncode}: {' '.join(argv)}\n{text}")
    raise RuntimeError("SC transaction failed after quiet/verbose attempts\n" + "\n".join(details))


def sc_enable_mask_args() -> list[str]:
    value = os.environ.get("BOARD_TEST_SC_ENABLE_MASK", "").strip()
    return ["--enable-mask", value] if value else []


def sc_read(sc_tool: Path, link: int, addr: int, count: int = 1) -> list[int]:
    argv = [str(sc_tool), str(link), "read", f"0x{addr:05X}", str(count)]
    out = sc_transaction(argv, expect_payload=count)
    words = parse_payload(out)
    if len(words) != count:
        raise RuntimeError(f"SC read 0x{addr:05X} count={count} returned {len(words)} words\n{out}")
    return words


def sc_write(sc_tool: Path, link: int, addr: int, words: list[int]) -> None:
    argv = [str(sc_tool), str(link), "write", f"0x{addr:05X}", *[f"0x{word & 0xFFFFFFFF:08X}" for word in words]]
    out = sc_transaction(argv)
    if sc_rsp_has_bus_error(out):
        raise RuntimeError(f"SC write 0x{addr:05X} got bus error\n{out}")


def rc_send(
    rc_tool: Path,
    device: str,
    feb: int,
    name: str,
    run_number: int | None = None,
    settle_us: int = 5000,
) -> str:
    argv = [str(rc_tool), "send", name, "--device", device, "--feb", str(feb), "--settle-us", str(settle_us)]
    if run_number is not None:
        argv.extend(["--run", str(run_number)])
    return checked_cmd(argv)


def emu_base(idx: int) -> int:
    return EMU_BASE_WORD + idx * EMU_STRIDE_WORD


def source_mux_base(idx: int) -> int:
    return SOURCE_MUX_BASE_WORD + idx * SOURCE_MUX_STRIDE_WORD


def decode_emu_status(word: int) -> dict[str, int]:
    return {
        "raw": word,
        "frame_count": word & 0xFFFF,
        "event_count": (word >> 16) & 0x03FF,
    }


def decode_source_mux_status(word: int) -> dict[str, int]:
    return {
        "raw": word,
        "select_emulator": word & 0x1,
        "real_valid": (word >> 1) & 0x1,
        "emu_valid": (word >> 2) & 0x1,
        "selected_valid": (word >> 3) & 0x1,
        "selected_channel": (word >> 4) & 0xF,
        "selected_error": (word >> 8) & 0x7,
        "real_channel": (word >> 11) & 0xF,
        "real_error": (word >> 15) & 0x7,
        "emu_channel": (word >> 18) & 0xF,
        "emu_error": (word >> 22) & 0x7,
        "both_valid": (word >> 25) & 0x1,
    }


def decode_source_mux_last_selected(word: int) -> dict[str, int]:
    return {
        "raw": word,
        "data": word & 0x1FF,
        "channel": (word >> 9) & 0xF,
        "error": (word >> 13) & 0x7,
        "source_emulator": (word >> 16) & 0x1,
    }


def read_lane_source_mux(sc_tool: Path, link: int, idx: int) -> dict[str, Any]:
    base = source_mux_base(idx)
    words = sc_read(sc_tool, link, base, SOURCE_MUX_REG_LAST_SELECTED + 1)
    status = decode_source_mux_status(words[SOURCE_MUX_REG_STATUS])
    last_selected = decode_source_mux_last_selected(words[SOURCE_MUX_REG_LAST_SELECTED])
    return {
        "idx": idx,
        "base": base,
        "uid": words[SOURCE_MUX_REG_UID],
        "control": words[SOURCE_MUX_REG_CONTROL],
        "status": status,
        "real_beats": words[SOURCE_MUX_REG_REAL_BEATS],
        "emu_beats": words[SOURCE_MUX_REG_EMU_BEATS],
        "selected_beats": words[SOURCE_MUX_REG_SELECTED_BEATS],
        "switch_count": words[SOURCE_MUX_REG_SWITCH_COUNT],
        "last_selected": last_selected,
    }


def read_lane_source_muxes(sc_tool: Path, link: int) -> list[dict[str, Any]]:
    return [read_lane_source_mux(sc_tool, link, idx) for idx in range(8)]


def select_lane_sources(
    sc_tool: Path,
    link: int,
    emulator_mask: int,
    clear_counters: bool = False,
) -> list[dict[str, Any]]:
    if emulator_mask < 0 or emulator_mask > 0xFF:
        raise ValueError(f"invalid source emulator mask 0x{emulator_mask:X}; expected 0x00..0xff")

    rows = []
    for idx in range(8):
        base = source_mux_base(idx)
        uid = sc_read(sc_tool, link, base + SOURCE_MUX_REG_UID)[0]
        if uid != SOURCE_MUX_UID:
            raise RuntimeError(
                f"mutrig_lane_source_mux_{idx} UID mismatch at 0x{base:05X}: "
                f"got 0x{uid:08X}, expected 0x{SOURCE_MUX_UID:08X}"
            )
        control = SOURCE_MUX_CONTROL_SELECT_EMULATOR if (emulator_mask & (1 << idx)) else 0
        if clear_counters:
            control |= SOURCE_MUX_CONTROL_CLEAR_COUNTERS
        sc_write(sc_tool, link, base + SOURCE_MUX_REG_CONTROL, [control])
        rows.append(read_lane_source_mux(sc_tool, link, idx))
    return rows


def hist_snapshot(sc_tool: Path, link: int) -> dict[str, int]:
    regs = sc_read(sc_tool, link, HIST_CSR_BASE_WORD + 8, 8)
    return {
        "UNDERFLOW_COUNT": regs[0],
        "OVERFLOW_COUNT": regs[1],
        "INTERVAL_CFG": regs[2],
        "BANK_STATUS": regs[3],
        "PORT_STATUS": regs[4],
        "TOTAL_HITS": regs[5],
        "DROPPED_HITS": regs[6],
        "COAL_STATUS": regs[7],
    }


def configure_histogram(sc_tool: Path, link: int) -> None:
    # Keep the live interval from resetting counters during short host polls.
    sc_write(sc_tool, link, HIST_CSR_BASE_WORD + 3, [0x00000000])  # LEFT_BOUND
    sc_write(sc_tool, link, HIST_CSR_BASE_WORD + 4, [0x000000FF])  # RIGHT_BOUND, recomputed on apply when BIN_WIDTH != 0
    sc_write(sc_tool, link, HIST_CSR_BASE_WORD + 5, [0x00000001])  # BIN_WIDTH=1 maps channel IDs directly
    sc_write(sc_tool, link, HIST_CSR_BASE_WORD + 6, [HIST_KEY_LOC_CHANNEL_POST])  # UPDATE_KEY=post hit channel[21:17]
    sc_write(sc_tool, link, HIST_CSR_BASE_WORD + 10, [0x3FFFFFFF])  # INTERVAL_CFG
    sc_write(sc_tool, link, HIST_CSR_BASE_WORD + 2, [0x00000101])  # apply + unsigned key
    for _ in range(20):
        control = sc_read(sc_tool, link, HIST_CSR_BASE_WORD + 2)[0]
        if (control & 0x2) == 0:
            return
        time.sleep(0.01)
    raise RuntimeError("histogram config apply did not clear apply_pending")


def clear_histogram(sc_tool: Path, link: int) -> None:
    sc_write(sc_tool, link, HIST_BIN_BASE_WORD, [0])
    time.sleep(0.05)


def decode_histogram_ingress_status(word: int) -> dict[str, int]:
    return {
        "raw": word,
        "live_select_post": word & 0x1,
        "requested_select_post": (word >> 1) & 0x1,
        "switch_pending": (word >> 2) & 0x1,
        "pre_packet_active": (word >> 8) & 0x1,
        "post_packet_active": (word >> 9) & 0x1,
        "post_hit_filter_enabled": (word >> 10) & 0x1,
        "post_hit_region": (word >> 11) & 0x1,
    }


def select_histogram_ingress_post(sc_tool: Path, link: int) -> dict[str, int]:
    sc_write(sc_tool, link, HIST_INGRESS_BASE_WORD + 2, [0x00000001])
    last_status = 0
    for _ in range(50):
        last_status = sc_read(sc_tool, link, HIST_INGRESS_BASE_WORD + 3)[0]
        decoded = decode_histogram_ingress_status(last_status)
        if (
            decoded["live_select_post"] == 1
            and decoded["requested_select_post"] == 1
            and decoded["switch_pending"] == 0
        ):
            return decoded
        time.sleep(0.01)
    decoded = decode_histogram_ingress_status(last_status)
    raise RuntimeError(
        "histogram ingress bridge did not switch to post stream: "
        f"status=0x{last_status:08X} decoded={decoded}"
    )


def configure_emulators(sc_tool: Path, link: int, hit_rate: int) -> None:
    for idx in range(8):
        base = emu_base(idx)
        sc_write(sc_tool, link, base + 0, [0x00000000])  # hold disabled while programming rate/seed/mode
        sc_write(sc_tool, link, base + 1, [hit_rate & 0xFFFF])  # noise=0, hit_rate=8.8 fixed point
        sc_write(sc_tool, link, base + 3, [0xDEADBEEF ^ idx])
        sc_write(sc_tool, link, base + 4, [0x00000008 | (idx << 4)])  # gen_idle=1, unique ASIC id
        sc_write(sc_tool, link, base + 6, [0xFFFFFFFF])
        sc_write(sc_tool, link, base + 0, [0x00000001])  # enable, poisson, long mode


def configure_lvds_lanes(sc_tool: Path, link: int, lane_mask: int = LVDS_LANE_GO_MASK) -> int:
    if lane_mask < 0 or lane_mask > LVDS_LANE_GO_MASK:
        raise ValueError(f"invalid LVDS lane mask 0x{lane_mask:X}; expected 0x0..0x{LVDS_LANE_GO_MASK:X}")
    sc_write(sc_tool, link, LVDS_CSR_BASE_WORD + 4, [lane_mask])
    return sc_read(sc_tool, link, LVDS_CSR_BASE_WORD + 4)[0]


def read_emulator_statuses(sc_tool: Path, link: int) -> list[dict[str, int]]:
    return [decode_emu_status(sc_read(sc_tool, link, emu_base(idx) + 5)[0]) for idx in range(8)]


def run_to_running(
    rc_tool: Path,
    device: str,
    feb: int,
    run_number: int,
    settle_us: int,
    post_stop_reset_s: float,
    after_stop_reset: Callable[[], None] | None = None,
) -> list[str]:
    logs = []
    for name, run in (("reset", None), ("stop-reset", None)):
        logs.append(rc_send(rc_tool, device, feb, name, run, settle_us=settle_us))
        if name == "stop-reset" and post_stop_reset_s > 0:
            time.sleep(post_stop_reset_s)
    if after_stop_reset is not None:
        after_stop_reset()
    for name, run in (("run-prepare", run_number), ("sync", None), ("start-run", None)):
        logs.append(rc_send(rc_tool, device, feb, name, run, settle_us=settle_us))
    return logs


def run_measurement(args: argparse.Namespace, hit_rate: int, duration_s: float, label: str) -> dict[str, Any]:
    ingress_status: dict[str, int] = {}
    source_mux_rows: list[dict[str, Any]] = []
    lane_go = 0
    quiet_emu_a: list[dict[str, int]] | None = None
    quiet_hist_a: dict[str, int] | None = None

    def configure_after_reset_release() -> None:
        nonlocal ingress_status, source_mux_rows, lane_go, quiet_emu_a, quiet_hist_a
        lane_go = configure_lvds_lanes(args.sc_tool, args.link)
        source_mux_rows = select_lane_sources(args.sc_tool, args.link, 0xFF, clear_counters=True)
        configure_histogram(args.sc_tool, args.link)
        clear_histogram(args.sc_tool, args.link)
        ingress_status = select_histogram_ingress_post(args.sc_tool, args.link)
        if args.measure_after_end:
            quiet_emu_a = read_emulator_statuses(args.sc_tool, args.link)
            quiet_hist_a = hist_snapshot(args.sc_tool, args.link)
        configure_emulators(args.sc_tool, args.link, hit_rate)

    rc_logs = run_to_running(
        args.rc_tool,
        args.device,
        args.feb,
        args.run_number,
        args.rc_settle_us,
        max(args.post_stop_reset_ms, 0) / 1000.0,
        after_stop_reset=configure_after_reset_release,
    )
    if args.pre_sample_ms > 0:
        time.sleep(args.pre_sample_ms / 1000.0)
    if args.measure_after_end:
        time.sleep(duration_s)
        emu_a = quiet_emu_a if quiet_emu_a is not None else read_emulator_statuses(args.sc_tool, args.link)
        hist_a = quiet_hist_a if quiet_hist_a is not None else hist_snapshot(args.sc_tool, args.link)
        emu_b = read_emulator_statuses(args.sc_tool, args.link)
        hist_b = hist_snapshot(args.sc_tool, args.link)
        rc_send(args.rc_tool, args.device, args.feb, "end-run", settle_us=args.rc_settle_us)
        if args.post_end_ms > 0:
            time.sleep(args.post_end_ms / 1000.0)
        hist_post_end = hist_snapshot(args.sc_tool, args.link)
    else:
        time.sleep(duration_s)
        emu_a = read_emulator_statuses(args.sc_tool, args.link)
        hist_a = hist_snapshot(args.sc_tool, args.link)
        time.sleep(duration_s)
        emu_b = read_emulator_statuses(args.sc_tool, args.link)
        hist_b = hist_snapshot(args.sc_tool, args.link)
        rc_send(args.rc_tool, args.device, args.feb, "end-run", settle_us=args.rc_settle_us)
        hist_post_end = None

    emu_rows = []
    for idx, (before, after) in enumerate(zip(emu_a, emu_b)):
        frame_delta = (after["frame_count"] - before["frame_count"]) & 0xFFFF
        emu_rows.append(
            {
                "idx": idx,
                "before": before,
                "after": after,
                "frame_delta": frame_delta,
                "pass": frame_delta > 0,
            }
        )
    total_delta = (hist_b["TOTAL_HITS"] - hist_a["TOTAL_HITS"]) & 0xFFFFFFFF
    dropped_delta = (hist_b["DROPPED_HITS"] - hist_a["DROPPED_HITS"]) & 0xFFFFFFFF
    post_end_clean = True
    if hist_post_end is not None:
        post_end_clean = (
            (hist_post_end["PORT_STATUS"] & 0xFF) == 0xFF
            and (hist_post_end["COAL_STATUS"] & 0xFF) == 0
        )
    return {
        "label": label,
        "hit_rate": hit_rate,
        "duration_s": duration_s,
        "rc_logs": rc_logs,
        "emu_a": emu_a,
        "emu_b": emu_b,
        "emu_rows": emu_rows,
        "hist_a": hist_a,
        "hist_b": hist_b,
        "hist_post_end": hist_post_end,
        "ingress_status": ingress_status,
        "source_mux_rows": source_mux_rows,
        "lane_go": lane_go,
        "total_delta": total_delta,
        "dropped_delta": dropped_delta,
        "post_end_clean": post_end_clean,
        "pass": all(row["pass"] for row in emu_rows) and total_delta > 0 and dropped_delta == 0 and post_end_clean,
    }


def fmt_hex(value: int) -> str:
    return f"0x{value:08X}"


def parse_sweep_rates(text: str) -> list[int]:
    rates: list[int] = []
    for item in text.split(","):
        item = item.strip()
        if not item:
            continue
        rate = int(item, 0)
        if rate <= 0 or rate > 0xFFFF:
            raise ValueError(f"invalid hit rate {item!r}; expected 1..0xffff")
        rates.append(rate)
    if not rates:
        raise ValueError("at least one rate-sweep point is required")
    return rates


def rate_per_second(item: dict[str, Any]) -> float:
    if item["duration_s"] <= 0:
        return 0.0
    return item["total_delta"] / item["duration_s"]


def find_sweep_knee(sweep: list[dict[str, Any]], ratio_tolerance: float) -> int | None:
    dropped_knee = next((idx for idx, item in enumerate(sweep) if item["dropped_delta"] > 0), None)
    ratio_knee: int | None = None
    for idx, (prev, curr) in enumerate(zip(sweep, sweep[1:]), start=1):
        if prev["total_delta"] <= 0 or curr["total_delta"] <= 0:
            continue
        expected = curr["hit_rate"] / prev["hit_rate"]
        observed = curr["total_delta"] / prev["total_delta"]
        lo = expected * (1.0 - ratio_tolerance)
        if observed < lo:
            ratio_knee = idx
            break
    knees = [idx for idx in (dropped_knee, ratio_knee) if idx is not None]
    return min(knees) if knees else None


def collect_failures(primary: dict[str, Any], sweep: list[dict[str, Any]], ratio_tolerance: float) -> list[str]:
    failures = []
    if not primary["pass"]:
        failures.append("primary 8-lane emulator/histogram measurement")
    knee_index = find_sweep_knee(sweep, ratio_tolerance)
    for idx, item in enumerate(sweep):
        if item["total_delta"] <= 0:
            failures.append(f"rate point {item['label']}")
        if not item.get("post_end_clean", True):
            failures.append(f"rate point {item['label']} left histogram FIFO/queue residue after END_RUN")
    for idx, (prev, curr) in enumerate(zip(sweep, sweep[1:]), start=1):
        if knee_index is not None and idx >= knee_index:
            continue
        if prev["total_delta"] <= 0 or curr["total_delta"] <= 0:
            failures.append(f"rate ratio {prev['label']}->{curr['label']} has zero hit delta")
            continue
        expected = curr["hit_rate"] / prev["hit_rate"]
        observed = curr["total_delta"] / prev["total_delta"]
        lo = expected * (1.0 - ratio_tolerance)
        hi = expected * (1.0 + ratio_tolerance)
        if observed > hi:
            failures.append(
                f"rate ratio {prev['label']}->{curr['label']} = {observed:.3f}, "
                f"expected {expected:.3f} +/- {ratio_tolerance:.0%}"
            )
    return failures


def write_report(path: Path, timestamp: str, args: argparse.Namespace, primary: dict[str, Any], sweep: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    failures = collect_failures(primary, sweep, args.ratio_tolerance)
    knee_index = find_sweep_knee(sweep, args.ratio_tolerance)

    lines = [
        "# Phase 4 Emulator/Histogram Report",
        "",
        f"- Timestamp: `{timestamp}`",
        f"- SC link: `{args.link}`",
        f"- Device: `{args.device}`",
        f"- FEB target: `{args.feb}`",
        f"- SC tool: `{args.sc_tool}`",
        f"- RC tool: `{args.rc_tool}`",
        f"- Result: `{'PASS' if not failures else 'FAIL'}`",
        "",
        "## Primary 8-Lane Run",
        "",
        f"- Hit rate: `0x{primary['hit_rate']:04X}`",
        f"- Sample spacing: `{primary['duration_s']:.3f} s`",
        f"- Measurement mode: `{'live terminal sample plus post-end flush check' if args.measure_after_end else 'live readback'}`",
        f"- Histogram TOTAL_HITS delta: `{primary['total_delta']}`",
        f"- Histogram DROPPED_HITS delta: `{primary['dropped_delta']}`",
        f"- Post-end histogram FIFO/queue empty: `{'yes' if primary.get('post_end_clean', True) else 'no'}`",
        f"- LVDS lane-go after reset release: `{fmt_hex(primary['lane_go'])}`",
        "- MuTRiG lane source mux: `emulator` selected for lanes 0..7",
        f"- Histogram ingress source: `post`",
        f"- Histogram ingress status after reset release: `{fmt_hex(primary['ingress_status'].get('raw', 0))}`",
        f"- Histogram binning: `LEFT_BOUND=0`, `BIN_WIDTH=1`, `RIGHT_BOUND=256 derived`",
        "",
        "| Lane | Frame Count A | Frame Count B | Delta | Event Count B | Result |",
        "|---:|---:|---:|---:|---:|---|",
    ]
    for row in primary["emu_rows"]:
        lines.append(
            f"| {row['idx']} | {row['before']['frame_count']} | {row['after']['frame_count']} | "
            f"{row['frame_delta']} | {row['after']['event_count']} | {'PASS' if row['pass'] else 'FAIL'} |"
        )
    lines.extend(
        [
            "",
            "| Lane | Source Mux Base | Source | Real Beats | Emu Beats | Selected Beats |",
            "|---:|---:|---|---:|---:|---:|",
        ]
    )
    for row in primary.get("source_mux_rows", []):
        source = "emulator" if (row["control"] & SOURCE_MUX_CONTROL_SELECT_EMULATOR) else "real"
        lines.append(
            f"| {row['idx']} | `{fmt_hex(row['base'])}` | `{source}` | "
            f"{row['real_beats']} | {row['emu_beats']} | {row['selected_beats']} |"
        )
    lines.extend(
        [
            "",
            "## Histogram Snapshot",
            "",
            "| Register | Before | Sample | Post-End |",
            "|---|---:|---:|---:|",
        ]
    )
    post_end = primary.get("hist_post_end")
    for key in primary["hist_a"]:
        post_end_text = fmt_hex(post_end[key]) if post_end is not None else "-"
        lines.append(
            f"| `{key}` | `{fmt_hex(primary['hist_a'][key])}` | "
            f"`{fmt_hex(primary['hist_b'][key])}` | `{post_end_text}` |"
        )

    if sweep:
        lines.extend(
            [
                "",
                "## Rate Sweep",
                "",
                f"- Ratio tolerance: `{args.ratio_tolerance:.0%}`",
                "",
                "| Label | Hit Rate | TOTAL Delta | Rate/s | DROPPED Delta | Ratio vs Prev | Result |",
                "|---|---:|---:|---:|---:|---:|---|",
            ]
        )
        prev: dict[str, Any] | None = None
        for item in sweep:
            ratio = ""
            if prev is not None and prev["total_delta"] > 0:
                ratio = f"{item['total_delta'] / prev['total_delta']:.3f}"
            idx = sweep.index(item)
            if item["total_delta"] <= 0:
                result = "FAIL"
            elif knee_index is not None and idx == knee_index:
                result = "KNEE"
            elif knee_index is not None and idx > knee_index:
                result = "CLIPPED"
            else:
                result = "PASS"
            lines.append(
                f"| `{item['label']}` | `0x{item['hit_rate']:04X}` | "
                f"{item['total_delta']} | {rate_per_second(item):.0f} | {item['dropped_delta']} | "
                f"{ratio or '-'} | "
                f"{result} |"
            )
            prev = item
        if knee_index is not None:
            knee = sweep[knee_index]
            lines.extend(
                [
                    "",
                    f"- Saturation knee: `{knee['label']}` / `0x{knee['hit_rate']:04X}` "
                    f"(`DROPPED_HITS` delta {knee['dropped_delta']}, "
                    f"throughput {rate_per_second(knee):.0f} hits/s).",
                ]
            )

    lines.extend(
        [
            "",
            "## Notes",
            "",
            "- This report covers TEST_PLAN Phase 4.2 and the histogram side of Phase 4.4 through SC-visible counters.",
            "- LVDS lane-go, emulator CSRs, histogram binning, and the histogram ingress bridge are configured after `stop-reset` and before `run-prepare`, so run-control reset cannot wipe the requested run settings.",
            "- The rate sweep compares per-run `TOTAL_HITS` deltas before `END_RUN`; with `--measure-after-end`, the post-TERMINATING readback is used to check FIFO/queue residue after the flush window.",
            "- The current emulator RTL uses INJECT_MASK only for the masked-trigger conduit, not for background Poisson traffic; the Phase 4.5 channel-mask sweep therefore needs a masked-pulse source or a future CSR/conduit driver before it can be run literally from host software.",
            "- SignalTap Phase 4.3 was not compiled in this nostp image; no stuck interface was observed in this functional pass.",
        ]
    )
    if failures:
        lines.extend(["", "## Failures", ""])
        lines.extend(f"- {item}" for item in failures)
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Phase 4 emulator/histogram functional checks over SC.")
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--device", default="/dev/mudaq0")
    parser.add_argument("--feb", type=int, default=7)
    parser.add_argument("--run-number", type=int, default=4242)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--rc-tool", type=Path, default=default_rc_tool())
    parser.add_argument("--duration-ms", type=int, default=500)
    parser.add_argument("--sweep-duration-ms", type=int, default=300)
    parser.add_argument("--sweep-rates", default=DEFAULT_SWEEP_RATES)
    parser.add_argument("--ratio-tolerance", type=float, default=0.35)
    parser.add_argument("--rc-settle-us", type=int, default=5000)
    parser.add_argument("--post-stop-reset-ms", type=int, default=0)
    parser.add_argument("--pre-sample-ms", type=int, default=0)
    parser.add_argument("--post-end-ms", type=int, default=50)
    parser.add_argument(
        "--measure-after-end",
        action="store_true",
        help="Stop the run before reading counters; useful when sustained event traffic competes with SC replies.",
    )
    parser.add_argument("--skip-rate-sweep", action="store_true")
    parser.add_argument("--output", type=Path, default=default_output())
    args = parser.parse_args()

    timestamp = dt.datetime.now().isoformat(timespec="seconds")
    primary = run_measurement(args, 0x0800, args.duration_ms / 1000.0, "primary")

    sweep: list[dict[str, Any]] = []
    if not args.skip_rate_sweep:
        for rate in parse_sweep_rates(args.sweep_rates):
            label = f"r{rate:04x}"
            sweep.append(run_measurement(args, rate, args.sweep_duration_ms / 1000.0, label))

    write_report(args.output, timestamp, args, primary, sweep)
    failures = len(collect_failures(primary, sweep, args.ratio_tolerance))
    print(f"Wrote {args.output}")
    print(f"RESULT {'PASS' if failures == 0 else 'FAIL'} failures={failures}")
    return 0 if failures == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
