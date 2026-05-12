# TEST_BASIC.md - BASIC bucket

**Parent:** [TEST_PLAN.md](TEST_PLAN.md)
**Siblings:** [TEST_BU.md](TEST_BU.md), [TEST_PERF.md](TEST_PERF.md), [TEST_ERROR.md](TEST_ERROR.md), [TEST_EDGE.md](TEST_EDGE.md)
**ID range:** SC.BASIC.001-012, RC.BASIC.001-011, RN.BASIC.001-128, RN.COSIM.001
**Total:** 152 cases

**Methodology key:**
- **D** (directed): single deterministic stimulus with a golden expectation.
- **R** (constrained-random): UVM/Python sweep randomises a named axis;
  scoreboard checks count parity.

**Bucket purpose:** happy-path verification across SC, RC, and RN. Aggregate
hit rate stays below 50% of OPQ ingress ceiling. Both sim and board deltas
vs `theoretical_hits` must stay within `|delta| < 5%`.

**Evidence model (BASIC):** all three E1 (post-TERM CSR snapshot), E2 (hist
during-running readout), and E3 (offline RDMA dump) must agree with
`theoretical_hits` within 5%.

---

## 1. Summary

| Section | Cases | ID range | What it Proves | Function Reference |
|---|---:|---|---|---|
| SC.BASIC | 12 | SC.BASIC.001-012 | scratchpad BIST; per-IP SCRATCH RW; sc_hub admission/ordering | `run_atpg_v2_reference.sh`, sc_tool |
| RC.BASIC | 11 | RC.BASIC.001-011 | legal opcode sequences; LOG FIFO decode; stage timing; SC-WEDGE-fixed CMD_RESET | `rc_tool`, `phase4_5_sweep.py:run_row()` |
| RN.BASIC | 128 | RN.BASIC.001-128 | 8 lane_masks x 4 channel_masks x 4 rates, all below saturation; theoretical-delta < 5% | `scripts/cotest/phase4_5_sweep.py:rn_basic_plan()` |
| RN.COSIM.001 | 1 | RN.COSIM.001 | 6-checkpoint cosim sanity, lossless at 1 ms below ceiling | `cosim/Makefile` |

---

## 2. SC.BASIC

Cold writes / reads. Round-trip + BIST.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| SC.BASIC.001 | D | scratch_pad_ram single-word RW | 1 | write 0xAABBCCDD at 0x00000, read back, restore | readback matches; restore observed | `run_atpg_v2_reference.sh` |
| SC.BASIC.002 | D | scratch_pad_ram 256-burst RW | 1 | write 256 random words, read back | every word matches | `run_atpg_v2_reference.sh` |
| SC.BASIC.003 | R | Scratchpad BIST 1024 random seeds | 16 | random addr + payload | 0 mismatches; UNDERFLOW = OVERFLOW = 0 | `run_atpg_v2_reference.sh` |
| SC.BASIC.004 | D | onewire SCRATCH RW | 1 | round-trip onewire SCRATCH | readback matches | `run_atpg_v2_reference.sh` |
| SC.BASIC.005 | D | max10_prog_avmm SCRATCH RW | 1 | same | matches | `run_atpg_v2_reference.sh` |
| SC.BASIC.006 | D | firefly_xcvr_ctrl mode RW | 1 | round-trip mode CSR | matches | `run_atpg_v2_reference.sh` |
| SC.BASIC.007 | D | histogram_statistics CFG RW | 1 | LEFT/RIGHT/BIN_WIDTH/INTERVAL_CFG round-trip | matches | `phase4_5_sweep.py:configure_histogram()` |
| SC.BASIC.008 | D | runctl RUN_NUMBER RW | 1 | write 0x00AA0000 to CSR_RUN_NUMBER | readback matches | `phase4_5_sweep.py:run_row()` |
| SC.BASIC.009 | D | runctl SCRATCH RW | 1 | round-trip SCRATCH | matches | `check_sc_bridges.py` |
| SC.BASIC.010 | D | sc_hub single-beat admission | 1 | one isolated SC packet | ack=OK, rsp[19:18]=0 | sc_tool low-level |
| SC.BASIC.011 | R | sc_hub 256-burst admission | 4 | random interleaved reads/writes | all ack=OK | sc_tool burst |
| SC.BASIC.012 | D | sc_hub stall-or-reject regression | 1 | drive conflicting beat pair | one accepted, other rsp=SLVERR; no corruption | sc_hub overlay log |

**SC.BASIC verdict:** PASS.

---

## 3. RC.BASIC

Legal opcode sequences.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| RC.BASIC.001 | D | rc_tool 0x10 RUN_PREPARE | 1 | `rc_tool 2 send 0x10` | RX_CMD_COUNT +1; LAST_CMD=0x10 | `rc_tool` |
| RC.BASIC.002 | D | rc_tool 0x11 SYNC | 1 | 0x11 | RX_CMD_COUNT +1; LAST_CMD=0x11 | `rc_tool` |
| RC.BASIC.003 | D | rc_tool 0x12 START_RUN | 1 | 0x12 | STATUS=RUNNING | `rc_tool` |
| RC.BASIC.004 | D | rc_tool 0x13 END_RUN | 1 | 0x13 | STATUS returns to IDLE through TERMINATING | `rc_tool` |
| RC.BASIC.005 | D | LOCAL_CMD fallback 0x10..0x13 | 4 | `sc_tool write 0x0C013 <op>` per opcode | matches rc_tool path | `phase4_5_sweep.py` |
| RC.BASIC.006 | D | LOG FIFO decode | 1 | drain LOG_POP x4 per run | each entry decodes to (recv_ts, opcode, payload) | `phase4_5_sweep.py:drain_log_fifo()` |
| RC.BASIC.007 | D | Stage timing extraction | 1 | compute prepare_ms / sync_ms / running_s / terminating_ms | RUNNING_s matches `interval_seconds`; PREP/SYNC/TERM in ms | `phase4_5_sweep.py:run_row()` |
| RC.BASIC.008 | D | CMD_RESET 0x30 SC-WEDGE check | 1 | drive 0x30; read 3 SC slaves immediately | SC reads remain clean (not 0xEEEEEEEE) per `abb3e455` | TP3 postfix-1 retest |
| RC.BASIC.009 | D | CMD_STOP_RESET 0x31 recovery | 1 | drive 0x31 after 0x30 | RX_CMD_COUNT continues incrementing | TP3 postfix-1 retest |
| RC.BASIC.010 | D | Full opcode sweep 0x10..0x14, 0x20..0x26 | 11 | drive each opcode | each increments RX_CMD_COUNT +1 and LAST_CMD reflects opcode | `tb_int_run_sequence_directed_test.sv` |
| RC.BASIC.011 | D | arb MODE survives PREP after `abb3e455` | 1 | configure MODE=EMU; drive 0x10..0x13 | MODE remains EMU through PREP/SYNC/RUNNING/TERM | `B033_mode_preserved_through_run_seq.sv` |

**RC.BASIC verdict:** PASS on-board.

---

## 4. RN.BASIC

Matrix: **8 lane_masks x 4 channel_masks x 4 rates = 128 rows**.

**Matrix axes:**

| Axis | Values |
|---|---|
| `lane_mask` (8) | `0xFF` all, `0x55` evens, `0xAA` odds, `0x01` lane0, `0x02` lane1, `0x04` lane2, `0x10` lane4, `0x40` lane6 |
| `channel_mask` (4) | `0xFFFFFFFF` all, `0x0000FFFF` low-half, `0x55555555` evens, `0x00000001` channel-0 only |
| `rate_88fp` (4) | `0x0100`, `0x0400`, `0x1000`, `0x2000` (all below OPQ 50%-of-ceiling) |
| `hit_mode` | fixed at `0x00` direct (other modes live in EDGE) |

**Row ID encoding:** `RN.BASIC.NNN` where NNN = `lane_idx*16 + chan_idx*4 + rate_idx + 1`, 1-indexed.

**Common per-row stimulus:**
- `INTERVAL_CFG = INTERVAL_CFG_NEVER_FIRE (0xFFFFFFFF)` for E1
- LEFT_BOUND=0, RIGHT_BOUND=255, BIN_WIDTH=1
- 1 ms RUNNING window in sim; 1 ms on board
- Opcode sequence: 0x10 -> 0x11 -> 0x12 -> wait RUNNING -> 0x13

**Common per-row pass criteria:**
- E1 (post-TERM csr13): |delta vs theoretical| < 5%
- E2 (hist_bin sum + per-interval shape): sum matches E1 within +/- 8
- E3 (RDMA dump): record count matches E1 within +/- 8

**Representative slice (8 of 128):**

| ID | lane_mask | channel_mask | rate_88fp | theoretical_hits (1 ms) | Notes |
|---|---|---|---|---:|---|
| RN.BASIC.001 | 0xFF | 0xFFFFFFFF | 0x0100 | 125,000 | flat 256-channel baseline |
| RN.BASIC.005 | 0xFF | 0x0000FFFF | 0x0100 | 62,500 | low-half channels, all lanes |
| RN.BASIC.013 | 0xFF | 0x00000001 | 0x0100 | 3,906 | channel-0 only, all lanes |
| RN.BASIC.017 | 0x55 | 0xFFFFFFFF | 0x0100 | 62,500 | all-channels, even lanes |
| RN.BASIC.065 | 0x01 | 0xFFFFFFFF | 0x0100 | 15,625 | lane-0 only, all channels |
| RN.BASIC.068 | 0x01 | 0xFFFFFFFF | 0x2000 | 1,000,000 | lane-0 only, high rate (may approach PROF threshold) |
| RN.BASIC.097 | 0x10 | 0x55555555 | 0x0400 | 250,000 | lane-4 only, even channels, mid rate |
| RN.BASIC.128 | 0x40 | 0x00000001 | 0x2000 | 15,625 | lane-6 only, channel-0 only, high rate |

The full 128-row enumeration lives in `scripts/cotest/phase4_5_sweep.py:rn_basic_plan()`.
Run any individual row with:
```bash
PHASE4_5_BUILD_DIR=<build-dir> swb_ring_lock python3 scripts/cotest/phase4_5_sweep.py --row RN.BASIC.<idx>
```

**RN.BASIC verdict:** sim 32/32 PASS at 10 ms RUNNING (commit `967845b5`);
1 ms sim re-baselining + 96 additional rows in flight (codex1 BASIC/PERF
dispatch). Board PASS at 25/32 pre-arbfix (commit `47efa242`); arbfix retest
in flight.

---

## 5. RN.COSIM.001

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| RN.COSIM.001 | D | 6-checkpoint cosim sanity at 1 ms | 1 | feb_swb cosim, 1 ms RUNNING, rate well below ceiling | pre-rbCAM = post-rbCAM = FEB egress = SWB ingress = OPQ egress = RDMA egress (lossless through all 6); cosim ingress byte-exact within 1-cycle CDC delta | `cosim/Makefile` |

**RN.COSIM.001 verdict:** infrastructure done (15 SV/UVM files, 1050 lines);
1 ms rerun in flight via codex1 cosim dispatch.

---

## 6. Cross-references

- Per-row board evidence: `firmware_builds/systems/v3_pretest-260511-emutype0-dualport*/sweep_evidence/<row_id>/`
- Per-row sim evidence: `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/sim_evidence/<row_id>/`
- HTML cross-validation: `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/PHASE4_5_SWEEP_REPORT.html`
