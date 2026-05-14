#!/usr/bin/env python3
"""Run RN.BASIC.001 board capture for the SWB OPQ DMA packer switch.

This script assumes the SWB image has already been programmed and PCIe has
already been recovered. It does not program the FEB. It configures the FEB
emulator/histogram path through the SWB SC hub, starts host DMA capture, drives
the local runctl opcode sequence 0x10 -> 0x11 -> 0x12 -> 1 ms -> 0x13, then
decodes the captured rxbuffer for Mu3e wire-frame markers.
"""
from __future__ import annotations

import argparse
import datetime as dt
import json
import mmap
import os
import signal
import struct
import subprocess
import sys
import time
from pathlib import Path
from typing import Any, Optional


SCRIPT = Path(__file__).resolve()
REPO_ROOT = SCRIPT.parents[6]
PHASE45_DIR = REPO_ROOT / "scripts" / "cotest"
if str(PHASE45_DIR) not in sys.path:
    sys.path.insert(0, str(PHASE45_DIR))

import phase4_5_sweep as sweep  # noqa: E402


DEFAULT_SC_TOOL = REPO_ROOT / "tools" / "run_script" / "build" / "sc_tool"
DEFAULT_DMA_TOOL = REPO_ROOT / "tools" / "run_script" / "build" / "dma_tool"
DEFAULT_OUT_ROOT = (
    REPO_ROOT
    / "firmware_builds"
    / "systems"
    / "swb"
    / "rdma_pretest-260511"
    / "tb_int"
    / "REPORT"
)
SWB_RING_LOCK = Path("/home/yifeng/.local/bin/swb_ring_lock")

K285 = 0xBC
K284 = 0x9C
USE_BIT_MERGER = 0x4
USE_BIT_SCIFI = 0x200
SCIFI_LINK2_MASK = 0x4
DEFAULT_DMA_REQUEST_BLOCKS = 0x80000
SWB_DATAPATH_RESET_MASK = (
    (1 << 1)
    | (1 << 2)
    | (1 << 3)
    | (1 << 22)
    | (1 << 24)
    | (1 << 25)
    | (1 << 26)
    | (1 << 28)
)

REG_SC_MAIN_ENABLE_W = 0x0D
REG_SC_MAIN_LENGTH_W = 0x0E
REG_SWB_GENERIC_MASK_W = 0x0F
REG_SWB_LINK_MASK_SCIFI_W = 0x11
REG_SWB_READOUT_STATE_W = 0x13
REG_FARM_READOUT_STATE_W = 0x16
REG_DMA_REGISTER_W = 0x38
REG_SC_MAIN_STATUS_R = 0x29
REG_DMA_STATUS_R = 0x38

MUDAQ_REGS_RW_INDEX = 0
MUDAQ_REGS_RO_INDEX = 1
MUDAQ_MEM_RW_INDEX = 2
MUDAQ_REGS_BYTES = 4096
MUDAQ_MEM_RW_BYTES = 1 << 18
PACKET_TYPE_SC = 0x7
PACKET_TYPE_SC_WRITE = 0x1
SC_TRAILER_WORD = 0x0000009C


def have_swb_ring_lock() -> bool:
    return sweep.have_swb_ring_lock()


def reexec_under_lock() -> None:
    if have_swb_ring_lock():
        return
    if not SWB_RING_LOCK.is_file():
        raise SystemExit(f"missing required SWB ring lock: {SWB_RING_LOCK}")
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


def log_line(log_fh: Any, line: str) -> None:
    log_fh.write(line + "\n")
    log_fh.flush()


def run_logged(cmd: list[str], log_fh: Any) -> subprocess.CompletedProcess[str]:
    log_line(log_fh, "CMD: " + " ".join(cmd))
    proc = subprocess.run(cmd, text=True, capture_output=True, timeout=30.0)
    log_line(log_fh, f"RC:  {proc.returncode}")
    if proc.stdout:
        log_line(log_fh, "OUT: " + proc.stdout.rstrip())
    if proc.stderr:
        log_line(log_fh, "ERR: " + proc.stderr.rstrip())
    log_line(log_fh, "")
    if proc.returncode != 0:
        raise RuntimeError(f"command failed rc={proc.returncode}: {' '.join(cmd)}")
    return proc


def swb_write(sc_tool: Path, name: str, value: int, log_fh: Any) -> None:
    run_logged([
        str(sc_tool),
        "--swb",
        "write",
        name,
        f"0x{value & 0xFFFFFFFF:08X}",
    ], log_fh)


def swb_read(sc_tool: Path, name: str, log_fh: Any) -> int:
    proc = run_logged([str(sc_tool), "--swb", "read", name], log_fh)
    for line in (proc.stdout + proc.stderr).splitlines():
        if "=0x" not in line:
            continue
        _, right = line.split("=", 1)
        return int(right.strip().split()[0], 16)
    raise RuntimeError(f"no SWB readback value for {name}")


def read_swb_datapath(sc_tool: Path, log_fh: Any) -> dict[str, str]:
    names = [
        "RESET_REGISTER_W",
        "SWB_LINK_MASK_SCIFI",
        "SWB_GENERIC_MASK_REGISTER_W",
        "SWB_READOUT_STATE",
        "FARM_READOUT_STATE",
        "GET_N_DMA_WORDS_REGISTER_W",
        "DMA_REGISTER",
        "DMA_STATUS_REGISTER_R",
        "EVENT_BUILD_STATUS_REGISTER_R",
        "EVENT_BUILD_IDLE_NOT_HEADER_R",
        "EVENT_BUILD_SKIP_EVENT_DMA_R",
        "EVENT_BUILD_CNT_EVENT_DMA_R",
        "EVENT_BUILD_TAG_FIFO_FULL_R",
        "BUFFER_STATUS_REGISTER_R",
        "DMA_CNT_WORDS_REGISTER_R",
    ]
    return {name: f"0x{swb_read(sc_tool, name, log_fh):08X}" for name in names}


def configure_swb_datapath(sc_tool: Path, log_fh: Any) -> dict[str, str]:
    state = USE_BIT_SCIFI | USE_BIT_MERGER
    swb_write(sc_tool, "RESET_REGISTER_W", SWB_DATAPATH_RESET_MASK, log_fh)
    swb_write(sc_tool, "SWB_LINK_MASK_SCIFI", SCIFI_LINK2_MASK, log_fh)
    swb_write(sc_tool, "SWB_GENERIC_MASK_REGISTER_W", SCIFI_LINK2_MASK, log_fh)
    swb_write(sc_tool, "SWB_READOUT_STATE", state, log_fh)
    swb_write(sc_tool, "FARM_READOUT_STATE", state, log_fh)
    swb_write(sc_tool, "GET_N_DMA_WORDS_REGISTER_W",
              DEFAULT_DMA_REQUEST_BLOCKS, log_fh)
    time.sleep(0.01)
    swb_write(sc_tool, "RESET_REGISTER_W", 0x0, log_fh)
    time.sleep(0.1)
    return read_swb_datapath(sc_tool, log_fh)


def start_dma_capture(dma_tool: Path, out_path: Path, log_path: Path,
                      staging_mb: int, af_pct: int
                      ) -> tuple[subprocess.Popen[bytes], Any]:
    log_fh = open(log_path, "wb")
    proc = subprocess.Popen(
        [
            str(dma_tool),
            "--duration-s", "0",
            "--staging-mb", str(staging_mb),
            "--af-pct", str(af_pct),
            "--out", str(out_path),
        ],
        stdout=log_fh,
        stderr=subprocess.STDOUT,
        preexec_fn=os.setsid,
    )
    time.sleep(1.0)
    if proc.poll() is not None:
        log_fh.close()
        raise RuntimeError(f"dma_tool exited early with rc={proc.returncode}")
    return proc, log_fh


def stop_dma_capture(proc: Optional[subprocess.Popen[bytes]],
                     log_fh: Optional[Any]) -> None:
    if proc is None:
        return
    if proc.poll() is None:
        os.killpg(os.getpgid(proc.pid), signal.SIGINT)
        try:
            proc.wait(timeout=10)
        except subprocess.TimeoutExpired:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
            proc.wait()
    if log_fh is not None:
        log_fh.close()


class SwbMmio:
    """Single-open SWB MMIO helper used while DMA must stay enabled."""

    def __init__(self, device: str = "/dev/mudaq0") -> None:
        self.device = device
        self.page_size = os.sysconf("SC_PAGESIZE")
        self.fd = os.open(device, os.O_RDWR | os.O_SYNC)
        self.regs_rw = mmap.mmap(
            self.fd,
            MUDAQ_REGS_BYTES,
            mmap.MAP_SHARED,
            mmap.PROT_READ | mmap.PROT_WRITE,
            offset=MUDAQ_REGS_RW_INDEX * self.page_size,
        )
        self.regs_ro = mmap.mmap(
            self.fd,
            MUDAQ_REGS_BYTES,
            mmap.MAP_SHARED,
            mmap.PROT_READ,
            offset=MUDAQ_REGS_RO_INDEX * self.page_size,
        )
        self.mem_rw = mmap.mmap(
            self.fd,
            MUDAQ_MEM_RW_BYTES,
            mmap.MAP_SHARED,
            mmap.PROT_READ | mmap.PROT_WRITE,
            offset=MUDAQ_MEM_RW_INDEX * self.page_size,
        )

    def close(self) -> None:
        self.mem_rw.close()
        self.regs_ro.close()
        self.regs_rw.close()
        os.close(self.fd)

    def __enter__(self) -> "SwbMmio":
        return self

    def __exit__(self, _exc_type: Any, _exc: Any, _tb: Any) -> None:
        self.close()

    @staticmethod
    def _pack(value: int) -> bytes:
        return struct.pack("<I", value & 0xFFFFFFFF)

    @staticmethod
    def _unpack(raw: bytes) -> int:
        return struct.unpack("<I", raw)[0]

    def write_reg(self, idx: int, value: int) -> None:
        start = idx * 4
        self.regs_rw[start:start + 4] = self._pack(value)

    def read_reg_rw(self, idx: int) -> int:
        start = idx * 4
        return self._unpack(self.regs_rw[start:start + 4])

    def read_reg_ro(self, idx: int) -> int:
        start = idx * 4
        return self._unpack(self.regs_ro[start:start + 4])

    def write_mem_rw(self, idx: int, value: int) -> None:
        start = idx * 4
        self.mem_rw[start:start + 4] = self._pack(value)

    def read_mem_rw(self, idx: int) -> int:
        start = idx * 4
        return self._unpack(self.mem_rw[start:start + 4])


def enable_dma_mmio(mmio: SwbMmio) -> dict[str, str]:
    mmio.write_reg(REG_DMA_REGISTER_W, 0x1)
    time.sleep(0.001)
    return {
        "DMA_REGISTER_W": f"0x{mmio.read_reg_rw(REG_DMA_REGISTER_W):08X}",
        "DMA_STATUS_REGISTER_R": f"0x{mmio.read_reg_ro(REG_DMA_STATUS_R):08X}",
        "SWB_READOUT_STATE_REGISTER_W": (
            f"0x{mmio.read_reg_rw(REG_SWB_READOUT_STATE_W):08X}"
        ),
    }


def sc_write_mmio(mmio: SwbMmio, link: int, addr: int, payload: list[int],
                  log_fh: Any, timeout_s: float = 1.0) -> dict[str, Any]:
    header = (
        (PACKET_TYPE_SC << 26)
        | (PACKET_TYPE_SC_WRITE << 24)
        | ((link & 0xFF) << 8)
        | K285
    )
    words = [header, addr & 0x0003FFFF, len(payload), *payload, SC_TRAILER_WORD]
    for idx, word in enumerate(words):
        mmio.write_mem_rw(idx, word)
    _ = mmio.read_mem_rw(len(words) - 1)

    main_len = 2 + len(payload)
    mmio.write_reg(REG_SC_MAIN_LENGTH_W, main_len)
    mmio.write_reg(REG_SC_MAIN_ENABLE_W, 0)
    mmio.write_reg(REG_SC_MAIN_ENABLE_W, 1)
    time.sleep(0.0001)
    mmio.write_reg(REG_SC_MAIN_ENABLE_W, 0)

    deadline = time.time() + timeout_s
    ready = False
    status = 0
    while time.time() < deadline:
        status = mmio.read_reg_ro(REG_SC_MAIN_STATUS_R)
        if (status & 0x1) != 0:
            ready = True
            break
        time.sleep(0.001)

    rec = {
        "addr": f"0x{addr:05X}",
        "payload": [f"0x{word & 0xFFFFFFFF:08X}" for word in payload],
        "words": [f"0x{word & 0xFFFFFFFF:08X}" for word in words],
        "main_length_words": main_len,
        "main_ready": ready,
        "main_status": f"0x{status:08X}",
    }
    log_line(log_fh, "MMIO_SC_WRITE: " + json.dumps(rec, sort_keys=True))
    if not ready:
        raise RuntimeError(f"SC main did not become ready for write to 0x{addr:05X}")
    return rec


def drive_local_cmd_mmio(mmio: SwbMmio, link: int, cmd: int, payload24: int,
                         log_fh: Any) -> dict[str, Any]:
    if cmd in sweep.FORBIDDEN_OPCODES:
        raise RuntimeError(f"opcode 0x{cmd:02X} is forbidden by task brief")
    word = ((payload24 & 0xFFFFFF) << 8) | (cmd & 0xFF)
    wall_start = time.time()
    sc_rec = sc_write_mmio(mmio, link, sweep.RUNCTL_LOCAL_CMD_ADDR, [word], log_fh)
    wall_end = time.time()
    return {
        "cmd": f"0x{cmd:02X}",
        "word": f"0x{word:08X}",
        "sc_write": sc_rec,
        "wall_start": wall_start,
        "wall_end": wall_end,
        "dma_after_cmd": enable_dma_mmio(mmio),
    }


def run_stage_recipe_mmio(mmio: SwbMmio, link: int, row: dict[str, Any],
                          row_idx: int, log_fh: Any) -> dict[str, Any]:
    """Run RN.BASIC.001 stage commands without reopening /dev/mudaq0."""
    rid = row["row_id"]
    record: dict[str, Any] = {
        "row_idx": row_idx,
        "cmd_traces": [],
        "wall_clock_durations": {},
        "dma_enable_pre": enable_dma_mmio(mmio),
    }

    print(f"  [{rid}] mmio step 1: GRACE_1", flush=True)
    time.sleep(sweep.GRACE_1_POST_SC_WRITE_S)

    run_number = 0xAA0000 | (row_idx & 0xFFFF)
    record["run_number_written"] = run_number
    record["run_number_write"] = sc_write_mmio(
        mmio, link, sweep.RUNCTL_RUN_NUMBER_ADDR, [run_number], log_fh
    )
    time.sleep(sweep.GRACE_3_AFTER_RUN_NUMBER_S)

    t0 = time.time()
    print(f"  [{rid}] mmio step 2: drive 0x10 RUN_PREPARE", flush=True)
    trace_prepare = drive_local_cmd_mmio(
        mmio, link, sweep.CMD_RUN_PREPARE, run_number & 0xFFFFFF, log_fh
    )
    record["cmd_traces"].append(trace_prepare)
    t_after_prepare = time.time()
    time.sleep(sweep.GRACE_STAGE_PREPARE_S)

    print(f"  [{rid}] mmio step 3: drive 0x11 RUN_SYNC", flush=True)
    trace_sync = drive_local_cmd_mmio(mmio, link, sweep.CMD_RUN_SYNC, 0, log_fh)
    record["cmd_traces"].append(trace_sync)
    t_after_sync = time.time()
    time.sleep(sweep.GRACE_STAGE_SYNC_S)

    print(f"  [{rid}] mmio step 4: drive 0x12 START_RUN", flush=True)
    trace_start = drive_local_cmd_mmio(mmio, link, sweep.CMD_START_RUN, 0, log_fh)
    record["cmd_traces"].append(trace_start)
    t_after_start = time.time()
    time.sleep(float(row["interval_seconds"]))
    t_after_run = time.time()

    print(f"  [{rid}] mmio step 5: drive 0x13 END_RUN", flush=True)
    trace_end = drive_local_cmd_mmio(mmio, link, sweep.CMD_END_RUN, 0, log_fh)
    record["cmd_traces"].append(trace_end)
    t_after_end = time.time()
    time.sleep(sweep.GRACE_STAGE_TERMINATE_S)
    t1 = time.time()

    record["wall_clock_durations"] = {
        "prepare_s": t_after_prepare - t0,
        "sync_s": t_after_sync - t_after_prepare,
        "running_s": t_after_run - t_after_start,
        "terminating_s": t1 - t_after_run,
        "total_s": t1 - t0,
    }
    record["t0_wall"] = t0
    record["t1_wall"] = t1
    record["dma_final_before_stop"] = enable_dma_mmio(mmio)
    return record


def decode_preamble_words(words: list[int]) -> dict[str, Any]:
    if len(words) < 5:
        return {
            "packet_timestamp": None,
            "packet_type_raw": None,
            "fpga_id": None,
        }
    w0, w1, w2, w3, w4 = words[:5]
    packet_type = (w0 >> 26) & 0x3F
    fpga_id = (w0 >> 8) & 0xFFFF
    packet_timestamp = ((w1 & 0xFFFFFFFF) << 16) | ((w2 >> 16) & 0xFFFF)
    return {
        "packet_type_raw": packet_type,
        "fpga_id": fpga_id,
        "packet_timestamp": packet_timestamp,
        "package_counter": w2 & 0xFFFF,
        "debug0": w3,
        "debug1": w4,
    }


def words_le(data: bytes, byte_offset: int, n_words: int) -> list[int]:
    out: list[int] = []
    for idx in range(n_words):
        start = byte_offset + idx * 4
        if start + 4 > len(data):
            break
        out.append(int.from_bytes(data[start:start + 4], "little"))
    return out


def decode_rxbuffer(path: Path, max_decode_bytes: int) -> dict[str, Any]:
    raw = path.read_bytes() if path.is_file() else b""
    scan = raw[:max_decode_bytes]
    frame_starts = [idx for idx in range(0, len(scan), 4) if scan[idx] == K285]
    trailer_offsets = {idx for idx in range(0, len(scan), 4) if scan[idx] == K284}
    frames: list[dict[str, Any]] = []
    for frame_idx, start in enumerate(frame_starts):
        next_start = (
            frame_starts[frame_idx + 1]
            if frame_idx + 1 < len(frame_starts)
            else len(scan)
        )
        trailer_pos = None
        for pos in range(start + 4, next_start, 4):
            if pos in trailer_offsets:
                trailer_pos = pos
                break
        frame_end = trailer_pos + 4 if trailer_pos is not None else next_start
        header = decode_preamble_words(words_le(scan, start, 5))
        frames.append({
            "frame_idx": frame_idx,
            "byte_offset": start,
            "length": frame_end - start,
            "trailer_offset": trailer_pos,
            "has_trailer": trailer_pos is not None,
            **header,
        })

    ts_values = [
        int(frame["packet_timestamp"])
        for frame in frames
        if frame.get("packet_timestamp") is not None
    ]
    delta_hist: dict[str, int] = {}
    for left, right in zip(ts_values, ts_values[1:]):
        delta = (right - left) & 0xFFFFFFFFFFFF
        key = f"0x{delta:X}"
        delta_hist[key] = delta_hist.get(key, 0) + 1
    frames_with_trailer = [frame for frame in frames if frame.get("has_trailer")]
    return {
        "path": str(path),
        "bytes_total": len(raw),
        "first_32_bytes": raw[:32].hex(" "),
        "first_k285_word_lsb": bool(raw) and raw[0] == K285,
        "k285_word_lsb_count": len(frame_starts),
        "k284_word_lsb_count": len(trailer_offsets),
        "frames_decoded": len(frames_with_trailer),
        "frame_start_count": len(frames),
        "all_decoded_frames_have_trailer": len(frames) == len(frames_with_trailer),
        "frame0_packet_timestamp": ts_values[0] if ts_values else None,
        "inter_frame_delta_histogram": delta_hist,
        "frames": frames[:16],
    }


def rn_basic_001_row() -> dict[str, Any]:
    return {
        "row_id": "RN.BASIC.001",
        "lane_mask": "0xFF",
        "channel_mask": "0xFFFFFFFF",
        "rate_88fp": "0x0040",
        "hit_mode": "10",
        "interval_seconds": 0.001,
        "axis_section": "RN.BASIC.001",
        "expected_behavior": (
            "RN.BASIC.001 internal periodic all-lane/all-channel 1 ms board capture"
        ),
        "sanity_negative": False,
        "bucket": "BASIC",
    }


def run_board_capture(args: argparse.Namespace) -> int:
    reexec_under_lock()
    sweep.HIST_INGRESS_SOURCE = args.hist_ingress_source
    sweep.HIST_INGRESS_BANK_COUNT = args.hist_ingress_banks
    evidence_dir = unique_evidence_dir(args.output_root, "RN.BASIC.001_swb_dma_packer")
    tool_log_path = evidence_dir / "tool_calls.log"
    rx_path = evidence_dir / "rdma_rxbuffer.bin"
    dma_log_path = evidence_dir / "dma_tool.log"
    row = rn_basic_001_row()
    row_idx = 1

    dma_proc: Optional[subprocess.Popen[bytes]] = None
    dma_log_fh: Optional[Any] = None
    record: dict[str, Any] = {
        "started_at": dt.datetime.now().isoformat(timespec="seconds"),
        "row": row,
        "sc_tool": str(args.sc_tool),
        "dma_tool": str(args.dma_tool),
        "link": args.link,
        "hist_ingress_source": args.hist_ingress_source,
        "hist_ingress_banks": args.hist_ingress_banks,
        "evidence_dir": str(evidence_dir),
    }

    with open(tool_log_path, "w", encoding="ascii") as log_fh:
        log_line(log_fh, "# run_swb_dma_packer_rn001_board.py")
        log_line(log_fh, f"# evidence_dir={evidence_dir}")

        sanity: dict[str, Any] = {}
        scratch_pattern = 0x5AA55A5A
        sweep.sc_write_stable(args.sc_tool, args.link, 0x00000,
                              [scratch_pattern], log_fh=log_fh)
        sanity["scratch_pad_ram"] = {
            "written": f"0x{scratch_pattern:08X}",
            "read": f"0x{sweep.sc_read(args.sc_tool, args.link, 0x00000, 1, log_fh=log_fh)[0]:08X}",
        }
        sanity["sc_hub_uid"] = (
            f"0x{sweep.sc_read(args.sc_tool, args.link, sweep.SC_HUB_UID_WORD, 1, log_fh=log_fh)[0]:08X}"
        )
        sanity["runctl_rx_cmd_count_pre"] = (
            f"0x{sweep.sc_read(args.sc_tool, args.link, sweep.RUNCTL_RX_CMD_ADDR, 1, log_fh=log_fh)[0]:08X}"
        )
        record["sanity"] = sanity

        record["swb_datapath_pre_run"] = configure_swb_datapath(
            args.sc_tool, log_fh
        )

        sweep.enable_lvds_lanes(args.sc_tool, args.link, log_fh=log_fh)
        record["arb_lane_cfg"] = sweep.configure_arb_lane_mask(
            args.sc_tool, args.link, int(row["lane_mask"], 16), log_fh=log_fh
        )
        record["emulator_cfg"] = sweep.configure_emulator(
            args.sc_tool,
            args.link,
            int(row["channel_mask"], 16),
            int(row["rate_88fp"], 16),
            int(row["hit_mode"], 2),
            log_fh=log_fh,
        )
        record["histogram_cfg"] = sweep.configure_histogram(
            args.sc_tool, args.link, sweep.INTERVAL_CFG_NEVER_FIRE, log_fh=log_fh
        )
        record["ingress_status"] = sweep.select_histogram_source(
            args.sc_tool, args.link, log_fh=log_fh
        )
        record["downstream_cfg"] = sweep.configure_downstream(
            args.sc_tool, args.link, log_fh=log_fh
        )
        record["snapshot_pre"] = sweep.full_snapshot(args.sc_tool, args.link,
                                                     log_fh=log_fh)

        try:
            dma_proc, dma_log_fh = start_dma_capture(
                args.dma_tool, rx_path, dma_log_path, args.staging_mb, args.af_pct
            )
            record["dma_started_at"] = dt.datetime.now().isoformat(timespec="seconds")
            with SwbMmio() as mmio:
                record["stage_recipe"] = run_stage_recipe_mmio(
                    mmio, args.link, row, row_idx, log_fh=log_fh
                )
        finally:
            stop_dma_capture(dma_proc, dma_log_fh)

        record["snapshot_post"] = sweep.full_snapshot(args.sc_tool, args.link,
                                                      log_fh=log_fh)
        record["hist_bins"] = sweep.read_hist_bins(args.sc_tool, args.link,
                                                   log_fh=log_fh)
        record["swb_datapath_post_run"] = read_swb_datapath(
            args.sc_tool, log_fh
        )

    record["finished_at"] = dt.datetime.now().isoformat(timespec="seconds")
    record["rdma"] = decode_rxbuffer(rx_path, args.max_decode_bytes)
    record["pass"] = (
        record["rdma"]["first_k285_word_lsb"]
        and record["rdma"]["frames_decoded"] > 0
        and record["rdma"]["frame0_packet_timestamp"] == 0
        and set(record["rdma"]["inter_frame_delta_histogram"].keys()) <= {"0x800"}
    )
    summary_path = evidence_dir / "board_summary.json"
    summary_path.write_text(json.dumps(record, indent=2) + "\n", encoding="ascii")

    print(f"evidence_dir={evidence_dir}")
    print(f"summary={summary_path}")
    print(f"rdma_rxbuffer={rx_path}")
    print(f"first_32_bytes={record['rdma']['first_32_bytes']}")
    print(f"frames_decoded={record['rdma']['frames_decoded']}")
    print(f"frame0_packet_timestamp={record['rdma']['frame0_packet_timestamp']}")
    print(f"delta_hist={record['rdma']['inter_frame_delta_histogram']}")
    print(f"pass={record['pass']}")
    return 0 if record["pass"] else 2


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--sc-tool", type=Path, default=DEFAULT_SC_TOOL)
    ap.add_argument("--dma-tool", type=Path, default=DEFAULT_DMA_TOOL)
    ap.add_argument("--link", type=int, default=2)
    ap.add_argument("--output-root", type=Path, default=DEFAULT_OUT_ROOT)
    ap.add_argument("--staging-mb", type=int, default=64)
    ap.add_argument("--af-pct", type=int, default=80)
    ap.add_argument("--max-decode-bytes", type=int, default=4 * 1024 * 1024)
    ap.add_argument("--hist-ingress-source", choices=["pre", "post"],
                    default="pre")
    ap.add_argument("--hist-ingress-banks", type=int, default=2)
    args = ap.parse_args(argv)
    return run_board_capture(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
