# DV Cross — `arb_hit_type0`

**Companion docs:** [`README.md`](../README.md), [`DV_PLAN.md`](DV_PLAN.md), [`DV_HARNESS.md`](DV_HARNESS.md), [`DV_BASIC.md`](DV_BASIC.md), [`DV_EDGE.md`](DV_EDGE.md), [`DV_PROF.md`](DV_PROF.md), [`DV_ERROR.md`](DV_ERROR.md), [`BUG_HISTORY.md`](BUG_HISTORY.md)

**Parent:** [DV_PLAN.md](DV_PLAN.md)
**ID Range:** `X001`-`X099`

This file owns the long-run, no-restart, continuous-frame baselines required by the `dv-workflow` skill: `bucket_frame` per bucket and `all_buckets_frame` across all sign-off buckets.

---

## 1. `bucket_frame` baselines

### X001_bucket_frame_basic

- **Goal:** Run all `B*` cases in case-id order inside one continuous timeframe without restarting the DUT between cases. Each case's expected scoreboard observations must hold relative to the running counter baseline (scoreboard subtracts the prior baseline; CSR W1P clears between cases are explicit and recorded).
- **Status:** planned

### X002_bucket_frame_edge

- Same as X001 for `E*`.
- **Status:** planned

### X003_bucket_frame_prof

- Same as X001 for `P*`.
- **Status:** planned

### X004_bucket_frame_error

- Same as X001 for `R*`. `R001`-`R003` issue resets, so this bucket frame is special: each post-reset segment is a sub-frame, and the merged-coverage rule treats sub-frames as the unit.
- **Status:** planned

---

## 2. `all_buckets_frame` baseline

### X005_all_buckets_frame

- **Goal:** Run every sign-off case in bucket order (`B*`, `E*`, `P*`, `R*`) and case-id order within each bucket, inside one continuous timeframe (with the same reset-handling rule as X004). The merged UCDB across this run is the long-run functional-coverage and continuous-frame sign-off baseline.
- **Status:** planned

---

## 3. Plan drift notes

(none yet)
