# DV Coverage Summary — v3_pretest-260511 tb_int

This page is the coverage summary only. Per-case evidence lives under [`REPORT/`](../REPORT/README.md).

## Legend

✅ pass / closed &middot; ⚠️ partial / below target &middot; ❌ failed / missing evidence &middot; ❓ pending &middot; ℹ️ informational

## Targets vs merged totals

| status | metric | merged_pct | target |
|:---:|---|---|---|
| ⚠️ | stmt | n/a | 95.0 |
| ⚠️ | branch | n/a | 90.0 |
| ℹ️ | cond | n/a | - |
| ℹ️ | expr | n/a | - |
| ⚠️ | fsm_state | n/a | 95.0 |
| ⚠️ | fsm_trans | n/a | 90.0 |
| ⚠️ | toggle | n/a | 80.0 |

## Per-bucket merged totals

| status | bucket | stmt | branch | cond | expr | fsm_state | fsm_trans | toggle |
|:---:|---|---|---|---|---|---|---|---|
| ⚠️ | [`BASIC`](DV_BASIC.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ❓ | [`EDGE`](DV_EDGE.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ❓ | [`PROF`](DV_PROF.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| ❓ | [`ERROR`](DV_ERROR.md) | n/a | n/a | n/a | n/a | n/a | n/a | n/a |

## Continuous-frame baselines by build

| status | run_id | kind | build | bucket | case_count | stmt | branch | toggle | functional_cross_pct | txns |
|:---:|---|---|---|---|---:|---|---|---|---:|---:|
| ✅ | `B065_firefly_nominal_smoke` | isolated | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | 0.5 | 16 |
| ✅ | `B066_emulator_direct_smoke` | isolated | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | 0.5 | 16 |
| ✅ | `B067_sidecar_lineage` | isolated | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | 0.5 | 100 |
| ✅ | `B068_histogram_cross_check` | isolated | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | 0.5 | 1024 |
| ✅ | `B069_upload_pkt_mux_one_hit` | isolated | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | 0.5 | 1 |
| ✅ | `RC_EMUL` | directed | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 16 |
| ✅ | `RC_EMUL_FIXED` | directed | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 16 |
| ✅ | `RC_EMUL_REALISTIC` | directed | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 16 |
| ✅ | `TYPE0_ARB_HIST_switch` | cosim | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 5392 |
| ✅ | `TYPE0_ARB_HIST_rate_32x8_model` | cosim | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 3168 |
| ✅ | `TYPE0_ARB_HIST_latency_32x8_model` | cosim | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 3168 |
| ✅ | `TYPE0_ARB_HIST_wave` | cosim | type0_sidecar | BASIC | 1 | n/a | n/a | n/a | n/a | 5392 |
| ❓ | `all_buckets_frame` | all_buckets_frame | generated_dut | - | 768 | n/a | n/a | n/a | 0.0 | 0 |

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

_Regenerate with `make run_RC_EMUL_REALISTIC_LONG_WAVE` and then refresh `DV_REPORT.json`, `DV_REPORT.md`, and `DV_COV.md` from the resulting tb_int evidence._
