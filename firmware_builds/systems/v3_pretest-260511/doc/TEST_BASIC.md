# TEST_BASIC.md - BASIC bucket

**Parent:** [TEST_PLAN.md](TEST_PLAN.md)
**Siblings:** [TEST_BU.md](TEST_BU.md), [TEST_PERF.md](TEST_PERF.md), [TEST_ERROR.md](TEST_ERROR.md), [TEST_EDGE.md](TEST_EDGE.md)
**ID range:** SC.BASIC.001-012, RC.BASIC.001-011, RN.BASIC.001-194
**Total:** 217 cases

**Methodology key:**
- **D** (directed): single deterministic stimulus with a golden expectation.
- **R** (constrained-random): UVM/Python sweep randomises a named axis;
  scoreboard checks count parity.

**Bucket purpose:** happy-path verification across SC, RC, and RN. Aggregate
hit rate stays below 50% of OPQ ingress ceiling. Each RN row carries
**three agreeing evidence streams** (theory / cosim sim / board), each
within `|delta vs theory| < 5%`.

**Evidence model (BASIC):** theory (math reference), sim (dual-UVM FEB-SWB
cosim run for the same row), and board (on-board sweep) all agree with each
other within `|delta| < 5%`. There is no separate "cosim sanity" row - the
cosim IS the sim evidence column for every BASIC row.

---

## 1. Summary

| Section | Cases | ID range | What it Proves | Function Reference |
|---|---:|---|---|---|
| SC.BASIC | 12 | SC.BASIC.001-012 | scratchpad BIST; per-IP SCRATCH RW; sc_hub admission/ordering | `run_atpg_v2_reference.sh`, sc_tool |
| RC.BASIC | 11 | RC.BASIC.001-011 | legal opcode sequences; LOG FIFO decode; stage timing; SC-WEDGE-fixed CMD_RESET | `rc_tool`, `phase4_5_sweep.py:run_row()` |
| RN.BASIC | 194 | RN.BASIC.001-194 | 4 injector-mode slices: periodic (128) + headersync (32) + onclick (2, 10 pulses each) + emulator-only (32); theoretical-delta < 5% in sim and board | `scripts/cotest/phase4_5_sweep.py:rn_basic_plan()` + `cosim/Makefile` |

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

**Total: 194 cases**, organised in 4 injector-mode slices. Each slice
holds one operating mode constant (periodic, headersync, onclick, or
emulator-only) and varies lane / channel within that mode so a regression
on any single axis is readable from row-to-row diffs inside one slice.

**Anchor (typical):** `lane_mask=0xFF`, `channel_mask=0xFFFFFFFF`,
`rate_88fp=0x0100`. Each slice fixes the injector mode + the emulator
hit-gen mode so the only intra-slice variables are lane and channel
(and rate or rate-ratio in slices 1 and 4).

**Injector-mode encoding (per `mutrig_injector_multiheader` CSR `mode`):**

| slice | injector_mode | name | meaning |
|---|---|---|---|
| 1 | 2 | periodic | sync periodic pulse train on the main clock |
| 2 | 1 | headersync | pulse fires on MuTRiG headerinfo events |
| 3 | 4 | onclick | mode-write 4 emits one pulse, FSM stores mode 0 |
| 4 | 0 | off (emulator-only) | no injector pulse; hits come only from the emulator hit-gen |

Async (mode 3) and PRBS (mode 5) are implemented in RTL but excluded from
RN.BASIC per 2026-05-12 directive. Mode 3 has its dedicated osc-clk FSM
(`periodic_async_injector_reg` in `mutrig_injector_multiheader.vhd:748`);
mode 5 has the PRBS LFSR FSM (`random_injector_reg` at line 789). Future
coverage for these modes belongs in EDGE or PERF as the program needs.

**Common per-row stimulus:**
- `INTERVAL_CFG = INTERVAL_CFG_NEVER_FIRE (0xFFFFFFFF)` so the full window
  accumulates as one bank (E1 readout via post-TERM csr13)
- LEFT_BOUND=0, RIGHT_BOUND=255, BIN_WIDTH=1
- 1 ms RUNNING window in sim and on board
- Opcode sequence: 0x10 -> 0x11 -> 0x12 -> wait RUNNING -> 0x13

**Common per-row pass criteria:**
- theory (math reference): `theoretical_hits` = `popcount(lane) *
  popcount(chan) * rate_88fp/65536 * 125e6 * 1e-3`, clipped at the OPQ
  ingress ceiling (250,000 hits per 1 ms window)
- sim (cosim): |delta vs theory| < 5%
- board: |delta vs theory| < 5%
- E2 (hist_bin sum + per-interval shape): matches E1 within +/- 8
- E3 (RDMA dump): record count matches E1 within +/- 8

**Slice 1 - periodic injector mode (128 cases): injector_mode=2 (periodic main clock), pulse_interval CSR per user, 8 lane x 4 chan x 4 rate**

| ID | lane_mask | channel_mask | rate_88fp | popcount L x C | theoretical_hits | clipped_hits |
|---|---|---|---|---:|---:|---:|
| RN.BASIC.001 | 0xFF | 0xFFFFFFFF | 0x0040 | 8 x 32 | 31,250 | 31,250 |
| RN.BASIC.002 | 0xFF | 0xFFFFFFFF | 0x0080 | 8 x 32 | 62,500 | 62,500 |
| RN.BASIC.003 | 0xFF | 0xFFFFFFFF | 0x00C0 | 8 x 32 | 93,750 | 93,750 |
| RN.BASIC.004 | 0xFF | 0xFFFFFFFF | 0x0100 | 8 x 32 | 125,000 | 125,000 |
| RN.BASIC.005 | 0xFF | 0x0000FFFF | 0x0040 | 8 x 16 | 15,625 | 15,625 |
| RN.BASIC.006 | 0xFF | 0x0000FFFF | 0x0080 | 8 x 16 | 31,250 | 31,250 |
| RN.BASIC.007 | 0xFF | 0x0000FFFF | 0x00C0 | 8 x 16 | 46,875 | 46,875 |
| RN.BASIC.008 | 0xFF | 0x0000FFFF | 0x0100 | 8 x 16 | 62,500 | 62,500 |
| RN.BASIC.009 | 0xFF | 0x55555555 | 0x0040 | 8 x 16 | 15,625 | 15,625 |
| RN.BASIC.010 | 0xFF | 0x55555555 | 0x0080 | 8 x 16 | 31,250 | 31,250 |
| RN.BASIC.011 | 0xFF | 0x55555555 | 0x00C0 | 8 x 16 | 46,875 | 46,875 |
| RN.BASIC.012 | 0xFF | 0x55555555 | 0x0100 | 8 x 16 | 62,500 | 62,500 |
| RN.BASIC.013 | 0xFF | 0x00000001 | 0x0040 | 8 x 1 | 977 | 977 |
| RN.BASIC.014 | 0xFF | 0x00000001 | 0x0080 | 8 x 1 | 1,953 | 1,953 |
| RN.BASIC.015 | 0xFF | 0x00000001 | 0x00C0 | 8 x 1 | 2,930 | 2,930 |
| RN.BASIC.016 | 0xFF | 0x00000001 | 0x0100 | 8 x 1 | 3,906 | 3,906 |
| RN.BASIC.017 | 0x55 | 0xFFFFFFFF | 0x0040 | 4 x 32 | 15,625 | 15,625 |
| RN.BASIC.018 | 0x55 | 0xFFFFFFFF | 0x0080 | 4 x 32 | 31,250 | 31,250 |
| RN.BASIC.019 | 0x55 | 0xFFFFFFFF | 0x00C0 | 4 x 32 | 46,875 | 46,875 |
| RN.BASIC.020 | 0x55 | 0xFFFFFFFF | 0x0100 | 4 x 32 | 62,500 | 62,500 |
| RN.BASIC.021 | 0x55 | 0x0000FFFF | 0x0040 | 4 x 16 | 7,812 | 7,812 |
| RN.BASIC.022 | 0x55 | 0x0000FFFF | 0x0080 | 4 x 16 | 15,625 | 15,625 |
| RN.BASIC.023 | 0x55 | 0x0000FFFF | 0x00C0 | 4 x 16 | 23,438 | 23,438 |
| RN.BASIC.024 | 0x55 | 0x0000FFFF | 0x0100 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.025 | 0x55 | 0x55555555 | 0x0040 | 4 x 16 | 7,812 | 7,812 |
| RN.BASIC.026 | 0x55 | 0x55555555 | 0x0080 | 4 x 16 | 15,625 | 15,625 |
| RN.BASIC.027 | 0x55 | 0x55555555 | 0x00C0 | 4 x 16 | 23,438 | 23,438 |
| RN.BASIC.028 | 0x55 | 0x55555555 | 0x0100 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.029 | 0x55 | 0x00000001 | 0x0040 | 4 x 1 | 488 | 488 |
| RN.BASIC.030 | 0x55 | 0x00000001 | 0x0080 | 4 x 1 | 977 | 977 |
| RN.BASIC.031 | 0x55 | 0x00000001 | 0x00C0 | 4 x 1 | 1,465 | 1,465 |
| RN.BASIC.032 | 0x55 | 0x00000001 | 0x0100 | 4 x 1 | 1,953 | 1,953 |
| RN.BASIC.033 | 0xAA | 0xFFFFFFFF | 0x0040 | 4 x 32 | 15,625 | 15,625 |
| RN.BASIC.034 | 0xAA | 0xFFFFFFFF | 0x0080 | 4 x 32 | 31,250 | 31,250 |
| RN.BASIC.035 | 0xAA | 0xFFFFFFFF | 0x00C0 | 4 x 32 | 46,875 | 46,875 |
| RN.BASIC.036 | 0xAA | 0xFFFFFFFF | 0x0100 | 4 x 32 | 62,500 | 62,500 |
| RN.BASIC.037 | 0xAA | 0x0000FFFF | 0x0040 | 4 x 16 | 7,812 | 7,812 |
| RN.BASIC.038 | 0xAA | 0x0000FFFF | 0x0080 | 4 x 16 | 15,625 | 15,625 |
| RN.BASIC.039 | 0xAA | 0x0000FFFF | 0x00C0 | 4 x 16 | 23,438 | 23,438 |
| RN.BASIC.040 | 0xAA | 0x0000FFFF | 0x0100 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.041 | 0xAA | 0x55555555 | 0x0040 | 4 x 16 | 7,812 | 7,812 |
| RN.BASIC.042 | 0xAA | 0x55555555 | 0x0080 | 4 x 16 | 15,625 | 15,625 |
| RN.BASIC.043 | 0xAA | 0x55555555 | 0x00C0 | 4 x 16 | 23,438 | 23,438 |
| RN.BASIC.044 | 0xAA | 0x55555555 | 0x0100 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.045 | 0xAA | 0x00000001 | 0x0040 | 4 x 1 | 488 | 488 |
| RN.BASIC.046 | 0xAA | 0x00000001 | 0x0080 | 4 x 1 | 977 | 977 |
| RN.BASIC.047 | 0xAA | 0x00000001 | 0x00C0 | 4 x 1 | 1,465 | 1,465 |
| RN.BASIC.048 | 0xAA | 0x00000001 | 0x0100 | 4 x 1 | 1,953 | 1,953 |
| RN.BASIC.049 | 0x01 | 0xFFFFFFFF | 0x0040 | 1 x 32 | 3,906 | 3,906 |
| RN.BASIC.050 | 0x01 | 0xFFFFFFFF | 0x0080 | 1 x 32 | 7,812 | 7,812 |
| RN.BASIC.051 | 0x01 | 0xFFFFFFFF | 0x00C0 | 1 x 32 | 11,719 | 11,719 |
| RN.BASIC.052 | 0x01 | 0xFFFFFFFF | 0x0100 | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.053 | 0x01 | 0x0000FFFF | 0x0040 | 1 x 16 | 1,953 | 1,953 |
| RN.BASIC.054 | 0x01 | 0x0000FFFF | 0x0080 | 1 x 16 | 3,906 | 3,906 |
| RN.BASIC.055 | 0x01 | 0x0000FFFF | 0x00C0 | 1 x 16 | 5,859 | 5,859 |
| RN.BASIC.056 | 0x01 | 0x0000FFFF | 0x0100 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.057 | 0x01 | 0x55555555 | 0x0040 | 1 x 16 | 1,953 | 1,953 |
| RN.BASIC.058 | 0x01 | 0x55555555 | 0x0080 | 1 x 16 | 3,906 | 3,906 |
| RN.BASIC.059 | 0x01 | 0x55555555 | 0x00C0 | 1 x 16 | 5,859 | 5,859 |
| RN.BASIC.060 | 0x01 | 0x55555555 | 0x0100 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.061 | 0x01 | 0x00000001 | 0x0040 | 1 x 1 | 122 | 122 |
| RN.BASIC.062 | 0x01 | 0x00000001 | 0x0080 | 1 x 1 | 244 | 244 |
| RN.BASIC.063 | 0x01 | 0x00000001 | 0x00C0 | 1 x 1 | 366 | 366 |
| RN.BASIC.064 | 0x01 | 0x00000001 | 0x0100 | 1 x 1 | 488 | 488 |
| RN.BASIC.065 | 0x02 | 0xFFFFFFFF | 0x0040 | 1 x 32 | 3,906 | 3,906 |
| RN.BASIC.066 | 0x02 | 0xFFFFFFFF | 0x0080 | 1 x 32 | 7,812 | 7,812 |
| RN.BASIC.067 | 0x02 | 0xFFFFFFFF | 0x00C0 | 1 x 32 | 11,719 | 11,719 |
| RN.BASIC.068 | 0x02 | 0xFFFFFFFF | 0x0100 | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.069 | 0x02 | 0x0000FFFF | 0x0040 | 1 x 16 | 1,953 | 1,953 |
| RN.BASIC.070 | 0x02 | 0x0000FFFF | 0x0080 | 1 x 16 | 3,906 | 3,906 |
| RN.BASIC.071 | 0x02 | 0x0000FFFF | 0x00C0 | 1 x 16 | 5,859 | 5,859 |
| RN.BASIC.072 | 0x02 | 0x0000FFFF | 0x0100 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.073 | 0x02 | 0x55555555 | 0x0040 | 1 x 16 | 1,953 | 1,953 |
| RN.BASIC.074 | 0x02 | 0x55555555 | 0x0080 | 1 x 16 | 3,906 | 3,906 |
| RN.BASIC.075 | 0x02 | 0x55555555 | 0x00C0 | 1 x 16 | 5,859 | 5,859 |
| RN.BASIC.076 | 0x02 | 0x55555555 | 0x0100 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.077 | 0x02 | 0x00000001 | 0x0040 | 1 x 1 | 122 | 122 |
| RN.BASIC.078 | 0x02 | 0x00000001 | 0x0080 | 1 x 1 | 244 | 244 |
| RN.BASIC.079 | 0x02 | 0x00000001 | 0x00C0 | 1 x 1 | 366 | 366 |
| RN.BASIC.080 | 0x02 | 0x00000001 | 0x0100 | 1 x 1 | 488 | 488 |
| RN.BASIC.081 | 0x04 | 0xFFFFFFFF | 0x0040 | 1 x 32 | 3,906 | 3,906 |
| RN.BASIC.082 | 0x04 | 0xFFFFFFFF | 0x0080 | 1 x 32 | 7,812 | 7,812 |
| RN.BASIC.083 | 0x04 | 0xFFFFFFFF | 0x00C0 | 1 x 32 | 11,719 | 11,719 |
| RN.BASIC.084 | 0x04 | 0xFFFFFFFF | 0x0100 | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.085 | 0x04 | 0x0000FFFF | 0x0040 | 1 x 16 | 1,953 | 1,953 |
| RN.BASIC.086 | 0x04 | 0x0000FFFF | 0x0080 | 1 x 16 | 3,906 | 3,906 |
| RN.BASIC.087 | 0x04 | 0x0000FFFF | 0x00C0 | 1 x 16 | 5,859 | 5,859 |
| RN.BASIC.088 | 0x04 | 0x0000FFFF | 0x0100 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.089 | 0x04 | 0x55555555 | 0x0040 | 1 x 16 | 1,953 | 1,953 |
| RN.BASIC.090 | 0x04 | 0x55555555 | 0x0080 | 1 x 16 | 3,906 | 3,906 |
| RN.BASIC.091 | 0x04 | 0x55555555 | 0x00C0 | 1 x 16 | 5,859 | 5,859 |
| RN.BASIC.092 | 0x04 | 0x55555555 | 0x0100 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.093 | 0x04 | 0x00000001 | 0x0040 | 1 x 1 | 122 | 122 |
| RN.BASIC.094 | 0x04 | 0x00000001 | 0x0080 | 1 x 1 | 244 | 244 |
| RN.BASIC.095 | 0x04 | 0x00000001 | 0x00C0 | 1 x 1 | 366 | 366 |
| RN.BASIC.096 | 0x04 | 0x00000001 | 0x0100 | 1 x 1 | 488 | 488 |
| RN.BASIC.097 | 0x10 | 0xFFFFFFFF | 0x0040 | 1 x 32 | 3,906 | 3,906 |
| RN.BASIC.098 | 0x10 | 0xFFFFFFFF | 0x0080 | 1 x 32 | 7,812 | 7,812 |
| RN.BASIC.099 | 0x10 | 0xFFFFFFFF | 0x00C0 | 1 x 32 | 11,719 | 11,719 |
| RN.BASIC.100 | 0x10 | 0xFFFFFFFF | 0x0100 | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.101 | 0x10 | 0x0000FFFF | 0x0040 | 1 x 16 | 1,953 | 1,953 |
| RN.BASIC.102 | 0x10 | 0x0000FFFF | 0x0080 | 1 x 16 | 3,906 | 3,906 |
| RN.BASIC.103 | 0x10 | 0x0000FFFF | 0x00C0 | 1 x 16 | 5,859 | 5,859 |
| RN.BASIC.104 | 0x10 | 0x0000FFFF | 0x0100 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.105 | 0x10 | 0x55555555 | 0x0040 | 1 x 16 | 1,953 | 1,953 |
| RN.BASIC.106 | 0x10 | 0x55555555 | 0x0080 | 1 x 16 | 3,906 | 3,906 |
| RN.BASIC.107 | 0x10 | 0x55555555 | 0x00C0 | 1 x 16 | 5,859 | 5,859 |
| RN.BASIC.108 | 0x10 | 0x55555555 | 0x0100 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.109 | 0x10 | 0x00000001 | 0x0040 | 1 x 1 | 122 | 122 |
| RN.BASIC.110 | 0x10 | 0x00000001 | 0x0080 | 1 x 1 | 244 | 244 |
| RN.BASIC.111 | 0x10 | 0x00000001 | 0x00C0 | 1 x 1 | 366 | 366 |
| RN.BASIC.112 | 0x10 | 0x00000001 | 0x0100 | 1 x 1 | 488 | 488 |
| RN.BASIC.113 | 0x40 | 0xFFFFFFFF | 0x0040 | 1 x 32 | 3,906 | 3,906 |
| RN.BASIC.114 | 0x40 | 0xFFFFFFFF | 0x0080 | 1 x 32 | 7,812 | 7,812 |
| RN.BASIC.115 | 0x40 | 0xFFFFFFFF | 0x00C0 | 1 x 32 | 11,719 | 11,719 |
| RN.BASIC.116 | 0x40 | 0xFFFFFFFF | 0x0100 | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.117 | 0x40 | 0x0000FFFF | 0x0040 | 1 x 16 | 1,953 | 1,953 |
| RN.BASIC.118 | 0x40 | 0x0000FFFF | 0x0080 | 1 x 16 | 3,906 | 3,906 |
| RN.BASIC.119 | 0x40 | 0x0000FFFF | 0x00C0 | 1 x 16 | 5,859 | 5,859 |
| RN.BASIC.120 | 0x40 | 0x0000FFFF | 0x0100 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.121 | 0x40 | 0x55555555 | 0x0040 | 1 x 16 | 1,953 | 1,953 |
| RN.BASIC.122 | 0x40 | 0x55555555 | 0x0080 | 1 x 16 | 3,906 | 3,906 |
| RN.BASIC.123 | 0x40 | 0x55555555 | 0x00C0 | 1 x 16 | 5,859 | 5,859 |
| RN.BASIC.124 | 0x40 | 0x55555555 | 0x0100 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.125 | 0x40 | 0x00000001 | 0x0040 | 1 x 1 | 122 | 122 |
| RN.BASIC.126 | 0x40 | 0x00000001 | 0x0080 | 1 x 1 | 244 | 244 |
| RN.BASIC.127 | 0x40 | 0x00000001 | 0x00C0 | 1 x 1 | 366 | 366 |
| RN.BASIC.128 | 0x40 | 0x00000001 | 0x0100 | 1 x 1 | 488 | 488 |

**Slice 2 - headersync injector mode (32 cases): injector_mode=1 (header-sync), pulse_interval CSR per user, 8 lane x 4 chan @ rate=0x0100**

| ID | lane_mask | channel_mask | popcount L x C | theoretical_hits | clipped_hits |
|---|---|---|---:|---:|---:|
| RN.BASIC.129 | 0xFF | 0xFFFFFFFF | 8 x 32 | 125,000 | 125,000 |
| RN.BASIC.130 | 0xFF | 0x0000FFFF | 8 x 16 | 62,500 | 62,500 |
| RN.BASIC.131 | 0xFF | 0x55555555 | 8 x 16 | 62,500 | 62,500 |
| RN.BASIC.132 | 0xFF | 0x00000001 | 8 x 1 | 3,906 | 3,906 |
| RN.BASIC.133 | 0x55 | 0xFFFFFFFF | 4 x 32 | 62,500 | 62,500 |
| RN.BASIC.134 | 0x55 | 0x0000FFFF | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.135 | 0x55 | 0x55555555 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.136 | 0x55 | 0x00000001 | 4 x 1 | 1,953 | 1,953 |
| RN.BASIC.137 | 0xAA | 0xFFFFFFFF | 4 x 32 | 62,500 | 62,500 |
| RN.BASIC.138 | 0xAA | 0x0000FFFF | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.139 | 0xAA | 0x55555555 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.140 | 0xAA | 0x00000001 | 4 x 1 | 1,953 | 1,953 |
| RN.BASIC.141 | 0x01 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.142 | 0x01 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.143 | 0x01 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.144 | 0x01 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.145 | 0x02 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.146 | 0x02 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.147 | 0x02 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.148 | 0x02 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.149 | 0x04 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.150 | 0x04 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.151 | 0x04 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.152 | 0x04 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.153 | 0x10 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.154 | 0x10 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.155 | 0x10 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.156 | 0x10 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.157 | 0x40 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.158 | 0x40 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.159 | 0x40 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.160 | 0x40 | 0x00000001 | 1 x 1 | 488 | 488 |

**Slice 3 - onclick injector mode (2 cases): mode=4 single-pulse trigger fired 10 times per case at lane_mask=0xFF, rate ignored; sanity check of the hit counters under a known small fixed number of pulses**

| ID | lane_mask | channel_mask | popcount L x C | n_pulses | expected_hits | note |
|---|---|---|---:|---:|---:|---|
| RN.BASIC.161 | 0xFF | 0xFFFFFFFF | 8 x 32 | 10 | 2,560 | 10 mode=4 writes; CSR mode reads back 0 after each fire; hist_csr13 = 8 x 32 x 10 |
| RN.BASIC.162 | 0xFF | 0x00000001 | 8 x 1 | 10 | 80 | 10 mode=4 writes; only ch0 admitted; hist_csr13 = 8 x 1 x 10 |

**Slice 4 - emulator-only mode (32 cases): injector_mode=0 (off); always all-channel (0xFFFFFFFF); 8 lane x 4 poisson:signal rate ratios**

Signal hits are periodic-in-time with random spatial channel (cfg_cluster_geom_random_random_center_seed set per row). Poisson hits use cfg_signal_hit_mode_sig=0 path. Total emitted rate is 0x0100 split across the two sources.

| ID | lane_mask | rate_ratio | poisson_rate | signal_rate | popcount L x C | total_theoretical_hits |
|---|---|---|---|---|---:|---:|
| RN.BASIC.163 | 0xFF | 100p / 0s | 0x0100 | 0x0000 | 8 x 32 | 125,000 |
| RN.BASIC.164 | 0xFF | 75p / 25s | 0x00C0 | 0x0040 | 8 x 32 | 125,000 |
| RN.BASIC.165 | 0xFF | 50p / 50s | 0x0080 | 0x0080 | 8 x 32 | 125,000 |
| RN.BASIC.166 | 0xFF | 25p / 75s | 0x0040 | 0x00C0 | 8 x 32 | 125,000 |
| RN.BASIC.167 | 0x55 | 100p / 0s | 0x0100 | 0x0000 | 4 x 32 | 62,500 |
| RN.BASIC.168 | 0x55 | 75p / 25s | 0x00C0 | 0x0040 | 4 x 32 | 62,500 |
| RN.BASIC.169 | 0x55 | 50p / 50s | 0x0080 | 0x0080 | 4 x 32 | 62,500 |
| RN.BASIC.170 | 0x55 | 25p / 75s | 0x0040 | 0x00C0 | 4 x 32 | 62,500 |
| RN.BASIC.171 | 0xAA | 100p / 0s | 0x0100 | 0x0000 | 4 x 32 | 62,500 |
| RN.BASIC.172 | 0xAA | 75p / 25s | 0x00C0 | 0x0040 | 4 x 32 | 62,500 |
| RN.BASIC.173 | 0xAA | 50p / 50s | 0x0080 | 0x0080 | 4 x 32 | 62,500 |
| RN.BASIC.174 | 0xAA | 25p / 75s | 0x0040 | 0x00C0 | 4 x 32 | 62,500 |
| RN.BASIC.175 | 0x01 | 100p / 0s | 0x0100 | 0x0000 | 1 x 32 | 15,625 |
| RN.BASIC.176 | 0x01 | 75p / 25s | 0x00C0 | 0x0040 | 1 x 32 | 15,625 |
| RN.BASIC.177 | 0x01 | 50p / 50s | 0x0080 | 0x0080 | 1 x 32 | 15,625 |
| RN.BASIC.178 | 0x01 | 25p / 75s | 0x0040 | 0x00C0 | 1 x 32 | 15,625 |
| RN.BASIC.179 | 0x02 | 100p / 0s | 0x0100 | 0x0000 | 1 x 32 | 15,625 |
| RN.BASIC.180 | 0x02 | 75p / 25s | 0x00C0 | 0x0040 | 1 x 32 | 15,625 |
| RN.BASIC.181 | 0x02 | 50p / 50s | 0x0080 | 0x0080 | 1 x 32 | 15,625 |
| RN.BASIC.182 | 0x02 | 25p / 75s | 0x0040 | 0x00C0 | 1 x 32 | 15,625 |
| RN.BASIC.183 | 0x04 | 100p / 0s | 0x0100 | 0x0000 | 1 x 32 | 15,625 |
| RN.BASIC.184 | 0x04 | 75p / 25s | 0x00C0 | 0x0040 | 1 x 32 | 15,625 |
| RN.BASIC.185 | 0x04 | 50p / 50s | 0x0080 | 0x0080 | 1 x 32 | 15,625 |
| RN.BASIC.186 | 0x04 | 25p / 75s | 0x0040 | 0x00C0 | 1 x 32 | 15,625 |
| RN.BASIC.187 | 0x10 | 100p / 0s | 0x0100 | 0x0000 | 1 x 32 | 15,625 |
| RN.BASIC.188 | 0x10 | 75p / 25s | 0x00C0 | 0x0040 | 1 x 32 | 15,625 |
| RN.BASIC.189 | 0x10 | 50p / 50s | 0x0080 | 0x0080 | 1 x 32 | 15,625 |
| RN.BASIC.190 | 0x10 | 25p / 75s | 0x0040 | 0x00C0 | 1 x 32 | 15,625 |
| RN.BASIC.191 | 0x40 | 100p / 0s | 0x0100 | 0x0000 | 1 x 32 | 15,625 |
| RN.BASIC.192 | 0x40 | 75p / 25s | 0x00C0 | 0x0040 | 1 x 32 | 15,625 |
| RN.BASIC.193 | 0x40 | 50p / 50s | 0x0080 | 0x0080 | 1 x 32 | 15,625 |
| RN.BASIC.194 | 0x40 | 25p / 75s | 0x0040 | 0x00C0 | 1 x 32 | 15,625 |

**Total RN.BASIC = 194 cases.**

The full 194-row plan lives in `scripts/cotest/phase4_5_sweep.py:rn_basic_plan()`.
Run any individual row with:
```bash
PHASE4_5_BUILD_DIR=<build-dir> swb_ring_lock python3 scripts/cotest/phase4_5_sweep.py --row RN.BASIC.<idx>
```

**RN.BASIC verdict:** layout reshape 2026-05-12 to 4-injector-mode slices;
codex1 BASIC sweep + arbfix board retest under the new 208-row plan are
pending dispatch. Prior 32-row sim sweep PASS evidence (commit `967845b5`)
maps to a subset of slice 1 (periodic mode at lane=0xFF, chan=0xFFFFFFFF,
rate sweep).

---

## 5. Cosim as a per-row evidence stream

The dual-UVM FEB <-> SWB cosim at `cosim/` is the **sim** evidence stream for
every RN.BASIC row (and every other RN row in other buckets). When a row
runs, the harness produces a cosim transcript at:

`firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/cosim/REPORT/<row_id>/`

with the 6 checkpoints (pre-rbCAM, post-rbCAM, FEB egress, SWB ingress, OPQ
egress, RDMA egress) for that row.

Parallel execution: up to **30 cosim invocations** in parallel (see
`cosim/doc/COSIM_USAGE.md`). The 128 RN.BASIC rows complete in roughly 5
batches of 30 (~15 min wall) vs ~6 hours sequential.

---

## 6. Cross-references

- Per-row board evidence: `firmware_builds/systems/v3_pretest-260511-emutype0-dualport*/sweep_evidence/<row_id>/`
- Per-row sim evidence: `firmware_builds/systems/system_20260504_emulator_type0/tb_int/feb_swb_corun/sim_evidence/<row_id>/`
- HTML cross-validation: `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/PHASE4_5_SWEEP_REPORT.html`
