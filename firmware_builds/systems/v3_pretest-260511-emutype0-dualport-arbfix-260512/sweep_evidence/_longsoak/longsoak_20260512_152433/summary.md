# Phase 4.5 dual-port long soak

- Verdict: FAIL
- Target hits: 100000
- Observed cumulative hits: 33792
- Tolerance: +/-1500
- Rate: 0x0016
- Interval clocks: 1250000
- Intervals captured: 5
- Toggle misses: 0
- Nonzero channels: []
- Final frozen-bank bin sum: 0
- Timed readout mode: csr_poll_during_run_full_256_bin_snapshot_after_end_run

## Per-Interval Summary

| interval | toggle | bank_status | elapsed_s | last_interval_total | total_live | dropped_live |
|---:|---:|---|---:|---:|---:|---:|
| 0 | 1 | 0x00000001 | 0.015260 | 6752 | 5856 | 0 |
| 1 | 1 | 0x00000000 | 0.033457 | 6784 | 2880 | 0 |
| 2 | 1 | 0x00000001 | 0.041175 | 6784 | 6400 | 0 |
| 3 | 1 | 0x00000000 | 0.046353 | 6752 | 3616 | 0 |
| 4 | 1 | 0x00000001 | 0.075768 | 6720 | 5664 | 0 |
