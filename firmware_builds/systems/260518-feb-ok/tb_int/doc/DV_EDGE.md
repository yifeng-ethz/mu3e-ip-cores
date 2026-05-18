# 260518-feb-ok tb_int — Edge / Corner Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** E001-E999
**Total:** 1 cases (1 implemented / 0 waived)

Corner + boundary conditions on the FEB v3 integration boundary.

**Methodology key:**
- **D** = Directed (hand-crafted stimulus)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog rand)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---|---|---|---|
| hist_bridge_switch repro (HS) | 1 | E001-E001 | Histogram source switching while pre/post packets are mid-fly does not stall the bridge | implemented |

---

## 2. hist_bridge_switch repro (HS) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| E001 | D | pre / post source switch with active packet | 1 | Configure histogram_ingress_bridge in pre-source mode; start a 128-hit packet; before EOP, request source switch to post; resume packet | bridge_pending falls within one toggle window; no packet stall; UVM_ERROR == 0; matches the hist_bridge_switch repro in `trash_bin/legacy_scenarios/hist_bridge_switch/`. | TBD |
