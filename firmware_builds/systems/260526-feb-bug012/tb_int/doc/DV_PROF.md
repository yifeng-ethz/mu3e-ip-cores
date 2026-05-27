# 260518-feb-ok tb_int — Performance / Soak Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** P001-P999
**Total:** 1 cases (1 implemented / 0 waived)

Sustained-rate + soak validation on the FEB v3 integration boundary.

**Methodology key:**
- **D** = Directed (hand-crafted stimulus)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog rand)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---|---|---|---|
| qsys_type1_delay soak (T1) | 1 | P001-P001 | mts_preprocessor.hit_type1_ts conduit delivers 48-bit timestamps to histogram_statistics_v2.type1_{up,down}_ts at sustained rate; no underflow / overflow / drop | implemented |

---

## 2. qsys_type1_delay soak (T1) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| P001 | D | 4-bank dual-port hit_type1_ts conduit soak | 1 | Drive 100 kHz Type1 traffic into mts_preprocessor_0 + mts_preprocessor_1 for 10 ms. The conduit binding mts_preprocessor.hit_type1_ts -> histogram_statistics_v2.type1_{up,down}_ts is the eb67302-merged interface restored in mts_processor 26.3.5.0518 | observed Type1 hit count is within 5% of expected; underflow_cnt == 0; overflow_cnt == 0; coalescer occupancy_max <= 12; matches the legacy soak in `trash_bin/legacy_scenarios/qsys_type1_delay/`. | TBD |
