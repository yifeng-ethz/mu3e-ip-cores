#!/usr/bin/env python3
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


SC_HUB_UID_WORD = 0x0FE80
SC_HUB_UID = 0x53434842
RUNCTL_BASE_WORD = 0x0C000
RUNCTL_STATUS_WORD = RUNCTL_BASE_WORD + 0x03
RUNCTL_LAST_CMD_WORD = RUNCTL_BASE_WORD + 0x04
LOCAL_CMD_WORD = 0x0C013

LVDS_LANE_GO_WORD = 0x08004
EMU_BASE_WORD = 0x08800
ARB_BASE_WORD = 0x088A0
ARB_STRIDE_WORD = 0x20
HIST_BIN_BASE_WORD = 0x0A800
HIST_CSR_BASE_WORD = 0x0A900
HIST_INGRESS_BASE_WORD = 0x0AB00

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

HIST_KEY_LOC_CHANNEL_POST = (38 << 24) | (35 << 16) | (21 << 8) | 17
DEFAULT_HIST_INTERVAL_CLOCKS = 125_000_000
RING_CTRL_GO = 0x00000001
RING_CTRL_FILTER_INERR = 0x00000010


def default_output_dir() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    return (
        Path(__file__).resolve().parents[1]
        / "reports"
        / f"phase4_emutype0_board_{stamp}"
    )


def have_swb_ring_lock() -> bool:
    if os.environ.get("SWB_RING_LOCK_HELD") == "1":
        return True
    try:
        return Path(os.readlink("/proc/self/fd/9")) == Path("/tmp/swb_ring.lock")
    except OSError:
        return False


def run(cmd: list[str], *, check: bool = True) -> subprocess.CompletedProcess[str]:
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


def sc_read(sc_tool: Path, link: int, addr: int, count: int = 1) -> list[int]:
    last = ""
    for attempt in range(6):
        proc = run(
            [
                str(sc_tool),
                str(link),
                "read",
                f"0x{addr:05X}",
                str(count),
                "--quiet",
            ],
            check=False,
        )
        last = proc.stdout + proc.stderr
        words = parse_payload(last)
        if proc.returncode == 0 and len(words) == count:
            return words
        time.sleep(0.05 * (attempt + 1))
    raise RuntimeError(f"SC read failed at 0x{addr:05X} count={count}\n{last}")


def sc_write(sc_tool: Path, link: int, addr: int, words: list[int]) -> str:
    last = ""
    for attempt in range(6):
        proc = run(
            [
                str(sc_tool),
                str(link),
                "write",
                f"0x{addr:05X}",
                *[f"0x{word & 0xFFFFFFFF:08X}" for word in words],
                "--quiet",
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
    if delay_s > 0:
        time.sleep(delay_s)
    return {
        "cmd": f"0x{cmd:02X}",
        "word": f"0x{word:08X}",
        "runctl_status": f"0x{status:08X}",
        "runctl_last_cmd": f"0x{last_cmd:08X}",
    }


def configure_emulator(sc_tool: Path, link: int, hit_rate: int) -> dict[str, Any]:
    writes = {
        "CENTRAL": (EMU_BASE_WORD + 0x07, 0x00000001),
        "SIGNAL": (EMU_BASE_WORD + 0x08, 0x00000000),
        "BACKGROUND": (EMU_BASE_WORD + 0x09, 0x00000000),
        "MUTRIG_FORMAT": (EMU_BASE_WORD + 0x0A, 0x00000023),
        "RATES": (EMU_BASE_WORD + 0x0B, hit_rate & 0xFFFF),
        "CLUSTER_FIX": (EMU_BASE_WORD + 0x0C, 0x00004000 | (3 << 7) | 0),
        "PRNG_SEED": (EMU_BASE_WORD + 0x0E, 0xDEADBEEF),
        "TIMEBASE_SEED": (EMU_BASE_WORD + 0x0F, 0x00010001),
    }
    for _, (addr, value) in writes.items():
        sc_write_stable(sc_tool, link, addr, [value])
    return {
        name: {
            "addr": f"0x{addr:05X}",
            "written": f"0x{value:08X}",
            "readback": f"0x{sc_read(sc_tool, link, addr)[0]:08X}",
        }
        for name, (addr, value) in writes.items()
    }


def configure_histogram(sc_tool: Path, link: int, interval_clocks: int) -> dict[str, str]:
    writes = {
        "LEFT_BOUND": (HIST_CSR_BASE_WORD + 0x03, 0x00000000),
        "RIGHT_BOUND": (HIST_CSR_BASE_WORD + 0x04, 0x000000FF),
        "BIN_WIDTH": (HIST_CSR_BASE_WORD + 0x05, 0x00000001),
        "KEY_LOC": (HIST_CSR_BASE_WORD + 0x06, HIST_KEY_LOC_CHANNEL_POST),
        "INTERVAL_CFG": (HIST_CSR_BASE_WORD + 0x0A, interval_clocks & 0xFFFFFFFF),
        "CONTROL_APPLY": (HIST_CSR_BASE_WORD + 0x02, 0x00000101),
    }
    sc_write_stable(sc_tool, link, HIST_BIN_BASE_WORD, [0])
    for _, (addr, value) in writes.items():
        sc_write_stable(sc_tool, link, addr, [value])
    for _ in range(50):
        control = sc_read(sc_tool, link, HIST_CSR_BASE_WORD + 0x02)[0]
        if (control & 0x2) == 0:
            break
        time.sleep(0.02)
    return {
        name: f"0x{sc_read(sc_tool, link, addr)[0]:08X}"
        for name, (addr, _) in writes.items()
    }


def select_histogram_post(sc_tool: Path, link: int) -> int:
    sc_write_stable(sc_tool, link, HIST_INGRESS_BASE_WORD + 0x02, [0x00000001])
    status = 0
    for _ in range(50):
        status = sc_read(sc_tool, link, HIST_INGRESS_BASE_WORD + 0x03)[0]
        if (status & 0x7) == 0x3:
            break
        time.sleep(0.02)
    return status


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


def histogram_light(sc_tool: Path, link: int) -> dict[str, int]:
    words = sc_read(sc_tool, link, HIST_CSR_BASE_WORD + 8, 9)
    return {
        "UNDERFLOW_COUNT": words[0],
        "OVERFLOW_COUNT": words[1],
        "INTERVAL_CFG": words[2],
        "BANK_STATUS": words[3],
        "PORT_STATUS": words[4],
        "TOTAL_HITS": words[5],
        "DROPPED_HITS": words[6],
        "COAL_STATUS": words[7],
        "LAST_INT_HITS": words[8],
    }


def snapshot(sc_tool: Path, link: int) -> dict[str, Any]:
    arb = []
    for lane in range(8):
        base = ARB_BASE_WORD + lane * ARB_STRIDE_WORD
        words = sc_read(sc_tool, link, base, 30)
        arb.append(
            {
                "lane": lane,
                "base": f"0x{base:05X}",
                "uid": f"0x{words[0]:08X}",
                "status": f"0x{words[3]:08X}",
                "ingress_real_hits": read_u64_pair(words, 0x0A, 0x0B),
                "ingress_emu_hits": read_u64_pair(words, 0x0C, 0x0D),
                "drops_real": read_u64_pair(words, 0x0E, 0x0F),
                "drops_emu": read_u64_pair(words, 0x10, 0x11),
                "egress_real_hits": read_u64_pair(words, 0x12, 0x13),
                "egress_emu_hits": read_u64_pair(words, 0x14, 0x15),
                "ingress_real_frames": read_u64_pair(words, 0x16, 0x17),
                "ingress_emu_frames": read_u64_pair(words, 0x18, 0x19),
                "egress_real_frames": read_u64_pair(words, 0x1A, 0x1B),
                "egress_emu_frames": read_u64_pair(words, 0x1C, 0x1D),
            }
        )

    hist_words = sc_read(sc_tool, link, HIST_CSR_BASE_WORD, 17)
    # Histogram-bin burst reads are a known SC bridge corruption trigger in
    # this FEB image. Keep these as single-word transactions.
    hist_bins = [
        sc_read(sc_tool, link, HIST_BIN_BASE_WORD + offset)[0]
        for offset in range(64)
    ]
    mts = []
    for idx, base in enumerate(MTS_BASE_WORDS):
        words = sc_read(sc_tool, link, base, 5)
        mts.append(
            {
                "idx": idx,
                "base": f"0x{base:05X}",
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
            "base": f"0x{base:05X}",
            "uid": f"0x{words[0]:08X}",
            "ctrl": f"0x{words[2]:08X}",
            "fill_level": words[4],
            "inerr_count": words[5],
            "push_count": words[6],
            "pop_count": words[7],
            "overwrite_count": words[8],
            "cache_miss_count": words[9],
        }

    frame_asm = {}
    for name, base in FRAME_ASM_BASE_WORDS.items():
        words = sc_read(sc_tool, link, base, 8)
        frame_asm[name] = {
            "base": f"0x{base:05X}",
            "feb_type": words[0],
            "feb_id": words[1],
            "declared_hits": ((words[2] & 0x3FFFF) << 32) | words[3],
            "actual_hits": ((words[4] & 0x3FFFF) << 32) | words[5],
            "missing_hits": ((words[6] & 0x3FFFF) << 32) | words[7],
        }

    return {
        "sc_hub": {
            "uid": f"0x{sc_read(sc_tool, link, SC_HUB_UID_WORD)[0]:08X}",
            "status": f"0x{sc_read(sc_tool, link, SC_HUB_UID_WORD + 3)[0]:08X}",
        },
        "lvds_lane_go": f"0x{sc_read(sc_tool, link, LVDS_LANE_GO_WORD)[0]:08X}",
        "emulator_csr_0x00_0x0f": [f"0x{x:08X}" for x in sc_read(sc_tool, link, EMU_BASE_WORD, 16)],
        "arb": arb,
        "histogram_ingress_status": f"0x{sc_read(sc_tool, link, HIST_INGRESS_BASE_WORD + 3)[0]:08X}",
        "histogram_csr_0x00_0x10": [f"0x{x:08X}" for x in hist_words],
        "histogram_decoded": {
            "UNDERFLOW_COUNT": hist_words[8],
            "OVERFLOW_COUNT": hist_words[9],
            "INTERVAL_CFG": hist_words[10],
            "BANK_STATUS": hist_words[11],
            "PORT_STATUS": hist_words[12],
            "TOTAL_HITS": hist_words[13],
            "DROPPED_HITS": hist_words[14],
            "COAL_STATUS": hist_words[15],
            "LAST_INT_HITS": hist_words[16],
        },
        "hist_bin_0_63": hist_bins,
        "hist_bin_sum_0_63": sum(hist_bins),
        "mts": mts,
        "ring": ring,
        "frame_assembly": frame_asm,
    }


def write_report(out_dir: Path, report: dict[str, Any]) -> None:
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "phase4_emutype0_board_probe.json").write_text(
        json.dumps(report, indent=2) + "\n",
        encoding="ascii",
    )

    hist = report["after_running"]["histogram_decoded"]
    arb_totals = {
        "ingress_emu_hits": sum(row["ingress_emu_hits"] for row in report["after_running"]["arb"]),
        "egress_emu_hits": sum(row["egress_emu_hits"] for row in report["after_running"]["arb"]),
        "drops_emu": sum(row["drops_emu"] for row in report["after_running"]["arb"]),
    }
    bank_samples = [row["BANK_STATUS"] for row in report.get("histogram_samples", [])]
    bank_toggled = len(set(bank_samples)) > 1
    verdict = (
        hist["TOTAL_HITS"] > 0
        and bank_toggled
        and hist["PORT_STATUS"] != 0xFF
    )
    lines = [
        "# Phase 4 Emulator-Type0 Board Probe",
        "",
        f"- Created: {report['created']}",
        f"- FEB link: `{report['link']}`",
        f"- sc_tool: `{report['sc_tool']}`",
        f"- LOCAL_CMD words: `{', '.join(report['local_cmd_words'])}`",
        f"- Verdict: `{'PASS' if verdict else 'FAIL'}`",
        "",
        "## Histogram",
        "",
        f"- TOTAL_HITS: `{hist['TOTAL_HITS']}`",
        f"- BANK_STATUS samples: `{bank_samples}`",
        f"- PORT_STATUS: `0x{hist['PORT_STATUS']:02X}`",
        f"- DROPPED_HITS: `{hist['DROPPED_HITS']}`",
        f"- hist_bin[0..63] sum: `{report['after_running']['hist_bin_sum_0_63']}`",
        "",
        "## Arbiter Totals",
        "",
        f"- ingress_emu_hits: `{arb_totals['ingress_emu_hits']}`",
        f"- egress_emu_hits: `{arb_totals['egress_emu_hits']}`",
        f"- drops_emu: `{arb_totals['drops_emu']}`",
        "",
        "## Files",
        "",
        "- `phase4_emutype0_board_probe.json`",
    ]
    (out_dir / "PHASE4_EMUTYPE0_BOARD_PROBE.md").write_text(
        "\n".join(lines) + "\n",
        encoding="ascii",
    )


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--sc-tool", type=Path, default=Path("tools/run_script/build/sc_tool"))
    ap.add_argument("--link", type=int, default=2)
    ap.add_argument("--output-dir", type=Path, default=default_output_dir())
    ap.add_argument("--hit-rate", type=lambda s: int(s, 0), default=0x0800)
    ap.add_argument("--run-seconds", type=float, default=4.0)
    ap.add_argument("--hist-interval-clocks", type=lambda s: int(s, 0), default=DEFAULT_HIST_INTERVAL_CLOCKS)
    args = ap.parse_args()

    if not have_swb_ring_lock():
        raise SystemExit("run under /home/yifeng/.local/bin/swb_ring_lock")

    report: dict[str, Any] = {
        "created": dt.datetime.now().isoformat(timespec="seconds"),
        "link": args.link,
        "sc_tool": str(args.sc_tool),
        "hit_rate": args.hit_rate,
        "run_seconds": args.run_seconds,
        "local_cmd_words": [],
        "local_cmd_trace": [],
    }

    uid = sc_read(args.sc_tool, args.link, SC_HUB_UID_WORD)[0]
    if uid != SC_HUB_UID:
        raise RuntimeError(f"SC hub UID mismatch: got 0x{uid:08X}, expected 0x{SC_HUB_UID:08X}")

    sc_write_stable(args.sc_tool, args.link, LVDS_LANE_GO_WORD, [0x000001FF])
    report["emulator_config"] = configure_emulator(args.sc_tool, args.link, args.hit_rate)
    report["histogram_config"] = configure_histogram(args.sc_tool, args.link, args.hist_interval_clocks)
    report["histogram_ingress_select_status"] = f"0x{select_histogram_post(args.sc_tool, args.link):08X}"
    report["downstream_config"] = configure_downstream(args.sc_tool, args.link)
    report["before"] = snapshot(args.sc_tool, args.link)

    run_number = int(time.time()) & 0xFFFFFF
    for cmd, delay in ((0x10, 0.05), (0x11, 0.05)):
        payload = run_number if cmd == 0x10 else 0
        trace = local_cmd(args.sc_tool, args.link, cmd, payload, delay)
        report["local_cmd_words"].append(trace["word"])
        report["local_cmd_trace"].append(trace)

    report["downstream_config_after_sync"] = configure_downstream(args.sc_tool, args.link)
    trace = local_cmd(args.sc_tool, args.link, 0x12, 0, 0.0)
    report["local_cmd_words"].append(trace["word"])
    report["local_cmd_trace"].append(trace)

    try:
        deadline = time.time() + args.run_seconds
        report["histogram_samples"] = []
        while time.time() < deadline:
            report["histogram_samples"].append(histogram_light(args.sc_tool, args.link))
            time.sleep(0.5)
        report["after_running"] = snapshot(args.sc_tool, args.link)
    except Exception as exc:
        report["after_running_error"] = str(exc)
        report["after_running"] = report["before"]
    finally:
        end_trace = local_cmd(args.sc_tool, args.link, 0x13, 0, 0.05)
        report["local_cmd_words"].append(end_trace["word"])
        report["local_cmd_trace"].append(end_trace)

    try:
        report["after_end_run"] = snapshot(args.sc_tool, args.link)
    except Exception as exc:
        report["after_end_run_error"] = str(exc)
        report["after_end_run"] = report["after_running"]

    write_report(args.output_dir, report)
    print(args.output_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
