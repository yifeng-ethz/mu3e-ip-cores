# 260518-feb-ok tb_int — Basic Functional Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** B001-B999
**Total:** 2 cases (2 implemented / 0 waived)

This bucket covers bring-up + protocol correctness on the FEB v3
integration boundary. Cases here drive the authentic generated firmware
under `firmware_builds/systems/260518-feb-ok/generated/simulation/feb_system_v3/`
via the UVM env in `tb_int/uvm/` per dv-workflow rule 19.

**Methodology key:**
- **D** = Directed (hand-crafted stimulus)
- **R** = Constrained-random (LCG-based PRNG; no SystemVerilog rand)

---

## 1. Summary

| Section | Cases | ID Range | What it Proves | Current Case |
|---|---|---|---|---|
| Upload mux backpressure (UB) | 1 | B001-B001 | hit_type3_upper ready loop is closed; SC packets and run-control idles reach upload egress under downstream backpressure | implemented |
| Histogram bank ping-pong (HB) | 1 | B002-B002 | scifi_datapath_system_v3 histogram_statistics_v2 bank toggle delivers monotonic ARB counts to host via SC | implemented |

---

## 2. Upload mux backpressure (UB) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| B001 | D | upload_pkt_mux ready_adapter mode | 1 | Drive in0 (Type3 hit stream) plus in1 (SC packet) plus in2 (run-control K28.5 idle) concurrently against the authentic generated upload_subsystem; assert downstream upload_data backpressure for 10 us; release backpressure | in1_sc_ready_pulses >= 4 within 200 us; in2_ready_pulses keeps the K28.5 idle running; sc_eop_accepted >= 1; UVM_ERROR == 0; matches the upload_backpressure ready_adapter marker from `trash_bin/legacy_scenarios/upload_backpressure/`. | TBD |

---

## 3. Histogram bank ping-pong (HB) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| B002 | D | hist_dualport dual-bank smoke | 1 | Configure histogram_statistics_v2 in dualport mode (channel_mask=0x00010000, hit_mode=Type0, rate=q16 0x0034). Run 100 ms. SC-read 256 bins through the live bank | hist_readout_nonzero == true; hist_drops_zero == true; total_hits within +/- 50% of target; matches the hist_dualport longsoak marker from `trash_bin/legacy_scenarios/hist_dualport/`. | TBD |
