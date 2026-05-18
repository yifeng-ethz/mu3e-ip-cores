# 260518-feb-ok tb_int — Basic Functional Cases

**Companion docs:** [DV_PLAN.md](DV_PLAN.md), [DV_HARNESS.md](DV_HARNESS.md), [DV_COV.md](DV_COV.md), [BUG_HISTORY.md](BUG_HISTORY.md)
**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** B001-B999
**Total:** 6 cases (2 implemented / 0 waived)

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
| SC-hub direct slave probe (SP) | 3 | B003-B005 | UID, VERSION, and full CSR-aperture burst readback over sc_hub reaches every reachable slave inside the v4 ctrl2data / ctrl2upload bridge windows | pending |
| Per-subsystem JTAG reach (JR) | 1 | B006-B006 | Each of the 3 local JTAG masters reads every readable slave and writes-then-reads-back every RW register in its own subsystem; runs against the FULL unmodified generated DUT (no workaround) with the JTAG access modeled by a dedicated SV driver | pending |

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

## 4. SC-hub direct slave probe (SP) -- 3 cases

The on-board companion driver is `script/probe_feb_ip_inventory.py`
with `--mode {uid,version,full} [--burst N]`. The UVM cases below
exercise the SAME modes against the unmodified generated DUT
(`generated/simulation/feb_system_v4/`) before each on-board run.

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| B003 | D | sc_hub UID readback walks every slave in the v4 map | 1 | For each Avalon-MM slave enumerated from `generated/qsys/feb_system_v4.sopcinfo` issue ONE 1-word read at offset 0 through `control_path_subsystem.sc_hub_cmd_pipe.m0`; sc_hub_internal_csr at sc-word 0xFE80 is included; passthrough bridges and altera_avalon_sc_fifo CSR ports are reported as INFO only | every reachable slave returns rsp=OK ack=1; UID matches the IP's RTL CSR_WORD_0_CONST stamp when defined; on-board parity: `probe_feb_ip_inventory.py --mode uid` enumerates the same 22 endpoints with the same UIDs; UVM_ERROR == 0. | TBD |
| B004 | D | sc_hub UID + META[0] VERSION dance | 1 | For each slave, run B003's UID read followed by `write meta_sel=0 at offset 4` then `read offset 4` to capture the META[0]=VERSION word; one full pass over the v4 sopcinfo | every reachable slave returns rsp=OK ack=1 for both the UID and VERSION reads; VERSION matches the IP's packaging-skill `YY.MINOR.PATCH.MMDD` stamp; on-board parity: `probe_feb_ip_inventory.py --mode version` returns identical UID+VERSION; UVM_ERROR == 0. | TBD |
| B005 | D | sc_hub full-CSR burst readback | 4 | For each slave, issue one burst read of the full `addressSpan` words through `sc_hub_cmd_pipe.m0`. Iterate burst length over {1, 16, 64, 256} (256 is the mm_bridge MAX_BURST_SIZE); skip iterations where burst > slave span. Pre-load `scratch_pad_ram` and `hist_bin` with a known monotonic sequence to detect word-drop / out-of-order delivery | 256 reachable-slave bursts complete with rsp=OK ack=1; the post-burst single-word read at the same base returns the same word as the burst's first word; no waitrequest pause longer than one mm_bridge pipeline stage in the elaboration report; on-board parity: `probe_feb_ip_inventory.py --mode full --burst 256` produces a word-dump that matches the sim trace within the per-IP allowable readback-dynamics window (counters tolerated to drift between sim and live); UVM_ERROR == 0. | TBD |

---

## 5. Per-subsystem JTAG reach (JR) -- 1 case (B006)

| ID | Method | Scenario | Iter | Stimulus | Pass Criteria | Function Reference |
|---|---|---|---|---|---|---|
| B006 | D | each of the 3 local JTAG masters walks all slaves in its own subsystem | 1 | Run against the UNMODIFIED generated DUT (`generated/simulation/feb_system_v4/` with DEBUG_LEVEL=2). Model the JTAG master external access via a dedicated SV Avalon-MM driver bound to `<subsystem>.jtag_master.master` (NO workaround, NO simplified passthrough). For each of the 3 masters (`control_path_subsystem.jtag_master`, `data_path_subsystem.jtag_master_datapath`, `upload_subsystem.upload_system_jtag_master`): (i) walk every reachable slave in its OWN subsystem and read UID + first 4 words; (ii) for every register marked RW in the IP's SVD, write a deterministic 32-bit pattern (alternating 0xA5..A5 / 0x5A..5A / value+1), read it back, and restore the original value. Skip exactly the two contract exceptions: cross-subsystem mm_bridge slaves and `control_path_subsystem.onewire_master_0` (the link-layer master; the `onewire_master_controller_0` CSR IS exercised) | every read returns rsp=OK ack=1; every RW write+readback round-trip matches the pattern (with a coverage hole tolerated for self-clearing or hardware-side-effect registers explicitly tagged `<modifiedWriteValues>` in the SVD); no slave is reached through a path that requires sc_hub to be live; UVM_ERROR == 0. | TBD |
