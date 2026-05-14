#!/usr/bin/env python3
"""Run RN.BASIC.001 board capture for the SWB OPQ DMA packer switch.

This script assumes the SWB image has already been programmed and PCIe has
already been recovered. It does not program the FEB. It configures the FEB
emulator/histogram path through the SWB SC hub, starts host DMA capture, drives
the local runctl opcode sequence 0x10 -> 0x11 -> 0x12 -> 1 s -> 0x13, then
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
K237 = 0xF7
USE_BIT_MERGER = 0x4
USE_BIT_SCIFI = 0x200
SCIFI_LINK2_MASK = 0x4
DEFAULT_DMA_REQUEST_BLOCKS = 0x80000
RN001_EXPECTED_CHANNELS = 256
RN001_EXPECTED_TOTAL_PER_MS = 31264
RN001_EXPECTED_PER_CHANNEL_PER_MS = RN001_EXPECTED_TOTAL_PER_MS / RN001_EXPECTED_CHANNELS
RN001_EXPECTED_THEORETICAL_PER_CHANNEL_PER_MS = 31250 / RN001_EXPECTED_CHANNELS
RN001_DELAY_EXPECTED_BY_SOURCE = {
    "pre": {"min_cycles": 27, "p50_cycles": 536, "max_cycles": 1043},
    "post": {"min_cycles": 2000, "p50_cycles": 2100, "max_cycles": 2196},
}
RN001_DEFAULT_RUN_SECONDS = 1.0
RN001_DEFAULT_HIST_INTERVAL_CLOCKS = sweep.HIST_INTERVAL_1MS_CLOCKS
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
MUDAQ_MEM_RO_INDEX = 3
MUDAQ_DMABUF_CTRL_INDEX = 4
MUDAQ_REGS_BYTES = 4096
MUDAQ_MEM_RW_BYTES = 1 << 18
MUDAQ_MEM_RO_BYTES = 1 << 18
MUDAQ_MEM_RO_WORDS = 1 << 16
MUDAQ_DMABUF_CTRL_BYTES = 4096
PACKET_TYPE_SC = 0x7
PACKET_TYPE_SC_READ = 0x0
PACKET_TYPE_SC_WRITE = 0x1
SC_TRAILER_WORD = 0x0000009C
PACKET_TYPE_SCIFI = {0b111000, 0b111001}

REG_MEM_WRITEADDR_LOW_R = 0x06
REG_DMA_STATUS_TOP_R = 0x11
REG_EVENT_BUILD_STATUS_R = 0x1C
REG_EVENT_BUILD_IDLE_NOT_HEADER_R = 0x1D
REG_EVENT_BUILD_SKIP_EVENT_DMA_R = 0x1E
REG_EVENT_BUILD_CNT_EVENT_DMA_R = 0x1F
REG_EVENT_BUILD_TAG_FIFO_FULL_R = 0x20
REG_BUFFER_STATUS_R = 0x1B
REG_DMA_CNT_WORDS_R = 0x32


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
        self.mem_ro = mmap.mmap(
            self.fd,
            MUDAQ_MEM_RO_BYTES,
            mmap.MAP_SHARED,
            mmap.PROT_READ,
            offset=MUDAQ_MEM_RO_INDEX * self.page_size,
        )
        try:
            self.dma_ctrl: Optional[mmap.mmap] = mmap.mmap(
                self.fd,
                MUDAQ_DMABUF_CTRL_BYTES,
                mmap.MAP_SHARED,
                mmap.PROT_READ,
                offset=MUDAQ_DMABUF_CTRL_INDEX * self.page_size,
            )
        except OSError:
            self.dma_ctrl = None

    def close(self) -> None:
        if self.dma_ctrl is not None:
            self.dma_ctrl.close()
        self.mem_ro.close()
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

    def read_mem_ro(self, idx: int) -> int:
        start = (idx & (MUDAQ_MEM_RO_WORDS - 1)) * 4
        return self._unpack(self.mem_ro[start:start + 4])

    def read_dma_ctrl_words(self, count: int = 8) -> list[int]:
        if self.dma_ctrl is None:
            return []
        return [self._unpack(self.dma_ctrl[idx * 4:idx * 4 + 4])
                for idx in range(count)]


def snapshot_dma_mmio(mmio: SwbMmio, label: str) -> dict[str, Any]:
    ctrl_words = mmio.read_dma_ctrl_words(8)
    ctrl3_words = (ctrl_words[3] >> 2) if len(ctrl_words) > 3 else 0
    ctrl0_words = (ctrl_words[0] * 8) if len(ctrl_words) > 0 else 0
    ctrl_write_words = ctrl3_words if ctrl3_words != 0 else ctrl0_words
    return {
        "label": label,
        "wall": time.time(),
        "rw": {
            "DMA_REGISTER_W": f"0x{mmio.read_reg_rw(REG_DMA_REGISTER_W):08X}",
            "SWB_READOUT_STATE_REGISTER_W": (
                f"0x{mmio.read_reg_rw(REG_SWB_READOUT_STATE_W):08X}"
            ),
            "FARM_READOUT_STATE_REGISTER_W": (
                f"0x{mmio.read_reg_rw(REG_FARM_READOUT_STATE_W):08X}"
            ),
            "GET_N_DMA_WORDS_REGISTER_W": (
                f"0x{mmio.read_reg_rw(0x0C):08X}"
            ),
        },
        "ro": {
            "DMA_STATUS_R": f"0x{mmio.read_reg_ro(REG_DMA_STATUS_TOP_R):08X}",
            "DMA_STATUS_REGISTER_R": f"0x{mmio.read_reg_ro(REG_DMA_STATUS_R):08X}",
            "EVENT_BUILD_STATUS_REGISTER_R": (
                f"0x{mmio.read_reg_ro(REG_EVENT_BUILD_STATUS_R):08X}"
            ),
            "EVENT_BUILD_IDLE_NOT_HEADER_R": (
                f"0x{mmio.read_reg_ro(REG_EVENT_BUILD_IDLE_NOT_HEADER_R):08X}"
            ),
            "EVENT_BUILD_SKIP_EVENT_DMA_R": (
                f"0x{mmio.read_reg_ro(REG_EVENT_BUILD_SKIP_EVENT_DMA_R):08X}"
            ),
            "EVENT_BUILD_CNT_EVENT_DMA_R": (
                f"0x{mmio.read_reg_ro(REG_EVENT_BUILD_CNT_EVENT_DMA_R):08X}"
            ),
            "EVENT_BUILD_TAG_FIFO_FULL_R": (
                f"0x{mmio.read_reg_ro(REG_EVENT_BUILD_TAG_FIFO_FULL_R):08X}"
            ),
            "BUFFER_STATUS_REGISTER_R": (
                f"0x{mmio.read_reg_ro(REG_BUFFER_STATUS_R):08X}"
            ),
            "DMA_CNT_WORDS_REGISTER_R": (
                f"0x{mmio.read_reg_ro(REG_DMA_CNT_WORDS_R):08X}"
            ),
        },
        "dma_ctrl": [f"0x{word:08X}" for word in ctrl_words],
        "dma_ctrl_write_word": (
            f"0x{ctrl_write_words:08X}" if ctrl_words else None
        ),
        "dma_ctrl_write_word_source": (
            "ctrl3_shifted" if ctrl3_words != 0 else "ctrl0_256b_lines"
        ),
    }


def enable_dma_mmio(mmio: SwbMmio) -> dict[str, str]:
    current = mmio.read_reg_rw(REG_DMA_REGISTER_W)
    if (current & 0x1) == 0:
        mmio.write_reg(REG_DMA_REGISTER_W, 0x1)
    time.sleep(0.001)
    return {
        "DMA_REGISTER_W_BEFORE": f"0x{current:08X}",
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


def sc_ring_next(ptr: int) -> int:
    return (ptr + 1) & (MUDAQ_MEM_RO_WORDS - 1)


def sc_ring_advance(ptr: int, words: int) -> int:
    return (ptr + words) & (MUDAQ_MEM_RO_WORDS - 1)


def sc_ring_distance(left: int, right: int) -> int:
    if right >= left:
        return right - left
    return (MUDAQ_MEM_RO_WORDS - left) + right


def sc_secondary_top(mmio: SwbMmio) -> int:
    return (mmio.read_reg_ro(REG_MEM_WRITEADDR_LOW_R) + 1) & (MUDAQ_MEM_RO_WORDS - 1)


def sc_scan_mmio_reply(mmio: SwbMmio, start: int, stop: int, link: int,
                       addr: int, count: int) -> Optional[dict[str, Any]]:
    ptr = start
    while ptr != stop:
        avail = sc_ring_distance(ptr, stop)
        header = mmio.read_mem_ro(ptr)
        if (header & 0x1C0000BC) != 0x1C0000BC:
            ptr = sc_ring_next(ptr)
            continue
        if avail < 4:
            return None

        addr_ptr = sc_ring_next(ptr)
        len_ptr = sc_ring_next(addr_ptr)
        addr_word = mmio.read_mem_ro(addr_ptr)
        len_word = mmio.read_mem_ro(len_ptr)
        pkt_type = (header >> 24) & 0x3
        pkt_link = (header >> 8) & 0xFF
        pkt_addr = addr_word & 0x0003FFFF
        rsp = (len_word >> 18) & 0x3
        ack = ((len_word >> 16) & 0x1) != 0
        payload_len = len_word & 0xFFFF
        total_words = 4 + payload_len
        if avail < total_words:
            return None

        trailer_ptr = sc_ring_advance(ptr, 3 + payload_len)
        trailer = mmio.read_mem_ro(trailer_ptr)
        if trailer != SC_TRAILER_WORD:
            ptr = sc_ring_next(ptr)
            continue

        payload = [
            mmio.read_mem_ro(sc_ring_advance(ptr, 3 + idx))
            for idx in range(payload_len)
        ]
        if (
            pkt_type == PACKET_TYPE_SC_READ
            and pkt_link == link
            and pkt_addr == (addr & 0x0003FFFF)
            and payload_len == count
        ):
            return {
                "start": f"0x{ptr:04X}",
                "stop": f"0x{sc_ring_advance(ptr, total_words):04X}",
                "header": f"0x{header:08X}",
                "addr": f"0x{addr_word:08X}",
                "len": f"0x{len_word:08X}",
                "rsp": rsp,
                "ack": ack,
                "payload": payload,
            }
        ptr = sc_ring_advance(ptr, total_words)
    return None


def sc_read_mmio(mmio: SwbMmio, link: int, addr: int, count: int,
                 log_fh: Any, timeout_s: float = 0.1) -> list[int]:
    """Issue one SC read through the already-open SWB MMIO mapping."""
    if count < 1:
        raise ValueError("SC read count must be >= 1")

    header = (
        (PACKET_TYPE_SC << 26)
        | (PACKET_TYPE_SC_READ << 24)
        | ((link & 0xFF) << 8)
        | K285
    )
    words = [header, addr & 0x0003FFFF, count & 0xFFFF, SC_TRAILER_WORD]
    secondary_before = sc_secondary_top(mmio)
    for idx, word in enumerate(words):
        mmio.write_mem_rw(idx, word)
    _ = mmio.read_mem_rw(len(words) - 1)

    wall_start = time.time()
    mmio.write_reg(REG_SC_MAIN_LENGTH_W, 2)
    mmio.write_reg(REG_SC_MAIN_ENABLE_W, 0)
    mmio.write_reg(REG_SC_MAIN_ENABLE_W, 1)
    time.sleep(0.0001)
    mmio.write_reg(REG_SC_MAIN_ENABLE_W, 0)

    main_ready = False
    deadline = wall_start + timeout_s
    status = 0
    while time.time() < deadline:
        status = mmio.read_reg_ro(REG_SC_MAIN_STATUS_R)
        if (status & 0x1) != 0:
            main_ready = True
            break
        time.sleep(0.001)

    if not main_ready:
        rec = {
            "addr": f"0x{addr:05X}",
            "count": count,
            "main_ready": False,
            "main_status": f"0x{status:08X}",
        }
        log_line(log_fh, "MMIO_SC_READ_FAIL: " + json.dumps(rec, sort_keys=True))
        raise RuntimeError(f"SC main did not become ready for read 0x{addr:05X}")

    while time.time() < deadline:
        secondary_after = sc_secondary_top(mmio)
        reply = sc_scan_mmio_reply(mmio, secondary_before, secondary_after,
                                   link, addr, count)
        if reply is not None:
            rec = {
                "addr": f"0x{addr:05X}",
                "count": count,
                "secondary_before": f"0x{secondary_before:04X}",
                "secondary_after": f"0x{secondary_after:04X}",
                "main_status": f"0x{status:08X}",
                "reply": {
                    **reply,
                    "payload": [f"0x{word:08X}" for word in reply["payload"]],
                },
            }
            log_line(log_fh, "MMIO_SC_READ: " + json.dumps(rec, sort_keys=True))
            if int(reply["rsp"]) != 0:
                raise RuntimeError(
                    f"SC read 0x{addr:05X} returned rsp={reply['rsp']}"
                )
            return [int(word) for word in reply["payload"]]
        time.sleep(0.001)

    rec = {
        "addr": f"0x{addr:05X}",
        "count": count,
        "secondary_before": f"0x{secondary_before:04X}",
        "secondary_after": f"0x{sc_secondary_top(mmio):04X}",
        "main_status": f"0x{status:08X}",
    }
    log_line(log_fh, "MMIO_SC_READ_FAIL: " + json.dumps(rec, sort_keys=True))
    raise RuntimeError(f"timed out waiting for SC read reply 0x{addr:05X}")


def snap_hist_mmio(mmio: SwbMmio, link: int, log_fh: Any,
                   label: str) -> dict[str, Any]:
    try:
        words = sc_read_mmio(mmio, link, sweep.HIST_CSR_BASE_WORD, 19, log_fh)
        return {
            "label": label,
            "wall": time.time(),
            "read_method": "mmio_sc_read",
            "raw": [f"0x{w:08X}" for w in words],
            "UNDERFLOW": words[sweep.HIST_UNDERFLOW_W],
            "OVERFLOW": words[sweep.HIST_OVERFLOW_W],
            "INTERVAL_CFG": words[sweep.HIST_INTERVAL_CFG_W],
            "BANK_STATUS": words[sweep.HIST_BANK_STATUS_W],
            "PORT_STATUS": words[sweep.HIST_PORT_STATUS_W],
            "TOTAL_HITS": words[sweep.HIST_TOTAL_HITS_W],
            "DROPPED_HITS": words[sweep.HIST_DROPPED_HITS_W],
            "COAL_STATUS": words[sweep.HIST_COAL_STATUS_W],
            "LAST_INTERVAL_TOTAL_HITS": (
                words[sweep.HIST_LAST_INTERVAL_TOTAL_HITS_W]
            ),
            "LAST_INTERVAL_DROPPED_HITS": (
                words[sweep.HIST_LAST_INTERVAL_DROPPED_HITS_W]
            ),
            "LAST_INT_HITS": words[sweep.HIST_LAST_INTERVAL_TOTAL_HITS_W],
        }
    except RuntimeError as exc:
        return {
            "label": label,
            "wall": time.time(),
            "read_method": "mmio_sc_read",
            "error": str(exc),
            "TOTAL_HITS": 0,
            "DROPPED_HITS": 0,
            "LAST_INTERVAL_TOTAL_HITS": 0,
            "LAST_INTERVAL_DROPPED_HITS": 0,
            "LAST_INT_HITS": 0,
            "INTERVAL_CFG": 0,
            "BANK_STATUS": 0,
            "PORT_STATUS": 0,
            "COAL_STATUS": 0,
        }


def read_hist_bins_mmio(mmio: SwbMmio, link: int, log_fh: Any,
                        max_errors: int = 8) -> tuple[list[int], dict[str, Any]]:
    bins: list[int] = []
    errors: list[dict[str, Any]] = []
    for offset in range(sweep.HIST_NUM_BINS):
        try:
            bins.append(sc_read_mmio(
                mmio, link, sweep.HIST_BIN_BASE_WORD + offset, 1, log_fh
            )[0])
        except RuntimeError as exc:
            bins.append(0)
            errors.append({
                "bin": offset,
                "addr": f"0x{sweep.HIST_BIN_BASE_WORD + offset:05X}",
                "error": str(exc),
            })
            if len(errors) >= max_errors:
                break
    attempted_count = len(bins)
    if len(bins) < sweep.HIST_NUM_BINS:
        bins.extend([0] * (sweep.HIST_NUM_BINS - len(bins)))
    return bins, {
        "read_count": attempted_count,
        "error_count": len(errors),
        "aborted": len(errors) >= max_errors,
        "errors_head": errors[:8],
    }


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


def attach_runctl_stage_timing(sc_tool: Path, link: int,
                               stage_record: dict[str, Any],
                               log_fh: Any) -> None:
    """Attach FPGA run-control log FIFO timing to the MMIO-driven recipe."""
    try:
        fifo_entries = sweep.drain_log_fifo(sc_tool, link, log_fh=log_fh)
    except RuntimeError as exc:
        stage_record["runctl_log_error"] = str(exc)
        return

    stage_record["fifo_entries"] = fifo_entries
    stage_record["log_entries_count"] = len(fifo_entries)
    stage_record["timing_source"] = "runctl_mgmt_host_log_fifo_recv_ts"
    stage_record["stage_durations"] = {
        "prepare_ms": None,
        "sync_ms": None,
        "running_s": None,
        "terminating_ms": None,
    }
    by_cmd = {
        entry.get("run_command"): entry
        for entry in fifo_entries
        if isinstance(entry, dict)
    }
    prepare_ts = by_cmd.get(sweep.CMD_RUN_PREPARE, {}).get("recv_ts")
    sync_ts = by_cmd.get(sweep.CMD_RUN_SYNC, {}).get("recv_ts")
    start_ts = by_cmd.get(sweep.CMD_START_RUN, {}).get("recv_ts")
    end_ts = by_cmd.get(sweep.CMD_END_RUN, {}).get("recv_ts")
    if prepare_ts is not None and sync_ts is not None and sync_ts >= prepare_ts:
        stage_record["stage_durations"]["prepare_ms"] = sweep.ticks_to_ms(sync_ts - prepare_ts)
    if sync_ts is not None and start_ts is not None and start_ts >= sync_ts:
        stage_record["stage_durations"]["sync_ms"] = sweep.ticks_to_ms(start_ts - sync_ts)
    if start_ts is not None and end_ts is not None and end_ts >= start_ts:
        stage_record["stage_durations"]["running_s"] = sweep.ticks_to_s(end_ts - start_ts)


def summarize_rate_histogram(hist_bins: list[int],
                             hist_interval_clocks: int) -> dict[str, Any]:
    interval_ms = hist_interval_clocks / sweep.LVDS_CLK_HZ * 1000.0
    if interval_ms <= 0.0:
        interval_ms = 1.0
    active_bins = hist_bins[:RN001_EXPECTED_CHANNELS]
    inactive_bins = hist_bins[RN001_EXPECTED_CHANNELS:]
    per_channel_per_ms = [count / interval_ms for count in active_bins]
    total_per_ms = sum(active_bins) / interval_ms
    mean_per_channel_per_ms = (
        total_per_ms / RN001_EXPECTED_CHANNELS
        if RN001_EXPECTED_CHANNELS else 0.0
    )
    max_abs_delta = max(
        (abs(value - RN001_EXPECTED_PER_CHANNEL_PER_MS)
         for value in per_channel_per_ms),
        default=0.0,
    )
    tolerance_per_channel = 8.0
    return {
        "hist_interval_clocks": hist_interval_clocks,
        "hist_interval_ms": interval_ms,
        "expected_total_per_ms": RN001_EXPECTED_TOTAL_PER_MS,
        "expected_per_channel_per_ms": RN001_EXPECTED_PER_CHANNEL_PER_MS,
        "expected_theoretical_per_channel_per_ms": (
            RN001_EXPECTED_THEORETICAL_PER_CHANNEL_PER_MS
        ),
        "total_per_ms": total_per_ms,
        "mean_per_channel_per_ms": mean_per_channel_per_ms,
        "per_channel_min_per_ms": min(per_channel_per_ms, default=0.0),
        "per_channel_p50_per_ms": sorted(per_channel_per_ms)[len(per_channel_per_ms) // 2] if per_channel_per_ms else 0.0,
        "per_channel_max_per_ms": max(per_channel_per_ms, default=0.0),
        "per_channel_max_abs_delta": max_abs_delta,
        "active_nonzero_channels": sum(1 for count in active_bins if count != 0),
        "inactive_nonzero_bins": sum(1 for count in inactive_bins if count != 0),
        "active_bin_sum": sum(active_bins),
        "inactive_bin_sum": sum(inactive_bins),
        "pass": max_abs_delta <= tolerance_per_channel,
    }


def summarize_delay_histogram(hist_bins: list[int],
                              hist_interval_clocks: int,
                              source: str = "pre") -> dict[str, Any]:
    interval_ms = hist_interval_clocks / sweep.LVDS_CLK_HZ * 1000.0
    nonzero_bins = [
        {"bin": idx, "count": count}
        for idx, count in enumerate(hist_bins)
        if count != 0
    ]
    total = sum(hist_bins)
    min_bin = nonzero_bins[0]["bin"] if nonzero_bins else None
    max_bin = nonzero_bins[-1]["bin"] if nonzero_bins else None
    p50_bin = None
    if total > 0:
        threshold = (total + 1) // 2
        running = 0
        for idx, count in enumerate(hist_bins):
            running += count
            if running >= threshold:
                p50_bin = idx
                break

    def bin_range(idx: Optional[int]) -> Optional[dict[str, int]]:
        if idx is None:
            return None
        low = sweep.HIST_DELAY_LEFT_CYCLES + idx * sweep.HIST_DELAY_BIN_WIDTH_CYCLES
        return {
            "bin": idx,
            "low_cycles": low,
            "high_cycles": low + sweep.HIST_DELAY_BIN_WIDTH_CYCLES - 1,
        }

    return {
        "hist_interval_clocks": hist_interval_clocks,
        "hist_interval_ms": interval_ms,
        "left_bound_cycles": sweep.HIST_DELAY_LEFT_CYCLES,
        "right_bound_cycles": sweep.HIST_DELAY_RIGHT_CYCLES,
        "bin_width_cycles": sweep.HIST_DELAY_BIN_WIDTH_CYCLES,
        "expected": RN001_DELAY_EXPECTED_BY_SOURCE.get(source, {}),
        "observed_min": bin_range(min_bin),
        "observed_p50": bin_range(p50_bin),
        "observed_max": bin_range(max_bin),
        "nonzero_bin_count": len(nonzero_bins),
        "nonzero_bins": nonzero_bins[:32],
        "hist_bin_sum": total,
    }


def run_stage_recipe_mmio(mmio: SwbMmio, link: int, row: dict[str, Any],
                          row_idx: int, log_fh: Any,
                          probe_period_s: float = 0.0,
                          hist_probe_period_s: float = 0.0,
                          hist_bin_sample_delays_s: Optional[list[float]] = None
                          ) -> dict[str, Any]:
    """Run RN.BASIC.001 stage commands without reopening /dev/mudaq0."""
    rid = row["row_id"]
    record: dict[str, Any] = {
        "row_idx": row_idx,
        "cmd_traces": [],
        "midrun_dma_probes": [],
        "midrun_hist_probes": [],
        "running_hist_bin_samples": [],
        "wall_clock_durations": {},
        "dma_enable_pre": enable_dma_mmio(mmio),
    }
    pending_hist_bin_delays = sorted(
        delay for delay in (hist_bin_sample_delays_s or []) if delay >= 0.0
    )

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
    run_duration_s = float(row["interval_seconds"])
    if probe_period_s > 0.0 or hist_probe_period_s > 0.0 or pending_hist_bin_delays:
        deadline = t_after_start + run_duration_s
        next_dma_probe = t_after_start if probe_period_s > 0.0 else None
        next_hist_probe = t_after_start if hist_probe_period_s > 0.0 else None
        dma_probe_idx = 0
        hist_probe_idx = 0
        bin_sample_idx = 0
        while time.time() < deadline or pending_hist_bin_delays:
            now = time.time()
            if next_dma_probe is not None and now >= next_dma_probe:
                probe = snapshot_dma_mmio(mmio, f"run_{dma_probe_idx:03d}")
                probe["elapsed_since_start_s"] = now - t_after_start
                record["midrun_dma_probes"].append(probe)
                log_line(log_fh, "MMIO_DMA_PROBE: " + json.dumps(probe, sort_keys=True))
                dma_probe_idx += 1
                next_dma_probe += probe_period_s
                while next_dma_probe <= time.time():
                    next_dma_probe += probe_period_s
            if next_hist_probe is not None and now >= next_hist_probe:
                hist = snap_hist_mmio(
                    mmio, link, log_fh, f"run_{hist_probe_idx:03d}"
                )
                hist["elapsed_since_start_s"] = now - t_after_start
                record["midrun_hist_probes"].append(hist)
                log_line(log_fh, "MMIO_HIST_PROBE: " + json.dumps(hist, sort_keys=True))
                hist_probe_idx += 1
                next_hist_probe += hist_probe_period_s
                while next_hist_probe <= time.time():
                    next_hist_probe += hist_probe_period_s
            if pending_hist_bin_delays and now >= (
                t_after_start + pending_hist_bin_delays[0]
            ):
                due_delay_s = pending_hist_bin_delays.pop(0)
                label = f"run_bins_{bin_sample_idx:03d}"
                sample_start = time.time()
                hist_before = snap_hist_mmio(mmio, link, log_fh, label + "_before")
                bins, bin_read_meta = read_hist_bins_mmio(mmio, link, log_fh)
                hist_after = snap_hist_mmio(mmio, link, log_fh, label + "_after")
                sample_end = time.time()
                sample = {
                    "label": label,
                    "requested_delay_s": due_delay_s,
                    "elapsed_start_s": sample_start - t_after_start,
                    "elapsed_end_s": sample_end - t_after_start,
                    "duration_s": sample_end - sample_start,
                    "hist_csr_before": hist_before,
                    "hist_csr_after": hist_after,
                    "bin_read": bin_read_meta,
                    "bins": bins,
                    "bins_sum": sum(bins),
                }
                record["running_hist_bin_samples"].append(sample)
                log_line(log_fh, "MMIO_HIST_BINS: " + json.dumps({
                    key: value for key, value in sample.items() if key != "bins"
                }, sort_keys=True))
                bin_sample_idx += 1
            sleep_targets: list[float] = []
            if time.time() < deadline:
                sleep_targets.append(deadline)
            if next_dma_probe is not None:
                sleep_targets.append(next_dma_probe)
            if next_hist_probe is not None:
                sleep_targets.append(next_hist_probe)
            if pending_hist_bin_delays:
                sleep_targets.append(t_after_start + pending_hist_bin_delays[0])
            sleep_until = min(sleep_targets) if sleep_targets else time.time()
            time.sleep(min(0.001, max(0.0, sleep_until - time.time())))
    else:
        time.sleep(run_duration_s)
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
    record["dma_probe_before_stop"] = snapshot_dma_mmio(mmio, "before_stop")
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


def decode_wire_frames_from_words(words: list[int]) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    frames: list[dict[str, Any]] = []
    issues: list[dict[str, Any]] = []
    idx = 0
    while idx < len(words):
        if (words[idx] & 0xFF) != K285:
            idx += 1
            continue

        start = idx
        if idx + 5 > len(words):
            issues.append({
                "word_idx": start,
                "type": "truncated_header",
                "word": f"0x{words[start]:08X}",
            })
            break

        header = decode_preamble_words(words[start:start + 5])
        packet_type = int(header.get("packet_type_raw", -1))
        if packet_type == 0:
            issues.append({
                "word_idx": start,
                "type": "idle_sop",
                "word": f"0x{words[start]:08X}",
            })
            idx += 1
            continue
        if packet_type not in PACKET_TYPE_SCIFI:
            issues.append({
                "word_idx": start,
                "type": f"unsupported_packet_type_0x{packet_type:02X}",
                "word": f"0x{words[start]:08X}",
            })
            idx += 1
            continue

        count_word = words[start + 3]
        subheader_declared = (count_word >> 16) & 0x7FFF
        hit_declared = count_word & 0xFFFF
        pos = start + 5
        subheaders: list[dict[str, Any]] = []
        hits_decoded = 0
        issue = ""

        for _ in range(subheader_declared):
            if pos >= len(words):
                issue = "truncated_subheaders"
                break
            sub_word = words[pos]
            if (sub_word & 0xFF) != K237:
                issue = f"missing_subheader_at_word_{pos}"
                break
            hit_count = (sub_word >> 8) & 0xFFFF
            subheaders.append({
                "word_idx": pos - start,
                "absolute_word_idx": pos,
                "subheader_idx": (sub_word >> 24) & 0xFF,
                "hit_count": hit_count,
                "word": f"0x{sub_word:08X}",
            })
            pos += 1
            if pos + hit_count > len(words):
                hits_decoded += max(0, len(words) - pos)
                pos = len(words)
                issue = "truncated_hits"
                break
            hits_decoded += hit_count
            pos += hit_count

        has_trailer = (
            issue == ""
            and pos < len(words)
            and (words[pos] & 0xFF) == K284
        )
        trailer_word = words[pos] if has_trailer else None
        if issue == "" and not has_trailer:
            issue = f"missing_trailer_at_word_{pos}"
        if issue == "" and hits_decoded != hit_declared:
            issue = f"hit_count_mismatch_{hits_decoded}_vs_{hit_declared}"
        if issue == "" and trailer_word is not None and (trailer_word & 0xFFFFFF00):
            issue = f"dirty_trailer_0x{trailer_word:08X}"

        frame = {
            "frame_idx": len(frames),
            "word_start": start,
            "word_end": pos if has_trailer else max(start, min(pos, len(words) - 1)),
            "byte_offset": start * 4,
            "length": ((pos + 1 - start) * 4) if has_trailer else max(0, (pos - start) * 4),
            "subheaders_decoded": len(subheaders),
            "subheader_declared": subheader_declared,
            "hits_decoded": hits_decoded,
            "hit_declared": hit_declared,
            "has_trailer": has_trailer,
            "trailer_word": f"0x{trailer_word:08X}" if trailer_word is not None else None,
            "bad": issue != "",
            "issue": issue,
            "subheaders_head": subheaders[:8],
            "subheaders_tail": subheaders[-8:],
            **header,
        }
        frames.append(frame)
        if issue != "":
            issues.append({
                "word_idx": start,
                "type": issue,
                "word": f"0x{words[start]:08X}",
            })
            idx = start + 1
        else:
            idx = pos + 1
    return frames, issues


def decode_rxbuffer(path: Path, max_decode_bytes: int,
                    valid_dma_bytes: Optional[int] = None) -> dict[str, Any]:
    raw = path.read_bytes() if path.is_file() else b""
    decode_limit = max_decode_bytes
    if valid_dma_bytes is not None and valid_dma_bytes > 0:
        decode_limit = min(decode_limit, valid_dma_bytes)
    scan = raw[:decode_limit]
    words = [
        int.from_bytes(scan[idx:idx + 4], "little")
        for idx in range(0, len(scan) - (len(scan) % 4), 4)
    ]
    frames, issues = decode_wire_frames_from_words(words)
    good_frames = [frame for frame in frames if not frame.get("bad")]
    canonical_frames = [
        frame
        for frame in good_frames
        if int(frame.get("subheader_declared", -1)) == 128
        and int(frame.get("subheaders_decoded", -1)) == 128
    ]
    ts_values = [int(frame["packet_timestamp"]) for frame in canonical_frames]
    delta_hist: dict[str, int] = {}
    for left, right in zip(ts_values, ts_values[1:]):
        delta = (right - left) & 0xFFFFFFFFFFFF
        key = f"0x{delta:X}"
        delta_hist[key] = delta_hist.get(key, 0) + 1
    subheader_counts = [
        int(frame.get("subheaders_decoded", 0))
        for frame in canonical_frames
    ]
    return {
        "path": str(path),
        "bytes_total": len(raw),
        "bytes_decoded": len(scan),
        "valid_dma_bytes": valid_dma_bytes,
        "first_32_bytes": raw[:32].hex(" "),
        "first_k285_word_lsb": bool(raw) and raw[0] == K285,
        "first_good_frame_word": good_frames[0]["word_start"] if good_frames else None,
        "first_canonical_frame_word": (
            canonical_frames[0]["word_start"] if canonical_frames else None
        ),
        "frames_decoded": len(canonical_frames),
        "good_frame_count": len(good_frames),
        "bad_frame_count": len(frames) - len(good_frames),
        "bad_frame_issues": [issue["type"] for issue in issues[:16]],
        "frame_start_count": len(frames),
        "all_decoded_frames_have_trailer": all(
            bool(frame.get("has_trailer")) for frame in good_frames
        ),
        "subheader_count_min": min(subheader_counts, default=0),
        "subheader_count_max": max(subheader_counts, default=0),
        "wire_hit_count": sum(
            int(frame.get("hits_decoded", 0)) for frame in canonical_frames
        ),
        "frame0_packet_timestamp": ts_values[0] if ts_values else None,
        "inter_frame_delta_histogram": delta_hist,
        "all_ts_delta_0x800": all(key == "0x800" for key in delta_hist.keys()),
        "frames": frames[:16],
    }


def rn_basic_001_row() -> dict[str, Any]:
    return {
        "row_id": "RN.BASIC.001",
        "lane_mask": "0xFF",
        "channel_mask": "0xFFFFFFFF",
        "rate_88fp": "0x0040",
        "hit_mode": "10",
        "interval_seconds": RN001_DEFAULT_RUN_SECONDS,
        "axis_section": "RN.BASIC.001",
        "expected_behavior": (
            "RN.BASIC.001 internal periodic all-lane/all-channel 1 s board "
            "capture with histogram INTERVAL_CFG at 1 ms"
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
    if args.interval_seconds is not None:
        row["interval_seconds"] = args.interval_seconds
        row["expected_behavior"] = (
            f"{row['expected_behavior']} with debug interval override "
            f"{args.interval_seconds:.6f} s"
        )
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
        "hist_preset": args.hist_preset,
        "hist_running_probe_period_s": args.hist_running_probe_period_s,
        "hist_running_bin_sample_s": args.hist_running_bin_sample_s,
        "evidence_dir": str(evidence_dir),
        "preenable_dma_before_capture": args.preenable_dma_before_capture,
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
        if args.hist_preset == "delay":
            record["histogram_cfg"] = sweep.configure_histogram_delay(
                args.sc_tool, args.link, args.hist_interval_clocks, log_fh=log_fh
            )
        else:
            record["histogram_cfg"] = sweep.configure_histogram_rate(
                args.sc_tool,
                args.link,
                args.hist_interval_clocks,
                source=args.hist_ingress_source,
                log_fh=log_fh,
            )
        record["ingress_status"] = sweep.select_histogram_source(
            args.sc_tool, args.link, log_fh=log_fh
        )
        record["downstream_cfg"] = sweep.configure_downstream(
            args.sc_tool, args.link, log_fh=log_fh
        )
        record["snapshot_pre"] = sweep.full_snapshot(args.sc_tool, args.link,
                                                     log_fh=log_fh)
        record["runctl_log_drain_pre_iter"] = sweep.discard_log_fifo(
            args.sc_tool, args.link, log_fh=log_fh
        )

        try:
            if args.preenable_dma_before_capture:
                with SwbMmio() as pre_mmio:
                    record["dma_pre_enable_before_capture"] = enable_dma_mmio(
                        pre_mmio
                    )
            dma_proc, dma_log_fh = start_dma_capture(
                args.dma_tool, rx_path, dma_log_path, args.staging_mb, args.af_pct
            )
            record["dma_started_at"] = dt.datetime.now().isoformat(timespec="seconds")
            with SwbMmio() as mmio:
                record["stage_recipe"] = run_stage_recipe_mmio(
                    mmio, args.link, row, row_idx, log_fh=log_fh,
                    probe_period_s=args.probe_period_s,
                    hist_probe_period_s=args.hist_running_probe_period_s,
                    hist_bin_sample_delays_s=args.hist_running_bin_sample_s,
                )
        finally:
            stop_dma_capture(dma_proc, dma_log_fh)

        attach_runctl_stage_timing(args.sc_tool, args.link,
                                   record["stage_recipe"], log_fh)
        record["snapshot_post"] = sweep.full_snapshot(args.sc_tool, args.link,
                                                      log_fh=log_fh)
        record["post_run_hist_bins"] = sweep.read_hist_bins(args.sc_tool, args.link,
                                                            log_fh=log_fh)
        running_hist_samples = record["stage_recipe"].get(
            "running_hist_bin_samples", []
        )
        if running_hist_samples:
            record["hist_bins"] = running_hist_samples[0]["bins"]
            record["hist_bins_selected_phase"] = "running"
            record["hist_bins_selected_label"] = running_hist_samples[0]["label"]
        else:
            record["hist_bins"] = record["post_run_hist_bins"]
            record["hist_bins_selected_phase"] = "post_run"
            record["hist_bins_selected_label"] = "post_run"
        record["hist_readout_policy"] = {
            "selected_phase": record["hist_bins_selected_phase"],
            "post_run_bins_valid_for_1ms_rate": False,
            "reason": (
                "With 1 ms ping-pong intervals, post-END bins normally show "
                "the last empty post-run interval; RUNNING-phase samples are "
                "the evidence used for rate comparison."
            ),
        }
        if args.hist_preset == "delay":
            record["delay_comparison"] = summarize_delay_histogram(
                record["hist_bins"], args.hist_interval_clocks,
                source=args.hist_ingress_source
            )
            record["post_run_delay_comparison"] = summarize_delay_histogram(
                record["post_run_hist_bins"], args.hist_interval_clocks,
                source=args.hist_ingress_source
            )
        else:
            record["rate_comparison"] = summarize_rate_histogram(
                record["hist_bins"], args.hist_interval_clocks
            )
            record["post_run_rate_comparison"] = summarize_rate_histogram(
                record["post_run_hist_bins"], args.hist_interval_clocks
            )
        record["cosim_expectation"] = {
            "source": "RN.BASIC.001 cosim 1 ms window",
            "total_hits_per_ms": RN001_EXPECTED_TOTAL_PER_MS,
            "per_channel_per_ms": RN001_EXPECTED_PER_CHANNEL_PER_MS,
            "active_channels": RN001_EXPECTED_CHANNELS,
        }
        record["swb_datapath_post_run"] = read_swb_datapath(
            args.sc_tool, log_fh
        )

    record["finished_at"] = dt.datetime.now().isoformat(timespec="seconds")
    valid_dma_bytes: Optional[int] = None
    try:
        dma_cnt_256b = int(
            record["swb_datapath_post_run"]["DMA_CNT_WORDS_REGISTER_R"], 16
        )
        valid_dma_bytes = dma_cnt_256b * 32
    except (KeyError, TypeError, ValueError):
        valid_dma_bytes = None
    record["rdma"] = decode_rxbuffer(
        rx_path, args.max_decode_bytes, valid_dma_bytes=valid_dma_bytes
    )
    record["pass"] = (
        record["rdma"]["first_k285_word_lsb"]
        and record["rdma"]["first_canonical_frame_word"] == 0
        and record["rdma"]["frames_decoded"] > 0
        and record["rdma"]["bad_frame_count"] == 0
        and record["rdma"]["subheader_count_min"] == 128
        and record["rdma"]["subheader_count_max"] == 128
        and record["rdma"]["frame0_packet_timestamp"] == 0
        and record["rdma"]["all_ts_delta_0x800"]
    )
    summary_path = evidence_dir / "board_summary.json"
    summary_path.write_text(json.dumps(record, indent=2) + "\n", encoding="ascii")

    print(f"evidence_dir={evidence_dir}")
    print(f"summary={summary_path}")
    print(f"rdma_rxbuffer={rx_path}")
    print(f"first_32_bytes={record['rdma']['first_32_bytes']}")
    print(f"bytes_total={record['rdma']['bytes_total']}")
    print(f"bytes_decoded={record['rdma']['bytes_decoded']}")
    print(f"frames_decoded={record['rdma']['frames_decoded']}")
    print(f"bad_frame_count={record['rdma']['bad_frame_count']}")
    print(f"wire_hit_count={record['rdma']['wire_hit_count']}")
    print(f"frame0_packet_timestamp={record['rdma']['frame0_packet_timestamp']}")
    print(f"delta_hist={record['rdma']['inter_frame_delta_histogram']}")
    print(f"hist_bins_selected_phase={record['hist_bins_selected_phase']}")
    if args.hist_preset == "delay":
        print(f"delay_comparison={record['delay_comparison']}")
        print(f"post_run_delay_comparison={record['post_run_delay_comparison']}")
    else:
        print(f"rate_comparison={record['rate_comparison']}")
        print(f"post_run_rate_comparison={record['post_run_rate_comparison']}")
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
    ap.add_argument("--hist-preset", choices=["rate", "delay"], default="rate",
                    help="histogram_statistics_v2 preset to program before START_RUN")
    ap.add_argument("--interval-seconds", type=float, default=None,
                    help="debug override for the RN.BASIC.001 START_RUN dwell")
    ap.add_argument("--hist-interval-clocks", type=lambda s: int(s, 0),
                    default=RN001_DEFAULT_HIST_INTERVAL_CLOCKS,
                    help="histogram_statistics_v2 INTERVAL_CFG; default is 1 ms at 125 MHz")
    ap.add_argument("--probe-period-s", type=float, default=0.0,
                    help="debug-only mid-run DMA/MMIO sample period")
    ap.add_argument("--hist-running-probe-period-s", type=float, default=0.0,
                    help="sample histogram CSR words during RUNNING at this period")
    ap.add_argument("--hist-running-bin-sample-s", type=float, action="append",
                    default=[],
                    help="sample all 256 histogram bins during RUNNING at this elapsed time; may be repeated")
    ap.add_argument("--preenable-dma-before-capture", action="store_true",
                    help="enable DMA before launching dma_tool so the reader snapshots a post-reset write pointer")
    args = ap.parse_args(argv)
    return run_board_capture(args)


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
