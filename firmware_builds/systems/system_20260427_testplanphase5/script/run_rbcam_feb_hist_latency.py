#!/usr/bin/env python3
"""Run FEB on-board rbCAM/FEB latency histogram captures.

The script assumes the pipe FEB image is already programmed. It drives the
generated 26.3 emulator/mux CSR map after stop-reset, starts the run through
rc_tool, captures the on-chip histogram through System Console/JTAG, and writes
a manifest consumed by plot_board_hist_latency.py.
"""

from __future__ import annotations

import argparse
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
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import (  # noqa: E402
    _default_jdi,
    _default_project_dir,
    _default_sc_tool,
    _default_system_console,
    sc_read,
    sc_write,
)
from check_run_control import default_rc_tool  # noqa: E402


EMU_BASE_WORD = 0x08800
EMU_STRIDE_WORD = 0x10
MUX_BASE_WORD = 0x08890
MUX_STRIDE_WORD = 0x10
LVDS_CSR_BASE_WORD = 0x08000
LVDS_LANE_GO_MASK = 0x000001FF
HIST_INGRESS_BASE_WORD = 0x0AB00

EMU_UID = 0x454D5554
MUX_UID = 0x4D4C534D
HIST_INGRESS_UID = 0x48495342

EMU_REG_UID = 0x00
EMU_REG_CENTRAL = 0x07
EMU_REG_SIGNAL = 0x08
EMU_REG_BACKGROUND = 0x09
EMU_REG_FORMAT = 0x0A
EMU_REG_RATES = 0x0B
EMU_REG_CLUSTER_FIX = 0x0C
EMU_REG_PRNG_SEED = 0x0E
EMU_REG_TIMEBASE_SEED = 0x0F

MUX_REG_UID = 0x00
MUX_REG_CONTROL = 0x02
MUX_REG_STATUS = 0x03
MUX_CONTROL_SELECT_EMULATOR = 0x1
MUX_CONTROL_CLEAR_COUNTERS = 0x2

HISB_REG_UID = 0x00
HISB_REG_CONTROL = 0x02
HISB_REG_STATUS = 0x03

LVDS_REG_LANE_GO = 0x04

HIST_CSR_BASE_BYTE = 0x00020400
HIST_BIN_BASE_BYTE = 0x00020000
HIST_INGRESS_BASE_BYTE = 0x00020C00

RATE_PRESETS = {
    "010k": 5,
    "100k": 52,
    "500k": 262,
    "1000k": 524,
}


def default_output_dir() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    return SCRIPT_DIR.parent / "reports" / f"rbcam_feb_hist_latency_{stamp}"


def run_checked(cmd: list[str], env: dict[str, str] | None = None) -> str:
    proc = subprocess.run(cmd, capture_output=True, text=True, env=env)
    if proc.returncode != 0:
        raise RuntimeError(
            f"command failed rc={proc.returncode}: {' '.join(cmd)}\n"
            f"{proc.stdout}{proc.stderr}"
        )
    return proc.stdout + proc.stderr


def rc_send(args: argparse.Namespace, command: str, run_number: int | None = None) -> str:
    cmd = [
        str(args.rc_tool),
        "send",
        command,
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


def emu_base(lane: int) -> int:
    return EMU_BASE_WORD + lane * EMU_STRIDE_WORD


def mux_base(lane: int) -> int:
    return MUX_BASE_WORD + lane * MUX_STRIDE_WORD


def fmt_hex(value: int, width: int = 8) -> str:
    return f"0x{value & ((1 << (4 * width)) - 1):0{width}X}"


def read_words(sc_tool: Path, link: int, addr: int, count: int) -> list[int]:
    last_error: Exception | None = None
    for attempt in range(6):
        try:
            return sc_read(sc_tool, link, addr, count)
        except Exception as exc:  # SC reply matching can race with stale secondary-ring traffic.
            last_error = exc
            time.sleep(0.05 * (attempt + 1))
    raise RuntimeError(f"SC read failed after retries at {fmt_hex(addr, 5)} count={count}: {last_error}") from last_error


def write_words(sc_tool: Path, link: int, addr: int, words: list[int]) -> None:
    last_error: Exception | None = None
    for attempt in range(6):
        try:
            # The live SC bridge can present the previous write payload on the
            # first transaction after an address change.  Repeating the same
            # burst makes the second transaction the intended value.
            sc_write(sc_tool, link, addr, words)
            sc_write(sc_tool, link, addr, words)
            return
        except Exception as exc:
            last_error = exc
            time.sleep(0.05 * (attempt + 1))
    raise RuntimeError(f"SC write failed after retries at {fmt_hex(addr, 5)}: {last_error}") from last_error


def read_one(sc_tool: Path, link: int, addr: int) -> int:
    return read_words(sc_tool, link, addr, 1)[0]


def expect_uid(sc_tool: Path, link: int, addr: int, expected: int, name: str) -> int:
    observed = read_one(sc_tool, link, addr)
    if observed != expected:
        raise RuntimeError(
            f"{name} UID mismatch at word {fmt_hex(addr, 5)}: "
            f"got {fmt_hex(observed)}, expected {fmt_hex(expected)}"
        )
    return observed


def configure_muxes(sc_tool: Path, link: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for lane in range(8):
        base = mux_base(lane)
        uid = expect_uid(sc_tool, link, base + MUX_REG_UID, MUX_UID, f"mutrig_lane_source_mux_{lane}")
        write_words(sc_tool, link, base + MUX_REG_CONTROL, [MUX_CONTROL_SELECT_EMULATOR | MUX_CONTROL_CLEAR_COUNTERS])
        write_words(sc_tool, link, base + MUX_REG_CONTROL, [MUX_CONTROL_SELECT_EMULATOR])
        status = read_one(sc_tool, link, base + MUX_REG_STATUS)
        rows.append(
            {
                "lane": lane,
                "base_word": fmt_hex(base, 5),
                "uid": fmt_hex(uid),
                "control": fmt_hex(MUX_CONTROL_SELECT_EMULATOR),
                "status": fmt_hex(status),
            }
        )
    return rows


def configure_lvds_lanes(sc_tool: Path, link: int) -> dict[str, Any]:
    write_words(sc_tool, link, LVDS_CSR_BASE_WORD + LVDS_REG_LANE_GO, [LVDS_LANE_GO_MASK])
    observed = read_one(sc_tool, link, LVDS_CSR_BASE_WORD + LVDS_REG_LANE_GO)
    return {
        "base_word": fmt_hex(LVDS_CSR_BASE_WORD, 5),
        "lane_go_addr": fmt_hex(LVDS_CSR_BASE_WORD + LVDS_REG_LANE_GO, 5),
        "requested": fmt_hex(LVDS_LANE_GO_MASK),
        "observed": fmt_hex(observed),
    }


def configure_emulators(sc_tool: Path, link: int, q16_rate: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for lane in range(8):
        base = emu_base(lane)
        uid = expect_uid(sc_tool, link, base + EMU_REG_UID, EMU_UID, f"emulator_mutrig_{lane}")
        write_words(sc_tool, link, base + EMU_REG_CENTRAL, [0x00000000])
        write_words(sc_tool, link, base + EMU_REG_BACKGROUND, [0x00000000])
        write_words(sc_tool, link, base + EMU_REG_SIGNAL, [0x00000002])
        write_words(sc_tool, link, base + EMU_REG_FORMAT, [0x00000023])
        write_words(sc_tool, link, base + EMU_REG_RATES, [q16_rate & 0xFFFF])
        write_words(sc_tool, link, base + EMU_REG_CLUSTER_FIX, [0x00004F80])
        write_words(sc_tool, link, base + EMU_REG_PRNG_SEED, [0xC0DEC000 ^ lane])
        write_words(sc_tool, link, base + EMU_REG_TIMEBASE_SEED, [0x00010001])
        if lane == 0:
            write_words(sc_tool, link, base + EMU_REG_CENTRAL, [0x00000001])
        rows.append(
            {
                "lane": lane,
                "base_word": fmt_hex(base, 5),
                "uid": fmt_hex(uid),
                "enabled": lane == 0,
                "q16_rate": q16_rate if lane == 0 else 0,
                "central": fmt_hex(read_one(sc_tool, link, base + EMU_REG_CENTRAL)),
            }
        )
    return rows


def decode_ingress_status(word: int) -> dict[str, Any]:
    return {
        "raw": fmt_hex(word),
        "live_select_post": word & 0x1,
        "requested_select_post": (word >> 1) & 0x1,
        "switch_pending": (word >> 2) & 0x1,
        "pre_packet_active": (word >> 8) & 0x1,
        "post_packet_active": (word >> 9) & 0x1,
        "post_hit_filter_enabled": (word >> 10) & 0x1,
        "post_hit_region": (word >> 11) & 0x1,
    }


def select_hist_source(sc_tool: Path, link: int, post: bool) -> dict[str, Any]:
    expect_uid(sc_tool, link, HIST_INGRESS_BASE_WORD + HISB_REG_UID, HIST_INGRESS_UID, "histogram_ingress_bridge_0")
    requested = 1 if post else 0
    write_words(sc_tool, link, HIST_INGRESS_BASE_WORD + HISB_REG_CONTROL, [requested])
    last = 0
    for _ in range(200):
        last = read_one(sc_tool, link, HIST_INGRESS_BASE_WORD + HISB_REG_STATUS)
        decoded = decode_ingress_status(last)
        if (
            decoded["live_select_post"] == requested
            and decoded["requested_select_post"] == requested
            and decoded["switch_pending"] == 0
        ):
            decoded["source"] = "post" if post else "pre"
            return decoded
        time.sleep(0.01)
    raise RuntimeError(f"histogram ingress source did not switch to {'post' if post else 'pre'}: {decode_ingress_status(last)}")


def observe_hist_source(sc_tool: Path, link: int) -> dict[str, Any]:
    expect_uid(sc_tool, link, HIST_INGRESS_BASE_WORD + HISB_REG_UID, HIST_INGRESS_UID, "histogram_ingress_bridge_0")
    decoded = decode_ingress_status(read_one(sc_tool, link, HIST_INGRESS_BASE_WORD + HISB_REG_STATUS))
    decoded["source"] = "post" if decoded["live_select_post"] else "pre"
    decoded["observed_only"] = True
    return decoded


def histogram_dump_cmd(args: argparse.Namespace, csv_path: Path, profile: str, wait_ms: int, left: int, bin_width: int) -> list[str]:
    return [
        str(args.system_console),
        "-cli",
        "-disable_readline",
        "-disable_timeout",
        f"--project_dir={args.project_dir}",
        f"--jdi={args.jdi}",
        f"--script={SCRIPT_DIR / 'phase6_histogram_bin_dump_keep_ingress.tcl'}",
        "--profile",
        profile,
        "--out",
        str(csv_path),
        "--wait-ms",
        str(wait_ms),
        "--csr-base",
        fmt_hex(HIST_CSR_BASE_BYTE),
        "--bin-base",
        fmt_hex(HIST_BIN_BASE_BYTE),
        "--rate-ingress-base-list",
        fmt_hex(HIST_INGRESS_BASE_BYTE),
        "--left-bound",
        str(left),
        "--bin-width",
        str(bin_width),
        "--read-chunk-words",
        "1",
    ]


def run_hist_dump(
    args: argparse.Namespace,
    csv_path: Path,
    profile: str,
    wait_ms: int,
    left: int,
    bin_width: int,
) -> dict[str, Any]:
    env = os.environ.copy()
    env.setdefault("BOARD_TEST_SCRIPT_DIR", str(SCRIPT_DIR))
    if "BOARD_TEST_DISPLAY" in env:
        env["DISPLAY"] = env["BOARD_TEST_DISPLAY"]
    else:
        env.pop("DISPLAY", None)
    cmd = histogram_dump_cmd(args, csv_path, profile, wait_ms, left, bin_width)
    text = run_checked(cmd, env=env)
    log_path = csv_path.with_suffix(".log")
    log_path.write_text(text, encoding="utf-8")
    result_line = next((line for line in text.splitlines() if line.startswith("PHASE5_HIST_DUMP_RESULT ")), "")
    return {
        "csv": str(csv_path),
        "log": str(log_path),
        "profile": profile,
        "wait_ms": wait_ms,
        "left_bound": left,
        "bin_width": bin_width,
        "command": cmd,
        "result_line": result_line,
    }


def start_rate_run(args: argparse.Namespace, q16_rate: int, run_number: int, hist_post: bool | None) -> dict[str, Any]:
    rc_logs = []
    rc_logs.append(rc_send(args, "reset"))
    rc_logs.append(rc_send(args, "stop-reset"))
    time.sleep(args.post_stop_reset_ms / 1000.0)
    lvds_lane_go = configure_lvds_lanes(args.sc_tool, args.link)
    mux_rows = configure_muxes(args.sc_tool, args.link)
    ingress_status = (
        observe_hist_source(args.sc_tool, args.link)
        if hist_post is None
        else select_hist_source(args.sc_tool, args.link, post=hist_post)
    )
    emu_rows = configure_emulators(args.sc_tool, args.link, q16_rate)
    time.sleep(args.post_config_ms / 1000.0)
    rc_logs.append(rc_send(args, "run-prepare", run_number))
    rc_logs.append(rc_send(args, "sync"))
    rc_logs.append(rc_send(args, "start-run"))
    time.sleep(args.post_start_ms / 1000.0)
    return {
        "rc_logs": rc_logs,
        "lvds_lane_go": lvds_lane_go,
        "mux": mux_rows,
        "emulators": emu_rows,
        "source_select": ingress_status,
    }


def run_rate(args: argparse.Namespace, out_dir: Path, label: str, q16_rate: int, run_number: int) -> dict[str, Any]:
    rate_dir = out_dir / label
    rate_dir.mkdir(parents=True, exist_ok=True)
    row: dict[str, Any] = {
        "label": label,
        "q16_rate": q16_rate,
        "started_at": dt.datetime.now().isoformat(timespec="seconds"),
    }
    captures: list[dict[str, Any]] = []

    def capture_one(stage: str, profile: str, filename: str, left: int, bin_width: int, hist_post: bool | None, run_no: int) -> None:
        start = start_rate_run(args, q16_rate, run_no, hist_post=hist_post)
        end_run_log = ""
        try:
            item = run_hist_dump(args, rate_dir / filename, profile, args.wait_ms, left, bin_width)
            item.update(
                {
                    "stage": stage,
                    "run_number": run_no,
                    "source_select": start["source_select"],
                    "rc_logs": start["rc_logs"],
                    "lvds_lane_go": start["lvds_lane_go"],
                    "mux": start["mux"],
                    "emulators": start["emulators"],
                }
            )
            captures.append(item)
        finally:
            end_run_log = rc_send(args, "end-run")
            time.sleep(args.post_end_ms / 1000.0)
            if captures and captures[-1].get("run_number") == run_no:
                captures[-1]["end_run_log"] = end_run_log

    if not args.skip_pre:
        capture_one(
            "pre_rbcam",
            "delay-debug1",
            f"{label}_pre_rbcam_debug1.csv",
            args.pre_left,
            args.pre_bin_width,
            True,
            run_number * 10,
        )
    if not args.skip_egress:
        capture_one(
            "feb_egress",
            "delay-hit-t",
            f"{label}_feb_egress.csv",
            args.egress_left,
            args.egress_bin_width,
            True,
            run_number * 10 + 1,
        )
    row["captures"] = captures
    row["ended_at"] = dt.datetime.now().isoformat(timespec="seconds")
    return row


def parse_rates(text: str) -> list[tuple[str, int]]:
    rates: list[tuple[str, int]] = []
    for item in re.split(r"[,\\s]+", text.strip()):
        if not item:
            continue
        if ":" in item:
            label, value = item.split(":", 1)
            rates.append((label, int(value, 0)))
        elif item in RATE_PRESETS:
            rates.append((item, RATE_PRESETS[item]))
        else:
            value = int(item, 0)
            rates.append((f"r{value:04x}", value))
    if not rates:
        raise argparse.ArgumentTypeError("rate list is empty")
    return rates


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--device", default="/dev/mudaq0")
    parser.add_argument("--feb", type=int, default=7)
    parser.add_argument("--run-number-base", type=int, default=520800)
    parser.add_argument("--rates", default="010k,100k,500k,1000k")
    parser.add_argument("--wait-ms", type=int, default=1200)
    parser.add_argument("--pre-left", type=int, default=-1000)
    parser.add_argument("--pre-bin-width", type=int, default=16)
    parser.add_argument("--egress-left", type=int, default=2000)
    parser.add_argument("--egress-bin-width", type=int, default=22)
    parser.add_argument("--post-stop-reset-ms", type=int, default=20)
    parser.add_argument("--post-config-ms", type=int, default=20)
    parser.add_argument("--post-start-ms", type=int, default=100)
    parser.add_argument("--post-end-ms", type=int, default=200)
    parser.add_argument("--rc-settle-us", type=int, default=5000)
    parser.add_argument("--skip-pre", action="store_true")
    parser.add_argument("--skip-egress", action="store_true")
    parser.add_argument("--output-dir", type=Path, default=default_output_dir())
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--rc-tool", type=Path, default=default_rc_tool())
    parser.add_argument("--system-console", type=Path, default=_default_system_console())
    parser.add_argument("--jdi", type=Path, default=_default_jdi())
    parser.add_argument("--project-dir", type=Path, default=_default_project_dir())
    args = parser.parse_args()

    out_dir = args.output_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    rates = parse_rates(args.rates)
    manifest: dict[str, Any] = {
        "created_at": dt.datetime.now().isoformat(timespec="seconds"),
        "output_dir": str(out_dir),
        "link": args.link,
        "device": args.device,
        "feb": args.feb,
        "tools": {
            "sc_tool": str(args.sc_tool),
            "rc_tool": str(args.rc_tool),
            "system_console": str(args.system_console),
            "jdi": str(args.jdi),
            "project_dir": str(args.project_dir),
        },
        "notes": [
            "pre_rbcam uses histogram debug_1 fed by mts_preprocessor_0.debug_ts",
            "feb_egress uses histogram_ingress_bridge_0 post select with delay-hit-t profile",
            "each capture writes the LVDS lane-go mask after stop-reset before run-prepare",
            "only emulator_mutrig_0 is enabled; lanes 1..7 are selected to emulator but held disabled",
        ],
        "rates": [],
    }

    try:
        for index, (label, rate) in enumerate(rates):
            manifest["rates"].append(run_rate(args, out_dir, label, rate, args.run_number_base + index))
    finally:
        manifest_path = out_dir / "manifest.json"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
        print(manifest_path)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
