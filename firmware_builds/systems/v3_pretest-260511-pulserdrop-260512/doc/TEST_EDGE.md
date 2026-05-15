# TEST_EDGE.md - EDGE bucket

**Parent:** [TEST_PLAN.md](TEST_PLAN.md)
**Siblings:** [TEST_BU.md](TEST_BU.md), [TEST_BASIC.md](TEST_BASIC.md), [TEST_PERF.md](TEST_PERF.md), [TEST_ERROR.md](TEST_ERROR.md)
**ID range:** RN.EDGE.001-006
**Total:** 6 cases

**Methodology key:** **D** (directed): single deterministic stimulus with a
golden expectation.

**Bucket purpose:** corner cases of the LEGAL contract. Boundary masks,
single-channel / single-lane, sanity-negative (`lane_mask = 0x00`),
max-rate-without-overload, simultaneous SC + RUNNING. The contract is upheld
and the IP behaves at the corner.

**Evidence model (EDGE):** same as BASIC unless the row note declares an
exception. Most EDGE rows are tighter / more deterministic than the
generalised BASIC rows; they pass on a specific bit pattern in `hist_bin` or
a specific equality.

---

## 1. Summary

| Section | Cases | ID range | What it Proves | Function Reference |
|---|---:|---|---|---|
| RN.EDGE | 6 | RN.EDGE.001-006 | corner-case stimulus patterns; sanity-neg; max-rate without overload; SC+RUNNING concurrency | `phase4_5_sweep.py` + tb_int |

---

## 2. RN.EDGE - Corner cases

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| RN.EDGE.001 | D | single-channel single-lane | 1 | lane_mask=0x01, channel_mask=0x00000001, default rate, direct mode | only bin 0 populated; E1 = theoretical | `phase4_5_sweep.py` (existing row `p45_029`) |
| RN.EDGE.002 | D | sanity-neg lane_mask=0x00 | 1 | lane_mask=0x00, channel_mask=any | E1 = 0 (no hits); no false drops; arb shows zero ingress | `phase4_5_sweep.py` (existing row `p45_025`) |
| RN.EDGE.003 | D | max rate without overload | 1 | rate at exactly 50% ceiling | E1 = theoretical; DROPPED_HITS = 0; BASIC-bucket boundary verified | `phase4_5_sweep.py` |
| RN.EDGE.004 | D | burst-mode coverage | 1 | hit_mode=burst (SIGNAL=0x01); all-lanes; default rate | E2 shape = cluster centered at `burst_center` | `phase4_5_sweep.py` (existing row `p45_021`) |
| RN.EDGE.005 | D | periodic-mode coverage | 1 | hit_mode=periodic (SIGNAL=0x03); all-lanes; default rate | E2 shape = delta-function at periodic intervals | `phase4_5_sweep.py` (existing row `p45_022`) |
| RN.EDGE.006 | D | SC reads during RUNNING + EDGE config | 1 | concurrent SC.AG.001..008 during EDGE.001-style run | both EDGE.001 and SC.AG pass; E1 unaffected by concurrent SC traffic | combined harness |

**RN.EDGE verdict:** RN.EDGE.002 sim-vs-board inversion (`p45_025` lane-leak)
under arbfix retest in flight; other EDGE rows PASS in sim and pending
on-board arbfix retest. Injector-mode coverage (headersync, periodic, onclick)
now lives in RN.BASIC slices 1-3 per the 2026-05-12 reshape.

---

## 3. Cross-references

- Existing sweep row mapping (32-row plan to EDGE-style): RN.EDGE.001 = `p45_029`, RN.EDGE.002 = `p45_025`, RN.EDGE.004 = `p45_021`, RN.EDGE.005 = `p45_022`
- arb MODE-clear topology fix needed for EDGE.002 closure: commit `abb3e455`
- Sim-vs-board fail-mode analysis: `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/doc/PHASE4_5_SWEEP_FAIL_ANALYSIS.md`
