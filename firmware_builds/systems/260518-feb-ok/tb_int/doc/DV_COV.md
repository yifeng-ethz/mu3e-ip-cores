# DV_COV.md - 260518-feb-ok tb_int coverage tracking

Per dv-workflow rules 6 + 7. Establishes the per-bucket coverage tables
on day 1; will be updated continuously through development, debug, and
sign-off. Sign-off requires every table to be populated and traceable
to regression evidence.

## Isolated per-case merged totals

Each case has its own UCDB; the merged total is rebuilt incrementally as
new cases land. Continuous-frame UCDBs (`bucket_frame`,
`all_buckets_frame`) are tracked separately below.

### BASIC bucket (B001-B999)

| Case | Statement | Branch | Condition | Expression | FSM | Toggle | UCDB |
|---|---|---|---|---|---|---|---|
| B001 | pending | pending | pending | pending | pending | pending | uvm/builds/B001/cov.ucdb |
| B002 | pending | pending | pending | pending | pending | pending | uvm/builds/B002/cov.ucdb |
| **merged isolated** | pending | pending | pending | pending | pending | pending | uvm/builds/merged_isolated.ucdb |

### EDGE bucket (E001-E999)

| Case | Statement | Branch | Condition | Expression | FSM | Toggle | UCDB |
|---|---|---|---|---|---|---|---|
| E001 | pending | pending | pending | pending | pending | pending | uvm/builds/E001/cov.ucdb |

### PROF bucket (P001-P999)

| Case | Statement | Branch | Condition | Expression | FSM | Toggle | UCDB |
|---|---|---|---|---|---|---|---|
| P001 | pending | pending | pending | pending | pending | pending | uvm/builds/P001/cov.ucdb |

### ERROR bucket (X001-X999)

| Case | Statement | Branch | Condition | Expression | FSM | Toggle | UCDB |
|---|---|---|---|---|---|---|---|
| X001 | pending | pending | pending | pending | pending | pending | uvm/builds/X001/cov.ucdb |

## Continuous-frame totals (reported separately)

### bucket_frame totals

| Bucket | Statement | Branch | Condition | Expression | FSM | Toggle | UCDB |
|---|---|---|---|---|---|---|---|
| B (basic_frame) | pending | pending | pending | pending | pending | pending | uvm/builds/bucket_frame_B.ucdb |

### all_buckets_frame total

| Stmt | Branch | Cond | Expr | FSM | Toggle | UCDB |
|---|---|---|---|---|---|---|
| pending | pending | pending | pending | pending | pending | uvm/builds/all_buckets_frame.ucdb |

## Functional coverage

| Coverpoint | Bins | Target | Current | Source |
|---|---|---|---|---|
| upload_pkt_mux arbitration {in0, in1, in2} | 3 | 100% each | pending | UB scoreboard |
| histogram bank toggle {bank0->bank1, bank1->bank0} | 2 | 100% each | pending | HB scoreboard |
| mts_preprocessor hit_type1_ts conduit valid pulse | 2 banks x {idle, hit} | 100% | pending | hit_type1_ts conduit monitor |

## Sign-off criteria

- Every cell in every bucket table must be a concrete percentage, not
  `pending`.
- Merged isolated total must reach the per-bucket gate set in
  [DV_PLAN.md](DV_PLAN.md).
- bucket_frame and all_buckets_frame totals are reported but may diverge
  from isolated totals; divergence must be documented in
  [DV_PLAN.md](DV_PLAN.md).
- `dv_bucket_format_check.py` exits clean for every bucket file.
