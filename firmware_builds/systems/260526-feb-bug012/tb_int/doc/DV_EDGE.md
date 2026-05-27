# 260518-feb-ok tb_int — Edge / Corner Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** E001-E999
**Total:** 2 cases (1 implemented / 0 waived)

Corner + boundary conditions on the FEB v3 integration boundary.

**Methodology key:**
- **D** = Directed (hand-crafted stimulus)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog rand)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---|---|---|---|
| hist_bridge_switch repro (HS) | 1 | E001-E001 | Histogram source switching while pre/post packets are mid-fly does not stall the bridge | implemented |
| SC-hub 256-word hist_bin burst (HB256) | 1 | E002-E002 | sc_hub can drive a single 256-word burst read of hist_bin through the new ctrl2data bridge without splitting or losing words | pending |

---

## 2. hist_bridge_switch repro (HS) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| E001 | D | pre / post source switch with active packet | 1 | Configure histogram_ingress_bridge in pre-source mode; start a 128-hit packet; before EOP, request source switch to post; resume packet | bridge_pending falls within one toggle window; no packet stall; UVM_ERROR == 0; matches the hist_bridge_switch repro in `trash_bin/legacy_scenarios/hist_bridge_switch/`. | TBD |

---

## 3. SC-hub 256-word hist_bin burst (HB256) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| E002 | D | sc_hub max-burst read of hist_bin | 1 | Pre-load hist_bin with a known monotonic sequence of 256 distinct values (one per bin). Drive sc_hub_cmd_pipe.m0 to issue ONE Avalon read with burstcount=256 starting at the hist_bin base (Region B sc-word 0x08400); follow with one isolated burstcount=1 read at the same base to confirm the slave is clean afterwards | 256 returned words match the pre-loaded sequence in order; no burst split / no waitrequest pause longer than one cycle; ctrl2data_mm_bridge.maxBurstLength reports >= 256 in the elaboration report; the post-burst single read returns bin[0] unchanged; matches the sc_hub burst budget noted in the slow-control / hub v2 spec. | TBD |
