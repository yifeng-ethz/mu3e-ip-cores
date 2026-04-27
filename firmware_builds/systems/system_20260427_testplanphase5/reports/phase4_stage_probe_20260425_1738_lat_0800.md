# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T17:33:42`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0800`
- Duration: `50 ms`
- Iterations: `1`
- Ring input-error filter override: `keep`
- MTS expected latency override: `2048`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `blocked_hist_ingress_or_stats` | 83176 | 5230823 | 20630284 | 73252 | 73252 | 73252 | 0 | 0 | 0 | `0x00000603` | `0x00000048` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `blocked_hist_ingress_or_stats`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': 2048}`
- Ingress select status: `0x00000403`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 2615700 | 2615700 |
| `mts1.total_hits` | 0 | 2615123 | 2615123 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 2579092/9391/9391 | 2579092/9391/9391 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 2579092/8800/8800 | 2579092/8800/8800 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 2579092/9217/9217 | 2579092/9217/9217 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 2579092/9200/9200 | 2579092/9200/9200 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 2578479/9155/9155 | 2578479/9155/9155 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 2578479/8964/8964 | 2578479/8964/8964 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 2578479/9422/9422 | 2578479/9422/9422 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 2578479/9103/9103 | 2578479/9103/9103 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 36608/36608/0 | 36608/36608/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 36644/36644/0 | 36644/36644/0 |
| `hist.total/dropped` | 0/0 | 0/0 | 0/0 |

