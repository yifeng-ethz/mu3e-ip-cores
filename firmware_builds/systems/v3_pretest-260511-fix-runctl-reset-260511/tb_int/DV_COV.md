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
| [PASS] | `B065_firefly_nominal_smoke` | isolated | firefly_nominal_feb_only | BASIC | 1 | n/a | n/a | n/a | 0.5 | 16 |
| [PEND] | `all_buckets_frame` | all_buckets_frame | generated_dut | - | 768 | n/a | n/a | n/a | 0.0 | 0 |

## Non-Claims

No UCDB coverage is claimed in this phase. B065 closes the corrected FEB-only firefly nominal smoke through the legacy `upload_pkt_mux` egress monitor; RDMA SQE/CQE cosim is outside this harness.
