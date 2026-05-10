# DV Edge — `arb_hit_type0`

**Companion docs:** [`README.md`](../README.md), [`DV_PLAN.md`](DV_PLAN.md), [`DV_HARNESS.md`](DV_HARNESS.md), [`DV_BASIC.md`](DV_BASIC.md), [`DV_PROF.md`](DV_PROF.md), [`DV_ERROR.md`](DV_ERROR.md), [`DV_CROSS.md`](DV_CROSS.md), [`BUG_HISTORY.md`](BUG_HISTORY.md)

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** `E001`-`E099`
**Total:** 18 cases listed below.

---

## 1. Boundary packet shapes (E001-E005)

### E001_single_beat_packet

- **Goal:** A 1-beat packet (`sop && eop && valid` on the same cycle) on real_in passes through unchanged; egress sees the same single-beat shape.
- **Stimulus sequence:** Single beat with sop=eop=1, data = 45'h1A2B3C4D5E6, error=0, channel=0.
- **Expected result:** Egress single beat with identical fields; INGRESS_REAL_HITS = 1.
- **Status:** planned

### E002_max_channel

- **Goal:** Channel field carries 4'b1111 unchanged across the FIFO and the arbiter.
- **Status:** planned

### E003_all_error_bits_set

- **Goal:** Error sideband 3'b111 (every error reason set) propagates correctly.
- **Status:** planned

### E004_eor_only_packet

- **Goal:** Single-beat packet with `endofrun=1` propagates EOR; subsequent grants on either source are blocked until reset.
- **Status:** planned

### E005_long_packet_at_fifo_depth

- **Goal:** A single packet of 16 beats fills the FIFO exactly; egress drains it at the granted pace; no drop.
- **Status:** planned

---

## 2. Mode switch on exact eop cycle (E006-E008)

### E006_switch_on_eop_clock_real_to_emu

- **Goal:** CONTROL.mode write lands on the same clock as the egress eop; mode commits this cycle (no extra delay).
- **Stimulus sequence:** Drive a 4-beat real packet; on the cycle of beat 4 (eop), AVMM write CONTROL.mode = EMU.
- **Expected result:** Beat 4 emits with `last_grant=0` (real); next granted packet sources from emu_in if any.
- **Status:** planned

### E007_switch_on_eop_real_to_mix_rr

- **Goal:** Symmetric of E006 with target MIX_RR.
- **Status:** planned

### E008_switch_just_after_eop

- **Goal:** CONTROL.mode write one clock after eop commits at the next clock with no defer; STATUS.mode_pending equals STATUS.mode after one clock.
- **Status:** planned

---

## 3. FIFO boundary (E009-E012)

### E009_fifo_full_to_empty

- **Goal:** Fill real FIFO to depth 16, drain to empty without external source activity, full / empty flags toggle correctly.
- **Status:** planned

### E010_simultaneous_full_both_sources

- **Goal:** Both FIFOs reach 16 beats simultaneously; no deadlock; arbiter still grants per packet boundary in MIX_RR.
- **Status:** planned

### E011_alternating_single_beat_packets_mix_rr

- **Goal:** In MIX_RR with single-beat packets (sop=eop=1) on each source, egress alternates strictly per cycle and each beat carries its native channel/sop/eop unchanged.
- **Status:** planned

### E012_one_source_silent_other_drains

- **Goal:** In MIX_RR with emu_in idle, real_in drains continuously without round-robin gaps. `last_grant` stays at 0 across the whole sequence; no spurious grants to the empty source.
- **Status:** planned

### E012b_overlapping_frames_merged_into_one_packet

- **Goal:** In MIX_RR with overlapping source frames (real 8 beats, emu 6 beats, emu's SOP 2 cycles after real's SOP), the merge-packet FSM collapses both into **one** merged Avalon-ST packet of 14 beats. Egress emits exactly one SOP (on the first granted beat) and one EOP (on the last granted beat). Per-beat channel disambiguates the source within the merged packet.
- **Stimulus sequence:** Real channel = 4'h0, emu channel = 4'h8. Drive real 8-beat frame starting at t = 0, emu 6-beat frame starting at t = 2.
- **Expected result:** Egress single merged packet of 14 beats. The four interior source-EOP beats (one each from real and emu) carry `egress_eop = 0` because `was_open_other = 1` at the time of the suppressed eop; the FSM emits the merged EOP only on the last granted beat where `merged_open` transitions 1 → 0. Per-channel scoreboard reconstructs the original 8-beat real frame and 6-beat emu frame bit-exact from per-beat channel.
- **Status:** planned

### E012c_eor_after_other_active

- **Goal:** Real emits EOR while emu is still mid-packet; egress EOR is held; emu later emits EOR; egress EOR fires on emu's closing beat.
- **Stimulus sequence:** Real frame ends with EOR=1 on its EOP at t = 5. Emu frame from t = 3 to t = 9 (last beat carries EOR=1).
- **Expected result:** Real's EOP suppressed (was_open_other = emu_open = 1), `eor_seen_real` sticky-set. Emu's final beat closes merged: egress_eop = 1, egress_eor = 1. `merged_locked = 1` after this beat; arbiter blocks further grants.
- **Status:** planned

### E012d_eor_simultaneous_at_egress

- **Goal:** Both sources have EOR-bearing beats granted in adjacent egress cycles. The first fires row 9 (suppressed eop, sticky eor); the second fires row 10 (egress eop, egress eor). Single egress EOR.
- **Status:** planned

### E012e_watchdog_synthesizes_eor_one_sided

- **Goal:** Real emits EOR; emu never emits EOR. After `WATCHDOG_CYCLES` of emu silence with `eor_seen_real = 1`, FAW synthesizes a 1-cycle egress beat with `eop = 1`, `eor = 1`, channel = `last_channel_emu`, error[2] = 1 (overflow flag indicates synthesis), data = 0. After this beat, `merged_locked = 1`, `STATUS.watchdog_synthesized_emu = 1`, no further egress beats until reset. Egress hit counters do NOT increment for the synthesized beat (it is a control beat, not a real hit).
- **Stimulus sequence:** Drive a real packet whose final beat carries EOR. Hold `asi_emu_valid = 0` for at least `WATCHDOG_CYCLES + 16` clocks after real's EOR.
- **Expected result:** Synthesized closing beat arrives at `WATCHDOG_CYCLES + (FSM latency)` after real's EOR. `EGRESS_EMU_HITS` unchanged across the synthesis event.
- **Status:** planned

### E012f_watchdog_disabled_leaves_packet_open

- **Goal:** With `WATCHDOG_CYCLES = 0` (FAW disabled), a one-sided run-end leaves the merged packet open until reset; STATUS.merged_locked = 0; egress EOR never fires.
- **Stimulus sequence:** Same as E012e but write `WATCHDOG_CYCLES = 0` first.
- **Expected result:** No synthesized beat. Documented and asserted limitation.
- **Status:** planned (negative test, asserts the disable-watchdog behaviour)

---

## 4. Counter saturation and W1P (E013-E015)

### E013_low_word_saturation

- **Goal:** Counter low half drives toward `0xFFFF_FFFF` and rolls into the high half cleanly.
- **Stimulus sequence:** Use plusarg `+ARB_COUNTER_PRELOAD=0xFFFF_FFF8` to seed the model close to the boundary, then drive 16 hits.
- **Expected result:** `_L` rolls to small value, `_H` = 1.
- **Status:** planned

### E014_full_64_bit_saturation_clamp

- **Goal:** When the 64-bit counter reaches `0xFFFF_FFFF_FFFF_FFFF`, further increments hold (saturating).
- **Stimulus sequence:** Plusarg seed near `2^64-1`, drive a few more hits.
- **Expected result:** Counter holds at max.
- **Status:** planned

### E015_w1p_clear_during_traffic

- **Goal:** W1P clear under live traffic clears all six counters atomically; the very next granted hit is counted normally.
- **Status:** planned

---

## 5. CSR boundary (E016-E018)

### E016_csr_address_aliasing

- **Goal:** Read every defined CSR word; verify each address returns its documented field. Read addresses with bit 4..7 set (out of decoded range) — DUT decode width is 4 bits, so this is internal harness consistency only.
- **Status:** planned

### E017_read_during_writeable_field_change

- **Goal:** Issue a CSR read of CONTROL one cycle after a CONTROL write; readback reflects the new written value.
- **Status:** planned

### E018_status_live_packet_flags

- **Goal:** STATUS.in_packet_active asserts on every SOP-without-EOP cycle and deasserts at EOP. Multiple polls during a long packet read consistent.
- **Status:** planned

---

## 6. Plan drift notes

(none yet)
