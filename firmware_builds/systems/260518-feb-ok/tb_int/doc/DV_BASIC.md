# 260518-feb-ok tb_int — Basic Functional Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** B001-B999
**Total:** 4 cases (2 implemented / 0 waived)

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
| SC-hub direct slave probe (SP) | 1 | B003-B003 | UID and META[0]=VERSION readback over sc_hub reaches every slave inside the new ctrl2data / ctrl2upload bridge windows | pending |
| Per-subsystem JTAG reach (JR) | 1 | B004-B004 | Each of the 3 local JTAG masters reads every slave in its own subsystem; skips the cross-subsystem bridges and skips onewire_master_controller per the agreed contract | pending |

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

---

## 4. SC-hub direct slave probe (SP) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| B003 | D | sc_hub walks every slave in the rearranged map | 1 | For each slave in the proposed addr map (Region A direct + Region B data-path + Region C upload) issue a 1-word SC read of UID at offset 0 and a META-mux dance (write 0 then read offset 4) for VERSION; reuse `script/probe_feb_ip_inventory.py` shape | every reachable slave returns non-zero UID; sc_tool reports rsp=OK ack=1 for every probe; the slaves at the new Region B addresses no longer alias back to ctrl-path; the on-board run of probe_feb_ip_inventory.py mirrors the sim readout | TBD |

---

## 5. Per-subsystem JTAG reach (JR) -- 1 case

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| B004 | D | each of the 3 local JTAG masters walks all slaves in its own subsystem | 1 | Drive control_path_subsystem.jtag_master, data_path_subsystem.master_datapath, and upload_subsystem.upload_system_jtag_master in turn; each master reads UID at every slave local to its subsystem; sc_hub master is held idle so the readbacks come solely from the JTAG side | every per-subsystem slave answered by JTAG matches the sc_hub readout from B003; no JTAG master is wired to either cross-subsystem bridge or to onewire_master_controller; sc_hub remains the only path that can reach onewire | pending |
