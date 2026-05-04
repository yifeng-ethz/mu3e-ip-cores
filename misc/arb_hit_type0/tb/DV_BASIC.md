# DV Basic — `arb_hit_type0`

**Companion docs:** [`README.md`](../README.md), [`DV_PLAN.md`](DV_PLAN.md), [`DV_HARNESS.md`](DV_HARNESS.md), [`DV_EDGE.md`](DV_EDGE.md), [`DV_PROF.md`](DV_PROF.md), [`DV_ERROR.md`](DV_ERROR.md), [`DV_CROSS.md`](DV_CROSS.md), [`BUG_HISTORY.md`](BUG_HISTORY.md)

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** `B001`-`B099`
**Total:** 24 cases listed below.

This document expands every B-bucket entry in `DV_PLAN.md` section 4 into a directed test specification. It is the driver-facing elaboration of the plan: each case lists the exact stimulus sequence, expected scoreboard observations, and coverage bins. The CSR map lives in `arb_hit_type0_hw.tcl` (owned by the `ip-packaging` skill) and is **not** duplicated here.

---

## 1. Identity (B001-B003)

### B001_uid_read

- **ID:** B001_uid_read
- **Category:** CSR header / UID
- **Goal:** Prove that CSR word 0x0 reads back the frozen UID `AHT0` after reset.
- **Setup:** Hold `rst` for 16 clocks, release. No CSR or stream activity.
- **Stimulus sequence:**
  1. Wait 4 clocks after reset deassert.
  2. AVMM read word `0x0`.
- **Expected result:**
  1. Read returns `0x41485430` exactly.
  2. `selected_out.valid` stayed low throughout.
- **Coverage bins hit:** `csr_addr_read[0x0]`
- **Pass criteria:** Readback bit-exact `0x41485430`; `uvm_error_count == 0`.
- **Status:** planned

### B002_uid_write_ignored

- **ID:** B002_uid_write_ignored
- **Goal:** UID is hard-wired; writes are silently discarded.
- **Stimulus sequence:** Read 0x0, write 0xDEADBEEF to 0x0, read 0x0 again.
- **Expected result:** Both reads return `0x41485430`; no waitrequest.
- **Pass criteria:** Both reads bit-exact.
- **Status:** planned

### B003_meta_versioning

- **ID:** B003_meta_versioning
- **Goal:** META mux selects VERSION/DATE/GIT/INSTANCE_ID by writing select code 0..3 to word 0x1.
- **Stimulus sequence:**
  1. For sel ∈ {0,1,2,3}: write `sel` to 0x1, read 0x1.
- **Expected result:** Each readback matches the parameterised constant.
- **Pass criteria:** All four reads exact.
- **Status:** planned

---

## 2. Mode contract (B004-B009)

### B004_default_mode_real

- **Goal:** After reset, `STATUS.mode = REAL`, `mode_pending = REAL`, both FIFOs empty, `last_grant = 0`.
- **Stimulus sequence:** Reset, read 0x3.
- **Expected result:** STATUS reflects defaults.
- **Status:** planned

### B005_set_mode_emu

- **Goal:** Write `CONTROL.mode = EMU` (01); STATUS.mode_pending becomes EMU; with both FIFOs empty STATUS.mode commits to EMU within one clock.
- **Stimulus sequence:** Write 0x2 = 0x1, read 0x3.
- **Expected result:** STATUS.mode_pending = 1, STATUS.mode = 1.
- **Status:** planned

### B006_set_mode_mix_rr

- **Goal:** Write `CONTROL.mode = MIX_RR` (10); STATUS reflects MIX_RR.
- **Status:** planned

### B007_real_only_drain

- **Goal:** In REAL mode, real-input beats forward to egress; emulator-input beats accumulate in emu FIFO and never appear on egress.
- **Stimulus sequence:** Drive 1 hit on real_in, 1 hit on emu_in, both 4-beat packets.
- **Expected result:** Egress sees the real packet only; emu FIFO depth becomes 4 (or fewer if hit was completed in 1 beat); no egress emu beats.
- **Status:** planned

### B008_emu_only_drain

- **Goal:** Symmetric of B007 for EMU mode.
- **Status:** planned

### B009_mix_rr_merged_packet_alternation

- **Goal:** In MIX_RR with both FIFOs primed, egress beats alternate at the cycle level (RR `last_grant` toggle) **and** the merge-packet FSM collapses both source frames into one merged Avalon-ST packet whose SOP fires once at the start and EOP fires once at the end. Each beat carries its source's `channel` and `error` unchanged so per-beat demux still works.
- **Stimulus sequence:** Configure real source `channel = 4'h0`, emulator source `channel = 4'h8`. Pre-load real FIFO with one 4-beat frame and emu FIFO with one 2-beat frame, both with their own SOP/EOP set. Enter MIX_RR.
- **Expected result:** Egress emits exactly **one** merged packet of 6 beats. Beat 1 carries `egress_sop = 1` (whichever source the RR grants first); beats 2..5 carry `egress_sop = 0, egress_eop = 0` and the granted source's data/channel; beat 6 carries `egress_eop = 1`. `INGRESS_REAL_HITS = 4`, `INGRESS_EMU_HITS = 2`, `EGRESS_REAL_HITS = 4`, `EGRESS_EMU_HITS = 2`. `STATUS.merged_open` reads as 1 between beats 1 and 6 inclusive and 0 outside that window.
- **Pass criteria:** Exactly one egress SOP and one egress EOP across the merged window; per-channel beat reconstruction equals the input streams bit-exact; no source SOP/EOP propagates to egress except the first SOP and the last EOP.
- **Status:** planned

### B009b_mix_rr_single_beat_absorbed

- **Goal:** In MIX_RR, a single-beat (sop=eop=1) packet from source X arriving while source Y is mid-packet is absorbed as a middle beat in the merged packet. Egress sop/eop are both suppressed for X's beat; X's hit is still counted and channel-tagged correctly.
- **Stimulus sequence:** Real source emits a 6-beat frame at t=0. Emu source emits a 1-beat frame at t=2 (sop=1, eop=1).
- **Expected result:** Egress emits one merged packet of 7 beats. Emu's beat lands somewhere in beats 2..6, carries `channel = 4'h8`, `egress_sop = 0`, `egress_eop = 0`. INGRESS_EMU_HITS = 1, EGRESS_EMU_HITS = 1, partial_packet_drop_sticky = 0.
- **Status:** planned

### B009c_mix_rr_single_beat_both_idle

- **Goal:** In MIX_RR with both sources idle, a single-beat packet from source X opens and closes the merged packet in one egress cycle.
- **Stimulus sequence:** Both FIFOs empty. Real emits one beat with sop=1, eop=1.
- **Expected result:** Egress emits one beat with `egress_sop = 1, egress_eop = 1`. After that beat, merged_open = 0 again.
- **Status:** planned

---

## 3. Mode switch atomicity (B010-B012)

### B010_switch_at_idle

- **Goal:** Mode change while both FIFOs empty commits in one clock.
- **Status:** planned

### B011_switch_during_packet_defers

- **Goal:** A mode change requested while any source is mid-packet is deferred until **all in-flight packets are closed on egress**; pending bit stays set; `STATUS.mode` does not change yet.
- **Stimulus sequence:** REAL mode, drive a 6-beat real packet, on cycle 3 write CONTROL.mode = EMU.
- **Expected result:** Beats 1..6 emit on egress as the real packet; on cycle of beat 6 (eop), mode commits; STATUS.mode reads as EMU on the next cycle.
- **Status:** planned

### B012_switch_back_to_back

- **Goal:** Two pending mode writes within the same packet keep only the latest pending value at commit.
- **Stimulus sequence:** REAL, mid-packet write EMU, then write MIX_RR before EOP.
- **Expected result:** Mode commits to MIX_RR at EOP.
- **Status:** planned

### B012b_switch_mix_rr_to_real_drains_outstanding_emu

- **Goal:** MIX_RR → REAL switch defers until BOTH sources are at packet boundary, including any in-flight emu packet on egress.
- **Stimulus sequence:** MIX_RR mode with both sources active. While an emu-channel packet is mid-flight on egress (SOP issued, EOP not yet), write CONTROL.mode = REAL.
- **Expected result:** Mode commit waits for the emu packet's EOP on egress; until commit, the arbiter still grants emu beats to close that packet; after commit, only real-source beats appear.
- **Status:** planned

---

## 4. Per-source ingress FIFO (B013-B015)

### B013_real_fifo_fill_drain

- **Goal:** Real FIFO accepts 16 beats, then drains every beat at the granted pace; STATUS.real_full asserts at depth 16, deasserts after first drain.
- **Status:** planned

### B014_emu_fifo_fill_drain

- **Goal:** Symmetric of B013 for emu FIFO.
- **Status:** planned

### B015_idle_does_not_consume

- **Goal:** Beats with `valid=0` are ignored; FIFO depth unchanged; counters do not move.
- **Status:** planned

---

## 5. Counters (B016-B021)

### B016_ingress_real_hit_counter

- **Goal:** Each `endofpacket && valid` on real_in increments INGRESS_REAL_HITS by 1.
- **Stimulus sequence:** Drive 100 hits with mixed packet lengths.
- **Expected result:** INGRESS_REAL_HITS_L = 100, INGRESS_REAL_HITS_H = 0.
- **Status:** planned

### B017_ingress_emu_hit_counter

- **Goal:** Symmetric of B016 for emulator source.
- **Status:** planned

### B018_drop_real_counter

- **Goal:** Saturate real FIFO with 16 hits; emit beat 17; DROPS_REAL increments by 1; INGRESS_REAL_HITS unchanged for that beat.
- **Status:** planned

### B019_drop_emu_counter

- **Goal:** Symmetric of B018 for emu FIFO.
- **Status:** planned

### B020_egress_real_counter

- **Goal:** Each `endofpacket && valid` on egress with `last_grant=0` increments EGRESS_REAL_HITS by 1.
- **Status:** planned

### B021_egress_emu_counter

- **Goal:** Symmetric of B020 for emulator-sourced egress.
- **Status:** planned

---

## 6. Counter atomicity and clear (B022-B024)

### B022_low_high_pair_atomicity

- **Goal:** Reading `_L` latches the matching `_H`; subsequent counter increments do not affect the latched `_H` until next `_L` read.
- **Stimulus sequence:** Drive counter to a value where the upper 32 bits are non-zero (use plusarg seed); read `_L`, drive 10 more increments, read `_H`.
- **Expected result:** `_H` reflects the value at the previous `_L` read, not the post-increment value.
- **Status:** planned

### B023_w1p_clear_counters

- **Goal:** Writing CONTROL bit 2 clears all six 64-bit counters in one clock.
- **Stimulus sequence:** Drive counters to non-zero; write CONTROL = (mode | bit 2).
- **Expected result:** All six pairs read 0 after the write; mode unchanged.
- **Status:** planned

### B024_csr_back_to_back_writes

- **Goal:** CSR writes on adjacent clocks are accepted in order; no waitrequest.
- **Status:** planned

---

## 7. Plan drift notes

(none yet)
