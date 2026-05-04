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

- **Goal:** In MIX_RR, alternating single-beat packets on real and emu produce strict alternation on egress.
- **Status:** planned

### E012_one_source_silent_other_drains

- **Goal:** In MIX_RR with emu_in idle, real_in drains continuously without round-robin gaps.
- **Status:** planned

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
