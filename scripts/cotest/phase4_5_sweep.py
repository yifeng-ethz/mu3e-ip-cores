#!/usr/bin/env python3
# ============================================================================
# phase4_5_sweep.py -- TEST_PLAN.md section 4.5 single-integrated sweep runner.
# ============================================================================
#
#   Phase 4d (TEST_PLAN.md section 4.5) histogram channel-mask, rate, and
#   hit-mode sweep for the FEB v3 emulator-type0 build. ONE script, all
#   integrated. A downstream test agent runs this with one command and zero
#   judgment calls -- every grace period, every reset window, every retry
#   strategy is baked in.
#
#   Usage (run from any cwd; script resolves paths relative to itself):
#       python3 scripts/cotest/phase4_5_sweep.py --dry-run               # preview
#       /home/yifeng/.local/bin/swb_ring_lock \
#           python3 scripts/cotest/phase4_5_sweep.py --all               # full sweep
#       /home/yifeng/.local/bin/swb_ring_lock \
#           python3 scripts/cotest/phase4_5_sweep.py --row p45_001_all_lanes_0x0000FFFF_0x0800_dir
#       python3 scripts/cotest/phase4_5_sweep.py --list                  # list row_ids
#       python3 scripts/cotest/phase4_5_sweep.py --export-plan plan.json # dump plan
#       python3 scripts/cotest/phase4_5_sweep.py --plot-smoke            # synthetic plot
#       python3 scripts/cotest/phase4_5_sweep.py --regen-table           # rebuild table
#
#   To target a different build (evidence/doc output dir) override via env var:
#       PHASE4_5_BUILD_DIR=/abs/path/to/build python3 scripts/cotest/phase4_5_sweep.py --all
#
#   Hard rules honoured:
#     - All sc_tool / rc_tool calls are routed through swb_ring_lock.
#     - hist_bin reads are SINGLE-WORD only (NOT burst). Round 3 a710b11a
#       finding: multi-word histogram-bin burst reads corrupt the SC bridge.
#     - Opcodes 0x30 / 0x31 are never issued.
#     - Python 3.10 compatible. ASCII only.
#     - NEVER os.remove / rm. Move-aside via os.rename(... + '.bak.<ts>').
#
#   This file is intentionally large to avoid splitting into multiple files.
#   Top-of-file constants define every grace period, retry count, and address
#   so the test agent can audit them without diving into call sites.
#
# ============================================================================
"""Phase 4.5 sweep runner (single integrated script).

The script orchestrates a TEST_PLAN section 4.5 sweep on a FEB v3
emulator-type0 build. Each row of the sweep matrix programs the emulator
channel-mask, the arb_hit_type0_supercore lane-mask, the emulator hit-rate
(8.8 fixed-point) and the emulator hit-mode (direct / burst / periodic),
then drives the runctl_mgmt_host LOCAL_CMD opcode sequence
0x10 -> 0x11 -> 0x12 -> (wait) -> 0x13. Pre-run and post-run CSR snapshots
are written to sweep_evidence/<row_id>/counters.json. A 2-panel
matplotlib plot of the 256-bin histogram is written to plot.png. After
each row the master table doc/PHASE4_5_SWEEP_TABLE.md is regenerated.

All grace periods are tunable via top-of-file constants. The default
profile is tuned so the test agent only has to run the script.

LIVE-vs-STABLE counter contract (histogram_statistics_v2):
    From histogram_statistics_v2_hw.tcl (verbatim):
      "TOTAL_HITS and DROPPED_HITS are LIVE CURRENT-INTERVAL counters.
       LAST_INTERVAL_TOTAL_HITS and LAST_INTERVAL_DROPPED_HITS latch the
       completed interval just before the live counters reset, allowing
       stable one-second rate polling."
    CSR offset 13 (TOTAL_HITS) is a LIVE accumulator. It resets every
    interval_pulse fires (period = HIST_INTERVAL_CFG clock cycles).
    CSR offset 17 (LAST_INTERVAL_TOTAL_HITS) is the STABLE snapshot of
    the just-completed interval (one interval window's worth).
    hist_bin[0..255] is dual-bank ping-pong SRAM; reading the inactive
    bank returns the LAST completed interval's per-channel counts.

    If HIST_INTERVAL_CFG <= run_window, multiple interval pulses fire
    DURING the run window:
      - TOTAL_HITS resets every pulse -> reads at end of run return at
        most the t=last_pulse..end_run partial (often 0).
      - LAST_INTERVAL_TOTAL_HITS holds the most recent completed interval
        only (NOT the full run total).
      - hist_bin[] returns one interval's bank, not the run total.
    To capture the full run window in TOTAL_HITS we configure
    HIST_INTERVAL_CFG = INTERVAL_CFG_NEVER_FIRE so no interval pulse
    fires during any reasonable run window; TOTAL_HITS then accumulates
    every hit from the start of the run until END_RUN drains. Reading
    TOTAL_HITS post-end-run gives the authoritative run total, and
    hist_bin[0..255] (which never bank-swaps in this configuration)
    holds the same per-channel decomposition.
"""
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
import traceback
from pathlib import Path
from typing import Any, Optional


# ============================================================================
# top-of-file constants (audit me first!)
# ============================================================================
# All grace periods, retry counts, address words, and plot ranges live here.
# Changing one of these constants changes the behaviour of the sweep -- there
# is no hidden state anywhere below.
# ----------------------------------------------------------------------------
# Grace periods (seconds)
# ----------------------------------------------------------------------------
# Per stage-timing recipe in the task brief.

GRACE_1_POST_SC_WRITE_S       = 0.200  # after CSR config writes settle
GRACE_2_AFTER_FIFO_DRAIN_S    = 0.100  # after FIFO drain, before run-number write
GRACE_3_AFTER_RUN_NUMBER_S    = 0.050  # after run-number write, before LOCAL_CMD
GRACE_STAGE_PREPARE_S         = 0.200  # after 0x10 RUN_PREPARE
GRACE_STAGE_SYNC_S            = 0.200  # after 0x11 RUN_SYNC
GRACE_STAGE_TERMINATE_S       = 0.500  # after 0x13 END_RUN -- let FIFOs drain
GRACE_IDLE_POLL_TIMEOUT_S     = 2.000  # max wait for STATUS to return to IDLE
GRACE_IDLE_POLL_PERIOD_S      = 0.025  # poll period inside idle wait

# ----------------------------------------------------------------------------
# Retry policy
# ----------------------------------------------------------------------------
SC_RETRY_COUNT                = 3      # task brief: 3 retries before fail
SC_RETRY_BACKOFF_S            = 0.100  # 100 ms backoff between retries
SC_RETRY_LINEAR               = True   # linear backoff (100ms, 200ms, 300ms)

# ----------------------------------------------------------------------------
# FIFO drain limits
# ----------------------------------------------------------------------------
LOG_FIFO_DRAIN_MAX_ITER       = 100    # hard cap to prevent infinite loops

# ----------------------------------------------------------------------------
# Histogram bin readout
# ----------------------------------------------------------------------------
HIST_NUM_BINS                 = 256    # 8-bit channel id space
HIST_BIN_READ_BURST           = False  # MUST be False (Round 3 a710b11a)

# ----------------------------------------------------------------------------
# Plot style constants live in phase4_5_plot.py (single source of truth).
# The renderers are imported lazily by _make_plots() below; keep this file
# free of matplotlib imports so --dry-run does not require it.
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# Address map (mirrored from run-control_mgmt/rtl/runctl_mgmt_host.sv and
# the v3 emulator-type0 Qsys map) -- DO NOT EDIT without confirming both.
# All addresses are SC-hub word addresses (byte_address / 4).
# ----------------------------------------------------------------------------
# runctl_mgmt_host_0 CSR base = 0x0C000 (per TEST_PLAN section 3.x)
RUNCTL_BASE_WORD                = 0x0C000
CSR_UID_W                       = 0x00      # RO
CSR_CONTROL_W                   = 0x02
CSR_STATUS_W                    = 0x03      # run-state in [23:16] host, [15:8] recv
CSR_LAST_CMD_W                  = 0x04
CSR_RUN_NUMBER_W                = 0x06      # readback of shadow_run_number
CSR_RECV_TS_L_W                 = 0x09      # 48-bit, lvdspll_clk ts of latest cmd recv
CSR_RECV_TS_H_W                 = 0x0A
CSR_EXEC_TS_L_W                 = 0x0B      # 48-bit, lvdspll_clk ts of latest exec
CSR_EXEC_TS_H_W                 = 0x0C
CSR_RX_CMD_COUNT_W              = 0x0F
CSR_RX_ERR_COUNT_W              = 0x10
CSR_LOG_STATUS_W                = 0x11
CSR_LOG_POP_W                   = 0x12      # 128-bit log entry = 4 reads of 32b
CSR_LOCAL_CMD_W                 = 0x13      # SC-side single-byte opcode driver

def runctl_addr(off: int) -> int:
    """Return absolute SC word address for a runctl_mgmt_host CSR offset."""
    return RUNCTL_BASE_WORD + off

RUNCTL_UID_ADDR        = runctl_addr(CSR_UID_W)
RUNCTL_STATUS_ADDR     = runctl_addr(CSR_STATUS_W)
RUNCTL_LAST_CMD_ADDR   = runctl_addr(CSR_LAST_CMD_W)
RUNCTL_RUN_NUMBER_ADDR = runctl_addr(CSR_RUN_NUMBER_W)
RUNCTL_RX_CMD_ADDR     = runctl_addr(CSR_RX_CMD_COUNT_W)
RUNCTL_RX_ERR_ADDR     = runctl_addr(CSR_RX_ERR_COUNT_W)
RUNCTL_LOG_STATUS_ADDR = runctl_addr(CSR_LOG_STATUS_W)
RUNCTL_LOG_POP_ADDR    = runctl_addr(CSR_LOG_POP_W)
RUNCTL_LOCAL_CMD_ADDR  = runctl_addr(CSR_LOCAL_CMD_W)
RUNCTL_RECV_TS_L_ADDR  = runctl_addr(CSR_RECV_TS_L_W)
RUNCTL_RECV_TS_H_ADDR  = runctl_addr(CSR_RECV_TS_H_W)
RUNCTL_EXEC_TS_L_ADDR  = runctl_addr(CSR_EXEC_TS_L_W)
RUNCTL_EXEC_TS_H_ADDR  = runctl_addr(CSR_EXEC_TS_H_W)

# sc_hub UID gateway -- sanity check before any sweep
SC_HUB_UID_WORD                 = 0x0FE80
SC_HUB_UID_EXPECT               = 0x53434842   # ASCII "SCHB"

# LVDS lane go (enables lvds_lane_go signal that lets emulator/arb run)
LVDS_LANE_GO_WORD               = 0x08004

# emulator_mutrig_0 base (lane unit -- single instance in v3 emulator-type0)
EMU_BASE_WORD                   = 0x08800
EMU_CHANNEL_MASK_W              = 0x05
EMU_CENTRAL_W                   = 0x07
EMU_SIGNAL_W                    = 0x08
EMU_BACKGROUND_W                = 0x09
EMU_MUTRIG_FORMAT_W             = 0x0A
EMU_RATES_W                     = 0x0B
EMU_CLUSTER_FIX_W               = 0x0C
EMU_PRNG_SEED_W                 = 0x0E
EMU_TIMEBASE_SEED_W             = 0x0F

# arb_hit_type0_supercore -- 8 lanes, each 0x20 words wide
ARB_BASE_WORD                   = 0x088A0
ARB_STRIDE_WORD                 = 0x20
ARB_MODE_OFFSET_W               = 0x03      # lane enable bit at [0]
ARB_INGRESS_EMU_LO_W            = 0x0C
ARB_INGRESS_EMU_HI_W            = 0x0D
ARB_DROPS_EMU_LO_W              = 0x10
ARB_DROPS_EMU_HI_W              = 0x11
ARB_EGRESS_EMU_LO_W             = 0x14
ARB_EGRESS_EMU_HI_W             = 0x15

# histogram_statistics_v2 bin RAM and CSR
HIST_BIN_BASE_WORD              = 0x0A800   # 256 bins, ONE word each
HIST_CSR_BASE_WORD              = 0x0A900
HIST_CONTROL_W                  = 0x02
HIST_LEFT_BOUND_W               = 0x03
HIST_RIGHT_BOUND_W              = 0x04
HIST_BIN_WIDTH_W                = 0x05
HIST_KEY_LOC_W                  = 0x06
HIST_UNDERFLOW_W                = 0x08
HIST_OVERFLOW_W                 = 0x09
HIST_INTERVAL_CFG_W             = 0x0A
HIST_BANK_STATUS_W              = 0x0B
HIST_PORT_STATUS_W              = 0x0C
HIST_TOTAL_HITS_W               = 0x0D    # CSR 13 -- LIVE current-interval accepted-hit counter (resets at every interval_pulse)
HIST_DROPPED_HITS_W             = 0x0E    # CSR 14 -- LIVE current-interval dropped-hit counter
HIST_COAL_STATUS_W              = 0x0F
HIST_SCRATCH_W                  = 0x10    # CSR 16 -- general-purpose RW scratch (was mislabelled LAST_INT_HITS_W in earlier revisions)
HIST_LAST_INTERVAL_TOTAL_HITS_W = 0x11    # CSR 17 -- STABLE: hits latched at the most recent interval_pulse before the live counter reset
HIST_LAST_INTERVAL_DROPPED_HITS_W = 0x12  # CSR 18 -- STABLE: dropped-hits latched at the most recent interval_pulse
HIST_INGRESS_BASE_WORD          = 0x0AB00
HIST_INGRESS_BANK_BASE_WORDS    = [0x0AB00, 0x0AB10]
HIST_INGRESS_CONTROL_W          = 0x02
HIST_INGRESS_STATUS_W           = 0x03

# MTS hit_type1 payload: ASIC[38:35], channel[34:30].
HIST_KEY_LOC_CHANNEL_POST       = (38 << 24) | (35 << 16) | (34 << 8) | 30

# mts_preprocessor_0 / _1
MTS_BASE_WORDS                  = [0x09000, 0x0A000]
MTS_CTRL_GO                     = 1 << 0
MTS_CTRL_DISCARD_HITERR         = 1 << 4
MTS_CTRL_DELAY_TS_USE_T         = 1 << 29
MTS_CTRL_DEFAULT                = MTS_CTRL_GO | MTS_CTRL_DISCARD_HITERR | MTS_CTRL_DELAY_TS_USE_T

# ring_buffer_cam_0..7 (HSS0 = lanes 0..3, HSS1 = lanes 4..7)
RING_CTRL_GO                    = 0x00000001
RING_CTRL_FILTER_INERR          = 0x00000010
RING_CTRL_DEFAULT               = RING_CTRL_GO | RING_CTRL_FILTER_INERR
RING_BASE_WORDS = {
    "hs0_rb0": 0x0AC00, "hs0_rb1": 0x0AC20,
    "hs0_rb2": 0x0AC40, "hs0_rb3": 0x0AC60,
    "hs1_rb0": 0x0AD00, "hs1_rb1": 0x0AD20,
    "hs1_rb2": 0x0AD40, "hs1_rb3": 0x0AD60,
}

# feb_frame_assembly_HSS0 / HSS1
FRAME_ASM_BASE_WORDS = {
    "hs0_frame": 0x0B400,
    "hs1_frame": 0x0B410,
}

# runctl_mgmt_host run command opcodes (LOCAL_CMD payload)
CMD_RUN_PREPARE                 = 0x10
CMD_RUN_SYNC                    = 0x11
CMD_START_RUN                   = 0x12
CMD_END_RUN                     = 0x13
# Forbidden by task brief
FORBIDDEN_OPCODES               = {0x30, 0x31}

# lvdspll_clk = 125 MHz; 1 tick = 8 ns
LVDS_CLK_HZ                     = 125_000_000
TICK_NS                         = 8.0

# Stage units (task brief): PREPARE/SYNC/TERMINATING in ms, RUNNING in s
def ticks_to_ms(ticks: int) -> float:
    return ticks * TICK_NS / 1.0e6

def ticks_to_s(ticks: int) -> float:
    return ticks * TICK_NS / 1.0e9

# ----------------------------------------------------------------------------
# Path layout (absolute, computed from __file__ so cwd can be anything)
# ----------------------------------------------------------------------------
# Script lives at <REPO_ROOT>/scripts/cotest/phase4_5_sweep.py.
# Evidence + doc live under a build dir (default: v3_pretest-260511
# emulator-type0). Override via env var PHASE4_5_BUILD_DIR=/abs/path.
SCRIPT_DIR    = Path(__file__).resolve().parent

def _find_repo_root(start: Path) -> Path:
    """Walk up from `start` to find the mu3e-ip-cores repo root.

    Marker: a directory containing both `firmware_builds/` and
    `tools/run_script/`. Raises RuntimeError if not found.
    """
    for p in [start, *start.parents]:
        if (p / "firmware_builds").is_dir() and (p / "tools" / "run_script").is_dir():
            return p
    raise RuntimeError(f"Could not locate mu3e-ip-cores repo root from {start}")

REPO_ROOT     = _find_repo_root(SCRIPT_DIR)
DEFAULT_BUILD_DIR_REL = "firmware_builds/systems/v3_pretest-260511-emulator-type0-260512"
_env_build = os.environ.get("PHASE4_5_BUILD_DIR", "").strip()
BUILD_DIR     = (Path(_env_build).expanduser().resolve()
                 if _env_build else REPO_ROOT / DEFAULT_BUILD_DIR_REL)
EVIDENCE_ROOT = BUILD_DIR / "sweep_evidence"
DOC_DIR       = BUILD_DIR / "doc"
TABLE_PATH    = DOC_DIR / "PHASE4_5_SWEEP_TABLE.md"
DEFAULT_SC_TOOL = REPO_ROOT / "tools" / "run_script" / "build" / "sc_tool"
DEFAULT_LINK    = 2
_dualport_build = "dualport" in BUILD_DIR.name
HIST_INGRESS_SOURCE = os.environ.get(
    "PHASE4_5_HIST_INGRESS_SOURCE",
    "pre" if _dualport_build else "post",
).strip().lower()
HIST_INGRESS_BANK_COUNT = int(os.environ.get(
    "PHASE4_5_HIST_INGRESS_BANKS",
    "2" if _dualport_build else "1",
))
if HIST_INGRESS_SOURCE not in {"pre", "post"}:
    raise RuntimeError("PHASE4_5_HIST_INGRESS_SOURCE must be 'pre' or 'post'")
if HIST_INGRESS_BANK_COUNT < 1 or HIST_INGRESS_BANK_COUNT > 2:
    raise RuntimeError("PHASE4_5_HIST_INGRESS_BANKS must be 1 or 2")

# ============================================================================
# Sweep matrix (inline -- no external JSON)
# ============================================================================
# Schema per row:
#   row_id             unique identifier (used as sweep_evidence/<row_id>/)
#   lane_mask          arb_hit_type0_supercore lane admit mask (8 bits)
#   channel_mask       emulator inject channel mask (32 bits)
#   rate_88fp          emulator 8.8 fixed-point hit rate (16 bits)
#   hit_mode           emulator hit-mode: "00"=direct, "01"=burst, "11"=periodic
#   interval_seconds   RUNNING window in seconds (default 4.0)
#   expected_behavior  human-readable note
#   axis_section       TEST_PLAN section that owns this row
#   sanity_negative    bool -- if True, total_hits == 0 is the PASS condition
#
# All numeric fields are strings (hex or 2-digit binary) to keep JSON export
# stable across editors.
# ----------------------------------------------------------------------------

DEFAULT_INTERVAL_S   = 4.0
DEFAULT_INTERVAL_CK  = int(DEFAULT_INTERVAL_S * LVDS_CLK_HZ)  # 500M cycles

# ----------------------------------------------------------------------------
# INTERVAL_CFG "never fire within the run window" value
# ----------------------------------------------------------------------------
# histogram_statistics_v2 owns a LIVE current-interval counter
# (csr_total_hits, CSR 13) that resets at every interval_pulse. The
# pulse fires every HIST_INTERVAL_CFG clock cycles (lvdspll_clk = 125 MHz
# -> 8 ns/tick). When INTERVAL_CFG <= run window, multiple interval
# pulses fire DURING the run, and the post-end-run TOTAL_HITS read returns
# at most the t=last_pulse..end_run partial -- frequently 0.
#
# We need TOTAL_HITS (and the ping-pong hist_bin bank) to accumulate
# the full run window. Setting INTERVAL_CFG to its maximum 32-bit value
# (0xFFFFFFFF = 4294967295 cycles = ~34.36 s @ 125 MHz) ensures no
# interval_pulse fires for any reasonable test run.
#
# Hard safety check below: if a row's interval_seconds exceeds
# INTERVAL_CFG_NEVER_FIRE_S we refuse to start the row (would require
# a different strategy: manual interval_reset between runs).
INTERVAL_CFG_NEVER_FIRE   = 0xFFFFFFFF                          # max 32-bit
INTERVAL_CFG_NEVER_FIRE_S = INTERVAL_CFG_NEVER_FIRE / LVDS_CLK_HZ # ~34.36 s


def _row(row_id: str, lane_mask: str, channel_mask: str, rate: str,
         mode: str, axis: str, expect: str, *,
         interval_seconds: float = DEFAULT_INTERVAL_S,
         sanity_negative: bool = False) -> dict[str, Any]:
    return {
        "row_id":            row_id,
        "lane_mask":         lane_mask,
        "channel_mask":      channel_mask,
        "rate_88fp":         rate,
        "hit_mode":          mode,
        "interval_seconds":  interval_seconds,
        "axis_section":      axis,
        "expected_behavior": expect,
        "sanity_negative":   sanity_negative,
    }


def build_plan() -> list[dict[str, Any]]:
    """Return ~32 sweep rows covering channel_mask, lane_mask, rate, hit_mode.

    Axes per task brief:
      lane_mask    : 0xFF, lane_N_only x8, 0x55, 0xAA, 0x00
      channel_mask : 0xFFFFFFFF, 0x0000FFFF, 0xFFFF0000, 0x55555555,
                     0xAAAAAAAA, 0x00000001
      rate_88fp    : 0x0100, 0x0400, 0x0800 (default), 0x1000, 0x2000,
                     0x4000, 0x8000
      hit_mode     : "00" direct, "01" burst, "11" periodic

    Coverage:
      section 4.5.1 channel-mask     :  6 rows  (default lane/rate/mode)
      lane isolation                 :  8 rows  (single-lane sweep)
      section 4.5.2 rate-doubling    :  7 rows  (default lane/channel/mode)
      section 4.5.3 hit-mode         :  2 rows  (burst + periodic)
      cross-products + sanity-neg    :  9 rows
      ----------------------------------------------------------------
      TOTAL                          : 32 rows
    """
    rows: list[dict[str, Any]] = []

    # section 4.5.1 channel-mask sweep (6 rows)
    cm_set = [
        ("0xFFFFFFFF", "all 32 channels populated (Poisson spread)"),
        ("0x0000FFFF", "channels 0..15 populated; bins 16..31 = 0"),
        ("0xFFFF0000", "channels 16..31 populated; bins 0..15 = 0"),
        ("0x55555555", "even channels populated; odd bins = 0"),
        ("0xAAAAAAAA", "odd channels populated; even bins = 0"),
        ("0x00000001", "single channel 0; bins 1..31 = 0"),
    ]
    for i, (cm, desc) in enumerate(cm_set):
        rows.append(_row(
            f"p45_{i:03d}_all_lanes_{cm}_default_dir",
            lane_mask="0xFF", channel_mask=cm, rate="0x0800",
            mode="00", axis="4.5.1",
            expect=f"section 4.5.1: {desc}; UNDERFLOW=0 OVERFLOW=0",
        ))

    # lane isolation sweep (8 rows): each single-lane admitted
    for lane in range(8):
        rows.append(_row(
            f"p45_{6+lane:03d}_lane{lane}_only_default_default_dir",
            lane_mask=f"0x{(1 << lane):02X}",
            channel_mask="0xFFFFFFFF",
            rate="0x0800", mode="00", axis="4.5.lane_iso",
            expect=f"lane {lane} admit-only; TOTAL_HITS ~= 1/8 of baseline",
        ))

    # section 4.5.2 rate sweep (7 rows)
    rates = ["0x0100", "0x0400", "0x0800", "0x1000",
             "0x2000", "0x4000", "0x8000"]
    for i, r in enumerate(rates):
        rows.append(_row(
            f"p45_{14+i:03d}_all_lanes_default_{r}_dir",
            lane_mask="0xFF", channel_mask="0xFFFFFFFF",
            rate=r, mode="00", axis="4.5.2",
            expect=f"section 4.5.2 rate {r}; ratio_to_prev ~= 2.0 until knee",
        ))

    # section 4.5.3 hit-mode (2 rows)
    rows.append(_row(
        "p45_021_all_lanes_default_default_burst",
        lane_mask="0xFF", channel_mask="0xFFFFFFFF",
        rate="0x0800", mode="01", axis="4.5.3",
        expect="section 4.5.3 burst-mode cluster centered at burst_center",
    ))
    rows.append(_row(
        "p45_022_all_lanes_default_default_periodic",
        lane_mask="0xFF", channel_mask="0xFFFFFFFF",
        rate="0x0800", mode="11", axis="4.5.3",
        expect="section 4.5.3 periodic-mode delta-function histogram",
    ))

    # cross-products + sanity-negative (9 rows)
    rows.append(_row(
        "p45_023_lane_evens_default_default_dir",
        lane_mask="0x55", channel_mask="0xFFFFFFFF",
        rate="0x0800", mode="00", axis="4.5.cross",
        expect="even lanes only; TOTAL_HITS ~= 4/8 of all-lanes baseline",
    ))
    rows.append(_row(
        "p45_024_lane_odds_default_default_dir",
        lane_mask="0xAA", channel_mask="0xFFFFFFFF",
        rate="0x0800", mode="00", axis="4.5.cross",
        expect="odd lanes only; TOTAL_HITS ~= 4/8 of all-lanes baseline",
    ))
    rows.append(_row(
        "p45_025_lane_none_default_default_dir",
        lane_mask="0x00", channel_mask="0xFFFFFFFF",
        rate="0x0800", mode="00", axis="4.5.sanity-neg",
        expect="sanity-negative: TOTAL_HITS == 0 (all lanes blocked)",
        sanity_negative=True,
    ))
    rows.append(_row(
        "p45_026_lane0only_0x0000FFFF_default_dir",
        lane_mask="0x01", channel_mask="0x0000FFFF",
        rate="0x0800", mode="00", axis="4.5.cross",
        expect="channel passes (low half) but only lane 0 admitted",
    ))
    rows.append(_row(
        "p45_027_lane_evens_0x55555555_default_dir",
        lane_mask="0x55", channel_mask="0x55555555",
        rate="0x0800", mode="00", axis="4.5.cross",
        expect="even lanes x even channels; double-even selection",
    ))
    rows.append(_row(
        "p45_028_lane_odds_0xAAAAAAAA_default_dir",
        lane_mask="0xAA", channel_mask="0xAAAAAAAA",
        rate="0x0800", mode="00", axis="4.5.cross",
        expect="odd lanes x odd channels; double-odd selection",
    ))
    rows.append(_row(
        "p45_029_lane0only_0x00000001_default_dir",
        lane_mask="0x01", channel_mask="0x00000001",
        rate="0x0800", mode="00", axis="4.5.cross",
        expect="most-restrictive: only lane 0 channel 0 populated",
    ))
    rows.append(_row(
        "p45_030_lane_evens_default_0x2000_dir",
        lane_mask="0x55", channel_mask="0xFFFFFFFF",
        rate="0x2000", mode="00", axis="4.5.cross",
        expect="even lanes x high rate; per-lane saturation check",
    ))
    rows.append(_row(
        "p45_031_lane_none_0x00000001_default_dir",
        lane_mask="0x00", channel_mask="0x00000001",
        rate="0x0800", mode="00", axis="4.5.sanity-neg",
        expect="sanity-negative: lane mask supersedes channel mask",
        sanity_negative=True,
    ))

    return rows


# ============================================================================
# tool call helpers (sc_tool / swb_ring_lock convention)
# ============================================================================
# All sc_tool invocations follow the run_phase4_emutype0_board_probe.py
# convention (commit a710b11a): sc_tool <link> read|write 0x<word> [args]
# --quiet, parse payload[n]=0xVAL from stdout, retry on returncode!=0 or
# rsp=SLVERR/DECERR.
# ----------------------------------------------------------------------------

PAYLOAD_RE = re.compile(r"payload\[(\d+)\]\s*=\s*(0x[0-9A-Fa-f]+)")
SLVERR_RE  = re.compile(r"rsp\s*:\s*(SLVERR|DECERR)")


def _cmd_str(cmd: list[str]) -> str:
    return " ".join(str(c) for c in cmd)


def _log(log_fh: Optional[Any], line: str) -> None:
    if log_fh is not None:
        log_fh.write(line + "\n")
        log_fh.flush()


def _run_subprocess(cmd: list[str], log_fh: Optional[Any] = None
                    ) -> subprocess.CompletedProcess[str]:
    _log(log_fh, f"CMD: {_cmd_str(cmd)}")
    try:
        proc = subprocess.run(cmd, text=True, capture_output=True, timeout=30.0)
    except subprocess.TimeoutExpired as exc:
        _log(log_fh, f"TIMEOUT: {exc}")
        raise
    _log(log_fh, f"RC:  {proc.returncode}")
    if proc.stdout:
        _log(log_fh, f"OUT: {proc.stdout.rstrip()}")
    if proc.stderr:
        _log(log_fh, f"ERR: {proc.stderr.rstrip()}")
    _log(log_fh, "")
    return proc


def parse_payload(text: str) -> list[int]:
    return [int(m.group(2), 16) for m in PAYLOAD_RE.finditer(text)]


def sc_read(sc_tool: Path, link: int, addr: int, count: int = 1,
            log_fh: Optional[Any] = None) -> list[int]:
    """Single SC read with structured retry.

    Returns a list of `count` 32-bit ints. Raises RuntimeError after
    SC_RETRY_COUNT failures, with a structured failure message that the
    test agent can log without parsing a Python traceback.
    """
    cmd = [str(sc_tool), str(link), "read", f"0x{addr:05X}",
           str(count), "--quiet"]
    last_text = ""
    last_rc = -1
    for attempt in range(SC_RETRY_COUNT + 1):
        proc = _run_subprocess(cmd, log_fh=log_fh)
        last_text = proc.stdout + proc.stderr
        last_rc   = proc.returncode
        words = parse_payload(last_text)
        if proc.returncode == 0 and len(words) == count:
            return words
        if attempt < SC_RETRY_COUNT:
            backoff = SC_RETRY_BACKOFF_S * (
                (attempt + 1) if SC_RETRY_LINEAR else 1
            )
            _log(log_fh, f"RETRY: sc_read addr=0x{addr:05X} attempt={attempt+1} "
                          f"backoff={backoff:.3f}s")
            time.sleep(backoff)
    raise RuntimeError(
        f"sc_read failed addr=0x{addr:05X} count={count} "
        f"rc={last_rc} retries={SC_RETRY_COUNT} "
        f"tail={last_text[-200:]!r}"
    )


def sc_write(sc_tool: Path, link: int, addr: int, words: list[int],
             log_fh: Optional[Any] = None) -> str:
    """Single SC write with structured retry on rc!=0 or SLVERR/DECERR."""
    cmd = [str(sc_tool), str(link), "write", f"0x{addr:05X}",
           *[f"0x{w & 0xFFFFFFFF:08X}" for w in words], "--quiet"]
    last_text = ""
    last_rc = -1
    for attempt in range(SC_RETRY_COUNT + 1):
        proc = _run_subprocess(cmd, log_fh=log_fh)
        last_text = proc.stdout + proc.stderr
        last_rc   = proc.returncode
        if proc.returncode == 0 and not SLVERR_RE.search(last_text):
            return last_text
        if attempt < SC_RETRY_COUNT:
            backoff = SC_RETRY_BACKOFF_S * (
                (attempt + 1) if SC_RETRY_LINEAR else 1
            )
            _log(log_fh, f"RETRY: sc_write addr=0x{addr:05X} attempt={attempt+1} "
                          f"backoff={backoff:.3f}s")
            time.sleep(backoff)
    raise RuntimeError(
        f"sc_write failed addr=0x{addr:05X} words={words} "
        f"rc={last_rc} retries={SC_RETRY_COUNT} "
        f"tail={last_text[-200:]!r}"
    )


def sc_write_stable(sc_tool: Path, link: int, addr: int, words: list[int],
                    log_fh: Optional[Any] = None) -> None:
    """Double-write: sc_hub V2 sometimes loses the first SC write after a long
    idle. The Round 3 board probe convention does the write twice. The grace
    period between writes is implicit in the swb_ring_lock guard-ms."""
    sc_write(sc_tool, link, addr, words, log_fh=log_fh)
    sc_write(sc_tool, link, addr, words, log_fh=log_fh)


def read_u48_pair(sc_tool: Path, link: int, lo_addr: int, hi_addr: int,
                  log_fh: Optional[Any] = None) -> int:
    lo = sc_read(sc_tool, link, lo_addr, 1, log_fh=log_fh)[0]
    hi = sc_read(sc_tool, link, hi_addr, 1, log_fh=log_fh)[0]
    return (lo & 0xFFFFFFFF) | ((hi & 0xFFFF) << 32)


def read_u64_pair_from_words(words: list[int], lo_idx: int, hi_idx: int) -> int:
    return (words[lo_idx] & 0xFFFFFFFF) | ((words[hi_idx] & 0xFFFFFFFF) << 32)


# ============================================================================
# LOG_POP decoder (128-bit log entry, 4 x 32-bit reads)
# ============================================================================
# Format per runctl_mgmt_host.sv:
#   [127:80] = recv_ts[47:0]
#   [79:72]  = run_command[7:0]
#   [71:64]  = reserved (0)
#   [63:32]  = payload32 (run_number for RUN_PREPARE)
#   [31:0]   = exec_ts[31:0]
#
# Wire order: 4 consecutive 32-bit reads of CSR_LOG_POP, MSB-first.
#   read[0] = bits [127:96]    -> recv_ts[47:16]
#   read[1] = bits [95:64]     -> recv_ts[15:0] | run_command[7:0] | 8'h00
#   read[2] = bits [63:32]     -> payload32
#   read[3] = bits [31:0]      -> exec_ts[31:0]
# ----------------------------------------------------------------------------

def log_pop_pop_entry(sc_tool: Path, link: int,
                      log_fh: Optional[Any] = None) -> Optional[dict[str, Any]]:
    """Pop one log entry. Returns None if the FIFO was empty."""
    status = sc_read(sc_tool, link, RUNCTL_LOG_STATUS_ADDR, 1, log_fh=log_fh)[0]
    log_empty = bool((status >> 16) & 0x1)
    depth = status & 0xFFFF
    if log_empty or depth == 0:
        return None
    words: list[int] = []
    for _ in range(4):
        words.append(sc_read(sc_tool, link, RUNCTL_LOG_POP_ADDR, 1,
                              log_fh=log_fh)[0])
    if len(words) != 4:
        return None
    return decode_log_entry(words)


def decode_log_entry(words: list[int]) -> dict[str, Any]:
    """Decode 4 x 32-bit reads into a single log entry dict."""
    w0, w1, w2, w3 = (words[0] & 0xFFFFFFFF,
                       words[1] & 0xFFFFFFFF,
                       words[2] & 0xFFFFFFFF,
                       words[3] & 0xFFFFFFFF)
    bits_127_96 = w0
    bits_95_64  = w1
    payload32   = w2
    exec_ts_lo  = w3
    recv_ts = ((bits_127_96 & 0xFFFFFFFF) << 16) | ((bits_95_64 >> 16) & 0xFFFF)
    run_command = (bits_95_64 >> 8) & 0xFF
    return {
        "raw_words":   [f"0x{w:08X}" for w in words],
        "recv_ts":     recv_ts & 0xFFFFFFFFFFFF,
        "run_command": run_command,
        "payload32":   payload32,
        "exec_ts_lo":  exec_ts_lo,
    }


def drain_log_fifo(sc_tool: Path, link: int,
                   log_fh: Optional[Any] = None) -> list[dict[str, Any]]:
    """Drain the LOG FIFO into a list. Hard cap at LOG_FIFO_DRAIN_MAX_ITER
    iterations to avoid infinite loops if STATUS reports a busy FIFO."""
    drained: list[dict[str, Any]] = []
    for _ in range(LOG_FIFO_DRAIN_MAX_ITER):
        entry = log_pop_pop_entry(sc_tool, link, log_fh=log_fh)
        if entry is None:
            break
        drained.append(entry)
    return drained


def discard_log_fifo(sc_tool: Path, link: int,
                     log_fh: Optional[Any] = None) -> int:
    """Discard all entries in the LOG FIFO. Returns count discarded."""
    n = 0
    for _ in range(LOG_FIFO_DRAIN_MAX_ITER):
        status = sc_read(sc_tool, link, RUNCTL_LOG_STATUS_ADDR, 1, log_fh=log_fh)[0]
        depth = status & 0xFFFF
        empty = bool((status >> 16) & 0x1)
        if empty or depth == 0:
            break
        # 4 reads to consume one entry
        for _ in range(4):
            sc_read(sc_tool, link, RUNCTL_LOG_POP_ADDR, 1, log_fh=log_fh)
        n += 1
    return n


# ============================================================================
# Configuration helpers (program emulator, arb, histogram, downstream)
# ============================================================================

def configure_arb_lane_mask(sc_tool: Path, link: int, lane_mask: int,
                            log_fh: Optional[Any] = None) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for lane in range(8):
        base = ARB_BASE_WORD + lane * ARB_STRIDE_WORD
        addr = base + ARB_MODE_OFFSET_W
        enabled = bool((lane_mask >> lane) & 1)
        value = 0x00000001 if enabled else 0x00000000
        sc_write_stable(sc_tool, link, addr, [value], log_fh=log_fh)
        readback = sc_read(sc_tool, link, addr, 1, log_fh=log_fh)[0]
        out[f"lane{lane}"] = {
            "addr":     f"0x{addr:05X}",
            "enabled":  enabled,
            "written":  f"0x{value:08X}",
            "readback": f"0x{readback:08X}",
        }
    return out


def configure_emulator(sc_tool: Path, link: int,
                       channel_mask: int, rate_88fp: int, hit_mode: int,
                       log_fh: Optional[Any] = None) -> dict[str, Any]:
    """Program emulator_mutrig channel_mask, rate, and hit_mode.

    Fix 1 (sim diag commit 6029646e): MUTRIG_FORMAT (CSR 0x0A) carries
    format flags only -- short_mode[0], gen_idle[1], tx_mode[4:2],
    type0_enable[5]. It does NOT dispatch hit_mode. The mode-dispatch
    bits live in the SIGNAL CSR (CSR 0x08, frontend_csr.sv:277-289):
      bit[0] cfg_signal_hit_mode_sig     : 0 = internal, 1 = external
      bit[1] cfg_signal_internal_sub_mode: 0 = direct (Poisson PRNG),
                                           1 = periodic (phase accumulator)

    Mode encoding that matches the sweep row hit_mode field:
      direct   (00b, hit_mode=0): SIGNAL=0x00  hit_mode_sig=0 sub_mode=0
      burst    (01b, hit_mode=1): SIGNAL=0x01  hit_mode_sig=1 (external)
      periodic (11b, hit_mode=3): SIGNAL=0x03  hit_mode_sig=1 sub_mode=1

    MUTRIG_FORMAT is always written as 0x20 (type0-enable bit[5]=1,
    all other format flags = default). This was already the correct
    constant for direct-mode rows; for burst/periodic rows the prior
    code wrote 0x21/0x23 which set format bits, not mode bits.
    """
    # MUTRIG_FORMAT: always 0x20 (type0 stream enabled, format defaults).
    # Do NOT OR in hit_mode here -- see comment above.
    mutrig_fmt = 0x20

    # SIGNAL CSR encodes the actual hit mode (direct / burst / periodic).
    # Bit[0]=hit_mode_sig, bit[1]=internal_sub_mode.
    signal_word = hit_mode & 0x3

    writes: list[tuple[str, int, int]] = [
        ("CHANNEL_MASK",  EMU_BASE_WORD + EMU_CHANNEL_MASK_W,  channel_mask & 0xFFFFFFFF),
        ("CENTRAL",       EMU_BASE_WORD + EMU_CENTRAL_W,       0x00000001),
        # SIGNAL: mode dispatch -- direct=0x00, burst=0x01, periodic=0x03
        ("SIGNAL",        EMU_BASE_WORD + EMU_SIGNAL_W,        signal_word),
        ("BACKGROUND",    EMU_BASE_WORD + EMU_BACKGROUND_W,    0x00000000),
        # MUTRIG_FORMAT: format flags only; type0-enable=1, rest=0 -> 0x20
        ("MUTRIG_FORMAT", EMU_BASE_WORD + EMU_MUTRIG_FORMAT_W, mutrig_fmt),
        ("RATES",         EMU_BASE_WORD + EMU_RATES_W,         rate_88fp & 0xFFFF),
        ("CLUSTER_FIX",   EMU_BASE_WORD + EMU_CLUSTER_FIX_W,   0x00004000 | (3 << 7) | 0),
        ("PRNG_SEED",     EMU_BASE_WORD + EMU_PRNG_SEED_W,     0xDEADBEEF),
        ("TIMEBASE_SEED", EMU_BASE_WORD + EMU_TIMEBASE_SEED_W, 0x00010001),
    ]
    out: dict[str, Any] = {}
    for name, addr, value in writes:
        sc_write_stable(sc_tool, link, addr, [value], log_fh=log_fh)
        try:
            readback = sc_read(sc_tool, link, addr, 1, log_fh=log_fh)[0]
            out[name] = {
                "addr": f"0x{addr:05X}",
                "written": f"0x{value:08X}",
                "readback": f"0x{readback:08X}",
            }
        except RuntimeError as exc:
            out[name] = {"addr": f"0x{addr:05X}",
                          "written": f"0x{value:08X}",
                          "readback": "NOT_AVAILABLE",
                          "error": str(exc)}
    return out


def configure_histogram(sc_tool: Path, link: int,
                        interval_clocks: int,
                        hist_left: int = 0, hist_right: int = 255,
                        hist_bin_width: int = 1,
                        log_fh: Optional[Any] = None) -> dict[str, str]:
    writes: list[tuple[str, int, int]] = [
        ("LEFT_BOUND",    HIST_CSR_BASE_WORD + HIST_LEFT_BOUND_W,   hist_left & 0xFFFFFFFF),
        ("RIGHT_BOUND",   HIST_CSR_BASE_WORD + HIST_RIGHT_BOUND_W,  hist_right & 0xFFFFFFFF),
        ("BIN_WIDTH",     HIST_CSR_BASE_WORD + HIST_BIN_WIDTH_W,    hist_bin_width & 0xFFFFFFFF),
        ("KEY_LOC",       HIST_CSR_BASE_WORD + HIST_KEY_LOC_W,      HIST_KEY_LOC_CHANNEL_POST),
        ("INTERVAL_CFG",  HIST_CSR_BASE_WORD + HIST_INTERVAL_CFG_W, interval_clocks & 0xFFFFFFFF),
        ("CONTROL_APPLY", HIST_CSR_BASE_WORD + HIST_CONTROL_W,      0x00000101),
    ]
    sc_write_stable(sc_tool, link, HIST_BIN_BASE_WORD, [0], log_fh=log_fh)
    for _, addr, value in writes:
        sc_write_stable(sc_tool, link, addr, [value], log_fh=log_fh)
    # wait for CONTROL apply self-clear
    for _ in range(50):
        try:
            ctrl = sc_read(sc_tool, link,
                           HIST_CSR_BASE_WORD + HIST_CONTROL_W, 1, log_fh=log_fh)[0]
        except RuntimeError:
            break
        if (ctrl & 0x2) == 0:
            break
        time.sleep(0.02)
    out: dict[str, str] = {}
    for name, addr, _ in writes:
        try:
            out[name] = f"0x{sc_read(sc_tool, link, addr, 1, log_fh=log_fh)[0]:08X}"
        except RuntimeError:
            out[name] = "NOT_AVAILABLE"
    return out


def select_histogram_source(sc_tool: Path, link: int,
                            source: str = HIST_INGRESS_SOURCE,
                            bank_count: int = HIST_INGRESS_BANK_COUNT,
                            log_fh: Optional[Any] = None) -> dict[str, str]:
    select_post = 1 if source == "post" else 0
    expected = 0x3 if select_post else 0x0
    statuses: dict[str, str] = {}
    for bank, base in enumerate(HIST_INGRESS_BANK_BASE_WORDS[:bank_count]):
        label = f"bank{bank}"
        try:
            sc_write_stable(sc_tool, link,
                            base + HIST_INGRESS_CONTROL_W,
                            [select_post], log_fh=log_fh)
            status = 0
            for _ in range(50):
                status = sc_read(sc_tool, link,
                                 base + HIST_INGRESS_STATUS_W, 1,
                                 log_fh=log_fh)[0]
                if (status & 0x7) == expected:
                    break
                time.sleep(0.02)
            statuses[label] = f"0x{status:08X}"
        except RuntimeError:
            statuses[label] = "NOT_AVAILABLE"
    return statuses


def configure_downstream(sc_tool: Path, link: int,
                         log_fh: Optional[Any] = None) -> dict[str, Any]:
    for base in MTS_BASE_WORDS:
        sc_write_stable(sc_tool, link, base, [MTS_CTRL_DEFAULT], log_fh=log_fh)
    for base in RING_BASE_WORDS.values():
        sc_write_stable(sc_tool, link, base + 0x02, [RING_CTRL_DEFAULT], log_fh=log_fh)
    return {
        "mts_ctrl":  f"0x{MTS_CTRL_DEFAULT:08X}",
        "ring_ctrl": f"0x{RING_CTRL_DEFAULT:08X}",
    }


def enable_lvds_lanes(sc_tool: Path, link: int,
                      log_fh: Optional[Any] = None) -> None:
    sc_write_stable(sc_tool, link, LVDS_LANE_GO_WORD, [0x000001FF], log_fh=log_fh)


# ============================================================================
# Counter inventory snapshots
# ============================================================================

def snap_arb(sc_tool: Path, link: int,
             log_fh: Optional[Any] = None) -> list[dict[str, Any]]:
    arb: list[dict[str, Any]] = []
    for lane in range(8):
        base = ARB_BASE_WORD + lane * ARB_STRIDE_WORD
        try:
            words = sc_read(sc_tool, link, base, 30, log_fh=log_fh)
            arb.append({
                "lane":              lane,
                "base":              f"0x{base:05X}",
                "uid":               f"0x{words[0]:08X}",
                "mode":              f"0x{words[3]:08X}",
                "fifo_level_max":    (words[3] >> 16) & 0xFF,
                "ingress_real_hits": read_u64_pair_from_words(words, 0x0A, 0x0B),
                "ingress_emu_hits":  read_u64_pair_from_words(words, 0x0C, 0x0D),
                "drops_real":        read_u64_pair_from_words(words, 0x0E, 0x0F),
                "drops_emu":         read_u64_pair_from_words(words, 0x10, 0x11),
                "egress_real_hits":  read_u64_pair_from_words(words, 0x12, 0x13),
                "egress_emu_hits":   read_u64_pair_from_words(words, 0x14, 0x15),
            })
        except RuntimeError as exc:
            arb.append({"lane": lane, "error": str(exc)})
    return arb


def snap_hist(sc_tool: Path, link: int,
              log_fh: Optional[Any] = None) -> dict[str, Any]:
    try:
        # 19 words covers offsets 0x00..0x12 in one transaction (NOT the bin RAM).
        # We need offsets 0x11 (LAST_INTERVAL_TOTAL_HITS) and 0x12
        # (LAST_INTERVAL_DROPPED_HITS) for cross-validation of the LIVE
        # CSR 13 counter against the STABLE CSR 17 latch.
        words = sc_read(sc_tool, link, HIST_CSR_BASE_WORD, 19, log_fh=log_fh)
        return {
            "raw":            [f"0x{w:08X}" for w in words],
            "UNDERFLOW":      words[HIST_UNDERFLOW_W],
            "OVERFLOW":       words[HIST_OVERFLOW_W],
            "INTERVAL_CFG":   words[HIST_INTERVAL_CFG_W],
            "BANK_STATUS":    words[HIST_BANK_STATUS_W],
            "PORT_STATUS":    words[HIST_PORT_STATUS_W],
            # LIVE current-interval counters (reset on interval_pulse)
            "TOTAL_HITS":     words[HIST_TOTAL_HITS_W],
            "DROPPED_HITS":   words[HIST_DROPPED_HITS_W],
            "COAL_STATUS":    words[HIST_COAL_STATUS_W],
            # STABLE last-interval snapshots (latched at most recent interval_pulse)
            "LAST_INTERVAL_TOTAL_HITS":   words[HIST_LAST_INTERVAL_TOTAL_HITS_W],
            "LAST_INTERVAL_DROPPED_HITS": words[HIST_LAST_INTERVAL_DROPPED_HITS_W],
            # Back-compat alias (was offset 0x10 = SCRATCH, mis-labelled in old runs)
            "LAST_INT_HITS":  words[HIST_LAST_INTERVAL_TOTAL_HITS_W],
        }
    except RuntimeError as exc:
        return {"error": str(exc),
                "TOTAL_HITS": 0, "UNDERFLOW": 0, "OVERFLOW": 0,
                "DROPPED_HITS": 0, "BANK_STATUS": 0, "PORT_STATUS": 0,
                "INTERVAL_CFG": 0, "COAL_STATUS": 0,
                "LAST_INTERVAL_TOTAL_HITS": 0,
                "LAST_INTERVAL_DROPPED_HITS": 0,
                "LAST_INT_HITS": 0}


def read_hist_bins(sc_tool: Path, link: int,
                   log_fh: Optional[Any] = None) -> list[int]:
    """Read all 256 hist bins ONE WORD AT A TIME (NOT burst).

    Round 3 a710b11a finding: multi-word burst reads of HIST_BIN_BASE_WORD
    corrupt the SC bridge. Each bin is a single sc_read transaction.
    """
    if HIST_BIN_READ_BURST:
        # guard so accidental flip stays a hard error
        raise RuntimeError("HIST_BIN_READ_BURST must remain False")
    bins: list[int] = []
    for offset in range(HIST_NUM_BINS):
        try:
            bins.append(sc_read(sc_tool, link,
                                HIST_BIN_BASE_WORD + offset, 1, log_fh=log_fh)[0])
        except RuntimeError:
            bins.append(0)
    return bins


def snap_ring(sc_tool: Path, link: int,
              log_fh: Optional[Any] = None) -> dict[str, Any]:
    ring: dict[str, Any] = {}
    for name, base in RING_BASE_WORDS.items():
        try:
            words = sc_read(sc_tool, link, base, 10, log_fh=log_fh)
            ring[name] = {
                "base":             f"0x{base:05X}",
                "uid":              f"0x{words[0]:08X}",
                "ctrl":             f"0x{words[2]:08X}",
                "fill_level":       words[4],
                "inerr_count":      words[5],
                "push_count":       words[6],
                "pop_count":        words[7],
                "overwrite_count":  words[8],
                "cache_miss_count": words[9],
            }
        except RuntimeError as exc:
            ring[name] = {"error": str(exc)}
    return ring


def snap_mts(sc_tool: Path, link: int,
             log_fh: Optional[Any] = None) -> list[dict[str, Any]]:
    mts: list[dict[str, Any]] = []
    for idx, base in enumerate(MTS_BASE_WORDS):
        try:
            words = sc_read(sc_tool, link, base, 5, log_fh=log_fh)
            mts.append({
                "idx":              idx,
                "base":             f"0x{base:05X}",
                "status_control":   f"0x{words[0]:08X}",
                "discard_hits":     words[1],
                "expected_latency": words[2],
                "total_hits":       ((words[3] & 0xFFFF) << 32) | words[4],
            })
        except RuntimeError as exc:
            mts.append({"idx": idx, "error": str(exc)})
    return mts


def snap_frame_asm(sc_tool: Path, link: int,
                   log_fh: Optional[Any] = None) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for name, base in FRAME_ASM_BASE_WORDS.items():
        try:
            words = sc_read(sc_tool, link, base, 8, log_fh=log_fh)
            out[name] = {
                "base":          f"0x{base:05X}",
                "declared_hits": read_u64_pair_from_words(words, 2, 3),
                "actual_hits":   read_u64_pair_from_words(words, 4, 5),
                "missing_hits":  read_u64_pair_from_words(words, 6, 7),
            }
        except RuntimeError as exc:
            out[name] = {"error": str(exc)}
    return out


def snap_runctl(sc_tool: Path, link: int,
                log_fh: Optional[Any] = None) -> dict[str, Any]:
    fields: dict[str, Any] = {}
    for name, addr in [
        ("UID",          RUNCTL_UID_ADDR),
        ("STATUS",       RUNCTL_STATUS_ADDR),
        ("LAST_CMD",     RUNCTL_LAST_CMD_ADDR),
        ("RUN_NUMBER",   RUNCTL_RUN_NUMBER_ADDR),
        ("RX_CMD_COUNT", RUNCTL_RX_CMD_ADDR),
        ("RX_ERR_COUNT", RUNCTL_RX_ERR_ADDR),
        ("LOG_STATUS",   RUNCTL_LOG_STATUS_ADDR),
    ]:
        try:
            val = sc_read(sc_tool, link, addr, 1, log_fh=log_fh)[0]
            fields[name] = {"addr": f"0x{addr:05X}", "value": f"0x{val:08X}",
                             "value_int": val}
        except RuntimeError as exc:
            fields[name] = {"addr": f"0x{addr:05X}",
                             "value": "NOT_AVAILABLE", "error": str(exc)}
    try:
        recv_ts = read_u48_pair(sc_tool, link,
                                RUNCTL_RECV_TS_L_ADDR, RUNCTL_RECV_TS_H_ADDR,
                                log_fh=log_fh)
        fields["RECV_TS"] = {"value_int": recv_ts, "value": f"0x{recv_ts:012X}"}
    except RuntimeError as exc:
        fields["RECV_TS"] = {"value": "NOT_AVAILABLE", "error": str(exc)}
    try:
        exec_ts = read_u48_pair(sc_tool, link,
                                RUNCTL_EXEC_TS_L_ADDR, RUNCTL_EXEC_TS_H_ADDR,
                                log_fh=log_fh)
        fields["EXEC_TS"] = {"value_int": exec_ts, "value": f"0x{exec_ts:012X}"}
    except RuntimeError as exc:
        fields["EXEC_TS"] = {"value": "NOT_AVAILABLE", "error": str(exc)}
    return fields


def full_snapshot(sc_tool: Path, link: int,
                  log_fh: Optional[Any] = None) -> dict[str, Any]:
    return {
        "timestamp": dt.datetime.now().isoformat(timespec="seconds"),
        "sc_hub_uid": _try_sc_read_word(sc_tool, link, SC_HUB_UID_WORD, log_fh),
        "runctl":    snap_runctl(sc_tool, link, log_fh=log_fh),
        "arb":       snap_arb(sc_tool, link, log_fh=log_fh),
        "histogram": snap_hist(sc_tool, link, log_fh=log_fh),
        "ring":      snap_ring(sc_tool, link, log_fh=log_fh),
        "mts":       snap_mts(sc_tool, link, log_fh=log_fh),
        "frame_asm": snap_frame_asm(sc_tool, link, log_fh=log_fh),
    }


def _try_sc_read_word(sc_tool: Path, link: int, addr: int,
                      log_fh: Optional[Any] = None) -> str:
    try:
        v = sc_read(sc_tool, link, addr, 1, log_fh=log_fh)[0]
        return f"0x{v:08X}"
    except RuntimeError:
        return "NOT_AVAILABLE"


# ============================================================================
# LOCAL_CMD driver (with stage-timing grace periods baked in)
# ============================================================================

def drive_local_cmd(sc_tool: Path, link: int, cmd: int, payload24: int,
                    log_fh: Optional[Any] = None) -> dict[str, Any]:
    """Write one LOCAL_CMD word and return STATUS+LAST_CMD snapshot.

    The 32-bit word format is { payload24[23:0], cmd[7:0] }.
    Forbidden opcodes are blocked at the call site, not here -- this is
    the bare driver and is also used for the cleanup 0x13 END_RUN.
    """
    if cmd in FORBIDDEN_OPCODES:
        raise RuntimeError(f"opcode 0x{cmd:02X} is forbidden by task brief")
    word = ((payload24 & 0xFFFFFF) << 8) | (cmd & 0xFF)
    wall_start = time.time()
    sc_write(sc_tool, link, RUNCTL_LOCAL_CMD_ADDR, [word], log_fh=log_fh)
    # poll for local_cmd_busy bit (STATUS[30]) to clear
    status_val = 0
    for _ in range(50):
        try:
            status_val = sc_read(sc_tool, link, RUNCTL_STATUS_ADDR, 1,
                                 log_fh=log_fh)[0]
        except RuntimeError:
            break
        if (status_val & (1 << 30)) == 0:
            break
        time.sleep(0.02)
    try:
        last_cmd = sc_read(sc_tool, link, RUNCTL_LAST_CMD_ADDR, 1,
                            log_fh=log_fh)[0]
    except RuntimeError:
        last_cmd = 0
    return {
        "cmd":             f"0x{cmd:02X}",
        "word":            f"0x{word:08X}",
        "runctl_status":   f"0x{status_val:08X}",
        "runctl_last_cmd": f"0x{last_cmd:08X}",
        "wall_start":      wall_start,
        "wall_end":        time.time(),
    }


def wait_for_idle(sc_tool: Path, link: int,
                  log_fh: Optional[Any] = None
                  ) -> tuple[bool, float, str]:
    """Poll CSR_STATUS until host_state[23:16] is IDLE (0x00) or timeout.

    Returns (idle_observed, wall_clock_observation_ts, completion_label).
    completion_label is one of "IDLE_OBSERVED" or "WALL_CLOCK_FALLBACK".
    """
    deadline = time.time() + GRACE_IDLE_POLL_TIMEOUT_S
    while time.time() < deadline:
        try:
            status = sc_read(sc_tool, link, RUNCTL_STATUS_ADDR, 1,
                             log_fh=log_fh)[0]
        except RuntimeError:
            time.sleep(GRACE_IDLE_POLL_PERIOD_S)
            continue
        host_state = (status >> 16) & 0xFF
        recv_state = (status >> 8) & 0xFF
        if host_state == 0x00 and recv_state == 0x00:
            return (True, time.time(), "IDLE_OBSERVED")
        time.sleep(GRACE_IDLE_POLL_PERIOD_S)
    return (False, time.time(), "WALL_CLOCK_FALLBACK")


# ============================================================================
# Stage-timing recipe (the deterministic part the test agent does NOT touch)
# ============================================================================

def run_stage_recipe(sc_tool: Path, link: int, row: dict[str, Any],
                     row_idx: int, log_fh: Any) -> dict[str, Any]:
    """Execute the full per-row stage-timing recipe.

    Returns a structured dict with everything the verdict computation needs:
      stage_durations, fifo_entries, run_number_writeback_ok, cmd_traces,
      rx_cmd_delta, rx_err_delta, idle_observed_label, hist_bins, snap_pre,
      snap_post, snap_terminating.
    """
    rid = row["row_id"]
    record: dict[str, Any] = {
        "row_idx": row_idx,
        "stage_durations": {
            "prepare_ms":     None,
            "sync_ms":        None,
            "running_s":      None,
            "terminating_ms": None,
        },
        "wall_clock_durations": {
            "prepare_s":      None,
            "sync_s":         None,
            "running_s":      None,
            "terminating_s":  None,
            "total_s":        None,
        },
        "fifo_entries":      [],
        "cmd_traces":        [],
        "drain_pre_iter":    0,
        "drain_post_iter":   0,
        "idle_completion":   "WALL_CLOCK_FALLBACK",
        "idle_observed_ts":  None,
        "run_number_written":  None,
        "run_number_readback": None,
        "run_number_writeback_ok": False,
    }

    # Step 1: Grace 1 (post-SC-write settle)
    print(f"  [{rid}] step 1: GRACE_1 ({GRACE_1_POST_SC_WRITE_S*1000:.0f}ms)",
          flush=True)
    time.sleep(GRACE_1_POST_SC_WRITE_S)

    # Step 2: FIFO drain
    print(f"  [{rid}] step 2: drain LOG FIFO", flush=True)
    record["drain_pre_iter"] = discard_log_fifo(sc_tool, link, log_fh=log_fh)

    # Step 3: Grace 2
    print(f"  [{rid}] step 3: GRACE_2 ({GRACE_2_AFTER_FIFO_DRAIN_S*1000:.0f}ms)",
          flush=True)
    time.sleep(GRACE_2_AFTER_FIFO_DRAIN_S)

    # Step 4: Write self-defined run_number to CSR_RUN_NUMBER
    run_number = (0xAA0000 | (row_idx & 0xFFFF))
    record["run_number_written"] = run_number
    print(f"  [{rid}] step 4: write CSR_RUN_NUMBER = 0x{run_number:08X}", flush=True)
    try:
        sc_write_stable(sc_tool, link, RUNCTL_RUN_NUMBER_ADDR,
                        [run_number], log_fh=log_fh)
    except RuntimeError as exc:
        # Per RTL, CSR_RUN_NUMBER reads the shadow latched from LVDS payload;
        # it might be RO. Capture failure but continue.
        _log(log_fh, f"NOTE: CSR_RUN_NUMBER side-load failed (likely RO): {exc}")

    # Read back BEFORE issuing RUN_PREPARE so we can compare
    try:
        rn_pre = sc_read(sc_tool, link, RUNCTL_RUN_NUMBER_ADDR, 1, log_fh=log_fh)[0]
    except RuntimeError:
        rn_pre = None

    # Step 5: Grace 3
    print(f"  [{rid}] step 5: GRACE_3 ({GRACE_3_AFTER_RUN_NUMBER_S*1000:.0f}ms)",
          flush=True)
    time.sleep(GRACE_3_AFTER_RUN_NUMBER_S)

    # Step 6: T0
    t0 = time.time()

    # Pre-snapshot of rx counters for delta sanity
    try:
        rx_cmd_pre = sc_read(sc_tool, link, RUNCTL_RX_CMD_ADDR, 1, log_fh=log_fh)[0]
    except RuntimeError:
        rx_cmd_pre = 0
    try:
        rx_err_pre = sc_read(sc_tool, link, RUNCTL_RX_ERR_ADDR, 1, log_fh=log_fh)[0]
    except RuntimeError:
        rx_err_pre = 0

    # Step 7: 0x10 RUN_PREPARE (payload24 = run_number low 24 bits)
    print(f"  [{rid}] step 7: drive 0x10 RUN_PREPARE", flush=True)
    payload24_for_prepare = run_number & 0xFFFFFF
    trace_prepare = drive_local_cmd(sc_tool, link, CMD_RUN_PREPARE,
                                     payload24_for_prepare, log_fh=log_fh)
    record["cmd_traces"].append(trace_prepare)
    t_after_prepare = time.time()
    print(f"  [{rid}] step 7b: GRACE_STAGE_PREPARE ({GRACE_STAGE_PREPARE_S*1000:.0f}ms)",
          flush=True)
    time.sleep(GRACE_STAGE_PREPARE_S)

    # Read run-number writeback AFTER RUN_PREPARE was accepted
    try:
        rn_post_prepare = sc_read(sc_tool, link, RUNCTL_RUN_NUMBER_ADDR, 1,
                                   log_fh=log_fh)[0]
        record["run_number_readback"] = rn_post_prepare
        record["run_number_writeback_ok"] = (rn_post_prepare == run_number)
    except RuntimeError:
        record["run_number_readback"] = None
        record["run_number_writeback_ok"] = False

    # Step 8: 0x11 RUN_SYNC
    print(f"  [{rid}] step 8: drive 0x11 RUN_SYNC", flush=True)
    trace_sync = drive_local_cmd(sc_tool, link, CMD_RUN_SYNC, 0, log_fh=log_fh)
    record["cmd_traces"].append(trace_sync)
    t_after_sync = time.time()
    print(f"  [{rid}] step 8b: GRACE_STAGE_SYNC ({GRACE_STAGE_SYNC_S*1000:.0f}ms)",
          flush=True)
    time.sleep(GRACE_STAGE_SYNC_S)

    # Step 9: 0x12 START_RUN, then run window
    print(f"  [{rid}] step 9: drive 0x12 START_RUN; run_window={row['interval_seconds']:.1f}s",
          flush=True)
    trace_start = drive_local_cmd(sc_tool, link, CMD_START_RUN, 0, log_fh=log_fh)
    record["cmd_traces"].append(trace_start)
    t_after_start = time.time()
    time.sleep(row["interval_seconds"])
    t_after_run = time.time()

    # Step 10: 0x13 END_RUN
    print(f"  [{rid}] step 10: drive 0x13 END_RUN", flush=True)
    trace_end = drive_local_cmd(sc_tool, link, CMD_END_RUN, 0, log_fh=log_fh)
    record["cmd_traces"].append(trace_end)
    t_end_wall = time.time()
    print(f"  [{rid}] step 10b: GRACE_STAGE_TERMINATE ({GRACE_STAGE_TERMINATE_S*1000:.0f}ms)",
          flush=True)
    time.sleep(GRACE_STAGE_TERMINATE_S)

    # Step 11: poll for IDLE
    idle_ok, idle_ts, idle_label = wait_for_idle(sc_tool, link, log_fh=log_fh)
    record["idle_completion"] = idle_label
    record["idle_observed_ts"] = idle_ts

    # Step 12: T1
    t1 = time.time()

    # rx counter deltas
    try:
        rx_cmd_post = sc_read(sc_tool, link, RUNCTL_RX_CMD_ADDR, 1, log_fh=log_fh)[0]
    except RuntimeError:
        rx_cmd_post = rx_cmd_pre
    try:
        rx_err_post = sc_read(sc_tool, link, RUNCTL_RX_ERR_ADDR, 1, log_fh=log_fh)[0]
    except RuntimeError:
        rx_err_post = rx_err_pre
    record["rx_cmd_count_pre"]   = rx_cmd_pre
    record["rx_cmd_count_post"]  = rx_cmd_post
    record["rx_cmd_count_delta"] = (rx_cmd_post - rx_cmd_pre) & 0xFFFFFFFF
    record["rx_err_count_pre"]   = rx_err_pre
    record["rx_err_count_post"]  = rx_err_post
    record["rx_err_count_delta"] = (rx_err_post - rx_err_pre) & 0xFFFFFFFF

    # Step 13: drain LOG FIFO into a list (typically 4 entries)
    print(f"  [{rid}] step 13: drain LOG FIFO post-run", flush=True)
    fifo_entries = drain_log_fifo(sc_tool, link, log_fh=log_fh)
    record["fifo_entries"] = fifo_entries
    record["log_entries_count"] = len(fifo_entries)

    # Step 14: compute stage durations from FIFO timestamps. Map by opcode.
    by_cmd: dict[int, dict[str, Any]] = {e["run_command"]: e
                                          for e in fifo_entries}
    prepare_ts = by_cmd.get(CMD_RUN_PREPARE, {}).get("recv_ts")
    sync_ts    = by_cmd.get(CMD_RUN_SYNC,    {}).get("recv_ts")
    start_ts   = by_cmd.get(CMD_START_RUN,   {}).get("recv_ts")
    end_ts     = by_cmd.get(CMD_END_RUN,     {}).get("recv_ts")
    if prepare_ts is not None and sync_ts is not None and sync_ts >= prepare_ts:
        record["stage_durations"]["prepare_ms"] = ticks_to_ms(sync_ts - prepare_ts)
    if sync_ts is not None and start_ts is not None and start_ts >= sync_ts:
        record["stage_durations"]["sync_ms"] = ticks_to_ms(start_ts - sync_ts)
    if start_ts is not None and end_ts is not None and end_ts >= start_ts:
        record["stage_durations"]["running_s"] = ticks_to_s(end_ts - start_ts)
    # terminating: prefer end_ts vs idle_ts, fall back to wall-clock
    if idle_label == "IDLE_OBSERVED":
        record["stage_durations"]["terminating_ms"] = (idle_ts - t_end_wall) * 1000.0
    else:
        record["stage_durations"]["terminating_ms"] = (t1 - t_end_wall) * 1000.0

    record["wall_clock_durations"]["prepare_s"]     = t_after_prepare - t0
    record["wall_clock_durations"]["sync_s"]        = t_after_sync    - t_after_prepare
    record["wall_clock_durations"]["running_s"]     = t_after_run     - t_after_sync
    record["wall_clock_durations"]["terminating_s"] = t1               - t_after_run
    record["wall_clock_durations"]["total_s"]       = t1               - t0

    record["t0_wall"] = t0
    record["t1_wall"] = t1
    record["run_number_pre"] = rn_pre

    return record


# ============================================================================
# Verdict computation
# ============================================================================

def compute_verdict(row: dict[str, Any], snap_pre: dict[str, Any],
                    snap_post: dict[str, Any], stage_rec: dict[str, Any],
                    hist_bins: list[int],
                    prev_total_hits: Optional[int]) -> dict[str, Any]:
    hist_post = snap_post.get("histogram", {})
    # LIVE current-interval accumulator (CSR 13). With
    # INTERVAL_CFG=INTERVAL_CFG_NEVER_FIRE this is the authoritative
    # full-run total because no interval_pulse fires during the run.
    total_hits_csr13 = int(hist_post.get("TOTAL_HITS",  0) or 0)
    # STABLE last-interval snapshot (CSR 17). Should be 0 or stale on
    # a clean run with INTERVAL_CFG=NEVER_FIRE (no interval pulse
    # latched anything). Captured for cross-validation only.
    last_interval_total_hits_csr17 = int(
        hist_post.get("LAST_INTERVAL_TOTAL_HITS", 0) or 0
    )
    last_interval_dropped_hits_csr18 = int(
        hist_post.get("LAST_INTERVAL_DROPPED_HITS", 0) or 0
    )
    underflow    = int(hist_post.get("UNDERFLOW",    0) or 0)
    overflow     = int(hist_post.get("OVERFLOW",     0) or 0)
    dropped      = int(hist_post.get("DROPPED_HITS", 0) or 0)
    hist_bin_sum = int(sum(hist_bins))

    # Cross-validation: with INTERVAL_CFG=NEVER_FIRE the ping-pong bank
    # never swaps, so hist_bin[0..255] reads the same accumulator that
    # CSR 13 reports. Allow an 8-hit tolerance for in-flight pipeline
    # drain between the CSR 13 sample and the bin-RAM single-word reads.
    HIST_CROSS_TOL = 8
    csr13_vs_hist_diff = abs(hist_bin_sum - total_hits_csr13)
    hist_bin_sum_matches_csr13 = (csr13_vs_hist_diff <= HIST_CROSS_TOL)

    # Authoritative total_hits for the run: CSR 13.
    total_hits = total_hits_csr13

    arb_drops = 0
    for lane_rec in snap_post.get("arb", []):
        if isinstance(lane_rec, dict) and "drops_emu" in lane_rec:
            arb_drops += int(lane_rec.get("drops_emu", 0) or 0)

    sanity_neg = bool(row.get("sanity_negative", False))
    if sanity_neg:
        traffic_predicate = (total_hits == 0)
    else:
        traffic_predicate = (total_hits > 0)

    rx_cmd_delta_ok = (stage_rec.get("rx_cmd_count_delta", 0) == 4)
    rx_err_delta_ok = (stage_rec.get("rx_err_count_delta", 0) == 0)

    ratio_to_prev: Optional[float] = None
    if prev_total_hits is not None and prev_total_hits > 0 and total_hits > 0:
        ratio_to_prev = float(total_hits) / float(prev_total_hits)

    failure_modes: list[str] = []
    if not traffic_predicate:
        failure_modes.append(
            "TOTAL_HITS_NOT_EXPECTED_FOR_SANITY_NEG" if sanity_neg
            else "TOTAL_HITS_ZERO"
        )
    if underflow != 0:
        failure_modes.append("UNDERFLOW_NONZERO")
    if overflow != 0:
        failure_modes.append("OVERFLOW_NONZERO")
    if dropped != 0:
        failure_modes.append("HIST_DROPPED_HITS_NONZERO")
    if arb_drops != 0:
        failure_modes.append("ARB_DROPS_EMU_NONZERO")
    if not rx_cmd_delta_ok:
        failure_modes.append(
            f"RX_CMD_COUNT_DELTA_NE_4_GOT_{stage_rec.get('rx_cmd_count_delta')}"
        )
    if not rx_err_delta_ok:
        failure_modes.append(
            f"RX_ERR_COUNT_DELTA_NE_0_GOT_{stage_rec.get('rx_err_count_delta')}"
        )

    # hist_bin_sum vs CSR 13 mismatch is reported as a WARNING (not a
    # failure) so a partial drain at end-of-run does not flip an
    # otherwise healthy row.
    warnings: list[str] = []
    if not hist_bin_sum_matches_csr13:
        warnings.append(
            f"HIST_BIN_SUM_NE_CSR13_diff={csr13_vs_hist_diff}_"
            f"sum={hist_bin_sum}_csr13={total_hits_csr13}"
        )

    passed = (
        traffic_predicate
        and underflow == 0
        and overflow == 0
        and dropped == 0
        and arb_drops == 0
        and rx_cmd_delta_ok
        and rx_err_delta_ok
    )

    return {
        "pass":              passed,
        "total_hits":        total_hits,                  # authoritative = CSR 13
        "total_hits_csr13":  total_hits_csr13,            # LIVE counter
        "last_interval_total_hits_csr17":   last_interval_total_hits_csr17,
        "last_interval_dropped_hits_csr18": last_interval_dropped_hits_csr18,
        "hist_bin_sum":      hist_bin_sum,
        "hist_bin_sum_matches_csr13": hist_bin_sum_matches_csr13,
        "csr13_vs_hist_diff": csr13_vs_hist_diff,
        "underflow":         underflow,
        "overflow":          overflow,
        "dropped_hits":      dropped,
        "arb_drops_emu":     arb_drops,
        "ratio_to_prev":     ratio_to_prev,
        "hist_sum":          hist_bin_sum,                # back-compat alias
        "sanity_negative":   sanity_neg,
        "run_number_writeback_ok": stage_rec.get("run_number_writeback_ok", False),
        "run_number_written":      stage_rec.get("run_number_written"),
        "run_number_readback":     stage_rec.get("run_number_readback"),
        "rx_cmd_count_delta":      stage_rec.get("rx_cmd_count_delta"),
        "rx_err_count_delta":      stage_rec.get("rx_err_count_delta"),
        "log_entries_count":       stage_rec.get("log_entries_count", 0),
        "stage_durations":         stage_rec.get("stage_durations", {}),
        "idle_completion":         stage_rec.get("idle_completion",
                                                 "WALL_CLOCK_FALLBACK"),
        "failure_mode":            "; ".join(failure_modes) if failure_modes else None,
        "warnings":                "; ".join(warnings)      if warnings      else None,
    }


# ============================================================================
# Plot generator (imports preset renderers from phase4_5_plot.py)
# ============================================================================
#
# The plot functions live in scripts/cotest/phase4_5_plot.py so that the
# same renderers can be invoked manually post-sweep without re-running the
# board side. This script only WRITES the inputs (hist_bin.csv) and CALLS
# the renderers. To regenerate plots without running the sweep:
#
#   python3 scripts/cotest/phase4_5_plot.py --row <row_id> --mode both
#
# The import is local to keep --dry-run independent of matplotlib being
# installed; downstream callers should pass plain Python lists.
# ----------------------------------------------------------------------------

def _make_plots(hist_bins: list[int], row_id: str,
                rate_path: Path, latency_path: Path,
                row_meta: Optional[dict[str, Any]] = None) -> None:
    """Render both rate and latency plots for one row.

    Inputs:
      hist_bins    : 256 ints from sweep_evidence/<row_id>/hist_bin.csv
      row_id       : row id for the suptitle
      rate_path    : target plot_rate.png
      latency_path : target plot_latency.png
      row_meta     : optional dict with lane_mask/channel_mask/rate_88fp/hit_mode
                     used to compose the title suffix.
    """
    # late import so --dry-run does not depend on matplotlib being installed
    from phase4_5_plot import render_rate_plot, render_latency_plot

    suffix_bits = []
    if row_meta:
        if row_meta.get("lane_mask"):
            suffix_bits.append(f"lane={row_meta['lane_mask']}")
        if row_meta.get("channel_mask"):
            suffix_bits.append(f"ch={row_meta['channel_mask']}")
        if row_meta.get("rate_88fp"):
            suffix_bits.append(f"rate={row_meta['rate_88fp']}")
        if row_meta.get("hit_mode"):
            suffix_bits.append(f"mode={row_meta['hit_mode']}")
    title_suffix = " ".join(suffix_bits)

    render_rate_plot(hist_bins, row_id, rate_path,
                     title_suffix=title_suffix)
    note_latency = (
        "no per-hit timestamps available on board; the histogram is keyed "
        "by channel_id (KEY_LOC=channel_post), see tb_int simulation for "
        "the full lifetime distribution"
    )
    render_latency_plot(hist_bins, row_id, latency_path,
                        title_suffix=title_suffix,
                        note=note_latency)


# ============================================================================
# Master table generator
# ============================================================================

def collect_evidence_records() -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    if not EVIDENCE_ROOT.exists():
        return out
    for ev_dir in sorted(EVIDENCE_ROOT.iterdir()):
        if ev_dir.name.startswith("_"):
            continue
        # skip move-aside backups (rename pattern "<rid>.bak.<ts>")
        if ".bak." in ev_dir.name:
            continue
        verdict_path = ev_dir / "verdict.json"
        counters_path = ev_dir / "counters.json"
        if not verdict_path.exists():
            continue
        try:
            with open(verdict_path, encoding="ascii") as f:
                v = json.load(f)
            c = {}
            if counters_path.exists():
                with open(counters_path, encoding="ascii") as f:
                    c = json.load(f)
            out[ev_dir.name] = {"verdict": v, "counters": c}
        except Exception:
            continue
    return out


def regen_master_table() -> Path:
    """Rebuild doc/PHASE4_5_SWEEP_TABLE.md from sweep_evidence/."""
    plan = build_plan()
    records = collect_evidence_records()
    now = dt.datetime.now().isoformat(timespec="seconds")
    pass_n = sum(1 for r in records.values()
                  if r["verdict"].get("pass") is True)
    fail_n = sum(1 for r in records.values()
                  if r["verdict"].get("pass") is False)
    pend_n = len(plan) - len(records)

    lines: list[str] = []
    lines.append("---")
    lines.append(f"generated:   {now}")
    lines.append(f"plan_rows:   {len(plan)}")
    lines.append(f"completed:   {len(records)}")
    lines.append(f"pass:        {pass_n}")
    lines.append(f"fail:        {fail_n}")
    lines.append(f"pending:     {pend_n}")
    lines.append("---")
    lines.append("")
    lines.append("# Phase 4.5 Sweep Master Table")
    lines.append("")
    lines.append("Auto-regenerated by `phase4_5_sweep.py --regen-table` "
                 "(also runs after every row).")
    lines.append("")
    lines.append("## Status Summary")
    lines.append("")
    lines.append("| Metric | Value |")
    lines.append("|--------|-------|")
    lines.append(f"| Plan rows | {len(plan)} |")
    lines.append(f"| Completed | {len(records)} |")
    lines.append(f"| PASS | {pass_n} |")
    lines.append(f"| FAIL | {fail_n} |")
    lines.append(f"| Pending | {pend_n} |")
    lines.append("")
    lines.append("## Per-Row Results")
    lines.append("")
    lines.append(
        "Every entry in the **Evidence** column is a clickable relative "
        "link to the per-row evidence directory or artifact. Open this "
        "file from `doc/` so the relative `../sweep_evidence/...` paths "
        "resolve."
    )
    lines.append("")
    # HTML double-column header. Evidence columns now contain 7 file links.
    lines.append("<table>")
    lines.append("<thead>")
    lines.append("<tr>"
                  "<th rowspan=2>row_id</th>"
                  "<th colspan=5>Conditions</th>"
                  "<th colspan=4>Stage timing</th>"
                  "<th colspan=7>Counter summary</th>"
                  "<th colspan=6>Evidence (clickable)</th>"
                  "<th rowspan=2>Verdict</th>"
                  "</tr>")
    lines.append("<tr>"
                  "<th>lane_mask</th>"
                  "<th>channel_mask</th>"
                  "<th>rate</th>"
                  "<th>mode</th>"
                  "<th>run_number</th>"
                  "<th>prep_ms</th>"
                  "<th>sync_ms</th>"
                  "<th>running_s</th>"
                  "<th>term_ms</th>"
                  "<th>csr13_TOTAL</th>"
                  "<th>csr17_LAST_INT</th>"
                  "<th>hist_bin_sum</th>"
                  "<th>UNDER</th>"
                  "<th>OVER</th>"
                  "<th>rxcmd&Delta;</th>"
                  "<th>ratio</th>"
                  "<th>dir</th>"
                  "<th>rate.png</th>"
                  "<th>latency.png</th>"
                  "<th>hist.csv</th>"
                  "<th>counters</th>"
                  "<th>log</th>"
                  "</tr>")
    lines.append("</thead>")
    lines.append("<tbody>")

    def _fmt_num(x: Any) -> str:
        if x is None: return "-"
        if isinstance(x, float):
            return f"{x:.2f}"
        return str(x)

    def _fmt_pass(p: Any) -> str:
        if p is True:  return "PASS"
        if p is False: return "FAIL"
        return "PENDING"

    def _evidence_links(rid: str) -> str:
        base = f"../sweep_evidence/{rid}"
        return (
            f"<td><a href=\"{base}/\">dir</a></td>"
            f"<td><a href=\"{base}/plot_rate.png\">rate</a></td>"
            f"<td><a href=\"{base}/plot_latency.png\">lat</a></td>"
            f"<td><a href=\"{base}/hist_bin.csv\">csv</a></td>"
            f"<td><a href=\"{base}/counters.json\">json</a> / "
            f"<a href=\"{base}/verdict.json\">v</a></td>"
            f"<td><a href=\"{base}/tool_calls.log\">log</a></td>"
        )

    for row in plan:
        rid = row["row_id"]
        rec = records.get(rid)
        if rec is None:
            lines.append(
                f"<tr>"
                f"<td><a href=\"../sweep_evidence/{rid}/\">{rid}</a></td>"
                f"<td>{row['lane_mask']}</td>"
                f"<td>{row['channel_mask']}</td>"
                f"<td>{row['rate_88fp']}</td>"
                f"<td>{row['hit_mode']}</td>"
                f"<td>-</td><td>-</td><td>-</td><td>-</td><td>-</td>"
                f"<td>-</td><td>-</td><td>-</td><td>-</td><td>-</td>"
                f"<td>-</td><td>-</td>"
                + _evidence_links(rid)
                + f"<td>PENDING</td>"
                f"</tr>"
            )
            continue
        v = rec["verdict"]
        sd = v.get("stage_durations", {}) or {}
        # Backward-compat: older verdict.json may lack csr13/csr17/hist_bin_sum
        csr13 = v.get("total_hits_csr13", v.get("total_hits"))
        csr17 = v.get("last_interval_total_hits_csr17")
        hbsum = v.get("hist_bin_sum", v.get("hist_sum"))
        lines.append(
            f"<tr>"
            f"<td><a href=\"../sweep_evidence/{rid}/\">{rid}</a></td>"
            f"<td>{row['lane_mask']}</td>"
            f"<td>{row['channel_mask']}</td>"
            f"<td>{row['rate_88fp']}</td>"
            f"<td>{row['hit_mode']}</td>"
            f"<td>0x{(v.get('run_number_written') or 0):06X}</td>"
            f"<td>{_fmt_num(sd.get('prepare_ms'))}</td>"
            f"<td>{_fmt_num(sd.get('sync_ms'))}</td>"
            f"<td>{_fmt_num(sd.get('running_s'))}</td>"
            f"<td>{_fmt_num(sd.get('terminating_ms'))}</td>"
            f"<td>{_fmt_num(csr13)}</td>"
            f"<td>{_fmt_num(csr17)}</td>"
            f"<td>{_fmt_num(hbsum)}</td>"
            f"<td>{_fmt_num(v.get('underflow'))}</td>"
            f"<td>{_fmt_num(v.get('overflow'))}</td>"
            f"<td>{_fmt_num(v.get('rx_cmd_count_delta'))}</td>"
            f"<td>{_fmt_num(v.get('ratio_to_prev'))}</td>"
            + _evidence_links(rid)
            + f"<td>{_fmt_pass(v.get('pass'))}</td>"
            f"</tr>"
        )
    lines.append("</tbody>")
    lines.append("</table>")
    lines.append("")
    lines.append("> Generated by `script/phase4_5_sweep.py`. "
                 "Evidence directory: `sweep_evidence/<row_id>/`.")
    lines.append("")

    DOC_DIR.mkdir(parents=True, exist_ok=True)
    TABLE_PATH.write_text("\n".join(lines), encoding="ascii")
    return TABLE_PATH


# ============================================================================
# Dry-run printer
# ============================================================================

def dry_run_row(row: dict[str, Any], row_idx: int,
                sc_tool: Path, link: int) -> list[str]:
    """Print the full command list for a row without executing anything.

    Returns the printed command list so smoke tests can capture it.
    """
    lm = row["lane_mask"]
    cm = row["channel_mask"]
    rate = row["rate_88fp"]
    mode = row["hit_mode"]
    interval_s = row["interval_seconds"]
    run_number = (0xAA0000 | (row_idx & 0xFFFF))

    out: list[str] = []
    def p(s: str = "") -> None:
        out.append(s)
        print(s)

    p(f"=== DRY-RUN row {row_idx}: {row['row_id']} ===")
    p(f"  axis={row['axis_section']}  sanity_neg={row.get('sanity_negative', False)}")
    p(f"  expected: {row['expected_behavior']}")
    p(f"  run_number (self-generated) = 0x{run_number:08X}")
    p(f"")
    p(f"  [pre] swb_ring_lock must be held (this script enforces)")
    p(f"  [0]   SC hub UID sanity")
    p(f"  CMD: {sc_tool} {link} read 0x{SC_HUB_UID_WORD:05X} 1 --quiet")
    p(f"")
    p(f"  [1] enable LVDS lanes")
    p(f"  CMD: {sc_tool} {link} write 0x{LVDS_LANE_GO_WORD:05X} 0x000001FF --quiet")
    p(f"")
    p(f"  [2] arb_hit_type0_supercore lane_mask = {lm}")
    lm_int = int(lm, 16)
    for lane in range(8):
        addr = ARB_BASE_WORD + lane * ARB_STRIDE_WORD + ARB_MODE_OFFSET_W
        enabled = bool((lm_int >> lane) & 1)
        val = 1 if enabled else 0
        p(f"  CMD: {sc_tool} {link} write 0x{addr:05X} 0x{val:08X} --quiet "
          f" # lane{lane} {'ENABLE' if enabled else 'DISABLE'}")
    p(f"")
    p(f"  [3] emulator_mutrig channel_mask={cm} rate={rate} hit_mode={mode}")
    p(f"  CMD: {sc_tool} {link} write 0x{EMU_BASE_WORD+EMU_CHANNEL_MASK_W:05X} {cm} --quiet  # CHANNEL_MASK")
    p(f"  CMD: {sc_tool} {link} write 0x{EMU_BASE_WORD+EMU_RATES_W:05X} {rate} --quiet  # RATES")
    # Fix 1 (sim diag 6029646e): mode-dispatch goes to SIGNAL CSR, NOT MUTRIG_FORMAT.
    # SIGNAL[0]=hit_mode_sig (0=internal, 1=external/burst),
    # SIGNAL[1]=internal_sub_mode (0=direct/Poisson, 1=periodic).
    # hit_mode field: direct=00b -> SIGNAL=0x00, burst=01b -> SIGNAL=0x01, periodic=11b -> SIGNAL=0x03.
    signal_val = int(mode, 2) & 0x3
    p(f"  CMD: {sc_tool} {link} write 0x{EMU_BASE_WORD+EMU_SIGNAL_W:05X} 0x{signal_val:08X} --quiet"
      f"  # SIGNAL (mode-dispatch: direct=0x00 burst=0x01 periodic=0x03)")
    # MUTRIG_FORMAT: format flags only -- type0-enable=1, rest=0 -> 0x20. Never encodes mode.
    fmt = 0x20
    p(f"  CMD: {sc_tool} {link} write 0x{EMU_BASE_WORD+EMU_MUTRIG_FORMAT_W:05X} 0x{fmt:08X} --quiet  # MUTRIG_FORMAT (type0-enable only)")
    p(f"")
    p(f"  [4] histogram: LEFT=0 RIGHT=255 BIN_WIDTH=1 KEY_LOC=channel_post")
    p(f"  CMD: {sc_tool} {link} write 0x{HIST_CSR_BASE_WORD+HIST_LEFT_BOUND_W:05X} 0x00000000 --quiet")
    p(f"  CMD: {sc_tool} {link} write 0x{HIST_CSR_BASE_WORD+HIST_RIGHT_BOUND_W:05X} 0x000000FF --quiet")
    p(f"  CMD: {sc_tool} {link} write 0x{HIST_CSR_BASE_WORD+HIST_BIN_WIDTH_W:05X} 0x00000001 --quiet")
    p(f"  CMD: {sc_tool} {link} write 0x{HIST_CSR_BASE_WORD+HIST_INTERVAL_CFG_W:05X} "
      f"0x{INTERVAL_CFG_NEVER_FIRE:08X} --quiet  # INTERVAL_CFG (never-fire; live counter accumulates full run)")
    p(f"")
    p(f"  [5] select {HIST_INGRESS_SOURCE} histogram path on {HIST_INGRESS_BANK_COUNT} ingress bridge(s)")
    ingress_select_word = 1 if HIST_INGRESS_SOURCE == "post" else 0
    p(f"  CMD: {sc_tool} {link} write 0x{HIST_INGRESS_BASE_WORD+HIST_INGRESS_CONTROL_W:05X} 0x{ingress_select_word:08X} --quiet")
    p(f"")
    p(f"  [6] downstream: MTS + ring_buffer_cam_0..7")
    for base in MTS_BASE_WORDS:
        p(f"  CMD: {sc_tool} {link} write 0x{base:05X} 0x{MTS_CTRL_DEFAULT:08X} --quiet  # MTS ctrl")
    for name, base in RING_BASE_WORDS.items():
        p(f"  CMD: {sc_tool} {link} write 0x{base+0x02:05X} 0x{RING_CTRL_DEFAULT:08X} --quiet  # {name} ctrl")
    p(f"")
    p(f"  [7] GRACE_1 sleep {GRACE_1_POST_SC_WRITE_S*1000:.0f} ms (post-SC-write settle)")
    p(f"  [8] FIFO drain: read LOG_STATUS at 0x{RUNCTL_LOG_STATUS_ADDR:05X}, "
      f"if depth>0 then 4x sc_read of 0x{RUNCTL_LOG_POP_ADDR:05X}")
    p(f"  [9] GRACE_2 sleep {GRACE_2_AFTER_FIFO_DRAIN_S*1000:.0f} ms")
    p(f"")
    p(f"  [10] write run_number into CSR_RUN_NUMBER at 0x{RUNCTL_RUN_NUMBER_ADDR:05X}")
    p(f"  CMD: {sc_tool} {link} write 0x{RUNCTL_RUN_NUMBER_ADDR:05X} 0x{run_number:08X} --quiet")
    p(f"  [11] GRACE_3 sleep {GRACE_3_AFTER_RUN_NUMBER_S*1000:.0f} ms")
    p(f"")
    p(f"  [12] capture wall-clock T0")
    p(f"  [13] LOCAL_CMD 0x10 RUN_PREPARE (payload24 = run_number low 24 bits)")
    word_prep = (((run_number & 0xFFFFFF) << 8) | CMD_RUN_PREPARE) & 0xFFFFFFFF
    p(f"  CMD: {sc_tool} {link} write 0x{RUNCTL_LOCAL_CMD_ADDR:05X} 0x{word_prep:08X} --quiet")
    p(f"  [14] GRACE_STAGE_PREPARE sleep {GRACE_STAGE_PREPARE_S*1000:.0f} ms")
    p(f"  [15] readback CSR_RUN_NUMBER -> compare against written for writeback_ok flag")
    p(f"")
    p(f"  [16] LOCAL_CMD 0x11 RUN_SYNC")
    p(f"  CMD: {sc_tool} {link} write 0x{RUNCTL_LOCAL_CMD_ADDR:05X} 0x00000011 --quiet")
    p(f"  [17] GRACE_STAGE_SYNC sleep {GRACE_STAGE_SYNC_S*1000:.0f} ms")
    p(f"")
    p(f"  [18] LOCAL_CMD 0x12 START_RUN")
    p(f"  CMD: {sc_tool} {link} write 0x{RUNCTL_LOCAL_CMD_ADDR:05X} 0x00000012 --quiet")
    p(f"  [19] RUNNING window sleep {interval_s:.1f} s")
    p(f"")
    p(f"  [20] LOCAL_CMD 0x13 END_RUN")
    p(f"  CMD: {sc_tool} {link} write 0x{RUNCTL_LOCAL_CMD_ADDR:05X} 0x00000013 --quiet")
    p(f"  [21] GRACE_STAGE_TERMINATE sleep {GRACE_STAGE_TERMINATE_S*1000:.0f} ms")
    p(f"  [22] poll CSR_STATUS until host_state==IDLE OR timeout "
      f"{GRACE_IDLE_POLL_TIMEOUT_S:.1f}s")
    p(f"")
    p(f"  [23] post-snapshot: full CSR sweep (arb, hist, ring, mts, frame, runctl)")
    p(f"  [24] read hist_bin[0..255] ONE WORD AT A TIME (NO burst!)")
    p(f"  CMD: {sc_tool} {link} read 0x{HIST_BIN_BASE_WORD:05X} 1 --quiet  # bin[0]")
    p(f"  ... ({HIST_NUM_BINS} single-word reads)")
    p(f"")
    p(f"  [25] drain LOG FIFO into list of (recv_ts, run_command, payload32) entries")
    p(f"       expect 4 entries: 0x10, 0x11, 0x12, 0x13")
    p(f"  [26] compute stage_durations from FIFO timestamps "
      f"(8 ns ticks -> ms or s)")
    p(f"  [27] save counters.json, hist_bin.csv, tool_calls.log, plot.png, verdict.json")
    p(f"  [28] regenerate doc/PHASE4_5_SWEEP_TABLE.md")
    return out


# ============================================================================
# Output dir guard (move-aside, NEVER delete)
# ============================================================================

def prepare_evidence_dir(rid: str) -> Path:
    """Create sweep_evidence/<rid>/, moving-aside an existing one.

    NEVER deletes files. If sweep_evidence/<rid>/ already exists, it is
    renamed to <rid>.bak.<timestamp>.
    """
    EVIDENCE_ROOT.mkdir(parents=True, exist_ok=True)
    target = EVIDENCE_ROOT / rid
    if target.exists():
        stamp = dt.datetime.now().strftime("%Y%m%dT%H%M%S")
        backup = EVIDENCE_ROOT / f"{rid}.bak.{stamp}"
        os.rename(str(target), str(backup))
    target.mkdir(parents=True, exist_ok=True)
    return target


# ============================================================================
# Row executor (the full pipeline)
# ============================================================================

def run_row(row: dict[str, Any], row_idx: int, sc_tool: Path, link: int,
            prev_total_hits: Optional[int] = None,
            verbose: bool = False) -> dict[str, Any]:
    rid = row["row_id"]
    ev_dir = prepare_evidence_dir(rid)
    log_path = ev_dir / "tool_calls.log"

    print(f"\n=== running row {row_idx}: {rid} ===", flush=True)

    started = dt.datetime.now().isoformat(timespec="seconds")
    record: dict[str, Any] = {
        "row":          row,
        "row_idx":      row_idx,
        "started":      started,
        "sc_tool":      str(sc_tool),
        "link":         link,
        "evidence_dir": str(ev_dir),
    }

    # Open the tool_calls.log immediately so every retry attempt is captured
    log_fh = open(log_path, "w", encoding="ascii")
    try:
        log_fh.write(f"# phase4_5_sweep.py tool_calls.log\n")
        log_fh.write(f"# row={rid} row_idx={row_idx} started={started}\n\n")

        # SC hub sanity
        try:
            uid = sc_read(sc_tool, link, SC_HUB_UID_WORD, 1, log_fh=log_fh)[0]
        except RuntimeError as exc:
            record["fatal"] = f"SC hub unreachable: {exc}"
            return _finalize_row_after_fatal(record, ev_dir, exc)
        if uid != SC_HUB_UID_EXPECT:
            record["fatal"] = (f"SC hub UID mismatch: got 0x{uid:08X} "
                                f"expected 0x{SC_HUB_UID_EXPECT:08X}")
            return _finalize_row_after_fatal(
                record, ev_dir, RuntimeError(record["fatal"])
            )

        # Enable LVDS lanes
        enable_lvds_lanes(sc_tool, link, log_fh=log_fh)

        # Arb lane mask
        # NOTE: arb MODE write order now safe per abb3e455; legacy ordering
        # preserved for stability. The Opus arb fix decoupled MODE-clear from
        # PREPARING so writing arb MODE in the configure stage (before 0x10)
        # is architecturally correct. A future hardening pass could defer
        # MODE writes to after PREPARING confirmation, but the current order
        # is not a hazard.
        arb_cfg = configure_arb_lane_mask(sc_tool, link,
                                          int(row["lane_mask"], 16),
                                          log_fh=log_fh)

        # Emulator
        emu_cfg = configure_emulator(sc_tool, link,
                                     int(row["channel_mask"], 16),
                                     int(row["rate_88fp"], 16),
                                     int(row["hit_mode"], 2),
                                     log_fh=log_fh)

        # Histogram
        # LIVE-vs-STABLE counter contract (see top-of-file docstring):
        # Setting INTERVAL_CFG = run_window per-row caused csr_total_hits
        # (CSR 13) to reset every interval_pulse during the run, leaving
        # the post-end-run read at 0 or at a partial. We program
        # INTERVAL_CFG = INTERVAL_CFG_NEVER_FIRE so no interval_pulse
        # fires during the run; csr_total_hits then accumulates the full
        # run total and the ping-pong hist_bin bank never swaps.
        if row["interval_seconds"] > INTERVAL_CFG_NEVER_FIRE_S:
            raise RuntimeError(
                f"row interval_seconds={row['interval_seconds']:.2f} exceeds "
                f"INTERVAL_CFG_NEVER_FIRE_S={INTERVAL_CFG_NEVER_FIRE_S:.2f}s; "
                "histogram_statistics_v2 INTERVAL_CFG cannot hold off the "
                "interval_pulse for this long without a different reset "
                "strategy. Reduce interval_seconds or switch to a manual "
                "interval_reset between runs."
            )
        interval_clocks = INTERVAL_CFG_NEVER_FIRE
        hist_cfg = configure_histogram(sc_tool, link, interval_clocks,
                                       log_fh=log_fh)

        # Ingress mux: pre-rbCAM for dualport builds, post-rbCAM for legacy builds.
        ingress_status = select_histogram_source(sc_tool, link, log_fh=log_fh)

        # Downstream
        ds_cfg = configure_downstream(sc_tool, link, log_fh=log_fh)

        # Pre snapshot
        snap_pre = full_snapshot(sc_tool, link, log_fh=log_fh)

        # Stage-timing recipe
        stage_rec = run_stage_recipe(sc_tool, link, row, row_idx, log_fh=log_fh)

        # Post snapshot
        snap_post = full_snapshot(sc_tool, link, log_fh=log_fh)

        # Hist bins (single-word reads!)
        hist_bins = read_hist_bins(sc_tool, link, log_fh=log_fh)

        # Save artifacts
        record.update({
            "arb_lane_cfg":   arb_cfg,
            "emulator_cfg":   emu_cfg,
            "histogram_cfg":  hist_cfg,
            "ingress_source": HIST_INGRESS_SOURCE,
            "ingress_status": ingress_status,
            "downstream_cfg": ds_cfg,
            "stage_recipe":   stage_rec,
            "snapshot_pre":   snap_pre,
            "snapshot_post":  snap_post,
        })

        verdict = compute_verdict(row, snap_pre, snap_post, stage_rec,
                                  hist_bins, prev_total_hits)
        record["verdict"] = verdict

        # Write counters.json
        with open(ev_dir / "counters.json", "w", encoding="ascii") as f:
            json.dump(record, f, indent=2)
            f.write("\n")
        # Write hist_bin.csv
        with open(ev_dir / "hist_bin.csv", "w", newline="", encoding="ascii") as f:
            w = csv.writer(f)
            w.writerow(["bin_idx", "count"])
            for i, c in enumerate(hist_bins):
                w.writerow([i, c])
        # Write verdict.json (standalone for the master table)
        with open(ev_dir / "verdict.json", "w", encoding="ascii") as f:
            json.dump(verdict, f, indent=2)
            f.write("\n")

        # Plots (rate + latency via phase4_5_plot.py)
        try:
            _make_plots(hist_bins, rid,
                        ev_dir / "plot_rate.png",
                        ev_dir / "plot_latency.png",
                        row_meta=row)
        except Exception as exc:
            _log(log_fh, f"PLOT_ERROR: {exc}\n{traceback.format_exc()}")
            print(f"  WARNING: plot generation failed: {exc}", file=sys.stderr)

        # Regenerate master table
        try:
            regen_master_table()
        except Exception as exc:
            _log(log_fh, f"REGEN_TABLE_ERROR: {exc}")

        status_label = "PASS" if verdict["pass"] else "FAIL"
        print(f"  [{rid}] {status_label}  "
              f"csr13={verdict['total_hits_csr13']}  "
              f"csr17={verdict['last_interval_total_hits_csr17']}  "
              f"hist_sum={verdict['hist_bin_sum']}  "
              f"sum_matches_csr13={verdict['hist_bin_sum_matches_csr13']}  "
              f"drops_emu={verdict['arb_drops_emu']}  "
              f"rxcmd_delta={verdict.get('rx_cmd_count_delta')}  "
              f"idle={verdict['idle_completion']}",
              flush=True)
        return verdict
    except Exception as exc:
        return _finalize_row_after_fatal(record, ev_dir, exc)
    finally:
        log_fh.close()


def _finalize_row_after_fatal(record: dict[str, Any], ev_dir: Path,
                              exc: BaseException) -> dict[str, Any]:
    """Capture a structured verdict.json after a fatal failure.

    The test agent should never see an uncaught Python traceback. Every
    row that runs to completion -- successful or fatal -- produces a
    structured verdict.json that records the failure mode.
    """
    tb = traceback.format_exc()
    verdict = {
        "pass":          False,
        "total_hits":    0,
        "total_hits_csr13":  0,
        "last_interval_total_hits_csr17":   0,
        "last_interval_dropped_hits_csr18": 0,
        "hist_bin_sum":  0,
        "hist_bin_sum_matches_csr13": False,
        "csr13_vs_hist_diff": 0,
        "underflow":     None,
        "overflow":      None,
        "dropped_hits":  None,
        "arb_drops_emu": None,
        "ratio_to_prev": None,
        "hist_sum":      0,
        "stage_durations": {},
        "failure_mode":  f"FATAL: {type(exc).__name__}: {exc}",
        "warnings":      None,
        "traceback":     tb,
    }
    record["verdict"] = verdict
    try:
        with open(ev_dir / "counters.json", "w", encoding="ascii") as f:
            json.dump(record, f, indent=2)
            f.write("\n")
        with open(ev_dir / "verdict.json", "w", encoding="ascii") as f:
            json.dump(verdict, f, indent=2)
            f.write("\n")
        # Always emit annotated empty plots so the test agent gets the files
        try:
            _make_plots([0] * HIST_NUM_BINS, record["row"]["row_id"],
                        ev_dir / "plot_rate.png",
                        ev_dir / "plot_latency.png",
                        row_meta=record.get("row"))
        except Exception:
            pass
    except Exception:
        pass
    print(f"  [{record['row']['row_id']}] FATAL: {exc}", file=sys.stderr,
          flush=True)
    return verdict


# ============================================================================
# Smoke tests (self-contained, no SWB required)
# ============================================================================

def smoke_plot(output_dir: Path) -> Path:
    """Render synthetic-data plots to verify the matplotlib path.

    Renders both plot_rate.png and plot_latency.png via phase4_5_plot.py and
    returns the rate plot path (callers used to expect a single file).
    """
    import math
    output_dir.mkdir(parents=True, exist_ok=True)
    bins: list[int] = []
    for i in range(HIST_NUM_BINS):
        # Two gaussian-ish bumps to exercise the percentile path
        a = 1000.0 * math.exp(-((i - 32) ** 2) / 80.0)
        b = 800.0  * math.exp(-((i - 160) ** 2) / 60.0)
        bins.append(int(a + b))
    # Write csv too so the test agent has a complete smoke directory
    with open(output_dir / "hist_bin.csv", "w", newline="", encoding="ascii") as f:
        w = csv.writer(f)
        w.writerow(["bin_idx", "count"])
        for i, c in enumerate(bins):
            w.writerow([i, c])
    _make_plots(bins, "_smoke_synthetic",
                output_dir / "plot_rate.png",
                output_dir / "plot_latency.png",
                row_meta={"lane_mask": "0xFF", "channel_mask": "synthetic",
                          "rate_88fp": "n/a",  "hit_mode":     "n/a"})
    return output_dir / "plot_rate.png"


def smoke_logpop_decode() -> dict[str, Any]:
    """Verify the LOG_POP decoder using a synthetic 128-bit pattern."""
    recv_ts     = 0x123456789ABC
    run_command = 0x10
    payload32   = 0xAA0001
    exec_ts_lo  = 0xDEADBEEF
    # Layout: 4 x 32 = 128 bits, MSB-first
    bits = (recv_ts << 80) | (run_command << 72) | (0x00 << 64) | \
            (payload32 << 32) | exec_ts_lo
    w0 = (bits >> 96) & 0xFFFFFFFF
    w1 = (bits >> 64) & 0xFFFFFFFF
    w2 = (bits >> 32) & 0xFFFFFFFF
    w3 = (bits >> 0)  & 0xFFFFFFFF
    decoded = decode_log_entry([w0, w1, w2, w3])
    expected = {
        "recv_ts":      recv_ts,
        "run_command":  run_command,
        "payload32":    payload32,
        "exec_ts_lo":   exec_ts_lo,
    }
    ok = all(decoded[k] == v for k, v in expected.items())
    return {"ok": ok, "decoded": decoded, "expected": expected}


# ============================================================================
# CLI helpers
# ============================================================================

def have_swb_ring_lock() -> bool:
    if os.environ.get("SWB_RING_LOCK_HELD") == "1":
        return True
    try:
        return Path(os.readlink("/proc/self/fd/9")) == Path("/tmp/swb_ring.lock")
    except OSError:
        return False


def export_plan(plan: list[dict[str, Any]], out_path: Path) -> None:
    out_path.parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", encoding="ascii") as f:
        json.dump({"_generated": dt.datetime.now().isoformat(timespec="seconds"),
                    "plan_row_count": len(plan),
                    "rows": plan}, f, indent=2)
        f.write("\n")
    print(f"Wrote plan: {out_path} ({len(plan)} rows)")


# ============================================================================
# Main
# ============================================================================

def main() -> int:
    ap = argparse.ArgumentParser(
        description="Phase 4.5 sweep -- one integrated script "
                     "(see TEST_PLAN.md section 4.5)"
    )
    ap.add_argument("--sc-tool", type=Path, default=DEFAULT_SC_TOOL,
                     help=f"sc_tool binary (default: {DEFAULT_SC_TOOL})")
    ap.add_argument("--link", type=int, default=DEFAULT_LINK,
                     help=f"FEB SC link index (default: {DEFAULT_LINK})")
    ap.add_argument("--dry-run", action="store_true",
                     help="Print commands without executing")
    ap.add_argument("--verbose", action="store_true",
                     help="Verbose debug logging")
    ap.add_argument("--list", action="store_true",
                     help="List row_ids and exit")
    ap.add_argument("--export-plan", type=Path, default=None,
                     help="Write the inline plan to a JSON file and exit")
    ap.add_argument("--plot-smoke", action="store_true",
                     help="Render synthetic plot to sweep_evidence/_smoke/")
    ap.add_argument("--regen-table", action="store_true",
                     help="Rebuild doc/PHASE4_5_SWEEP_TABLE.md and exit")
    grp = ap.add_mutually_exclusive_group()
    grp.add_argument("--row", metavar="ROW_ID",
                      help="Run a single row by id")
    grp.add_argument("--all", action="store_true",
                      help="Run all rows sequentially")
    args = ap.parse_args()

    plan = build_plan()

    if args.list:
        for i, r in enumerate(plan):
            print(f"  {i:2d}  {r['row_id']:60s} "
                  f"lane={r['lane_mask']:6s} ch={r['channel_mask']:10s} "
                  f"rate={r['rate_88fp']:6s} mode={r['hit_mode']:2s} "
                  f"axis={r['axis_section']}")
        return 0

    if args.export_plan:
        export_plan(plan, args.export_plan)
        return 0

    if args.plot_smoke:
        out = smoke_plot(EVIDENCE_ROOT / "_smoke")
        print(f"Smoke plot: {out}")
        decode = smoke_logpop_decode()
        print(f"LOG_POP decode self-test: {'OK' if decode['ok'] else 'FAIL'}")
        if not decode["ok"]:
            print(json.dumps(decode, indent=2))
        return 0 if decode["ok"] else 1

    if args.regen_table:
        out = regen_master_table()
        print(f"Regenerated: {out}")
        return 0

    if not (args.row or args.all or args.dry_run):
        ap.error("must specify --row, --all, --dry-run, --list, "
                  "--plot-smoke, --regen-table, or --export-plan")

    # dry-run: no SWB required
    if args.dry_run:
        if args.row:
            matches = [(i, r) for i, r in enumerate(plan)
                       if r["row_id"] == args.row]
            if not matches:
                print(f"ERROR: row_id {args.row!r} not found in plan",
                      file=sys.stderr)
                return 1
            i, r = matches[0]
            dry_run_row(r, i, args.sc_tool, args.link)
        else:
            for i, r in enumerate(plan):
                dry_run_row(r, i, args.sc_tool, args.link)
                print()
        # Smoke plot + log-pop self-test as part of --dry-run
        smoke_plot(EVIDENCE_ROOT / "_smoke")
        decode = smoke_logpop_decode()
        print(f"\nLOG_POP decode self-test: "
              f"{'OK' if decode['ok'] else 'FAIL'}")
        # Regenerate master table so the doc tree is consistent
        try:
            regen_master_table()
        except Exception as exc:
            print(f"WARNING: --dry-run table regen failed: {exc}",
                  file=sys.stderr)
        return 0

    # live mode -- require swb_ring_lock
    if not have_swb_ring_lock():
        print("ERROR: must be called under "
               "/home/yifeng/.local/bin/swb_ring_lock",
               file=sys.stderr)
        return 1

    if args.row:
        matches = [(i, r) for i, r in enumerate(plan)
                   if r["row_id"] == args.row]
        if not matches:
            print(f"ERROR: row_id {args.row!r} not found in plan",
                  file=sys.stderr)
            return 1
        i, r = matches[0]
        v = run_row(r, i, args.sc_tool, args.link,
                    prev_total_hits=None, verbose=args.verbose)
        return 0 if v.get("pass") else 2

    # --all
    prev_total: Optional[int] = None
    all_pass = True
    for i, r in enumerate(plan):
        try:
            v = run_row(r, i, args.sc_tool, args.link,
                        prev_total_hits=prev_total, verbose=args.verbose)
            if not v.get("pass"):
                all_pass = False
            prev_total = v.get("total_hits")
        except Exception as exc:
            print(f"  ERROR row {r['row_id']}: {exc}", file=sys.stderr)
            all_pass = False
    try:
        regen_master_table()
    except Exception:
        pass
    return 0 if all_pass else 2


if __name__ == "__main__":
    sys.exit(main())
