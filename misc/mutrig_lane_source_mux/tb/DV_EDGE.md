# mutrig_lane_source_mux DV — Edge Cases

**Companion docs:** `README.md`, `DV_PLAN.md`, `DV_HARNESS.md`,
`DV_BASIC.md`, `DV_PROF.md`, `DV_ERROR.md`, `DV_CROSS.md`, `DV_COV.md`,
`BUG_HISTORY.md`

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** E001-E001
**Total:** 1 cases (0 implemented / 1 waived)

**Methodology key:**
- **D** = Directed
- **R** = Constrained-random

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---:|---|---|---|
| No Promoted Edge Cases | 1 | E001-E001 | Edge behavior is currently covered inside BASIC and PROF for this small mux. | waived |

## 2. No Promoted Edge Cases

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---:|---|---|---|
| E001 | D | Dedicated edge bucket waived | 0 | No standalone edge stimulus promoted for this constrained mux request. | Covered by BASIC mixed/direct boundary cases and PROF pressure runs. | waived |
