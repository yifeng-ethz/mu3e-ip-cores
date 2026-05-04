# DV Prof — `arb_hit_type0`

**Companion docs:** [`README.md`](../README.md), [`DV_PLAN.md`](DV_PLAN.md), [`DV_HARNESS.md`](DV_HARNESS.md), [`DV_BASIC.md`](DV_BASIC.md), [`DV_EDGE.md`](DV_EDGE.md), [`DV_ERROR.md`](DV_ERROR.md), [`DV_CROSS.md`](DV_CROSS.md), [`BUG_HISTORY.md`](BUG_HISTORY.md)

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** `P001`-`P099`
**Total:** 8 cases listed below.

---

## 1. Sustained throughput (P001-P004)

### P001_real_only_peak

- **Goal:** Continuous valid on real_in (no idle gaps) for 100k clocks; emu_in idle. In REAL mode the IP must drain without back-pressure-induced drops as long as the consumer accepts at the same rate. Drops must remain at zero.
- **Stimulus sequence:** Real source emits 4-beat packets back-to-back for 100k clocks.
- **Expected result:** INGRESS_REAL_HITS = EGRESS_REAL_HITS; DROPS_REAL = 0; DROPS_EMU = 0.
- **Status:** planned

### P002_emu_only_peak

- **Goal:** Symmetric of P001 for EMU mode.
- **Status:** planned

### P003_mix_rr_peak

- **Goal:** Sustained traffic on both sources at 1 hit / 8 cycles each (combined ≈ 1 hit / 4 cycles aggregate). Egress alternates per packet; total egress hits = sum of ingress hits; drops zero.
- **Status:** planned

### P004_emulator_raw_3p5_cycles_per_hit

- **Goal:** Emulate the `1 hit / 3.5 cycles` raw-load reference from `emulator_mutrig/README.md:89` on emu_in (single-beat short hits, alternating 3-cycle / 4-cycle gap). In EMU mode this is the saturation case for the emulator FIFO. Drops equal expected drop count from the model (FIFO-bounded backpressure surrogate).
- **Status:** planned

---

## 2. Soak (P005-P006)

### P005_basic_soak_1m_cycles

- **Goal:** 1M-cycle directed soak with mixed traffic on both sources (Poisson at 1 hit / 8 cycles each), MIX_RR mode. Counters monotonically advance; sticky flags do not light spuriously.
- **Status:** planned

### P006_long_soak_with_eor

- **Goal:** 1M-cycle soak followed by a final EOR on either source; egress emits the EOR; further grants are blocked until reset.
- **Status:** planned

---

## 3. Counter pair atomicity under load (P007)

### P007_pair_read_under_traffic

- **Goal:** Read every counter pair (`_L` then `_H`) at random offsets while traffic continues at peak rate. Latched-on-read semantics keep each pair atomic; the model predicts the readback value bit-exact.
- **Status:** planned

---

## 4. Mode switch under load (P008)

### P008_mode_switch_under_peak

- **Goal:** During P003 peak traffic, write CONTROL.mode every 1k clocks alternating REAL ↔ EMU ↔ MIX_RR. Each switch defers to the next eop on egress; counters remain consistent with the model.
- **Status:** planned

---

## 5. Plan drift notes

(none yet)
