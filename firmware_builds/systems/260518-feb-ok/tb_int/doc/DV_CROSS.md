# 260518-feb-ok tb_int — Cross / Continuous-Frame Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** C001-C999
**Total:** 1 cases (1 implemented / 0 waived)

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

---

## 2. Basic-bucket continuous frame (BB) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| C001 | D | bucket_frame BASIC composer | 1 | Compose B001 sequence followed by B002 sequence in one continuous timeframe; no reset between them; reuse the boundary agents | both B001 and B002 pass criteria still hold; merged code coverage reported separately in [DV_COV.md](DV_COV.md); UVM_ERROR == 0; UVM_FATAL == 0. | TBD |
