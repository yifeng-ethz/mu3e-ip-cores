# [WARN] DV Report - v3_pretest-260511 tb_int

**DUT:** `feb_system_v3` &nbsp; **Date:** `2026-05-11` &nbsp; **RTL variant:** `generated_synthesis` &nbsp; **Seed:** `1`

This page is the chief-architect dashboard. All per-case evidence lives under [`REPORT/`](REPORT/README.md).

## Legend

[PASS] pass / closed &middot; [WARN] partial / below target / known limitation &middot; [FAIL] failed / missing evidence &middot; [PEND] pending &middot; [INFO] informational

## Health

| status | field | value |
|:---:|---|---|
| [PASS] | failed_cases | `0` |
| [PASS] | signoff_runs_with_failures | `0` |
| [WARN] | catalog_backlog_cases | `767` |
| [WARN] | unimplemented_cases | `767` |
| [PASS] | stale_artifacts | `0` |

## Signoff Scope

| field | claimed value |
|---|---|
| DUT_IMPL | `generated_synthesis` |
| BUILD | `v3_pretest-260511` |
| TB_MODE | `firefly_nominal_feb_only` |
| BASIC_IMPLEMENTED | `B065` |
| TOOLCHAIN | `QuestaOne 2026.1` |
| FEB_EGRESS_BIND | `legacy upload_pkt_mux` |
| debug_fallback_scope | `B-RC-CSR-001/002, E-RC-CSR-001, B-SC-JTG-001/002/003, E-SC-CONC-001` |

## Non-Claims

- B065 is a firefly nominal FEB-only smoke result through the corrected `upload_pkt_mux` egress contract.
- CSR-toggle RC and JTAG-master SC are debug fallback paths only for their dedicated case IDs.
- RDMA SQE/CQE cosim is not claimed in this FEB-only harness; it belongs to the separate FEB+SWB task.

## Bucket Summary

| status | bucket | catalog_planned | promoted | evidenced | backlog | merged | promoted functional |
|:---:|---|---:|---:|---:|---:|---|---|
| [WARN] | [`BASIC`](doc/DV_BASIC.md) | 192 | 1 | 1 | 191 | stmt=n/a, branch=n/a, cond=n/a, expr=n/a, fsm_state=n/a, fsm_trans=n/a, toggle=n/a | 0.5% (1/192) |
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
- promoted_signoff_cases: `1`
- evidenced_promoted_cases: `1`
- promoted functional coverage: `0.5% (1/192 BASIC)`

## Signoff Runs

| status | run_id | kind | build | seq | txns | cross_pct |
|:---:|---|---|---|---|---:|---:|
| [PASS] | [`B065_firefly_nominal_smoke`](REPORT/B065/REPORT.md) | isolated | firefly_nominal_feb_only | run_B065 | 16 | 0.5 |

## Index

- [`REPORT/README.md`](REPORT/README.md) - reviewer entry point
- [`REPORT/B065/REPORT.md`](REPORT/B065/REPORT.md) - B065 evidence
- [`DV_COV.md`](DV_COV.md) - coverage summary and non-claims
