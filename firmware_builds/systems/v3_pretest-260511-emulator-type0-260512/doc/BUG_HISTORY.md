# BUG_HISTORY.md - FEB v3 emulator-type0 phase 4.5 sweep bug ledger

This ledger records bugs found by the phase 4.5 sweep harness on the
`v3_pretest-260511-emulator-type0-260512` build. The harness is
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
| [BUG-006-I](#bug-006-i-histogram-input-fifos-are-empty-on-every-row-of-the-2026-05-12-sweep) | I | hard stuck error | `common (every sweep row on this session)` | open | FEB v3 emulator-type0 phase 4.5 sweep, 2026-05-12 | next commit | `histogram_statistics_v2` input hit_fifos read `PORT_STATUS = 0x000000FF` on every row even though `arb_hit_type0_supercore` reports `ingress_emu_hits` of 159M-1.27B. The path between arb egress and histogram ingress delivers nothing in this board session. |

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
- Root cause (suspected, not confirmed):
  - The ingress mux at `HIST_INGRESS_BASE_WORD = 0x0AB00` acknowledges the post-rbCAM selection (`status & 0x7 == 0x3`) but no hits reach the histogram's `asi_data*` ports.
  - The previous run had occasional PASSes with `BANK_STATUS = 1` (after at least one bank swap); the new run with `INTERVAL_CFG = NEVER_FIRE` keeps `BANK_STATUS = 0` throughout. Worth checking whether the very first `interval_pulse` was acting as a side-effectful arm that the never-fire value no longer provides.
- Status:
  - open. Hand off to the next iterative-debug pass; STP coverage of the histogram `asi_data*` ports and the arb-to-histogram routing would localise the gap.
- Evidence:
  - 32-row sweep verdict.json + counters.json under `sweep_evidence/`.
  - Findings section of `doc/PHASE4_5_SWEEP_REPORT.html` documents the BUG-006-I hand-off.
