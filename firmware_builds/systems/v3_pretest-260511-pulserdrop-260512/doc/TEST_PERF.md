# TEST_PERF.md - PERF bucket

**Parent:** [TEST_PLAN.md](TEST_PLAN.md)
**Siblings:** [TEST_BU.md](TEST_BU.md), [TEST_BASIC.md](TEST_BASIC.md), [TEST_ERROR.md](TEST_ERROR.md), [TEST_EDGE.md](TEST_EDGE.md)
**ID range:** SC.AG.001-008, RN.PROF.001-007
**Total:** 15 cases

**Methodology key:**
- **P** (perf): performance / saturation; uses theoretical-delta accounting.
- **D** (directed): single deterministic stimulus with a golden expectation.
- **E** (error-injection): drive an intentional contract stress; observe rejection.

**Bucket purpose:** stress tests that approach or exceed the OPQ ingress
ceiling, or that pile concurrent SC traffic on top of a RUNNING window.
Loss is expected by design; the row passes when measured loss matches the
theoretical-clipping curve within tolerance.

**Evidence model (PERF):** every row carries **three agreeing evidence
streams** - theory (math reference, clipped at OPQ ceiling), sim (dual-UVM
FEB-SWB cosim), and board. All three must collectively sit below
`theoretical_hits` by the saturation delta and agree with each other on the
clipping shape. A row PASSES if the measured loss matches the predicted
clipped curve within tolerance. Long-soak rows (>= 10 s) may waive the
**sim** evidence stream and rely on theory + board only - the row's
`cosim_waived` flag must be set explicitly in the test record.

---

## 1. Summary

| Section | Cases | ID range | What it Proves | Function Reference |
|---|---:|---|---|---|
| SC.AG | 8 | SC.AG.001-008 | SC plane reads during RUNNING do not disrupt hit traffic; reads return monotone snapshots | sc_tool + `phase4_5_sweep.py` |
| RN.PROF | 7 | RN.PROF.001-007 | OPQ ingress saturation curve at 50% / 100% / 150% / 200% / 6-lane / 2-lane + 10 s long-soak | `phase4_5_sweep.py` + `scripts/cotest/phase4_5_longsoak.py` |

---

## 2. SC.AG - Slow control aggressive (read DURING RUNNING)

**Pre-condition:** drive a low-rate RUNNING window (RN.BASIC.001-style)
concurrently issue SC reads.

**Pass criteria:** SC reads return valid live snapshots (monotone non-decreasing
for counters); the concurrent SC traffic does not increase DROPPED_HITS or
disturb the post-TERM E1 counters vs the same row run without concurrent SC.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| SC.AG.001 | D | hist TOTAL_HITS_CSR13 during RUNNING | 8 | read csr13 every 100 us during 1 ms RUNNING | each read is a monotone non-decreasing snapshot | `phase4_5_sweep.py` |
| SC.AG.002 | D | hist hist_bin[0..255] during RUNNING | 1 | full 256-word bin read mid-run | individual-word reads succeed; bin values are monotone non-decreasing | `phase4_5_sweep.py:snap_hist_bin()` |
| SC.AG.003 | D | arb selected_count during RUNNING | 8 | per-lane SELECTED_COUNT every 100 us | monotone non-decreasing | sc_tool |
| SC.AG.004 | D | mts PORT_STATUS during RUNNING | 8 | poll PORT_STATUS every 100 us | not stuck at 0x000000FF; FIFO levels evolve | sc_tool |
| SC.AG.005 | D | rbCAM debug_msg2.push_cnt during RUNNING | 8 | poll push_cnt every 100 us | monotone non-decreasing | sc_tool |
| SC.AG.006 | D | runctl RX_CMD_COUNT during RUNNING | 1 | read RX_CMD_COUNT inside RUNNING | reads valid; LAST_CMD = 0x12 | sc_tool |
| SC.AG.007 | D | concurrent burst-read does not stall pipeline | 1 | 64-word read burst during RUNNING; compare E1 vs identical row without burst | E1 deltas match within 5% | `phase4_5_sweep.py` + harness |
| SC.AG.008 | E | hist_bin BURST read corruption | 1 | intentional multi-word hist_bin burst read mid-run | DROPPED_HITS may increase; SC ring does NOT wedge (per BUG-006-S precaution) | `phase4_5_sweep.py` (uses single-word reads to avoid) |

**SC.AG verdict:** BUG-006-S documented (burst hist_bin reads corrupt the SC
bridge); the single-word-read workaround in `phase4_5_sweep.py` is the canonical
safe path. SC.AG.001-007 PASS pending arbfix retest.

---

## 3. RN.PROF - Saturation curve

Probes the OPQ ingress ceiling explicitly. Rate selected so requested aggregate
exceeds the BASIC threshold of 50% ceiling. `opq_ceiling_hps = 250e6` per user
spec.

**Common stimulus:** lane_mask = 0xFF, channel_mask = 0xFFFFFFFF unless noted,
hit_mode = 0x00 direct, 1 ms RUNNING, INTERVAL_CFG_NEVER_FIRE for E1 readout.

| ID | Method | Scenario | Iter | Rate (target) | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| RN.PROF.001 | P | 50% ceiling | 1 | rate so requested = 0.5 x ceiling | E1 = theoretical (no loss); board_delta_pct < 5% | `phase4_5_sweep.py` |
| RN.PROF.002 | P | 100% ceiling (knee) | 1 | requested = 1.0 x ceiling | E1 ~ theoretical with small saturation margin; DROPPED_HITS small but nonzero | `phase4_5_sweep.py` |
| RN.PROF.003 | P | 150% ceiling | 1 | requested = 1.5 x ceiling | E1 = theoretical (clipped at ceiling); DROPPED_HITS > 0 | `phase4_5_sweep.py` |
| RN.PROF.004 | P | 200% ceiling | 1 | requested = 2.0 x ceiling | E1 = theoretical (clipped); board_delta matches saturation curve | `phase4_5_sweep.py` |
| RN.PROF.005 | P | 6 lanes admitted at ceiling | 1 | lane_mask popcount=6, rate at ceiling-equivalent | E1 = theoretical for the 6-lane aggregate; per-lane SELECTED_COUNT divides evenly | `phase4_5_sweep.py` |
| RN.PROF.006 | P | 2 lanes admitted at ceiling | 1 | lane_mask popcount=2, rate at ceiling-equivalent | E1 = theoretical for the 2-lane aggregate | `phase4_5_sweep.py` |

**RN.PROF verdict:** RN.PROF.002-004 partially observed via `p45_019` (rate 0x4000
clips per the earlier 32-row sweep). Saturation knee documented in
`firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/doc/PHASE4_5_SWEEP_FAIL_ANALYSIS.md`.

---

## 4. RN.PROF.007 - Long-soak

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| RN.PROF.007 | P | 10 s long-soak (`cosim_waived=true`) | 1 | `phase4_5_longsoak.py --interval-ms 1.0`, rate = 0.5 x ceiling, RUNNING window = 10 s (explicit long-soak exception to the 1 ms convention; sim evidence waived because cosim wall-time at 10 s is prohibitive) | theory + board agree within tolerance; bank-toggle regularity stddev < 1 ms across 10000 intervals; E1 = theoretical over the full 10 s window; per-interval E2 readout shape matches at every bank-swap | `scripts/cotest/phase4_5_longsoak.py` |

**RN.PROF.007 verdict:** pending on-board; cosim evidence stream is waived
per the long-soak exception (theory + board comparison only). All other
PERF rows still carry full theory / sim / board.

---

## 5. Cross-references

- Per-row board evidence: `firmware_builds/systems/v3_pretest-260511-emutype0-dualport*/sweep_evidence/<row_id>/`
- Saturation knee analysis: `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/doc/PHASE4_5_SWEEP_FAIL_ANALYSIS.md`
- HTML rate-normalized + theoretical-delta cross-validation: `firmware_builds/systems/v3_pretest-260511-emulator-type0-260512/doc/PHASE4_5_SWEEP_REPORT.html`
