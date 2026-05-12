# TEST_BASIC.md - BASIC bucket

**Parent:** [TEST_PLAN.md](TEST_PLAN.md)
**Siblings:** [TEST_BU.md](TEST_BU.md), [TEST_PERF.md](TEST_PERF.md), [TEST_ERROR.md](TEST_ERROR.md), [TEST_EDGE.md](TEST_EDGE.md)
**ID range:** SC.BASIC.001-012, RC.BASIC.001-011, RN.BASIC.001-128
**Total:** 151 cases

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
| RN.BASIC | 128 | RN.BASIC.001-128 | 4 emul-mode sub-buckets (iid_only / clustered_only / mixed / bkg_only), each 8 lane_mask x 4 channel_mask at rate=0x0100; theoretical-delta < 5% in sim and board | `scripts/cotest/phase4_5_sweep.py:rn_basic_plan()` + `cosim/Makefile` |

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

**Total: 128 cases**, organised in 4 emulator-hit-mode sub-buckets of 32
cases each. Anchor on the typical operating point and vary lane / channel
within each emulator mode so a regression on any single axis is readable
from the row neighbourhood within a sub-bucket.

**Anchor (typical):** `lane_mask=0xFF`, `channel_mask=0xFFFFFFFF`,
`rate_88fp=0x0100`, `injector_mode=0` (off), emulator hit-mode = iid_only.
This is the all-channel / all-ASIC operating point at 50% of the OPQ
ingress ceiling (125,000 hits per 1 ms window).

**Emulator hit-mode encoding (per `frontend_csr.sv` CSR bits):**

| sub-bucket | label | sig | cluster | bkg | meaning |
|---|---|---|---|---|---|
| A | iid_only | 1 | 0 | 0 | Poisson-IID hits per channel, no clustering, no background |
| B | clustered_only | 0 | 1 | 0 | clustered hit bursts on geometric pattern, no IID, no background |
| C | mixed | 1 | 1 | 0 | iid AND clustered hits superimposed on the signal path |
| D | bkg_only | 0 | 0 | 1 | background-only hits via the dedicated bkg generator (rate set by bkg CSR, not rate_88fp) |

**Injector pulse mode** (`mutrig_injector_multiheader` CSR `mode`):
fixed at `0` (off) across BASIC; headersync (mode 1) and periodic (mode 2)
injector coverage lives in `TEST_EDGE.md` as dedicated directed rows.
Async (mode 3) is dropped from BASIC and EDGE per 2026-05-12 directive.

**Common per-row stimulus:**
- `INTERVAL_CFG = INTERVAL_CFG_NEVER_FIRE (0xFFFFFFFF)` so the full window
  accumulates as one bank (E1 readout via post-TERM csr13)
- LEFT_BOUND=0, RIGHT_BOUND=255, BIN_WIDTH=1
- 1 ms RUNNING window in sim and on board
- Opcode sequence: 0x10 -> 0x11 -> 0x12 -> wait RUNNING -> 0x13
- `rate_88fp = 0x0100` fixed across all sub-buckets

**Common per-row pass criteria:**
- theory (math reference): `theoretical_hits` = `popcount(lane) *
  popcount(chan) * rate_88fp/65536 * 125e6 * 1e-3`, clipped at the OPQ
  ingress ceiling (250,000 hits per 1 ms window)
- sim (cosim): |delta vs theory| < 5%
- board: |delta vs theory| < 5%
- E2 (hist_bin sum + per-interval shape): matches E1 within +/- 8
- E3 (RDMA dump): record count matches E1 within +/- 8
- For sub-bucket D (`bkg_only`): theoretical_hits is set by the bkg CSR
  rate field, not `rate_88fp`; the table values are placeholders against
  the same lane/chan popcount math at `rate_88fp = 0x0100` so the row-
  level diff is consistent, but the actual board / sim total depends on
  the bkg CSR programmed at row start (the runner script sets it)

| ID | lane_mask | channel_mask | popcount L x C | theoretical_hits | clipped_hits |
|---|---|---|---:|---:|---:|
| RN.BASIC.001 | 0xFF | 0xFFFFFFFF | 8 x 32 | 125,000 | 125,000 |
| RN.BASIC.002 | 0xFF | 0x0000FFFF | 8 x 16 | 62,500 | 62,500 |
| RN.BASIC.003 | 0xFF | 0x55555555 | 8 x 16 | 62,500 | 62,500 |
| RN.BASIC.004 | 0xFF | 0x00000001 | 8 x 1 | 3,906 | 3,906 |
| RN.BASIC.005 | 0x55 | 0xFFFFFFFF | 4 x 32 | 62,500 | 62,500 |
| RN.BASIC.006 | 0x55 | 0x0000FFFF | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.007 | 0x55 | 0x55555555 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.008 | 0x55 | 0x00000001 | 4 x 1 | 1,953 | 1,953 |
| RN.BASIC.009 | 0xAA | 0xFFFFFFFF | 4 x 32 | 62,500 | 62,500 |
| RN.BASIC.010 | 0xAA | 0x0000FFFF | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.011 | 0xAA | 0x55555555 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.012 | 0xAA | 0x00000001 | 4 x 1 | 1,953 | 1,953 |
| RN.BASIC.013 | 0x01 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.014 | 0x01 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.015 | 0x01 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.016 | 0x01 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.017 | 0x02 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.018 | 0x02 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.019 | 0x02 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.020 | 0x02 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.021 | 0x04 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.022 | 0x04 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.023 | 0x04 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.024 | 0x04 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.025 | 0x10 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.026 | 0x10 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.027 | 0x10 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.028 | 0x10 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.029 | 0x40 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.030 | 0x40 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.031 | 0x40 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.032 | 0x40 | 0x00000001 | 1 x 1 | 488 | 488 |

**Sub-bucket B - clustered_only (sig=0, cluster=1, bkg=0) (32 cases): rate_88fp=0x0100, injector_mode=0 (off)**

| ID | lane_mask | channel_mask | popcount L x C | theoretical_hits | clipped_hits |
|---|---|---|---:|---:|---:|
| RN.BASIC.033 | 0xFF | 0xFFFFFFFF | 8 x 32 | 125,000 | 125,000 |
| RN.BASIC.034 | 0xFF | 0x0000FFFF | 8 x 16 | 62,500 | 62,500 |
| RN.BASIC.035 | 0xFF | 0x55555555 | 8 x 16 | 62,500 | 62,500 |
| RN.BASIC.036 | 0xFF | 0x00000001 | 8 x 1 | 3,906 | 3,906 |
| RN.BASIC.037 | 0x55 | 0xFFFFFFFF | 4 x 32 | 62,500 | 62,500 |
| RN.BASIC.038 | 0x55 | 0x0000FFFF | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.039 | 0x55 | 0x55555555 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.040 | 0x55 | 0x00000001 | 4 x 1 | 1,953 | 1,953 |
| RN.BASIC.041 | 0xAA | 0xFFFFFFFF | 4 x 32 | 62,500 | 62,500 |
| RN.BASIC.042 | 0xAA | 0x0000FFFF | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.043 | 0xAA | 0x55555555 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.044 | 0xAA | 0x00000001 | 4 x 1 | 1,953 | 1,953 |
| RN.BASIC.045 | 0x01 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.046 | 0x01 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.047 | 0x01 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.048 | 0x01 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.049 | 0x02 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.050 | 0x02 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.051 | 0x02 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.052 | 0x02 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.053 | 0x04 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.054 | 0x04 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.055 | 0x04 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.056 | 0x04 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.057 | 0x10 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.058 | 0x10 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.059 | 0x10 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.060 | 0x10 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.061 | 0x40 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.062 | 0x40 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.063 | 0x40 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.064 | 0x40 | 0x00000001 | 1 x 1 | 488 | 488 |

**Sub-bucket C - mixed (sig=1, cluster=1, bkg=0) (32 cases): rate_88fp=0x0100, injector_mode=0 (off)**

| ID | lane_mask | channel_mask | popcount L x C | theoretical_hits | clipped_hits |
|---|---|---|---:|---:|---:|
| RN.BASIC.065 | 0xFF | 0xFFFFFFFF | 8 x 32 | 125,000 | 125,000 |
| RN.BASIC.066 | 0xFF | 0x0000FFFF | 8 x 16 | 62,500 | 62,500 |
| RN.BASIC.067 | 0xFF | 0x55555555 | 8 x 16 | 62,500 | 62,500 |
| RN.BASIC.068 | 0xFF | 0x00000001 | 8 x 1 | 3,906 | 3,906 |
| RN.BASIC.069 | 0x55 | 0xFFFFFFFF | 4 x 32 | 62,500 | 62,500 |
| RN.BASIC.070 | 0x55 | 0x0000FFFF | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.071 | 0x55 | 0x55555555 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.072 | 0x55 | 0x00000001 | 4 x 1 | 1,953 | 1,953 |
| RN.BASIC.073 | 0xAA | 0xFFFFFFFF | 4 x 32 | 62,500 | 62,500 |
| RN.BASIC.074 | 0xAA | 0x0000FFFF | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.075 | 0xAA | 0x55555555 | 4 x 16 | 31,250 | 31,250 |
| RN.BASIC.076 | 0xAA | 0x00000001 | 4 x 1 | 1,953 | 1,953 |
| RN.BASIC.077 | 0x01 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.078 | 0x01 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.079 | 0x01 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.080 | 0x01 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.081 | 0x02 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.082 | 0x02 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.083 | 0x02 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.084 | 0x02 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.085 | 0x04 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.086 | 0x04 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.087 | 0x04 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.088 | 0x04 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.089 | 0x10 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.090 | 0x10 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.091 | 0x10 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.092 | 0x10 | 0x00000001 | 1 x 1 | 488 | 488 |
| RN.BASIC.093 | 0x40 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 |
| RN.BASIC.094 | 0x40 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.095 | 0x40 | 0x55555555 | 1 x 16 | 7,812 | 7,812 |
| RN.BASIC.096 | 0x40 | 0x00000001 | 1 x 1 | 488 | 488 |

**Sub-bucket D - bkg_only (sig=0, cluster=0, bkg=1) (32 cases): rate_88fp=0x0100, injector_mode=0 (off)**

| ID | lane_mask | channel_mask | popcount L x C | theoretical_hits | clipped_hits |
|---|---|---|---:|---:|---:|
| RN.BASIC.097 | 0xFF | 0xFFFFFFFF | 8 x 32 | 125,000 | 125,000 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.098 | 0xFF | 0x0000FFFF | 8 x 16 | 62,500 | 62,500 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.099 | 0xFF | 0x55555555 | 8 x 16 | 62,500 | 62,500 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.100 | 0xFF | 0x00000001 | 8 x 1 | 3,906 | 3,906 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.101 | 0x55 | 0xFFFFFFFF | 4 x 32 | 62,500 | 62,500 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.102 | 0x55 | 0x0000FFFF | 4 x 16 | 31,250 | 31,250 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.103 | 0x55 | 0x55555555 | 4 x 16 | 31,250 | 31,250 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.104 | 0x55 | 0x00000001 | 4 x 1 | 1,953 | 1,953 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.105 | 0xAA | 0xFFFFFFFF | 4 x 32 | 62,500 | 62,500 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.106 | 0xAA | 0x0000FFFF | 4 x 16 | 31,250 | 31,250 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.107 | 0xAA | 0x55555555 | 4 x 16 | 31,250 | 31,250 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.108 | 0xAA | 0x00000001 | 4 x 1 | 1,953 | 1,953 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.109 | 0x01 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.110 | 0x01 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.111 | 0x01 | 0x55555555 | 1 x 16 | 7,812 | 7,812 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.112 | 0x01 | 0x00000001 | 1 x 1 | 488 | 488 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.113 | 0x02 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.114 | 0x02 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.115 | 0x02 | 0x55555555 | 1 x 16 | 7,812 | 7,812 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.116 | 0x02 | 0x00000001 | 1 x 1 | 488 | 488 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.117 | 0x04 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.118 | 0x04 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.119 | 0x04 | 0x55555555 | 1 x 16 | 7,812 | 7,812 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.120 | 0x04 | 0x00000001 | 1 x 1 | 488 | 488 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.121 | 0x10 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.122 | 0x10 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.123 | 0x10 | 0x55555555 | 1 x 16 | 7,812 | 7,812 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.124 | 0x10 | 0x00000001 | 1 x 1 | 488 | 488 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.125 | 0x40 | 0xFFFFFFFF | 1 x 32 | 15,625 | 15,625 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.126 | 0x40 | 0x0000FFFF | 1 x 16 | 7,812 | 7,812 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.127 | 0x40 | 0x55555555 | 1 x 16 | 7,812 | 7,812 (bkg-only rate scales by bkg CSR, not rate_88fp) |
| RN.BASIC.128 | 0x40 | 0x00000001 | 1 x 1 | 488 | 488 (bkg-only rate scales by bkg CSR, not rate_88fp) |

**Total RN.BASIC = 128 cases.**

The full 128-row plan lives in `scripts/cotest/phase4_5_sweep.py:rn_basic_plan()`.
Run any individual row with:
```bash
PHASE4_5_BUILD_DIR=<build-dir> swb_ring_lock python3 scripts/cotest/phase4_5_sweep.py --row RN.BASIC.<idx>
```

**RN.BASIC verdict:** prior 32-row sim sweep PASS at 10 ms RUNNING (commit
`967845b5`); 128-row sweep with 4 emulator-mode sub-buckets at 1 ms is the
new BASIC plan as of 2026-05-12; codex1 BASIC/PERF dispatch + arbfix board
retest are both pending under the new layout.

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
