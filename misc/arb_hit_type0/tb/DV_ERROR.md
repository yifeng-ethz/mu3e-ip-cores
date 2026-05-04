# DV Error — `arb_hit_type0`

**Companion docs:** [`README.md`](../README.md), [`DV_PLAN.md`](DV_PLAN.md), [`DV_HARNESS.md`](DV_HARNESS.md), [`DV_BASIC.md`](DV_BASIC.md), [`DV_EDGE.md`](DV_EDGE.md), [`DV_PROF.md`](DV_PROF.md), [`DV_CROSS.md`](DV_CROSS.md), [`BUG_HISTORY.md`](BUG_HISTORY.md)

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** `R001`-`R099`
**Total:** 12 cases listed below.

---

## 1. Reset (R001-R003)

### R001_async_reset_clears_state

- **Goal:** Asserting `rst` mid-traffic clears both FIFOs, all six counters, sticky flags, and reverts mode to default. After deassert, identity reads succeed.
- **Status:** planned

### R002_reset_during_packet

- **Goal:** Reset asserted mid-packet; egress immediately drops valid; STATUS.partial_packet_drop_sticky after reset deassert is **not** set (reset is not a packet-drop event).
- **Status:** planned

### R003_back_to_back_resets

- **Goal:** Multiple short reset pulses produce identical post-deassert state.
- **Status:** planned

---

## 2. Illegal CSR (R004-R006)

### R004_illegal_mode_encoding

- **Goal:** Writing CONTROL.mode = 2'b11 leaves effective mode at REAL and sets STATUS.mode_reserved_seen sticky.
- **Stimulus sequence:** Write CONTROL = 0x3.
- **Expected result:** STATUS.mode = 0; STATUS.mode_reserved_seen = 1.
- **Status:** planned

### R005_clear_sticky_w1p

- **Goal:** Bit 3 of CONTROL clears all sticky flags atomically; bit is W1P (no need to clear afterwards).
- **Status:** planned

### R006_csr_undefined_address_read

- **Goal:** Read of an undefined word in `[0x0..0xF]` (per the planned map all 16 are defined; this case becomes a no-op in 26.2.0). For 26.3.x extension, the contract is "undefined → 0".
- **Status:** planned (no-op for 26.2.0; reserved id)

---

## 3. Stream protocol violations (R007-R010)

### R007_sop_without_eop_drop

- **Goal:** Source emits SOP but the FIFO fills before EOP arrives; the partial packet is dropped; STATUS.partial_packet_drop_sticky asserts; INGRESS_*_HITS unchanged for this hit.
- **Stimulus sequence:** Pre-fill real FIFO to 15 entries; emit a 5-beat packet on real_in.
- **Expected result:** Beat 1 (sop) accepted, beats 2..5 dropped (FIFO full); DROPS_REAL = 4; INGRESS_REAL_HITS unchanged.
- **Status:** planned

### R008_eop_without_sop

- **Goal:** Source emits a beat with `eop=1, sop=0` while no packet is open. Defensive contract: this beat is admitted if FIFO has space (we trust the upstream contract); the model records it; STATUS.partial_packet_drop_sticky unaffected.
- **Status:** planned

### R009_eor_without_sop

- **Goal:** Single-beat with `eor=1, eop=0` is illegal; treat as `eor && eop` (apply EOR semantics). Document the chosen contract here and validate against the RTL.
- **Status:** planned

### R010_two_simultaneous_eors

- **Goal:** Both sources assert EOR in the same cycle; arbiter picks last_grant peer first, emits the EOR; second EOR is also emitted on the next granted boundary; further grants blocked.
- **Status:** planned

---

## 4. Both FIFOs full simultaneously (R011-R012)

### R011_both_full_no_deadlock

- **Goal:** Both FIFOs reach depth 16. Egress in REAL/EMU/MIX_RR mode drains correctly without hang.
- **Status:** planned

### R012_both_full_under_mode_switch

- **Goal:** Both FIFOs full; mode switches REAL → EMU → MIX_RR. Each switch defers per packet boundary; no SOP/EOP imbalance on egress.
- **Status:** planned

---

## 5. Plan drift notes

(none yet)
