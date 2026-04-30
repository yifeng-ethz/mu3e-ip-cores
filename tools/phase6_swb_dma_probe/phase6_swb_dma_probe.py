#!/usr/bin/env python3
"""Standalone Phase-6 SWB DMA probe.

The probe talks to the MuDaq kernel devices directly and keeps every hardware
assumption visible in the output manifest. It is deliberately not a wrapper
around Mu3e online tools.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import mmap
import os
import struct
import sys
import time
from pathlib import Path
from typing import Any


PAGE_SIZE = os.sysconf("SC_PAGE_SIZE")
REG_WORDS = 256
DMABUF_DATA_LEN = 1 << 25
DMABUF_WORDS = DMABUF_DATA_LEN // 4
DMABUF_CTRL_WORDS = 4

REGS_RW_INDEX = 0
REGS_RO_INDEX = 1
DMABUF_CTRL_INDEX = 4

RW_REGS = {
    0x01: "RESET_REGISTER_W",
    0x03: "DATAGENERATOR_DIVIDER_REGISTER_W",
    0x0C: "GET_N_DMA_WORDS_REGISTER_W",
    0x0F: "SWB_GENERIC_MASK_REGISTER_W",
    0x10: "SWB_LINK_MASK_PIXEL_REGISTER_W",
    0x11: "SWB_LINK_MASK_SCIFI_REGISTER_W",
    0x12: "SWB_LINK_MASK_TILES_REGISTER_W",
    0x13: "SWB_READOUT_STATE_REGISTER_W",
    0x14: "SWB_READOUT_LINK_REGISTER_W",
    0x15: "SWB_COUNTER_REGISTER_W",
    0x16: "FARM_READOUT_STATE_REGISTER_W",
    0x38: "DMA_REGISTER_W",
}

RO_REGS = {
    0x01: "VERSION_REGISTER_R",
    0x1B: "BUFFER_STATUS_REGISTER_R",
    0x1C: "EVENT_BUILD_STATUS_REGISTER_R",
    0x1D: "EVENT_BUILD_IDLE_NOT_HEADER_R",
    0x1E: "EVENT_BUILD_SKIP_EVENT_DMA_R",
    0x1F: "EVENT_BUILD_CNT_EVENT_DMA_R",
    0x20: "EVENT_BUILD_TAG_FIFO_FULL_R",
    0x25: "CNT_FEB_MERGE_TIMEOUT_R",
    0x2A: "GLOBAL_TS_LOW_REGISTER_R",
    0x2B: "GLOBAL_TS_HIGH_REGISTER_R",
    0x2C: "SERIAL_NUM_REGISTER_R",
    0x32: "DMA_CNT_WORDS_REGISTER_R",
    0x33: "SWB_COUNTER_REGISTER_R",
    0x34: "SWB_LINK_COUNTER_REGISTER_R",
    0x36: "LINK_LOCKED_LOW_REGISTER_R",
    0x37: "LINK_LOCKED_HIGH_REGISTER_R",
    0x38: "DMA_STATUS_REGISTER_R",
}

RESET_BITS = {
    "DATAGEN": 1,
    "SWB_STREAM_MERGER": 2,
    "SWB_TIME_MERGER": 3,
    "DATA_PATH": 22,
    "FARM_DATA_PATH": 23,
    "FARM_STREAM_MERGER": 24,
    "FARM_TIME_MERGER": 25,
    "LINK_LOCKED": 26,
    "FARM_BLOCK": 28,
}

READOUT_BITS = {
    "GEN_LINK": 0,
    "STREAM": 1,
    "MERGER": 2,
    "PIXEL_US": 7,
    "PIXEL_DS": 8,
    "SCIFI": 9,
    "ALL": 12,
    "GENERIC": 18,
}

DEFAULT_RESET_MASK = sum(1 << bit for bit in RESET_BITS.values())


def iso_now() -> str:
    return dt.datetime.now().isoformat(timespec="milliseconds")


def hex32(value: int) -> str:
    return f"0x{value & 0xFFFFFFFF:08X}"


def parse_int(text: str) -> int:
    return int(text, 0)


def bitmask(*names: str) -> int:
    value = 0
    for name in names:
        value |= 1 << READOUT_BITS[name]
    return value


def build_readout_state(mode: str, profile: str, custom: int | None) -> int:
    if custom is not None:
        return custom & 0xFFFFFFFF

    modes = {
        "stream-links": bitmask("STREAM"),
        "time-links": bitmask("MERGER"),
        "stream-datagen": bitmask("GEN_LINK", "STREAM"),
        "time-datagen": bitmask("GEN_LINK", "MERGER"),
    }
    profiles = {
        "none": 0,
        "pixel-us": bitmask("PIXEL_US"),
        "pixel-ds": bitmask("PIXEL_DS"),
        "scifi": bitmask("SCIFI"),
        "all": bitmask("ALL"),
        "generic": bitmask("GENERIC", "ALL"),
    }
    return (modes[mode] | profiles[profile]) & 0xFFFFFFFF


def word_at(mm: mmap.mmap, idx: int) -> int:
    return struct.unpack_from("<I", mm, idx * 4)[0]


def write_word(mm: mmap.mmap, idx: int, value: int) -> None:
    struct.pack_into("<I", mm, idx * 4, value & 0xFFFFFFFF)


def read_words(mm: mmap.mmap, count: int) -> list[int]:
    return list(struct.unpack_from(f"<{count}I", mm, 0))


def snapshot_registers(rw: mmap.mmap, ro: mmap.mmap) -> dict[str, Any]:
    rw_words = read_words(rw, REG_WORDS)
    ro_words = read_words(ro, REG_WORDS)
    return {
        "timestamp": iso_now(),
        "rw_named": {name: hex32(rw_words[idx]) for idx, name in RW_REGS.items()},
        "ro_named": {name: hex32(ro_words[idx]) for idx, name in RO_REGS.items()},
        "rw_raw": [hex32(value) for value in rw_words[:64]],
        "ro_raw": [hex32(value) for value in ro_words[:64]],
    }


def sweep_counters(rw: mmap.mmap, ro: mmap.mmap, count: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for idx in range(count):
        write_word(rw, 0x15, idx)
        rows.append(
            {
                "index": idx,
                "swb_counter": hex32(word_at(ro, 0x33)),
                "swb_link_counter": hex32(word_at(ro, 0x34)),
            }
        )
    write_word(rw, 0x15, 0)
    return rows


def summarize_dmabuf(words: memoryview, *, first_word_count: int, sparse_limit: int) -> dict[str, Any]:
    total_words = len(words) // 4
    first_words: list[str] = []
    sparse: list[dict[str, Any]] = []
    nonzero = 0
    nonpadding = 0
    first_nonzero: int | None = None
    last_nonzero: int | None = None
    padding = {0x00000000, 0xFFFFFFFF, 0xAFFEAFFE}

    for idx in range(total_words):
        value = struct.unpack_from("<I", words, idx * 4)[0]
        if idx < first_word_count:
            first_words.append(hex32(value))
        if value != 0:
            nonzero += 1
            if first_nonzero is None:
                first_nonzero = idx
            last_nonzero = idx
            if len(sparse) < sparse_limit:
                sparse.append({"index": idx, "word": hex32(value)})
        if value not in padding:
            nonpadding += 1

    return {
        "total_words": total_words,
        "nonzero_words": nonzero,
        "nonpadding_words": nonpadding,
        "first_nonzero_index": first_nonzero,
        "last_nonzero_index": last_nonzero,
        "first_words": first_words,
        "first_nonzero_words": sparse,
    }


def write_text_dump(path: Path, words: memoryview) -> None:
    total_words = len(words) // 4
    with path.open("w", encoding="utf-8") as handle:
        for idx in range(total_words):
            value = struct.unpack_from("<I", words, idx * 4)[0]
            handle.write(f"{idx}\t{value:08X}\n")


def write_sparse_dump(path: Path, sparse: list[dict[str, Any]]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        handle.write("# index word\n")
        for item in sparse:
            handle.write(f"{item['index']}\t{item['word']}\n")


def write_markdown(path: Path, summary: dict[str, Any]) -> None:
    lines = [
        "# Phase 6 SWB DMA Probe",
        "",
        f"- Classification: `{summary['classification']}`",
        f"- Mode: `{summary['mode']}`",
        f"- Profile: `{summary['profile']}`",
        f"- Readout state: `{hex32(summary['readout_state'])}`",
        f"- Hold seconds: `{summary['hold_s']}`",
        f"- DMA words: total `{summary['dma']['total_words']}`, nonzero `{summary['dma']['nonzero_words']}`, nonpadding `{summary['dma']['nonpadding_words']}`",
        f"- First nonzero index: `{summary['dma']['first_nonzero_index']}`",
        f"- Last nonzero index: `{summary['dma']['last_nonzero_index']}`",
        f"- Event-build status before cleanup: `{summary['final_pre_cleanup_ro'].get('EVENT_BUILD_STATUS_REGISTER_R')}`",
        f"- Event-build count before cleanup: `{summary['final_pre_cleanup_ro'].get('EVENT_BUILD_CNT_EVENT_DMA_R')}`",
        f"- DMA count words before cleanup: `{summary['final_pre_cleanup_ro'].get('DMA_CNT_WORDS_REGISTER_R')}`",
        "",
        "## First DMA Words",
        "",
    ]
    lines.extend(f"- `{idx}` `{word}`" for idx, word in enumerate(summary["dma"]["first_words"]))
    lines.extend(["", "## First Nonzero DMA Words", ""])
    for item in summary["dma"]["first_nonzero_words"][:64]:
        lines.append(f"- `{item['index']}` `{item['word']}`")
    lines.append("")
    path.write_text("\n".join(lines), encoding="utf-8")


class MappedDevice:
    def __init__(self, device: Path, dmabuf: Path, dmabuf_len: int) -> None:
        self.device = device
        self.dmabuf = dmabuf
        self.dmabuf_len = dmabuf_len
        self.fd = -1
        self.dmabuf_fd = -1
        self.rw: mmap.mmap | None = None
        self.ro: mmap.mmap | None = None
        self.ctrl: mmap.mmap | None = None
        self.data: mmap.mmap | None = None

    def __enter__(self) -> "MappedDevice":
        self.fd = os.open(self.device, os.O_RDWR | os.O_SYNC)
        self.rw = mmap.mmap(self.fd, REG_WORDS * 4, flags=mmap.MAP_SHARED, prot=mmap.PROT_READ | mmap.PROT_WRITE, offset=REGS_RW_INDEX * PAGE_SIZE)
        self.ro = mmap.mmap(self.fd, REG_WORDS * 4, flags=mmap.MAP_SHARED, prot=mmap.PROT_READ, offset=REGS_RO_INDEX * PAGE_SIZE)
        self.ctrl = mmap.mmap(self.fd, DMABUF_CTRL_WORDS * 4, flags=mmap.MAP_SHARED, prot=mmap.PROT_READ, offset=DMABUF_CTRL_INDEX * PAGE_SIZE)
        self.dmabuf_fd = os.open(self.dmabuf, os.O_RDWR)
        self.data = mmap.mmap(self.dmabuf_fd, self.dmabuf_len, flags=mmap.MAP_SHARED, prot=mmap.PROT_READ | mmap.PROT_WRITE, offset=0)
        return self

    def __exit__(self, exc_type: object, exc: object, tb: object) -> None:
        for mm in (self.data, self.ctrl, self.ro, self.rw):
            if mm is not None:
                mm.close()
        for fd in (self.dmabuf_fd, self.fd):
            if fd >= 0:
                os.close(fd)

    def require(self) -> tuple[mmap.mmap, mmap.mmap, mmap.mmap, mmap.mmap]:
        assert self.rw is not None
        assert self.ro is not None
        assert self.ctrl is not None
        assert self.data is not None
        return self.rw, self.ro, self.ctrl, self.data


def classify(dma_summary: dict[str, Any], final_ro: dict[str, str]) -> str:
    if dma_summary["nonzero_words"] > 0:
        return "dma_nonzero"
    if final_ro.get("EVENT_BUILD_CNT_EVENT_DMA_R") not in (None, "0x00000000"):
        return "event_builder_no_dma_words"
    if final_ro.get("EVENT_BUILD_IDLE_NOT_HEADER_R") not in (None, "0x00000000"):
        return "event_builder_input_no_payload"
    return "no_dma_words"


def run_probe(args: argparse.Namespace) -> int:
    out_dir = args.out_dir.resolve()
    out_dir.mkdir(parents=True, exist_ok=True)
    snapshots_path = out_dir / "snapshots.jsonl"

    readout_state = build_readout_state(args.mode, args.profile, args.readout_state)
    mask_values = {
        "generic": args.generic_mask,
        "pixel": args.pixel_mask,
        "scifi": args.scifi_mask,
        "tiles": args.tiles_mask,
    }

    command_manifest = {
        "created": iso_now(),
        "argv": sys.argv,
        "device": str(args.device),
        "dmabuf": str(args.dmabuf),
        "mode": args.mode,
        "profile": args.profile,
        "readout_state": hex32(readout_state),
        "masks": {key: hex32(value) for key, value in mask_values.items()},
        "get_n_dma_words": args.get_n_dma_words,
        "datagen_divider": hex32(args.datagen_divider),
        "reset_mask": hex32(args.reset_mask),
        "counter_sweep_count": args.counter_sweep_count,
        "cleanup": args.cleanup,
    }
    (out_dir / "manifest.json").write_text(json.dumps(command_manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    with MappedDevice(args.device, args.dmabuf, args.dmabuf_len) as dev:
        rw, ro, ctrl, data = dev.require()
        data[:] = b"\x00" * args.dmabuf_len

        snapshots: list[dict[str, Any]] = []

        def capture(label: str) -> dict[str, Any]:
            snap = snapshot_registers(rw, ro)
            snap["label"] = label
            snap["dmabuf_ctrl"] = [hex32(word_at(ctrl, idx)) for idx in range(DMABUF_CTRL_WORDS)]
            if args.counter_sweep_count:
                snap["counter_sweep"] = sweep_counters(rw, ro, args.counter_sweep_count)
            snapshots.append(snap)
            with snapshots_path.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(snap, sort_keys=True) + "\n")
            return snap

        capture("pre_reset")
        write_word(rw, 0x38, 0)
        write_word(rw, 0x01, args.reset_mask)
        time.sleep(args.reset_us / 1_000_000.0)
        write_word(rw, 0x01, 0)
        time.sleep(args.post_reset_s)
        capture("post_reset")

        write_word(rw, 0x03, args.datagen_divider)
        write_word(rw, 0x0C, args.get_n_dma_words)
        write_word(rw, 0x0F, args.generic_mask)
        write_word(rw, 0x10, args.pixel_mask)
        write_word(rw, 0x11, args.scifi_mask)
        write_word(rw, 0x12, args.tiles_mask)
        write_word(rw, 0x13, readout_state)
        if args.write_farm_state:
            write_word(rw, 0x16, readout_state)
        time.sleep(args.post_config_s)
        capture("post_config_pre_dma")

        write_word(rw, 0x38, args.dma_control)
        capture("post_dma_enable")
        deadline = time.monotonic() + args.hold_s
        next_snapshot = time.monotonic() + args.snapshot_period_s
        while time.monotonic() < deadline:
            if args.wait_done and (word_at(ro, 0x1C) & 0x1) != 0:
                break
            now = time.monotonic()
            if args.snapshot_period_s > 0 and now >= next_snapshot:
                capture(f"during_{len(snapshots):03d}")
                next_snapshot = now + args.snapshot_period_s
            time.sleep(args.poll_s)

        final_pre_cleanup = capture("final_pre_cleanup")
        write_word(rw, 0x38, 0)
        post_disable = capture("post_dma_disable")

        dma_path = out_dir / "dma_words.bin"
        dma_path.write_bytes(data[:])
        dma_summary = summarize_dmabuf(memoryview(data), first_word_count=args.first_words, sparse_limit=args.sparse_limit)
        write_sparse_dump(out_dir / "dma_nonzero_head.txt", dma_summary["first_nonzero_words"])
        if args.dump_text:
            write_text_dump(out_dir / "memory_content.txt", memoryview(data))

        if args.cleanup:
            write_word(rw, 0x01, args.reset_mask)
            time.sleep(args.reset_us / 1_000_000.0)
            write_word(rw, 0x38, 0)
            write_word(rw, 0x03, 0)
            write_word(rw, 0x0C, 0)
            write_word(rw, 0x0F, 0)
            write_word(rw, 0x10, 0)
            write_word(rw, 0x11, 0)
            write_word(rw, 0x12, 0)
            write_word(rw, 0x13, 0)
            write_word(rw, 0x16, 0)
            write_word(rw, 0x01, 0)
            time.sleep(args.post_cleanup_s)
            cleanup_snapshot = capture("post_cleanup")
        else:
            cleanup_snapshot = None

    final_ro = final_pre_cleanup["ro_named"]
    summary = {
        "created": iso_now(),
        "classification": classify(dma_summary, final_ro),
        "mode": args.mode,
        "profile": args.profile,
        "readout_state": readout_state,
        "hold_s": args.hold_s,
        "dma_file": str(out_dir / "dma_words.bin"),
        "text_dump": str(out_dir / "memory_content.txt") if args.dump_text else None,
        "snapshots": str(snapshots_path),
        "dma": dma_summary,
        "final_pre_cleanup_ro": final_ro,
        "post_disable_ro": post_disable["ro_named"],
        "post_cleanup_ro": cleanup_snapshot["ro_named"] if cleanup_snapshot is not None else None,
        "dmabuf_ctrl_final_pre_cleanup": final_pre_cleanup["dmabuf_ctrl"],
    }
    (out_dir / "summary.json").write_text(json.dumps(summary, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    write_markdown(out_dir / "summary.md", summary)
    print(json.dumps({"classification": summary["classification"], "summary": str(out_dir / "summary.json")}, sort_keys=True))
    return 0 if summary["classification"] == "dma_nonzero" else 2


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", type=Path, default=Path("/dev/mudaq0"))
    parser.add_argument("--dmabuf", type=Path, default=Path("/dev/mudaq0_dmabuf"))
    parser.add_argument("--dmabuf-len", type=int, default=DMABUF_DATA_LEN)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument(
        "--mode",
        choices=("stream-links", "time-links", "stream-datagen", "time-datagen"),
        default="time-links",
    )
    parser.add_argument(
        "--profile",
        choices=("none", "pixel-us", "pixel-ds", "scifi", "all", "generic"),
        default="scifi",
    )
    parser.add_argument("--readout-state", type=parse_int, default=None, help="Override computed SWB/FARM readout state.")
    parser.add_argument("--generic-mask", type=parse_int, default=0)
    parser.add_argument("--pixel-mask", type=parse_int, default=0)
    parser.add_argument("--scifi-mask", type=parse_int, default=0)
    parser.add_argument("--tiles-mask", type=parse_int, default=0)
    parser.add_argument("--datagen-divider", type=parse_int, default=0x10)
    parser.add_argument(
        "--get-n-dma-words",
        type=parse_int,
        default=(DMABUF_WORDS // 2) // 8,
        help="Value written to GET_N_DMA_WORDS_REGISTER_W. The firmware interprets this in 256-bit blocks.",
    )
    parser.add_argument("--dma-control", type=parse_int, default=0x1)
    parser.add_argument("--reset-mask", type=parse_int, default=DEFAULT_RESET_MASK)
    parser.add_argument("--reset-us", type=int, default=10)
    parser.add_argument("--post-reset-s", type=float, default=0.05)
    parser.add_argument("--post-config-s", type=float, default=0.01)
    parser.add_argument("--post-cleanup-s", type=float, default=0.02)
    parser.add_argument("--hold-s", type=float, default=10.0)
    parser.add_argument("--poll-s", type=float, default=0.01)
    parser.add_argument("--snapshot-period-s", type=float, default=1.0)
    parser.add_argument("--wait-done", action="store_true")
    parser.add_argument("--write-farm-state", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--cleanup", action=argparse.BooleanOptionalAction, default=True)
    parser.add_argument("--counter-sweep-count", type=int, default=256)
    parser.add_argument("--first-words", type=int, default=64)
    parser.add_argument("--sparse-limit", type=int, default=4096)
    parser.add_argument("--dump-text", action="store_true")
    return parser.parse_args()


def main() -> int:
    return run_probe(parse_args())


if __name__ == "__main__":
    raise SystemExit(main())
