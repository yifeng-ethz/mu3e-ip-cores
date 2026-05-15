#!/usr/bin/env python3
"""Drive the pulserdrop RN.BASIC.001 periodic emulator row on the FEB board.

This helper deliberately covers one row only.  It configures the pulserdrop
FEB emulator/arb/histogram path with RN.BASIC.001's corrected internal
periodic source settings, then optionally drives the local debug run-control
source for a 1 ms run window.  Every SC transaction is logged in the evidence
directory so the on-board counters can be audited after a SignalTap capture.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from typing import Any


SCRIPT = Path(__file__).resolve()


def find_repo_root(start: Path) -> Path:
    for path in [start, *start.parents]:
        if (path / "firmware_builds").is_dir() and (path / "tools" / "run_script").is_dir():
            return path
    raise RuntimeError(f"could not locate repo root from {start}")


REPO_ROOT = find_repo_root(SCRIPT)
PHASE45_DIR = REPO_ROOT / "scripts" / "cotest"
if str(PHASE45_DIR) not in sys.path:
    sys.path.insert(0, str(PHASE45_DIR))

import phase4_5_sweep as sweep  # noqa: E402


DEFAULT_SC_TOOL = REPO_ROOT / "tools" / "run_script" / "build" / "sc_tool"
DEFAULT_OUT_ROOT = (
    REPO_ROOT
    / "firmware_builds"
    / "systems"
    / "v3_pretest-260511-pulserdrop-260512"
    / "board_evidence"
    / "RN.BASIC.001_stp_20260513"
)
SWB_RING_LOCK = Path("/home/yifeng/.local/bin/swb_ring_lock")

DBG_BASE_WORD = 0x08880
DBG_ID_W = 0x0
DBG_STATUS_W = 0x1
DBG_CONTROL_W = 0x2
DBG_HOST_CMD_W = 0x3
DBG_SENT_COUNT_W = 0x7
DBG_LAST_SENT_W = 0x8

DBG_CONTROL_ENABLE_CLEAR = 0x00000007

CMD_RUN_PREPARE = 0x10
CMD_RUN_SYNC = 0x11
CMD_START_RUN = 0x12
CMD_END_RUN = 0x13


def reexec_under_lock() -> None:
    if sweep.have_swb_ring_lock():
        return
    if not SWB_RING_LOCK.is_file():
        return
    os.execv(
        str(SWB_RING_LOCK),
        [str(SWB_RING_LOCK), sys.executable, str(SCRIPT), *sys.argv[1:]],
    )


def unique_evidence_dir(root: Path, prefix: str) -> Path:
    root.mkdir(parents=True, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    for suffix in ["", *[f"_{idx:02d}" for idx in range(1, 100)]]:
        path = root / f"{prefix}_{stamp}{suffix}"
        try:
            path.mkdir()
            return path
        except FileExistsError:
            continue
    raise RuntimeError("could not allocate unique evidence directory")


def read_dbg(sc_tool: Path, link: int, log_fh: Any) -> dict[str, Any]:
    words = sweep.sc_read(sc_tool, link, DBG_BASE_WORD, 9, log_fh=log_fh)
    status = words[DBG_STATUS_W]
    last_sent = words[DBG_LAST_SENT_W]
    return {
        "uid": f"0x{words[DBG_ID_W]:08X}",
        "status": f"0x{status:08X}",
        "local_enable": bool(status & 0x1),
        "pending": bool(status & 0x2),
        "script_busy": bool(status & 0x4),
        "sticky_overrun": bool(status & 0x8),
        "sticky_bad_cmd": bool(status & 0x10),
        "last_from_host": bool(status & 0x20),
        "gap_cycles": (status >> 16) & 0xFFFF,
        "control": f"0x{words[DBG_CONTROL_W]:08X}",
        "sent_count": words[DBG_SENT_COUNT_W],
        "sent_count_hex": f"0x{words[DBG_SENT_COUNT_W]:08X}",
        "last_sent": f"0x{last_sent:08X}",
        "last_sent_state": last_sent & 0x1FF,
        "last_sent_from_host": bool((last_sent >> 9) & 0x1),
        "last_sent_host_cmd": (last_sent >> 10) & 0xFF,
    }


def write_dbg_control(sc_tool: Path, link: int, log_fh: Any) -> dict[str, Any]:
    sweep.sc_write_stable(
        sc_tool,
        link,
        DBG_BASE_WORD + DBG_CONTROL_W,
        [DBG_CONTROL_ENABLE_CLEAR],
        log_fh=log_fh,
    )
    return read_dbg(sc_tool, link, log_fh)


def write_dbg_host_cmd(
    sc_tool: Path,
    link: int,
    cmd: int,
    pause_s: float,
    log_fh: Any,
) -> dict[str, Any]:
    before = read_dbg(sc_tool, link, log_fh)
    sweep.sc_write(
        sc_tool,
        link,
        DBG_BASE_WORD + DBG_HOST_CMD_W,
        [cmd & 0xFF],
        log_fh=log_fh,
    )

    deadline = time.time() + 2.0
    after = before
    while time.time() < deadline:
        after = read_dbg(sc_tool, link, log_fh)
        if after["sent_count"] >= before["sent_count"] + 1 and not after["pending"]:
            break
        time.sleep(0.005)

    time.sleep(pause_s)
    return {
        "cmd": f"0x{cmd:02X}",
        "sent_before": before["sent_count"],
        "sent_after": after["sent_count"],
        "accepted": after["sent_count"] >= before["sent_count"] + 1,
        "status_after": after["status"],
        "last_sent": after["last_sent"],
        "last_sent_host_cmd": f"0x{after['last_sent_host_cmd']:02X}",
        "pause_s": pause_s,
    }


def rn001_row() -> dict[str, Any]:
    return {
        "row_id": "RN.BASIC.001",
        "lane_mask": "0xFF",
        "channel_mask": "0xFFFFFFFF",
        "rate_88fp": "0x0040",
        "hit_mode": "10",
        "interval_seconds": 0.001,
        "axis_section": "RN.BASIC.001",
        "expected_behavior": "internal periodic emulator source, all lanes, all channels",
        "sanity_negative": False,
        "bucket": "BASIC",
    }


def configure_row(args: argparse.Namespace, record: dict[str, Any], log_fh: Any) -> None:
    row = record["row"]
    sweep.HIST_INGRESS_SOURCE = args.hist_ingress_source
    sweep.HIST_INGRESS_BANK_COUNT = args.hist_ingress_banks

    record["dbg_control_after_clear"] = write_dbg_control(args.sc_tool, args.link, log_fh)
    sweep.enable_lvds_lanes(args.sc_tool, args.link, log_fh=log_fh)
    record["arb_lane_cfg"] = sweep.configure_arb_lane_mask(
        args.sc_tool,
        args.link,
        int(row["lane_mask"], 16),
        log_fh=log_fh,
    )
    record["emulator_cfg"] = sweep.configure_emulator(
        args.sc_tool,
        args.link,
        int(row["channel_mask"], 16),
        int(row["rate_88fp"], 16),
        int(row["hit_mode"], 2),
        log_fh=log_fh,
    )
    record["lane_enable_written"] = "0x000000FF"
    sweep.sc_write_stable(
        args.sc_tool,
        args.link,
        sweep.EMU_BASE_WORD + 0x12,
        [0x000000FF],
        log_fh=log_fh,
    )
    record["lane_enable_readback"] = (
        f"0x{sweep.sc_read(args.sc_tool, args.link, sweep.EMU_BASE_WORD + 0x12, 1, log_fh=log_fh)[0]:08X}"
    )
    record["histogram_cfg"] = sweep.configure_histogram(
        args.sc_tool,
        args.link,
        sweep.INTERVAL_CFG_NEVER_FIRE,
        log_fh=log_fh,
    )
    record["ingress_status"] = sweep.select_histogram_source(
        args.sc_tool,
        args.link,
        source=args.hist_ingress_source,
        bank_count=args.hist_ingress_banks,
        log_fh=log_fh,
    )
    record["downstream_cfg"] = sweep.configure_downstream(
        args.sc_tool,
        args.link,
        log_fh=log_fh,
    )


def drive_dbg_run(args: argparse.Namespace, record: dict[str, Any], log_fh: Any) -> None:
    record["dbg_pre_run"] = read_dbg(args.sc_tool, args.link, log_fh)
    record["snapshot_pre"] = sweep.full_snapshot(args.sc_tool, args.link, log_fh=log_fh)
    record["cmd_trace"] = [
        write_dbg_host_cmd(args.sc_tool, args.link, CMD_RUN_PREPARE, 0.200, log_fh),
        write_dbg_host_cmd(args.sc_tool, args.link, CMD_RUN_SYNC, 0.200, log_fh),
        write_dbg_host_cmd(args.sc_tool, args.link, CMD_START_RUN, args.run_window_s, log_fh),
        write_dbg_host_cmd(args.sc_tool, args.link, CMD_END_RUN, 0.500, log_fh),
    ]
    record["snapshot_post"] = sweep.full_snapshot(args.sc_tool, args.link, log_fh=log_fh)
    record["hist_bins"] = sweep.read_hist_bins(args.sc_tool, args.link, log_fh=log_fh)
    record["dbg_post_run"] = read_dbg(args.sc_tool, args.link, log_fh)


def drive_host_run(args: argparse.Namespace, record: dict[str, Any], log_fh: Any) -> None:
    record["snapshot_pre"] = sweep.full_snapshot(args.sc_tool, args.link, log_fh=log_fh)
    record["stage_recipe"] = sweep.run_stage_recipe(
        args.sc_tool,
        args.link,
        record["row"],
        1,
        log_fh=log_fh,
    )
    record["snapshot_post"] = sweep.full_snapshot(args.sc_tool, args.link, log_fh=log_fh)
    record["hist_bins"] = sweep.read_hist_bins(args.sc_tool, args.link, log_fh=log_fh)


def drive_run(args: argparse.Namespace, record: dict[str, Any], log_fh: Any) -> None:
    if args.run_driver == "host":
        drive_host_run(args, record, log_fh)
    else:
        drive_dbg_run(args, record, log_fh)


def summarize_pass(record: dict[str, Any]) -> dict[str, Any]:
    post = record.get("snapshot_post", {})
    arb = post.get("arb", [])
    hist = post.get("histogram", {})
    egress_emu_hits = sum(int(lane.get("egress_emu_hits", 0)) for lane in arb)
    ingress_emu_hits = sum(int(lane.get("ingress_emu_hits", 0)) for lane in arb)
    drops_emu = sum(int(lane.get("drops_emu", 0)) for lane in arb)
    hist_total_hits = int(hist.get("TOTAL_HITS", 0)) if isinstance(hist, dict) else 0
    cmd_trace = record.get("cmd_trace", [])
    if cmd_trace:
        all_cmds_accepted = all(item.get("accepted") for item in cmd_trace)
    else:
        stage_recipe = record.get("stage_recipe", {})
        all_cmds_accepted = len(stage_recipe.get("cmd_traces", [])) == 4
    return {
        "dbg_all_cmds_accepted": all_cmds_accepted,
        "arb_ingress_emu_hits_sum": ingress_emu_hits,
        "arb_egress_emu_hits_sum": egress_emu_hits,
        "arb_drops_emu_sum": drops_emu,
        "hist_total_hits": hist_total_hits,
        "board_counter_pass": (
            all_cmds_accepted
            and ingress_emu_hits > 0
            and egress_emu_hits > 0
            and drops_emu == 0
            and hist_total_hits > 0
        ),
    }


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sc-tool", type=Path, default=DEFAULT_SC_TOOL)
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUT_ROOT)
    parser.add_argument(
        "--mode",
        choices=("configure", "run", "configure-run"),
        default="configure-run",
    )
    parser.add_argument("--run-window-s", type=float, default=0.001)
    parser.add_argument("--run-driver", choices=("dbg", "host"), default="dbg")
    parser.add_argument("--hist-ingress-source", choices=("pre", "post"), default="post")
    parser.add_argument("--hist-ingress-banks", type=int, default=1)
    parser.add_argument("--no-lock", action="store_true")
    args = parser.parse_args(argv)

    if not args.no_lock:
        reexec_under_lock()

    prefix = {
        "configure": "RN.BASIC.001_readyless_config",
        "run": "RN.BASIC.001_readyless_run",
        "configure-run": "RN.BASIC.001_readyless_periodic",
    }[args.mode]
    evidence_dir = unique_evidence_dir(args.output_root, prefix)
    record: dict[str, Any] = {
        "started_at": dt.datetime.now().isoformat(timespec="seconds"),
        "row": rn001_row(),
        "evidence_dir": str(evidence_dir),
        "sc_tool": str(args.sc_tool),
        "link": args.link,
        "mode": args.mode,
        "runctrl_source": "runctl_mgmt_host_0" if args.run_driver == "host" else "dbg_mm2runctrl_0",
        "dbg_base": f"0x{DBG_BASE_WORD:05X}",
        "hist_ingress_source": args.hist_ingress_source,
        "hist_ingress_banks": args.hist_ingress_banks,
    }

    tool_log = evidence_dir / "tool_calls.log"
    with tool_log.open("w", encoding="ascii") as log_fh:
        sweep._log(log_fh, "# run_rn001_direct_periodic_board.py")
        sweep._log(log_fh, f"# evidence_dir={evidence_dir}")
        if args.mode in {"configure", "configure-run"}:
            configure_row(args, record, log_fh)
        if args.mode in {"run", "configure-run"}:
            drive_run(args, record, log_fh)

    record["finished_at"] = dt.datetime.now().isoformat(timespec="seconds")
    record["summary"] = summarize_pass(record)
    summary_path = evidence_dir / "board_summary.json"
    summary_path.write_text(json.dumps(record, indent=2) + "\n", encoding="ascii")

    print(f"evidence_dir={evidence_dir}")
    print(f"summary={summary_path}")
    print(f"mode={args.mode}")
    print(json.dumps(record["summary"], indent=2))
    return 0 if record["summary"].get("board_counter_pass", False) or args.mode == "configure" else 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
