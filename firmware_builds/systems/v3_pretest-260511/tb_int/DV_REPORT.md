# [WARN] DV Report - v3_pretest-260511 tb_int

**DUT:** `feb_system_v3` &nbsp; **Date:** `2026-05-15` &nbsp; **RTL variant:** `generated_synthesis + old dual UVM shell` &nbsp; **Seed:** `1`

This page is the chief-architect dashboard. All per-case evidence lives under [`REPORT/`](REPORT/README.md).

## Legend

[PASS] pass / closed &middot; [WARN] partial / below target / known limitation &middot; [FAIL] failed / missing evidence &middot; [PEND] pending &middot; [INFO] informational

## Health

| status | field | value |
|:---:|---|---|
| [PASS] | failed_cases | `0` |
| [PASS] | signoff_runs_with_failures | `0` |
| [WARN] | catalog_backlog_cases | `763` |
| [WARN] | unimplemented_cases | `763` |
| [PASS] | stale_artifacts | `0` |

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `generated_synthesis` |
| BUILD | `v3_pretest-260511` |
| TB_MODE | `histogram-backed behavioral shell + Type-0 arb/MTS/hist cosim` |
| BASIC_IMPLEMENTED | `B065-B069` |
| TOOLCHAIN | `QuestaOne 2026.1` |
| FEB_EGRESS_BIND | `legacy upload_pkt_mux` |
| debug_fallback_scope | `B-RC-CSR-001/002, E-RC-CSR-001, B-SC-JTG-001/002/003, E-SC-CONC-001` |
| STREAM_DEBUG_PHASE | `Type-0 arbitration after MuTRiG frame deassembly; BYTE_STREAM_ENABLE=false; histogram CONTROL.in_port source selection` |

## Non-Claims

- B065 through B069 and `RC_EMUL*` are old dual UVM environment results with debug-id per-hit scoreboard closure. Current RC/emulator evidence drives the real `runctl_mgmt_host` synclink input and generated Qsys splitters; the earlier shortcut one-hot waveform is retired.
- `TYPE0_ARB_HIST*` is Type-0 arb/MTS/histogram cosim evidence, not a full FEB board or all-buckets signoff run.
- `BIND_REAL_DUT=1` B067 is historical bridge-free bind-smoke evidence and is not claimed as current Type-0 sidecar evidence until rerun after the latest Qsys generation.
- The current Type-0 sidecar STP has been imported with `quartus_stp` and
  pre-synthesis node-finder resolves 282/282 probes. The
  `top_stp_stream_debug_hist` compile produced a SOF, but timing is not closed:
  STA setup WNS is -2.391 ns on the LVDS `pll_sclk` domain and -0.462 ns on
  `lvds_firefly_clk`.
- The 32x8 rate/latency cosims use a single-lane RTL slice with `LANE_SCALE=8`; they model the expected board rate but are not a full eight-lane instantiated firmware sim.
- Simulation enables DEBUG_LEVEL=2 for per-hit scoreboard lineage. Generated
  synthesis Qsys/VHDL is forced to DEBUG_LEVEL=0 and checked separately.
- CSR-toggle RC and JTAG-master SC are debug fallback paths only for their dedicated case IDs.
- RDMA SQE/CQE cosim is not claimed in this FEB-only harness; it belongs to the separate FEB+SWB task.
- UCDB/code-coverage closure is not claimed in this phase.

## Bucket Summary

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged | promoted functional |
|:---:|---|---:|---:|---:|---:|---|---|
| [WARN] | [`BASIC`](doc/DV_BASIC.md) | 192 | 5 | 5 | 187 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a | 2.6% (5/192) |
| [PEND] | [`EDGE`](doc/DV_EDGE.md) | 192 | 0 | 0 | 192 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a | 0.0% (0/192) |
| [PEND] | [`PROF`](doc/DV_PROF.md) | 192 | 0 | 0 | 192 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a | 0.0% (0/192) |
| [PEND] | [`ERROR`](doc/DV_ERROR.md) | 192 | 0 | 0 | 192 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a | 0.0% (0/192) |

## Totals

| status | metric | pct | target |
|:---:|---|---|---|
| [WARN] | stmt | n/a | 95.0 |
| [WARN] | branch | n/a | 90.0 |
| [INFO] | cond | n/a | - |
| [INFO] | expr | n/a | - |
| [WARN] | fsm_state | n/a | 95.0 |
| [WARN] | fsm_trans | n/a | 90.0 |
| [WARN] | toggle | n/a | 80.0 |

- catalog_planned_cases: `768`
- promoted_signoff_cases: `5`
- evidenced_promoted_cases: `5`
- promoted functional coverage: `2.6% (5/192 BASIC)`

## Signoff Runs

| status | run_id | kind | build | seq | txns | cross_pct |
|:---:|---|---|---|---|---:|---:|
| [PASS] | `B065_firefly_nominal_smoke` | isolated | type0_sidecar | run_B065 | 16 | 0.5 |
| [PASS] | `B066_emulator_direct_smoke` | isolated | type0_sidecar | run_B066 | 16 | 0.5 |
| [PASS] | `B067_sidecar_lineage` | isolated | type0_sidecar | run_B067 | 100 | 0.5 |
| [PASS] | `B068_histogram_cross_check` | isolated | type0_sidecar | run_B068 | 1024 | 0.5 |
| [PASS] | `B069_upload_pkt_mux_one_hit` | isolated | type0_sidecar | run_B069 | 1 | 0.5 |
| [PASS] | `RC_EMUL` | directed | type0_sidecar | run_RC_EMUL | 16 | n/a |
| [PASS] | `RC_EMUL_FIXED` | directed | type0_sidecar | run_RC_EMUL_FIXED | 16 | n/a |
| [PASS] | `RC_EMUL_REALISTIC` | directed | type0_sidecar | run_RC_EMUL_FIXED + TB_INT_REALISTIC_LATENCY + split emulator-egress checkpoint + 5000-cycle RUN_PREP flush | 16 | n/a |
| [PASS] | `TYPE0_ARB_HIST_switch` | cosim | type0_sidecar | run_type0_arb_mts_hist_cosim | 5392 | n/a |
| [PASS] | `TYPE0_ARB_HIST_rate_32x8_model` | cosim | type0_sidecar | run_type0_arb_mts_hist_cosim_rate | 3168 | n/a |
| [PASS] | `TYPE0_ARB_HIST_latency_32x8_model` | cosim | type0_sidecar | run_type0_arb_mts_hist_cosim_latency | 3168 | n/a |
| [PASS] | `TYPE0_ARB_HIST_wave` | cosim | type0_sidecar | run_type0_arb_mts_hist_cosim_wave | 5392 | n/a |

## Index

- `sim_feb_host_runctl_split_egress_regress_basic_20260516/*/transcript` - current local run transcripts for B065-B069
- `sim_uvm_type0_rcemul_20260515/*/transcript` - current local run transcripts for RC_EMUL and RC_EMUL_FIXED
- `sim_feb_host_runctl_split_egress_20260516/RC_EMUL_REALISTIC/transcript` - real `runctl_mgmt_host` synclink input plus generated Qsys splitter path; explicit reset/configure/40 us `RUN_PREP`/run/collection directed run, one channel at 100 kHz, 16 closed hits
- `sim_feb_host_runctl_split_egress_20260516/RC_EMUL_REALISTIC/rbcam_lifetime_report.{md,csv}` - generated per-hit lifetime report: rbCAM ingress = 835 cycles for all hits, rbCAM egress = 2070 cycles for all hits
- `sim_type0_arb_switch2_20260515/TYPE0_ARB_HIST/transcript` - runtime EMU->REAL->EMU Type-0 arb/MTS/histogram cosim
- `sim_type0_arb_32x8_rate_20260515/TYPE0_ARB_HIST_RATE/transcript` - 32x8 100 kHz rate-mode model cosim
- `sim_type0_arb_32x8_latency_20260515/TYPE0_ARB_HIST_LATENCY/transcript` - 32x8 100 kHz latency-mode model cosim
- `sim_hist_ip_cosim_exploratory_fail_20260515/*/transcript` - non-signoff exploratory failures used for BUG-008-H root cause
- `sim_type0_arb_wave_20260515/TYPE0_ARB_HIST_WAVE/type0_arb_mts_hist.{vcd,fst}` and `waves/gtkw/type0_arb_mts_hist.gtkw` - waveform/GTKWave evidence for Type-0 hits filling the histogram IP
- `sim_feb_host_runctl_split_egress_20260516/RC_EMUL_REALISTIC/feb_host_runctl_realistic.{vcd,fst}` and `waves/gtkw/feb_host_runctl_emulator_rbcam_realistic.gtkw` - GTKWave evidence for run-control host input, generated splitters, emulator commit, emulator egress, rbCAM ingress/egress, histogram fill, and FEB frame assembly checkpoints with decoded payload fields
- `../signaltap/stream_debug_hist_path.stp` - current 282-probe Type-0/MTS/hist SignalTap probe set
- `../signaltap/stream_debug_hist_path_nodes_top_stp_stream_debug_hist.md` - pre-synthesis node-finder PASS, 282 found, 0 missing
- `../syn/quartus_stp_stream_debug_hist_20260515_type0_remap.log` - current `quartus_stp` import transcript, 0 errors and 0 warnings
- `../syn/board_projects/fe_scifi_feb_v3/output_files_stp_stream_debug_hist/top_stp_stream_debug_hist.sof` - generated debug SOF; not timing signoff because STA has setup violations
- `../script/check_feb_synthesis_debug_levels.py` - synthesis debug-level checker, PASS with `allowed_debug=[0]`
- [`DV_COV.md`](DV_COV.md) - coverage summary and non-claims
