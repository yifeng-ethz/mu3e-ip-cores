# mutrig_lane_source_mux DV — Error Cases

**Companion docs:** `README.md`, `DV_PLAN.md`, `DV_HARNESS.md`,
`DV_BASIC.md`, `DV_EDGE.md`, `DV_PROF.md`, `DV_CROSS.md`, `DV_COV.md`,
`BUG_HISTORY.md`

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** X001-X001
**Total:** 1 cases (0 implemented / 1 waived)

**Methodology key:**
- **D** = Directed
- **R** = Constrained-random

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| No Promoted Error Cases | 1 | X001-X001 | Illegal-input and recovery cases are not promoted for this constrained mux request. | waived |

## 2. No Promoted Error Cases

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| X001 | D | Dedicated error bucket waived | 0 | No illegal-input or recovery stimulus promoted for this constrained mux request. | No error-bucket claim; BASIC/PROF cover legal traffic and pressure behavior. | waived |
