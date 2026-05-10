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

### R007_sop_without_eop_records_syndrome

- **Goal:** Source emits SOP, FIFO fills, EOP-bearing beat is dropped → upstream contract violated. The arbiter does NOT recover: `STATUS.drop_mid_packet_sticky = 1`, `ERROR_COUNT_DROP_MID_PACKET = 1`, `SYNDROME_DROP_MID_PACKET` snapshots source / FIFO depth / beat fields / run_state at the dropped beat. The merged packet is left in an undefined state; recovery is a clean reset (RUN_PREP / RESET / hard reset).
- **Stimulus sequence:** Pre-fill real FIFO to 15 entries; emit a 5-beat packet on real_in. The 5th beat (eop) is dropped because the FIFO is full at that moment.
- **Expected result:** Sticky asserted, error counter at 1, syndrome captures source=real, beat.eop=1, FIFO depth=16, source's _open=1.
- **Status:** planned

### R008_protocol_violation_two_sops_records_syndrome

- **Goal:** Source emits two SOPs without intervening EOP → upstream contract violated. `STATUS.protocol_violation_sticky = 1`, `ERROR_COUNT_PROTOCOL = 1`, `SYNDROME_PROTOCOL` snapshots source / prior `_open` flags / beat fields / run_state at the offending second SOP. The arbiter does NOT repair the merged packet; recovery is a clean reset.
- **Status:** planned

### R009_eor_without_sop

- **Goal:** Single-beat with `eor=1, eop=0` is treated as `eor && eop` (apply EOR semantics on the implicit EOP). Document the chosen contract and validate against the RTL.
- **Status:** planned

### R010_two_simultaneous_eors

- **Goal:** Both sources assert EOR in adjacent egress cycles; row 9 fires first (suppressed eop, sticky eor), row 10 fires second (egress eop, egress eor). Further grants blocked after the second.
- **Status:** planned

### R011_error_counter_saturation

- **Goal:** Drive `ERROR_COUNT_PROTOCOL` and `ERROR_COUNT_DROP_MID_PACKET` to `0xFFFF_FFFF` via plusarg seed; further events hold (saturating). The first-event syndrome is preserved; W1P clear via `CONTROL.bit[5]` clears both error counters and both syndromes atomically.
- **Status:** planned

### R012_run_control_reset_clears_error_state

- **Goal:** With sticky flags asserted and error counters non-zero, a RESET state on run_ctrl clears: both sticky flags, both error counters, both syndromes, all six 64-bit hit counters, the watchdog status, mode_pending → mode_default, both _open flags, eor_seen flags, merged_locked.
- **Stimulus sequence:** Drive R007 first, then R008 in the same run, then issue run_ctrl RESET.
- **Expected result:** All cleared after RESET.
- **Status:** planned

### R013_watchdog_synthesis_real

- **Goal:** Real source goes silent mid-packet for `WATCHDOG_CYCLES + 1` while emu has EORed. FAW synthesizes a closing beat with `last_channel_real`, `eor=1`. `STATUS.watchdog_synthesized_real = 1`. Egress hit counters do NOT increment for the synthesized beat.
- **Status:** planned

### R014_watchdog_disabled_then_stuck

- **Goal:** With `WATCHDOG_CYCLES = 0`, a one-sided EOR leaves merged_open stuck; egress EOR never fires; downstream sees a hung packet. Documented limitation; recovery via run_ctrl RESET.
- **Status:** planned

### R015_run_control_run_prep_during_packet

- **Goal:** Mid-packet RUN_PREP synchronously flushes the in-flight packet without leaking partial beats to egress. After RUN_PREP, the next granted source's SOP is the start of a new merged packet.
- **Stimulus sequence:** Drive a 6-beat real packet; issue RUN_PREP at beat 3.
- **Expected result:** Beats 1..3 may have already reached egress; cycle 4 onwards egress is quiet (`aso_valid = 0`); ingress FIFOs empty; `STATUS.real_open = 0` after RUN_PREP. Counter pairs preserved (RUN_PREP does not clear hit counters).
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
