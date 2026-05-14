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
| [BUG-007-I](#bug-007-i-feb-top-qsys-carried-stale-eight-emulator-csr-map) | I | non-datapath-refactor | `common (every top-level Qsys regenerate)` | fixed | FEB top Qsys regenerate, 2026-05-14 | this working tree | `syn/feb_system_v3.qsys` still bound `data_path_subsystem` to `3.0.4.512` and exported eight `emulator_mutrig_N` CSR apertures, causing Platform Designer address-map overlaps when the active datapath component only has `emulator_mutrig_qsys_inst`. |
| [BUG-008-I](#bug-008-i-feb-top-qsys-exported-a-stale-pulse_out_conduit-interface) | I | non-datapath-refactor | `common (every top-level Qsys regenerate after the runctrl refactor)` | fixed-debug-loadable | FEB top Qsys regenerate, 2026-05-14 | this checkpoint | `syn/feb_system_v3.qsys` still exported `pulse_out_conduit` even though the regenerated datapath/runctrl interface no longer drives that conduit, leaving stale wrapper ports and blocking a clean FEB top compile. |
| [BUG-009-H](#bug-009-h-feb-stp-generator-used-whole-vector-probes-that-synthesized-into-partial-signaltap-connections) | H | non-datapath-refactor | `directed-only (SignalTap observability build)` | fixed-debug-loadable | FEB STP map gate, 2026-05-14 | this checkpoint | The first FEB rbCAM-gap STP used whole-vector probes that Node Finder accepted but Quartus map only partially connected; the fixed generator emits bit-expanded instance-port probes and map reports all 631 SignalTap inputs/clocks/pins connected. |
| [BUG-010-H](#bug-010-h-febswb-corun-smoke-did-not-model-the-declared-128-subheader-frame) | H | non-datapath-refactor | `directed-only (FEB/SWB corun smoke and monitor harness)` | fixed | FEB/SWB corun UVM smoke, 2026-05-14 | this checkpoint | The corun smoke declared 128 subheaders but drove only the active subheader, and the monitors reconstructed true timestamps without rejecting a declared-versus-seen subheader mismatch. |

## 2026-05-14

### BUG-010-H: FEB/SWB corun smoke did not model the declared 128-subheader frame

- First seen:
  - FEB/SWB corun UVM harness review after the RN.BASIC cosim frame-format fix, 2026-05-14.
- Symptom:
  - The smoke frame declared `subheader_count = 128` in the frame header but emitted only one K28.7 subheader before the hit payload.
  - The FEB and OPQ monitors reconstructed true hit timestamps but did not independently compare the seen subheader count against the declared frame count.
- Root cause:
  - The older corun smoke was built as a minimal hit timestamp path check, not as a strict Mu3e wire-frame shape check.
  - That left a harness blind spot: a one-subheader trace could still produce a valid reconstructed timestamp and pass even though the frame was not shaped like the validated RN.BASIC cosim frame.
- Fix:
  - `tb_int/feb_swb_corun/uvm/tb_top.sv` now drives all 128 subheaders on both FEB and OPQ synthetic frame sources, with the hit payload only under the matching subheader timestamp.
  - `tb_int/feb_swb_corun/uvm/feb_swb_corun_uvm_pkg.sv` now tracks declared and seen subheader counts and reports `FEB_SWB_FRAME` errors on mismatch.
  - The corun run window was extended to 4 us so the enlarged frames can drain before the scoreboard summary.
- Evidence:
  - `make smoke` in `tb_int/feb_swb_corun/uvm` passed on 2026-05-14.
  - The smoke summary reported `feb=270`, `opq_debug=2`, `opq_payload=270`, `dma=2`, `dma_payload=2`, `missing_opq=0`, `missing_dma=0`, `ts_mismatch=0`, `true_ts_mismatch=0`, `UVM_ERROR=0`, and `UVM_FATAL=0`.
- Residuals:
  - This closes the synthetic FEB/SWB corun harness blind spot only. Board closure still requires STP proof through SWB OPQ and RDMA.

### BUG-009-H: FEB STP generator used whole-vector probes that synthesized into partial SignalTap connections

- First seen:
  - FEB `phase4_pre_hss_gap` SignalTap map gate for `v3_pretest-260511-emutype0-dualport-260512`, 2026-05-14.
- Symptom:
  - The old STP passed a pre-synthesis Node Finder check, but Quartus map reported a partially connected SignalTap instance.
  - Prior map evidence showed `phase4_pre_hss_gap_lvds` connected to only 125 of 171 requested inputs; 46 full-vector sources such as `selected_out_0_data` and `aso_hist_data` were missing after synthesis.
- Root cause:
  - The STP used whole-vector module-port probes. Quartus could resolve them in the pre-synthesis namespace, but did not preserve those aggregate vector names as post-synthesis debug sources.
  - A rejected alternative using generated Qsys architecture signal names produced 299 probes but Node Finder found 0 of them, proving those names are not valid in the STP pre-synthesis observable set.
- Fix:
  - `script/generate_phase4_pre_hss_gap_stp.py` now emits bit-expanded instance-port probes for each Avalon-ST field.
  - Probe groups cover arbiter selected output, mux-to-MTS, MTS type1 to histogram pre-input, pre-rbCAM histogram input, post-rbCAM CDC output, and histogram selector output.
  - The trigger is the bit-expanded pre-synthesis instance-port path for `histogram_ingress_bridge_0|aso_hist_valid`.
- Evidence:
  - Node Finder live check:
    `phase4_pre_hss_gap_nodes_livecheck_20260514_portbits.md`, `probes total=299 found=299 missing=0 errors=0`.
  - STP import completed with 0 errors and 0 warnings.
  - Map-only gate:
    `output_files_stp_phase4_pre_hss_gap/top_stp_phase4_pre_hss_gap.map.rpt` reports
    `Info (35024): Successfully connected in-system debug instance "phase4_pre_hss_gap_lvds" to all 631 required data inputs, trigger inputs, acquisition clocks, and dynamic pins`.
  - Full compile synthesis rerun repeated the same `Info (35024)` before entering fitter.
  - Full compile for revision `top_stp_phase4_pre_hss_gap` completed on 2026-05-14 with Quartus `0 errors, 1568 warnings`.
  - Fitter was successful; assembler was successful with 0 errors and 0 warnings.
  - Generated SOF:
    `syn/board_projects/fe_scifi_feb_v3/output_files_stp_phase4_pre_hss_gap/top_stp_phase4_pre_hss_gap.sof`,
    size `12746320` bytes,
    SHA256 `cf2dab3903da0455221bfa1b8ea06a2e7006c4a20fca28b9f5973673961fc881`.
  - STA setup corners:
    Slow 1100 mV 85 C `-0.440 ns`,
    Slow 1100 mV 0 C `-0.241 ns`,
    Fast 1100 mV 85 C `+0.510 ns`,
    Fast 1100 mV 0 C `+0.694 ns`.
  - This meets the FEB iterative-debug load gate of at least 2 passing corners, but it is not production timing closure.
- Residuals:
  - Board SignalTap capture is still pending.
  - The STP capture must still be naysayed against frame marker count, subheader count, hit count, timestamp reconstruction, spatial/channel distribution, pre/post rbCAM delay, and SWB OPQ/RDMA continuity before it can close the board datapath.

### BUG-008-I: FEB top Qsys exported a stale pulse_out_conduit interface

- First seen:
  - FEB top-level Qsys generation and wrapper compile for `v3_pretest-260511-emutype0-dualport-260512`, 2026-05-14.
- Symptom:
  - Regenerated top/wrapper surfaces still referenced `pulse_out_conduit` even though the active datapath/runctrl Qsys no longer exports that conduit.
  - The stale exported interface made the generated FEB wrapper inconsistent with the current run-control management host wiring.
- Root cause:
  - The top-level patch flow updated the datapath component and CSR address map, but did not remove the obsolete exported conduit from the legacy top Qsys export list.
  - Local wrapper files retained stale `pulse_out_conduit_pulse => open` associations after the Qsys interface disappeared.
- Fix:
  - `script/update_feb_system_v3_dualport_version.tcl` now removes the stale exported interface while rewriting the top metadata and address map.
  - The active `syn/feb_system_v3.qsys` no longer exports `pulse_out_conduit`.
  - Generated local wrappers were cleaned so the removed conduit is not instantiated as an open port.
- Evidence:
  - Qsys generation after the CSR-map/export fix completed with `exit_code=0` and `error_count=0`.
  - FEB STP map-only gate completed Analysis & Synthesis with 0 errors on 2026-05-14.
  - FEB full compile for revision `top_stp_phase4_pre_hss_gap` completed with Quartus `0 errors, 1568 warnings`; the remaining slow-corner setup failures are recorded under BUG-009-H as debug-image timing residuals.
- Residuals:
  - Production timing closure is still open; the current STP image is accepted only for iterative board debug.

### BUG-007-I: FEB top Qsys carried stale eight-emulator CSR map

- First seen:
  - FEB top-level Qsys generation for `v3_pretest-260511-emutype0-dualport-260512`, 2026-05-14.
- Symptom:
  - `qsys-generate` reported address-map legality errors for `emulator_mutrig_1..7.csr` at 0x40-byte strides.
  - `dbg_mm2runctrl_0.csr` overlapped the stale `emulator_mutrig_7.csr` range.
- Root cause:
  - The active datapath Qsys component is `scifi_datapath_system_v3` version `3.0.5.0512` with one `emulator_mutrig_qsys_inst` CSR aperture.
  - The top-level `control_path_subsystem.AUTO_AVMM_PORT_ADDRESS_MAP` still listed the older eight-emulator map and the `data_path_subsystem` module still requested version `3.0.4.512`.
- Fix:
  - `script/update_feb_system_v3_dualport_version.tcl` now rewrites both the top metadata and the top-level datapath binding/address map.
  - `data_path_subsystem_emulator_mutrig_qsys_inst.csr` is mapped to `0x2000..0x2100`.
  - `data_path_subsystem_dbg_mm2runctrl_0.csr` remains at `0x2200..0x2240`.
  - `data_path_subsystem_histogram_ingress_bridge_1.csr` is exported at `0xAC10..0xAC20`.
  - Build-local generation scripts call that top patch before `qsys-generate`.
- Evidence:
  - Qsys generation stamp `20260514_addrmap_fix`: `arb_hit_type0_supercore`, `scifi_datapath_system_v3`, `scifi_datapath_system_v3_pipe`, and top `feb_system_v3` all report `exit_code=0`, `error_count=0`.

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
