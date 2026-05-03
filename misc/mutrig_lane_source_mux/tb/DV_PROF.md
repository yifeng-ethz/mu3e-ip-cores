# DV Prof - mutrig_lane_source_mux

**Companion docs:** `README.md`, `DV_PLAN.md`, `DV_HARNESS.md`,
`DV_BASIC.md`, `DV_CROSS.md`, `DV_COV.md`, `BUG_HISTORY.md`

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** P001-P003
**Total:** 3 cases (3 implemented / 0 waived)

**Methodology key:**
- **D** = Directed
- **R** = Constrained-random

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| Random Directed-Case Soaks | 3 | P001-P003 | Long pressure, random case selection, and timing-fix functional stability. | 3/3 |

## 2. Random Directed-Case Soaks

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| P001 | R | Valid-qualified random directed-case soak | >=30s wall | `mlsm_soak_test`, `REAL_ALWAYS_VALID=0`, random picks from B001-B032. | No UVM errors; no scoreboard mismatch; run wall time at least 30s. | `mlsm_soak_test` |
| P002 | R | Validless random directed-case soak seed A | >=30s wall | `mlsm_soak_test`, `REAL_ALWAYS_VALID=1`, random picks from B033-B064. | No UVM errors; no selected-output accounting mismatch; run wall time at least 30s. | `mlsm_soak_test` |
| P003 | R | Validless random directed-case soak seed B | >=30s wall | Same as P002 with independent seed. | No UVM errors; no selected-output accounting mismatch; run wall time at least 30s. | `mlsm_soak_test` |
