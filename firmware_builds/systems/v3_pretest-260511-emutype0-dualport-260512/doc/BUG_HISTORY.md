# BUG_HISTORY.md - FEB v3 emulator-type0 phase 4.5 sweep bug ledger

This ledger records bugs found by the phase 4.5 sweep harness on the
`v3_pretest-260511-emutype0-dualport-260512` build. The harness is
`scripts/cotest/phase4_5_sweep.py` and the per-row evidence lives under
`sweep_evidence/<row_id>/`.

Class legend:
- `R` = RTL / DUT bug in an IP shipped on this build
- `H` = sweep-harness / testcase / reporting bug
- `I` = integration / Qsys / wiring bug at the FEB datapath level

Severity legend:
- `soft error` = the bad data is observable but the datapath does not remain stuck
- `hard stuck error` = the bug can poison later datapath behavior until reset or restart
- `non-datapath-refactor` = packaging, observability, reporting, harness, or metadata work with no direct packet-contract effect

## Index

| bug_id | class | severity | encounterability | status | first seen | commit | summary |
|---|---|---|---|---|---|---|---|
| [BUG-005-H](#bug-005-h-phase4_5_sweep-read-the-live-csr-13-counter-while-interval-pulses-reset-it-mid-run) | H | non-datapath-refactor | `common (default sweep configuration)` | fixed | FEB v3 emulator-type0 phase 4.5 sweep, 2026-05-12 | this commit | `scripts/cotest/phase4_5_sweep.py` programmed `INTERVAL_CFG = run_window` so the LIVE CSR 13 counter reset every 1 s during the 4 s window, and the sweep read the wrong offset (`0x10` = SCRATCH) for the STABLE CSR 17 latch. |
| [BUG-006-I](#bug-006-i-histogram-input-fifos-are-empty-on-every-row-of-the-2026-05-12-sweep) | I | hard stuck error | `common (every sweep row on the single-port build)` | fixed-with-residuals | FEB v3 emulator-type0 phase 4.5 sweep, 2026-05-12 | this commit | The single-port topology fed only `mts_preprocessor_0` into `histogram_statistics_0`; lanes 4..7 were routed only to hit-stack bank 1. The dual-port build wires both MTS banks into `histogram_statistics_0` and removes the ready-mismatch hazard on the arb-to-MTS path. |

## 2026-05-12

### BUG-005-H: phase4_5_sweep read the LIVE CSR 13 counter while interval pulses reset it mid-run

- First seen:
  - FEB v3 emulator-type0 phase 4.5 sweep on the `v3_pretest-260511-emulator-type0-260512` build.
  - Prior 32-row sweep reported 8 PASS / 24 FAIL with the dominant failure mode `TOTAL_HITS_ZERO` even though several rows had populated per-channel `hist_bin` counts.
- Symptom:
  - Post-end-run read of CSR 13 (`TOTAL_HITS`) returned 0 or a partial bucket on most rows, while the per-channel `hist_bin` SRAM held multi-million hits on lucky rows.
  - The verdict logic depended on CSR 13 alone and miscounted those rows as failures even when traffic clearly reached the histogram on the bench.
- Root cause:
  - `histogram_statistics_v2_hw.tcl` documents the contract verbatim: "TOTAL_HITS and DROPPED_HITS are LIVE CURRENT-INTERVAL counters. LAST_INTERVAL_TOTAL_HITS and LAST_INTERVAL_DROPPED_HITS latch the completed interval just before the live counters reset, allowing stable one-second rate polling."
  - `histogram_statistics_v2.vhd` resets `csr_total_hits` at every `interval_pulse`; the pulse fires every `INTERVAL_CFG` clock cycles. On this build `interval_reset` is wired only to the POR bridge, so the periodic timer is the sole source of pulses.
  - The previous sweep used `INTERVAL_CFG = run_window * 125 MHz = 500 M cycles` for a 4 s run, firing 4 pulses during the run window.
  - The sweep also defined `HIST_LAST_INT_HITS_W = 0x10` (the SCRATCH register) instead of `0x11` (`LAST_INTERVAL_TOTAL_HITS`).
- Fix:
  - `scripts/cotest/phase4_5_sweep.py` programs `INTERVAL_CFG = 0xFFFFFFFF` (`INTERVAL_CFG_NEVER_FIRE`, ~34.36 s @ 125 MHz) so no `interval_pulse` fires during any run in the matrix.
  - New constants `HIST_LAST_INTERVAL_TOTAL_HITS_W = 0x11` and `HIST_LAST_INTERVAL_DROPPED_HITS_W = 0x12` map to the STABLE CSR offsets per the VHDL `when 17 / when 18` readout cases.
  - `snap_hist()` reads 19 words (0x00..0x12) and now exposes `LAST_INTERVAL_TOTAL_HITS`, `LAST_INTERVAL_DROPPED_HITS`, plus a back-compat alias for the older `LAST_INT_HITS` field.
  - `compute_verdict()` captures `total_hits_csr13` (LIVE), `last_interval_total_hits_csr17` (STABLE), and `hist_bin_sum` on every row; the PASS predicate uses `total_hits_csr13`; `hist_bin_sum_matches_csr13` (within an 8-hit pipeline tolerance) is a warning-only flag.
- Evidence (2026-05-12 sweep, build `v3_pretest-260511-emulator-type0-260512`):
  - Single-row diagnostic on `p45_000_all_lanes_0xFFFFFFFF_default_dir` confirmed `INTERVAL_CFG` readback = `0xFFFFFFFF`, stable cross-validation (`csr13 = csr17 = hist_bin_sum = 0`, `hist_bin_sum_matches_csr13 = true`).
  - Full 32-row sweep: 2 PASS (both sanity-negative `lane_mask=0x00` rows), 30 FAIL. On every FAIL row the three counters agree; the live-vs-stable race is resolved.
  - Sweep evidence at `sweep_evidence/<row_id>/{counters.json,verdict.json,hist_bin.csv,tool_calls.log}`.
  - Refreshed report at `doc/PHASE4_5_SWEEP_REPORT.html` (Diagnosis section + Counter Cross-Validation sub-section).
- Residual hazard:
  - The refreshed sweep exposes the upstream histogram-feeding bug tracked separately as BUG-006-I.

### BUG-006-I: histogram input FIFOs are empty on every row of the 2026-05-12 sweep

- First seen:
  - FEB v3 emulator-type0 phase 4.5 sweep on the `v3_pretest-260511-emulator-type0-260512` build, 2026-05-12.
- Symptom:
  - On all 32 sweep rows, `histogram_statistics_v2` `PORT_STATUS = 0x000000FF` post-end-run (every per-port `hit_fifo` empty, `fifo_level_max = 0`).
  - `csr_total_hits = csr_last_interval_total_hits = sum(hist_bin[0..255]) = 0` on every non-sanity-negative row.
  - `arb_hit_type0_supercore` reports `ingress_emu_hits` and `egress_emu_hits` growing from ~274 M on row 0 to ~1.27 B on row 31, so traffic flows through the arb stage. Nothing reaches the histogram.
- Root cause:
  - `histogram_statistics_0` was configured with `N_PORTS = 1`, so only `hist_fill_in` port 0 was live.
  - `mts_preprocessor_0.hit_type1_out` fed `histogram_ingress_bridge_0.pre_in`, but `mts_preprocessor_1.hit_type1_out` fed only `hit_stack_subsystem_1.hit_type_1`.
  - Lanes 4..7 therefore reached `mts_preprocessor_1` and the bank-1 hit stack, but never reached the histogram pre-rbCAM measurement input.
  - The `arb_hit_type0_supercore -> mux_mutrig2processor -> mts_preprocessor.hit_type0_in` path also had a ready-contract mismatch risk. The MTS input declared `ready`; the arb/mux path is valid-only. This build removes that sink ready and uses explicit readyless 4:1 hit_type0 muxes so Qsys does not insert a dropping timing adapter on the hit path.
- Fix:
  - New build directory: `firmware_builds/systems/v3_pretest-260511-emutype0-dualport-260512/`.
  - `histogram_statistics_0.N_PORTS = 2`.
  - `histogram_ingress_bridge_0` feeds histogram port 0 from `mts_preprocessor_0` for lanes 0..3.
  - `histogram_ingress_bridge_1` feeds histogram `fill_in_1` from `mts_preprocessor_1` for lanes 4..7 and forwards to `hit_stack_subsystem_1.hit_type_1`.
  - Top-level Qsys version is bumped to `3.0.5.0512`.
  - `mutrig_timestamp_processor/mts_processor_hw.tcl` version is bumped to `26.3.0.512` and the `hit_type0_in` ready port is removed.
- Evidence:
  - Focused dual-port simulation:
    - `tb_int/REPORT/dualport_smoke.md`: port0 handshakes 500, port1 handshakes 500, `hist_bin` writes 844, total 1000.
    - `tb_int/REPORT/100k_single_channel_soak.md`: port0 handshakes 50000, port1 handshakes 50000, internal `hist_bin` writes 100000, observed 100000.
  - Board sweep on the dual-port image:
    - 32 rows executed under `swb_ring_lock`.
    - 25 PASS / 7 FAIL by the existing CSR-based verdict.
    - Non-sanity rows now have live `TOTAL_HITS` on 28 rows; lane 4..7 rows prove the second MTS bank contributes to CSR 13.
  - Directed board long-soak:
    - Evidence: `sweep_evidence/_longsoak/longsoak_20260512_153309/`.
    - PASS: 10 interval snapshots, 97652 observed hits vs 100000 target with the documented 4000-hit rate-quantization tolerance.
    - Live 256-bin snapshots show the channel-mask-1 stimulus in MTS bank bins `[0..3]` and `[32..35]`.
- Residuals:
  - The existing full sweep still reads `hist_bin` after END_RUN with `INTERVAL_CFG_NEVER_FIRE`; this image clears the frozen bank at END_RUN, so the per-row `hist_bin_sum` remains zero in the 32-row table.
  - The directed long-soak works around that by taking 256 single-word bin snapshots while RUNNING. Burst reads remain disabled because they corrupt the SC bridge on this bench.
