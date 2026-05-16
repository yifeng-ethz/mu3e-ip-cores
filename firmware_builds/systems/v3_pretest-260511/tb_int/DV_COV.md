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
| [PASS] | `B065_firefly_nominal_smoke` | isolated | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | 0.5 | 16 |
| [PASS] | `B066_emulator_direct_smoke` | isolated | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | 0.5 | 16 |
| [PASS] | `B067_sidecar_lineage` | isolated | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | 0.5 | 100 |
| [PASS] | `B068_histogram_cross_check` | isolated | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | 0.5 | 1024 |
| [PASS] | `B069_upload_pkt_mux_one_hit` | isolated | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | 0.5 | 1 |
| [PASS] | `RC_EMUL` | directed | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 16 |
| [PASS] | `RC_EMUL_FIXED` | directed | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 16 |
| [PASS] | `RC_EMUL_REALISTIC` | directed | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 16 |
| [PASS] | `TYPE0_ARB_HIST_switch` | cosim | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 5392 |
| [PASS] | `TYPE0_ARB_HIST_rate_32x8_model` | cosim | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 3168 |
| [PASS] | `TYPE0_ARB_HIST_latency_32x8_model` | cosim | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 3168 |
| [PASS] | `TYPE0_ARB_HIST_wave` | cosim | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 5392 |
| [PEND] | `all_buckets_frame` | all_buckets_frame | generated_dut | - | 768 | n/a | n/a | n/a | 0.0 | 0 |

## Non-Claims

No UCDB coverage is claimed in this phase. B065 through B069 and `RC_EMUL*`
close functional per-hit scoreboard evidence in the old dual UVM environment;
the current RC/emulator waveform evidence uses the real `runctl_mgmt_host`
synclink command stream and generated Qsys splitters, not the retired shortcut
one-hot model. The corrected realistic run lives in
`sim_feb_host_runctl_split_egress_20260516/RC_EMUL_REALISTIC` and includes
separate emulator commit, emulator egress, rbCAM ingress, rbCAM egress, and
FEB egress checkpoints; `rbcam_lifetime_report.md` shows 16/16 rbCAM ingress
hits at 835 cycles and 16/16 rbCAM egress hits at 2070 cycles.
`TYPE0_ARB_HIST*` closes the Type-0 arb/MTS/histogram cosim with exact selected
hit, metadata, MTS sidecar, and histogram totals. The 32x8 rate/latency cases
use a single-lane RTL cosim slice with `LANE_SCALE=8`; they model the expected
board rate but are not a full eight-lane instantiated firmware sim. The current
STP import and SOF build are integration evidence only and do not add UCDB
coverage; node validation passed pre-synthesis, but timing and board capture
remain open. RDMA
SQE/CQE cosim is outside this harness.
