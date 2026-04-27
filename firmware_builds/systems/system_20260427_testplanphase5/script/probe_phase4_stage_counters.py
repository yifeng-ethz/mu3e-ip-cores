#!/usr/bin/env python3

from __future__ import annotations

import argparse
import datetime as dt
import json
import sys
import time
from pathlib import Path
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
BOARD_TEST_DIR = SCRIPT_DIR.parent

if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from check_ip_metadata import _default_sc_tool  # noqa: E402
from check_run_control import default_rc_tool  # noqa: E402
from run_phase4_emulator import (  # noqa: E402
    HIST_CSR_BASE_WORD,
    HIST_INGRESS_BASE_WORD,
    LVDS_LANE_GO_MASK,
    clear_histogram,
    configure_emulators,
    configure_histogram,
    configure_lvds_lanes,
    decode_histogram_ingress_status,
    hist_snapshot,
    rc_send,
    read_emulator_statuses,
    sc_read,
    sc_write,
    select_histogram_ingress_post,
)


SC_HUB_BASE_WORD = 0x0FE80
FRAME_RCV_BASE_WORDS = [0x08240, 0x08640, 0x08A40, 0x08E40, 0x09240, 0x09640, 0x09A40, 0x09E40]
MTS_BASE_WORDS = [0x09000, 0x0A000]
MTS_CTRL_GO = 1 << 0
MTS_CTRL_DISCARD_HITERR = 1 << 4
MTS_CTRL_DROP_DELAY_ERROR = 1 << 5
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
RING_CTRL_GO = 0x00000001
RING_CTRL_FILTER_INERR = 0x00000010


def default_output() -> Path:
    stamp = dt.datetime.now().strftime("%Y%m%d_%H%M%S")
    return BOARD_TEST_DIR / "reports" / f"phase4_stage_probe_{stamp}.md"


def counter_delta(before: int, after: int, bits: int = 32) -> int:
    mask = (1 << bits) - 1
    return (after - before) & mask


def u48(high_word: int, low_word: int, high_bits: int = 16) -> int:
    return ((high_word & ((1 << high_bits) - 1)) << 32) | (low_word & 0xFFFFFFFF)


def read_sc_hub_snapshot(sc_tool: Path, link: int) -> dict[str, int]:
    offsets = {
        "uid": 0x00,
        "status": 0x03,
        "err_flags": 0x04,
        "err_count": 0x05,
        "ext_pkt_rd": 0x0F,
        "ext_pkt_wr": 0x10,
        "ext_word_rd": 0x11,
        "ext_word_wr": 0x12,
        "pkt_drop_count": 0x17,
    }
    return {name: sc_read(sc_tool, link, SC_HUB_BASE_WORD + offset)[0] for name, offset in offsets.items()}


def read_frame_rcv_snapshot(sc_tool: Path, link: int) -> list[dict[str, int]]:
    rows: list[dict[str, int]] = []
    for idx, base in enumerate(FRAME_RCV_BASE_WORDS):
        words = sc_read(sc_tool, link, base, 3)
        rows.append(
            {
                "lane": idx,
                "status_control": words[0],
                "crc_err": words[1],
                "open_frame_count": words[2],
            }
        )
    return rows


def read_mts_snapshot(sc_tool: Path, link: int) -> list[dict[str, int]]:
    rows: list[dict[str, int]] = []
    for idx, base in enumerate(MTS_BASE_WORDS):
        words = sc_read(sc_tool, link, base, 5)
        rows.append(
            {
                "idx": idx,
                "status_control": words[0],
                "discard_hits": words[1],
                "expected_latency": words[2],
                "total_hits": u48(words[3], words[4], high_bits=16),
            }
        )
    return rows


def read_ring_snapshot(sc_tool: Path, link: int) -> dict[str, dict[str, int]]:
    rows: dict[str, dict[str, int]] = {}
    for name, base in RING_BASE_WORDS.items():
        words = sc_read(sc_tool, link, base, 10)
        rows[name] = {
            "uid": words[0],
            "meta": words[1],
            "ctrl": words[2],
            "expected_latency": words[3],
            "fill_level": words[4],
            "inerr_count": words[5],
            "push_count": words[6],
            "pop_count": words[7],
            "overwrite_count": words[8],
            "cache_miss_count": words[9],
        }
    return rows


def read_frame_asm_snapshot(sc_tool: Path, link: int) -> dict[str, dict[str, int]]:
    rows: dict[str, dict[str, int]] = {}
    for name, base in FRAME_ASM_BASE_WORDS.items():
        words = sc_read(sc_tool, link, base, 8)
        rows[name] = {
            "feb_type": words[0],
            "feb_id": words[1],
            "declared_hits": u48(words[2], words[3], high_bits=18),
            "actual_hits": u48(words[4], words[5], high_bits=18),
            "missing_hits": u48(words[6], words[7], high_bits=18),
        }
    return rows


def read_stage_snapshot(sc_tool: Path, link: int) -> dict[str, Any]:
    ingress_raw = sc_read(sc_tool, link, HIST_INGRESS_BASE_WORD + 3)[0]
    return {
        "sc_hub": read_sc_hub_snapshot(sc_tool, link),
        "emulators": read_emulator_statuses(sc_tool, link),
        "frame_rcv": read_frame_rcv_snapshot(sc_tool, link),
        "mts": read_mts_snapshot(sc_tool, link),
        "ring": read_ring_snapshot(sc_tool, link),
        "frame_asm": read_frame_asm_snapshot(sc_tool, link),
        "hist_ingress": decode_histogram_ingress_status(ingress_raw),
        "histogram": hist_snapshot(sc_tool, link),
    }


def apply_debug_overrides(args: argparse.Namespace) -> dict[str, Any]:
    overrides: dict[str, Any] = {
        "ring_filter_inerr": args.ring_filter_inerr,
        "mts_expected_latency": args.mts_expected_latency,
        "mts_drop_delay_error": args.mts_drop_delay_error,
    }

    if args.mts_expected_latency is not None:
        for base in MTS_BASE_WORDS:
            sc_write(args.sc_tool, args.link, base + 2, [args.mts_expected_latency])

    if args.mts_drop_delay_error != "keep":
        ctrl = MTS_CTRL_GO | MTS_CTRL_DISCARD_HITERR | MTS_CTRL_DELAY_TS_FIELD_USE_T
        if args.mts_drop_delay_error == "on":
            ctrl |= MTS_CTRL_DROP_DELAY_ERROR
        for base in MTS_BASE_WORDS:
            sc_write(args.sc_tool, args.link, base + 0, [ctrl])
        overrides["mts_ctrl_written"] = ctrl

    if args.ring_filter_inerr != "keep":
        ctrl = RING_CTRL_GO
        if args.ring_filter_inerr == "on":
            ctrl |= RING_CTRL_FILTER_INERR
        for base in RING_BASE_WORDS.values():
            sc_write(args.sc_tool, args.link, base + 2, [ctrl])
        overrides["ring_ctrl_written"] = ctrl

    return overrides


def summarize_cycle(before: dict[str, Any], sample: dict[str, Any], post_end: dict[str, Any]) -> dict[str, Any]:
    emu_frame_delta = sum(
        counter_delta(a["frame_count"], b["frame_count"], bits=16)
        for a, b in zip(before["emulators"], sample["emulators"])
    )
    frame_crc_delta = sum(
        counter_delta(a["crc_err"], b["crc_err"])
        for a, b in zip(before["frame_rcv"], sample["frame_rcv"])
    )
    mts_total_delta = sum(
        counter_delta(a["total_hits"], b["total_hits"], bits=48)
        for a, b in zip(before["mts"], sample["mts"])
    )
    mts_discard_delta = sum(
        counter_delta(a["discard_hits"], b["discard_hits"])
        for a, b in zip(before["mts"], sample["mts"])
    )
    ring_push_delta = sum(
        counter_delta(before["ring"][name]["push_count"], sample["ring"][name]["push_count"])
        for name in RING_BASE_WORDS
    )
    ring_pop_delta = sum(
        counter_delta(before["ring"][name]["pop_count"], sample["ring"][name]["pop_count"])
        for name in RING_BASE_WORDS
    )
    ring_cache_miss_delta = sum(
        counter_delta(before["ring"][name]["cache_miss_count"], sample["ring"][name]["cache_miss_count"])
        for name in RING_BASE_WORDS
    )
    ring_inerr_delta = sum(
        counter_delta(before["ring"][name]["inerr_count"], sample["ring"][name]["inerr_count"])
        for name in RING_BASE_WORDS
    )
    frame_declared_delta = sum(
        counter_delta(before["frame_asm"][name]["declared_hits"], sample["frame_asm"][name]["declared_hits"], bits=50)
        for name in FRAME_ASM_BASE_WORDS
    )
    frame_actual_delta = sum(
        counter_delta(before["frame_asm"][name]["actual_hits"], sample["frame_asm"][name]["actual_hits"], bits=50)
        for name in FRAME_ASM_BASE_WORDS
    )
    frame_missing_delta = sum(
        counter_delta(before["frame_asm"][name]["missing_hits"], sample["frame_asm"][name]["missing_hits"], bits=50)
        for name in FRAME_ASM_BASE_WORDS
    )
    hist_total_delta = counter_delta(before["histogram"]["TOTAL_HITS"], sample["histogram"]["TOTAL_HITS"])
    hist_drop_delta = counter_delta(before["histogram"]["DROPPED_HITS"], sample["histogram"]["DROPPED_HITS"])
    post_end_hist = post_end["histogram"]
    post_end_clean = (
        (post_end_hist["PORT_STATUS"] & 0xFF) == 0xFF
        and (post_end_hist["COAL_STATUS"] & 0xFF) == 0
    )

    if hist_total_delta > 0 and hist_drop_delta == 0 and mts_discard_delta == 0 and post_end_clean:
        classification = "PASS"
    elif hist_total_delta > 0 and not post_end_clean:
        classification = "post_end_residue"
    elif emu_frame_delta == 0:
        classification = "blocked_before_emulator"
    elif mts_total_delta == 0:
        classification = "blocked_before_mts"
    elif mts_discard_delta != 0:
        classification = "mts_discarding_or_invalid_input"
    elif ring_push_delta == 0:
        classification = "blocked_mts_to_hitstack"
    elif ring_pop_delta == 0 and frame_actual_delta == 0:
        classification = "blocked_hitstack_pop"
    elif frame_actual_delta > 0 and hist_total_delta == 0:
        classification = "blocked_hist_ingress_or_stats"
    else:
        classification = "mixed_or_saturated"

    return {
        "classification": classification,
        "emu_frame_delta": emu_frame_delta,
        "frame_crc_delta": frame_crc_delta,
        "mts_total_delta": mts_total_delta,
        "mts_discard_delta": mts_discard_delta,
        "ring_push_delta": ring_push_delta,
        "ring_pop_delta": ring_pop_delta,
        "ring_inerr_delta": ring_inerr_delta,
        "ring_cache_miss_delta": ring_cache_miss_delta,
        "frame_declared_delta": frame_declared_delta,
        "frame_actual_delta": frame_actual_delta,
        "frame_missing_delta": frame_missing_delta,
        "hist_total_delta": hist_total_delta,
        "hist_drop_delta": hist_drop_delta,
        "hist_ingress_after": post_end["hist_ingress"]["raw"],
        "sc_hub_err_flags_after": post_end["sc_hub"]["err_flags"],
        "sc_hub_pkt_drop_after": post_end["sc_hub"]["pkt_drop_count"],
        "post_end_clean": post_end_clean,
        "post_end_port_status": post_end_hist["PORT_STATUS"],
        "post_end_coal_status": post_end_hist["COAL_STATUS"],
    }


def run_cycle(args: argparse.Namespace, index: int) -> dict[str, Any]:
    run_number = args.run_number_base + index
    rc_log: list[str] = []

    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "reset", settle_us=args.rc_settle_us))
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "stop-reset", settle_us=args.rc_settle_us))
    if args.post_stop_reset_ms > 0:
        time.sleep(args.post_stop_reset_ms / 1000.0)

    lane_go = configure_lvds_lanes(args.sc_tool, args.link)
    configure_histogram(args.sc_tool, args.link)
    clear_histogram(args.sc_tool, args.link)
    ingress_status = select_histogram_ingress_post(args.sc_tool, args.link)
    configure_emulators(args.sc_tool, args.link, args.hit_rate)
    overrides = apply_debug_overrides(args)

    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "run-prepare", run_number, settle_us=args.rc_settle_us))
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "sync", settle_us=args.rc_settle_us))
    if args.post_sync_ms > 0:
        time.sleep(args.post_sync_ms / 1000.0)

    before = read_stage_snapshot(args.sc_tool, args.link)
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "start-run", settle_us=args.rc_settle_us))
    time.sleep(args.duration_ms / 1000.0)
    sample = read_stage_snapshot(args.sc_tool, args.link)
    rc_log.append(rc_send(args.rc_tool, args.device, args.feb, "end-run", settle_us=args.rc_settle_us))
    if args.post_end_ms > 0:
        time.sleep(args.post_end_ms / 1000.0)
    after = read_stage_snapshot(args.sc_tool, args.link)

    summary = summarize_cycle(before, sample, after)
    return {
        "index": index,
        "run_number": run_number,
        "hit_rate": args.hit_rate,
        "duration_ms": args.duration_ms,
        "lane_go": lane_go,
        "debug_overrides": overrides,
        "ingress_status_after_select": ingress_status,
        "before": before,
        "sample": sample,
        "after": after,
        "summary": summary,
        "rc_log": rc_log,
    }


def fmt_hex(value: int) -> str:
    return f"0x{value:08X}"


def write_markdown(path: Path, args: argparse.Namespace, records: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# Phase 4 Stage Counter Probe",
        "",
        f"- Timestamp: `{dt.datetime.now().isoformat(timespec='seconds')}`",
        f"- SC link: `{args.link}`",
        f"- FEB target: `{args.feb}`",
        f"- Hit rate: `0x{args.hit_rate:04X}`",
        f"- Duration: `{args.duration_ms} ms`",
        f"- Iterations: `{len(records)}`",
        f"- Ring input-error filter override: `{args.ring_filter_inerr}`",
        f"- MTS expected latency override: `{args.mts_expected_latency}`",
        f"- MTS timestamp-delay local-drop override: `{args.mts_drop_delay_error}`",
        "",
        "## Summary",
        "",
        "| Iter | Class | Emu Frames | MTS Hits | MTS Discard | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Flush | Ingress | SC Flags | SC Drops |",
        "|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|---:|---:|---:|",
    ]
    for record in records:
        s = record["summary"]
        lines.append(
            f"| {record['index']} | `{s['classification']}` | {s['emu_frame_delta']} | "
            f"{s['mts_total_delta']} | {s['mts_discard_delta']} | {s['ring_inerr_delta']} | {s['ring_push_delta']} | {s['ring_pop_delta']} | "
            f"{s['frame_actual_delta']} | {s['hist_total_delta']} | {s['hist_drop_delta']} | "
            f"{s['frame_crc_delta']} | `{'clean' if s['post_end_clean'] else 'residue'}` | `{fmt_hex(s['hist_ingress_after'])}` | "
            f"`{fmt_hex(s['sc_hub_err_flags_after'])}` | {s['sc_hub_pkt_drop_after']} |"
        )

    lines.extend(
        [
            "",
            "## Per-Iteration Stage Detail",
            "",
        ]
    )
    for record in records:
        s = record["summary"]
        lines.extend(
            [
                f"### Iteration {record['index']}",
                "",
                f"- Classification: `{s['classification']}`",
                f"- Lane-go: `{fmt_hex(record['lane_go'])}`",
                f"- Debug overrides: `{record['debug_overrides']}`",
                f"- Ingress select status: `{fmt_hex(record['ingress_status_after_select']['raw'])}`",
                f"- Post-end flush: `{'clean' if s['post_end_clean'] else 'residue'}` "
                f"(PORT_STATUS={fmt_hex(s['post_end_port_status'])}, COAL_STATUS={fmt_hex(s['post_end_coal_status'])})",
                "",
                "| Stage | Before | Sample | Delta |",
                "|---|---:|---:|---:|",
            ]
        )
        before = record["before"]
        after = record.get("sample", record["after"])
        for idx in range(2):
            lines.append(
                f"| `mts{idx}.total_hits` | {before['mts'][idx]['total_hits']} | "
                f"{after['mts'][idx]['total_hits']} | "
                f"{counter_delta(before['mts'][idx]['total_hits'], after['mts'][idx]['total_hits'], bits=48)} |"
            )
            lines.append(
                f"| `mts{idx}.discard_hits` | {before['mts'][idx]['discard_hits']} | "
                f"{after['mts'][idx]['discard_hits']} | "
                f"{counter_delta(before['mts'][idx]['discard_hits'], after['mts'][idx]['discard_hits'])} |"
            )
        for name in RING_BASE_WORDS:
            lines.append(
                f"| `{name}.inerr/push/pop` | "
                f"{before['ring'][name]['inerr_count']}/{before['ring'][name]['push_count']}/{before['ring'][name]['pop_count']} | "
                f"{after['ring'][name]['inerr_count']}/{after['ring'][name]['push_count']}/{after['ring'][name]['pop_count']} | "
                f"{counter_delta(before['ring'][name]['inerr_count'], after['ring'][name]['inerr_count'])}/"
                f"{counter_delta(before['ring'][name]['push_count'], after['ring'][name]['push_count'])}/"
                f"{counter_delta(before['ring'][name]['pop_count'], after['ring'][name]['pop_count'])} |"
            )
        for name in FRAME_ASM_BASE_WORDS:
            lines.append(
                f"| `{name}.decl/actual/missing` | "
                f"{before['frame_asm'][name]['declared_hits']}/{before['frame_asm'][name]['actual_hits']}/{before['frame_asm'][name]['missing_hits']} | "
                f"{after['frame_asm'][name]['declared_hits']}/{after['frame_asm'][name]['actual_hits']}/{after['frame_asm'][name]['missing_hits']} | "
                f"{counter_delta(before['frame_asm'][name]['declared_hits'], after['frame_asm'][name]['declared_hits'], bits=50)}/"
                f"{counter_delta(before['frame_asm'][name]['actual_hits'], after['frame_asm'][name]['actual_hits'], bits=50)}/"
                f"{counter_delta(before['frame_asm'][name]['missing_hits'], after['frame_asm'][name]['missing_hits'], bits=50)} |"
            )
        lines.extend(
            [
                f"| `hist.total/dropped` | {before['histogram']['TOTAL_HITS']}/{before['histogram']['DROPPED_HITS']} | "
                f"{after['histogram']['TOTAL_HITS']}/{after['histogram']['DROPPED_HITS']} | "
                f"{s['hist_total_delta']}/{s['hist_drop_delta']} |",
                "",
            ]
        )

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser(description="Probe SC-visible Phase 4 datapath stage counters.")
    parser.add_argument("--link", type=int, default=2)
    parser.add_argument("--device", default="/dev/mudaq0")
    parser.add_argument("--feb", type=int, default=7)
    parser.add_argument("--run-number-base", type=int, default=5200)
    parser.add_argument("--sc-tool", type=Path, default=_default_sc_tool())
    parser.add_argument("--rc-tool", type=Path, default=default_rc_tool())
    parser.add_argument("--hit-rate", type=lambda text: int(text, 0), default=0x0800)
    parser.add_argument("--duration-ms", type=int, default=100)
    parser.add_argument("--iterations", type=int, default=4)
    parser.add_argument("--rc-settle-us", type=int, default=10000)
    parser.add_argument("--post-stop-reset-ms", type=int, default=200)
    parser.add_argument("--post-sync-ms", type=int, default=20)
    parser.add_argument("--post-end-ms", type=int, default=200)
    parser.add_argument(
        "--ring-filter-inerr",
        choices=("keep", "on", "off"),
        default="keep",
        help="Override ring CAM CTRL bit4 after reset/config. 'off' proves whether MTS error marking is the only blocker.",
    )
    parser.add_argument(
        "--mts-expected-latency",
        type=lambda text: int(text, 0),
        help="Override MTS CSR expected_latency word after reset/config.",
    )
    parser.add_argument(
        "--mts-drop-delay-error",
        choices=("keep", "on", "off"),
        default="keep",
        help="Override MTS CONTROL_STATUS bit 5. Default policy is forward with error asserted; use 'on' only to trim timestamp-error hits inside MTS.",
    )
    parser.add_argument("--stop-on-zero", action="store_true")
    parser.add_argument("--output", type=Path, default=default_output())
    parser.add_argument("--json-output", type=Path)
    args = parser.parse_args()

    records: list[dict[str, Any]] = []
    for index in range(args.iterations):
        record = run_cycle(args, index)
        records.append(record)
        s = record["summary"]
        print(
            "ITER "
            f"{index} class={s['classification']} "
            f"emu_frames={s['emu_frame_delta']} "
            f"mts_hits={s['mts_total_delta']} "
            f"ring_inerr={s['ring_inerr_delta']} "
            f"ring_push={s['ring_push_delta']} "
            f"ring_pop={s['ring_pop_delta']} "
            f"frame_actual={s['frame_actual_delta']} "
            f"hist_total={s['hist_total_delta']} "
            f"hist_drop={s['hist_drop_delta']} "
            f"flush={'clean' if s['post_end_clean'] else 'residue'}"
        )
        if args.stop_on_zero and s["hist_total_delta"] == 0:
            break

    write_markdown(args.output, args, records)
    json_path = args.json_output or args.output.with_suffix(".json")
    json_path.write_text(json.dumps(records, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    print(f"Wrote {args.output}")
    print(f"Wrote {json_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
