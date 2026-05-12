# 100k single-channel 10ms ping-pong soak simulation

## Summary

- Verdict: PASS
- Expected hits: 100000
- Observed interval bin sum: 100000
- Delta: 0
- Interval bin source: trace-derived from internal hist_bin write events
- Port 0 handshakes (`hist_fill_in`): 50000
- Port 1 handshakes (`fill_in_1`): 50000
- Internal `hist_bin` write pulses observed: 100000
- Max monitored `csr_total_hits`: 10000

## Interval Bin Sums

| Interval | Sum |
|---:|---:|
| 1 | 10000 |
| 2 | 10000 |
| 3 | 10000 |
| 4 | 10000 |
| 5 | 10000 |
| 6 | 10000 |
| 7 | 10000 |
| 8 | 10000 |
| 9 | 10000 |
| 10 | 10000 |

## Trace Samples

| Probe | Cycle | Data | Bin | Bank | Value | CSR total |
|---|---:|---|---:|---:|---|---:|
| hist_fill_in | 1250645 | 0x0000000000 | - | - | - | 0 |
| hist_fill_in | 1250895 | 0x0000000000 | - | - | - | 2 |
| hist_fill_in | 1251145 | 0x0000000000 | - | - | - | 4 |
| fill_in_1 | 1250645 | 0x0000000000 | - | - | - | 0 |
| fill_in_1 | 1250895 | 0x0000000000 | - | - | - | 2 |
| fill_in_1 | 1251145 | 0x0000000000 | - | - | - | 4 |
| hist_bin_write | 1250905 | 0x0 | 64 | 1 | 0x00000001 | 4 |
| hist_bin_write | 1250906 | 0x0 | 62 | 1 | 0x00000001 | 4 |
| hist_bin_write | 1250920 | 0x0 | 64 | 1 | 0x00000002 | 4 |

## Artifacts

- Summary CSV: `soak_20260512_140939_summary.csv`
- Event CSV: `soak_20260512_140939_events.csv`
- Live per-interval bin CSV: `soak_20260512_140939_interval_bins.csv`
- Trace-derived per-interval bin CSV: `soak_20260512_140939_trace_interval_bins.csv`
