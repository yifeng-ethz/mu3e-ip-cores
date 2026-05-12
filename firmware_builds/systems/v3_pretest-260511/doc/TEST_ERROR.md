# TEST_ERROR.md - ERROR bucket

**Parent:** [TEST_PLAN.md](TEST_PLAN.md)
**Siblings:** [TEST_BU.md](TEST_BU.md), [TEST_BASIC.md](TEST_BASIC.md), [TEST_PERF.md](TEST_PERF.md), [TEST_EDGE.md](TEST_EDGE.md)
**ID range:** RC.ERROR.001-006, RN.ERROR.001-006
**Total:** 12 cases

**Methodology key:** **E** (error-injection): drive an illegal opcode order or
out-of-bound CSR value; scoreboard asserts the IP rejects / errors / preserves
invariants rather than corrupts state.

**Bucket purpose:** verify graceful rejection of illegal stimulus. The IP must
NOT corrupt valid CSRs and must NOT wedge the SC plane. Where the spec defines
an error sticky / error counter, that must increment; where the spec says reject,
the operation must no-op.

**Evidence model (ERROR):** E1 shows the rejection footprint (error counter set,
specific `LAST_CMD` value, error sticky asserted). E2 and E3 may be empty (the
illegal stimulus typically produces no valid hits). PASS criterion is
"contract upheld" rather than count parity.

---

## 1. Summary

| Section | Cases | ID range | What it Proves | Function Reference |
|---|---:|---|---|---|
| RC.ERROR | 6 | RC.ERROR.001-006 | illegal opcode sequences; FSM either rejects or transitions to ERROR; no corruption | tb_int harness |
| RN.ERROR | 6 | RN.ERROR.001-006 | invalid configurations during run; arb / hist / runctl reject gracefully | tb_int + on-board (selective) |

---

## 2. RC.ERROR - Illegal opcode sequences

**Common pass criterion:** the IP rejects the illegal stimulus without
corrupting valid CSRs; SC plane stays alive.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| RC.ERROR.001 | E | 0x12 START before 0x11 SYNC | 1 | drive 0x10, then 0x12 directly (skip 0x11) | runctl FSM either rejects 0x12 OR transitions to ERROR state; STATUS reflects error; no hit traffic | tb_int |
| RC.ERROR.002 | E | double 0x10 RUN_PREPARE | 1 | drive 0x10, 0x10 | second 0x10 either no-ops or sets error; FSM state stable | tb_int |
| RC.ERROR.003 | E | 0x10 during RUNNING | 1 | drive 0x10..0x12, then 0x10 inside RUNNING | second 0x10 rejected; STATUS=RUNNING preserved | tb_int |
| RC.ERROR.004 | E | 0x30 RESET during RUNNING | 1 | drive 0x10..0x12, then 0x30 inside RUNNING | bounded `ext_hard_reset` pulse fires; arb MODE clears; FSM goes to RESETTING then IDLE; SC plane stays alive per `abb3e455` | tb_int + on-board (controlled) |
| RC.ERROR.005 | E | Unknown opcode 0x77 | 1 | drive an undefined opcode value | RX_ERR_COUNT +1; LAST_CMD unchanged; no FSM transition | tb_int |
| RC.ERROR.006 | E | 0x13 END before 0x12 START | 1 | drive 0x10, 0x11, 0x13 (skip 0x12) | runctl FSM either rejects 0x13 OR returns to IDLE; no hits emitted | tb_int |

**RC.ERROR verdict:** pending; tb_int harness exists at `feb_swb_corun`.

---

## 3. RN.ERROR - Invalid run-time configurations

**Common pre-condition:** start from a clean IDLE state. Each row may leave the
FSM in a non-IDLE state; the runner must perform explicit recovery between
rows.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| RN.ERROR.001 | E | arb MODE = invalid (3) | 1 | write MODE=3 (reserved) on every lane; drive run | arb either clamps to a valid MODE OR sets error sticky; no corruption of other CSRs | tb_int |
| RN.ERROR.002 | E | emulator rate=0 with channels enabled | 1 | rate_88fp=0, channel_mask=0xFFFFFFFF, lane_mask=0xFF | run completes; E1=0 (no hits); no FSM hang; STATUS returns to IDLE | `phase4_5_sweep.py` (on-board safe) |
| RN.ERROR.003 | E | hist LEFT > RIGHT bound | 1 | write LEFT_BOUND=255, RIGHT_BOUND=0; drive run | hist asserts UNDERFLOW or OVERFLOW per spec; total_hits = 0 | `phase4_5_sweep.py` |
| RN.ERROR.004 | E | channel_mask = 0 + lane_mask = 0xFF | 1 | lane_mask=0xFF, channel_mask=0x00000000 | E1 = 0 (no hits); arb shows ingress = 0; clean IDLE | `phase4_5_sweep.py` |
| RN.ERROR.005 | E | Configure mid-RUNNING | 1 | drive 0x12; write arb MODE inside RUNNING | per `abb3e455`, arb MODE writes don't take effect mid-run (RESET-only clear); MODE stays at pre-RUN setting | tb_int + on-board |
| RN.ERROR.006 | E | Reset asserted twice rapidly | 1 | drive 0x30, then 0x30 again within 10 cycles | second 0x30 either no-ops or extends pulse; SC plane stable per `abb3e455` | tb_int |

**RN.ERROR verdict:** pending; harness exists at `feb_swb_corun`.

---

## 4. Cross-references

- arb MODE-clear topology fix: commit `abb3e455`
- SC-WEDGE on-board verification: commit `5bd7e112`
- BUG_HISTORY.md: `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/BUG_HISTORY.md`
