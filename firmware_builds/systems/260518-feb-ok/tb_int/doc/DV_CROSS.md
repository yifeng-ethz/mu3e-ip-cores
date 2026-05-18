# 260518-feb-ok tb_int — Cross / Continuous-Frame Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** C001-C999
**Total:** 2 cases (1 implemented / 0 waived)

`bucket_frame` and `all_buckets_frame` continuous-frame composers per
dv-workflow rule 9. Their coverage UCDBs are reported separately from
the isolated per-case merged UCDB.

**Methodology key:**
- **D** = Directed (hand-crafted stimulus)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog rand)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---|---|---|---|
| Basic-bucket continuous frame (BB) | 1 | C001 | All BASIC cases (B001..B002) run back-to-back in one timeframe without DUT restart; no stale-state coupling between cases | implemented |
| avmm_cnt 256-word hist_bin burst (MCC) | 1 | C002 | mutrig_cfg_ctrl_0.avmm_cnt (already existing master port, currently dangling) in the ctrl-path subsystem can drive a 256-word burst read of hist_bin in the data-path subsystem through the new shared ctrl2data bridge, sharing arbitration with sc_hub | pending |

---

## 2. Basic-bucket continuous frame (BB) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| C001 | D | bucket_frame BASIC composer | 1 | Compose B001 sequence followed by B002 sequence in one continuous timeframe; no reset between them; reuse the boundary agents | both B001 and B002 pass criteria still hold; merged code coverage reported separately in [DV_COV.md](DV_COV.md); UVM_ERROR == 0; UVM_FATAL == 0. | TBD |

---

## 3. MCC master 256-word hist_bin burst (MCC) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| C002 | D | mutrig_cfg_ctrl_0.avmm_cnt drives a real burst read of hist_bin | 1 | Pre-load hist_bin (Region B sc-word 0x08400) with a monotonic 256-word sequence as in E002. Drive mutrig_cfg_ctrl_0.avmm_cnt (an existing dangling Avalon-MM master on the ctrl-path IP) to issue ONE burstcount=256 read at the hist_bin base; concurrently arm a sc_hub probe of the same slave so the Qsys arbiter has to interleave; verify avmm_cnt sees the full 256 words in order; run a second iteration with the sc_hub probe issued FIRST to swap arbitration order | avmm_cnt captures 256 words matching the pre-loaded sequence in both iterations; arbiter never starves either master for more than one full burst window; UVM_ERROR == 0; one ctrl2data bridge instance is shared between sc_hub.m0 and mutrig_cfg_ctrl_0.avmm_cnt per the proposed bridge architecture; matches the cross-subsystem burst envelope agreed in the addr-map proposal. | pending |
