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
| TB_MODE | `firefly_nominal_feb_only` |
| BASIC_IMPLEMENTED | `B065-B069` |
| TOOLCHAIN | `QuestaOne 2026.1` |
| FEB_EGRESS_BIND | `legacy upload_pkt_mux` |
| debug_fallback_scope | `B-RC-CSR-001/002, E-RC-CSR-001, B-SC-JTG-001/002/003, E-SC-CONC-001` |
| STREAM_DEBUG_PHASE | `bridge-free Phase A, histogram CONTROL.in_port source selection` |

## Non-Claims

- B065 through B069 and `RC_EMUL` are old dual UVM environment results with DEBUG_LEVEL=2 per-hit scoreboard closure.
- `SOURCE_MUX_FRAME` is source-mux/frame-parser cosim evidence, not a full FEB board or all-buckets signoff run.
- `BIND_REAL_DUT=1` B067 compiles and instantiates the generated `synthesis/` tree as `u_dut`; the existing behavioral shell taps remain the scoreboard-observed path.
- Vendor/generated assertions under `u_dut` are disabled in bind mode to keep dormant generated fabric from polluting the UVM scoreboard result.
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
| [PASS] | `B065_firefly_nominal_smoke` | isolated | bridgefree_phase_a | run_B065 | 16 | 0.5 |
| [PASS] | `B066_emulator_direct_smoke` | isolated | bridgefree_phase_a | run_B066 | 16 | 0.5 |
| [PASS] | `B067_sidecar_lineage` | isolated | bridgefree_phase_a | run_B067 | 100 | 0.5 |
| [PASS] | `B068_histogram_cross_check` | isolated | bridgefree_phase_a | run_B068 | 1024 | 0.5 |
| [PASS] | `B069_upload_pkt_mux_one_hit` | isolated | bridgefree_phase_a | run_B069 | 1 | 0.5 |
| [PASS] | `RC_EMUL` | directed | bridgefree_phase_a | run_RC_EMUL | 16 | n/a |
| [PASS] | `SOURCE_MUX_FRAME` | cosim | bridgefree_phase_a | run_source_mux_frame_parser_cosim | 5056 | n/a |
| [PASS] | `B067_bind_real_dut` | bind-smoke | generated_synthesis | run_B067 BIND_REAL_DUT=1 | 100 | n/a |

## Index

- `sim_stream_debug_20260515_rerun/*/transcript` - local run transcripts for B065-B069, RC_EMUL, and SOURCE_MUX_FRAME
- `sim_stream_debug_bind/B067/transcript` - generated-DUT bind smoke transcript
- [`DV_COV.md`](DV_COV.md) - coverage summary and non-claims
