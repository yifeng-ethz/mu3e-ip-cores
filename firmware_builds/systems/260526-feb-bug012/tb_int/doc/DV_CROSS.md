# 260518-feb-ok tb_int — Cross / Continuous-Frame Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** C001-C999
**Total:** 3 cases (1 implemented / 0 waived)

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
| MCC ASIC configure/readback loop with hist_bin burst (MCC) | 1 | C002 | A CSR write to mutrig_cfg_ctrl_0 triggers the controller's (configure*8 + wait + readback*8) * 64 tth_steps loop; the per-step 1 s wait is bypassed by a hierarchical `force` on the wait counter; on each readback the controller's avmm_cnt master issues a 256-word burst read of hist_bin through the v4 ctrl2data bridge, sharing arbitration with sc_hub | pending |
| Dual-DEBUG_LEVEL OoO datapath scoreboard (DOO) | 1 | C003 | The SAME LVDS-RX stimulus replayed against the DEBUG_LEVEL=0 and DEBUG_LEVEL=2 generated DUTs delivers the same hit set to the upload egress; per-hit OoO scoreboard matches by (ASIC, channel, TS) and reports zero unmatched | pending |

---

## 2. Basic-bucket continuous frame (BB) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| C001 | D | bucket_frame BASIC composer | 1 | Compose B001 sequence followed by B002 sequence in one continuous timeframe; no reset between them; reuse the boundary agents | both B001 and B002 pass criteria still hold; merged code coverage reported separately in [DV_COV.md](DV_COV.md); UVM_ERROR == 0; UVM_FATAL == 0. | TBD |

---

## 3. MCC ASIC configure/readback loop with hist_bin burst (MCC) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| C002 | D | Real mutrig_cfg_ctrl_0 host-triggered configure / wait / readback loop driving a 256-word hist_bin burst per step | 1 | (i) Pre-load hist_bin (Region B sc-byte 0x028000) with 256 distinct monotonic values via sc_hub. (ii) Through sc_hub.m0 write the mutrig_cfg_ctrl_0 CSR sequence that arms the controller's `(configure*8 ASICs + wait + readback*8 ASICs) * 64 tth_steps` loop, then write the GO bit. (iii) The wait between configure and readback is the 1 s settle counter `mutrig_cfg_ctrl_0/.../wait_count_q`; force-skip it by hierarchical SV `force` (no RTL change) to a near-terminal value (count_max - 4) on each pass via a small monitor that watches the state register and pumps the counter when state == `WAIT_SETTLE`. (iv) On each readback step, mutrig_cfg_ctrl_0.avmm_cnt issues a burstcount=256 read of hist_bin through the v4 ctrl2data bridge; in 8 of the 64 tth_steps, ALSO arm a sc_hub.m0 read of hist_bin so the bridge arbiter has to interleave. | (a) All 64 tth_steps complete; on each step avmm_cnt captures 256 words matching the pre-loaded sequence; (b) sc_hub-interleaved steps still see correct words on both masters; (c) the bridge arbiter never starves either master for more than one full burst window; (d) controller FSM ends in `DONE`; (e) the only modification of the DUT is the hierarchical `force` on `wait_count_q` (no signal redirected, no module replaced); (f) UVM_ERROR == 0. | TBD |

---

## 4. Dual-DEBUG_LEVEL OoO datapath scoreboard (DOO) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| C003 | D | Same LVDS-RX stimulus replayed against the DEBUG_LEVEL=0 and DEBUG_LEVEL=2 generated DUTs in PARALLEL, per-hit OoO scoreboard | 1 | (i) Instantiate the v4 generated DUT TWICE in tb_top: `dut_d0` bound to `generated/synthesis/feb_system_v4/` (DEBUG_LEVEL=0) and `dut_d2` bound to `generated/simulation/feb_system_v4/` (DEBUG_LEVEL=2). (ii) Drive identical LVDS-RX stimulus to both DUTs from one shared emulator/jitter generator. (iii) Drive identical SC-hub configuration (channel mask, hit mode, RUN_PREP/RUNNING handshake) to both DUTs. (iv) Tap the upload_subsystem hit egress on both DUTs. (v) An OoO scoreboard collects hits from each side keyed by (ASIC, channel, TS, hit_type) and matches them; report unmatched hits + age + side. | (a) For at least 100 ms of stimulated traffic across all 8 ASICs at >= 50 kHz/channel, every hit emitted by `dut_d0` is matched by an identical hit in `dut_d2` within an OoO window of 1024 hits; (b) `dut_d2` emits at most `EXTRA_DEBUG_INSTRUMENTATION_WINDOW` extra non-data words (the DEBUG_LEVEL=2 instrumentation overhead), and these are explicitly filtered before scoreboard match; (c) zero scoreboard unmatched at end of test; (d) the two DUTs use IDENTICAL clock periods and reset releases; (e) UVM_ERROR == 0; (f) coverage UCDB collects per-(ASIC, channel) hit counts on BOTH sides. | TBD |
