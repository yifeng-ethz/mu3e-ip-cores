# DV Plan: `arb_hit_type0`

**DUT:** `arb_hit_type0`
**IP source:** `rtl/arb_hit_type0.sv`
**Author:** Mu3e IP team
**Date:** 2026-05-04
**Status:** Draft. Awaiting design approval before harness construction starts.
**Companion docs:** [`README.md`](../README.md), [`doc/RTL_PLAN.md`](../doc/RTL_PLAN.md), [`DV_HARNESS.md`](DV_HARNESS.md), [`DV_BASIC.md`](DV_BASIC.md), [`DV_EDGE.md`](DV_EDGE.md), [`DV_PROF.md`](DV_PROF.md), [`DV_ERROR.md`](DV_ERROR.md), [`DV_CROSS.md`](DV_CROSS.md), [`DV_COV.md`](DV_COV.md), [`BUG_HISTORY.md`](BUG_HISTORY.md)

---

## 1. Purpose & Scope

`arb_hit_type0` is the per-lane arbiter on the post-deassembly hit_type0 boundary. It selects between the real MuTRiG hit_type0 stream and the emulator hit_type0 stream, with 16-deep ingress FIFOs per source and a packet-boundary round-robin arbiter for the `MIX_RR` mode. This plan covers standalone DV of the IP up to the point where it is wired into a generated FEB system through Qsys-Tcl.

### In-scope

- Reset and identity: UID/META/STATUS reset values, version readback semantics
- Per-source ingress FIFO behaviour: depth, fill/drain, full/empty flags, drop accounting
- Packet integrity: SOP/EOP/EOR atomicity through every mode and every transition
- Mode contract: `REAL`, `EMU`, `MIX_RR` mode-effective set, mode-pending defer through packet boundary
- Arbiter contract: round-robin alternation, single-source steady drain when peer is empty, no-tear guarantee on switch
- Counters: ingress-real, ingress-emu, drops-real, drops-emu, egress-real, egress-emu (64-bit, saturating, latched-on-read low-then-high pair atomicity)
- Sticky flags: `partial_packet_drop_sticky`, `mode_reserved_seen`, W1P clears
- CSR access path, including read-after-write coherency on `CONTROL`

### Out-of-scope

- Multi-lane integration (handled by the system-level Qsys-Tcl regen and its own `tb_int/`)
- Real LVDS / decoder behaviour (driven from synthetic upstream Avalon-ST stimulus)
- Quartus place-and-route timing closure (covered by `syn/SYN_REPORT.md`)

---

## 2. DUT Interfaces

| Interface | Type | Width | Clock | Direction | Notes |
|---|---|---|---|---|---|
| `clk` | clock | 1b | self | in | single clock domain, target 125 MHz, signoff at 137.5 MHz |
| `rst` | reset | 1b | clk | in | sync deassert |
| `csr` | AVMM slave | addr 5b (word), data 32b | clk | in/out | read latency 1, no waitrequest |
| `run_ctrl` | AVST sink | data 9b | clk | in | sync-reset on RUN_PREP / RESET states |
| `real_in` | AVST sink | data 45b, error 3b, channel 4b, sop/eop/eor | clk | in | implicit always-ready (no `ready` line); FIFO accepts on `valid` or drops |
| `emu_in` | AVST sink | data 45b, error 3b, channel 4b, sop/eop/eor | clk | in | same shape as `real_in` |
| `selected_out` | AVST source | data 45b, error 3b, channel 4b, sop/eop/eor | clk | out | downstream is `backpressure_fifo` (`readyLatency=0`); the IP holds beats internally if the consumer cannot accept |

The CSR map is owned by the IP packaging (`arb_hit_type0_hw.tcl` plus the ip-packaging skill's CSR-header lint). DV bucket files **must not** duplicate the CSR map; they reference it.

---

## 3. Verification Targets

1. Identity (`UID`, `META`) read-only enforcement; reset values bit-exact.
2. Mode selection: every `(initial_mode, target_mode)` pair in `{REAL, EMU, MIX_RR}` × `{REAL, EMU, MIX_RR}` produces the documented effective steady-state behaviour and the documented switch behaviour.
3. Mode switch atomicity: a CSR-driven mode change while egress is mid-packet is deferred until `endofpacket && valid`; no SOP/EOP imbalance is observable on `selected_out`.
4. Per-source ingress FIFO: 16-deep, every beat with `valid=1` is accepted unless full; full → beat dropped, drop counter +1; never re-ordered.
5. Round-robin arbiter (in `MIX_RR`): alternates per packet; if one FIFO is empty the other drains continuously; switching never tears packets; `last_grant` tracks the most recent winner.
6. Counters: ingress-real, ingress-emu, egress-real, egress-emu increment on hit completion (`endofpacket && valid`); drops-real, drops-emu increment per dropped beat; saturating at `0xFFFF_FFFF_FFFF_FFFF`; W1P clear sets all six to zero atomically; `_L`/`_H` pair atomicity preserved when the high half is read after the low half.
7. EOR (`endofrun`) propagation: once granted, EOR locks out further grants until reset; both mode and arbiter respect this.
8. Sticky flags: `partial_packet_drop_sticky` set when a SOP-bearing beat is accepted but the matching EOP is later dropped; `mode_reserved_seen` set when CONTROL.mode is written as `2'b11`; W1P bit 3 clears both.
9. Reset: all visible state returns to defaults inside one clock after reset deassert.

Functional coverage is split between code coverage (target ≥ 95% line, ≥ 90% branch, ≥ 90% toggle) and bucket-table coverage in `DV_COV.md`.

---

## 4. Bucket Layout

| Bucket | File | ID range | Goal |
|---|---|---|---|
| BASIC | `DV_BASIC.md` | `B001..B0xx` | Smoke + happy-path forward direction for every documented feature |
| EDGE | `DV_EDGE.md` | `E001..E0xx` | Boundary conditions: empty/full FIFO, single-beat packets, SOP-only/EOP-only patterns, mode switch on the exact eop cycle, max channel/error sideband bits |
| PROF | `DV_PROF.md` | `P001..P0xx` | Sustained throughput, sustained-soak counters, mixed-load cyclical patterns, raw 1 hit / 3.5 cycles emulator-equivalent peak |
| ERROR | `DV_ERROR.md` | `R001..R0xx` | Reset patterns, illegal mode encoding, SOP without EOP, beat dropped mid-packet, both FIFOs full, CSR illegal-address access |
| CROSS | `DV_CROSS.md` | `X001..X0xx` | `bucket_frame` + `all_buckets_frame` continuous-frame sign-off |

Per the `dv-workflow` skill, every bucket file is enforced by `dv_bucket_format_check.py` and must not duplicate the CSR map.

---

## 5. Bring-up Order

1. BASIC `B001`-`B003` (identity).
2. BASIC `B004`-`B0xx` (mode contract, ingress, egress, counter happy paths).
3. EDGE bucket (FIFO boundaries, mode switch on eop cycle).
4. ERROR bucket (resets, illegal CSR, illegal mode encoding, drops).
5. PROF bucket (soak, throughput, peak).
6. CROSS bucket (`bucket_frame` and `all_buckets_frame` continuous-frame baselines).

System-level integration into the focus build `top_nostp_emulator_type0` is conditional on BASIC + EDGE + ERROR all green and PROF basic-soak green; CROSS must be green before integration sign-off.

---

## 6. Plan Drift

Any deviation from this plan must be recorded under `## Plan drift notes` in the affected bucket file, with date and rationale. Plan revisions update this file and bump the date stamp.
