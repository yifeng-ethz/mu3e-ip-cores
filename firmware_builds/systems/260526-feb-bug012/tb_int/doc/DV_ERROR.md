# 260518-feb-ok tb_int — Error / Reset / Recovery Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** X001-X999
**Total:** 1 cases (1 implemented / 0 waived)

Reset / fault / illegal-input / recovery validation on the FEB v3
integration boundary.

**Methodology key:**
- **D** = Directed (hand-crafted stimulus)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog rand)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---|---|---|---|
| upload backpressure broken-marker (UB) | 1 | X001-X001 | The pre-fix BUG-021-I shape (in0 starved, in1 SC packet held) is provoked and the recovery sequence restores in1 / in2 ready pulses | implemented |

---

## 2. upload backpressure broken-marker (UB) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| X001 | D | upload_backpressure broken-then-fixed A/B | 1 | Run the upload_backpressure scenario in broken mode (legacy adapter inUseReady=0); observe in0_valid_held >= 80, in0_ready_pulses >= 60, in1_sc_ready_pulses == 0; then run in ready_adapter mode | broken marker matches in1_sc_ready_pulses == 0 and in2_ready_pulses <= 1; ready_adapter marker matches in1_sc_ready_pulses >= 4 and in2_ready_pulses >= 1000; UVM_FATAL == 0; matches the upload_backpressure A/B repro from `trash_bin/legacy_scenarios/upload_backpressure/`. | TBD |
