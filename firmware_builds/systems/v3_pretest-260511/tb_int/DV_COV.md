# DV Coverage Summary - v3_pretest-260511 tb_int

This page is the coverage summary only. Per-case evidence lives under [`REPORT/`](REPORT/README.md).

## Legend

[PASS] pass / closed &middot; [WARN] partial / below target &middot; [FAIL] failed / missing evidence &middot; [PEND] pending &middot; [INFO] informational

## Targets vs merged totals

| status | metric | merged_pct | target |
|:---:|---|---|---|
| [WARN] | stmt | n/a | 95.0 |
| [WARN] | branch | n/a | 90.0 |
| [INFO] | cond | n/a | - |
| [INFO] | expr | n/a | - |
| [WARN] | fsm_state | n/a | 95.0 |
| [WARN] | fsm_trans | n/a | 90.0 |
| [WARN] | toggle | n/a | 80.0 |

## Per-bucket merged totals

| status | bucket | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle |
|:---:|---|---|---|---|---|---|---|---|
| [WARN] | [`BASIC`](doc/DV_BASIC.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| [PEND] | [`EDGE`](doc/DV_EDGE.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| [PEND] | [`PROF`](doc/DV_PROF.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| [PEND] | [`ERROR`](doc/DV_ERROR.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |

## Continuous-frame baselines by build

| status | run_id | kind | build | bucket | case_count | stmt | branch | toggle | functional_cross_pct | txns |
|:---:|---|---|---|---|---:|---|---|---|---:|---:|
| [PASS] | `B065_firefly_nominal_smoke` | isolated | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | 0.5 | 16 |
| [PASS] | `B066_emulator_direct_smoke` | isolated | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | 0.5 | 16 |
| [PASS] | `B067_sidecar_lineage` | isolated | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | 0.5 | 100 |
| [PASS] | `B068_histogram_cross_check` | isolated | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | 0.5 | 1024 |
| [PASS] | `B069_upload_pkt_mux_one_hit` | isolated | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | 0.5 | 1 |
| [PASS] | `RC_EMUL` | directed | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | n/a | 16 |
| [PASS] | `RC_EMUL_BLOCKED` | directed | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | n/a | 16 |
| [PASS] | `RC_EMUL_FIXED` | directed | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | n/a | 16 |
| [PASS] | `SOURCE_MUX_FRAME` | cosim | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | n/a | 5056 |
| [PASS] | `SOURCE_MUX_FRAME_nominal_5m` | cosim | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | n/a | 126944 |
| [PASS] | `SOURCE_MUX_FRAME_sparse_5m` | cosim | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | n/a | 9760 |
| [PASS] | `SOURCE_MUX_FRAME_high_q256_longdrain` | cosim | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | n/a | 124992 |
| [PASS] | `SOURCE_MUX_FRAME_high_q384_longdrain` | cosim | bridgefree_phase_a | BASIC | 1 | n/a | n/a | n/a | n/a | 187488 |
| [PASS] | `B067_bind_real_dut` | bind-smoke | generated_synthesis | BASIC | 1 | n/a | n/a | n/a | n/a | 100 |
| [PEND] | `all_buckets_frame` | all_buckets_frame | generated_dut | - | 768 | n/a | n/a | n/a | 0.0 | 0 |

## Non-Claims

No UCDB coverage is claimed in this phase. B065 through B069 and `RC_EMUL*`
close functional DEBUG_LEVEL=2 per-hit scoreboard evidence in the old dual UVM
environment; `SOURCE_MUX_FRAME*` closes the source-mux/frame-parser/MTS/histogram
cosim with exact parser/MTS/hist totals; and `B067_bind_real_dut` proves the
generated `synthesis/` tree compiles and can be instantiated as the dormant DUT
in the harness. The clean-STP FEB firmware compile is tracked as integration
evidence only and does not add UCDB coverage; slow-corner setup timing remains
open. RDMA SQE/CQE cosim is outside this harness.
