# Dual-port smoke simulation

## Summary

- Verdict: PASS
- Expected hits: 1000
- Observed interval bin sum: 1000
- Delta: 0
- Interval bin source: live hist_bin AVMM readback
- Port 0 handshakes (`hist_fill_in`): 500
- Port 1 handshakes (`fill_in_1`): 500
- Internal `hist_bin` write pulses observed: 844
- Max monitored `csr_total_hits`: 1000

## Interval Bin Sums

| Interval | Sum |
|---:|---:|
| 1 | 1000 |

## Trace Samples

| Probe | Cycle | Data | Bin | Bank | Value | CSR total |
|---|---:|---|---:|---:|---|---:|
| hist_fill_in | 2645 | 0x0000000000 | - | - | - | 0 |
| hist_fill_in | 2648 | 0x0000000000 | - | - | - | 2 |
| hist_fill_in | 2651 | 0x0000000000 | - | - | - | 4 |
| fill_in_1 | 2645 | 0x0000000000 | - | - | - | 0 |
| fill_in_1 | 2648 | 0x0000000000 | - | - | - | 2 |
| fill_in_1 | 2651 | 0x0000000000 | - | - | - | 4 |
| hist_bin_write | 2905 | 0x0 | 64 | 1 | 0x0000004F | 174 |
| hist_bin_write | 2906 | 0x0 | 62 | 1 | 0x0000004F | 174 |
| hist_bin_write | 2907 | 0x0 | 64 | 1 | 0x00000050 | 174 |

## Artifacts

- Summary CSV: `smoke_20260512_140755_summary.csv`
- Event CSV: `smoke_20260512_140755_events.csv`
- Live per-interval bin CSV: `smoke_20260512_140755_interval_bins.csv`
- Trace-derived per-interval bin CSV: `smoke_20260512_140755_trace_interval_bins.csv`
