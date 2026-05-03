# DV Report - mutrig_lane_source_mux

**DUT:** `mutrig_lane_source_mux`  **Date:** `2026-05-03`  **RTL variant:** `current worktree`

## Legend

pass / closed | partial / below target / known limitation | failed / missing evidence | pending | informational

## Health

| status | field | value |
|:---:|---|---|
| pass | directed_case_failures | `0` in clean `directed64` rerun |
| pass | uvm_compile | `QuestaOne 2026.1_1` |
| pass | prof_soak_30s | `SOAK_ITERS=150000`, 3/3 runs >=30s, no UVM errors |

## Bucket Summary

| status | bucket | catalog_planned | implemented | evidenced | note |
|:---:|---|---:|---:|---:|---|
| pass | BASIC | 64 | 64 | 64 | B001-B064 directed cases. |
| pass | PROF | 3 | 3 | 3 | P001-P003 long random directed-case soaks. |

## Signoff Runs

| status | run_id | kind | build | cases |
|:---:|---|---|---|---:|
| pass | `directed64` | isolated | `REAL_ALWAYS_VALID=0/1` | 64 |
| pass | `directed32_rav0` | isolated | `REAL_ALWAYS_VALID=0` | 32 |
| pass | `directed32_rav1` | isolated | `REAL_ALWAYS_VALID=1` | 32 |
| pass | `bucket_frame` | continuous frame | `REAL_ALWAYS_VALID=0/1` | 2 |
| pass | `soak_150000_s101` | pressure | `REAL_ALWAYS_VALID=0` | P001, 34s |
| pass | `soak_150000_s102` | pressure | `REAL_ALWAYS_VALID=1` | P002, 37s |
| pass | `soak_150000_s103` | pressure | `REAL_ALWAYS_VALID=1` | P003, 36s |

## Index

- [`DV_PLAN.md`](DV_PLAN.md)
- [`DV_HARNESS.md`](DV_HARNESS.md)
- [`DV_BASIC.md`](DV_BASIC.md)
- [`DV_PROF.md`](DV_PROF.md)
- [`DV_CROSS.md`](DV_CROSS.md)
- [`DV_COV.md`](DV_COV.md)
- [`BUG_HISTORY.md`](BUG_HISTORY.md)
