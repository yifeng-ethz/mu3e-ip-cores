# DV Cov — `arb_hit_type0`

**Parent:** [DV_PLAN.md](DV_PLAN.md)

Per the `dv-workflow` skill, this file is mandatory and must contain one maintained per-bucket testcase table and the running merged-coverage trace.

## 1. BASIC bucket

| ID | Title | Status | Sim seed | UCDB | Sign-off run | Iso line% | Iso branch% | Iso toggle% | Functional bins added |
|---|---|---|---|---|---|---|---|---|---|
| B001 | uid_read | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B002 | uid_write_ignored | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B003 | meta_versioning | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B004 | default_mode_real | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B005 | set_mode_emu | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B006 | set_mode_mix_rr | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B007 | real_only_drain | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B008 | emu_only_drain | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B009 | mix_rr_alternation | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B010 | switch_at_idle | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B011 | switch_during_packet_defers | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B012 | switch_back_to_back | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B013 | real_fifo_fill_drain | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B014 | emu_fifo_fill_drain | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B015 | idle_does_not_consume | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B016 | ingress_real_hit_counter | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B017 | ingress_emu_hit_counter | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B018 | drop_real_counter | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B019 | drop_emu_counter | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B020 | egress_real_counter | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B021 | egress_emu_counter | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B022 | low_high_pair_atomicity | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B023 | w1p_clear_counters | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |
| B024 | csr_back_to_back_writes | planned | n/a | n/a | n/a | n/a | n/a | n/a | n/a |

- Iso merged code coverage: pending
- Functional coverage: pending
- `bucket_frame` baseline: pending
- `all_buckets_frame` baseline: pending

## 2. EDGE bucket

| ID | Title | Status |
|---|---|---|
| E001..E018 | see DV_EDGE.md | planned |

## 3. PROF bucket

| ID | Title | Status |
|---|---|---|
| P001..P008 | see DV_PROF.md | planned |

## 4. ERROR bucket

| ID | Title | Status |
|---|---|---|
| R001..R012 | see DV_ERROR.md | planned |

## 5. CROSS bucket

| ID | Title | Status |
|---|---|---|
| X001..X005 | see DV_CROSS.md | planned |

## 6. Final sign-off totals

Pending. Final sign-off cannot be claimed until the BASIC, EDGE, PROF, ERROR per-case tables are populated, the per-bucket isolated merged code-coverage and functional-coverage totals meet the DV_PLAN targets, and the `bucket_frame` and `all_buckets_frame` baselines are recorded.
