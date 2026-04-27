# Phase 4 Stage Counter Probe

- Timestamp: `2026-04-25T17:35:09`
- SC link: `2`
- FEB target: `7`
- Hit rate: `0x0100`
- Duration: `100 ms`
- Iterations: `2`
- Ring input-error filter override: `keep`
- MTS expected latency override: `None`

## Summary

| Iter | Class | Emu Frames | MTS Hits | Ring InErr | Ring Push | Ring Pop | Frame Actual | Hist Total | Hist Drop | CRC Err | Ingress | SC Flags | SC Drops |
|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | `PASS` | 112152 | 1396612 | 5585744 | 176 | 176 | 176 | 79 | 0 | 0 | `0x00000403` | `0x00000048` | 0 |
| 1 | `PASS` | 113472 | 1413016 | 5651896 | 42 | 42 | 42 | 21 | 0 | 0 | `0x00000403` | `0x00000048` | 0 |

## Per-Iteration Stage Detail

### Iteration 0

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000503`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 698403 | 698403 |
| `mts1.total_hits` | 0 | 698209 | 698209 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 698324/22/22 | 698324/22/22 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 698324/5/5 | 698324/5/5 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 698324/34/34 | 698324/34/34 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 698324/18/18 | 698324/18/18 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 698112/32/32 | 698112/32/32 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 698112/16/16 | 698112/16/16 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 698112/27/27 | 698112/27/27 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 698112/22/22 | 698112/22/22 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 79/79/0 | 79/79/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 97/97/0 | 97/97/0 |
| `hist.total/dropped` | 0/0 | 79/0 | 79/0 |

### Iteration 1

- Classification: `PASS`
- Lane-go: `0x000001FF`
- Debug overrides: `{'ring_filter_inerr': 'keep', 'mts_expected_latency': None}`
- Ingress select status: `0x00000E03`

| Stage | Before | After | Delta |
|---|---:|---:|---:|
| `mts0.total_hits` | 0 | 706763 | 706763 |
| `mts1.total_hits` | 0 | 706253 | 706253 |
| `hs0_rb0.inerr/push/pop` | 0/0/0 | 706742/2/2 | 706742/2/2 |
| `hs0_rb1.inerr/push/pop` | 0/0/0 | 706742/11/11 | 706742/11/11 |
| `hs0_rb2.inerr/push/pop` | 0/0/0 | 706742/0/0 | 706742/0/0 |
| `hs0_rb3.inerr/push/pop` | 0/0/0 | 706742/8/8 | 706742/8/8 |
| `hs1_rb0.inerr/push/pop` | 0/0/0 | 706232/0/0 | 706232/0/0 |
| `hs1_rb1.inerr/push/pop` | 0/0/0 | 706232/10/10 | 706232/10/10 |
| `hs1_rb2.inerr/push/pop` | 0/0/0 | 706232/0/0 | 706232/0/0 |
| `hs1_rb3.inerr/push/pop` | 0/0/0 | 706232/11/11 | 706232/11/11 |
| `hs0_frame.decl/actual/missing` | 0/0/0 | 21/21/0 | 21/21/0 |
| `hs1_frame.decl/actual/missing` | 0/0/0 | 21/21/0 | 21/21/0 |
| `hist.total/dropped` | 0/0 | 21/0 | 21/0 |

